import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

import '../../l10n/app_localizations.dart';
import 'log_service.dart';
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
  final Map<String, _DownloadRequest> _pendingRetries = {};
  static const _maxRetries = 3;

  Future<String> _ensureExecutable(ResolvedEmbeddedTool tool) async {
    if (tool.isCustom) return tool.path;
    // Always extract embedded tools from rootBundle — never trust
    // the filesystem path, because CWD differs between dev and prod.
    final cached = _extractedPaths[tool.path];
    if (cached != null) {
      if (File(cached).existsSync()) return cached;
      _extractedPaths.remove(tool.path);
    }

    try {
      final data = await rootBundle.load(tool.path);
      final dir = Directory.systemTemp.createTempSync('hiext-yt-tools-');
      final fileName = tool.path.split('/').last;
      final filePath = '${dir.path}/$fileName';
      File(filePath).writeAsBytesSync(data.buffer.asUint8List());
      await Process.run('chmod', ['+x', filePath]);
      _extractedPaths[tool.path] = filePath;
      LogService.instance.debug(
        'Extracted ${tool.kind.name} to $filePath',
        'executor',
      );
      return filePath;
    } catch (e) {
      LogService.instance.warn(
        'Failed to extract ${tool.kind.name}: $e',
        'executor',
      );
      if (tool.fallbackPath != null) {
        LogService.instance.info(
          'Using fallback ${tool.kind.name}: ${tool.fallbackPath}',
          'executor',
        );
        return tool.fallbackPath!;
      }
      final msg =
          'Missing ${tool.kind.baseExecutableName}. Install ${tool.kind.baseExecutableName} on PATH, add ${tool.path} to the app bundle, or set a custom path in Settings.';
      LogService.instance.error(msg, 'executor');
      throw EmbeddedToolResolutionException(msg);
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
    final cookieFile = _resolveCookieFile(url, normalizedSettings);

    // First attempt: with cookies (if available)
    if (cookieFile != null) {
      try {
        return await _doInspect(
          url,
          normalizedSettings: normalizedSettings,
          cookieFile: cookieFile,
          localizations: localizations,
          onLog: onLog,
          timeoutSeconds: 120,
        );
      } on YtDlpExecutorException catch (e) {
        LogService.instance.warn(
          'inspect with cookie failed: ${e.message}, retrying without cookie',
          'executor',
        );
      }
    }

    // Second attempt: without cookies (or first attempt if no cookie)
    return _doInspect(
      url,
      normalizedSettings: normalizedSettings,
      cookieFile: null,
      localizations: localizations,
      onLog: onLog,
      timeoutSeconds: 120,
    );
  }

  Future<List<ResourceVariant>> _doInspect(
    Uri url, {
    required DownloadSettings normalizedSettings,
    required String? cookieFile,
    AppLocalizations? localizations,
    InspectLogSink? onLog,
    required int timeoutSeconds,
  }) async {
    final sw = Stopwatch()..start();
    final tools = _toolResolver.resolveBundle(settings: normalizedSettings);
    LogService.instance.info(
      'inspect: resolveBundle took ${sw.elapsedMilliseconds}ms',
      'executor',
    );
    final ytDlpPath = await _ensureExecutable(tools.ytDlp);
    LogService.instance.info(
      'inspect: ensureExecutable took ${sw.elapsedMilliseconds}ms, path=$ytDlpPath',
      'executor',
    );
    if (cookieFile != null) {
      LogService.instance.debug(
        'inspect: using cookie $cookieFile',
        'executor',
      );
    }
    final args = buildInspectArguments(url, cookieFile: cookieFile);
    final l10n = localizations ?? currentAppLocalizations();

    // Use Process.run for production (avoids stream hang with subprocesses),
    // use injected _processRunner when customized (for unit testing).
    if (_processRunner == _defaultProcessRunner) {
      try {
        final result = await Process.run(
          ytDlpPath,
          args,
          runInShell: false,
        ).timeout(Duration(seconds: timeoutSeconds));
        LogService.instance.info(
          'inspect: exitCode=${result.exitCode} at ${sw.elapsedMilliseconds}ms',
          'executor',
        );

        final stderr = result.stderr as String;
        if (stderr.isNotEmpty && onLog != null) {
          for (final line in stderr.split('\n')) {
            if (line.trim().isNotEmpty) onLog(line);
          }
        }

        if (result.exitCode != 0) {
          final msg = stderr.trim().isNotEmpty
              ? stderr.trim().split('\n').last
              : 'yt-dlp exit code ${result.exitCode}';
          LogService.instance.error(
            'inspect failed: exit=${result.exitCode} $msg',
            'executor',
          );
          throw YtDlpExecutorException(msg);
        }

        final stdout = result.stdout as String;
        final outputLines = stdout
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();
        final variants = _parseInspectVariants(
          outputLines,
          l10n,
          recommendedVariantCount: normalizedSettings.recommendedVariantCount,
        );
        LogService.instance.info(
          'inspect: found ${variants.length} variants at ${sw.elapsedMilliseconds}ms',
          'executor',
        );
        return variants;
      } on TimeoutException {
        LogService.instance.error(
          'inspect timed out after ${timeoutSeconds}s',
          'executor',
        );
        throw YtDlpExecutorException(
          'Parse timed out after $timeoutSeconds seconds',
        );
      }
    }

    // Custom process runner path (for tests with _FakeProcess)
    final process = await _processRunner(ytDlpPath, args);
    LogService.instance.info(
      'inspect: process started at ${sw.elapsedMilliseconds}ms, pid=${process.pid}',
      'executor',
    );

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
    final exitCode = await process.exitCode.timeout(
      Duration(seconds: timeoutSeconds),
      onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
    LogService.instance.info(
      'inspect: exitCode=$exitCode at ${sw.elapsedMilliseconds}ms',
      'executor',
    );

    try {
      await Future.wait([
        stdoutFuture,
        stderrFuture,
      ]).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      LogService.instance.warn('inspect: stream drain timed out', 'executor');
    }

    if (exitCode == -1) {
      LogService.instance.error(
        'inspect timed out after ${timeoutSeconds}s',
        'executor',
      );
      throw YtDlpExecutorException(
        'Parse timed out after $timeoutSeconds seconds',
      );
    }
    if (exitCode != 0) {
      final message = session.errorMessage ?? l10n.ytDlpNonZeroExit;
      throw YtDlpExecutorException(message);
    }

    final variants = _parseInspectVariants(
      outputLines,
      l10n,
      recommendedVariantCount: normalizedSettings.recommendedVariantCount,
    );
    LogService.instance.info(
      'inspect: found ${variants.length} variants',
      'executor',
    );
    return variants;
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
    LogService.instance.debug(
      'startDownload: yt-dlp=$ytDlpPath ffmpeg=$ffmpegPath',
      'executor',
    );
    final downloadArgs = buildDownloadArguments(
      url: url,
      variant: variant,
      settings: settings,
      ffmpegPath: ffmpegPath,
      cookieFile: _resolveCookieFile(url, settings),
    );
    LogService.instance.debug(
      'startDownload args: ${_redactDownloadArgs(downloadArgs)}',
      'executor',
    );
    final process = await _processRunner(ytDlpPath, downloadArgs);

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
    final prevAttempts = _pendingRetries[task.id]?.attempts ?? 0;
    _pendingRetries[task.id] = _DownloadRequest(
      url: url,
      variant: variant,
      settings: settings,
      onTaskChanged: onTaskChanged,
      attempts: prevAttempts,
    );

    LogService.instance.info(
      'Starting download: $taskId (attempt ${_pendingRetries[task.id]!.attempts + 1}/$_maxRetries)',
      'executor',
    );
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
    _pendingRetries.remove(taskId);
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
      '--no-playlist',
      ..._antiBotHeaders(url),
      if (cookieFile != null) ...['--cookies', cookieFile],
      url.toString(),
    ];
  }

  /// Sites that require additional HTTP headers to bypass anti-bot protection.
  static List<String> _antiBotHeaders(Uri url) {
    final host = url.host;
    if (host.contains('bilibili.com') || host.contains('bilibili.tv')) {
      return [
        '--add-header',
        'Referer:https://www.bilibili.com',
        '--add-header',
        'Origin:https://www.bilibili.com',
        '--add-header',
        'User-Agent:Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        '--add-header',
        'Accept:text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        '--add-header',
        'Accept-Language:zh-CN,zh;q=0.9,en;q=0.8',
        '--add-header',
        'Accept-Encoding:gzip, deflate, br',
        '--add-header',
        'Sec-Fetch-Site:none',
        '--add-header',
        'Sec-Fetch-Mode:navigate',
        '--add-header',
        'Sec-Fetch-Dest:document',
      ];
    }
    return const [];
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
      '--progress',
      '--continue',
      '--part',
      '--progress-template',
      'download:__HIEYT_PROGRESS__:%(progress.status)s|'
          '%(progress._percent_str)s|'
          '%(progress._speed_str)s|'
          '%(progress._eta_str)s',
      '--ffmpeg-location',
      ffmpegPath,
      ..._antiBotHeaders(url),
      '--print',
      'after_move:__HIEYT_FILEPATH__:%(filepath)s',
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

  static String _redactDownloadArgs(List<String> args) {
    final redacted = <String>[];
    for (var i = 0; i < args.length; i += 1) {
      final arg = args[i];
      redacted.add(arg);
      if (arg == '--cookies' && i + 1 < args.length) {
        redacted.add('[cookie-file]');
        i += 1;
      }
    }
    return redacted.join(' ');
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
      expandCarriageReturns: true,
    );
    final stderrFuture = _consumeLines(
      process.stderr,
      session,
      onTaskChanged: onTaskChanged,
      expandCarriageReturns: true,
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
      _pendingRetries.remove(session.task.id);
      LogService.instance.info(
        'Download completed: ${session.task.id}, mediaPath: ${session.task.mediaPath}',
        'executor',
      );
      onTaskChanged?.call(session.task);
      return;
    }

    if (session.status != DownloadStatus.failed) {
      // Auto-retry on failure (network flakiness, transient errors).
      final retry = _pendingRetries[session.task.id];
      if (retry != null && retry.attempts < _maxRetries - 1) {
        final next = retry.attempts + 1;
        _pendingRetries[session.task.id] = _DownloadRequest(
          url: retry.url,
          variant: retry.variant,
          settings: retry.settings,
          onTaskChanged: retry.onTaskChanged,
          attempts: next,
        );
        LogService.instance.warn(
          'Retrying ${session.task.id} (attempt ${next + 1}/$_maxRetries) '
              'after exit=$exitCode',
          'executor',
        );
        // Small delay before retry to let transient issues resolve.
        await Future<void>.delayed(const Duration(seconds: 2));
        if (_intentionalStops.contains(session.task.id)) return;
        unawaited(
          startDownload(
            taskId: session.task.id,
            url: retry.url,
            variant: retry.variant,
            settings: retry.settings,
            onTaskChanged: retry.onTaskChanged,
          ),
        );
        return;
      }

      final detail = session.errorMessage;
      final msg = detail?.isNotEmpty == true
          ? detail!
          : currentAppLocalizations().ytDlpNonZeroExit;
      _pendingRetries.remove(session.task.id);
      LogService.instance.error(
        'Download failed after ${(retry?.attempts ?? 0) + 1} attempts: '
            'exit=$exitCode ${session.task.id} — $msg',
        'executor',
      );
      session.handleEvent(
        YtDlpProgressEvent(type: YtDlpProgressEventType.error, message: msg),
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
    bool expandCarriageReturns = false,
  }) async {
    var lastLoggedPercent = -1.0;
    var lineStream = stream
        .transform(SystemEncoding().decoder)
        .transform(LineSplitter());
    // Older yt-dlp versions don't support --newline and use \r
    // (carriage return) to update progress on the same line.
    // Only enable for download output — JSON inspect output may contain
    // literal \r inside string values (e.g. MHTML storyboard URLs).
    if (expandCarriageReturns) {
      // \r not followed by \n is a progress overwrite — replace with \n
      lineStream = stream
          .transform(SystemEncoding().decoder)
          .transform(
            StreamTransformer<String, String>.fromHandlers(
              handleData: (data, sink) {
                sink.add(data.replaceAll(RegExp(r'\r(?!\n)'), '\n'));
              },
            ),
          )
          .transform(LineSplitter());
    }
    await for (final line in lineStream) {
      collectedLines?.add(line);
      onLog?.call(line);
      if (_intentionalStops.contains(session.task.id)) {
        continue;
      }
      final previousProgress = session.task.progress;
      session.handleLine(line);
      final filepathMatch = _filepathRe.firstMatch(line);
      if (filepathMatch != null) {
        session.task = session.task.copyWith(
          mediaPath: filepathMatch.namedGroup('path'),
        );
      }
      if (session.task.progress != previousProgress) {
        LogService.instance.debug(
          'Parsed progress ${session.task.id}: '
              '${session.task.progress.toStringAsFixed(1)}% '
              'speed=${session.task.speed} eta=${session.task.eta}',
          'executor',
        );
      } else if (line.contains('__HIEYT_PROGRESS__')) {
        LogService.instance.warn(
          'Unparsed progress line ${session.task.id}: $line',
          'executor',
        );
      }
      // Log progress milestones (every ~20%)
      final pct = session.task.progress;
      if (pct - lastLoggedPercent >= 20) {
        lastLoggedPercent = pct - (pct % 20);
        LogService.instance.debug(
          'Progress ${session.task.id}: ${pct.toStringAsFixed(0)}% '
              'speed=${session.task.speed} eta=${session.task.eta}',
          'executor',
        );
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

class _DownloadRequest {
  const _DownloadRequest({
    required this.url,
    required this.variant,
    required this.settings,
    required this.onTaskChanged,
    required this.attempts,
  });

  final Uri url;
  final ResourceVariant variant;
  final DownloadSettings settings;
  final DownloadTaskChanged? onTaskChanged;
  final int attempts;
}

/// Matches the after_move print output:
///   __HIEYT_FILEPATH__:/path/to/video.mp4
final _filepathRe = RegExp(r'^__HIEYT_FILEPATH__:(?<path>.+)$');

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
