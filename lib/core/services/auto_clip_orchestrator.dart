import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../models/app_models.dart';
import '../models/license_models.dart';
import 'ai_clip_analyzer_executor.dart';
import 'cloud_clip_client.dart';
import 'local_analysis_service.dart';
import 'local_clip_worker_service.dart';
import 'log_service.dart';
import 'media_asset_indexer_service.dart';
import 'media_asset_repository.dart';

class AutoClipOrchestrator {
  AutoClipOrchestrator({
    MediaAssetIndexerService? mediaAssetIndexer,
    MediaAssetRepository? repository,
    AutoClipSegmentAnalyzer? segmentAnalyzer,
    this._localAnalyzer,
    this._localExporter,
    this._cloudSyncService,
    this.entitlementsProvider,
  })  : _mediaAssetIndexer = mediaAssetIndexer ?? MediaAssetIndexerService(),
        _repository = repository ?? MediaAssetRepository(),
        _segmentAnalyzer = segmentAnalyzer ?? _analyzeSegments;

  final MediaAssetIndexerService _mediaAssetIndexer;
  final MediaAssetRepository _repository;
  final AutoClipSegmentAnalyzer _segmentAnalyzer;
  final LocalAnalysisRunner? _localAnalyzer;
  final LocalClipExporter? _localExporter;
  final CloudClipSyncService? _cloudSyncService;

  /// License entitlements for capping slice counts. Falls back to Free (3 per
  /// video) when absent so legacy callers (tests / older AppShell) stay safe.
  final Entitlements Function()? entitlementsProvider;

  Future<AutoClipOrchestrationResult> onDownloadCompleted(
    DownloadTask task, {
    required DownloadSettings settings,
  }) async {
    final config = settings.autoClipConfig;
    if (!config.enabled) {
      return const AutoClipOrchestrationResult(
        status: AutoClipOrchestrationStatus.skipped,
        message: 'Auto clip is disabled',
      );
    }

    try {
      final asset = await _mediaAssetIndexer.indexCompletedDownload(task);
      if (asset == null) {
        return const AutoClipOrchestrationResult(
          status: AutoClipOrchestrationStatus.skipped,
          message: 'No media asset was indexed for the completed download',
        );
      }
      if (asset.mediaType != MediaAssetType.video) {
        return const AutoClipOrchestrationResult(
          status: AutoClipOrchestrationStatus.skipped,
          message: 'Auto clip only supports video assets',
        );
      }

      final segments = await _segmentAnalyzer(asset, settings);
      if (segments.isEmpty) {
        return const AutoClipOrchestrationResult(
          status: AutoClipOrchestrationStatus.skipped,
          message: 'No clip candidates were produced',
        );
      }

      final analysis = await (_localAnalyzer ?? _defaultLocalAnalyzer)(
        asset: asset,
        settings: settings,
        seedSegments: segments,
      );
      if (analysis.job.status != MediaAnalysisStatus.completed) {
        return AutoClipOrchestrationResult(
          status: AutoClipOrchestrationStatus.failed,
          message: analysis.job.errorMessage ?? 'Local analysis failed',
        );
      }

      final candidates = _selectCandidates(analysis.candidates, config);
      if (candidates.isEmpty) {
        return const AutoClipOrchestrationResult(
          status: AutoClipOrchestrationStatus.skipped,
          message: 'No candidates matched the auto clip thresholds',
        );
      }

      final adjusted = [
        for (final candidate in candidates)
          _applyConfig(candidate, config),
      ];
      await _repository.saveClipCandidates(adjusted);

      final exports = <ClipExportRecord>[];
      for (final candidate in adjusted) {
        final record = await (_localExporter ?? _defaultLocalExporter)(
          asset: analysis.asset,
          candidate: candidate,
          settings: settings,
        );
        exports.add(record);
      }

      final cloudSync = _cloudSyncService ?? DefaultCloudClipSyncService(
        repository: _repository,
        entitlementsProvider: entitlementsProvider,
      );
      try {
        await cloudSync.syncAutoClipResult(
          asset: analysis.asset,
          candidates: adjusted,
          localExports: exports,
          settings: settings,
        );
      } catch (error) {
        LogService.instance.warn(
          'cloud sync failed for ${analysis.asset.id}: $error', 'ctrl',
        );
      }

      return AutoClipOrchestrationResult(
        status: exports.any((record) => record.status == ClipExportStatus.failed)
            ? AutoClipOrchestrationStatus.failed
            : AutoClipOrchestrationStatus.completed,
        asset: analysis.asset,
        candidates: adjusted,
        localExports: exports,
      );
    } catch (error) {
      return AutoClipOrchestrationResult(
        status: AutoClipOrchestrationStatus.failed,
        message: error.toString(),
      );
    }
  }

