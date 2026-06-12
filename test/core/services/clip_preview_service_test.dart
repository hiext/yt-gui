import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/clip_preview_service.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('clip-preview-service-');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test(
    'generates cached preview from completed export at clip start',
    () async {
      final source = File('${tempDir.path}/source.mp4')
        ..writeAsStringSync('video');
      final ffmpeg = File('${tempDir.path}/ffmpeg')..writeAsStringSync('');
      final export = File('${tempDir.path}/clips/result.mp4')
        ..createSync(recursive: true)
        ..writeAsStringSync('clip');
      String? executable;
      List<String>? arguments;
      final process = _FakeProcess(
        onExit: () {
          final outputPath = arguments!.last;
          File(outputPath)
            ..createSync(recursive: true)
            ..writeAsStringSync('jpg');
        },
      );
      final service = ClipPreviewService(
        processRunner: (path, args) async {
          executable = path;
          arguments = args;
          return process;
        },
      );

      final previewPath = await service.resolvePreviewPath(
        asset: _asset(source.path),
        candidate: _candidate(),
        export: ClipExportRecord(
          id: 'export-1',
          mediaAssetId: 'asset-1',
          candidateId: 'candidate-1',
          startMs: 62000,
          endMs: 76000,
          outputPath: export.path,
          status: ClipExportStatus.completed,
          progress: 100,
        ),
        settings: DownloadSettings(
          saveDirectory: '/tmp',
          downloadMode: DownloadMode.serial,
          concurrentCount: 1,
          defaultQuality: 'best',
          downloadSubtitles: false,
          downloadThumbnail: false,
          disclaimerAccepted: false,
          ffmpegPath: ffmpeg.path,
        ),
      );

      expect(executable, ffmpeg.path);
      expect(arguments, containsAll(['-ss', '00:00:00', '-frames:v', '1']));
      expect(arguments, contains(export.path));
      expect(previewPath, endsWith('clips/previews/asset-1_candidate-1.jpg'));
      expect(File(previewPath!).existsSync(), isTrue);
    },
  );
}

MediaAsset _asset(String mediaPath) {
  return MediaAsset(
    id: 'asset-1',
    sourceTaskId: 'download-1',
    sourceUrl: 'https://example.com/video',
    title: 'Video',
    mediaPath: mediaPath,
    mediaType: MediaAssetType.video,
    fileSha256: 'f' * 64,
    durationMs: 120000,
    fileSizeBytes: 100,
  );
}

ClipCandidate _candidate() {
  return ClipCandidate(
    id: 'candidate-1',
    mediaAssetId: 'asset-1',
    startMs: 62000,
    endMs: 76000,
    title: 'Result',
    summary: 'Result',
    score: 0.8,
    reason: 'test',
  );
}

class _FakeProcess implements Process {
  _FakeProcess({required this.onExit}) {
    scheduleMicrotask(close);
  }

  final void Function() onExit;
  final _stdout = StreamController<List<int>>();
  final _stderr = StreamController<List<int>>();
  final _exit = Completer<int>();

  Future<void> close() async {
    await _stdout.close();
    await _stderr.close();
    onExit();
    if (!_exit.isCompleted) _exit.complete(0);
  }

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;

  @override
  int get pid => 1;

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => _stderr.stream;
}
