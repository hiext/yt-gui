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
    this.fallbackPath,
  });

  final EmbeddedToolKind kind;
  final String path;
  final bool isCustom;
  final String? fallbackPath;
}

class EmbeddedToolResolver {
  const EmbeddedToolResolver({
    this.manifest = EmbeddedToolManifest.bundled,
    this.platformOverride,
    this.environment,
    this.fileExists,
  });

  final EmbeddedToolManifest manifest;
  final EmbeddedToolPlatform? platformOverride;
  final Map<String, String>? environment;
  final bool Function(String path)? fileExists;

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
      if (!_fileExists(customPath)) {
        final customExecutable = _findCustomExecutableOnPath(
          platform: platform,
          command: customPath,
          environment: environment ?? Platform.environment,
        );
        if (customExecutable != null) {
          return ResolvedEmbeddedTool(
            kind: kind,
            path: customExecutable,
            isCustom: true,
          );
        }
        throw EmbeddedToolResolutionException(
          'Configured ${kind.baseExecutableName} path does not exist: $customPath',
        );
      }

      return ResolvedEmbeddedTool(kind: kind, path: customPath, isCustom: true);
    }

    final spec = manifest.resolve(platform: platform, kind: kind);
    final systemPath = _findExecutableOnPath(
      platform: platform,
      spec: spec,
      environment: environment ?? Platform.environment,
    );

    if (_fileExists(spec.assetPath)) {
      return ResolvedEmbeddedTool(
        kind: kind,
        path: spec.assetPath,
        isCustom: false,
        fallbackPath: systemPath,
      );
    }

    if (systemPath != null) {
      return ResolvedEmbeddedTool(
        kind: kind,
        path: spec.assetPath,
        isCustom: false,
        fallbackPath: systemPath,
      );
    }

    return ResolvedEmbeddedTool(
      kind: kind,
      path: spec.assetPath,
      isCustom: false,
    );
  }

  String? _findExecutableOnPath({
    required EmbeddedToolPlatform platform,
    required EmbeddedToolSpec spec,
    required Map<String, String> environment,
  }) {
    final pathValue = environment['PATH'];
    final pathSeparator = platform == EmbeddedToolPlatform.windows ? ';' : ':';
    final executableNames = _pathExecutableNames(
      platform: platform,
      spec: spec,
      environment: environment,
    );
    final directories = <String>[
      if (pathValue != null && pathValue.trim().isNotEmpty)
        ...pathValue.split(pathSeparator),
      ..._wellKnownToolDirectories(platform, environment),
    ];
    final checkedDirectories = <String>{};
    for (final rawDir in directories) {
      final dir = rawDir.trim();
      if (dir.isEmpty || !checkedDirectories.add(dir)) continue;
      for (final executableName in executableNames) {
        final candidate = _joinPath(dir, executableName);
        if (_fileExists(candidate)) {
          return File(candidate).absolute.path;
        }
      }
    }
    return null;
  }

  String? _findCustomExecutableOnPath({
    required EmbeddedToolPlatform platform,
    required String command,
    required Map<String, String> environment,
  }) {
    if (command.contains('/') || command.contains(r'\')) return null;

    final pathValue = environment['PATH'];
    final pathSeparator = platform == EmbeddedToolPlatform.windows ? ';' : ':';
    final directories = <String>[
      if (pathValue != null && pathValue.trim().isNotEmpty)
        ...pathValue.split(pathSeparator),
      ..._wellKnownToolDirectories(platform, environment),
    ];
    final checkedDirectories = <String>{};
    for (final rawDir in directories) {
      final dir = rawDir.trim();
      if (dir.isEmpty || !checkedDirectories.add(dir)) continue;
      final candidate = _joinPath(dir, command);
      if (_fileExists(candidate)) {
        return File(candidate).absolute.path;
      }
    }
    return null;
  }

  List<String> _wellKnownToolDirectories(
    EmbeddedToolPlatform platform,
    Map<String, String> environment,
  ) {
    final home = environment['HOME']?.trim();
    if (platform == EmbeddedToolPlatform.windows) {
      return const <String>[];
    }
    return [
      if (home != null && home.isNotEmpty) '$home/.local/bin',
      '/opt/homebrew/bin',
      '/usr/local/bin',
      '/opt/local/bin',
      '/usr/bin',
      '/bin',
    ];
  }

  List<String> _pathExecutableNames({
    required EmbeddedToolPlatform platform,
    required EmbeddedToolSpec spec,
    required Map<String, String> environment,
  }) {
    final names = <String>{spec.executableName, spec.kind.baseExecutableName};
    if (platform == EmbeddedToolPlatform.windows) {
      final extensions =
          environment['PATHEXT']
              ?.split(';')
              .map((ext) => ext.trim())
              .where((ext) => ext.isNotEmpty)
              .toList() ??
          const ['.EXE', '.BAT', '.CMD'];
      for (final extension in extensions) {
        names.add('${spec.kind.baseExecutableName}$extension');
      }
    }
    return names.toList(growable: false);
  }

  String _joinPath(String directory, String executableName) {
    if (directory.endsWith('/') || directory.endsWith(r'\')) {
      return '$directory$executableName';
    }
    return '$directory${Platform.pathSeparator}$executableName';
  }

  bool _fileExists(String path) {
    return fileExists?.call(path) ?? File(path).existsSync();
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
