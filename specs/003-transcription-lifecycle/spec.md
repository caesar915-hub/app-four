# Feature Specification: Transcription Lifecycle (in-progress → done | failed, visible and bounded)

**Feature Branch**: `feat/feedback-specs` (Spec Kit feature `003-transcription-lifecycle`)

**Created**: 2026-06-15

**Status**: Draft

**Input**: Screen-recording feedback plan §4.1 and §4.2, and the "Transcription UX is a state-machine gap" cross-cutting theme (`docs/superpowers/2026-06-15-screen-recording-feedback-plan.md`). Owner walkthrough: a freshly recorded check-in shows its raw fallback name while transcribing instead of a clear "Transcribing…" label, and a long transcription hangs without ever being declared failed.

## User Scenarios & Testing *(mandatory)*

This feature makes the lifecycle of a single check-in's transcription — *in-progress → done | failed* — visible and bounded everywhere the check-in appears. The three stories are the visible half (a clear in-progress label), the bounded half (a long wait becomes a failure the user can retry), and the first-run nuance (a model download is its own honest state, not a hang).

### User Story 1 - In-progress check-in is clearly labelled "Transcribing…" everywhere (Priority: P1)

After finishing a voice check-in, the user sees the new entry appear immediately at the top of today's timeline and, if they open it, in the detail header. While the system is still turning speech into text, that entry is labelled with a clear temporary name — "Transcribing…" — instead of a raw fallback name. When transcription completes, the same entry resolves into a normal check-in (its real title and extracted mood/energy/focus) with no further action from the user.

**Why this priority**: This is the visible foundation of the whole lifecycle. Without it the user cannot tell a fresh entry apart from a finished one, and a slow transcription looks like a broken or mislabelled entry. It is independently valuable even if nothing else in this feature ships: a clear in-progress label is the single most direct fix to the owner's complaint, and it is the surface every other story attaches to.

**Independent Test**: Record a check-in (or place an entry into the in-progress state by any means) and confirm that both the timeline entry and the detail header read "Transcribing…", then confirm both resolve to the normal title once the entry reaches the completed state — without touching timeout or retry behaviour.

**Acceptance Scenarios**:

1. **Given** a check-in that has just finished recording and is still being transcribed, **When** the user looks at today's timeline, **Then** that entry is shown at the top of the day with the temporary name "Transcribing…" rather than a raw fallback name (e.g. a date/time stamp or "Untitled").
2. **Given** an in-progress check-in, **When** the user opens its detail view, **Then** the detail header also shows "Transcribing…" as the name.
3. **Given** an in-progress check-in displayed as "Transcribing…", **When** transcription completes successfully, **Then** the same entry — in both the timeline and the detail header — updates in place to its normal title and resolved check-in content, with no user action required.
4. **Given** an in-progress check-in, **When** it is displayed anywhere it can appear, **Then** the temporary name is consistent (the same wording and treatment) across the timeline and the detail header.

---

### User Story 2 - An over-long transcription fails within a human-scale wait and offers Retry (Priority: P2)

If transcription takes longer than a human would reasonably wait, the entry stops claiming to be "Transcribing…" and is instead marked as failed, with a clear way to try again. The user is never left staring at an indefinite spinner. From either the timeline entry or the detail view, the user can tap Retry to attempt transcription again, and the entry returns to the in-progress ("Transcribing…") state while the retry runs.

**Why this priority**: This is the bounded half of the lifecycle and the owner's explicit ask ("we need to consider that it failed at this point"). Today a wait can run for several minutes before anything changes — far past the point of trust. It depends on Story 1 for the in-progress label that a retry returns the entry to, so it is prioritised second.

**Independent Test**: Force a transcription to exceed the configured wait bound and confirm the entry transitions to failed within that bound (not minutes later); then confirm a Retry control is present in both the timeline entry and the detail view, and that using it returns the entry to "Transcribing…".

**Acceptance Scenarios**:

