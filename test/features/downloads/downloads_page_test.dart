import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/controllers/download_controller.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/download_scheduler.dart';
import 'package:hiext_yt_gui/core/services/yt_dlp_executor.dart';
import 'package:hiext_yt_gui/features/downloads/downloads_page.dart';
import 'package:hiext_yt_gui/l10n/app_localizations.dart';

void main() {
  testWidgets('shows pause and resume actions for download tasks', (tester) async {
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

    await tester.pumpWidget(
      _buildApp(DownloadsPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('example.com'), findsWidgets);
    expect(find.textContaining('视频'), findsWidgets);
    expect(find.byIcon(Icons.pause_outlined), findsOneWidget);
    expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause_outlined));
    await tester.pumpAndSettle();

    expect(executor.paused, ['https://example.com/video#1']);
    expect(find.byIcon(Icons.play_arrow_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow_outlined));
    await tester.pumpAndSettle();

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

class _FakeExecutor implements YtDlpExecutor {
  final List<String> started = [];
  final List<String> paused = [];
  final List<String> resumed = [];
  final List<String> cancelled = [];

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
  }
}