  List<ClipCandidate> _selectCandidates(
    List<ClipCandidate> candidates,
    AutoClipConfig config,
  ) {
    final qualified = candidates
        .where((candidate) => candidate.score >= config.minConfidence)
        .toList();
    qualified.sort((a, b) {
      final score = b.score.compareTo(a.score);
      return score != 0 ? score : a.startMs.compareTo(b.startMs);
    });
    final settingsCap = config.maxClipsPerVideo;
    final licenseCap = entitlementsProvider?.call().maxClipsPerVideo ??
        Entitlements.forTier(LicenseTier.free).maxClipsPerVideo;
    final cap = settingsCap <= 0 ? licenseCap : min(settingsCap, licenseCap);
    return qualified.take(cap).toList(growable: false);
  }

  ClipCandidate _applyConfig(ClipCandidate candidate, AutoClipConfig config) {
    final start = max(0, candidate.startMs + config.startOffsetMs);
    final rawEnd = max(start + 1000, candidate.endMs + config.endOffsetMs);
    final maxDurationMs = max(1000, config.maxClipDurationSec * 1000);
    final end = min(rawEnd, start + maxDurationMs);
    final clampedEnd = max(start + 1000, end);
    return ClipCandidate(
      id: candidate.id,
      mediaAssetId: candidate.mediaAssetId,
      startMs: start,
      endMs: clampedEnd,
      title: candidate.title,
      summary: candidate.summary,
      tags: candidate.tags,
      keywords: candidate.keywords,
      score: candidate.score,
      scoreBreakdown: candidate.scoreBreakdown,
      evidenceIds: candidate.evidenceIds,
      reason: candidate.reason,
      source: candidate.source,
      createdAt: candidate.createdAt,
    );
  }
}

enum AutoClipOrchestrationStatus { skipped, completed, failed }

class AutoClipOrchestrationResult {
  const AutoClipOrchestrationResult({
    required this.status,
    this.message,
    this.asset,
    this.candidates = const [],
    this.localExports = const [],
  });

  final AutoClipOrchestrationStatus status;
  final String? message;
  final MediaAsset? asset;
  final List<ClipCandidate> candidates;
  final List<ClipExportRecord> localExports;
}

typedef AutoClipSegmentAnalyzer =
    Future<List<ClipSegment>> Function(
      MediaAsset asset,
      DownloadSettings settings,
    );

typedef LocalAnalysisRunner =
    Future<LocalAnalysisResult> Function({
      required MediaAsset asset,
      required DownloadSettings settings,
      List<ClipSegment> seedSegments,
    });

typedef LocalClipExporter =
    Future<ClipExportRecord> Function({
      required MediaAsset asset,
      required ClipCandidate candidate,
      required DownloadSettings settings,
      ClipExportProgressChanged? onProgress,
    });

abstract class CloudClipSyncService {
  Future<void> syncAutoClipResult({
    required MediaAsset asset,
    required List<ClipCandidate> candidates,
    required List<ClipExportRecord> localExports,
    required DownloadSettings settings,
  });
}

Future<LocalAnalysisResult> _defaultLocalAnalyzer({
  required MediaAsset asset,
  required DownloadSettings settings,
  List<ClipSegment> seedSegments = const [],
}) {
  return LocalAnalysisService(repository: MediaAssetRepository()).analyze(
    asset: asset,
    settings: settings,
    seedSegments: seedSegments,
  );
}

Future<ClipExportRecord> _defaultLocalExporter({
  required MediaAsset asset,
  required ClipCandidate candidate,
  required DownloadSettings settings,
  ClipExportProgressChanged? onProgress,
}) {
  return LocalClipWorkerService(repository: MediaAssetRepository()).exportCandidate(
    asset: asset,
    candidate: candidate,
    settings: settings,
    onProgress: onProgress,
  );
}

