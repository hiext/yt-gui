import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/app_models.dart';
import 'database_service.dart';

class CookieService {
  Future<List<CookieConfig>> loadConfigs() async {
    return DatabaseService().loadCookieConfigs();
  }

  Future<void> saveConfigs(List<CookieConfig> configs) async {
    await DatabaseService().saveCookieConfigs(configs);
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

  static const _chromeBased = {'chrome', 'edge', 'brave', 'opera', 'chromium'};

  String? _findExtractScript() {
    // Check development paths (relative to project root)
    for (final path in ['assets/bin/linux/extract_cookies.py']) {
      if (File(path).existsSync()) return path;
    }
    // Check bundled release paths (relative to executable)
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    for (final path in [
      '$exeDir/data/flutter_assets/assets/bin/linux/extract_cookies.py',
    ]) {
      if (File(path).existsSync()) return path;
    }
    return null;
  }

  Future<CookieImportResult> _tryBrowserCookie3({
    required String browser,
    required String domain,
    required String outputFile,
    required String actualBrowser,
  }) async {
    final script = _findExtractScript();
    if (script == null) {
      return const CookieImportResult(
        success: false,
        reason: 'no_script',
        detail: 'extract_cookies.py 脚本未找到',
      );
    }

    // Try python3 first, then python as fallback
    ProcessResult result;
    try {
      result = await Process.run('python3', [
        script,
        browser,
        domain,
        outputFile,
      ], runInShell: false);
    } catch (_) {
      try {
        result = await Process.run('python', [
          script,
          browser,
          domain,
          outputFile,
        ], runInShell: false);
      } catch (e) {
        return CookieImportResult(
          success: false,
          reason: 'no_python',
          detail: 'Python 未安装或不在 PATH 中',
        );
      }
    }

    if (result.exitCode == 0) {
      final stderr = result.stderr.toString();
      final count = _parseBrowserCookie3Count(stderr);
      return CookieImportResult(
        success: true,
        detail: '已从 $actualBrowser 提取 $count 个 cookie (browser_cookie3)',
      );
    }

    final stderr = result.stderr.toString();
    if (stderr.contains('NO_MODULE')) {
      return const CookieImportResult(
        success: false,
        reason: 'no_module',
        detail: 'browser_cookie3 未安装。运行: pip install browser-cookie3',
      );
    }
    if (stderr.contains('NO_COOKIES')) {
      return CookieImportResult(
        success: false,
        reason: 'no_cookies',
        detail: '$actualBrowser: 未找到 $domain 的已登录 cookie',
      );
    }
    return CookieImportResult(
      success: false,
      reason: 'error',
      detail: '$actualBrowser: browser_cookie3 失败: ${stderr.trim()}',
    );
  }

  int _parseBrowserCookie3Count(String stderr) {
    final match = RegExp(r'EXTRACTED: (\d+)').firstMatch(stderr);
    if (match != null) return int.parse(match.group(1)!);
    return 0;
  }

  String? _bundledSecretToolPath() {
    // Check development path
    if (File('assets/bin/linux/secret-tool').existsSync()) {
      return 'assets/bin/linux/secret-tool';
    }
    // Check bundled release path
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final bundledPath =
        '$exeDir/data/flutter_assets/assets/bin/linux/secret-tool';
    if (File(bundledPath).existsSync()) return bundledPath;
    return null;
  }

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

    // Ensure bundled secret-tool is in PATH for Chrome-based browsers
    final secretTool = _bundledSecretToolPath();
    final testUrl = _siteTestUrls[domain] ?? 'https://$domain/';

    // Build browser list: selected browser first, then fallbacks
    final browsers = <String>[browser];
    for (final b in _browserFallback) {
      if (b != browser) browsers.add(b);
    }

    final failures = <String>[];
    for (final br in browsers) {
      if (file.existsSync()) file.deleteSync();

      // Prepare environment with bundled secret-tool if available
      Map<String, String>? env;
      if (secretTool != null && _chromeBased.contains(br)) {
        final secretDir = File(secretTool).parent.path;
        final existingPath = Platform.environment['PATH'] ?? '';
        env = {'PATH': '$secretDir:$existingPath'};
      }

      final process = await Process.start(
        ytDlpPath,
        [
          '--cookies-from-browser',
          br,
          '--cookies',
          outputFile,
          '--print',
          'id',
          '--skip-download',
          '--no-playlist',
          testUrl,
        ],
        runInShell: false,
        environment: env,
      );
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
        // Try browser_cookie3 as fallback for encrypted Chrome on Linux
        if (Platform.isLinux && _chromeBased.contains(br)) {
          final bc3 = await _tryBrowserCookie3(
            browser: br,
            domain: domain,
            outputFile: outputFile,
            actualBrowser: br,
          );
          if (bc3.success) return bc3;
          failures.add(bc3.detail!);
          continue;
        }
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
