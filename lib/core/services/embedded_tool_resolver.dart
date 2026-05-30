import 'dart:io';

import '../models/app_models.dart';
import 'embedded_tool_manifest.dart';

class EmbeddedToolBundle {
  const EmbeddedToolBundle({required this.ytDlp, required this.ffmpeg});

  final ResolvedEmbeddedTool ytDlp;
  final ResolvedEmbeddedTool ffmpeg;
}

class ResolvedEmbeddedTool {
  const ResolvedEmbeddedTool({
    required this.kind,
    required this.path,
    required this.isCustom,
  });

  final EmbeddedToolKind kind;
  final String path;
  final bool isCustom;
}

class EmbeddedToolResolver {
  const EmbeddedToolResolver({
    this.manifest = EmbeddedToolManifest.bundled,
    this.platformOverride,
  });

  final EmbeddedToolManifest manifest;
  final EmbeddedToolPlatform? platformOverride;

  EmbeddedToolPlatform get platform =>
      platformOverride ?? EmbeddedToolPlatformDetector.current();

  EmbeddedToolBundle resolveBundle({
    DownloadSettings settings = DownloadSettings.defaults,
  }) {
    final normalizedSettings = settings.normalized();
    final resolvedPlatform = platform;

    return EmbeddedToolBundle(
      ytDlp: _resolveTool(
        platform: resolvedPlatform,
        kind: EmbeddedToolKind.ytDlp,
        customPath: normalizedSettings.ytDlpPath,
      ),
      ffmpeg: _resolveTool(
        platform: resolvedPlatform,
        kind: EmbeddedToolKind.ffmpeg,
        customPath: normalizedSettings.ffmpegPath,
      ),
    );
  }

  ResolvedEmbeddedTool _resolveTool({
    required EmbeddedToolPlatform platform,
    required EmbeddedToolKind kind,
    required String? customPath,
  }) {
    if (customPath != null) {
      if (!File(customPath).existsSync()) {
        throw EmbeddedToolResolutionException(
          'Configured ${kind.baseExecutableName} path does not exist: $customPath',
        );
      }

      return ResolvedEmbeddedTool(kind: kind, path: customPath, isCustom: true);
    }

    final spec = manifest.resolve(platform: platform, kind: kind);
    return ResolvedEmbeddedTool(
      kind: kind,
      path: spec.assetPath,
      isCustom: false,
    );
  }
}

class EmbeddedToolPlatformDetector {
  const EmbeddedToolPlatformDetector._();

  static EmbeddedToolPlatform current() {
    return fromOperatingSystem(Platform.operatingSystem);
  }

  static EmbeddedToolPlatform fromOperatingSystem(String operatingSystem) {
    return switch (operatingSystem) {
      'linux' => EmbeddedToolPlatform.linux,
      'macos' => EmbeddedToolPlatform.macos,
      'windows' => EmbeddedToolPlatform.windows,
      _ => throw UnsupportedEmbeddedToolPlatformException(operatingSystem),
    };
  }
}

class UnsupportedEmbeddedToolPlatformException implements Exception {
  const UnsupportedEmbeddedToolPlatformException(this.operatingSystem);

  final String operatingSystem;

  @override
  String toString() => 'Unsupported desktop platform: $operatingSystem';
}

class EmbeddedToolResolutionException implements Exception {
  const EmbeddedToolResolutionException(this.message);

  final String message;

  @override
  String toString() => message;
}
