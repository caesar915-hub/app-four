# Feature Specification: Onboarding & First-Run

**Feature Branch**: `015-onboarding-first-run`

**Created**: 2026-06-23

**Status**: Draft

**Input**: Full redesign of first-run. Collapse the three-step setup gate (welcome → mic permission → model download) into a single warm Paper & Pollen welcome that lands on the Check-in hub. Move microphone permission and the transcription-model download out of the gate: permission is requested just-in-time at first record; the model downloads in the background with no exit gate. A recording made before the model is ready is saved and transcribed automatically once the model lands. Source brainstorm: [docs/brainstorm-onboarding.md](../../docs/brainstorm-onboarding.md); critique: [docs/ux-critique-onboarding.md](../../docs/ux-critique-onboarding.md).

## User Scenarios & Testing *(mandatory)*

The north star: first-run's one job is to deliver "relief, then permission" and get an ADHD user to their first captured thought in under a minute — not to run a setup ceremony of grant + download before the app does anything. Today the flow renders in iOS-default system fonts and blue tint (a P0 brand regression), hard-gates exit on the model download (a connectivity dead-end), advances on mic denial with no recovery, and leaks the internal name "Whisper" and "~150 MB" to a non-technical audience. This feature replaces that with one calm welcome, just-in-time permission, a non-blocking background download, and a queue so a recording made before the model is ready still transcribes.

### User Story 1 - One warm welcome that lands on capture (Priority: P1)

A first-time user opens Squirl. They see a single, unmistakably-Squirl welcome on warm paper: a breathing crescent, a Fraunces headline, one calm sentence of privacy framing, and one primary "Start" action. Tapping it (or completing first launch) drops them directly on the Check-in hub, ready to record. There is no permission screen and no download screen to clear first.

**Why this priority**: This is the most identity-defining screen in the app and the entire premise of the redesign. Delivered alone it removes the connectivity dead-end (no download gate), kills the brand regression (Paper & Pollen instead of system defaults), and honors the under-a-minute north star. It is the MVP: a calm welcome that reliably reaches a usable hub is shippable on its own, with permission and the model handled by the existing point-of-use paths.

**Independent Test**: Launch with `hasCompletedOnboarding == false`; confirm one welcome screen renders in Paper & Pollen tokens with a breathing crescent and a single primary action; tap it; confirm the welcome dismisses and the Check-in hub is shown; relaunch and confirm the welcome does not reappear.

**Acceptance Scenarios**:

1. **Given** a fresh install (no `AppSettings` row, or `hasCompletedOnboarding == false`), **When** the app launches, **Then** a single welcome screen is presented over warm paper (`Theme.background`) with a Fraunces headline, one privacy sentence, a breathing `CrescentRing`, and exactly one primary action — and no microphone or model-download step appears.
2. **Given** the welcome screen, **When** the user taps the primary action, **Then** `hasCompletedOnboarding` is persisted as `true`, the welcome dismisses, and the Check-in hub is shown.
3. **Given** the persisted-settings write fails, **When** the user taps the primary action, **Then** the user is never stranded on a dead button: the app proceeds to the hub and the welcome does not block (failure is recoverable, never a self-blame dead end).
4. **Given** onboarding has been completed once, **When** the app is relaunched, **Then** the welcome is not shown again and the app opens directly to its normal tabs.
5. **Given** Reduce Motion is enabled, **When** the welcome is shown, **Then** the crescent does not animate (collapses to a static glow) and no other motion plays.

---

### User Story 2 - Transcription model downloads in the background (Priority: P1)

After the welcome, the transcription model downloads quietly in the background. The user is never blocked waiting for it. Whether the model is downloading, ready, or yet to start is never a wall on the path to capture. The download respects the user's "Download over Cellular" preference: on cellular with that preference off, the download waits for Wi-Fi rather than silently spending the user's data.

**Why this priority**: Removing the exit gate is the core safety property — a user on cellular or weak Wi-Fi must still reach a working app. Background download is the enabling half of "land on capture": it lets the welcome dismiss immediately while the model arrives on its own schedule. Respecting `downloadOverCellular` prevents a surprise data charge, which for this audience is a trust-breaking event.

