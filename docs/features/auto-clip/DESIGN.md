# Auto-Clip Feature Design Document

> **Status**: Draft | **Branch**: `feat/auto-clip` | **Date**: 2026-06-07

## 1. Overview

### 1.1 Problem
After downloading a video, the user must manually trigger AI analysis, wait for results, review clips, and manually trigger FFmpeg cutting for each clip. This is a multi-step manual process.

### 1.2 Solution
A fully automated pipeline: **Download → AI Analysis → Auto-Cut → Output**. The system automatically:
1. Runs AI clip analysis after download completes
2. Automatically cuts all detected clips (above configurable confidence threshold)
3. Provides one-click "Cut All" and per-clip cut buttons for manual override
4. Shows structured results with progress tracking

### 1.3 Scope
- **In scope**: Auto-cut pipeline, config settings, UI enhancements, structured clip record storage
- **Out of scope**: New AI analysis models, video transcoding, cloud upload

## 2. Research Findings

### 2.1 FunClip (Alibaba Damo Academy) [[source](https://deepwiki.com/modelscope/FunClip)]
| Aspect | Detail |
|--------|--------|
| Pipeline | Extract Audio → ASR → SRT → LLM Analyze → Extract Timestamps → Clip |
| Config | `dest_text`, `start_ost`(ms), `end_ost`(ms), `hotwords`, `add_sub` |
| LLM | OpenAI / DashScope / G4F / Moonshot — prompt-based timestamp extraction |
| Output | Clipped video + subtitle files |

**Adoptable patterns**:
- `start_ost`/`end_ost` offset parameters for fine-tuning clip boundaries
- Structured prompt template for LLM clip analysis

### 2.2 AI-Youtube-Shorts-Generator (SamurAI) [[source](https://deepwiki.com/SamurAIGPT/AI-Youtube-Shorts-Generator)]
| Aspect | Detail |
|--------|--------|
| Pipeline | Download → Audio Extract → Whisper Transcribe → GPT-4o Highlight → FFmpeg Crop → Vertical Output |
| Config | `num_clips`(3), `CHUNK_SIZE_SECONDS`(1200), clip sweet spot `<60s` |
| Output | JSON results dump via `--output-json` |

**Adoptable patterns**:
- `num_clips` configuration for max clip count
- JSON output for structured result storage
- `chunk_size` / `chunk_overlap` for long video handling

### 2.3 Configuration Schema (Merged Best Practices)
Based on research, our configuration schema:

```dart
// New fields in DownloadSettings
class AutoClipConfig {
  /// Master switch: enable automatic clip cutting after AI analysis
  final bool enabled;                    // default: true

  /// Minimum confidence threshold (0.0-1.0) for auto-cutting
  final double minConfidence;            // default: 0.7

  /// Maximum number of clips to auto-cut per video (0 = unlimited)
  final int maxClipsPerVideo;            // default: 5

  /// Maximum duration per clip in seconds
  final int maxClipDurationSec;          // default: 60

  /// Additional start offset in milliseconds (before detected start)
  final int startOffsetMs;               // default: -500 (extend 0.5s earlier)

  /// Additional end offset in milliseconds (after detected end)
  final int endOffsetMs;                 // default: 500 (extend 0.5s later)
}
```

## 3. Architecture

### 3.1 New Component: `AutoClipService`

```
┌─────────────────────────────────────────────────────────────┐
│                    AutoClipService                          │
│  - Receives ClipSegment[] from PostProcessController       │
│  - Filters by confidence >= minConfidence                  │
│  - Limits to maxClipsPerVideo                              │
│  - Creates PostProcessTask(type: clip) for each segment    │
│  - Calls FfmpegClipExecutor.startTask for each             │
│  - Reports progress via callback                           │
│  - Persists results to ClipRecordRepository                │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Data Model: `ClipRecord`

```dart
class ClipRecord {
  final String id;                  // UUID
  final String sourceTaskId;        // DownloadTask ID
  final String sourcePath;          // Original video path
  final String outputPath;          // Cut clip output path
  final String title;               // Clip title (from AI)
  final double confidence;          // AI confidence score
  final int startMs;                // Start time in ms
  final int endMs;                  // End time in ms
  final int durationMs;             // Duration
  final ClipRecordStatus status;    // pending/cutting/completed/failed
  final int progress;               // 0-100
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;
}

enum ClipRecordStatus { pending, cutting, completed, failed }
```

### 3.3 Flow Diagram

```
Download Complete
  │
  ├─→ PostProcessController.enqueueClipForDownload()
  │     │
  │     ├─→ AI Analysis (existing)
  │     │     │
  │     │     └─→ ClipSegment[] produced
  │     │
  │     └─→ [NEW] PostProcessController._handleAnalysisComplete()
  │              │
  │              ├─→ if (autoClipConfig.enabled)
  │              │     AutoClipService.startAutoCut(segments)
  │              │       │
  │              │       ├─→ Filter by confidence
  │              │       ├─→ Limit count
  │              │       ├─→ Create PostProcessTask for each
  │              │       ├─→ Execute via FfmpegClipExecutor
  │              │       └─→ Save ClipRecord to DB
  │              │
  │              └─→ notifyListeners() → UI update
