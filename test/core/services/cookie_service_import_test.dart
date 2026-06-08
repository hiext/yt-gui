import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/services/cookie_service.dart';
import 'package:hiext_yt_gui/l10n/app_localizations.dart';

/// Creates a fake yt-dlp script that writes stderr AND creates the cookie output file.
File _createFakeYtDlp(Directory dir, {
  int exitCode = 0,
  String stderr = '',
  bool createOutput = true,
}) {
  final script = File('${dir.path}/yt-dlp-fake');

  final buf = StringBuffer();
  buf.writeln('#!/bin/sh');
  buf.writeln('cookie_file=""');
  buf.writeln('next_is_cookie=0');
  buf.writeln(r'for arg in $@; do');
  buf.writeln(r'  if [ "$next_is_cookie" = "1" ]; then');
  buf.writeln(r'    cookie_file="$arg"');
  buf.writeln(r'    break');
  buf.writeln(r'  fi');
  buf.writeln(r'  if [ "$arg" = "--cookies" ]; then');
  buf.writeln(r'    next_is_cookie=1');
  buf.writeln(r'  fi');
  buf.writeln(r'done');
  // Write the actual stderr (Dart interpolation here is intentional)
  buf.writeln('echo "${stderr.replaceAll('"', '\\"')}" >&2');
  if (createOutput) {
    buf.writeln(r'if [ -n "$cookie_file" ]; then');
    buf.writeln(r'  mkdir -p "$(dirname "$cookie_file")"');
    buf.writeln(r'  echo "# Netscape HTTP Cookie File" > "$cookie_file"');
    buf.writeln(r'  echo ".example.com\tTRUE\t/\tTRUE\t0\ttest\tvalue123" >> "$cookie_file"');
    buf.writeln(r'fi');
  }
  buf.writeln('exit ${exitCode}');

  script.writeAsStringSync(buf.toString());
  Process.runSync('chmod', ['+x', script.path]);
  return script;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('importFromBrowser - success', () {
    test('imports cookies and reports extracted count', () async {
      final dir = Directory.systemTemp.createTempSync('cookie-test-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final outputFile = '${dir.path}/cookies.txt';

      final fakeYtDlp = _createFakeYtDlp(dir,
        stderr: '[Cookies] Extracted 10 cookies from chrome',
      );

      final result = await CookieService().importFromBrowser(
        browser: 'chrome',
        domain: 'youtube.com',
        ytDlpPath: fakeYtDlp.path,
        outputFile: outputFile,
        localizations: l10n,
      );

      expect(result.success, isTrue);
      expect(result.detail, contains('10'));
    });

    test('handles bilibili.com domain', () async {
      final dir = Directory.systemTemp.createTempSync('cookie-test-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final outputFile = '${dir.path}/cookies.txt';

      final fakeYtDlp = _createFakeYtDlp(dir,
        stderr: '[Cookies] Extracted 8 cookies from firefox',
      );

      final result = await CookieService().importFromBrowser(
        browser: 'firefox',
        domain: 'bilibili.com',
        ytDlpPath: fakeYtDlp.path,
        outputFile: outputFile,
        localizations: l10n,
      );

      expect(result.success, isTrue);
    });

    test('handles custom domain', () async {
      final dir = Directory.systemTemp.createTempSync('cookie-test-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final outputFile = '${dir.path}/cookies.txt';

      final fakeYtDlp = _createFakeYtDlp(dir,
        stderr: '[Cookies] Extracted 3 cookies from edge',
      );

      final result = await CookieService().importFromBrowser(
        browser: 'edge',
        domain: 'nicovideo.jp',
        ytDlpPath: fakeYtDlp.path,
        outputFile: outputFile,
        localizations: l10n,
      );

      expect(result.success, isTrue);
    });

    test('creates nested output directory', () async {
      final dir = Directory.systemTemp.createTempSync('cookie-test-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final nestedDir = '${dir.path}/deeply/nested';
      final outputFile = '$nestedDir/cookies.txt';

      final fakeYtDlp = _createFakeYtDlp(dir,
        stderr: '[Cookies] Extracted 1 cookie from brave',
      );

      await CookieService().importFromBrowser(
        browser: 'brave',
        domain: 'youtube.com',
        ytDlpPath: fakeYtDlp.path,
        outputFile: outputFile,
        localizations: l10n,
      );

      expect(Directory(nestedDir).existsSync(), isTrue);
    });
  });

  group('importFromBrowser - failure', () {
    test('throws ProcessException for nonexistent binary', () async {
      final dir = Directory.systemTemp.createTempSync('cookie-test-');
      addTearDown(() => dir.deleteSync(recursive: true));

      expect(
        () => CookieService().importFromBrowser(
          browser: 'chrome',
          domain: 'youtube.com',
          ytDlpPath: '/nonexistent/yt-dlp-xyz',
          outputFile: '${dir.path}/cookies.txt',
          localizations: l10n,
        ),
        throwsA(isA<ProcessException>()),
      );
    });

    test('fails when zero cookies extracted', () async {
      final dir = Directory.systemTemp.createTempSync('cookie-test-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final outputFile = '${dir.path}/cookies.txt';

      final fakeYtDlp = _createFakeYtDlp(dir,
        stderr: '[Cookies] Extracted 0 cookies from chrome',
      );

      final result = await CookieService().importFromBrowser(
        browser: 'chrome',
        domain: 'youtube.com',
        ytDlpPath: fakeYtDlp.path,
        outputFile: outputFile,
        localizations: l10n,
      );

      expect(result.success, isFalse);
      expect(result.reason, 'all_failed');
    });

    test('fails when output file not generated', () async {
      final dir = Directory.systemTemp.createTempSync('cookie-test-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final outputFile = '${dir.path}/cookies.txt';

      final fakeYtDlp = _createFakeYtDlp(dir,
        stderr: 'Some error occurred',
        createOutput: false,
      );

      final result = await CookieService().importFromBrowser(
        browser: 'chrome',
        domain: 'youtube.com',
        ytDlpPath: fakeYtDlp.path,
        outputFile: outputFile,
        localizations: l10n,
      );

      expect(result.success, isFalse);
    });

    test('could not be decrypted + 0 cookies → falls back to next browser', () async {
      final dir = Directory.systemTemp.createTempSync('cookie-test-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final outputFile = '${dir.path}/cookies.txt';

      // First browser (chrome) hits "could not be decrypted + 0 cookies",
      // which triggers browser_cookie3 fallback. browser_cookie3 fails,
      // so it tries the next fallback browser (firefox) which succeeds.
      final fakeYtDlp = _createFakeYtDlp(dir,
        stderr: 'WARNING: could not be decrypted\n'
                '[Cookies] Extracted 0 cookies from chrome',
      );

      final result = await CookieService().importFromBrowser(
        browser: 'chrome',
        domain: 'youtube.com',
        ytDlpPath: fakeYtDlp.path,
        outputFile: outputFile,
        localizations: l10n,
      );

      // Falls back to next browser in the list which succeeds
      expect(result.success, isTrue);
    });

    test('could not be decrypted with cookies → still succeeds', () async {
      final dir = Directory.systemTemp.createTempSync('cookie-test-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final outputFile = '${dir.path}/cookies.txt';

      final fakeYtDlp = _createFakeYtDlp(dir,
        stderr: 'WARNING: could not be decrypted\n'
                '[Cookies] Extracted 5 cookies from chrome',
      );

      final result = await CookieService().importFromBrowser(
        browser: 'chrome',
        domain: 'youtube.com',
        ytDlpPath: fakeYtDlp.path,
        outputFile: outputFile,
        localizations: l10n,
      );

      // extractedCount > 0 and fileCreated → success
      expect(result.success, isTrue);
    });
  });

  group('isCookieFileValid', () {
    test('returns false for file under 10 bytes', () {
      final dir = Directory.systemTemp.createTempSync('cookie-test-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/tiny.txt')..writeAsStringSync('123456789'); // 9 bytes
      expect(CookieService().isCookieFileValid(file.path), isFalse);
    });

    test('returns true for file >= 10 bytes', () {
      final dir = Directory.systemTemp.createTempSync('cookie-test-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/ok.txt')..writeAsStringSync('1234567890ABC'); // 13 bytes
      expect(CookieService().isCookieFileValid(file.path), isTrue);
    });
  });

  group('importFromBrowser - edge cases', () {
    test('uses default localizations when not provided', () async {
      final dir = Directory.systemTemp.createTempSync('cookie-test-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final outputFile = '${dir.path}/cookies.txt';

      final fakeYtDlp = _createFakeYtDlp(dir,
        stderr: '[Cookies] Extracted 2 cookies from firefox',
      );

      // Pass null for localizations → should use currentAppLocalizations()
      final result = await CookieService().importFromBrowser(
        browser: 'firefox',
        domain: 'youtube.com',
        ytDlpPath: fakeYtDlp.path,
        outputFile: outputFile,
        localizations: null,
      );

      expect(result.success, isTrue);
    });
  });

  group('CookieImportResult', () {
    test('success with detail', () {
      const r = CookieImportResult(success: true, detail: '5 cookies from chrome');
      expect(r.success, isTrue);
      expect(r.reason, isNull);
      expect(r.detail, '5 cookies from chrome');
    });

    test('failure with reason and detail', () {
      const r = CookieImportResult(
        success: false,
        reason: 'no_cookies',
        detail: 'No cookies found',
      );
      expect(r.success, isFalse);
      expect(r.reason, 'no_cookies');
      expect(r.detail, 'No cookies found');
    });
  });
}
