import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app/hiext_yt_app.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  unawaited(NotificationService().initialize(appName: 'Hiext YT GUI'));

  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);

  runApp(const HiextYtApp());
}
