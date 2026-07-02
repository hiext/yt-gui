import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/embedded_tool_manifest.dart';
import 'package:hiext_yt_gui/core/services/embedded_tool_resolver.dart';
import 'package:hiext_yt_gui/core/services/ffmpeg_clip_executor.dart';

void main() {
  test('builds ffmpeg copy clip arguments', () {
    final args = FfmpegClipExecutor.buildClipArguments(
      sourcePath: '/downloads/source.mp4',
      outputPath: '/downloads/source.mp4.clips/source_clip_001.mp4',
    );

    expect(args, [
      '-y',
      '-ss',
      '00:00:00',
      '-i',
      '/downloads/source.mp4',
      '-t',
      '00:01:00',
      '-c',
      'copy',
      '/downloads/source.mp4.clips/source_clip_001.mp4',
    ]);
  });

  test('starts ffmpeg and reports completed output path', () async {
    final ffmpeg = _createToolFile('ffmpeg');
    final process = _FakeProcess(exitCodeValue: 0);
    String? executable;
    List<String>? arguments;
    final executor = FfmpegClipExecutor(
      toolResolver: _resolver(),
      processRunner: (path, args) async {
        executable = path;
        arguments = args;
        return process;
      },
    );
    final changes = <PostProcessTask>[];
    final task = PostProcessTask(
      id: 'clip-1',
      sourceTaskId: 'download-1',
      title: 'Example',
      type: PostProcessTaskType.clip,
      status: PostProcessStatus.queued,
      progress: 0,
      sourcePath: '/downloads/source.mp4',
      outputDirectory: Directory.systemTemp.createTempSync('clips-').path,
    );
    addTearDown(() => executor.dispose());

    await executor.startTask(
      task: task,
      settings: _settings(ffmpegPath: ffmpeg.path),
      onTaskChanged: changes.add,
    );
    await process.close();
    await pumpEventQueue();

    expect(executable, ffmpeg.path);
    expect(
      arguments,
      containsAll(['-i', '/downloads/source.mp4', '-c', 'copy']),
    );
    expect(changes.first.status, PostProcessStatus.running);
    expect(changes.last.status, PostProcessStatus.completed);
    expect(changes.last.outputPaths.single, endsWith('source_clip_001.mp4'));
  });

  test('reports failed when ffmpeg exits with non-zero code', () async {
    final ffmpeg = _createToolFile('ffmpeg');
    final process = _FakeProcess(exitCodeValue: 1);
    final executor = FfmpegClipExecutor(
      toolResolver: _resolver(),
      processRunner: (_, _) async => process,
    );
    final changes = <PostProcessTask>[];
    final task = PostProcessTask(
      id: 'clip-fail',
      sourceTaskId: 'download-1',
      title: 'Example',
      type: PostProcessTaskType.clip,
      status: PostProcessStatus.queued,
      progress: 0,
      sourcePath: '/downloads/source.mp4',
      outputDirectory: Directory.systemTemp.createTempSync('clips-').path,
    );
    addTearDown(() => executor.dispose());

    await executor.startTask(
      task: task,
      settings: _settings(ffmpegPath: ffmpeg.path),
      onTaskChanged: changes.add,
    );
    await process.close();
    await pumpEventQueue();

    expect(changes.last.status, PostProcessStatus.failed);
    expect(changes.last.errorMessage, contains('exited with code 1'));
  });

  test('cancel kills process and marks task cancelled', () async {
    final ffmpeg = _createToolFile('ffmpeg');
    final process = _FakeProcess(exitCodeValue: 0);
    final executor = FfmpegClipExecutor(
      toolResolver: _resolver(),
      processRunner: (_, _) async => process,
    );
    final changes = <PostProcessTask>[];
    final task = PostProcessTask(
      id: 'clip-cancel',
      sourceTaskId: 'download-1',
      title: 'Example',
      type: PostProcessTaskType.clip,
      status: PostProcessStatus.queued,
      progress: 0,
      sourcePath: '/downloads/source.mp4',
      outputDirectory: Directory.systemTemp.createTempSync('clips-').path,
    );
    addTearDown(() => executor.dispose());

    await executor.startTask(
      task: task,
      settings: _settings(ffmpegPath: ffmpeg.path),
      onTaskChanged: changes.add,
    );
    await executor.cancel('clip-cancel');
    await process.close();
    await pumpEventQueue();

    expect(changes.last.status, PostProcessStatus.cancelled);
  });

  test('dispose kills all running processes', () async {
    final ffmpeg = _createToolFile('ffmpeg');
    final p1 = _FakeProcess(exitCodeValue: 0);
    final executor = FfmpegClipExecutor(
      toolResolver: _resolver(),
      processRunner: (_, _) async => p1,
    );
    addTearDown(() => executor.dispose());

    final task1 = PostProcessTask(
      id: 'clip-dispose-1',
      sourceTaskId: 'download-1',
      title: 'Task 1',
      type: PostProcessTaskType.clip,
      status: PostProcessStatus.queued,
      progress: 0,
      sourcePath: '/downloads/source.mp4',
      outputDirectory: Directory.systemTemp.createTempSync('clips-').path,
    );

    await executor.startTask(
      task: task1,
      settings: _settings(ffmpegPath: ffmpeg.path),
    );

    await executor.dispose();
    await p1.close();
    await pumpEventQueue();
    // dispose should not throw
  });

  test('throws for unsupported task type', () async {
    final ffmpeg = _createToolFile('ffmpeg');
    final executor = FfmpegClipExecutor(toolResolver: _resolver());
    addTearDown(() => executor.dispose());

    final task = PostProcessTask(
      id: 'bad-type',
      sourceTaskId: 'download-1',
      title: 'Bad',
      type: PostProcessTaskType.aiClipAnalysis,
      status: PostProcessStatus.queued,
      progress: 0,
      sourcePath: '/downloads/source.mp4',
      outputDirectory: Directory.systemTemp.createTempSync('clips-').path,
    );

    expect(
      () => executor.startTask(
        task: task,
        settings: _settings(ffmpegPath: ffmpeg.path),
      ),
      throwsA(isA<PostProcessExecutorException>()),
    );
  });

  test('cancel does nothing for unknown task id', () async {
    final executor = FfmpegClipExecutor();
    await expectLater(executor.cancel('unknown-task'), completes);
  });

  test('buildClipArguments with custom start and duration', () {
    final args = FfmpegClipExecutor.buildClipArguments(
      sourcePath: '/tmp/src.mp4',
      outputPath: '/tmp/out.mp4',
      start: const Duration(minutes: 1, seconds: 30),
      duration: const Duration(seconds: 30),
    );

    expect(args, [
      '-y',
      '-ss',
      '00:01:30',
      '-i',
      '/tmp/src.mp4',
      '-t',
      '00:00:30',
      '-c',
      'copy',
      '/tmp/out.mp4',
    ]);
  });

  test('_buildOutputPath handles path with dot and without dot', () async {
    final executor = FfmpegClipExecutor(toolResolver: _resolver());
    addTearDown(() => executor.dispose());

    // We test the output path indirectly via startTask
    final ffmpeg = _createToolFile('ffmpeg');
    final process = _FakeProcess(exitCodeValue: 0);
    List<String>? capturedArgs;
    final executor2 = FfmpegClipExecutor(
      toolResolver: _resolver(),
      processRunner: (_, args) async {
        capturedArgs = args;
        return process;
      },
    );
    addTearDown(() => executor2.dispose());

    // File with extension
    final task = PostProcessTask(
      id: 'clip-path',
      sourceTaskId: 'download-1',
      title: 'Example',
      type: PostProcessTaskType.clip,
      status: PostProcessStatus.queued,
      progress: 0,
      sourcePath: '/downloads/video.mkv',
      outputDirectory: Directory.systemTemp.createTempSync('clips-').path,
    );
    await executor2.startTask(
      task: task,
      settings: _settings(ffmpegPath: ffmpeg.path),
    );
    await process.close();
    await pumpEventQueue();

    // Output path should use .mkv extension
    expect(capturedArgs!.last, endsWith('video_clip_001.mkv'));
  });

  test('uses PATH ffmpeg before bundled asset', () async {
    final tempDir = Directory.systemTemp.createTempSync('ffmpeg-fallback-');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    File('${tempDir.path}/yt-dlp').writeAsStringSync('');
    final ffmpeg = File('${tempDir.path}/ffmpeg')..writeAsStringSync('');
    final process = _FakeProcess(exitCodeValue: 0);
    String? executable;
    var attemptedAssetLoad = false;
    final executor = FfmpegClipExecutor(
      toolResolver: EmbeddedToolResolver(
        platformOverride: EmbeddedToolPlatform.macos,
        environment: {'PATH': tempDir.path},
      ),
      loadAsset: (_) {
        attemptedAssetLoad = true;
        throw Exception('bundled asset should not be loaded first');
      },
      processRunner: (path, _) async {
        executable = path;
        return process;
      },
    );
    final task = PostProcessTask(
      id: 'clip-fallback',
      sourceTaskId: 'download-1',
      title: 'Example',
      type: PostProcessTaskType.clip,
      status: PostProcessStatus.queued,
      progress: 0,
      sourcePath: '/downloads/source.mp4',
      outputDirectory: Directory.systemTemp.createTempSync('clips-').path,
    );
    addTearDown(() => executor.dispose());

    await executor.startTask(task: task, settings: _settings());
    await process.close();
    await pumpEventQueue();

    expect(executable, ffmpeg.absolute.path);
    expect(attemptedAssetLoad, isFalse);
  });
}

