import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/controllers/settings_controller.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/media_asset_repository.dart';
import 'package:hiext_yt_gui/features/settings/settings_page.dart';
import 'package:hiext_yt_gui/l10n/app_localizations.dart';

void main() {
  /// Helper to use a viewport tall enough to fit most content
  Future<void> useLargeViewport(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 7000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  group('form fields', () {
    testWidgets('updates text and dropdown fields', (tester) async {
      final controller = SettingsController();
      addTearDown(controller.dispose);
      await useLargeViewport(tester);

      await tester.pumpWidget(_buildApp(SettingsPage(controller: controller)));
      await tester.pumpAndSettle();

      final saveField = find.byKey(const Key('save-directory-field'));
      await tester.enterText(saveField, '/home/user/downloads');
      await tester.pump();

      final qualityField = find.byKey(const Key('default-quality-field'));
      await tester.ensureVisible(qualityField);
      await tester.pumpAndSettle();
      await tester.tap(qualityField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('bestvideo+bestaudio').last);
      await tester.pumpAndSettle();

      final recField = find.byKey(const Key('recommended-variant-count-field'));
      await tester.ensureVisible(recField);
      await tester.pumpAndSettle();
      await tester.enterText(recField, '4');
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
      expect(controller.settings.recommendedVariantCount, 4);
      expect(controller.settings.ytDlpPath, '/tools/yt-dlp');
      expect(controller.settings.ffmpegPath, '/tools/ffmpeg');
    });

    testWidgets('updates toggles and download mode', (tester) async {
      final controller = SettingsController();
      addTearDown(controller.dispose);
      await useLargeViewport(tester);

      await tester.pumpWidget(_buildApp(SettingsPage(controller: controller)));
      await tester.pumpAndSettle();

      controller.updateDownloadSubtitles(true);
      controller.updateDownloadThumbnail(true);
      controller.updateDownloadMode(DownloadMode.concurrent);
      await tester.pump();

      expect(controller.settings.downloadSubtitles, isTrue);
      expect(controller.settings.downloadThumbnail, isTrue);
      expect(controller.settings.downloadMode, DownloadMode.concurrent);
    });
  });

  group('section visibility', () {
    testWidgets('all major sections are present', (tester) async {
      final controller = SettingsController();
      addTearDown(controller.dispose);
      await useLargeViewport(tester);

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
      expect(find.text(l10n.saveAndQuality), findsOneWidget);
      expect(find.text(l10n.externalTools), findsOneWidget);
      expect(find.text(l10n.downloadMode), findsOneWidget);
      expect(find.text(l10n.additionalOptions), findsOneWidget);
      expect(find.text(l10n.aiClipAnalysis), findsOneWidget);
      expect(find.text(l10n.cookieManagement), findsOneWidget);
    });

    testWidgets('restore defaults button present', (tester) async {
      final controller = SettingsController();
      addTearDown(controller.dispose);
      await useLargeViewport(tester);

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
      expect(find.text(l10n.restoreDefaults), findsOneWidget);
      expect(find.byIcon(Icons.restore_outlined), findsOneWidget);
    });

    testWidgets('download mode dropdown visible', (tester) async {
      final controller = SettingsController();
      addTearDown(controller.dispose);
      await useLargeViewport(tester);

      await tester.pumpWidget(
        _buildApp(
          SettingsPage(controller: controller),
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('download-mode-field')), findsOneWidget);
    });

    testWidgets('log level section present', (tester) async {
      final controller = SettingsController();
      addTearDown(controller.dispose);
      await useLargeViewport(tester);

      await tester.pumpWidget(_buildApp(SettingsPage(controller: controller)));
      await tester.pumpAndSettle();

      expect(find.text('Log Level'), findsOneWidget);
    });

    testWidgets('save bar present', (tester) async {
      final controller = SettingsController();
      addTearDown(controller.dispose);
      await useLargeViewport(tester);

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
      expect(find.text(l10n.saveSettingsBtn), findsOneWidget);
    });

    testWidgets('save bar shows unsaved after edit', (tester) async {
      final controller = SettingsController();
      addTearDown(controller.dispose);
      await useLargeViewport(tester);

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
      final saveField = find.byKey(const Key('save-directory-field'));
      await tester.enterText(saveField, '/tmp');
      await tester.pump();

      expect(find.text(l10n.settingsUnsaved), findsOneWidget);
    });
  });

  group('AI section', () {
    testWidgets('shows builtin mode dropdown', (tester) async {
      final controller = SettingsController();
      addTearDown(controller.dispose);
      await useLargeViewport(tester);

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
      expect(
        find.byKey(const Key('built-in-clip-analyzer-mode-field')),
        findsOneWidget,
      );
      expect(find.text(l10n.builtInBalanced), findsOneWidget);
    });

    testWidgets('shows external command field', (tester) async {
      final controller = SettingsController(
        settings: DownloadSettings.defaults.copyWith(
          aiAnalysisProvider: AiAnalysisProvider.externalCommand,
        ),
      );
      addTearDown(controller.dispose);
      await useLargeViewport(tester);

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
      expect(find.text(l10n.aiAnalyzerCommand), findsOneWidget);
    });

    testWidgets('shows no profiles message when cloud configs empty', (
      tester,
    ) async {
      final controller = SettingsController(
        settings: DownloadSettings.defaults.copyWith(
          aiAnalysisProvider: AiAnalysisProvider.cloudEndpoint,
          aiCloudConfigs: const <AiCloudConfig>[],
        ),
      );
      addTearDown(controller.dispose);
      await useLargeViewport(tester);

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
      expect(find.text(l10n.aiCloudNoProfiles), findsOneWidget);
    });

    testWidgets('cloud config fields visible when cloud configured', (
      tester,
    ) async {
      final cloudConfig = AiCloudConfig(
        id: 'cloud-1',
        vendor: AiCloudVendor.openAI,
        name: 'My OpenAI',
        endpoint: 'https://api.openai.com',
        apiKey: 'sk-test',
        model: 'gpt-4',
      );
      final controller = SettingsController(
        settings: DownloadSettings.defaults.copyWith(
          aiAnalysisProvider: AiAnalysisProvider.cloudEndpoint,
          aiCloudConfigs: [cloudConfig],
          selectedAiCloudConfigId: cloudConfig.id,
        ),
      );
      addTearDown(controller.dispose);
      await useLargeViewport(tester);

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
      expect(find.text(l10n.aiCloudProfileName), findsOneWidget);
      expect(find.text(l10n.aiCloudEndpoint), findsOneWidget);
      expect(find.text(l10n.aiCloudModel), findsOneWidget);
      expect(find.text(l10n.aiCloudApiKey), findsOneWidget);
      expect(find.text(l10n.deleteAiCloudProfile), findsOneWidget);
    });

    testWidgets('add profile dropdown exists', (tester) async {
      final controller = SettingsController(
        settings: DownloadSettings.defaults.copyWith(
          aiAnalysisProvider: AiAnalysisProvider.cloudEndpoint,
        ),
      );
      addTearDown(controller.dispose);
      await useLargeViewport(tester);

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
      expect(
        find.byKey(const Key('ai-cloud-add-vendor-field')),
        findsOneWidget,
      );
      expect(find.text(l10n.addAiCloudProfile), findsOneWidget);
    });
  });

  group('personal cloud section', () {
    testWidgets('saves personal cloud connection config', (tester) async {
      final controller = SettingsController();
      final repository = _FakeMediaAssetRepository();
      addTearDown(controller.dispose);
      await useLargeViewport(tester);

      await tester.pumpWidget(
        _buildApp(
          SettingsPage(
            controller: controller,
            mediaAssetRepository: repository,
          ),
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('personal-cloud-url-field')),
        'https://clips.example.test/',
      );
      await tester.enterText(
        find.byKey(const Key('personal-cloud-device-field')),
        'mac-mini',
      );
      await tester.enterText(
        find.byKey(const Key('personal-cloud-token-field')),
        'token-1',
      );
      await tester.enterText(
        find.byKey(const Key('personal-cloud-pairing-token-field')),
        'pair-once',
      );
      await tester.tap(
        find.byKey(const Key('personal-cloud-sync-enabled-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('personal-cloud-save-button')));
      await tester.pumpAndSettle();

      expect(repository.savedConfigs, hasLength(1));
      expect(
        repository.savedConfigs.single.baseUrl,
        'https://clips.example.test',
      );
      expect(repository.savedConfigs.single.deviceName, 'mac-mini');
      expect(repository.savedConfigs.single.accessToken, 'token-1');
      expect(repository.savedConfigs.single.syncEnabled, isTrue);
      expect(
        repository.savedConfigs.single.toJson().containsKey('pairingToken'),
        isFalse,
      );
    });
  });

  group('download options', () {
    testWidgets('additional options toggles present', (tester) async {
      final controller = SettingsController();
      addTearDown(controller.dispose);
      await useLargeViewport(tester);

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
      expect(find.text(l10n.downloadSubtitles), findsOneWidget);
      expect(find.text(l10n.downloadThumbnail), findsOneWidget);
    });

    testWidgets('concurrent count section exists', (tester) async {
      final controller = SettingsController();
      addTearDown(controller.dispose);
      await useLargeViewport(tester);

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
      expect(find.text(l10n.concurrentCount), findsOneWidget);
    });
  });

  group('cookie section', () {
    testWidgets('cookie management header visible', (tester) async {
      final controller = SettingsController(
        settings: DownloadSettings.defaults.copyWith(
          cookieConfigs: const <CookieConfig>[],
        ),
      );
      addTearDown(controller.dispose);
      await useLargeViewport(tester);

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
      expect(find.text(l10n.cookieManagement), findsOneWidget);
      expect(find.text(l10n.browser), findsOneWidget);
      expect(find.text(l10n.domain), findsOneWidget);
      expect(find.text(l10n.importBtn), findsOneWidget);
      expect(find.text(l10n.commonSites), findsOneWidget);
    });

    testWidgets('imported cookies rendered in list', (tester) async {
      final configs = [
        CookieConfig(
          domain: 'youtube.com',
          browser: 'chrome',
          cookieFile: '/tmp/yt.txt',
        ),
        CookieConfig(
          domain: 'bilibili.com',
          browser: 'firefox',
          cookieFile: '/tmp/bi.txt',
        ),
      ];
      final controller = SettingsController(
        settings: DownloadSettings.defaults.copyWith(cookieConfigs: configs),
      );
      addTearDown(controller.dispose);
      await useLargeViewport(tester);

      await tester.pumpWidget(
        _buildApp(
          SettingsPage(controller: controller),
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      // Cookie tiles should show the imported domains
      expect(find.text('youtube.com'), findsOneWidget);
      expect(find.text('bilibili.com'), findsOneWidget);
    });

    testWidgets('narrow layout does not crash', (tester) async {
      final controller = SettingsController();
      addTearDown(controller.dispose);
      await tester.binding.setSurfaceSize(const Size(380, 7000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildApp(
          SettingsPage(controller: controller),
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}

class _FakeMediaAssetRepository extends MediaAssetRepository {
  final savedConfigs = <CloudConnectionConfig>[];

  @override
  Future<void> saveCloudConnectionConfig(CloudConnectionConfig config) async {
    savedConfigs.add(config.normalized());
  }

  @override
  Future<List<CloudConnectionConfig>> loadCloudConnectionConfigs({
    bool enabledOnly = false,
  }) async {
    return savedConfigs;
  }
}

Widget _buildApp(Widget child, {Locale? locale}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}
