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
      expect(
        controller.settings.aiAnalysisProvider,
        AiAnalysisProvider.builtIn,
      );
      expect(
        controller.settings.builtInClipAnalyzerMode,
        BuiltInClipAnalyzerMode.balanced,
      );
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
          aiAnalysisProvider: AiAnalysisProvider.cloudEndpoint,
          builtInClipAnalyzerMode: BuiltInClipAnalyzerMode.visualFocused,
          ytDlpPath: '  ',
          ffmpegPath: ' /tools/ffmpeg ',
          aiCloudEndpoint: ' https://ai.example.com/analyze ',
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
      expect(
        controller.settings.aiAnalysisProvider,
        AiAnalysisProvider.cloudEndpoint,
      );
      expect(
        controller.settings.builtInClipAnalyzerMode,
        BuiltInClipAnalyzerMode.visualFocused,
      );
      expect(controller.settings.ytDlpPath, isNull);
      expect(controller.settings.ffmpegPath, '/tools/ffmpeg');
      expect(
        controller.settings.aiCloudEndpoint,
        'https://ai.example.com/analyze',
      );
      expect(controller.settings.selectedAiCloudConfigId, 'legacy-cloud');
      expect(
        controller.settings.aiCloudConfigs.single.vendor,
        AiCloudVendor.custom,
      );
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
      controller.updateAiAnalysisProvider(AiAnalysisProvider.cloudEndpoint);
      controller.updateBuiltInClipAnalyzerMode(
        BuiltInClipAnalyzerMode.audioFocused,
      );
      controller.updateAiAnalyzerCommand('python3 tools/ai_clip_analyzer.py');
      controller.updateAiCloudEndpoint('https://ai.example.com/analyze');
      controller.updateAiCloudApiKey('token');
      controller.updateAiCloudModel('clip-model');

      expect(controller.settings.saveDirectory, '/downloads');
      expect(controller.settings.downloadMode, DownloadMode.concurrent);
      expect(controller.settings.concurrentCount, 3);
      expect(controller.settings.defaultQuality, 'bestvideo+bestaudio');
      expect(controller.settings.downloadSubtitles, isTrue);
      expect(controller.settings.downloadThumbnail, isTrue);
      expect(controller.settings.disclaimerAccepted, isTrue);
      expect(controller.settings.ytDlpPath, '/tools/yt-dlp');
      expect(controller.settings.ffmpegPath, '/tools/ffmpeg');
      expect(
        controller.settings.aiAnalysisProvider,
        AiAnalysisProvider.cloudEndpoint,
      );
      expect(
        controller.settings.builtInClipAnalyzerMode,
        BuiltInClipAnalyzerMode.audioFocused,
      );
      expect(
        controller.settings.aiAnalyzerCommand,
        'python3 tools/ai_clip_analyzer.py',
      );
      expect(
        controller.settings.aiCloudEndpoint,
        'https://ai.example.com/analyze',
      );
      expect(controller.settings.aiCloudApiKey, 'token');
      expect(controller.settings.aiCloudModel, 'clip-model');
      expect(
        controller.settings.aiCloudConfigs.single.vendor,
        AiCloudVendor.custom,
      );
    });

    test('adds selects edits and removes cloud vendor profiles', () {
      final controller = SettingsController();
      addTearDown(controller.dispose);

      controller.addAiCloudConfig(AiCloudVendor.openAI);
      controller.addAiCloudConfig(AiCloudVendor.qwen);
      controller.updateSelectedAiCloudConfig('openAI');
      controller.updateSelectedAiCloudName('OpenAI Clips');
      controller.updateAiCloudApiKey('openai-token');
      controller.updateSelectedAiCloudVendor(AiCloudVendor.groq);

      expect(
        controller.settings.aiAnalysisProvider,
        AiAnalysisProvider.cloudEndpoint,
      );
      expect(controller.settings.aiCloudConfigs, hasLength(2));
      expect(controller.settings.selectedAiCloudConfigId, 'openAI');
      expect(
        controller.settings.selectedAiCloudConfig?.vendor,
        AiCloudVendor.groq,
      );
      expect(controller.settings.selectedAiCloudConfig?.apiKey, 'openai-token');
      expect(
        controller.settings.selectedAiCloudConfig?.endpoint,
        'https://api.groq.com/openai/v1/chat/completions',
      );

      controller.removeAiCloudConfig('openAI');

      expect(controller.settings.aiCloudConfigs, hasLength(1));
      expect(controller.settings.selectedAiCloudConfigId, 'qwen');
      expect(
        controller.settings.selectedAiCloudConfig?.vendor,
        AiCloudVendor.qwen,
      );
    });
  });
}
