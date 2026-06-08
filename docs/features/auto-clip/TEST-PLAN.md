# Auto-Clip Test Plan

> **Branch**: `feat/auto-clip`

## 1. Test Strategy

| Layer | Tool | Coverage Target | File Pattern |
|-------|------|-----------------|-------------|
| Unit (models) | `flutter_test` | 95%+ | `test/core/models/auto_clip_config_test.dart` |
| Unit (services) | `flutter_test` + fake executor | 90%+ | `test/core/services/auto_clip_service_test.dart` |
| Unit (repository) | `flutter_test` + in-memory SQLite | 90%+ | `test/core/services/clip_record_repository_test.dart` |
| Widget | `flutter_test` | 80%+ | `test/features/clips/clip_library_page_test.dart` |
| Widget | `flutter_test` | 80%+ | `test/features/settings/settings_page_test.dart` |
| Integration | `integration_test` | Happy path | `integration_test/auto_clip_test.dart` |

## 2. Unit Tests

### 2.1 AutoClipConfig

```
File: test/core/models/auto_clip_config_test.dart

Test Cases:
├── defaults have expected values
├── copyWith overrides individual fields
├── copyWith preserves unchanged fields
├── toJson produces correct JSON
├── fromJson parses complete JSON
├── fromJson applies defaults for missing fields
├── fromJson handles invalid values gracefully
└── serialization round-trip preserves all fields
```

### 2.2 ClipRecord

```
File: test/core/models/clip_record_test.dart (add to existing app_models tests)

Test Cases:
├── constructor sets all fields correctly
├── copyWith overrides individual fields
├── toJson produces correct JSON
├── fromJson parses complete JSON
├── createdAt defaults to now when not provided
└── serialization round-trip preserves all fields
```

### 2.3 AutoClipService

```
File: test/core/services/auto_clip_service_test.dart

Test Cases:
├── startAutoCut filters by confidence
│   ├── clips below threshold are skipped
│   ├── clips at threshold are included
│   └── clips above threshold are included
├── startAutoCut limits count
│   ├── respects maxClipsPerVideo
│   └── selects highest confidence when exceeding limit
├── startAutoCut applies offsets
│   ├── startOffset shifts start time
│   └── endOffset shifts end time
├── startAutoCut respects max duration
│   └── clips exceeding maxClipDurationSec are truncated
├── startAutoCut creates ClipRecords
│   ├── records start in pending status
│   └── records transition to cutting → completed
├── startAutoCut handles empty segments list
├── startAutoCut handles all-below-threshold segments
├── cutSingle creates and executes one ClipRecord
├── cutSingle reports progress via callback
├── cancel stops active cut
├── cancel sets record status to failed
├── loadRecords returns filtered results
└── dispose cleans up resources

Fake Dependencies:
├── _FakeFfmpegClipExecutor (mimics FfmpegClipExecutor without real FFmpeg)
└── _FakeClipRecordRepository (in-memory list, no SQLite)
```

### 2.4 ClipRecordRepository

```
File: test/core/services/clip_record_repository_test.dart

Test Cases:
├── save persists a ClipRecord
├── saveAll persists multiple records
├── loadBySourceTask filters correctly
├── loadAll returns all records
├── updateStatus modifies status, progress, error, outputPath
├── updateStatus non-existent ID is no-op
├── delete removes record
└── delete non-existent ID is no-op

Database Setup:
└── Uses in-memory SQLite via sqlite_test_setup.dart
```

### 2.5 AutoClipConfig in DownloadSettings

```
File: test/core/models/download_settings_test.dart (add to existing)

Test Cases:
├── autoClipConfig defaults to AutoClipConfig.defaults
├── autoClipConfig survives serialization round-trip
├── legacy JSON (without autoClipConfig) uses defaults
└── partial JSON (some fields missing) fills defaults
```

## 3. Widget Tests

### 3.1 Settings Page — Auto-Clip Section

```
File: test/features/settings/settings_page_test.dart (extend)

Test Cases:
├── renders auto-clip section when scrolled to
├── enabled toggle shows/hides controls
│   ├── when disabled, other controls are greyed out
│   └── when enabled, other controls are interactive
├── confidence slider updates value
├── max clips slider updates value
├── max duration slider updates value
├── start offset field accepts input
├── end offset field accepts input
└── settings persist through controller.updateAutoClipConfig()
```

### 3.2 Clip Library — Cut Buttons

```
File: test/features/clips/clip_library_page_test.dart (extend)

Test Cases:
├── renders per-clip "Cut" button when clip not yet cut
├── shows "Cutting..." progress bar during active cut
├── shows "✅ Completed" status after successful cut
├── shows "❌ Failed" status after failed cut
├── renders "Cut All (N)" batch button
├── "Cut All" button hidden when no uncut clips
├── "Cut All" button triggers autoCutService.cutBatch()
├── batch progress shows "Cutting 2/5..."
└── status chips update after cut operations
```

### 3.3 PostProcessController Integration

```
File: test/core/controllers/post_process_controller_test.dart (extend)

Test Cases:
├── auto-cut triggered when analysis completes and auto-clip enabled
├── auto-cut NOT triggered when auto-clip disabled
├── auto-clip service receives correct segments
└── clip records updated in controller state
```

## 4. Integration Tests

```
File: integration_test/auto_clip_test.dart

Test Scenarios:
├── E2E: Download → Auto-Analyze → Auto-Cut → Verify output files
│   (Requires: real yt-dlp, ffmpeg, network, short test video)
└── E2E: Manual Cut All flow
    (Requires: pre-analyzed clips, real ffmpeg)

Note: Integration tests require real binaries and network access.
      Mark with @Skip in CI unless binaries are available.
```

## 5. Test Data

### Sample ClipSegment for Tests

```dart
const testClipSegment = ClipSegment(
  id: 'test-seg-1',
  sourceTaskId: 'test-dl-1',
  postProcessTaskId: 'test-pp-1',
  sourcePath: '/tmp/test-video.mp4',
  startMs: 15000,
  endMs: 45000,
  title: 'Test Highlight',
  summary: 'A test highlight segment',
  keywords: ['test', 'highlight'],
  tags: ['demo'],
  confidence: 0.85,
  reason: 'test data',
);
```

### Sample AutoClipConfig for Tests

```dart
const strictConfig = AutoClipConfig(
  enabled: true,
  minConfidence: 0.9,
  maxClipsPerVideo: 3,
  maxClipDurationSec: 30,
  startOffsetMs: -1000,
  endOffsetMs: 1000,
);

const lenientConfig = AutoClipConfig(
  enabled: true,
  minConfidence: 0.3,
  maxClipsPerVideo: 10,
  maxClipDurationSec: 120,
  startOffsetMs: 0,
  endOffsetMs: 0,
);
```

## 6. Coverage Targets

| File | Current | Target | Delta |
|------|---------|--------|-------|
| `auto_clip_service.dart` | 0% (new) | 90%+ | +90% |
| `clip_record_repository.dart` | 0% (new) | 90%+ | +90% |
| `app_models.dart` (new types) | 88.9% | 90%+ | +1.1% |
| `post_process_controller.dart` | 88.7% | 90%+ | +1.3% |
| `settings_page.dart` | 73.7% | 80%+ | +6.3% |
| `clip_library_page.dart` | 96.6% | 96%+ | maintain |
| **Overall project** | 78.9% | 80%+ | +1.1% |
