import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/models/license_models.dart';
import 'package:hiext_yt_gui/core/services/download_scheduler.dart';

void main() {
  DownloadTask task(String id) => DownloadTask(
        id: id,
        title: id,
        source: 'https://example.com/$id',
        status: DownloadStatus.ready,
        progress: 0,
        variants: const [],
      );

  DownloadSettings concurrent(int count) => DownloadSettings.defaults.copyWith(
        downloadMode: DownloadMode.concurrent,
        concurrentCount: count,
        disclaimerAccepted: true,
      );

  test('free entitlements cap concurrency to 1 regardless of settings', () {
    final scheduler = DownloadScheduler(
      settingsProvider: () => concurrent(8),
      entitlementsProvider: () => Entitlements.forTier(LicenseTier.free),
    );
    scheduler.enqueueAll([task('a'), task('b'), task('c')]);
    scheduler.startNext();
    expect(scheduler.runningTasks.length, 1);
  });

  test('pro entitlements allow up to 8 concurrent', () {
    final scheduler = DownloadScheduler(
      settingsProvider: () => concurrent(8),
      entitlementsProvider: () => Entitlements.forTier(LicenseTier.pro),
    );
    scheduler.enqueueAll([for (var i = 0; i < 10; i++) task('t$i')]);
    scheduler.startNext();
    expect(scheduler.runningTasks.length, 8);
  });

  test('pro respects user concurrentCount below the cap', () {
    final scheduler = DownloadScheduler(
      settingsProvider: () => concurrent(3),
      entitlementsProvider: () => Entitlements.forTier(LicenseTier.pro),
    );
    scheduler.enqueueAll([for (var i = 0; i < 10; i++) task('t$i')]);
    scheduler.startNext();
    expect(scheduler.runningTasks.length, 3);
  });

  test('missing entitlementsProvider behaves as free (cap 1)', () {
    final scheduler = DownloadScheduler(settingsProvider: () => concurrent(8));
    scheduler.enqueueAll([task('a'), task('b')]);
    scheduler.startNext();
    expect(scheduler.runningTasks.length, 1);
  });
}
