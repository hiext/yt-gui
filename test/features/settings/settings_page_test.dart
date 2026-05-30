import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/controllers/settings_controller.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/features/settings/settings_page.dart';

void main() {
  testWidgets('renders settings form and updates text fields', (tester) async {
    final controller = SettingsController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: SettingsPage(controller: controller)),
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
      MaterialApp(home: SettingsPage(controller: controller)),
    );

    // Scroll to the toggles section and tap
    final subtitleSwitch = find.widgetWithText(SwitchListTile, '下载字幕');
    final thumbnailSwitch = find.widgetWithText(SwitchListTile, '下载封面');
    await tester.dragUntilVisible(subtitleSwitch, find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(subtitleSwitch);
    await tester.pump();
    await tester.tap(thumbnailSwitch);
    await tester.pump();

    expect(controller.settings.downloadSubtitles, isTrue);
    expect(controller.settings.downloadThumbnail, isTrue);

    // Switch download mode - scroll to the mode dropdown
    final modeField = find.byKey(const Key('download-mode-field'));
    await tester.dragUntilVisible(modeField, find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(modeField);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('并发下载').last);
    await tester.pumpAndSettle();

    expect(controller.settings.downloadMode, DownloadMode.concurrent);
  });
}
