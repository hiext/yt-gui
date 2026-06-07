# Auto-Clip Implementation Tasks

> Branch: `feat/auto-clip` | Based on [DESIGN.md](./DESIGN.md)

## Phase 1: Data Layer

### 1.1 Add AutoClipConfig to DownloadSettings
- File: `lib/core/models/app_models.dart`
- Add `AutoClipConfig` class with fields: `enabled`, `minConfidence`, `maxClipsPerVideo`, `maxClipDurationSec`, `startOffsetMs`, `endOffsetMs`
- Add `autoClipConfig` field to `DownloadSettings`
- Implement serialization/deserialization
- **Estimate**: 1 file, ~80 lines

### 1.2 Add ClipRecord model
- File: `lib/core/models/app_models.dart`
- Add `ClipRecord` class with fields per DESIGN.md
- Add `ClipRecordStatus` enum
- Implement `toJson()`/`fromJson()`
- **Estimate**: 1 file, ~60 lines

### 1.3 Add clip_records DB migration (v4)
- File: `lib/core/services/database_service.dart`
- Add `_createClipRecordsTable()` method
- Bump version to 4, add migration logic
- **Estimate**: 1 file, ~30 lines

### 1.4 Implement ClipRecordRepository
- New file: `lib/core/services/clip_record_repository.dart`
- Methods: `save()`, `loadBySourceTask()`, `loadAll()`, `updateStatus()`, `delete()`
- **Estimate**: 1 new file, ~80 lines

## Phase 2: Core Service

### 2.1 Implement AutoClipService
- New file: `lib/core/services/auto_clip_service.dart`
- Methods per DESIGN.md §7
- Integration with FfmpegClipExecutor
- Progress callback mechanism
- **Estimate**: 1 new file, ~150 lines

### 2.2 Wire into PostProcessController
- File: `lib/core/controllers/post_process_controller.dart`
- Add `_handleAnalysisComplete()` method
- Call `AutoClipService.startAutoCut()` when analysis completes
- Emit progress updates
- **Estimate**: 1 file, ~50 lines

### 2.3 Wire into DownloadController
- File: `lib/core/controllers/download_controller.dart`
- Pass `autoClipConfig` settings through
- **Estimate**: 1 file, ~10 lines

## Phase 3: Settings UI

### 3.1 Add Auto-Clip settings section
- File: `lib/features/settings/settings_page.dart`
- New `SectionCard` for auto-clip config
- Toggle for `enabled`
- Sliders for `minConfidence`, `maxClipsPerVideo`, `maxClipDurationSec`
- Text fields for `startOffsetMs`, `endOffsetMs`
- **Estimate**: 1 file, ~100 lines

## Phase 4: ClipLibrary UI

### 4.1 Add per-clip cut button
- File: `lib/features/clips/clip_library_page.dart`
- Each `_ClipSegmentCard` gets a "Cut This Clip" button
- Shows status (pending/cutting/completed/failed)
- **Estimate**: 1 file, ~60 lines

### 4.2 Add "Cut All" button
- File: `lib/features/clips/clip_library_page.dart`
- Summary bar with "Cut All (N)" button
- Progress indicator for batch cutting
- **Estimate**: 1 file, ~40 lines

### 4.3 Show progress bars
- File: `lib/features/clips/clip_library_page.dart`
- Linear progress per clip card
- Status chips
- **Estimate**: 1 file, ~30 lines

## Phase 5: Testing

### 5.1 Unit tests
- `test/core/services/auto_clip_service_test.dart`
- `test/core/services/clip_record_repository_test.dart`
- `test/core/models/auto_clip_config_test.dart`
- **Estimate**: 3 new files, ~200 lines

### 5.2 Widget tests
- `test/features/clips/clip_library_page_test.dart` (expand)
- `test/features/settings/settings_page_test.dart` (expand)
- **Estimate**: 2 files, ~150 lines

## Summary

| Phase | Files | Est. Lines | Priority |
|-------|-------|-----------|----------|
| 1. Data Layer | 3 files | ~250 | P0 |
| 2. Core Service | 3 files | ~210 | P0 |
| 3. Settings UI | 1 file | ~100 | P1 |
| 4. ClipLibrary UI | 1 file | ~130 | P1 |
| 5. Testing | 5 files | ~350 | P1 |
| **Total** | **6 new + 7 modified** | **~1040** | |
