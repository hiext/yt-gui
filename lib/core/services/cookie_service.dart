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
    // Ensure output directory exists
    final file = File(outputFile);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }

    // Use yt-dlp to extract cookies from browser for the domain
    // by doing a lightweight request that triggers cookie reading,
    // then saving the jar to the output file
    final result = await Process.run(ytDlpPath, [
      '--cookies-from-browser',
      browser,
      '--cookies',
      outputFile,
      '--dump-json',
      '--skip-download',
      'https://$domain/',
    ], runInShell: false);

    if (result.exitCode != 0) {
      return false;
    }

    // Verify the cookie file was created
    if (!file.existsSync() || file.lengthSync() < 10) {
      return false;
    }

    return true;
  }

  bool isCookieFileValid(String path) {
    final file = File(path);
    if (!file.existsSync()) return false;
    return file.lengthSync() > 10;
  }
}
