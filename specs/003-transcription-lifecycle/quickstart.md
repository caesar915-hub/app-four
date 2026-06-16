# Quickstart & Validation: Transcription Lifecycle

**Feature**: `003-transcription-lifecycle` | **Branch**: `feat/feedback-specs` | **Date**: 2026-06-15
**Spec**: [spec.md](spec.md) · **Plan**: [plan.md](plan.md) · **Research**: [research.md](research.md) · **Data model**: [data-model.md](data-model.md)

This maps every acceptance scenario and Success Criterion to a concrete check — manual on a booted simulator/device, and automated in `app-fourTests`. Per Principle II, the build and full test suite MUST pass via the `ios-debugger-agent` (XcodeBuildMCP) skill before this feature is reported done.

---

## Build gate (Principle II)

1. Build the `app-four` scheme and run the full test suite using the **`ios-debugger-agent`** skill (XcodeBuildMCP) on a booted iOS 26 simulator. Do not ask — just run it.
2. The PR is not ready until the build is clean and the suite is green on `feat/feedback-specs`.
3. Run `/code-review` on the diff and surface findings before merge (Principle V).

---

## Manual validation

### Story 1 — In-progress check-in labelled "Transcribing…" (P1)

| Step | Expectation | Maps to |
|------|-------------|---------|
| Record a short voice check-in and return to today's timeline before transcription finishes. | The new entry sits at the top of the day labelled **"Transcribing…"**, not a date/time stamp or "Untitled". | AS1.1, FR-001, SC-001 |
| Open that in-progress entry's detail. | The detail **header name** also reads **"Transcribing…"**. | AS1.2, FR-002, SC-001 |
| Wait for transcription to complete with the detail open, then return to the timeline. | The same entry resolves **in place** to its real title and shows mood/energy/focus content — no tap required — in both detail and timeline. | AS1.3, FR-004 |
| Compare the in-progress wording/treatment between timeline and header. | Identical wording and treatment in both surfaces. | AS1.4, FR-003 |

### Story 2 — Over-long transcription fails within a human-scale wait, with Retry (P2)

| Step | Expectation | Maps to |
|------|-------------|---------|
| Force transcription to stall past the configured bound (e.g. inject a non-yielding mock `TranscriptionService`, or a clip that exceeds the bound). | Within the configured human-scale bound (target 60–90 s for a short check-in), the entry flips to **failed** and stops showing "Transcribing…". | AS2.1, FR-005, FR-006, SC-002 |
| Inspect the failed entry in both the timeline and the detail view. | A **Retry** affordance is present in **both**, alongside a clear "did not finish" indication (the `.failed` status pill stays in detail). | AS2.2, FR-007, SC-003 |
| Tap **Retry**. | The entry returns to **"Transcribing…"** and a fresh attempt runs against the existing audio (no re-recording). | AS2.3, FR-008 |
| Let a retry succeed. | Resolves to normal title + content exactly like a first-time success. | AS2.4, FR-009, SC-004 |
| Make a retry also exceed the bound. | Entry returns to **failed**; Retry remains available. | AS2.5, FR-009 |

### Story 3 — First-run model download is its own state, not a hang (P3)

| Step | Expectation | Maps to |
|------|-------------|---------|
| With **no model present** (fresh install / model removed), record a check-in that triggers transcription. | The entry shows a **model-preparation** state distinct from ordinary "Transcribing…". | AS3.1, FR-010 |
| Let preparation run longer than the transcription wait bound. | The entry is **not** marked failed for the download time alone. | AS3.2, FR-011, SC-005 |
| Let the model finish preparing. | Entry moves into normal **"Transcribing…"**; the wait bound now applies to transcription itself. | AS3.3, FR-012 |
| Record again **with the model already present**. | **No** model-preparation state; entry goes straight to "Transcribing…". | AS3.4, FR-013 |

### Edge cases

