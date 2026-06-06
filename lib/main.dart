import 'dart:async';
import 'dart:ffi' show DynamicLibrary;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqlite3/open.dart' as sqlite_open;
import 'package:window_manager/window_manager.dart';

import 'app/hiext_yt_app.dart';
import 'app/runtime_screenshot_app.dart';
import 'core/services/notification_service.dart';

const _screenshotMode = bool.fromEnvironment('HIEXT_SCREENSHOT_MODE');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _configureLinuxSqlite();

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

/// Overrides the default SQLite library loading on Linux to try known
/// system paths before falling back to the plugin-bundled library.
///
/// This is a development convenience; it is NOT required for production
/// builds where [sqlite3_flutter_libs] bundles the correct library.
void _configureLinuxSqlite() {
  if (!Platform.isLinux) return;

  sqlite_open.open.overrideFor(sqlite_open.OperatingSystem.linux, () {
    const candidates = <String>[
      'libsqlite3.so',
      'libsqlite3.so.0',
      '/lib/x86_64-linux-gnu/libsqlite3.so.0',
      '/usr/lib/x86_64-linux-gnu/libsqlite3.so.0',
    ];
    for (final path in candidates) {
      try {
        return DynamicLibrary.open(path);
      } on ArgumentError {
        // try next candidate
      }
    }
    throw UnsupportedError(
      'Could not load libsqlite3 on Linux. '
      'Install libsqlite3-0 or sqlite3_flutter_libs.',
    );
  });
}
