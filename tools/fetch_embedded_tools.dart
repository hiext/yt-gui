import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final options = _Options.parse(args);
  if (options.help) {
    _printHelp();
    return;
  }

  final lockFile = File(options.lockPath);
  if (!lockFile.existsSync()) {
    throw _ToolException('Lock file not found: ${lockFile.path}');
  }

  final lock = jsonDecode(await lockFile.readAsString());
  if (lock is! Map<String, Object?>) {
    throw _ToolException('Invalid lock file root: expected JSON object');
  }

  final rawArtifacts = lock['artifacts'];
  if (rawArtifacts is! List) {
    throw _ToolException('Invalid lock file: missing artifacts array');
  }

  final artifacts = rawArtifacts
      .whereType<Map<String, Object?>>()
      .map(_ToolArtifact.fromJson)
      .where(options.matches)
      .toList(growable: false);

  if (artifacts.isEmpty) {
    throw _ToolException('No artifacts matched the requested filters.');
  }

  final tempDir = Directory.systemTemp.createTempSync('hiext-embedded-tools-');
  try {
    var installed = 0;
    var skipped = 0;
    for (final artifact in artifacts) {
      if (artifact.manual) {
        skipped++;
        final reason = artifact.manualReason ?? 'manual artifact';
        if (options.includeManual) {
          throw _ToolException('${artifact.id} requires manual setup: $reason');
        }
        stdout.writeln('skip ${artifact.id}: $reason');
        continue;
      }

      stdout.writeln(
        '${options.dryRun ? 'plan' : 'fetch'} ${artifact.id} -> '
        '${artifact.output}',
      );

      if (options.dryRun) {
        continue;
      }

      await artifact.install(tempDir);
      installed++;
    }

    stdout.writeln(
      'done: ${options.dryRun ? 'planned' : 'installed'} '
      '${artifacts.length - skipped}, skipped $skipped',
    );
    if (!options.dryRun && installed > 0) {
      stdout.writeln('Run flutter build after verifying licenses and notices.');
    }
  } finally {
    if (!options.keepTemp) {
      tempDir.deleteSync(recursive: true);
    } else {
      stdout.writeln('kept temp directory: ${tempDir.path}');
    }
  }
}

class _Options {
  const _Options({
    required this.lockPath,
    required this.platforms,
    required this.tools,
    required this.dryRun,
    required this.keepTemp,
    required this.includeManual,
    required this.help,
  });

  final String lockPath;
  final Set<String>? platforms;
  final Set<String>? tools;
  final bool dryRun;
  final bool keepTemp;
  final bool includeManual;
  final bool help;

  static _Options parse(List<String> args) {
    var lockPath = 'tools/embedded_tools.lock.json';
    Set<String>? platforms;
    Set<String>? tools;
    var dryRun = false;
    var keepTemp = false;
    var includeManual = false;
    var help = false;

    for (final arg in args) {
      if (arg == '--help' || arg == '-h') {
        help = true;
      } else if (arg == '--dry-run') {
        dryRun = true;
      } else if (arg == '--keep-temp') {
        keepTemp = true;
      } else if (arg == '--include-manual') {
        includeManual = true;
      } else if (arg.startsWith('--lock=')) {
        lockPath = arg.substring('--lock='.length);
      } else if (arg.startsWith('--platform=')) {
        platforms = _csv(arg.substring('--platform='.length));
      } else if (arg.startsWith('--tool=')) {
        tools = _csv(arg.substring('--tool='.length));
      } else {
        throw _ToolException('Unknown argument: $arg');
      }
    }

    return _Options(
      lockPath: lockPath,
      platforms: platforms,
      tools: tools,
      dryRun: dryRun,
      keepTemp: keepTemp,
      includeManual: includeManual,
      help: help,
    );
  }

  bool matches(_ToolArtifact artifact) {
    final platformMatch =
        platforms == null || platforms!.contains(artifact.platform);
    final toolMatch = tools == null || tools!.contains(artifact.tool);
    return platformMatch && toolMatch;
  }

  static Set<String> _csv(String value) => value
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toSet();
}

class _ToolArtifact {
  const _ToolArtifact({
    required this.id,
    required this.tool,
    required this.platform,
    required this.output,
    required this.archiveType,
    required this.chmod,
    this.url,
    this.mirrors = const <String>[],
    this.sha256,
    this.extract,
    this.manual = false,
    this.manualReason,
  });

  final String id;
  final String tool;
  final String platform;
  final String output;
  final String archiveType;
  final bool chmod;
  final String? url;
  final List<String> mirrors;
  final String? sha256;
  final String? extract;
  final bool manual;
  final String? manualReason;

  factory _ToolArtifact.fromJson(Map<String, Object?> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      throw _ToolException(
        'Artifact ${json['id'] ?? '<unknown>'}: '
        'missing string "$key"',
      );
    }