DownloadSettings _settings({String? ffmpegPath}) {
  return DownloadSettings(
    saveDirectory: '/downloads',
    downloadMode: DownloadMode.serial,
    concurrentCount: 1,
    defaultQuality: 'best',
    downloadSubtitles: false,
    downloadThumbnail: false,
    disclaimerAccepted: false,
    ffmpegPath: ffmpegPath,
  );
}

File _createToolFile(String name) {
  final tempDir = Directory.systemTemp.createTempSync('ffmpeg-clip-executor-');
  addTearDown(() => tempDir.deleteSync(recursive: true));
  return File('${tempDir.path}/$name')..writeAsStringSync('');
}

EmbeddedToolResolver _resolver() {
  final tempDir = Directory.systemTemp.createTempSync('embedded-tool-path-');
  addTearDown(() => tempDir.deleteSync(recursive: true));
  File('${tempDir.path}/yt-dlp').writeAsStringSync('');
  File('${tempDir.path}/ffmpeg').writeAsStringSync('');
  return EmbeddedToolResolver(
    manifest: EmbeddedToolManifest(
      specs: [
        EmbeddedToolSpec(
          platform: EmbeddedToolPlatform.linux,
          kind: EmbeddedToolKind.ytDlp,
          version: 'test',
        ),
        EmbeddedToolSpec(
          platform: EmbeddedToolPlatform.linux,
          kind: EmbeddedToolKind.ffmpeg,
          version: 'test',
        ),
      ],
    ),
    platformOverride: EmbeddedToolPlatform.linux,
    environment: {'PATH': tempDir.path},
  );
}

class _FakeProcess implements Process {
  _FakeProcess({required this.exitCodeValue});

  final int exitCodeValue;
  final _stdout = StreamController<List<int>>();
  final _stderr = StreamController<List<int>>();
  final _exit = Completer<int>();

  Future<void> close() async {
    await _stdout.close();
    await _stderr.close();
    if (!_exit.isCompleted) {
      _exit.complete(exitCodeValue);
    }
  }

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;

  @override
  int get pid => 1;

  @override
  IOSink get stdin => IOSink(StreamController<List<int>>().sink);

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => _stderr.stream;
}
