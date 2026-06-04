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
}
