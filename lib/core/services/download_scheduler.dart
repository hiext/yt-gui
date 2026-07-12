import '../models/app_models.dart';
import '../models/license_models.dart';

class DownloadScheduler {
  DownloadScheduler({
    required this.settingsProvider,
    this.entitlementsProvider,
  });

  final DownloadSettings Function() settingsProvider;

  /// Optional license entitlements. When absent, behaves as Free (cap 1).
  final Entitlements Function()? entitlementsProvider;
  final List<DownloadTask> _queued = [];
  final List<DownloadTask> _running = [];
  final List<DownloadTask> _paused = [];
  final List<DownloadTask> _completed = [];
  final List<DownloadTask> _failed = [];
  final List<DownloadTask> _cancelled = [];

  List<DownloadTask> get queuedTasks => List.unmodifiable(_queued);

  List<DownloadTask> get runningTasks => List.unmodifiable(_running);

  List<DownloadTask> get pausedTasks => List.unmodifiable(_paused);

  List<DownloadTask> get completedTasks => List.unmodifiable(_completed);

  List<DownloadTask> get failedTasks => List.unmodifiable(_failed);

  List<DownloadTask> get cancelledTasks => List.unmodifiable(_cancelled);

  List<DownloadTask> get allTasks => [
    ..._queued,
    ..._running,
    ..._paused,
    ..._completed,
    ..._failed,
    ..._cancelled,
  ];

  void enqueue(DownloadTask task) {
    _ensureUniqueTaskId(task.id);
    _queued.add(task.copyWith(status: DownloadStatus.queued));
  }

  void enqueueAll(Iterable<DownloadTask> tasks) {
    for (final task in tasks) {
      enqueue(task);
    }
  }

  void startNext() {
    while (_queued.isNotEmpty && _running.length < _maxRunningTasks) {
      final task = _queued.removeAt(0);
      _running.add(task.copyWith(status: DownloadStatus.downloading));
    }
  }

  void complete(String taskId) {
    final task = _removeById(_running, taskId);
    _completed.add(
      task.copyWith(status: DownloadStatus.completed, progress: 100),
    );
    startNext();
  }

  void pause(String taskId) {
    final task = _removeById(_running, taskId);
    _paused.add(task.copyWith(status: DownloadStatus.paused));
    startNext();
  }

  void resume(String taskId) {
    final task = _removeById(_paused, taskId);
    if (_running.length < _maxRunningTasks) {
      _running.add(task.copyWith(status: DownloadStatus.downloading));
      return;
    }

    _queued.insert(0, task.copyWith(status: DownloadStatus.queued));
  }

  void cancel(String taskId) {
    final task = _removeActiveTask(taskId);
    _cancelled.add(task.copyWith(status: DownloadStatus.cancelled));
    startNext();
  }

  void fail(String taskId, {required String message}) {
    final task = _removeActiveTask(taskId);
    _failed.add(
      task.copyWith(status: DownloadStatus.failed, errorMessage: message),
    );
    startNext();
  }

  void restoreHistory(List<DownloadTask> tasks) {
    for (final task in tasks) {
      switch (task.status) {
        case DownloadStatus.completed:
          _completed.add(task);
        case DownloadStatus.failed:
          _failed.add(task);
        case DownloadStatus.cancelled:
          _cancelled.add(task);
        default:
          break;
      }
    }
  }

  void removeFromHistory(String taskId) {
    _completed.removeWhere((t) => t.id == taskId);
    _failed.removeWhere((t) => t.id == taskId);
    _cancelled.removeWhere((t) => t.id == taskId);
  }

  void retry(String taskId) {
    final task = _removeById(_failed, taskId);
    _queued.insert(
      0,
      task.copyWith(status: DownloadStatus.queued, errorMessage: null),
    );
    startNext();
  }

  void updateTask(DownloadTask updatedTask) {
    for (final bucket in [
      _queued,
      _running,
      _paused,
      _completed,
      _failed,
      _cancelled,
    ]) {
      final index = bucket.indexWhere((task) => task.id == updatedTask.id);
      if (index >= 0) {
        bucket[index] = updatedTask;
        return;
      }
    }

    throw DownloadSchedulerException('Unknown task id: ${updatedTask.id}');
  }

  int get _maxRunningTasks {
    final settings = settingsProvider();
    final cap = entitlementsProvider?.call().maxConcurrentDownloads ?? 1;
    return switch (settings.downloadMode) {
      DownloadMode.serial => 1,
      DownloadMode.queue => 1,
      DownloadMode.concurrent =>
        settings.concurrentCount.clamp(1, cap).toInt(),
    };
  }

  void _ensureUniqueTaskId(String taskId) {
    for (final bucket in [
      _queued,
      _running,
      _paused,
      _completed,
      _failed,
      _cancelled,
    ]) {
      if (bucket.any((task) => task.id == taskId)) {
        throw DownloadSchedulerException('Duplicated task id: $taskId');
      }
    }
  }

  DownloadTask _removeActiveTask(String taskId) {
    for (final bucket in [_running, _queued, _paused]) {
      final index = bucket.indexWhere((task) => task.id == taskId);
      if (index >= 0) {
        return bucket.removeAt(index);
      }
    }

    throw DownloadSchedulerException('Unknown task id: $taskId');
  }

  DownloadTask _removeById(List<DownloadTask> tasks, String taskId) {
    final index = tasks.indexWhere((task) => task.id == taskId);
    if (index < 0) {
      throw DownloadSchedulerException('Unknown task id: $taskId');
    }

    return tasks.removeAt(index);
  }
}

class DownloadSchedulerException implements Exception {
  const DownloadSchedulerException(this.message);

  final String message;

  @override
  String toString() => message;
}
