<!-- Created: 2026-07-27 15:10 (WEST) · Updated: 2026-07-27 15:10 (WEST) -->
# 03 — Check-in Capture

## Purpose

The capture area is the product's core loop: record a voice check-in (or type one) in under a minute, confirm capture instantly, and hand everything else to the background pipeline. It covers the Check-in tab UI and its view model, the audio recording service, the text composer, and the save/retry/discard paths. Transcription and extraction are specified in [04-processing-and-extraction.md](04-processing-and-extraction.md); this file covers only up to the point where a recording is persisted and background processing is kicked off.

## Scope

- **In scope:** `CheckInView` / `CheckInSavedView` / `CrescentRing`; `CheckInViewModel` (record → cap → stop → save → background-transcribe kickoff); `AudioRecordingServiceImpl` (format, levels, permissions, interruptions, auto-stop); `TextCheckInComposer` + `CheckInDraft`; the `PendingSave` retry buffer; permission and disk-space error surfaces.
- **Out of scope:** the WhisperKit/NL pipeline internals and pending-transcription drain ([04-processing-and-extraction.md](04-processing-and-extraction.md)); the medication log sheet's dose rules ([07-medications.md](07-medications.md)); what Calendar/Insights do with the saved recording ([05-library-and-history.md](05-library-and-history.md), [06-insights.md](06-insights.md)).

## Actors & triggers

- **User** — taps "Speak check-in", "Type note", "Log meds", "Stop & save", "Cancel", "Try again", "Discard", "Done"; grants/denies mic permission.
- **External triggers** — `StartCheckInIntent` / `whispernotes://checkin` arm auto-start via `AppIntentRouter` (see [02-navigation-and-shell.md](02-navigation-and-shell.md)).
- **System** — audio-session interruptions (Siri, calls, route changes); disk space; 0.1 s UI timer; 50 ms level sampler; the 480 s cap.
- **VoiceOver** — prompt announcements, timer announcements, state announcements.

## Functional requirements

### Entry & guards

**FR-CAP-01 — Single start chokepoint.**
All voice captures — tapped or auto-started — go through `startVoiceCapture()`, which sets `checkInHintSeen = true` and calls `viewModel.startRecording()`. A first capture of either kind (voice or text) permanently dismisses the first-launch hint (`CheckInView.swift:32-33, 68-83, 177`).

**FR-CAP-02 — Re-entry guard.**
`startRecording()` only proceeds from `.idle` or `.done`; from any other state it returns an empty task before any disk, permission, or audio-session work. A rapid double-tap or a re-firing auto-start can never zero a running timer or open a second session (`CheckInViewModel.swift:100-107`). The auto-start consumer mirrors this: `.recording` / `.paused` / `.processing` → return; `.done` → `reset()` then start; `.idle` → start (`CheckInView.swift:68-83`).

**FR-CAP-03 — Disk pre-check (50 MB).**
Before recording, `storageService.availableStorage()` must exceed `LayoutConstants.minDiskSpaceForRecordingBytes` = **50 MB (50 × 1024 × 1024 bytes)**; otherwise the failure is logged and `lowDiskSpace = true`, presenting the alert **"Not Enough Storage"** with message **"Squirl needs at least 50 MB of free space to record. Free up some space and try again."** (single **"OK"** button) (`CheckInViewModel.swift:118-123`; `Constants.swift:11`; `CheckInView.swift:54-58`).

**FR-CAP-04 — Microphone permission.**
`audioService.requestPermission()` (→ `AVAudioApplication.requestRecordPermission()`) runs before the recorder starts; denial logs and sets `permissionDenied = true`, presenting the alert **"Microphone Access Required"** with message **"Squirl needs microphone access to record voice notes. Enable it in Settings."** and buttons **"Open Settings"** (opens `UIApplication.openSettingsURLString`) and **"Cancel"** (`CheckInViewModel.swift:125-130`; `CheckInView.swift:46-53`; `AudioRecordingServiceImpl.swift:54-56`). No speech-recognition permission is requested at record time — the active transcriber is on-device WhisperKit.

**FR-CAP-05 — Silent start failure.**
If recorder start itself throws, the failure is only logged (`"Failed to start recording: \(error)"`); state stays `.idle` with no user-facing surface (`CheckInViewModel.swift:151-153`).

