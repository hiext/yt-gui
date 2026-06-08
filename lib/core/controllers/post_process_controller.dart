import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_models.dart';
import '../services/auto_clip_service.dart';
import '../services/post_process_executor.dart';
import '../services/post_process_repository.dart';

class PostProcessController extends ChangeNotifier {
  PostProcessController({
    required this.executor,
    required this.settingsProvider,
    this.repository,
    this._autoClipService,
  });

  final PostProcessExecutor executor;
  final DownloadSettings Function() settingsProvider;
  final PostProcessRepository? repository;
  final AutoClipService? _autoClipService;

  final List<PostProcessTask> _queued = [];
  final List<PostProcessTask> _running = [];
  final List<PostProcessTask> _completed = [];
  final List<PostProcessTask> _failed = [];
  final List<PostProcessTask> _cancelled = [];
  final List<ClipSegment> _clipSegments = [];
  final Set<String> _startedTaskIds = {};
  final List<ClipRecord> _clipRecords = [];
  bool _isDisposed = false;

  List<ClipRecord> get clipRecords => List.unmodifiable(_clipRecords);

  List<PostProcessTask> get queuedTasks => List.unmodifiable(_queued);
  List<PostProcessTask> get runningTasks => List.unmodifiable(_running);
  List<PostProcessTask> get completedTasks => List.unmodifiable(_completed);
  List<PostProcessTask> get failedTasks => List.unmodifiable(_failed);
  List<PostProcessTask> get cancelledTasks => List.unmodifiable(_cancelled);
  List<ClipSegment> get clipSegments => List.unmodifiable(_clipSegments);

  List<PostProcessTask> get allTasks => [
    ..._queued,
    ..._running,
    ..._completed,
    ..._failed,
    ..._cancelled,
  ];

  Future<void> loadPendingTasks() async {
    final repo = repository;
    if (repo == null) return;

    final history = await repo.loadHistoryTasks();
    _completed.addAll(
      history.where((task) => task.status == PostProcessStatus.completed),
    );
    _failed.addAll(
      history.where((task) => task.status == PostProcessStatus.failed),
    );
    _cancelled.addAll(
      history.where((task) => task.status == PostProcessStatus.cancelled),
    );

    final pending = await repo.loadPendingTasks();
    _queued.addAll(
      pending.map((task) => task.copyWith(status: PostProcessStatus.queued)),
    );
    _clipSegments
      ..clear()
      ..addAll(await repo.loadClipSegments());
    _startNext();
    _notifyChanged();
    await _startPendingRunningTasks();
  }

  Future<void> enqueueClipForDownload(DownloadTask downloadTask) async {
    await enqueueAiClipAnalysisForDownload(downloadTask);
  }

  Future<void> enqueueAiClipAnalysisForDownload(
    DownloadTask downloadTask,
  ) async {
    final sourcePath = downloadTask.mediaPath;
    if (sourcePath == null || sourcePath.trim().isEmpty) {
      return;
    }

    final task = PostProcessTask(
      id: '${downloadTask.id}#ai-clip-analysis',
      sourceTaskId: downloadTask.id,
      title: downloadTask.title,
      type: PostProcessTaskType.aiClipAnalysis,
      status: PostProcessStatus.queued,
      progress: 0,
      sourcePath: sourcePath,
      outputDirectory: '$sourcePath.clips',
    );

    if (_containsTask(task.id)) {
      return;
    }

    _queued.add(task);
    _startNext();
    _notifyChanged();
    await _startPendingRunningTasks();
  }

  void handleTaskChanged(PostProcessTask task) {
    if (_isDisposed) return;

    switch (task.status) {
      case PostProcessStatus.completed:
        _startedTaskIds.remove(task.id);
        _moveToTerminal(task, _completed);
        _saveClipSegments(task);
        _startAutoCutIfEnabled(task);
        _startNext();
        break;
      case PostProcessStatus.failed:
        _startedTaskIds.remove(task.id);
        _moveToTerminal(task, _failed);
        _startNext();
        break;
      case PostProcessStatus.cancelled:
        _startedTaskIds.remove(task.id);
        _moveToTerminal(task, _cancelled);
        _startNext();
        break;
      case PostProcessStatus.running:
        _replaceTask(task);
        break;
      case PostProcessStatus.queued:
        _replaceTask(task);
        break;
    }

    _notifyChanged();
    unawaited(_startPendingRunningTasks());
  }

  Future<void> cancel(String taskId) async {
    await executor.cancel(taskId);
    final task = _removeActiveTask(taskId);
    _startedTaskIds.remove(taskId);
    _cancelled.add(task.copyWith(status: PostProcessStatus.cancelled));
    _startNext();
    _notifyChanged();
    await _startPendingRunningTasks();
  }

  Future<void> retry(String taskId) async {
    final task = _removeById(_failed, taskId);
    _queued.insert(
      0,
      task.copyWith(
        status: PostProcessStatus.queued,
        progress: 0,
        errorMessage: null,
      ),
    );
    _startNext();
    _notifyChanged();
    await _startPendingRunningTasks();
  }

