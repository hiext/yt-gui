import 'dart:io';

import 'embedded_tool_manifest.dart';

class EmbeddedToolBundle {
  const EmbeddedToolBundle({required this.ytDlp, required this.ffmpeg});

  final EmbeddedToolSpec ytDlp;
  final EmbeddedToolSpec ffmpeg;
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

  EmbeddedToolBundle resolveBundle() {
    final resolvedPlatform = platform;

    return EmbeddedToolBundle(
      ytDlp: manifest.resolve(
        platform: resolvedPlatform,
        kind: EmbeddedToolKind.ytDlp,
      ),
      ffmpeg: manifest.resolve(
        platform: resolvedPlatform,
        kind: EmbeddedToolKind.ffmpeg,
      ),
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