```

## 4. UI Design

### 4.1 Settings Page (DownloadSettings additions)

```
┌─ Auto Clip ─────────────────────────────────────┐
│ [✓] Enable automatic clip cutting               │
│                                                  │
│ Min Confidence:  [══════●═══] 0.7               │
│ Max Clips/Video: [═══●═══════] 5                │
│ Max Clip Duration: [═════●════] 60s              │
│ Start Offset:     [-500ms]  End Offset: [500ms] │
└──────────────────────────────────────────────────┘
```

### 4.2 ClipLibraryPage Enhancements

```
┌─ Clips ──────────────────────────────────────────┐
│ 🔍 [Search clips...]                             │
│ [0 queued] [1 analyzing] [3 clips]              │
│                                                   │
│ ┌─────────────────────────────────────────────┐  │
│ │ 🎬 Product demo         0:15 - 0:45        │  │
│ │ Product demo segment                       │  │
│ │ Reason: object + speech                    │  │
│ │ Confidence: 82%  #product #demo            │  │
│ │ ┌─────────────────────────────────────┐    │  │
│ │ │ [⏸ 0%] Cutting...                   │    │  │
│ │ └─────────────────────────────────────┘    │  │
│ │ [Start Earlier] [Start Later]              │  │
│ │ [End Earlier] [End Later]                  │  │
│ └─────────────────────────────────────────────┘  │
│                                                   │
│ ┌─────────────────────────────────────────────┐  │
│ │ 🎬 Highlight reel       1:20 - 2:10        │  │
│ │ ...                                         │  │
│ │ [▶ Cut This Clip]  ← per-clip button       │  │
│ └─────────────────────────────────────────────┘  │
│                                                   │
│ [🎬 Cut All Clips (2)]  ← one-click button       │
└───────────────────────────────────────────────────┘
```

### 4.3 Progress Indicators
- **Per-clip**: Linear progress bar inside each clip card
- **Batch**: Summary chip showing "2/5 completed"
- **Status icons**: ⏳ pending, 🔄 cutting, ✅ completed, ❌ failed

## 5. Database Schema Additions

```sql
CREATE TABLE clip_records (
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

CREATE INDEX idx_clip_records_source ON clip_records(source_task_id);
CREATE INDEX idx_clip_records_status ON clip_records(status);
```

## 6. Implementation Plan

### Phase 1: Data Layer
- [ ] Add `AutoClipConfig` to `DownloadSettings`
- [ ] Add `ClipRecord` model to `app_models.dart`
- [ ] Add `clip_records` table migration (DB version 4)
- [ ] Implement `ClipRecordRepository`

### Phase 2: Core Service
- [ ] Implement `AutoClipService`
- [ ] Wire into `PostProcessController._handleAnalysisComplete()`
- [ ] Integrate with existing `FfmpegClipExecutor`

### Phase 3: Settings UI
- [ ] Add Auto-Clip section to `SettingsPage`
- [ ] Wire settings to `AutoClipService`

### Phase 4: ClipLibrary UI
- [ ] Add per-clip cut button
- [ ] Add "Cut All" button
- [ ] Show progress bars per clip
- [ ] Show status chips

### Phase 5: Testing
- [ ] Unit tests for `AutoClipService`
- [ ] Unit tests for `ClipRecordRepository`
- [ ] Widget tests for new UI elements
- [ ] Integration test for end-to-end auto-clip flow

## 7. API Reference

### AutoClipService
```dart
class AutoClipService {
  AutoClipConfig config;
  final List<ClipRecord> records;

  Future<void> startAutoCut(List<ClipSegment> segments, DownloadSettings settings);
  Future<void> cutSingle(ClipSegment segment, DownloadSettings settings);
  Future<void> cutAll(List<ClipSegment> segments);
  Future<void> cancel(String recordId);
  Future<List<ClipRecord>> loadRecords({String? sourceTaskId});
  void dispose();
}
```

## 8. Testing Strategy

| Layer | Approach | Coverage Target |
|-------|----------|-----------------|
| AutoClipService | Unit tests with fake FfmpegClipExecutor | 90%+ |
| ClipRecordRepository | Unit tests with in-memory SQLite | 90%+ |
| Settings UI | Widget tests | 80%+ |
| ClipLibrary UI | Widget tests | 80%+ |
| E2E | Integration test with mock yt-dlp + ffmpeg | Happy path |

## 9. References
- [FunClip Architecture](https://deepwiki.com/modelscope/FunClip/1.2-system-architecture)
- [FunClip LLM Clipping](https://deepwiki.com/modelscope/FunClip/5.2-llm-assisted-clipping)
- [AI-Youtube-Shorts-Generator Config](https://deepwiki.com/SamurAIGPT/AI-Youtube-Shorts-Generator/6.2-configuration-options)
- [AI-Youtube-Shorts-Generator Architecture](https://deepwiki.com/SamurAIGPT/AI-Youtube-Shorts-Generator/5-technical-deep-dives)
