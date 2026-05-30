import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

import '../models/app_models.dart';
import 'embedded_tool_resolver.dart';
import 'yt_dlp_progress_parser.dart';
import 'yt_dlp_session.dart';
import 'yt_dlp_executor.dart';

class ProcessYtDlpExecutor implements YtDlpExecutor {
  ProcessYtDlpExecutor({
    EmbeddedToolResolver? toolResolver,
    ProcessRunner? processRunner,
  }) : _toolResolver = toolResolver ?? const EmbeddedToolResolver(),
       _processRunner = processRunner ?? _defaultProcessRunner;

  final EmbeddedToolResolver _toolResolver;
  final ProcessRunner _processRunner;
  final Map<String, YtDlpSession> _sessions = {};
  final Map<String, Process> _processes = {};
  final Set<String> _intentionalStops = {};
  final Map<String, String> _extractedPaths = {};

  Future<String> _ensureExecutable(ResolvedEmbeddedTool tool) async {
    if (tool.isCustom) return tool.path;
    if (File(tool.path).existsSync()) return tool.path;
    final cached = _extractedPaths[tool.path];
    if (cached != null) return cached;

    final data = await rootBundle.load(tool.path);
    final dir = Directory.systemTemp.createTempSync('hiext-yt-tools-');
    final fileName = tool.path.split('/').last;
    final filePath = '${dir.path}/$fileName';
    File(filePath).writeAsBytesSync(data.buffer.asUint8List());
    await Process.run('chmod', ['+x', filePath]);
    _extractedPaths[tool.path] = filePath;
    return filePath;
  }

  @override
  Future<List<ResourceVariant>> inspect(
    Uri url, {
    DownloadSettings? settings,
  }) async {
    final tools = _toolResolver.resolveBundle(
      settings: settings ?? DownloadSettings.defaults,
    );
    final ytDlpPath = await _ensureExecutable(tools.ytDlp);
    final process = await _processRunner(ytDlpPath, buildInspectArguments(url));

    final outputLines = <String>[];
    final session = YtDlpSession.forTesting(
      task: DownloadTask(
        id: 'inspect:${url.toString()}',
        title: url.toString(),
        source: url.toString(),
        status: DownloadStatus.parsing,
        progress: 0,
        variants: const [],
      ),
    );

    final stdoutFuture = _consumeLines(process.stdout, session, outputLines);
    final stderrFuture = _consumeLines(process.stderr, session, outputLines);
    final exitCode = await process.exitCode;
    await Future.wait([stdoutFuture, stderrFuture]);

    if (exitCode != 0) {
      final message =
          session.errorMessage ?? 'yt-dlp exited with a non-zero status';
      throw YtDlpExecutorException(message);
    }

    final variants = _parseInspectVariants(outputLines);
    return variants.isEmpty
        ? const [
            ResourceVariant(
              label: '推荐',
              description: '适合大多数人',
              isRecommended: true,
            ),
          ]
        : variants;
  }

  @override
  Future<void> startDownload({
    required String taskId,
    required Uri url,
    required ResourceVariant variant,
    required DownloadSettings settings,
    DownloadTaskChanged? onTaskChanged,
  }) async {
    final tools = _toolResolver.resolveBundle(settings: settings);
    final ytDlpPath = await _ensureExecutable(tools.ytDlp);
    final ffmpegPath = await _ensureExecutable(tools.ffmpeg);
    final process = await _processRunner(
      ytDlpPath,
      buildDownloadArguments(
        url: url,
        variant: variant,
        settings: settings,
        ffmpegPath: ffmpegPath,
        cookieFile: _resolveCookieFile(url, settings),
      ),
    );

    final task = DownloadTask(
      id: taskId,
      title: url.toString(),
      source: url.toString(),
      status: DownloadStatus.downloading,
      progress: 0,
      variants: [variant],
    );
    final session = YtDlpSession(task: task);
    _sessions[task.id] = session;
    _processes[task.id] = process;

    unawaited(_streamProcess(process, session, onTaskChanged));
  }