### Recording session

**FR-CAP-06 — Recording format & session.**
Audio is captured as MPEG-4 AAC (`.m4a`) at `AVSampleRateKey = 16000`, mono (`AVNumberOfChannelsKey = 1`), `AVEncoderAudioQualityKey = .high` (label constant `"16 kHz • M4A"`). The audio session is `.playAndRecord`, mode `.default`, options `[.allowBluetoothHFP, .allowBluetoothA2DP]`. The temp file is `recording_<uuid lowercase>.m4a` in `FileManager.default.temporaryDirectory`. `prepareToRecord()` and `record()` must both succeed or the service throws `RecordingError.hardwareFailure` (`AudioRecordingServiceImpl.swift:14-19, 58-90`; `Constants.swift:3-7`).

**FR-CAP-07 — Service-level disk backstop (20 MB).**
`AudioRecordingServiceImpl.startRecording()` throws `RecordingError.deviceDiskFull` if free space is below **20,000,000 bytes (~20 MB)** — a deliberately *lower* secondary threshold behind the view model's 50 MB pre-check (`AudioRecordingServiceImpl.swift:60`).

**FR-CAP-08 — Session chrome on start.**
On successful start: `state = .recording`; the idle timer is disabled (`UIApplication.shared.isIdleTimerDisabled = true`); `elapsedTime` resets; the prompt interval is loaded from settings; the 0.1 s UI timer and 50 ms level monitoring start (`CheckInViewModel.swift:132-141`).

**FR-CAP-09 — Model preload.**
A detached `.utility` task calls `transcriptionService.loadModel()` during recording so post-recording transcription doesn't pay the load cost; failure is only logged ("will retry on stop") (`CheckInViewModel.swift:143-150`).

**FR-CAP-10 — Duration cap (480 s) with auto-stop.**
`maxDuration = LayoutConstants.maxRecordingDuration` = **480 s (8 minutes)**. The 0.1 s timer loop calls `stopRecording()` and breaks when `elapsedTime >= maxDuration` — **the cap auto-stops and saves** (`CheckInViewModel.swift:441-457`; `Constants.swift:10`). Independently, the service runs a max-duration backstop polling every 100 ms that auto-stops the recorder at the same 480 s (`AudioRecordingServiceImpl.swift:251-262`).

**FR-CAP-11 — Wrap-up cue (30 s window, one-shot, 4 s).**
`approachWindow = 30` seconds; `isApproachingCap = elapsedTime >= maxDuration - approachWindow` (≥ 450 s). A one-shot latch (`hasShownCapApproach`, re-armed by a clean `startRecording()`) drives a faint (0.7 opacity) caption **"Wrapping up soon"** — no red, no ticking bar — faded in once, held **4 seconds**, then faded out (`CheckInViewModel.swift:16-37`; `CheckInView.swift:139-145, 293-299`).

**FR-CAP-12 — Nudge prompts with pace settings (exact strings).**
Five prompts cycle while recording, wrapping modulo 5 (`CheckInViewModel.swift:369-375, 380-384`):

1. **"How's your mood?"** — "Heavy, light, flat, bright — whatever fits."
2. **"What's your energy like?"** — "Wired, steady, or running low."
3. **"Able to focus?"** — "Locked in, scattered, somewhere between."
4. **"How did you sleep?"** — "Hours, and how rested you feel."
5. **"Any strong emotions?"** — "Something sitting with you right now."

Cadence: `currentPromptIndex = Int((elapsedTime + 1e-6) / promptInterval) % 5` (the epsilon avoids float drift landing one tick late); `promptProgress` is the 0→1 fraction within the current window (`CheckInViewModel.swift:380-391`). The interval is read once per recording start from `AppSettings.promptPaceSeconds` via `PromptPace(rawValue:)`: **Relaxed = 10 s** ("Relaxed · 10 s", default) or **Brisk = 6 s** ("Brisk · 6 s"); it stays stable during the session (`CheckInViewModel.swift:353-360`; `PromptPace.swift:3-14`).

