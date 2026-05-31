import '../models/app_models.dart';
import 'database_service.dart';

class TaskRepository {
  Future<List<DownloadTask>> loadPendingTasks() async {
    return DatabaseService().loadTasksByStatus(const [
      'queued',
      'running',
      'paused',
      'downloading',
    ]);
  }

  Future<void> savePendingTasks(List<DownloadTask> tasks) async {
    await DatabaseService().replaceStatusTasks('queued', []);
    await DatabaseService().replaceStatusTasks('running', []);
    await DatabaseService().replaceStatusTasks('downloading', []);
    for (final task in tasks) {
      await DatabaseService().saveTask(task);
    }
  }

  Future<List<DownloadTask>> loadHistoryTasks() async {
    return DatabaseService().loadTasksByStatus(const [
      'completed',
      'failed',
      'cancelled',
    ]);
  }

  Future<void> saveHistoryTasks(List<DownloadTask> tasks) async {
    await DatabaseService().replaceStatusTasks('completed', []);
    await DatabaseService().replaceStatusTasks('failed', []);
    await DatabaseService().replaceStatusTasks('cancelled', []);
    for (final task in tasks) {
      await DatabaseService().saveTask(task);
    }
  }
}
