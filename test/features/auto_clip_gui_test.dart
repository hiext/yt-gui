import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/controllers/download_controller.dart';
import 'package:hiext_yt_gui/core/controllers/post_process_controller.dart';
import 'package:hiext_yt_gui/core/controllers/settings_controller.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/ai_clip_analyzer_executor.dart';
import 'package:hiext_yt_gui/core/services/download_scheduler.dart';
import 'package:hiext_yt_gui/core/services/post_process_repository.dart';
import 'package:hiext_yt_gui/core/services/yt_dlp_executor.dart';
import 'package:hiext_yt_gui/features/home/home_page.dart';
import 'package:hiext_yt_gui/features/clips/clip_library_page.dart';
import 'package:hiext_yt_gui/features/settings/settings_page.dart';
import 'package:hiext_yt_gui/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../sqlite_test_setup.dart';

final inspectedUrls = <String>[];

Future<List<ResourceVariant>> _fakeInspect(
  Uri uri, {
  DownloadSettings? settings,
  AppLocalizations? localizations,
  InspectLogSink? onLog,
}) async {
  inspectedUrls.add(uri.toString());
  return const [
    ResourceVariant(label: '720p', description: 'mp4', isRecommended: true, formatId: '1'),
  ];
}

class FakeYtDlpExecutor implements YtDlpExecutor {
  @override
  Future<void> cancel(String taskId) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<List<ResourceVariant>> inspect(
    Uri url, {
    DownloadSettings? settings,
    AppLocalizations? localizations,
    InspectLogSink? onLog,
  }) async => _fakeInspect(url, settings: settings, localizations: localizations, onLog: onLog);

  @override
  Future<void> pause(String taskId) async {}

  @override
  Future<void> resume(String taskId) async {}

  @override
  Future<void> startDownload({
    required String taskId,
    required Uri url,
    required ResourceVariant variant,
    required DownloadSettings settings,
    DownloadTaskChanged? onTaskChanged,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsController settingsController;
  late PostProcessController postProcessController;
  late DownloadController downloadController;

  DownloadSettings defaultSettings() {
    return DownloadSettings.defaults.copyWith(
      saveDirectory: '/tmp/auto-clip-gui-test',
      downloadMode: DownloadMode.serial,
      concurrentCount: 1,
      defaultQuality: 'best',
      downloadSubtitles: false,
      downloadThumbnail: false,
      disclaimerAccepted: true,
      ytDlpPath: '/home/hiext/.local/bin/yt-dlp',
      ffmpegPath: '/usr/bin/ffmpeg',
      autoClipConfig: AutoClipConfig.defaults.copyWith(enabled: true),
    );
  }

  Future<void> pumpLargeViewport(WidgetTester tester, Widget app) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  setUp(() async {
    initTestSqlite();
    final db = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    await createMediaLibraryTestSchema(db);

    final settings = defaultSettings();
    Directory(settings.saveDirectory).createSync(recursive: true);

    settingsController = SettingsController(settings: settings);

    final scheduler = DownloadScheduler(settingsProvider: () => settingsController.settings);

    postProcessController = PostProcessController(
      executor: AiClipAnalyzerExecutor(),
      settingsProvider: () => settingsController.settings,
      repository: PostProcessRepository(),
    );

    downloadController = DownloadController(
      scheduler: scheduler,
      executor: FakeYtDlpExecutor(),
      settingsProvider: () => settingsController.settings,
      postProcessController: postProcessController,
    );

    inspectedUrls.clear();
  });

  // ── Test 1: URL input and inspect ──
  testWidgets('type URL and trigger inspect', (tester) async {
    await pumpLargeViewport(
      tester,
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomePage(
          controller: downloadController,
          onShowDownloads: () {},
        ),
      ),
    );

    // 找到 TextField 并输入 URL
    final urlField = find.byType(TextField);
    expect(urlField, findsOneWidget);
    await tester.enterText(urlField, 'https://www.bilibili.com/video/BV1ogVZ6ZEJk/');
    await tester.pump();
    expect(find.text('https://www.bilibili.com/video/BV1ogVZ6ZEJk/'), findsOneWidget);

    // 点解析按钮 — 文本是 "Parse Link"
    final inspectBtn = find.widgetWithText(FilledButton, 'Parse Link');
    expect(inspectBtn, findsOneWidget);
    await tester.tap(inspectBtn);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(inspectedUrls, isNotEmpty);
    expect(inspectedUrls.first, contains('bilibili.com'));
  });

  // ── Test 2: Settings tool path configuration ──
  testWidgets('configure yt-dlp and ffmpeg paths in settings', (tester) async {
    await pumpLargeViewport(
      tester,
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SettingsPage(controller: settingsController)),
      ),
    );

    // yt-dlp
    final ytField = find.byKey(const Key('yt-dlp-path-field'));
    await tester.ensureVisible(ytField);
    await tester.pumpAndSettle();
    await tester.enterText(ytField, '/home/hiext/.local/bin/yt-dlp');
    await tester.pump();
    expect(settingsController.settings.ytDlpPath, '/home/hiext/.local/bin/yt-dlp');

    // ffmpeg
    final ffField = find.byKey(const Key('ffmpeg-path-field'));
    await tester.ensureVisible(ffField);
    await tester.pumpAndSettle();
    await tester.enterText(ffField, '/usr/bin/ffmpeg');
    await tester.pump();
    expect(settingsController.settings.ffmpegPath, '/usr/bin/ffmpeg');
  });

  // ── Test 3: Personal Cloud fields ──
  testWidgets('fill Personal Cloud configuration fields', (tester) async {
    await pumpLargeViewport(
      tester,
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SettingsPage(controller: settingsController)),
      ),
    );

    final urlField = find.byKey(const Key('personal-cloud-url-field'));
    await tester.ensureVisible(urlField);
    await tester.pumpAndSettle();
    await tester.enterText(urlField, 'http://127.0.0.1:8731');
    await tester.pump();

    final deviceField = find.byKey(const Key('personal-cloud-device-field'));
    await tester.enterText(deviceField, 'gui-test');
    await tester.pump();

    expect(find.text('http://127.0.0.1:8731'), findsOneWidget);
    expect(find.text('gui-test'), findsOneWidget);
  });

  // ── Test 4: Clips page renders ──
  testWidgets('clips page renders with empty state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ClipLibraryPage(controller: postProcessController)),
    ));
    // 用 pump 而非 pumpAndSettle 避免 _loadMediaAssets 永不 settle
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ClipLibraryPage), findsOneWidget);
  });

  // ── Test 5: Full flow ──
  testWidgets('complete flow: inspect URL then view clips', (tester) async {
    await pumpLargeViewport(
      tester,
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomePage(
          controller: downloadController,
          onShowDownloads: () {},
        ),
      ),
    );

    // Enter URL
    await tester.enterText(find.byType(TextField), 'https://test.video/test.mp4');
    await tester.pump();

    // Click inspect
    await tester.tap(find.widgetWithText(FilledButton, 'Parse Link'));
    await tester.pump(const Duration(seconds: 1));

    expect(inspectedUrls.length, greaterThanOrEqualTo(1));

    // Navigate to clips
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ClipLibraryPage(controller: postProcessController)),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ClipLibraryPage), findsOneWidget);
  });
}
