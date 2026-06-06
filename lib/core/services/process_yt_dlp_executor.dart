import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_current.dart';
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

    try {
      final data = await rootBundle.load(tool.path);
      final dir = Directory.systemTemp.createTempSync('hiext-yt-tools-');
      final fileName = tool.path.split('/').last;
      final filePath = '${dir.path}/$fileName';
      File(filePath).writeAsBytesSync(data.buffer.asUint8List());
      await Process.run('chmod', ['+x', filePath]);
      _extractedPaths[tool.path] = filePath;
      return filePath;
    } catch (_) {
      if (tool.fallbackPath != null) {
        return tool.fallbackPath!;
      }
      throw EmbeddedToolResolutionException(
        'Missing ${tool.kind.baseExecutableName}. Install ${tool.kind.baseExecutableName} on PATH, add ${tool.path} to the app bundle, or set a custom path in Settings.',
      );
    }
  }

  @override
  Future<List<ResourceVariant>> inspect(
    Uri url, {
    DownloadSettings? settings,
    AppLocalizations? localizations,
    InspectLogSink? onLog,
  }) async {
    final normalizedSettings = (settings ?? DownloadSettings.defaults)
        .normalized();
    final tools = _toolResolver.resolveBundle(settings: normalizedSettings);
    final ytDlpPath = await _ensureExecutable(tools.ytDlp);
    final cookieFile = _resolveCookieFile(url, normalizedSettings);
    final process = await _processRunner(
      ytDlpPath,
      buildInspectArguments(url, cookieFile: cookieFile),
    );
    final l10n = localizations ?? currentAppLocalizations();

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

    final stdoutFuture = _consumeLines(
      process.stdout,
      session,
      collectedLines: outputLines,
    );
    final stderrFuture = _consumeLines(
      process.stderr,
      session,
      collectedLines: outputLines,
      onLog: onLog,
    );
    final exitCode = await process.exitCode;
    await Future.wait([stdoutFuture, stderrFuture]);

    if (exitCode != 0) {
      final message = session.errorMessage ?? l10n.ytDlpNonZeroExit;
      throw YtDlpExecutorException(message);
    }

    final variants = _parseInspectVariants(
      outputLines,
      l10n,
      recommendedVariantCount: normalizedSettings.recommendedVariantCount,
    );
    return variants.isEmpty
        ? [
            ResourceVariant(
              label: l10n.recommendedOptionLabel,
              description: l10n.recommendedOptionDesc,
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
    _intentionalStops.remove(task.id);
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

  static List<String> buildInspectArguments(Uri url, {String? cookieFile}) {
    return [
      '--dump-json',
      '--verbose',
      '--no-playlist',
      if (cookieFile != null) ...['--cookies', cookieFile],
      url.toString(),
    ];
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
      '--progress-template',
      'download:${YtDlpProgressParser.progressPrefix}'
          '%(progress.status)s|%(progress._percent_str)s|'
          '%(progress._speed_str)s|%(progress._eta_str)s',
      '--print',
      'after_move:$_filepathPrefix%(filepath)s',
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
    final stdoutFuture = _consumeLines(
      process.stdout,
      session,
      onTaskChanged: onTaskChanged,
    );
    final stderrFuture = _consumeLines(
      process.stderr,
      session,
      onTaskChanged: onTaskChanged,
    );
    final exitCode = await process.exitCode;
    await Future.wait([stdoutFuture, stderrFuture]);

    // Drop stale completion events when a newer startDownload has replaced
    // this session (e.g. after a quick pause→resume cycle).
    if (_sessions[session.task.id] != session) {
      return;
    }

    if (_processes[session.task.id] == process) {
      _processes.remove(session.task.id);
    }

    _sessions.remove(session.task.id);

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
        YtDlpProgressEvent(
          type: YtDlpProgressEventType.error,
          message: currentAppLocalizations().ytDlpNonZeroExit,
        ),
      );
      onTaskChanged?.call(session.task);
    }
  }

  Future<void> _consumeLines(
    Stream<List<int>> stream,
    YtDlpSession session, {
    List<String>? collectedLines,
    DownloadTaskChanged? onTaskChanged,
    InspectLogSink? onLog,
  }) async {
    await for (final line
        in stream
            .transform(SystemEncoding().decoder)
            .transform(LineSplitter())) {
      collectedLines?.add(line);
      onLog?.call(line);
      if (_intentionalStops.contains(session.task.id)) {
        continue;
      }
      session.handleLine(line);
      if (line.startsWith(_filepathPrefix)) {
        final path = line.substring(_filepathPrefix.length);
        session.task = session.task.copyWith(mediaPath: path);
      }
      onTaskChanged?.call(session.task);
    }
  }

  static List<ResourceVariant> _parseInspectVariants(
    List<String> lines,
    AppLocalizations l10n, {
    int recommendedVariantCount = 1,
  }) {
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
            ResourceType.video =>
              height != null
                  ? l10n.videoFormatWithHeight(height)
                  : l10n.videoFormatWithId(id ?? ''),
            ResourceType.audio => l10n.audioFormatWithId(id ?? ''),
          };

          final parts = <String>[];
          if (ext != null) parts.add(ext);
          if (hasVideo && hasAudio) {
            parts.add(l10n.containsAudioTrack);
          } else if (hasVideo && !hasAudio) {
            parts.add(l10n.videoOnly);
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

        final recommendedVariants = _buildRecommendedMergeVariants(
          variants,
          l10n,
          count: recommendedVariantCount,
          videoId: videoId,
          videoTitle: videoTitle,
        );

        final seenFormatIds = <String?>{};
        return [
          ...recommendedVariants,
          ...variants.where((variant) => seenFormatIds.add(variant.formatId)),
        ];
      } on FormatException {
        continue;
      }
    }

    return const [];
  }

  static List<ResourceVariant> _buildRecommendedMergeVariants(
    List<ResourceVariant> variants,
    AppLocalizations l10n, {
    required int count,
    required String? videoId,
    required String? videoTitle,
  }) {
    final videoVariants = variants
        .where((variant) => variant.type == ResourceType.video)
        .toList(growable: false);
    if (videoVariants.isEmpty) return const [];

    final normalizedCount = count.clamp(1, 5).toInt();
    final bestVideo = videoVariants.first;
    final maxHeight = bestVideo.height ?? 1080;
    final recommended = <ResourceVariant>[
      ResourceVariant(
        label: l10n.bestQualityLabel(maxHeight),
        description: l10n.bestQualityDesc,
        isRecommended: true,
        formatId: 'bestvideo+bestaudio',
        type: ResourceType.video,
        height: maxHeight,
        videoId: videoId,
        videoTitle: videoTitle,
      ),
    ];

    for (final variant in videoVariants) {
      if (recommended.length >= normalizedCount) break;
      final formatId = variant.formatId;
      final height = variant.height;
      if (formatId == null || formatId.trim().isEmpty) continue;
      recommended.add(
        ResourceVariant(
          label: height != null
              ? l10n.recommendedQualityWithHeightLabel(height)
              : '${variant.label} (${l10n.recommendedSuffix})',
          description: l10n.recommendedQualityWithHeightDesc,
          isRecommended: true,
          formatId: '$formatId+bestaudio/best',
          type: ResourceType.video,
          height: height,
          filesize: variant.filesize,
          videoId: variant.videoId,
          videoTitle: variant.videoTitle,
        ),
      );
    }

    return recommended;
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

const _filepathPrefix = '__HIEYT_FILEPATH__:';

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
