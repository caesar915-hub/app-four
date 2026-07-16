<!-- Created: 2026-07-16 18:25 (WEST) · Updated: 2026-07-16 18:25 (WEST) -->
# Feature Specification: Live Activity Recording Controls for Check-In

**Feature Branch**: `feat/037-live-activity-controls`

**Created**: 2026-07-16

**Status**: Draft

**Input**: User description: "Live Activity recording controls for the voice check-in. Once a check-in recording is started in the foreground, present a Live Activity on the Lock Screen and in the Dynamic Island for the duration of the recording, showing live recording state and exposing pause/resume and stop-and-save controls backed by App Intents that run in the background without foregrounding or unlocking the app. Recording continues while the phone is locked via the already-declared audio background mode. Follow-on to spec 030 (App Intents Foundation). Out of scope: starting a recording from the background or a locked device, and any Apple Watch surface."

## Context

This feature builds directly on **spec 030 (App Intents Foundation)**. Spec 030 established that a check-in recording can only *start* while the app is foregrounded — iOS blocks activating a microphone session from a background/locked process (an OS-level privacy rule confirmed by Apple Developer Technical Support; the only exceptions are call-management frameworks). Decision D2 therefore made `StartCheckInIntent` a foreground intent: the phone must be unlocked to begin recording.

This feature addresses the *other* half of the recording lifecycle: **once a recording is already running**, the user should be able to lock the phone or switch apps and still see that it is recording and control it — pause, resume, and stop-and-save — from the Lock Screen and Dynamic Island, **without unlocking or reopening Squirl**. Modifying an already-active recording from the background is permitted by the platform (it is not *starting* one), which is what makes this feature possible where background *start* is not.

The audio-session capability this relies on (continue recording while backgrounded/locked) is already declared on the app; the recording pipeline already supports pause, resume, and stop. This feature is the user-facing control surface over capabilities that mostly already exist.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - End a check-in from the Lock Screen without unlocking (Priority: P1)

A user starts a voice check-in, then locks the phone or slips it into a pocket to keep talking (or to stop talking). When they are done, they end and save the check-in directly from the Lock Screen — one tap, no unlock, no reopening the app. The capture is saved and transcribed exactly as if they had tapped Stop inside the app.

**Why this priority**: This is the core pain the user hit — after starting a check-in, the only way to stop-and-save today is to unlock and return to the app. A stop control on the Lock Screen removes that friction entirely and is the minimum slice that delivers real value. It also stands alone: a live indicator with only a Stop button is already useful.

**Independent Test**: Start a check-in in the app, lock the phone, confirm a recording indicator appears on the Lock Screen, tap its Stop control, unlock, and verify a saved journal entry exists matching the recorded audio — identical to an in-app stop.

**Acceptance Scenarios**:

1. **Given** a check-in recording has started and the phone is locked, **When** the user taps the Stop-and-save control on the Lock Screen recording indicator, **Then** the recording ends, the capture is saved and enters the same transcription/extraction pipeline as an in-app stop, and the indicator is removed — all without the phone unlocking.
2. **Given** a check-in recording is running, **When** the phone locks, **Then** the recording continues capturing audio uninterrupted and the elapsed time keeps advancing on the Lock Screen indicator.
3. **Given** the transcription model is not yet downloaded, **When** the user stops the recording from the Lock Screen, **Then** the capture is queued as pending and transcribes automatically later — identical to stopping in-app.

---

### User Story 2 - Pause and resume an in-progress check-in from the Lock Screen (Priority: P2)

Mid check-in, the user is interrupted (someone speaks to them, they need a moment to think) and does not want that gap or the surrounding silence in the recording, but also does not want to end the check-in. They pause from the Lock Screen and resume when ready — the recording is one continuous capture, minus the paused gap.

**Why this priority**: Pause/resume is a meaningful quality-of-capture improvement but is secondary to simply being able to stop. A user gets value from P1 alone; pause/resume deepens it.

**Independent Test**: Start a recording, lock the phone, tap Pause on the Lock Screen indicator, confirm elapsed time halts and the indicator shows a paused state, tap Resume, confirm capture continues, then stop and verify the saved audio contains the pre- and post-pause speech with the paused interval excluded.

**Acceptance Scenarios**:

