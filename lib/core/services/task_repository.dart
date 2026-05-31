import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';

class TaskRepository {
  TaskRepository({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const _pendingKey = 'pending_tasks';
  static const _historyKey = 'history_tasks';

  Future<List<DownloadTask>> loadPendingTasks() async {
    return _loadList(_pendingKey);
  }

  Future<void> savePendingTasks(List<DownloadTask> tasks) async {
    await _saveList(_pendingKey, tasks);
  }

  Future<List<DownloadTask>> loadHistoryTasks() async {
    return _loadList(_historyKey);
  }

  Future<void> saveHistoryTasks(List<DownloadTask> tasks) async {
    await _saveList(_historyKey, tasks);
  }

  Future<List<DownloadTask>> _loadList(String key) async {
    final raw = await _prefs.getString(key);
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

  Future<void> _saveList(String key, List<DownloadTask> tasks) async {
    if (tasks.isEmpty) {
      await _prefs.remove(key);
      return;
    }
    final json = jsonEncode(tasks.map((t) => t.toJson()).toList());
    await _prefs.setString(key, json);
  }
}
