import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/l10n/app_localizations.dart';
import 'package:hiext_yt_gui/core/services/embedded_tool_manifest.dart';
import 'package:hiext_yt_gui/core/services/embedded_tool_resolver.dart';
import 'package:hiext_yt_gui/core/services/process_yt_dlp_executor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('inspect parses format variants from yt-dlp json output', () async {
    final process = _FakeProcess(exitCodeValue: 0);
    final executor = ProcessYtDlpExecutor(
      toolResolver: _resolver(),
      processRunner: (_, _) async => process,
    );

    final inspectFuture = executor.inspect(
      Uri.parse('https://example.com/video'),
      localizations: lookupAppLocalizations(const Locale('en')),
    );
    process.addStdout(
      '''{"formats":[{"format_id":"137","height":1080,"ext":"mp4"},{"format_id":"140","ext":"m4a"}]}''',
    );
    await process.close();

    final variants = await inspectFuture;

    expect(variants.length, greaterThanOrEqualTo(2));
    expect(variants.where((v) => v.isRecommended), hasLength(2));
    expect(variants.first.formatId, 'bestvideo+bestaudio');
    expect(variants.first.label, 'Best Quality (1080p video + audio merge)');
    expect(variants[1].formatId, '137+bestaudio/best');
    expect(variants[1].label, '1080p Video + Audio Merge');
    expect(
      variants.firstWhere((v) => v.formatId == '137').isRecommended,
      false,
    );
    expect(variants.last.label, 'Audio 140');
    expect(variants.last.formatId, '140');
  });

  test('inspect honors configured recommended variant count', () async {
    final process = _FakeProcess(exitCodeValue: 0);
    final executor = ProcessYtDlpExecutor(
      toolResolver: _resolver(),
      processRunner: (_, _) async => process,
    );

    final inspectFuture = executor.inspect(
      Uri.parse('https://example.com/video'),
      settings: DownloadSettings.defaults.copyWith(recommendedVariantCount: 3),
      localizations: lookupAppLocalizations(const Locale('en')),
    );
    process.addStdout(
      '''{"formats":[{"format_id":"313","height":2160,"ext":"webm"},{"format_id":"137","height":1080,"ext":"mp4"},{"format_id":"140","ext":"m4a"}]}''',
    );
    await process.close();

    final variants = await inspectFuture;
    final recommended = variants.where((v) => v.isRecommended).toList();

    expect(recommended, hasLength(3));
    expect(recommended.map((v) => v.formatId), [
      'bestvideo+bestaudio',
      '313+bestaudio/best',
      '137+bestaudio/best',
    ]);
  });

  test('inspect throws when yt-dlp exits with a non-zero status', () async {
    final process = _FakeProcess(exitCodeValue: 1);
    final executor = ProcessYtDlpExecutor(
      toolResolver: _resolver(),
      processRunner: (_, _) async => process,
    );

    final inspectFuture = executor.inspect(
      Uri.parse('https://example.com/video'),
    );
    await process.close();

    await expectLater(inspectFuture, throwsA(isA<YtDlpExecutorException>()));
  });

  test('inspect forwards verbose logs through callback', () async {
    final process = _FakeProcess(exitCodeValue: 0);
    final executor = ProcessYtDlpExecutor(
      toolResolver: _resolver(),
      processRunner: (_, _) async => process,
    );
    final logs = <String>[];

    final inspectFuture = executor.inspect(
      Uri.parse('https://example.com/video'),
      onLog: logs.add,
      localizations: lookupAppLocalizations(const Locale('en')),
    );
    process.addStderr('[debug] Extracting URL: https://example.com/video');
    process.addStdout(
      '{"formats":[{"format_id":"137","height":1080,"ext":"mp4"}]}',
    );
    await process.close();

    await inspectFuture;

    expect(logs, contains('[debug] Extracting URL: https://example.com/video'));
    expect(
      logs,
      isNot(
        contains('{"formats":[{"format_id":"137","height":1080,"ext":"mp4"}]}'),
      ),
    );
  });

  test('inspect uses custom yt-dlp path from settings', () async {
    final ytDlp = _createToolFile('yt-dlp');
    final process = _FakeProcess(exitCodeValue: 0);
    String? executable;
    final executor = ProcessYtDlpExecutor(
      toolResolver: _resolver(),
      processRunner: (path, _) async {
        executable = path;
        return process;
      },
    );

    final inspectFuture = executor.inspect(
      Uri.parse('https://example.com/video'),
      settings: DownloadSettings.defaults.copyWith(ytDlpPath: ytDlp.path),
    );
    await process.close();
    await inspectFuture;

    expect(executable, ytDlp.path);
  });

  test(
    'inspect uses PATH fallback when bundled asset is unavailable',
    () async {
      final tempDir = Directory.systemTemp.createTempSync('yt-dlp-fallback-');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final ytDlp = File('${tempDir.path}/yt-dlp.exe')..writeAsStringSync('');
      File('${tempDir.path}/ffmpeg.exe').writeAsStringSync('');
      final process = _FakeProcess(exitCodeValue: 0);
      String? executable;
      final executor = ProcessYtDlpExecutor(
        toolResolver: EmbeddedToolResolver(
          platformOverride: EmbeddedToolPlatform.windows,
          environment: {'PATH': tempDir.path},
        ),
        processRunner: (path, _) async {
          executable = path;
          return process;
        },
      );

      final inspectFuture = executor.inspect(
        Uri.parse('https://example.com/video'),
        localizations: lookupAppLocalizations(const Locale('en')),
      );
      await process.close();
      await inspectFuture;

      expect(executable, ytDlp.absolute.path);
    },
  );

  test('startDownload uses custom yt-dlp and ffmpeg paths', () async {
    final ytDlp = _createToolFile('yt-dlp');
    final ffmpeg = _createToolFile('ffmpeg');
    String? executable;
    List<String>? arguments;
    final executor = ProcessYtDlpExecutor(
      toolResolver: _resolver(),
      processRunner: (path, args) async {
        executable = path;
        arguments = args;
        return _FakeProcess(exitCodeValue: 0);
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
      settings: _settings(ytDlpPath: ytDlp.path, ffmpegPath: ffmpeg.path),
    );

    expect(executable, ytDlp.path);
    expect(arguments, containsAll(['--ffmpeg-location', ffmpeg.path]));
  });

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
        disclaimerAccepted: false,
      ),
      ffmpegPath: '/tools/ffmpeg',
    );

    expect(
      args,
      containsAll(['--newline', '--continue', '--part', '--ffmpeg-location']),
    );
    expect(
      args,
      containsAll([
        '--progress-template',
        'download:__HIEYT_PROGRESS__:%(progress.status)s|'
            '%(progress._percent_str)s|'
            '%(progress._speed_str)s|'
            '%(progress._eta_str)s',
      ]),
    );
    expect(
      args,
      containsAll(['--print', 'after_move:__HIEYT_FILEPATH__:%(filepath)s']),
    );
    expect(args, containsAll(['/tools/ffmpeg', '--write-subs']));
    expect(
      args,
      containsAll(['--write-thumbnail', '-f', 'bestvideo+bestaudio']),
    );
    expect(
      args,
      containsAll(['-P', '/downloads', 'https://example.com/video']),
    );
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
    expect(
      changes.where((task) => task.status == DownloadStatus.failed),
      isEmpty,
    );
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

  test(
    'inspect handles JSON with embedded \\r characters gracefully',
    () async {
      final process = _FakeProcess(exitCodeValue: 0);
      final executor = ProcessYtDlpExecutor(
        toolResolver: _resolver(),
        processRunner: (_, _) async => process,
      );

      final inspectFuture = executor.inspect(
        Uri.parse('https://example.com/video'),
        localizations: lookupAppLocalizations(const Locale('en')),
      );
      // Simulate JSON output with \r inside a string value (like MHTML URLs)
      process.addStdout(
        '{"id":"test","title":"Test","formats":['
        '{"format_id":"sb3","format_note":"storyboard",'
        '"ext":"mhtml","acodec":"none","vcodec":"none",'
        '"url":"https://example.com/sb/L0.jpg?M\\u0026M",'
        '"width":48,"height":27,"fps":0.03}'
        ']}\r\n',
      );
      await process.close();

      final variants = await inspectFuture;
      expect(variants, isNotEmpty);
    },
  );

  test(
    'inspect handles JSON with special characters in string values',
    () async {
      final process = _FakeProcess(exitCodeValue: 0);
      final executor = ProcessYtDlpExecutor(
        toolResolver: _resolver(),
        processRunner: (_, _) async => process,
      );

      final inspectFuture = executor.inspect(
        Uri.parse('https://example.com/video'),
        localizations: lookupAppLocalizations(const Locale('en')),
      );
      // JSON with escaped special characters (realistic for MHTML URLs)
      process.addStdout(
        '{"id":"test","title":"Test with unicode \\\\u0026",'
        '"formats":[{"format_id":"sb3","format_note":"storyboard",'
        '"ext":"mhtml","acodec":"none","vcodec":"none",'
        '"url":"https://example.com/sb/L0.jpg?sigh=rs\\\\u0026M",'
        '"width":48,"height":27,"fps":0.03}]'
        '}',
      );
      await process.close();

      final variants = await inspectFuture;
      expect(variants, isNotEmpty);
    },
  );

  test('reports final media path printed by yt-dlp', () async {
    final process = _FakeProcess(exitCodeValue: 0);
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
    process.addStdout('__HIEYT_FILEPATH__:/downloads/video.mp4');
    await process.close();
    await pumpEventQueue();

    expect(
      changes.where((task) => task.mediaPath == '/downloads/video.mp4'),
      isNotEmpty,
    );
    expect(changes.last.status, DownloadStatus.completed);
    expect(changes.last.mediaPath, '/downloads/video.mp4');
  });

  test('reports progress from custom progress template output', () async {
    final process = _FakeProcess(exitCodeValue: 0);
    final executor = ProcessYtDlpExecutor(
      toolResolver: _resolver(),
      processRunner: (_, _) async => process,
    );
    final changes = <DownloadTask>[];

    await executor.startDownload(
      taskId: 'task-1',
      url: Uri.parse('https://www.youtube.com/watch?v=NCtc5lIV7pM'),
      variant: const ResourceVariant(
        label: '最佳品质（1080p 视频+音频合并）',
        description: '适合大多数人',
        isRecommended: true,
        formatId: '399+251',
      ),
      settings: _settings(),
      onTaskChanged: changes.add,
    );
    process.addStdout('__HIEYT_PROGRESS__:downloading| 12.5%|1.23MiB/s|00:42');
    await process.close();
    await pumpEventQueue();

    expect(changes.any((task) => task.progress == 12.5), isTrue);
    expect(changes.any((task) => task.speed == '1.23MiB/s'), isTrue);
  });
}

DownloadSettings _settings({String? ytDlpPath, String? ffmpegPath}) {
  return DownloadSettings(
    saveDirectory: '/downloads',
    downloadMode: DownloadMode.serial,
    concurrentCount: 1,
    defaultQuality: 'best',
    downloadSubtitles: false,
    downloadThumbnail: false,
    disclaimerAccepted: false,
    ytDlpPath: ytDlpPath,
    ffmpegPath: ffmpegPath,
  );
}

File _createToolFile(String name) {
  final tempDir = Directory.systemTemp.createTempSync('yt-dlp-executor-');
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
  final List<ProcessSignal> killedSignals = [];
  final _stdout = StreamController<List<int>>();
  final _stderr = StreamController<List<int>>();
  final _exit = Completer<int>();

  void addStdout(String line) {
    _stdout.add('$line\n'.codeUnits);
  }

  void addStderr(String line) {
    _stderr.add('$line\n'.codeUnits);
  }

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
