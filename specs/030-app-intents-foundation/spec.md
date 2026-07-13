<!-- Created: 2026-07-03 17:14 (WEST) · Updated: 2026-07-13 17:29 (WEST) -->
# Feature Specification: App Intents Foundation + NFC Sticker Actions

**Feature Branch**: `030-app-intents-foundation`

**Created**: 2026-07-03

**Status**: Draft

**Input**: User description: "App Intents foundation + NFC sticker actions (post-v1.0). Two frictionless entry actions for every user, triggered by NFC stickers, Siri, Spotlight, or Shortcuts — decided 2026-07-03 over an App Clip. Scope: default medication setting · background dose-log action · user-configurable dose guard (off / total / 1–4h window) · hands-free check-in start · zero-setup system exposure (Siri/Spotlight/Shortcuts) · guided sticker setup screen · not-configured fallback. See Master PRD §22.1, BACKLOG 💡 row, DEVLOG 2026-07-03 17:14."

## Overview

Squirl's core promise is capture that costs less attention than the moment it happens in. Today both high-frequency actions — logging a stimulant dose and starting a voice check-in — require opening the app and navigating to the action. This feature exposes those two actions as system-level verbs that any trigger surface can fire: an NFC sticker on the pill bottle, a sticker on the mirror, a Siri phrase from across the room, a Spotlight search, or the Shortcuts app. The verbs work from the moment the app is installed with zero setup; NFC stickers add a one-time ~60-second guided setup per sticker. An App Clip was explicitly evaluated and rejected (clips only run when the app is *not* installed; the predefined dose lives in the user's settings, so the capability cannot exist outside the full app).

## Clarifications

### Session 2026-07-03

- Q: What does the check-in action do when onboarding is incomplete? → A: Strict gate — the app opens to onboarding, no recording starts; the action responds with a calm "finish setting up Squirl first" message (Option A).
- Q: Does the dose confirmation name the medication (spoken aloud / on the lock screen)? → A: User setting — "Name medication in confirmations" toggle; ON = "Elvanse 30 mg logged · 17:42" everywhere, OFF = discreet "Dose logged · 17:42" everywhere. **Default OFF (discreet)** — privacy-first default; med name only inside the app until the user opts in.
- Q: Which prior doses arm the guard — any dose event, or only expedited-logged ones? → A: Any dose event, regardless of how it was logged (in-app or expedited); the guard answers "did I already take it?", which doesn't depend on the logging surface (Option A).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Log my dose without opening the app (Priority: P1)

A medicated user configures their usual medication and dose once ("My medication": one pick from the existing catalog — Concerta / Ritalin / Elvanse — plus one of its dose options). From then on, triggering the "log my meds" action — by tapping an NFC sticker on the pill bottle, saying the Siri phrase, or running it from Spotlight/Shortcuts — records a dose of that medication at the current time, without the app visibly opening. The user gets an unmissable acknowledgment (system banner + haptic; spoken when triggered by voice). What it discloses is the user's choice: by default it is discreet — "Dose logged · 17:42" — and a Settings toggle ("Name medication in confirmations") opts into naming the medication and dose *(clarified 2026-07-03)*. Saying the phrase to a **locked** phone still works — the action is deliberately allowed without unlocking, because the accepted worst case is a stray journal entry, and nothing is ever read back out loud beyond the confirmation.

If no default medication is configured yet, the action never dead-ends: it responds with a calm prompt ("Set your medication first") that takes the user straight to the setting when tapped.

**Why this priority**: This is the flagship friction-killer — dose logging happens at the exact moment attention is scarcest (mid-morning routine, pill in hand). It also carries the two foundation pieces (the default-medication setting and the system-verb exposure) that every other story builds on. On its own it is a complete, shippable MVP.

**Independent Test**: Configure a default medication in Settings, invoke the action via Siri and via the Shortcuts app (no sticker needed), and verify a correctly-attributed dose event appears in the journal with the acknowledgment shown — app never foregrounded.

**Acceptance Scenarios**:

