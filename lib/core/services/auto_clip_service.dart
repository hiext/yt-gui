import 'dart:io';
import 'dart:math';

import '../models/app_models.dart';
import '../models/license_models.dart';
import 'clip_record_repository.dart';
import 'embedded_tool_executable.dart';
import 'embedded_tool_resolver.dart';
import 'ffmpeg_clip_executor.dart';
import 'media_asset_repository.dart';

class AutoClipService {
  AutoClipService({
    ClipRecordRepository? repository,
    MediaAssetRepository? mediaAssetRepository,
    AutoClipConfig? config,
    EmbeddedToolResolver? toolResolver,
    EmbeddedToolExecutableResolver? executableResolver,
    this.entitlementsProvider,
  }) : _repo = repository ?? ClipRecordRepository(),
       _mediaAssetRepository = mediaAssetRepository ?? MediaAssetRepository(),
       _toolResolver = toolResolver ?? const EmbeddedToolResolver(),
       _executableResolver =
           executableResolver ?? EmbeddedToolExecutableResolver(),
       config = config ?? AutoClipConfig.defaults;

  final ClipRecordRepository _repo;
  final MediaAssetRepository _mediaAssetRepository;
  final EmbeddedToolResolver _toolResolver;
  final EmbeddedToolExecutableResolver _executableResolver;

  /// Configuration (can be updated from settings).
  AutoClipConfig config;

  /// License entitlements for capping slice counts.
  final Entitlements Function()? entitlementsProvider;

  /// Currently tracked records.
  final List<ClipRecord> _records = [];

  /// Active ffmpeg processes, keyed by record id.
  final Map<String, Process> _processes = {};

  List<ClipRecord> get records => List.unmodifiable(_records);

  /// Start automatic cutting for qualifying segments.
  /// Returns list of created ClipRecords (status: cutting→completed/failed).
  Future<List<ClipRecord>> startAutoCut({
    required List<ClipSegment> segments,
    required DownloadSettings settings,
    void Function(String recordId, double progress)? onProgress,
    void Function(String recordId, ClipRecordStatus status)? onStatusChanged,
  }) async {
    if (!config.enabled || segments.isEmpty) return [];

    // Filter by confidence threshold
    final qualified = segments
        .where((s) => s.confidence >= config.minConfidence)
        .toList();

    if (qualified.isEmpty) return [];

    // Sort by confidence descending, then limit
    qualified.sort((a, b) => b.confidence.compareTo(a.confidence));
    final licenseCap = entitlementsProvider?.call().maxClipsPerVideo ??
        Entitlements.forTier(LicenseTier.free).maxClipsPerVideo;
    final cap = config.maxClipsPerVideo <= 0
        ? licenseCap
        : min(config.maxClipsPerVideo, licenseCap);
    final limited = qualified.take(cap).toList();

    // Apply offsets and duration limits
    final records = <ClipRecord>[];
    for (final segment in limited) {
      final effectiveStart = max(
        0,
        segment.effectiveStartMs + config.startOffsetMs,
      );
      final effectiveEnd = max(
        effectiveStart + 1000,
        segment.effectiveEndMs + config.endOffsetMs,
      );
      final maxDurationMs = max(1000, config.maxClipDurationSec * 1000);
      final clippedEnd = min(effectiveEnd, effectiveStart + maxDurationMs);
      final clampedEnd = max(effectiveStart + 1000, clippedEnd);

      final record = ClipRecord(
        id: '${segment.id}#cut',
        sourceTaskId: segment.sourceTaskId,
        sourcePath: segment.sourcePath,
        title: segment.title,
        confidence: segment.confidence,
        startMs: effectiveStart,
        endMs: clampedEnd,
        durationMs: clampedEnd - effectiveStart,
        status: ClipRecordStatus.pending,
      );
      records.add(record);
      _records.add(record);
    }

    // Save all records
    await _repo.saveAll(records);

    // Execute cuts serially
    for (final record in records) {
      await _repo.updateStatus(record.id, ClipRecordStatus.cutting);
      _updateLocalRecord(record.id, status: ClipRecordStatus.cutting);
      onStatusChanged?.call(record.id, ClipRecordStatus.cutting);

      try {
        // We use the FfmpegClipExecutor via PostProcessTask (type: clip)
        // For now, direct ffmpeg call through buildClipArguments
        final outputPath = _buildOutputPath(record, settings);
        final process = await _executorStartCut(
          record: record,
          outputPath: outputPath,
          settings: settings,
        );
        _processes[record.id] = process;

        // Watch for completion
        final exitCode = await process.exitCode;
        await process.stdout.drain<void>();
        await process.stderr.drain<void>();
        _processes.remove(record.id);

        if (exitCode == 0) {
          await _repo.updateStatus(
            record.id,
            ClipRecordStatus.completed,
            outputPath: outputPath,
          );
          _updateLocalRecord(
            record.id,
            status: ClipRecordStatus.completed,
            outputPath: outputPath,
          );
          await _mirrorRecordToMediaLibrary(
            record.copyWith(
              status: ClipRecordStatus.completed,
              outputPath: outputPath,
              progress: 100,
              completedAt: DateTime.now(),
            ),
          );
          onStatusChanged?.call(record.id, ClipRecordStatus.completed);
        } else {
          await _repo.updateStatus(
            record.id,
            ClipRecordStatus.failed,
            errorMessage: 'ffmpeg exited with code $exitCode',
          );
          _updateLocalRecord(
            record.id,
            status: ClipRecordStatus.failed,
            errorMessage: 'ffmpeg exited with code $exitCode',
          );
          await _mirrorRecordToMediaLibrary(
            record.copyWith(
              status: ClipRecordStatus.failed,
              errorMessage: 'ffmpeg exited with code $exitCode',
            ),
          );
          onStatusChanged?.call(record.id, ClipRecordStatus.failed);
        }
      } catch (e) {
        await _repo.updateStatus(
          record.id,
          ClipRecordStatus.failed,
          errorMessage: e.toString(),
        );
        _updateLocalRecord(
          record.id,
          status: ClipRecordStatus.failed,
          errorMessage: e.toString(),
        );
        await _mirrorRecordToMediaLibrary(
          record.copyWith(
            status: ClipRecordStatus.failed,
            errorMessage: e.toString(),
          ),
        );
        onStatusChanged?.call(record.id, ClipRecordStatus.failed);
      }
    }

    return records;
  }

