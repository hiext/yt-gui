import 'dart:async';
import 'dart:ffi' hide Size;

import 'package:ffi/ffi.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart' as sqlite_open;
import 'package:window_manager/window_manager.dart';

import 'app/hiext_yt_app.dart';
import 'app/runtime_screenshot_app.dart';
import 'core/services/log_service.dart';
import 'core/services/notification_service.dart';

const _screenshotMode = bool.fromEnvironment('HIEXT_SCREENSHOT_MODE');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // sqfliteFfiInit must come before _configureLinuxSqlite because
  // sqlite3_flutter_libs may overwrite our override during its own
  // initialization path. Setting ours LAST guarantees it wins.
  sqfliteFfiInit();
  _configureLinuxSqlite();

  LogService.instance.info('App starting — platform: ${Platform.operatingSystem}', 'main');
  unawaited(NotificationService().initialize(appName: 'Hiext YT GUI'));

  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);
  windowManager.waitUntilReadyToShow(
    WindowOptions(
      size: _screenshotMode ? const Size(1440, 1320) : null,
      center: true,
      title: 'Hiext YT GUI',
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  runApp(_screenshotMode ? const RuntimeScreenshotApp() : const HiextYtApp());
}

/// Overrides the default SQLite library loading on Linux.
///
/// `sqflite_common_ffi` looks up SQLite symbols via `DynamicLibrary.process()`,
/// which only sees libraries loaded with `RTLD_GLOBAL`.  `DynamicLibrary.open()`
/// loads with `RTLD_LOCAL` by default, so we must call `dlopen` ourselves with
/// `RTLD_GLOBAL` to make the system libsqlite3 visible process-wide.
void _configureLinuxSqlite() {
  if (!Platform.isLinux) return;

  // dlopen flags
  // ignore: constant_identifier_names
  const int RTLD_NOW = 2;
  // ignore: constant_identifier_names
  const int RTLD_GLOBAL = 0x100;

  // Bind native dlopen / dlerror
  final libc = DynamicLibrary.open('libc.so.6');
  final dlopenFn = libc.lookupFunction<
    Pointer<Void> Function(Pointer<Utf8>, Int32),
    Pointer<Void> Function(Pointer<Utf8>, int)
  >('dlopen');
  final dlerrorFn = libc.lookupFunction<
    Pointer<Utf8> Function(),
    Pointer<Utf8> Function()
  >('dlerror');

  final candidates = <String>[
    '/lib/x86_64-linux-gnu/libsqlite3.so.0',
    '/usr/lib/x86_64-linux-gnu/libsqlite3.so.0',
    '/lib64/libsqlite3.so.0',
    '/usr/lib64/libsqlite3.so.0',
    '/lib/aarch64-linux-gnu/libsqlite3.so.0',
    '/usr/lib/aarch64-linux-gnu/libsqlite3.so.0',
  ];

  Pointer<Void>? handle;
  for (final path in candidates) {
    if (!File(path).existsSync()) continue;
    final pathPtr = path.toNativeUtf8();
    handle = dlopenFn(pathPtr, RTLD_NOW | RTLD_GLOBAL);
    calloc.free(pathPtr);
    if (handle != nullptr) break;
    final err = dlerrorFn();
    if (err != nullptr) {
      LogService.instance.warn(
        'dlopen($path): ${err.toDartString()}',
        'sqlite',
      );
    }
  }

  // Last resort: short-name search
  if (handle == nullptr) {
    final pathPtr = 'libsqlite3.so.0'.toNativeUtf8();
    handle = dlopenFn(pathPtr, RTLD_NOW | RTLD_GLOBAL);
    calloc.free(pathPtr);
  }

  if (handle == nullptr) {
    final err = dlerrorFn();
    final msg = err != nullptr
        ? 'Could not load libsqlite3: ${err.toDartString()}'
        : 'Could not load libsqlite3';
    LogService.instance.error(msg, 'sqlite');
    throw UnsupportedError(msg);
  }

  LogService.instance.info('SQLite loaded (RTLD_GLOBAL)', 'sqlite');

  // Also set up the sqlite3 Dart package override so our handle is used
  DynamicLibrary? cached;
  sqlite_open.open.overrideFor(
    sqlite_open.OperatingSystem.linux,
    () {
      cached ??= DynamicLibrary.open(
        candidates.firstWhere(
          (p) => File(p).existsSync(),
          orElse: () => 'libsqlite3.so.0',
        ),
      );
      return cached!;
    },
  );
}
