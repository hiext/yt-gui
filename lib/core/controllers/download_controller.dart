import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_models.dart';
import '../services/download_scheduler.dart';
import '../services/notification_service.dart';
import '../services/task_repository.dart';
import '../services/yt_dlp_executor.dart';
import '../../shared/utils/platform_utils.dart';

class DownloadController extends ChangeNotifier {
  DownloadController({
    required this.scheduler,
    required this.executor,
    required this.settingsProvider,
    this.taskRepository,
  });

  final DownloadScheduler scheduler;
  final YtDlpExecutor executor;
  final DownloadSettings Function() settingsProvider;
  final TaskRepository? taskRepository;
  final Set<String> _startedTaskIds = {};
  int _taskSequence = 0;

  Future<void> loadPendingTasks() async {
    final repo = taskRepository;
    if (repo == null) return;
    // Load history first
    final history = await repo.loadHistoryTasks();
    if (history.isNotEmpty) {
      scheduler.restoreHistory(history);
    }
    // Load pending tasks
    final tasks = await repo.loadPendingTasks();
    if (tasks.isEmpty) return;
    for (final task in tasks) {
      scheduler.enqueue(
        task.copyWith(
          status: DownloadStatus.queued,
          progress: 0,
          speed: null,
          eta: null,
        ),
      );
    }
    scheduler.startNext();
    _notifyChanged();
    unawaited(_startPendingRunningTasks());
  }

  void _persistTasks() {
    final repo = taskRepository;
    if (repo == null) return;
    final active = <DownloadTask>[
      ...scheduler.queuedTasks,
      ...scheduler.runningTasks,
      ...scheduler.pausedTasks,
    ];
    unawaited(repo.savePendingTasks(active));
    final history = <DownloadTask>[
      ...scheduler.completedTasks,
      ...scheduler.failedTasks,
      ...scheduler.cancelledTasks,
    ];
    unawaited(repo.saveHistoryTasks(history));
  }

  void _notifyChanged() {
    notifyListeners();
    _persistTasks();
  }

  List<DownloadTask> get queuedTasks => scheduler.queuedTasks;
  List<DownloadTask> get runningTasks => scheduler.runningTasks;
  List<DownloadTask> get pausedTasks => scheduler.pausedTasks;
  List<DownloadTask> get completedTasks => scheduler.completedTasks;
  List<DownloadTask> get failedTasks => scheduler.failedTasks;
  List<DownloadTask> get cancelledTasks => scheduler.cancelledTasks;
  List<DownloadTask> get allTasks => scheduler.allTasks;

  List<TaskGroup> get taskGroups {
    final groups = <String, List<DownloadTask>>{};
    final order = <String>[];
    for (final task in allTasks) {
      if (!groups.containsKey(task.source)) {
        groups[task.source] = [];
        order.add(task.source);
      }
      groups[task.source]!.add(task);
    }
    return order.map((source) {
      final tasks = groups[source]!;
      return TaskGroup(source: source, tasks: tasks);
    }).toList();
  }

  bool _isDisposed = false;

  Future<List<ResourceVariant>> inspect(Uri url) {
    return executor.inspect(url, settings: settingsProvider());
  }

  String? resolveCookieFile(Uri url) {
    final host = url.host;
    for (final config in settingsProvider().cookieConfigs) {
      if (!config.enabled) continue;
      if (host.contains(config.domain) || config.domain.contains(host)) {
        return config.cookieFile;
      }
    }
    return null;
  }

  String getDownloadPath(DownloadTask task) {
    final variant = task.variants.isNotEmpty ? task.variants.first : null;
    final videoId = variant?.videoId;
    final saveDir = settingsProvider().saveDirectory;
    if (videoId != null) return '$saveDir/$videoId';
    return saveDir;
  }

  Future<void> openDownloadFolder(DownloadTask task) async {
    final path = getDownloadPath(task);
    await openFolder(path);
  }

  Future<void> queueDownload({
    required Uri url,
    required ResourceVariant variant,
    String? title,
  }) async {
    final task = DownloadTask(
      id: _createTaskId(url),
      title: title ?? url.toString(),
      source: url.toString(),
      status: DownloadStatus.ready,
      progress: 0,
      variants: [variant],
    );

    scheduler.enqueue(task);
    scheduler.startNext();
    _notifyChanged();
    await _startPendingRunningTasks();
  }

