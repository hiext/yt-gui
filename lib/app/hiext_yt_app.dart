import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app_shell.dart';

class HiextYtApp extends StatefulWidget {
  const HiextYtApp({super.key});

  @override
  State<HiextYtApp> createState() => _HiextYtAppState();
}

class _HiextYtAppState extends State<HiextYtApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() {
    windowManager.hide();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hiext YT GUI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}
