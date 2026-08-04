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
import 'sqlite_test_setup.dart';

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
        await createMediaLibraryTestSchema(db);
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

/// 获取 l10n — 使用 TextField 作为 context 锚点 (与现有测试保持一致)
AppLocalizations _l10n(WidgetTester tester) {
  return AppLocalizations.of(tester.element(find.byType(TextField).first))!;
}

void main() {
  setUp(() async {
    await _setupTestDb();
  });

  // ── 导航测试 ────────────────────────────────────────

  group('导航系统', () {
    testWidgets('启动后显示全部6个导航项', (tester) async {
      final sc = SettingsController(
        settings: DownloadSettings.defaults.copyWith(disclaimerAccepted: true),
      );
      await tester.pumpWidget(_buildTestApp(settingsController: sc));
      await tester.pump();

      expect(find.text(_l10n(tester).newDownload), findsAtLeastNWidgets(1));
      expect(find.text(_l10n(tester).downloading), findsOneWidget);
      expect(find.text(_l10n(tester).history), findsOneWidget);
      expect(find.text(_l10n(tester).settings), findsOneWidget);
      expect(find.text(_l10n(tester).help), findsOneWidget);
    });

    testWidgets('切换全部页面', (tester) async {
      final sc = SettingsController(
        settings: DownloadSettings.defaults.copyWith(disclaimerAccepted: true),
      );
      await tester.pumpWidget(_buildTestApp(settingsController: sc));
      await tester.pump();
      final l10n = _l10n(tester);

      // 首页 → 下载 → 剪辑 → 历史 → 设置 → 帮助 → 首页
      expect(find.text(l10n.selectFormatHint), findsOneWidget);

      await tester.tap(find.text(l10n.downloading));
      await tester.pump();
      expect(find.text(l10n.noDownloadTasks), findsOneWidget);

      await tester.tap(find.text(l10n.clips));
      await tester.pump();

      await tester.tap(find.text(l10n.history));
      await tester.pump();

      await tester.tap(find.text(l10n.settings));
      await tester.pump();
      expect(find.text(l10n.saveAndQuality), findsOneWidget);

      await tester.tap(find.text(l10n.help));
      await tester.pump();
      expect(find.text(l10n.help), findsWidgets);

      await tester.tap(find.text(l10n.newDownload));
      await tester.pump();
      expect(find.text(l10n.selectFormatHint), findsOneWidget);
    });
  });

  // ── 解析和下载流程 ─────────────────────────────────

  group('解析和下载', () {
    testWidgets('输入链接并解析', (tester) async {
      final executor = _RecordingExecutor();
      final sc = SettingsController(
        settings: DownloadSettings.defaults.copyWith(disclaimerAccepted: true),
      );
      final dc = DownloadController(
        scheduler: DownloadScheduler(settingsProvider: () => sc.settings),
        executor: executor,
        settingsProvider: () => sc.settings,
      );

      await tester.pumpWidget(
        _buildTestApp(settingsController: sc, downloadController: dc),
      );
      await tester.pump();
      final l10n = _l10n(tester);

      await tester.enterText(
        find.byType(TextField),
        'https://www.youtube.com/watch?v=test123',
      );
      await tester.tap(find.text(l10n.parseLink));
      await tester.pump();

      expect(executor.inspectedUrls, isNotEmpty);
      expect(
        executor.inspectedUrls.first.toString(),
        contains('youtube.com/watch?v=test123'),
      );
    });

    testWidgets('解析后选择格式并下载', (tester) async {
      final executor = _RecordingExecutor();
      final sc = SettingsController(
        settings: DownloadSettings.defaults.copyWith(
          disclaimerAccepted: true,
          saveDirectory: '/tmp/test-downloads',
        ),
      );
      final dc = DownloadController(
        scheduler: DownloadScheduler(settingsProvider: () => sc.settings),
        executor: executor,
        settingsProvider: () => sc.settings,
      );

      await tester.pumpWidget(
        _buildTestApp(settingsController: sc, downloadController: dc),
      );
      await tester.pump();
      final l10n = _l10n(tester);

      await tester.enterText(
        find.byType(TextField),
        'https://example.com/video',
      );
      await tester.tap(find.text(l10n.parseLink));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('1080p 视频'), findsOneWidget);
      await tester.tap(find.text('1080p 视频'));
      await tester.pump();

      final dlBtn = find.text(l10n.downloadSelectedCount(1));
      await tester.scrollUntilVisible(
        dlBtn,
        300,
        scrollable: find
            .descendant(
              of: find.byType(IndexedStack),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pump();
      await tester.tap(dlBtn);
      await tester.pump();

      expect(executor.startedTaskIds, isNotEmpty);
    });
  });

  // ── 设置页 ─────────────────────────────────────────

  group('设置页', () {
    testWidgets('修改保存目录路径', (tester) async {
      final sc = SettingsController(
        settings: DownloadSettings.defaults.copyWith(disclaimerAccepted: true),
      );

      await tester.pumpWidget(_buildTestApp(settingsController: sc));
      await tester.pump();
      final l10n = _l10n(tester);

      await tester.tap(find.text(l10n.settings));
      await tester.pump();

      final saveField = find.byKey(const Key('save-directory-field'));
      await tester.enterText(saveField, '/home/user/videos');
      await tester.pump();

      expect(sc.settings.saveDirectory, '/home/user/videos');
    });

    testWidgets('修改自定义yt-dlp路径', (tester) async {
      final sc = SettingsController(
        settings: DownloadSettings.defaults.copyWith(disclaimerAccepted: true),
      );

      await tester.pumpWidget(_buildTestApp(settingsController: sc));
      await tester.pump();
      final l10n = _l10n(tester);

      await tester.tap(find.text(l10n.settings));
      await tester.pump();

      final ytField = find.byKey(const Key('yt-dlp-path-field'));
      await tester.ensureVisible(ytField);
      await tester.pump();
      await tester.enterText(ytField, '/tools/yt-dlp');
      await tester.pump();

      expect(sc.settings.ytDlpPath, '/tools/yt-dlp');
    });
  });

  // ── 免责声明弹窗 ───────────────────────────────────

  group('免责声明', () {
    testWidgets('未接受时显示弹窗，接受后关闭', (tester) async {
      final sc = SettingsController(
        settings: DownloadSettings.defaults.copyWith(disclaimerAccepted: false),
      );

      await tester.pumpWidget(_buildTestApp(settingsController: sc));
      await tester.pump();
      final l10n = _l10n(tester);

      // 触发 settings 变更通知以唤起免责声明检查
      sc.updateSettings(sc.settings);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(l10n.disclaimerTitle), findsOneWidget);
      expect(find.text(l10n.disclaimerAcknowledge), findsOneWidget);

      await tester.tap(find.text(l10n.disclaimerAcknowledge));
      await tester.pumpAndSettle();

      expect(find.text(l10n.disclaimerTitle), findsNothing);
      expect(sc.settings.disclaimerAccepted, isTrue);
    });
  });
}

// ── 测试辅助类 ─────────────────────────────────────

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