  Future<void> queueDownloads({
    required Uri url,
    required List<ResourceVariant> variants,
    String? title,
  }) async {
    for (final variant in variants) {
      final task = DownloadTask(
        id: _createTaskId(url),
        title: title ?? url.toString(),
        source: url.toString(),
        status: DownloadStatus.ready,
        progress: 0,
        variants: [variant],
      );
      scheduler.enqueue(task);
    }
    scheduler.startNext();
    _notifyChanged();
    await _startPendingRunningTasks();
  }

  void handleProgress({
    required String taskId,
    required double? progress,
    String? speed,
    String? eta,
  }) {
    final task = _findTask(taskId);
    if (task == null) {
      return;
    }

    handleTaskChanged(
      task.copyWith(
        status: DownloadStatus.downloading,
        progress: progress,
        speed: speed,
        eta: eta,
      ),
    );
  }

  void handleTaskChanged(DownloadTask task) {
    if (_isDisposed) {
      return;
    }

    if (task.status == DownloadStatus.completed) {
      _startedTaskIds.remove(task.id);
      scheduler.complete(task.id);
      _notifyChanged();
      unawaited(_startPendingRunningTasks());
      NotificationService().showDownloadComplete(title: task.title);
      return;
    }

    if (task.status == DownloadStatus.failed) {
      _startedTaskIds.remove(task.id);
      scheduler.fail(task.id, message: task.errorMessage ?? '下载失败');
      _notifyChanged();
      unawaited(_startPendingRunningTasks());
      NotificationService().showDownloadFailed(
        title: task.title,
        error: task.errorMessage ?? '未知错误',
      );
      return;
    }

    scheduler.updateTask(task);
    _notifyChanged();
  }

  void handleCompleted(String taskId) {
    _startedTaskIds.remove(taskId);
    scheduler.complete(taskId);
    _notifyChanged();
    unawaited(_startPendingRunningTasks());
  }

  void handleFailed(String taskId, String message) {
    _startedTaskIds.remove(taskId);
    scheduler.fail(taskId, message: message);
    _notifyChanged();
    unawaited(_startPendingRunningTasks());
  }

  Future<void> pause(String taskId) async {
    await executor.pause(taskId);
    _startedTaskIds.remove(taskId);
    scheduler.pause(taskId);
    _notifyChanged();
  }

  Future<void> resume(String taskId) async {
    final task = _findTask(taskId);
    if (task == null) {
      return;
    }

    scheduler.resume(taskId);
    _notifyChanged();
    await _startPendingRunningTasks();
  }

  Future<void> cancel(String taskId) async {
    await executor.cancel(taskId);
    _startedTaskIds.remove(taskId);
    scheduler.cancel(taskId);
    _notifyChanged();
    await _startPendingRunningTasks();
  }

  Future<void> retry(String taskId) async {
    scheduler.retry(taskId);
    _notifyChanged();
    await _startPendingRunningTasks();
  }

  Future<void> _startPendingRunningTasks() async {
    if (_isDisposed) {
      return;
    }

    for (final task in scheduler.runningTasks) {
      if (_startedTaskIds.contains(task.id)) {
        continue;
      }

      final variant = task.variants.isNotEmpty
          ? task.variants.first
          : const ResourceVariant(
              label: '推荐',
              description: '适合大多数人',
              isRecommended: true,
            );
      _startedTaskIds.add(task.id);
      await executor.startDownload(
        taskId: task.id,
        url: Uri.parse(task.source),
        variant: variant,
        settings: settingsProvider(),
        onTaskChanged: handleTaskChanged,
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _startedTaskIds.clear();
    unawaited(executor.dispose());
    super.dispose();
  }

  DownloadTask? _findTask(String taskId) {
    for (final task in scheduler.allTasks) {
      if (task.id == taskId) {
        return task;
      }
    }

    return null;
  }

  String _createTaskId(Uri url) {
    _taskSequence += 1;
    return '${url.toString()}#$_taskSequence';
  }
}

class TaskGroup {
  const TaskGroup({required this.source, required this.tasks});

  final String source;
  final List<DownloadTask> tasks;
}
