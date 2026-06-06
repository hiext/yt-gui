import 'dart:async';
import 'dart:ffi' show DynamicLibrary;
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
  _configureLinuxSqlite();
  sqfliteFfiInit();

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
/// [sqlite3_flutter_libs] is a no-op on Linux for this project (it does not
/// bundle a prebuilt sqlite3). We must load the system libsqlite3.so.0
/// using absolute paths because `dlopen` short-name resolution is unreliable
/// in Flutter release bundles where LD_LIBRARY_PATH may not include system
/// library directories.
void _configureLinuxSqlite() {
  if (!Platform.isLinux) return;

  sqlite_open.open.overrideFor(sqlite_open.OperatingSystem.linux, () {
    const candidates = <String>[
      '/lib/x86_64-linux-gnu/libsqlite3.so.0',
      '/usr/lib/x86_64-linux-gnu/libsqlite3.so.0',
      '/lib64/libsqlite3.so.0',
      '/usr/lib64/libsqlite3.so.0',
      '/lib/aarch64-linux-gnu/libsqlite3.so.0',
      '/usr/lib/aarch64-linux-gnu/libsqlite3.so.0',
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) {
        return DynamicLibrary.open(path);
      }
    }
    throw UnsupportedError(
      'Could not load libsqlite3 on Linux. '
      'Install libsqlite3-0 (e.g. sudo apt install libsqlite3-0).',
    );
  });
}
