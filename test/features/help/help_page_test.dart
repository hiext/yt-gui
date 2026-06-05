import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/features/help/help_page.dart';
import 'package:hiext_yt_gui/l10n/app_localizations.dart';

void main() {
  testWidgets('renders help mode section in english locale', (tester) async {
    await tester.pumpWidget(
      _buildApp(const HelpPage(), locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Help'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Download Modes'), 300);
    await tester.pumpAndSettle();

    expect(find.text('Download Modes'), findsOneWidget);
    expect(find.text('Serial Download'), findsOneWidget);
    expect(find.text('Queue Download'), findsOneWidget);
    expect(find.text('Concurrent Download'), findsOneWidget);
    expect(find.text('串行下载'), findsNothing);
    expect(find.text('队列下载'), findsNothing);
    expect(find.text('并发下载'), findsNothing);
  });
}

Widget _buildApp(Widget child, {Locale? locale}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}
