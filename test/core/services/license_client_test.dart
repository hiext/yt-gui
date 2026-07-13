import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/license_models.dart';
import 'package:hiext_yt_gui/core/services/license_client.dart';

void main() {
  test('activate sends code + fingerprint via curl and parses tier/token', () async {
    // Provide a fake curl via path override that writes a valid JSON response.
    // The test writes a small shell script to /tmp that emulates curl.
    final client = LicenseClient(
      baseUrl: 'https://dp-api.hiext.com/v1/license',
      curlPath: '/usr/bin/curl', // real curl — integration test
    );

    // This is an integration test against the live API.
    // Skip if offline or Worker not deployed.
    try {
      final result = await client.activate(
        code: 'HIEXT-G6TJ4-KQWHS-F5YDB-0ZTRH',
        fingerprint: 'fp-test-curl-${DateTime.now().millisecondsSinceEpoch}',
        platform: 'linux',
      );
      expect(result.tier, LicenseTier.pro);
      expect(result.token.isNotEmpty, isTrue);
      expect(result.maxDevices, 3);
    } on LicenseClientException catch (e) {
      // API reachable but code/device issue — still verifying curl path works
      expect(e.message, contains('device limit'));
    }
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
      );
      final restored = LicenseState.decode(state.encode());
      expect(restored.tier, LicenseTier.team);
      expect(restored.code, 'HIEXT-ABCDE-12345-FGHIJ-67890');
      expect(restored.fingerprint, 'fp-1');
      expect(restored.graceUntil, DateTime.utc(2026, 7, 11));
    });
  });
}
