import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/cookie_service.dart';
import 'package:hiext_yt_gui/core/services/database_service.dart';
import 'package:hiext_yt_gui/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../sqlite_test_setup.dart';

Future<Database> _createTestDb() async {
  initTestSqlite();
  final d = await databaseFactoryFfiNoIsolate.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE cookie_configs (id INTEGER PRIMARY KEY AUTOINCREMENT, domain TEXT NOT NULL UNIQUE, data TEXT NOT NULL)',
        );
      },
    ),
  );
  return d;
}

void main() {
  // ---- Cookie configs DB tests ----
  group('saveConfigs / loadConfigs', () {
    late Database db;

    setUp(() async {
      db = await _createTestDb();
      DatabaseService().useTestDatabase(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('saveConfigs and loadConfigs round-trip', () async {
      final svc = CookieService();

      // Initially empty
      expect(await svc.loadConfigs(), isEmpty);

      // Save configs
      await svc.saveConfigs(<CookieConfig>[
        CookieConfig(domain: 'youtube.com', browser: 'chrome', cookieFile: '/tmp/yt.txt'),
        CookieConfig(domain: 'bilibili.com', browser: 'firefox', cookieFile: '/tmp/bi.txt'),
      ]);

      // Load and verify
      final loaded = await svc.loadConfigs();
      expect(loaded, hasLength(2));
      expect(loaded.map((c) => c.domain), containsAll(['youtube.com', 'bilibili.com']));
    });

    test('saveConfigs overwrites previous configs', () async {
      final svc = CookieService();

      await svc.saveConfigs(<CookieConfig>[
        CookieConfig(domain: 'old.com', browser: 'chrome', cookieFile: '/tmp/old.txt'),
      ]);
      expect(await svc.loadConfigs(), hasLength(1));

      await svc.saveConfigs(<CookieConfig>[
        CookieConfig(domain: 'new.com', browser: 'edge', cookieFile: '/tmp/new.txt'),
      ]);
      expect(await svc.loadConfigs(), hasLength(1));
      expect((await svc.loadConfigs()).single.domain, 'new.com');
    });

    test('saveConfigs handles empty list', () async {
      final svc = CookieService();
      await svc.saveConfigs(<CookieConfig>[]);
      expect(await svc.loadConfigs(), isEmpty);
    });
  });
  group('CookieEntry.expiryText', () {
    test('returns Session for null expiry', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        const CookieEntry(
          domain: '.example.com',
          flag: 'TRUE',
          path: '/',
          secure: true,
          name: 'session',
          value: 'abc',
        ).expiryText(l10n),
        'Session',
      );
    });

    test('returns Expired for past expiry', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final now = DateTime.now();
      expect(
        CookieEntry(
          domain: '.example.com',
          flag: 'TRUE',
          path: '/',
          secure: true,
          expiry: now.subtract(const Duration(hours: 1)),
          name: 'expired',
          value: 'abc',
        ).expiryText(l10n),
        'Expired',
      );
    });

    test('returns days for future expiry more than 24h away', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final now = DateTime.now();
      // Add 1 minute buffer to avoid edge case where the internal
      // DateTime.now() call inside expiryText shifts the inDays count.
      expect(
        CookieEntry(
          domain: '.example.com',
          flag: 'TRUE',
          path: '/',
          secure: true,
          expiry: now.add(const Duration(days: 5, minutes: 1)),
          name: 'future',
          value: 'abc',
        ).expiryText(l10n),
        l10n.cookieExpiresInDays(5),
      );
    });

    test('returns hours for future expiry less than 24h away', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final now = DateTime.now();
      expect(
        CookieEntry(
          domain: '.example.com',
          flag: 'TRUE',
          path: '/',
          secure: true,
          expiry: now.add(const Duration(hours: 3, minutes: 1)),
          name: 'future',
          value: 'abc',
        ).expiryText(l10n),
        l10n.cookieExpiresInHours(3),
      );
    });

    test('returns expires soon for future expiry under 1h', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final now = DateTime.now();
      expect(
        CookieEntry(
          domain: '.example.com',
          flag: 'TRUE',
          path: '/',
          secure: true,
          expiry: now.add(const Duration(minutes: 30)),
          name: 'future',
          value: 'abc',
        ).expiryText(l10n),
        l10n.cookieExpiresSoon,
      );
    });
  });

  group('CookieEntry.isExpired', () {
    test('false when expiry is null', () {
      const entry = CookieEntry(
        domain: '.example.com',
        flag: 'TRUE',
        path: '/',
        secure: true,
        name: 'session',
        value: 'abc',
      );
      expect(entry.isExpired, isFalse);
    });

    test('true when expiry is in the past', () {
      final entry = CookieEntry(
        domain: '.example.com',
        flag: 'TRUE',
        path: '/',
        secure: true,
        expiry: DateTime.now().subtract(const Duration(hours: 1)),
        name: 'expired',
        value: 'abc',
      );
      expect(entry.isExpired, isTrue);
    });

    test('false when expiry is in the future', () {
      final entry = CookieEntry(
        domain: '.example.com',
        flag: 'TRUE',
        path: '/',
        secure: true,
        expiry: DateTime.now().add(const Duration(days: 1)),
        name: 'valid',
        value: 'abc',
      );
      expect(entry.isExpired, isFalse);
    });
  });

  group('parseCookieFile', () {
    test('returns empty list for non-existent file', () {
      final entries = CookieService().parseCookieFile('/nonexistent/cookies.txt');
      expect(entries, isEmpty);
    });

    test('keeps #HttpOnly_ entries', () {
      final dir = Directory.systemTemp.createTempSync('cookie-service-test-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/cookies.txt')
        ..writeAsStringSync(
          '# Netscape HTTP Cookie File\n'
          '#HttpOnly_.youtube.com\tTRUE\t/\tTRUE\t2147483647\tSID\tvalue123\n'
          '.youtube.com\tTRUE\t/\tFALSE\t2147483647\tHSID\tvalue456\n',
        );

      final entries = CookieService().parseCookieFile(file.path);

      expect(entries, hasLength(2));
      expect(entries.first.domain, '.youtube.com');
      expect(entries.first.name, 'SID');
      expect(entries.first.value, 'value123');
      expect(entries.last.name, 'HSID');
    });

    test('preserves trailing empty cookie values', () {
      final dir = Directory.systemTemp.createTempSync('cookie-service-test-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/cookies.txt')
        ..writeAsStringSync(
          '# Netscape HTTP Cookie File\n'
          '#HttpOnly_.youtube.com\tTRUE\t/\tTRUE\t2147483647\tSID\t\n',
        );

      final entries = CookieService().parseCookieFile(file.path);

      expect(entries, hasLength(1));
      expect(entries.single.domain, '.youtube.com');
      expect(entries.single.name, 'SID');
      expect(entries.single.value, '');
    });

    test('skips comment lines but keeps HttpOnly prefixed lines', () {
      final dir = Directory.systemTemp.createTempSync('cookie-service-test-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/cookies.txt')
        ..writeAsStringSync(
          '# Netscape HTTP Cookie File\n'
          '# This is a comment\n'
          '.example.com\tTRUE\t/\tTRUE\t0\ttoken\tabc123\n',
        );

      final entries = CookieService().parseCookieFile(file.path);

      expect(entries, hasLength(1));
      expect(entries.single.name, 'token');
      expect(entries.single.value, 'abc123');
    });

    test('skips lines with fewer than 7 tab-separated fields', () {
      final dir = Directory.systemTemp.createTempSync('cookie-service-test-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/cookies.txt')
        ..writeAsStringSync(
          '# Netscape HTTP Cookie File\n'
          '.example.com\tTRUE\t/\tTRUE\n' // only 4 fields
          '.example.com\tTRUE\t/\tTRUE\t0\tname\tvalue\n', // 7 fields
        );

      final entries = CookieService().parseCookieFile(file.path);

      expect(entries, hasLength(1));
    });

    test('handles expiry timestamp parsing', () {
      final dir = Directory.systemTemp.createTempSync('cookie-service-test-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final futureTs =
          DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch ~/
              1000;
      final file = File('${dir.path}/cookies.txt')
        ..writeAsStringSync(
          '# Netscape HTTP Cookie File\n'
          '.example.com\tTRUE\t/\tTRUE\t$futureTs\ttoken\tvalue\n',
        );

      final entries = CookieService().parseCookieFile(file.path);

      expect(entries, hasLength(1));
      expect(entries.single.expiry, isNotNull);
      expect(entries.single.isExpired, isFalse);
    });
  });

  group('isCookieFileValid', () {
    test('returns false for non-existent file', () {
      expect(
        CookieService().isCookieFileValid('/nonexistent/cookies.txt'),
        isFalse,
      );
    });

    test('returns false for empty or small file', () {
      final dir = Directory.systemTemp.createTempSync('cookie-service-test-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/small.txt')..writeAsStringSync('tiny');

      expect(CookieService().isCookieFileValid(file.path), isFalse);
    });

    test('returns true for valid cookie file', () {
      final dir = Directory.systemTemp.createTempSync('cookie-service-test-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/cookies.txt')
        ..writeAsStringSync('.example.com\tTRUE\t/\tTRUE\t0\ttoken\tvalue123456');

      expect(CookieService().isCookieFileValid(file.path), isTrue);
    });
  });

  // _parseExtractedCount and _parseBrowserCookie3Count are private methods.
  // They are tested indirectly through importFromBrowser integration flow,
  // or through parseCookieFile which exercises the cookie parsing logic.
  // The private helper behavior is verified by the cookie file parsing tests above.
}
