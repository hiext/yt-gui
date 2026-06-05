import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/controllers/download_controller.dart';
import 'package:hiext_yt_gui/core/controllers/post_process_controller.dart';
import 'package:hiext_yt_gui/l10n/app_localizations.dart';
import 'package:hiext_yt_gui/l10n/app_localizations_current.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/download_scheduler.dart';
import 'package:hiext_yt_gui/core/services/post_process_executor.dart';
import 'package:hiext_yt_gui/core/services/yt_dlp_executor.dart';

class _FakeExecutor implements YtDlpExecutor {
  final List<String> started = [];
  final List<String> paused = [];
  final List<String> resumed = [];
  final List<String> cancelled = [];
  final List<Uri> inspected = [];
  List<ResourceVariant> inspectResult = const [];
  bool disposed = false;

  @override
  Future<void> cancel(String taskId) async {
    cancelled.add(taskId);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  Future<List<ResourceVariant>> inspect(
    Uri url, {
    DownloadSettings? settings,
    AppLocalizations? localizations,
  }) async {
    inspected.add(url);
    return inspectResult;
  }

  @override
  Future<void> pause(String taskId) async {
    paused.add(taskId);
  }

  @override
  Future<void> resume(String taskId) async {
    resumed.add(taskId);
  }

  @override
  Future<void> startDownload({
    required String taskId,
    required Uri url,
    required ResourceVariant variant,
    required DownloadSettings settings,
    DownloadTaskChanged? onTaskChanged,
  }) async {
    started.add(taskId);
  }
}

class _FakePostProcessExecutor implements PostProcessExecutor {
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
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'inspect returns executor variants without enqueueing download',
    () async {
      final scheduler = DownloadScheduler(settingsProvider: _settings);
      final executor = _FakeExecutor()
        ..inspectResult = const [
          ResourceVariant(
            label: '清晰版 1080p',
            description: 'mp4 格式',
            isRecommended: false,
            formatId: '137',
          ),
        ];
      final controller = DownloadController(
        scheduler: scheduler,
        executor: executor,
        settingsProvider: _settings,
      );
      final url = Uri.parse('https://example.com/video');

      final variants = await controller.inspect(url);

      expect(executor.inspected, [url]);
      expect(variants.single.formatId, '137');
      expect(controller.allTasks, isEmpty);
      expect(executor.started, isEmpty);
    },
  );

  test('queue download starts executor and updates scheduler', () async {
    final scheduler = DownloadScheduler(settingsProvider: _settings);
    final executor = _FakeExecutor();
    final controller = DownloadController(
      scheduler: scheduler,
      executor: executor,
      settingsProvider: _settings,
    );

    await controller.queueDownload(
      url: Uri.parse('https://example.com/video'),
      variant: const ResourceVariant(
        label: '推荐',
        description: '适合大多数人',
        isRecommended: true,
        formatId: 'best',
      ),
    );

    expect(executor.started, hasLength(1));
    expect(controller.runningTasks, isNotEmpty);
  });

  test('progress updates task fields', () {
    final scheduler = DownloadScheduler(settingsProvider: _settings);
    final controller = DownloadController(
      scheduler: scheduler,
      executor: _FakeExecutor(),
      settingsProvider: _settings,
    );

    scheduler.enqueue(
      DownloadTask(
        id: '1',
        title: 'Task 1',
        source: 'https://example.com',
        status: DownloadStatus.ready,
        progress: 0,
        variants: const [],
      ),
    );
    scheduler.startNext();

    controller.handleProgress(
      taskId: '1',
      progress: 52.5,
      speed: '1.2MiB/s',
      eta: '00:10',
    );

    final task = controller.runningTasks.single;
    expect(task.progress, 52.5);
    expect(task.speed, '1.2MiB/s');
    expect(task.eta, '00:10');
  });

