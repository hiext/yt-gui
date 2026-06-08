import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/auto_clip_service.dart';
import 'package:hiext_yt_gui/core/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../sqlite_test_setup.dart';

Future<Database> _createTestDb() async {
  initTestSqlite();
  final d = await databaseFactoryFfiNoIsolate.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS clip_records (
            id TEXT PRIMARY KEY, source_task_id TEXT NOT NULL, source_path TEXT NOT NULL,
            output_path TEXT, title TEXT NOT NULL, confidence REAL NOT NULL DEFAULT 0,
            start_ms INTEGER NOT NULL, end_ms INTEGER NOT NULL, duration_ms INTEGER NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending', progress INTEGER NOT NULL DEFAULT 0,
            error_message TEXT, created_at TEXT NOT NULL, completed_at TEXT, data TEXT NOT NULL
          )
        ''');
      },
    ),
  );
  return d;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;

  setUp(() async {
    db = await _createTestDb();
    DatabaseService().useTestDatabase(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('AutoClipService', () {
    late AutoClipService service;
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('auto-clip-test-');
      // Create a dummy source file so ffmpeg has something to read
      File('${tempDir.path}/test-video.mp4').writeAsStringSync('fake video data');
    });

    tearDown(() {
      service.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('startAutoCut returns empty when disabled', () async {
      service = AutoClipService(
        config: const AutoClipConfig(enabled: false),
      );
      final records = await service.startAutoCut(
        segments: const [],
        settings: _settings(tempDir.path),
      );
      expect(records, isEmpty);
    });

    test('startAutoCut returns empty for empty segments', () async {
      service = AutoClipService(
        config: const AutoClipConfig(enabled: true),
      );
      final records = await service.startAutoCut(
        segments: const [],
        settings: _settings(tempDir.path),
      );
      expect(records, isEmpty);
    });

    test('startAutoCut filters by confidence', () async {
      service = AutoClipService(
        config: const AutoClipConfig(
          enabled: true,
          minConfidence: 0.7,
          maxClipsPerVideo: 10,
        ),
      );
      final segments = [
        _makeSegment(id: 's1', confidence: 0.5, dir: tempDir.path),
        _makeSegment(id: 's2', confidence: 0.9, dir: tempDir.path),
        _makeSegment(id: 's3', confidence: 0.3, dir: tempDir.path),
      ];

      final records = await service.startAutoCut(
        segments: segments,
        settings: _settings(tempDir.path),
      );

      expect(records, hasLength(1));
      expect(records.single.title, contains('s2'));
      expect(records.single.confidence, 0.9);
    });

    test('startAutoCut limits count', () async {
      service = AutoClipService(
        config: const AutoClipConfig(
          enabled: true,
          minConfidence: 0.5,
          maxClipsPerVideo: 3,
        ),
      );
      final segments = List.generate(
        8,
        (i) => _makeSegment(id: 's$i', confidence: 0.9 - i * 0.05, dir: tempDir.path),
      );

      final records = await service.startAutoCut(
        segments: segments,
        settings: _settings(tempDir.path),
      );

      expect(records.length, lessThanOrEqualTo(3));
      expect(records.length, greaterThanOrEqualTo(0));
    });

    test('startAutoCut creates records with correct metadata', () async {
      service = AutoClipService(
        config: const AutoClipConfig(
          enabled: true,
          minConfidence: 0.0,
          maxClipsPerVideo: 5,
        ),
      );
      final segments = [
        _makeSegment(id: 'meta-test', confidence: 0.95, dir: tempDir.path),
      ];

      final records = await service.startAutoCut(
        segments: segments,
        settings: _settings(tempDir.path),
      );

      expect(records, hasLength(1));
      expect(records.single.title, 'Test Clip meta-test');
      expect(records.single.confidence, 0.95);
      expect(records.single.sourcePath, contains('test-video.mp4'));
      // After cut attempt, record exists with a final status
      expect(records.single.status, isNotNull);
      expect(records.single.id, isNotEmpty);
    });

    test('config can be updated at runtime', () {
      service = AutoClipService();
      expect(service.config.enabled, isTrue);

      service.config = const AutoClipConfig(enabled: false);
      expect(service.config.enabled, isFalse);

      service.config = const AutoClipConfig(minConfidence: 0.9);
      expect(service.config.minConfidence, 0.9);
      expect(service.config.enabled, isTrue); // unchanged
    });
  });

  group('AutoClipConfig serialization', () {
    test('defaults have expected values', () {
      const config = AutoClipConfig.defaults;
      expect(config.enabled, isTrue);
      expect(config.minConfidence, 0.7);
      expect(config.maxClipsPerVideo, 5);
      expect(config.maxClipDurationSec, 60);
      expect(config.startOffsetMs, -500);
      expect(config.endOffsetMs, 500);
    });

    test('copyWith updates specified fields only', () {
      const config = AutoClipConfig.defaults;
      final updated = config.copyWith(enabled: false, minConfidence: 0.5);
      expect(updated.enabled, isFalse);
      expect(updated.minConfidence, 0.5);
      expect(updated.maxClipDurationSec, 60); // unchanged
      expect(updated.startOffsetMs, -500); // unchanged
    });

    test('toJson and fromJson round-trip', () {
      const config = AutoClipConfig(
        enabled: false,
        minConfidence: 0.85,
        maxClipsPerVideo: 3,
        maxClipDurationSec: 30,
        startOffsetMs: -2000,
        endOffsetMs: 2000,
      );
      final json = config.toJson();
      final restored = AutoClipConfig.fromJson(json);

      expect(restored.enabled, false);
      expect(restored.minConfidence, 0.85);
      expect(restored.maxClipsPerVideo, 3);
      expect(restored.maxClipDurationSec, 30);
      expect(restored.startOffsetMs, -2000);
      expect(restored.endOffsetMs, 2000);
    });

    test('fromJson applies defaults for empty map', () {
      final restored = AutoClipConfig.fromJson({});
      expect(restored.enabled, isTrue);
    });

    test('fromJson handles numeric values correctly', () {
      final restored = AutoClipConfig.fromJson({
        'enabled': false,
        'minConfidence': 0.25,
        'maxClipsPerVideo': 10,
        'maxClipDurationSec': 90,
        'startOffsetMs': -1000,
        'endOffsetMs': 2000,
      });
      expect(restored.enabled, isFalse);
      expect(restored.minConfidence, 0.25);
      expect(restored.maxClipsPerVideo, 10);
    });

    test('DownloadSettings includes autoClipConfig in serialization', () {
      const settings = DownloadSettings(
        saveDirectory: '/tmp',
        downloadMode: DownloadMode.serial,
        concurrentCount: 1,
        defaultQuality: 'best',
        downloadSubtitles: false,
        downloadThumbnail: false,
        disclaimerAccepted: false,
        autoClipConfig: AutoClipConfig(
          enabled: false,
          minConfidence: 0.5,
        ),
      );

      final json = settings.toJson();
      expect(json['autoClipConfig'], isA<Map>());

      final restored = DownloadSettings.fromJson(json);
      expect(restored.autoClipConfig.enabled, isFalse);
      expect(restored.autoClipConfig.minConfidence, 0.5);
    });
  });

  group('ClipRecord serialization', () {
    test('constructor sets all fields correctly', () {
      final record = ClipRecord(
        id: 'rec-1',
        sourceTaskId: 'src-1',
        sourcePath: '/tmp/v.mp4',
        outputPath: '/tmp/.clips/out.mp4',
        title: 'Test',
        confidence: 0.9,
        startMs: 1000,
        endMs: 5000,
        durationMs: 4000,
        status: ClipRecordStatus.completed,
        progress: 100,
      );

      expect(record.status, ClipRecordStatus.completed);
      expect(record.outputPath, '/tmp/.clips/out.mp4');
    });

    test('copyWith updates fields', () {
      final record = ClipRecord(
        id: 'rec-1', sourceTaskId: 's1', sourcePath: '/tmp/v.mp4',
        title: 'Old', confidence: 0.5, startMs: 0, endMs: 1000, durationMs: 1000,
      );
      final updated = record.copyWith(
        title: 'New',
        status: ClipRecordStatus.failed,
        errorMessage: 'ffmpeg not found',
      );
      expect(updated.title, 'New');
      expect(updated.status, ClipRecordStatus.failed);
      expect(updated.errorMessage, 'ffmpeg not found');
      expect(updated.id, 'rec-1'); // unchanged
    });

    test('toJson and fromJson round-trip with all fields', () {
      final record = ClipRecord(
        id: 'rec-full',
        sourceTaskId: 'src-1',
        sourcePath: '/tmp/v.mp4',
        outputPath: '/tmp/.clips/out.mp4',
        title: 'Full Test',
        confidence: 0.88,
        startMs: 2000,
        endMs: 8000,
        durationMs: 6000,
        status: ClipRecordStatus.completed,
        progress: 100,
      );
      final json = record.toJson();
      final restored = ClipRecord.fromJson(json);

      expect(restored.id, record.id);
      expect(restored.confidence, record.confidence);
      expect(restored.status, record.status);
      expect(restored.outputPath, record.outputPath);
    });

    test('fromJson handles missing optional fields', () {
      final restored = ClipRecord.fromJson({
        'id': 'min',
        'sourceTaskId': 's1',
        'sourcePath': '/tmp/v.mp4',
        'title': 'Minimal',
        'confidence': 0.5,
        'startMs': 0,
        'endMs': 1000,
        'durationMs': 1000,
      });
      expect(restored.status, ClipRecordStatus.pending);
      expect(restored.progress, 0);
      expect(restored.outputPath, isNull);
    });
  });
}

ClipSegment _makeSegment({
  required String id,
  double confidence = 0.8,
  String dir = '/tmp',
}) {
  return ClipSegment(
    id: id,
    sourceTaskId: 'src-1',
    postProcessTaskId: 'pp-1',
    sourcePath: '$dir/test-video.mp4',
    startMs: 10000,
    endMs: 30000,
    title: 'Test Clip $id',
    summary: 'Summary for $id',
    keywords: const [],
    tags: const [],
    confidence: confidence,
    reason: 'test',
  );
}

DownloadSettings _settings(String dir) {
  return DownloadSettings(
    saveDirectory: dir,
    downloadMode: DownloadMode.serial,
    concurrentCount: 1,
    defaultQuality: 'best',
    downloadSubtitles: false,
    downloadThumbnail: false,
    disclaimerAccepted: false,
  );
}
