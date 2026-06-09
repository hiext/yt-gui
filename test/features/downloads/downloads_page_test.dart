import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/controllers/download_controller.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/download_scheduler.dart';
import 'package:hiext_yt_gui/core/services/yt_dlp_executor.dart';
import 'package:hiext_yt_gui/features/downloads/downloads_page.dart';
import 'package:hiext_yt_gui/l10n/app_localizations.dart';

void main() {
  testWidgets('shows pause and resume actions for download tasks', (
    tester,
  ) async {
    final executor = _FakeExecutor();
    final controller = DownloadController(
      scheduler: DownloadScheduler(settingsProvider: _settings),
      executor: executor,
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);

    await controller.queueDownload(
      url: Uri.parse('https://example.com/video'),
      variant: const ResourceVariant(
        label: '1080p 视频',
        description: 'mp4',
        isRecommended: true,
        formatId: '137',
        type: ResourceType.video,
      ),
    );

    await tester.pumpWidget(_buildApp(DownloadsPage(controller: controller)));
    await tester.pump();

    expect(find.textContaining('example.com'), findsWidgets);
    expect(find.textContaining('视频'), findsWidgets);
    expect(find.byIcon(Icons.pause_outlined), findsOneWidget);
    expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause_outlined));
    await tester.pumpAndSettle();

    expect(executor.paused, ['https://example.com/video#1']);
    expect(find.byIcon(Icons.play_arrow_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow_outlined));
    await tester.pump();

    expect(executor.started, [
      'https://example.com/video#1',
      'https://example.com/video#1',
    ]);
  });

  testWidgets('renders localized download labels in english locale', (
    tester,
  ) async {
    final executor = _FakeExecutor();
    final scheduler = DownloadScheduler(settingsProvider: _settings)
      ..restoreHistory([
        DownloadTask(
          id: 'history-1',
          title: 'Example Video',
          source: 'https://example.com/video',
          status: DownloadStatus.completed,
          progress: 100,
          variants: [
            ResourceVariant(
              label: '1080p',
              description: 'mp4',
              isRecommended: true,
              formatId: '137',
              type: ResourceType.video,
            ),
          ],
        ),
      ]);
    final controller = DownloadController(
      scheduler: scheduler,
      executor: executor,
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _buildApp(
        DownloadsPage(controller: controller),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(DownloadsPage)),
    )!;

    expect(find.text(l10n.downloading), findsOneWidget);
    expect(find.textContaining(l10n.completedTasks), findsOneWidget);
    expect(find.text(l10n.expandCompleted), findsOneWidget);
  });

  testWidgets('shows indeterminate progress before first download percent', (
    tester,
  ) async {
    final executor = _FakeExecutor();
    final controller = DownloadController(
      scheduler: DownloadScheduler(settingsProvider: _settings),
      executor: executor,
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);

    await controller.queueDownload(
      url: Uri.parse('https://www.youtube.com/watch?v=NCtc5lIV7pM'),
      variant: const ResourceVariant(
        label: '最佳品质（1080p 视频+音频合并）',
        description: 'mp4',
        isRecommended: true,
        formatId: '399+251',
        type: ResourceType.video,
      ),
    );

    await tester.pumpWidget(_buildApp(DownloadsPage(controller: controller)));
    await tester.pump();

    final indicators = tester.widgetList<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicators.any((indicator) => indicator.value == null), isTrue);
  });

  testWidgets('updates visible progress after download callback', (
    tester,
  ) async {
    final executor = _FakeExecutor();
    final controller = DownloadController(
      scheduler: DownloadScheduler(settingsProvider: _settings),
      executor: executor,
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);

    await controller.queueDownload(
      url: Uri.parse('https://www.youtube.com/watch?v=NCtc5lIV7pM'),
      variant: const ResourceVariant(
        label: '最佳品质（1080p 视频+音频合并）',
        description: 'mp4',
        isRecommended: true,
        formatId: '399+251',
        type: ResourceType.video,
      ),
    );

    await tester.pumpWidget(_buildApp(DownloadsPage(controller: controller)));
    await tester.pump();

    executor.emitProgress(
      'https://www.youtube.com/watch?v=NCtc5lIV7pM#1',
      7.5,
      speed: '1.2MiB/s',
      eta: '00:10',
    );
    await tester.pump();

    expect(find.text('7.5%'), findsOneWidget);
    expect(find.text('1.2MiB/s'), findsOneWidget);
    final indicators = tester.widgetList<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(
      indicators
          .where((indicator) => indicator.value != null)
          .map((indicator) => indicator.value!),
      contains(closeTo(0.075, 0.001)),
    );
  });

  testWidgets('group progress ignores queued tasks once a task is running', (
    tester,
  ) async {
    final executor = _FakeExecutor();
    final controller = DownloadController(
      scheduler: DownloadScheduler(settingsProvider: _settings),
      executor: executor,
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);
    final url = Uri.parse('https://www.youtube.com/watch?v=NCtc5lIV7pM');

    await controller.queueDownloads(
      url: url,
      variants: const [
        ResourceVariant(
          label: '最佳品质（1080p 视频+音频合并）',
          description: 'mp4',
          isRecommended: true,
          formatId: '399+251',
          type: ResourceType.video,
        ),
        ResourceVariant(
          label: '推荐品质（720p 视频+音频合并）',
          description: 'mp4',
          isRecommended: true,
          formatId: '398+bestaudio/best',
          type: ResourceType.video,
        ),
      ],
    );

    await tester.pumpWidget(_buildApp(DownloadsPage(controller: controller)));
    await tester.pump();

    executor.emitProgress('${url.toString()}#1', 40);
    await tester.pump();

    expect(find.text('40%'), findsWidgets);
    expect(
      find.text('20%'),
      findsNothing,
      reason: 'Queued tasks should not halve the visible group progress.',
    );
  });

  testWidgets('excludes cancelled tasks from group progress', (tester) async {
    final executor = _FakeExecutor();
    final scheduler = DownloadScheduler(settingsProvider: _settings)
      ..restoreHistory([
        _historyTask(
          id: 'completed-video',
          status: DownloadStatus.completed,
          progress: 100,
        ),
        _historyTask(
          id: 'completed-audio',
          status: DownloadStatus.completed,
          progress: 100,
          type: ResourceType.audio,
        ),
        _historyTask(id: 'cancelled-video', status: DownloadStatus.cancelled),
        _historyTask(
          id: 'cancelled-audio',
          status: DownloadStatus.cancelled,
          type: ResourceType.audio,
        ),
      ]);
    final controller = DownloadController(
      scheduler: scheduler,
      executor: executor,
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_buildApp(DownloadsPage(controller: controller)));
    await tester.pumpAndSettle();

    expect(find.text('50%'), findsNothing);
    expect(find.text('✓'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
  });

  testWidgets('deletes cancelled task from downloads page', (tester) async {
    final executor = _FakeExecutor();
    final scheduler = DownloadScheduler(settingsProvider: _settings)
      ..restoreHistory([
        _historyTask(id: 'cancelled-video', status: DownloadStatus.cancelled),
      ]);
    final controller = DownloadController(
      scheduler: scheduler,
      executor: executor,
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_buildApp(DownloadsPage(controller: controller)));
    await tester.pumpAndSettle();

    expect(controller.cancelledTasks, hasLength(1));

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(controller.cancelledTasks, isEmpty);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });
}

Widget _buildApp(Widget child, {Locale? locale}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

DownloadSettings _settings() {
  return const DownloadSettings(
    saveDirectory: '/tmp',
    downloadMode: DownloadMode.serial,
    concurrentCount: 1,
    defaultQuality: 'best',
    downloadSubtitles: false,
    downloadThumbnail: false,
    disclaimerAccepted: false,
  );
}

DownloadTask _historyTask({
  required String id,
  required DownloadStatus status,
  double progress = 0,
  ResourceType type = ResourceType.video,
}) {
  return DownloadTask(
    id: id,
    title: 'Example Video',
    source: 'https://example.com/video',
    status: status,
    progress: progress,
    variants: [
      ResourceVariant(
        label: type == ResourceType.video ? '1080p 视频' : '音频 140',
        description: 'test',
        isRecommended: true,
        formatId: type == ResourceType.video ? '137' : '140',
        type: type,
      ),
    ],
  );
}

class _FakeExecutor implements YtDlpExecutor {
  final List<String> started = [];
  final List<String> paused = [];
  final List<String> resumed = [];
  final List<String> cancelled = [];
  final Map<String, _StartedDownload> _downloads = {};
  final Map<String, DownloadTaskChanged?> _callbacks = {};

  @override
  Future<void> cancel(String taskId) async {
    cancelled.add(taskId);
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<List<ResourceVariant>> inspect(
    Uri url, {
    DownloadSettings? settings,
    AppLocalizations? localizations,
    InspectLogSink? onLog,
  }) async => const [];

  @override
  Future<void> pause(String taskId) async {
    paused.add(taskId);
  }

  @override
  Future<void> resume(String taskId) async {
    resumed.add(taskId);
  }

  @override
  Future<void> startDownload({
    required String taskId,
    required Uri url,
    required ResourceVariant variant,
    required DownloadSettings settings,
    DownloadTaskChanged? onTaskChanged,
  }) async {
    started.add(taskId);
    _downloads[taskId] = _StartedDownload(url: url, variant: variant);
    _callbacks[taskId] = onTaskChanged;
  }

  void emitProgress(
    String taskId,
    double progress, {
    String? speed,
    String? eta,
  }) {
    final download = _downloads[taskId];
    final callback = _callbacks[taskId];
    if (download == null || callback == null) return;
    callback(
      DownloadTask(
        id: taskId,
        title: download.url.toString(),
        source: download.url.toString(),
        status: DownloadStatus.downloading,
        progress: progress,
        speed: speed,
        eta: eta,
        variants: [download.variant],
      ),
    );
  }
}

class _StartedDownload {
  const _StartedDownload({required this.url, required this.variant});

  final Uri url;
  final ResourceVariant variant;
}
