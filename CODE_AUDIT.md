<!-- Created: 2026-07-18 02:31 (WEST) · Updated: 2026-07-18 02:31 (WEST) -->
# Squirl (app-four) Code Audit — 2026-07-18

Scope: production tree on `feat/037-live-activity-controls` (= `main` + spec 037), ~16.5k lines / 128 Swift files across app-four, SquirlWidgets, SquirlLiveActivity. Method: 8 skill-grounded audit lenses (swift-concurrency-pro, swiftui-pro, swiftui-design-principles, widgets, app-intents, background-execution + dead-code and bugs/security/perf sweeps) run as parallel agents, every Critical/High adversarially verified by an independent refuter, Criticals additionally verified by hand. Compiler ground truth: CLI device build (`generic/platform=iOS`, Debug) — **BUILD SUCCEEDED, 0 warnings** (note: Swift 5 language mode with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; minimal checking, so silence ≠ safety). 102 raw findings → 4 refuted → 1 merged → **97 findings**. Read §1, fix §2 in an afternoon, then work §3–§9 by severity.

## 1. Executive summary

1. **[Critical] Retry-transcription path mutates a possibly-deleted @Model — missing the store.exists guards the main pipeline has** — §5.1 — `app-four/ViewModels/RecordingDetailViewModel.swift:77-130`
2. **[High] Shared WhisperKit engine is preempted by cancel-on-entry across three independent consumers** — §3.1 — `app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift:97`
3. **[High] Debug 'Delete All' permanently destroys all real recordings with no confirmation; 'Done' button is a no-op (reachable in TestFlight)** — §5.2 — `app-four/Views/TestServicesView.swift:101-107`
4. **[High] Drain loop lacks every environmental guard the VM path has: no timeout, no backgrounded re-queue, isDraining wedges forever on a hung inference** — §5.3 — `app-four/Services/PendingTranscriptionServiceImpl.swift:37-52`
5. **[High] Medication bar's time model is frozen at refresh() — progress, state word, onset pulse, and visibility go stale on screen** — §5.4 — `app-four/ViewModels/MedicationBarViewModel.swift:59-109`
6. **[High] WhisperKit's beginBackgroundTask has no expiration handler — backgrounding mid-transcription is a guaranteed watchdog kill** — §5.5 — `app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift:145-152`
7. **[High] Documents dir with health audio + plaintext transcript exports exposed via Files app / Finder file sharing** — §6.1 — `app-four.xcodeproj/project.pbxproj:738`
8. **[High] User-deleted check-ins leave health audio recordings on disk forever** — §6.2 — `app-four/Store/RecordingStore.swift:79-84`
9. **[High] Journal export reads up to 200MB of audio and JSON-encodes the whole archive on the main actor** — §7.1 — `app-four/Services/ExportService.swift:125-133`
10. **[High] Transcription pipeline implemented three times with diverging behavior** — §9.1 — `app-four/ViewModels/CheckInViewModel.swift:284-380`

Headline reversal: the long-flagged “AudioRecordingServiceImpl main-queue vs pool data race” was **refuted with build evidence** — the app target compiles with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (project.pbxproj:507/547/711/751), so the whole service is MainActor-isolated. Three lenses claimed it; three refuters independently killed it. The residual finding (implicit, load-bearing isolation + audio-session work on the main thread) is §3.2.

## 2. Quick wins

### 2.1 CheckInView hand-rolls the primary button twice, duplicating PrimaryButtonStyle's gradient/shadow constants and splitting the primary shape (rect-16 vs Capsule vs DESIGN.md 'pill')
- **Location:** `app-four/Views/CheckIn/CheckInView.swift:205-221, 385-396, 426, Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Buttons.swift:13`
- **What:** speakButton (lines 205-221) and failureRecovery's 'Try again' (385-396) rebuild the meadow-gradient primary action inline — white label, Theme.meadowGradient fill, and the shadow constant Theme.meadowAmber.opacity(0.34)/radius 12/y 5 now copy-pasted in three places (Buttons.swift:13 + both sites), with a fourth near-variant (0.3/20/8) on the saved disc at line 426. The two hand-rolled buttons also disagree on shape: RoundedRectangle(Radius.button = 16) vs Capsule, while DESIGN.md specifies 'primary = Meadow gradient pill'.
- **Why:** Three copies of one shadow spec guarantees drift (one already drifted), and two primary-button silhouettes appear within the same capture flow. A fixed width: 220 on speakButton also ignores the style's maxWidth behavior.
- **Action:** Extend PrimaryButtonStyle (e.g. an optional fixedWidth/shape parameter, or a hubPrimary variant) and replace both inline builds with .buttonStyle(.primary); hoist the shadow into the style so it exists once. ~30 min.
- **Severity:** Medium

### 2.2 AppLogger is an ungated print() — migrate to os.Logger with privacy annotations
- **Location:** `app-four/Utils/Logger.swift:4-9`
- **What:** All 100+ log sites funnel into a bare print(), active in Release builds (interpolation cost paid, output discarded), with no privacy redaction and no log-level control. Current messages are content-clean (ids/counts/paths, never transcript or med text — verified by grep), but nothing enforces that.
- **Why:** ≤30-min fix: os.Logger gives free Release-build compile-out of message interpolation, Console.app visibility during device QA, and %{private} redaction as a guardrail before someone logs transcript text.
- **Action:** Replace the print with os.Logger(subsystem:category:) using .debug level; keep the AppLogger facade so no call sites change.
- **Severity:** Low

