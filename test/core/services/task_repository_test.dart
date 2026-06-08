import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/database_service.dart';
import 'package:hiext_yt_gui/core/services/task_repository.dart';
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
          'CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL, source TEXT NOT NULL, status TEXT NOT NULL, progress REAL NOT NULL DEFAULT 0, data TEXT NOT NULL)',
        );
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

  group('TaskRepository', () {
    final repo = TaskRepository();

    test('loadPendingTasks returns empty when no tasks', () async {
      final tasks = await repo.loadPendingTasks();
      expect(tasks, isEmpty);
    });

    test('loadPendingTasks returns queued, downloading, paused tasks', () async {
      final pending = [
        DownloadTask(
          id: 'q-1', title: 'Q1', source: 'https://x.com/1',
          status: DownloadStatus.queued, progress: 0, variants: const [],
        ),
        DownloadTask(
          id: 'd-1', title: 'D1', source: 'https://x.com/2',
          status: DownloadStatus.downloading, progress: 10, variants: const [],
        ),
        DownloadTask(
          id: 'p-1', title: 'P1', source: 'https://x.com/3',
          status: DownloadStatus.paused, progress: 30, variants: const [],
        ),
        DownloadTask(
          id: 'c-1', title: 'C1', source: 'https://x.com/5',
          status: DownloadStatus.completed, progress: 100, variants: const [],
        ),
      ];
      await DatabaseService().saveTasks(pending);

      final loaded = await repo.loadPendingTasks();
      expect(loaded, hasLength(3));
      expect(
        loaded.map((t) => t.status).toSet(),
        {
          DownloadStatus.queued,
          DownloadStatus.downloading,
          DownloadStatus.paused,
        },
      );
    });

    test('savePendingTasks replaces pending statuses with given tasks', () async {
      // Seed with existing tasks
      await DatabaseService().saveTask(
        DownloadTask(
          id: 'old-q', title: 'Old', source: 'https://x.com/old',
          status: DownloadStatus.queued, progress: 0, variants: const [],
        ),
      );
      await DatabaseService().saveTask(
        DownloadTask(
          id: 'old-c', title: 'OldC', source: 'https://x.com/oldc',
          status: DownloadStatus.completed, progress: 100, variants: const [],
        ),
      );

      await repo.savePendingTasks([
        DownloadTask(
          id: 'new-q', title: 'New', source: 'https://x.com/new',
          status: DownloadStatus.queued, progress: 0, variants: const [],
        ),
      ]);

      final pending = await repo.loadPendingTasks();
      expect(pending, hasLength(1));
      expect(pending.single.id, 'new-q');

      // Completed tasks should remain
      final history = await repo.loadHistoryTasks();
      expect(history, hasLength(1));
      expect(history.single.id, 'old-c');
    });

    test('loadHistoryTasks returns completed, failed, cancelled', () async {
      final tasks = [
        DownloadTask(
          id: 'comp', title: 'Comp', source: 'https://x.com/1',
          status: DownloadStatus.completed, progress: 100, variants: const [],
        ),
        DownloadTask(
          id: 'fail', title: 'Fail', source: 'https://x.com/2',
          status: DownloadStatus.failed, progress: 30, variants: const [],
        ),
        DownloadTask(
          id: 'cancel', title: 'Cancel', source: 'https://x.com/3',
          status: DownloadStatus.cancelled, progress: 0, variants: const [],
        ),
        DownloadTask(
          id: 'queue', title: 'Queue', source: 'https://x.com/4',
          status: DownloadStatus.queued, progress: 0, variants: const [],
        ),
      ];
      await DatabaseService().saveTasks(tasks);

      final history = await repo.loadHistoryTasks();
      expect(history, hasLength(3));
      expect(
        history.map((t) => t.status).toSet(),
        {
          DownloadStatus.completed,
          DownloadStatus.failed,
          DownloadStatus.cancelled,
        },
      );
    });

    test('saveHistoryTasks replaces history statuses', () async {
      await DatabaseService().saveTask(
        DownloadTask(
          id: 'old-comp', title: 'Old', source: 'https://x.com/old',
          status: DownloadStatus.completed, progress: 100, variants: const [],
        ),
      );

      await repo.saveHistoryTasks([
        DownloadTask(
          id: 'new-comp', title: 'New', source: 'https://x.com/new',
          status: DownloadStatus.completed, progress: 100, variants: const [],
        ),
      ]);

      final history = await repo.loadHistoryTasks();
      expect(history, hasLength(1));
      expect(history.single.id, 'new-comp');
    });
  });
}
