import 'dart:ui' as ui;

import 'app_localizations.dart';

AppLocalizations currentAppLocalizations([ui.Locale? locale]) {
  return lookupAppLocalizations(
    locale ?? ui.PlatformDispatcher.instance.locale,
  );
}
