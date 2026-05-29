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

    expect(find.text('保存目录'), findsOneWidget);
    expect(find.text('默认画质 / 格式'), findsOneWidget);
    expect(find.text('下载模式'), findsOneWidget);
    expect(find.text('并发数量'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('save-directory-field')),
      '/home/user/downloads',
    );
    await tester.enterText(
      find.byKey(const Key('default-quality-field')),
      'bestvideo+bestaudio',
    );

    expect(controller.settings.saveDirectory, '/home/user/downloads');
    expect(controller.settings.defaultQuality, 'bestvideo+bestaudio');
  });

  testWidgets('updates toggles and download mode', (tester) async {
    final controller = SettingsController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: SettingsPage(controller: controller)),
    );

    await tester.tap(find.text('下载字幕'));
    await tester.pump();
    await tester.tap(find.text('下载封面'));
    await tester.pump();

    expect(controller.settings.downloadSubtitles, isTrue);
    expect(controller.settings.downloadThumbnail, isTrue);

    await tester.tap(find.byKey(const Key('download-mode-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('并发下载').last);
    await tester.pumpAndSettle();

    expect(controller.settings.downloadMode, DownloadMode.concurrent);
  });
}
