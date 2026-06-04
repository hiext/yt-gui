import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/controllers/settings_controller.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';

void main() {
  group('SettingsController', () {
    test('starts with normalized defaults', () {
      final controller = SettingsController();
      addTearDown(controller.dispose);

      expect(controller.settings.saveDirectory, isNotEmpty);
      expect(controller.settings.defaultQuality, 'best');
      expect(controller.settings.concurrentCount, 1);
      expect(controller.settings.disclaimerAccepted, isFalse);
      expect(controller.settings.ytDlpPath, isNull);
      expect(controller.settings.ffmpegPath, isNull);
    });

    test('normalizes updates and notifies listeners', () {
      final controller = SettingsController();
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications += 1);

      controller.updateSettings(
        const DownloadSettings(
          saveDirectory: '  ',
          downloadMode: DownloadMode.concurrent,
          concurrentCount: 99,
          defaultQuality: '  ',
          downloadSubtitles: true,
          downloadThumbnail: true,
          disclaimerAccepted: true,
          ytDlpPath: '  ',
          ffmpegPath: ' /tools/ffmpeg ',
        ),
      );

      expect(notifications, 1);
      expect(controller.settings.saveDirectory, isNotEmpty);
      expect(controller.settings.downloadMode, DownloadMode.concurrent);
      expect(controller.settings.concurrentCount, 8);
      expect(controller.settings.defaultQuality, 'best');
      expect(controller.settings.downloadSubtitles, isTrue);
      expect(controller.settings.downloadThumbnail, isTrue);
      expect(controller.settings.disclaimerAccepted, isTrue);
      expect(controller.settings.ytDlpPath, isNull);
      expect(controller.settings.ffmpegPath, '/tools/ffmpeg');
    });

    test('updates individual settings fields', () {
      final controller = SettingsController();
      addTearDown(controller.dispose);

      controller.updateSaveDirectory('/downloads');
      controller.updateDownloadMode(DownloadMode.concurrent);
      controller.updateConcurrentCount(3);
      controller.updateDefaultQuality('bestvideo+bestaudio');
      controller.updateDownloadSubtitles(true);
      controller.updateDownloadThumbnail(true);
      controller.acknowledgeDisclaimer();
      controller.updateYtDlpPath('/tools/yt-dlp');
      controller.updateFfmpegPath('/tools/ffmpeg');

      expect(controller.settings.saveDirectory, '/downloads');
      expect(controller.settings.downloadMode, DownloadMode.concurrent);
      expect(controller.settings.concurrentCount, 3);
      expect(controller.settings.defaultQuality, 'bestvideo+bestaudio');
      expect(controller.settings.downloadSubtitles, isTrue);
      expect(controller.settings.downloadThumbnail, isTrue);
      expect(controller.settings.disclaimerAccepted, isTrue);
      expect(controller.settings.ytDlpPath, '/tools/yt-dlp');
      expect(controller.settings.ffmpegPath, '/tools/ffmpeg');
    });
  });
}