**FR-CAP-13 — VoiceOver prompt announcements, gated on speech.**
`static let activeVoiceThreshold: Float = 0.1` — the normalized audio level at/above which the mic counts as active voice (above the ~0.01 silence floor). A prompt change sets a single pending announcement flag; the announcement `"<question> <hint>"` is posted only when the flag is pending **and** the user is not speaking (`promptAnnouncementIsEligible = pending && !isSpeaking`). The backlog never accumulates — the user hears the current prompt, not a queue (`CheckInViewModel.swift:49-66, 395-409`; `CheckInView.swift:147-162`).

**FR-CAP-14 — Recording timer accessibility.**
The timer text is an accessibility element with the `.updatesFrequently` trait and label **"Recording, <time> elapsed"** or **"Paused, <time> elapsed"**, throttled to whole seconds so VoiceOver doesn't chatter (`CheckInView.swift:263-270`). State-change announcements: `.processing` → **"Saving…"**; `.done` → **"Captured."** (`CheckInView.swift:147-162`).

### Interruptions & pause

**FR-CAP-15 — Interruption policy: never lose a recording.**
Audio-session interruptions are handled by a pure, testable policy `InterruptionResponse { pause, resume, stayPaused, ignore }`: `.began` → `.pause` if recording else `.ignore`; `.ended` → `.ignore` unless `wasInterrupted`, then `.resume` if options contain `.shouldResume` else `.stayPaused`. The handler **never stops or cancels** on interruption — a transient interruption (Siri, brief call, route blip) never loses the in-progress recording (`AudioRecordingServiceImpl.swift:179-249`).

**FR-CAP-16 — Pause is internal to the service.**
`pauseForInterruption()` accumulates elapsed time and sets `wasInterrupted`; `resumeFromInterruption()` reactivates the session and resumes (failures only logged). This pause/resume is entirely internal: the view model's `state` stays `.recording`, its 0.1 s UI timer keeps counting through an interruption, and the service's own duration bookkeeping excludes the paused span (`AudioRecordingServiceImpl.swift:92-112, 225-249`; notes §10 note).

**FR-CAP-17 — `.paused` UI state is an honest floor.** *Implemented, dormant in 1.0.*
`RecordingState.paused` exists in the enum and is rendered ("Paused" label, dimmed crescent, "Paused, <time> elapsed" announcement), but nothing in `CheckInViewModel` on `main` ever sets `.paused`; pausing happens only inside `AudioRecordingServiceImpl` without flipping the VM state. The view comment calls paused "an honest visual floor only, no resume / audio-append engineering" (`CheckInView.swift:251-277`; `AppEnums.swift:18-24`).

### Stop, save, retry

**FR-CAP-18 — Stop & save pipeline.**
`stopRecording()` (`CheckInViewModel.swift:157-222`):

1. Stops timer/level tasks but **keeps any prior recording's transcription running**; re-enables the idle timer; `state = .processing`.
2. Captures `priorTranscription = transcriptionTask` so the new transcription chains after it — the single WhisperKit engine never runs two inferences at once, and a back-to-back recording never cancels the previous one's transcription.
3. `audioService.stopRecording()` returns `(url, max(finalDuration, recorder.currentTime))`; the file URL + duration are buffered into `pendingSave` **before** the save step. If the audio stop itself throws: logged, `state = .idle` — no captured file to buffer.
4. `attemptSave`: `storageService.saveRecording(from:duration:)` → `store.addRecording(recording)`; clears the buffer and `saveFailed`; `state = .done` immediately — **the UI shows "Captured." before transcription starts.**
5. Model not installed (`aiModelService.localPath(for: .whisper) == nil`): `recording.status = .pendingTranscription`, persisted, transcription skipped — the pending queue drains it later through the exact same path.
6. Model ready: spawns `transcriptionTask` that awaits the prior transcription's completion, then runs `transcribeInBackground(recording)`.