  /// Cut a single clip segment manually.
  Future<ClipRecord> cutSingle({
    required ClipSegment segment,
    required DownloadSettings settings,
    void Function(double progress)? onProgress,
  }) async {
    final effectiveStart = max(
      0,
      segment.effectiveStartMs + config.startOffsetMs,
    );
    final effectiveEnd = max(
      effectiveStart + 1000,
      segment.effectiveEndMs + config.endOffsetMs,
    );
    final maxDurationMs = config.maxClipDurationSec * 1000;
    final clippedEnd = effectiveStart + maxDurationMs < effectiveEnd
        ? effectiveStart + maxDurationMs
        : effectiveEnd;

    final record = ClipRecord(
      id: '${segment.id}#cut-${DateTime.now().millisecondsSinceEpoch}',
      sourceTaskId: segment.sourceTaskId,
      sourcePath: segment.sourcePath,
      title: segment.title,
      confidence: segment.confidence,
      startMs: effectiveStart,
      endMs: clippedEnd,
      durationMs: clippedEnd - effectiveStart,
      status: ClipRecordStatus.pending,
    );
    _records.add(record);
    await _repo.save(record);

    await _repo.updateStatus(record.id, ClipRecordStatus.cutting);
    _updateLocalRecord(record.id, status: ClipRecordStatus.cutting);

    try {
      final outputPath = _buildOutputPath(record, settings);
      final process = await _executorStartCut(
        record: record,
        outputPath: outputPath,
        settings: settings,
      );
      _processes[record.id] = process;
      final exitCode = await process.exitCode;
      await process.stdout.drain<void>();
      await process.stderr.drain<void>();
      _processes.remove(record.id);

      if (exitCode == 0) {
        await _repo.updateStatus(
          record.id,
          ClipRecordStatus.completed,
          outputPath: outputPath,
        );
        _updateLocalRecord(
          record.id,
          status: ClipRecordStatus.completed,
          outputPath: outputPath,
        );
        await _mirrorRecordToMediaLibrary(
          record.copyWith(
            status: ClipRecordStatus.completed,
            outputPath: outputPath,
            progress: 100,
            completedAt: DateTime.now(),
          ),
        );
      } else {
        await _repo.updateStatus(
          record.id,
          ClipRecordStatus.failed,
          errorMessage: 'ffmpeg exited with code $exitCode',
        );
        _updateLocalRecord(
          record.id,
          status: ClipRecordStatus.failed,
          errorMessage: 'ffmpeg exited with code $exitCode',
        );
        await _mirrorRecordToMediaLibrary(
          record.copyWith(
            status: ClipRecordStatus.failed,
            errorMessage: 'ffmpeg exited with code $exitCode',
          ),
        );
      }
    } catch (e) {
      await _repo.updateStatus(
        record.id,
        ClipRecordStatus.failed,
        errorMessage: e.toString(),
      );
      _updateLocalRecord(
        record.id,
        status: ClipRecordStatus.failed,
        errorMessage: e.toString(),
      );
      await _mirrorRecordToMediaLibrary(
        record.copyWith(
          status: ClipRecordStatus.failed,
          errorMessage: e.toString(),
        ),
      );
    }

    return record;
  }