### 2.3 Duration formatting implemented three times
- **Location:** `app-four/Utils/AccessibilityHelpers.swift:10-14, app-four/Models/Recording.swift:122-126, app-four/Views/Components/AudioPlayerView.swift:76-79`
- **What:** Three hand-rolled m:ss formatters: AccessibilityHelpers.formatDuration (used by CheckInViewModel.timeString), Recording.formattedDuration (identical body), and AudioPlayerView's private formatter (%02d:%02d variant).
- **Why:** Cosmetic divergence risk (one pads minutes, two don't) and triplicated logic for a two-line function.
- **Action:** Keep AccessibilityHelpers.formatDuration (or switch all to Duration.formatted(.time(pattern:))) and delete the other two.
- **Severity:** Low

### 2.4 IntentDialog(full:supporting:) passes the identical string for both variants
- **Location:** `app-four/Intents/LogDefaultDoseIntent.swift:29`
- **What:** `IntentDialog(full: "\(line)", supporting: "\(line)")` — the two-variant API is inert because both variants are the same string. The supporting variant exists so screen-capable surfaces get a compact form while voice-only surfaces (HomePod/AirPods, where this background intent is most valuable) get the full sentence.
- **Why:** Dead parameter today; it also masks the fact that no genuinely short confirmation was designed for the visual surface.
- **Action:** Provide a real short supporting form (e.g. "Logged · 9:41" / "Dose still active") and keep the current line as `full`; or collapse to the single-string `IntentDialog` initializer if variants are intentionally identical.
- **Severity:** Low

### 2.5 No in-app shortcut discoverability (ShortcutsLink / SiriTipView absent)
- **Location:** `app-four/Intents/SquirlAppShortcuts.swift:7, app-four/Views/SettingsView.swift:55-63`
- **What:** Grep confirms neither `ShortcutsLink` nor `SiriTipView` appears anywhere in app-four/. The two App Shortcuts are zero-setup discoverable via Siri/Spotlight, but nothing in the app itself ever tells the user "Log my meds in Squirl" exists.
- **Why:** US1's whole value is hands-free logging; users who never open the Shortcuts app will not discover the phrase, and a one-line SiriTipView near the My Medication section is the canonical, cheap nudge.
- **Action:** Add `SiriTipView(intent: LogDefaultDoseIntent(), isVisible:)` (dismissal persisted via @AppStorage) under the My Medication section and optionally a `ShortcutsLink()` footer in Settings — ≤30 min.
- **Severity:** Low

### 2.6 Off-grid spacing/radius scatter where Spacing/Radius tokens exist
- **Location:** `app-four/Views/Settings/MyMedicationSection.swift:148, 153, 162-163, app-four/Views/Insights/SignalAverageGauges.swift:71-72, app-four/Views/Insights/ConnectionCardsView.swift:120, app-four/Views/Components/RecordingRow.swift:41, app-four/Views/Components/MedicationLogSheet.swift:185, app-four/Views/Settings/StickerSetupView.swift:131`
- **What:** Arbitrary values off the 4/8 grid where tokens exist: HStack(spacing: 10) + .padding(10) + cornerRadius 7 and a Color(.tertiarySystemFill) surface in MyMedicationSection's preview banner (the one system-gray surface amid cream listRowBackground rows); .padding(.top, 6)/.padding(.horizontal, 4) in SignalAverageGauges; spacing: 6 in ConnectionCardsView's MiniBar; .padding(.top, 5) baseline nudge in RecordingRow (unnamed, unlike Metrics.rowHeadTop which documents the same trick); .padding(.vertical, 2) in MedicationLogSheet/StickerSetupView.
- **Why:** Spacing.swift's own doc says 'Never use arbitrary numbers like 14, 18, 26, 34'. The Settings typography exemption (2026-06-24) covers native List chrome, not bespoke nested cards with invented radii. Individually invisible; collectively the rhythm the grid exists to protect.
- **Action:** Snap each to the nearest token (10→Spacing.m or .s, 7→Radius.control, 6→Spacing.xs or .s, 2→drop or Spacing.xs) and name the RecordingRow baseline nudge in Metrics if it must stay; consider Theme.surface2 for the settings banner fill. ~30 min total.
- **Severity:** Low

### 2.7 Per-body DateFormatter allocations — spec 022 T037 still unfinished
- **Location:** `app-four/Views/SettingsView.swift:28-32, app-four/Views/Components/DayDetailSheet.swift:9-16, app-four/Views/Insights/MonthSelectorScrollView.swift:7-11, app-four/Views/Insights/SignalStripsView.swift:105`
- **What:** SettingsView.exportFilename allocates a fresh DateFormatter on every body evaluation (and Settings re-evaluates per download-progress tick); DayDetailSheet.dayLabel builds one per body; MonthSelectorScrollView stores one per view-struct init; SignalStripsView uses DateFormatter.localizedString per bead label. specs/022-view-audit-remediation/tasks.md T037 already tracks the first two and is unchecked.
- **Why:** DateFormatter creation is one of the classically expensive per-frame allocations; Date.FormatStyle is cached by the system and localized correctly (the current 'yyyy-MM-dd'/'MMM yyyy' patterns also ignore locale).
- **Action:** Replace with Text(date, format:)/Date.FormatStyle or a static let formatter; close T037.
- **Severity:** Low

### 2.8 Per-row RelativeDateTimeFormatter allocation in Recording.formattedDate
- **Location:** `app-four/Models/Recording.swift:129-133`
- **What:** formattedDate constructs a new RelativeDateTimeFormatter on every access; it is called from list rows, so scrolling allocates a formatter per row per render.
- **Why:** Formatter construction is one of the classic list-scroll costs; hoisting to a static let is a two-line change.
- **Action:** Cache one static RelativeDateTimeFormatter (formatters are thread-safe for reading) or switch to Date.RelativeFormatStyle which is cheap by value.
- **Severity:** Low

### 2.9 Quick win: Task.sleep(nanoseconds:) magic numbers and a spurious await on a sync static call
- **Location:** `app-four/ViewModels/CheckInViewModel.swift:372, 549; app-four/ViewModels/RecordingDetailViewModel.swift:124; app-four/Services/Audio/AudioRecordingServiceImpl.swift:44; app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift:156`
- **What:** Four sites still use the raw nanosecond API (100_000_000, 50_000_000, timeoutSeconds * 1_000_000_000) where Task.sleep(for: .milliseconds(100)) / .seconds(timeout) is the modern, misread-proof form (LiveActivityControllerImpl.swift:80 already uses it). Separately, WhisperKitTranscriptionService.swift:156 writes await Self.cleanTranscript(...) on a nonisolated synchronous static function — the await is a no-op that implies a suspension that never happens.
- **Why:** Consistency with the codebase's own modern usage, and the phantom await misleads reviewers auditing this actor's real suspension points (where reentrancy assumptions live).
- **Action:** Swap to Duration-based Task.sleep(for:) at the three sleep sites; delete the await at line 156.
- **Severity:** Low

### 2.10 Quick win: dead duration fallback — recorder.currentTime read after stop() always returns 0
- **Location:** `app-four/Services/Audio/AudioRecordingServiceImpl.swift:124-133`
- **What:** stopRecording() calls recorder.stop() (line 124) and only then computes max(finalDuration, recorder.currentTime) (line 130). AVAudioRecorder.currentTime is only meaningful while recording; after stop it reports 0, so the 'ensure duration is at least the recorder's reported duration' fallback is dead and the log line prints a misleading 0.
- **Why:** The safety net the comment promises does not exist — duration rests entirely on the wall-clock accumulation that finding 2 shows can drift.
- **Action:** Capture let reported = recorder.currentTime BEFORE recorder.stop(), then max() with it; or drop the fallback and the stale comment.
- **Severity:** Low

### 2.11 Quick win: isSpeaking is re-assigned on every 50 ms level sample, firing @Observable invalidation at 20 Hz
- **Location:** `app-four/ViewModels/CheckInViewModel.swift:495-497, app-four/Services/Audio/AudioRecordingServiceImpl.swift:22-53`
- **What:** `ingestAudioLevel` does `isSpeaking = level >= threshold` for every sample of the 50 ms polling stream. Observation fires on every set regardless of value equality, so the recording screen receives ~20 invalidations/s from this property alone, on top of the 10 Hz elapsedTime ticks — for a value that changes state a few times a minute.
- **Why:** Free render churn on the battery-sensitive recording screen; the level stream is otherwise discarded (it feeds only this gate, per the R4 comment).
- **Action:** `let speaking = level >= Self.activeVoiceThreshold; if speaking != isSpeaking { isSpeaking = speaking }`. One-line guard.
- **Severity:** Low

### 2.12 Quick win: legacy .tabItem instead of the Tab API on an iOS 26 target
- **Location:** `app-four/Views/RootTabView.swift:21, 25, 29, 33`
- **What:** The root TabView still builds its four tabs with .tabItem { Label(...) }. On an iOS 26-only deployment the Tab(_:systemImage:value:) API (iOS 18+) is the supported form — it gives type-safe selection over the existing Tab enum and is required footing for sidebar-adaptable/tab customization behaviors.
- **Why:** swiftui-pro api guidance: always use the Tab API over tabItem; this is the app's main navigation surface and the migration is mechanical.
- **Action:** Replace the four .tabItem blocks with Tab("Calendar", systemImage: Icons.calendar, value: .calendar) { ... } etc., binding the existing selection value.
- **Severity:** Low

### 2.13 Quick win: recording-start failure is swallowed — UI stays silently idle on hardware failure
- **Location:** `app-four/ViewModels/CheckInViewModel.swift:173-175`
- **What:** startRecording()'s catch for audioService.startRecording() only logs. permissionDenied and lowDiskSpace have dedicated surfaces, but RecordingError.hardwareFailure / session-activation errors leave state == .idle with no user-visible feedback — the tap just does nothing (the bug-patterns 'swallowed errors in Task closures' shape).
- **Why:** A mic in use by another app or a failed session activation reads as 'the button is broken'; for a capture-first app that is a trust-killer, and it is a 10-minute fix.
- **Action:** Add a startFailed flag set in the catch, surfaced with the same calm retry copy pattern as saveFailed (FR-005 styling).
- **Severity:** Low

### 2.14 Quick win: stopRecording's duration fallback reads recorder.currentTime after stop() — always 0, fallback is dead
- **Location:** `app-four/Services/Audio/AudioRecordingServiceImpl.swift:118-133`
- **What:** `recorder.stop()` runs at line 124; `recorder.currentTime` is read at line 130. `currentTime` is valid only while recording — after stop it reports 0, so `max(finalDuration, recorder.currentTime)` always resolves to the wall-clock computation and the intended hardware-truth fallback never engages (the log at line 132 will show 'recorder time: 0.0').
- **Why:** The fallback exists precisely for when the wall-clock bookkeeping is wrong (e.g. the interruption races in finding 1), which is exactly when it silently returns 0 instead of correcting the duration.
- **Action:** Capture `let recorderTime = recorder.currentTime` before calling `stop()`, then `max(finalDuration, recorderTime)`. Two-line fix.
- **Severity:** Low

### 2.15 Scaffolding-era dead declarations: two whole enums, three never-thrown error cases, a placeholder function, two compat aliases
- **Location:** `app-four/Models/AppEnums.swift:27-51,103-108, app-four/Utils/AudioConverter.swift:19-36, app-four/Models/Recording.swift:143-145`
- **What:** Zero-reference (verified project-wide grep): enum ModelStatus (AppEnums:45), enum DownloadStatus (AppEnums:103), RecordingError cases .permissionDenied/.storageFull/.interruption (never thrown; only .deviceDiskFull/.hardwareFailure/.unknown/.timeout are) and with them enum InterruptionType (AppEnums:38, referenced only by the dead case), AudioConverter.convertToPCM (self-described 'Placeholder for future PCM conversion'), and Recording's 'UI Compatibility Properties' transcriptText/durationString aliases each used exactly once (RecordingDetailView.swift:105,190).
- **Why:** Repo CLAUDE.md explicitly bans dead code and backwards-compat shims; the unused RecordingError cases also force Codable synthesis over a payload type that exists for nothing.
- **Action:** Delete all of them and inline the two alias call sites to fullTranscriptText/formattedDuration. ~15 minutes, zero behavior change.
- **Severity:** Low

### 2.16 Stale design comments contradict the shipped system: Fraunces/DM Sans (x4), phantom .glassEffect, systemPurple, wrong token values in doc comments
- **Location:** `app-four/Views/Components/CalendarDayCell.swift:19, app-four/Views/CheckIn/CheckInView.swift:412, app-four/Views/Onboarding/WelcomeView.swift:4-6, app-four/Views/InsightsView.swift:66, app-four/DesignSystem/MedicationBarOverlay.swift:10-11, app-four/Views/Components/TimelineBead.swift:77, Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Card.swift:6, Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Opacity.swift:9`
- **What:** Comments still narrate the pre-reversal system: 'DM Sans tabular figures' (CalendarDayCell:19), ''Captured.' in Fraunces' (CheckInView:412), 'a Fraunces headline' (WelcomeView), 'Fraunces "Insights"' (InsightsView:66) — all SF since spec 023. MedicationBarOverlay's doc claims 'floating Liquid Glass capsule (.glassEffect)' but no glassEffect is applied. TimelineBead:77 says 'systemPurple brightens in dark mode' while using Palette.medication. Card.swift's doc says '12pt corner radius' but Radius.card = 16; Opacity.swift documents moodBlock as '0.16' while the value is 0.24.
- **Why:** These comments are the in-file design record; each one asserts a token or face the system no longer has, and the Card/Opacity ones misstate actual token values — the exact traps a future edit will copy.
- **Action:** One sweep deleting or correcting the eight comments (per repo standard: no comments unless the WHY is non-obvious). ~15 min.
- **Severity:** Low

### 2.17 Staleness conveyed only by 50% opacity; phase glyphs unlabeled — VoiceOver reads a dead card as an active recording
- **Location:** `SquirlWidgets/SquirlWidgetsLiveActivity.swift:30,36,46,51,56,95, 71-88`
- **What:** `context.isStale` is expressed exclusively as `.opacity(0.5)` at six sites. VoiceOver on the Lock-Screen card still announces 'Recording check-in' plus live-sounding buttons when the backing process is dead; low-vision users get a contrast-halving dim as the only cue. The phase `Image(systemName:)` glyphs (waveform/pause/checkmark) carry no accessibility labels, so VoiceOver reads SF Symbol default names; the card's header rows are not grouped with `.accessibilityElement(children: .combine)`.
- **Why:** The Lock-Screen card is the feature's whole UI when the phone is locked; the stale state is precisely the moment the surface must not claim to be recording (FR-016 adjacent). All fixes are view-modifier-only, ≤30 min.
- **Action:** When `context.isStale`, swap the title to a stale string (e.g. 'Check-in — needs reopening') or add `.accessibilityLabel`; add labels/`.accessibilityHidden(true)` to decorative glyphs and combine the header row into one element.
- **Severity:** Low

### 2.18 TextEditor + manual placeholder ZStack where TextField(axis: .vertical) suffices
- **Location:** `app-four/Views/CheckIn/TextCheckInComposer.swift:73-95, app-four/Views/Feedback/IssueReportView.swift:76-77`
- **What:** The type-note composer fakes a placeholder by overlaying a Text with allowsHitTesting(false) over a TextEditor; IssueReportView uses a bare TextEditor with no placeholder at all.
- **Why:** TextField("prompt", text:, axis: .vertical) with .lineLimit(5...) gives native placeholder behavior, removes the hit-testing hack, and keeps scroll/typography defaults consistent.
- **Action:** Swap both to TextField(axis: .vertical) with lineLimit(n...) and delete the overlay (≤15 min).
- **Severity:** Low

### 2.19 VoiceOver 'selected' state double-announced or baked into labels on Edit-sheet chips
- **Location:** `app-four/Views/ExtractionReviewView.swift:414-415,435,453`
- **What:** medGrid chips set accessibilityLabel("\(name), selected") AND .accessibilityAddTraits(.isSelected) — VoiceOver announces selection twice. The emotion/side-effect chips override Chip's built-in label with state baked into the string, duplicating the .isSelected trait Chip already applies (Components/Chip.swift:68).
- **Why:** Redundant/state-encoded labels drift from actual state and produce double announcements; the component already carries the canonical trait.
- **Action:** Drop the ', selected' suffixes and rely on the .isSelected trait everywhere (≤15 min).
- **Severity:** Low

## 3. Concurrency

### 3.1 Shared WhisperKit engine is preempted by cancel-on-entry across three independent consumers
- **Location:** `app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift:97, app-four/ViewModels/CheckInViewModel.swift:286, app-four/Services/PendingTranscriptionServiceImpl.swift:87, app-four/ViewModels/RecordingDetailViewModel.swift:86`
- **What:** transcribe() begins with activeTranscriptionTask?.cancel() (line 97). Three callers share the one actor instance (AppDependencies.transcriptionService): CheckInViewModel chains only on ITS OWN priorTranscription (comment at CheckInViewModel.swift:190-193 assumes the single engine never runs two inferences), PendingTranscriptionServiceImpl serializes only its own drain, and RecordingDetailViewModel.retryTranscription is a third entry. Cross-consumer overlap is real: model lands -> drain starts transcribing a pending recording; user records and stops a new check-in (app active) -> attemptSave calls transcribe -> line 97 cancels the drain's in-flight task. Same preemption in reverse when a foreground drain fires (SquirlApp.swift:127) during a live VM transcription.
- **Why:** If WhisperKit honors the cancellation, the preempted task's catch yields an isError segment -> PendingTranscriptionServiceImpl.transcribe throws -> markFailed marks a perfectly good pending capture 'Transcription failed' (PendingTranscriptionServiceImpl.swift:90,79). If WhisperKit ignores it, two concurrent kit.transcribe calls run on ONE non-actor WhisperKit instance (state corruption risk) and the first finisher's unloadModel() (lines 175/199) nils the shared engine mid-flight — exactly the double-inference the code's own comments forbid on the A14 target.
- **Action:** Serialize inside the actor: never cancel-on-entry. Keep a tail Task and chain each transcribe after the previous one's completion (in-flight task pattern from actors.md); expose cancellation only via the explicit cancelTranscription() API so a deliberate cancel and a new request are distinguishable.
- **Severity:** High

### 3.2 KNOWN ITEM 1 REASSESSED: AudioRecordingServiceImpl has no interruption/pool data race on this target — but its MainActor isolation is implicit, load-bearing, and puts all AVAudioSession work on the main thread
- **Location:** `app-four/Services/Audio/AudioRecordingServiceImpl.swift:5, 66-67, 130, 165, 249; app-four.xcodeproj/project.pbxproj:960`
- **What:** The premise 'main-queue interruption observer races pool-executed async methods' is false on this target: the app target builds with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor (pbxproj lines 960/1000, verified as the squirl-app.app-four configs; enforcement confirmed by the workaround comment in NLNoteExtractor.swift:7-10), so the unannotated class, the AudioRecordingService protocol, its async methods, the .main-queue observer, and the level-poll Task all run on the MainActor — one executor, no race. Residuals: (a) nothing in the file states this; a future nonisolated opt-out, or moving the file to a module without the setting, silently reintroduces the documented race; (b) AVAudioSession.setActive(true/false) (lines 67, 165, 249), prepareToRecord/record, and file deletion now execute synchronously on the main thread during start/stop/finalize/interruption-resume — session (de)activation routinely takes 50-200ms.
- **Why:** Correctness currently hangs on a build setting invisible at the call site, and every capture start/stop injects an audio-session hitch into the UI thread — during finalize this sits inside the background-task window a Lock-Screen stop depends on.
- **Action:** Make the isolation explicit (@MainActor on the class) and add MainActor.assertIsolated() in handleInterruption; then move session activation/deactivation and file IO off the main actor via @concurrent helpers (or convert the service to an actor with a main-queue notification bridge), keeping the handler-emission ordering contract the VM's assumeIsolated relies on (CheckInViewModel.swift:164).
- **Severity:** Medium

### 3.3 Live-capture and pending-drain transcriptions can overlap; the service's self-cancel breaks the never-cancel contract
- **Location:** `app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift:97-98,211; app-four/ViewModels/CheckInViewModel.swift:190-193; app-four/Services/PendingTranscriptionServiceImpl.swift:37-52`
- **What:** CheckInViewModel serializes its own transcriptions and PendingTranscriptionServiceImpl serializes its own drain, but nothing serializes the two pipelines against each other. If a stop finalizes while the foreground drain is mid-inference, the VM's transcribe() call executes `activeTranscriptionTask?.cancel()` on the actor (reentrant across the drain's await), cancelling the drain's in-flight task — and two kit.transcribe inferences can run concurrently until cancellation is observed.
- **Why:** One of the two recordings ends with a spurious 'Transcription failed/cancelled', and two simultaneous Whisper inferences double the peak RAM on a device the code elsewhere treats as jetsam-prone (QA 07-17). Violates the documented single-engine invariant both call sites rely on.
- **Action:** Move serialization into the transcription service itself (queue requests on the actor; drop the transcribe()-side cancel of the previous task, keeping cancelTranscription() as the only cancel path), or gate the drain and the live pipeline on one shared async semaphore.
- **Severity:** Medium

### 3.4 Task.detached breaks cancellation propagation in extraction and export offload; NLSummarizationService's own safety comment is wrong
- **Location:** `app-four/Services/NLSummarizationService.swift:24-29, app-four/Services/ExportService.swift:130-132`
- **What:** runExtraction awaits Task.detached { extractor.extract(...) }.value. Cancelling the caller (ProcessingViewModel.cancelProcessing, or the cancel-then-restart at ProcessingViewModel.swift:34) never cancels the detached task — awaiting .value does not forward cancellation — so the comment 'the extractor checks Task.isCancelled between sentences' (line 23) describes a check that can never fire. Every rapid re-capture leaves a full 1041-line NLNoteExtractor pass running to completion; overlapping passes can stack. ExportServiceImpl.export has the identical shape: the detached AES-GCM seal of up to a 200MB archive is unstoppable once started. Both detached hops exist only because approachable concurrency (NonisolatedNonsendingByDefault) would otherwise run these nonisolated async funcs on the calling MainActor.
- **Why:** Wasted CPU/battery on the A14 floor and an unkillable memory spike during export cancel; the misleading comment invites future regressions.
- **Action:** Replace both Task.detached hops with @concurrent functions (available under SWIFT_APPROACHABLE_CONCURRENCY): off-actor execution WITH structured cancellation, making the extractor's Task.isCancelled checks live. Two-line change per site.
- **Severity:** Medium

### 3.5 MainActor reentrancy in pause/resume anchor bookkeeping: post-await writes trust pre-await state
- **Location:** `app-four/Services/Recording/RecordingSessionControllerImpl.swift:99-101, 104-118`
- **What:** pause() re-checks session identity after await session.pauseCapture() but then writes pausedAt = Date() unconditionally — if a mic-interruption event landed during the suspension, interruptionDidChangeState already stamped an earlier pausedAt, which is overwritten with a later one (pause gap under-counted on resume). resume() binds let pausedAt in its guard BEFORE the await and uses it at line 115 — if an interruption-resume raced in during resumeCapture() and already advanced the anchor and cleared self.pausedAt, resume() advances the anchor a second time, double-subtracting the gap. The classic check-then-act-across-await pattern; both windows need an OS interruption racing a Lock-Screen tap, so they are narrow.
- **Why:** The corrupted anchor is persistent controller state — every subsequent Live Activity update inherits a timer offset by seconds (over- or under-reporting elapsed) with no convergence path until the recording ends.
- **Action:** Re-read self.pausedAt and session.state AFTER each await and no-op if the interruption path already did the bookkeeping (guard self.pausedAt == nil in pause(); guard let pausedAt = self.pausedAt post-await in resume()).
- **Severity:** Low

### 3.6 Single-scalar finalizeAssertion lets overlapping finalizes release each other's background assertion
- **Location:** `app-four/ViewModels/CheckInViewModel.swift:596-614, 199, 214`
- **What:** `beginFinalizeAssertion` first ends any live prior assertion (comment at 599-603 acknowledges the back-to-back window). If finalize #2 begins during finalize #1's `recordingDidFinish → activity.end` await, #2 ends id#1 and stores id#2; when Task #1 resumes, its `endFinalizeAssertion()` sees id#2 ≠ .invalid and ends it — finalize #2 then runs its audio-stop/save with no background assertion. Requires stopping capture #2 inside capture #1's sub-second end window, so effectively unreachable by a human today, but the scalar makes the invariant depend on timing rather than structure.
- **Why:** If the unprotected finalize coincides with a lock/background transition, iOS can suspend mid-save — the exact truncated-capture failure D9 exists to prevent. Latent, timing-dependent, zero-cost to fix structurally.
- **Action:** Make the assertion per-finalize: capture the `UIBackgroundTaskIdentifier` as a local in `stopRecording()`'s Task and end that specific id in the defer/expiration handler, instead of sharing one stored scalar.
- **Severity:** Low

### 3.7 pause()/resume() post-await re-check is identity-only, not state — transient 'Paused' surface can be pushed over a finalizing capture
- **Location:** `app-four/Services/Recording/RecordingSessionControllerImpl.swift:96-101, 110-117`
- **What:** After `await session.pauseCapture()` the guard re-checks `self.session === session` but not `session.state`. If the cap auto-stop (or an in-app stop) flips the VM to `.processing` during the await, `pauseCapture` no-ops on its own guard, yet the controller still stamps `pausedAt = Date()` and pushes a `.paused` LA update while the finalize is mid-save; the surface shows 'Paused' until `recordingDidFinish → end()` clears it seconds later. `resume()` has the mirror-image gap. `session` is only nil'd at the end of the finalize Task, so the identity check passes throughout the window.
- **Why:** Self-correcting and MainActor-serialized, so no corruption — but it is a genuine surface-contradicts-capture window on the exact code paths (Lock-Screen controls racing cap auto-stop) the spec's guards exist for.
- **Action:** Extend both post-await guards to also require the expected state: `guard self.session === session, session.state == .paused` (pause) / `== .recording` (resume) before stamping pausedAt/anchor and updating the surface.
- **Severity:** Low