  Future<void> _startPendingRunningTasks() async {
    if (_isDisposed) return;

    for (final task in List<PostProcessTask>.of(_running)) {
      if (_startedTaskIds.contains(task.id)) continue;
      _startedTaskIds.add(task.id);
      await executor.startTask(
        task: task,
        settings: settingsProvider(),
        onTaskChanged: handleTaskChanged,
      );
    }
  }

  void _startNext() {
    while (_queued.isNotEmpty && _running.isEmpty) {
      final task = _queued.removeAt(0);
      _running.add(task.copyWith(status: PostProcessStatus.running));
    }
  }

  void _moveToTerminal(
    PostProcessTask task,
    List<PostProcessTask> terminalBucket,
  ) {
    _removeIfExists(_running, task.id);
    _removeIfExists(_queued, task.id);
    terminalBucket.removeWhere((existing) => existing.id == task.id);
    terminalBucket.add(task);
  }

  void _replaceTask(PostProcessTask task) {
    for (final bucket in [_queued, _running]) {
      final index = bucket.indexWhere((existing) => existing.id == task.id);
      if (index >= 0) {
        bucket[index] = task;
        return;
      }
    }
  }

  PostProcessTask _removeActiveTask(String taskId) {
    for (final bucket in [_running, _queued]) {
      final task = _removeIfExists(bucket, taskId);
      if (task != null) return task;
    }
    throw PostProcessControllerException(
      'Unknown post-process task id: $taskId',
    );
  }

  PostProcessTask _removeById(List<PostProcessTask> tasks, String taskId) {
    final task = _removeIfExists(tasks, taskId);
    if (task != null) return task;
    throw PostProcessControllerException(
      'Unknown post-process task id: $taskId',
    );
  }

  PostProcessTask? _removeIfExists(List<PostProcessTask> tasks, String taskId) {
    final index = tasks.indexWhere((task) => task.id == taskId);
    if (index < 0) return null;
    return tasks.removeAt(index);
  }

  bool _containsTask(String taskId) {
    return allTasks.any((task) => task.id == taskId);
  }

  void _notifyChanged() {
    notifyListeners();
    _persistTasks();
  }

  Future<List<ClipSegment>> searchClipSegments(String query) async {
    final repo = repository;
    if (repo == null) {
      final normalized = query.trim().toLowerCase();
      if (normalized.isEmpty) return clipSegments;
      return _clipSegments.where((segment) {
        final haystack = [
          segment.title,
          segment.summary,
          segment.reason,
          ...segment.keywords,
          ...segment.tags,
          ...segment.transcripts.map((t) => t.text),
          ...segment.detections.map((d) => d.label),
        ].join(' ').toLowerCase();
        return haystack.contains(normalized);
      }).toList();
    }
    return repo.searchClipSegments(query);
  }

  Future<void> adjustClipTiming(
    String segmentId, {
    int? adjustedStartMs,
    int? adjustedEndMs,
  }) async {
    final index = _clipSegments.indexWhere(
      (segment) => segment.id == segmentId,
    );
    if (index < 0) return;
    final updated = _clipSegments[index].copyWith(
      adjustedStartMs: adjustedStartMs,
      adjustedEndMs: adjustedEndMs,
    );
    _clipSegments[index] = updated;
    await repository?.updateClipSegmentTiming(
      segmentId,
      adjustedStartMs: adjustedStartMs,
      adjustedEndMs: adjustedEndMs,
    );
    notifyListeners();
  }

  void _startAutoCutIfEnabled(PostProcessTask task) {
    final service = _autoClipService;
    if (service == null) return;
    if (task.clipSegments.isEmpty) return;

    // Ensure the service uses the latest settings config
    service.config = settingsProvider().autoClipConfig;

    if (!service.config.enabled) return;

    unawaited(
      service
          .startAutoCut(
            segments: task.clipSegments,
            settings: settingsProvider(),
            onStatusChanged: (recordId, status) {
              final index = _clipRecords.indexWhere((r) => r.id == recordId);
              if (index >= 0) {
                _clipRecords[index] = service.records.firstWhere(
                  (r) => r.id == recordId,
                  orElse: () => _clipRecords[index],
                );
              } else {
                _clipRecords.addAll(
                  service.records.where((r) => r.id == recordId),
                );
              }
              notifyListeners();
            },
          )
          .then((newRecords) {
            _clipRecords.addAll(
              newRecords.where((r) => !_clipRecords.any((e) => e.id == r.id)),
            );
            notifyListeners();
          }),
    );
  }

  void _saveClipSegments(PostProcessTask task) {
    if (task.clipSegments.isEmpty) return;
    _clipSegments.removeWhere(
      (segment) => segment.postProcessTaskId == task.id,
    );
    _clipSegments.addAll(task.clipSegments);
    final repo = repository;
    if (repo == null) return;
    unawaited(repo.saveClipSegments(task.id, task.clipSegments));
  }

  void _persistTasks() {
    final repo = repository;
    if (repo == null) return;
    unawaited(repo.savePendingTasks([..._queued, ..._running]));
    unawaited(
      repo.saveHistoryTasks([..._completed, ..._failed, ..._cancelled]),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _startedTaskIds.clear();
    unawaited(executor.dispose());
    super.dispose();
  }
}

class PostProcessControllerException implements Exception {
  const PostProcessControllerException(this.message);

  final String message;

  @override
  String toString() => message;
}
