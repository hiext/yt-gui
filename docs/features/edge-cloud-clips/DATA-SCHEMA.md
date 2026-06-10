# Data Schema: 媒体资产、向量与同步模型

## 1. 设计目标

- 同时支持本地分析、本地切片、云端切片和结果同步。
- 支持视频和纯音频。
- 支持结构化检索和向量检索。
- 支持旧切片数据迁移。
- 支持原片不上传的云端任务。

## 2. MediaAsset

媒体资产是下载结果的根对象。

```dart
class MediaAsset {
  final String id;
  final String sourceTaskId;
  final String sourceUrl;
  final String title;
  final String? author;
  final String mediaPath;
  final String mediaType; // video | audio
  final String fileSha256;
  final int durationMs;
  final int fileSizeBytes;
  final String? thumbnailPath;
  final Map<String, Object?> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

关键约束：

- `fileSha256` 用于重复识别和上传校验。
- `metadata` 保存 yt-dlp info、ffprobe 流信息、章节、字幕入口等扩展信息。
- `sourceTaskId` 关联原下载任务。

## 3. MediaAnalysisJob

本地或云端分析任务。

```dart
class MediaAnalysisJob {
  final String id;
  final String mediaAssetId;
  final String runtime; // local | cloud
  final String status; // queued | running | completed | failed | cancelled
  final double progress;
  final List<String> stages;
  final String? errorMessage;
  final String? manifestPath;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

阶段建议：

- metadata
- transcript
- scene
- audio
- visual
- candidate
- embedding
- export

## 4. ClipCandidate

候选切片，不等同已导出的文件。

```dart
class ClipCandidate {
  final String id;
  final String mediaAssetId;
  final int startMs;
  final int endMs;
  final String title;
  final String summary;
  final List<String> tags;
  final List<String> keywords;
  final double score;
  final Map<String, double> scoreBreakdown;
  final List<String> evidenceIds;
  final String reason;
  final String source; // local | cloud | user
  final DateTime createdAt;
}
```

评分维度：

- semantic
- boundary
- density
- novelty
- platformFit
- userIntent

## 5. ClipExportRecord

已导出的切片文件。

```dart
class ClipExportRecord {
  final String id;
  final String mediaAssetId;
  final String? candidateId;
  final int startMs;
  final int endMs;
  final String outputPath;
  final String status; // pending | cutting | completed | failed
  final int progress;
  final String runtime; // local | cloud
  final String? cloudJobId;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;
}
```

约束：

- 同一个 candidate 可以导出多个版本。
- 本地和云端导出统一进入此模型。

## 6. MediaVectorRecord

向量记录用于语义检索和智能推荐。

```dart
class MediaVectorRecord {
  final String id;
  final String mediaAssetId;
  final String targetType; // media | transcript | frame | candidate | export
  final String targetId;
  final int? startMs;
  final int? endMs;
  final String modality; // text | image | audio | multimodal
  final String model;
  final int dimension;
  final List<double> vector;
  final Map<String, Object?> payload;
  final DateTime createdAt;
}
```

MVP 存储策略：

- SQLite 保存 metadata 和 payload。
- 向量可先保存为 JSON 或 BLOB。
- 后续抽象到本地向量库或云端向量库。

## 7. CloudConnectionConfig

个人云端连接配置。

```dart
class CloudConnectionConfig {
  final String id;
  final String name;
  final String baseUrl;
  final String deviceName;
  final String? accessToken;
  final bool enabled;
  final String uploadPolicy; // manifestOnly | selectedClips | originalOnConfirm
  final int maxConcurrentSync;
  final DateTime? pairedAt;
}
```

安全要求：

- Token 不写入日志。
- 导出诊断信息时必须脱敏。

## 8. CloudSyncTask

同步任务。

```dart
class CloudSyncTask {
  final String id;
  final String mediaAssetId;
  final String type; // uploadManifest | uploadClip | uploadOriginal | pullResult
  final String status; // pending | uploading | queued | running | completed | failed | cancelled
  final String idempotencyKey;
  final int uploadedBytes;
  final int totalBytes;
  final String? cloudMediaId;
  final String? cloudJobId;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

## 9. Manifest 草案

```json
{
  "schemaVersion": 1,
  "mediaAsset": {},
  "analysis": {
    "runtime": "local",
    "stages": []
  },
  "timeline": [],
  "clipCandidates": [],
  "clipExports": [],
  "vectors": {
    "count": 0,
    "externalPath": ".hiext/vectors.jsonl"
  },
  "toolVersions": {},
  "errors": []
}
```

## 10. 数据库表建议

- `media_assets`
- `media_analysis_jobs`
- `media_timeline_items`
- `clip_candidates`
- `clip_export_records`
- `media_vector_records`
- `cloud_connection_configs`
- `cloud_sync_tasks`

## 11. 迁移策略

- 旧 `clip_segments` 可映射为 `ClipCandidate`。
- 旧 `clip_records` 可映射为 `ClipExportRecord`。
- 旧数据首版只读展示，后续再提供显式迁移命令。

## 12. 下一步

- 为每个模型补充 `toJson/fromJson` 字段规范。
- 设计 SQLite migration 版本号。
- 确认向量存储是否先采用 JSONL 外部文件。
