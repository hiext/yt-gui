import '../models/app_models.dart';

typedef PostProcessTaskChanged = void Function(PostProcessTask task);

abstract class PostProcessExecutor {
  Future<void> startTask({
    required PostProcessTask task,
    required DownloadSettings settings,
    PostProcessTaskChanged? onTaskChanged,
  });

  Future<void> cancel(String taskId);

  Future<void> dispose();
}