## 4. API modernity

### 4.1 RootTabView uses deprecated tabItem instead of the Tab API
- **Location:** `app-four/Views/RootTabView.swift:19-35`
- **What:** TabView(selection:) with four .tabItem { Label(…) }.tag(Tab.x) blocks; the iOS 26 target has the Tab("Calendar", systemImage:, value:) API (iOS 18+), which the swiftui-pro skill mandates over tabItem().
- **Why:** tabItem is the legacy path — the Tab API gets correct selection typing, sidebar-adaptable behavior, and future Liquid Glass tab treatments for free.
- **Action:** Rewrite as TabView(selection: $selectedTab) { Tab("Calendar", systemImage: Icons.calendar, value: .calendar) { CalendarLibraryView(…) } … } (≤20 min).
- **Severity:** Low

## 5. Bugs / logic errors

### 5.1 Retry-transcription path mutates a possibly-deleted @Model — missing the store.exists guards the main pipeline has
- **Location:** `app-four/ViewModels/RecordingDetailViewModel.swift:77-130`
- **What:** retryTranscription()'s stream consumer (consumeTranscription, lines 108-130) and finishFailed (102-106) set recording.fullTranscriptText/status and call store.save() with zero store.exists(recording.id) checks. CheckInViewModel.transcribeInBackground guards every equivalent mutation (CheckInViewModel.swift:293, 316, 324, 337, 360) precisely because QA 07-18 hit the deleted-@Model trap. The retry task also captures self strongly, so deinit's retryTask?.cancel() never runs while streaming.
- **Why:** User opens a failed recording, taps 'Retry transcription' (up to 90 s of streaming), then taps Delete → confirm → dismiss; pendingDelete fires viewModel.delete() on onDisappear (RecordingDetailView.swift:74) while the retry stream is still writing segments. Mutating the freed Recording traps in SwiftData ('BackingData detached without resolving faults') — the exact crash class the pendingDelete pattern exists to prevent.
- **Action:** Mirror the main pipeline: guard store.exists(recording.id) before every mutation/save in consumeTranscription, finishFailed, and the post-stream completion; cancel retryTask from delete().
- **Severity:** Critical (upgraded from High by verification)

### 5.2 Debug 'Delete All' permanently destroys all real recordings with no confirmation; 'Done' button is a no-op (reachable in TestFlight)
- **Location:** `app-four/Views/TestServicesView.swift:101-107,153-157, app-four/Views/SettingsView.swift:269-271`
- **What:** TestServicesView is reachable in DEBUG || TESTFLIGHT via the 5-tap version gesture. 'Delete All' iterates the unfiltered @Query (all recordings, mock AND real) and deletes rows + audio files instantly — no confirmationDialog, no destructive role. The toolbar 'Done' button has an empty action ('Close sheet action would go here'), so the sheet can only be swiped away.
- **Why:** A TestFlight tester exploring the hidden panel is one tap from irreversibly losing their entire journal and audio — data loss on a shipped build channel. The dead Done button is a broken control on the same surface.
- **Action:** Filter 'Delete All' to isMockData (or gate real-data deletion behind a confirmationDialog with role: .destructive), and wire Done to @Environment(\.dismiss).
- **Severity:** High

### 5.3 Drain loop lacks every environmental guard the VM path has: no timeout, no backgrounded re-queue, isDraining wedges forever on a hung inference
- **Location:** `app-four/Services/PendingTranscriptionServiceImpl.swift:37-52, 67-96`
- **What:** CheckInViewModel's transcription path has a 90 s timeout (CheckInViewModel.swift:287) and re-queues `.pendingTranscription` instead of `.failed` when the app is not active (lines 328-333). The drain path has neither: `transcribe(audioURL:id:)` consumes the stream with no timeout, the loop re-checks only model presence between items (line 49) — never `applicationState` — and errors always `markFailed` (line 79).
- **Why:** Scenario: foreground kicks a 3-item drain; user locks after 5 s. Inference continues into the background where GPU work is aborted (the exact QA 07-18 kIOGPUCommandBuffer flood the VM gate was added for). If the stream hangs, `drainIfModelReady` never returns, the `defer` never resets `isDraining` (line 41), and every future drain no-ops for the process lifetime — the pending queue is silently dead until relaunch. If it errors instead, an environmental failure permanently stamps `.failed` on a capture the VM path would have re-queued.
- **Action:** Between items, re-check an isAppActive seam and return early (items stay `.pendingTranscription` and the next foreground drain resumes). Wrap the stream in the same 90 s timeout. In the catch, re-queue `.pendingTranscription` when backgrounded, mirroring CheckInViewModel.swift:328-333.
- **Severity:** High

### 5.4 Medication bar's time model is frozen at refresh() — progress, state word, onset pulse, and visibility go stale on screen
- **Location:** `app-four/ViewModels/MedicationBarViewModel.swift:59-109, app-four/Views/Components/MedicationBarView.swift:47,88-95,162-188`
- **What:** DoseDisplay.progress/endsAt/activeDoses are computed once in refresh(now:), which is only called from the bar's onAppear and the .medicationEventsDidChange notification. There is no TimelineView, timer, or scenePhase hook. DoseTrack's onset pulse derives onsetPulsing from this frozen progress, so the .repeatForever pulse latches on past the real onset window.
- **Why:** Background the app overnight (or just stay on one tab): on return the bar still shows yesterday's dose as 'active' with a frozen fill — foregrounding does not fire onAppear and nothing re-computes now-relative state. For a medication-status surface aimed at ADHD users, a wrong 'kicking in / active / wearing off' reading is a real correctness failure, and a worn-off dose never leaves the bar.
- **Action:** Drive the bar from a clock: wrap rows in TimelineView(.periodic(from:by: 60)) computing progress from takenAt/durationHours at render time (or refresh on a 1-min task + scenePhase.active), and derive activeDoses emptiness from the same clock.
- **Severity:** High

### 5.5 WhisperKit's beginBackgroundTask has no expiration handler — backgrounding mid-transcription is a guaranteed watchdog kill
- **Location:** `app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift:145-152`
- **What:** `beginBackgroundTask(withName: "WhisperTranscription")` is taken with a nil expiration handler and ended only via `defer` when the transcribe Task body exits. If the assertion expires before the inference completes, nothing calls `endBackgroundTask` at expiry — the system terminates the app (0xbada5e47-class assertion-timeout kill).
- **Why:** In Release, ComputeEnvironment selects `.cpuAndNeuralEngine` (ComputeEnvironment.swift:38) and ANE inference continues in the background — an 8-minute clip on whisper-small (A14) runs well past the ~30 s assertion budget, so a user who backgrounds mid-transcription gets the app killed. On the GPU path the inference is aborted instead and can hang the task body forever, so the `defer` never runs and the same expiry kill fires. `RecordingStore.recoverOrphanedTranscriptions` (RecordingStore.swift:25-37) sweeps the stuck `.transcribing` row to `.failed` at next launch, so no data is lost — which is why this is High, not Critical — but the kill is real and degrades the app's background-scheduling reputation.
- **Action:** Pass an expiration handler that idempotently ends the task and calls `cancelTranscription()` (mirror the checkin-finalize pattern in CheckInViewModel.swift:598-614: guard on `.invalid`, end on both paths). Store the id in the actor so the handler and the defer cannot double-end.
- **Severity:** High

### 5.6 22 silent `try? save()` sites across the persistence layer swallow SwiftData write failures
- **Location:** `app-four/Store/RecordingStore.swift:35,75,82,87,96,102; app-four/Services/AIModelServiceImpl.swift:26,41,50,98; app-four/Services/DoseLog/DoseLogServiceImpl.swift:76 (+11 more; grep 'try? modelContext.save\|try? context.save')`
- **What:** Every store mutation except RecordingStore.persistCheckInNote and DoseLogServiceImpl.logDefaultDose discards the save error. addRecording — the post-capture persistence of a voice note — is `try? modelContext.save()` even though the surrounding capture flow (FR-005) was built specifically to never silently lose a capture.
- **Why:** A save failure (disk-full is realistic in an audio app) silently drops a health entry, a favorite toggle, or a status transition while the UI reports success — the exact failure class specs 030/037 spent effort eliminating on other paths.
- **Action:** Make RecordingStore.addRecording/save throwing (the retry surface in CheckInViewModel.attemptSave already exists to consume it), and at minimum log-and-surface the remaining sites. The persistCheckInNote pattern is the in-repo template.
- **Severity:** Medium

### 5.7 Back-to-back check-ins cancel the prior extraction, wedging the first recording at summaryStatus=.generating forever
- **Location:** `app-four/ViewModels/ProcessingViewModel.swift:34,68,82; app-four/Store/RecordingStore.swift:25-37`
- **What:** processRawTranscription unconditionally cancels activeTask. run() has already persisted summaryStatus=.generating (line 68); after the cancelled summarize the `guard !Task.isCancelled else { return }` (line 82) exits without writing .failed or .completed. Nothing ever recovers it: the launch sweep (RecordingStore.recoverOrphanedTranscriptions) recovers only status==.transcribing, not summaryStatus==.generating — an app kill mid-extraction strands the same state.
- **Why:** User records two check-ins in quick succession (or the app dies during extraction): the first note shows a permanent 'generating' summary state with no retry affordance — a real, user-hittable stuck state in the core capture flow.
- **Action:** On the cancelled path, persist summaryStatus=.failed (mirroring the error branch) before returning; extend the launch recovery sweep to also reset summaryStatus==.generating rows. Consider serializing extraction like transcription instead of cancelling.
- **Severity:** Medium (demoted from High by verification)

### 5.8 Cap boundary mismatch: wall-clock Live Activity timer + staleDate vs tick-accumulated in-app cap (known item 2 — confirmed on the LA surface)
- **Location:** `app-four/ViewModels/CheckInViewModel.swift:541-557, SquirlWidgets/SquirlWidgetsLiveActivity.swift:104-110, app-four/Services/LiveActivity/LiveActivityControllerImpl.swift:30,53`
- **What:** The LA timer is wall-clock anchored (`Text(timerInterval: anchor...anchor+cap)`) and staleDate is set to exactly `anchor+cap`. The in-app cap is enforced by accumulating 0.1s ticks (`elapsedTime += 0.1` after `Task.sleep(0.1s)`), which lags wall clock by scheduling overhead — over an 8-min capture, seconds of drift, more when locked (background QoS stretches sleeps). At the cap the Lock-Screen card freezes at 8:00 AND dims to 50% (isStale) while the mic is still recording until the lagging tick loop fires `stopRecording()`; the capture also overshoots the advertised cap by the drift. Even with zero drift, staleDate==cap dims the card during the stop→save finalize window before `end()` clears it.
- **Why:** The surface visibly asserts staleness over an actively recording mic — exactly the FR-008 'surface never contradicts the capture' contract this feature is built around — and every capped recording hits it. Also relevant when the user pauses after the visual cap: `pauseTime` then sits past the range's upper bound (clamped, but untested).
- **Action:** Drive the in-app cap from the same pause-adjusted wall-clock anchor the controller keeps (compute elapsed = now − anchor each tick; schedule the cap stop as a deadline, not a tick count), and add a small grace to staleDate (e.g. cap + 10-15s) to cover the finalize window.
- **Severity:** Medium

### 5.9 Check-in trigger observer misses armed-before-attach and permanently wedges the one-shot latch
- **Location:** `app-four/App/SquirlApp.swift:63-67, app-four/Intents/AppIntentRouter.swift:41-52`
- **What:** `.onChange(of: router.shouldStartCheckIn)` has no `initial: true`, unlike the parallel medication observer at SquirlApp.swift:73 whose comment explicitly documents this exact race ("either side of this body attaching"). If StartCheckInIntent.perform() arms the trigger before the WindowGroup body attaches (headless process resumed by a prior background dose/Live-Activity launch, then foregrounded by the check-in intent), the observer's baseline reads `true` and never fires. Because the latch is Bool and `onChange` is equality-gated, every later `requestCheckIn()` is a true→true non-change: the deep link and all subsequent Siri check-ins go dead for the process lifetime — nothing else calls `consumeCheckIn()`.
- **Why:** Siri "Check in on Squirl" silently opens the app without starting recording (FR-013 broken) and the failure is sticky, not transient — the feature stays wedged until the process dies.
- **Action:** Add `initial: true` to the shouldStartCheckIn onChange, mirroring line 73. The existing `guard armed, router.consumeCheckIn()` already makes the initial fire idempotent, and CheckInView.consumeAutoStart (CheckInView.swift:68-76) safely absorbs the downstream flag.
- **Severity:** Medium (demoted from High by verification)

### 5.10 Elapsed timer accumulates 0.1 s ticks — drifts behind wall clock, cap fires late, diverges from the wall-clock Live Activity
- **Location:** `app-four/ViewModels/CheckInViewModel.swift:541-557, app-four/Services/Recording/RecordingSessionControllerImpl.swift:25-26, 41`
- **What:** Known open item 2, formally confirmed. `startTimer()` does `Task.sleep(100ms)` then `elapsedTime += 0.1`; sleep-overshoot and main-actor scheduling latency are never reconciled, so elapsedTime runs slow relative to wall time — seconds of lag over the 480 s cap. Meanwhile RecordingSessionControllerImpl mirrors a wall-clock anchor to the Live Activity, and LiveActivityControllerImpl arms `staleDate = startedAt + cap` (LiveActivityControllerImpl.swift:30, 53) — two clocks for one capture.
- **Why:** Near the cap the Lock-Screen countdown reaches 0 and the surface goes stale/dims while the app is still recording for several more seconds before its lagging `elapsedTime >= maxDuration` check fires — visible inconsistency on the exact flagship 037 surface, plus the recorded file exceeds the 8:00 contract and prompt cadence (`currentPromptIndex`) drifts.
- **Action:** Derive elapsed from a pause-adjusted anchor Date — the identical model RecordingSessionControllerImpl already maintains (`anchor`/`pausedAt`) — and keep the 0.1 s tick purely as a display-refresh trigger. The controller's anchor could be exposed so both surfaces share one clock.
- **Severity:** Medium

### 5.11 Elapsed timer accumulates fixed 0.1s ticks — drifts behind wall clock, cap fires late, disagrees with Live Activity (known item 2 — confirmed)
- **Location:** `app-four/ViewModels/CheckInViewModel.swift:541-557`
- **What:** startTimer sleeps 100ms then does elapsedTime += 0.1, ignoring sleep overshoot and scheduling latency, so elapsedTime lags real time cumulatively (~1-3% typical). The 8-minute cap check (line 551) and the approach-cue window key off this drifting value, while the Live Activity timer is wall-clock anchored via the pause-adjusted anchor in RecordingSessionControllerImpl.
- **Why:** The recording runs seconds past the advertised 480s cap, the Lock-Screen timer and the in-app timer visibly diverge on long captures, and the stored duration (computed separately by the audio service from Date diffs) disagrees with what the user watched.
- **Action:** Derive elapsedTime from a pause-adjusted anchor Date on each tick (elapsed = accumulated + Date().timeIntervalSince(resumeAnchor)) — same pattern RecordingSessionControllerImpl already uses — keeping the 0.1s tick purely as a refresh cadence.
- **Severity:** Medium

