import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';

class CookieService {
  CookieService({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;
  static const _storeKey = 'cookie_configs';

  Future<List<CookieConfig>> loadConfigs() async {
    final raw = await _prefs.getString(_storeKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<Object?>;
      return list
          .whereType<Map<String, Object?>>()
          .map(CookieConfig.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveConfigs(List<CookieConfig> configs) async {
    final json = jsonEncode(configs.map((c) => c.toJson()).toList());
    await _prefs.setString(_storeKey, json);
  }

  Future<bool> importFromBrowser({
    required String browser,
    required String domain,
    required String ytDlpPath,
    required String outputFile,
  }) async {
    final file = File(outputFile);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }

    // Use Process.start to avoid buffering large stdout
    final process = await Process.start(ytDlpPath, [
      '--cookies-from-browser',
      browser,
      '--cookies',
      outputFile,
      '--print',
      'id',
      '--skip-download',
      '--no-playlist',
      'https://$domain/',
    ], runInShell: false);

    // Discard stdout/stderr but wait for completion
    unawaited(process.stdout.drain());
    unawaited(process.stderr.drain());
    final exitCode = await process.exitCode;

    if (exitCode != 0) return false;
    if (!file.existsSync() || file.lengthSync() < 10) return false;
    return true;
  }

  bool isCookieFileValid(String path) {
    final file = File(path);
    if (!file.existsSync()) return false;
    return file.lengthSync() > 10;
  }
}
