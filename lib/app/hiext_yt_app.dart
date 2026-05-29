import 'package:flutter/material.dart';

import 'app_shell.dart';

class HiextYtApp extends StatelessWidget {
  const HiextYtApp({super.key});

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