### 5.12 Issue-report sheet attaches placeholder sensitive data and mails a stale-brand recipient
- **Location:** `app-four/Views/Feedback/IssueReportView.swift:192-213,58-59`
- **What:** When the user opts in via the 'Include Transcription/Summary/Audio' toggles, reportAttachments appends literal placeholder strings ('[Transcription text would be inserted…]') and an empty audio.m4a, while composedBody's '--- Attachments ---' section claims they are present. The mail goes to support@whisperhealth.app with subject 'WhisperHealth Beta Feedback' — the pre-rename app identity.
- **Why:** Beta feedback silently loses exactly the data the tester consented to share, making bug reports undebuggable, and the report likely lands in a mailbox for a brand that no longer matches the app (Squirl).
- **Action:** Populate the attachments from the current/most-recent Recording (transcript text, summary, audio file data) or remove the toggles until wired; update recipient/subject to the Squirl identity.
- **Severity:** Medium

### 5.13 KNOWN ITEM 2 CONFIRMED: 0.1s tick-accumulated elapsedTime drifts behind wall clock; cap and approach cue fire late; diverges from the wall-anchored Live Activity timer
- **Location:** `app-four/ViewModels/CheckInViewModel.swift:541-557, SquirlWidgets/SquirlWidgetsLiveActivity.swift:104-110, app-four/Services/Recording/RecordingSessionControllerImpl.swift:25-26`
- **What:** startTimer() loops Task.sleep(nanoseconds: 100_000_000) then advanceTick() adds a fixed 0.1s. Task.sleep guarantees AT LEAST the duration; per-tick scheduling overhead makes each iteration >100ms, so elapsedTime undercounts wall time by roughly 1-3% (approx. 5-15s over the 480s cap on device). Spec 037 made this user-visible: the Lock Screen timer is Text(timerInterval:) anchored to the wall-clock startedAt (pause-adjusted by the controller), so the two clocks are guaranteed to diverge — the Live Activity freezes at 8:00 (its range ends at startedAt+cap and staleDate dims it) seconds before the in-app cap auto-stop (line 551-553) fires. isApproachingCap (line 26) and the prompt-index epsilon hack (line 482-484, which papers over the same float accumulation) inherit the drift.
- **Why:** Mechanism of the known item confirmed with a sharper consequence than 'cap fires late': the 037 Lock Screen surface shows a dimmed, frozen 8:00 'Recording' card while the app is still capturing, and the recorded duration exceeds the displayed cap by the drift.
- **Action:** Derive elapsedTime from a ContinuousClock.Instant (or Date) anchor plus an accumulated-pause offset — the exact bookkeeping RecordingSessionControllerImpl already does for the Live Activity (anchor/pausedAt) — and keep the 0.1s task purely as a display-refresh tick. Cap check becomes anchor-based and lands on wall time; drop the 1e-6 epsilon.
- **Severity:** Medium

### 5.14 KNOWN ITEM 3 ASSESSED: pipeline migration verified complete, but clearAllData() still deletes through the mock-filtered array — 'delete all user content' silently retains real captures
- **Location:** `app-four/ViewModels/SettingsViewModel.swift:221, 31; verified-migrated: app-four/ViewModels/CheckInViewModel.swift:293, app-four/Services/PendingTranscriptionServiceImpl.swift:60, app-four/ViewModels/ProcessingViewModel.swift:52-58`
- **What:** Formal closure of the DEBUG debugMockMode item: all background pipelines now resolve context-grounded (CheckInViewModel via store.exists, pending drain via store.pendingTranscriptionIDs, ProcessingViewModel via direct context fetch) — confirmed at the cited lines. One mutating consumer was missed: SettingsViewModel.clearAllData() iterates store.recordings (line 221), which RecordingStore filters by isMockData == mockMode (RecordingStore.swift:41-44). With the DEBUG-registered debugMockMode=true (SquirlApp.swift:19), 'Permanently deletes all user content' deletes only mock rows; real captures recorded in mock-dev mode survive as invisible SwiftData rows plus audio files on disk. recordingCount (line 31) reports the same filtered count.
- **Why:** A user-invoked full-wipe that leaves undeleted voice-journal audio on disk is a data-retention/privacy defect — dev-mode-weighted today, but any mock rows carried onto a release build flip the same hole the other way.
- **Action:** Delete via a context-grounded fetch (mirror RecordingStore.pendingTranscriptionIDs: fetch ALL recordings, no mock predicate) and base recordingCount on the same; keep store.recordings strictly a UI projection.
- **Severity:** Medium

### 5.15 Known item (formal): CheckInViewModel elapsed timer accumulates 0.1 s ticks — drifts vs wall clock, 8-min cap fires late
- **Location:** `app-four/ViewModels/CheckInViewModel.swift:541-557`
- **What:** startTimer() loops `Task.sleep(nanoseconds: 100ms)` then `elapsedTime += 0.1`. Task.sleep only guarantees ≥ the interval, so per-tick overshoot (scheduler jitter, Low Power Mode throttling) compounds: over 8 minutes (4 800 ticks) the accumulated value lags real time by seconds. The cap auto-stop (line 551) and the prompt-advance windows (currentPromptIndex/promptProgress, 480-491) inherit the drift; the recorder keeps rolling until stopRecording, so the audio file exceeds the displayed duration.
- **Why:** The displayed timer, the VoiceOver 'elapsed' announcements, the FR-014 approach cue, and the hard cap all fire late relative to the actual recording — the one number the capture screen exists to show is wrong by an unbounded (accumulating) margin.
- **Action:** Anchor to a monotonic clock: store a ContinuousClock.Instant (plus accumulated pause intervals) at start/resume and compute elapsedTime = now - anchor on each tick; keep the 0.1 s wake cadence purely as a redraw trigger.
- **Severity:** Medium

### 5.16 Only interruptions are observed — route change, media-services reset, and encoder errors leave a dead recorder with the timer and Live Activity still counting
- **Location:** `app-four/Services/Audio/AudioRecordingServiceImpl.swift:74, 168-183`
- **What:** The service observes `AVAudioSession.interruptionNotification` only. No `routeChangeNotification` (BT mic walks out of range / unplugged — `.oldDeviceUnavailable` on the input side), no `mediaServicesWereResetNotification` (mediaserverd crash invalidates recorder and session), and the `AVAudioRecorderDelegate` is assigned (line 74) but implements neither `audioRecorderEncodeErrorDidOccur` nor `audioRecorderDidFinishRecording(successfully: false)`.
- **Why:** Each of these kills or degrades capture with no signal into the 037 state machine: `isRecording` stays true, `elapsedTime` keeps ticking, the Live Activity keeps showing 'Recording' over a dead mic — the exact defect class QA 07-17 fixed for interruptions, still open for these three triggers. A media-services reset mid-check-in silently loses everything after the reset point.
- **Action:** Observe both notifications and implement the two delegate methods; funnel all of them into the existing `RecordingInterruption` handler (`.paused`/`.endedWithoutResume`) so the VM freeze + Live Activity sync logic is reused unchanged. On media-services reset, rebuild the recorder before allowing resume.
- **Severity:** Medium

### 5.17 Pending drain has no transcription timeout — a hung inference wedges the queue for the process lifetime
- **Location:** `app-four/Services/PendingTranscriptionServiceImpl.swift:86-96,37-52; contrast app-four/ViewModels/CheckInViewModel.swift:287`
- **What:** The live-capture path guards stream consumption with a 90s timeout (consumeStreamWithTimeout); drain's transcribe() awaits the AsyncStream unboundedly. If WhisperKit stalls (the exact GPU-abort scenario QA 07-18 hit), drainIfModelReady never returns, so `defer { isDraining = false }` never runs and every later launch/foreground drain call no-ops.
- **Why:** One stalled inference permanently freezes the pending queue until the app is killed; the affected recording sits at .transcribing and all queued captures behind it never drain — silent, unrecoverable within the session.
- **Action:** Reuse the timeout-race pattern from CheckInViewModel.consumeStreamWithTimeout inside drain (timeout → requeue as .pendingTranscription and continue with the next id).
- **Severity:** Medium

### 5.18 applySummary keeps stale side-effects/emotions/topics/sleep JSON when a regenerate finds none
- **Location:** `app-four/Models/Recording.swift:259-281 (contradicting comment at 235-237)`
- **What:** sideEffectsJSON, emotionsJSON, topicTagsJSON and sleepEventJSON are only assigned when the new result is non-empty (`if !result.sideEffects.isEmpty …`), so a reprocess whose extraction finds none silently retains the previous values — despite the adjacent comment claiming these blocks 'always reflect the latest extraction'.
- **Why:** After editing a transcript to remove a side-effect or emotion mention and regenerating, the removed health signals persist in the UI, in Insights aggregation, and in the encrypted export — stale medical data presented as current.
- **Action:** Assign unconditionally on the non-fillOnly path (nil/empty when the result is empty), keeping conditional writes only for fillOnly gap-filling.
- **Severity:** Medium

### 5.19 resumeRecording() never reactivates the audio session — Live Activity Resume fails after any system deactivation
- **Location:** `app-four/Services/Audio/AudioRecordingServiceImpl.swift:107-116, 246-260`
- **What:** `resumeFromInterruption()` correctly calls `setActive(true)` before `recorder.record()` (line 249), but the user-driven `resumeRecording()` (lines 107-116) — the only path behind ResumeRecordingIntent → RecordingSessionControllerImpl.resume() → resumeCapture() — calls `record()` with no session reactivation. There is no in-app pause/resume UI (no Views call pauseCapture/resumeCapture), so the Live Activity button is the sole user resume path.
- **Why:** Failure scenario: user pauses from the Live Activity (isRecording→false), a call or Siri arrives — `interruptionResponse(.began, isRecording:false)` returns `.ignore` (line 202), so `wasInterrupted` never sets and the system's deactivation of our session goes unrecorded; `.ended` is likewise ignored (line 204). User taps Resume on the Lock Screen → `record()` on an inactive session returns false → `RecordingError.hardwareFailure` thrown → the intent rethrows into ActivityKit and the capture is wedged `.paused` with no recovery surface except Stop. Same failure after paused-then-locked suspension where the system reclaims the idle session. Covers the audit question 'recording survives lock in all states': recording-then-locked survives (active session + audio mode); paused-then-locked does not reliably resume.
- **Action:** Mirror the interruption path: `try AVAudioSession.sharedInstance().setActive(true)` in `resumeRecording()` before `record()`. Additionally, in RecordingSessionControllerImpl.resume(), catch the throw and push a `.paused` (or failed) Live Activity update instead of letting the intent rethrow silently.
- **Severity:** Medium (demoted from High by verification)

### 5.20 startRecording failure path leaks an activated non-mixable playAndRecord session
- **Location:** `app-four/Services/Audio/AudioRecordingServiceImpl.swift:65-79, app-four/ViewModels/CheckInViewModel.swift:173-175`
- **What:** `setActive(true)` (line 67) precedes AVAudioRecorder creation and `prepareToRecord()/record()`; if any of those fail the method throws (line 78) without deactivating. The VM's catch only logs. The category is non-mixable `.playAndRecord`, so activation interrupted every other app's audio.
- **Why:** A transient hardware failure (mic held by a call in another app → `AVAudioSessionErrorInsufficientPriority` on activate is handled by the throw, but a post-activate recorder failure is not) leaves the user's Music/podcast silenced indefinitely with the app showing an idle check-in screen and no error — a courtesy violation the skill flags explicitly (deactivating with `.notifyOthersOnDeactivation` exists only in `cleanup()`, line 165, which this path never reaches).
- **Action:** In the catch/guard-fail path of `startRecording()`, call `try? session.setActive(false, options: .notifyOthersOnDeactivation)` and nil the recorder before rethrowing. Consider surfacing the failure in the VM instead of only logging.
- **Severity:** Medium

### 5.21 DEBUG mock mode: dose-guard reads real doses while the medication bar shows mock doses
- **Location:** `app-four/Services/DoseLog/DoseLogServiceImpl.swift:82-89; app-four/ViewModels/MedicationBarViewModel.swift:61-63; app-four/App/SquirlApp.swift:13-21`
- **What:** Known item 3 assessment: the context-grounded migration is correctly in place (RecordingStore.resolve/exists/pendingTranscriptionIDs at RecordingStore.swift:58-71, consumed by CheckInViewModel:293,316,324 and PendingTranscriptionServiceImpl throughout) — no remaining background pipeline reads the filtered array. Residual inconsistency: mostRecentDose pins isMockData==false while the bar/library filter isMockData==mockMode, so in DEBUG mock mode the double-dose guard evaluates doses the UI hides and ignores the ones it shows.
- **Why:** Debug-only, but it makes dose-guard QA misleading: the guard blocks/passes against invisible history, which is exactly how the 07-18 class of mock-filter bugs went unnoticed. Release behavior is correct (key unregistered → false).
- **Action:** Have mostRecentDose use the same debugMockMode-driven predicate as MedicationBarViewModel so guard decisions match what the tester sees.
- **Severity:** Low

### 5.22 DEBUG mock-mode split-brain: Siri-logged dose is invisible in-app and visible mock doses never arm the guard
- **Location:** `app-four/Services/DoseLog/DoseLogServiceImpl.swift:84, app-four/ViewModels/MedicationBarViewModel.swift:61-63, app-four/App/SquirlApp.swift:18-20`
- **What:** Formal assessment of known open item 3 at this lens: DEBUG registers `debugMockMode=true`, and MedicationBarViewModel filters events by `isMockData == mockMode`. LogDefaultDoseIntent writes a real event (`MedicationEvent.isMockData` defaults false, Models/MedicationEvent.swift:25) and the guard correctly reads only real doses (`isMockData == false`, context-grounded — the 037 migration is applied here). Result in a Debug build: a Siri-logged dose never appears in the medication bar, while the mock doses the developer sees never trigger the double-dose guard.
- **Why:** Debug-only, but it directly sabotages the mandated on-device QA of US1 (owner QA happens on Debug builds): "logged" confirmations with no visible effect will be filed as bugs, and guard behavior cannot be exercised against visible data.
- **Action:** For US1 device QA, flip mock mode off (TestServices) before testing the dose intent; longer term, make MedicationEvent surfaces ignore the mock filter for intent-written events or exclude MedicationEvent from mock-mode filtering entirely.
- **Severity:** Low

### 5.23 Intent dialog copy bypasses LocalizedStringResource entirely
- **Location:** `app-four/Intents/DoseConfirmationCopy.swift:8-20, app-four/Intents/LogDefaultDoseIntent.swift:28-29`
- **What:** DoseConfirmationCopy returns plain `String`s that are interpolated into `IntentDialog` as verbatim values — they never enter a String Catalog and can't use Foundation grammar agreement/inflection. Intent titles/descriptions correctly use LocalizedStringResource; only the runtime dialog path is opaque to localization.
- **Why:** Acceptable while the app ships English-only, but this is the one intents-layer surface that would need rework for any localization pass, and Siri speaks these strings aloud.
- **Action:** No action required now; when localization lands, convert `DoseConfirmationCopy.text` to return `LocalizedStringResource`/`AttributedString(localized:)` and interpolate structured values (time via `Date.FormatStyle`) instead of pre-baked strings.
- **Severity:** Low

