import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/controllers/download_controller.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/download_scheduler.dart';
import 'package:hiext_yt_gui/core/services/yt_dlp_executor.dart';
import 'package:hiext_yt_gui/features/downloads/downloads_page.dart';

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

    await controller.queueDownload(
      url: Uri.parse('https://example.com/video'),
      variant: const ResourceVariant(
        label: '推荐',
        description: '适合大多数人',
        isRecommended: true,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: DownloadsPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂停'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);

    await tester.tap(find.text('暂停'));
    await tester.pumpAndSettle();

    expect(executor.paused, ['https://example.com/video#1']);
    expect(find.text('恢复'), findsOneWidget);

    await tester.tap(find.text('恢复'));
    await tester.pumpAndSettle();

    expect(executor.started, [
      'https://example.com/video#1',
      'https://example.com/video#1',
    ]);
  });
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
  Future<List<ResourceVariant>> inspect(Uri url) async => const [];

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