**FR-CAP-19 — PendingSave retry buffer.**
`PendingSave { fileURL: URL; duration: TimeInterval }` holds the just-recorded audio after a save failure. On save failure: logged, `saveFailed = true`, **buffer kept**, state stays `.processing` so the inline retry surface remains on screen — never a silent reset to idle (`CheckInViewModel.swift:39-47, 215-221`). The recovery surface shows copy **"Couldn't save that one."** / **"Your check-in is safe — tap to try again."** with buttons **"Try again"** (accessibility label **"Try saving again"**) → `retrySave()` (re-runs `attemptSave`, chaining after the current transcription task) and **"Discard"** (accessibility label **"Discard this check-in"**) → `discardFailedCapture()` (deletes the buffered audio file, clears buffer + flag, `state = .idle`). Failure also fires `Haptics.error()` (`CheckInView.swift:134-136, 387-419`; `CheckInViewModel.swift:224-244`).

**FR-CAP-20 — Cancel.**
`cancelRecording()` stops timer/level **and** transcription tasks, cancels the model-preload task, re-enables the idle timer, awaits `audioService.cancelRecording()` (**deletes the temp file**) and `transcriptionService.cancelTranscription()`, then `state = .idle`, `elapsedTime = 0`, `lastSavedRecording = nil` (`CheckInViewModel.swift:332-351`; `AudioRecordingServiceImpl.swift:132-139`).

**FR-CAP-21 — Saved confirmation.**
On `.done`: a meadow-green check disc (78 pt circle, 32 pt bold checkmark) spring-pops once (`response: 0.5, dampingFraction: 0.6`; skipped under Reduce Motion) with `Haptics.success()`. Copy: **"Captured."** (24 pt bold) and **"That's today's check-in. Talk to you next time."** (callout, max width 240). A **"Done"** full-width green pill (min height 50) calls `reset()` back to the idle hub. No transcribing UI, no daily card — transcription/extraction run silently in the background (`CheckInView.swift:422-477`; `CheckInViewModel.swift:346-351`).

### Background transcription kickoff

**FR-CAP-22 — Background transcription with 90 s timeout.**
`transcribeInBackground` consumes `transcriptionService.transcribe(audioURL:)` through `consumeStreamWithTimeout(..., timeoutSeconds: 90)`. Per segment: bail if the recording was deleted; an `isError` segment throws; otherwise write `fullTranscriptText = segment.text`, `status = .transcribing`, save. After completion: re-verify the recording still exists (the user may have deleted it mid-transcription — never touch a freed `@Model`), set `status = .completed`, save, and hand the transcript to `processingViewModel.processRawTranscription(_:duration:language:audioFileName:)` (`CheckInViewModel.swift:246-296`). Failure copy written to the transcript: cancellation → **"Transcription cancelled. Tap to retry in the recording detail view."**; timeout → **"Transcription timed out. Tap to retry in the recording detail view."**; other errors → `"Transcription failed: \(error.localizedDescription)"` — each with `status = .failed`. The cancelled path finalizes status in a fresh, uncancelled MainActor task (`CheckInViewModel.swift:267-295`).

### Text check-in

**FR-CAP-23 — Text composer ("signals-first").**
The **"Type note"** pill opens `TextCheckInComposer`: a sheet titled **"Type a check-in"** with a circular close button (accessibility label **"Close"**), three `SignalScaleRow` glyph pickers — **"Mood"**, **"Energy"**, **"Focus"** (1→5 ramp with a mono readout `"<N> · <displayLabel>"` or **"—"** when unselected) — then a `TextEditor` note box with placeholder **"Anything you want to remember about today?"** (min height 120 pt), then **"Save check-in"** (`.checkInPrimary`), disabled while `draft.isEmpty`. Meds and sleep are deliberately not captured here (voice/Edit sheet only) (`TextCheckInComposer.swift:3-5, 29-149`; `CheckInView.swift:193-203`).

**FR-CAP-24 — Draft semantics.**
`CheckInDraft` holds exactly what the user explicitly picked — `mood`, `energy`, `focus`, `sleepQuality`, `meds: [DraftMedication]`, `note` — and is authoritative: extraction may only fill what is nil. `DraftMedication` defaults: `takenAt = .now`, `durationHours = 10` (**10-hour default**). `isEmpty` is true only when all pickers are nil, meds are empty, and the trimmed note is empty (`CheckInDraft.swift:5-33`).

