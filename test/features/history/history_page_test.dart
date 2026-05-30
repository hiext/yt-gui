import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/controllers/download_controller.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/download_scheduler.dart';
import 'package:hiext_yt_gui/core/services/yt_dlp_executor.dart';
import 'package:hiext_yt_gui/features/history/history_page.dart';

void main() {
  testWidgets('shows completed failed and cancelled tasks', (tester) async {
    final controller = _controller();
    _seedTerminalTasks(controller.scheduler);

    await tester.pumpWidget(
      MaterialApp(home: HistoryPage(controller: controller)),
    );

    expect(find.textContaining('已完成任务'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('失败任务'),
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('失败任务'), findsOneWidget);
    expect(find.text('Completed task'), findsOneWidget);
    expect(find.text('Failed task'), findsOneWidget);
    expect(find.textContaining('network timeout'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.textContaining('已取消任务'),
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('已取消任务'), findsOneWidget);
    expect(find.text('Cancelled task'), findsOneWidget);
  });

  testWidgets('retries failed task from history', (tester) async {
    final executor = _FakeExecutor();
    final controller = _controller(executor: executor);
    _seedTerminalTasks(controller.scheduler);

    await tester.pumpWidget(
      MaterialApp(home: HistoryPage(controller: controller)),
    );

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(controller.failedTasks, isEmpty);
    expect(controller.runningTasks.single.id, 'failed');
    expect(executor.started, ['failed']);
  });
}

DownloadController _controller({_FakeExecutor? executor}) {
  return DownloadController(
    scheduler: DownloadScheduler(settingsProvider: _settings),
    executor: executor ?? _FakeExecutor(),
    settingsProvider: _settings,
  );
}

void _seedTerminalTasks(DownloadScheduler scheduler) {
  scheduler.enqueueAll([
    _task('completed', 'Completed task'),
    _task('failed', 'Failed task'),
    _task('cancelled', 'Cancelled task'),
  ]);
  scheduler.startNext();
  scheduler.complete('completed');
  scheduler.startNext();
  scheduler.fail('failed', message: 'network timeout');
  scheduler.startNext();
  scheduler.cancel('cancelled');
}

DownloadTask _task(String id, String title) {
  return DownloadTask(
    id: id,
    title: title,
    source: 'https://example.com/$id',
    status: DownloadStatus.ready,
    progress: 0,
    variants: const [
      ResourceVariant(label: '推荐', description: '适合大多数人', isRecommended: true),
    ],
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
  );
}

class _FakeExecutor implements YtDlpExecutor {
  final List<String> started = [];

  @override
  Future<void> cancel(String taskId) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<List<ResourceVariant>> inspect(
    Uri url, {
    DownloadSettings? settings,
  }) async => const [];

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
  }) async {
    started.add(taskId);
  }
}
