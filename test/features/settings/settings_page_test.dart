import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/controllers/settings_controller.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/features/settings/settings_page.dart';
import 'package:hiext_yt_gui/l10n/app_localizations.dart';

void main() {
  testWidgets('renders settings form and updates text fields', (tester) async {
    final controller = SettingsController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _buildApp(SettingsPage(controller: controller)),
    );

    final saveField = find.byKey(const Key('save-directory-field'));
    await tester.enterText(saveField, '/home/user/downloads');
    await tester.pump();

    final qualityField = find.byKey(const Key('default-quality-field'));
    await tester.ensureVisible(qualityField);
    await tester.pumpAndSettle();
    await tester.enterText(qualityField, 'bestvideo+bestaudio');
    await tester.pump();

    final ytField = find.byKey(const Key('yt-dlp-path-field'));
    await tester.ensureVisible(ytField);
    await tester.pumpAndSettle();
    await tester.enterText(ytField, '/tools/yt-dlp');
    await tester.pump();

    final ffField = find.byKey(const Key('ffmpeg-path-field'));
    await tester.ensureVisible(ffField);
    await tester.pumpAndSettle();
    await tester.enterText(ffField, '/tools/ffmpeg');
    await tester.pump();

    expect(controller.settings.saveDirectory, '/home/user/downloads');
    expect(controller.settings.defaultQuality, 'bestvideo+bestaudio');
    expect(controller.settings.ytDlpPath, '/tools/yt-dlp');
    expect(controller.settings.ffmpegPath, '/tools/ffmpeg');
  });

  testWidgets('updates toggles and download mode', (tester) async {
    final controller = SettingsController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _buildApp(SettingsPage(controller: controller)),
    );

    controller.updateDownloadSubtitles(true);
    controller.updateDownloadThumbnail(true);
    controller.updateDownloadMode(DownloadMode.concurrent);
    await tester.pump();

    expect(controller.settings.downloadSubtitles, isTrue);
    expect(controller.settings.downloadThumbnail, isTrue);
    expect(controller.settings.downloadMode, DownloadMode.concurrent);
  });

  testWidgets('renders cookie section in english locale', (tester) async {
    final controller = SettingsController(
      settings: DownloadSettings.defaults,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _buildApp(
        SettingsPage(controller: controller),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Cookie Management'), findsOneWidget);
    expect(find.text('Browser'), findsOneWidget);
    expect(find.text('Domain'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
    expect(find.text('设置'), findsNothing);
    expect(find.text('Cookie 管理'), findsNothing);
    expect(find.text('浏览器'), findsNothing);
    expect(find.text('域名'), findsNothing);
    expect(find.text('导入'), findsNothing);
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