**FR-CAP-25 — Text save & retry.**
`saveTextCheckIn` is a no-op on an empty draft. It persists via `store.persistCheckInNote(draft)`; on throw: logged, `textSaveFailed = true`, and **the draft stays intact in the composer** — the composer stays open showing inline error **"Couldn't save — tap to try again. Your note is safe."** with `Haptics.error()` (the sheet's `onSave` returns `!textSaveFailed`; false keeps it open). On success: `checkInHintSeen = true`; if `draft.trimmedNote` is non-empty, extraction runs with `fillOnly: true` (fills only what the user didn't explicitly pick); `state = .done` — the text path lands on the same "Captured." screen as voice (`CheckInViewModel.swift:411-439`; `TextCheckInComposer.swift:98-120`; `CheckInView.swift:39-45`).

### Idle & recording chrome

**FR-CAP-26 — Idle hub content.**
Header: today's date (`Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.wide))`, uppercased, label font); headline **"How do you feel?"** (24 pt bold, `.isHeader`). First-launch whisper hint (until the first capture of either kind, `@AppStorage("checkInHintSeen")`): **"Say whatever's on your mind — a few words is plenty."** (inkSecondary at 0.7 opacity). Three stacked actions: **"Log meds"** pill (icon `Icons.medication`, tint `Palette.medication`) → medication log sheet; **"Speak check-in"** — solid `Theme.meadowGreen` capsule, `mic.fill` icon, min height 48, accessibility label **"Start voice check-in"**; **"Type note"** pill (icon `square.and.pencil`) → text composer. Hub pills: white card capsule, min height `Metrics.minTapTarget` (44 pt) (`CheckInView.swift:85-87, 169-238`).

**FR-CAP-27 — Recording chrome.**
While recording: a prompt card (progress bar + hero prompt + 5 prompt dots); the timer; the crescent (diameter `Metrics.CheckIn.crescentDiameter` = 300 pt, `accessibilityHidden(true)`); **"Stop & save"** (stop glyph 11 pt rounded square + text; while `.processing` shows a `ProgressView` and is disabled; accessibility label **"Finish check-in"**); **"Cancel"** (secondary capsule, min 44×38; accessibility label **"Cancel recording"**). The progress bar is a capsule track (`NewLook.tintNeutral`) with `Theme.meadowGreen` fill, height 4 pt, `.id(currentPromptIndex)` so per-window resets snap to 0 instead of animating backwards; `accessibilityHidden(true)`. Prompt dots: 6 pt circles, active = meadowGreen, inactive = inkSecondary at 0.3; `accessibilityHidden(true)`. The hero prompt has combined accessibility label `"<question> <hint>"` (`CheckInView.swift:242-360, 362-385`).

**FR-CAP-28 — Crescent behavior.**
`CrescentRing` is purely decorative (`accessibilityHidden(true)`), a full-circle `Theme.meadowGreen` stroke (default `lineWidth = 22`). Idle: breathes — scale 1.0→1.035, opacity 0.94→1.0, `easeInOut(duration: 5).repeatForever(autoreverses: true)`. Active: rotates — `linear(duration: 7).repeatForever(autoreverses: false)`. `.id(isActive)` forces recreation on every flip, resetting animation state. All animations removed under Reduce Motion (`CrescentRing.swift:6-47`).

## User flows

### Voice check-in (normative end-to-end)
1. User taps "Speak check-in" (or an intent/deep link arms auto-start). Hint flag set; `startRecording()`.
2. Guards: state must be `.idle`/`.done`; disk ≥ 50 MB else "Not Enough Storage" alert; mic permission else "Microphone Access Required" alert with "Open Settings".
3. Recorder starts (AAC 16 kHz mono `.m4a` in temp); idle timer disabled; 0.1 s UI timer; 50 ms level monitoring feeds the VoiceOver announcement gate; Whisper model preloads detached.
4. UI: crescent rotates; prompt card cycles the 5 nudge prompts at the configured pace (default 10 s); timer counts up; prompt announcements defer while the user speaks.
5. At ≥ 450 s: one-shot faint "Wrapping up soon" cue (4 s). At 480 s: auto stop & save.
6. User taps "Stop & save" → `.processing` ("Saving…" announced; spinner): audio finalized → buffered in `pendingSave` → persisted via `storageService.saveRecording` + `store.addRecording`.
7. Success → `.done` ("Captured." screen, success haptic). Model ready → background transcription (chained after any prior one; 90 s timeout; `.transcribing` → `.completed`) → summarization + medication events. Model missing → `status = .pendingTranscription`, drained later on launch/foreground/download-completion through the identical path.
8. Failures: save failure keeps the buffer and shows inline "Try again"/"Discard"; transcription cancel/timeout/error set `.failed` with retry copy; stop failure returns to `.idle`; cancel deletes the temp file and kills in-flight transcription.

