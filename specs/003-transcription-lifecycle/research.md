# Phase 0 Research: Transcription Lifecycle

**Feature**: `003-transcription-lifecycle` | **Branch**: `feat/feedback-specs` | **Date**: 2026-06-15
**Spec**: [spec.md](spec.md) · **Plan**: [plan.md](plan.md)
**Provenance**: feedback plan §4.1, §4.2, "Transcription UX is a state-machine gap" (`docs/superpowers/2026-06-15-screen-recording-feedback-plan.md`)

Each decision below records what was chosen, why, and the alternatives rejected. All line citations were confirmed against the live source on 2026-06-15.

---

## D1 — Transcription wait bound: value and whether it scales with audio length

**Context**: A timeout already exists. `CheckInViewModel.consumeStreamWithTimeout(_:for:timeoutSeconds:)` races the stream consumer against a sleep of `timeoutSeconds`, throwing `RecordingError.timeout` ([CheckInViewModel.swift#L151](../../app-four/ViewModels/CheckInViewModel.swift#L151)); it is invoked with `timeoutSeconds: 300` ([#L119](../../app-four/ViewModels/CheckInViewModel.swift#L119)). The `.timeout` catch already sets `recording.status = .failed` ([#L136-L141](../../app-four/ViewModels/CheckInViewModel.swift#L136)). The maximum recording length is bounded: `LayoutConstants.maxRecordingDuration = 480` s (8 min) ([Constants.swift#L10](../../app-four/Utils/Constants.swift#L10)). The service estimates transcription size as `~100 tokens/sec` of audio ([WhisperKitTranscriptionService.swift#L88](../../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L88)).

**Decision**: Lower the bound to a human scale and make it **proportional to audio length with a floor**: `bound = max(base, k · audioDuration)`, with a proposed `base` in the **60–90 s** range and `k` chosen so the longest permitted recording (480 s) still has comfortable headroom over its expected transcribe time. The exact `base`, `k`, and ceiling are flagged `[NEEDS CLARIFICATION]` in the spec (FR-006) for owner confirmation. The bound applies to **transcription only**, not to model preparation (see D2).

**Why**: 300 s is far past the point a user trusts the app (the owner's "it failed at this point" was triggered well under a minute). A flat short bound, however, would falsely fail a healthy long recording — Whisper-Small runs slower than real-time on long clips, and recordings can legitimately be 8 minutes. Proportional-with-floor keeps short check-ins (the common case) honest at tens of seconds while not punishing the rare long one.

**Alternatives rejected**:
- *Flat 60–90 s for all audio* — simplest, but falsely fails long-but-healthy transcriptions; violates spec Edge Case "very long audio".
- *Keep 300 s* — the status quo; fails the owner's core ask and SC-002.
- *No timeout, rely on cancellation* — leaves entries stuck "Transcribing…" forever; violates FR-014.

---

## D2 — Separating model download from transcription

**Context**: On first run the service must download a ~150 MB model before any transcription. Today it signals this by **yielding a display string** into the same `AsyncStream<TranscriptionSegmentDTO>`: `"Downloading AI Model (~150MB)... Please wait."` ([WhisperKitTranscriptionService.swift#L105](../../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L105)), then `"Transcribing with Whisper..."` ([#L120](../../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L120)). Both flow through `consumeStreamWithTimeout`, which marks `recording.status = .transcribing` on every non-error segment ([CheckInViewModel.swift#L167](../../app-four/ViewModels/CheckInViewModel.swift#L167)) — so the download phase is currently counted against the (300 s) transcription timeout and is indistinguishable from real transcription except by parsing the yielded text.

**Decision**: Make the phase **typed and explicit** on the existing stream contract rather than inferred from display strings — e.g. a `phase` discriminator (`preparingModel` / `transcribing`) on the segment DTO (or a small dedicated signal), so the ViewModel can (a) present a distinct model-preparation state and (b) **start the transcription timeout clock only when the `transcribing` phase begins**, leaving download time un-bounded by the transcription bound.

**Why**: Spec FR-010–FR-013 and SC-005 require the download to be its own honest state and *not* charged against the transcription bound. Parsing user-facing strings to drive control flow is brittle (breaks on copy edits, untestable as a contract) and conflates display with state — counter to Principle VIII (capability behind a protocol contract). A typed phase is the minimal correct seam.

**Alternatives rejected**:
- *Keep inferring from the yielded string* — brittle, couples logic to display copy, hard to unit-test; the current cause of the download being mis-timed.
- *A second, separate "download" stream/method* — larger surface than needed; the existing single stream already carries ordered phases, so one typed discriminator suffices (Principle IV).
- *Pre-download the model entirely outside this flow and never show a state* — the app already preloads opportunistically on `startRecording` ([CheckInViewModel.swift#L74](../../app-four/ViewModels/CheckInViewModel.swift#L74)), but that can still be incomplete at stop time on a true first run, so the in-flow state is still required.

---

## D3 — Where the "Transcribing…" display name is derived (computed vs stored)

**Context**: `Recording.title` is a **stored** SwiftData property defaulting to `"Untitled"` ([Recording.swift#L14](../../app-four/Models/Recording.swift#L14), [#L58](../../app-four/Models/Recording.swift#L58)); the real title is written only after extraction ([#L212](../../app-four/Models/Recording.swift#L212)). The timeline renders the name via `MoodBanner(fallbackTitle: recording.title …)` ([TimelineRow.swift#L57](../../app-four/Views/Components/TimelineRow.swift#L57)); the detail header renders `viewModel.recording.title` ([RecordingDetailView.swift#L54](../../app-four/Views/RecordingDetailView.swift#L54)). The detail transcript section *already* special-cases `status == .transcribing` to show "Transcribing with Whisper…" ([#L110-L117](../../app-four/Views/RecordingDetailView.swift#L110)) — but the title/name and the timeline do not.

**Decision**: Derive the display name from `status` at the **view layer** (a computed presentation, e.g. `displayName` returning "Transcribing…" when `status` is `.transcribing`/`.placeholder`, else `title`). Do **not** write "Transcribing…" into the stored `title`.

**Why**: The temporary name is a function of state, not data — storing it would mean writing a placeholder string and later overwriting it, risking a persisted "Transcribing…" if the app dies mid-flight (an entry that can never resolve). Computing it keeps `title` meaning "the resolved title" and keeps the display consistent across surfaces by construction (FR-003). It also needs no schema change (Principle IX) and no migration. The detail view already proves the pattern for the transcript body; this extends the same status-driven derivation to the name.

**Alternatives rejected**:
- *Store "Transcribing…" in `title` while in progress* — risks a stuck placeholder on crash; adds a write/overwrite cycle; muddies the meaning of `title`.
- *A separate stored `displayName` field* — new persisted field for a value fully derivable from `status`; violates Principle IV and adds schema surface for nothing.

---

## D4 — Retry mechanism

**Context**: The `.failed` status pill already renders in the detail view ([RecordingDetailView.swift#L147-L148](../../app-four/Views/RecordingDetailView.swift#L147)), and the timeout catch already leaves a retry-hint string in `fullTranscriptText` ([CheckInViewModel.swift#L140](../../app-four/ViewModels/CheckInViewModel.swift#L140)) — but no actual Retry control exists, in either the timeline or the detail. The original audio is retained (`recording.audioURL`), and the transcription orchestration (`transcribeInBackground` / `consumeStreamWithTimeout`) already exists and is re-runnable. Transcription sits behind `TranscriptionService` ([Protocols.swift#L27](../../app-four/Services/Protocols.swift#L27)).

**Decision**: Add a **`retry(_ recording:)`-style entry point on `CheckInViewModel`** that re-invokes the existing background transcription path against the already-captured `audioURL`, flipping `status` back to `.transcribing` for the duration. Surface it as a Retry control in both the timeline row (on `.failed`) and the detail view (next to the existing `.failed` pill). Retry **re-runs transcription**, and prepares the model only if it is not already available (it normally is); it does **not** force a re-download of an existing healthy model. This nuance is flagged `[NEEDS CLARIFICATION]` in the spec (FR-008) for confirmation.

**Why**: The audio is intact, so recovery is a pure re-transcription — no re-recording, no new persisted state beyond the already-existing `.failed → .transcribing` status flip (Principle IX stays green, see data-model). Reusing the existing orchestration avoids a parallel code path (Principle IV) and inherits the same timeout/cancellation guards.

**Alternatives rejected**:
- *Retry always re-downloads the model* — wasteful and slow on the common case (model already present); only correct when the model is genuinely missing/corrupt, which `loadModel()` already handles lazily.
- *Persist a dedicated "retryable" flag* — unnecessary; `.failed` + retained audio already fully expresses retry-eligibility (avoids a schema change).
- *Auto-retry on timeout without user action* — hides failure and could loop on a genuinely unprocessable clip; the owner asked to *see* failure, and FR-007 requires an explicit affordance.

---

## D5 — Guaranteeing a terminal state (no permanent "Transcribing…")

**Context**: Spec FR-014 / SC-006 require every entry to reach completed or failed across edge cases. The consumer already guards against the recording being deleted mid-stream (`store.recordings.contains` per segment, [CheckInViewModel.swift#L162](../../app-four/ViewModels/CheckInViewModel.swift#L162)) and against cancellation (`catch is CancellationError` → `.failed`, [#L130](../../app-four/ViewModels/CheckInViewModel.swift#L130)). The service strips non-speech markers and throws `"No transcription result"` on empty output ([WhisperKitTranscriptionService.swift#L157](../../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L157)), which surfaces as an error segment → terminal `.failed`.

**Decision**: Rely on the existing terminal-state guarantees (timeout, cancellation, error-segment, delete-guard) and verify them by test rather than adding new machinery; the no-speech case resolves to a terminal state via the existing empty-result error path. The one behavioural addition is ensuring an app-backgrounded-mid-flight entry is not left displaying "Transcribing…" with no work in flight — covered because the display name is computed from `status` (D3) and the timeout/cancellation paths set a terminal `status`.

**Why**: The machinery already exists; the gap was display and the over-long bound, not the absence of terminal transitions. Principle III/IV favour verifying existing correctness over adding parallel safeguards.

**Alternatives rejected**:
- *A watchdog that periodically scans for stuck entries* — redundant given the per-attempt timeout already bounds each in-progress entry; adds a background scanner for a case the timeout already covers.

---

## Open clarifications carried into the spec

- **FR-006 / D1**: exact `base`, per-second factor, and ceiling for the proportional timeout (proposed base 60–90 s).
- **FR-008 / D4**: whether Retry may re-download the model or strictly re-runs transcription against the existing model (proposed: re-run only, prepare model solely if missing).
