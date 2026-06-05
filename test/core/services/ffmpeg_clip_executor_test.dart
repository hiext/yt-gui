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

  test('uses PATH fallback when bundled ffmpeg asset is unavailable', () async {
    final tempDir = Directory.systemTemp.createTempSync('ffmpeg-fallback-');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    File('${tempDir.path}/yt-dlp').writeAsStringSync('');
    final ffmpeg = File('${tempDir.path}/ffmpeg')..writeAsStringSync('');
    final process = _FakeProcess(exitCodeValue: 0);
    String? executable;
    final executor = FfmpegClipExecutor(
      toolResolver: EmbeddedToolResolver(
        platformOverride: EmbeddedToolPlatform.macos,
        environment: {'PATH': tempDir.path},
      ),
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
