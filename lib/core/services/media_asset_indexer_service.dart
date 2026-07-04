import 'dart:io';

import 'package:crypto/crypto.dart';

import '../models/app_models.dart';
import 'media_asset_repository.dart';

class MediaAssetIndexerService {
  MediaAssetIndexerService({MediaAssetRepository? repository})
    : _repository = repository ?? MediaAssetRepository();

  final MediaAssetRepository _repository;

  Future<MediaAsset?> indexCompletedDownload(DownloadTask task) async {
    final mediaPath = task.mediaPath?.trim();
    if (mediaPath == null || mediaPath.isEmpty) return null;

    final file = File(mediaPath);
    if (!file.existsSync()) return null;

    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) return null;

    final variant = task.variants.isNotEmpty ? task.variants.first : null;
    final now = DateTime.now();
    final existing = await _repository.loadMediaAssetBySourceTask(task.id);
    final asset = MediaAsset(
      id: existing?.id ?? _stableMediaAssetId(task.id),
      sourceTaskId: task.id,
      sourceUrl: task.source,
      title: task.title.trim().isEmpty
          ? variant?.videoTitle ?? file.uri.pathSegments.last
          : task.title,
      mediaPath: mediaPath,
      mediaType: _inferMediaType(mediaPath, variant),
      fileSha256: await _sha256(file),
      durationMs: existing?.durationMs ?? 0,
      fileSizeBytes: stat.size,
      thumbnailPath: existing?.thumbnailPath,
      metadata: {
        ...?existing?.metadata,
        'downloadStatus': task.status.name,
        'source': task.source,
        if (variant?.formatId != null) 'formatId': variant!.formatId,
        if (variant?.label != null) 'variantLabel': variant!.label,
        if (variant?.description != null)
          'variantDescription': variant!.description,
        if (variant?.videoId != null) 'videoId': variant!.videoId,
        if (variant?.videoTitle != null) 'videoTitle': variant!.videoTitle,
        if (variant?.height != null) 'height': variant!.height,
        if (variant?.filesize != null) 'expectedFileSize': variant!.filesize,
        'indexedAt': now.toIso8601String(),
      },
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    await _repository.saveMediaAsset(asset);
    return asset;
  }

  String _stableMediaAssetId(String sourceTaskId) {
    final sanitized = sourceTaskId
        .replaceAll(RegExp(r'[^A-Za-z0-9_.-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return 'media-${sanitized.isEmpty ? sourceTaskId.hashCode : sanitized}';
  }

  MediaAssetType _inferMediaType(String mediaPath, ResourceVariant? variant) {
    if (variant?.type == ResourceType.audio) return MediaAssetType.audio;
    if (variant?.type == ResourceType.video) return MediaAssetType.video;

    final lower = mediaPath.toLowerCase();
    if (lower.endsWith('.mp3') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.flac') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.opus')) {
      return MediaAssetType.audio;
    }
    return MediaAssetType.video;
  }

  Future<String> _sha256(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}
