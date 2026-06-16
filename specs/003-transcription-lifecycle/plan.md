# Implementation Plan: Transcription Lifecycle (in-progress → done | failed, visible and bounded)

**Branch**: `feat/feedback-specs` (Spec Kit feature `003-transcription-lifecycle`) | **Date**: 2026-06-15 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/003-transcription-lifecycle/spec.md`. Provenance: screen-recording feedback plan §4.1, §4.2, and the "Transcription UX is a state-machine gap" cross-cutting theme (`docs/superpowers/2026-06-15-screen-recording-feedback-plan.md`).

## Summary

Make a single check-in's transcription lifecycle — *in-progress → done | failed* — visible and bounded everywhere the check-in appears. Three slices: (P1) render the temporary name "Transcribing…" for an in-progress entry in both the day timeline and the recording detail header, resolving in place to the real title on completion; (P2) lower the transcription timeout from the current 300 s to a human-scale bound and surface a Retry affordance on failure in both the timeline and the detail view; (P3) distinguish the first-run model download from active transcription so a slow one-time download shows its own state and is not charged against the transcription wait bound. The needed states already exist (`RecordingStatus.transcribing`, `.failed`, `.completed`, `.placeholder`); the timeout already fires (`CheckInViewModel.consumeStreamWithTimeout(…, timeoutSeconds: 300)`) and already sets `.failed` on the timeout path. The work is therefore: correct the timeout value, separate download from transcription in the orchestration and display, derive the "Transcribing…" display name from status at the view layer, and add the Retry affordance — with no SwiftData schema change.

## Coordination with in-flight branches

Two un-merged branches already address parts of this lifecycle. This feature builds **on top of** them and narrows accordingly — it must not re-implement their work:

- **`fix/orphaned-transcription-status`** (touches `CheckInViewModel` + `RecordingStore`, +tests): already (a) recovers any recording left on `.transcribing` at launch to `.failed` (`RecordingStore.recoverOrphanedTranscriptions()`), (b) finalizes the cancel path to `.failed` in a fresh `@MainActor` task so it never sticks on `.transcribing`, (c) ships the user-facing copy *"Transcription was interrupted / cancelled. Tap to retry in the recording detail view."*, and (d) serializes back-to-back transcriptions on the single Whisper actor (no cancel-on-restart). **→ 003 does NOT re-implement orphan/cancel finalization.** 003's Retry control MUST honour the copy that branch already ships (it references a retry that does not yet exist as a control).
- **`fix/whisper-simulator-compute`** (touches `ComputeEnvironment`): forces `.cpuAndGPU` on the Simulator (no ANE), which the branch notes was *"stalling transcription on 'Transcribing with Whisper…' indefinitely."* That is a primary cause of the owner's "very big delay" — the walkthrough ran on the Simulator. **→ Part of §4.2's perceived slowness is a Simulator artifact already fixed here.** 003's timeout bound must be chosen against this improved baseline, not the pre-fix hang.

**Net remaining scope for 003** once those land:
1. The **"Transcribing…" display name** in the timeline row and the detail header (neither branch changes the title). (§4.1)
2. **Lower the 300 s timeout** — still unchanged by either branch — to a human-scale bound. (§4.2)
3. The actual **Retry control** in the recording detail (the copy exists; the button does not). (§4.2)
4. **Separate model-download from transcription** so a one-time download isn't counted as a hang. (§4.2)

**Sequencing**: land `fix/whisper-simulator-compute` and `fix/orphaned-transcription-status` first, then rebase 003 on them so the `CheckInViewModel`/`RecordingStore` edits stack cleanly rather than conflicting.

## Technical Context

**Language/Version**: Swift 6 (strict concurrency enabled)

**Primary Dependencies**: SwiftUI (iOS 26+), SwiftData, Swift Concurrency (`async/await`, `AsyncStream`, structured `TaskGroup`), WhisperKit running OpenAI Whisper Small (`openai_whisper-small`)

**Storage**: SwiftData (`Recording` `@Model`); no schema change planned

**Testing**: Swift Testing (`@Test`/`#expect`); build/run via `ios-debugger-agent` (XcodeBuildMCP)

