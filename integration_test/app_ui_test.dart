import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/app/app_shell.dart';
import 'package:hiext_yt_gui/core/controllers/download_controller.dart';
import 'package:hiext_yt_gui/core/controllers/settings_controller.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/download_scheduler.dart';
import 'package:hiext_yt_gui/core/services/yt_dlp_executor.dart';
import 'package:hiext_yt_gui/core/services/database_service.dart';
import 'package:hiext_yt_gui/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../test/sqlite_test_setup.dart';

Future<void> _setupTestDb() async {
  initTestSqlite();
  final db = await databaseFactoryFfiNoIsolate.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL, '
          'source TEXT NOT NULL, status TEXT NOT NULL, progress REAL NOT NULL '
          'DEFAULT 0, data TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE cookie_configs (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'domain TEXT NOT NULL UNIQUE, data TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE post_process_tasks (id TEXT PRIMARY KEY, '
          'source_task_id TEXT NOT NULL, type TEXT NOT NULL, status TEXT NOT NULL, '
          'progress REAL NOT NULL DEFAULT 0, data TEXT NOT NULL)',
        );
        await createClipAnalysisTestSchema(db);
      },
    ),
  );
  DatabaseService().useTestDatabase(db);
}

Widget _buildTestApp({
  SettingsController? settingsController,
  DownloadController? downloadController,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: const [Locale('zh'), Locale('en')],
    home: AppShell(
      settingsController: settingsController,
      downloadController: downloadController,
    ),
  );
}

