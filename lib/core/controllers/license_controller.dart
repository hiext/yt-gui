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
  })  : _repository = repository ?? LicenseRepository(),
        _client = client ?? LicenseClient(),
        _fingerprint = fingerprint ?? const DeviceFingerprint();

  final LicenseRepository _repository;
  final LicenseClient _client;
  final DeviceFingerprint _fingerprint;

  LicenseState _state = LicenseState.free;
  bool _hasLoaded = false;

  LicenseState get state => _state;
  LicenseTier get tier => _state.effectiveTier;
  Entitlements get entitlements => _state.entitlements;
  bool get hasLoaded => _hasLoaded;

  /// Loads cached state and, if activated and online, refreshes the token.
  Future<void> load() async {
    _state = await _repository.load();
    _hasLoaded = true;
    notifyListeners();
    if (_state.isActivated && _state.code != null) {
      unawaited(_revalidate());
    }
  }

  Future<void> _revalidate() async {
    try {
      final fp = await _fingerprint.compute();
      final result = await _client.validate(code: _state.code!, fingerprint: fp);
      _applyResult(result, code: _state.code!, fingerprint: fp);
    } catch (e) {
      // Offline or transient — stay on cached state; grace window governs.
      LogService.instance.debug('license revalidate skipped: $e', 'license');
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
        deviceName: null,
        platform: platform,
      );
      await _applyResult(result, code: trimmed, fingerprint: fp);
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

  /// Releases the current device seat and reverts to Free.
  Future<void> deactivate() async {
    if (_state.code != null) {
      try {
        final fp = _state.fingerprint ?? await _fingerprint.compute();
        await _client.deactivate(code: _state.code!, fingerprint: fp);
      } catch (e) {
        LogService.instance.warn('license deactivate error: $e', 'license');
      }
    }
    _state = LicenseState.free;
    await _repository.save(_state);
    notifyListeners();
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
    );
    await _repository.save(_state);
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
  const LicenseActivationOutcome({required this.success, required this.message});

  final bool success;
  final String message;
}