  test('pause resume cancel and dispose forward to executor', () async {
    final scheduler = DownloadScheduler(settingsProvider: _settings);
    final executor = _FakeExecutor();
    final controller = DownloadController(
      scheduler: scheduler,
      executor: executor,
      settingsProvider: _settings,
    );

    scheduler.enqueue(
      DownloadTask(
        id: 'task-1',
        title: 'Task 1',
        source: 'https://example.com',
        status: DownloadStatus.ready,
        progress: 0,
        variants: const [
          ResourceVariant(
            label: '推荐',
            description: '适合大多数人',
            isRecommended: true,
          ),
        ],
      ),
    );
    scheduler.startNext();

    await controller.pause('task-1');
    await controller.resume('task-1');
    await controller.cancel('task-1');
    controller.dispose();

    expect(executor.paused, ['task-1']);
    expect(executor.resumed, isEmpty);
    expect(executor.cancelled, ['task-1']);
    expect(executor.disposed, isTrue);
    expect(executor.started, ['task-1']);
  });

  test('queue download generates unique task ids for same url', () async {
    final scheduler = DownloadScheduler(settingsProvider: _settings);
    final executor = _FakeExecutor();
    final controller = DownloadController(
      scheduler: scheduler,
      executor: executor,
      settingsProvider: _settings,
    );
    final url = Uri.parse('https://example.com/video');

    await controller.queueDownload(
      url: url,
      variant: const ResourceVariant(
        label: '推荐',
        description: '适合大多数人',
        isRecommended: true,
      ),
    );
    await controller.queueDownload(
      url: url,
      variant: const ResourceVariant(
        label: '推荐',
        description: '适合大多数人',
        isRecommended: true,
      ),
    );

    expect(executor.started, hasLength(1));
    expect(controller.allTasks.map((task) => task.id), hasLength(2));
    expect(controller.allTasks.map((task) => task.id).toSet(), hasLength(2));
  });

  test('failed task uses localized fallback message', () {
    final scheduler = DownloadScheduler(settingsProvider: _settings);
    final controller = DownloadController(
      scheduler: scheduler,
      executor: _FakeExecutor(),
      settingsProvider: _settings,
    );
    const source = 'https://example.com/video';

    scheduler.enqueue(
      DownloadTask(
        id: 'task-1',
        title: 'Task 1',
        source: source,
        status: DownloadStatus.ready,
        progress: 0,
        variants: [],
      ),
    );
    scheduler.startNext();

    controller.handleTaskChanged(
      DownloadTask(
        id: 'task-1',
        title: 'Task 1',
        source: source,
        status: DownloadStatus.failed,
        progress: 0,
        variants: [],
      ),
    );

    expect(
      controller.failedTasks.single.errorMessage,
      currentAppLocalizations().downloadFailedFallback,
    );
  });

  test(
    'completed download with media path queues ai clip analysis task',
    () async {
      final scheduler = DownloadScheduler(settingsProvider: _settings);
      final postExecutor = _FakePostProcessExecutor();
      final postController = PostProcessController(
        executor: postExecutor,
        settingsProvider: _settings,
      );
      final controller = DownloadController(
        scheduler: scheduler,
        executor: _FakeExecutor(),
        settingsProvider: _settings,
        postProcessController: postController,
      );
      addTearDown(controller.dispose);
      addTearDown(postController.dispose);

      scheduler.enqueue(
        DownloadTask(
          id: 'task-1',
          title: 'Task 1',
          source: 'https://example.com',
          status: DownloadStatus.ready,
          progress: 0,
          variants: const [],
        ),
      );
      scheduler.startNext();

      controller.handleTaskChanged(
        DownloadTask(
          id: 'task-1',
          title: 'Task 1',
          source: 'https://example.com',
          status: DownloadStatus.completed,
          progress: 100,
          variants: const [],
          mediaPath: '/downloads/task-1.mp4',
        ),
      );
      await pumpEventQueue();

      expect(
        controller.completedTasks.single.mediaPath,
        '/downloads/task-1.mp4',
      );
      expect(postExecutor.started, ['task-1#ai-clip-analysis']);
    },
  );
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
