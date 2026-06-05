import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/app_models.dart';
import 'post_process_executor.dart';
import 'process_yt_dlp_executor.dart' show ProcessRunner;

class AiClipAnalyzerExecutor implements PostProcessExecutor {
  AiClipAnalyzerExecutor({
    ProcessRunner? processRunner,
    Future<List<ClipSegment>> Function(
      PostProcessTask task,
      BuiltInClipAnalyzerMode mode,
    )?
    builtInBuilder,
    HttpClient Function()? httpClientFactory,
  }) : _processRunner = processRunner ?? _defaultProcessRunner,
       _builtInBuilder = builtInBuilder ?? _buildBuiltInSegments,
       _httpClientFactory = httpClientFactory ?? HttpClient.new;

  final ProcessRunner _processRunner;
  final Future<List<ClipSegment>> Function(
    PostProcessTask task,
    BuiltInClipAnalyzerMode mode,
  )
  _builtInBuilder;
  final HttpClient Function() _httpClientFactory;
  final Map<String, Process> _processes = {};
  final Set<String> _intentionalStops = {};

  @override
  Future<void> startTask({
    required PostProcessTask task,
    required DownloadSettings settings,
    PostProcessTaskChanged? onTaskChanged,
  }) async {
    if (task.type != PostProcessTaskType.aiClipAnalysis) {
      throw AiClipAnalyzerException('Unsupported task type: ${task.type.name}');
    }

    onTaskChanged?.call(
      task.copyWith(status: PostProcessStatus.running, progress: 10),
    );

    switch (settings.aiAnalysisProvider) {
      case AiAnalysisProvider.builtIn:
        await _completeWithBuiltIn(task, settings, onTaskChanged);
      case AiAnalysisProvider.externalCommand:
        final command = settings.aiAnalyzerCommand;
        if (command == null || command.trim().isEmpty) {
          onTaskChanged?.call(
            task.copyWith(
              status: PostProcessStatus.failed,
              errorMessage: 'AI analyzer command is not configured',
            ),
          );
          return;
        }
        await _startExternalAnalyzer(
          command: command,
          task: task,
          onTaskChanged: onTaskChanged,
        );
      case AiAnalysisProvider.cloudEndpoint:
        await _startCloudAnalyzer(
          settings: settings,
          task: task,
          onTaskChanged: onTaskChanged,
        );
    }
  }

  Future<void> _completeWithBuiltIn(
    PostProcessTask task,
    DownloadSettings settings,
    PostProcessTaskChanged? onTaskChanged,
  ) async {
    final segments = await _builtInBuilder(
      task,
      settings.builtInClipAnalyzerMode,
    );
    onTaskChanged?.call(
      task.copyWith(
        status: PostProcessStatus.completed,
        progress: 100,
        clipSegments: segments,
      ),
    );
  }

  Future<void> _startExternalAnalyzer({
    required String command,
    required PostProcessTask task,
    PostProcessTaskChanged? onTaskChanged,
  }) async {
    final parts = _splitCommand(command);
    if (parts.isEmpty) {
      throw const AiClipAnalyzerException('AI analyzer command is empty');
    }
    final process = await _processRunner(parts.first, [
      ...parts.skip(1),
      '--input',
      task.sourcePath,
      '--task-id',
      task.id,
      '--source-task-id',
      task.sourceTaskId,
      '--title',
      task.title,
    ]);
    _processes[task.id] = process;
    unawaited(_watchProcess(process, task, onTaskChanged));
  }

