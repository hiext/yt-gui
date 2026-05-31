import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' show join;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/app_models.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._();

  factory DatabaseService() => _instance;

  DatabaseService._();

  Database? _db;

  void useTestDatabase(Database database) {
    _db = database;
  }

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    sqfliteFfiInit();
    final dbPath = join(
      Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '.',
      '.config',
      'hiext-yt-gui',
    );
    await Directory(dbPath).create(recursive: true);
    final database = await databaseFactoryFfi.openDatabase(
      join(dbPath, 'hiext_yt.db'),
      options: OpenDatabaseOptions(version: 1, onCreate: _onCreate),
    );
    return database;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        source TEXT NOT NULL,
        status TEXT NOT NULL,
        progress REAL NOT NULL DEFAULT 0,
        data TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE cookie_configs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        domain TEXT NOT NULL UNIQUE,
        data TEXT NOT NULL
      )
    ''');
  }

  // ---- Settings ----

  Future<Map<String, String>> loadSettings() async {
    final d = await db;
    final rows = await d.query('settings');
    return {for (final r in rows) r['key'] as String: r['value'] as String};
  }

  Future<void> saveSettings(Map<String, Object> data) async {
    final d = await db;
    await d.delete('settings');
    for (final entry in data.entries) {
      await d.insert(
        'settings',
        {'key': entry.key, 'value': entry.value.toString()},
      );
    }
  }

  // ---- Tasks ----

  Future<void> saveTask(DownloadTask task) async {
    final d = await db;
    await d.insert('tasks', {
      'id': task.id,
      'title': task.title,
      'source': task.source,
      'status': task.status.name,
      'progress': task.progress,
      'data': jsonEncode(task.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveTasks(List<DownloadTask> tasks) async {
    final d = await db;
    final batch = d.batch();
    for (final task in tasks) {
      batch.insert('tasks', {
        'id': task.id,
        'title': task.title,
        'source': task.source,
        'status': task.status.name,
        'progress': task.progress,
        'data': jsonEncode(task.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteTask(String id) async {
    final d = await db;
    await d.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<DownloadTask>> loadTasksByStatus(List<String> statuses) async {
    final d = await db;
    final placeholders = statuses.map((_) => '?').join(',');
    final rows = await d.query(
      'tasks',
      where: 'status IN ($placeholders)',
      whereArgs: statuses,
    );
    return rows
        .map(
          (r) => DownloadTask.fromJson(
            jsonDecode(r['data'] as String) as Map<String, Object?>,
          ),
        )
        .toList();
  }

  Future<void> replaceStatusTasks(
    String status,
    List<DownloadTask> tasks,
  ) async {
    final d = await db;
    await d.delete('tasks', where: 'status = ?', whereArgs: [status]);
    await saveTasks(tasks);
  }

  // ---- Cookie Configs ----

  Future<List<CookieConfig>> loadCookieConfigs() async {
    final d = await db;
    final rows = await d.query('cookie_configs');
    return rows
        .map(
          (r) => CookieConfig.fromJson(
            jsonDecode(r['data'] as String) as Map<String, Object?>,
          ),
        )
        .toList();
  }

  Future<void> saveCookieConfigs(List<CookieConfig> configs) async {
    final d = await db;
    await d.delete('cookie_configs');
    final batch = d.batch();
    for (final config in configs) {
      batch.insert('cookie_configs', {
        'domain': config.domain,
        'data': jsonEncode(config.toJson()),
      });
    }
    await batch.commit(noResult: true);
  }
}