Future<List<ClipSegment>> _analyzeSegments(
  MediaAsset asset,
  DownloadSettings settings,
) async {
  final executor = AiClipAnalyzerExecutor();
  final completer = Completer<List<ClipSegment>>();
  final task = PostProcessTask(
    id: '${asset.sourceTaskId}#auto-clip-analysis',
    sourceTaskId: asset.sourceTaskId,
    title: asset.title,
    type: PostProcessTaskType.aiClipAnalysis,
    status: PostProcessStatus.queued,
    progress: 0,
    sourcePath: asset.mediaPath,
    outputDirectory: '${asset.mediaPath}.clips',
  );

  try {
    await executor.startTask(
      task: task,
      settings: settings,
      onTaskChanged: (changed) {
        if (changed.status == PostProcessStatus.completed &&
            !completer.isCompleted) {
          completer.complete(changed.clipSegments);
        }
        if (changed.status == PostProcessStatus.failed && !completer.isCompleted) {
          completer.completeError(
            AutoClipOrchestrationException(
              changed.errorMessage ?? 'AI clip analysis failed',
            ),
          );
        }
        if (changed.status == PostProcessStatus.cancelled &&
            !completer.isCompleted) {
          completer.complete(const <ClipSegment>[]);
        }
      },
    );

    if (!completer.isCompleted) {
      return await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          if (!completer.isCompleted) {
            completer.completeError(
              const AutoClipOrchestrationException(
                'AI clip analysis timed out after 5 minutes',
              ),
            );
          }
          throw TimeoutException(
            'AI clip analysis timed out for ${asset.sourceTaskId}',
          );
        },
      );
    }
    return await completer.future;
  } finally {
    await executor.dispose();
  }
}

class DefaultCloudClipSyncService implements CloudClipSyncService {
  DefaultCloudClipSyncService({
    MediaAssetRepository? repository,
    this._clientFactory,
    CloudOriginalUploader? originalUploader,
    this.entitlementsProvider,
  }) : _repository = repository ?? MediaAssetRepository(),
       _originalUploader = originalUploader ?? _uploadOriginalFile;

  final MediaAssetRepository _repository;
  final CloudClipClient Function(CloudConnectionConfig config)? _clientFactory;
  final CloudOriginalUploader _originalUploader;

  /// License entitlements gate. Cloud sync is a Team-only feature; when the
  /// provider is absent or reports a non-Team tier we fall back to Free
  /// (disabled) so unactivated / Pro apps never sync to the cloud.
  final Entitlements Function()? entitlementsProvider;

