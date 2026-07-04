import 'dart:convert';
import 'dart:io';

import '../models/app_models.dart';

class CloudHealthResult {
  const CloudHealthResult({required this.ok, this.version});

  final bool ok;
  final String? version;
}

class CloudPairResult {
  const CloudPairResult({required this.deviceId, required this.accessToken});

  final String deviceId;
  final String accessToken;
}

class CloudMediaUploadResult {
  const CloudMediaUploadResult({required this.cloudMediaId});

  final String cloudMediaId;
}

class CloudClipJobResult {
  const CloudClipJobResult({required this.cloudJobId});

  final String cloudJobId;
}

class CloudClipJobStatus {
  const CloudClipJobStatus({required this.status, required this.progress});

  final CloudSyncStatus status;
  final double progress;
}

class CloudUploadInitResult {
  const CloudUploadInitResult({
    required this.uploadId,
    required this.chunkSize,
    required this.uploadedChunks,
  });

  final String uploadId;
  final int chunkSize;
  final List<int> uploadedChunks;
}

class CloudChunkUploadResult {
  const CloudChunkUploadResult({
    required this.uploadId,
    required this.chunkIndex,
    required this.receivedBytes,
  });

  final String uploadId;
  final int chunkIndex;
  final int receivedBytes;
}

class CloudUploadCompleteResult {
  const CloudUploadCompleteResult({
    required this.cloudMediaId,
    required this.objectPath,
    required this.totalBytes,
  });

  final String cloudMediaId;
  final String objectPath;
  final int totalBytes;
}

class CloudUploadStatusResult {
  const CloudUploadStatusResult({
    required this.uploadId,
    required this.status,
    required this.uploadedChunks,
  });

  final String uploadId;
  final CloudSyncStatus status;
  final List<int> uploadedChunks;
}

class CloudClipClient {
  CloudClipClient({
    required String baseUrl,
    this.accessToken,
    HttpClient Function()? httpClientFactory,
  }) : baseUrl = baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
       _httpClientFactory = httpClientFactory ?? HttpClient.new;

  final String baseUrl;
  final String? accessToken;
  final HttpClient Function() _httpClientFactory;

  Future<CloudHealthResult> health() async {
    final json = await _request('GET', '/api/health');
    return CloudHealthResult(
      ok: json['ok'] == true,
      version: json['version'] as String?,
    );
  }

  Future<CloudPairResult> pairDevice({
    required String deviceName,
    required String pairingToken,
  }) async {
    final json = await _request(
      'POST',
      '/api/devices/pair',
      body: {'deviceName': deviceName, 'pairingToken': pairingToken},
      authenticated: false,
    );
    return CloudPairResult(
      deviceId: json['deviceId'] as String? ?? '',
      accessToken: json['accessToken'] as String? ?? '',
    );
  }

  Future<CloudMediaUploadResult> uploadAnalysisPackage({
    required MediaAsset asset,
    List<ClipCandidate> candidates = const [],
    List<ClipExportRecord> exports = const [],
    List<MediaVectorRecord> vectors = const [],
    required CloudUploadPolicy uploadPolicy,
  }) async {
    final json = await _request(
      'POST',
      '/api/media/analysis-package',
      body: {
        'schemaVersion': 1,
        'uploadPolicy': uploadPolicy.name,
        'mediaAsset': asset.toJson(),
        'clipCandidates': candidates
            .map((candidate) => candidate.toJson())
            .toList(),
        'clipExports': exports.map((record) => record.toJson()).toList(),
        'vectors': {
          'count': vectors.length,
          'records': vectors.map((record) => record.toJson()).toList(),
        },
      },
    );
    return CloudMediaUploadResult(
      cloudMediaId: json['cloudMediaId'] as String? ?? '',
    );
  }

  Future<CloudClipJobResult> createClipJob({
    required String cloudMediaId,
    List<String> candidateIds = const [],
    bool uploadOriginal = false,
  }) async {
    final json = await _request(
      'POST',
      '/api/clip-jobs',
      body: {
        'cloudMediaId': cloudMediaId,
        'candidateIds': candidateIds,
        'uploadOriginal': uploadOriginal,
      },
    );
    return CloudClipJobResult(cloudJobId: json['cloudJobId'] as String? ?? '');
  }