**Independent Test**: Launch fresh with no model on disk; confirm the welcome dismisses to the hub without any download progress blocking it; confirm a background download begins; with "Download over Cellular" off and the device on cellular, confirm the download does not start until Wi-Fi is available; with the model already on disk, confirm no re-download occurs.

**Acceptance Scenarios**:

1. **Given** a fresh first run with the transcription model not on disk, **When** the welcome is dismissed, **Then** a background download of the model begins without any blocking progress UI in the first-run path.
2. **Given** the model is already present on disk (e.g. reinstall with retained files), **When** first run completes, **Then** no download is started and the model is treated as ready.
3. **Given** the device is on a cellular connection and "Download over Cellular" is OFF (the default, [AppSettings.swift#L19](../../app-four/Models/AppSettings.swift#L19)), **When** a background download would start, **Then** it is deferred until a Wi-Fi connection is available, and it begins automatically once Wi-Fi is reachable.
4. **Given** the device is on cellular and "Download over Cellular" is ON, **When** a background download would start, **Then** it proceeds over cellular.
5. **Given** a background download fails (network drops), **When** the failure occurs, **Then** the app remains fully usable, the failure is not surfaced as an alarming first-run error, and the model can be retried later from its Settings home (no first-run dead end).

---

### User Story 3 - Record before the model is ready; transcribe automatically when it lands (Priority: P1)

A user captures a thought immediately on first run, before the background model download has finished. Their audio is saved and is not lost. The check-in flow still confirms "Captured." as it always does. Once the model finishes downloading, the queued recording is transcribed automatically with no further action from the user, and a gentle, non-alarming affordance tells them transcription will be ready shortly rather than implying something is broken.

**Why this priority**: This is the real engineering of the feature and the reason the welcome can safely drop the download gate. Without it, a recording made on first run before the model lands would either block the user or silently fail to transcribe — exactly the dead end the redesign exists to remove. It must be P1 because US1 + US2 are unsafe to ship without it: the moment you let users record before the model is ready, you owe them a queue.

**Independent Test**: With no model on disk, record a check-in; confirm the recording is saved and the "Captured." confirmation appears; confirm the recording is marked as awaiting transcription with a calm affordance (not a failure); then make the model become ready; confirm the queued recording transcribes automatically and its status, title, and extracted signals populate without any user action.

**Acceptance Scenarios**:

1. **Given** the transcription model is not yet ready, **When** the user finishes a voice check-in, **Then** the audio is persisted, the check-in confirms "Captured." normally, and the recording enters a pending-transcription state (it is not transcribed yet and is not marked failed).
2. **Given** one or more recordings are pending transcription, **When** the model becomes ready, **Then** each pending recording is transcribed automatically, in capture order, with no user action, and on success its transcript, generated title, and extracted signals are written exactly as a normal post-recording transcription would write them.
3. **Given** a recording is pending transcription, **When** the user views it before the model is ready, **Then** it shows a gentle, non-alarming affordance conveying that transcription will be ready shortly — never raw-red error language and never implying the user broke something.
4. **Given** a recording is pending transcription, **When** the app is killed and relaunched while the model is still not ready, **Then** the recording remains pending (not stuck "Transcribing…", not silently failed) and is still transcribed automatically once the model lands.
5. **Given** a typed (text) check-in is made before the model is ready, **When** it is saved, **Then** it is unaffected by the queue (text check-ins do not require transcription) and behaves exactly as today.
6. **Given** the model becomes ready while a queued recording is draining, **When** a new live recording is also finished, **Then** transcriptions are serialized on the single transcription engine so no two inferences run at once and no recording's work is discarded.

---

### User Story 4 - Microphone permission requested just-in-time, with an escape (Priority: P2)

The app never asks for the microphone during first-run. The OS permission prompt appears the first time the user taps record. If the user denies (or has denied before), the app does not nag and does not break: typed check-ins still work, and at the point of the next record attempt the app offers a calm path to enable the mic in Settings. If the user already granted the mic (e.g. a reinstall with a retained grant), they are never re-prompted.

**Why this priority**: Permission-at-point-of-use is already implemented and shipping in the Check-in flow ([CheckInView.swift#L39-L46](../../app-four/Views/CheckIn/CheckInView.swift#L39), [CheckInViewModel.swift#L55-L60](../../app-four/ViewModels/CheckInViewModel.swift#L55)). This story is mostly about *deleting* the redundant onboarding permission gate and trusting the existing recovery, so it ranks below the structural work in US1–US3. It is still its own slice because the deletion must be deliberate and the denial path must be verified end-to-end.

**Independent Test**: Complete onboarding without ever seeing a permission screen; tap record for the first time; confirm the OS mic prompt appears; deny it and confirm the app surfaces the existing "Open Settings" recovery rather than a dead end; separately, with the mic already authorized, tap record and confirm no redundant prompt and recording starts.

**Acceptance Scenarios**:

1. **Given** first run, **When** the user proceeds through the welcome, **Then** no microphone permission is requested during first-run (no permission screen exists).
2. **Given** the mic has never been granted, **When** the user taps record for the first time, **Then** the OS microphone prompt is presented at that moment.
3. **Given** the user denies the microphone, **When** they next attempt to record, **Then** the app presents the existing in-context recovery offering "Open Settings" (deep-link) and a cancel, and does not repeatedly nag.
4. **Given** the microphone is already authorized, **When** the user taps record, **Then** no permission prompt is shown and recording begins.
5. **Given** the microphone is denied, **When** the user uses a typed check-in instead, **Then** the typed path works fully and produces a saved check-in.

---

### User Story 5 - Plain-language model wording, with model management in Settings (Priority: P2)

Wherever the transcription model is described to the user, it uses plain language — never the internal name "Whisper", never a raw "~150 MB" wall. The permanent home for model state and management (downloaded / downloading / not set up, and the actions to download, retry, or delete to reclaim space) is a row in Settings. If the model is not set up or failed, the Check-in hub may surface one gentle, non-naggy hint linking to that Settings row. First-run is not replayable.

**Why this priority**: This is the trust-and-polish layer. The Settings model-management surface already substantially exists ([SettingsView.swift#L58-L70](../../app-four/Views/SettingsView.swift#L58), [SettingsViewModel.swift#L82-L121](../../app-four/ViewModels/SettingsViewModel.swift#L82)); this story coordinates with the Settings redesign (Feature 017) to own the de-jargon wording and the state/affordances, and ensures first-run doesn't duplicate it. It ranks P2 because the app is correct and usable without it, but the jargon leak and the "where did my model go" gap are real first-impression costs.

**Independent Test**: Audit every user-facing string introduced or touched by this feature and confirm none contains "Whisper" or a bare "150 MB"; open Settings and confirm a single transcription row reflects model state and offers download/retry/delete; confirm there is no "replay onboarding" entry.

**Acceptance Scenarios**:

1. **Given** any first-run or queue affordance shown to the user, **When** it references the transcription capability, **Then** it uses plain language (e.g. "on-device transcription", "voice transcription") and never the token "Whisper" or a bare "~150 MB".
2. **Given** the user opens Settings, **When** they view the transcription row, **Then** it shows the current model state and offers download / retry / delete-to-reclaim-space as appropriate.
3. **Given** the transcription model is not set up or has failed, **When** the user is on the Check-in hub, **Then** at most one gentle, non-naggy hint may be shown that links to the Settings transcription row (it must read as an offer, not a chore or an alarm).
4. **Given** onboarding has completed, **When** the user looks for a way to replay the welcome, **Then** none exists (first-run is single-shot) and model management is reached via the Settings row instead.

---

### Edge Cases

- **Offline at first run**: the welcome still dismisses to a usable hub; the background download simply waits for connectivity and begins when the network returns. The user can record immediately; the recording queues (US3).
- **Cellular + "Download over Cellular" off**: download is deferred to Wi-Fi (FR-009); a recording made meanwhile queues and transcribes when Wi-Fi arrives and the model lands.
- **App killed mid-download**: on next launch the download resumes/restarts as needed (the model service short-circuits if files are already present) and any pending recording is still drained once the model is ready (FR-016).
- **App killed while a recording is pending transcription**: the recording must not be left stuck "Transcribing…" or silently failed; it stays pending and drains later (FR-016). This complements the existing orphaned-`.transcribing` → `.failed` recovery ([RecordingStore.swift#L21-L32](../../app-four/Store/RecordingStore.swift#L21)), which must not mistakenly sweep a still-legitimately-pending recording.
- **Persisted-settings write fails on completion**: the user proceeds to the hub anyway; the app is not bricked behind an undismissable cover (FR-005).
- **Mic denied, then later enabled in Settings**: the next record attempt succeeds without any first-run replay.
- **Model becomes ready while the app is backgrounded**: queued recordings drain when the app is next foregrounded (or while still alive if the system permits); on relaunch the queue is re-driven.
- **Two recordings finished back-to-back while the model is becoming ready**: transcriptions serialize on the single engine so neither is dropped (FR-015), preserving the existing back-to-back guarantee ([CheckInViewModel.swift#L96-L114](../../app-four/ViewModels/CheckInViewModel.swift#L96)).
- **Download repeatedly fails**: the model stays "not set up / failed" in Settings with retry; recordings stay pending and drain whenever the model finally lands — they are never auto-marked failed just because the model is late.

## Requirements *(mandatory)*

### Functional Requirements

**First-run shape (US1)**

- **FR-001**: First-run MUST be a single welcome screen — no microphone step and no model-download step in the first-run path.
- **FR-002**: The welcome MUST render in the Paper & Pollen design system (warm-paper background, Fraunces headline, DM Sans body, Meadow-gradient primary action) and MUST NOT use iOS-default system fonts or `accentColor`/system-tint, system `.green`/`.red`, on the first-run path.
- **FR-003**: The welcome MUST present the breathing `CrescentRing` as its signature visual, honoring Reduce Motion (no animation when enabled).
- **FR-004**: The welcome MUST include exactly one primary action that, when invoked, lands the user on the Check-in hub; it MUST include at most one calm sentence framing on-device privacy.
- **FR-005**: Completing the welcome MUST persist `hasCompletedOnboarding = true`; if that write fails, the user MUST still reach the hub (never stranded on an undismissable cover).
- **FR-006**: Once `hasCompletedOnboarding` is true, the welcome MUST NOT be shown on subsequent launches.

**Background model download (US2)**

- **FR-007**: The transcription model MUST download in the background after first run, with no blocking progress UI gating the first-run path.
- **FR-008**: If the model is already present on disk, the system MUST NOT start a redundant download and MUST treat it as ready.
- **FR-009**: The background download MUST respect the `downloadOverCellular` preference: when it is OFF and the active connection is cellular, the download MUST be deferred until a Wi-Fi connection is available, then begin automatically; when ON, it MAY proceed over cellular.
- **FR-010**: A background download failure MUST NOT make the app unusable and MUST NOT be surfaced as an alarming first-run error; the model MUST remain retryable from its Settings home.

**Record-before-model-ready queue (US3)**

- **FR-011**: A voice recording finished while the transcription model is not ready MUST be persisted and MUST enter a distinct pending-transcription state (not transcribed, not failed).
- **FR-012**: The check-in confirmation experience for such a recording MUST be unchanged ("Captured."); the pending state MUST NOT block or alter the capture flow.
- **FR-013**: When the model becomes ready, every pending recording MUST be transcribed automatically, with no user action, in capture order.
- **FR-014**: On successful automatic transcription of a pending recording, the system MUST write its transcript, generated title, and extracted signals identically to the normal post-recording path (same `applySummary`/extraction behavior).
- **FR-015**: Automatic draining MUST serialize on the single transcription engine so no two inferences run concurrently and no recording's transcription work is discarded, preserving the existing back-to-back guarantee.
- **FR-016**: Pending recordings MUST survive app relaunch: a recording left pending when the app is killed MUST remain pending (not stuck "Transcribing…", not silently failed) and MUST still be drained once the model is ready. Launch-time orphan recovery MUST NOT mark a legitimately-pending recording as failed.
- **FR-017**: While a recording is pending transcription, any UI that surfaces it MUST use a gentle, non-alarming affordance (e.g. "transcription will be ready shortly") using warm clay never raw red, and MUST NOT imply user error.
- **FR-018**: Text (typed) check-ins MUST be unaffected by the queue.

**Permission (US4)**

- **FR-019**: First-run MUST NOT request microphone permission; the request MUST occur just-in-time at the first record attempt (reusing the existing Check-in request path).
- **FR-020**: On microphone denial, the app MUST offer the existing in-context recovery (an "Open Settings" deep-link with a cancel) at the next record attempt and MUST NOT nag.
- **FR-021**: If the microphone is already authorized, the system MUST NOT present a redundant permission prompt.

**Wording & model home (US5)**

- **FR-022**: No user-facing string introduced or modified by this feature may contain the internal model name "Whisper" or a bare "~150 MB"; all model wording MUST be plain language.
- **FR-023**: Model state and management (download / retry / delete-to-reclaim) MUST live as a single Settings row (coordinated with Feature 017, not duplicated by first-run).
- **FR-024**: When the model is not set up or has failed, the Check-in hub MAY surface at most one gentle, non-naggy hint linking to the Settings transcription row.
- **FR-025**: First-run MUST NOT be replayable; there MUST be no "replay onboarding" entry.

### Key Entities *(include if feature involves data)*

- **AppSettings**: existing singleton ([AppSettings.swift](../../app-four/Models/AppSettings.swift)). Reused for `hasCompletedOnboarding` (first-run gate) and `downloadOverCellular` (cellular policy). No new fields required by this feature beyond what exists.
- **Recording**: existing `@Model` ([Recording.swift](../../app-four/Models/Recording.swift)). Gains a pending-transcription status value so a recording captured before the model is ready can be persisted, surfaced calmly, and drained later. (The concrete status representation is a plan-level decision.)
- **Pending-transcription queue**: a conceptual ordered set of recordings awaiting the model. Its job: hold captured-but-not-yet-transcribed recordings, observe model-readiness, and drain them in capture order through the existing transcription path. (Whether this is a new service or an extension of existing recording flow is a plan-level decision.)
- **Connectivity policy**: a conceptual check of "cellular vs Wi-Fi vs offline" used only to honor `downloadOverCellular` and to defer a background download to Wi-Fi. (No new persisted entity.)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A first-time user can reach the Check-in hub from app launch in a single tap (one primary action), with no permission or download screen in between.
- **SC-002**: On a connection that cannot complete the model download (offline, or cellular with the preference off), the user still reaches a fully usable hub and can capture a recording — there is no first-run dead end. Measured by completing a capture with the model unavailable.
- **SC-003**: 100% of recordings captured before the model is ready are eventually transcribed automatically once the model lands (no lost audio, no permanently-pending recording), including across an app relaunch.
- **SC-004**: No user-facing string on the first-run or queue paths contains "Whisper" or a bare "150 MB" (verified by a string/grep audit).
- **SC-005**: The first-run path uses zero raw color/font literals — only design-system tokens — verified by the project's token-grep check, matching the standard applied to other screens.
- **SC-006**: A returning user (onboarding already completed) never sees the welcome again, and a user who already granted the mic is never re-prompted on the first record.
- **SC-007**: No automatic data is spent: with "Download over Cellular" off on a cellular connection, the model download does not begin until Wi-Fi is available.

## Assumptions

- **Audience**: ADHD adults, overwhelm-sensitive and time-blind; the design goal is near-zero first-run friction and a no-nag, no-blame failure posture (DESIGN.md "relief, then permission", "forgiving, no penalty").
- **Direction is approved**: the brainstorm's Direction-A recommendations across all four threads are the agreed scope (single welcome + just-in-time permission + background download + record-before-ready queue + living crescent hero + plain-language copy + Settings model home), per the user's stated choice of the ambitious option.
- **Existing recovery is reused**: the Check-in microphone grant/deny/Settings-deep-link path and the back-to-back transcription serialization already ship and are reused rather than reimplemented.
- **Settings model row is shared with Feature 017**: the transcription row in Settings is the single model-management home; this feature coordinates with 017's Settings work and does not build a parallel one. The existing "AI Models → Whisper Transcription" row is the seam to evolve (de-jargon owned with 017).
- **Single transcription engine**: transcription runs on one on-device engine instance; concurrent inferences are not supported, so the queue serializes.
- **The breathing crescent is liftable**: `CrescentRing` is a self-contained decorative view ([CrescentRing.swift](../../app-four/Views/CheckIn/CrescentRing.swift)) that can be presented from the welcome.
- **No reachability dependency exists yet**: the app has no current network-reachability monitor; honoring the cellular policy (FR-009) introduces one, scoped to the download decision only.
- **Privacy posture is unchanged**: everything stays on-device; no audio, transcript, mood, or medication data leaves the device; logging stays counts/durations only.
