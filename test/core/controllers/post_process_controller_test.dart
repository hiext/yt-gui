import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/controllers/post_process_controller.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/post_process_executor.dart';

void main() {
  test(
    'queues ai clip analysis task for completed download with media path',
    () async {
      final executor = _FakePostProcessExecutor();
      final controller = PostProcessController(
        executor: executor,
        settingsProvider: _settings,
      );
      addTearDown(controller.dispose);

      await controller.enqueueClipForDownload(
        DownloadTask(
          id: 'download-1',
          title: 'Example Video',
          source: 'https://example.com/video',
          status: DownloadStatus.completed,
          progress: 100,
          variants: const [],
          mediaPath: '/downloads/example.mp4',
        ),
      );

      expect(executor.started, ['download-1#ai-clip-analysis']);
      expect(
        controller.runningTasks.single.type,
        PostProcessTaskType.aiClipAnalysis,
      );
      expect(
        controller.runningTasks.single.sourcePath,
        '/downloads/example.mp4',
      );
    },
  );

  test('ignores download without media path', () async {
    final executor = _FakePostProcessExecutor();
    final controller = PostProcessController(
      executor: executor,
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);

    await controller.enqueueClipForDownload(
      DownloadTask(
        id: 'download-1',
        title: 'Example Video',
        source: 'https://example.com/video',
        status: DownloadStatus.completed,
        progress: 100,
        variants: const [],
      ),
    );

    expect(executor.started, isEmpty);
    expect(controller.allTasks, isEmpty);
  });

  test('moves task to completed when executor reports success', () async {
    final executor = _FakePostProcessExecutor(completeImmediately: true);
    final controller = PostProcessController(
      executor: executor,
      settingsProvider: _settings,
    );
    addTearDown(controller.dispose);

    await controller.enqueueClipForDownload(
      DownloadTask(
        id: 'download-1',
        title: 'Example Video',
        source: 'https://example.com/video',
        status: DownloadStatus.completed,
        progress: 100,
        variants: const [],
        mediaPath: '/downloads/example.mp4',
      ),
    );

    expect(controller.runningTasks, isEmpty);
    expect(controller.completedTasks.single.clipSegments.single.keywords, [
      'product',
      'demo',
    ]);
    expect(controller.clipSegments.single.summary, 'Product demo segment');
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
    }
  }
}
