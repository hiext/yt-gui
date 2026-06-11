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
      options: OpenDatabaseOptions(
        version: 5,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
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
    await _createPostProcessTasksTable(db);
    await _createClipAnalysisTables(db);
    await _createClipRecordsTable(db);
    await ensureMediaLibrarySchema(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createPostProcessTasksTable(db);
    }
    if (oldVersion < 3) {
      await _createClipAnalysisTables(db);
    }
    if (oldVersion < 4) {
      await _createClipRecordsTable(db);
    }
    if (oldVersion < 5) {
      await ensureMediaLibrarySchema(db);
    }
  }

  Future<void> ensureMediaLibrarySchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS media_assets (
        id TEXT PRIMARY KEY,
        source_task_id TEXT NOT NULL,
        source_url TEXT NOT NULL,
        title TEXT NOT NULL,
        author TEXT,
        media_path TEXT NOT NULL,
        media_type TEXT NOT NULL,
        file_sha256 TEXT NOT NULL,
        duration_ms INTEGER NOT NULL DEFAULT 0,
        file_size_bytes INTEGER NOT NULL DEFAULT 0,
        thumbnail_path TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        data TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_media_assets_source_task ON media_assets(source_task_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_media_assets_file_sha256 ON media_assets(file_sha256)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS media_analysis_jobs (
        id TEXT PRIMARY KEY,
        media_asset_id TEXT NOT NULL,
        runtime TEXT NOT NULL,
        status TEXT NOT NULL,
        progress REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        data TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_media_analysis_jobs_asset ON media_analysis_jobs(media_asset_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_media_analysis_jobs_status ON media_analysis_jobs(status)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS clip_candidates (
        id TEXT PRIMARY KEY,
        media_asset_id TEXT NOT NULL,
        start_ms INTEGER NOT NULL,
        end_ms INTEGER NOT NULL,
        title TEXT NOT NULL,
        summary TEXT NOT NULL,
        tags TEXT NOT NULL,
        keywords TEXT NOT NULL,
        score REAL NOT NULL DEFAULT 0,
        source TEXT NOT NULL,
        created_at TEXT NOT NULL,
        data TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_clip_candidates_asset ON clip_candidates(media_asset_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_clip_candidates_score ON clip_candidates(score)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS clip_export_records (
        id TEXT PRIMARY KEY,
        media_asset_id TEXT NOT NULL,
        candidate_id TEXT,
        start_ms INTEGER NOT NULL,
        end_ms INTEGER NOT NULL,
        output_path TEXT NOT NULL,
        status TEXT NOT NULL,
        progress INTEGER NOT NULL DEFAULT 0,
        runtime TEXT NOT NULL,
        cloud_job_id TEXT,
        created_at TEXT NOT NULL,
        completed_at TEXT,
        data TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_clip_export_records_asset ON clip_export_records(media_asset_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_clip_export_records_status ON clip_export_records(status)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS media_vector_records (
        id TEXT PRIMARY KEY,
        media_asset_id TEXT NOT NULL,
        target_type TEXT NOT NULL,
        target_id TEXT NOT NULL,
        start_ms INTEGER,
        end_ms INTEGER,
        modality TEXT NOT NULL,
        model TEXT NOT NULL,
        dimension INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        data TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_media_vector_records_asset ON media_vector_records(media_asset_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_media_vector_records_target ON media_vector_records(target_type, target_id)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cloud_connection_configs (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        base_url TEXT NOT NULL,
        device_name TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        upload_policy TEXT NOT NULL,
        paired_at TEXT,
        data TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cloud_connection_configs_enabled ON cloud_connection_configs(enabled)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cloud_sync_tasks (
        id TEXT PRIMARY KEY,
        media_asset_id TEXT NOT NULL,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        idempotency_key TEXT NOT NULL,
        uploaded_bytes INTEGER NOT NULL DEFAULT 0,
        total_bytes INTEGER NOT NULL DEFAULT 0,
        cloud_media_id TEXT,
        cloud_job_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        data TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_cloud_sync_tasks_idempotency ON cloud_sync_tasks(idempotency_key)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cloud_sync_tasks_asset ON cloud_sync_tasks(media_asset_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cloud_sync_tasks_status ON cloud_sync_tasks(status)',
    );
  }

  Future<void> _createClipRecordsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS clip_records (
        id TEXT PRIMARY KEY,
        source_task_id TEXT NOT NULL,
        source_path TEXT NOT NULL,
        output_path TEXT,
        title TEXT NOT NULL,
        confidence REAL NOT NULL DEFAULT 0,
        start_ms INTEGER NOT NULL,
        end_ms INTEGER NOT NULL,
        duration_ms INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        progress INTEGER NOT NULL DEFAULT 0,
        error_message TEXT,
        created_at TEXT NOT NULL,
        completed_at TEXT,
        data TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_clip_records_source ON clip_records(source_task_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_clip_records_status ON clip_records(status)',
    );
  }

  Future<void> _createPostProcessTasksTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS post_process_tasks (
        id TEXT PRIMARY KEY,
        source_task_id TEXT NOT NULL,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        progress REAL NOT NULL DEFAULT 0,
        data TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createClipAnalysisTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS clip_segments (
        id TEXT PRIMARY KEY,
        source_task_id TEXT NOT NULL,
        post_process_task_id TEXT NOT NULL,
        source_path TEXT NOT NULL,
        start_ms INTEGER NOT NULL,
        end_ms INTEGER NOT NULL,
        adjusted_start_ms INTEGER,
        adjusted_end_ms INTEGER,
        title TEXT NOT NULL,
        summary TEXT NOT NULL,
        keywords TEXT NOT NULL,
        tags TEXT NOT NULL,
        confidence REAL NOT NULL DEFAULT 0,
        reason TEXT NOT NULL,
        output_path TEXT,
        created_at TEXT NOT NULL,
        data TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS clip_detections (
        id TEXT PRIMARY KEY,
        segment_id TEXT NOT NULL,
        timestamp_ms INTEGER NOT NULL,
        label TEXT NOT NULL,
        confidence REAL NOT NULL DEFAULT 0,
        bbox TEXT NOT NULL,
        track_id TEXT,
        data TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS clip_transcripts (
        id TEXT PRIMARY KEY,
        segment_id TEXT NOT NULL,
        start_ms INTEGER NOT NULL,
        end_ms INTEGER NOT NULL,
        text TEXT NOT NULL,
        words TEXT NOT NULL,
        data TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS clip_search_index (
        segment_id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        summary TEXT NOT NULL,
        transcript TEXT NOT NULL,
        keywords TEXT NOT NULL,
        tags TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_clip_segments_source_task ON clip_segments(source_task_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_clip_detections_segment ON clip_detections(segment_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_clip_transcripts_segment ON clip_transcripts(segment_id)',
    );
  }

  // ---- Settings ----

  Future<Map<String, String>> loadSettings() async {
    final d = await db;
    final rows = await d.query('settings');
    return {for (final r in rows) r['key'] as String: r['value'] as String};
  }

  Future<void> saveSettings(Map<String, Object> data) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('settings');
      for (final entry in data.entries) {
        await txn.insert('settings', {
          'key': entry.key,
          'value': entry.value is String
              ? entry.value
              : jsonEncode(entry.value),
        });
      }
    });
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

  // ---- Post-processing Tasks ----

  Future<void> savePostProcessTask(PostProcessTask task) async {
    final d = await db;
    await d.insert('post_process_tasks', {
      'id': task.id,
      'source_task_id': task.sourceTaskId,
      'type': task.type.name,
      'status': task.status.name,
      'progress': task.progress,
      'data': jsonEncode(task.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> savePostProcessTasks(List<PostProcessTask> tasks) async {
    final d = await db;
    final batch = d.batch();
    for (final task in tasks) {
      batch.insert('post_process_tasks', {
        'id': task.id,
        'source_task_id': task.sourceTaskId,
        'type': task.type.name,
        'status': task.status.name,
        'progress': task.progress,
        'data': jsonEncode(task.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<PostProcessTask>> loadPostProcessTasksByStatus(
    List<String> statuses,
  ) async {
    final d = await db;
    final placeholders = statuses.map((_) => '?').join(',');
    final rows = await d.query(
      'post_process_tasks',
      where: 'status IN ($placeholders)',
      whereArgs: statuses,
    );
    return rows
        .map(
          (r) => PostProcessTask.fromJson(
            jsonDecode(r['data'] as String) as Map<String, Object?>,
          ),
        )
        .toList();
  }

  Future<void> replacePostProcessStatusTasks(
    String status,
    List<PostProcessTask> tasks,
  ) async {
    final d = await db;
    await d.delete(
      'post_process_tasks',
      where: 'status = ?',
      whereArgs: [status],
    );
    await savePostProcessTasks(tasks);
  }

  // ---- AI Clip Analysis ----

  Future<void> replaceClipSegmentsForTask(
    String postProcessTaskId,
    List<ClipSegment> segments,
  ) async {
    final d = await db;
    await d.transaction((txn) async {
      final existing = await txn.query(
        'clip_segments',
        columns: ['id'],
        where: 'post_process_task_id = ?',
        whereArgs: [postProcessTaskId],
      );
      final existingIds = existing.map((row) => row['id'] as String).toList();
      if (existingIds.isNotEmpty) {
        final placeholders = existingIds.map((_) => '?').join(',');
        await txn.delete(
          'clip_detections',
          where: 'segment_id IN ($placeholders)',
          whereArgs: existingIds,
        );
        await txn.delete(
          'clip_transcripts',
          where: 'segment_id IN ($placeholders)',
          whereArgs: existingIds,
        );
        await txn.delete(
          'clip_search_index',
          where: 'segment_id IN ($placeholders)',
          whereArgs: existingIds,
        );
      }
      await txn.delete(
        'clip_segments',
        where: 'post_process_task_id = ?',
        whereArgs: [postProcessTaskId],
      );
      for (final segment in segments) {
        await _insertClipSegment(txn, segment);
      }
    });
  }

  Future<List<ClipSegment>> loadClipSegments({String? sourceTaskId}) async {
    final d = await db;
    final rows = await d.query(
      'clip_segments',
      where: sourceTaskId == null ? null : 'source_task_id = ?',
      whereArgs: sourceTaskId == null ? null : [sourceTaskId],
      orderBy: 'created_at DESC, start_ms ASC',
    );
    return rows
        .map(
          (r) => ClipSegment.fromJson(
            jsonDecode(r['data'] as String) as Map<String, Object?>,
          ),
        )
        .toList();
  }

  Future<List<ClipSegment>> searchClipSegments(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return loadClipSegments();
    }

    final d = await db;
    final like = '%${trimmed.replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
    final rows = await d.rawQuery(
      '''
      SELECT s.data
      FROM clip_segments s
      JOIN clip_search_index i ON i.segment_id = s.id
      WHERE i.title LIKE ? ESCAPE '\\'
        OR i.summary LIKE ? ESCAPE '\\'
        OR i.transcript LIKE ? ESCAPE '\\'
        OR i.keywords LIKE ? ESCAPE '\\'
        OR i.tags LIKE ? ESCAPE '\\'
      ORDER BY s.created_at DESC, s.start_ms ASC
      ''',
      [like, like, like, like, like],
    );
    return rows
        .map(
          (r) => ClipSegment.fromJson(
            jsonDecode(r['data'] as String) as Map<String, Object?>,
          ),
        )
        .toList();
  }

  Future<void> updateClipSegmentTiming(
    String segmentId, {
    int? adjustedStartMs,
    int? adjustedEndMs,
  }) async {
    final d = await db;
    final rows = await d.query(
      'clip_segments',
      where: 'id = ?',
      whereArgs: [segmentId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final segment = ClipSegment.fromJson(
      jsonDecode(rows.single['data'] as String) as Map<String, Object?>,
    ).copyWith(adjustedStartMs: adjustedStartMs, adjustedEndMs: adjustedEndMs);
    await d.transaction((txn) async {
      await _insertClipSegment(txn, segment);
    });
  }

  Future<void> _insertClipSegment(Transaction txn, ClipSegment segment) async {
    final data = jsonEncode(segment.toJson());
    await txn.insert('clip_segments', {
      'id': segment.id,
      'source_task_id': segment.sourceTaskId,
      'post_process_task_id': segment.postProcessTaskId,
      'source_path': segment.sourcePath,
      'start_ms': segment.startMs,
      'end_ms': segment.endMs,
      'adjusted_start_ms': segment.adjustedStartMs,
      'adjusted_end_ms': segment.adjustedEndMs,
      'title': segment.title,
      'summary': segment.summary,
      'keywords': jsonEncode(segment.keywords),
      'tags': jsonEncode(segment.tags),
      'confidence': segment.confidence,
      'reason': segment.reason,
      'output_path': segment.outputPath,
      'created_at': segment.createdAt.toIso8601String(),
      'data': data,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await txn.delete(
      'clip_detections',
      where: 'segment_id = ?',
      whereArgs: [segment.id],
    );
    for (final detection in segment.detections) {
      await txn.insert('clip_detections', {
        'id': detection.id,
        'segment_id': segment.id,
        'timestamp_ms': detection.timestampMs,
        'label': detection.label,
        'confidence': detection.confidence,
        'bbox': jsonEncode(detection.bbox),
        'track_id': detection.trackId,
        'data': jsonEncode(detection.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await txn.delete(
      'clip_transcripts',
      where: 'segment_id = ?',
      whereArgs: [segment.id],
    );
    for (final transcript in segment.transcripts) {
      await txn.insert('clip_transcripts', {
        'id': transcript.id,
        'segment_id': segment.id,
        'start_ms': transcript.startMs,
        'end_ms': transcript.endMs,
        'text': transcript.text,
        'words': jsonEncode(transcript.words),
        'data': jsonEncode(transcript.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await txn.insert('clip_search_index', {
      'segment_id': segment.id,
      'title': segment.title,
      'summary': segment.summary,
      'transcript': segment.transcripts.map((t) => t.text).join('\n'),
      'keywords': segment.keywords.join(' '),
      'tags': segment.tags.join(' '),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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