  /// Cancel an active cutting operation.
  Future<void> cancel(String recordId) async {
    final process = _processes.remove(recordId);
    process?.kill(ProcessSignal.sigterm);
    _updateLocalRecord(
      recordId,
      status: ClipRecordStatus.failed,
      errorMessage: 'Cancelled by user',
    );
    await _repo.updateStatus(
      recordId,
      ClipRecordStatus.failed,
      errorMessage: 'Cancelled by user',
    );
  }

  /// Load clip records for a source download task.
  Future<List<ClipRecord>> loadRecords({String? sourceTaskId}) async {
    if (sourceTaskId != null) {
      return _repo.loadBySourceTask(sourceTaskId);
    }
    return _repo.loadAll();
  }

  void _updateLocalRecord(
    String id, {
    ClipRecordStatus? status,
    String? outputPath,
    String? errorMessage,
  }) {
    final index = _records.indexWhere((r) => r.id == id);
    if (index < 0) return;
    _records[index] = _records[index].copyWith(
      status: status,
      outputPath: outputPath,
      errorMessage: errorMessage,
    );
  }

  String _buildOutputPath(ClipRecord record, DownloadSettings settings) {
    final sourceName = record.sourcePath.split('/').last;
    final dot = sourceName.lastIndexOf('.');
    final baseName = dot > 0 ? sourceName.substring(0, dot) : sourceName;
    final ext = dot > 0 ? sourceName.substring(dot) : '.mp4';
    final clipsDir = '${settings.saveDirectory}/.clips';
    return '$clipsDir/${baseName}_clip_${record.id}$ext';
  }

  Future<Process> _executorStartCut({
    required ClipRecord record,
    required String outputPath,
    required DownloadSettings settings,
  }) async {
    final tools = _toolResolver.resolveBundle(settings: settings);
    final ffmpegPath = await _executableResolver.ensureExecutable(
      tools.ffmpeg,
    );

    // Ensure output directory exists
    final outFile = File(outputPath);
    if (!outFile.parent.existsSync()) {
      outFile.parent.createSync(recursive: true);
    }

    final startOffset = Duration(milliseconds: record.startMs);
    final duration = Duration(milliseconds: record.durationMs);

    return Process.start(
      ffmpegPath,
      FfmpegClipExecutor.buildClipArguments(
        sourcePath: record.sourcePath,
        outputPath: outputPath,
        start: startOffset,
        duration: duration,
      ),
      runInShell: false,
    );
  }

  Future<void> _mirrorRecordToMediaLibrary(ClipRecord record) async {
    try {
      final asset = await _mediaAssetRepository.loadMediaAssetBySourceTask(
        record.sourceTaskId,
      );
      if (asset == null) return;
      await _mediaAssetRepository.saveClipExportRecord(
        ClipExportRecord(
          id: 'legacy-auto:${record.id}',
          mediaAssetId: asset.id,
          candidateId: 'legacy:${record.sourceTaskId}',
          startMs: record.startMs,
          endMs: record.endMs,
          outputPath: record.outputPath ?? '',
          status: _mapStatus(record.status),
          progress: record.progress,
          runtime: MediaJobRuntime.local,
          errorMessage: record.errorMessage,
          createdAt: record.createdAt,
          completedAt: record.completedAt,
        ),
      );
    } catch (_) {
      // The legacy auto-cut path must remain usable even when the new media
      // library schema is not present yet.
    }
  }

  ClipExportStatus _mapStatus(ClipRecordStatus status) {
    return switch (status) {
      ClipRecordStatus.pending => ClipExportStatus.pending,
      ClipRecordStatus.cutting => ClipExportStatus.cutting,
      ClipRecordStatus.completed => ClipExportStatus.completed,
      ClipRecordStatus.failed => ClipExportStatus.failed,
    };
  }

  Future<void> dispose() async {
    _records.clear();
  }
}