### Text check-in
1. "Type note" → composer sheet.
2. Optionally pick mood/energy/focus 1→5 and/or write a note; "Save check-in" enables once the draft is non-empty.
3. Save → persisted; optional note text runs extraction in `fillOnly` mode → `.done` "Captured." screen.
4. Save failure → composer stays open, draft intact, inline error "Couldn't save — tap to try again. Your note is safe."

## UI states

`RecordingState` (`AppEnums.swift:18-24`): `idle`, `recording`, `paused`, `processing`, `done`. Rendering:

| State | Surface |
|---|---|
| `.idle` | Hub: date header, "How do you feel?", hint (first launch), Log meds / Speak check-in / Type note; crescent breathing |
| `.recording` | Prompt card, timer, crescent rotating, Stop & save, Cancel; wrap-up cue ≥ 450 s |
| `.paused` | "Paused" label, dimmed crescent — rendered but never set on `main` (dormant; see FR-CAP-17) |
| `.processing` | Same stage; stop button shows spinner, disabled; "Saving…" announced |
| `.done` | `CheckInSavedView`: "Captured." + Done |
| `saveFailed` (over `.processing`) | Inline recovery: "Couldn't save that one." / Try again / Discard |
| `permissionDenied` | Alert "Microphone Access Required" |
| `lowDiskSpace` | Alert "Not Enough Storage" |

`.idle`, `.recording`, `.paused`, `.processing` share one `captureStage` ZStack so the crescent stays anchored and grows in place rather than jumping; state changes animate with `Motion.smooth`, disabled under Reduce Motion (`CheckInView.swift:29, 105-113`).

## Validation & constants

| Item | Value | Source |
|---|---|---|
| Max recording duration | 480 s (8 min) | `Constants.swift:10` |
| Min free disk to start (VM gate) | 50 MB (`50 * 1024 * 1024`) | `Constants.swift:11` |
| Min free disk (service backstop) | 20,000,000 bytes (~20 MB) | `AudioRecordingServiceImpl.swift:60` |
| Cap-approach window | 30 s before cap (≥ 450 s) | `CheckInViewModel.swift:21` |
| Cap cue display | 4 s fade | `CheckInView.swift:143` |
| UI timer tick | 0.1 s | `CheckInViewModel.swift:449` |
| Audio level sample interval | 50 ms | `AudioRecordingServiceImpl.swift:43` |
| Active-voice threshold | 0.1 (normalized) | `CheckInViewModel.swift:55` |
| Silence floor (not recording) | 0.01 | `AudioRecordingServiceImpl.swift:41` |
| Transcription timeout | 90 s | `CheckInViewModel.swift:250` |
| Prompt pace | Relaxed 10 s (default) / Brisk 6 s | `PromptPace.swift:3-14` |
| Nudge prompts | 5, wrapping modulo | `CheckInViewModel.swift:369-375, 383` |
| Audio format | AAC `.m4a`, 16 kHz, mono, high quality | `AudioRecordingServiceImpl.swift:14-19` |
| Crescent diameter | 300 pt | `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Metrics.swift:53` |
| Prompt bar height | 4 pt | `CheckInView.swift:304-320` |
| Min tap target | 44 pt | `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Metrics.swift:10` |
| First-launch hint key | `@AppStorage("checkInHintSeen")`, default false | `CheckInView.swift:14-16` |
| DraftMedication default duration | 10 hours | `CheckInDraft.swift:18` |
| Text note min height | 120 pt | `TextCheckInComposer.swift:94` |
| Saved disc / check | 78 pt / 32 pt; spring `response: 0.5, dampingFraction: 0.6` | `CheckInView.swift:422-477` |

