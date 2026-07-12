import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/models/license_models.dart';
import 'package:hiext_yt_gui/core/services/auto_clip_orchestrator.dart';
import 'package:hiext_yt_gui/core/services/database_service.dart';
import 'package:hiext_yt_gui/core/services/local_analysis_service.dart';
import 'package:hiext_yt_gui/core/services/media_asset_indexer_service.dart';
import 'package:hiext_yt_gui/core/services/media_asset_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../sqlite_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late MediaAssetRepository repository;
  late _FakeMediaAssetIndexer indexer;
  late _FakeCloudSyncService cloudSync;

  setUp(() async {
    initTestSqlite();
    db = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    await createMediaLibraryTestSchema(db);
    DatabaseService().useTestDatabase(db);
    repository = MediaAssetRepository();
    indexer = _FakeMediaAssetIndexer();
    cloudSync = _FakeCloudSyncService();
  });

  tearDown(() async {
    await db.close();
  });

  test('indexes, analyzes, exports locally, and syncs cloud after download', () async {
    final asset = _asset();
    indexer.asset = asset;
    final exportCalls = <String>[];
    final orchestrator = AutoClipOrchestrator(
      mediaAssetIndexer: indexer,
      repository: repository,
      segmentAnalyzer: (_, _) async => [_segment(asset)],
      localAnalyzer: ({required asset, required settings, seedSegments = const []}) async {
        final candidate = ClipCandidate(
          id: 'local:seg-1',
          mediaAssetId: asset.id,
          startMs: seedSegments.single.effectiveStartMs,
          endMs: seedSegments.single.effectiveEndMs,
          title: seedSegments.single.title,
          summary: seedSegments.single.summary,
          tags: seedSegments.single.tags,
          keywords: seedSegments.single.keywords,
          score: seedSegments.single.confidence,
          reason: seedSegments.single.reason,
          source: ClipCandidateSource.local,
        );
        await repository.saveClipCandidate(candidate);
        return LocalAnalysisResult(
          asset: asset,
          job: MediaAnalysisJob(
            id: 'job-1',
            mediaAssetId: asset.id,
            runtime: MediaJobRuntime.local,
            status: MediaAnalysisStatus.completed,
            progress: 1,
          ),
          candidates: [candidate],
          vectors: const [],
        );
      },
      localExporter: ({required asset, required candidate, required settings, onProgress}) async {
        exportCalls.add(candidate.id);
        final record = ClipExportRecord(
          id: '${asset.id}#export:${candidate.id}',
          mediaAssetId: asset.id,
          candidateId: candidate.id,
          startMs: candidate.startMs,
          endMs: candidate.endMs,
          outputPath: '${settings.saveDirectory}/.clips/${candidate.id}.mp4',
          status: ClipExportStatus.completed,
          progress: 100,
          runtime: MediaJobRuntime.local,
        );
        await repository.saveClipExportRecord(record);
        return record;
      },
      cloudSyncService: cloudSync,
    );

    final result = await orchestrator.onDownloadCompleted(
      _downloadTask(),
      settings: _settings(),
    );

    expect(result.status, AutoClipOrchestrationStatus.completed);
    expect(indexer.indexed.single.id, 'download-1');
    expect(exportCalls, ['local:seg-1']);
    expect(await repository.loadClipCandidates(asset.id), hasLength(1));
    final exports = await repository.loadClipExportRecords(asset.id);
    expect(exports.single.status, ClipExportStatus.completed);
    expect(exports.single.runtime, MediaJobRuntime.local);
    expect(cloudSync.syncedCandidates.single.id, 'local:seg-1');
  });

  test('does not analyze or export when auto clip is disabled', () async {
    var analyzed = false;
    var exported = false;
    final orchestrator = AutoClipOrchestrator(
      mediaAssetIndexer: indexer,
      repository: repository,
      segmentAnalyzer: (_, _) async {
        analyzed = true;
        return const [];
      },
      localExporter: ({required asset, required candidate, required settings, onProgress}) async {
        exported = true;
        throw StateError('should not export');
      },
    );

    final result = await orchestrator.onDownloadCompleted(
      _downloadTask(),
      settings: _settings(
        autoClipConfig: AutoClipConfig.defaults.copyWith(enabled: false),
      ),
    );

    expect(result.status, AutoClipOrchestrationStatus.skipped);
    expect(indexer.indexed, isEmpty);
    expect(analyzed, isFalse);
    expect(exported, isFalse);
  });

  test('skips when indexing cannot create a media asset', () async {
    indexer.asset = null;
    final orchestrator = AutoClipOrchestrator(
      mediaAssetIndexer: indexer,
      repository: repository,
      segmentAnalyzer: (_, _) async => const [],
    );

    final result = await orchestrator.onDownloadCompleted(
      _downloadTask(),
      settings: _settings(),
    );

    expect(result.status, AutoClipOrchestrationStatus.skipped);
    expect(result.message, contains('No media asset'));
  });

  test('returns failed result when indexing throws', () async {
    indexer.failure = StateError('index failed');
    final orchestrator = AutoClipOrchestrator(
      mediaAssetIndexer: indexer,
      repository: repository,
      segmentAnalyzer: (_, _) async => const [],
    );

    final result = await orchestrator.onDownloadCompleted(
      _downloadTask(),
      settings: _settings(),
    );

    expect(result.status, AutoClipOrchestrationStatus.failed);
    expect(result.message, contains('index failed'));
  });

  test('local export succeeds even when cloud sync fails', () async {
    indexer.asset = _asset();
    final orchestrator = AutoClipOrchestrator(
      mediaAssetIndexer: indexer,
      repository: repository,
      segmentAnalyzer: (_, _) async => [_segment(_asset())],
      localAnalyzer: ({required asset, required settings, seedSegments = const []}) async {
        final candidate = ClipCandidate(
          id: 'local:seg-1', mediaAssetId: asset.id,
          startMs: 1000, endMs: 9000, title: 'Hook', summary: 'Sum',
          score: 0.9, reason: 'test', source: ClipCandidateSource.local,
        );
        await repository.saveClipCandidate(candidate);
        return LocalAnalysisResult(
          asset: asset,
          job: MediaAnalysisJob(id: 'j', mediaAssetId: asset.id,
            runtime: MediaJobRuntime.local, status: MediaAnalysisStatus.completed, progress: 1),
          candidates: [candidate], vectors: const [],
        );
      },
      localExporter: ({required asset, required candidate, required settings, onProgress}) async {
        final record = ClipExportRecord(
          id: '${asset.id}#export:${candidate.id}', mediaAssetId: asset.id,
          candidateId: candidate.id, startMs: candidate.startMs, endMs: candidate.endMs,
          outputPath: '/tmp/out.mp4', status: ClipExportStatus.completed, progress: 100,
          runtime: MediaJobRuntime.local,
        );
        await repository.saveClipExportRecord(record);
        return record;
      },
      cloudSyncService: _FakeFailingCloudSyncService(),
    );

    final result = await orchestrator.onDownloadCompleted(
      _downloadTask(), settings: _settings(),
    );

    expect(result.status, AutoClipOrchestrationStatus.completed);
    final exports = await repository.loadClipExportRecords(_asset().id);
    expect(exports.single.status, ClipExportStatus.completed);
  });

  test('returns skipped when no candidates match confidence threshold', () async {
    indexer.asset = _asset();
    final orchestrator = AutoClipOrchestrator(
      mediaAssetIndexer: indexer,
      repository: repository,
      segmentAnalyzer: (_, _) async => [_segment(_asset())],
      localAnalyzer: ({required asset, required settings, seedSegments = const []}) async {
        final candidate = ClipCandidate(
          id: 'low-score', mediaAssetId: asset.id,
          startMs: 0, endMs: 5000, title: 'Low', summary: 'Low',
          score: 0.3, reason: 'low', source: ClipCandidateSource.local,
        );
        await repository.saveClipCandidate(candidate);
        return LocalAnalysisResult(
          asset: asset,
          job: MediaAnalysisJob(id: 'j', mediaAssetId: asset.id,
            runtime: MediaJobRuntime.local, status: MediaAnalysisStatus.completed, progress: 1),
          candidates: [candidate], vectors: const [],
        );
      },
    );

    final result = await orchestrator.onDownloadCompleted(
      _downloadTask(), settings: _settings(),
    );

    expect(result.status, AutoClipOrchestrationStatus.skipped);
    expect(result.message, contains('No candidates matched'));
  });

  test('returns failed when analysis job reports failed status', () async {
    indexer.asset = _asset();
    final orchestrator = AutoClipOrchestrator(
      mediaAssetIndexer: indexer,
      repository: repository,
      segmentAnalyzer: (_, _) async => [_segment(_asset())],
      localAnalyzer: ({required asset, required settings, seedSegments = const []}) async {
        return LocalAnalysisResult(
          asset: asset,
          job: MediaAnalysisJob(id: 'j', mediaAssetId: asset.id,
            runtime: MediaJobRuntime.local, status: MediaAnalysisStatus.failed,
            progress: 0, errorMessage: 'ffprobe not found'),
          candidates: const [], vectors: const [],
        );
      },
    );

    final result = await orchestrator.onDownloadCompleted(
      _downloadTask(), settings: _settings(),
    );

    expect(result.status, AutoClipOrchestrationStatus.failed);
    expect(result.message, contains('ffprobe'));
  });

  test('skips non-video media assets', () async {
    final audioAsset = MediaAsset(
      id: 'audio-1', sourceTaskId: 'download-1',
      sourceUrl: 'https://example.com/audio',
      title: 'Audio', mediaPath: '/tmp/audio.m4a',
      mediaType: MediaAssetType.audio,
      fileSha256: 'b' * 64, durationMs: 60000, fileSizeBytes: 512,
    );
    indexer.asset = audioAsset;
    final orchestrator = AutoClipOrchestrator(
      mediaAssetIndexer: indexer,
      repository: repository,
      segmentAnalyzer: (_, _) async => const [],
    );

    final result = await orchestrator.onDownloadCompleted(
      _downloadTask(), settings: _settings(),
    );

    expect(result.status, AutoClipOrchestrationStatus.skipped);
    expect(result.message, contains('video'));
  });

  group('DefaultCloudClipSyncService entitlement gating', () {
    Future<int> configLoadsFor(Entitlements Function()? provider) async {
      final repo = _RecordingRepository();
      final service = DefaultCloudClipSyncService(
        repository: repo,
        entitlementsProvider: provider,
      );
      await service.syncAutoClipResult(
        asset: _asset(),
        candidates: const [],
        localExports: const [],
        settings: _settings(),
      );
      return repo.loadConfigsCalls;
    }

    test('skips cloud sync for Free tier (no config lookup)', () async {
      final calls =
          await configLoadsFor(() => Entitlements.forTier(LicenseTier.free));
      expect(calls, 0);
    });

    test('skips cloud sync for Pro tier (no config lookup)', () async {
      final calls =
          await configLoadsFor(() => Entitlements.forTier(LicenseTier.pro));
      expect(calls, 0);
    });

    test('skips cloud sync when no entitlements provider (defaults to Free)',
        () async {
      final calls = await configLoadsFor(null);
      expect(calls, 0);
    });

    test('executes cloud sync for Team tier (reaches config lookup)', () async {
      final calls =
          await configLoadsFor(() => Entitlements.forTier(LicenseTier.team));
      expect(calls, 1);
    });
  });
}

