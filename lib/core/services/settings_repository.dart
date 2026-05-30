import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';

class SettingsRepository {
  SettingsRepository({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const _keys = _SettingsKeys();

  Future<DownloadSettings> load() async {
    final all = await _prefs.getAll(allowList: _keys.allKeys);
    if (all.isEmpty) return DownloadSettings.defaults.normalized();
    return DownloadSettings.fromJson(all);
  }

  Future<void> save(DownloadSettings settings) async {
    final json = settings.normalized().toJson();
    final futures = <Future<void>>[];
    for (final entry in json.entries) {
      futures.add(_saveValue(entry.key, entry.value));
    }
    for (final key in _keys.allKeys.difference(json.keys.toSet())) {
      futures.add(_prefs.remove(key));
    }
    await Future.wait(futures);
  }

  Future<void> _saveValue(String key, Object value) {
    return switch (value) {
      String s => _prefs.setString(key, s),
      int i => _prefs.setInt(key, i),
      bool b => _prefs.setBool(key, b),
      _ => _prefs.setString(key, value.toString()),
    };
  }

  void dispose() {}
}

class _SettingsKeys {
  const _SettingsKeys();

  final allKeys = const <String>{
    'saveDirectory',
    'downloadMode',
    'concurrentCount',
    'defaultQuality',
    'downloadSubtitles',
    'downloadThumbnail',
    'ytDlpPath',
    'ffmpegPath',
  };
}
