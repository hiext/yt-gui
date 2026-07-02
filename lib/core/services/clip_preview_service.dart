import 'dart:io';

import '../models/app_models.dart';
import 'embedded_tool_executable.dart';
import 'embedded_tool_resolver.dart';
import 'process_yt_dlp_executor.dart' show ProcessRunner;

typedef ClipPreviewPathResolver =
    Future<String?> Function(
      MediaAsset asset,
      ClipCandidate candidate,
      ClipExportRecord? export,
    );

class ClipPreviewService {
  ClipPreviewService({
    EmbeddedToolResolver? toolResolver,
    ProcessRunner? processRunner,
    EmbeddedToolExecutableResolver? executableResolver,
  }) : _toolResolver = toolResolver ?? const EmbeddedToolResolver(),
       _processRunner = processRunner ?? _defaultProcessRunner,
       _executableResolver =
           executableResolver ?? EmbeddedToolExecutableResolver();

  final EmbeddedToolResolver _toolResolver;
  final ProcessRunner _processRunner;
  final EmbeddedToolExecutableResolver _executableResolver;

  Future<String?> resolvePreviewPath({
    required MediaAsset asset,
    required ClipCandidate candidate,
    ClipExportRecord? export,
    DownloadSettings settings = DownloadSettings.defaults,
  }) async {
    if (asset.thumbnailPath != null &&
        asset.thumbnailPath!.trim().isNotEmpty &&
        File(asset.thumbnailPath!).existsSync()) {
      return asset.thumbnailPath;
    }

    final inputPath = _inputPath(asset, export);
    if (inputPath == null || !File(inputPath).existsSync()) return null;

    final previewPath = _previewPath(asset, candidate, export);
    final previewFile = File(previewPath);
    if (previewFile.existsSync() && previewFile.lengthSync() > 0) {
      return previewPath;
    }

    try {
      await previewFile.parent.create(recursive: true);
      final seekMs =
          export != null &&
              export.status == ClipExportStatus.completed &&
              export.outputPath.trim().isNotEmpty
          ? 0
          : candidate.startMs;
      final process = await _processRunner(await _resolveFfmpegPath(settings), [
        '-y',
        '-ss',
        _formatFfmpegTime(seekMs),
        '-i',
        inputPath,
        '-frames:v',
        '1',
        '-vf',
        'scale=480:-1',
        previewPath,
      ]);
      await process.stdout.drain<void>();
      await process.stderr.drain<void>();
      final exitCode = await process.exitCode;
      if (exitCode == 0 &&
          previewFile.existsSync() &&
          previewFile.lengthSync() > 0) {
        return previewPath;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String? _inputPath(MediaAsset asset, ClipExportRecord? export) {
    if (export != null &&
        export.outputPath.trim().isNotEmpty &&
        export.status == ClipExportStatus.completed) {
      return export.outputPath;
    }
    return asset.mediaType == MediaAssetType.video ? asset.mediaPath : null;
  }

  String _previewPath(
    MediaAsset asset,
    ClipCandidate candidate,
    ClipExportRecord? export,
  ) {
    final baseDir = export != null && export.outputPath.trim().isNotEmpty
        ? File(export.outputPath).parent.path
        : File(asset.mediaPath).parent.path;
    return [
      baseDir,
      'previews',
      '${_safePathPart(asset.id)}_${_safePathPart(candidate.id)}.jpg',
    ].join(Platform.pathSeparator);
  }

  Future<String> _resolveFfmpegPath(DownloadSettings settings) {
    final bundle = _toolResolver.resolveBundle(settings: settings);
    return _executableResolver.ensureExecutable(bundle.ffmpeg);
  }

  String _formatFfmpegTime(int ms) {
    final totalSeconds = ms ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(hours)}:${two(minutes)}:${two(seconds)}';
  }

  String _safePathPart(String value) {
    final sanitized = value
        .replaceAll(RegExp(r'[^A-Za-z0-9_.-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return sanitized.isEmpty ? value.hashCode.toString() : sanitized;
  }
}

Future<Process> _defaultProcessRunner(
  String executable,
  List<String> arguments,
) {
  return Process.start(executable, arguments, runInShell: false);
}