  Future<CloudClipJobStatus> fetchClipJobStatus(String cloudJobId) async {
    final json = await _request('GET', '/api/clip-jobs/$cloudJobId');
    return CloudClipJobStatus(
      status: _syncStatus(json['status']),
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<CloudClipJobStatus> runClipJob(String cloudJobId) async {
    final json = await _request('POST', '/api/clip-jobs/$cloudJobId/run');
    return CloudClipJobStatus(
      status: _syncStatus(json['status']),
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<CloudUploadInitResult> initOriginalUpload({
    required String cloudMediaId,
    required String fileName,
    required int totalBytes,
    required String sha256,
    required int chunkSize,
  }) async {
    final json = await _request(
      'POST',
      '/api/media/$cloudMediaId/uploads/init',
      body: {
        'fileName': fileName,
        'totalBytes': totalBytes,
        'sha256': sha256,
        'chunkSize': chunkSize,
      },
    );
    return CloudUploadInitResult(
      uploadId: json['uploadId'] as String? ?? '',
      chunkSize: (json['chunkSize'] as num?)?.toInt() ?? chunkSize,
      uploadedChunks:
          (json['uploadedChunks'] as List?)
              ?.whereType<num>()
              .map((value) => value.toInt())
              .toList() ??
          const [],
    );
  }

  Future<CloudChunkUploadResult> uploadChunk({
    required String cloudMediaId,
    required String uploadId,
    required int chunkIndex,
    required List<int> bytes,
  }) async {
    final json = await _request(
      'PUT',
      '/api/media/$cloudMediaId/uploads/$uploadId/chunks/$chunkIndex',
      rawBody: bytes,
      contentType: ContentType.binary,
    );
    return CloudChunkUploadResult(
      uploadId: json['uploadId'] as String? ?? uploadId,
      chunkIndex: (json['chunkIndex'] as num?)?.toInt() ?? chunkIndex,
      receivedBytes: (json['receivedBytes'] as num?)?.toInt() ?? bytes.length,
    );
  }

  Future<CloudUploadCompleteResult> completeOriginalUpload({
    required String cloudMediaId,
    required String uploadId,
    required String sha256,
  }) async {
    final json = await _request(
      'POST',
      '/api/media/$cloudMediaId/uploads/$uploadId/complete',
      body: {'sha256': sha256},
    );
    return CloudUploadCompleteResult(
      cloudMediaId: json['cloudMediaId'] as String? ?? cloudMediaId,
      objectPath: json['objectPath'] as String? ?? '',
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
    );
  }

  Future<CloudUploadStatusResult> fetchOriginalUploadStatus({
    required String cloudMediaId,
    required String uploadId,
  }) async {
    final json = await _request(
      'GET',
      '/api/media/$cloudMediaId/uploads/$uploadId',
    );
    return CloudUploadStatusResult(
      uploadId: json['uploadId'] as String? ?? uploadId,
      status: _syncStatus(json['status']),
      uploadedChunks:
          (json['uploadedChunks'] as List?)
              ?.whereType<num>()
              .map((value) => value.toInt())
              .toList() ??
          const [],
    );
  }

  Future<CloudUploadStatusResult> cancelOriginalUpload({
    required String cloudMediaId,
    required String uploadId,
  }) async {
    final json = await _request(
      'DELETE',
      '/api/media/$cloudMediaId/uploads/$uploadId',
    );
    return CloudUploadStatusResult(
      uploadId: json['uploadId'] as String? ?? uploadId,
      status: _syncStatus(json['status']),
      uploadedChunks:
          (json['uploadedChunks'] as List?)
              ?.whereType<num>()
              .map((value) => value.toInt())
              .toList() ??
          const [],
    );
  }

  Future<Map<String, Object?>> fetchResultManifest(String cloudJobId) {
    return _request('GET', '/api/clip-jobs/$cloudJobId/result-manifest');
  }

  Future<Map<String, Object?>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
    List<int>? rawBody,
    ContentType? contentType,
    bool authenticated = true,
  }) async {
    final client = _httpClientFactory();
    try {
      final request = await client.openUrl(method, Uri.parse('$baseUrl$path'));
      request.headers.contentType = contentType ?? ContentType.json;
      if (authenticated &&
          accessToken != null &&
          accessToken!.trim().isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${accessToken!.trim()}',
        );
      }
      if (rawBody != null) {
        request.add(rawBody);
      } else if (body != null) {
        request.write(jsonEncode(body));
      }
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      final decoded = _tryDecodeJsonObject(responseBody);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded?['error'] ?? _bodySummary(responseBody);
        throw CloudClipClientException('HTTP ${response.statusCode}: $error');
      }
      if (decoded != null) return decoded;
      throw const CloudClipClientException(
        'Cloud response must be a JSON object',
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

  CloudSyncStatus _syncStatus(Object? value) {
    if (value is String) {
      return CloudSyncStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => CloudSyncStatus.pending,
      );
    }
    return CloudSyncStatus.pending;
  }
}

class CloudClipClientException implements Exception {
  const CloudClipClientException(this.message);

  final String message;

  @override
  String toString() => message;
}
