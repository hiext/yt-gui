# Auto-Clip Feature Documentation

> **Branch**: `feat/auto-clip` | **Status**: 📝 Documentation Phase | **Date**: 2026-06-07

## Overview

Automated clip cutting pipeline that seamlessly integrates with the existing download and AI analysis workflow.

### Quick Links

| Document | Purpose |
|----------|---------|
| [PRD.md](./PRD.md) | Product requirements, user stories, acceptance criteria |
| [ARCHITECTURE.md](./ARCHITECTURE.md) | System architecture, component design, data flow |
| [API.md](./API.md) | API reference for all new classes and methods |
| [UI-SPEC.md](./UI-SPEC.md) | UI layout, widgets, localization keys |
| [TEST-PLAN.md](./TEST-PLAN.md) | Test strategy, test cases, coverage targets |
| [DESIGN.md](./DESIGN.md) | Initial design (research findings, merged into above docs) |
| [TASKS.md](./TASKS.md) | Implementation task breakdown and estimates |

### Key Decisions

| Decision | Rationale |
|----------|-----------|
| Serial cut execution | Avoids CPU/IO overload; parallel can be added later |
| Confidence threshold 0.7 | Balanced default per industry research |
| Max 5 clips per video | Prevents resource exhaustion on long content |
| FFmpeg copy mode | Fastest cutting (no re-encode), verified reliable |
| SQLite for records | Same DB as tasks, no new dependency |

### Implementation Plan

```
Phase 1: Data Layer     [P0] ~250 lines  ← Next
Phase 2: Core Service   [P0] ~210 lines
Phase 3: Settings UI    [P1] ~100 lines
Phase 4: ClipLibrary UI [P1] ~130 lines
Phase 5: Testing        [P1] ~350 lines
────────────────────────────────────
Total: 6 new files + 7 modified, ~1040 lines
```

### References

- [FunClip (Alibaba Damo Academy)](https://github.com/modelscope/FunClip) — ASR + LLM clipping pipeline
- [AI-Youtube-Shorts-Generator (SamurAI)](https://github.com/SamurAIGPT/AI-Youtube-Shorts-Generator) — LLM highlight detection + FFmpeg crop
- [autoclipper (VadlapatiKarthik)](https://github.com/VadlapatiKarthik/autoclipper) — FFmpeg + Whisper auto-clipper
