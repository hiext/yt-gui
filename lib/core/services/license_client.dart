import 'dart:convert';
import 'dart:io';

import '../models/license_models.dart';

/// HTTP client for the Hiext license API. Mirrors the dart:io HttpClient
/// pattern used by CloudClipClient — no third-party HTTP dependency.
class LicenseClient {
  LicenseClient({
    this.baseUrl = defaultBaseUrl,
    HttpClient Function()? httpClientFactory,
  }) : _httpClientFactory = httpClientFactory ?? HttpClient.new;

  static const defaultBaseUrl = 'https://dp-api.hiext.com/v1/license';

  final String baseUrl;
  final HttpClient Function() _httpClientFactory;

  Future<LicenseActivationResult> activate({
    required String code,
    required String fingerprint,
    String? deviceName,
    String? platform,
  }) async {
    final json = await _request('POST', '/activate', body: {
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
    final json = await _request('POST', '/validate', body: {
      'code': code,
      'fingerprint': fingerprint,
    });
    return LicenseActivationResult.fromJson(json);
  }

  Future<void> deactivate({
    required String code,
    required String fingerprint,
  }) async {
    await _request('POST', '/deactivate', body: {
      'code': code,
      'fingerprint': fingerprint,
    });
  }

  Future<Map<String, Object?>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final client = _httpClientFactory();
    try {
      final request = await client.openUrl(method, Uri.parse('$baseUrl$path'));
      request.headers.contentType = ContentType.json;
      if (body != null) {
        request.write(jsonEncode(body));
      }
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      final decoded = _tryDecodeJsonObject(responseBody);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded?['error'] ?? _bodySummary(responseBody);
        throw LicenseClientException('HTTP ${response.statusCode}: $error');
      }
      if (decoded != null) return decoded;
      throw const LicenseClientException(
        'License response must be a JSON object',
      );
    } finally {
      client.close(force: true);
    }
  }

  Map<String, Object?>? _tryDecodeJsonObject(String responseBody) {
    if (responseBody.trim().isEmpty) return <String, Object?>{};
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
