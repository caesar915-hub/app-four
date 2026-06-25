# Feature Specification: Check-in — Capture That Lands

**Feature Branch**: `016-checkin-capture-feel`

**Created**: 2026-06-23

**Status**: Draft

**Input**: Approved direction from [brainstorm-checkin.md](../../docs/brainstorm-checkin.md) + [ux-critique-checkin.md](../../docs/ux-critique-checkin.md). The owner has accepted the recommended thread of each brainstorm thread.

## Overview *(non-normative)*

The Check-in tab is Squirl's primary capture surface and the screen the whole product reward model rests on: "I said it and it's captured" ([DESIGN.md#L86](../../DESIGN.md#L86)). The screen is already strong and on-brand (critique verdict: Nielsen 31/40, "authored, not generated"), but the moment of capture currently lands with no felt confirmation, the "Captured." screen dead-ends in two identical buttons, the recording prompts are invisible to VoiceOver, save failures discard the capture silently, and `startRecording()` can fire re-entrantly. This feature makes the capture moment *land in the body*, makes the unhappy paths *never lose a capture*, finishes the *VoiceOver story*, and fixes the *double-start bug* — without reopening any loop the Saved state was designed to close.

Explicitly **out of scope** (deferred to future specs, per the approved direction): the "field remembers you" idle-ring continuity treatment; adaptive Speak/Type/Log-meds weighting; a post-save "Echo" of what was heard; full resume-the-same-recording after an interruption; the wildcard heads-down / spoken-send-off modes.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The Settle: capture lands in the body (Priority: P1)

A user finishes speaking and taps "Stop & save". Instead of the recording ring vanishing and a brand-new checkmark cross-dissolving in from a separate screen, the recording crescent decelerates from its spin, contracts, and its stroke redraws into a checkmark *in place* — landing with one soft success haptic at the exact frame the check completes. "Captured." fades in beneath it. A single "Done" button returns the user to the calm hub. There is no second button to weigh.

