import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/database_service.dart';
import 'package:hiext_yt_gui/core/services/settings_repository.dart';
import '../../sqlite_test_setup.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> _createTestDb() async {
  initTestSqlite();
  final db = await databaseFactoryFfiNoIsolate.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL, source TEXT NOT NULL, status TEXT NOT NULL, progress REAL NOT NULL DEFAULT 0, data TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE cookie_configs (id INTEGER PRIMARY KEY AUTOINCREMENT, domain TEXT NOT NULL UNIQUE, data TEXT NOT NULL)',
        );
      },
    ),
  );
  return db;
}

late Database _testDb;

void main() {
  group('SettingsRepository', () {
    setUp(() async {
      _testDb = await _createTestDb();
      DatabaseService().useTestDatabase(_testDb);
    });

    tearDown(() async {
      await _testDb.close();
    });

    test('loads defaults when no settings are saved', () async {
      final repository = SettingsRepository();

      final settings = await repository.load();

      expect(settings.saveDirectory, isNotEmpty);
      expect(settings.defaultQuality, 'best');
      expect(settings.ytDlpPath, isNull);
      expect(settings.ffmpegPath, isNull);
    });

    test('saves and loads settings', () async {
      final repository = SettingsRepository();
      const settings = DownloadSettings(
        saveDirectory: '/downloads',
        downloadMode: DownloadMode.concurrent,
        concurrentCount: 3,
        defaultQuality: 'bestvideo+bestaudio',
        downloadSubtitles: true,
        downloadThumbnail: true,
        disclaimerAccepted: true,
        ytDlpPath: '/tools/yt-dlp',
        ffmpegPath: '/tools/ffmpeg',
      );

      await repository.save(settings);
      final restored = await repository.load();

      expect(restored.saveDirectory, '/downloads');
      expect(restored.downloadMode, DownloadMode.concurrent);
      expect(restored.concurrentCount, 3);
      expect(restored.defaultQuality, 'bestvideo+bestaudio');
      expect(restored.downloadSubtitles, isTrue);
      expect(restored.downloadThumbnail, isTrue);
      expect(restored.disclaimerAccepted, isTrue);
      expect(restored.ytDlpPath, '/tools/yt-dlp');
      expect(restored.ffmpegPath, '/tools/ffmpeg');
    });

    test('removes optional tool paths when they are cleared', () async {
      final repository = SettingsRepository();
      await repository.save(
        DownloadSettings.defaults.copyWith(
          ytDlpPath: '/tools/yt-dlp',
          ffmpegPath: '/tools/ffmpeg',
        ),
      );

      await repository.save(DownloadSettings.defaults);
      final restored = await repository.load();

      expect(restored.ytDlpPath, isNull);
      expect(restored.ffmpegPath, isNull);
    });
  });
}
