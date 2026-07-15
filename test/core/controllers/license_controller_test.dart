import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/controllers/license_controller.dart';
import 'package:hiext_yt_gui/core/models/license_models.dart';
import 'package:hiext_yt_gui/core/services/device_fingerprint.dart';
import 'package:hiext_yt_gui/core/services/license_client.dart';
import 'package:hiext_yt_gui/core/services/license_repository.dart';

void main() {
  LicenseState activeState() => LicenseState(
    tier: LicenseTier.pro,
    code: 'HIEXT-TEST',
    fingerprint: 'fp-current',
    entitlementToken: 'cached-token',
    graceUntil: DateTime.now().add(const Duration(days: 5)),
  );

  const currentDevice = LicenseDevice(
    id: 'device-current',
    deviceName: 'Current PC',
    platform: 'linux',
    isCurrent: true,
  );
  const oldDevice = LicenseDevice(
    id: 'device-old',
    deviceName: 'Old laptop',
    platform: 'windows',
  );

  test('load refreshes entitlement and active device snapshot', () async {
    final repository = _FakeLicenseRepository(activeState());
    final client = _FakeLicenseClient(
      devices: const [currentDevice, oldDevice],
    );
    final controller = LicenseController(
      repository: repository,
      client: client,
      fingerprint: const _FakeFingerprint(),
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.devices, const [currentDevice, oldDevice]);
    expect(controller.activeDeviceCount, 2);
    expect(controller.maxDevices, 3);
    expect(controller.state.lastValidatedAt, isNotNull);
    expect(controller.syncError, isNull);
  });

  test('releasing another device keeps local license active', () async {
    final repository = _FakeLicenseRepository(activeState());
    final client = _FakeLicenseClient(
      devices: const [currentDevice, oldDevice],
    );
    final controller = LicenseController(
      repository: repository,
      client: client,
      fingerprint: const _FakeFingerprint(),
    );
    addTearDown(controller.dispose);
    await controller.load();

    final outcome = await controller.releaseDevice(oldDevice);

    expect(outcome.success, isTrue);
    expect(client.releasedDeviceId, oldDevice.id);
    expect(controller.state.isActivated, isTrue);
    expect(controller.devices, const [currentDevice]);
  });

  test(
    'releasing current device clears local license only after success',
    () async {
      final repository = _FakeLicenseRepository(activeState());
      final client = _FakeLicenseClient(devices: const [currentDevice]);
      final controller = LicenseController(
        repository: repository,
        client: client,
        fingerprint: const _FakeFingerprint(),
      );
      addTearDown(controller.dispose);
      await controller.load();

      final outcome = await controller.releaseDevice(currentDevice);

      expect(outcome.success, isTrue);
      expect(controller.state, same(LicenseState.free));
      expect(repository.saved, same(LicenseState.free));
      expect(controller.devices, isEmpty);
    },
  );

  test('failed current-device release preserves cached license', () async {
    final repository = _FakeLicenseRepository(activeState());
    final client = _FakeLicenseClient(
      devices: const [currentDevice],
      failLegacyDeactivate: true,
    );
    final controller = LicenseController(
      repository: repository,
      client: client,
      fingerprint: const _FakeFingerprint(),
    );
    addTearDown(controller.dispose);
    await controller.load();

    final outcome = await controller.deactivate();

    expect(outcome.success, isFalse);
    expect(controller.state.isActivated, isTrue);
    expect(repository.saved.isActivated, isTrue);
    expect(controller.syncError, contains('network unavailable'));
  });
}

class _FakeLicenseRepository extends LicenseRepository {
  _FakeLicenseRepository(this.saved);

  LicenseState saved;

  @override
  Future<LicenseState> load() async => saved;

  @override
  Future<void> save(LicenseState state) async => saved = state;
}

class _FakeLicenseClient extends LicenseClient {
  _FakeLicenseClient({
    required this.devices,
    this.failLegacyDeactivate = false,
  });

  final List<LicenseDevice> devices;
  final bool failLegacyDeactivate;
  String? releasedDeviceId;

  @override
  Future<LicenseActivationResult> validate({
    required String code,
    required String fingerprint,
  }) async {
    return const LicenseActivationResult(
      tier: LicenseTier.pro,
      token: 'fresh-token',
      maxDevices: 3,
    );
  }

  @override
  Future<LicenseDevicesResult> listDevices({
    required String code,
    required String currentFingerprint,
  }) async {
    return LicenseDevicesResult(
      maxDevices: 3,
      activeDevices: devices.length,
      devices: devices,
    );
  }

  @override
  Future<void> deactivate({
    required String code,
    required String fingerprint,
  }) async {
    if (failLegacyDeactivate) {
      throw const LicenseClientException('network unavailable');
    }
  }

  @override
  Future<void> deactivateDevice({
    required String code,
    required String deviceId,
  }) async {
    releasedDeviceId = deviceId;
  }
}

class _FakeFingerprint extends DeviceFingerprint {
  const _FakeFingerprint();

  @override
  Future<String> compute() async => 'fp-current';
}
