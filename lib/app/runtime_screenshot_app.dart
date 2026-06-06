import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../core/controllers/download_controller.dart';
import '../core/controllers/settings_controller.dart';
import '../core/models/app_models.dart';
import '../core/services/download_scheduler.dart';
import '../core/services/yt_dlp_executor.dart';
import '../features/downloads/downloads_page.dart';
import '../features/help/help_page.dart';
import '../features/history/history_page.dart';
import '../features/home/home_page.dart';
import '../features/settings/settings_page.dart';
import '../l10n/app_localizations.dart';
import '../shared/widgets/section_card.dart';
import 'app_shell.dart';

class RuntimeScreenshotApp extends StatelessWidget {
  const RuntimeScreenshotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hiext YT GUI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _RuntimeScreenshotFlow(),
    );
  }
}

class _RuntimeScreenshotFlow extends StatefulWidget {
  const _RuntimeScreenshotFlow();

  @override
  State<_RuntimeScreenshotFlow> createState() => _RuntimeScreenshotFlowState();
}

class _RuntimeScreenshotFlowState extends State<_RuntimeScreenshotFlow> {
  final GlobalKey _boundaryKey = GlobalKey();
  late final SettingsController _settingsController;
  late final DownloadController _downloadController;
  late final Directory _outputDir;

  int _scenarioIndex = 0;
  bool _capturing = false;

  final List<_ScreenshotScenario> _scenarios = const [
    _ScreenshotScenario(name: 'real-home', section: AppSection.home),
    _ScreenshotScenario(name: 'real-downloads', section: AppSection.downloads),
    _ScreenshotScenario(name: 'real-settings', section: AppSection.settings),
  ];

  @override
  void initState() {
    super.initState();
    final settings = _sampleSettings();
    _settingsController = SettingsController(settings: settings);
    _downloadController = _createDownloadController(settings);
    _outputDir = Directory('${Directory.current.path}/runtime-screenshots');
    unawaited(_outputDir.create(recursive: true));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_captureAllScenarios());
    });
  }

  @override
  void dispose() {
    _downloadController.dispose();
    _settingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scenario = _scenarios[_scenarioIndex];
    return RepaintBoundary(
      key: _boundaryKey,
      child: _ScreenshotShell(
        section: scenario.section,
        settingsController: _settingsController,
        downloadController: _downloadController,
      ),
    );
  }

  Future<void> _captureAllScenarios() async {
    if (_capturing) return;
    _capturing = true;

    for (var i = 0; i < _scenarios.length; i++) {
      setState(() => _scenarioIndex = i);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await _captureCurrentScenario(_scenarios[i].name);
    }

    await Future<void>.delayed(const Duration(milliseconds: 300));
    exit(0);
  }

  Future<void> _captureCurrentScenario(String name) async {
    final context = _boundaryKey.currentContext;
    if (context == null) return;

    final boundary = context.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 1.5);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    final bytes = byteData.buffer.asUint8List();
    final file = File('${_outputDir.path}/$name.png');
    await file.writeAsBytes(bytes, flush: true);
  }
}

class _ScreenshotShell extends StatelessWidget {
  const _ScreenshotShell({
    required this.section,
    required this.settingsController,
    required this.downloadController,
  });

  final AppSection section;
  final SettingsController settingsController;
  final DownloadController downloadController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pages = <Widget>[
      HomePage(controller: downloadController, onShowDownloads: () {}),
      DownloadsPage(controller: downloadController),
      HistoryPage(controller: downloadController),
      SettingsPage(controller: settingsController),
      const HelpPage(),
    ];

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: section.index,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SectionCard(
                  title: l10n.appTitle,
                  subtitle: l10n.appSubtitle,
                  child: const SizedBox(height: 1),
                ),
              ),
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.add_link_outlined),
                  selectedIcon: const Icon(Icons.add_link),
                  label: Text(l10n.newDownload),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.downloading_outlined),
                  selectedIcon: const Icon(Icons.downloading),
                  label: Text(l10n.downloading),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.history_outlined),
                  selectedIcon: const Icon(Icons.history),
                  label: Text(l10n.history),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: Text(l10n.settings),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.help_outline),
                  selectedIcon: const Icon(Icons.help),
                  label: Text(l10n.help),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: IndexedStack(index: section.index, children: pages)),
          ],
        ),
      ),
    );
  }
}

