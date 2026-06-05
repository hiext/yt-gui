import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/database_service.dart';
import 'package:hiext_yt_gui/core/services/post_process_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../sqlite_test_setup.dart';

void main() {
  late Database db;

  setUp(() async {
    initTestSqlite();
    db = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    await createClipAnalysisTestSchema(db);
    DatabaseService().useTestDatabase(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'saves searchable structured clip segments and adjusted timing',
    () async {
      final repository = PostProcessRepository();
      final segment = ClipSegment(
        id: 'segment-1',
        sourceTaskId: 'download-1',
        postProcessTaskId: 'post-1',
        sourcePath: '/downloads/source.mp4',
        startMs: 1000,
        endMs: 12000,
        title: 'Coffee product demo',
        summary: 'A person presents coffee beans on a table',
        keywords: const ['coffee', 'beans', 'table'],
        tags: const ['yolo', 'whisper'],
        confidence: 0.88,
        reason: 'person object + speech keyword',
        detections: [
          ClipDetection(
            id: 'det-1',
            segmentId: 'segment-1',
            timestampMs: 2000,
            label: 'person',
            confidence: 0.91,
            bbox: const [1, 2, 3, 4],
          ),
        ],
        transcripts: [
          ClipTranscript(
            id: 'txt-1',
            segmentId: 'segment-1',
            startMs: 1500,
            endMs: 9000,
            text: 'fresh coffee beans',
            words: const ['fresh', 'coffee', 'beans'],
          ),
        ],
      );

      await repository.saveClipSegments('post-1', [segment]);

      final results = await repository.searchClipSegments('beans');
      expect(results.single.id, 'segment-1');
      expect(results.single.detections.single.label, 'person');

      await repository.updateClipSegmentTiming(
        'segment-1',
        adjustedStartMs: 500,
        adjustedEndMs: 12500,
      );
      final updated = await repository.searchClipSegments('person');

      expect(updated.single.adjustedStartMs, 500);
      expect(updated.single.adjustedEndMs, 12500);
    },
  );
}
