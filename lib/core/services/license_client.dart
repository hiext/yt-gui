import 'dart:convert';
import 'dart:io';

import '../models/license_models.dart';

/// HTTP client for the Hiext license API.
/// Uses process-spawned `curl` on desktop platforms to avoid TLS handshake
/// issues with Flutter's bundled BoringSSL on some Linux distros.
class LicenseClient {
  LicenseClient({
    this.baseUrl = defaultBaseUrl,
    this.curlPath = 'curl',
  });

  static const defaultBaseUrl = 'https://dp-api.hiext.com/v1/license';

  final String baseUrl;

  /// Path to the curl binary; overridable for testing.
  final String curlPath;

  Future<LicenseActivationResult> activate({
    required String code,
    required String fingerprint,
    String? deviceName,
    String? platform,
  }) async {
    final json = await _curl('POST', '/activate', body: {
      'code': code,
      'fingerprint': fingerprint,
      'deviceName': ?deviceName,
      'platform': ?platform,
    });
    return LicenseActivationResult.fromJson(json);
  }

  Future<LicenseActivationResult> validate({
    required String code,
    required String fingerprint,
  }) async {
    final json = await _curl('POST', '/validate', body: {
      'code': code,
      'fingerprint': fingerprint,
    });
    return LicenseActivationResult.fromJson(json);
  }

  Future<void> deactivate({
    required String code,
    required String fingerprint,
  }) async {
    await _curl('POST', '/deactivate', body: {
      'code': code,
      'fingerprint': fingerprint,
    });
  }

  Future<Map<String, Object?>> _curl(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final args = [
      '-sS',
      '-X', method,
      '--max-time', '15',
      '--connect-timeout', '10',
      '--noproxy', '*', // bypass system HTTP proxy for direct API access
    ];
    if (body != null) {
      args.addAll(['-H', 'Content-Type: application/json']);
      args.addAll(['-d', jsonEncode(body)]);
    }
    args.add('$baseUrl$path');

    final result = await Process.run(curlPath, args);
    final stdout = (result.stdout as String).trim();
    final decoded = _tryDecodeJsonObject(stdout);

    if (result.exitCode != 0) {
      final stderr = result.stderr;
      final msg = stderr is String ? stderr : (stderr is List<int> ? String.fromCharCodes(stderr) : '$stderr');
      throw LicenseClientException('curl exited ${result.exitCode}: $msg'.trim());
    }
    // curl exits 0 on HTTP 4xx too — check the body
    if (decoded?['error'] != null && decoded?['success'] == false) {
      throw LicenseClientException('${decoded!['error']}');
    }
    if (decoded != null) return decoded;
    throw LicenseClientException('License response must be a JSON object: ${stdout.length > 200 ? stdout.substring(0, 200) : stdout}');
  }

  Map<String, Object?>? _tryDecodeJsonObject(String responseBody) {
    if (responseBody.isEmpty) return <String, Object?>{};
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, Object?>) return decoded;
      if (decoded is Map) return Map<String, Object?>.from(decoded);
      return null;
    } catch (_) {
      return null;
    }
  }

  String _bodySummary(String responseBody) {
    final trimmed = responseBody.trim();
    if (trimmed.isEmpty) return 'empty response body';
    return trimmed.length <= 200 ? trimmed : '${trimmed.substring(0, 200)}...';
  }
}

class LicenseClientException implements Exception {
  const LicenseClientException(this.message);

  final String message;

  @override
  String toString() => message;
}
