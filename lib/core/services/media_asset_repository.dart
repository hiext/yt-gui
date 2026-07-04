import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/app_models.dart';
import 'database_service.dart';

class MediaAssetRepository {
  MediaAssetRepository({DatabaseService? db}) : _db = db ?? DatabaseService();

  final DatabaseService _db;

  Future<void> saveMediaAsset(MediaAsset asset) async {
    final d = await _db.db;
    await d.insert(
      'media_assets',
      _mediaAssetRow(asset),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<MediaAsset?> loadMediaAsset(String id) async {
    final d = await _db.db;
    final rows = await d.query(
      'media_assets',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mediaAssetFromRow(rows.single);
  }

  Future<MediaAsset?> loadMediaAssetBySourceTask(String sourceTaskId) async {
    final d = await _db.db;
    final rows = await d.query(
      'media_assets',
      where: 'source_task_id = ?',
      whereArgs: [sourceTaskId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mediaAssetFromRow(rows.single);
  }

  Future<List<MediaAsset>> loadMediaAssets() async {
    final d = await _db.db;
    final rows = await d.query('media_assets', orderBy: 'updated_at DESC');
    return rows.map(_mediaAssetFromRow).toList();
  }

  Future<void> saveAnalysisJob(MediaAnalysisJob job) async {
    final d = await _db.db;
    await d.insert(
      'media_analysis_jobs',
      _analysisJobRow(job),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MediaAnalysisJob>> loadAnalysisJobs(String mediaAssetId) async {
    final d = await _db.db;
    final rows = await d.query(
      'media_analysis_jobs',
      where: 'media_asset_id = ?',
      whereArgs: [mediaAssetId],
      orderBy: 'created_at DESC',
    );
    return rows.map(_analysisJobFromRow).toList();
  }

  Future<void> saveClipCandidate(ClipCandidate candidate) async {
    final d = await _db.db;
    await d.insert(
      'clip_candidates',
      _clipCandidateRow(candidate),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveClipCandidates(List<ClipCandidate> candidates) async {
    final d = await _db.db;
    final batch = d.batch();
    for (final candidate in candidates) {
      batch.insert(
        'clip_candidates',
        _clipCandidateRow(candidate),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<ClipCandidate>> loadClipCandidates(String mediaAssetId) async {
    final d = await _db.db;
    final rows = await d.query(
      'clip_candidates',
      where: 'media_asset_id = ?',
      whereArgs: [mediaAssetId],
      orderBy: 'score DESC, start_ms ASC',
    );
    return rows.map(_clipCandidateFromRow).toList();
  }

  Future<List<ClipCandidate>> loadCompatibleClipCandidates(
    String mediaAssetId,
  ) async {
    final candidates = await loadClipCandidates(mediaAssetId);
    final asset = await loadMediaAsset(mediaAssetId);
    if (asset == null) return candidates;

    final legacy = await _loadLegacyClipCandidates(asset);
    if (legacy.isEmpty) return candidates;

    final seenIds = candidates.map((candidate) => candidate.id).toSet();
    return [
      ...candidates,
      ...legacy.where((candidate) => seenIds.add(candidate.id)),
    ];
  }

  Future<List<ClipCandidate>> searchClipCandidates(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      final d = await _db.db;
      final rows = await d.query(
        'clip_candidates',
        orderBy: 'created_at DESC, score DESC',
      );
      return rows.map(_clipCandidateFromRow).toList();
    }

    final d = await _db.db;
    final like = '%${trimmed.replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
    final rows = await d.query(
      'clip_candidates',
      where:
          'title LIKE ? ESCAPE \'\\\' OR summary LIKE ? ESCAPE \'\\\' OR tags LIKE ? ESCAPE \'\\\' OR keywords LIKE ? ESCAPE \'\\\'',
      whereArgs: [like, like, like, like],
      orderBy: 'score DESC, start_ms ASC',
    );
    return rows.map(_clipCandidateFromRow).toList();
  }

  Future<void> saveClipExportRecord(ClipExportRecord record) async {
    final d = await _db.db;
    await d.insert(
      'clip_export_records',
      _clipExportRecordRow(record),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ClipExportRecord>> loadClipExportRecords(
    String mediaAssetId,
  ) async {
    final d = await _db.db;
    final rows = await d.query(
      'clip_export_records',
      where: 'media_asset_id = ?',
      whereArgs: [mediaAssetId],
      orderBy: 'created_at DESC',
    );
    return rows.map(_clipExportRecordFromRow).toList();
  }

  Future<List<ClipExportRecord>> loadCompatibleClipExportRecords(
    String mediaAssetId,
  ) async {
    final records = await loadClipExportRecords(mediaAssetId);
    final asset = await loadMediaAsset(mediaAssetId);
    if (asset == null) return records;

    final legacy = await _loadLegacyClipExportRecords(asset);
    if (legacy.isEmpty) return records;

    final seenIds = records.map((record) => record.id).toSet();
    return [...records, ...legacy.where((record) => seenIds.add(record.id))];
  }

  Future<void> deleteClipCandidate(String id) async {
    final d = await _db.db;
    await d.transaction((txn) async {
      await txn.delete(
        'clip_export_records',
        where: 'candidate_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'media_vector_records',
        where: 'target_type = ? AND target_id = ?',
        whereArgs: [MediaVectorTargetType.candidate.name, id],
      );
      await txn.delete('clip_candidates', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> deleteClipExportRecord(String id) async {
    final d = await _db.db;
    await d.delete('clip_export_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearClipResultsForAsset(String mediaAssetId) async {
    final d = await _db.db;
    await d.transaction((txn) async {
      await txn.delete(
        'media_analysis_jobs',
        where: 'media_asset_id = ?',
        whereArgs: [mediaAssetId],
      );
      await txn.delete(
        'clip_candidates',
        where: 'media_asset_id = ?',
        whereArgs: [mediaAssetId],
      );
      await txn.delete(
        'clip_export_records',
        where: 'media_asset_id = ?',
        whereArgs: [mediaAssetId],
      );
      await txn.delete(
        'media_vector_records',
        where: 'media_asset_id = ?',
        whereArgs: [mediaAssetId],
      );
      await txn.delete(
        'cloud_sync_tasks',
        where: 'media_asset_id = ?',
        whereArgs: [mediaAssetId],
      );
    });
  }

  Future<void> saveVectorRecord(MediaVectorRecord record) async {
    final d = await _db.db;
    await d.insert(
      'media_vector_records',
      _vectorRecordRow(record),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MediaVectorRecord>> loadVectorRecords(String mediaAssetId) async {
    final d = await _db.db;
    final rows = await d.query(
      'media_vector_records',
      where: 'media_asset_id = ?',
      whereArgs: [mediaAssetId],
      orderBy: 'created_at DESC',
    );
    return rows.map(_vectorRecordFromRow).toList();
  }

  Future<void> saveCloudConnectionConfig(CloudConnectionConfig config) async {
    final normalized = config.normalized();
    final d = await _db.db;
    await d.insert(
      'cloud_connection_configs',
      _cloudConnectionConfigRow(normalized),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CloudConnectionConfig>> loadCloudConnectionConfigs({
    bool enabledOnly = false,
  }) async {
    final d = await _db.db;
    final rows = await d.query(
      'cloud_connection_configs',
      where: enabledOnly ? 'enabled = 1' : null,
      orderBy: 'name ASC',
    );
    return rows.map(_cloudConnectionConfigFromRow).toList();
  }

  Future<void> saveCloudSyncTask(CloudSyncTask task) async {
    final d = await _db.db;
    await d.insert(
      'cloud_sync_tasks',
      _cloudSyncTaskRow(task),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CloudSyncTask>> loadCloudSyncTasks({
    String? mediaAssetId,
    CloudSyncStatus? status,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (mediaAssetId != null) {
      where.add('media_asset_id = ?');
      args.add(mediaAssetId);
    }
    if (status != null) {
      where.add('status = ?');
      args.add(status.name);
    }

    final d = await _db.db;
    final rows = await d.query(
      'cloud_sync_tasks',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
    );
    return rows.map(_cloudSyncTaskFromRow).toList();
  }

  Future<void> deleteMediaAsset(String id) async {
    final d = await _db.db;
    await d.delete('media_assets', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ClipCandidate>> _loadLegacyClipCandidates(
    MediaAsset asset,
  ) async {
    final rows = await (await _db.db).query(
      'clip_segments',
      where: 'source_task_id = ?',
      whereArgs: [asset.sourceTaskId],
      orderBy: 'created_at DESC, start_ms ASC',
    );
    return rows.map((row) {
      final segment = ClipSegment.fromJson(
        jsonDecode(row['data'] as String) as Map<String, Object?>,
      );
      return ClipCandidate(
        id: 'legacy:${segment.id}',
        mediaAssetId: asset.id,
        startMs: segment.effectiveStartMs,
        endMs: segment.effectiveEndMs,
        title: segment.title,
        summary: segment.summary,
        tags: segment.tags,
        keywords: segment.keywords,
        score: segment.confidence,
        scoreBreakdown: {'legacyConfidence': segment.confidence},
        evidenceIds: [
          'clip_segment:${segment.id}',
          ...segment.detections.map((detection) => 'detection:${detection.id}'),
          ...segment.transcripts.map(
            (transcript) => 'transcript:${transcript.id}',
          ),
        ],
        reason: segment.reason,
        source: ClipCandidateSource.legacy,
        createdAt: segment.createdAt,
      );
    }).toList();
  }

  Future<List<ClipExportRecord>> _loadLegacyClipExportRecords(
    MediaAsset asset,
  ) async {
    final rows = await (await _db.db).query(
      'clip_records',
      where: 'source_task_id = ?',
      whereArgs: [asset.sourceTaskId],
      orderBy: 'created_at DESC',
    );
    return rows.map((row) {
      final record = ClipRecord.fromJson(
        jsonDecode(row['data'] as String) as Map<String, Object?>,
      );
      return ClipExportRecord(
        id: 'legacy:${record.id}',
        mediaAssetId: asset.id,
        startMs: record.startMs,
        endMs: record.endMs,
        outputPath: record.outputPath ?? '',
        status: _mapLegacyClipRecordStatus(record.status),
        progress: record.progress,
        runtime: MediaJobRuntime.local,
        errorMessage: record.errorMessage,
        createdAt: record.createdAt,
        completedAt: record.completedAt,
      );
    }).toList();
  }

  ClipExportStatus _mapLegacyClipRecordStatus(ClipRecordStatus status) {
    return switch (status) {
      ClipRecordStatus.pending => ClipExportStatus.pending,
      ClipRecordStatus.cutting => ClipExportStatus.cutting,
      ClipRecordStatus.completed => ClipExportStatus.completed,
      ClipRecordStatus.failed => ClipExportStatus.failed,
    };
  }

  Map<String, Object?> _mediaAssetRow(MediaAsset asset) => {
    'id': asset.id,
    'source_task_id': asset.sourceTaskId,
    'source_url': asset.sourceUrl,
    'title': asset.title,
    'author': asset.author,
    'media_path': asset.mediaPath,
    'media_type': asset.mediaType.name,
    'file_sha256': asset.fileSha256,
    'duration_ms': asset.durationMs,
    'file_size_bytes': asset.fileSizeBytes,
    'thumbnail_path': asset.thumbnailPath,
    'created_at': asset.createdAt.toIso8601String(),
    'updated_at': asset.updatedAt.toIso8601String(),
    'data': jsonEncode(asset.toJson()),
  };

  MediaAsset _mediaAssetFromRow(Map<String, Object?> row) {
    return MediaAsset.fromJson(
      jsonDecode(row['data'] as String) as Map<String, Object?>,
    );
  }

  Map<String, Object?> _analysisJobRow(MediaAnalysisJob job) => {
    'id': job.id,
    'media_asset_id': job.mediaAssetId,
    'runtime': job.runtime.name,
    'status': job.status.name,
    'progress': job.progress,
    'created_at': job.createdAt.toIso8601String(),
    'updated_at': job.updatedAt.toIso8601String(),
    'data': jsonEncode(job.toJson()),
  };

  MediaAnalysisJob _analysisJobFromRow(Map<String, Object?> row) {
    return MediaAnalysisJob.fromJson(
      jsonDecode(row['data'] as String) as Map<String, Object?>,
    );
  }

  Map<String, Object?> _clipCandidateRow(ClipCandidate candidate) => {
    'id': candidate.id,
    'media_asset_id': candidate.mediaAssetId,
    'start_ms': candidate.startMs,
    'end_ms': candidate.endMs,
    'title': candidate.title,
    'summary': candidate.summary,
    'tags': jsonEncode(candidate.tags),
    'keywords': jsonEncode(candidate.keywords),
    'score': candidate.score,
    'source': candidate.source.name,
    'created_at': candidate.createdAt.toIso8601String(),
    'data': jsonEncode(candidate.toJson()),
  };

  ClipCandidate _clipCandidateFromRow(Map<String, Object?> row) {
    return ClipCandidate.fromJson(
      jsonDecode(row['data'] as String) as Map<String, Object?>,
    );
  }

  Map<String, Object?> _clipExportRecordRow(ClipExportRecord record) => {
    'id': record.id,
    'media_asset_id': record.mediaAssetId,
    'candidate_id': record.candidateId,
    'start_ms': record.startMs,
    'end_ms': record.endMs,
    'output_path': record.outputPath,
    'status': record.status.name,
    'progress': record.progress,
    'runtime': record.runtime.name,
    'cloud_job_id': record.cloudJobId,
    'created_at': record.createdAt.toIso8601String(),
    'completed_at': record.completedAt?.toIso8601String(),
    'data': jsonEncode(record.toJson()),
  };

  ClipExportRecord _clipExportRecordFromRow(Map<String, Object?> row) {
    return ClipExportRecord.fromJson(
      jsonDecode(row['data'] as String) as Map<String, Object?>,
    );
  }

  Map<String, Object?> _vectorRecordRow(MediaVectorRecord record) => {
    'id': record.id,
    'media_asset_id': record.mediaAssetId,
    'target_type': record.targetType.name,
    'target_id': record.targetId,
    'start_ms': record.startMs,
    'end_ms': record.endMs,
    'modality': record.modality.name,
    'model': record.model,
    'dimension': record.dimension,
    'created_at': record.createdAt.toIso8601String(),
    'data': jsonEncode(record.toJson()),
  };

  MediaVectorRecord _vectorRecordFromRow(Map<String, Object?> row) {
    return MediaVectorRecord.fromJson(
      jsonDecode(row['data'] as String) as Map<String, Object?>,
    );
  }

  Map<String, Object?> _cloudConnectionConfigRow(
    CloudConnectionConfig config,
  ) => {
    'id': config.id,
    'name': config.name,
    'base_url': config.baseUrl,
    'device_name': config.deviceName,
    'enabled': config.enabled ? 1 : 0,
    'upload_policy': config.uploadPolicy.name,
    'paired_at': config.pairedAt?.toIso8601String(),
    'data': jsonEncode(config.toJson()),
  };

  CloudConnectionConfig _cloudConnectionConfigFromRow(
    Map<String, Object?> row,
  ) {
    return CloudConnectionConfig.fromJson(
      jsonDecode(row['data'] as String) as Map<String, Object?>,
    );
  }

  Map<String, Object?> _cloudSyncTaskRow(CloudSyncTask task) => {
    'id': task.id,
    'media_asset_id': task.mediaAssetId,
    'type': task.type.name,
    'status': task.status.name,
    'idempotency_key': task.idempotencyKey,
    'uploaded_bytes': task.uploadedBytes,
    'total_bytes': task.totalBytes,
    'cloud_media_id': task.cloudMediaId,
    'cloud_job_id': task.cloudJobId,
    'created_at': task.createdAt.toIso8601String(),
    'updated_at': task.updatedAt.toIso8601String(),
    'data': jsonEncode(task.toJson()),
  };

  CloudSyncTask _cloudSyncTaskFromRow(Map<String, Object?> row) {
    return CloudSyncTask.fromJson(
      jsonDecode(row['data'] as String) as Map<String, Object?>,
    );
  }
}