DownloadTask _downloadTask() {
  return DownloadTask(
    id: 'download-1',
    title: 'Downloaded video',
    source: 'https://example.com/video',
    status: DownloadStatus.completed,
    progress: 100,
    variants: const [ResourceVariant(label: 'video', description: 'mp4', isRecommended: true)],
    mediaPath: '/downloads/video.mp4',
  );
}

MediaAsset _asset() {
  return MediaAsset(
    id: 'asset-1',
    sourceTaskId: 'download-1',
    sourceUrl: 'https://example.com/video',
    title: 'Downloaded video',
    mediaPath: '/downloads/video.mp4',
    mediaType: MediaAssetType.video,
    fileSha256: 'a' * 64,
    durationMs: 30000,
    fileSizeBytes: 1024,
  );
}

ClipSegment _segment(MediaAsset asset) {
  return ClipSegment(
    id: 'seg-1',
    sourceTaskId: asset.sourceTaskId,
    postProcessTaskId: 'auto-clip-analysis',
    sourcePath: asset.mediaPath,
    startMs: 1000,
    endMs: 9000,
    title: 'Strong hook',
    summary: 'A strong opening hook.',
    keywords: const ['hook'],
    tags: const ['auto'],
    confidence: 0.91,
    reason: 'high density',
  );
}

