# Auto-Clip UI Specification

> **Branch**: `feat/auto-clip`

## 1. Settings Page — Auto-Clip Section

### 1.1 Layout

```
┌─────────────────────────────────────────────────────────┐
│ ┌─ Auto Clip ────────────────────────────────────────┐ │
│ │ Configure automatic clip cutting after AI analysis │ │
│ │                                                     │ │
│ │  Enable Auto-Cut:  [══════════════●]  ON           │ │
│ │                                                     │ │
│ │  Min Confidence:   [══════●═══════]  0.70          │ │
│ │  (Only cut clips with confidence ≥ this value)      │ │
│ │                                                     │ │
│ │  Max Clips/Video:  [════●══════════]  5             │ │
│ │  (Limit clips per download, 0 = unlimited)          │ │
│ │                                                     │ │
│ │  Max Duration:     [══════●═══════]  60 sec         │ │
│ │  (Maximum length per cut clip)                      │ │
│ │                                                     │ │
│ │  Start Offset:     [-500] ms    End Offset: [500] ms│ │
│ │  (Adjust clipping boundaries)                       │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### 1.2 Components

| Component | Key | Widget Type | Range | Default |
|-----------|-----|-------------|-------|---------|
| Enable toggle | `auto-clip-enabled` | `SwitchListTile` | bool | true |
| Min confidence | `auto-clip-confidence` | `Slider` | 0.0-1.0 (step 0.05) | 0.70 |
| Max clips | `auto-clip-max-clips` | `Slider` | 1-20 (step 1) | 5 |
| Max duration | `auto-clip-max-duration` | `Slider` | 10-120 (step 5) | 60 |
| Start offset | `auto-clip-start-offset` | `TextFormField` (number) | -5000..5000 | -500 |
| End offset | `auto-clip-end-offset` | `TextFormField` (number) | -5000..5000 | 500 |

### 1.3 Behavior
- When `enabled` is toggled OFF, other controls are disabled (greyed out)
- Slider labels show current value
- Changes auto-save via `SettingsController.updateAutoClipConfig()`

## 2. Clip Library — Clip Card Enhancements

### 2.1 Existing Card (before)

```
┌─────────────────────────────────────────┐
│ 🎬 Product demo        0:15 - 0:45     │
│ Product demo segment                    │
│ Reason: object + speech                 │
│ Confidence: 82%  #product #demo        │
│ [Start Earlier] [Start Later]          │
│ [End Earlier] [End Later]              │
└─────────────────────────────────────────┘
```

### 2.2 Enhanced Card (after)

```
┌──────────────────────────────────────────────┐
│ 🎬 Product demo          0:15 - 0:45        │
│ Product demo segment                         │
│ Reason: object + speech                      │
│ Confidence: 82%  #product #demo             │
│                                               │
│ ┌──────────────────────────────────────┐     │
│ │ ✅ Cut complete · /tmp/.clips/...mp4 │     │
│ └──────────────────────────────────────┘     │
│                                               │
│ [Start Earlier] [Start Later]                │
│ [End Earlier] [End Later]   [🔄 Re-Cut]     │
└──────────────────────────────────────────────┘
```

### 2.3 Status States

| State | Icon | Color | Progress Bar | Action Button |
|-------|------|-------|-------------|---------------|
| **Pending** (not cut) | — | — | Hidden | `[▶ Cut]` |
| **Cutting** (in progress) | ⏳ | Blue | Shown (0-100%) | `[⏸ Cancel]` |
| **Completed** | ✅ | Green | Hidden (show 100%) | `[🔄 Re-Cut]` |
| **Failed** | ❌ | Red | Hidden | `[🔄 Retry]` |

### 2.4 Progress Bar Component

```dart
// Inside _ClipSegmentCard:
if (clipRecord != null && clipRecord.status == ClipRecordStatus.cutting) {
  LinearProgressIndicator(
    value: clipRecord.progress / 100.0,
    backgroundColor: Colors.grey[200],
    valueColor: AlwaysStoppedAnimation(Colors.blue),
  );
}
```

## 3. Batch Cut Button

### 3.1 Position
Below the search bar and chips, above the clip list:

```
┌─────────────────────────────────────────────────────────┐
│ 🔍 [Search clips...]                                    │
│ [0 queued] [1 analyzing] [3 clips]                      │
│                                                          │
│ ┌──────────────────────────────────────────────────┐    │
│ │ 🎬 Cut All (2 uncut)    [▶ Execute]             │    │
│ └──────────────────────────────────────────────────┘    │
│                                                          │
│ ┌─ Clip Card 1 ────────────────────────────────────┐    │
│ ...                                                   │
```

### 3.2 States

| State | Text | Button |
|-------|------|--------|
| No uncut clips | `All clips cut ✅` | Hidden |
| Some uncut | `Cut All (N uncut)` | `[▶ Cut All]` |
| Cutting in progress | `Cutting 2/5...` | `[⏸ Cancel All]` |
| All completed | `5/5 completed ✅` | `[🔄 Re-Cut All]` |

### 3.3 Implementation

```dart
// In ClipLibraryPage:
Widget _buildBatchCutBar() {
  final uncut = clipRecords
    .where((r) => r.status == ClipRecordStatus.pending)
    .length;
  final cutting = clipRecords
    .where((r) => r.status == ClipRecordStatus.cutting)
    .length;
  final completed = clipRecords
    .where((r) => r.status == ClipRecordStatus.completed)
    .length;

  if (uncut == 0 && cutting == 0) {
    return Text(l10n.allClipsCut(completed));
  }

  return Row(
    children: [
      Icon(Icons.content_cut, size: 18),
      SizedBox(width: 8),
      Text(cutting > 0
        ? l10n.cuttingProgress(completed, uncut + cutting + completed)
        : l10n.cutAllClips(uncut)),
      Spacer(),
      FilledButton.tonalIcon(
        onPressed: cutting > 0 ? _cancelAll : () => _cutAll(),
        icon: Icon(cutting > 0 ? Icons.stop : Icons.play_arrow),
        label: Text(cutting > 0 ? l10n.cancelAll : l10n.execute),
      ),
    ],
  );
}
```

## 4. Localization Keys

```arb
// English
"autoClipSection": "Auto Clip",
"autoClipSectionDesc": "Configure automatic clip cutting after AI analysis",
"autoClipEnabled": "Enable Auto-Cut",
"autoClipMinConfidence": "Min Confidence",
"autoClipMinConfidenceHint": "Only cut clips with confidence ≥ this value",
"autoClipMaxClips": "Max Clips/Video",
"autoClipMaxClipsHint": "Limit clips per download, 0 = unlimited",
"autoClipMaxDuration": "Max Duration",
"autoClipMaxDurationHint": "Maximum length per cut clip (seconds)",
"autoClipStartOffset": "Start Offset (ms)",
"autoClipEndOffset": "End Offset (ms)",
"autoClipOffsetHint": "Adjust clipping boundaries",
"cutClip": "Cut",
"cutAllClips": "Cut All ({count} uncut)",
"cutAllClipsBtn": "Cut All ({count})",
"allClipsCut": "All clips cut ✅",
"cuttingProgress": "Cutting {completed}/{total}...",
"reCut": "Re-Cut",
"clipCutComplete": "Cut complete",
"clipCutFailed": "Cut failed",
"clipRecordTitle": "Clip Record",