**Target Platform**: iOS 26+ (iPadOS secondary)

**Project Type**: mobile-app

**Performance Goals**: A stuck transcription is declared failed within the configured human-scale bound (target 60–90 s for typical short check-ins); in-progress → completed/failed transitions are reflected in the timeline and detail header in the same frame they occur; first-run model download is not charged against the transcription bound.

**Constraints**: Fully on-device; no network beyond the one-time model download; logs are counts/durations/state-names/token-estimates only (never transcript text); model lifecycle stays RAM-isolated (load lazily, unload before downstream extraction) exactly as today.

**Scale/Scope**: Single feature touching one ViewModel (timeout/retry orchestration), the transcription service seam (download-vs-transcribe signalling), and two view surfaces (timeline row, detail header) plus a small status→display-name derivation. No new persisted fields.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

See `.specify/memory/constitution.md` (v1.1.0).

- [x] **I. SwiftUI-First** — PASS. All UI is SwiftUI on iOS 26+: a status→name derivation feeding `MoodBanner`/timeline ([TimelineRow.swift](../../app-four/Views/Components/TimelineRow.swift#L57)) and the detail header title ([RecordingDetailView.swift](../../app-four/Views/RecordingDetailView.swift#L54)), plus a Retry control reusing existing button/status-pill patterns. No UIKit added. The Retry control and "Transcribing…" treatment are small additions to existing views; an HTML mockup precedes any net-new view surface per the constitution.
- [x] **II. Test-Build-Ship** — PASS. The change is buildable and unit-testable: timeout fires at the configured bound and sets `.failed`; status→display-name maps to "Transcribing…"; retry returns status to `.transcribing`. Build + full suite via `ios-debugger-agent` before the PR.
- [x] **III. Correctness Over Speed** — PASS. The fix corrects an existing wrong value (300 s) and an existing display gap rather than adding parallel paths; no dead code or compat shims. The download-vs-transcription separation is a real correctness fix (a healthy download was being counted as a hang), surfaced explicitly here.
- [x] **IV. Minimal Surface** — PASS. No new abstractions or flags: reuse the existing `RecordingStatus` cases, the existing timeout mechanism, and the existing `.failed` status pill. The display name is computed at the view layer, not stored. No speculative configuration.
- [x] **V. Solo Git Discipline** — PASS. One revertable feature on `feat/feedback-specs`; `/code-review` before merge; `main` stays releasable. (Specs land on this branch; implementation rebases on `fix/orphaned-transcription-status` + `fix/whisper-simulator-compute` — see Coordination — so it stacks cleanly rather than conflicting.)
- [x] **VI. On-Device Privacy** — PASS. Nothing leaves the device; the only network is the pre-existing one-time model download. Timeout/retry orchestration and all logging record counts, durations, state names, and token estimates only — no transcript text — consistent with the existing `AppLogger.log` calls in `CheckInViewModel` and the `DiagnosticsStore` snapshots in the service (`whisperDurationMs`, `transcriptionTokenEstimate`, `screenName`).
- [x] **VII. Deterministic, Measured Extraction** — N-A. This feature ends at a resolved title and the entry leaving the in-progress state; it does not touch `NLNoteExtractor`, the lexicon, or extraction floors. Downstream extraction runs unchanged after a successful transcription.
- [x] **VIII. Service-Oriented Architecture** — PASS. Transcription stays behind the existing `TranscriptionService` protocol ([Services/Protocols.swift](../../app-four/Services/Protocols.swift#L27)); the timeout/retry state machine stays in the `@MainActor @Observable` `CheckInViewModel` (heavy work already dispatched off-main into the actor service). The model load→unload RAM-isolation in `WhisperKitTranscriptionService` is unchanged (unload still precedes completion). The only seam change is making the download-vs-transcription distinction observable to the ViewModel (e.g. a typed signal on the existing stream) rather than inferred from yielded display strings.
- [x] **IX. Pre-Release Data Posture** — PASS. No schema change: `RecordingStatus` already carries `.transcribing`, `.failed`, `.completed`, `.placeholder`, and `Recording.status`/`Recording.title` already exist and are non-unique/defaulted. "Failed + retryable" is expressed by the existing `.failed` status against the already-persisted audio — no new persisted field — so the store stays CloudKit-compatible and IX stays green. (If research surfaces a genuine need for a persisted "retry-eligible" flag, it would be justified here against the CloudKit path before merge; current design needs none.)

## Project Structure

### Documentation (this feature)

```text
specs/003-transcription-lifecycle/
├── plan.md              # This file
├── spec.md              # WHAT & WHY (already authored)
├── research.md          # Phase 0 decisions
├── data-model.md        # Entities / status / schema-impact (no change)
├── quickstart.md        # Manual + automated validation
└── tasks.md             # Phase 2 (/speckit-tasks — NOT created here)
```

(No `contracts/` — on-device feature; the behavioural contract is the spec's acceptance scenarios.)

### Source Code (repository root)

```text
app-four/
├── Models/
│   ├── AppEnums.swift                 # REUSE — RecordingStatus {.transcribing,.failed,.completed,.placeholder}
│   └── Recording.swift                # REUSE — Recording.status / Recording.title (no schema change)
├── ViewModels/
│   ├── CheckInViewModel.swift         # MODIFY (atop fix/orphaned-transcription-status) — lower timeout to
│   │                                  #          human-scale (was 300s, ~L119); split download-vs-transcription
│   │                                  #          accounting; add retry(_:) path. Orphan/cancel finalization is
│   │                                  #          already done by that branch — do not duplicate.
│   └── DayTimeline.swift              # REUSE — Node.recording drives the row; no model change here
├── Views/
│   ├── RecordingDetailView.swift      # MODIFY — header title (~L54) shows "Transcribing…" when in-progress;
│   │                                  #          add Retry affordance on .failed (status pill ~L147 stays)
│   └── Components/
│       ├── TimelineRow.swift          # MODIFY — fallbackTitle/name reflects "Transcribing…" + Retry on .failed (~L57)
│       └── DayCard.swift              # REUSE/possible MODIFY — placeholder/transcribing presentation if needed
├── Services/
│   ├── Protocols.swift                # MODIFY (small) — make download-vs-transcription distinguishable to the VM
│   │                                  #   (typed phase signal on the existing AsyncStream<TranscriptionSegmentDTO>)
│   └── WhisperKit/
│       └── WhisperKitTranscriptionService.swift  # MODIFY — emit a typed "preparing model" phase distinct from
│                                      #   transcription (replaces inferring it from the yielded display string ~L105);
│                                      #   model load→unload RAM isolation UNCHANGED
└── Utils/
    └── Constants.swift                # REUSE/possible MODIFY — home for the new human-scale timeout constant

app-fourTests/
└── ViewModels/
    └── CheckInViewModelTests.swift    # MODIFY — add: timeout fires at bound → .failed; retry → .transcribing;
                                       #   download phase NOT counted against the transcription bound
```

**Structure Decision**: Single iOS app module `app-four` with its `app-fourTests` target — matches the constitution's stack. No new module or directory. Orchestration (timeout, retry, download-vs-transcription accounting) lives in `CheckInViewModel`; the capability stays behind `TranscriptionService`; display is a view-layer derivation from `RecordingStatus`. The only structural addition is a typed transcription-phase signal so the ViewModel learns "preparing model" vs "transcribing" from the service contract instead of parsing yielded display text.

## Complexity Tracking

> No constitution violations. Table intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |
