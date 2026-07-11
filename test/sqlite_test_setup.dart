import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/open.dart' as sqlite_open;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _sqliteInitialized = false;

void initTestSqlite() {
  if (_sqliteInitialized) return;

  if (Platform.isLinux) {
    sqlite_open.open.overrideFor(
      sqlite_open.OperatingSystem.linux,
      _openLinuxSqliteForTests,
    );
  }

  sqfliteFfiInit();
  _sqliteInitialized = true;
}

Future<void> createClipAnalysisTestSchema(Database db) async {
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
}

Future<void> createClipRecordsTestSchema(Database db) async {
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

Future<void> createMediaLibraryTestSchema(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS license_state (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      data TEXT NOT NULL
    )
  ''');
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
}

DynamicLibrary _openLinuxSqliteForTests() {
  const candidates = [
    '/lib/x86_64-linux-gnu/libsqlite3.so.0',
    '/usr/lib/x86_64-linux-gnu/libsqlite3.so.0',
    '/lib64/libsqlite3.so.0',
    '/usr/lib64/libsqlite3.so.0',
  ];

  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return DynamicLibrary.open(candidate);
    }
  }

  return DynamicLibrary.open('libsqlite3.so');
}