**Why this priority**: This is the product's stated signature motion ([DESIGN.md#L80](../../DESIGN.md#L80), [#L92](../../DESIGN.md#L92)) that is currently unmet — the highest-identity, lowest-feature-creep win. For a time-blind, reassurance-hungry audience, an un-felt confirmation is a confirmation that doesn't fully land. The redundant second button ("Check in again" is behaviorally identical to "Done", [CheckInView.swift#L308-311](../../app-four/Views/CheckIn/CheckInView.swift#L308)) implies a choice that doesn't exist and wastes the one beat the user is paying attention. Delivers the felt reward and removes the false fork in one slice; it is the MVP.

**Independent Test**: Record a voice check-in, tap Stop & save, and confirm (a) the ring visibly morphs into the check rather than cross-dissolving, (b) exactly one success haptic fires as the check completes, (c) the Saved screen shows a single "Done" that returns to the idle hub. Under Reduce Motion, confirm the check appears in its final state instantly with the same single haptic. Fully demonstrable without any other story.

**Acceptance Scenarios**:

1. **Given** a recording is in progress, **When** the user taps "Stop & save" and the save succeeds, **Then** the crescent morphs in place into a checkmark and exactly one success haptic fires as the morph completes.
2. **Given** the save has completed and the Settle has played, **When** the user views the Saved state, **Then** a single "Done" button is shown (no "Check in again") and tapping it returns to the idle hub.
3. **Given** Reduce Motion is enabled, **When** the save completes, **Then** the checkmark is shown already in its final state (no spin/contract/redraw) and the single success haptic still fires once.
4. **Given** a text check-in is saved from the composer, **When** the Saved state appears, **Then** the same single success haptic fires once and the same single-"Done" Saved screen is shown.
5. **Given** the save completes, **When** the Settle plays, **Then** no second haptic, no duplicate haptic, and no haptic on entering recording or on the hub is produced.

---

### User Story 2 - Never lose a capture (Priority: P1)

A user speaks a check-in and taps "Stop & save", but the save or file-write fails. Instead of the screen silently snapping back to the empty hub with the capture gone, the audio is held in a retry buffer and a calm inline line appears — "Couldn't save that one — tap to try again" — with a gentle error haptic. Tapping it re-attempts the save from the buffered audio. The capture is never discarded without the user's knowledge.

**Why this priority**: The product's one promise is "it's captured"; that promise breaks completely if a save can silently evaporate. The critique flags the current silent reset to `.idle` as a P2 trust failure ([CheckInViewModel.swift#L115-118](../../app-four/ViewModels/CheckInViewModel.swift#L115)). For an impulsive, time-blind audience mid-thought, a vanished recording reads as the app failing them — corrosive to the trust the whole product depends on. This is the trust-critical floor and ships independently of the Settle.

**Independent Test**: Force a stop/save failure (mock the storage/audio service to throw), confirm the screen shows the inline "try again" line instead of resetting to idle, confirm the buffered audio survives, tap "try again" with the failure cleared, and confirm the check-in then saves and reaches the Saved state. The capture is recoverable at every step.

**Acceptance Scenarios**:

1. **Given** a recording is in progress, **When** the user taps "Stop & save" and the save throws, **Then** the screen shows a non-alarming inline "try again" affordance (never a silent reset to idle) and a single error haptic fires.
2. **Given** a save has failed and the retry affordance is showing, **When** the user taps "try again" and the underlying condition has cleared, **Then** the buffered audio is saved and the flow proceeds to the Saved state (Settle + success haptic).
3. **Given** a save has failed and the retry affordance is showing, **When** the user taps "try again" and it fails again, **Then** the retry affordance remains and the buffered audio is still retained (no discard, no idle reset).
4. **Given** a save failed and the user has not retried, **When** the user instead chooses to discard, **Then** the buffer is cleared, the recording is released, and the screen returns to the idle hub.
5. **Given** the copy of any failure surface, **When** it is shown, **Then** it is worded as "try again" / recovery, never "something went wrong" / blame, and uses no red alarm styling.

---

### User Story 3 - The recording experience is heard (Priority: P2)

A VoiceOver user starts a voice check-in. They hear the current prompt; when the prompt advances they hear the new prompt announced; the recording crescent + timer are exposed as a single status that reads "Recording, 0:42 elapsed" and updates as a live region; and when they finish, they hear the state transitions ("Saving…", then "Captured."). Announcements are gated so the app never speaks over the user while the mic is actively picking up their voice.

**Why this priority**: The rotating prompts *are* the recording UX, yet they are entirely silent to VoiceOver — the dots and progress bar are `accessibilityHidden`, prompt rotation posts no announcement ([CheckInView.swift#L205](../../app-four/Views/CheckIn/CheckInView.swift#L205), [#L245](../../app-four/Views/CheckIn/CheckInView.swift#L245); [CheckInViewModel.swift#L244-250](../../app-four/ViewModels/CheckInViewModel.swift#L244)), and there is no live region for state transitions. A VoiceOver user hears the first prompt once, then nothing — the screen's whole reason for existing while recording is eyes-only. This audience has high ADHD/sensory-disability overlap; the gap is a P1 in the critique's accessibility audit. P2 here because the Settle and the no-lost-capture floor land value for everyone first; this completes the experience for the users most reliant on it.

**Independent Test**: With VoiceOver on, start a recording and confirm: the first prompt is spoken; on the visual prompt swap a new announcement is heard; the crescent+timer read as "Recording, [elapsed]" and update; on Stop the "Saving…" then "Captured." transitions are announced; and no announcement fires while the level meter shows active voice. Verifiable as a standalone accessibility pass.

**Acceptance Scenarios**:

1. **Given** VoiceOver is on and a recording is in progress, **When** the visual prompt advances to the next nudge, **Then** the new prompt's question (and hint) is announced — and is NOT announced while the audio level indicates the user is actively speaking (deferred until a pause).
2. **Given** VoiceOver is on and a recording is in progress, **When** the user navigates to the recording status, **Then** the crescent + timer are a single grouped element labeled "Recording, [elapsed] elapsed" that updates as a live region as time passes (throttled to avoid chatter).
3. **Given** VoiceOver is on, **When** the state transitions to processing then done, **Then** "Saving…" and then "Captured." are posted as announcements.
4. **Given** VoiceOver is on, **When** a save failure occurs, **Then** the inline retry affordance (US2) is announced and is reachable/operable by VoiceOver, and its tap target is at least 44×44pt.
5. **Given** the hand-rolled recording controls (Stop & save, Cancel) and the retry affordance, **When** measured, **Then** each meets the 44pt minimum tap target ([Metrics.swift#L10](../../app-four/DesignSystem/Metrics.swift#L10)).

---

### User Story 4 - The 8-minute cliff becomes a soft landing (Priority: P2)

A user is recording a long check-in. As the 8-minute cap approaches (in the final stretch), a single calm cue appears once — a faint line such as "wrapping up soon" — not a ticking countdown. At the cap, instead of a hard drop straight to Saved, the recording finishes gracefully into the same Settle/Captured moment, so a forced stop still feels like a successful capture rather than a cut-off.

**Why this priority**: Today the cap cuts the user off mid-thought and drops straight to Saved with no warning ([CheckInViewModel.swift#L282-285](../../app-four/ViewModels/CheckInViewModel.swift#L282)). A gentle approach cue serves time-blind users who can't feel 8 minutes passing ([DESIGN.md#L9](../../DESIGN.md#L9)); routing the forced stop through the Settle makes even a capped recording feel captured, not failed. P2 because 8 minutes is long and this path is rare — high polish, low frequency — and it builds on the Settle (US1).

**Independent Test**: Drive elapsed time toward the cap and confirm (a) the soft approach cue appears exactly once in the final stretch (and never re-appears, never ticks), and (b) at the cap the recording saves through the same Settle + success haptic path as a manual stop, landing on the Saved screen. Verifiable by advancing the timer in isolation.

**Acceptance Scenarios**:

1. **Given** a recording is in progress, **When** elapsed time enters the final approach window before the cap, **Then** a single soft "approaching the cap" cue is shown once (not a ticking countdown, no red, no alarm) and does not repeat.
2. **Given** a recording reaches the 8-minute cap, **When** the auto-stop fires, **Then** the recording is saved and the flow lands on the Saved state via the same Settle + single success haptic as a manual Stop & save (no hard drop).
3. **Given** the cap auto-stop saves successfully, **When** the Saved screen appears, **Then** it is indistinguishable from a manually-stopped capture (single "Done", "Captured.").
4. **Given** the cap auto-stop save *fails*, **When** the failure occurs, **Then** it routes through the same never-lose-a-capture retry surface (US2) rather than discarding.

---

### User Story 5 - First-launch whisper hint (Priority: P3)

On the very first launch of the Check-in tab only, a single low-contrast line appears under the headline — e.g. "Tap Speak and just talk — a minute, then you're done." — and a one-time faint caption under the idle crescent defusing the "is this a button?" question (e.g. "just breathing — tap Speak when ready"). The hint fades the first time the user starts any capture and never reappears. No coachmarks, no carousel, no demo recording. The idle ring stays purely ambient.

**Why this priority**: A brand-new user and a 100-day user currently see the identical "Ready when you are." with no hint that voice is the fast path, and the breathing crescent (~40% of the screen) may be misread as a progress bar or tap target ([critique §5](../../docs/ux-critique-checkin.md), §9). This is the lightest possible touch that closes the first-run orientation gap and the ring ambiguity in one stroke, and self-erases for everyone after day 1. P3 because it serves only the first session and is pure additive polish.

**Independent Test**: On a fresh install, open the Check-in tab and confirm both the headline hint and the ring caption are visible; start any capture; confirm they fade and, on every subsequent visit, never reappear. Verifiable with a cleared first-run flag.

**Acceptance Scenarios**:

1. **Given** the Check-in tab has never been used (first-run flag unset), **When** the idle hub appears, **Then** the one-time headline hint and the one-time ring caption are shown.
2. **Given** the first-launch hint is showing, **When** the user starts any capture (voice or text), **Then** the hint and caption are dismissed and the first-run flag is set.
3. **Given** the user has previously started a capture (first-run flag set), **When** the idle hub appears on any later visit, **Then** neither the headline hint nor the ring caption is shown.
4. **Given** the first-launch hint is present, **When** rendered, **Then** the idle crescent remains purely ambient (no fill, no count, no recency, no "last seen") — the hint only adds the two ghost lines.

---

### Edge Cases

- **Double-start / re-entry**: What happens if "Speak check-in" is tapped twice quickly, or the auto-start path fires while a recording is already live? → `startRecording()` MUST guard against any non-resettable state and never zero a live timer or open a duplicate audio session (FR-016). This is the P1 logic bug in the critique ([§7](../../docs/ux-critique-checkin.md), [CheckInViewModel.swift#L46-85](../../app-four/ViewModels/CheckInViewModel.swift#L46)).
- **Reduce Motion**: The Settle morph MUST have an instant final-state equivalent (no animation) while still firing the single success haptic ([DESIGN.md#L82](../../DESIGN.md#L82)).
- **Save fails on the cap path**: A failure at the 8-minute auto-stop MUST route through the same retry buffer as a manual-stop failure, not discard (US4 AC4).
- **VoiceOver while actively speaking**: Prompt-advance announcements MUST be suppressed while the level meter indicates active voice, to avoid the app talking over the user mid-recording.
- **Retry after the app is backgrounded**: The retry buffer is in-memory for the session; if the app is torn down before a retry, the buffered (unsaved) audio may be lost — acceptable for this iteration (the failure surface still prevents a *silent* loss while the screen is alive). [NEEDS CLARIFICATION: should the retry buffer survive a cold relaunch, or is session-lifetime sufficient for v1?]
- **Interruption (phone call) during recording**: The `.paused` state currently renders identically to `.recording` with no affordance ([CheckInView.swift#L72](../../app-four/Views/CheckIn/CheckInView.swift#L72)). Full resume-the-same-recording is OUT OF SCOPE; a minimal honest visual "paused" state is the floor (FR-017).
- **Empty/very short recording at the cap or manual stop**: existing save behavior is unchanged; this feature does not add minimum-length gating.
- **Text composer save failure**: `saveTextCheckIn` currently returns `Void` with no error channel; a text-save failure SHOULD surface a comparable non-alarming failure rather than silently dropping (FR-009 applies to both voice and text save paths).

## Requirements *(mandatory)*

### Functional Requirements

**The Settle (US1)**

- **FR-001**: On a successful save, the recording crescent MUST visually morph in place into a checkmark (decelerate, contract, stroke redraws to a check) rather than cross-dissolving to a separate Saved view.
- **FR-002**: Exactly one success haptic MUST fire at the completion of the Settle (the frame the check resolves), for both the voice-save and the text-save paths, and MUST be idempotent (fires once per capture, never on entering recording or on the hub).
- **FR-003**: Under Reduce Motion, the checkmark MUST appear directly in its final state with no morph animation, while the single success haptic still fires once.
- **FR-004**: The Saved state MUST present a single primary action ("Done") that returns to the idle hub; the redundant "Check in again" button MUST be removed.

**Never lose a capture (US2)**

- **FR-005**: On a stop/save failure, the captured audio MUST be retained in a retry buffer; the system MUST NOT silently reset to the idle hub and MUST NOT discard the capture without the user's action.
- **FR-006**: A save failure MUST surface a calm, inline, non-alarming recovery affordance ("Couldn't save that one — tap to try again") accompanied by a single error haptic; copy MUST be recovery-framed, never blame-framed, with no red/alarm styling.
- **FR-007**: The recovery affordance MUST allow re-attempting the save from the buffered audio; a successful retry MUST proceed to the Saved state (Settle + success haptic).
- **FR-008**: The user MUST be able to explicitly discard a failed capture, which clears the buffer and returns to the idle hub.
- **FR-009**: The text-save path MUST also expose a non-alarming failure surface rather than silently dropping a draft.

**Heard (US3)**

- **FR-010**: When the visual prompt advances, the new prompt's question and hint MUST be announced to VoiceOver — suppressed while the audio level indicates the user is actively speaking, posted only on a pause/quiet.
- **FR-011**: The recording crescent and timer MUST be exposed to VoiceOver as a single grouped status element labeled "Recording, [elapsed] elapsed" that updates as a live region, throttled to avoid chatter.
- **FR-012**: State transitions to processing and done MUST be announced to VoiceOver as "Saving…" and "Captured." respectively.
- **FR-013**: The hand-rolled recording controls (Stop & save, Cancel) and the new retry affordance MUST each meet the 44pt minimum tap target ([Metrics.swift#L10](../../app-four/DesignSystem/Metrics.swift#L10)) and be VoiceOver-operable.

**Soft landing (US4)**

- **FR-014**: As the recording approaches the max-duration cap, a single soft approach cue MUST be shown once in the final stretch — not a ticking countdown, no red, no alarm — and MUST NOT repeat within the same recording.
- **FR-015**: At the cap, the auto-stop MUST save and land on the Saved state via the same Settle + success haptic path as a manual stop; a failure on this path MUST route through the same retry buffer (FR-005).

**Correctness & interruption floor**

- **FR-016**: `startRecording()` MUST guard against re-entry: it MUST start only from a resettable state, MUST NOT zero a live timer, and MUST NOT request a duplicate audio session; the auto-start entry point MUST early-return when a capture is already in progress.
- **FR-017**: The `.paused` state MUST be visually distinguishable from `.recording` (a minimal honest "paused" indication); audio-append / resume-the-same-recording is explicitly OUT OF SCOPE for this feature.

**First-launch hint (US5)**

- **FR-018**: On the first-ever use of the Check-in tab, a single low-contrast headline hint and a single faint idle-ring caption MUST be shown; both MUST dismiss on the first capture start and MUST NOT reappear thereafter (tracked by a first-run flag).
- **FR-019**: The idle crescent MUST remain purely ambient — it MUST NOT show a fill, a count, a streak, a recency, or a "last seen" — for this feature.

**Cross-cutting (privacy & determinism, per constitution)**

- **FR-020**: No new data leaves the device; any logging added for these flows MUST record counts/durations/state names only, never transcript text or medication content ([constitution Principle VI](../../.specify/memory/constitution.md)).
- **FR-021**: The background transcription/extraction architecture MUST be preserved unchanged — the Saved state MUST NOT show transcribing UI, a daily card, or an extracted-content echo ([DESIGN.md#L108](../../DESIGN.md#L108)); extraction stays silent and off-main.

### Key Entities *(include if feature involves data)*

- **Capture retry buffer**: A transient, session-lifetime hold of the just-recorded audio (its file URL + duration) kept when a save fails, so a retry can re-attempt the save without re-recording. Not persisted to the SwiftData store; cleared on successful save or explicit discard. (No schema change.)
- **First-run hint flag**: A single boolean recording whether the Check-in tab has ever had a capture started, controlling the one-time hint/caption. Stored in user defaults (consistent with the app's existing `@AppStorage`/`UserDefaults` flag pattern, e.g. [DayCardSettingsSection.swift#L7](../../app-four/Views/Settings/DayCardSettingsSection.swift#L7)); no schema change.
- **No new `@Model` types** are introduced; existing `Recording`, `CheckInDraft`, `RecordingState`, and `InterruptionType` ([AppEnums.swift](../../app-four/Models/AppEnums.swift)) are reused.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of successful saves (voice and text) fire exactly one success haptic at Settle completion — zero double-fires, zero missing-fires — verified across normal and Reduce-Motion runs.
- **SC-002**: 0% of stop/save failures result in a silent reset to the idle hub; 100% surface the inline retry affordance and retain the buffered audio (no capture is ever discarded without an explicit user action).
- **SC-003**: A VoiceOver user can complete a full voice check-in — start, hear prompt advances, hear elapsed time, hear "Captured." — using audio output alone, with zero reliance on visual-only cues.
- **SC-004**: At the 8-minute cap, 100% of auto-stops land on the Saved state via the Settle path (never a hard drop), and the approach cue is shown exactly once per recording.
- **SC-005**: Rapid double-taps of "Speak check-in" and concurrent auto-start never produce a duplicate audio session or a reset live timer (the P1 re-entry bug is eliminated, verified by a VM test).
- **SC-006**: All hand-rolled recording controls and the retry affordance measure ≥ 44×44pt.
- **SC-007**: The first-launch hint appears on exactly the first session and never on any subsequent session.
- **SC-008**: The full existing test suite stays green and the on-device extraction eval floors are not regressed ([constitution Principles II, VII, X](../../.specify/memory/constitution.md)).

## Assumptions

- The owner has approved the recommended thread of each brainstorm thread; ambiguity is resolved toward those recommendations.
- "The Echo" (post-save glimpse of what was heard), the "field remembers you" idle-ring continuity treatment, adaptive Speak/Type/Log-meds weighting, full resume-the-same-recording, and the heads-down / spoken-send-off wildcards are all **deferred** to separate future specs and are NOT built here.
- The retry buffer is session-lifetime and in-memory; surviving a cold relaunch is a possible future enhancement, not a v1 requirement (see open clarification).
- The `.paused` state gets a minimal honest visual treatment only; the full interruption/resume flow is a separate spec.
- `Haptics.success()` / `.error()` / `.selection()` already exist ([Haptics.swift](../../app-four/DesignSystem/Haptics.swift)) and are reused; no new haptic primitives are introduced.
- The existing background-transcription architecture, the silent-extraction posture, and the "no transcribing UI / no daily card on Saved" locked decision are preserved exactly.
- The `audioLevelStream` (normalized 0.0–1.0, [Protocols.swift#L49-50](../../app-four/Services/Protocols.swift#L49)) is the signal source for the "active voice" gate on announcements; this feature MAY consume it but MUST NOT change the protocol.
