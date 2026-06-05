import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/embedded_tool_manifest.dart';
import 'package:hiext_yt_gui/core/services/embedded_tool_resolver.dart';
import 'package:hiext_yt_gui/core/services/process_yt_dlp_executor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('keeps part files and restarts with same resume command', () async {
    final tempDir = Directory.systemTemp.createTempSync('yt-dlp-resume-');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final starts = <List<String>>[];
    var run = 0;
    final executor = ProcessYtDlpExecutor(
      toolResolver: _resolver(),
      processRunner: (_, arguments) async {
        starts.add(List<String>.from(arguments));
        run += 1;
        if (run == 1) {
          _seedResumeFiles(tempDir);
        }
        return _FakeProcess(exitCodeValue: run == 1 ? 143 : 0);
      },
    );

    const variant = ResourceVariant(
      label: '推荐',
      description: '适合大多数人',
      isRecommended: true,
      formatId: 'best',
    );
    final settings = DownloadSettings(
      saveDirectory: tempDir.path,
      downloadMode: DownloadMode.serial,
      concurrentCount: 1,
      defaultQuality: 'best',
      downloadSubtitles: false,
      downloadThumbnail: false,
      disclaimerAccepted: false,
    );

    await executor.startDownload(
      taskId: 'task-1',
      url: Uri.parse('https://example.com/video'),
      variant: variant,
      settings: settings,
    );
    await executor.pause('task-1');
    await executor.startDownload(
      taskId: 'task-1',
      url: Uri.parse('https://example.com/video'),
      variant: variant,
      settings: settings,
    );

    expect(starts, hasLength(2));
    expect(starts.first, starts.last);
    expect(starts.last, contains('--continue'));
    expect(starts.last, contains('--part'));
    expect(File('${tempDir.path}/sample.part').existsSync(), isTrue);
    expect(File('${tempDir.path}/sample.ytdl').existsSync(), isTrue);
  });
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

void _seedResumeFiles(Directory tempDir) {
  File('${tempDir.path}/sample.part').writeAsStringSync('partial');
  File(
    '${tempDir.path}/sample.ytdl',
  ).writeAsStringSync('{"fragment_index": 1}');
}

class _FakeProcess implements Process {
  _FakeProcess({required this.exitCodeValue});

  final int exitCodeValue;
  final _stdout = StreamController<List<int>>();
  final _stderr = StreamController<List<int>>();
  final _exit = Completer<int>();
  final List<ProcessSignal> killedSignals = [];

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
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killedSignals.add(signal);
    return true;
  }

  @override
  int get pid => 1;

  @override
  IOSink get stdin => IOSink(StreamController<List<int>>().sink);

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => _stderr.stream;
}
