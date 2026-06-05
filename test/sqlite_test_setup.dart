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
