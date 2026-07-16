<!-- Created: 2026-07-16 19:03 (WEST) · Updated: 2026-07-16 19:03 (WEST) -->
# Phase 1 Data Model: Live Activity Recording Controls for Check-In

**Feature**: [spec.md](spec.md) · **Research**: [research.md](research.md)

**No new SwiftData `@Model`.** The Live Activity state is transient (ActivityKit-owned, in memory + system store), and the saved artifact is the existing `Recording`. This preserves the CloudKit-compatible schema (Constitution IX) trivially. Two *transient* types and a reused-status marker are introduced.

## 1. `CheckInActivityAttributes` (ActivityKit — transient, shared package)

The contract between the app (producer) and the widget extension (renderer). Lives in a local Swift package imported by both targets (research D2). Not persisted to SwiftData; ActivityKit owns its lifetime.

| Member | Type | Purpose |
|---|---|---|
| `startedAt` | `Date` | Wall-clock start; drives the self-updating `Text(timerInterval:)` elapsed display (research D4) — the app never pushes per-second ticks. |
| `cap` | `TimeInterval` | Max-duration cap; lets the surface bound the timer range. |
| **`ContentState`** (nested, `Codable & Hashable`) | | The mutable state pushed via `activity.update`. |
| `ContentState.phase` | `RecordingActivityPhase` | `.recording` / `.paused` / `.ended` — the only state the surface renders (see §3). |
| `ContentState.pausedAt` | `Date?` | When paused, the freeze point passed as `Text(timerInterval:pauseTime:)`; `nil` while recording. |

**Validation / invariants**:
- `phase == .paused` ⇒ `pausedAt != nil`; `phase == .recording` ⇒ `pausedAt == nil`.
- `ContentState` MUST contain **no** transcript, mood, or medication content (FR-016 / SC-006). Only timing + phase. This is a hard privacy invariant, asserted in tests (§5) because `ContentState` is `Codable` and rendered on a surface visible to anyone holding the phone.
- Exactly one activity exists at a time (FR-010) — enforced by the controller (§4), not the type.

## 2. `RecordingActivityPhase` (transient enum)

```
recording | paused | ended
```

Derived from the app's existing `RecordingState` (`idle/recording/paused/processing/done`) by a **pure mapping function** (the primary Constitution X test seam, research D18):

| App `RecordingState` | `RecordingActivityPhase` | Activity present? |
|---|---|---|
| `.idle` | — | No activity (not started / already ended) |
| `.recording` | `.recording` | Yes |
| `.paused` | `.paused` | Yes |
| `.processing` | `.ended` | Ending → `activity.end(.immediate)` |
| `.done` | `.ended` | Ended (dismissed) |

## 3. Recording lifecycle state (owned by `RecordingSessionController`, research D10)

The controller is the process-level owner of the active recording. It holds the authoritative lifecycle state and the metadata the Live Activity + finalize need. Transient (in-memory), not a `@Model`.

| Field | Type | Notes |
|---|---|---|
| `captureID` | `UUID` | Idempotency key for the single finalize (research D14); ties STOP / cap-finish / interruption / launch-recovery to one capture. |
| `state` | `RecordingState` | Mirrors/hosts the existing state machine; `.paused` becomes a **real, user-reachable** state for the first time (research D19). |
| `fileURL` | `URL` | The in-progress audio file (pinned to `.completeUntilFirstUserAuthentication`, research D13). |
| `startedAt` | `Date` | For elapsed display + the in-progress marker. |
| `cap` | `TimeInterval` | Passed to `AVAudioRecorder.record(forDuration:)` for lock-tolerant cap enforcement (research D17). |
| `activity` | `Activity<CheckInActivityAttributes>?` | The started activity, so `perform()` can `update`/`end` it (research D3/D7). |

## 4. In-progress capture marker (reuses `Recording.status`, no new entity)

For terminated-app recovery (research D15). Rather than a new `@Model`, reuse the existing `Recording.status` state that already carries "downstream steps didn't complete" semantics (`.pendingTranscription` today; the plan confirms whether a distinct `.unfinalized`/pre-save marker is needed or whether an on-disk marker file + the existing `pendingSave` buffer suffices — decided at task time against the actual `RecordingStore`).

**Invariant**: the marker is written at record-start and cleared **atomically in the same transaction as the finalize save**, so a crash leaves exactly one of {marker present, record saved} — never both, never neither with an orphaned file that can't be found.

## 5. Test-first coverage (Constitution X, research D18)

| Pure seam | Test file (new) | Key assertions |
|---|---|---|
| `RecordingState → RecordingActivityPhase` + `ContentState` derivation | `LiveActivityContentStateTests.swift` | mapping table §2; **privacy invariant**: encoded `ContentState` never contains transcript/mood/med strings (FR-016); paused ⇒ `pausedAt != nil`. |
| Controller lifecycle + idempotent finalize | `RecordingSessionControllerTests.swift` | start→pause→resume→stop transitions; finalize called twice with same `captureID` saves **once**; stop while `.paused` finalizes; model-absent path routes to pending (parity with `CheckInViewModel`). |
| Intent → control-command routing | `RecordingControlIntentsTests.swift` | each intent calls the right controller method on a mock; no unlock/foreground assumptions baked in. |

SwiftUI surfaces (`CheckInLiveActivity`, Dynamic Island regions) are exempt (build + device QA).
