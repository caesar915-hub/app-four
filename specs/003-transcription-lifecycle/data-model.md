# Phase 1 Data Model: Transcription Lifecycle

**Feature**: `003-transcription-lifecycle` | **Branch**: `feat/feedback-specs` | **Date**: 2026-06-15
**Spec**: [spec.md](spec.md) · **Plan**: [plan.md](plan.md) · **Research**: [research.md](research.md)

**Headline**: **No SwiftData schema change.** Every entity, attribute, and status case this feature needs already exists. The lifecycle is expressed entirely through the existing `Recording.status` (a `RecordingStatus`) plus a view-layer derived display name; the only data-shaped addition is a *transient, in-memory* transcription-phase signal on the service stream that is never persisted.

---

## Entities

### Recording (existing `@Model`) — REUSE, no change

Source: [Recording.swift](../../app-four/Models/Recording.swift). Attributes relevant to this feature:

| Attribute | Type | Role in this feature | Change |
|-----------|------|----------------------|--------|
| `status` | `RecordingStatus` | The single source of truth for the lifecycle state. Drives both the derived display name and the Retry affordance. | REUSE — no change |
| `title` | `String` (stored, default `"Untitled"`) | The **resolved** title, written only after a successful transcription/extraction ([#L212](../../app-four/Models/Recording.swift#L212)). NEVER holds "Transcribing…" — that name is computed from `status` at the view layer (research D3). | REUSE — no change |
| `fullTranscriptText` | `String` (default `""`) | Receives streamed segments while `.transcribing`; receives a failure/timeout hint on `.failed` (existing behaviour, [CheckInViewModel.swift#L140](../../app-four/ViewModels/CheckInViewModel.swift#L140)). Retry re-runs against the retained audio and overwrites this. | REUSE — no change |
| `audioURL` (derived from `audioFileName`) | `URL` | The retained audio that makes Retry a pure re-transcription (no re-record). | REUSE — no change |
| `createdAt`, `duration`, `mood`/`energyLevel`/`focusLevel` | — | Timeline placement and post-completion check-in content; out of this feature's write path. | REUSE — no change |

Note: `Recording.id` is `@Attribute(.unique)` already in the live model ([#L6](../../app-four/Models/Recording.swift#L6)). This feature introduces **no new** unique or required attribute, so it does not move Principle IX's posture in either direction.

### RecordingStatus (existing enum) — REUSE, no change

Source: [AppEnums.swift#L5-L11](../../app-four/Models/AppEnums.swift#L5). All cases needed already exist:

```
placeholder   // freshly created, pre-transcription
transcribing  // in-progress  → display name "Transcribing…"
completed     // done         → display name = resolved title, check-in content visible
failed        // bounded-out / errored → Retry affordance shown
recorded      // (pre-existing case, unchanged)
```

The feature uses these as a state machine; it adds **no new case**. First-run "preparing model" is *not* a new persisted status — it is a transient phase distinction (below), so the entry's persisted `status` is `.transcribing` throughout download-then-transcribe, while the *display* differentiates the preparation phase.

---

## State machine (over `Recording.status`)

```
            record audio
                 │
                 ▼
         ┌──────────────┐
         │ .placeholder │
         └──────┬───────┘
                │ transcription starts
                ▼
        ┌────────────────┐   first run only: model-preparation phase
        │ .transcribing  │◀─ (transient, in-memory phase = preparingModel),
        └───┬───────┬────┘    then phase = transcribing; status stays .transcribing
            │       │
   success  │       │  exceeds wait bound / error / cancellation
            ▼       ▼
     ┌───────────┐ ┌──────────┐
     │.completed │ │ .failed  │
     └───────────┘ └────┬─────┘
                        │ user taps Retry (re-run vs retained audio)
                        └────────────► back to .transcribing
```

Transition rules (all on `Recording.status`, all driven from `CheckInViewModel`):

| From | Event | To | Notes |
|------|-------|----|-------|
| `.placeholder` | transcription begins | `.transcribing` | set on first streamed/phase signal |
| `.transcribing` | model-preparation phase (first run) | `.transcribing` | status unchanged; *display* shows model-preparation; transcription wait bound NOT yet ticking (research D2) |
| `.transcribing` | successful final result | `.completed` | resolved title + extraction written; entry resolves in place |
| `.transcribing` | exceeds wait bound | `.failed` | existing `RecordingError.timeout` path ([CheckInViewModel.swift#L136](../../app-four/ViewModels/CheckInViewModel.swift#L136)) — value lowered per research D1 |
| `.transcribing` | error segment / empty result | `.failed` | existing error path ([#L142](../../app-four/ViewModels/CheckInViewModel.swift#L142)) |
| `.transcribing` | cancellation (e.g. deleted mid-flight, app teardown) | `.failed` / no-op if entry gone | existing `CancellationError` path ([#L130](../../app-four/ViewModels/CheckInViewModel.swift#L130)); per-segment delete guard ([#L162](../../app-four/ViewModels/CheckInViewModel.swift#L162)) prevents writing to a deleted entry |
| `.failed` | user taps Retry | `.transcribing` | re-runs existing background transcription against retained audio (research D4) |

Invariant (FR-014 / SC-006): no entry remains `.transcribing` indefinitely — every in-progress entry is bounded by the timeout, terminated by an error/empty result, or guarded out on delete/cancel.

---

## Derived (non-persisted) values

### Display name — computed, view layer (research D3)

```
displayName(for recording) =
    (recording.status == .transcribing || recording.status == .placeholder)
        ? "Transcribing…"
        : recording.title
```

- Consumed by the timeline name (`MoodBanner` fallback, [TimelineRow.swift#L57](../../app-four/Views/Components/TimelineRow.swift#L57)) and the detail header ([RecordingDetailView.swift#L54](../../app-four/Views/RecordingDetailView.swift#L54)).
- **Not stored.** Guarantees consistency across surfaces (FR-003) and avoids a persisted placeholder that could survive a crash.

### Transcription phase — transient, in-memory only (research D2)

A typed discriminator carried on the existing `AsyncStream<TranscriptionSegmentDTO>` contract (or an equivalent small signal) distinguishing `preparingModel` from `transcribing`:

- Lives only for the duration of the in-flight stream; **never written to SwiftData**.
- Lets the ViewModel start the transcription wait-bound clock only at the `transcribing` phase, and lets the UI show a distinct model-preparation state while persisted `status` remains `.transcribing`.
- Because it is transient and unpersisted, it has **zero schema impact**.

---

## Schema impact & Principle IX check

| Question | Answer |
|----------|--------|
| New `@Model`? | No. |
| New stored attribute on `Recording`? | No. |
| New `RecordingStatus` case? | No — `.transcribing`, `.failed`, `.completed`, `.placeholder` already cover the machine. |
| New `@Attribute(.unique)` or new required (non-defaulted) attribute? | No. |
| Persisted "retryable" flag needed? | No — `.failed` + retained audio fully expresses retry-eligibility (research D4). |
| Migration required? | No. |

**Principle IX — stays GREEN.** The schema is untouched: no unique constraint added, no required/non-defaulted attribute, so the store remains CloudKit-compatible and the pre-release wipe-and-rebuild posture is unaffected. Because no schema change is introduced, no Complexity Tracking justification is required (the plan's table is empty). Should implementation discover a genuine need to *persist* retry state, that would be a schema change and MUST be justified against the CloudKit path in the plan before merging — the current design deliberately avoids it.