  @override
  Future<void> pause(String taskId) async {
    final session = _sessions[taskId];
    final process = _processes[taskId];
    if (session == null || process == null) {
      return;
    }

    _intentionalStops.add(taskId);
    session.status = DownloadStatus.paused;
    process.kill(ProcessSignal.sigterm);
  }

  @override
  Future<void> resume(String taskId) async {
    final session = _sessions[taskId];
    if (session == null) {
      return;
    }

    session.status = DownloadStatus.downloading;
  }

  @override
  Future<void> cancel(String taskId) async {
    final session = _sessions[taskId];
    final process = _processes[taskId];
    if (session == null) {
      return;
    }

    _intentionalStops.add(taskId);
    session.status = DownloadStatus.cancelled;
    process?.kill(ProcessSignal.sigterm);
  }

  @override
  Future<void> dispose() async {
    _intentionalStops.addAll(_processes.keys);
    for (final process in _processes.values) {
      process.kill(ProcessSignal.sigterm);
    }
    _processes.clear();
    _sessions.clear();
  }

  static List<String> buildInspectArguments(Uri url) {
    return ['--dump-json', '--no-playlist', url.toString()];
  }

  static List<String> buildDownloadArguments({
    required Uri url,
    required ResourceVariant variant,
    required DownloadSettings settings,
    required String ffmpegPath,
    String? cookieFile,
  }) {
    return [
      '--newline',
      '--continue',
      '--part',
      '--ffmpeg-location',
      ffmpegPath,
      if (settings.downloadSubtitles) '--write-subs',
      if (settings.downloadThumbnail) '--write-thumbnail',
      if (cookieFile != null) ...['--cookies', cookieFile],
      '-f',
      variant.formatId ?? settings.defaultQuality,
      '-P',
      variant.videoId != null
          ? '${settings.saveDirectory}/${variant.videoId}'
          : settings.saveDirectory,
      url.toString(),
    ];
  }

  Future<void> _streamProcess(
    Process process,
    YtDlpSession session,
    DownloadTaskChanged? onTaskChanged,
  ) async {
    final stdoutFuture = _consumeLines(process.stdout, session, onTaskChanged);
    final stderrFuture = _consumeLines(process.stderr, session, onTaskChanged);
    final exitCode = await process.exitCode;
    await Future.wait([stdoutFuture, stderrFuture]);

    if (_processes[session.task.id] == process) {
      _processes.remove(session.task.id);
    }

    if (_sessions[session.task.id] == session) {
      _sessions.remove(session.task.id);
    }

    if (_intentionalStops.remove(session.task.id)) {
      return;
    }

    if (exitCode == 0 && session.status != DownloadStatus.failed) {
      session.markCompleted();
      onTaskChanged?.call(session.task);
      return;
    }

    if (session.status != DownloadStatus.failed) {
      session.handleEvent(
        const YtDlpProgressEvent(
          type: YtDlpProgressEventType.error,
          message: 'yt-dlp exited with a non-zero status',
        ),
      );
      onTaskChanged?.call(session.task);
    }
  }

  Future<void> _consumeLines(
    Stream<List<int>> stream,
    YtDlpSession session, [
    Object? thirdArgument,
  ]) async {
    final collectedLines = thirdArgument is List<String> ? thirdArgument : null;
    final onTaskChanged = thirdArgument is DownloadTaskChanged
        ? thirdArgument
        : null;

    await for (final line
        in stream
            .transform(SystemEncoding().decoder)
            .transform(LineSplitter())) {
      collectedLines?.add(line);
      session.handleLine(line);
      if (_intentionalStops.contains(session.task.id)) {
        continue;
      }
      onTaskChanged?.call(session.task);
    }
  }

