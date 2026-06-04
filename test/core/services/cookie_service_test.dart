import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/services/cookie_service.dart';
import 'package:hiext_yt_gui/l10n/app_localizations.dart';

void main() {
  test('cookie expiry text uses localized labels', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final now = DateTime.now();

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

  test('parseCookieFile keeps #HttpOnly_ entries', () {
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

  test('parseCookieFile preserves trailing empty cookie values', () {
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
}