1. **Given** a recording is running and the phone is locked, **When** the user taps Pause on the Lock Screen indicator, **Then** capture suspends, the elapsed timer halts, and the indicator clearly shows a paused (not recording) state.
2. **Given** a recording is paused, **When** the user taps Resume, **Then** capture continues into the same recording and the elapsed timer advances again.
3. **Given** a recording is paused, **When** the user taps Stop-and-save, **Then** the check-in ends and saves with only the captured (non-paused) audio.

---

### User Story 3 - Control and monitor a check-in from another app via the Dynamic Island (Priority: P3)

While a check-in is recording, the user opens another app. The Dynamic Island keeps the recording visible (elapsed time, recording state) and, when expanded, offers the same pause/resume/stop controls — so the user can manage the check-in without leaving what they are doing or returning to Squirl.

**Why this priority**: Extends the same controls to the unlocked-but-multitasking case and to devices with a Dynamic Island. Valuable for reassurance and reach, but the locked-Lock-Screen case (P1/P2) is the primary problem; this is additive presentation.

**Independent Test**: Start a recording, switch to another app, confirm the Dynamic Island shows a live recording indicator with elapsed time; expand it and exercise pause/resume/stop, verifying each behaves as the Lock Screen controls do.

**Acceptance Scenarios**:

1. **Given** a recording is running and the user is in another app, **When** they glance at the Dynamic Island, **Then** it shows the recording is active with live elapsed time.
2. **Given** the recording is running, **When** the user expands the Dynamic Island, **Then** pause/resume and stop-and-save controls are available and behave identically to the Lock Screen controls.

---

### Edge Cases

- **Max-duration cap reached while locked/backgrounded**: The check-in reaches its recording length cap while the user is not in the app. The recording MUST stop-and-save automatically, and the indicator MUST reflect the ended/saved state before it is removed — the user is never left with a stale "recording" indicator for a capture that already ended.
- **Stopped from inside the app**: The user returns to Squirl and stops the recording in-app while the Lock Screen / Dynamic Island indicator is showing. The indicator MUST be removed promptly so it never contradicts the app.
- **Phone call or system interruption**: An incoming call or other audio interruption occurs during a controlled recording. The recording follows the app's existing interruption handling, and the indicator MUST reflect the resulting state (e.g. paused/interrupted) rather than falsely showing active capture.
- **Tapping the indicator body (not a control)**: Opens Squirl into the live check-in; if the phone is locked this prompts for unlock first — expected and consistent with spec 030's lock-behavior copy (anything that *opens* Squirl requires unlock).
- **Live Activities disabled by the user**: The user has turned off Live Activities for Squirl or system-wide. Check-in recording MUST still work fully in-app; the missing indicator MUST degrade silently with no error and no loss of function.
- **App terminated by the system while backgrounded**: If iOS reclaims the app mid-recording, the active audio session is what keeps the process alive; if the process is nonetheless killed, capture has already ended. The indicator MUST NOT continue to imply live recording, and any audio captured up to that point MUST be recoverable/saved rather than lost.
- **Re-entry / second start attempt**: With a recording already active and its indicator showing, a new check-in start request MUST NOT create a second concurrent recording (consistent with spec 030 FR-014); at most one recording indicator exists at a time.
- **Reduce Motion**: Any animated recording indicator MUST respect Reduce Motion and present a static equivalent.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When a voice check-in recording begins (necessarily in the foreground), the system MUST present a Lock Screen recording indicator for the lifetime of that recording.
- **FR-002**: The indicator MUST display live elapsed recording time and an unambiguous recording-in-progress state, updating as the recording continues.
- **FR-003**: The indicator MUST provide a Stop-and-save control that ends the recording and saves the capture through the exact same save/transcription/extraction path as stopping inside the app, producing an equivalent journal entry.
- **FR-004**: The indicator MUST provide Pause and Resume controls that suspend and continue the in-progress recording as one continuous capture, without ending it or discarding captured audio.
- **FR-005**: The Stop, Pause, and Resume controls MUST operate while the device is locked, without requiring the user to unlock, foreground, or reopen the app. (These modify an already-active recording — permitted by the platform, unlike *starting* a recording, which is not.)
- **FR-006**: The recording MUST continue capturing audio while the device is locked and while the app is backgrounded, for the full duration until stopped, paused, or the max-duration cap is reached.
- **FR-007**: When the recording ends by any path — user stop, max-duration cap, cancellation, or unrecoverable interruption — the recording indicator MUST be removed promptly and MUST NOT linger implying active capture.
- **FR-008**: The indicator MUST always reflect the true current recording state (recording vs. paused vs. ended); the displayed state MUST NOT contradict the actual capture state.
- **FR-009**: Tapping the indicator body (outside its controls) MUST open the app into the active check-in session; when the device is locked this MAY prompt for unlock first (expected, per spec 030 lock-behavior).
- **FR-010**: At most one recording indicator MUST exist at any time, consistent with the single-active-recording guarantee (spec 030 FR-014).
- **FR-011**: If the max-duration cap is reached while the recording is being managed only from the indicator (app backgrounded / device locked), the recording MUST stop-and-save automatically and the indicator MUST show the ended/saved state before removal.
- **FR-012**: A recording stopped from the indicator while the transcription model is unavailable MUST be queued as a pending capture and transcribed later — identical to the in-app pending path (spec 030 / US3).
- **FR-013**: On devices with a Dynamic Island, the indicator MUST also present in the Dynamic Island (compact and expanded), exposing the same recording status and, in the expanded presentation, the same controls.
- **FR-014**: If Live Activities are disabled for the app or the device, check-in recording MUST remain fully functional in-app; the absence of the indicator MUST NOT surface an error or reduce recording capability.
- **FR-015**: All indicator controls MUST have accessible labels, and any animated recording indication MUST honor Reduce Motion with a static equivalent.
- **FR-016**: The Lock Screen / Dynamic Island indicator MUST NOT display any transcript text, mood, or medication content — only recording status (elapsed time and state). (On-device privacy, Constitution VI: the Lock Screen is visible to anyone holding the phone.)

