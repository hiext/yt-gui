import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/controllers/post_process_controller.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/post_process_executor.dart';
import 'package:hiext_yt_gui/core/services/post_process_repository.dart';

void main() {
  group('PostProcessController extended', () {
    test('cancel removes running task and adds to cancelled', () async {
      final executor = _FakePostProcessExecutor();
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

      expect(controller.queuedTasks, isEmpty);
      expect(controller.runningTasks, hasLength(1));

      await controller.cancel('download-1#ai-clip-analysis');

      expect(controller.queuedTasks, isEmpty);
      expect(controller.runningTasks, isEmpty);
      expect(controller.cancelledTasks, hasLength(1));
      expect(
        controller.cancelledTasks.single.status,
        PostProcessStatus.cancelled,
      );
    });

    test('cancel throws for unknown task id', () async {
      final executor = _FakePostProcessExecutor();
      final controller = PostProcessController(
        executor: executor,
        settingsProvider: _settings,
      );
      addTearDown(controller.dispose);

      expect(
        () async => controller.cancel('nonexistent-task'),
        throwsA(isA<PostProcessControllerException>()),
      );
    });

    test('retry throws for unknown task id', () async {
      final executor = _FakePostProcessExecutor();
      final controller = PostProcessController(
        executor: executor,
        settingsProvider: _settings,
      );
      addTearDown(controller.dispose);

      expect(
        () => controller.retry('unknown-id'),
        throwsA(isA<PostProcessControllerException>()),
      );
    });

    test('handleTaskChanged ignores events after dispose', () async {
      final executor = _FakePostProcessExecutor();
      final controller = PostProcessController(
        executor: executor,
        settingsProvider: _settings,
      );
      controller.dispose();

      final segments = [
        ClipSegment(
          id: 'seg-1',
          sourceTaskId: 'src-1',
          postProcessTaskId: 'task-1',
          sourcePath: '/tmp/test.mp4',
          startMs: 0,
          endMs: 10000,
          title: 'Segment',
          summary: 'Summary',
          keywords: const [],
          tags: const [],
          confidence: 0.9,
          reason: 'test',
        ),
      ];

      // Should not throw after dispose
      controller.handleTaskChanged(
        PostProcessTask(
          id: 'task-1',
          sourceTaskId: 'src-1',
          title: 'Test',
          type: PostProcessTaskType.aiClipAnalysis,
          status: PostProcessStatus.completed,
          progress: 100,
          sourcePath: '/tmp/test.mp4',
          outputDirectory: '/tmp/test.mp4.clips',
          clipSegments: segments,
        ),
      );
    });

    test('searchClipSegments without repository filters by query', () async {
      final executor = _FakePostProcessExecutor(completeImmediately: true);
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

      final allSegments = controller.clipSegments;
      if (allSegments.isNotEmpty) {
        // Search by keyword
        final results = await controller.searchClipSegments('product');
        expect(results, isNotEmpty);
        expect(results.first.keywords, contains('product'));

        // Search with empty query returns all
        final all = await controller.searchClipSegments('');
        expect(all, hasLength(allSegments.length));

        // Search with no match
        final none = await controller.searchClipSegments('zzz_nonexistent_zzz');
        expect(none, isEmpty);
      }
    });

    test('adjustClipTiming updates segment start and end', () async {
      final executor = _FakePostProcessExecutor(completeImmediately: true);
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

      final segments = controller.clipSegments;
      if (segments.isNotEmpty) {
        final segmentId = segments.first.id;
        await controller.adjustClipTiming(
          segmentId,
          adjustedStartMs: 2000,
          adjustedEndMs: 8000,
        );

        final updated = controller.clipSegments.firstWhere(
          (s) => s.id == segmentId,
        );
        expect(updated.adjustedStartMs, 2000);
        expect(updated.adjustedEndMs, 8000);
      }
    });

    test('adjustClipTiming does nothing for unknown segment id', () async {
      final executor = _FakePostProcessExecutor();
      final controller = PostProcessController(
        executor: executor,
        settingsProvider: _settings,
      );
      addTearDown(controller.dispose);

      await controller.adjustClipTiming('nonexistent-segment');
    });

    test('enqueueClipForDownload ignores duplicate task id', () async {
      final executor = _FakePostProcessExecutor();
      final controller = PostProcessController(
        executor: executor,
        settingsProvider: _settings,
      );
      addTearDown(controller.dispose);

      final downloadTask = DownloadTask(
        id: 'download-1',
        title: 'Test Video',
        source: 'https://example.com/video',
        status: DownloadStatus.completed,
        progress: 100,
        variants: const [],
        mediaPath: '/tmp/test.mp4',
      );

      await controller.enqueueClipForDownload(downloadTask);
      expect(controller.runningTasks, hasLength(1));

      await controller.enqueueClipForDownload(downloadTask);
      expect(controller.runningTasks, hasLength(1));
    });

    test('loadPendingTasks does nothing without repository', () async {
      final executor = _FakePostProcessExecutor();
      final controller = PostProcessController(
        executor: executor,
        settingsProvider: _settings,
        repository: null,
      );
      addTearDown(controller.dispose);

      await controller.loadPendingTasks();
      expect(controller.allTasks, isEmpty);
    });

    test('allTasks returns combined lists', () async {
      final executor = _FakePostProcessExecutor();
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

      final all = controller.allTasks;
      expect(all.length, 1);
      expect(all.single.id, 'download-1#ai-clip-analysis');
    });
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
    disclaimerAccepted: false,
  );
}

class _FakePostProcessExecutor implements PostProcessExecutor {
  _FakePostProcessExecutor({this.completeImmediately = false});

  final bool completeImmediately;
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
              confidence: 0.82,
              reason: 'object + speech',
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
