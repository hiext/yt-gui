# Clip Library Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add first-version management operations to the Clips module: preview, regenerate, delete, clear, and practical grouping/filtering.

**Architecture:** Keep the first version local-first. `MediaAssetRepository` owns persistent delete/clear operations, while `ClipLibraryPage` exposes UI actions through injectable callbacks so widget tests can verify behavior without running real FFmpeg.

**Tech Stack:** Flutter desktop, Material widgets, sqflite repository tests, Flutter widget tests.

---

### Task 1: Repository Delete And Clear Operations

**Files:**
- Modify: `lib/core/services/media_asset_repository.dart`
- Test: `test/core/services/media_asset_repository_test.dart`

- [x] Write a failing repository test that saves one media asset with candidates, exports, vectors, analysis jobs, and sync tasks, then deletes one candidate and verifies candidate-linked exports and vectors are gone.
- [x] Run `flutter test test/core/services/media_asset_repository_test.dart --plain-name 'deletes a clip candidate with linked exports and vectors' -r expanded` and confirm it fails because delete APIs are missing.
- [x] Add `deleteClipCandidate(String id)` and `deleteClipExportRecord(String id)` to `MediaAssetRepository`.
- [x] Run the focused repository test and confirm it passes.
- [x] Write a failing repository test for `clearClipResultsForAsset(String mediaAssetId)` that removes candidates, exports, vectors, analysis jobs, and sync tasks while keeping the media asset.
- [x] Run `flutter test test/core/services/media_asset_repository_test.dart --plain-name 'clears all generated clip results for a media asset' -r expanded` and confirm it fails because the clear API is missing.
- [x] Implement `clearClipResultsForAsset(String mediaAssetId)`.
- [x] Run `flutter test test/core/services/media_asset_repository_test.dart -r expanded`.

### Task 2: Clips Page Management UI

**Files:**
- Modify: `lib/features/clips/clip_library_page.dart`
- Test: `test/features/clips/clip_library_page_test.dart`

- [x] Write a failing widget test that verifies a clip card exposes Preview, Regenerate, and Delete actions and calls injected callbacks with the selected asset/candidate/export.
- [x] Run `flutter test test/features/clips/clip_library_page_test.dart --plain-name 'manages clip card preview regenerate and delete actions' -r expanded` and confirm it fails because the actions do not exist.
- [x] Add injectable callbacks to `ClipLibraryPage`: `previewClip`, `regenerateClip`, `deleteClipCandidate`, and `clearClipResults`.
- [x] Add buttons to `_ClipGalleryCard`: Preview, Regenerate, Delete. Keep Open clip and Open folder.
- [x] Wire Delete to repository deletion by default and then reload media assets.
- [x] Wire Regenerate to local `LocalClipWorkerService` by default, with callback injection preserved for tests and future orchestration.
- [x] Run the focused widget test and confirm it passes.
- [x] Write a failing widget test for asset-level Clear results and quality/status organization filter.
- [x] Add asset-level Clear results button and a quality filter dropdown with All quality, High score, Needs review.
- [x] Run `flutter test test/features/clips/clip_library_page_test.dart -r expanded`.

### Task 3: Documentation And Regression

**Files:**
- Modify: `docs/features/edge-cloud-clips/TASKS.md`
- Modify: `docs/features/edge-cloud-clips/README.md`
- Modify: `docs/functional-regression.md`

- [x] Add Phase 10 to `TASKS.md` for clip library management.
- [x] Update README feature status with management actions.
- [x] Update functional regression commands with the new repository and widget tests.
- [x] Run format, analyze, focused tests, full tests, and `git diff --check`.

### Task 4: Supplemental Coverage

**Files:**
- Modify: `test/core/services/media_asset_repository_test.dart`
- Modify: `test/features/clips/clip_library_page_test.dart`
- Create: `docs/features/edge-cloud-clips/TEST-COVERAGE.md`

- [x] Add `deleteClipExportRecord` coverage proving export deletion keeps the source candidate.
- [x] Add default preview coverage proving exported clips open through the normal local path handler.
- [x] Add default delete and clear coverage proving repository-backed actions reload the Clips page.
- [x] Add `Needs review` quality filter coverage.
- [x] Document the applicable test matrix and recommended commands.
