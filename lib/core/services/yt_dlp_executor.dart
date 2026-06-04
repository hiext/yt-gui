import '../../l10n/app_localizations.dart';
import '../models/app_models.dart';

typedef DownloadTaskChanged = void Function(DownloadTask task);

abstract class YtDlpExecutor {
  Future<List<ResourceVariant>> inspect(
    Uri url, {
    DownloadSettings? settings,
    AppLocalizations? localizations,
  });

  Future<void> startDownload({
    required String taskId,
    required Uri url,
    required ResourceVariant variant,
    required DownloadSettings settings,
    DownloadTaskChanged? onTaskChanged,
  });

  Future<void> pause(String taskId);

  Future<void> resume(String taskId);

  Future<void> cancel(String taskId);

  Future<void> dispose();
}