// Chinese
"@autoClipSection": "自动切片",
"@autoClipSectionDesc": "AI 分析完成后自动切割片段",
"@autoClipEnabled": "启用自动切割",
"@autoClipMinConfidence": "最低置信度",
"@autoClipMinConfidenceHint": "仅切割置信度不低于此值的片段",
"@autoClipMaxClips": "每视频最多片段数",
"@autoClipMaxClipsHint": "限制每个视频的切割数量，0 = 不限制",
"@autoClipMaxDuration": "最大时长",
"@autoClipMaxDurationHint": "每个片段的时长上限（秒）",
"@autoClipStartOffset": "开始偏移 (ms)",
"@autoClipEndOffset": "结束偏移 (ms)",
"@autoClipOffsetHint": "调整切割边界",
"@cutClip": "切割",
"@cutAllClips": "一键切割 ({count} 个待切)",
"@cutAllClipsBtn": "一键切割 ({count})",
"@allClipsCut": "全部已切割 ✅",
"@cuttingProgress": "切割中 {completed}/{total}...",
"@reCut": "重新切割",
"@clipCutComplete": "切割完成",
"@clipCutFailed": "切割失败",
"@clipRecordTitle": "切割记录",
```

## 5. Widget Key Reference

| Key | Widget | Purpose |
|-----|--------|---------|
| `auto-clip-section` | `SectionCard` | Auto-clip settings section |
| `auto-clip-enabled` | `SwitchListTile` | Enable/disable toggle |
| `auto-clip-confidence` | `Slider` | Confidence threshold |
| `auto-clip-max-clips` | `Slider` | Max clips per video |
| `auto-clip-max-duration` | `Slider` | Max clip duration |
| `auto-clip-start-offset` | `TextFormField` | Start offset input |
| `auto-clip-end-offset` | `TextFormField` | End offset input |
| `batch-cut-bar` | `Row` | Batch cut controls |
| `batch-cut-btn` | `FilledButton` | Batch cut action |
| `clip-cut-btn-{id}` | `OutlinedButton` | Per-clip cut action |
| `clip-progress-{id}` | `LinearProgressIndicator` | Per-clip progress |
| `clip-status-{id}` | `Row` | Per-clip status display |
