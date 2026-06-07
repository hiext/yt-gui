# PRD: Automated Clip Cutting (自动化切片)

> **Version**: 1.0 | **Status**: Draft | **Branch**: `feat/auto-clip` | **Date**: 2026-06-07

## 1. Problem Statement

### 1.1 Current State
After downloading a video with Hiext YT GUI, the clip workflow requires **manual intervention at every step**:

```
Download Complete → [Manual] Open Clips tab → [Wait] AI Analysis → [Manual] Review clips → [Manual] Click cut for each clip → [Manual] Find output files
```

### 1.2 Pain Points
| Pain Point | Impact |
|------------|--------|
| Multi-step manual process | Users must remember to trigger analysis |
| No automation after download | Clips are analyzed but never cut |
| Per-clip manual cutting | Tedious for videos with 5+ clips |
| No progress visibility | Users don't know cut status |
| No result history | Cut clips info not persisted |

### 1.3 Desired State
```
Download Complete → [Auto] AI Analysis → [Auto] Cut clips → [Auto] Save records → User opens output folder
```

## 2. User Stories

### US-1: Auto-Cut After Download
> As a user, I want clips to be automatically cut after download completes, so I don't need to remember to do it manually.

**Acceptance Criteria**:
- When auto-cut is enabled in settings, clips are cut immediately after AI analysis
- Only clips above the configured confidence threshold are cut
- Cut clips are saved to `<source_dir>/.clips/` directory
- A notification is shown when auto-cut completes

### US-2: Configurable Auto-Cut
> As a user, I want to configure how auto-cut works, so I can control quality and quantity.

**Acceptance Criteria**:
- Toggle to enable/disable auto-cut
- Slider for minimum confidence threshold (0.0-1.0)
- Slider for max clips per video (1-20)
- Slider for max duration per clip (10-120 seconds)
- Offset controls for trimming clip boundaries

### US-3: One-Click Cut All
> As a user, I want a single button to cut all AI-detected clips, even when auto-cut is disabled.

**Acceptance Criteria**:
- "Cut All (N)" button visible when clips are available
- Progress indicator showing completed/total
- Each clip shows individual status

### US-4: Per-Clip Cut Button
> As a user, I want to cut individual clips on demand, for fine-grained control.

**Acceptance Criteria**:
- Each clip card has a "Cut" button
- Shows per-clip progress during cutting
- Status shown as icon + text (pending/cutting/completed/failed)

### US-5: Clip Result History
> As a user, I want to see the history of cut clips, so I can find and replay them.

**Acceptance Criteria**:
- Cut clip records persisted in database
- Output path + metadata stored
- Viewable in clip library with status filter

## 3. Functional Requirements

### FR-1: AutoClipService
- Automatically creates `PostProcessTask(type: clip)` for each qualifying `ClipSegment`
- Qualifying = confidence >= `autoClipConfig.minConfidence`
- Limited to `autoClipConfig.maxClipsPerVideo` clips (sorted by confidence desc)
- Each clip trimmed by `autoClipConfig.startOffsetMs` / `endOffsetMs`
- Capped at `autoClipConfig.maxClipDurationSec`

### FR-2: Configuration Storage
- New `AutoClipConfig` model serialized within `DownloadSettings`
- Persisted via existing `SettingsRepository` (SharedPreferences)
- Default values: enabled=true, minConfidence=0.7, maxClips=5, maxDuration=60s, startOffset=-500ms, endOffset=500ms

### FR-3: Clip Record Persistence
- New `clip_records` SQLite table (DB v4 migration)
- Fields per DESIGN.md §3.2
- Indexed by `source_task_id` and `status`

### FR-4: UI Components
- Settings page: Auto-Clip section with all configuration controls
- Clip library: Per-clip cut button + status display
- Clip library: "Cut All" batch button + progress

### FR-5: Progress Tracking
- `ClipRecord.progress` updated during FFmpeg execution
- Real-time progress via `PostProcessTask` callback chain
- UI polling via `ChangeNotifier`

## 4. Non-Functional Requirements

| Category | Requirement |
|----------|-------------|
| Performance | Auto-cut starts within 1s of AI analysis completion |
| Reliability | Failed cuts don't block other clips from cutting |
| Storage | Clip records stored in SQLite (same DB as tasks) |
| Backwards Compatibility | `autoClipConfig` field nullable, defaults applied if missing |
| Testability | `AutoClipService` accepts injectable `FfmpegClipExecutor` |

## 5. Dependencies

| Dependency | Status | Notes |
|------------|--------|-------|
| FfmpegClipExecutor | ✅ Existing | Reused for clip cutting |
| PostProcessController | ✅ Existing | Extended with auto-cut hook |
| SettingsRepository | ✅ Existing | Extended with autoClipConfig |
| DatabaseService | ✅ Existing | Migration v3→v4 for clip_records |
| EmbeddedToolResolver | ✅ Existing | For FFmpeg binary resolution |

## 6. Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| FFmpeg not available | Graceful fallback — clips remain as analysis-only, user notified |
| Disk space exhausted | Check available space before batch cut, warn if < 1GB |
| Very long video → many clips | `maxClipsPerVideo` limit prevents resource exhaustion |
| Concurrent cuts overwhelm CPU | Serial execution by default; concurrent option in future |

## 7. Success Metrics

| Metric | Target |
|--------|--------|
| Auto-cut success rate | >95% (when FFmpeg available) |
| Time from download to cut clips | <5 minutes (for 60min video) |
| User satisfaction (qualitative) | "I don't think about clips — they just appear" |
