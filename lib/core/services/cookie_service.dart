import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_current.dart';
import '../models/app_models.dart';
import 'database_service.dart';

class CookieService {
  static const defaultBrowserImportTimeout = Duration(seconds: 20);

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
    required AppLocalizations l10n,
  }) async {
    final script = _findExtractScript();
    if (script == null) {
      return CookieImportResult(
        success: false,
        reason: 'no_script',
        detail: l10n.cookieScriptNotFound,
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
          detail: l10n.pythonNotFound,
        );
      }
    }

    if (result.exitCode == 0) {
      final stderr = result.stderr.toString();
      final count = _parseBrowserCookie3Count(stderr);
      return CookieImportResult(
        success: true,
        detail: l10n.cookiesExtractedWithBrowserCookie3(actualBrowser, count),
      );
    }

    final stderr = result.stderr.toString();
    if (stderr.contains('NO_MODULE')) {
      return CookieImportResult(
        success: false,
        reason: 'no_module',
        detail: l10n.browserCookie3NotInstalled,
      );
    }
    if (stderr.contains('NO_COOKIES')) {
      return CookieImportResult(
        success: false,
        reason: 'no_cookies',
        detail: l10n.browserCookie3NoCookies(actualBrowser, domain),
      );
    }
    return CookieImportResult(
      success: false,
      reason: 'error',
      detail: l10n.browserCookie3Failed(actualBrowser, stderr.trim()),
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
    AppLocalizations? localizations,
    Duration browserTimeout = defaultBrowserImportTimeout,
  }) async {
    final l10n = localizations ?? currentAppLocalizations();
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

      final runResult = await _runCookieImportProcess(
        ytDlpPath: ytDlpPath,
        browser: br,
        outputFile: outputFile,
        testUrl: testUrl,
        environment: env,
        timeout: browserTimeout,
      );
      final stderr = runResult.stderr;

      if (runResult.timedOut) {
        if (file.existsSync()) file.deleteSync();
        final timeoutSeconds = browserTimeout.inSeconds < 1
            ? 1
            : browserTimeout.inSeconds;
        failures.add(l10n.cookieImportTimedOut(br, timeoutSeconds));
        continue;
      }

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
            l10n: l10n,
          );
          if (bc3.success) return bc3;
          failures.add(bc3.detail!);
          continue;
        }
        failures.add(l10n.cookieDecryptFailed(br));
        continue;
      }

      if (!fileCreated) {
        failures.add(l10n.cookieFileNotGenerated(br));
        continue;
      }

      if (extractedCount == 0) {
        failures.add(l10n.loggedInCookiesNotFound(br));
        continue;
      }

      // Success — note which browser worked
      final actualBr = br;
      return CookieImportResult(
        success: true,
        detail: l10n.cookiesExtractedFromBrowser(actualBr, extractedCount),
      );
    }

    return CookieImportResult(
      success: false,
      reason: 'all_failed',
      detail: failures.join('\n'),
    );
  }

  Future<_CookieImportProcessResult> _runCookieImportProcess({
    required String ytDlpPath,
    required String browser,
    required String outputFile,
    required String testUrl,
    required Map<String, String>? environment,
    required Duration timeout,
  }) async {
    final process = await Process.start(
      ytDlpPath,
      [
        '--cookies-from-browser',
        browser,
        '--cookies',
        outputFile,
        '--print',
        'id',
        '--skip-download',
        '--no-playlist',
        testUrl,
      ],
      runInShell: false,
      environment: environment,
    ).timeout(timeout);

    final stdoutFuture = process.stdout.drain<void>();
    final stderrFuture = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .toList();
    final exitCodeFuture = process.exitCode;

    try {
      final exitCode = await exitCodeFuture.timeout(timeout);
      final stderr = await stderrFuture.timeout(
        const Duration(seconds: 2),
        onTimeout: () => const <String>[],
      );
      await stdoutFuture
          .timeout(const Duration(seconds: 2), onTimeout: () {})
          .catchError((_) {});
      return _CookieImportProcessResult(
        stderr: stderr,
        exitCode: exitCode,
        timedOut: false,
      );
    } on TimeoutException {
      process.kill();
      final stderr = await stderrFuture.timeout(
        const Duration(seconds: 2),
        onTimeout: () => const <String>[],
      );
      await stdoutFuture
          .timeout(const Duration(seconds: 2), onTimeout: () {})
          .catchError((_) {});
      final exitCode = await exitCodeFuture.timeout(
        const Duration(seconds: 2),
        onTimeout: () => -1,
      );
      return _CookieImportProcessResult(
        stderr: stderr,
        exitCode: exitCode,
        timedOut: true,
      );
    }
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
      for (final rawLine in file.readAsLinesSync()) {
        if (rawLine.trim().isEmpty) continue;
        if (rawLine.startsWith('#') && !rawLine.startsWith('#HttpOnly_')) {
          continue;
        }
        final normalizedLine = rawLine.startsWith('#HttpOnly_')
            ? rawLine.substring('#HttpOnly_'.length)
            : rawLine;
        final parts = normalizedLine.split('\t');
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

class _CookieImportProcessResult {
  const _CookieImportProcessResult({
    required this.stderr,
    required this.exitCode,
    required this.timedOut,
  });

  final List<String> stderr;
  final int exitCode;
  final bool timedOut;
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

  String expiryText(AppLocalizations l10n) {
    if (expiry == null) return l10n.cookieSession;
    if (isExpired) return l10n.cookieExpired;
    final diff = expiry!.difference(DateTime.now());
    if (diff.inDays > 0) return l10n.cookieExpiresInDays(diff.inDays);
    if (diff.inHours > 0) return l10n.cookieExpiresInHours(diff.inHours);
    return l10n.cookieExpiresSoon;
  }
}
