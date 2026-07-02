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
import '../sqlite_test_setup.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
          'CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL, source TEXT NOT NULL, status TEXT NOT NULL, progress REAL NOT NULL DEFAULT 0, data TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE cookie_configs (id INTEGER PRIMARY KEY AUTOINCREMENT, domain TEXT NOT NULL UNIQUE, data TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE post_process_tasks (id TEXT PRIMARY KEY, source_task_id TEXT NOT NULL, type TEXT NOT NULL, status TEXT NOT NULL, progress REAL NOT NULL DEFAULT 0, data TEXT NOT NULL)',
        );
        await createClipAnalysisTestSchema(db);
        await createMediaLibraryTestSchema(db);
      },
    ),
  );
  DatabaseService().useTestDatabase(db);
}

void main() {
  setUp(() async {
    await _setupTestDb();
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
      ),
    );
    await tester.pump();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(TextField).first),
    )!;

    // Phase 1: Verify home page shows
    expect(find.text(l10n.newDownload), findsWidgets);
    expect(find.text(l10n.selectFormatHint), findsOneWidget);

    // Phase 2: Enter URL and parse
    await tester.enterText(find.byType(TextField), 'https://example.com/video');
    await tester.pump();
    await tester.tap(find.text(l10n.parseLink));
    await tester.pump();

    // Phase 3: Verify formats appear
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('1080p 视频'), findsOneWidget);
    expect(executor.inspected, isNotEmpty);

    // Phase 4: Select format and download
    await tester.tap(find.text('1080p 视频'));
    await tester.pump();
    final dlBtn = find.text(l10n.downloadSelectedCount(1));
    await tester.scrollUntilVisible(
      dlBtn,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(dlBtn);
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
    expect(find.text(l10n.saveAndQuality), findsOneWidget);

    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pump();
    expect(find.text(l10n.help), findsWidgets);
  });

  testWidgets('settings modifications persist', (tester) async {
    final settingsController = SettingsController();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh'), Locale('en')],
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
  Future<List<ResourceVariant>> inspect(
    Uri url, {
    DownloadSettings? settings,
    AppLocalizations? localizations,
    InspectLogSink? onLog,
  }) async {
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
    onTaskChanged?.call(
      DownloadTask(
        id: taskId,
        title: 'example.com/video',
        source: 'https://example.com/video',
        status: DownloadStatus.downloading,
        progress: 50,
        variants: const [],
        speed: '1.2MiB/s',
        eta: '00:10',
      ),
    );
  }
}