1. **Given** a default medication "Elvanse 30 mg" is configured, **When** the user triggers the log-dose action from the Shortcuts app, **Then** a dose event for Elvanse 30 mg timestamped "now" is recorded, the app does not visibly open, and a system banner confirms the log (no haptic — the log ran in the background; D9) — "Dose logged · HH:MM" by default, or "Elvanse 30 mg logged · HH:MM" when "Name medication in confirmations" is on.
2. **Given** a default medication is configured and the phone is **locked**, **When** the user says the Siri phrase, **Then** the dose is recorded and Siri speaks the confirmation — no unlock required.
3. **Given** no default medication is configured, **When** the user triggers the log-dose action, **Then** no dose event is created and the response calmly directs the user to the "My medication" setting, which opens on tap.
4. **Given** a dose was just logged via the action, **When** the user later opens the app, **Then** the medication bar and day timeline reflect that dose exactly as if it had been logged in-app.

---

### User Story 2 - Start a check-in hands-free (Priority: P2)

A user passes their check-in sticker (on the mirror, the desk) — or says "check in" to Siri — and Squirl opens straight into the Listening state, **already recording**. No navigation, no taps inside the app: they just start talking. Stopping and saving behaves exactly like a normal check-in. Transcription and signal extraction are deliberately deferred to the app's normal pipeline; the sticker's job is only to capture voice with zero friction. If the transcription model isn't downloaded yet, the recording still happens and queues — a capture is never lost.

**Why this priority**: The check-in is the app's core loop, but this story depends on nothing from Story 1 and delivers independently. It is P2 only because dose logging (P1) additionally carries the shared foundation and the pill-bottle moment is the more attention-starved one.

**Independent Test**: Trigger the check-in action from Spotlight or Siri on a phone where the app is closed; verify the app opens directly into an active recording, that stop-and-save produces a normal recording, and that it transcribes later through the standard pipeline.

**Acceptance Scenarios**:

1. **Given** the app is not running, **When** the user triggers the check-in action, **Then** the app opens directly into the Listening state with recording already active (visible timer/crescent), with no intermediate taps required.
2. **Given** a check-in recording is already in progress, **When** the check-in action is triggered again, **Then** no second recording starts and the in-progress session is unaffected (existing re-entry protection).
3. **Given** the transcription model is not yet downloaded, **When** the user records via the action and saves, **Then** the audio is preserved and queued, and transcribes automatically once the model is available.
4. **Given** microphone permission was revoked in iOS Settings, **When** the action is triggered, **Then** the app opens and shows its existing calm mic-permission guidance — the trigger never fails silently.

---

### User Story 3 - Dose guard: protect me from double-logging (Priority: P3)

A user who can't always remember whether they already tapped enables the **Dose guard** in Settings. The guard is a user choice with three states: **off** (every trigger logs — the default), **total guard** (a second log is blocked while the previous dose is still active, i.e. inside its effect-duration window), or **time-window guard** (a second log is blocked for X hours after the previous dose, X selectable from 1/2/3/4). A guarded trigger changes nothing in the journal and answers calmly — "Your 14:00 dose is still active." — no shame, no double entry. The guard applies to **expedited logging only** (sticker/voice/Shortcuts); the in-app Log Dose sheet is always allowed — deliberately opening it is treated as intentional *(owner decision, 2026-07-03: Option A)*.

**Why this priority**: Valuable safety net for exactly this audience, but meaningful only once Story 1 exists; ships independently on top of it.

**Independent Test**: Enable each guard mode in Settings, log a dose, immediately trigger the action again, and verify: blocked with calm feedback under total/time-window modes (and unblocked after the window passes), logged normally with the guard off.

**Acceptance Scenarios**:

