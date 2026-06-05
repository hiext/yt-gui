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
        recommendedVariantCount: 3,
        downloadSubtitles: true,
        downloadThumbnail: true,
        disclaimerAccepted: true,
        aiAnalysisProvider: AiAnalysisProvider.cloudEndpoint,
        builtInClipAnalyzerMode: BuiltInClipAnalyzerMode.visualFocused,
        ytDlpPath: '/tools/yt-dlp',
        ffmpegPath: '/tools/ffmpeg',
        aiAnalyzerCommand: 'python3 tools/ai_clip_analyzer.py',
        selectedAiCloudConfigId: 'openai-main',
        aiCloudConfigs: [
          AiCloudConfig(
            id: 'openai-main',
            vendor: AiCloudVendor.openAI,
            name: 'OpenAI Main',
            endpoint: 'https://api.openai.com/v1/chat/completions',
            apiKey: 'test-key',
            model: 'gpt-4o-mini',
          ),
          AiCloudConfig(
            id: 'qwen-backup',
            vendor: AiCloudVendor.qwen,
            name: 'Qwen Backup',
            endpoint:
                'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
            model: 'qwen-plus',
          ),
        ],
      );

      final restored = DownloadSettings.fromJson(settings.toJson());

      expect(restored.saveDirectory, '/downloads');
      expect(restored.downloadMode, DownloadMode.concurrent);
      expect(restored.concurrentCount, 4);
      expect(restored.defaultQuality, 'bestvideo+bestaudio');
      expect(restored.recommendedVariantCount, 3);
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
      expect(
        restored.aiCloudEndpoint,
        'https://api.openai.com/v1/chat/completions',
      );
      expect(restored.aiCloudApiKey, 'test-key');
      expect(restored.aiCloudModel, 'gpt-4o-mini');
      expect(restored.selectedAiCloudConfigId, 'openai-main');
      expect(restored.aiCloudConfigs, hasLength(2));
      expect(restored.selectedAiCloudConfig?.vendor, AiCloudVendor.openAI);
    });

    test('normalizes missing and invalid persisted values', () {
      final restored = DownloadSettings.fromJson(const {
        'saveDirectory': '  ',
        'downloadMode': 'unknown',
        'concurrentCount': 99,
        'defaultQuality': '  ',
        'recommendedVariantCount': 99,
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
      expect(restored.recommendedVariantCount, 5);
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

    test('migrates legacy cloud endpoint into a cloud profile', () {
      final restored = DownloadSettings.fromJson(const {
        'aiCloudEndpoint': ' https://ai.example.com/analyze ',
        'aiCloudApiKey': ' token ',
        'aiCloudModel': ' clip-model ',
      });

      expect(restored.aiAnalysisProvider, AiAnalysisProvider.cloudEndpoint);
      expect(restored.selectedAiCloudConfigId, 'legacy-cloud');
      expect(restored.aiCloudConfigs.single.vendor, AiCloudVendor.custom);
      expect(restored.aiCloudEndpoint, 'https://ai.example.com/analyze');
      expect(restored.aiCloudApiKey, 'token');
      expect(restored.aiCloudModel, 'clip-model');
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
