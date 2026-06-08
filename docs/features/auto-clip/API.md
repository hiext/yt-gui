# Auto-Clip API Reference

> **Branch**: `feat/auto-clip`

## 1. AutoClipConfig

### Definition
```dart
class AutoClipConfig {
  const AutoClipConfig({
    this.enabled = true,
    this.minConfidence = 0.7,
    this.maxClipsPerVideo = 5,
    this.maxClipDurationSec = 60,
    this.startOffsetMs = -500,
    this.endOffsetMs = 500,
  });

  /// Master switch for automatic clip cutting
  final bool enabled;

  /// Minimum confidence threshold (0.0-1.0)
  /// Only clips with confidence >= this value are auto-cut
  final double minConfidence;

  /// Maximum number of clips to auto-cut per video
  /// 0 = unlimited, clips sorted by confidence descending
  final int maxClipsPerVideo;

  /// Maximum duration per clip in seconds
  /// Clips longer than this are truncated
  final int maxClipDurationSec;

  /// Milliseconds to add BEFORE the detected start time
  /// Negative = start earlier (default: -500ms)
  final int startOffsetMs;

  /// Milliseconds to add AFTER the detected end time
  /// Positive = extend later (default: +500ms)
  final int endOffsetMs;

  static const defaults = AutoClipConfig();

  AutoClipConfig copyWith({...});
  Map<String, Object?> toJson();
  factory AutoClipConfig.fromJson(Map<String, Object?> json);
}
```

### Default Values Rationale
| Field | Default | Rationale |
|-------|---------|-----------|
| `enabled` | `true` | Opt-out by default — users expect automation |
| `minConfidence` | `0.7` | Balanced: filters noise without being too strict |
| `maxClipsPerVideo` | `5` | Prevents resource exhaustion on long videos |
| `maxClipDurationSec` | `60` | Aligns with Shorts/Reels/TikTok format |
| `startOffsetMs` | `-500` | Catches slightly late AI boundary detection |
| `endOffsetMs` | `500` | Same, for end boundary |

### JSON Representation
```json
{
  "enabled": true,
  "minConfidence": 0.7,
  "maxClipsPerVideo": 5,
  "maxClipDurationSec": 60,
  "startOffsetMs": -500,
  "endOffsetMs": 500
}
```

## 2. ClipRecord

### Definition
```dart
class ClipRecord {
  const ClipRecord({
    required this.id,
    required this.sourceTaskId,
    required this.sourcePath,
    this.outputPath,
    required this.title,
    required this.confidence,
    required this.startMs,
    required this.endMs,
    required this.durationMs,
    this.status = ClipRecordStatus.pending,
    this.progress = 0,
    this.errorMessage,
    DateTime? createdAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String sourceTaskId;
  final String sourcePath;
  final String? outputPath;
  final String title;
  final double confidence;
  final int startMs;
  final int endMs;
  final int durationMs;
  final ClipRecordStatus status;
  final int progress;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;

  ClipRecord copyWith({...});
  Map<String, Object?> toJson();
  factory ClipRecord.fromJson(Map<String, Object?> json);
}

enum ClipRecordStatus {
  pending,   // Not yet started
  cutting,   // FFmpeg is running
  completed, // Successfully cut
  failed,    // Error occurred
}
```

## 3. AutoClipService

### Constructor
```dart
AutoClipService({
  FfmpegClipExecutor? executor,           // Injected, defaults to new instance
  ClipRecordRepository? repository,       // Injected, defaults to new instance
  AutoClipConfig? config,                 // Override config for testing
});
```

### Methods

#### startAutoCut
```dart
/// Start automatic cutting for qualifying segments.
///
/// Returns list of created ClipRecords.
/// Each record progresses: pending → cutting → completed/failed
///
/// Throws [AutoClipException] if FFmpeg is unavailable.
Future<List<ClipRecord>> startAutoCut({
  required List<ClipSegment> segments,
  required DownloadSettings settings,
  void Function(String recordId, double progress)? onProgress,
  void Function(String recordId, ClipRecordStatus status)? onStatusChanged,
});
```

#### cutSingle
```dart
/// Cut a single clip segment manually.
///
/// Returns a ClipRecord tracking the operation.
/// Listeners are notified on status changes.
Future<ClipRecord> cutSingle({
  required ClipSegment segment,
  required DownloadSettings settings,
  void Function(double progress)? onProgress,
});
```

#### cancel
```dart
/// Cancel an active cutting operation.
///
/// Sends SIGTERM to the FFmpeg process.
/// Sets the record status to [ClipRecordStatus.failed].
Future<void> cancel(String recordId);
```

#### loadRecords
```dart
/// Load clip records, optionally filtered by source download task.
Future<List<ClipRecord>> loadRecords({String? sourceTaskId});
```

## 4. ClipRecordRepository

### Constructor
```dart
ClipRecordRepository({DatabaseService? db});
```

### Methods
```dart
Future<void> save(ClipRecord record);
Future<void> saveAll(List<ClipRecord> records);
Future<List<ClipRecord>> loadBySourceTask(String sourceTaskId);
Future<List<ClipRecord>> loadAll();
Future<void> updateStatus(String id, ClipRecordStatus status, {
  int? progress,
  String? errorMessage,
  String? outputPath,
});
Future<void> delete(String id);
```

## 5. DownloadSettings Integration

### New Field
```dart
class DownloadSettings {
  // ... existing fields ...
  final AutoClipConfig autoClipConfig;  // NEW

  const DownloadSettings({
    // ... existing params ...
    this.autoClipConfig = AutoClipConfig.defaults,  // NEW
  });
}
```

### Serialization
```json
{
  // ... existing fields ...
  "autoClipConfig": {
    "enabled": true,
    "minConfidence": 0.7,
    "maxClipsPerVideo": 5,
    "maxClipDurationSec": 60,
    "startOffsetMs": -500,
    "endOffsetMs": 500
  }
}
```
