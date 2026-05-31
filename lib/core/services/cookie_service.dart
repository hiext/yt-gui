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

  static const _browserFallback = [
    'chrome',
    'firefox',
    'edge',
    'brave',
    'opera',
  ];

  Future<CookieImportResult> importFromBrowser({
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

    // Build browser list: selected browser first, then fallbacks
    final browsers = <String>[browser];
    for (final b in _browserFallback) {
      if (b != browser) browsers.add(b);
    }

    final failures = <String>[];
    for (final br in browsers) {
      if (file.existsSync()) file.deleteSync();

      final process = await Process.start(ytDlpPath, [
        '--cookies-from-browser',
        br,
        '--cookies',
        outputFile,
        '--print',
        'id',
        '--skip-download',
        '--no-playlist',
        testUrl,
      ], runInShell: false);

      unawaited(process.stdout.drain());
      final stderr = await process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .toList();
      await process.exitCode;

      final cannotDecrypt = stderr.any(
        (l) => l.contains('could not be decrypted'),
      );
      final extractedCount = _parseExtractedCount(stderr);
      final fileCreated = file.existsSync() && file.lengthSync() >= 10;

      if (cannotDecrypt && extractedCount == 0) {
        failures.add('$br: cookie 加密无法解密');
        continue;
      }

      if (!fileCreated) {
        failures.add('$br: 未生成 cookie 文件');
        continue;
      }

      if (extractedCount == 0) {
        failures.add('$br: 未找到已登录的 cookie');
        continue;
      }

      // Success — note which browser worked
      final actualBr = br;
      return CookieImportResult(
        success: true,
        detail: '已从 $actualBr 提取 $extractedCount 个 cookie',
      );
    }

    return CookieImportResult(
      success: false,
      reason: 'all_failed',
      detail: failures.join('\n'),
    );
  }

  int _parseExtractedCount(List<String> stderr) {
    for (final line in stderr) {
      // "Extracted 1234 cookies from chrome"
      final match = RegExp(r'Extracted (\d+) cookies?').firstMatch(line);
      if (match != null) return int.parse(match.group(1)!);
    }
    return -1;
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

class CookieImportResult {
  const CookieImportResult({required this.success, this.reason, this.detail});

  final bool success;
  final String? reason;
  final String? detail;
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
