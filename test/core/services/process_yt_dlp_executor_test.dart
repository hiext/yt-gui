import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/embedded_tool_manifest.dart';
import 'package:hiext_yt_gui/core/services/embedded_tool_resolver.dart';
import 'package:hiext_yt_gui/core/services/process_yt_dlp_executor.dart';

void main() {
  test('builds inspect arguments', () {
    final args = ProcessYtDlpExecutor.buildInspectArguments(
      Uri.parse('https://example.com/video'),
    );

    expect(args, ['--dump-json', '--no-playlist', 'https://example.com/video']);
  });

  test('builds resumable download arguments', () {
    final args = ProcessYtDlpExecutor.buildDownloadArguments(
      url: Uri.parse('https://example.com/video'),
      variant: const ResourceVariant(
        label: '推荐',
        description: '适合大多数人',
        isRecommended: true,
        formatId: 'bestvideo+bestaudio',
      ),
      settings: const DownloadSettings(
        saveDirectory: '/downloads',
        downloadMode: DownloadMode.serial,
        concurrentCount: 1,
        defaultQuality: 'best',
        downloadSubtitles: true,
        downloadThumbnail: true,
      ),
      ffmpegPath: '/tools/ffmpeg',
    );

    expect(
      args,
      containsAll(['--newline', '--continue', '--part', '--ffmpeg-location']),
    );
    expect(args, containsAll(['/tools/ffmpeg', '--write-subs']));
    expect(args, containsAll(['--write-thumbnail', '-f', 'bestvideo+bestaudio']));
    expect(args, containsAll(['-P', '/downloads', 'https://example.com/video']));
    expect(args, isNot(contains('--no-continue')));
    expect(args, isNot(contains('--no-part')));
    expect(args, isNot(contains('--force-overwrites')));
  });

  test('pause suppresses non-zero process exit failure callback', () async {
    final process = _FakeProcess(exitCodeValue: 143);
    final executor = ProcessYtDlpExecutor(
      toolResolver: _resolver(),
      processRunner: (_, _) async => process,
    );
    final changes = <DownloadTask>[];

    await executor.startDownload(
      taskId: 'task-1',
      url: Uri.parse('https://example.com/video'),
      variant: const ResourceVariant(
        label: '推荐',
        description: '适合大多数人',
        isRecommended: true,
        formatId: 'best',
      ),
      settings: _settings(),
      onTaskChanged: changes.add,
    );
    await executor.pause('task-1');
    await process.close();
    await pumpEventQueue();

    expect(process.killedSignals, [ProcessSignal.sigterm]);
    expect(changes.where((task) => task.status == DownloadStatus.failed), isEmpty);
  });

  test('pause does not let old process clear new process tracking', () async {
    final first = _FakeProcess(exitCodeValue: 143);
    final second = _FakeProcess(exitCodeValue: 0);
    var run = 0;
    final executor = ProcessYtDlpExecutor(
      toolResolver: _resolver(),
      processRunner: (_, _) async {
        run += 1;
        return run == 1 ? first : second;
      },
    );

    await executor.startDownload(
      taskId: 'task-1',
      url: Uri.parse('https://example.com/video'),
      variant: const ResourceVariant(
        label: '推荐',
        description: '适合大多数人',
        isRecommended: true,
        formatId: 'best',
      ),
      settings: _settings(),
    );
    await executor.pause('task-1');
    await executor.startDownload(
      taskId: 'task-1',
      url: Uri.parse('https://example.com/video'),
      variant: const ResourceVariant(
        label: '推荐',
        description: '适合大多数人',
        isRecommended: true,
        formatId: 'best',
      ),
      settings: _settings(),
    );
    await first.close();
    await second.close();
    await pumpEventQueue();

    expect(second.killedSignals, isEmpty);
  });

  test('resume-friendly arguments stay stable across restarts', () async {
    final starts = <List<String>>[];
    var run = 0;
    final executor = ProcessYtDlpExecutor(
      toolResolver: _resolver(),
      processRunner: (_, arguments) async {
        starts.add(arguments);
        run += 1;
        return _FakeProcess(exitCodeValue: run == 1 ? 143 : 0);
      },
    );
    const variant = ResourceVariant(
      label: '推荐',
      description: '适合大多数人',
      isRecommended: true,
      formatId: 'best',
    );
    final settings = _settings();
    final url = Uri.parse('https://example.com/video');

    await executor.startDownload(
      taskId: 'task-1',
      url: url,
      variant: variant,
      settings: settings,
    );
    await executor.pause('task-1');
    await executor.startDownload(
      taskId: 'task-1',
      url: url,
      variant: variant,
      settings: settings,
    );

    expect(starts, hasLength(2));
    expect(starts.first, starts.last);
    expect(starts.last, contains('--continue'));
    expect(starts.last, contains('--part'));
  });
}

DownloadSettings _settings() {
  return const DownloadSettings(
    saveDirectory: '/downloads',
    downloadMode: DownloadMode.serial,
    concurrentCount: 1,
    defaultQuality: 'best',
    downloadSubtitles: false,
    downloadThumbnail: false,
  );
}

EmbeddedToolResolver _resolver() {
  return const EmbeddedToolResolver(
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
  );
}

class _FakeProcess implements Process {
  _FakeProcess({required this.exitCodeValue});

  final int exitCodeValue;
  final List<ProcessSignal> killedSignals = [];
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
