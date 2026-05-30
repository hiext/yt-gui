import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/settings_repository.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  group('SettingsRepository', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test('loads defaults when no settings are saved', () async {
      final repository = SettingsRepository();

      final settings = await repository.load();

      expect(settings.saveDirectory, '.');
      expect(settings.defaultQuality, 'best');
      expect(settings.ytDlpPath, isNull);
      expect(settings.ffmpegPath, isNull);
    });

    test('saves and loads settings', () async {
      final repository = SettingsRepository();
      const settings = DownloadSettings(
        saveDirectory: '/downloads',
        downloadMode: DownloadMode.concurrent,
        concurrentCount: 3,
        defaultQuality: 'bestvideo+bestaudio',
        downloadSubtitles: true,
        downloadThumbnail: true,
        ytDlpPath: '/tools/yt-dlp',
        ffmpegPath: '/tools/ffmpeg',
      );

      await repository.save(settings);
      final restored = await repository.load();

      expect(restored.saveDirectory, '/downloads');
      expect(restored.downloadMode, DownloadMode.concurrent);
      expect(restored.concurrentCount, 3);
      expect(restored.defaultQuality, 'bestvideo+bestaudio');
      expect(restored.downloadSubtitles, isTrue);
      expect(restored.downloadThumbnail, isTrue);
      expect(restored.ytDlpPath, '/tools/yt-dlp');
      expect(restored.ffmpegPath, '/tools/ffmpeg');
    });

    test('removes optional tool paths when they are cleared', () async {
      final repository = SettingsRepository();
      await repository.save(
        DownloadSettings.defaults.copyWith(
          ytDlpPath: '/tools/yt-dlp',
          ffmpegPath: '/tools/ffmpeg',
        ),
      );

      await repository.save(DownloadSettings.defaults);
      final restored = await repository.load();

      expect(restored.ytDlpPath, isNull);
      expect(restored.ffmpegPath, isNull);
    });
  });
}