1. **Given** the guard is **off**, **When** the log-dose action fires twice in five minutes, **Then** two dose events exist (the user's explicit choice).
2. **Given** **total guard** is on and a dose logged 2 hours ago has an 8-hour effect duration, **When** the action fires, **Then** no event is created and the response says the earlier dose is still active, naming its time.
3. **Given** **time-window guard (2 h)** is on and a dose was logged 3 hours ago, **When** the action fires, **Then** a new dose event is created normally.
4. **Given** **time-window guard (4 h)** is on and a dose was logged 1 hour ago, **When** the action fires, **Then** no event is created and the calm "already active" response is shown.

---

### User Story 4 - Set up my sticker in a minute (Priority: P4)

A non-technical user opens a guided "Set up your sticker" screen in Settings and follows an illustrated step-by-step walkthrough (one path per sticker: dose / check-in) that hands off into the Shortcuts app at the right step. The guide recommends the zero-tap option ("Run Immediately"), and sets expectations honestly: the sticker fires instantly on an unlocked phone; on a locked phone iOS shows a notification instead and the action runs after unlocking — the tap is never lost, and that's normal behavior, not the user's failure. Works with any blank NFC sticker.

**Why this priority**: The stickers already *work* for a user who knows Shortcuts (Stories 1–2 expose the verbs there); this story makes them reachable for everyone else. Pure guidance — no journal behavior changes.

**Independent Test**: A user who has never used the Shortcuts app follows the guide with a blank NFC tag and ends with a working zero-tap sticker in about a minute; the lock-behavior copy matches observed behavior.

**Acceptance Scenarios**:

1. **Given** a user on the guide's dose-sticker path, **When** they follow every step with a blank NFC tag, **Then** tapping the sticker on an unlocked phone logs their default dose with no confirmation prompt.
2. **Given** the guide is open, **When** the user reaches the hand-off step, **Then** a single tap takes them into the Shortcuts app at the point where the automation is created.
3. **Given** the finished sticker and a **locked** phone, **When** the user taps it, **Then** the behavior matches what the guide told them to expect (notification now, action after unlock — nothing lost).

---

### Edge Cases

- **Not configured + voice on locked phone**: not-configured response must also work spoken (locked Siri trigger with no default set → spoken "set your medication first"; deep link works after unlock).
- **Guard boundary**: trigger at exactly X hours after the previous dose (time-window mode) or exactly at effect-duration end (total mode) → treat the window as closed (log succeeds). Boundary must be deterministic and tested.
- **Previous dose with edited duration**: total guard must respect the event's actual effect duration (users can edit it), not the catalog default.
- **Rapid double-fire**: two triggers arriving within seconds (automation + impatient re-tap) must never create two events when any guard is on, and must not crash when the guard is off (two events are then legitimate).
- **Default medication removed/changed**: changing the default only affects future logs; past events keep their recorded medication.
- **Check-in trigger while app shows a different screen** (Settings, Edit sheet): the app must land in a coherent Listening state — never a half-presented stack.
- **Check-in trigger before onboarding is complete**: strict gate (clarified 2026-07-03) — the app opens to onboarding, no recording starts, and the action responds calmly ("finish setting up Squirl first"). The dose action is inherently gated the same way in practice: no default medication can exist before Settings is reachable, so it takes the not-configured path (FR-007).
- **Storage full / recording cannot start**: the check-in action surfaces the app's existing storage guidance rather than silently doing nothing.
- **Clock changes / time zones**: dose timestamps are always device-now at trigger time; guard comparisons use absolute elapsed time, immune to zone display changes.
- **Stale sticker** (user deleted the automation or the app): out of scope — iOS owns that failure surface; the guide's troubleshooting note covers re-creation.
- **Free tier**: interaction with any future check-in limits is deliberately undecided and out of scope.

## Requirements *(mandatory)*

### Functional Requirements

**Default medication ("My medication")**

- **FR-001**: Settings MUST offer a "My medication" control where the user picks exactly one medication from the existing catalog and one of its dose options; the choice persists across launches.
- **FR-002**: The user MUST be able to change or clear the default at any time; changes affect only future expedited logs.

**Expedited dose logging**

- **FR-003**: The system MUST expose a "log my meds" action that records a dose event of the default medication + dose, timestamped at trigger time, without requiring the app to visibly open.
- **FR-004**: The action MUST work when triggered by voice on a locked device (deliberate decision; accepted risk is a stray journal entry — the action never reads journal content back).
- **FR-005**: Every successful expedited log MUST produce an acknowledgment — visible as a banner, spoken when the trigger was voice, and accompanied by a haptic **where the platform allows it (the app is in the foreground)** — always including the time. A background log (the common sticker/Shortcuts case) cannot play a haptic — an Apple platform limit (D9): a background App Intent's engine is suspended, so its acknowledgment is the system banner plus, for a voice trigger, the spoken dialog. System-standard presentation is sufficient (no custom sound in v1). *(Haptic clause amended 2026-07-13 per D9 — owner sign-off; SC-001's 3 s banner is unaffected.)*
- **FR-023**: Settings MUST offer a "Name medication in confirmations" toggle, **default OFF**: OFF = confirmations say "Dose logged · HH:MM" on every surface (medication name visible only inside the app); ON = confirmations name medication and dose (e.g. "Elvanse 30 mg logged · HH:MM"). The toggle governs all confirmation surfaces uniformly (banner, spoken, locked).
- **FR-006**: A dose event created by the action MUST be indistinguishable in downstream behavior (medication bar, day timeline, insights) from one logged in-app.
- **FR-007**: With no default configured, the action MUST create nothing and respond with calm guidance that deep-links to the "My medication" setting; the not-configured path MUST also work for locked/voice triggers.

