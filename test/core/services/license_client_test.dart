import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/license_models.dart';
import 'package:hiext_yt_gui/core/services/license_client.dart';

void main() {
  late HttpServer server;
  final requests = <({String path, String body})>[];

  setUp(() async {
    requests.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      requests.add((path: request.uri.path, body: body));
      final path = request.uri.path;
      request.response.headers.contentType = ContentType.json;
      if (body.contains('FORBIDDEN')) {
        request.response.statusCode = HttpStatus.forbidden;
        request.response.write(jsonEncode({'error': 'license not active'}));
      } else if (path == '/activate') {
        request.response.write(jsonEncode({
          'success': true,
          'tier': 'pro',
          'token': 'signed.token.here',
          'maxDevices': 3,
        }));
      } else if (path == '/validate') {
        request.response.write(jsonEncode({
          'success': true,
          'tier': 'pro',
          'token': 'refreshed.token',
        }));
      } else if (path == '/deactivate') {
        request.response.write(jsonEncode({'success': true}));
      } else {
        request.response.statusCode = HttpStatus.forbidden;
        request.response.write(jsonEncode({'error': 'license not active'}));
      }
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  String baseUrl() => 'http://${server.address.address}:${server.port}';

  test('activate sends code + fingerprint and parses tier/token', () async {
    final client = LicenseClient(baseUrl: baseUrl());
    final result = await client.activate(
      code: 'HIEXT-ABCDE-12345-FGHIJ-67890',
      fingerprint: 'fp-1',
      platform: 'linux',
    );

    expect(result.tier, LicenseTier.pro);
    expect(result.token, 'signed.token.here');
    expect(result.maxDevices, 3);

    final sent = jsonDecode(requests.single.body) as Map<String, Object?>;
    expect(sent['code'], 'HIEXT-ABCDE-12345-FGHIJ-67890');
    expect(sent['fingerprint'], 'fp-1');
    expect(sent['platform'], 'linux');
  });

  test('validate refreshes token', () async {
    final client = LicenseClient(baseUrl: baseUrl());
    final result = await client.validate(code: 'HIEXT-X', fingerprint: 'fp-1');
    expect(result.token, 'refreshed.token');
    expect(requests.single.path, '/validate');
  });

  test('deactivate posts to /deactivate', () async {
    final client = LicenseClient(baseUrl: baseUrl());
    await client.deactivate(code: 'HIEXT-X', fingerprint: 'fp-1');
    expect(requests.single.path, '/deactivate');
  });

  test('non-2xx throws LicenseClientException with server error', () async {
    final client = LicenseClient(baseUrl: baseUrl());
    await expectLater(
      client.activate(code: 'HIEXT-FORBIDDEN', fingerprint: 'y'),
      throwsA(isA<LicenseClientException>().having(
        (e) => e.message,
        'message',
        contains('HTTP 403'),
      )),
    );
  });

  group('Entitlements', () {
    test('free tier limits', () {
      final e = Entitlements.forTier(LicenseTier.free);
      expect(e.maxConcurrentDownloads, 1);
      expect(e.maxClipsPerVideo, 3);
      expect(e.cloudSyncEnabled, isFalse);
    });

    test('pro tier unlocks concurrency and clips', () {
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