  Future<void> _watchProcess(
    Process process,
    PostProcessTask task,
    PostProcessTaskChanged? onTaskChanged,
  ) async {
    final stdoutFuture = process.stdout.transform(utf8.decoder).join();
    final stderrFuture = process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode;
    final stdout = await stdoutFuture;
    final stderr = await stderrFuture;

    if (_processes[task.id] == process) {
      _processes.remove(task.id);
    }

    if (_intentionalStops.remove(task.id)) {
      onTaskChanged?.call(task.copyWith(status: PostProcessStatus.cancelled));
      return;
    }

    if (exitCode != 0) {
      onTaskChanged?.call(
        task.copyWith(
          status: PostProcessStatus.failed,
          errorMessage: stderr.trim().isEmpty
              ? 'AI analyzer exited with code $exitCode'
              : stderr.trim(),
        ),
      );
      return;
    }

    try {
      final segments = _parseManifest(stdout, task);
      onTaskChanged?.call(
        task.copyWith(
          status: PostProcessStatus.completed,
          progress: 100,
          clipSegments: segments,
        ),
      );
    } catch (error) {
      onTaskChanged?.call(
        task.copyWith(
          status: PostProcessStatus.failed,
          errorMessage: 'Invalid AI analyzer manifest: $error',
        ),
      );
    }
  }

