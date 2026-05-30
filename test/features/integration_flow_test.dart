import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/app/app_shell.dart';
import 'package:hiext_yt_gui/core/controllers/download_controller.dart';
import 'package:hiext_yt_gui/core/controllers/settings_controller.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/download_scheduler.dart';
import 'package:hiext_yt_gui/core/services/yt_dlp_executor.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('full user flow', (tester) async {
    final executor = _ImmediateFake();
    final settingsController = SettingsController(
      settings: DownloadSettings.defaults.copyWith(
        saveDirectory: '/tmp/test-downloads',
      ),
    );
    final downloadController = DownloadController(
      scheduler: DownloadScheduler(
        settingsProvider: () => settingsController.settings,
      ),
      executor: executor,
      settingsProvider: () => settingsController.settings,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          settingsController: settingsController,
          downloadController: downloadController,
        ),
      ),
    );
    await tester.pump();

    // Phase 1: Verify home page shows
    expect(find.text('新建下载'), findsWidgets);
    expect(find.text('请先粘贴链接并解析可下载格式。'), findsOneWidget);

    // Phase 2: Enter URL and parse
    await tester.enterText(find.byType(TextField), 'https://example.com/video');
    await tester.pump();
    await tester.tap(find.text('解析链接'));
    await tester.pump();

    // Phase 3: Verify formats appear
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('1080p 视频'), findsOneWidget);
    expect(executor.inspected, isNotEmpty);

    // Phase 4: Select format and download
    await tester.tap(find.text('1080p 视频'));
    await tester.pump();
    await tester.ensureVisible(find.textContaining('下载所选'));
    await tester.pump();
    await tester.tap(find.textContaining('下载所选'));
    await tester.pump();

    // Phase 5: Verify download started and navigated to downloads
    expect(executor.started, isNotEmpty);
    await tester.pump();
    expect(find.textContaining('example.com'), findsWidgets);

    // Phase 6: Navigate sections
    await tester.tap(find.byIcon(Icons.history_outlined));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump();
    expect(find.text('保存与画质'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pump();
    expect(find.text('帮助'), findsWidgets);
  });

  testWidgets('settings modifications persist', (tester) async {
    final settingsController = SettingsController();

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(settingsController: settingsController),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump();

    final saveField = find.byKey(const Key('save-directory-field'));
    await tester.enterText(saveField, '/home/user/videos');
    await tester.pump();

    final ytField = find.byKey(const Key('yt-dlp-path-field'));
    await tester.ensureVisible(ytField);
    await tester.pump();
    await tester.enterText(ytField, '/tools/yt-dlp');
    await tester.pump();

    expect(settingsController.settings.saveDirectory, '/home/user/videos');
    expect(settingsController.settings.ytDlpPath, '/tools/yt-dlp');
  });
}

class _ImmediateFake implements YtDlpExecutor {
  final List<Uri> inspected = [];
  final List<String> started = [];

  @override
  Future<void> cancel(String taskId) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<List<ResourceVariant>> inspect(Uri url, {DownloadSettings? settings}) async {
    inspected.add(url);
    return const [
      ResourceVariant(
        label: '1080p 视频',
        description: 'mp4 · 含音轨',
        isRecommended: true,
        formatId: '137',
        type: ResourceType.video,
      ),
    ];
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
  }) async {
    started.add(taskId);
    onTaskChanged?.call(DownloadTask(
      id: taskId,
      title: 'example.com/video',
      source: 'https://example.com/video',
      status: DownloadStatus.downloading,
      progress: 50,
      variants: const [],
      speed: '1.2MiB/s',
      eta: '00:10',
    ));
  }
}
