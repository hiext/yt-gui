# Auto-Clip Architecture Document

> **Branch**: `feat/auto-clip` | **Based on**: [DESIGN.md](./DESIGN.md) | [PRD.md](./PRD.md)

## 1. System Context

```
┌──────────────────────────────────────────────────────────────────┐
│                        Hiext YT GUI                              │
│                                                                  │
│  ┌──────────────┐   ┌──────────────────┐   ┌──────────────────┐ │
│  │ DownloadCtrl │──→│ PostProcessCtrl  │──→│ AutoClipService  │ │
│  │              │   │                  │   │ (NEW)            │ │
│  │ yt-dlp       │   │ AiAnalysis       │   │ FFmpeg cutting   │ │
│  └──────────────┘   └──────────────────┘   └────────┬─────────┘ │
│                                                      │           │
│  ┌──────────────┐   ┌──────────────────┐   ┌────────▼─────────┐ │
│  │ SettingsPage │   │ ClipLibraryPage  │   │ ClipRecordRepo   │ │
│  │              │   │                  │   │ (NEW)            │ │
│  │ AutoClip     │   │ Cut buttons      │   │ SQLite storage   │ │
│  │ Config UI    │   │ Progress bars    │   │                  │ │
│  └──────────────┘   └──────────────────┘   └──────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

## 2. Component Design

### 2.1 AutoClipService

```
┌─────────────────────────────────────────────────────┐
│                AutoClipService                      │
│                                                     │
│  Dependencies:                                      │
│  - FfmpegClipExecutor (injected)                    │
│  - ClipRecordRepository (injected)                  │
│  - AutoClipConfig (from settings)                   │
│                                                     │
│  State:                                             │
│  - List<ClipRecord> records                         │
│  - Map<String, Process> activeProcesses             │
│                                                     │
│  Entry Points:                                      │
│  → startAutoCut(segments, settings)                 │
│  → cutSingle(segment, settings)                     │
│  → cutBatch(segments)                               │
│  → cancel(recordId)                                 │
│                                                     │
│  Callbacks:                                         │
│  → onProgress(recordId, progress)                   │
│  → onComplete(recordId, outputPath)                 │
│  → onError(recordId, error)                         │
└─────────────────────────────────────────────────────┘
```

### 2.2 Data Flow

```
                    PostProcessController
                           │
            _handleAnalysisComplete(task)
                           │
                    ┌──────┴──────┐
                    │             │
              autoCutEnabled?    │
              ┌───┴───┐         │
              │ YES   │ NO      │
              ▼       ▼         │
        AutoClipSvc  Skip       │
              │                 │
    ┌─────────┼─────────┐      │
    │         │         │      │
  Filter  Limit    Create     │
  by      count    ClipTask   │
  conf             for each   │
    │         │         │      │
    └─────────┼─────────┘      │
              ▼                │
    FfmpegClipExecutor         │
    .startTask() × N           │
              │                │
              ▼                │
    ClipRecordRepository       │
    .save() × N                │
              │                │
              ▼                │
    notifyListeners() ─────────┘
              │
              ▼
    ClipLibraryPage rebuilds
```

### 2.3 State Machine

```
                    ┌─────────┐
                    │ PENDING │ ← initial state
                    └────┬────┘
                         │ startAutoCut() / cutSingle()
                         ▼
                    ┌─────────┐
                    │ CUTTING │
                    └────┬────┘
                    ┌────┴────┐
                    │         │
                    ▼         ▼
              ┌─────────┐ ┌────────┐
              │COMPLETED│ │ FAILED │
              └─────────┘ └────────┘
```

## 3. Interface Contracts

### 3.1 AutoClipService Interface

```dart
abstract class IAutoClipService {
  AutoClipConfig get config;

  /// Start automatic cutting for qualifying segments.
  /// Returns list of created ClipRecords (status: pending→cutting→completed/failed).
  Future<List<ClipRecord>> startAutoCut({
    required List<ClipSegment> segments,
    required DownloadSettings settings,
    void Function(String recordId, double progress)? onProgress,
    void Function(String recordId, ClipRecordStatus status)? onStatusChanged,
  });

  /// Cut a single clip segment.
  Future<ClipRecord> cutSingle({
    required ClipSegment segment,
    required DownloadSettings settings,
    void Function(double progress)? onProgress,
  });

  /// Cancel an active cutting operation.
  Future<void> cancel(String recordId);

  /// Load clip records for a source download task.
  Future<List<ClipRecord>> loadRecords({String? sourceTaskId});

  void dispose();
}
```

### 3.2 ClipRecordRepository Interface

```dart
abstract class IClipRecordRepository {
  Future<void> save(ClipRecord record);
  Future<void> saveAll(List<ClipRecord> records);
  Future<List<ClipRecord>> loadBySourceTask(String sourceTaskId);
  Future<List<ClipRecord>> loadAll();
  Future<void> updateStatus(String id, ClipRecordStatus status, {int? progress, String? errorMessage, String? outputPath});
  Future<void> delete(String id);
}
```

### 3.3 PostProcessController Extension Points

```dart
// In PostProcessController:

// NEW method: called when AI analysis task completes
void _handleAnalysisComplete(PostProcessTask task) {
  if (task.clipSegments.isEmpty) return;

  final config = settingsProvider().autoClipConfig;
  if (config.enabled) {
    _autoClipService?.startAutoCut(
      segments: task.clipSegments,
      settings: settingsProvider(),
      onProgress: (recordId, progress) {
        _updateClipRecordProgress(recordId, progress);
      },
      onStatusChanged: (recordId, status) {
        _updateClipRecordStatus(recordId, status);
      },
    );
  }

  _clipRecords = _autoClipService?.records ?? [];
  notifyListeners();
}
```

## 4. Database Migration (v3 → v4)

```sql
-- Migration: version 3 → 4
-- New table for clip records

CREATE TABLE IF NOT EXISTS clip_records (
  id TEXT PRIMARY KEY,
  source_task_id TEXT NOT NULL,
  source_path TEXT NOT NULL,
  output_path TEXT,
  title TEXT NOT NULL,
  confidence REAL NOT NULL DEFAULT 0,
  start_ms INTEGER NOT NULL,
  end_ms INTEGER NOT NULL,
  duration_ms INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  progress INTEGER NOT NULL DEFAULT 0,
  error_message TEXT,
  created_at TEXT NOT NULL,
  completed_at TEXT,
  data TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_clip_records_source
  ON clip_records(source_task_id);

CREATE INDEX IF NOT EXISTS idx_clip_records_status
  ON clip_records(status);
```

## 5. Error Handling Strategy

| Scenario | Behavior |
|----------|----------|
| FFmpeg binary not found | Catch `EmbeddedToolResolutionException`, mark all records as `failed` with descriptive error |
| Single clip cut fails | Mark that record as `failed`, continue with remaining clips |
| All clips fail | Mark all as `failed`, notify user via SnackBar |
| Settings not configured | Use `AutoClipConfig.defaults` |
| Disk space low | Check available space before batch, warn if < 1GB free |

## 6. Threading Model

All FFmpeg operations run asynchronously via `Process.start()`. The `AutoClipService`:
- Does NOT use isolates (FFmpeg is a separate process)
- Executes cuts **serially** by default (one clip at a time)
- Future enhancement: `concurrentClipCuts` setting for parallel cutting