### 5.24 Mock-mode migration (known item 3) verified resolved for background pipelines; one residual UI-side consumer: clearAllData deletes through the mock-filtered array
- **Location:** `app-four/ViewModels/SettingsViewModel.swift:221, app-four/Store/RecordingStore.swift:58-71`
- **What:** Formal assessment of known open item 3: the background pipelines are correctly context-grounded on this branch — `store.resolve/exists` (RecordingStore.swift:58-64) and `pendingTranscriptionIDs` (67-71) bypass the `isMockData` filter, and CheckInViewModel (293, 316, 324) plus PendingTranscriptionServiceImpl (99-143) use only those. Residual: `SettingsViewModel.clearAllData` iterates `Array(store.recordings)` — the mock-filtered array.
- **Why:** In DEBUG mock-dev mode (debugMockMode registered true, SquirlApp.swift:19), 'delete all data' removes only mock rows and leaves real captures' rows and audio files on disk — the doc comment promises 'every recording'. Release is unaffected (filter selects real rows), hence Low.
- **Action:** Fetch unfiltered in clearAllData (a context `FetchDescriptor<Recording>()` like `recoverOrphanedTranscriptions` uses) instead of `store.recordings`.
- **Severity:** Low

### 5.25 ResumeRecordingIntent failure is completely silent — thrown error has no surface on a widget-button invocation
- **Location:** `SquirlLiveActivity/Sources/SquirlLiveActivity/RecordingControlIntents.swift:61-65, app-four/Services/Recording/RecordingSessionControllerImpl.swift:104-118`
- **What:** `ResumeRecordingIntent.perform()` propagates `session.resumeCapture()` errors (e.g. AVAudioSession reactivation failing from the background). For a Live-Activity `Button(intent:)` the system swallows the thrown error: no dialog, no haptic, no log. The Live Activity correctly stays "Paused" (truthful), but the user's tap does nothing with zero feedback and nothing is written to AppLogger for diagnosis.
- **Why:** Lock-Screen resume while backgrounded is precisely the environment where audio-session reactivation is most likely to fail; a silent no-op button is indistinguishable from the "dead buttons" class already hit in QA 07-17.
- **Action:** Catch in perform(): log via AppLogger and refresh the activity content (re-push the paused state) so at minimum the failure is diagnosable; optionally mark the activity stale to hint at opening the app.
- **Severity:** Low

### 5.26 Save-failure retry buffer lives in memory + tmp only — process death or tmp purge loses the capture
- **Location:** `app-four/ViewModels/CheckInViewModel.swift:41-47, 202-205, app-four/Services/Audio/AudioRecordingServiceImpl.swift:69-71`
- **What:** US2's 'never lose a capture' buffer (`PendingSave`) holds a URL into `FileManager.temporaryDirectory` and exists only in the VM instance. On a save failure the state machine parks in `.processing` with the in-session retry surface; if the app is then killed (or expires during a locked finalize) the reference is gone, and the audio sits in tmp where iOS may purge it.
- **Why:** The one flow explicitly designed for durability has a window where the only copy of the user's audio is an unreferenced tmp file — save-failure plus process death equals silent capture loss, contradicting FR-005's intent.
- **Action:** Record into (or move the buffered file to) an app-support 'orphans' directory and sweep it at launch: any orphaned audio file without a Recording row becomes a `.pendingTranscription` recording. Cheap and closes the last data-loss window.
- **Severity:** Low

### 5.27 debugMockMode residual (known item 3 — LA-lens exposure closed; DEBUG-only visibility gap remains)
- **Location:** `app-four/App/SquirlApp.swift:17-21, app-four/ViewModels/CheckInViewModel.swift:293,316,324`
- **What:** Formal assessment: the background/Live-Activity finalize pipeline no longer consults the mock-filtered `store.recordings` array — deletion checks are context-grounded via `store.exists(recording.id)` (lines 293, 316, 324; commit e342488c), so a Lock-Screen stop in a DEBUG build can no longer drop transcripts of real captures. Residual: DEBUG registers `debugMockMode=true` at launch (SquirlApp.swift:18-20), so a real capture saved via `attemptSave → store.addRecording` while mock mode is on persists but is hidden from mock-filtered UI surfaces until the toggle is flipped — an owner-confusion hazard during device QA of 037, not a shipping bug (key never registers in Release).
- **Why:** Device QA of the Lock-Screen stop path is mandatory before merge (repo rule); a QA capture that 'vanishes' behind the mock filter would read as a lost capture and burn a QA cycle.
- **Action:** No code change required for release correctness. Optionally have the capture flow (or TestServices) surface a banner when a real capture is saved while debugMockMode is on, or auto-disable mock mode on first real capture in DEBUG.
- **Severity:** Low

## 6. Security & privacy

