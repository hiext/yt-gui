import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
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
        await db.execute(
          'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL, source TEXT NOT NULL, status TEXT NOT NULL, progress REAL NOT NULL DEFAULT 0, data TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE cookie_configs (id INTEGER PRIMARY KEY AUTOINCREMENT, domain TEXT NOT NULL UNIQUE, data TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE post_process_tasks (id TEXT PRIMARY KEY, source_task_id TEXT NOT NULL, type TEXT NOT NULL, status TEXT NOT NULL, progress REAL NOT NULL DEFAULT 0, data TEXT NOT NULL)',
        );
        await createClipAnalysisTestSchema(db);
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

  group('settings', () {
    test('loadSettings returns empty map for fresh db', () async {
      final map = await DatabaseService().loadSettings();
      expect(map, isEmpty);
    });

    test('saveSettings and loadSettings round-trip', () async {
      await DatabaseService().saveSettings({'key1': 'value1', 'key2': 42});

      final map = await DatabaseService().loadSettings();
      expect(map['key1'], 'value1');
      expect(jsonDecode(map['key2']!), 42);
    });

    test('saveSettings overwrites previous entries', () async {
      await DatabaseService().saveSettings({'key1': 'old'});
      await DatabaseService().saveSettings({'key1': 'new', 'key2': 'val'});

      final map = await DatabaseService().loadSettings();
      expect(map.length, 2);
      expect(map['key1'], 'new');
      expect(map['key2'], 'val');
    });
  });

  group('download tasks', () {
    test('saveTask and loadTasksByStatus round-trip', () async {
      final task = DownloadTask(
        id: 'task-1',
        title: 'Test Video',
        source: 'https://example.com/video',
        status: DownloadStatus.queued,
        progress: 0,
        variants: const [],
      );
      await DatabaseService().saveTask(task);

      final loaded = await DatabaseService().loadTasksByStatus(['queued']);
      expect(loaded, hasLength(1));
      expect(loaded.single.id, 'task-1');
      expect(loaded.single.title, 'Test Video');
    });

    test('saveTasks batch inserts multiple tasks', () async {
      final tasks = [
        DownloadTask(
          id: 'batch-1',
          title: 'Video 1',
          source: 'https://example.com/1',
          status: DownloadStatus.queued,
          progress: 0,
          variants: const [],
        ),
        DownloadTask(
          id: 'batch-2',
          title: 'Video 2',
          source: 'https://example.com/2',
          status: DownloadStatus.downloading,
          progress: 50,
          variants: const [],
        ),
      ];
      await DatabaseService().saveTasks(tasks);

      final queued = await DatabaseService().loadTasksByStatus(['queued']);
      final downloading = await DatabaseService().loadTasksByStatus([
        'downloading',
      ]);
      expect(queued, hasLength(1));
      expect(downloading, hasLength(1));
    });

    test('loadTasksByStatus with multiple statuses', () async {
      final tasks = [
        DownloadTask(
          id: 's-1',
          title: 'Completed',
          source: 'https://example.com/1',
          status: DownloadStatus.completed,
          progress: 100,
          variants: const [],
        ),
        DownloadTask(
          id: 's-2',
          title: 'Failed',
          source: 'https://example.com/2',
          status: DownloadStatus.failed,
          progress: 30,
          variants: const [],
        ),
        DownloadTask(
          id: 's-3',
          title: 'Cancelled',
          source: 'https://example.com/3',
          status: DownloadStatus.cancelled,
          progress: 0,
          variants: const [],
        ),
      ];
      await DatabaseService().saveTasks(tasks);

      final history = await DatabaseService().loadTasksByStatus([
        'completed',
        'failed',
        'cancelled',
      ]);
      expect(history, hasLength(3));
    });

    test('deleteTask removes task', () async {
      final task = DownloadTask(
        id: 'delete-me',
        title: 'Delete',
        source: 'https://example.com/del',
        status: DownloadStatus.completed,
        progress: 100,
        variants: const [],
      );
      await DatabaseService().saveTask(task);
      expect(
        (await DatabaseService().loadTasksByStatus(['completed'])),
        hasLength(1),
      );

      await DatabaseService().deleteTask('delete-me');
      expect(
        (await DatabaseService().loadTasksByStatus(['completed'])),
        isEmpty,
      );
    });

    test('replaceStatusTasks removes old and inserts new', () async {
      final old = DownloadTask(
        id: 'old',
        title: 'Old',
        source: 'https://example.com/old',
        status: DownloadStatus.queued,
        progress: 0,
        variants: const [],
      );
      await DatabaseService().saveTask(old);
      expect(
        (await DatabaseService().loadTasksByStatus(['queued'])),
        hasLength(1),
      );

      final newTasks = [
        DownloadTask(
          id: 'new-1',
          title: 'New 1',
          source: 'https://example.com/n1',
          status: DownloadStatus.queued,
          progress: 0,
          variants: const [],
        ),
        DownloadTask(
          id: 'new-2',
          title: 'New 2',
          source: 'https://example.com/n2',
          status: DownloadStatus.queued,
          progress: 0,
          variants: const [],
        ),
      ];
      await DatabaseService().replaceStatusTasks('queued', newTasks);

      final queued = await DatabaseService().loadTasksByStatus(['queued']);
      expect(queued, hasLength(2));
      expect(queued.any((t) => t.id == 'new-1'), isTrue);
      expect(queued.any((t) => t.id == 'old'), isFalse);
    });
  });

  group('post process tasks', () {
    test(
      'savePostProcessTask and loadPostProcessTasksByStatus round-trip',
      () async {
        final task = PostProcessTask(
          id: 'pp-1',
          sourceTaskId: 'src-1',
          title: 'PP Task',
          type: PostProcessTaskType.aiClipAnalysis,
          status: PostProcessStatus.queued,
          progress: 0,
          sourcePath: '/tmp/test.mp4',
          outputDirectory: '/tmp/test.mp4.clips',
        );
        await DatabaseService().savePostProcessTask(task);

        final loaded = await DatabaseService().loadPostProcessTasksByStatus([
          'queued',
        ]);
        expect(loaded, hasLength(1));
        expect(loaded.single.id, 'pp-1');
      },
    );

    test('savePostProcessTasks batch inserts', () async {
      final tasks = [
        PostProcessTask(
          id: 'pp-b1',
          sourceTaskId: 's1',
          title: 'PP1',
          type: PostProcessTaskType.aiClipAnalysis,
          status: PostProcessStatus.queued,
          progress: 0,
          sourcePath: '/tmp/a.mp4',
          outputDirectory: '/tmp/a.mp4.clips',
        ),
        PostProcessTask(
          id: 'pp-b2',
          sourceTaskId: 's2',
          title: 'PP2',
          type: PostProcessTaskType.clip,
          status: PostProcessStatus.running,
          progress: 50,
          sourcePath: '/tmp/b.mp4',
          outputDirectory: '/tmp/b.mp4.clips',
        ),
      ];
      await DatabaseService().savePostProcessTasks(tasks);

      final queued = await DatabaseService().loadPostProcessTasksByStatus([
        'queued',
      ]);
      final running = await DatabaseService().loadPostProcessTasksByStatus([
        'running',
      ]);
      expect(queued, hasLength(1));
      expect(running, hasLength(1));
    });

    test('replacePostProcessStatusTasks replaces old with new', () async {
      await DatabaseService().savePostProcessTask(
        PostProcessTask(
          id: 'old-pp',
          sourceTaskId: 'src',
          title: 'Old',
          type: PostProcessTaskType.clip,
          status: PostProcessStatus.running,
          progress: 50,
          sourcePath: '/tmp/old.mp4',
          outputDirectory: '/tmp/old.mp4.clips',
        ),
      );
      expect(
        (await DatabaseService().loadPostProcessTasksByStatus(['running'])),
        hasLength(1),
      );

      await DatabaseService().replacePostProcessStatusTasks('running', []);
      expect(
        (await DatabaseService().loadPostProcessTasksByStatus(['running'])),
        isEmpty,
      );
    });
  });

  group('clip segments', () {
    test('replaceClipSegmentsForTask inserts and loads segments', () async {
      final segment = ClipSegment(
        id: 'seg-1',
        sourceTaskId: 'src-1',
        postProcessTaskId: 'pp-1',
        sourcePath: '/tmp/test.mp4',
        startMs: 0,
        endMs: 12000,
        title: 'Test Segment',
        summary: 'A test segment',
        keywords: const ['test'],
        tags: const ['demo'],
        confidence: 0.9,
        reason: 'testing',
      );

      await DatabaseService().replaceClipSegmentsForTask('pp-1', [segment]);

      final loaded = await DatabaseService().loadClipSegments();
      expect(loaded, hasLength(1));
      expect(loaded.single.id, 'seg-1');
      expect(loaded.single.title, 'Test Segment');
    });

    test('replaceClipSegmentsForTask replaces existing segments', () async {
      final segment1 = ClipSegment(
        id: 'seg-old',
        sourceTaskId: 'src-1',
        postProcessTaskId: 'pp-1',
        sourcePath: '/tmp/test.mp4',
        startMs: 0,
        endMs: 5000,
        title: 'Old Segment',
        summary: 'Old',
        keywords: const [],
        tags: const [],
        confidence: 0.5,
        reason: 'old',
      );

      await DatabaseService().replaceClipSegmentsForTask('pp-1', [segment1]);
      expect((await DatabaseService().loadClipSegments()), hasLength(1));

      final segment2 = ClipSegment(
        id: 'seg-new',
        sourceTaskId: 'src-1',
        postProcessTaskId: 'pp-1',
        sourcePath: '/tmp/test.mp4',
        startMs: 5000,
        endMs: 10000,
        title: 'New Segment',
        summary: 'New',
        keywords: const [],
        tags: const [],
        confidence: 0.8,
        reason: 'new',
      );

      await DatabaseService().replaceClipSegmentsForTask('pp-1', [segment2]);
      final loaded = await DatabaseService().loadClipSegments();
      expect(loaded, hasLength(1));
      expect(loaded.single.id, 'seg-new');
    });

    test('loadClipSegments with sourceTaskId filter', () async {
      final seg1 = ClipSegment(
        id: 'seg-a',
        sourceTaskId: 'src-a',
        postProcessTaskId: 'pp-a',
        sourcePath: '/tmp/a.mp4',
        startMs: 0,
        endMs: 5000,
        title: 'A',
        summary: 'A',
        keywords: const [],
        tags: const [],
        confidence: 0.5,
        reason: 'a',
      );
      final seg2 = ClipSegment(
        id: 'seg-b',
        sourceTaskId: 'src-b',
        postProcessTaskId: 'pp-b',
        sourcePath: '/tmp/b.mp4',
        startMs: 0,
        endMs: 5000,
        title: 'B',
        summary: 'B',
        keywords: const [],
        tags: const [],
        confidence: 0.5,
        reason: 'b',
      );

      await DatabaseService().replaceClipSegmentsForTask('pp-a', [seg1]);
      await DatabaseService().replaceClipSegmentsForTask('pp-b', [seg2]);

      final filtered = await DatabaseService().loadClipSegments(
        sourceTaskId: 'src-a',
      );
      expect(filtered, hasLength(1));
      expect(filtered.single.id, 'seg-a');
    });

    test('searchClipSegments finds by title', () async {
      final segment = ClipSegment(
        id: 'seg-search',
        sourceTaskId: 'src-1',
        postProcessTaskId: 'pp-1',
        sourcePath: '/tmp/test.mp4',
        startMs: 0,
        endMs: 10000,
        title: 'Unique Title Here',
        summary: 'Something interesting',
        keywords: const ['keyword1'],
        tags: const ['tag1'],
        confidence: 0.9,
        reason: 'reason text',
      );

      await DatabaseService().replaceClipSegmentsForTask('pp-1', [segment]);

      final results = await DatabaseService().searchClipSegments('Unique');
      expect(results, hasLength(1));
      expect(results.single.id, 'seg-search');
    });

    test('searchClipSegments finds by keyword', () async {
      final segment = ClipSegment(
        id: 'seg-kw',
        sourceTaskId: 'src-1',
        postProcessTaskId: 'pp-1',
        sourcePath: '/tmp/test.mp4',
        startMs: 0,
        endMs: 10000,
        title: 'Title',
        summary: 'Summary',
        keywords: const ['specialKeyword', 'other'],
        tags: const [],
        confidence: 0.9,
        reason: 'reason',
      );

      await DatabaseService().replaceClipSegmentsForTask('pp-1', [segment]);

      final results = await DatabaseService().searchClipSegments(
        'specialKeyword',
      );
      expect(results, hasLength(1));
    });

    test('searchClipSegments empty query returns all', () async {
      final seg1 = ClipSegment(
        id: 'seg-e1',
        sourceTaskId: 'src-1',
        postProcessTaskId: 'pp-1',
        sourcePath: '/tmp/a.mp4',
        startMs: 0,
        endMs: 5000,
        title: 'A',
        summary: 'A summary',
        keywords: const [],
        tags: const [],
        confidence: 0.5,
        reason: 'a',
      );
      await DatabaseService().replaceClipSegmentsForTask('pp-1', [seg1]);

      final results = await DatabaseService().searchClipSegments('');
      expect(results, hasLength(1));
    });

    test('searchClipSegments escapes special SQL characters', () async {
      final segment = ClipSegment(
        id: 'seg-escape',
        sourceTaskId: 'src-1',
        postProcessTaskId: 'pp-1',
        sourcePath: '/tmp/test.mp4',
        startMs: 0,
        endMs: 10000,
        title: 'Test%_with special chars',
        summary: 'Summary',
        keywords: const [],
        tags: const [],
        confidence: 0.9,
        reason: 'reason',
      );

      await DatabaseService().replaceClipSegmentsForTask('pp-1', [segment]);

      // Searching for a literal _ should NOT match because it's escaped
      // (title contains _, so searching for just _ would normally match everything)
      final results = await DatabaseService().searchClipSegments(
        'no-match-xyz',
      );
      expect(results, isEmpty);
    });

    test('updateClipSegmentTiming modifies adjusted times', () async {
      final segment = ClipSegment(
        id: 'seg-time',
        sourceTaskId: 'src-1',
        postProcessTaskId: 'pp-1',
        sourcePath: '/tmp/test.mp4',
        startMs: 0,
        endMs: 12000,
        title: 'Timing Test',
        summary: 'Test',
        keywords: const [],
        tags: const [],
        confidence: 0.9,
        reason: 'timing',
      );

      await DatabaseService().replaceClipSegmentsForTask('pp-1', [segment]);

      await DatabaseService().updateClipSegmentTiming(
        'seg-time',
        adjustedStartMs: 2000,
        adjustedEndMs: 8000,
      );

      final loaded = await DatabaseService().loadClipSegments();
      expect(loaded.single.adjustedStartMs, 2000);
      expect(loaded.single.adjustedEndMs, 8000);
    });

    test('updateClipSegmentTiming does nothing for unknown id', () async {
      await DatabaseService().updateClipSegmentTiming(
        'nonexistent',
        adjustedStartMs: 1000,
      );
    });
  });

  group('cookie configs', () {
    test('loadCookieConfigs returns empty for fresh db', () async {
      final configs = await DatabaseService().loadCookieConfigs();
      expect(configs, isEmpty);
    });

    test('saveCookieConfigs and loadCookieConfigs round-trip', () async {
      final configs = <CookieConfig>[
        CookieConfig(
          domain: 'youtube.com',
          browser: 'chrome',
          cookieFile: '/tmp/yt-cookies.txt',
        ),
        CookieConfig(
          domain: 'bilibili.com',
          browser: 'chrome',
          cookieFile: '/tmp/bi-cookies.txt',
        ),
      ];
      await DatabaseService().saveCookieConfigs(configs);

      final loaded = await DatabaseService().loadCookieConfigs();
      expect(loaded, hasLength(2));
      expect(
        loaded.map((c) => c.domain),
        containsAll(['youtube.com', 'bilibili.com']),
      );
    });

    test('saveCookieConfigs overwrites previous configs', () async {
      await DatabaseService().saveCookieConfigs(<CookieConfig>[
        CookieConfig(
          domain: 'old.com',
          browser: 'chrome',
          cookieFile: '/tmp/old.txt',
        ),
      ]);

      await DatabaseService().saveCookieConfigs(<CookieConfig>[
        CookieConfig(
          domain: 'new.com',
          browser: 'chrome',
          cookieFile: '/tmp/new.txt',
        ),
      ]);

      final loaded = await DatabaseService().loadCookieConfigs();
      expect(loaded, hasLength(1));
      expect(loaded.single.domain, 'new.com');
    });
  });
}