  Future<void> _startCloudAnalyzer({
    required DownloadSettings settings,
    required PostProcessTask task,
    PostProcessTaskChanged? onTaskChanged,
  }) async {
    final endpoint = settings.aiCloudEndpoint;
    if (endpoint == null || endpoint.trim().isEmpty) {
      onTaskChanged?.call(
        task.copyWith(
          status: PostProcessStatus.failed,
          errorMessage: 'AI cloud endpoint is not configured',
        ),
      );
      return;
    }

    final candidates = await _builtInBuilder(
      task,
      settings.builtInClipAnalyzerMode,
    );
    final client = _httpClientFactory();
    try {
      final request = await client.postUrl(Uri.parse(endpoint));
      request.headers.contentType = ContentType.json;
      if (settings.aiCloudApiKey != null) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${settings.aiCloudApiKey}',
        );
      }
      request.write(
        jsonEncode({
          'schemaVersion': 1,
          'taskId': task.id,
          'sourceTaskId': task.sourceTaskId,
          'title': task.title,
          'sourcePath': task.sourcePath,
          if (settings.aiCloudModel != null) 'model': settings.aiCloudModel,
          'instructions':
              'Return JSON with a top-level segments array. Each segment should include startMs, endMs, title, summary, keywords, tags, confidence, reason, detections, and transcripts.',
          'builtInCandidates': candidates
              .map((segment) => segment.toJson())
              .toList(),
        }),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        onTaskChanged?.call(
          task.copyWith(
            status: PostProcessStatus.failed,
            errorMessage:
                'AI cloud endpoint returned HTTP ${response.statusCode}',
          ),
        );
        return;
      }
      final segments = _parseManifest(body, task);
      onTaskChanged?.call(
        task.copyWith(
          status: PostProcessStatus.completed,
          progress: 100,
          clipSegments: segments,
        ),
      );
    } catch (error) {
      onTaskChanged?.call(
        task.copyWith(
          status: PostProcessStatus.failed,
          errorMessage: 'AI cloud analysis failed: $error',
        ),
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> cancel(String taskId) async {
    final process = _processes[taskId];
    if (process == null) return;
    _intentionalStops.add(taskId);
    process.kill(ProcessSignal.sigterm);
  }

  @override
  Future<void> dispose() async {
    _intentionalStops.addAll(_processes.keys);
    for (final process in _processes.values) {
      process.kill(ProcessSignal.sigterm);
    }
    _processes.clear();
  }

  static List<ClipSegment> _parseManifest(
    String manifest,
    PostProcessTask task,
  ) {
    final decoded = _decodeManifestRoot(manifest);
    final rawSegments = decoded['segments'];
    if (rawSegments is! List) {
      throw const AiClipAnalyzerException('segments must be a JSON array');
    }
    return rawSegments.asMap().entries.map((entry) {
      final index = entry.key;
      final raw = entry.value;
      if (raw is! Map<String, Object?>) {
        throw const AiClipAnalyzerException('segment must be a JSON object');
      }
      final segmentId =
          raw['id'] as String? ?? '${task.id}#segment-${index + 1}';
      final detections = _readObjects(raw['detections'])
          .asMap()
          .entries
          .map(
            (d) => ClipDetection.fromJson({
              'id': d.value['id'] ?? '$segmentId#det-${d.key + 1}',
              'segmentId': segmentId,
              ...d.value,
            }),
          )
          .toList();
      final transcripts = _readObjects(raw['transcripts'])
          .asMap()
          .entries
          .map(
            (t) => ClipTranscript.fromJson({
              'id': t.value['id'] ?? '$segmentId#txt-${t.key + 1}',
              'segmentId': segmentId,
              ...t.value,
            }),
          )
          .toList();
      return ClipSegment(
        id: segmentId,
        sourceTaskId: task.sourceTaskId,
        postProcessTaskId: task.id,
        sourcePath: task.sourcePath,
        startMs: _readMs(raw, 'startMs', 'start'),
        endMs: _readMs(raw, 'endMs', 'end'),
        adjustedStartMs: (raw['adjustedStartMs'] as num?)?.toInt(),
        adjustedEndMs: (raw['adjustedEndMs'] as num?)?.toInt(),
        title: raw['title'] as String? ?? '${task.title} #${index + 1}',
        summary: raw['summary'] as String? ?? '',
        keywords: _readStrings(raw['keywords']),
        tags: _readStrings(raw['tags']),
        confidence: (raw['confidence'] as num?)?.toDouble() ?? 0,
        reason: raw['reason'] as String? ?? '',
        detections: detections,
        transcripts: transcripts,
        outputPath: raw['outputPath'] as String?,
      );
    }).toList();
  }

  static Map<String, Object?> _decodeManifestRoot(String manifest) {
    final decoded = jsonDecode(manifest);
    if (decoded is! Map<String, Object?>) {
      throw const AiClipAnalyzerException('root must be a JSON object');
    }
    if (decoded['segments'] is List) {
      return decoded;
    }
    final outputText = decoded['output_text'];
    if (outputText is String && outputText.trim().isNotEmpty) {
      return _decodeManifestRoot(outputText);
    }
    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map<String, Object?>) {
        final message = first['message'];
        if (message is Map<String, Object?>) {
          final content = message['content'];
          if (content is String && content.trim().isNotEmpty) {
            return _decodeManifestRoot(content);
          }
        }
      }
    }
    return decoded;
  }

  static int _readMs(
    Map<String, Object?> json,
    String millisecondKey,
    String secondKey,
  ) {
    final ms = json[millisecondKey];
    if (ms is num) return ms.toInt();
    final seconds = json[secondKey];
    if (seconds is num) return (seconds * 1000).round();
    return 0;
  }

  static List<Map<String, Object?>> _readObjects(Object? value) {
    return (value as List<Object?>?)
            ?.whereType<Map<String, Object?>>()
            .toList() ??
        const <Map<String, Object?>>[];
  }

  static List<String> _readStrings(Object? value) {
    if (value is String) {
      return value
          .split(RegExp(r'[,，\s]+'))
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toList();
    }
    return (value as List<Object?>?)?.map((v) => v.toString()).toList() ??
        const <String>[];
  }

  static List<String> _splitCommand(String command) {
    final result = <String>[];
    final current = StringBuffer();
    var quote = '';
    for (var i = 0; i < command.length; i += 1) {
      final char = command[i];
      if ((char == '"' || char == "'") && quote.isEmpty) {
        quote = char;
        continue;
      }
      if (char == quote) {
        quote = '';
        continue;
      }
      if (char.trim().isEmpty && quote.isEmpty) {
        if (current.isNotEmpty) {
          result.add(current.toString());
          current.clear();
        }
        continue;
      }
      current.write(char);
    }
    if (current.isNotEmpty) result.add(current.toString());
    return result;
  }

  static Future<List<ClipSegment>> _buildBuiltInSegments(
    PostProcessTask task,
    BuiltInClipAnalyzerMode mode,
  ) async {
    final sourceName = task.sourcePath.split(Platform.pathSeparator).last;
    final keywords = _keywordTokens(task.title, sourceName);
    final windows = switch (mode) {
      BuiltInClipAnalyzerMode.balanced => const [
        _BuiltInWindow(0, 30000, 'Opening context', 'balanced'),
        _BuiltInWindow(30000, 90000, 'Main content candidate', 'balanced'),
        _BuiltInWindow(90000, 150000, 'Follow-up candidate', 'balanced'),
      ],
      BuiltInClipAnalyzerMode.visualFocused => const [
        _BuiltInWindow(0, 20000, 'Visual opening candidate', 'visual'),
        _BuiltInWindow(20000, 50000, 'Visual scene candidate', 'visual'),
        _BuiltInWindow(50000, 80000, 'Visual detail candidate', 'visual'),
        _BuiltInWindow(80000, 110000, 'Visual transition candidate', 'visual'),
      ],
      BuiltInClipAnalyzerMode.audioFocused => const [
        _BuiltInWindow(0, 45000, 'Speech/context candidate', 'audio'),
        _BuiltInWindow(45000, 90000, 'Speech/topic candidate', 'audio'),
        _BuiltInWindow(90000, 135000, 'Speech/summary candidate', 'audio'),
      ],
    };

    return windows.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final window = entry.value;
      final segmentId = '${task.id}#builtin-$index';
      final summary = switch (mode) {
        BuiltInClipAnalyzerMode.balanced =>
          'Built-in balanced analysis candidate for "$sourceName". Use it as a searchable baseline before YOLO/Whisper/cloud refinement.',
        BuiltInClipAnalyzerMode.visualFocused =>
          'Built-in visual-focused candidate based on stable sampling windows and file/title keywords.',
        BuiltInClipAnalyzerMode.audioFocused =>
          'Built-in audio-focused candidate prepared for transcript/cloud refinement using title and file keywords.',
      };
      final detections = mode == BuiltInClipAnalyzerMode.audioFocused
          ? const <ClipDetection>[]
          : [
              ClipDetection(
                id: '$segmentId#det-1',
                segmentId: segmentId,
                timestampMs:
                    window.startMs + ((window.endMs - window.startMs) ~/ 2),
                label: mode == BuiltInClipAnalyzerMode.visualFocused
                    ? 'visual-scene-candidate'
                    : 'scene-candidate',
                confidence: mode == BuiltInClipAnalyzerMode.visualFocused
                    ? 0.34
                    : 0.26,
                bbox: const [],
              ),
            ];
      final transcripts = mode == BuiltInClipAnalyzerMode.visualFocused
          ? const <ClipTranscript>[]
          : [
              ClipTranscript(
                id: '$segmentId#txt-1',
                segmentId: segmentId,
                startMs: window.startMs,
                endMs: window.endMs,
                text: [task.title, sourceName, ...keywords].join(' '),
                words: keywords,
              ),
            ];
      return ClipSegment(
        id: segmentId,
        sourceTaskId: task.sourceTaskId,
        postProcessTaskId: task.id,
        sourcePath: task.sourcePath,
        startMs: window.startMs,
        endMs: window.endMs,
        title: '${task.title} · ${window.title}',
        summary: summary,
        keywords: [...keywords, window.tag, 'built-in'],
        tags: ['built-in', window.tag, mode.name],
        confidence: switch (mode) {
          BuiltInClipAnalyzerMode.balanced => 0.28,
          BuiltInClipAnalyzerMode.visualFocused => 0.34,
          BuiltInClipAnalyzerMode.audioFocused => 0.3,
        },
        reason:
            'Built-in ${mode.name} heuristic. Configure a local sidecar or cloud endpoint for model-based semantic refinement.',
        detections: detections,
        transcripts: transcripts,
      );
    }).toList();
  }

  static List<String> _keywordTokens(String title, String sourceName) {
    return '$title $sourceName'
        .replaceAll(RegExp(r'[_\-.]+'), ' ')
        .split(RegExp(r'\s+'))
        .map((token) => token.trim().toLowerCase())
        .where((token) => token.length >= 2)
        .take(16)
        .toList();
  }
}

class _BuiltInWindow {
  const _BuiltInWindow(this.startMs, this.endMs, this.title, this.tag);

  final int startMs;
  final int endMs;
  final String title;
  final String tag;
}

class AiClipAnalyzerException implements Exception {
  const AiClipAnalyzerException(this.message);

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
