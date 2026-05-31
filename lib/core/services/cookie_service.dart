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

  static const _siteTestUrls = <String, String>{
    'bilibili.com': 'https://www.bilibili.com/video/BV1GJ411x7h7',
    'nicovideo.jp': 'https://www.nicovideo.jp/watch/sm8628149',
  };

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

    final testUrl = _siteTestUrls[domain] ?? 'https://$domain/';

    final process = await Process.start(ytDlpPath, [
      '--cookies-from-browser',
      browser,
      '--cookies',
      outputFile,
      '--print',
      'id',
      '--skip-download',
      '--no-playlist',
      testUrl,
    ], runInShell: false);

    unawaited(process.stdout.drain());
    unawaited(process.stderr.drain());
    await process.exitCode;

    // Exit code may be non-zero for sites without a supported homepage
    // (e.g. bilibili.com), but cookies may still have been extracted.
    // Only check if the cookie file was actually created.
    if (!file.existsSync() || file.lengthSync() < 10) return false;
    return true;
  }

  bool isCookieFileValid(String path) {
    final file = File(path);
    if (!file.existsSync()) return false;
    return file.lengthSync() > 10;
  }

  List<CookieEntry> parseCookieFile(String path) {
    final file = File(path);
    if (!file.existsSync()) return const [];
    try {
      final entries = <CookieEntry>[];
      for (final line in file.readAsLinesSync()) {
        if (line.startsWith('#') || line.trim().isEmpty) continue;
        final parts = line.split('\t');
        if (parts.length < 7) continue;
        final expUnix = int.tryParse(parts[4]) ?? 0;
        entries.add(
          CookieEntry(
            domain: parts[0],
            flag: parts[1],
            path: parts[2],
            secure: parts[3] == 'TRUE',
            expiry: expUnix > 0
                ? DateTime.fromMillisecondsSinceEpoch(expUnix * 1000)
                : null,
            name: parts[5],
            value: parts[6],
          ),
        );
      }
      return entries;
    } catch (_) {
      return const [];
    }
  }
}

class CookieEntry {
  const CookieEntry({
    required this.domain,
    required this.flag,
    required this.path,
    required this.secure,
    this.expiry,
    required this.name,
    required this.value,
  });

  final String domain;
  final String flag;
  final String path;
  final bool secure;
  final DateTime? expiry;
  final String name;
  final String value;

  bool get isExpired => expiry != null && expiry!.isBefore(DateTime.now());

  String get expiryText {
    if (expiry == null) return '会话';
    if (isExpired) return '已过期';
    final diff = expiry!.difference(DateTime.now());
    if (diff.inDays > 0) return '${diff.inDays} 天后';
    if (diff.inHours > 0) return '${diff.inHours} 小时后';
    return '即将过期';
  }
}