  @override
  Future<void> syncAutoClipResult({
    required MediaAsset asset,
    required List<ClipCandidate> candidates,
    required List<ClipExportRecord> localExports,
    required DownloadSettings settings,
  }) async {
    final cloudSyncEnabled = entitlementsProvider?.call().cloudSyncEnabled ??
        Entitlements.forTier(LicenseTier.free).cloudSyncEnabled;
    if (!cloudSyncEnabled) return;

    final configs = await _repository.loadCloudConnectionConfigs(
      enabledOnly: true,
    );
    final config = configs
        .where((candidate) => candidate.syncEnabled && candidate.isPaired)
        .cast<CloudConnectionConfig?>()
        .firstWhere((candidate) => candidate != null, orElse: () => null);
    if (config == null) return;

    final client = _clientFactory?.call(config) ??
        CloudClipClient(baseUrl: config.baseUrl, accessToken: config.accessToken);
    final syncTaskId = '${asset.id}#cloud:auto-clip';
    var syncTask = CloudSyncTask(
      id: syncTaskId,
      mediaAssetId: asset.id,
      type: CloudSyncTaskType.uploadManifest,
      status: CloudSyncStatus.uploading,
      idempotencyKey: syncTaskId,
      totalBytes: asset.fileSizeBytes,
    );
    await _repository.saveCloudSyncTask(syncTask);

    try {
      final media = await client.uploadAnalysisPackage(
        asset: asset,
        candidates: candidates,
        exports: localExports,
        uploadPolicy: config.uploadPolicy,
      );

      if (config.uploadPolicy == CloudUploadPolicy.originalOnConfirm) {
        syncTask = syncTask.copyWith(
          type: CloudSyncTaskType.uploadOriginal,
          status: CloudSyncStatus.uploading,
          cloudMediaId: media.cloudMediaId,
        );
        await _repository.saveCloudSyncTask(syncTask);
        await _originalUploader(client, media.cloudMediaId, asset);
      }

      final job = await client.createClipJob(
        cloudMediaId: media.cloudMediaId,
        candidateIds: candidates.map((candidate) => candidate.id).toList(),
        uploadOriginal: config.uploadPolicy == CloudUploadPolicy.originalOnConfirm,
      );
      syncTask = syncTask.copyWith(
        type: CloudSyncTaskType.createClipJob,
        status: CloudSyncStatus.running,
        cloudMediaId: media.cloudMediaId,
        cloudJobId: job.cloudJobId,
      );
      await _repository.saveCloudSyncTask(syncTask);

      await client.runClipJob(job.cloudJobId);
      final manifest = await client.fetchResultManifest(job.cloudJobId);
      await _saveCloudExports(
        asset: asset,
        candidates: candidates,
        manifest: manifest,
        cloudJobId: job.cloudJobId,
      );
      await _repository.saveCloudSyncTask(
        syncTask.copyWith(
          type: CloudSyncTaskType.pullResult,
          status: CloudSyncStatus.completed,
          uploadedBytes: asset.fileSizeBytes,
        ),
      );
    } catch (error) {
      await _repository.saveCloudSyncTask(
        syncTask.copyWith(
          status: CloudSyncStatus.failed,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _saveCloudExports({
    required MediaAsset asset,
    required List<ClipCandidate> candidates,
    required Map<String, Object?> manifest,
    required String cloudJobId,
  }) async {
    final byId = {for (final candidate in candidates) candidate.id: candidate};
    final clips = manifest['clips'];
    if (clips is! List) return;
    for (final raw in clips.whereType<Map>()) {
      final candidateId = raw['candidateId'] as String?;
      final candidate = byId[candidateId];
      if (candidateId == null || candidate == null) continue;
      await _repository.saveClipExportRecord(
        ClipExportRecord(
          id: '${asset.id}#cloud:$candidateId',
          mediaAssetId: asset.id,
          candidateId: candidateId,
          startMs: candidate.startMs,
          endMs: candidate.endMs,
          outputPath: raw['downloadPath'] as String? ?? '',
          status: ClipExportStatus.completed,
          progress: 100,
          runtime: MediaJobRuntime.cloud,
          cloudJobId: cloudJobId,
          completedAt: DateTime.now(),
        ),
      );
    }
  }
}

typedef CloudOriginalUploader =
    Future<void> Function(
      CloudClipClient client,
      String cloudMediaId,
      MediaAsset asset,
    );

Future<void> _uploadOriginalFile(
  CloudClipClient client,
  String cloudMediaId,
  MediaAsset asset,
) async {
  final file = File(asset.mediaPath);
  if (!file.existsSync()) {
    throw AutoClipOrchestrationException(
      'Original media file does not exist: ${asset.mediaPath}',
    );
  }
  const chunkSize = 8 * 1024 * 1024;
  final init = await client.initOriginalUpload(
    cloudMediaId: cloudMediaId,
    fileName: file.uri.pathSegments.last,
    totalBytes: asset.fileSizeBytes,
    sha256: asset.fileSha256,
    chunkSize: chunkSize,
  );
  final uploaded = init.uploadedChunks.toSet();
  var index = 0;
  await for (final bytes in file.openRead().transform(_ChunkSplitter(chunkSize))) {
    if (!uploaded.contains(index)) {
      await client.uploadChunk(
        cloudMediaId: cloudMediaId,
        uploadId: init.uploadId,
        chunkIndex: index,
        bytes: bytes,
      );
    }
    index += 1;
  }
  await client.completeOriginalUpload(
    cloudMediaId: cloudMediaId,
    uploadId: init.uploadId,
    sha256: asset.fileSha256,
  );
}

class _ChunkSplitter extends StreamTransformerBase<List<int>, List<int>> {
  const _ChunkSplitter(this.chunkSize);

  final int chunkSize;

  @override
  Stream<List<int>> bind(Stream<List<int>> stream) async* {
    var buffer = <int>[];
    await for (final bytes in stream) {
      buffer.addAll(bytes);
      while (buffer.length >= chunkSize) {
        yield List<int>.from(buffer.take(chunkSize));
        buffer = buffer.skip(chunkSize).toList();
      }
    }
    if (buffer.isNotEmpty) yield buffer;
  }
}

class AutoClipOrchestrationException implements Exception {
  const AutoClipOrchestrationException(this.message);

  final String message;

  @override
  String toString() => message;
}
