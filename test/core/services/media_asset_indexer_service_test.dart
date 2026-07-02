import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/database_service.dart';
import 'package:hiext_yt_gui/core/services/media_asset_indexer_service.dart';
import 'package:hiext_yt_gui/core/services/media_asset_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../sqlite_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late Directory tempDir;
  late MediaAssetRepository repository;
  late MediaAssetIndexerService service;

  setUp(() async {
    initTestSqlite();
    db = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    await createMediaLibraryTestSchema(db);
    DatabaseService().useTestDatabase(db);
    tempDir = Directory.systemTemp.createTempSync('media-asset-indexer-');
    repository = MediaAssetRepository();
    service = MediaAssetIndexerService(repository: repository);
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('indexes a completed downloaded video as a media asset', () async {
    final mediaFile = File('${tempDir.path}/demo.mp4');
    mediaFile.writeAsStringSync('video bytes');
    final task = DownloadTask(
      id: 'download-1',
      title: 'Demo Video',
      source: 'https://example.com/demo',
      status: DownloadStatus.completed,
      progress: 100,
      variants: const [
        ResourceVariant(
          label: '1080p',
          description: 'mp4',
          isRecommended: true,
          type: ResourceType.video,
          formatId: '137',
          videoId: 'demo-id',
          videoTitle: 'Demo Video',
        ),
      ],
      mediaPath: mediaFile.path,
    );

    final asset = await service.indexCompletedDownload(task);

    expect(asset, isNotNull);
    expect(asset!.id, 'media-download-1');
    expect(asset.sourceTaskId, 'download-1');
    expect(asset.sourceUrl, 'https://example.com/demo');
    expect(asset.title, 'Demo Video');
    expect(asset.mediaType, MediaAssetType.video);
    expect(asset.fileSizeBytes, mediaFile.lengthSync());
    expect(asset.fileSha256, hasLength(64));
    expect(asset.metadata['formatId'], '137');

    final persisted = await repository.loadMediaAssetBySourceTask('download-1');
    expect(persisted, isNotNull);
    expect(persisted!.fileSha256, asset.fileSha256);
  });

  test(
    'indexes audio files by extension when variant type is absent',
    () async {
      final mediaFile = File('${tempDir.path}/episode.m4a');
      mediaFile.writeAsStringSync('audio bytes');
      final task = DownloadTask(
        id: 'audio-1',
        title: 'Episode',
        source: 'https://example.com/audio',
        status: DownloadStatus.completed,
        progress: 100,
        variants: const [],
        mediaPath: mediaFile.path,
      );

      final asset = await service.indexCompletedDownload(task);

      expect(asset, isNotNull);
      expect(asset!.mediaType, MediaAssetType.audio);
    },
  );

  test('skips completed downloads without a usable media file', () async {
    final noPath = DownloadTask(
      id: 'missing-path',
      title: 'No Path',
      source: 'https://example.com/no-path',
      status: DownloadStatus.completed,
      progress: 100,
      variants: const [],
    );
    final missingFile = DownloadTask(
      id: 'missing-file',
      title: 'Missing File',
      source: 'https://example.com/missing-file',
      status: DownloadStatus.completed,
      progress: 100,
      variants: const [],
      mediaPath: '${tempDir.path}/missing.mp4',
    );

    expect(await service.indexCompletedDownload(noPath), isNull);
    expect(await service.indexCompletedDownload(missingFile), isNull);
    expect(await repository.loadMediaAssets(), isEmpty);
  });
}
