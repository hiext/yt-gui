import 'dart:convert';

import '../models/app_models.dart';
import 'database_service.dart';

class ClipRecordRepository {
  ClipRecordRepository({DatabaseService? db}) : _db = db ?? DatabaseService();

  final DatabaseService _db;

  Future<void> save(ClipRecord record) async {
    final d = await _db.db;
    await d.insert('clip_records', {
      'id': record.id,
      'source_task_id': record.sourceTaskId,
      'source_path': record.sourcePath,
      'output_path': record.outputPath,
      'title': record.title,
      'confidence': record.confidence,
      'start_ms': record.startMs,
      'end_ms': record.endMs,
      'duration_ms': record.durationMs,
      'status': record.status.name,
      'progress': record.progress,
      'error_message': record.errorMessage,
      'created_at': record.createdAt.toIso8601String(),
      'completed_at': record.completedAt?.toIso8601String(),
      'data': jsonEncode(record.toJson()),
    }, conflictAlgorithm: null); // INSERT only, use updateStatus for changes
  }

  Future<void> saveAll(List<ClipRecord> records) async {
    final d = await _db.db;
    final batch = d.batch();
    for (final record in records) {
      batch.insert('clip_records', {
        'id': record.id,
        'source_task_id': record.sourceTaskId,
        'source_path': record.sourcePath,
        'output_path': record.outputPath,
        'title': record.title,
        'confidence': record.confidence,
        'start_ms': record.startMs,
        'end_ms': record.endMs,
        'duration_ms': record.durationMs,
        'status': record.status.name,
        'progress': record.progress,
        'error_message': record.errorMessage,
        'created_at': record.createdAt.toIso8601String(),
        'completed_at': record.completedAt?.toIso8601String(),
        'data': jsonEncode(record.toJson()),
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<ClipRecord>> loadBySourceTask(String sourceTaskId) async {
    final d = await _db.db;
    final rows = await d.query(
      'clip_records',
      where: 'source_task_id = ?',
      whereArgs: [sourceTaskId],
      orderBy: 'created_at ASC',
    );
    return rows.map((r) => _fromRow(r)).toList();
  }

  Future<List<ClipRecord>> loadAll() async {
    final d = await _db.db;
    final rows = await d.query(
      'clip_records',
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => _fromRow(r)).toList();
  }

  Future<void> updateStatus(
    String id,
    ClipRecordStatus status, {
    int? progress,
    String? errorMessage,
    String? outputPath,
  }) async {
    final d = await _db.db;
    final updates = <String, Object?>{
      'status': status.name,
    };
    if (progress != null) updates['progress'] = progress;
    if (errorMessage != null) updates['error_message'] = errorMessage;
    if (outputPath != null) updates['output_path'] = outputPath;

    if (status == ClipRecordStatus.completed) {
      updates['completed_at'] = DateTime.now().toIso8601String();
      if (progress == null) updates['progress'] = 100;
    }

    await d.update(
      'clip_records',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(String id) async {
    final d = await _db.db;
    await d.delete('clip_records', where: 'id = ?', whereArgs: [id]);
  }

  ClipRecord _fromRow(Map<String, Object?> row) {
    return ClipRecord.fromJson(
      jsonDecode(row['data'] as String) as Map<String, Object?>,
    );
  }
}