| Case | Expectation | Maps to |
|------|-------------|---------|
| Record a clip with no intelligible speech. | Entry reaches a terminal state (empty success or clear failure) — never stuck "Transcribing…". | Spec edge case, FR-014, SC-006 |
| Background the app mid-transcription, return. | Entry reflects a correct terminal/in-progress state; not silently stuck "Transcribing…" with no work in flight. | Spec edge case, FR-014, SC-006 |
| Record a second check-in while the first-run model is still preparing. | The second entry awaits the model rather than being immediately failed for the shared download time. | Spec edge case, FR-011 |
| Delete an entry while it is transcribing. | In-flight work does not resurrect the entry or write to a deleted item. | Spec edge case, FR-014 |
| Record the longest permitted clip (8 min) and let it transcribe healthily. | A long-but-healthy transcription is **not** falsely failed (bound accommodates `maxRecordingDuration`). | Spec edge case "very long audio", FR-006 |
| Inspect logs during all of the above. | Logs/diagnostics contain only counts, durations, state names, token estimates — **no** transcript text or check-in content. | FR-015, SC-007 |

---

## Automated tests to add

Target: `app-fourTests/ViewModels/CheckInViewModelTests.swift` (extend the existing file). Drive `CheckInViewModel` with an in-memory `RecordingStore` and an injected mock `TranscriptionService` conforming to [`TranscriptionService`](../../app-four/Services/Protocols.swift#L27) so timing and phases are controllable without WhisperKit.

| Test | Asserts | Maps to |
|------|---------|---------|
| `test_timeout_marksFailed_atConfiguredBound` | A mock service that yields the `transcribing` phase then never finishes causes `recording.status == .failed` once the configured bound elapses — and **not** before (assert it is still `.transcribing` just under the bound). | FR-005, FR-006, SC-002 |
| `test_displayName_isTranscribing_whenInProgress` | The status→display-name derivation returns `"Transcribing…"` for `.transcribing` and `.placeholder`, and the resolved `title` for `.completed`/`.failed`. | FR-001, FR-002, FR-003, SC-001 |
| `test_retry_transitionsBackToTranscribing` | Invoking the retry entry point on a `.failed` recording sets `status == .transcribing` and re-invokes the service against the same `audioURL`. | FR-008, AS2.3 |
| `test_retrySuccess_resolvesToCompleted` | A retry whose mock yields a final result reaches `.completed` with a resolved title, same as a first-time success. | FR-009, SC-004 |
| `test_modelPreparation_notCountedAgainstTranscriptionBound` | A mock that holds in the `preparingModel` phase past the transcription bound, then transitions to `transcribing`, does **not** mark `.failed` for the preparation time; the bound starts only at the `transcribing` phase. | FR-010, FR-011, FR-012, SC-005 |
| `test_modelAlreadyPresent_skipsPreparationState` | When the mock reports the model ready, no `preparingModel` phase is observed and the entry goes straight to `transcribing`. | FR-013, AS3.4 |
| `test_emptyResult_reachesTerminalState` | A mock yielding an empty/error result drives the entry to `.failed` (terminal), not a stuck `.transcribing`. | FR-014, SC-006 |
| `test_deletedMidFlight_doesNotResurrect` | Removing the recording from the store mid-stream means subsequent segments do not write back state (existing per-segment guard, [CheckInViewModel.swift#L162](../../app-four/ViewModels/CheckInViewModel.swift#L162)). | FR-014 |
| `test_logs_containNoTranscriptText` | Captured log/diagnostic output for a transcription run contains no transcript text or check-in content (counts/durations/state-names only). | FR-015, SC-007 |

Notes:
- Where the bound is proportional to audio length (research D1), parameterise the test over a short and a max-length (`LayoutConstants.maxRecordingDuration = 480 s`) duration to prove a long-but-healthy clip is not falsely failed.
- Keep the mock `TranscriptionService` phase-aware so the same mock exercises Stories 2 and 3 without touching WhisperKit or the network.

---

## Definition of done

- All manual checks above pass on a booted iOS 26 simulator.
- All listed automated tests are added and green; the full `app-four` suite is green via `ios-debugger-agent`.
- Both open clarifications (FR-006 timeout value/shape; FR-008 retry-vs-redownload) are resolved with the owner and the constants/behaviour reflect the decision.
- No transcript text appears in any log/diagnostic output (FR-015 / SC-007 spot-checked).
- `/code-review` run on the diff; `main` stays releasable (Principle V).
