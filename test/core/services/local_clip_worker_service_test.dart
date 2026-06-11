import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/database_service.dart';
import 'package:hiext_yt_gui/core/services/local_clip_worker_service.dart';
import 'package:hiext_yt_gui/core/services/media_asset_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../sqlite_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late MediaAssetRepository repository;
  late Directory tempDir;

  setUp(() async {
    initTestSqlite();
    db = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    await createMediaLibraryTestSchema(db);
    DatabaseService().useTestDatabase(db);
    repository = MediaAssetRepository();
    tempDir = Directory.systemTemp.createTempSync('local-clip-worker-');
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('exports a candidate with ffmpeg and stores export record', () async {
    final process = _FakeProcess(exitCodeValue: 0);
    String? executable;
    List<String>? arguments;
    final service = LocalClipWorkerService(
      repository: repository,
      processRunner: (path, args) async {
        executable = path;
        arguments = args;
        return process;
      },
      ffmpegPathResolver: (_) => '/tools/ffmpeg',
    );
    final asset = _asset();
    await repository.saveMediaAsset(asset);
    final candidate = ClipCandidate(
      id: 'candidate-1',
      mediaAssetId: asset.id,
      startMs: 1000,
      endMs: 9000,
      title: 'Strong hook',
      summary: 'The first hook',
      score: 0.9,
      reason: 'test',
    );

    final record = await service.exportCandidate(
      asset: asset,
      candidate: candidate,
      settings: _settings(tempDir.path),
    );
    await process.close();
    await pumpEventQueue();

    expect(executable, '/tools/ffmpeg');
    expect(arguments, containsAll(['-ss', '00:00:01', '-t', '00:00:08']));
    expect(record.status, ClipExportStatus.completed);
    expect(record.progress, 100);
    expect(record.outputPath, contains('asset-1_candidate-1.mp4'));
    final persisted = await repository.loadClipExportRecords(asset.id);
    expect(persisted.single.status, ClipExportStatus.completed);
  });

  test('stores failed export record when ffmpeg fails', () async {
    final process = _FakeProcess(exitCodeValue: 1);
    final service = LocalClipWorkerService(
      repository: repository,
      processRunner: (_, _) async => process,
      ffmpegPathResolver: (_) => '/tools/ffmpeg',
    );
    final asset = _asset();
    await repository.saveMediaAsset(asset);
    final candidate = ClipCandidate(
      id: 'candidate-fail',
      mediaAssetId: asset.id,
      startMs: 0,
      endMs: 3000,
      title: 'Fail',
      summary: 'Fail',
      score: 0.1,
      reason: 'test',
    );

    final record = await service.exportCandidate(
      asset: asset,
      candidate: candidate,
      settings: _settings(tempDir.path),
    );
    await process.close();
    await pumpEventQueue();

    expect(record.status, ClipExportStatus.failed);
    expect(record.errorMessage, contains('ffmpeg exited with code 1'));
    final persisted = await repository.loadClipExportRecords(asset.id);
    expect(persisted.single.status, ClipExportStatus.failed);
  });

  test(
    'parses ffmpeg stderr progress and stores intermediate record',
    () async {
      final process = _FakeProcess(exitCodeValue: 0, autoClose: false);
      final service = LocalClipWorkerService(
        repository: repository,
        processRunner: (_, _) async => process,
        ffmpegPathResolver: (_) => '/tools/ffmpeg',
      );
      final asset = _asset();
      await repository.saveMediaAsset(asset);
      final candidate = ClipCandidate(
        id: 'candidate-progress',
        mediaAssetId: asset.id,
        startMs: 1000,
        endMs: 9000,
        title: 'Progress hook',
        summary: 'Progress',
        score: 0.9,
        reason: 'test',
      );
      final progressValues = <int>[];

      final exportFuture = service.exportCandidate(
        asset: asset,
        candidate: candidate,
        settings: _settings(tempDir.path),
        onProgress: (_, progress) => progressValues.add(progress),
      );
      await pumpEventQueue();

      process.addStderr(
        'frame=12 fps=0.0 size=0kB time=00:00:04.00 bitrate=N/A speed=1x\n',
      );
      await pumpEventQueue();

      var persisted = await repository.loadClipExportRecords(asset.id);
      expect(persisted.single.progress, 50);
      expect(progressValues, contains(50));

      await process.close();
      final record = await exportFuture;

      expect(record.status, ClipExportStatus.completed);
      persisted = await repository.loadClipExportRecords(asset.id);
      expect(persisted.single.progress, 100);
    },
  );
}

MediaAsset _asset() {
  return MediaAsset(
    id: 'asset-1',
    sourceTaskId: 'download-1',
    sourceUrl: 'https://example.com/video',
    title: 'Video',
    mediaPath: '/downloads/video.mp4',
    mediaType: MediaAssetType.video,
    fileSha256: 'e' * 64,
    durationMs: 10000,
    fileSizeBytes: 100,
  );
}

DownloadSettings _settings(String saveDirectory) {
  return DownloadSettings(
    saveDirectory: saveDirectory,
    downloadMode: DownloadMode.serial,
    concurrentCount: 1,
    defaultQuality: 'best',
    downloadSubtitles: false,
    downloadThumbnail: false,
    disclaimerAccepted: false,
  );
}

class _FakeProcess implements Process {
  _FakeProcess({required this.exitCodeValue, this.autoClose = true}) {
    if (autoClose) {
      scheduleMicrotask(close);
    }
  }

  final int exitCodeValue;
  final bool autoClose;
  final _stdout = StreamController<List<int>>();
  final _stderr = StreamController<List<int>>();
  final _exit = Completer<int>();

  void addStderr(String value) {
    _stderr.add(value.codeUnits);
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