class _ScreenshotScenario {
  const _ScreenshotScenario({required this.name, required this.section});

  final String name;
  final AppSection section;
}

DownloadSettings _sampleSettings() {
  return DownloadSettings(
    saveDirectory: '/home/hiext/Videos/Hiext YT GUI',
    downloadMode: DownloadMode.concurrent,
    concurrentCount: 3,
    defaultQuality: 'bestvideo+bestaudio',
    downloadSubtitles: true,
    downloadThumbnail: true,
    ytDlpPath: '/usr/local/bin/yt-dlp',
    ffmpegPath: '/usr/local/bin/ffmpeg',
    cookieConfigs: [
      CookieConfig(
        domain: 'youtube.com',
        browser: 'chrome',
        cookieFile: '/home/hiext/Videos/.cookies/youtube.com_chrome.txt',
        importedAt: DateTime(2026, 6, 6, 10, 0),
      ),
      CookieConfig(
        domain: 'bilibili.com',
        browser: 'edge',
        cookieFile: '/home/hiext/Videos/.cookies/bilibili.com_edge.txt',
        importedAt: DateTime(2026, 6, 6, 9, 30),
      ),
    ],
    defaultCookieBrowser: 'chrome',
  );
}

DownloadController _createDownloadController(DownloadSettings settings) {
  final scheduler = DownloadScheduler(settingsProvider: () => settings);
  scheduler.enqueueAll([
    DownloadTask(
      id: 'task-1',
      title: '演示视频：首发版本界面预览',
      source: 'https://www.bilibili.com/video/BV1demo001',
      status: DownloadStatus.ready,
      progress: 0,
      variants: const [
        ResourceVariant(
          label: '1080p 高清',
          description: 'mp4 · 含音轨',
          isRecommended: true,
          formatId: '137',
          type: ResourceType.video,
        ),
      ],
    ),
    DownloadTask(
      id: 'task-2',
      title: '演示视频：首发版本界面预览',
      source: 'https://www.bilibili.com/video/BV1demo001',
      status: DownloadStatus.ready,
      progress: 0,
      variants: const [
        ResourceVariant(
          label: '720p 标清',
          description: 'mp4 · 通用兼容',
          isRecommended: false,
          formatId: '136',
          type: ResourceType.video,
        ),
      ],
    ),
    DownloadTask(
      id: 'task-3',
      title: '演示视频：首发版本界面预览',
      source: 'https://www.bilibili.com/video/BV1demo001',
      status: DownloadStatus.ready,
      progress: 0,
      variants: const [
        ResourceVariant(
          label: '音频 128kbps',
          description: 'm4a · AAC',
          isRecommended: false,
          formatId: '140',
          type: ResourceType.audio,
        ),
      ],
    ),
  ]);
  scheduler.startNext();
  scheduler.updateTask(
    DownloadTask(
      id: 'task-1',
      title: '演示视频：首发版本界面预览',
      source: 'https://www.bilibili.com/video/BV1demo001',
      status: DownloadStatus.downloading,
      progress: 65,
      speed: '1.2 MiB/s',
      eta: '00:18',
      variants: const [
        ResourceVariant(
          label: '1080p 高清',
          description: 'mp4 · 含音轨',
          isRecommended: true,
          formatId: '137',
          type: ResourceType.video,
        ),
      ],
    ),
  );
  scheduler.pause('task-2');
  scheduler.updateTask(
    DownloadTask(
      id: 'task-2',
      title: '演示视频：首发版本界面预览',
      source: 'https://www.bilibili.com/video/BV1demo001',
      status: DownloadStatus.paused,
      progress: 42,
      variants: const [
        ResourceVariant(
          label: '720p 标清',
          description: 'mp4 · 通用兼容',
          isRecommended: false,
          formatId: '136',
          type: ResourceType.video,
        ),
      ],
    ),
  );
  scheduler.complete('task-3');

  return DownloadController(
    scheduler: scheduler,
    executor: _NoopExecutor(),
    settingsProvider: () => settings,
  );
}

class _NoopExecutor implements YtDlpExecutor {
  @override
  Future<void> cancel(String taskId) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<List<ResourceVariant>> inspect(
    Uri url, {
    DownloadSettings? settings,
    AppLocalizations? localizations,
  }) async {
    return const [];
  }

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
