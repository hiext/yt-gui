import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/clip_record_repository.dart';
import 'package:hiext_yt_gui/core/services/database_service.dart';
import 'package:hiext_yt_gui/core/services/media_asset_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../sqlite_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late MediaAssetRepository repository;

  setUp(() async {
    initTestSqlite();
    db = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    await createClipAnalysisTestSchema(db);
    await createClipRecordsTestSchema(db);
    await createMediaLibraryTestSchema(db);
    DatabaseService().useTestDatabase(db);
    repository = MediaAssetRepository();
  });

  tearDown(() async {
    await db.close();
  });

  test('saves and loads structured media library records', () async {
    final now = DateTime.utc(2026, 6, 11, 10);
    final asset = MediaAsset(
      id: 'asset-1',
      sourceTaskId: 'download-1',
      sourceUrl: 'https://example.com/video',
      title: 'Launch review',
      mediaPath: '/downloads/launch.mp4',
      mediaType: MediaAssetType.video,
      fileSha256: 'a' * 64,
      durationMs: 120000,
      fileSizeBytes: 4096,
      author: 'Creator',
      thumbnailPath: '/downloads/launch.jpg',
      metadata: const {
        'chapters': ['intro'],
        'format': {'ext': 'mp4'},
      },
      createdAt: now,
      updatedAt: now,
    );
    await repository.saveMediaAsset(asset);
    await repository.saveAnalysisJob(
      MediaAnalysisJob(
        id: 'job-1',
        mediaAssetId: asset.id,
        runtime: MediaJobRuntime.local,
        status: MediaAnalysisStatus.completed,
        progress: 1,
        stages: const ['metadata', 'candidate'],
        manifestPath: '/downloads/launch.manifest.json',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.saveClipCandidate(
      ClipCandidate(
        id: 'candidate-1',
        mediaAssetId: asset.id,
        startMs: 1000,
        endMs: 9000,
        title: 'Strong hook',
        summary: 'The creator opens with a dense promise.',
        tags: const ['hook'],
        keywords: const ['launch', 'promise'],
        score: 0.91,
        scoreBreakdown: const {'semantic': 0.9, 'boundary': 0.8},
        evidenceIds: const ['transcript-1'],
        reason: 'high density opening',
        createdAt: now,
      ),
    );
    await repository.saveClipExportRecord(
      ClipExportRecord(
        id: 'export-1',
        mediaAssetId: asset.id,
        candidateId: 'candidate-1',
        startMs: 1000,
        endMs: 9000,
        outputPath: '/downloads/clips/hook.mp4',
        status: ClipExportStatus.completed,
        progress: 100,
        runtime: MediaJobRuntime.local,
        createdAt: now,
        completedAt: now,
      ),
    );
    await repository.saveVectorRecord(
      MediaVectorRecord(
        id: 'vector-1',
        mediaAssetId: asset.id,
        targetType: MediaVectorTargetType.candidate,
        targetId: 'candidate-1',
        modality: MediaVectorModality.text,
        model: 'test-embedding',
        dimension: 3,
        vector: const [0.1, 0.2, 0.3],
        payload: const {'text': 'Strong hook'},
        createdAt: now,
      ),
    );
    await repository.saveCloudConnectionConfig(
      CloudConnectionConfig(
        id: 'cloud-1',
        name: 'Home Lab',
        baseUrl: 'https://clips.example.test/',
        deviceName: 'mac-mini',
        accessToken: 'secret',
        uploadPolicy: CloudUploadPolicy.selectedClips,
        syncEnabled: true,
        pairedAt: now,
      ),
    );
    await repository.saveCloudSyncTask(
      CloudSyncTask(
        id: 'sync-1',
        mediaAssetId: asset.id,
        type: CloudSyncTaskType.uploadManifest,
        status: CloudSyncStatus.completed,
        idempotencyKey: 'asset-1:manifest',
        uploadedBytes: 120,
        totalBytes: 120,
        cloudMediaId: 'cloud-media-1',
        createdAt: now,
        updatedAt: now,
      ),
    );

    expect((await repository.loadMediaAsset(asset.id))!.metadata['chapters'], [
      'intro',
    ]);
    expect(
      await repository.loadMediaAssetBySourceTask('download-1'),
      isNotNull,
    );
    expect(await repository.loadAnalysisJobs(asset.id), hasLength(1));
    expect(await repository.searchClipCandidates('promise'), hasLength(1));
    expect(await repository.loadClipExportRecords(asset.id), hasLength(1));
    expect((await repository.loadVectorRecords(asset.id)).single.vector, [
      0.1,
      0.2,
      0.3,
    ]);
    expect(
      (await repository.loadCloudConnectionConfigs(
        enabledOnly: true,
      )).single.baseUrl,
      'https://clips.example.test',
    );
    expect(
      (await repository.loadCloudConnectionConfigs()).single.syncEnabled,
      isTrue,
    );
    expect(
      (await repository.loadCloudSyncTasks(
        status: CloudSyncStatus.completed,
      )).single.progress,
      1,
    );
  });

  test(
    'loads legacy clip segments as read-only compatible candidates',
    () async {
      final asset = _mediaAsset(sourceTaskId: 'download-legacy');
      await repository.saveMediaAsset(asset);
      await DatabaseService().replaceClipSegmentsForTask('post-1', [
        ClipSegment(
          id: 'seg-1',
          sourceTaskId: asset.sourceTaskId,
          postProcessTaskId: 'post-1',
          sourcePath: asset.mediaPath,
          startMs: 1000,
          endMs: 10000,
          adjustedStartMs: 800,
          adjustedEndMs: 11000,
          title: 'Legacy hook',
          summary: 'Old AI result',
          keywords: const ['legacy', 'hook'],
          tags: const ['old-model'],
          confidence: 0.82,
          reason: 'legacy segment',
          transcripts: [
            ClipTranscript(
              id: 'txt-1',
              segmentId: 'seg-1',
              startMs: 1000,
              endMs: 3000,
              text: 'legacy transcript',
              words: const ['legacy', 'transcript'],
            ),
          ],
        ),
      ]);

      final candidates = await repository.loadCompatibleClipCandidates(
        asset.id,
      );

      expect(candidates, hasLength(1));
      expect(candidates.single.id, 'legacy:seg-1');
      expect(candidates.single.mediaAssetId, asset.id);
      expect(candidates.single.startMs, 800);
      expect(candidates.single.endMs, 11000);
      expect(candidates.single.source, ClipCandidateSource.legacy);
      expect(candidates.single.evidenceIds, contains('clip_segment:seg-1'));
    },
  );

  test('loads legacy clip records as read-only compatible exports', () async {
    final asset = _mediaAsset(sourceTaskId: 'download-records');
    await repository.saveMediaAsset(asset);
    await ClipRecordRepository().save(
      ClipRecord(
        id: 'record-1',
        sourceTaskId: asset.sourceTaskId,
        sourcePath: asset.mediaPath,
        outputPath: '/downloads/clips/record-1.mp4',
        title: 'Exported old clip',
        confidence: 0.77,
        startMs: 2000,
        endMs: 7000,
        durationMs: 5000,
        status: ClipRecordStatus.completed,
        progress: 100,
        completedAt: DateTime.utc(2026, 6, 11, 10),
      ),
    );

    final records = await repository.loadCompatibleClipExportRecords(asset.id);

    expect(records, hasLength(1));
    expect(records.single.id, 'legacy:record-1');
    expect(records.single.mediaAssetId, asset.id);
    expect(records.single.status, ClipExportStatus.completed);
    expect(records.single.outputPath, '/downloads/clips/record-1.mp4');
  });
}

MediaAsset _mediaAsset({required String sourceTaskId}) {
  return MediaAsset(
    id: 'asset-$sourceTaskId',
    sourceTaskId: sourceTaskId,
    sourceUrl: 'https://example.com/$sourceTaskId',
    title: 'Downloaded media',
    mediaPath: '/downloads/$sourceTaskId.mp4',
    mediaType: MediaAssetType.video,
    fileSha256: 'b' * 64,
    durationMs: 0,
    fileSizeBytes: 0,
  );
}
