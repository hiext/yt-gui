import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_models.dart';
import '../services/download_scheduler.dart';
import '../services/yt_dlp_executor.dart';

class DownloadController extends ChangeNotifier {
  DownloadController({
    required this.scheduler,
    required this.executor,
    required this.settingsProvider,
  });

  final DownloadScheduler scheduler;
  final YtDlpExecutor executor;
  final DownloadSettings Function() settingsProvider;
  final Set<String> _startedTaskIds = {};
  int _taskSequence = 0;

  List<DownloadTask> get queuedTasks => scheduler.queuedTasks;
  List<DownloadTask> get runningTasks => scheduler.runningTasks;
  List<DownloadTask> get pausedTasks => scheduler.pausedTasks;
  List<DownloadTask> get completedTasks => scheduler.completedTasks;
  List<DownloadTask> get failedTasks => scheduler.failedTasks;
  List<DownloadTask> get cancelledTasks => scheduler.cancelledTasks;
  List<DownloadTask> get allTasks => scheduler.allTasks;

  bool _isDisposed = false;

  Future<void> queueDownload({
    required Uri url,
    required ResourceVariant variant,
  }) async {
    final task = DownloadTask(
      id: _createTaskId(url),
      title: url.toString(),
      source: url.toString(),
      status: DownloadStatus.ready,
      progress: 0,
      variants: [variant],
    );

    scheduler.enqueue(task);
    scheduler.startNext();
    notifyListeners();
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
      notifyListeners();
      unawaited(_startPendingRunningTasks());
      return;
    }

    if (task.status == DownloadStatus.failed) {
      _startedTaskIds.remove(task.id);
      scheduler.fail(task.id, message: task.errorMessage ?? '下载失败');
      notifyListeners();
      unawaited(_startPendingRunningTasks());
      return;
    }

    scheduler.updateTask(task);
    notifyListeners();
  }

  void handleCompleted(String taskId) {
    _startedTaskIds.remove(taskId);
    scheduler.complete(taskId);
    notifyListeners();
    unawaited(_startPendingRunningTasks());
  }

  void handleFailed(String taskId, String message) {
    _startedTaskIds.remove(taskId);
    scheduler.fail(taskId, message: message);
    notifyListeners();
    unawaited(_startPendingRunningTasks());
  }

  Future<void> pause(String taskId) async {
    await executor.pause(taskId);
    _startedTaskIds.remove(taskId);
    scheduler.pause(taskId);
    notifyListeners();
  }

  Future<void> resume(String taskId) async {
    final task = _findTask(taskId);
    if (task == null) {
      return;
    }

    scheduler.resume(taskId);
    notifyListeners();
    await _startPendingRunningTasks();
  }

  Future<void> cancel(String taskId) async {
    await executor.cancel(taskId);
    _startedTaskIds.remove(taskId);
    scheduler.cancel(taskId);
    notifyListeners();
    await _startPendingRunningTasks();
  }

  Future<void> retry(String taskId) async {
    scheduler.retry(taskId);
    notifyListeners();
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