  static List<ResourceVariant> _parseInspectVariants(List<String> lines) {
    for (final line in lines) {
      try {
        final decoded = jsonDecode(line);
        if (decoded is! Map<String, Object?>) {
          continue;
        }

        final formats = decoded['formats'];
        if (formats is! List) {
          continue;
        }

        final videoId = decoded['id']?.toString();
        final videoTitle = decoded['title']?.toString();

        final variants = formats.whereType<Map<String, Object?>>().map((
          format,
        ) {
          final id = format['format_id']?.toString();
          final heightNum = format['height'] as int?;
          final height = heightNum?.toString();
          final ext = format['ext']?.toString();
          final vcodec = format['vcodec']?.toString() ?? '';
          final acodec = format['acodec']?.toString() ?? '';
          final filesize = format['filesize'] as int?;
          final tbr = (format['tbr'] as num?)?.toDouble();

          final hasVideo =
              (vcodec.isNotEmpty && vcodec != 'none') || heightNum != null;
          final hasAudio = acodec.isNotEmpty && acodec != 'none';
          final type = hasVideo ? ResourceType.video : ResourceType.audio;

          final label = switch (type) {
            ResourceType.video => height != null ? '${height}p 视频' : '视频 $id',
            ResourceType.audio => '音频 $id',
          };

          final parts = <String>[];
          if (ext != null) parts.add(ext);
          if (hasVideo && hasAudio) {
            parts.add('含音轨');
          } else if (hasVideo && !hasAudio) {
            parts.add('仅视频');
          } else if (!hasVideo && hasAudio) {
            parts.add(ext == 'm4a' ? 'AAC' : ext?.toUpperCase() ?? '');
          }
          if (filesize != null && filesize > 0) {
            parts.add(_formatFileSize(filesize));
          } else if (tbr != null && tbr > 0) {
            parts.add('${tbr.toStringAsFixed(0)}kbps');
          }

          return ResourceVariant(
            label: label,
            description: parts.join(' · '),
            isRecommended: false,
            formatId: id,
            type: type,
            height: heightNum,
            filesize: filesize,
            videoId: videoId,
            videoTitle: videoTitle,
          );
        }).toList();

        // Sort: video first (by height desc), then audio (by bitrate/filesize)
        variants.sort((a, b) {
          final aVideo = a.type == ResourceType.video;
          final bVideo = b.type == ResourceType.video;
          if (aVideo && !bVideo) return -1;
          if (!aVideo && bVideo) return 1;
          // Both video: higher resolution first
          if (aVideo) return (b.height ?? 0).compareTo(a.height ?? 0);
          // Both audio: larger file first (usually higher quality)
          return (b.filesize ?? 0).compareTo(a.filesize ?? 0);
        });

        // Mark best quality video as recommended
        final bestVideo = variants.firstWhere(
          (v) => v.type == ResourceType.video,
          orElse: () => variants.first,
        );
        final bestIdx = variants.indexOf(bestVideo);
        if (bestIdx >= 0) {
          variants[bestIdx] = ResourceVariant(
            label: '${bestVideo.label} (推荐)',
            description: bestVideo.description,
            isRecommended: true,
            formatId: bestVideo.formatId,
            type: bestVideo.type,
            height: bestVideo.height,
            filesize: bestVideo.filesize,
          );
        }

        return variants;
      } on FormatException {
        continue;
      }
    }

    return const [];
  }
}

String? _resolveCookieFile(Uri url, DownloadSettings settings) {
  final host = url.host;
  for (final config in settings.cookieConfigs) {
    if (!config.enabled) continue;
    if (host.contains(config.domain) || config.domain.contains(host)) {
      return config.cookieFile;
    }
  }
  return null;
}

String _formatFileSize(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)}KB';
  }
  return '$bytes B';
}

typedef ProcessRunner =
    Future<Process> Function(String executable, List<String> arguments);

class YtDlpExecutorException implements Exception {
  const YtDlpExecutorException(this.message);

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
