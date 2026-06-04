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