### 6.1 Documents dir with health audio + plaintext transcript exports exposed via Files app / Finder file sharing
- **Location:** `app-four.xcodeproj/project.pbxproj:738,743 (and Release dupes 778,783), app-four/Services/Audio/AudioFileStorageServiceImpl.swift:74-103`
- **What:** INFOPLIST_KEY_UIFileSharingEnabled=YES + LSSupportsOpeningDocumentsInPlace=YES expose the entire Documents directory (Recordings/*.m4a health audio, Exports/*.json) in the Files app and Finder. exportTranscript writes the full transcript as plaintext JSON into Documents/Exports and nothing ever deletes those files.
- **Why:** Anyone with the unlocked phone or a paired computer can browse raw mood/medication transcripts and audio. This directly contradicts ExportService's design intent ('plaintext never leaving the device sandbox' via AES-GCM) — the unencrypted copies sit in a world-browsable folder.
- **Action:** Set both file-sharing keys to NO (exportTranscript is only reachable from TestServicesView, so the user-facing loss is nil). If sharing must stay, move Recordings/Exports to Application Support and delete each export file after the share sheet completes.
- **Severity:** High

### 6.2 User-deleted check-ins leave health audio recordings on disk forever
- **Location:** `app-four/Store/RecordingStore.swift:79-84, app-four/ViewModels/MoodLibraryViewModel.swift:147-149, app-four/ViewModels/RecordingDetailViewModel.swift:30-32`
- **What:** Both user-facing delete paths (library swipe/multi-select and detail-view delete) call RecordingStore.deleteRecording, which deletes only the SwiftData row and never removes Recordings/recording_<id>.m4a. SettingsViewModel.swift:219-222 explicitly documents that only storageService.deleteRecording removes the file, but the two main delete surfaces don't use it.
- **Why:** The user believes their voice note (ADHD med + mood content) is deleted, yet the raw audio persists in Documents indefinitely — a privacy violation for a health app and an unbounded storage leak. Combined with UIFileSharingEnabled the 'deleted' audio remains browsable in the Files app.
- **Action:** Route MoodLibraryViewModel.delete and RecordingDetailViewModel.delete through AudioFileStorageService.deleteRecording (or make RecordingStore.deleteRecording remove recording.audioURL first). Add a launch sweep that deletes orphaned .m4a files with no matching Recording row to clean up existing installs.
- **Severity:** High

### 6.3 Locked-device Siri dose log can read back medication name and dose; the D8 rationale comment is factually wrong
- **Location:** `app-four/Intents/LogDefaultDoseIntent.swift:17-19, app-four/Intents/DoseConfirmationCopy.swift:11-14`
- **What:** `authenticationPolicy = .alwaysAllowed` is justified by the comment "worst case is journal pollution, nothing is read back (D8)". But DoseConfirmationCopy DOES read back: with the opt-in `nameMedicationInConfirmations == true` (AppSettings.swift:19, default false), `.logged` speaks "<drug> <dose> logged" and `.guarded` always discloses that a dose exists and when — all to anyone holding the locked phone, since the dialog is spoken/shown without unlock.
- **Why:** ADHD stimulant medication is sensitive health data; disclosure on a locked device contradicts the intent's own documented security rationale, so the policy was accepted on a false premise. Opt-in mitigates but the setting copy nowhere warns it extends to locked Siri.
- **Action:** Either suppress the medication name when the device is locked (e.g. check `UIApplication.shared.isProtectedDataAvailable` in the service, or force `named: false` for locked invocations) or consciously re-accept the tradeoff: fix the D8 comment and add the locked-Siri caveat to the "Name medication in confirmations" setting copy.
- **Severity:** Medium

### 6.4 No data-protection class on health audio, exports, or the SwiftData store
- **Location:** `app-four/Services/Audio/AudioFileStorageServiceImpl.swift:11-31, app-four/App/AppModelContainer.swift:35`
- **What:** No FileProtectionType is ever set (repo-wide grep: zero hits): Recordings/, Exports/, and the SwiftData store all inherit the default NSFileProtectionCompleteUntilFirstUserAuthentication, leaving transcripts and audio decryptable any time after first unlock, including while the phone is locked. (Backup exclusion at AppModelContainer.swift:35 is correctly handled.)
- **Why:** For ADHD medication and mood data, best practice (and App Review health-data expectations) is .completeUnlessOpen/.complete so data at rest is keyed to the lock state; the current default gives the weakest post-boot protection for the app's most sensitive files.
- **Action:** Create the Recordings/Exports directories and saved files with [.protectionKey: .completeUnlessOpen] (recording continues while locked, so complete is too strict for the active file), and consider the same for the model container's store URL.
- **Severity:** Medium

### 6.5 ITSAppUsesNonExemptEncryption=false may be wrong now that the app ships AES-GCM user-data encryption
- **Location:** `app-four/Info.plist:5-6; app-four/Services/ExportService.swift:217-224`
- **What:** The plist declares only-exempt encryption, but spec 036+ added AES-GCM-256 encryption of user content (the journal export). Proprietary use of standard crypto for user-data protection generally requires the annual self-classification report; a medical/health end-use exemption may apply but has not been verified anywhere in the repo (no docs reference export compliance).
- **Why:** An incorrect declaration is an App Store Connect compliance issue discovered at submission time (or worse, after France distribution) — cheap to verify now, annoying later.
- **Action:** Verify against Apple's export-compliance categories; if the CryptoKit health-data use qualifies as exempt, record the rationale; otherwise flip the key and file the self-classification report.
- **Severity:** Low

## 7. Performance

### 7.1 Journal export reads up to 200MB of audio and JSON-encodes the whole archive on the main actor
- **Location:** `app-four/Services/ExportService.swift:125-133,158-210 (esp. 160, 129)`
- **What:** ExportServiceImpl.export runs snapshot() and JSONEncoder().encode on the main actor. dto(for:) does Data(contentsOf: r.audioURL) + base64EncodedString() per recording synchronously on main; the encode then serializes an archive that can approach ~270MB (200MB audio budget × 4/3 base64) still on main. Only the AES-GCM seal is detached.
- **Why:** A user with months of voice notes gets a multi-second full UI hang on export and a real watchdog-kill (0x8badf00d) risk on the A14 minimum target — precisely in the flow that exists to protect their data.
- **Action:** Fetch model scalars on the main actor into DTOs holding file URLs only, then read audio bytes, base64, JSON-encode and seal inside the detached task. Also consider streaming audio into the archive rather than one monolithic buffer.
- **Severity:** High

### 7.2 Derived analytics recomputed on every body evaluation and re-triggered by scroll-position state
- **Location:** `app-four/ViewModels/InsightsViewModel+Signals.swift:98-368, app-four/ViewModels/InsightsViewModel.swift:36-53, app-four/ViewModels/MoodLibraryViewModel.swift:69-110, app-four/Views/InsightsView.swift:101-126,141-215, app-four/Views/Library/CalendarLibraryView.swift:85,103`
- **What:** moodShares, weekdaySignalStrips, signalAverages, rhythmMatrix and connections are uncached computed properties, each doing multiple full filter/group passes over monthRecordings (connections do per-day re-filters: O(days × recordings)); InsightsView builds all five pages eagerly in one body pass. Because scrollPosition(id: $activeSectionID) (InsightsView.swift:115) and scrollPosition(id: $topDayID) (CalendarLibraryView.swift:103) mutate view state during scrolling, every page snap / card boundary re-runs the entire analytics or DayTimelineBuilder pipeline (timelineDays rebuilds ~30 days of nodes per call, and timelineDaysFilteredToSelectedDate re-derives it again).
- **Why:** With months of data this is dozens of O(n) passes per scroll event on the main thread — dropped frames exactly during the paging/scroll interactions the two tabs are built around.
- **Action:** Materialize the per-month analytics once per (currentMonth, store.recordings) change — e.g. cache in the VM and invalidate via onChange/observation — and pass precomputed arrays to the section views; same for timelineDays.
- **Severity:** Medium

### 7.3 Insights aggregations recomputed from scratch on every SwiftUI body evaluation
- **Location:** `app-four/ViewModels/InsightsViewModel+Signals.swift:112-125,188-210,214-325`
- **What:** signalStrips re-filters monthRecordings per day (O(days×recordings) with repeated calendar.startOfDay), and connections runs three multi-pass filter chains — all as computed properties on an @Observable model, re-executed on every dependent body pass (scrolls, unrelated state changes).
- **Why:** Fine at 30 recordings, but cost grows quadratically with journal density and this screen re-renders often; hoisting is cheap now and avoids a future scroll-hitch class on A14.
- **Action:** Materialize the per-day grouping once per (month, recordings) change into a cached dictionary keyed by startOfDay, and derive strips/connections from it; invalidate on monthRecordings change.
- **Severity:** Medium

### 7.4 No Low Power Mode or thermal gating on the heavy pipelines (model download, drain inference burst)
- **Location:** `app-four/App/SquirlApp.swift:144-171, app-four/Services/PendingTranscriptionServiceImpl.swift:37-52, app-four/Diagnostics/SessionSnapshot.swift:23`
- **What:** `ProcessInfo.isLowPowerModeEnabled` is checked nowhere; `thermalState` is read only for diagnostics display (SessionSnapshot). The multi-hundred-MB whisper-small download starts on any permitted interface regardless of power state, and `drainIfModelReady` runs back-to-back ANE/GPU inferences immediately on every foreground regardless of Low Power Mode or `.serious`/`.critical` thermal state.
- **Why:** WWDC background-execution guidance (fundamentals: Low Power Mode pauses discretionary work; thermal state is a scheduling input) — a hot, low-battery iPhone 12 foregrounding into a 3-item drain gets a sustained inference burst it should defer, and iOS 26's per-app background battery attribution makes the cost user-visible.
- **Action:** Gate `drainIfModelReady` and `startBackgroundModelDownloadIfNeeded` on `!isLowPowerModeEnabled && thermalState < .serious`; observe `NSProcessInfoPowerStateDidChange` / `thermalStateDidChangeNotification` to resume when conditions clear (items are already durable as `.pendingTranscription`, so deferral is free).
- **Severity:** Medium

### 7.5 Background intent launch pays the full eager composition-root cost
- **Location:** `app-four/App/SquirlApp.swift:23-24, app-four/Store/RecordingStore.swift:11-15,26-37`
- **What:** `SquirlApp.init()` runs on every headless intent launch and eagerly builds the whole graph: `_ = AppDependencies.store` triggers RecordingStore.init, which performs one unfiltered full-table Recording fetch (orphan recovery) plus a filtered full load and a possible save, then MetricManager starts and the WhisperKit service object is constructed. A background Siri dose log needs only DoseLogService + router.
- **Why:** Well within the 30s budget at current journal sizes, but every millisecond here is added latency on the Siri confirmation, and the cost grows linearly with journal size on a path that touches none of it.
- **Action:** No urgent fix. If Siri dose-log latency ever registers, gate `_ = AppDependencies.store` / MetricManager behind scene connection (they are UI concerns) and keep only the three intent dependencies eager in init.
- **Severity:** Low

## 8. SwiftUI / UI / design system

### 8.1 Card surface treatment fragmented: .card() is the documented single pattern but two screens re-implement bare variants, and the eyebrow style forks
- **Location:** `app-four/Views/Insights/ConnectionCardsView.swift:55, 70, 87, app-four/Views/Components/DayCard.swift:39, Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Card.swift:26, 38`
- **What:** Card.swift declares .card() 'the single card pattern for the entire app' (surface + hairline stroke + soft shadow — matching DESIGN.md §Layout 'Cards on Surface with a hairline border and soft shadow'). ConnectionCardsView builds its cards with background+radius only (no hairline, no shadow) and hand-rolls its uppercase eyebrows with .tracking(0.5) while cardEyebrow() uses .tracking(0.7). DayCard uses background+clipShape only. Insights therefore shows flatter, borderless cards next to Calendar's stroked ones on the same paper background.
- **Why:** Cross-screen inconsistency in the most repeated container primitive; two tracking values for one eyebrow role is exactly the imperceptible-but-registering drift the design-principles skill bans. If DayCard's border-free look is an approved spec-019 exception it should be a named DS variant, not an inline divergence.
- **Action:** Move ConnectionCardsView onto .card() and Text.cardEyebrow(); either adopt .card() in DayCard or add an explicit .card(style: .flush) variant to the package so the exception is named and reusable.
- **Severity:** Medium

### 8.2 Energy and Focus signal-ramp hexes in code contradict DESIGN.md's binding values (10 of 10 hexes differ)
- **Location:** `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Palette+Signals.swift:10-16, 27-33, DESIGN.md:45-46`
- **What:** DESIGN.md (binding source of truth, both this worktree and main) specifies Energy 'Lemon' = #A9A079 · #C2B25A · #D8C53E · #EAD22A · #F5D70E and Focus 'Voltage blue' = #7E8B96 · #6E8DAE · #5683B8 · #3E73B0 · #2C5E9E. Shipped code uses entirely different ramps: Energy #7C6E2E→#FCEE64 and Focus #44546E→#79C4FF (plus undocumented Partner ramps). The Mood ramp matches the doc exactly, proving the doc lineage is live — only Energy/Focus drifted (verified on main too via git show main:DESIGN.md).
- **Why:** These ramps are the ordinal data encoding for two of the three core signals across Insights, timeline rows, and the edit sheet. With the doc and code disagreeing on all 10 values, the design system has no enforceable SSOT for signal color — future work can 'correct' in either direction and both look grounded. DESIGN.md changes require explicit owner approval + a Decisions Log entry, and none exists for this change.
- **Action:** Reconcile with the owner: if the shipped ramps are the approved evolution, update DESIGN.md's §Color table and add a Decisions Log row (including the Partner ramps); if not, repoint Palette+Signals.swift at the documented hexes. Do not leave the binding doc contradicting the shipped encoding.
- **Severity:** Medium

### 8.3 Fixed hex palette + light-weight timer on the adaptive Lock Screen material — no dark/light/StandBy adaptation, no system-action colors
- **Location:** `SquirlWidgets/SquirlWidgetsLiveActivity.swift:145-150, 86, 20-23`
- **What:** CheckInPalette hardcodes #5FB36E green and #B8863B amber via `Color(red:green:blue:)` with no dark/light variants. The Lock Screen banner renders on the system material that adapts to the wallpaper's light appearance: the green timer at `.title3.weight(.light)` (line 86) lands around 2.5:1 contrast on a light material, the amber ~3:1 — below the 4.5:1 body-text bar, thinnest possible stroke weight. The same fixed colors are fine in the always-dark Dynamic Island but are also what StandBy scales up 200%. No `activityBackgroundTint`/`activitySystemActionForegroundColor` pair is supplied (comment at 20-22 opts out), so the system derives the swipe-to-dismiss button from defaults rather than the brand palette.
- **Why:** Elapsed time is the primary datum of this surface (spec: timing only); it is the least legible element in light appearance. DESIGN.md owns color decisions — a Live Activity color that only works on dark is a design-system gap, not a per-view choice.
- **Action:** Move the two colors into the widget extension's asset catalog with dark/light variants (darken the green/amber for light), bump the timer to `.regular`/`.medium` weight, and set `activityBackgroundTint` + `activitySystemActionForegroundColor` so the dismiss button matches.
- **Severity:** Medium

### 8.4 Insights pager hard-frames each section to one viewport — content clips at large Dynamic Type
- **Location:** `app-four/Views/InsightsView.swift:101-126`
- **What:** page(_:height:) applies .frame(height: pageHeight) (exact viewport height from GeometryReader) to every section; sections stack header + chart + legend/chips with no inner scrolling. At accessibility text sizes (headers, MoodLegend, ConnectionCards copy all scale via Typography's UIFontMetrics) a section outgrows one viewport and the overflow is clipped and unreachable.
- **Why:** The app ships accessibility deliberately (CalendarHeaderView force-collapses at .accessibility1, ScaledMetric badges) — but its main analytics screen becomes partially unreadable for the same users. GeometryReader is also replaceable by containerRelativeFrame(.vertical) here.
- **Action:** At dynamicTypeSize >= .accessibility1 drop the paging (plain ScrollView, natural heights), or give each page frame(minHeight:) with its own vertical scrolling; consider containerRelativeFrame for page sizing.
- **Severity:** Medium

### 8.5 Live Activity palette: off-palette paused amber, duplicated capture green, no dark variants, DS unreachable from widget target
- **Location:** `SquirlWidgets/SquirlWidgetsLiveActivity.swift:145-150, SquirlWidgets/Assets.xcassets/AccentColor.colorset/Contents.json:1-18, app-four.xcodeproj/project.pbxproj:124-132`
- **What:** CheckInPalette hardcodes accent = Color(red: 95/255, green: 179/255, blue: 110/255) (#5FB36E) and paused = Color(red: 184/255, green: 134/255, blue: 59/255) (#B8863B). #5FB36E is the correct capture green (MoodLevel.good / main's NewLook.checkInGreen) but is duplicated as a private literal; #B8863B matches NO DESIGN.md token (accent bronze is #B8842A light / #D4A24A dark; meadowAmber is #E0A33A). Neither color has a dark variant although the Lock Screen and Dynamic Island render in both appearances (main defines checkInGreen dark = #6FC47E). The widget AccentColor asset likewise carries only a single universal #5FB36E. Root cause: the SquirlWidgetsExtension Frameworks phase links only SwiftUI/WidgetKit/SquirlLiveActivity — SquirlDesignSystem is not linked, so Theme/Palette tokens are unreachable.
- **Why:** This is the app's most publicly visible surface (anyone holding the phone sees it). The paused amber is off-brand today, and the duplicated green will silently drift from main's NewLook.checkInGreen token the next time the capture green is tuned (it already changed once, commit 81ce578c). On a dark Lock Screen the light-mode hexes render without their dark partners, unlike every in-app token.
- **Action:** Link SquirlDesignSystem to the SquirlWidgetsExtension target (its UIKit import is extension-safe) or hoist a two-appearance capture palette into the shared SquirlLiveActivity package; replace CheckInPalette.accent with the shared checkInGreen light/dark pair and paused with Theme.accent (#B8842A/#D4A24A) or meadowAmber — never a bespoke #B8863B. Give the AccentColor asset a dark appearance (#6FC47E).
- **Severity:** Medium (demoted from High by verification)

### 8.6 Monolithic computed-property screen bodies make one observable tick re-render whole screens
- **Location:** `app-four/Views/CheckIn/CheckInView.swift:89-406, app-four/Views/ExtractionReviewView.swift:32-464, app-four/Views/SettingsView.swift:42-276, app-four/Views/Settings/StickerSetupView.swift:50-255`
- **What:** The four largest screens are built almost entirely from private `some View` computed properties on one struct instead of extracted child View structs, so every observable property the body touches invalidates the entire screen. Concrete cost: during a Whisper download, whisperDownloadProgress ticks re-evaluate all twelve Settings sections (including export, DoseGuard, MyMedication) per progress event; during recording, each 0.1 s elapsedTime tick re-evaluates CheckInView's whole captureStage including the static idle/bottom chrome.
- **Why:** swiftui-pro flags exactly this: extracted View structs give SwiftUI diffing boundaries so only views reading the changed property re-render; computed properties (even @ViewBuilder) do not.
- **Action:** Extract the hot leaves first — Settings' aiModelsSection row, CheckInView's recordingCentre/promptProgressBar (pass only timeString/progress), ExtractionReviewView's per-field sections — into standalone structs taking narrow inputs.
- **Severity:** Medium

### 8.7 One semantic 'soft tint chip wash' rendered with six different opacity values across eight sites
- **Location:** `app-four/Views/Components/RecordingRow.swift:89, app-four/Views/Components/TagFlowView.swift:23, app-four/Views/Components/Chip.swift:49, 62, app-four/Views/RecordingDetailView.swift:222, app-four/Views/ExtractionReviewView.swift:223, 354, 409, app-four/Views/Components/MedicationLogSheet.swift:174`
- **What:** The identical pattern — colored text on a soft same-hue capsule/rect wash — uses .opacity(0.12) in RecordingRow, 0.13 in TagFlowView, 0.15 in Chip and the detail status pill, 0.16 and 0.18 in ExtractionReviewView's segPill/dosePill/medGrid, and 0.25 in MedicationLogSheet's med chips. Three near-identical chip renderers coexist (TagFlowView, RecordingRow.tagRow, Chip) with slightly different fonts (TagFlowView uses raw .caption instead of Typography.caption) and paddings.
- **Why:** The wash IS the chip's visual identity; six values means the same tag reads at different weights on Calendar rows, library rows, detail, and the edit sheet. An Opacity token file already exists (deEmphasis/moodBlock/moodBadge) specifically to prevent this class of drift.
- **Action:** Add Opacity.chipWash (pick one value, e.g. 0.15) plus at most one 'selected' variant (0.25) to the DS package, consolidate the three tag-chip renderers onto the DisplayTag-driven one, and sweep the eight sites.
- **Severity:** Medium

### 8.8 Remaining orphan windows after the 07-18 begin-sweep: paused orphans never go stale; cold-launch population races have single fixed retries
- **Location:** `app-four/Services/LiveActivity/LiveActivityControllerImpl.swift:22-24, 53, 77-81`
- **What:** Three residual orphan paths survive the c990a6f8 sweep wave: (a) a `.paused` update deliberately carries `staleDate: nil` (line 53), so if the process dies while paused (jetsam-while-locked is documented as real for this app — CheckInViewModel.swift:170-172), the orphaned 'Paused' card never dims and looks live (frozen timer + Resume/Stop) until the system 8h auto-end, a button tap (reaped via RecordingSessionControllerImpl.swift:82-86), or the next app foreground; (b) `begin()`'s sweep (22-24) reads `Activity.activities` once with no retry, so a cold-launch deep-link auto-start can miss not-yet-populated orphans and briefly stack cards — the exact QA 07-17 symptom; (c) `endAllStale` (77-81) trusts a single 2s sleep — population slower than 2s survives until the next foreground.
- **Why:** All three self-heal (tap-reap or foreground re-sweep), so no permanent lie remains — but a dead-process 'Paused' card presenting live controls for hours is the weakest remaining spot in the FR-010 single-truthful-surface guarantee.
- **Action:** Give `.paused` a generous bounded staleDate (e.g. pausedAt + 30-60 min) so a dead-process paused card eventually dims; consider replacing the sleep-retry with observation of `Activity.activityUpdates` at launch so the sweep is event-driven rather than time-boxed.
- **Severity:** Medium

### 8.9 Signal tag icon + color language fragmented: three sleep icons, two med icons, two side-effect icons, off-palette .pink and system .indigo
- **Location:** `app-four/Models/Recording+MoodDisplay.swift:62-67, 75, app-four/Views/Components/TimelineRow.swift:130, 133, 151, app-four/Views/Components/FoldedDayCardHeader.swift:110, app-four/Views/Components/ADHDSummarySection.swift:58, 63, 82`
- **What:** The same signals render with different SF Symbols and colors per surface. Sleep: 'bed.double.fill' + system .indigo in library chips (Recording+MoodDisplay:62-67), 'zzz' + Palette.sleepIndigo in TimelineRow:133, 'moon.fill' + Palette.sleepIndigo in ADHDSummarySection:58/63. Medication: Icons.medication ('pills.fill') in the hub/settings vs 'capsule.righthalf.filled' in TimelineRow:130 and FoldedDayCardHeader:110. Side-effects: Icons.sideEffect ('bandage.fill') vs 'medical.thermometer' (TimelineRow:151). Emotions: system .pink (not in the palette at all) in library chips vs Theme.accent in the detail summary (ADHDSummarySection:82). Icons.swift exists precisely to centralize these names but is bypassed.
- **Why:** DESIGN.md's glyph language is explicit: sleep = bed icon in cool indigo #5566A6 ('bluer than med purple so they never collide') and medication = horizontal capsule. System .indigo is not #5566A6 and brightens toward med purple in dark mode, eroding the deliberate sleep/med separation; .pink is entirely off-palette. A user sees the same datum wearing three different icons across Calendar, day card, and detail.
- **Action:** Extend Icons (and a small per-signal tint map) with canonical sleep/emotion entries; replace .indigo with Palette.sleepIndigo and .pink with the approved emotion tint (Theme.accent, per the detail screen); pick one sleep icon (bed, per DESIGN.md) and one med SF fallback, and route all DisplayTag construction through them.
- **Severity:** Medium

### 8.10 VoiceOver cannot page months in Calendar or seek audio playback — both are gesture-only
- **Location:** `app-four/Views/Components/CalendarHeaderView.swift:44,116-122, app-four/Views/Components/PlaybackWaveformBars.swift:24-34`
- **What:** Month paging is driven solely by a DragGesture on the header (onPageMonth has no button equivalent; out-of-month cell taps only exist in the expanded month grid, which is force-collapsed at AX sizes). PlaybackWaveformBars exposes seeking only through a DragGesture and flattens itself with accessibilityElement(children: .ignore) plus a static label — no accessibilityAdjustableAction.
- **Why:** VoiceOver and Switch Control users can't reach earlier months from the Calendar tab header (precisely when forceWeek removes the grid fallback) and can't scrub audio at all — inconsistent with the otherwise deliberate a11y work in the same files.
- **Action:** Add .accessibilityAdjustableAction (or hidden previous/next actions) on the calendar header mapping increment/decrement to onPageMonth, and an adjustable action on the waveform mapping to onSeek in ~10% steps.
- **Severity:** Medium

### 8.11 Calendar selection and bead fallbacks use pure system white/black and system grays instead of warm Paper & Pollen tokens
- **Location:** `app-four/Views/Components/CalendarDayCell.swift:28, 44-46, app-four/Views/Components/TimelineBead.swift:43`
- **What:** The selected day number renders Color(.systemBackground) on a Color.primary disc — pure white-on-near-black in light, pure black in dark — and future/out-of-month numbers use Color(.tertiaryLabel); TimelineBead's no-mood fallback disc is Color(.systemGray5). DESIGN.md's first color rule is 'Never pure white, never #000; light = warm paper; dark = warm loam', and warm equivalents exist (Theme.background/Theme.textPrimary/Theme.surface2).
- **Why:** The selected-day disc is the calendar's single strongest accent; cool pure-white/gray chips sit visibly colder than the warm cream/loam surfaces around them, and these are the only surfaces in the Calendar tab not driven by Theme tokens.
- **Action:** Swap to Theme.textPrimary disc + Theme.background numeral, Theme.textSecondary (or a muted token) for future days, and Theme.surface2 for the bead fallback. ~15 min.
- **Severity:** Low

### 8.12 DESIGN.md screen specs contradict the shipped, owner-approved detail screen (pencil toolbar, no Summary+Regenerate card)
- **Location:** `DESIGN.md:94-95, app-four/Views/RecordingDetailView.swift:48-64`
- **What:** DESIGN.md's Recording-detail spec still says 'the old edit pencil is removed — the Edit check-in button is the single consistent edit affordance' and prescribes a 'Summary card (with Regenerate)' and Fraunces title. The shipped screen (spec 027, PR #24, owner-approved) has a pencil toolbar button as the edit affordance, a standard back control, and no Summary/Regenerate card; §Screen Specs and §Motion also still reference the removed Fraunces face ('rotating Fraunces nudge').
- **Why:** The audit's own precedence rule is 'DESIGN.md wins' — a binding doc that loses to shipped reality on its own screen specs stops functioning as a gate; the next design pass could 'fix' the pencil back out in good faith.
- **Action:** Update the Recording-detail and Check-in screen specs to the spec-027/023 shipped state and add Decisions Log rows (decisions were owner-approved; only the doc lagged). Doc-only change, straight to main per repo rules.
- **Severity:** Low

### 8.13 Hand-rolled Binding(get:set:) drives the med-bar confirmation dialog (and adapter bindings in the Edit sheet)
- **Location:** `app-four/Views/Components/MedicationBarView.swift:22-41, app-four/Views/ExtractionReviewView.swift:168-176`
- **What:** MedicationBarView builds the confirmationDialog's isPresented as Binding(get: { selectedDose != nil }, set: …) inline in body, and attaches the dialog to the whole bar VStack rather than the row that triggered it. ExtractionReviewView keeps three Binding(get:set:) adapter properties for mood/energy/focus that only exist to route through set-side effects.
- **Why:** Inline Binding(get:set:) recreates binding identity every body pass and is the pattern the skill explicitly deprioritizes; attaching the dialog away from its source breaks the Liquid Glass source-anchored transition on iOS 26.
- **Action:** Use confirmationDialog(_:isPresented:presenting:actions:) with a plain @State bool + the selected dose as `presenting`, attached to the tapped row; in the Edit sheet expose typed VM properties whose didSet marks editedFields, binding directly with $.
- **Severity:** Low

### 8.14 Interactive tint forks: app-wide NavigationStacks tint meadow green, the edit sheet tints bronze accent
- **Location:** `app-four/DesignSystem/ScreenContainer.swift:56, app-four/Views/ExtractionReviewView.swift:56`
- **What:** ScreenContainer applies .tint(Theme.meadowGreen) to every tab's NavigationStack, while ExtractionReviewView applies .tint(Theme.accent) (bronze) to its own stack — so toolbar buttons, DatePickers, and links change accent color between the detail screen and the edit sheet it presents.
- **Why:** DESIGN.md assigns bronze to 'links/focus' and meadow green to actions; whichever is intended for control tint, it should be one choice — the current split makes Cancel/Save read as a different app from the screen beneath. (Note: on main, 81ce578c moved this sheet's accents to checkInGreen, so resolve against that lineage when 037 merges.)
- **Action:** Pick the single control-tint token (post-merge: checkInGreen for capture/edit surfaces per the 2026-07-16 decision) and set it in one place; remove the per-screen override or document it as the scoped capture-flow exception.
- **Severity:** Low

### 8.15 Verified-clean checklist for the requested checks (no findings)
- **Location:** `SquirlLiveActivity/Sources/SquirlLiveActivity/CheckInActivityAttributes.swift:13-38, SquirlWidgets/SquirlWidgetsLiveActivity.swift:58, app-four/Info.plist:7-12, SquirlWidgets/Info.plist:5-9`
- **What:** Audited and found correct: ContentState is ~3 fields (2 Dates + enum raw string, well under 4KB) with the mutable/immutable split right (cap immutable in attributes); staleDate lives on ActivityContent, not the configuration; keylineTint is set; dismissal uses .immediate per SC-005; intents are LiveActivityIntent with isDiscoverable=false, alwaysAllowed auth pinned by contract, dependencies registered in App.init before any perform (D11), and stopAndSave awaits the finalize Task's value so the save commits before perform returns (D9); NSSupportsLiveActivities=true + UIBackgroundModes audio in the app plist; widget plist has the correct extension point; no symbolEffect/withAnimation in the LA views; `Text(timerInterval:pauseTime:countsDown:showsHours:)` is the right self-updating form with showsHours:false fitting the 44pt compactTrailing cap; controls appear only on Lock Screen + expanded island.
- **Why:** Recorded so the parent audit does not re-open these axes; they were checked against the widgets-skill references, not assumed.
- **Action:** None. Optional iOS-18+ nicety, not a defect: adopt `supplementalActivityFamilies([.small])` + `\.activityFamily` if watch Smart Stack presentation ever matters.
- **Severity:** Low

### 8.16 minimumScaleFactor used to squeeze labels instead of fixing layout in Insights
- **Location:** `app-four/Views/Insights/SignalAverageGauges.swift:74, app-four/Views/Insights/DailyRhythmMatrix.swift:60, app-four/Views/Components/CalendarDayCell.swift:23`
- **What:** Gauge fill labels and rhythm-cell level words shrink via .minimumScaleFactor(0.7) inside fixed 64pt/52pt frames, so adjacent labels render at visibly different point sizes once Dynamic Type grows. (CalendarDayCell:23's 0.6 is a documented, deliberate AX5 shrink-don't-truncate choice — acceptable, listed for completeness.)
- **Why:** The design-principles checklist explicitly bans minimumScaleFactor hacks; mixed-size sibling labels inside one chart read as broken hierarchy at accessibility sizes.
- **Action:** Let the gauge/matrix cells derive width from a ScaledMetric (as StickerSetupView already does for its badges) or drop to an abbreviated label at AX sizes, instead of scaling the type.
- **Severity:** Low

## 9. Dead code / duplication / refactor

### 9.1 Transcription pipeline implemented three times with diverging behavior
- **Location:** `app-four/ViewModels/CheckInViewModel.swift:284-380, app-four/ViewModels/RecordingDetailViewModel.swift:84-150, app-four/Services/PendingTranscriptionServiceImpl.swift:67-133, app-four/ViewModels/ProcessingViewModel.swift:73-90`
- **What:** Stream consumption (for-await over TranscriptionSegmentDTO, write fullTranscriptText, set .transcribing, save) plus the apply-result step exist as three independent copies: CheckInViewModel.consumeStreamWithTimeout (90s timeout + store.exists guard), RecordingDetailViewModel.consumeTranscription (90s timeout, NO exists guard), and PendingTranscriptionServiceImpl.transcribe (exists guard via resolve, NO timeout at all). The apply step also diverges: ProcessingViewModel:84-89 and PendingTranscriptionServiceImpl:120-131 run applySummary + setMedicationEvents, while RecordingDetailViewModel.performSummarization:142 runs applySummary only — a retry/regenerate never refreshes medication events.
- **Why:** The drain path's missing timeout is user-hittable: a hung Whisper inference leaves isDraining=true forever (PendingTranscriptionServiceImpl.swift:39-41), so every subsequent pending recording is blocked until app relaunch — the exact stall the 90s timeout exists to prevent in the foreground path. Each future pipeline fix must now be applied in three places; the med-event divergence already shipped.
- **Action:** Extract one TranscriptionPipeline helper (consume-with-timeout + exists-guard + apply-result with an explicit fillOnly/medEvents policy) and call it from all three sites; this also shrinks CheckInViewModel. At minimum, add the 90s timeout to PendingTranscriptionServiceImpl.transcribe.
- **Severity:** High

### 9.2 CheckInViewModel bundles six responsibilities in 615 lines
- **Location:** `app-four/ViewModels/CheckInViewModel.swift:9-110,284-380,401-460,462-530`
- **What:** One @Observable class owns: recording lifecycle + interruption mirroring, save/retry buffering, the background transcription pipeline (shared-candidate with finding 1), the 8-minute cap approach state, the VoiceOver announcement gate, and the voice-nudge prompt engine (its own interval/pace/progress state from line 462).
- **Why:** The nudge engine and VoiceOver gate have no dependency on audio services and are independently testable; keeping them here is why the file keeps growing every spec (US3/US4/037 all landed in this one type).
- **Action:** Extract NudgePromptEngine (interval, index, progress, ingestAudioLevel) and the transcription pipeline (per finding 1); CheckInViewModel drops to ~350 lines of actual capture-flow logic.
- **Severity:** Medium

### 9.3 Dead code cluster across ViewModels + an unreachable Insights day-detail flow
- **Location:** `app-four/ViewModels/InsightsViewModel.swift:20-30,59-85, app-four/ViewModels/InsightsViewModel+Signals.swift:112-125, app-four/Views/InsightsView.swift:37-49, app-four/Views/Components/DayDetailSheet.swift:1-45, app-four/ViewModels/ExtractionReviewViewModel.swift:10-19,226-228, app-four/ViewModels/RecordingDetailViewModel.swift:13,26-28,50-71, app-four/ViewModels/SettingsViewModel.swift:34-42, app-four/Views/Feedback/ScreenshotCapture.swift:8`
- **What:** InsightsViewModel.selectedDay is never assigned non-nil, so InsightsView's sheet(item:) + its navigationDestination and all of DayDetailSheet are unreachable; also unused: signalStrips, monthLabel+monthFormatter, prevMonth/nextMonth/jumpToToday, calendarDay(for:). ExtractionReviewViewModel.name/userDidSetTitle can never change (the Edit sheet has no title field) so the confirm() title-preserve branch is dead. RecordingDetailViewModel.toggleFavorite/updateTitle/updateDate/updateMood/startRegenerate/summaryTask are called by no view. SettingsViewModel.medicalPromptEnabled is read by no view (the service reads UserDefaults directly). ScreenshotCapture.isCapturing is observed by nothing — the documented FeedbackButton hide-during-capture contract is unimplemented.
- **Why:** Repo rule is 'no dead code'; the unreachable Insights day-detail flow is a silently missing feature (tapping nothing ever opens a day sheet), and dead title/favorite paths mislead future edits into wiring against phantom behavior.
- **Action:** Either wire selectedDay from a chart/strip tap or delete the sheet+destination+DayDetailSheet; delete the other listed members (or add the missing UI they imply, e.g. a title field in the Edit sheet).
- **Severity:** Medium

### 9.4 Entire app-four/wireframes/ folder is unreferenced but compiles into the shipping binary
- **Location:** `app-four/wireframes/CalendarWireframe.swift:3, app-four/wireframes/DetailWireframe.swift:3, app-four/wireframes/InsightsWireframe.swift:3, app-four/wireframes/SettingsWireframe.swift:3, app-four/wireframes/SharedWireframes.swift:4-82`
- **What:** Five wireframe files (486 lines: CalendarWireframe, DetailWireframe, InsightsWireframe, SettingsWireframe, MedicationBarWireframe, TabBarWireframe, FloatingChatButton) have zero references outside the folder (verified project-wide grep). The pbxproj synchronized-folder exception list (project.pbxproj:81-86) excludes only Info.plist, so all five compile into the App Store target.
- **Why:** Pure binary bloat and design-drift risk: per repo CLAUDE.md, mockups/wireframes are explicitly NOT source of truth and they ban dead code; FloatingChatButton depicts a feature that does not exist in the app.
- **Action:** Delete app-four/wireframes/ (git history preserves them). If wanted as reference, move outside the app-four/ synchronized folder (e.g. mockups/).
- **Severity:** Medium

### 9.5 Favorites chain and cloudSyncStatus are unreachable from any UI
- **Location:** `app-four/Models/Recording.swift:15-16, app-four/Store/RecordingStore.swift:93-97, app-four/ViewModels/RecordingDetailViewModel.swift:26-28`
- **What:** cloudSyncStatus has zero references outside its declaration. isFavorite has writers (RecordingStore.toggleFavorite, called only by RecordingDetailViewModel.toggleFavorite) but no view invokes toggleFavorite and no view renders favorite state (grep of app-four/Views for favorite/star: zero hits) — only MockDataGenerator randomizes it and ExportService exports it.
- **Why:** Dead stored properties on a @Model are schema debt, and the export emits a favorite flag the user can never set — misleading data in the user's own journal archive.
- **Action:** Delete cloudSyncStatus outright; for favorites either add the UI affordance (detail-view star) or remove isFavorite + toggleFavorite + the export field.
- **Severity:** Medium

### 9.6 Feedback + Diagnostics chain is write-only: production collects and persists data whose sole reader is unmounted
- **Location:** `app-four/Views/Feedback/FeedbackButton.swift:1-32, app-four/Views/Feedback/IssueReportView.swift:137, app-four/Diagnostics/DiagnosticsStore.swift:57, app-four/App/SquirlApp.swift:24,54, app-four/Utils/View+Tracking.swift, app-four/Utils/EnvironmentKeys.swift:8`
- **What:** FeedbackButton has zero references (deliberately unmounted — assessed formally, not new), which makes IssueReportView, MailComposeView, ScreenshotCapture, and ShareSheetView (380 ln) unreachable. But the writers still run in production: MetricManager.shared.start() at launch, WhisperKitTranscriptionService records SessionSnapshots which DiagnosticsStore.persist() writes to disk, and every .trackScreen call feeds ScreenTracker. The only reader of any of it is the unmounted IssueReportView (diagnosticsStore.recentSnapshots at IssueReportView.swift:137). EnvironmentKeys.swift:8 and WhisperKitTranscriptionService.swift:14 also each allocate decoy default DiagnosticsStore() instances.
- **Why:** ~680 lines across 9 files where half executes for no consumer: CPU/disk writes of session snapshots that no reachable UI ever surfaces, and persisted-on-device diagnostic data with no user-facing view or deletion path.
- **Action:** Pick one: remount FeedbackButton, or remove the Feedback views AND stop the collectors (MetricManager.start, DiagnosticsStore persistence, .trackScreen). Do not keep collecting for an unreachable surface.
- **Severity:** Medium

### 9.7 NLNoteExtractor.swift is 1041 lines holding two top-level types across seven concerns
- **Location:** `app-four/Services/NoteExtraction/NLNoteExtractor.swift:11,101,329,400,545,725,818,906,936`
- **What:** One file contains NLNoteExtractor (sentence splitting, negation, mood/energy/focus matching, medication extraction, sleep, highlights, title — each already MARK-delimited) plus the independent ADHDRegexPatterns type (lines 936-1041). All ADHDRegexPatterns functions are used (verified intra-file call sites at lines 141-146), so this is size, not dead code.
- **Why:** The single hottest file in the census; every extraction change lands in the same 1000-line diff, and review/merge conflict risk concentrates here (three extractor rewrites already collided per project memory).
- **Action:** Move ADHDRegexPatterns to its own file first (pure cut-paste, synchronized folders mean no pbxproj edit), then split NLNoteExtractor into extension files per MARK (NLNoteExtractor+Medications, +Sleep, +Highlights, +MoodEnergyFocus).
- **Severity:** Medium

### 9.8 Personal-lexicon feature is built and tested but never wired into production
- **Location:** `app-four/Services/NoteExtraction/PersonalLexiconBuilder.swift:1-45, app-four/Store/AppDependencies.swift:33, app-four/Services/NLSummarizationService.swift:16-18`
- **What:** PersonalLexiconBuilder.build(from:) is called only from app-fourTests/Services/PersonalLexiconTests.swift. The production summarizer is constructed as NLSummarizationService() (AppDependencies.swift:33), so personalOverlay defaults to nil and LexiconLoader.loadBundled(overlay: nil) always runs; the PersonalLexicon overlay plumbing in LexiconData.swift:63,107,122 is exercised by no shipping code path.
- **Why:** A dormant feature with green tests looks live in reviews and silently rots; users never get the personalization the RecordingTag correction flow implies they are training.
- **Action:** Decide: wire PersonalLexiconBuilder.build(from:) into AppDependencies' summarizer construction (it was clearly the intent), or delete the builder + overlay parameters and their tests.
- **Severity:** Medium

### 9.9 Superseded transcription engines: SpeechTranscriptionService and MockTranscriptionService are dead files
- **Location:** `app-four/Services/Speech/SpeechTranscriptionService.swift:5, app-four/Services/Mock/MockTranscriptionService.swift:4`
- **What:** Zero references to either type anywhere in app, widgets, or tests (verified grep). AppDependencies.swift:12 wires WhisperKitTranscriptionService as the only TranscriptionService. SpeechTranscriptionService (103 ln) still imports the Speech framework and hardcodes en-US SFSpeechRecognizer.
- **Why:** 144 dead lines plus a linked Speech framework dependency the app no longer needs; an SFSpeechRecognizer code path in the binary can also invite App Store reviewer questions about speech-recognition permission usage the app never requests.
- **Action:** Delete both files and the now-empty Services/Speech and Services/Mock folders.
- **Severity:** Medium

### 9.10 TestServicesView (with its own parallel service instances) compiles into Release builds
- **Location:** `app-four/Views/TestServicesView.swift:1-172, app-four/Views/SettingsView.swift:91-93,269-271`
- **What:** Only the 5-tap trigger is inside #if DEBUG || TESTFLIGHT (SettingsView.swift:269-271); the .sheet and the whole 172-line view ship in Release, unreachable but present. The view constructs a second AudioRecordingServiceImpl and a second AIModelServiceImpl(context:) (TestServicesView.swift:12-13) bypassing AppDependencies, and includes a 'Create Fake Recording' button that writes non-audio bytes as an .m4a into the real store.
- **Why:** Debug tooling in an App Store binary (reviewer surface, dead weight), and in DEBUG/TestFlight the duplicate AVAudioSession-owning recorder can fight the real one; fake recordings pollute real user data on a tester device.
- **Action:** Wrap the entire file and the .sheet in #if DEBUG || TESTFLIGHT, and take services from AppDependencies instead of constructing duplicates.
- **Severity:** Medium

### 9.11 TranscriptionSegment @Model is only ever created by DEBUG mock data
- **Location:** `app-four/Models/TranscriptionSegment.swift:5, app-four/Models/Recording.swift:52-53, app-four/Utils/MockDataGenerator.swift:112, app-four/Services/ExportService.swift:190`
- **What:** The only writer of TranscriptionSegment is MockDataGenerator (DEBUG); the real pipeline writes only recording.fullTranscriptText. The only reader is ExportService.swift:190, which for real users always serializes an empty array into the journal export. The @Model still lives in both schema registrations (AppModelContainer.swift:11,75) with a cascade relationship on Recording.
- **Why:** Stale remnant of the pre-WhisperKit segment pipeline: schema weight, migration surface, and an export field (segments) that is a lie — always [] for real data.
- **Action:** Remove TranscriptionSegment, the Recording.segments relationship, the mock writes, and the SegmentDTO export field in one schema-migration-aware change (fields are additive-nullable, but test a store upgrade on device before merging).
- **Severity:** Medium

### 9.12 AppIntentRouter.selectedTab is production-dead — duplicated tab-selection source of truth
- **Location:** `app-four/Intents/AppIntentRouter.swift:23,43,55, app-four/App/SquirlApp.swift:8,65,75`
- **What:** `requestCheckIn()` and `focusMyMedication()` write `router.selectedTab`, but no production code reads it (grep: only app-fourTests/Intents/AppIntentRouterTests.swift:15,34,56). The app's real tab state is SquirlApp's private `@State selectedTab`, set independently inside the two onChange observers — two writers encoding the same decision.
- **Why:** Violates the repo's no-dead-code standard and invites drift: a future trigger added to the router will look routed (tests pass on `router.selectedTab`) while the app never switches tabs.
- **Action:** Delete `selectedTab` from the router and its test assertions, or make it the single source by binding RootContainerView to `router.selectedTab` and dropping SquirlApp's local @State — pick one owner.
- **Severity:** Low

### 9.13 Dead code compiled into the shipping app: SFSpeechRecognizer service, mock transcription service, and 5 wireframe files — plus the orphaned speech-recognition Info.plist key
- **Location:** `app-four/Services/Speech/SpeechTranscriptionService.swift:1-104, app-four/Services/Mock/MockTranscriptionService.swift, app-four/wireframes/SettingsWireframe.swift, app-four/wireframes/DetailWireframe.swift, app-four/wireframes/InsightsWireframe.swift, app-four/wireframes/CalendarWireframe.swift, app-four/wireframes/SharedWireframes.swift, app-four.xcodeproj/project.pbxproj:740`
- **What:** Repo-wide grep (app + tests) finds zero references to SpeechTranscriptionService, MockTranscriptionService, or any wireframe type; AppDependencies wires only WhisperKitTranscriptionService. The app folder is an Xcode 16 synchronized root whose only membership exception is Info.plist (pbxproj:80-86), so all of these compile into the release binary. The wireframes are also the codebase's only remaining .cornerRadius/.foregroundColor legacy-API cluster. INFOPLIST_KEY_NSSpeechRecognitionUsageDescription (pbxproj:740 and 3 siblings) exists solely for the dead SFSpeechRecognizer path.
- **Why:** Violates the repo's explicit 'no dead code' standard, drags pre-reversal UI idioms through future audits, and ships a speech-recognition purpose string for a capability the app no longer uses — an App Store review question waiting to happen.
- **Action:** Delete the two services and the wireframes directory; remove the NSSpeechRecognitionUsageDescription build settings. Zero-risk with synchronized folders (no pbxproj file-list surgery beyond the plist keys).
- **Severity:** Low

### 9.14 Duplicate export path: AudioFileStorageService.exportTranscript is only called by the debug view
- **Location:** `app-four/Services/Audio/AudioFileStorageServiceImpl.swift:74-110, app-four/Services/Protocols.swift:141, app-four/Views/TestServicesView.swift:96, app-four/Models/AppEnums.swift:54-58`
- **What:** exportTranscript(_:format:) — a protocol requirement plus ~37-line implementation — has exactly one caller: TestServicesView.swift:96. The production export is the separate ExportServiceImpl (AppDependencies.swift:41). ExportFormat cases .text and .srt exist solely for this orphaned path.
- **Why:** Two export implementations invite divergence (the stale one predates the encrypted JournalArchive design); the protocol requirement forces every future storage-service conformance to implement dead code.
- **Action:** Delete exportTranscript from the protocol and impl, drop the TestServicesView button, and reduce ExportFormat to the case ExportServiceImpl actually uses.
- **Severity:** Low

### 9.15 Mapper's .processing/.done → .ended path contradicts its contract: update() would leave an un-dismissed, still-ticking 'Saved' card
- **Location:** `app-four/Services/LiveActivity/RecordingActivityContentStateMapper.swift:13-14,27-28, app-four/Services/LiveActivity/LiveActivityControllerImpl.swift:43-55`
- **What:** The mapper's doc says '.processing/.done map to .ended so the caller ends the activity', but `update(for:)` only ends on a nil contentState — a non-nil `.ended` state takes the update branch: it would push a 'Saved' card with staleDate re-armed at anchor+cap, no dismissal policy, controls hidden but the `Text(timerInterval:)` clock still counting up to the cap (phase .ended carries `pausedAt: nil`). The path is currently unreachable (RecordingSessionControllerImpl never calls update with .processing/.done; `end()` builds its own final state), so it is a latent trap guarded only by convention.
- **Why:** The mapper is explicitly the 'single builder... so the surface can never contradict the capture' seam; its one untested branch produces exactly a contradicting surface if any future caller trusts the doc comment.
- **Action:** Either make `.processing/.done` return nil (so update() routes to end(), matching the doc) or change `update(for:)` to end the activity when `contentState.phase == .ended`; add a mapper test pinning the choice.
- **Severity:** Low

### 9.16 Stale WhisperCLI package forks app sources; build artifact committed at repo root
- **Location:** `WhisperCLI/Sources/WhisperCLI/AppEnums.swift:1, Swift-5SCGS38H536W.swiftmodule`
- **What:** Git-tracked WhisperCLI/ SPM package contains copy-paste forks of app files (AppEnums, AudioConverter, DiagnosticsStore, Logger, Protocols, ModelMetadata, plus a MedicalTermCorrector the app no longer has); nothing in the Xcode project references it. A compiled Swift-5SCGS38H536W.swiftmodule directory is also committed at the repo root.
- **Why:** The fork silently diverges from the in-app copies it duplicates (grep hits on these types now return misleading double results), and committed build artifacts churn diffs.
- **Action:** Delete Swift-5SCGS38H536W.swiftmodule (and gitignore *.swiftmodule); move WhisperCLI to spikes/ or delete it if the eval workflow no longer uses it.
- **Severity:** Low

### 9.17 Unused widget template asset WidgetBackground.colorset
- **Location:** `SquirlWidgets/Assets.xcassets/WidgetBackground.colorset/Contents.json:1`
- **What:** An empty colorset (no color components) left from the Xcode widget template; zero references in SquirlWidgets or app sources (grep 'WidgetBackground' finds only the asset). The bundle comment itself notes the generated samples were removed — this asset was missed.
- **Why:** Repo standard is no dead code; an empty named color silently resolves to clear if someone later references it by name expecting the template's default.
- **Action:** Delete the colorset directory. ~2 min.
- **Severity:** Low

## 10. Cross-cutting recommendations

1. **One transcription pipeline.** The stream-consume/timeout/status logic exists three times with diverging guards (§9.1, §5.x, §3.1). Extract a single `TranscriptionRunner` (actor-serialized, context-grounded, environment-aware) that CheckInViewModel, PendingTranscriptionServiceImpl, and RecordingDetailViewModel all call — most High findings collapse into this one refactor.
2. **Context-grounded resolution everywhere.** `RecordingStore.resolve/exists` (added 07-18) must be the ONLY way non-UI code touches a `@Model` after an await. §5.1 (Critical) is exactly one missed site.
3. **Serialize the shared WhisperKit engine at the actor, not at each caller.** Replace cancel-on-entry with tail-chaining inside `WhisperKitTranscriptionService`; callers stop needing bespoke serialization (§3.1).
4. **Make the MainActor default-isolation explicit where it is load-bearing** (`@MainActor` on AudioRecordingServiceImpl and peers) and treat `nonisolated`/module moves as reviewable events (§3.2).
5. **Health-data privacy posture.** Purge audio on delete, add `.completeFileProtection`/`.completeUntilFirstUserAuthentication` to the Recordings dir, and stop exposing Documents via file sharing (§6.1, §6.2).

## 11. What was NOT audited

- `app-fourTests/` as a quality target (consulted only as coverage evidence).
- `mockups/`, `html-mockups/`, `SandboxApp/`, `spikes/`, `docs/`, `specs/` (per repo rules: mockups are not source of truth).
- The Xcode project file beyond isolation/signing/versioning settings; schemes; CI.
- Networking/push (none shipped), StoreKit (none), localization completeness, App Store metadata.
- Runtime profiling (Instruments) — performance findings are static-analysis only.
- The two pre-existing uncommitted local changes (`StartCheckInIntent.swift` dialog removal, `app-four-stable.xcscheme`) were audited as-on-disk but are not part of any commit.

## 12. Verification

- **§5.1** [Critical] — open `app-four/ViewModels/RecordingDetailViewModel.swift:77-130`; refuter: Verified in worktree: RecordingDetailViewModel.retryTranscription/consumeTranscription/finishFailed (lines 79-120) mutate recording and call store.save() with no store.exists guard, while CheckInViewModel guards every eq…
- **§3.1** [High] — open `app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift:97`; refuter: Verified in the worktree: (1) one shared WhisperKitTranscriptionService actor feeds all three consumers (AppDependencies.swift:12,37,47); (2) transcribe() cancels activeTranscriptionTask on entry (WhisperKitTranscription…
- **§5.2** [High] — open `app-four/Views/TestServicesView.swift:101-107`; refuter: Verified: SettingsView.swift:269-271 gates the 5-tap gesture with #if DEBUG || TESTFLIGHT and presents TestServicesView (sheet at L91-93); TESTFLIGHT is defined in Release and Release-Stable SWIFT_ACTIVE_COMPILATION_COND…
- **§5.3** [High] — open `app-four/Services/PendingTranscriptionServiceImpl.swift:37-52`; refuter: All cited code matches the claim. PendingTranscriptionServiceImpl.transcribe (lines 86-96) consumes the stream with no timeout; the drain loop (line 49) re-checks only model presence, never applicationState; errors alway…
- **§5.4** [High] — open `app-four/ViewModels/MedicationBarViewModel.swift:59-109`; refuter: Code confirms the claim: refresh(now:) is invoked only from init, the .medicationEventsDidChange data-change observer (MedicationBarViewModel.swift:42-50), and MedicationBarView.onAppear (MedicationBarView.swift:47). No …
- **§5.5** [High] — open `app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift:145-152`; refuter: Verified against the worktree: WhisperKitTranscriptionService.swift:145-152 takes beginBackgroundTask(withName:) with the default nil expirationHandler and ends it only via defer after kit.transcribe completes — so an ex…
- **§6.1** [High] — open `app-four.xcodeproj/project.pbxproj:738`; refuter: All factual claims verified in the worktree. project.pbxproj lines 738/743 (Debug) and 778/783 (Release) set INFOPLIST_KEY_UIFileSharingEnabled=YES and INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace=YES on the main app …
- **§6.2** [High] — open `app-four/Store/RecordingStore.swift:79-84`; refuter: Confirmed. RecordingStore.deleteRecording (RecordingStore.swift:79-84) deletes only the SwiftData row; its comment claiming AudioFileStorageService handles file deletion is false for this path — no caller invokes the ser…
- **§7.1** [High] — open `app-four/Services/ExportService.swift:125-133`; refuter: Code matches the claim exactly: ExportService.swift declares export as @MainActor (L120, L124); snapshot() (L137-156) and dto(for:) (L158-210) run on main, with Data(contentsOf: r.audioURL) + base64EncodedString() per re…
- **§9.1** [High] — open `app-four/ViewModels/CheckInViewModel.swift:284-380`; refuter: All cited code matches the claim. Stream consumption exists in three diverging copies: CheckInViewModel.consumeStreamWithTimeout (90s timeout + store.exists guard, lines 349-380), RecordingDetailViewModel.consumeTranscri…

Refuted during verification (not in the findings above):
- ~~AudioRecordingServiceImpl: unsynchronized state shared between main-queue interruption observer and pool-executed async methods (known item 1 — confirmed)~~ — The finding's core premise — that the async methods run on the concurrent pool and race the main-queue interruption observer — is false for this project's actual build configuration. The app target th…
- ~~Pending-transcription drain destroys a successfully captured transcript when extraction fails~~ — The code-structure description is accurate — drain(_:)'s generic catch (PendingTranscriptionServiceImpl.swift:77-80) calls markFailed (lines 136-143), which does overwrite recording.fullTranscriptText…
- ~~AudioRecordingServiceImpl: main-queue interruption observer races pool-executed async methods (known item 1 — confirmed, exposure raised by 037)~~ — The finding's foundational claim — that AudioRecordingServiceImpl is non-isolated and its async methods execute on the cooperative pool — is false. The app target compiles with SWIFT_DEFAULT_ACTOR_ISO…
- ~~AudioRecordingServiceImpl is a Sendable-declared class whose main-queue interruption path races its pool-executed async methods~~ — The app target compiles this file with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor in all four configurations (project.pbxproj lines 756, 796, 960, 1000) plus SWIFT_APPROACHABLE_CONCURRENCY = YES, and t…
