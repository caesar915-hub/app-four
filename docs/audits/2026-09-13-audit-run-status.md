<!-- Created: 2026-09-13 10:06 WEST · Updated: 2026-09-13 10:06 WEST -->
# Overnight audit — status (2026-09-13, ~06:45 WEST)

**Ran to completion. Nothing merged to `main`.** Two PRs are open for your device QA + merge.

## What ran
- Baseline on `main` @ 2553e251: **clean build + 544 tests green** on the iPhone 17 Pro sim.
- Audit workflow: **10 Opus (max-effort) lens agents → 1 adversarial verifier per finding → independent cross-check panel** (completeness + false-positive + fix-safety). 88 agents, 0 errors, ~75 min, ~6.5M tokens.
- Safe fixes applied on a branch and **verified in Debug (544 tests) and Release (build) — both green.**

## Findings
- **62 confirmed** (2 high, 17 medium, 43 low) + **4 cross-check additions** (1 high, 3 medium). **0 false positives** after adversarial verification.
- The June 2026 audit is **fully remediated** on `main`.

### The two 🔴 to fix first (both reported, NOT auto-fixed — need device QA)
1. **8-minute recording silently lost at the cap.** `CheckInViewModel` and `AudioRecordingServiceImpl` run two independent 480 s auto-stop timers on different clocks; the service fires first, tears down the recorder with no callback, and the ViewModel's later stop throws → resets to `.idle`, no save, no orphan recovery.
2. **Deleting a check-in orphans the voice `.m4a` forever.** `RecordingStore.deleteRecording` deletes only the SwiftData row (a comment claims the storage service deletes the file — it doesn't). Sensitive audio persists on disk after delete. Privacy-critical.
   Plus a 🟡 data-loss variant: `AudioFileStorageServiceImpl` moves the temp file before the SwiftData save, orphaning it (and breaking retry) if the save throws.

## PRs (open, not merged)
- **#43** — the full report (`docs/audits/2026-09-13-main-codebase-audit.md`). https://github.com/caesar915-hub/app-four/pull/43
- **#44** — safe cleanup, 10 findings, 14 files, +23/−308. https://github.com/caesar915-hub/app-four/pull/44

## Auto-fixed in #44 (compile-verified, Debug+Release green)
Dead code deleted (`Chip`, `RecordingRow`, `MockTranscriptionService`, `AudioConverter.convertToPCM`); debug surfaces gated out of Release (`TestServicesView`, `MockDataGenerator` + its `previewContainer` call, `Views/Feedback/*` — **closes RC-30**); the 3 transcript/medication-bearing `MLXJournalService` logs gated `#if DEBUG` (privacy); `PlaybackWaveformBars` `abs()` overflow trap removed; a stale `MoodLevel` comment fixed.

The Release build caught a real mistake mid-run: gating `previewContainer` broke Release because `#Preview` blocks compile there. I corrected it (gated only the mock-data call inside it) and re-verified. This is why the two-config check mattered.

## Needs YOU (device QA, then merge)
- Merge **#43** (docs) anytime — it's report-only.
- QA **#44** on device (record/playback, delete a check-in, open Settings), then merge. It closes RC-30 (App Review insurance).
- Then tackle the reported 🔴/🟡: recording-cap race, orphaned-audio-on-delete, save-before-move, LLM cancellation, focus level-5 in Insights (apply per-site — a blanket `no-lowercase` edit breaks `FoldedDayCardHeader:115`; see the report's Verification note), and the download/transcription hardening trio.
- `chore/remove-dead-nlp` already stages the ~2k-LOC dead-NL removal (and would delete the 97 tests that exercise it) — land it after #44.

## Deliberately NOT done autonomously (owner calls)
- `SummarizationError` unused-case removal (public error type on a load-bearing protocol).
- `RecordingStore.createCheckInNote` deletion (touches tests).
- Wireframe bundle exclusion (needs a project-file membership change).
- Design-system token prune + `DESIGN.md` sync (owner-curated per CLAUDE.md).
- CI pipeline — I couldn't validate a workflow run here, so a ready-to-use file is below rather than committed.
- WORKLOG regen deferred: it derives from `main`; regenerate after you merge.

## Ready-to-use CI workflow (constitution II — "CI green on branch")
Save as `.github/workflows/ci.yml`, adjust the Xcode version/runner, and push:

```yaml
name: CI
on:
  pull_request:
  push:
    branches: [main]
jobs:
  test:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_26.app
      - name: Build & test
        run: |
          xcodebuild -project app-four.xcodeproj -scheme app-four \
            -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
            -testPlan app-four clean build test
```

## Notes
- Ran on this Mac (local) because build/test/fix-verification need Xcode + a simulator; a cloud cron can't do that.
- The audit worktree was removed; `report-wt` and `fix-wt` remain (their branches are pushed).
- Full report: `docs/audits/2026-09-13-main-codebase-audit.md` (on branch `docs/codebase-audit-2026-09`).
