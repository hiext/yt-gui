enum EmbeddedToolPlatform {
  linux('linux'),
  macos('macos'),
  windows('windows');

  const EmbeddedToolPlatform(this.directoryName);

  final String directoryName;
}

enum EmbeddedToolKind {
  ytDlp('yt-dlp'),
  ffmpeg('ffmpeg');

  const EmbeddedToolKind(this.baseExecutableName);

  final String baseExecutableName;
}

class EmbeddedToolSpec {
  const EmbeddedToolSpec({
    required this.platform,
    required this.kind,
    required this.version,
  });

  final EmbeddedToolPlatform platform;
  final EmbeddedToolKind kind;
  final String version;

  String get executableName {
    if (platform == EmbeddedToolPlatform.windows) {
      return '${kind.baseExecutableName}.exe';
    }

    return kind.baseExecutableName;
  }

  String get assetPath =>
      'assets/bin/${platform.directoryName}/$executableName';
}

class EmbeddedToolManifest {
  const EmbeddedToolManifest({required this.specs});

  static const bundled = EmbeddedToolManifest(
    specs: [
      EmbeddedToolSpec(
        platform: EmbeddedToolPlatform.linux,
        kind: EmbeddedToolKind.ytDlp,
        version: 'bundled',
      ),
      EmbeddedToolSpec(
        platform: EmbeddedToolPlatform.linux,
        kind: EmbeddedToolKind.ffmpeg,
        version: 'bundled',
      ),
      EmbeddedToolSpec(
        platform: EmbeddedToolPlatform.macos,
        kind: EmbeddedToolKind.ytDlp,
        version: 'bundled',
      ),
      EmbeddedToolSpec(
        platform: EmbeddedToolPlatform.macos,
        kind: EmbeddedToolKind.ffmpeg,
        version: 'bundled',
      ),
      EmbeddedToolSpec(
        platform: EmbeddedToolPlatform.windows,
        kind: EmbeddedToolKind.ytDlp,
        version: 'bundled',
      ),
      EmbeddedToolSpec(
        platform: EmbeddedToolPlatform.windows,
        kind: EmbeddedToolKind.ffmpeg,
        version: 'bundled',
      ),
    ],
  );

  final List<EmbeddedToolSpec> specs;

  EmbeddedToolSpec resolve({
    required EmbeddedToolPlatform platform,
    required EmbeddedToolKind kind,
  }) {
    for (final spec in specs) {
      if (spec.platform == platform && spec.kind == kind) {
        return spec;
      }
    }

    throw EmbeddedToolManifestException(
      'Missing embedded tool spec: ${platform.directoryName}/${kind.baseExecutableName}',
    );
  }
}

class EmbeddedToolManifestException implements Exception {
  const EmbeddedToolManifestException(this.message);

  final String message;

  @override
  String toString() => message;
}
