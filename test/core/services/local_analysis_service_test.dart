import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/database_service.dart';
import 'package:hiext_yt_gui/core/services/local_analysis_service.dart';
import 'package:hiext_yt_gui/core/services/media_asset_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../sqlite_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late MediaAssetRepository repository;

  setUp(() async {
    initTestSqlite();
    db = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    await createMediaLibraryTestSchema(db);
    DatabaseService().useTestDatabase(db);
    repository = MediaAssetRepository();
  });

  tearDown(() async {
    await db.close();
  });

  test('extracts ffprobe metadata and stores candidates and vectors', () async {
    final process = _FakeProcess(
      stdoutText: jsonEncode({
        'format': {'duration': '12.5', 'size': '2048'},
        'streams': [
          {'codec_type': 'video', 'width': 1920, 'height': 1080},
          {'codec_type': 'audio', 'codec_name': 'aac'},
        ],
      }),
    );
    String? executable;
    List<String>? arguments;
    final service = LocalAnalysisService(
      repository: repository,
      processRunner: (path, args) async {
        executable = path;
        arguments = args;
        return process;
      },
      ffprobePathResolver: (_) => '/tools/ffprobe',
    );
    final asset = _asset();
    await repository.saveMediaAsset(asset);
    final segment = ClipSegment(
      id: 'seg-1',
      sourceTaskId: asset.sourceTaskId,
      postProcessTaskId: 'post-1',
      sourcePath: asset.mediaPath,
      startMs: 1000,
      endMs: 6000,
      title: 'Launch hook',
      summary: 'A dense opening promise',
      keywords: const ['launch', 'hook'],
      tags: const ['built-in'],
      confidence: 0.83,
      reason: 'speech density',
    );

    final result = await service.analyze(
      asset: asset,
      settings: _settings(),
      seedSegments: [segment],
    );

    expect(executable, '/tools/ffprobe');
    expect(arguments, containsAll(['-show_format', '-show_streams']));
    expect(result.job.status, MediaAnalysisStatus.completed);
    expect(result.candidates.single.id, 'local:seg-1');
    expect(result.candidates.single.score, 0.83);
    expect(result.vectors, isNotEmpty);

    final updatedAsset = await repository.loadMediaAsset(asset.id);
    expect(updatedAsset!.durationMs, 12500);
    expect(updatedAsset.fileSizeBytes, 2048);
    expect(updatedAsset.metadata['ffprobe'], isA<Map<String, Object?>>());
    expect(await repository.loadAnalysisJobs(asset.id), hasLength(1));
    expect(await repository.loadClipCandidates(asset.id), hasLength(1));
    expect(await repository.loadVectorRecords(asset.id), isNotEmpty);
  });

  test('marks analysis failed when ffprobe exits with non-zero code', () async {
    final service = LocalAnalysisService(
      repository: repository,
      processRunner: (_, _) async =>
          _FakeProcess(exitCodeValue: 1, stderrText: 'ffprobe failed'),
      ffprobePathResolver: (_) => '/tools/ffprobe',
    );
    final asset = _asset();
    await repository.saveMediaAsset(asset);

    final result = await service.analyze(asset: asset, settings: _settings());

    expect(result.job.status, MediaAnalysisStatus.failed);
    expect(result.job.errorMessage, contains('ffprobe failed'));
    expect(await repository.loadClipCandidates(asset.id), isEmpty);
  });
}

MediaAsset _asset() {
  return MediaAsset(
    id: 'asset-1',
    sourceTaskId: 'download-1',
    sourceUrl: 'https://example.com/video',
    title: 'Launch Video',
    mediaPath: '/downloads/video.mp4',
    mediaType: MediaAssetType.video,
    fileSha256: 'd' * 64,
    durationMs: 0,
    fileSizeBytes: 0,
  );
}

DownloadSettings _settings() {
  return const DownloadSettings(
    saveDirectory: '/downloads',
    downloadMode: DownloadMode.serial,
    concurrentCount: 1,
    defaultQuality: 'best',
    downloadSubtitles: false,
    downloadThumbnail: false,
    disclaimerAccepted: false,
  );
}

class _FakeProcess implements Process {
  _FakeProcess({
    this.exitCodeValue = 0,
    this.stdoutText = '',
    this.stderrText = '',
  }) {
    scheduleMicrotask(() async {
      _stdout.add(utf8.encode(stdoutText));
      _stderr.add(utf8.encode(stderrText));
      await _stdout.close();
      await _stderr.close();
      _exit.complete(exitCodeValue);
    });
  }

  final int exitCodeValue;
  final String stdoutText;
  final String stderrText;
  final _stdout = StreamController<List<int>>();
  final _stderr = StreamController<List<int>>();
  final _exit = Completer<int>();

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
