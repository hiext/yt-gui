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
    this.isBundledAsset = false,
    this.fallbackPath,
  });

  final EmbeddedToolKind kind;
  final String path;
  final bool isCustom;
  final bool isBundledAsset;
  final String? fallbackPath;
}

class EmbeddedToolResolver {
  const EmbeddedToolResolver({
    this.manifest = EmbeddedToolManifest.bundled,
    this.platformOverride,
    this.environment,
    this.fileExists,
    this.resolvedExecutablePath,
  });

  final EmbeddedToolManifest manifest;
  final EmbeddedToolPlatform? platformOverride;
  final Map<String, String>? environment;
  final bool Function(String path)? fileExists;
  final String? resolvedExecutablePath;

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

  ResolvedEmbeddedTool resolveExecutable({
    required EmbeddedToolKind kind,
    DownloadSettings settings = DownloadSettings.defaults,
    bool allowMissingCustomFallback = false,
  }) {
    final normalizedSettings = settings.normalized();
    final resolvedPlatform = platform;
    final customTool = _resolveCustomTool(
      platform: resolvedPlatform,
      kind: kind,
      customPath: _customPathForKind(kind, normalizedSettings),
      allowMissingCustomFallback: allowMissingCustomFallback,
    );
    if (customTool != null) return customTool;

    final spec = manifest.resolve(platform: resolvedPlatform, kind: kind);
    final systemPath = _findExecutableOnPath(
      platform: resolvedPlatform,
      spec: spec,
      environment: environment ?? Platform.environment,
    );

    for (final candidate in bundledExecutableCandidates(kind: kind)) {
      if (_fileExists(candidate)) {
        return ResolvedEmbeddedTool(
          kind: kind,
          path: candidate,
          isCustom: false,
          fallbackPath: systemPath,
        );
      }
    }

    if (systemPath != null) {
      return ResolvedEmbeddedTool(
        kind: kind,
        path: systemPath,
        isCustom: false,
      );
    }

    return ResolvedEmbeddedTool(
      kind: kind,
      path: spec.executableName,
      isCustom: false,
    );
  }

  List<String> bundledExecutableCandidates({required EmbeddedToolKind kind}) {
    final resolvedPlatform = platform;
    final spec = manifest.resolve(platform: resolvedPlatform, kind: kind);
    final executable = resolvedExecutablePath ?? Platform.resolvedExecutable;
    final executableDir = _parentPath(executable, resolvedPlatform);
    final assetParts = spec.assetPath.split('/');
    final candidates = <String>[
      spec.assetPath,
      _joinPathSegments(resolvedPlatform, [
        executableDir,
        'data',
        'flutter_assets',
        ...assetParts,
      ]),
    ];

    if (resolvedPlatform == EmbeddedToolPlatform.macos) {
      final contentsDir =
          _lastPathSegment(executableDir, resolvedPlatform) == 'MacOS'
          ? _parentPath(executableDir, resolvedPlatform)
          : executableDir;
      candidates.addAll([
        _joinPathSegments(resolvedPlatform, [
          contentsDir,
          'Frameworks',
          'App.framework',
          'Versions',
          'A',
          'Resources',
          'flutter_assets',
          ...assetParts,
        ]),
        _joinPathSegments(resolvedPlatform, [
          contentsDir,
          'Resources',
          'flutter_assets',
          ...assetParts,
        ]),
      ]);
    }

    return candidates;
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
          _validateCustomToolPath(kind, customExecutable);
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

      _validateCustomToolPath(kind, customPath);
      return ResolvedEmbeddedTool(kind: kind, path: customPath, isCustom: true);
    }

    final spec = manifest.resolve(platform: platform, kind: kind);
    final systemPath = _findExecutableOnPath(
      platform: platform,
      spec: spec,
      environment: environment ?? Platform.environment,
    );

    if (systemPath != null) {
      return ResolvedEmbeddedTool(
        kind: kind,
        path: systemPath,
        isCustom: false,
        fallbackPath: spec.assetPath,
      );
    }

    return ResolvedEmbeddedTool(
      kind: kind,
      path: spec.assetPath,
      isCustom: false,
      isBundledAsset: true,
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
        final candidate = _joinPathSegments(platform, [dir, executableName]);
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
      final candidate = _joinPathSegments(platform, [dir, command]);
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

  String _parentPath(String path, EmbeddedToolPlatform platform) {
    final index = _lastSeparatorIndex(path, platform);
    if (index <= 0) return '.';
    return path.substring(0, index);
  }

  String _lastPathSegment(String path, EmbeddedToolPlatform platform) {
    final index = _lastSeparatorIndex(path, platform);
    return index < 0 ? path : path.substring(index + 1);
  }

  int _lastSeparatorIndex(String path, EmbeddedToolPlatform platform) {
    final slash = path.lastIndexOf('/');
    if (platform != EmbeddedToolPlatform.windows) return slash;
    final backslash = path.lastIndexOf(r'\');
    return slash > backslash ? slash : backslash;
  }

  String _joinPathSegments(
    EmbeddedToolPlatform platform,
    List<String> segments,
  ) {
    final cleanSegments = segments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (cleanSegments.isEmpty) return '';
    final separator = _separatorForJoin(platform, cleanSegments.first);

    final buffer = StringBuffer(
      _trimTrailingSeparators(cleanSegments.first, platform),
    );
    for (final rawSegment in cleanSegments.skip(1)) {
      final segment = _trimPathSeparators(rawSegment, platform);
      if (segment.isEmpty) continue;
      final current = buffer.toString();
      if (!current.endsWith('/') && !current.endsWith(r'\')) {
        buffer.write(separator);
      }
      buffer.write(segment);
    }
    return buffer.toString();
  }

  String _separatorForJoin(EmbeddedToolPlatform platform, String firstSegment) {
    if (platform != EmbeddedToolPlatform.windows) return '/';
    if (firstSegment.contains('/') && !firstSegment.contains(r'\')) return '/';
    return r'\';
  }

  String _trimPathSeparators(String value, EmbeddedToolPlatform platform) {
    var trimmed = value;
    while (trimmed.startsWith('/') || trimmed.startsWith(r'\')) {
      trimmed = trimmed.substring(1);
    }
    return _trimTrailingSeparators(trimmed, platform);
  }

  String _trimTrailingSeparators(String value, EmbeddedToolPlatform platform) {
    var trimmed = value;
    while (trimmed.length > 1 &&
        (trimmed.endsWith('/') || trimmed.endsWith(r'\'))) {
      if (platform == EmbeddedToolPlatform.windows &&
          RegExp(r'^[A-Za-z]:\\$').hasMatch(trimmed)) {
        break;
      }
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  bool _fileExists(String path) {
    return fileExists?.call(path) ?? File(path).existsSync();
  }

  void _validateCustomToolPath(EmbeddedToolKind kind, String path) {
    final fileName = path
        .split(RegExp(r'[/\\]+'))
        .where((part) => part.isNotEmpty)
        .lastOrNull
        ?.toLowerCase();
    if (fileName == null) return;
    final expected = kind.baseExecutableName.toLowerCase();
    final validNames = {expected, '$expected.exe'};
    if (validNames.contains(fileName)) return;

    throw EmbeddedToolResolutionException(
      'Configured ${kind.baseExecutableName} path does not look like '
      '${kind.baseExecutableName}: $path. Choose the real '
      '${kind.baseExecutableName} executable and verify it with '
      '"${kind.baseExecutableName} --version".',
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
