import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/download_scheduler.dart';

void main() {
  group('DownloadScheduler', () {
    test('starts only one task in serial mode', () {
      final scheduler = DownloadScheduler(
        settingsProvider: () =>
            _settings(DownloadMode.serial, concurrentCount: 3),
      );

      scheduler.enqueueAll([_task('1'), _task('2'), _task('3')]);
      scheduler.startNext();

      expect(scheduler.runningTasks.map((task) => task.id), ['1']);
      expect(scheduler.queuedTasks.map((task) => task.id), ['2', '3']);
    });

    test('starts tasks up to concurrent limit', () {
      final scheduler = DownloadScheduler(
        settingsProvider: () =>
            _settings(DownloadMode.concurrent, concurrentCount: 2),
      );

      scheduler.enqueueAll([_task('1'), _task('2'), _task('3')]);
      scheduler.startNext();

      expect(scheduler.runningTasks.map((task) => task.id), ['1', '2']);
      expect(scheduler.queuedTasks.map((task) => task.id), ['3']);
    });

    test('clamps concurrent count to safe bounds', () {
      final scheduler = DownloadScheduler(
        settingsProvider: () =>
            _settings(DownloadMode.concurrent, concurrentCount: 99),
      );

      scheduler.enqueueAll(List.generate(10, (index) => _task('$index')));
      scheduler.startNext();

      expect(scheduler.runningTasks.length, 8);
      expect(scheduler.queuedTasks.length, 2);
    });

    test('rejects duplicated task ids', () {
      final scheduler = DownloadScheduler(
        settingsProvider: () => _settings(DownloadMode.serial),
      );

      scheduler.enqueue(_task('1'));

      expect(
        () => scheduler.enqueue(_task('1')),
        throwsA(isA<DownloadSchedulerException>()),
      );
    });

    test('completes running task and starts next queued task', () {
      final scheduler = DownloadScheduler(
        settingsProvider: () =>
            _settings(DownloadMode.serial, concurrentCount: 1),
      );

      scheduler.enqueueAll([_task('1'), _task('2')]);
      scheduler.startNext();
      scheduler.complete('1');

      expect(scheduler.completedTasks.map((task) => task.id), ['1']);
      expect(scheduler.completedTasks.single.progress, 100);
      expect(scheduler.runningTasks.map((task) => task.id), ['2']);
      expect(scheduler.queuedTasks, isEmpty);
    });

    test('pause and resume keep task identity', () {
      final scheduler = DownloadScheduler(
        settingsProvider: () => _settings(DownloadMode.serial),
      );

      scheduler.enqueue(_task('1'));
      scheduler.startNext();
      scheduler.pause('1');

      expect(scheduler.pausedTasks.single.id, '1');
      expect(scheduler.pausedTasks.single.status, DownloadStatus.paused);

      scheduler.resume('1');

      expect(scheduler.runningTasks.single.id, '1');
      expect(scheduler.runningTasks.single.status, DownloadStatus.downloading);
    });

    test('cancel removes task from active queues', () {
      final scheduler = DownloadScheduler(
        settingsProvider: () => _settings(DownloadMode.concurrent),
      );

      scheduler.enqueueAll([_task('1'), _task('2')]);
      scheduler.startNext();
      scheduler.cancel('1');

      expect(scheduler.cancelledTasks.map((task) => task.id), ['1']);
      expect(scheduler.runningTasks.map((task) => task.id), ['2']);
    });

    test('resume queues paused task when running slots are full', () {
      final scheduler = DownloadScheduler(
        settingsProvider: () => _settings(DownloadMode.serial),
      );

      scheduler.enqueueAll([_task('1'), _task('2')]);
      scheduler.startNext();
      scheduler.pause('1');
      scheduler.resume('1');

      expect(scheduler.runningTasks.map((task) => task.id), ['2']);
      expect(scheduler.queuedTasks.map((task) => task.id), ['1']);
    });

    test('fail records task and starts next queued task', () {
      final scheduler = DownloadScheduler(
        settingsProvider: () => _settings(DownloadMode.serial),
      );

      scheduler.enqueueAll([_task('1'), _task('2')]);
      scheduler.startNext();
      scheduler.fail('1', message: 'network timeout');

      expect(scheduler.failedTasks.single.errorMessage, 'network timeout');
      expect(scheduler.runningTasks.single.id, '2');
    });

    test('retry moves failed task back to queue', () {
      final scheduler = DownloadScheduler(
        settingsProvider: () => _settings(DownloadMode.serial),
      );

      scheduler.enqueue(_task('1'));
      scheduler.startNext();
      scheduler.fail('1', message: 'network timeout');
      scheduler.retry('1');

      expect(scheduler.failedTasks, isEmpty);
      expect(scheduler.runningTasks.single.id, '1');
      expect(scheduler.runningTasks.single.errorMessage, isNull);
    });
  });
}

DownloadSettings _settings(DownloadMode mode, {int concurrentCount = 1}) {
  return DownloadSettings(
    saveDirectory: '/tmp',
    downloadMode: mode,
    concurrentCount: concurrentCount,
    defaultQuality: 'recommended',
    downloadSubtitles: false,
    downloadThumbnail: false,
    disclaimerAccepted: false,
  );
}

DownloadTask _task(String id) {
  return DownloadTask(
    id: id,
    title: 'Task $id',
    source: 'https://example.com/$id',
    status: DownloadStatus.ready,
    progress: 0,
    variants: const [
      ResourceVariant(label: '推荐', description: '适合大多数人', isRecommended: true),
    ],
  );
}