1. **Given** a check-in whose transcription exceeds the configured human-scale wait bound, **When** the bound is reached, **Then** the entry is marked failed and stops being shown as "Transcribing…".
2. **Given** a check-in marked failed, **When** the user views it in the timeline or the detail view, **Then** a Retry affordance is offered in both places alongside an indication that transcription did not finish.
3. **Given** a failed check-in, **When** the user taps Retry, **Then** transcription is attempted again and the entry returns to the "Transcribing…" in-progress state.
4. **Given** a retried check-in, **When** the retry completes successfully, **Then** the entry resolves to its normal title and check-in content exactly as a first-time success would.
5. **Given** a retried check-in, **When** the retry also exceeds the wait bound, **Then** the entry returns to failed and the Retry affordance remains available.

---

### User Story 3 - First-run model download is shown as its own state, not a hang (Priority: P3)

The first time the user ever transcribes anything, the system must obtain a sizeable on-device model before any speech can be turned into text. During that one-time download the entry communicates that a model is being prepared — a distinct, honest state — rather than appearing to hang or being wrongly counted against the transcription wait bound and failed. Once the model is ready, the entry proceeds into normal transcription and the wait bound applies to the transcription itself.

**Why this priority**: It removes the worst false-positive failure: a first-run download that is working correctly but slow being declared a hang. It only matters on first use (or after the model is removed), so it is the lowest priority of the three, but it protects the credibility of Story 2's failure rule.

**Independent Test**: With no model yet present, start a transcription and confirm the entry shows a model-preparation state distinct from "Transcribing…", that the transcription wait bound is not charged against the download time, and that once the model is ready the entry proceeds into normal "Transcribing…" and then completion.

**Acceptance Scenarios**:

1. **Given** no transcription model is present yet, **When** the user records a check-in that triggers transcription, **Then** the entry shows a model-preparation state distinct from the ordinary "Transcribing…" state.
2. **Given** a model is being prepared on first run, **When** the preparation takes longer than the transcription wait bound, **Then** the entry is NOT failed solely on account of the download time.
3. **Given** the model finishes preparing, **When** transcription begins, **Then** the entry moves into the normal "Transcribing…" state and the wait bound applies to the transcription itself.
4. **Given** a model already present from a prior run, **When** the user records a check-in, **Then** no model-preparation state is shown and the entry goes straight to "Transcribing…".

---

### Edge Cases

- **No speech detected**: A check-in that contains no intelligible speech must reach a terminal state (a successful empty/near-empty result or a clear failure) and must not remain "Transcribing…" indefinitely.
- **App backgrounded mid-transcription**: If the app is backgrounded while an entry is transcribing, on return the entry must reflect a correct terminal or in-progress state — it must not be silently stuck on "Transcribing…" with no underlying work in flight.
- **Model still downloading when a second check-in is recorded**: A new check-in recorded while the first-run model is still being prepared must queue/await the model rather than being immediately failed for the shared download time.
- **Retry after failure (repeated)**: A user may retry a failed entry more than once; each retry must behave like a fresh attempt (in-progress → done | failed) and the Retry affordance must persist as long as the entry is failed.
- **Entry deleted mid-transcription**: If the user deletes an entry while it is transcribing, the in-flight work must not resurrect the entry or write state back to a deleted item.
- **Very long audio**: A long recording legitimately takes longer to transcribe than a short one; the wait bound must accommodate the longest allowed recording so that long-but-healthy transcriptions are not falsely failed. [NEEDS CLARIFICATION: should the wait bound be a fixed value, or scale with audio length (e.g. a base allowance plus a per-second factor)? Proposed: a fixed human-scale bound in the 60–90 s range for typical short check-ins, raised proportionally for longer audio — confirm the exact shape.]

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: While a check-in's transcription is in progress, the system MUST display the temporary name "Transcribing…" for that entry in the day timeline.
- **FR-002**: While a check-in's transcription is in progress, the system MUST display the temporary name "Transcribing…" for that entry in the recording detail header.
- **FR-003**: The temporary in-progress name MUST be consistent in wording and treatment across every place an entry can appear (timeline and detail header).
- **FR-004**: When transcription completes successfully, the system MUST resolve the entry in place to its normal title and check-in content in both the timeline and the detail header, without requiring any user action.
- **FR-005**: The system MUST bound how long an entry may remain in the in-progress transcription state; when the bound is exceeded, the entry MUST be marked failed and MUST stop being shown as "Transcribing…".
- **FR-006**: The wait bound for transcription MUST be human-scale rather than multi-minute, so that a stuck transcription is declared failed within a time a user would plausibly wait. [NEEDS CLARIFICATION: exact bound — proposed 60–90 s for typical short check-ins; confirm value and whether it scales with audio length.]
- **FR-007**: A failed entry MUST present a Retry affordance in both the day timeline and the recording detail view.
- **FR-008**: When the user invokes Retry on a failed entry, the system MUST attempt transcription again and return the entry to the in-progress "Transcribing…" state for the duration of the retry. [NEEDS CLARIFICATION: does Retry re-run transcription only, or may it also re-prepare the model if the model is missing/corrupt? Proposed: Retry re-runs transcription and prepares the model only if it is not already available.]
- **FR-009**: A retried entry MUST follow the same lifecycle as a first attempt — resolving to normal content on success, or returning to failed if it again exceeds the wait bound — with the Retry affordance remaining available while failed.
- **FR-010**: The system MUST distinguish a first-run model-preparation period from active transcription, presenting model preparation as its own state distinct from "Transcribing…".
- **FR-011**: The transcription wait bound MUST NOT be charged against time spent preparing the model on first run; a slow but healthy first-run model preparation MUST NOT, by itself, cause the entry to be marked failed.
- **FR-012**: Once the model is prepared, the system MUST move the entry into the normal "Transcribing…" state and apply the wait bound to the transcription itself.
- **FR-013**: When a model is already available, the system MUST NOT show a model-preparation state and MUST take the entry straight to "Transcribing…".
- **FR-014**: Every entry MUST reach a terminal state (completed or failed); no entry may remain in the in-progress state indefinitely, including the no-speech, backgrounded, and deleted-mid-flight cases.
- **FR-015**: Diagnostic and log output for this lifecycle MUST record only counts, durations, state names, and token estimates — never transcript text or any check-in content.