    String? optionalString(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is String && value.trim().isNotEmpty) return value.trim();
      throw _ToolException(
        'Artifact ${json['id'] ?? '<unknown>'}: '
        'invalid string "$key"',
      );
    }

    List<String> optionalStringList(String key) {
      final value = json[key];
      if (value == null) return const <String>[];
      if (value is! List) {
        throw _ToolException(
          'Artifact ${json['id'] ?? '<unknown>'}: '
          'invalid string list "$key"',
        );
      }
      return value
          .whereType<String>()
          .map((entry) => entry.trim())
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false);
    }

    return _ToolArtifact(
      id: requiredString('id'),
      tool: requiredString('tool'),
      platform: requiredString('platform'),
      output: requiredString('output'),
      archiveType: optionalString('archiveType') ?? 'file',
      chmod: json['chmod'] == true,
      url: optionalString('url'),
      mirrors: optionalStringList('mirrors'),
      sha256: optionalString('sha256'),
      extract: optionalString('extract'),
      manual: json['manual'] == true,
      manualReason: optionalString('manualReason'),
    );
  }

  Future<void> install(Directory tempDir) async {
    if ((url == null && mirrors.isEmpty) || sha256 == null) {
      throw _ToolException('$id is missing url or sha256');
    }

    final downloadFile = File('${tempDir.path}${Platform.pathSeparator}$id');
    await _downloadVerified(downloadFile);

    final outputFile = File(output);
    outputFile.parent.createSync(recursive: true);

    if (archiveType == 'file') {
      await downloadFile.copy(outputFile.path);
    } else {
      final extracted = await _extract(downloadFile, tempDir);
      await extracted.copy(outputFile.path);
    }

    if (chmod && !Platform.isWindows) {
      await _run('chmod', ['+x', outputFile.path]);
    }
  }

  Future<void> _downloadVerified(File target) async {
    final urls = [
      ?url,
      ...mirrors,
    ];
    final failures = <String>[];

    for (final rawUrl in urls) {
      try {
        if (target.existsSync()) target.deleteSync();
        stdout.writeln('  source $rawUrl');
        await _download(Uri.parse(rawUrl), target);
        final actualSha = await _sha256(target);
        if (actualSha.toLowerCase() == sha256!.toLowerCase()) {
          return;
        }
        failures.add(
          '$rawUrl checksum mismatch, expected $sha256, actual $actualSha',
        );
      } catch (error) {
        failures.add('$rawUrl failed: $error');
      }
    }

    throw _ToolException(
      '$id could not be downloaded from primary source or mirrors:\n'
      '${failures.map((failure) => '- $failure').join('\n')}',
    );
  }

  Future<File> _extract(File archive, Directory tempDir) async {
    if (extract == null) {
      throw _ToolException('$id archive is missing extract path');
    }

    final extractDir = Directory(
      '${tempDir.path}${Platform.pathSeparator}${id}_extract',
    )..createSync(recursive: true);

    if (archiveType == 'zip') {
      if (Platform.isWindows) {
        await _run('powershell', [
          '-NoProfile',
          '-Command',
          'Expand-Archive -LiteralPath "${archive.path}" '
              '-DestinationPath "${extractDir.path}" -Force',
        ]);
      } else {
        await _run('unzip', ['-q', archive.path, '-d', extractDir.path]);
      }
    } else if (archiveType == 'tar.xz') {
      await _run('tar', ['-xJf', archive.path, '-C', extractDir.path]);
    } else {
      throw _ToolException('$id has unsupported archiveType: $archiveType');
    }

    final normalizedExtract = extract!.replaceAll(r'\', '/');
    final candidates = extractDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) {
          final normalizedPath = file.path.replaceAll(r'\', '/');
          return normalizedPath.endsWith('/$normalizedExtract') ||
              normalizedPath.endsWith(normalizedExtract);
        })
        .toList(growable: false);

    if (candidates.isEmpty) {
      throw _ToolException('$id did not contain expected file: $extract');
    }

    return candidates.first;
  }
}

Future<void> _download(Uri url, File target) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(url);
    request.followRedirects = true;
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _ToolException('Download failed (${response.statusCode}): $url');
    }

    final sink = target.openWrite();
    await response.pipe(sink);
  } finally {
    client.close(force: true);
  }
}

Future<String> _sha256(File file) async {
  final commands = Platform.isWindows
      ? [
          ['certutil', '-hashfile', file.path, 'SHA256'],
        ]
      : [
          ['shasum', '-a', '256', file.path],
          ['sha256sum', file.path],
          ['openssl', 'dgst', '-sha256', file.path],
        ];

  for (final command in commands) {
    final result = await Process.run(command.first, command.skip(1).toList());
    if (result.exitCode != 0) continue;
    final match = RegExp(
      r'\b[a-fA-F0-9]{64}\b',
    ).firstMatch('${result.stdout}\n${result.stderr}');
    if (match != null) {
      return match.group(0)!.toLowerCase();
    }
  }

  throw _ToolException(
    'Unable to compute SHA256. Install shasum, sha256sum, openssl, or certutil.',
  );
}

Future<void> _run(String executable, List<String> arguments) async {
  final result = await Process.run(executable, arguments);
  if (result.exitCode != 0) {
    throw _ToolException(
      '$executable failed with exit ${result.exitCode}\n'
      '${result.stdout}\n${result.stderr}',
    );
  }
}

void _printHelp() {
  stdout.writeln('''
Fetch locked yt-dlp/ffmpeg binaries into assets/bin/<platform>/.

Usage:
  dart run tools/fetch_embedded_tools.dart [options]

Options:
  --platform=linux,macos,windows  Limit platforms.
  --tool=yt-dlp,ffmpeg            Limit tools.
  --lock=PATH                     Lock file path.
  --dry-run                       Show planned downloads only.
  --keep-temp                     Keep downloaded archives for debugging.
  --include-manual                Fail on manual entries instead of skipping.
  --help                          Show this help.

Examples:
  dart run tools/fetch_embedded_tools.dart --dry-run
  dart run tools/fetch_embedded_tools.dart --platform=macos --tool=yt-dlp
  dart run tools/fetch_embedded_tools.dart --platform=linux,windows
''');
}

class _ToolException implements Exception {
  const _ToolException(this.message);

  final String message;

  @override
  String toString() => message;
}