void main() {
  setUp(() async {
    await _setupTestDb();
  });

  group('App 启动和导航', () {
    testWidgets('应用启动后显示首页和导航栏', (tester) async {
      final settingsController = SettingsController(
        settings: DownloadSettings.defaults.copyWith(
          disclaimerAccepted: true,
        ),
      );
      await tester.pumpWidget(_buildTestApp(
        settingsController: settingsController,
      ));
      await tester.pump();

      // 首页关键元素验证（通过 TextField 获取 l10n）
      final l10n = AppLocalizations.of(
        tester.element(find.byType(TextField).first),
      )!;

      // NavigationRail 标签 + SectionCard 标题都包含 "新建下载"
      expect(find.text(l10n.newDownload), findsAtLeastNWidgets(1));
      expect(find.text(l10n.downloading), findsOneWidget);
      expect(find.text(l10n.history), findsOneWidget);
      expect(find.text(l10n.settings), findsOneWidget);
      expect(find.text(l10n.help), findsOneWidget);
      expect(find.text(l10n.selectFormatHint), findsOneWidget);
    });

    testWidgets('导航栏切换全部6个页面', (tester) async {
      final settingsController = SettingsController(
        settings: DownloadSettings.defaults.copyWith(
          disclaimerAccepted: true,
        ),
      );
      await tester.pumpWidget(_buildTestApp(
        settingsController: settingsController,
      ));
      await tester.pump();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(TextField).first),
      )!;

      // 首页
      expect(find.text(l10n.selectFormatHint), findsOneWidget);

      // 切换到下载页
      await tester.tap(find.text(l10n.downloading));
      await tester.pump();
      expect(find.text(l10n.noDownloadTasks), findsOneWidget);

      // 切换到剪辑库
      await tester.tap(find.text(l10n.clips));
      await tester.pump();

      // 切换到历史页
      await tester.tap(find.text(l10n.history));
      await tester.pump();

      // 切换到设置页
      await tester.tap(find.text(l10n.settings));
      await tester.pump();
      expect(find.text(l10n.saveAndQuality), findsOneWidget);

      // 切换到帮助页
      await tester.tap(find.text(l10n.help));
      await tester.pump();
      expect(find.text(l10n.help), findsWidgets);

      // 回到首页
      await tester.tap(find.text(l10n.newDownload));
      await tester.pump();
      expect(find.text(l10n.selectFormatHint), findsOneWidget);
    });
  });

  group('首页 - 解析和下载流程', () {
    testWidgets('输入链接并点击解析触发 executor.inspect', (tester) async {
      final executor = _RecordingExecutor();
      final settingsController = SettingsController(
        settings: DownloadSettings.defaults.copyWith(
          disclaimerAccepted: true,
        ),
      );
      final downloadController = DownloadController(
        scheduler: DownloadScheduler(
          settingsProvider: () => settingsController.settings,
        ),
        executor: executor,
        settingsProvider: () => settingsController.settings,
      );

      await tester.pumpWidget(_buildTestApp(
        settingsController: settingsController,
        downloadController: downloadController,
      ));
      await tester.pump();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(TextField).first),
      )!;

      final urlField = find.byType(TextField);
      await tester.enterText(urlField, 'https://www.youtube.com/watch?v=test123');
      await tester.pump();

      await tester.tap(find.text(l10n.parseLink));
      await tester.pump();

      expect(executor.inspectedUrls, isNotEmpty);
      expect(
        executor.inspectedUrls.first.toString(),
        contains('youtube.com/watch?v=test123'),
      );
    });

    testWidgets('选择格式并触发下载任务', (tester) async {
      final executor = _RecordingExecutor();
      final settingsController = SettingsController(
        settings: DownloadSettings.defaults.copyWith(
          disclaimerAccepted: true,
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

      await tester.pumpWidget(_buildTestApp(
        settingsController: settingsController,
        downloadController: downloadController,
      ));
      await tester.pump();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(TextField).first),
      )!;

      await tester.enterText(
        find.byType(TextField),
        'https://example.com/video',
      );
      await tester.tap(find.text(l10n.parseLink));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 选择格式
      expect(find.text('1080p 视频'), findsOneWidget);
      await tester.tap(find.text('1080p 视频'));
      await tester.pump();

      // 点击下载
      final dlBtn = find.text(l10n.downloadSelectedCount(1));
      await tester.scrollUntilVisible(dlBtn, 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pump();
      await tester.tap(dlBtn);
      await tester.pump();

      expect(executor.startedTaskIds, isNotEmpty);
    });
  });

  group('设置页 - 配置修改', () {
    testWidgets('修改保存目录和yt-dlp路径', (tester) async {
      final settingsController = SettingsController(
        settings: DownloadSettings.defaults.copyWith(
          disclaimerAccepted: true,
        ),
      );

      await tester.pumpWidget(_buildTestApp(
        settingsController: settingsController,
      ));
      await tester.pump();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(TextField).first),
      )!;

      await tester.tap(find.text(l10n.settings));
      await tester.pump();

      // 修改保存目录
      final saveField = find.byKey(const Key('save-directory-field'));
      await tester.enterText(saveField, '/home/user/videos');
      await tester.pump();
      expect(settingsController.settings.saveDirectory, '/home/user/videos');

      // 修改 yt-dlp 路径
      final ytField = find.byKey(const Key('yt-dlp-path-field'));
      await tester.ensureVisible(ytField);
      await tester.pump();
      await tester.enterText(ytField, '/tools/yt-dlp');
      await tester.pump();
      expect(settingsController.settings.ytDlpPath, '/tools/yt-dlp');
    });
  });

  group('免责声明弹窗', () {
    testWidgets('未接受免责声明时显示弹窗并可接受', (tester) async {
      final settingsController = SettingsController(
        settings: DownloadSettings.defaults.copyWith(
          disclaimerAccepted: false,
        ),
      );

      await tester.pumpWidget(_buildTestApp(
        settingsController: settingsController,
      ));
      // 从页面组件获取 l10n
      final l10n = AppLocalizations.of(
        tester.element(find.byType(NavigationRail).first),
      )!;

      // AppShell.initState 中 addListener 不会主动触发回调，
      // 需通过 updateSettings 触发 notifyListeners 来唤起免责声明弹窗
      settingsController.updateSettings(settingsController.settings);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 确认弹窗显示
      expect(find.text(l10n.disclaimerTitle), findsOneWidget);
      expect(find.text(l10n.disclaimerAcknowledge), findsOneWidget);

      // 点击接受
      await tester.tap(find.text(l10n.disclaimerAcknowledge));
      await tester.pumpAndSettle();

      // 弹窗关闭
      expect(find.text(l10n.disclaimerTitle), findsNothing);
      expect(settingsController.settings.disclaimerAccepted, isTrue);
    });
  });
}

/// 记录所有方法调用的假 executor，用于验证 UI 交互
class _RecordingExecutor implements YtDlpExecutor {
  final List<Uri> inspectedUrls = [];
  final List<String> startedTaskIds = [];

  @override
  Future<List<ResourceVariant>> inspect(
    Uri url, {
    DownloadSettings? settings,
    AppLocalizations? localizations,
    InspectLogSink? onLog,
  }) async {
    inspectedUrls.add(url);
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
  Future<void> startDownload({
    required String taskId,
    required Uri url,
    required ResourceVariant variant,
    required DownloadSettings settings,
    DownloadTaskChanged? onTaskChanged,
  }) async {
    startedTaskIds.add(taskId);
    onTaskChanged?.call(
      DownloadTask(
        id: taskId,
        title: url.toString(),
        source: url.toString(),
        status: DownloadStatus.downloading,
        progress: 50,
        variants: [variant],
        speed: '1.2MiB/s',
        eta: '00:10',
      ),
    );
  }

  @override
  Future<void> pause(String taskId) async {}

  @override
  Future<void> resume(String taskId) async {}

  @override
  Future<void> cancel(String taskId) async {}

  @override
  Future<void> dispose() async {}
}
