import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ffmpeg_clip_executor.dart';
import '../models/app_models.dart';
import 'embedded_tool_resolver.dart';
import 'media_asset_repository.dart';
import 'process_yt_dlp_executor.dart' show ProcessRunner;

typedef FfmpegPathResolver = String Function(DownloadSettings settings);
typedef ClipExportProgressChanged =
    void Function(ClipExportRecord record, int progress);

class LocalClipWorkerService {
  LocalClipWorkerService({
    MediaAssetRepository? repository,
    EmbeddedToolResolver? toolResolver,
    ProcessRunner? processRunner,
    FfmpegPathResolver? ffmpegPathResolver,
  }) : _repository = repository ?? MediaAssetRepository(),
       _toolResolver = toolResolver ?? const EmbeddedToolResolver(),
       _processRunner = processRunner ?? _defaultProcessRunner,
       _ffmpegPathResolver = ffmpegPathResolver;

  final MediaAssetRepository _repository;
  final EmbeddedToolResolver _toolResolver;
  final ProcessRunner _processRunner;
  final FfmpegPathResolver? _ffmpegPathResolver;
  final Map<String, Process> _processes = {};

  Future<ClipExportRecord> exportCandidate({
    required MediaAsset asset,
    required ClipCandidate candidate,
    required DownloadSettings settings,
    ClipExportProgressChanged? onProgress,
  }) async {
    final recordId = '${asset.id}#export:${candidate.id}';
    final outputPath = _outputPath(asset, candidate, settings);
    final createdAt = DateTime.now();
    final pending = ClipExportRecord(
      id: recordId,
      mediaAssetId: asset.id,
      candidateId: candidate.id,
      startMs: candidate.startMs,
      endMs: candidate.endMs,
      outputPath: outputPath,
      status: ClipExportStatus.cutting,
      progress: 5,
      runtime: MediaJobRuntime.local,
      createdAt: createdAt,
    );
    await _repository.saveClipExportRecord(pending);

    try {
      await Directory(File(outputPath).parent.path).create(recursive: true);
      final process = await _processRunner(
        _ffmpegPathResolver?.call(settings) ?? _resolveFfmpegPath(settings),
        FfmpegClipExecutor.buildClipArguments(
          sourcePath: asset.mediaPath,
          outputPath: outputPath,
          start: Duration(milliseconds: candidate.startMs),
          duration: Duration(milliseconds: candidate.durationMs),
        ),
      );
      _processes[recordId] = process;
      final stdoutDone = process.stdout.drain<void>();
      var latest = pending;
      var lastProgress = pending.progress;
      final stderrDone = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .asyncMap((line) async {
            final progress = _parseFfmpegProgress(
              line,
              totalMs: candidate.durationMs,
            );
            if (progress == null || progress <= lastProgress) return;
            lastProgress = progress.clamp(5, 99);
            latest = latest.copyWith(progress: lastProgress);
            await _repository.saveClipExportRecord(latest);
            onProgress?.call(latest, lastProgress);
          })
          .drain<void>();
      final exitCode = await process.exitCode;
      await Future.wait([stdoutDone, stderrDone]);
      _processes.remove(recordId);

      if (exitCode == 0) {
        final completed = pending.copyWith(
          status: ClipExportStatus.completed,
          progress: 100,
          completedAt: DateTime.now(),
        );
        await _repository.saveClipExportRecord(completed);
        return completed;
      }

      final failed = pending.copyWith(
        status: ClipExportStatus.failed,
        progress: 0,
        errorMessage: 'ffmpeg exited with code $exitCode',
        completedAt: DateTime.now(),
      );
      await _repository.saveClipExportRecord(failed);
      return failed;
    } catch (error) {
      _processes.remove(recordId);
      final failed = pending.copyWith(
        status: ClipExportStatus.failed,
        progress: 0,
        errorMessage: error.toString(),
        completedAt: DateTime.now(),
      );
      await _repository.saveClipExportRecord(failed);
      return failed;
    }
  }

  Future<void> cancel(String recordId) async {
    final process = _processes.remove(recordId);
    process?.kill(ProcessSignal.sigterm);
  }

  String _resolveFfmpegPath(DownloadSettings settings) {
    final bundle = _toolResolver.resolveBundle(settings: settings);
    return bundle.ffmpeg.isCustom
        ? bundle.ffmpeg.path
        : bundle.ffmpeg.fallbackPath ?? bundle.ffmpeg.path;
  }

  String _outputPath(
    MediaAsset asset,
    ClipCandidate candidate,
    DownloadSettings settings,
  ) {
    final sourceName = asset.mediaPath.split(Platform.pathSeparator).last;
    final dot = sourceName.lastIndexOf('.');
    final ext = dot > 0 ? sourceName.substring(dot) : '.mp4';
    final safeAssetId = _safePathPart(asset.id);
    final safeCandidateId = _safePathPart(candidate.id);
    return [
      settings.normalized().saveDirectory,
      '.clips',
      '${safeAssetId}_$safeCandidateId$ext',
    ].join(Platform.pathSeparator);
  }

  String _safePathPart(String value) {
    final sanitized = value
        .replaceAll(RegExp(r'[^A-Za-z0-9_.-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return sanitized.isEmpty ? value.hashCode.toString() : sanitized;
  }

  int? _parseFfmpegProgress(String line, {required int totalMs}) {
    if (totalMs <= 0) return null;
    final match = RegExp(
      r'time=(\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?',
    ).firstMatch(line);
    if (match == null) return null;

    final hours = int.tryParse(match.group(1) ?? '') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
    final seconds = int.tryParse(match.group(3) ?? '') ?? 0;
    final fraction = match.group(4) ?? '';
    final fractionMs = fraction.isEmpty
        ? 0
        : int.parse(fraction.padRight(3, '0').substring(0, 3));
    final elapsedMs =
        (((hours * 60 + minutes) * 60 + seconds) * 1000) + fractionMs;
    return ((elapsedMs / totalMs) * 100).floor().clamp(0, 99);
  }
}

Future<Process> _defaultProcessRunner(
  String executable,
  List<String> arguments,
) {
  return Process.start(executable, arguments, runInShell: false);
}
