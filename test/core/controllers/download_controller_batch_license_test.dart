import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/controllers/download_controller.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/models/license_models.dart';
import 'package:hiext_yt_gui/core/services/download_scheduler.dart';
import 'package:hiext_yt_gui/core/services/yt_dlp_executor.dart';
import 'package:hiext_yt_gui/l10n/app_localizations.dart';

class _FakeExecutor implements YtDlpExecutor {
  final List<String> started = [];

  @override
  Future<void> cancel(String taskId) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<List<ResourceVariant>> inspect(
    Uri url, {
    DownloadSettings? settings,
    AppLocalizations? localizations,
    InspectLogSink? onLog,
  }) async {
    return const [];
  }

  @override
  Future<void> pause(String taskId) async {}

  @override
  Future<void> resume(String taskId) async {}

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DownloadSettings settings() => DownloadSettings.defaults.copyWith(
        downloadMode: DownloadMode.concurrent,
        concurrentCount: 8,
        disclaimerAccepted: true,
      );

  List<ResourceVariant> variants(int count) => [
        for (var i = 0; i < count; i++)
          ResourceVariant(
            label: 'v$i',
            description: 'mp4',
            isRecommended: i == 0,
            formatId: 'fmt$i',
            type: ResourceType.video,
          ),
      ];

  DownloadController controllerFor(
    LicenseTier? tier, {
    _FakeExecutor? executor,
  }) {
    return DownloadController(
      scheduler: DownloadScheduler(
        settingsProvider: settings,
        entitlementsProvider:
            tier == null ? null : () => Entitlements.forTier(tier),
      ),
      executor: executor ?? _FakeExecutor(),
      settingsProvider: settings,
      entitlementsProvider:
          tier == null ? null : () => Entitlements.forTier(tier),
    );
  }

  final url = Uri.parse('https://example.com/video');

  test('free tier enqueues only a single variant from a batch', () async {
    final controller = controllerFor(LicenseTier.free);
    addTearDown(controller.dispose);

    await controller.queueDownloads(url: url, variants: variants(4));

    expect(controller.allTasks, hasLength(1));
  });

  test('missing entitlements provider behaves as free (single)', () async {
    final controller = controllerFor(null);
    addTearDown(controller.dispose);

    await controller.queueDownloads(url: url, variants: variants(3));

    expect(controller.allTasks, hasLength(1));
  });

  test('pro tier enqueues every variant in the batch', () async {
    final controller = controllerFor(LicenseTier.pro);
    addTearDown(controller.dispose);

    await controller.queueDownloads(url: url, variants: variants(5));

    expect(controller.allTasks, hasLength(5));
  });

  test('team tier enqueues every variant in the batch', () async {
    final controller = controllerFor(LicenseTier.team);
    addTearDown(controller.dispose);

    await controller.queueDownloads(url: url, variants: variants(6));

    expect(controller.allTasks, hasLength(6));
  });

  test('allowedBatchCount clamps free to one and passes pro through', () {
    final free = controllerFor(LicenseTier.free);
    addTearDown(free.dispose);
    final pro = controllerFor(LicenseTier.pro);
    addTearDown(pro.dispose);

    expect(free.allowedBatchCount(5), 1);
    expect(free.allowedBatchCount(0), 0);
    expect(pro.allowedBatchCount(5), 5);
  });
}
