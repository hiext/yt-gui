import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';

class TaskRepository {
  TaskRepository({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const _key = 'pending_tasks';

  Future<List<DownloadTask>> loadPendingTasks() async {
    final raw = await _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<Object?>;
      return list
          .whereType<Map<String, Object?>>()
          .map(DownloadTask.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> savePendingTasks(List<DownloadTask> tasks) async {
    final json = jsonEncode(tasks.map((t) => t.toJson()).toList());
    await _prefs.setString(_key, json);
  }
}