### Key Entities *(include if feature involves data)*

- **Check-in entry**: A single recorded check-in that owns a transcription lifecycle. Relevant attributes for this feature are its lifecycle state (in-progress / completed / failed, plus the pre-transcription placeholder), its displayed name (a temporary "Transcribing…" while in progress, a resolved title once complete), and its derived check-in content (mood/energy/focus) which only appears once complete.
- **Transcription lifecycle state**: The state a check-in moves through — placeholder → in-progress (with first-run model-preparation as a distinguished sub-state) → completed | failed, with failed being re-entrant via Retry back into in-progress. The set of states already exists in the system; this feature makes the transitions and their display bounded and consistent.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of in-progress check-ins display the name "Transcribing…" in both the timeline and the detail header (no entry shows a raw fallback name while transcribing).
- **SC-002**: A check-in whose transcription stalls is marked failed within the configured human-scale wait bound (target 60–90 s for typical short check-ins), never lingering minutes past it.
- **SC-003**: 100% of failed check-ins present a working Retry affordance in both the timeline and the detail view.
- **SC-004**: A successful retry resolves the entry to the same normal title and check-in content as a first-time success in 100% of cases.
- **SC-005**: On a first run with no model present, 0% of entries are marked failed solely because the one-time model preparation exceeded the transcription wait bound.
- **SC-006**: No check-in remains in the in-progress state indefinitely across the tested edge cases (no speech, backgrounded mid-flight, deleted mid-flight): every entry reaches completed or failed.
- **SC-007**: No transcript text or check-in content appears in any diagnostic or log output produced by this lifecycle.

## Assumptions

- The lifecycle states needed (placeholder, in-progress/transcribing, completed, failed) already exist in the system, so this feature is primarily about making the transitions bounded and the states consistently visible rather than inventing new states.
- A failed entry is recoverable purely by re-running transcription against the already-captured audio; no re-recording is required, and the original audio remains available for retry.
- "Human-scale wait" is taken to mean tens of seconds, not minutes; the precise bound (and whether it scales with audio length) is the open clarification above, with 60–90 s proposed for typical short check-ins and a longer allowance for the longest permitted recordings.
- The first-run model download is a one-time cost; after the model is present, no model-preparation state is expected on subsequent transcriptions until the model is removed or invalidated.
- Mood/energy/focus extraction that follows a successful transcription is out of scope here — this feature is responsible only up to a resolved title and the entry leaving the in-progress state; downstream extraction is assumed to proceed as it does today.
- All transcription and state handling remain fully on-device; nothing about this lifecycle introduces a network dependency beyond the one-time model download.
