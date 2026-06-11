import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/cloud_clip_client.dart';

void main() {
  late HttpServer server;
  late List<_RequestLog> requests;

  setUp(() async {
    requests = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(
      server.forEach((request) async {
        final body = await utf8.decoder.bind(request).join();
        requests.add(_RequestLog(request.method, request.uri.path, body));
        request.response.headers.contentType = ContentType.json;
        switch ('${request.method} ${request.uri.path}') {
          case 'GET /api/health':
            request.response.write(jsonEncode({'ok': true, 'version': 'test'}));
          case 'POST /api/devices/pair':
            request.response.write(
              jsonEncode({'deviceId': 'dev-1', 'accessToken': 'token-1'}),
            );
          case 'POST /api/media/analysis-package':
            expect(
              request.headers.value(HttpHeaders.authorizationHeader),
              'Bearer token-1',
            );
            request.response.write(jsonEncode({'cloudMediaId': 'media-1'}));
          case 'POST /api/clip-jobs':
            request.response.write(jsonEncode({'cloudJobId': 'job-1'}));
          case 'GET /api/clip-jobs/job-1':
            request.response.write(
              jsonEncode({'status': 'completed', 'progress': 1.0}),
            );
          case 'POST /api/media/media-1/uploads/init':
            request.response.write(
              jsonEncode({
                'uploadId': 'upload-1',
                'chunkSize': 4,
                'uploadedChunks': <int>[],
              }),
            );
          case 'PUT /api/media/media-1/uploads/upload-1/chunks/0':
            request.response.write(
              jsonEncode({
                'uploadId': 'upload-1',
                'chunkIndex': 0,
                'receivedBytes': body.length,
              }),
            );
          case 'POST /api/media/media-1/uploads/upload-1/complete':
            request.response.write(
              jsonEncode({
                'cloudMediaId': 'media-1',
                'objectPath': 'objects/media-1/original.bin',
                'totalBytes': 4,
              }),
            );
          case 'GET /api/media/media-1/uploads/upload-1':
            request.response.write(
              jsonEncode({
                'uploadId': 'upload-1',
                'status': 'uploading',
                'uploadedChunks': [0],
              }),
            );
          case 'DELETE /api/media/media-1/uploads/upload-1':
            request.response.write(
              jsonEncode({
                'uploadId': 'upload-1',
                'status': 'cancelled',
                'uploadedChunks': [0],
              }),
            );
          case 'GET /api/clip-jobs/job-1/result-manifest':
            request.response.write(
              jsonEncode({
                'cloudJobId': 'job-1',
                'status': 'completed',
                'clips': [
                  {'id': 'clip-1', 'downloadPath': '/api/files/clip-1.mp4'},
                ],
              }),
            );
          default:
            request.response.statusCode = HttpStatus.notFound;
            request.response.write(jsonEncode({'error': 'not found'}));
        }
        await request.response.close();
      }),
    );
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('calls personal cloud health and pairing endpoints', () async {
    final client = CloudClipClient(baseUrl: _baseUrl(server));

    final health = await client.health();
    final pair = await client.pairDevice(
      deviceName: 'mac',
      pairingToken: 'pair-token',
    );

    expect(health.ok, isTrue);
    expect(health.version, 'test');
    expect(pair.deviceId, 'dev-1');
    expect(pair.accessToken, 'token-1');
    expect(requests.map((r) => '${r.method} ${r.path}'), [
      'GET /api/health',
      'POST /api/devices/pair',
    ]);
    expect(jsonDecode(requests.last.body)['pairingToken'], 'pair-token');
  });

  test('uploads analysis package and creates cloud clipping job', () async {
    final client = CloudClipClient(
      baseUrl: _baseUrl(server),
      accessToken: 'token-1',
    );
    final asset = MediaAsset(
      id: 'asset-1',
      sourceTaskId: 'download-1',
      sourceUrl: 'https://example.com/video',
      title: 'Video',
      mediaPath: '/downloads/video.mp4',
      mediaType: MediaAssetType.video,
      fileSha256: 'f' * 64,
      durationMs: 10000,
      fileSizeBytes: 100,
    );

    final media = await client.uploadAnalysisPackage(
      asset: asset,
      candidates: [
        ClipCandidate(
          id: 'candidate-1',
          mediaAssetId: asset.id,
          startMs: 0,
          endMs: 5000,
          title: 'Hook',
          summary: 'Hook',
          score: 0.8,
          reason: 'test',
        ),
      ],
      uploadPolicy: CloudUploadPolicy.manifestOnly,
    );
    final job = await client.createClipJob(
      cloudMediaId: media.cloudMediaId,
      candidateIds: const ['candidate-1'],
      uploadOriginal: false,
    );
    final status = await client.fetchClipJobStatus(job.cloudJobId);

    expect(media.cloudMediaId, 'media-1');
    expect(job.cloudJobId, 'job-1');
    expect(status.status, CloudSyncStatus.completed);
    expect(status.progress, 1);
    expect(requests[0].path, '/api/media/analysis-package');
    expect(jsonDecode(requests[0].body)['uploadPolicy'], 'manifestOnly');
    expect(jsonDecode(requests[1].body)['candidateIds'], ['candidate-1']);
  });

  test('supports chunk upload and result manifest retrieval', () async {
    final client = CloudClipClient(
      baseUrl: _baseUrl(server),
      accessToken: 'token-1',
    );

    final upload = await client.initOriginalUpload(
      cloudMediaId: 'media-1',
      fileName: 'video.mp4',
      totalBytes: 4,
      sha256: 'a' * 64,
      chunkSize: 4,
    );
    final chunk = await client.uploadChunk(
      cloudMediaId: 'media-1',
      uploadId: upload.uploadId,
      chunkIndex: 0,
      bytes: [1, 2, 3, 4],
    );
    final completed = await client.completeOriginalUpload(
      cloudMediaId: 'media-1',
      uploadId: upload.uploadId,
      sha256: 'a' * 64,
    );
    final status = await client.fetchOriginalUploadStatus(
      cloudMediaId: 'media-1',
      uploadId: upload.uploadId,
    );
    final cancelled = await client.cancelOriginalUpload(
      cloudMediaId: 'media-1',
      uploadId: upload.uploadId,
    );
    final manifest = await client.fetchResultManifest('job-1');

    expect(upload.uploadId, 'upload-1');
    expect(upload.chunkSize, 4);
    expect(chunk.receivedBytes, 4);
    expect(completed.objectPath, 'objects/media-1/original.bin');
    expect(status.status, CloudSyncStatus.uploading);
    expect(status.uploadedChunks, [0]);
    expect(cancelled.status, CloudSyncStatus.cancelled);
    expect(manifest['cloudJobId'], 'job-1');
    expect((manifest['clips'] as List), hasLength(1));
    expect(
      requests.map((r) => '${r.method} ${r.path}'),
      containsAll([
        'POST /api/media/media-1/uploads/init',
        'PUT /api/media/media-1/uploads/upload-1/chunks/0',
        'POST /api/media/media-1/uploads/upload-1/complete',
        'GET /api/media/media-1/uploads/upload-1',
        'DELETE /api/media/media-1/uploads/upload-1',
        'GET /api/clip-jobs/job-1/result-manifest',
      ]),
    );
  });
}

String _baseUrl(HttpServer server) {
  return 'http://${server.address.address}:${server.port}';
}

class _RequestLog {
  const _RequestLog(this.method, this.path, this.body);

  final String method;
  final String path;
  final String body;
}
