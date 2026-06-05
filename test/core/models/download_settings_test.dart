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
        disclaimerAccepted: true,
        aiAnalysisProvider: AiAnalysisProvider.cloudEndpoint,
        builtInClipAnalyzerMode: BuiltInClipAnalyzerMode.visualFocused,
        ytDlpPath: '/tools/yt-dlp',
        ffmpegPath: '/tools/ffmpeg',
        aiAnalyzerCommand: 'python3 tools/ai_clip_analyzer.py',
        aiCloudEndpoint: 'https://ai.example.com/analyze',
        aiCloudApiKey: 'test-key',
        aiCloudModel: 'clip-model',
      );

      final restored = DownloadSettings.fromJson(settings.toJson());

      expect(restored.saveDirectory, '/downloads');
      expect(restored.downloadMode, DownloadMode.concurrent);
      expect(restored.concurrentCount, 4);
      expect(restored.defaultQuality, 'bestvideo+bestaudio');
      expect(restored.downloadSubtitles, isTrue);
      expect(restored.downloadThumbnail, isTrue);
      expect(restored.disclaimerAccepted, isTrue);
      expect(restored.aiAnalysisProvider, AiAnalysisProvider.cloudEndpoint);
      expect(
        restored.builtInClipAnalyzerMode,
        BuiltInClipAnalyzerMode.visualFocused,
      );
      expect(restored.ytDlpPath, '/tools/yt-dlp');
      expect(restored.ffmpegPath, '/tools/ffmpeg');
      expect(restored.aiAnalyzerCommand, 'python3 tools/ai_clip_analyzer.py');
      expect(restored.aiCloudEndpoint, 'https://ai.example.com/analyze');
      expect(restored.aiCloudApiKey, 'test-key');
      expect(restored.aiCloudModel, 'clip-model');
    });

    test('normalizes missing and invalid persisted values', () {
      final restored = DownloadSettings.fromJson(const {
        'saveDirectory': '  ',
        'downloadMode': 'unknown',
        'concurrentCount': 99,
        'defaultQuality': '  ',
        'downloadSubtitles': true,
        'downloadThumbnail': true,
        'disclaimerAccepted': true,
        'aiAnalysisProvider': 'unknown',
        'builtInClipAnalyzerMode': 'unknown',
        'ytDlpPath': '  ',
        'ffmpegPath': ' /tools/ffmpeg ',
        'aiAnalyzerCommand': '  ',
        'aiCloudEndpoint': '  ',
      });

      expect(restored.saveDirectory, isNotEmpty);
      expect(restored.downloadMode, DownloadMode.serial);
      expect(restored.concurrentCount, 8);
      expect(restored.defaultQuality, 'best');
      expect(restored.downloadSubtitles, isTrue);
      expect(restored.downloadThumbnail, isTrue);
      expect(restored.disclaimerAccepted, isTrue);
      expect(restored.aiAnalysisProvider, AiAnalysisProvider.builtIn);
      expect(
        restored.builtInClipAnalyzerMode,
        BuiltInClipAnalyzerMode.balanced,
      );
      expect(restored.ytDlpPath, isNull);
      expect(restored.ffmpegPath, '/tools/ffmpeg');
      expect(restored.aiAnalyzerCommand, isNull);
      expect(restored.aiCloudEndpoint, isNull);
    });

    test('treats legacy analyzer command as external command provider', () {
      final restored = DownloadSettings.fromJson(const {
        'aiAnalyzerCommand': 'python3 tools/ai_clip_analyzer.py',
      });

      expect(restored.aiAnalysisProvider, AiAnalysisProvider.externalCommand);
      expect(restored.aiAnalyzerCommand, 'python3 tools/ai_clip_analyzer.py');
    });
  });
}