### Key Entities *(include if feature involves data)*

- **Recording status surface**: A transient, per-recording status representation shown on the Lock Screen and Dynamic Island. Attributes: recording state (recording / paused / ended), elapsed time, start time, and the max-duration cap. It exists only for the lifetime of one active check-in recording and persists nothing of its own.
- **Check-in recording (existing)**: The in-progress voice capture and its resulting saved journal entry. This feature adds a control/monitoring surface over the existing recording; it introduces no new persisted data model and reuses the existing capture, save, and transcription entities.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can end and save an in-progress check-in from the Lock Screen in a single tap, without unlocking the phone.
- **SC-002**: The recording indicator appears within 1 second of the recording starting.
- **SC-003**: 100% of check-ins stopped via the indicator produce a saved journal entry equivalent to an in-app stop, with no lost, empty, or truncated captures.
- **SC-004**: The elapsed time shown on the indicator stays within 1 second of the actual recording duration.
- **SC-005**: When a recording ends by any path, the indicator is removed within a few seconds — no stale "recording" indicator remains on the Lock Screen.
- **SC-006**: The Lock Screen / Dynamic Island surface never displays transcript, mood, or medication content in any state.
- **SC-007**: With Live Activities disabled, the check-in recording success rate is unchanged from today (graceful degradation, no regression).
- **SC-008**: A paused-then-resumed check-in saves as one continuous capture containing the pre- and post-pause speech, with the paused interval excluded.

## Assumptions

- **Scope is check-in recording only.** The medication-dose log is an instantaneous action with no duration, so a live recording surface does not apply to it. It is out of scope.
- **Stop from the indicator finalizes silently in the background** — it does not force the app to open (which would demand an unlock and defeat the purpose). The user reviews the saved check-in later, on their next open. This mirrors the "no app-opening" ethos of the dose-log flagship.
- **P1 ships Stop-and-save; pause/resume (P2) and Dynamic Island parity (P3) layer on top.** The user requested all three; this only partitions them by delivery priority, each independently testable. Stop alone is a viable MVP.
- **The existing max-duration cap governs auto-stop.** This feature reuses the check-in's current recording-length cap rather than introducing a new one.
- **The audio-continues-while-locked capability is already declared** on the app; this feature depends on it but does not add it. A device-QA pass confirms the session survives lock today.
- **The recording pipeline already exposes start / pause / resume / stop / cancel** at the service layer; this feature surfaces those existing operations to the Lock Screen and Dynamic Island rather than adding new recording mechanics.
- **This is a follow-on to spec 030 and reuses its router / intent foundation** for the background, no-unlock control actions. It does not modify how a check-in *starts* (that remains foreground-only per 030 D2).
- **Out of scope**: starting a recording from the background or a locked device (not possible for third-party apps on iOS — established by this session's research), and any Apple Watch recording surface (a separate platform and spec).
