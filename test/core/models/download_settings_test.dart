import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';

void main() {
  group('DownloadSettings serialization', () {
    test('round trips all settings fields', () {
      const settings = DownloadSettings(
        saveDirectory: '/downloads',
        downloadMode: DownloadMode.concurrent,
        concurrentCount: 4,
        defaultQuality: 'bestvideo+bestaudio',
        downloadSubtitles: true,
        downloadThumbnail: true,
        ytDlpPath: '/tools/yt-dlp',
        ffmpegPath: '/tools/ffmpeg',
      );

      final restored = DownloadSettings.fromJson(settings.toJson());

      expect(restored.saveDirectory, '/downloads');
      expect(restored.downloadMode, DownloadMode.concurrent);
      expect(restored.concurrentCount, 4);
      expect(restored.defaultQuality, 'bestvideo+bestaudio');
      expect(restored.downloadSubtitles, isTrue);
      expect(restored.downloadThumbnail, isTrue);
      expect(restored.ytDlpPath, '/tools/yt-dlp');
      expect(restored.ffmpegPath, '/tools/ffmpeg');
    });

    test('normalizes missing and invalid persisted values', () {
      final restored = DownloadSettings.fromJson(const {
        'saveDirectory': '  ',
        'downloadMode': 'unknown',
        'concurrentCount': 99,
        'defaultQuality': '  ',
        'downloadSubtitles': true,
        'downloadThumbnail': true,
        'ytDlpPath': '  ',
        'ffmpegPath': ' /tools/ffmpeg ',
      });

      expect(restored.saveDirectory, '.');
      expect(restored.downloadMode, DownloadMode.serial);
      expect(restored.concurrentCount, 8);
      expect(restored.defaultQuality, 'best');
      expect(restored.downloadSubtitles, isTrue);
      expect(restored.downloadThumbnail, isTrue);
      expect(restored.ytDlpPath, isNull);
      expect(restored.ffmpegPath, '/tools/ffmpeg');
    });
  });
}
