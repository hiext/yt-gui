import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/yt_dlp_progress_parser.dart';
import 'package:hiext_yt_gui/core/services/yt_dlp_session.dart';

void main() {
  test('updates task progress from output events', () async {
    final session = YtDlpSession.forTesting(
      task: DownloadTask(
        id: '1',
        title: 'Task 1',
        source: 'https://example.com',
        status: DownloadStatus.downloading,
        progress: 0,
        variants: const [],
      ),
    );

    session.handleEvent(
      const YtDlpProgressEvent(
        type: YtDlpProgressEventType.progress,
        stage: 'download',
        percent: 45.5,
        speed: '2.1MiB/s',
        eta: '00:12',
      ),
    );

    expect(session.task.progress, 45.5);
    expect(session.status, DownloadStatus.downloading);
    expect(session.lastSpeed, '2.1MiB/s');
    expect(session.lastEta, '00:12');
  });

  test('marks task failed on error event', () {
    final session = YtDlpSession.forTesting(
      task: DownloadTask(
        id: '1',
        title: 'Task 1',
        source: 'https://example.com',
        status: DownloadStatus.downloading,
        progress: 0,
        variants: const [],
      ),
    );

    session.handleEvent(
      const YtDlpProgressEvent(
        type: YtDlpProgressEventType.error,
        message: 'network timeout',
      ),
    );

    expect(session.status, DownloadStatus.failed);
    expect(session.errorMessage, 'network timeout');
  });

  test('marks task completed when process ends successfully', () {
    final session = YtDlpSession.forTesting(
      task: DownloadTask(
        id: '1',
        title: 'Task 1',
        source: 'https://example.com',
        status: DownloadStatus.downloading,
        progress: 0,
        variants: const [],
      ),
    );

    session.markCompleted();

    expect(session.status, DownloadStatus.completed);
    expect(session.task.progress, 100);
  });
}
