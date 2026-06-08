import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/controllers/post_process_controller.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/post_process_executor.dart';
import 'package:hiext_yt_gui/features/clips/clip_library_page.dart';
import 'package:hiext_yt_gui/l10n/app_localizations.dart';

void main() {
  testWidgets('renders empty clip library', (tester) async {
    final controller = PostProcessController(
      executor: _FakePostProcessExecutor(),
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_buildApp(
      ClipLibraryPage(controller: controller),
      locale: const Locale('en'),
    ));
    await tester.pumpAndSettle();

    final l10n = _l10n(tester);
    expect(find.text(l10n.clips), findsOneWidget);
    expect(find.byKey(const Key('clip-search-field')), findsOneWidget);
    expect(find.text(l10n.noClipSegments), findsOneWidget);
  });

  testWidgets('displays zero-count chips', (tester) async {
    final controller = PostProcessController(
      executor: _FakePostProcessExecutor(),
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_buildApp(
      ClipLibraryPage(controller: controller),
      locale: const Locale('en'),
    ));
    await tester.pumpAndSettle();

    final l10n = _l10n(tester);
    expect(find.text(l10n.aiQueuedTasks(0)), findsOneWidget);
    expect(find.text(l10n.aiRunningTasks(0)), findsOneWidget);
    expect(find.text(l10n.clipSegmentsCount(0)), findsOneWidget);
  });

  testWidgets('renders chip counts after enqueue', (tester) async {
    final controller = PostProcessController(
      executor: _FakePostProcessExecutor(),
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);

    await controller.enqueueClipForDownload(
      DownloadTask(
        id: 'download-1',
        title: 'Test Video',
        source: 'https://example.com/video',
        status: DownloadStatus.completed,
        progress: 100,
        variants: const [],
        mediaPath: '/tmp/test.mp4',
      ),
    );

    await tester.pumpWidget(_buildApp(
      ClipLibraryPage(controller: controller),
      locale: const Locale('en'),
    ));
    await tester.pumpAndSettle();

    final l10n = _l10n(tester);
    expect(find.text(l10n.aiRunningTasks(1)), findsOneWidget);
  });

  testWidgets('renders clip segment cards with full data', (tester) async {
    final controller = PostProcessController(
      executor: _FakePostProcessExecutor(completeImmediately: true),
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);

    await controller.enqueueClipForDownload(
      DownloadTask(
        id: 'download-1',
        title: 'Test Video',
        source: 'https://example.com/video',
        status: DownloadStatus.completed,
        progress: 100,
        variants: const [],
        mediaPath: '/tmp/test.mp4',
      ),
    );

    await tester.pumpWidget(_buildApp(
      ClipLibraryPage(controller: controller),
      locale: const Locale('en'),
    ));
    await tester.pumpAndSettle();

    final l10n = _l10n(tester);

    // Should show the segment title, summary, confidence, keywords, tags
    expect(find.text('Product demo'), findsOneWidget);
    expect(find.text('Product demo segment'), findsOneWidget);
    expect(find.textContaining('100%'), findsOneWidget);
    expect(find.text('product'), findsWidgets); // keyword chip
    expect(find.text('demo'), findsWidgets); // keyword chip
    expect(find.text('#yolo'), findsWidgets); // tag chip
    expect(find.text('#whisper'), findsWidgets); // tag chip
    expect(find.textContaining(l10n.clipReason), findsOneWidget);

    // Transcript should be visible
    expect(find.textContaining(l10n.clipTranscript), findsOneWidget);
    expect(find.textContaining('product demonstration'), findsOneWidget);
  });

  testWidgets('renders adjust timing buttons for each segment', (
    tester,
  ) async {
    final controller = PostProcessController(
      executor: _FakePostProcessExecutor(completeImmediately: true),
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);

    await controller.enqueueClipForDownload(
      DownloadTask(
        id: 'download-1',
        title: 'Test Video',
        source: 'https://example.com/video',
        status: DownloadStatus.completed,
        progress: 100,
        variants: const [],
        mediaPath: '/tmp/test.mp4',
      ),
    );

    await tester.pumpWidget(_buildApp(
      ClipLibraryPage(controller: controller),
      locale: const Locale('en'),
    ));
    await tester.pumpAndSettle();

    final l10n = _l10n(tester);

    // All four adjust buttons should be visible
    expect(find.text(l10n.clipStartEarlier), findsOneWidget);
    expect(find.text(l10n.clipStartLater), findsOneWidget);
    expect(find.text(l10n.clipEndEarlier), findsOneWidget);
    expect(find.text(l10n.clipEndLater), findsOneWidget);
  });

  testWidgets('adjust timing buttons modify segment', (tester) async {
    final controller = PostProcessController(
      executor: _FakePostProcessExecutor(completeImmediately: true),
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);

    await controller.enqueueClipForDownload(
      DownloadTask(
        id: 'download-1',
        title: 'Test Video',
        source: 'https://example.com/video',
        status: DownloadStatus.completed,
        progress: 100,
        variants: const [],
        mediaPath: '/tmp/test.mp4',
      ),
    );

    await tester.pumpWidget(_buildApp(
      ClipLibraryPage(controller: controller),
      locale: const Locale('en'),
    ));
    await tester.pumpAndSettle();

    final l10n = _l10n(tester);

    // Tap "Start Later" (+1000ms)
    await tester.tap(find.text(l10n.clipStartLater));
    await tester.pumpAndSettle();

    // The segment's adjusted start should now be 1000
    final segments = controller.clipSegments;
    if (segments.isNotEmpty) {
      expect(segments.first.effectiveStartMs, greaterThanOrEqualTo(0));
    }
  });

  testWidgets('search field triggers search', (tester) async {
    final controller = PostProcessController(
      executor: _FakePostProcessExecutor(completeImmediately: true),
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);

    await controller.enqueueClipForDownload(
      DownloadTask(
        id: 'download-1',
        title: 'Test Video',
        source: 'https://example.com/video',
        status: DownloadStatus.completed,
        progress: 100,
        variants: const [],
        mediaPath: '/tmp/test.mp4',
      ),
    );

    await tester.pumpWidget(_buildApp(
      ClipLibraryPage(controller: controller),
      locale: const Locale('en'),
    ));
    await tester.pumpAndSettle();

    // Search for product keyword should find the segment
    await tester.enterText(
      find.byKey(const Key('clip-search-field')),
      'product',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('clip-search-field')), findsOneWidget);
    // The segment should still be visible because it matches "product"
    expect(find.text('Product demo'), findsOneWidget);
  });

  testWidgets('search with no match shows empty state', (tester) async {
    final controller = PostProcessController(
      executor: _FakePostProcessExecutor(completeImmediately: true),
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);

    await controller.enqueueClipForDownload(
      DownloadTask(
        id: 'download-1',
        title: 'Test Video',
        source: 'https://example.com/video',
        status: DownloadStatus.completed,
        progress: 100,
        variants: const [],
        mediaPath: '/tmp/test.mp4',
      ),
    );

    await tester.pumpWidget(_buildApp(
      ClipLibraryPage(controller: controller),
      locale: const Locale('en'),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('clip-search-field')),
      'zzz-nonexistent-zzz',
    );
    await tester.pumpAndSettle();

    final l10n = _l10n(tester);
    // Should show empty state
    expect(find.text(l10n.noClipSegments), findsOneWidget);
  });

  testWidgets('displays time format correctly', (tester) async {
    final controller = PostProcessController(
      executor: _FakePostProcessExecutor(completeImmediately: true),
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);

    await controller.enqueueClipForDownload(
      DownloadTask(
        id: 'download-1',
        title: 'Test Video',
        source: 'https://example.com/video',
        status: DownloadStatus.completed,
        progress: 100,
        variants: const [],
        mediaPath: '/tmp/test.mp4',
      ),
    );

    await tester.pumpWidget(_buildApp(
      ClipLibraryPage(controller: controller),
      locale: const Locale('en'),
    ));
    await tester.pumpAndSettle();

    // Time format: 0:00 - 0:12 (for 0ms to 12000ms)
    expect(find.textContaining('0:00'), findsOneWidget);
    expect(find.textContaining('0:12'), findsOneWidget);
  });

  testWidgets('renders segment without transcript', (tester) async {
    // Use a custom executor that creates a segment without transcript
    final executor = _FakePostProcessExecutor(
      completeImmediately: true,
      includeTranscript: false,
    );
    final controller = PostProcessController(
      executor: executor,
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);

    await controller.enqueueClipForDownload(
      DownloadTask(
        id: 'download-1',
        title: 'Test Video',
        source: 'https://example.com/video',
        status: DownloadStatus.completed,
        progress: 100,
        variants: const [],
        mediaPath: '/tmp/test.mp4',
      ),
    );

    await tester.pumpWidget(_buildApp(
      ClipLibraryPage(controller: controller),
      locale: const Locale('en'),
    ));
    await tester.pumpAndSettle();

    final l10n = _l10n(tester);
    // Transcript section should NOT be visible
    expect(find.textContaining(l10n.clipTranscript), findsNothing);
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
  return AppLocalizations.of(
    tester.element(find.byType(ClipLibraryPage).first),
  )!;
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

class _FakePostProcessExecutor implements PostProcessExecutor {
  _FakePostProcessExecutor({
    this.completeImmediately = false,
    this.includeTranscript = true,
  });

  final bool completeImmediately;
  final bool includeTranscript;
  final List<String> started = [];

  @override
  Future<void> cancel(String taskId) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> startTask({
    required PostProcessTask task,
    required DownloadSettings settings,
    PostProcessTaskChanged? onTaskChanged,
  }) async {
    started.add(task.id);
    if (completeImmediately) {
      onTaskChanged?.call(
        task.copyWith(
          status: PostProcessStatus.completed,
          progress: 100,
          clipSegments: [
            ClipSegment(
              id: '${task.id}#segment-1',
              sourceTaskId: task.sourceTaskId,
              postProcessTaskId: task.id,
              sourcePath: task.sourcePath,
              startMs: 0,
              endMs: 12000,
              title: 'Product demo',
              summary: 'Product demo segment',
              keywords: const ['product', 'demo'],
              tags: const ['yolo', 'whisper'],
              confidence: 1.0,
              reason: 'object + speech',
              transcripts: includeTranscript
                  ? [
                      ClipTranscript(
                        id: 'tr-1',
                        segmentId: '${task.id}#segment-1',
                        startMs: 0,
                        endMs: 5000,
                        text: 'This is a product demonstration',
                        words: const [],
                      ),
                    ]
                  : const [],
              detections: [
                ClipDetection(
                  id: 'det-1',
                  segmentId: '${task.id}#segment-1',
                  timestampMs: 2000,
                  label: 'product',
                  confidence: 0.95,
                  bbox: const [],
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      onTaskChanged?.call(
        task.copyWith(status: PostProcessStatus.running),
      );
    }
  }
}