**Dose guard**

- **FR-008**: Settings MUST offer a "Dose guard" control with three user-selectable states: off (default), total guard, and time-window guard with a selectable window of 1, 2, 3, or 4 hours. The guard governs **expedited logs only**; logging through the in-app Log Dose sheet is never blocked (deliberate action, owner decision 2026-07-03).
- **FR-009**: With total guard on, an expedited log MUST be blocked while the most recent dose event's effect duration (as recorded on that event, including user edits) has not yet elapsed. The most recent dose event counts **regardless of how it was logged** — in-app or expedited (clarified 2026-07-03).
- **FR-010**: With time-window guard on, an expedited log MUST be blocked while less than the selected window has elapsed since the most recent dose event — again regardless of that event's logging surface.
- **FR-011**: A blocked trigger MUST change nothing in the journal and MUST respond with a calm, non-judgmental message naming the earlier dose's time (e.g. "Your 14:00 dose is still active."). Never alarming language, never red.
- **FR-012**: At an exact window boundary the guard MUST treat the window as closed (the log succeeds), deterministically.

**Hands-free check-in**

- **FR-013**: The system MUST expose a "check in" action that opens the app directly into the Listening state with recording already active — zero user taps between trigger and active capture.
- **FR-014**: The action MUST respect the existing re-entry protection: if a recording is already in progress, no second recording starts and the session is unaffected.
- **FR-015**: Recordings started by the action MUST flow through the existing capture pipeline unchanged — including the record-before-model-ready queue (audio preserved and transcribed later if the model is absent) and deferred transcription/extraction. The action itself performs no transcription.
- **FR-016**: If recording cannot start (mic permission revoked, storage full), the app MUST surface its existing guidance for that condition; the trigger must never fail silently.
- **FR-022**: While onboarding is incomplete, the check-in action MUST NOT start a recording: the app opens to onboarding and the action responds with calm "finish setting up first" guidance (strict gate — clarified 2026-07-03).

**System exposure (zero setup)**

- **FR-017**: Both actions MUST be available system-wide from first install with zero user setup: runnable from the system voice assistant via natural phrases, from system search, and listed in the Shortcuts app.
- **FR-018**: Both actions MUST be usable as building blocks in user-created Shortcuts automations (which is how NFC stickers trigger them); the feature itself ships no NFC-reading capability and requires no web infrastructure.

**Guided sticker setup**

- **FR-019**: Settings MUST include a guided "Set up your sticker" walkthrough with one path per sticker type (dose / check-in), including a hand-off step that opens the Shortcuts app.
- **FR-020**: The guide MUST recommend the zero-tap configuration, and MUST honestly describe lock-screen behavior (unlocked = instant; locked = notification, runs after unlock, never lost) in no-shame framing.

**Privacy**

