import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';

void main() {
  group('media library model serialization', () {
    test('MediaAsset round-trips structured metadata', () {
      final now = DateTime.utc(2026, 6, 11, 8);
      final asset = MediaAsset(
        id: 'asset-1',
        sourceTaskId: 'task-1',
        sourceUrl: 'https://example.com/video',
        title: 'Video',
        author: 'Creator',
        mediaPath: '/downloads/video.mp4',
        mediaType: MediaAssetType.video,
        fileSha256: 'a' * 64,
        durationMs: 123000,
        fileSizeBytes: 456,
        thumbnailPath: '/downloads/video.jpg',
        metadata: const {
          'chapters': ['intro', 'main'],
          'streams': {'video': 1, 'audio': 1},
        },
        createdAt: now,
        updatedAt: now,
      );

      final restored = MediaAsset.fromJson(asset.toJson());

      expect(restored.id, asset.id);
      expect(restored.metadata['chapters'], ['intro', 'main']);
      expect(restored.mediaType, MediaAssetType.video);
      expect(restored.createdAt, now);
    });

    test('ClipCandidate reads list fields from JSON strings', () {
      final candidate = ClipCandidate.fromJson({
        'id': 'candidate-1',
        'mediaAssetId': 'asset-1',
        'startMs': 1000,
        'endMs': 5000,
        'title': 'Hook',
        'summary': 'Dense opening',
        'tags': '["hook","shorts"]',
        'keywords': 'launch promise',
        'score': 0.81,
        'scoreBreakdown': {'semantic': 0.8},
        'evidenceIds': '["transcript-1"]',
        'reason': 'high density',
        'source': 'cloud',
      });

      expect(candidate.tags, ['hook', 'shorts']);
      expect(candidate.keywords, ['launch', 'promise']);
      expect(candidate.evidenceIds, ['transcript-1']);
      expect(candidate.source, ClipCandidateSource.cloud);
    });

    test('CloudConnectionConfig normalizes URL and sync limits', () {
      final config = CloudConnectionConfig.fromJson({
        'id': 'home-cloud',
        'name': '',
        'baseUrl': 'https://clips.example.test///',
        'deviceName': ' mac ',
        'accessToken': ' token ',
        'uploadPolicy': 'manifestOnly',
        'maxConcurrentSync': 99,
        'syncEnabled': true,
      });

      expect(config.name, 'Personal Cloud');
      expect(config.baseUrl, 'https://clips.example.test');
      expect(config.deviceName, 'mac');
      expect(config.accessToken, 'token');
      expect(config.uploadPolicy, CloudUploadPolicy.manifestOnly);
      expect(config.maxConcurrentSync, 8);
      expect(config.syncEnabled, isTrue);
    });

    test('CloudSyncTask computes upload progress', () {
      final task = CloudSyncTask.fromJson({
        'id': 'sync-1',
        'mediaAssetId': 'asset-1',
        'type': 'uploadClip',
        'status': 'uploading',
        'idempotencyKey': 'asset-1:clip-1',
        'uploadedBytes': 25,
        'totalBytes': 100,
      });

      expect(task.type, CloudSyncTaskType.uploadClip);
      expect(task.status, CloudSyncStatus.uploading);
      expect(task.progress, 0.25);
    });
  });
}
