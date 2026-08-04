import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../models/license_models.dart';
import '../services/device_fingerprint.dart';
import '../services/license_client.dart';
import '../services/license_repository.dart';
import '../services/log_service.dart';

/// Owns license state and exposes activation/validation. Mirrors
/// SettingsController's ChangeNotifier shape so it slots into app_shell the
/// same way as SettingsController.
class LicenseController extends ChangeNotifier {
  LicenseController({
    LicenseRepository? repository,
    LicenseClient? client,
    DeviceFingerprint? fingerprint,
  }) : _repository = repository ?? LicenseRepository(),
       _client = client ?? LicenseClient(),
       _fingerprint = fingerprint ?? const DeviceFingerprint();

  final LicenseRepository _repository;
  final LicenseClient _client;
  final DeviceFingerprint _fingerprint;

  LicenseState _state = LicenseState.free;
  bool _hasLoaded = false;
  List<LicenseDevice> _devices = const [];
  int? _deviceLimit;
  bool _isSyncing = false;
  String? _syncError;

  LicenseState get state => _state;
  LicenseTier get tier => _state.effectiveTier;
  Entitlements get entitlements => _state.entitlements;
  bool get hasLoaded => _hasLoaded;
  List<LicenseDevice> get devices => List.unmodifiable(_devices);
  int get activeDeviceCount => _devices.length;
  int get maxDevices =>
      _deviceLimit ?? _state.maxDevices ?? entitlements.maxDevices;
  bool get isSyncing => _isSyncing;
  String? get syncError => _syncError;

  /// Loads cached state and, if activated and online, refreshes the token.
  Future<void> load() async {
    _state = await _repository.load();
    _hasLoaded = true;
    notifyListeners();
    if (_state.isActivated && _state.code != null) {
      await _revalidate();
    }
  }

  Future<void> _revalidate() async {
    final outcome = await refresh();
    if (!outcome.success) {
      // Offline or transient — stay on cached state; grace window governs.
      LogService.instance.debug(
        'license revalidate skipped: ${outcome.message}',
        'license',
      );
    }
  }