DownloadSettings _settings({AutoClipConfig? autoClipConfig}) {
  return DownloadSettings(
    saveDirectory: '/downloads',
    downloadMode: DownloadMode.serial,
    concurrentCount: 1,
    defaultQuality: 'best',
    downloadSubtitles: false,
    downloadThumbnail: false,
    disclaimerAccepted: false,
    autoClipConfig: autoClipConfig ?? AutoClipConfig.defaults,
  );
}

class _FakeMediaAssetIndexer implements MediaAssetIndexerService {
  MediaAsset? asset = _asset();
  Object? failure;
  final indexed = <DownloadTask>[];

  @override
  Future<MediaAsset?> indexCompletedDownload(DownloadTask task) async {
    indexed.add(task);
    final error = failure;
    if (error != null) throw error;
    final indexedAsset = asset;
    if (indexedAsset != null) {
      await MediaAssetRepository().saveMediaAsset(indexedAsset);
    }
    return indexedAsset;
  }
}

class _FakeFailingCloudSyncService implements CloudClipSyncService {
  @override
  Future<void> syncAutoClipResult({
    required MediaAsset asset,
    required List<ClipCandidate> candidates,
    required List<ClipExportRecord> localExports,
    required DownloadSettings settings,
  }) async {
    throw Exception('cloud sync failed');
  }
}

class _FakeCloudSyncService implements CloudClipSyncService {
  List<ClipCandidate> syncedCandidates = const [];

  @override
  Future<void> syncAutoClipResult({
    required MediaAsset asset,
    required List<ClipCandidate> candidates,
    required List<ClipExportRecord> localExports,
    required DownloadSettings settings,
  }) async {
    syncedCandidates = candidates;
  }
}

/// Records how many times the cloud sync path reaches the connection-config
/// lookup. The entitlement gate returns before this call for Free/Pro, so a
/// zero count proves the gate blocked the sync; a count of one proves Team
/// passed the gate. Returns no configs, so Team stops cleanly at
/// `config == null` without touching the network.
class _RecordingRepository extends MediaAssetRepository {
  int loadConfigsCalls = 0;

  @override
  Future<List<CloudConnectionConfig>> loadCloudConnectionConfigs({
    bool enabledOnly = false,
  }) async {
    loadConfigsCalls += 1;
    return const [];
  }
}
