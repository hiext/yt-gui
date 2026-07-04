import '../models/app_models.dart';
import 'database_service.dart';

class PostProcessRepository {
  Future<List<PostProcessTask>> loadPendingTasks() async {
    return DatabaseService().loadPostProcessTasksByStatus(const [
      'queued',
      'running',
    ]);
  }

  Future<void> savePendingTasks(List<PostProcessTask> tasks) async {
    await DatabaseService().replacePostProcessStatusTasks('queued', []);
    await DatabaseService().replacePostProcessStatusTasks('running', []);
    for (final task in tasks) {
      await DatabaseService().savePostProcessTask(task);
    }
  }

  Future<List<PostProcessTask>> loadHistoryTasks() async {
    return DatabaseService().loadPostProcessTasksByStatus(const [
      'completed',
      'failed',
      'cancelled',
    ]);
  }

  Future<void> saveHistoryTasks(List<PostProcessTask> tasks) async {
    await DatabaseService().replacePostProcessStatusTasks('completed', []);
    await DatabaseService().replacePostProcessStatusTasks('failed', []);
    await DatabaseService().replacePostProcessStatusTasks('cancelled', []);
    for (final task in tasks) {
      await DatabaseService().savePostProcessTask(task);
    }
  }

  Future<void> saveClipSegments(
    String postProcessTaskId,
    List<ClipSegment> segments,
  ) {
    return DatabaseService().replaceClipSegmentsForTask(
      postProcessTaskId,
      segments,
    );
  }

  Future<List<ClipSegment>> loadClipSegments() {
    return DatabaseService().loadClipSegments();
  }

  Future<List<ClipSegment>> searchClipSegments(String query) {
    return DatabaseService().searchClipSegments(query);
  }

  Future<void> updateClipSegmentTiming(
    String segmentId, {
    int? adjustedStartMs,
    int? adjustedEndMs,
  }) {
    return DatabaseService().updateClipSegmentTiming(
      segmentId,
      adjustedStartMs: adjustedStartMs,
      adjustedEndMs: adjustedEndMs,
    );
  }

  Future<void> updateClipSegmentOutputPath(
    String segmentId, {
    required String outputPath,
  }) {
    return DatabaseService().updateClipSegmentOutputPath(
      segmentId,
      outputPath: outputPath,
    );
  }

  Future<void> deleteClipSegment(String segmentId) {
    return DatabaseService().deleteClipSegment(segmentId);
  }
}