Enum inventories: `RecordingError { permissionDenied, hardwareFailure, storageFull, deviceDiskFull, interruption(InterruptionType), timeout, unknown }`; `InterruptionType { phoneCall, systemOverload, appBackgrounded }`; `RecordingStatus { recorded, transcribing, pendingTranscription, completed, failed, placeholder }` (`AppEnums.swift:4-42`).

## Edge cases

- **Double-tap / re-firing auto-start:** no-op via the FR-CAP-02 guard.
- **Recording deleted mid-transcription:** every post-stream mutation re-checks existence; a deleted recording is never touched.
- **Back-to-back recordings:** the second transcription chains after the first; the previous recording's transcription is never cancelled by a new recording (it is cancelled only by an explicit Cancel of its own session).
- **Model absent at save:** recording persisted as `.pendingTranscription`; the queue drains it later through the identical path (see [04-processing-and-extraction.md](04-processing-and-extraction.md)).
- **Interruption mid-recording:** service pauses internally and resumes per policy; UI timer keeps counting; recording is never discarded.
- **Save failure:** buffer retained; user chooses retry or discard; discard deletes the temp audio file.
- **Stop failure:** returns to `.idle` with no buffered file.
- **Empty text draft:** save is a no-op; the button is disabled.
- **Simulator:** the level stream emits a fake sine wave between 0.2 and 0.8 (`sin(t*5)*0.3 + 0.5`) (`AudioRecordingServiceImpl.swift:21-52`).

## Acceptance criteria

- Tapping "Speak check-in" with mic permission granted and ≥ 50 MB free starts a recording; the timer, rotating crescent, and cycling prompts appear.
- At 450 s elapsed, "Wrapping up soon" fades in once for 4 s; at 480 s the recording auto-stops and saves.
- Denying mic permission shows the "Microphone Access Required" alert with the exact message and an "Open Settings" button that opens Settings.
- With < 50 MB free, the "Not Enough Storage" alert shows the exact message; no recorder is started.
- Tapping "Stop & save" shows "Captured." immediately after persistence, before transcription completes; the recording appears in the library and transcribes in the background.
- Forcing a save failure keeps the buffered audio; "Try again" persists it; "Discard" deletes the file and returns to idle.
- An audio-session interruption during recording does not lose the recording; on `.shouldResume` the recorder resumes.
- The first-launch hint disappears after either a voice or text capture and never reappears (`checkInHintSeen`).
- A text check-in with only glyph picks (no note) saves and shows "Captured."; a failed text save leaves the composer open with the draft intact and the exact inline error.

## Source references

- `app-four/Views/CheckIn/CheckInView.swift:14-16` hint key; `:26-58` container, sheets, alerts; `:61-66, 147-162` announcements; `:68-83` auto-start; `:105-145` stage mapping & cap cue; `:169-238` idle chrome; `:242-360` recording chrome; `:362-419` stop/cancel & recovery; `:422-477` saved view
- `app-four/Views/CheckIn/CrescentRing.swift:6-47` — breathing/rotation, Reduce Motion
- `app-four/Views/CheckIn/TextCheckInComposer.swift:3-149` — composer layout, strings, retry
- `app-four/ViewModels/CheckInViewModel.swift:9-98` state & constants; `:100-155` startRecording; `:157-244` stop/save/retry/discard; `:246-330` background transcription & timeout; `:332-360` cancel/reset/prompt interval; `:369-409` prompts & announcements; `:411-439` text save; `:441-466` timer & levels
- `app-four/Services/Audio/AudioRecordingServiceImpl.swift:14-19` format; `:21-52` level stream; `:54-56` permission; `:58-90` start; `:92-112` pause/resume; `:114-139` stop/cancel; `:160-249` interruption policy; `:251-268` auto-stop & storage
- `app-four/Models/CheckInDraft.swift:5-33` — draft semantics
- `app-four/Models/AppEnums.swift:4-42, 88-93` — status/state/error enums
- `app-four/Models/PromptPace.swift:3-14` — pace options
- `app-four/Utils/Constants.swift:3-11` — audio format, cap, disk gate
- `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Metrics.swift:10, 53` — tap target, crescent diameter