- **FR-021**: The actions MUST NOT expose journal content to any trigger surface: responses contain only the just-logged medication/dose/time or neutral status phrases — never transcripts, notes, or historical data. All processing remains on-device (Constitution VI).

### Key Entities

- **Default Medication Setting**: the user's single chosen medication + dose from the existing catalog; persisted app setting; absence is a first-class state (drives the not-configured path).
- **Dose Guard Setting**: user preference — off / total / time-window(1–4 h); persisted app setting; consulted only at expedited-log time.
- **Confirmation Style Setting**: user preference — name medication in confirmations on/off (default off = discreet); persisted app setting; governs every confirmation surface uniformly.
- **Dose Event**: the existing medication event record; expedited logs create ordinary instances (medication, dose, timestamp = trigger time, effect duration from catalog defaults, user-editable afterward as today).
- **Check-in Recording**: the existing recording aggregate; action-started recordings are ordinary instances entering the standard lifecycle (pending transcription → transcribed → extracted).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: From an unlocked phone with a configured default, a dose is logged and acknowledged within 3 seconds of the trigger, with zero taps inside the app (app never visibly opens).
- **SC-002**: From trigger to actively-recording Listening state, the check-in action requires zero in-app taps and completes within 3 seconds on the baseline device (iPhone 12).
- **SC-003**: On a fresh install with zero configuration, both actions are discoverable and runnable via the system voice assistant, system search, and the Shortcuts app.
- **SC-004**: A first-time user following the guide turns a blank NFC sticker into a working zero-tap trigger in under 2 minutes, without external help.
- **SC-005**: With any guard mode active, duplicate triggers inside the guard window produce zero duplicate journal entries across all trigger surfaces, and 100% of blocked attempts receive the calm feedback message.
- **SC-006**: 100% of action-started check-ins are eventually transcribed via the normal pipeline — including those recorded before the transcription model was downloaded (zero lost captures).
- **SC-007**: No trigger path can dead-end: every failure state (not configured, guarded, mic revoked, storage full) produces visible, actionable, calm feedback.

## Assumptions

- **Guard default state**: Dose guard ships **off** — logging every trigger is the least surprising default; the guard is an opt-in safety net. Default window when time-window mode is first selected: 2 hours.
- **Guard reference event**: the guard evaluates elapsed time against the **most recent dose event regardless of medication and regardless of logging surface** (in-app or expedited — clarified 2026-07-03) — the risk being mitigated is "did I already take it just now", not per-medication bookkeeping.
- **Voice phrases**: final Siri phrase wording ("log my meds in Squirl", "check in on Squirl") is copy-level detail settled at implementation; phrases must contain the app name (platform requirement).
- **Locked-voice logging** (`FR-004`) is an explicitly accepted owner decision (2026-07-03): worst case is journal pollution; nothing is read back.
- **Acknowledgment**: system-standard banner/spoken dialog + haptic suffices for v1; a custom confirmation sound was considered and deliberately deferred. Confirmation wording is governed by the "Name medication in confirmations" toggle (default discreet — clarified 2026-07-03).
- **NFC mechanics**: stickers are blank NDEF tags used by tag-ID through user-created Shortcuts automations. No system API allows the app to create those automations — the one-time ~60 s guided setup per sticker is the accepted floor. Zero-tap requires an unlocked, screen-on phone; a locked tap degrades to a notification (community-verified behavior — confirm during device QA and keep guide copy truthful).
- **Existing plumbing reused**: the check-in action reuses the spec-016 re-entry guard and the spec-015 record-before-model-ready queue; the dose path reuses the existing catalog and dose-event model. No new capture or persistence machinery.
- **Sequencing**: post-v1.0 feature; free-tier interaction deliberately undecided.
- **Platform floor**: owner decision 2026-07-03 — the app's deployment target is raised to **iOS 26.0** for this feature onward (reverses the 2026-06-28 lowering to 17.0; consequence: device floor becomes iPhone 11/A13+, dropping iPhone XS/XR). All required system capabilities exist from iOS 16 and the modern iOS 26 App Intents execution-mode API is used; the baseline device (iPhone 12) runs iOS 26 and supports background NFC reading.
