import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/controllers/download_controller.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/download_scheduler.dart';
import 'package:hiext_yt_gui/core/services/yt_dlp_executor.dart';
import 'package:hiext_yt_gui/features/home/home_page.dart';
import 'package:hiext_yt_gui/l10n/app_localizations.dart';

void main() {
  testWidgets('inspects link, selects variants and queues download', (tester) async {
    final executor = _FakeExecutor()
      ..inspectResult = const [
        ResourceVariant(
          label: '1080p 视频',
          description: 'mp4 · 含音轨',
          isRecommended: true,
          formatId: '137',
          type: ResourceType.video,
        ),
        ResourceVariant(
          label: '音频 140',
          description: 'm4a · AAC',
          isRecommended: false,
          formatId: '140',
          type: ResourceType.audio,
        ),
      ];
    final controller = DownloadController(
      scheduler: DownloadScheduler(settingsProvider: _settings),
      executor: executor,
      settingsProvider: _settings,
    );
    var showedDownloads = false;

    await tester.pumpWidget(
      _buildApp(
        HomePage(
          controller: controller,
          onShowDownloads: () => showedDownloads = true,
        ),
      ),
    );

    final l10n = _l10n(tester);

    await tester.enterText(find.byType(TextField), 'https://example.com/video');
    await tester.tap(find.text(l10n.parseLink));
    await tester.pumpAndSettle();

    expect(executor.inspected, [Uri.parse('https://example.com/video')]);
    expect(executor.started, isEmpty);
    expect(find.text('1080p 视频'), findsOneWidget);
    expect(find.text('音频 140'), findsOneWidget);

    // Check the audio format checkbox and submit
    await tester.scrollUntilVisible(find.text('音频 140'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('音频 140'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text(l10n.downloadSelectedCount(1)),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.downloadSelectedCount(1)));
    await tester.pumpAndSettle();

    expect(executor.startedVariants.length, 1);
    expect(executor.startedVariants.single.formatId, '140');
    expect(showedDownloads, isTrue);
  });

  testWidgets('ignores stale inspect result after input changes', (
    tester,
  ) async {
    final executor = _FakeExecutor()
      ..inspectResult = const [
        ResourceVariant(
          label: '1080p 视频',
          description: 'mp4',
          isRecommended: false,
          formatId: '137',
          type: ResourceType.video,
        ),
      ];
    final controller = DownloadController(
      scheduler: DownloadScheduler(settingsProvider: _settings),
      executor: executor,
      settingsProvider: _settings,
    );

    await tester.pumpWidget(
      _buildApp(HomePage(controller: controller, onShowDownloads: () {})),
    );

    final l10n = _l10n(tester);

    await tester.enterText(find.byType(TextField), 'https://example.com/old');
    await tester.tap(find.text(l10n.parseLink));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'https://example.com/new');
    await tester.pumpAndSettle();

    expect(find.text('1080p 视频'), findsNothing);
    expect(find.text(l10n.selectFormatHint), findsOneWidget);
  });

  testWidgets('ignores stale inspect error after input changes', (
    tester,
  ) async {
    final executor = _FakeExecutor()..inspectError = Exception('old failed');
    final controller = DownloadController(
      scheduler: DownloadScheduler(settingsProvider: _settings),
      executor: executor,
      settingsProvider: _settings,
    );

    await tester.pumpWidget(
      _buildApp(HomePage(controller: controller, onShowDownloads: () {})),
    );

    final l10n = _l10n(tester);

    await tester.enterText(find.byType(TextField), 'https://example.com/old');
    await tester.tap(find.text(l10n.parseLink));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'https://example.com/new');
    await tester.pumpAndSettle();

    expect(find.textContaining('old failed'), findsNothing);
    expect(find.text(l10n.parseLink), findsOneWidget);
  });

  testWidgets('shows inspect error without queueing download', (tester) async {
    final executor = _FakeExecutor()..inspectError = Exception('parse failed');
    final controller = DownloadController(
      scheduler: DownloadScheduler(settingsProvider: _settings),
      executor: executor,
      settingsProvider: _settings,
    );

    await tester.pumpWidget(
      _buildApp(HomePage(controller: controller, onShowDownloads: () {})),
    );

    final l10n = _l10n(tester);

    await tester.enterText(find.byType(TextField), 'https://example.com/video');
    await tester.tap(find.text(l10n.parseLink));
    await tester.pumpAndSettle();

    expect(
      find.text(l10n.parseFailed('Exception: parse failed')),
      findsOneWidget,
    );
    expect(executor.started, isEmpty);
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

AppLocalizations _l10n(WidgetTester tester) {
  return AppLocalizations.of(tester.element(find.byType(TextField).first))!;
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
  final List<Uri> inspected = [];
  final List<String> started = [];
  final List<ResourceVariant> startedVariants = [];
  List<ResourceVariant> inspectResult = const [];
  Object? inspectError;

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
    await Future<void>.delayed(Duration.zero);
    inspected.add(url);
    final error = inspectError;
    if (error != null) {
      throw error;
    }
    return inspectResult;
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
    startedVariants.add(variant);
  }
}
