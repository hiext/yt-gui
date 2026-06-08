import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

import '../models/app_models.dart';
import 'embedded_tool_resolver.dart';
import 'post_process_executor.dart';
import 'process_yt_dlp_executor.dart' show ProcessRunner;

class FfmpegClipExecutor implements PostProcessExecutor {
  FfmpegClipExecutor({
    EmbeddedToolResolver? toolResolver,
    ProcessRunner? processRunner,
  }) : _toolResolver = toolResolver ?? const EmbeddedToolResolver(),
       _processRunner = processRunner ?? _defaultProcessRunner;

  final EmbeddedToolResolver _toolResolver;
  final ProcessRunner _processRunner;
  final Map<String, Process> _processes = {};
  final Set<String> _intentionalStops = {};
  final Map<String, String> _extractedPaths = {};

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
      final filePath = '${dir.path}${Platform.pathSeparator}$fileName';
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
  Future<void> startTask({
    required PostProcessTask task,
    required DownloadSettings settings,
    PostProcessTaskChanged? onTaskChanged,
  }) async {
    if (task.type != PostProcessTaskType.clip) {
      throw PostProcessExecutorException(
        'Unsupported task type: ${task.type.name}',
      );
    }

    await Directory(task.outputDirectory).create(recursive: true);
    final tools = _toolResolver.resolveBundle(settings: settings);
    final ffmpegPath = await _ensureExecutable(tools.ffmpeg);
    final outputPath = _buildOutputPath(task);
    final process = await _processRunner(
      ffmpegPath,
      buildClipArguments(sourcePath: task.sourcePath, outputPath: outputPath),
    );

    _processes[task.id] = process;
    final running = task.copyWith(
      status: PostProcessStatus.running,
      progress: 5,
    );
    onTaskChanged?.call(running);

    unawaited(_watchProcess(process, running, outputPath, onTaskChanged));
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

  static List<String> buildClipArguments({
    required String sourcePath,
    required String outputPath,
    Duration start = Duration.zero,
    Duration duration = const Duration(seconds: 60),
  }) {
    return [
      '-y',
      '-ss',
      _formatDuration(start),
      '-i',
      sourcePath,
      '-t',
      _formatDuration(duration),
      '-c',
      'copy',
      outputPath,
    ];
  }

  Future<void> _watchProcess(
    Process process,
    PostProcessTask task,
    String outputPath,
    PostProcessTaskChanged? onTaskChanged,
  ) async {
    final stdoutDone = process.stdout.drain<void>();
    final stderrDone = process.stderr.drain<void>();
    final exitCode = await process.exitCode;
    await Future.wait([stdoutDone, stderrDone]);

    if (_processes[task.id] == process) {
      _processes.remove(task.id);
    }

    if (_intentionalStops.remove(task.id)) {
      onTaskChanged?.call(
        task.copyWith(
          status: PostProcessStatus.cancelled,
          progress: task.progress,
        ),
      );
      return;
    }

    if (exitCode == 0) {
      onTaskChanged?.call(
        task.copyWith(
          status: PostProcessStatus.completed,
          progress: 100,
          outputPaths: [outputPath],
          errorMessage: null,
        ),
      );
      return;
    }

    onTaskChanged?.call(
      task.copyWith(
        status: PostProcessStatus.failed,
        errorMessage: 'ffmpeg exited with code $exitCode',
      ),
    );
  }

  String _buildOutputPath(PostProcessTask task) {
    final sourceName = task.sourcePath.split(Platform.pathSeparator).last;
    final dot = sourceName.lastIndexOf('.');
    final baseName = dot > 0 ? sourceName.substring(0, dot) : sourceName;
    final ext = dot > 0 ? sourceName.substring(dot) : '.mp4';
    return '${task.outputDirectory}${Platform.pathSeparator}${baseName}_clip_001$ext';
  }

  static String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(hours)}:${two(minutes)}:${two(seconds)}';
  }
}

class PostProcessExecutorException implements Exception {
  const PostProcessExecutorException(this.message);

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
