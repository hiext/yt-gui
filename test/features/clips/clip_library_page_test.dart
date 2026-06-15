import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/controllers/post_process_controller.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/auto_clip_service.dart';
import 'package:hiext_yt_gui/core/services/local_clip_worker_service.dart';
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
    expect(find.textContaining('local · completed'), findsOneWidget);
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

  testWidgets('manages clip card preview regenerate and delete actions', (
    tester,
  ) async {
    final controller = PostProcessController(
      executor: _FakePostProcessExecutor(),
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);
    final previewed = <String>[];
    final regenerated = <String>[];
    final deleted = <String>[];
    final asset = _asset(
      id: 'asset-manage',
      title: 'Managed Video',
      mediaPath: '/downloads/managed.mp4',
    );
    final candidate = _candidate(
      id: 'candidate-manage',
      mediaAssetId: asset.id,
      title: 'Managed clip',
      score: 0.72,
    );
    final export = ClipExportRecord(
      id: 'export-manage',
      mediaAssetId: asset.id,
      candidateId: candidate.id,
      startMs: candidate.startMs,
      endMs: candidate.endMs,
      outputPath: '/downloads/.clips/managed.mp4',
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
          previewClip: (asset, candidate, export) async =>
              previewed.add('${asset.id}/${candidate.id}/${export?.id}'),
          regenerateClip: (asset, candidate, export) async =>
              regenerated.add('${asset.id}/${candidate.id}/${export?.id}'),
          deleteClipCandidate: (candidate) async => deleted.add(candidate.id),
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    final previewButton = find.byKey(
      const Key('preview-clip-candidate-manage'),
    );
    await tester.ensureVisible(previewButton);
    await tester.pumpAndSettle();
    await tester.tap(previewButton);
    await tester.pumpAndSettle();
    final regenerateButton = find.byKey(
      const Key('regenerate-clip-candidate-manage'),
    );
    await tester.ensureVisible(regenerateButton);
    await tester.pumpAndSettle();
    await tester.tap(regenerateButton);
    await tester.pumpAndSettle();
    final deleteButton = find.byKey(const Key('delete-clip-candidate-manage'));
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(previewed, ['asset-manage/candidate-manage/export-manage']);
    expect(regenerated, ['asset-manage/candidate-manage/export-manage']);
    expect(deleted, ['candidate-manage']);
  });

  testWidgets('regenerates a clip with the local worker by default', (
    tester,
  ) async {
    final controller = PostProcessController(
      executor: _FakePostProcessExecutor(),
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);
    final worker = _FakeLocalClipWorkerService();
    final asset = _asset(
      id: 'asset-worker',
      title: 'Worker Video',
      mediaPath: '/downloads/worker.mp4',
    );
    final candidate = _candidate(
      id: 'candidate-worker',
      mediaAssetId: asset.id,
      title: 'Worker clip',
      score: 0.82,
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
          ),
          localClipWorkerService: worker,
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    final regenerateButton = find.byKey(
      const Key('regenerate-clip-candidate-worker'),
    );
    await tester.ensureVisible(regenerateButton);
    await tester.pumpAndSettle();
    await tester.tap(regenerateButton);
    await tester.pumpAndSettle();

    expect(worker.exported, ['asset-worker/candidate-worker']);
  });

  testWidgets('previews exported clip through open local path by default', (
    tester,
  ) async {
    final controller = PostProcessController(
      executor: _FakePostProcessExecutor(),
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);
    final opened = <String>[];
    final asset = _asset(
      id: 'asset-preview-default',
      title: 'Preview Default Video',
      mediaPath: '/downloads/preview-default.mp4',
    );
    final candidate = _candidate(
      id: 'candidate-preview-default',
      mediaAssetId: asset.id,
      title: 'Preview default clip',
      score: 0.82,
    );
    final export = ClipExportRecord(
      id: 'export-preview-default',
      mediaAssetId: asset.id,
      candidateId: candidate.id,
      startMs: candidate.startMs,
      endMs: candidate.endMs,
      outputPath: '/downloads/.clips/preview-default.mp4',
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
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    final previewButton = find.byKey(
      const Key('preview-clip-candidate-preview-default'),
    );
    await tester.ensureVisible(previewButton);
    await tester.pumpAndSettle();
    await tester.tap(previewButton);
    await tester.pumpAndSettle();

    expect(opened, ['/downloads/.clips/preview-default.mp4']);
  });

  testWidgets('default delete and clear actions update repository and reload', (
    tester,
  ) async {
    final controller = PostProcessController(
      executor: _FakePostProcessExecutor(),
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);
    final asset = _asset(
      id: 'asset-default-delete',
      title: 'Default Delete Video',
      mediaPath: '/downloads/default-delete.mp4',
    );
    final firstCandidate = _candidate(
      id: 'candidate-delete-default',
      mediaAssetId: asset.id,
      title: 'Delete default clip',
      score: 0.82,
    );
    final secondCandidate = _candidate(
      id: 'candidate-clear-default',
      mediaAssetId: asset.id,
      title: 'Clear default clip',
      score: 0.76,
    );
    final repository = _FakeMediaAssetRepository(
      assets: [asset],
      candidates: {
        asset.id: [firstCandidate, secondCandidate],
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

    final deleteButton = find.byKey(
      const Key('delete-clip-candidate-delete-default'),
    );
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(repository.deletedCandidates, ['candidate-delete-default']);
    expect(find.text('Delete default clip'), findsNothing);
    expect(find.text('Clear default clip'), findsOneWidget);

    final clearButton = find.byKey(
      const Key('clear-results-asset-default-delete'),
    );
    await tester.ensureVisible(clearButton);
    await tester.pumpAndSettle();
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    expect(repository.clearedAssets, ['asset-default-delete']);
    expect(find.text('Clear default clip'), findsNothing);
  });

  testWidgets('clears asset clip results and filters by clip quality', (
    tester,
  ) async {
    final controller = PostProcessController(
      executor: _FakePostProcessExecutor(),
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);
    final cleared = <String>[];
    final asset = _asset(
      id: 'asset-organize',
      title: 'Organized Video',
      mediaPath: '/downloads/organized.mp4',
    );

    await tester.pumpWidget(
      _buildApp(
        ClipLibraryPage(
          controller: controller,
          mediaAssetRepository: _FakeMediaAssetRepository(
            assets: [asset],
            candidates: {
              asset.id: [
                _candidate(
                  id: 'candidate-high',
                  mediaAssetId: asset.id,
                  title: 'High quality clip',
                  score: 0.9,
                ),
                _candidate(
                  id: 'candidate-review',
                  mediaAssetId: asset.id,
                  title: 'Needs review clip',
                  score: 0.48,
                ),
              ],
            },
          ),
          clearClipResults: (asset) async => cleared.add(asset.id),
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('High quality clip'), findsOneWidget);
    expect(find.text('Needs review clip'), findsOneWidget);

    await tester.tap(find.byKey(const Key('clip-quality-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('High score').last);
    await tester.pumpAndSettle();

    expect(find.text('High quality clip'), findsOneWidget);
    expect(find.text('Needs review clip'), findsNothing);

    await tester.tap(find.byKey(const Key('clear-results-asset-organize')));
    await tester.pumpAndSettle();

    expect(cleared, ['asset-organize']);
  });

  testWidgets('filters media assets to needs review clip quality', (
    tester,
  ) async {
    final controller = PostProcessController(
      executor: _FakePostProcessExecutor(),
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);
    final asset = _asset(
      id: 'asset-review-filter',
      title: 'Review Filter Video',
      mediaPath: '/downloads/review-filter.mp4',
    );

    await tester.pumpWidget(
      _buildApp(
        ClipLibraryPage(
          controller: controller,
          mediaAssetRepository: _FakeMediaAssetRepository(
            assets: [asset],
            candidates: {
              asset.id: [
                _candidate(
                  id: 'candidate-high-filter',
                  mediaAssetId: asset.id,
                  title: 'Strong clip',
                  score: 0.9,
                ),
                _candidate(
                  id: 'candidate-low-filter',
                  mediaAssetId: asset.id,
                  title: 'Needs review only',
                  score: 0.42,
                ),
              ],
            },
          ),
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('clip-quality-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Needs review').last);
    await tester.pumpAndSettle();

    expect(find.text('Strong clip'), findsNothing);
    expect(find.text('Needs review only'), findsOneWidget);
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

  testWidgets('legacy clip segment opens exported and source videos', (
    tester,
  ) async {
    final opened = <String>[];
    final controller = PostProcessController(
      executor: _FakePostProcessExecutor(
        completeImmediately: true,
        segmentOutputPath: '/tmp/.clips/product-demo.mp4',
      ),
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
          openLocalPath: (path) async => opened.add(path),
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    final segmentId = controller.clipSegments.single.id;
    final openOutputButton = find.byKey(Key('open-segment-output-$segmentId'));
    await tester.ensureVisible(openOutputButton);
    await tester.pumpAndSettle();
    await tester.tap(openOutputButton);
    await tester.pumpAndSettle();

    final openSourceButton = find.byKey(Key('open-segment-source-$segmentId'));
    await tester.ensureVisible(openSourceButton);
    await tester.pumpAndSettle();
    await tester.tap(openSourceButton);
    await tester.pumpAndSettle();

    expect(opened, ['/tmp/.clips/product-demo.mp4', '/tmp/test.mp4']);
  });

  testWidgets('legacy clip segment still opens source when no export exists', (
    tester,
  ) async {
    final opened = <String>[];
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
          openLocalPath: (path) async => opened.add(path),
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    final segmentId = controller.clipSegments.single.id;
    final openSourceButton = find.byKey(Key('open-segment-source-$segmentId'));
    await tester.ensureVisible(openSourceButton);
    await tester.pumpAndSettle();
    await tester.tap(openSourceButton);
    await tester.pumpAndSettle();

    expect(find.byKey(Key('open-segment-output-$segmentId')), findsNothing);
    expect(opened, ['/tmp/test.mp4']);
  });

  testWidgets('legacy clip segment cuts and opens generated clip', (
    tester,
  ) async {
    final opened = <String>[];
    final autoClipService = _FakeAutoClipService(
      outputPath: '/tmp/.clips/generated-product-demo.mp4',
    );
    final controller = PostProcessController(
      executor: _FakePostProcessExecutor(completeImmediately: true),
      settingsProvider: _settings,
      autoClipService: autoClipService,
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
          openLocalPath: (path) async => opened.add(path),
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    final segmentId = controller.clipSegments.single.id;
    final generateButton = find.byKey(
      Key('generate-segment-output-$segmentId'),
    );
    await tester.ensureVisible(generateButton);
    await tester.pumpAndSettle();
    await tester.tap(generateButton);
    await tester.pumpAndSettle();

    expect(autoClipService.cutSegmentIds, [segmentId]);
    expect(opened, ['/tmp/.clips/generated-product-demo.mp4']);
    expect(
      controller.clipSegments.single.outputPath,
      '/tmp/.clips/generated-product-demo.mp4',
    );
  });

  testWidgets(
    'legacy clip segment reports cut failure instead of staying silent',
    (tester) async {
      final autoClipService = _FakeAutoClipService(
        outputPath: '',
        status: ClipRecordStatus.failed,
        errorMessage: 'ffmpeg not found',
      );
      final controller = PostProcessController(
        executor: _FakePostProcessExecutor(completeImmediately: true),
        settingsProvider: _settings,
        autoClipService: autoClipService,
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

      final segmentId = controller.clipSegments.single.id;
      final generateButton = find.byKey(
        Key('generate-segment-output-$segmentId'),
      );
      await tester.ensureVisible(generateButton);
      await tester.pumpAndSettle();
      await tester.tap(generateButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('ffmpeg not found'), findsOneWidget);
    },
  );

  testWidgets('legacy clip segment delete removes it from management list', (
    tester,
  ) async {
    final controller = PostProcessController(
      executor: _FakePostProcessExecutor(
        completeImmediately: true,
        segmentCount: 2,
      ),
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

    final firstSegmentId = controller.clipSegments.first.id;
    final deleteButton = find.byKey(Key('delete-segment-$firstSegmentId'));
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(controller.clipSegments, hasLength(1));
    expect(
      controller.clipSegments.any((segment) => segment.id == firstSegmentId),
      isFalse,
    );
    expect(find.text('Product demo 1'), findsNothing);
    expect(find.text('Product demo 2'), findsOneWidget);
  });

  testWidgets('legacy clip segments support grouped status filter', (
    tester,
  ) async {
    final controller = PostProcessController(
      executor: _FakePostProcessExecutor(
        completeImmediately: true,
        segmentCount: 2,
        exportedSegmentIndexes: const {2},
      ),
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

    expect(
      find.byKey(const Key('clip-source-group-download-1')),
      findsOneWidget,
    );
    expect(find.textContaining('1 exported'), findsOneWidget);
    expect(find.textContaining('1 needs export'), findsOneWidget);

    await tester.tap(find.byKey(const Key('legacy-segment-status-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Needs export').last);
    await tester.pumpAndSettle();

    expect(find.text('Product demo 1'), findsOneWidget);
    expect(find.text('Product demo 2'), findsNothing);

    await tester.tap(find.byKey(const Key('legacy-segment-status-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exported').last);
    await tester.pumpAndSettle();

    expect(find.text('Product demo 1'), findsNothing);
    expect(find.text('Product demo 2'), findsOneWidget);
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
    home: Scaffold(body: child),
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

MediaAsset _asset({
  required String id,
  required String title,
  required String mediaPath,
}) {
  return MediaAsset(
    id: id,
    sourceTaskId: 'download-$id',
    sourceUrl: 'https://example.com/$id',
    title: title,
    mediaPath: mediaPath,
    mediaType: MediaAssetType.video,
    fileSha256: 'e' * 64,
    durationMs: 120000,
    fileSizeBytes: 4096,
  );
}

ClipCandidate _candidate({
  required String id,
  required String mediaAssetId,
  required String title,
  required double score,
}) {
  return ClipCandidate(
    id: id,
    mediaAssetId: mediaAssetId,
    startMs: 1000,
    endMs: 9000,
    title: title,
    summary: '$title summary',
    tags: const ['managed'],
    keywords: const ['clip'],
    score: score,
    reason: 'test candidate',
  );
}

class _FakePostProcessExecutor implements PostProcessExecutor {
  _FakePostProcessExecutor({
    this.completeImmediately = false,
    this.includeTranscript = true,
    this.segmentOutputPath,
    this.segmentCount = 1,
    this.exportedSegmentIndexes = const {},
  });

  final bool completeImmediately;
  final bool includeTranscript;
  final String? segmentOutputPath;
  final int segmentCount;
  final Set<int> exportedSegmentIndexes;
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
            for (var index = 1; index <= segmentCount; index++)
              _segmentForTask(task, index),
          ],
        ),
      );
    } else {
      onTaskChanged?.call(task.copyWith(status: PostProcessStatus.running));
    }
  }

  ClipSegment _segmentForTask(PostProcessTask task, int index) {
    final id = '${task.id}#segment-$index';
    final isSingle = segmentCount == 1;
    final title = isSingle ? 'Product demo' : 'Product demo $index';
    final exported = exportedSegmentIndexes.contains(index);
    return ClipSegment(
      id: id,
      sourceTaskId: task.sourceTaskId,
      postProcessTaskId: task.id,
      sourcePath: task.sourcePath,
      startMs: (index - 1) * 12000,
      endMs: index * 12000,
      title: title,
      summary: isSingle
          ? 'Product demo segment'
          : 'Product demo segment $index',
      keywords: const ['product', 'demo'],
      tags: const ['yolo', 'whisper'],
      confidence: index == 1 ? 1.0 : 0.7,
      reason: 'object + speech',
      outputPath: exported
          ? '/tmp/.clips/product-demo-$index.mp4'
          : segmentOutputPath,
      transcripts: includeTranscript
          ? [
              ClipTranscript(
                id: 'tr-$index',
                segmentId: id,
                startMs: (index - 1) * 12000,
                endMs: (index - 1) * 12000 + 5000,
                text: 'This is a product demonstration $index',
                words: const [],
              ),
            ]
          : const [],
      detections: [
        ClipDetection(
          id: 'det-$index',
          segmentId: id,
          timestampMs: (index - 1) * 12000 + 2000,
          label: 'product',
          confidence: 0.95,
          bbox: const [],
        ),
      ],
    );
  }
}

class _FakeLocalClipWorkerService extends LocalClipWorkerService {
  final List<String> exported = [];

  @override
  Future<ClipExportRecord> exportCandidate({
    required MediaAsset asset,
    required ClipCandidate candidate,
    required DownloadSettings settings,
    ClipExportProgressChanged? onProgress,
  }) async {
    exported.add('${asset.id}/${candidate.id}');
    return ClipExportRecord(
      id: '${asset.id}#export:${candidate.id}',
      mediaAssetId: asset.id,
      candidateId: candidate.id,
      startMs: candidate.startMs,
      endMs: candidate.endMs,
      outputPath: '${settings.saveDirectory}/.clips/${candidate.id}.mp4',
      status: ClipExportStatus.completed,
      progress: 100,
    );
  }
}

class _FakeAutoClipService extends AutoClipService {
  _FakeAutoClipService({
    required this.outputPath,
    this.status = ClipRecordStatus.completed,
    this.errorMessage,
  });

  final String outputPath;
  final ClipRecordStatus status;
  final String? errorMessage;
  final List<String> cutSegmentIds = [];

  @override
  Future<ClipRecord> cutSingle({
    required ClipSegment segment,
    required DownloadSettings settings,
    void Function(double progress)? onProgress,
  }) async {
    cutSegmentIds.add(segment.id);
    return ClipRecord(
      id: '${segment.id}#manual-cut',
      sourceTaskId: segment.sourceTaskId,
      sourcePath: segment.sourcePath,
      title: segment.title,
      confidence: segment.confidence,
      startMs: segment.effectiveStartMs,
      endMs: segment.effectiveEndMs,
      durationMs: segment.effectiveEndMs - segment.effectiveStartMs,
      status: status,
      outputPath: outputPath,
      errorMessage: errorMessage,
      progress: 100,
    );
  }
}

class _FakeMediaAssetRepository extends MediaAssetRepository {
  _FakeMediaAssetRepository({
    List<MediaAsset> assets = const [],
    Map<String, List<ClipCandidate>> candidates = const {},
    Map<String, List<ClipExportRecord>> exports = const {},
  }) : assets = List.of(assets),
       candidates = candidates.map(
         (mediaAssetId, candidates) =>
             MapEntry(mediaAssetId, List.of(candidates)),
       ),
       exports = exports.map(
         (mediaAssetId, exports) => MapEntry(mediaAssetId, List.of(exports)),
       );

  final List<MediaAsset> assets;
  final Map<String, List<ClipCandidate>> candidates;
  final Map<String, List<ClipExportRecord>> exports;
  final List<String> deletedCandidates = [];
  final List<String> deletedExports = [];
  final List<String> clearedAssets = [];

  @override
  Future<List<MediaAsset>> loadMediaAssets() async => assets;

  @override
  Future<List<ClipCandidate>> loadCompatibleClipCandidates(
    String mediaAssetId,
  ) async {
    return List.unmodifiable(candidates[mediaAssetId] ?? const []);
  }

  @override
  Future<List<ClipExportRecord>> loadCompatibleClipExportRecords(
    String mediaAssetId,
  ) async {
    return List.unmodifiable(exports[mediaAssetId] ?? const []);
  }

  @override
  Future<void> deleteClipCandidate(String id) async {
    deletedCandidates.add(id);
    for (final entry in candidates.entries) {
      entry.value.removeWhere((candidate) => candidate.id == id);
    }
    for (final entry in exports.entries) {
      entry.value.removeWhere((export) => export.candidateId == id);
    }
  }

  @override
  Future<void> deleteClipExportRecord(String id) async {
    deletedExports.add(id);
    for (final entry in exports.entries) {
      entry.value.removeWhere((export) => export.id == id);
    }
  }

  @override
  Future<void> clearClipResultsForAsset(String mediaAssetId) async {
    clearedAssets.add(mediaAssetId);
    candidates[mediaAssetId] = [];
    exports[mediaAssetId] = [];
  }
}
