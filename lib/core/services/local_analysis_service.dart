import 'dart:convert';
import 'dart:io';

import '../models/app_models.dart';
import 'embedded_tool_resolver.dart';
import 'media_asset_repository.dart';
import 'process_yt_dlp_executor.dart' show ProcessRunner;

typedef FfprobePathResolver = String Function(DownloadSettings settings);

class LocalAnalysisResult {
  const LocalAnalysisResult({
    required this.asset,
    required this.job,
    required this.candidates,
    required this.vectors,
  });

  final MediaAsset asset;
  final MediaAnalysisJob job;
  final List<ClipCandidate> candidates;
  final List<MediaVectorRecord> vectors;
}

class LocalAnalysisService {
  LocalAnalysisService({
    MediaAssetRepository? repository,
    EmbeddedToolResolver? toolResolver,
    ProcessRunner? processRunner,
    this._ffprobePathResolver,
  }) : _repository = repository ?? MediaAssetRepository(),
       _toolResolver = toolResolver ?? const EmbeddedToolResolver(),
       _processRunner = processRunner ?? _defaultProcessRunner;

  final MediaAssetRepository _repository;
  final EmbeddedToolResolver _toolResolver;
  final ProcessRunner _processRunner;
  final FfprobePathResolver? _ffprobePathResolver;

