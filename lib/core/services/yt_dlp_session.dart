import '../models/app_models.dart';
import 'yt_dlp_progress_parser.dart';

class YtDlpSession {
  YtDlpSession({required this.task});

  YtDlpSession.forTesting({required this.task});

  DownloadTask task;
  DownloadStatus status = DownloadStatus.idle;
  String? lastSpeed;
  String? lastEta;
  String? errorMessage;

  void handleLine(String line) {
    final event = YtDlpProgressParser.parse(line);
    if (event != null) {
      handleEvent(event);
    }
  }

  void handleEvent(YtDlpProgressEvent event) {
    switch (event.type) {
      case YtDlpProgressEventType.progress:
        status = DownloadStatus.downloading;
        task = task.copyWith(
          status: DownloadStatus.downloading,
          progress: event.percent ?? task.progress,
          speed: event.speed,
          eta: event.eta,
        );
        lastSpeed = event.speed;
        lastEta = event.eta;
      case YtDlpProgressEventType.info:
        break;
      case YtDlpProgressEventType.error:
        // Don't immediately mark the task as failed — yt-dlp may output
        // non-fatal ERROR lines during normal operation (e.g. fragment
        // retries, format fallback). Accumulate the message and let the
        // final exit code determine the outcome.
        errorMessage = event.message;
        if (status != DownloadStatus.downloading) {
          status = DownloadStatus.failed;
          task = task.copyWith(
            status: DownloadStatus.failed,
            errorMessage: event.message,
          );
        }
    }
  }

  void markCompleted() {
    status = DownloadStatus.completed;
    task = task.copyWith(status: DownloadStatus.completed, progress: 100);
  }
}