  /// Activates a code against the license server and binds this device.
  Future<LicenseActivationOutcome> activate(String code) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) {
      return const LicenseActivationOutcome(success: false, message: '请输入激活码');
    }
    try {
      final fp = await _fingerprint.compute();
      final platform = _platformName();
      final result = await _client.activate(
        code: trimmed,
        fingerprint: fp,
        deviceName: Platform.localHostname,
        platform: platform,
      );
      await _applyResult(result, code: trimmed, fingerprint: fp);
      unawaited(refreshDevices());
      return LicenseActivationOutcome(
        success: true,
        message: '激活成功：${result.tier.name.toUpperCase()}',
      );
    } on LicenseClientException catch (e) {
      LogService.instance.warn('license activate failed: $e', 'license');
      return LicenseActivationOutcome(success: false, message: '激活失败：$e');
    } catch (e) {
      LogService.instance.warn('license activate error: $e', 'license');
      return LicenseActivationOutcome(success: false, message: '激活失败：$e');
    }
  }

  /// 重新校验授权，并刷新已激活设备快照。
  Future<LicenseOperationOutcome> refresh() async {
    final code = _state.code;
    if (!_state.isActivated || code == null) {
      return const LicenseOperationOutcome(
        success: false,
        message: 'license is not activated',
      );
    }
    _startSync();
    try {
      final fp = _state.fingerprint ?? await _fingerprint.compute();
      final result = await _client.validate(code: code, fingerprint: fp);
      await _applyResult(result, code: code, fingerprint: fp);
      await _loadDevices(code: code, fingerprint: fp);
      return const LicenseOperationOutcome(success: true);
    } catch (e) {
      _syncError = '$e';
      return LicenseOperationOutcome(success: false, message: '$e');
    } finally {
      _finishSync();
    }
  }

  /// 仅刷新设备列表，不修改缓存的授权状态。
  Future<LicenseOperationOutcome> refreshDevices() async {
    final code = _state.code;
    if (!_state.isActivated || code == null) {
      return const LicenseOperationOutcome(
        success: false,
        message: 'license is not activated',
      );
    }
    _startSync();
    try {
      final fp = _state.fingerprint ?? await _fingerprint.compute();
      await _loadDevices(code: code, fingerprint: fp);
      return const LicenseOperationOutcome(success: true);
    } catch (e) {
      _syncError = '$e';
      return LicenseOperationOutcome(success: false, message: '$e');
    } finally {
      _finishSync();
    }
  }

  /// 释放指定设备席位；请求失败时不清除缓存状态。
  Future<LicenseOperationOutcome> releaseDevice(LicenseDevice device) async {
    final code = _state.code;
    if (code == null) {
      return const LicenseOperationOutcome(
        success: false,
        message: 'license is not activated',
      );
    }
    _startSync();
    try {
      await _client.deactivateDevice(code: code, deviceId: device.id);
      if (device.isCurrent) {
        await _clearLocalState();
      } else {
        _devices = _devices
            .where((candidate) => candidate.id != device.id)
            .toList(growable: false);
        notifyListeners();
      }
      return const LicenseOperationOutcome(success: true);
    } catch (e) {
      LogService.instance.warn('license device release error: $e', 'license');
      _syncError = '$e';
      return LicenseOperationOutcome(success: false, message: '$e');
    } finally {
      _finishSync();
    }
  }

  /// 释放本设备席位，并恢复为免费版。
  Future<LicenseOperationOutcome> deactivate() async {
    final code = _state.code;
    if (code == null) {
      return const LicenseOperationOutcome(success: true);
    }
    _startSync();
    try {
      final fp = _state.fingerprint ?? await _fingerprint.compute();
      await _client.deactivate(code: code, fingerprint: fp);
      await _clearLocalState();
      return const LicenseOperationOutcome(success: true);
    } catch (e) {
      LogService.instance.warn('license deactivate error: $e', 'license');
      _syncError = '$e';
      return LicenseOperationOutcome(success: false, message: '$e');
    } finally {
      _finishSync();
    }
  }

  Future<void> _applyResult(
    LicenseActivationResult result, {
    required String code,
    required String fingerprint,
  }) async {
    final now = DateTime.now();
    final graceDays = result.tier == LicenseTier.team ? 7 : 14;
    _state = _state.copyWith(
      tier: result.tier,
      code: code,
      status: 'active',
      fingerprint: fingerprint,
      entitlementToken: result.token,
      activatedAt: _state.activatedAt ?? now,
      lastValidatedAt: now,
      expiresAt: result.expiresAt,
      graceUntil: now.add(Duration(days: graceDays)),
      maxDevices: result.maxDevices,
    );
    await _repository.save(_state);
    notifyListeners();
  }

  Future<void> _loadDevices({
    required String code,
    required String fingerprint,
  }) async {
    final result = await _client.listDevices(
      code: code,
      currentFingerprint: fingerprint,
    );
    _devices = result.devices;
    _deviceLimit = result.maxDevices;
    _syncError = null;
    notifyListeners();
  }

  Future<void> _clearLocalState() async {
    _state = LicenseState.free;
    _devices = const [];
    _deviceLimit = null;
    _syncError = null;
    await _repository.save(_state);
    notifyListeners();
  }

  void _startSync() {
    _isSyncing = true;
    _syncError = null;
    notifyListeners();
  }

  void _finishSync() {
    _isSyncing = false;
    notifyListeners();
  }

  String _platformName() {
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    return 'desktop';
  }
}

class LicenseActivationOutcome {
  const LicenseActivationOutcome({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

class LicenseOperationOutcome {
  const LicenseOperationOutcome({required this.success, this.message});

  final bool success;
  final String? message;
}