  Future<LocalAnalysisResult> analyze({
    required MediaAsset asset,
    required DownloadSettings settings,
    List<ClipSegment> seedSegments = const [],
  }) async {
    final createdAt = DateTime.now();
    final jobId =
        '${asset.id}#local-analysis-${createdAt.millisecondsSinceEpoch}';
    var job = MediaAnalysisJob(
      id: jobId,
      mediaAssetId: asset.id,
      runtime: MediaJobRuntime.local,
      status: MediaAnalysisStatus.running,
      progress: 0.1,
      stages: const ['metadata'],
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    await _repository.saveAnalysisJob(job);

    try {
      final ffprobe = await _runFfprobe(asset, settings);
      final updatedAsset = asset.copyWith(
        durationMs: _durationMs(ffprobe) ?? asset.durationMs,
        fileSizeBytes: _fileSizeBytes(ffprobe) ?? asset.fileSizeBytes,
        metadata: {
          ...asset.metadata,
          'ffprobe': ffprobe,
          'analysisRuntime': MediaJobRuntime.local.name,
          'analysisUpdatedAt': DateTime.now().toIso8601String(),
        },
        updatedAt: DateTime.now(),
      );
      await _repository.saveMediaAsset(updatedAsset);

      final candidates = _candidateRecords(updatedAsset, seedSegments);
      if (candidates.isNotEmpty) {
        await _repository.saveClipCandidates(candidates);
      }
      final vectors = _vectorRecords(updatedAsset, candidates);
      for (final vector in vectors) {
        await _repository.saveVectorRecord(vector);
      }

      job = job.copyWith(
        status: MediaAnalysisStatus.completed,
        progress: 1,
        stages: const ['metadata', 'candidate', 'embedding'],
        updatedAt: DateTime.now(),
      );
      await _repository.saveAnalysisJob(job);
      return LocalAnalysisResult(
        asset: updatedAsset,
        job: job,
        candidates: candidates,
        vectors: vectors,
      );
    } catch (error) {
      job = job.copyWith(
        status: MediaAnalysisStatus.failed,
        progress: 0,
        errorMessage: error.toString(),
        updatedAt: DateTime.now(),
      );
      await _repository.saveAnalysisJob(job);
      return LocalAnalysisResult(
        asset: asset,
        job: job,
        candidates: const [],
        vectors: const [],
      );
    }
  }

  Future<Map<String, Object?>> _runFfprobe(
    MediaAsset asset,
    DownloadSettings settings,
  ) async {
    final executable =
        _ffprobePathResolver?.call(settings) ?? _resolveFfprobePath(settings);
    final process = await _processRunner(executable, [
      '-v',
      'quiet',
      '-print_format',
      'json',
      '-show_format',
      '-show_streams',
      asset.mediaPath,
    ]);
    final stdoutFuture = process.stdout.transform(utf8.decoder).join();
    final stderrFuture = process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode;
    final stdout = await stdoutFuture;
    final stderr = await stderrFuture;
    if (exitCode != 0) {
      throw LocalAnalysisException(
        stderr.trim().isEmpty ? 'ffprobe exited with code $exitCode' : stderr,
      );
    }
    final decoded = jsonDecode(stdout.trim().isEmpty ? '{}' : stdout);
    if (decoded is! Map<String, Object?>) {
      throw const LocalAnalysisException('ffprobe returned non-object JSON');
    }
    return decoded;
  }

  String _resolveFfprobePath(DownloadSettings settings) {
    final normalized = settings.normalized();
    if (normalized.ffmpegPath != null) {
      final ffmpeg = File(normalized.ffmpegPath!);
      final name = Platform.isWindows ? 'ffprobe.exe' : 'ffprobe';
      final sibling = File(
        '${ffmpeg.parent.path}${Platform.pathSeparator}$name',
      );
      if (sibling.existsSync()) return sibling.path;
    }

    final bundle = _toolResolver.resolveBundle(settings: settings);
    final ffmpegPath = bundle.ffmpeg.isCustom
        ? bundle.ffmpeg.path
        : bundle.ffmpeg.fallbackPath ?? bundle.ffmpeg.path;
    if (ffmpegPath.endsWith('ffmpeg.exe')) {
      return ffmpegPath.replaceFirst(RegExp(r'ffmpeg\.exe$'), 'ffprobe.exe');
    }
    if (ffmpegPath.endsWith('ffmpeg')) {
      return ffmpegPath.replaceFirst(RegExp(r'ffmpeg$'), 'ffprobe');
    }
    return 'ffprobe';
  }

  int? _durationMs(Map<String, Object?> ffprobe) {
    final format = ffprobe['format'];
    if (format is! Map) return null;
    final duration = format['duration'];
    final seconds = duration is num
        ? duration.toDouble()
        : duration is String
        ? double.tryParse(duration)
        : null;
    if (seconds == null) return null;
    return (seconds * 1000).round();
  }

  int? _fileSizeBytes(Map<String, Object?> ffprobe) {
    final format = ffprobe['format'];
    if (format is! Map) return null;
    final size = format['size'];
    if (size is num) return size.toInt();
    if (size is String) return int.tryParse(size);
    return null;
  }

  List<ClipCandidate> _candidateRecords(
    MediaAsset asset,
    List<ClipSegment> segments,
  ) {
    return segments
        .map((segment) {
          return ClipCandidate(
            id: 'local:${segment.id}',
            mediaAssetId: asset.id,
            startMs: segment.effectiveStartMs,
            endMs: segment.effectiveEndMs,
            title: segment.title,
            summary: segment.summary,
            tags: segment.tags,
            keywords: segment.keywords,
            score: segment.confidence,
            scoreBreakdown: {'localConfidence': segment.confidence},
            evidenceIds: [
              'clip_segment:${segment.id}',
              ...segment.transcripts.map((t) => 'transcript:${t.id}'),
              ...segment.detections.map((d) => 'detection:${d.id}'),
            ],
            reason: segment.reason,
            source: ClipCandidateSource.local,
            createdAt: segment.createdAt,
          );
        })
        .toList(growable: false);
  }

  List<MediaVectorRecord> _vectorRecords(
    MediaAsset asset,
    List<ClipCandidate> candidates,
  ) {
    return [
      MediaVectorRecord(
        id: '${asset.id}#vector:metadata',
        mediaAssetId: asset.id,
        targetType: MediaVectorTargetType.media,
        targetId: asset.id,
        modality: MediaVectorModality.text,
        model: 'local-keyword-hash-v1',
        dimension: 16,
        vector: _hashVector('${asset.title} ${asset.sourceUrl}'),
        payload: {'title': asset.title, 'sourceUrl': asset.sourceUrl},
      ),
      for (final candidate in candidates)
        MediaVectorRecord(
          id: '${asset.id}#vector:${candidate.id}',
          mediaAssetId: asset.id,
          targetType: MediaVectorTargetType.candidate,
          targetId: candidate.id,
          startMs: candidate.startMs,
          endMs: candidate.endMs,
          modality: MediaVectorModality.text,
          model: 'local-keyword-hash-v1',
          dimension: 16,
          vector: _hashVector(
            [
              candidate.title,
              candidate.summary,
              candidate.reason,
              ...candidate.tags,
              ...candidate.keywords,
            ].join(' '),
          ),
          payload: {
            'title': candidate.title,
            'summary': candidate.summary,
            'reason': candidate.reason,
          },
        ),
    ];
  }

  List<double> _hashVector(String text) {
    final buckets = List<double>.filled(16, 0);
    final tokens = text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9\u4e00-\u9fa5]+'))
        .where((token) => token.isNotEmpty);
    for (final token in tokens) {
      final index = token.runes.fold<int>(0, (sum, rune) => sum + rune) % 16;
      buckets[index] += 1;
    }
    final total = buckets.fold<double>(0, (sum, value) => sum + value);
    if (total == 0) return buckets;
    return buckets.map((value) => value / total).toList(growable: false);
  }
}

class LocalAnalysisException implements Exception {
  const LocalAnalysisException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<Process> _defaultProcessRunner(
  String executable,
  List<String> arguments,
) {
  return Process.start(executable, arguments, runInShell: false);
}
