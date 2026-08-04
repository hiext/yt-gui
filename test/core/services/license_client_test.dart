import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/license_models.dart';
import 'package:hiext_yt_gui/core/services/license_client.dart';

void main() {
  test('activate sends code + fingerprint and parses tier/token', () async {
    late List<String> arguments;
    final client = LicenseClient(
      baseUrl: 'https://dp-api.hiext.com/v1/license',
      processRunner: (executable, args) async {
        arguments = args;
        return ProcessResult(
          1,
          0,
          jsonEncode({
            'success': true,
            'tier': 'pro',
            'token': 'signed-token',
            'maxDevices': 3,
          }),
          '',
        );
      },
    );

    final result = await client.activate(
      code: 'HIEXT-TEST',
      fingerprint: 'fp-test',
      platform: 'linux',
    );

    expect(result.tier, LicenseTier.pro);
    expect(result.token, 'signed-token');
    expect(result.maxDevices, 3);
    expect(arguments.last, endsWith('/activate'));
    final body = jsonDecode(arguments[arguments.indexOf('-d') + 1]);
    expect(body['code'], 'HIEXT-TEST');
    expect(body['fingerprint'], 'fp-test');
  });

  test('lists active devices and releases the selected device id', () async {
    final requests = <List<String>>[];
    final client = LicenseClient(
      processRunner: (executable, args) async {
        requests.add(args);
        final isList = args.last.endsWith('/devices/list');
        return ProcessResult(
          requests.length,
          0,
          jsonEncode(
            isList
                ? {
                    'success': true,
                    'maxDevices': 3,
                    'activeDevices': 1,
                    'devices': [
                      {
                        'id': 'device-1',
                        'deviceName': 'Desktop',
                        'platform': 'linux',
                        'lastSeenAt': '2026-07-15T10:00:00Z',
                        'isCurrent': true,
                      },
                    ],
                  }
                : {'success': true, 'deactivatedDeviceId': 'device-1'},
          ),
          '',
        );
      },
    );

    final result = await client.listDevices(
      code: 'HIEXT-TEST',
      currentFingerprint: 'fp-test',
    );
    await client.deactivateDevice(code: 'HIEXT-TEST', deviceId: 'device-1');

    expect(result.activeDevices, 1);
    expect(result.devices.single.deviceName, 'Desktop');
    expect(result.devices.single.isCurrent, isTrue);
    expect(requests[0].last, endsWith('/devices/list'));
    expect(requests[1].last, endsWith('/devices/deactivate'));
    final releaseBody = jsonDecode(requests[1][requests[1].indexOf('-d') + 1]);
    expect(releaseBody['deviceId'], 'device-1');
  });

  test('curl exits non-zero throws LicenseClientException', () async {
    final client = LicenseClient(
      baseUrl: 'https://dp-api.hiext.com/v1/license',
      curlPath: '/bin/false', // always exits 1
    );
    await expectLater(
      client.activate(code: 'x', fingerprint: 'y'),
      throwsA(isA<LicenseClientException>()),
    );
  });

  group('Entitlements', () {
    test('free tier limits', () {
      final e = Entitlements.forTier(LicenseTier.free);
      expect(e.maxConcurrentDownloads, 1);
      expect(e.maxClipsPerVideo, 3);
      expect(e.cloudSyncEnabled, isFalse);
    });

    test('pro tier unlocks', () {
      final e = Entitlements.forTier(LicenseTier.pro);
      expect(e.maxConcurrentDownloads, 8);
      expect(e.maxClipsPerVideo, greaterThan(1000));
      expect(e.cloudSyncEnabled, isFalse);
    });

    test('team tier unlocks cloud sync', () {
      final e = Entitlements.forTier(LicenseTier.team);
      expect(e.cloudSyncEnabled, isTrue);
      expect(e.maxDevices, 10);
    });
  });

  group('LicenseState grace/expiry', () {
    test('effectiveTier falls back to free after grace elapsed', () {
      final expired = LicenseState(
        tier: LicenseTier.pro,
        code: 'HIEXT-X',
        graceUntil: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(expired.effectiveTier, LicenseTier.free);
    });

    test('effectiveTier honors pro within grace', () {
      final valid = LicenseState(
        tier: LicenseTier.pro,
        code: 'HIEXT-X',
        graceUntil: DateTime.now().add(const Duration(days: 10)),
      );
      expect(valid.effectiveTier, LicenseTier.pro);
    });

    test('team subscription past expiresAt reverts to free', () {
      final expired = LicenseState(
        tier: LicenseTier.team,
        code: 'HIEXT-X',
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        graceUntil: DateTime.now().add(const Duration(days: 5)),
      );
      expect(expired.effectiveTier, LicenseTier.free);
    });

    test('round-trips through encode/decode', () {
      final state = LicenseState(
        tier: LicenseTier.team,
        code: 'HIEXT-ABCDE-12345-FGHIJ-67890',
        status: 'active',
        fingerprint: 'fp-1',
        entitlementToken: 'tok',
        activatedAt: DateTime.utc(2026, 7, 4),
        graceUntil: DateTime.utc(2026, 7, 11),
        maxDevices: 12,
      );
      final restored = LicenseState.decode(state.encode());
      expect(restored.tier, LicenseTier.team);
      expect(restored.code, 'HIEXT-ABCDE-12345-FGHIJ-67890');
      expect(restored.fingerprint, 'fp-1');
      expect(restored.graceUntil, DateTime.utc(2026, 7, 11));
      expect(restored.maxDevices, 12);
    });
  });
}
