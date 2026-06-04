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

    final l10n = AppLocalizations.of(
      tester.element(find.byType(SettingsPage)),
    )!;

    expect(find.text(l10n.settings), findsOneWidget);
    await tester.dragUntilVisible(
      find.text(l10n.importBtn),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.cookieManagement), findsOneWidget);
    expect(find.text(l10n.browser), findsOneWidget);
    expect(find.text(l10n.domain), findsOneWidget);
    expect(find.text(l10n.importBtn), findsOneWidget);
  });

  testWidgets('download mode field stays stable on narrow width', (
    tester,
  ) async {
    final controller = SettingsController();
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildApp(
        SettingsPage(controller: controller),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.byKey(const Key('download-mode-field')),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
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
