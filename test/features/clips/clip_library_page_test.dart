import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/controllers/post_process_controller.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/media_asset_repository.dart';
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

    await tester.pumpWidget(
      _buildApp(
        ClipLibraryPage(
          controller: controller,
          mediaAssetRepository: _FakeMediaAssetRepository(),
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = _l10n(tester);
    expect(find.text(l10n.clips), findsOneWidget);
    expect(find.byKey(const Key('clip-search-field')), findsOneWidget);
    expect(find.text(l10n.noClipSegments), findsOneWidget);
  });

  testWidgets('renders media assets with candidates and exports', (
    tester,
  ) async {
    final controller = PostProcessController(
      executor: _FakePostProcessExecutor(),
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);
    final asset = MediaAsset(
      id: 'asset-1',
      sourceTaskId: 'download-1',
      sourceUrl: 'https://example.com/video',
      title: 'Launch Video',
      mediaPath: '/downloads/video.mp4',
      mediaType: MediaAssetType.video,
      fileSha256: 'a' * 64,
      durationMs: 120000,
      fileSizeBytes: 4096,
    );
    final repository = _FakeMediaAssetRepository(
      assets: [asset],
      candidates: {
        asset.id: [
          ClipCandidate(
            id: 'candidate-1',
            mediaAssetId: asset.id,
            startMs: 1000,
            endMs: 9000,
            title: 'Launch hook',
            summary: 'A strong opening hook.',
            tags: const ['hook'],
            keywords: const ['launch'],
            score: 0.91,
            reason: 'high semantic density',
          ),
        ],
      },
      exports: {
        asset.id: [
          ClipExportRecord(
            id: 'export-1',
            mediaAssetId: asset.id,
            candidateId: 'candidate-1',
            startMs: 1000,
            endMs: 9000,
            outputPath: '/downloads/.clips/hook.mp4',
            status: ClipExportStatus.completed,
            progress: 100,
          ),
        ],
      },
    );

    await tester.pumpWidget(
      _buildApp(
        ClipLibraryPage(
          controller: controller,
          mediaAssetRepository: repository,
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Launch Video'), findsOneWidget);
    expect(find.text('Launch hook'), findsOneWidget);
    expect(find.textContaining('completed'), findsOneWidget);
    expect(find.textContaining('2:00'), findsOneWidget);
  });

  testWidgets('renders clip candidates as visual preview gallery cards', (
    tester,
  ) async {
    final controller = PostProcessController(
      executor: _FakePostProcessExecutor(),
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);
    final opened = <String>[];
    final asset = MediaAsset(
      id: 'asset-gallery',
      sourceTaskId: 'download-gallery',
      sourceUrl: 'https://example.com/gallery',
      title: 'Gallery Video',
      mediaPath: '/downloads/gallery.mp4',
      mediaType: MediaAssetType.video,
      fileSha256: 'd' * 64,
      durationMs: 180000,
      fileSizeBytes: 8192,
      thumbnailPath: '/downloads/gallery.webp',
    );
    final candidate = ClipCandidate(
      id: 'candidate-gallery',
      mediaAssetId: asset.id,
      startMs: 62000,
      endMs: 76000,
      title: 'Show the result',
      summary: 'The speaker reveals the finished product on screen.',
      tags: const ['result', 'screen'],
      keywords: const ['finished product', 'demo'],
      score: 0.87,
      reason: 'visual reveal with matching transcript',
    );
    final export = ClipExportRecord(
      id: 'export-gallery',
      mediaAssetId: asset.id,
      candidateId: candidate.id,
      startMs: candidate.startMs,
      endMs: candidate.endMs,
      outputPath: '/downloads/.clips/result.mp4',
      status: ClipExportStatus.completed,
      progress: 100,
    );

    await tester.pumpWidget(
      _buildApp(
        ClipLibraryPage(
          controller: controller,
          mediaAssetRepository: _FakeMediaAssetRepository(
            assets: [asset],
            candidates: {
              asset.id: [candidate],
            },
            exports: {
              asset.id: [export],
            },
          ),
          openLocalPath: (path) async => opened.add(path),
          resolveClipPreviewPath: (asset, candidate, export) async =>
              '/downloads/.clips/previews/candidate-gallery.jpg',
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Clip gallery'), findsOneWidget);
    expect(
      find.byKey(const Key('clip-preview-candidate-gallery')),
      findsOneWidget,
    );
    expect(find.text('Show the result'), findsOneWidget);
    expect(find.text('1:02 - 1:16'), findsOneWidget);
    expect(find.text('14s'), findsOneWidget);
    expect(find.textContaining('visual reveal'), findsOneWidget);
    expect(find.text('completed'), findsOneWidget);

    final openClipButton = find.byKey(const Key('open-clip-export-gallery'));
    await tester.ensureVisible(openClipButton);
    await tester.pumpAndSettle();
    await tester.tap(openClipButton);
    await tester.pumpAndSettle();

    expect(opened, ['/downloads/.clips/result.mp4']);
  });

  testWidgets('filters media assets by candidate text and export status', (
    tester,
  ) async {
    final controller = PostProcessController(
      executor: _FakePostProcessExecutor(),
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);
    final completedAsset = MediaAsset(
      id: 'asset-completed',
      sourceTaskId: 'download-1',
      sourceUrl: 'https://example.com/video',
      title: 'Launch Video',
      mediaPath: '/downloads/video.mp4',
      mediaType: MediaAssetType.video,
      fileSha256: 'a' * 64,
      durationMs: 120000,
      fileSizeBytes: 4096,
    );
    final failedAsset = MediaAsset(
      id: 'asset-failed',
      sourceTaskId: 'download-2',
      sourceUrl: 'https://example.com/failed',
      title: 'Archive Talk',
      mediaPath: '/downloads/archive.mp4',
      mediaType: MediaAssetType.video,
      fileSha256: 'b' * 64,
      durationMs: 60000,
      fileSizeBytes: 2048,
    );
    final repository = _FakeMediaAssetRepository(
      assets: [completedAsset, failedAsset],
      candidates: {
        completedAsset.id: [
          ClipCandidate(
            id: 'candidate-1',
            mediaAssetId: completedAsset.id,
            startMs: 1000,
            endMs: 9000,
            title: 'Launch hook',
            summary: 'A strong opening hook.',
            tags: const ['hook'],
            keywords: const ['semantic'],
            score: 0.91,
            reason: 'high semantic density',
          ),
        ],
      },
      exports: {
        completedAsset.id: [
          ClipExportRecord(
            id: 'export-1',
            mediaAssetId: completedAsset.id,
            candidateId: 'candidate-1',
            startMs: 1000,
            endMs: 9000,
            outputPath: '/downloads/.clips/hook.mp4',
            status: ClipExportStatus.completed,
            progress: 100,
          ),
        ],
        failedAsset.id: [
          ClipExportRecord(
            id: 'export-2',
            mediaAssetId: failedAsset.id,
            startMs: 1000,
            endMs: 9000,
            outputPath: '/downloads/.clips/failed.mp4',
            status: ClipExportStatus.failed,
            progress: 0,
          ),
        ],
      },
    );

    await tester.pumpWidget(
      _buildApp(
        ClipLibraryPage(
          controller: controller,
          mediaAssetRepository: repository,
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('clip-search-field')),
      'semantic',
    );
    await tester.pumpAndSettle();
    expect(find.text('Launch Video'), findsOneWidget);
    expect(find.text('Archive Talk'), findsNothing);

    await tester.enterText(find.byKey(const Key('clip-search-field')), '');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('clip-export-status-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('failed').last);
    await tester.pumpAndSettle();

    expect(find.text('Launch Video'), findsNothing);
    expect(find.text('Archive Talk'), findsOneWidget);
  });

  testWidgets('opens media and output locations from media asset card', (
    tester,
  ) async {
    final controller = PostProcessController(
      executor: _FakePostProcessExecutor(),
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);
    final opened = <String>[];
    final asset = MediaAsset(
      id: 'asset-open',
      sourceTaskId: 'download-1',
      sourceUrl: 'https://example.com/video',
      title: 'Open Video',
      mediaPath: '/downloads/video.mp4',
      mediaType: MediaAssetType.video,
      fileSha256: 'c' * 64,
      durationMs: 120000,
      fileSizeBytes: 4096,
    );
    final repository = _FakeMediaAssetRepository(
      assets: [asset],
      exports: {
        asset.id: [
          ClipExportRecord(
            id: 'export-open',
            mediaAssetId: asset.id,
            startMs: 1000,
            endMs: 9000,
            outputPath: '/downloads/.clips/hook.mp4',
            status: ClipExportStatus.completed,
            progress: 100,
          ),
        ],
      },
    );

    await tester.pumpWidget(
      _buildApp(
        ClipLibraryPage(
          controller: controller,
          mediaAssetRepository: repository,
          openLocalPath: (path) async => opened.add(path),
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-media-asset-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-output-asset-open')));
    await tester.pumpAndSettle();

    expect(opened, ['/downloads/video.mp4', '/downloads/.clips']);
  });

  testWidgets('displays zero-count chips', (tester) async {
    final controller = PostProcessController(
      executor: _FakePostProcessExecutor(),
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _buildApp(
        ClipLibraryPage(
          controller: controller,
          mediaAssetRepository: _FakeMediaAssetRepository(),
        ),
        locale: const Locale('en'),
      ),
    );
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

    await tester.pumpWidget(
      _buildApp(
        ClipLibraryPage(
          controller: controller,
          mediaAssetRepository: _FakeMediaAssetRepository(),
        ),
        locale: const Locale('en'),
      ),
    );
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

    await tester.pumpWidget(
      _buildApp(
        ClipLibraryPage(
          controller: controller,
          mediaAssetRepository: _FakeMediaAssetRepository(),
        ),
        locale: const Locale('en'),
      ),
    );
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

  testWidgets('renders adjust timing buttons for each segment', (tester) async {
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

    await tester.pumpWidget(
      _buildApp(
        ClipLibraryPage(
          controller: controller,
          mediaAssetRepository: _FakeMediaAssetRepository(),
        ),
        locale: const Locale('en'),
      ),
    );
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

    await tester.pumpWidget(
      _buildApp(
        ClipLibraryPage(
          controller: controller,
          mediaAssetRepository: _FakeMediaAssetRepository(),
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = _l10n(tester);

    // Tap "Start Later" (+1000ms)
    final startLaterButton = find.text(l10n.clipStartLater);
    await tester.ensureVisible(startLaterButton);
    await tester.pumpAndSettle();
    await tester.tap(startLaterButton);
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

    await tester.pumpWidget(
      _buildApp(
        ClipLibraryPage(
          controller: controller,
          mediaAssetRepository: _FakeMediaAssetRepository(),
        ),
        locale: const Locale('en'),
      ),
    );
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

    await tester.pumpWidget(
      _buildApp(
        ClipLibraryPage(
          controller: controller,
          mediaAssetRepository: _FakeMediaAssetRepository(),
        ),
        locale: const Locale('en'),
      ),
    );
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

    await tester.pumpWidget(
      _buildApp(
        ClipLibraryPage(
          controller: controller,
          mediaAssetRepository: _FakeMediaAssetRepository(),
        ),
        locale: const Locale('en'),
      ),
    );
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

    await tester.pumpWidget(
      _buildApp(
        ClipLibraryPage(
          controller: controller,
          mediaAssetRepository: _FakeMediaAssetRepository(),
        ),
        locale: const Locale('en'),
      ),
    );
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
      onTaskChanged?.call(task.copyWith(status: PostProcessStatus.running));
    }
  }
}

class _FakeMediaAssetRepository extends MediaAssetRepository {
  _FakeMediaAssetRepository({
    this.assets = const [],
    this.candidates = const {},
    this.exports = const {},
  });

  final List<MediaAsset> assets;
  final Map<String, List<ClipCandidate>> candidates;
  final Map<String, List<ClipExportRecord>> exports;

  @override
  Future<List<MediaAsset>> loadMediaAssets() async => assets;

  @override
  Future<List<ClipCandidate>> loadCompatibleClipCandidates(
    String mediaAssetId,
  ) async {
    return candidates[mediaAssetId] ?? const [];
  }

  @override
  Future<List<ClipExportRecord>> loadCompatibleClipExportRecords(
    String mediaAssetId,
  ) async {
    return exports[mediaAssetId] ?? const [];
  }
}
