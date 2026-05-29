import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/services/yt_dlp_progress_parser.dart';

void main() {
  group('YtDlpProgressParser', () {
    test('parses progress line fields', () {
      const line = '[download]  42.5% of  1.23GiB at  3.45MiB/s ETA 00:18';

      final event = YtDlpProgressParser.parse(line);

      expect(event, isA<YtDlpProgressEvent>());
      expect(event!.type, YtDlpProgressEventType.progress);
      expect(event.percent, closeTo(42.5, 0.01));
      expect(event.speed, '3.45MiB/s');
      expect(event.eta, '00:18');
      expect(event.stage, 'download');
    });

    test('parses error line', () {
      final event = YtDlpProgressParser.parse('ERROR: network timeout');

      expect(event!.type, YtDlpProgressEventType.error);
      expect(event.message, 'network timeout');
    });

    test('parses info line', () {
      final event = YtDlpProgressParser.parse('[info] extracting video info');

      expect(event!.type, YtDlpProgressEventType.info);
      expect(event.message, 'extracting video info');
    });

    test('returns null for noise', () {
      expect(YtDlpProgressParser.parse(''), isNull);
      expect(YtDlpProgressParser.parse('plain text'), isNull);
    });
  });
}
