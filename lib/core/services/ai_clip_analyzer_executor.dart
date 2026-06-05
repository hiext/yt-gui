import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/app_models.dart';
import 'post_process_executor.dart';
import 'process_yt_dlp_executor.dart' show ProcessRunner;

class AiClipAnalyzerExecutor implements PostProcessExecutor {
  AiClipAnalyzerExecutor({
    ProcessRunner? processRunner,
    Future<List<ClipSegment>> Function(PostProcessTask task)? fallbackBuilder,
  }) : _processRunner = processRunner ?? _defaultProcessRunner,
       _fallbackBuilder = fallbackBuilder ?? _buildFallbackSegments;

  final ProcessRunner _processRunner;
  final Future<List<ClipSegment>> Function(PostProcessTask task)
  _fallbackBuilder;
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

    final command = settings.aiAnalyzerCommand;
    if (command == null || command.trim().isEmpty) {
      final segments = await _fallbackBuilder(task);
      onTaskChanged?.call(
        task.copyWith(
          status: PostProcessStatus.completed,
          progress: 100,
          clipSegments: segments,
        ),
      );
      return;
    }

    await _startExternalAnalyzer(
      command: command,
      task: task,
      onTaskChanged: onTaskChanged,
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
    final decoded = jsonDecode(manifest);
    if (decoded is! Map<String, Object?>) {
      throw const AiClipAnalyzerException('root must be a JSON object');
    }
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

  static Future<List<ClipSegment>> _buildFallbackSegments(
    PostProcessTask task,
  ) async {
    final sourceName = task.sourcePath.split(Platform.pathSeparator).last;
    final segmentId = '${task.id}#segment-1';
    return [
      ClipSegment(
        id: segmentId,
        sourceTaskId: task.sourceTaskId,
        postProcessTaskId: task.id,
        sourcePath: task.sourcePath,
        startMs: 0,
        endMs: 60000,
        title: task.title,
        summary:
            'AI analyzer is not configured. This placeholder keeps "$sourceName" searchable until a YOLO/Whisper sidecar is connected.',
        keywords: [task.title, sourceName, 'ai-analyzer-pending'],
        tags: const ['pending-ai-analysis'],
        confidence: 0.05,
        reason: 'No AI analyzer command configured in Settings.',
        transcripts: [
          ClipTranscript(
            id: '$segmentId#txt-1',
            segmentId: segmentId,
            startMs: 0,
            endMs: 60000,
            text: sourceName,
          ),
        ],
      ),
    ];
  }
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
