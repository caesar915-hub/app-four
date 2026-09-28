<!-- Created: 2026-09-27 22:09 WEST · Updated: 2026-09-27 22:09 WEST -->
# Codebase capture — Root · Check-in · Insights · Settings · Onboarding (as built on `feat/057-ui-refresh`)

Worktree: `/Users/caesargrey/Projects/app-four/.claude/worktrees/057-ui-refresh` (HEAD `08ba8cba`). Read-only capture; no Swift was changed.
All paths below are repo-relative; `file:line` refers to that worktree. Copy strings are quoted verbatim from source.

Working-tree state worth knowing: `DESIGN.md` is **deleted in the working tree** (`git status` → ` D DESIGN.md`); the HEAD version still exists in git (13 sections, headings at HEAD lines 2–182). `outsource_design/` (8 untracked SVGs, "iPhone 17 - N.svg") is the only other change.

---

## 0. Design-token layer the views actually use (so the Figma→code diff is exact)

Tokens live in `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/` and are re-exported app-wide by `app-four/App/SignalsReexport.swift:4-5` (`@_exported import SquirlSignals` / `SquirlDesignSystem`).

| Token | Light | Dark | Source |
|---|---|---|---|
| `NewLook.screen` (ground) | `#EFF2EB` | `#12140F` | NewLook.swift:13 |
| `NewLook.card` | `#FFFFFF` | `#1C1E19` | :15 |
| `NewLook.inkPrimary` | `#1C1B1F` | `#F2F3EE` | :17 |
| `NewLook.onInk` | `#F2F3EE` | `#1C1B1F` | :20 |
| `NewLook.inkSecondary` | `#8A8A8E` (documented below AA, kept by owner decision 2026-07-12) | `#9BA09A` | :25 |
| `NewLook.hairline` | `#DBDDDE` | `#33362F` | :27 |
| `NewLook.tintNeutral` | `#ECEAE6` | `#272A22` | :29 |
| `NewLook.selection` | `#54B492` | `#5FC49F` | :31 |
| `NewLook.onSelection` | `#FFFFFF` | `#1C1B1F` | :35 |
| `NewLook.checkInGreen` | `#5FB36E` | `#6FC47E` | :41 |
| `NewLook.checkInGreenSoft` | `#96C19F` | `#86BC9D` | :44 |
| `Theme.accent` (bronze) | `#B8842A` | `#D4A24A` | Theme.swift:8 |
| `Theme.meadowGreen` | `#5F8A4C` | `#6E9A58` | :9 |
| `Theme.meadowAmber` | `#E0A33A` | `#E8B255` | :10 |
| `Theme.danger` | `#B5503A` | `#CF6A52` | :16 |
| `Theme.meadowGradient` | meadowGreen→meadowAmber, topLeading→bottomTrailing | | :20-23 |
| `Palette.medication` | `#7E5CA8` | `#957BC1` | Palette.swift:12 |
| `Palette.medicationFillEnd` | `#AF99C3` | `#B3A1D6` | :17 |
| `Palette.warning` | `#C2772E` | `#D98A3E` | :19 |
| `Palette.sleepIndigo` | `#5566A6` | `#8E9BD4` | :24 |

Signal ramps (static, same in both modes):
- Mood base low→great: `#DA7A2A · #EDA94A · #9FCB79 · #5FB36E · #2E8B57`; partners `#EA9248 · #FDC06C · #B9DB9C · #7EC38A · #459B6B` (MoodLevel+Palette.swift:16-35). Labels "Low / Flat / Okay / Good / Great" (:65-73).
- Energy sluggish→charged: `#7C6E2E · #A89236 · #D2BB40 · #EEDA4C · #FCEE64`; partners `#8C7F44 · #B8A450 · #E2CD5F · #FEEC6E · #FFF482` (Palette+Signals.swift:10-23). Labels = rawValue capitalized: "Sluggish / Tired / Steady / Alert / Charged" (SignalLevel.swift:57).
- Focus foggy→lockedIn: `#44546E · #4E6F94 · #5889BA · #63A4E0 · #79C4FF`; partners `#5C697E · #6985A4 · #77A0CA · #85BDF0 · #96D1FF` (:27-40). Labels "Foggy / Distracted / Present / Sharp / Locked In" (Levels.swift:113-121).
- Sleep level enum exists (`SleepLevel` restless/light/okay/good/deep, Levels.swift:152-171) but has no ramp; sleep renders as one `BedIcon` in `Palette.sleepIndigo` (SignalGlyph.swift:38-39).
- `fillGradient` = partner(topLeading)→base(bottomTrailing); `bubbleFill` = radial, centre (0.32, 0.28), endRadius 110 (SignalLevel.swift:39-47).

Typography (all SF, Dynamic-Type scaled; Typography.swift): `display` 28 semibold/title1 · `largeTitle` 34 bold · `title` 22 semibold/title2 · `moodWord` 24 bold/title2 · `headline` 16 semibold · `subheadline` 14 medium · `body` 16 regular · `callout` 15 regular · `caption` 12 regular · `label` 12 medium (caller adds uppercase) · `timer` SF Mono 22 medium · `mono12` SF Mono 12 · `text(size, weight, relativeTo)` bespoke.

Spacing (Spacing.swift): xs 4 · s 8 · m 12 · l 16 · xl 20 · xxl 24 · section 32 · hero 40. Radius (Radius.swift): card 16 · control 10 · button 16 · chip 15 · newLookCard 20. Metrics: minTapTarget 44, maxContentWidth 600; `Metrics.CheckIn`: crescentDiameter 300 · stopGlyph 11 · stopGlyphRadius 3 · promptDot 6 · promptBarHeight 4 · savedDisc 78 · savedCheck 32 (Metrics.swift:51-67). Motion: snappy `.snappy(0.3)` · smooth `.smooth(0.4)` · expand `.easeInOut(0.25)` (Motion.swift). Opacity: deEmphasis 0.34 · moodBlock 0.24 · moodBadge 0.50.

Shared card/chip grammar (NewLook.swift):
- `.newLookCard(padding: Spacing.l)` = padding 16, `NewLook.card` fill, radius 20, no border, two-layer shadow `black.opacity(0.05) r8 y2` + `black.opacity(0.03) r2 y1` (:52-66).
- `.newLookChip(selected:role:)` = caption/medium; unselected white + 1pt hairline + inkPrimary; selected = role fill + `onSelection`. Role fills: `.standard` → **`Theme.meadowGreen`** (not `NewLook.selection`), `.medication` → `Palette.medication`, `.checkIn` → `NewLook.checkInGreen` (:80-86, :94-107). Capsule shape, padding h 12 / v 8.
- `NewLookNavBar` (title 24 bold centred via ZStack) exists (:116-148) but none of the four screens in scope use it.

Button styles (Buttons.swift): `.primary` = headline, white, full width, minHeight 44, meadowGradient, radius 16, shadow amber 0.34 r12 y5 (:5-16). `.checkInPrimary` = same metrics, `onSelection` label, gradient checkInGreen→checkInGreenSoft, shadow checkInGreen 0.3 (:21-36). `.secondary` = inkPrimary on `card`, hairline 1pt, radius 16 (:39-53).

Icons (Icons.swift:5-15): tabs `calendar` = "calendar", `checkIn` = "checkmark.circle", `insights` = "chart.bar.fill", `settings` = "gear"; domain `medication` = "pills.fill", `sideEffect` = "bandage.fill".

---

## 1. Root — app entry, dependencies, tab shell

### Files
- `app-four/App/SquirlApp.swift` (224 lines) — `@main`, `RootContainerView`
- `app-four/Views/RootTabView.swift` (44) — `Tab` enum + `TabView`
- `app-four/App/AppModelContainer.swift` (260) — SwiftData container, store quarantine/recovery, `isEphemeral`
- `app-four/App/AppDelegate.swift` (26) — background URLSession reconnect for the LLM download
- `app-four/App/SquirlSchema.swift` (33) — `SquirlSchemaV1` (Recording, TranscriptionSegment, ModelMetadata, AppSettings, RecordingTag, MedicationEvent), empty migration plan
- `app-four/Store/AppDependencies.swift` (52) — composition root; `app-four/Store/AppServices.swift` (38) — the `@Environment` bundle
- `app-four/DesignSystem/ScreenContainer.swift` (111) — per-tab chrome; `app-four/DesignSystem/MedicationBarOverlay.swift` (36)
- `app-four/Views/Components/MedicationBarView.swift` (193) + `app-four/ViewModels/MedicationBarViewModel.swift` (136)

### Entry & environment (SquirlApp.swift)
- `selectedTab` starts at **`.calendar`** (:9); `shouldAutoStartRecording` (:10); `router = AppDependencies.appIntentRouter` (:11).
- `init` (:13-48): `StorageMigration.run()`, `-mockData` launch-arg handling (DEBUG) / clears `debugMockMode` (Release), `MetricManager.shared.start()`, registers `doseLogService` + `router` with `AppDependencyManager` for App Intents.
- Environment injected on `RootContainerView` (:52-63): `.modelContainer(AppModelContainer.container)`, `AppDependencies.store` (RecordingStore), `medicationBarViewModel`, `screenTracker`, `services` (AppServices), `router`, `\.diagnosticsStore`.
- **Feedback button is unmounted** — comment at :64: "Feedback button unmounted (spec 024) — it crashed the app. Views/Feedback/* retained." Confirmed: no `FeedbackButton()` call anywhere in `app-four/`.
- Deep link `whispernotes://checkin` → `router.requestCheckIn()` (:68-71). `router.shouldStartCheckIn` → `selectedTab = .checkIn; shouldAutoStartRecording = true` (:72-76). `router.shouldFocusMyMedication` (initial: true) → `selectedTab = .settings` (:82-85); consumption happens in SettingsView.
- `AppIntentRouter` (`app-four/Intents/AppIntentRouter.swift`): `requestCheckIn()` is gated on `AppSettings.hasCompletedOnboarding` (:41-46, wired in AppDependencies.swift:18-23); returns `.gatedOnboarding` when incomplete. One-shot consumers `consumeCheckIn()` / `consumeMyMedicationFocus()` (:49-63).

### RootContainerView (SquirlApp.swift:90-224)
- Wraps `RootTabView` in `.fullScreenCover(isPresented: $showOnboarding) { WelcomeView(...) }` (:108-110). `showOnboarding = !hasCompletedOnboarding` from `@Query AppSettings` (:95-100, :121); DEBUG skips with `-skipOnboarding` or mock mode (:112-120).
- Background model download (:129, :158-207): only after onboarding, only if not declined per model (`declinedOnboardingModelDownload` / `declinedOnboardingLLMDownload`, :209-214), whisper first then LLM, waits for a permitted interface (`downloadOverCellular`), via `ResilientModelDownload`.
- Drains `pendingTranscriptionService.drainIfModelReady()` on launch and every `.active` scene phase (:134-139).

### RootTabView (RootTabView.swift)
- `enum Tab: Hashable { calendar, checkIn, insights, settings }` (:5-10).
- `TabView(selection:)` order + labels (:19-35): **Calendar** (`Icons.calendar` = "calendar") → `CalendarLibraryView(store:selectedTab:)`; **"Check in"** (`Icons.checkIn` = "checkmark.circle") → `CheckInView(store:services:shouldAutoStart:)`; **Insights** ("chart.bar.fill") → `InsightsView(store:selectedTab:)`; **Settings** ("gear") → `SettingsView(store:services:selectedTab:)`.
- Tab tint: `.tint(Theme.meadowGreen)` (:36). Plain `tabItem` labels; no custom tab bar, no badges.

### Per-tab chrome (ScreenContainer.swift)
- Every tab root = `NavigationStack(path:)` + `.navigationTitle(title)` inline + `.background(NewLook.screen)` + `.toolbarBackground(NewLook.screen, for: .navigationBar)` (:49-54); `.tint(Theme.meadowGreen)`; tab-bar background `NewLook.screen`, visibility `.visible` (:56-60). All four in-scope screens pass `title: ""` (empty nav title).
- `scrollable: true` wraps content in `ScrollView` + `.edgeFadeMask(top: 0, bottom: 36)` (:68-79); Check-in, Insights and Settings all pass `scrollable: false` and manage their own scroll.
- Medication bar: `.medicationBarOverlay(shown:)` = `safeAreaInset(edge: .top)` with `MedicationBarView()` padded h 16 / top 8 (MedicationBarOverlay.swift:18-23). Doc comments in both files still say "floating Liquid Glass capsule / `.glassEffect`" (ScreenContainer.swift:8, MedicationBarOverlay.swift:10-11) but the bar is a plain `.newLookCard(padding: Spacing.m)` (MedicationBarView.swift:19) — **doc/code drift, no glass in code**.
- Check-in and Settings show the bar (`showsMedicationBar: true`); Insights uses the default (`true`); Sticker setup / Acknowledgements pass `false`.

### Medication bar contents (MedicationBarView.swift)
- Renders only when `@AppStorage("medicationBarVisible")` is true AND `activeDoses` non-empty (:12). Up to **3** active doses, oldest→newest, from `MedicationEvent`s taken in the last 24 h still inside their `durationHours` window (MedicationBarViewModel.swift:22, :59-76).
- Row (:51-75): `SignalGlyph(.medication, size: 24)` · title `"HH:mm · <Name> <dose>"` (`Typography.text(15, .semibold)`; name/dose suffix dropped when `medicationBarShowName` is false, :96-104) · state word uppercase `Typography.label` tracking 0.5 in `Palette.medication` — "kicking in" <20 %, "active" <80 %, "wearing off" <100 %, "worn off" (:79-86) · `DoseTrack` capsule height 19, `tintNeutral` groove, gradient `medication→medicationFillEnd`, onset pulse 0.55 opacity ≤20 % (:133-174).
- Tap → confirmationDialog "Log new dose" / "Delete this dose" / "Cancel" (:20-39); "Log new dose" opens `MedicationLogSheet`.

---

## 2. Check-in

### Files
- `app-four/Views/CheckIn/CheckInView.swift` (512) — screen + private `CheckInSavedView`
- `app-four/Views/CheckIn/CrescentRing.swift` (61) — the ring
- `app-four/Views/CheckIn/TextCheckInComposer.swift` (154) — type-note sheet + `SignalScaleRow`
- `app-four/ViewModels/CheckInViewModel.swift` (568); `app-four/ViewModels/ProcessingViewModel.swift` (107)
- Supporting: `app-four/Models/PromptPace.swift`, `app-four/Models/CheckInDraft.swift`, `app-four/Views/Components/GlyphRampPicker.swift`, `app-four/Views/Components/MedicationLogSheet.swift`, `app-four/Models/AppEnums.swift:18-24` (`RecordingState`), `app-four/Utils/Constants.swift:9-12`

### View model state machine (CheckInViewModel.swift)
- `state: RecordingState` = `.idle | .recording | .paused | .processing | .done` (AppEnums.swift:18-24). **`.paused` is never assigned by CheckInViewModel** (grep: only `AudioPlaybackViewModel` uses a `.paused`, and that is a different enum) — the "Paused" UI at CheckInView.swift:302-307 and the `Opacity.deEmphasis` dim at :150 are unreachable today.
- `maxDuration = 480 s` (8 min; Constants.swift:10); `approachWindow = 30 s` (:26); `isApproachingCap = elapsed ≥ 450 s` (:31), one-shot latch `hasShownCapApproach` (:36-42). Timer ticks every 0.1 s (:510-526) and auto-calls `stopRecording()` at the cap (:520-523).
- `startRecording()` (:119-188): re-entry guard (idle/done only); clears recovery flags; **Whisper model intercept** — if not downloading and `localPath(for: .whisper) == nil` → `showModelDownloadPrompt = true` and return (:139-142); disk guard `> 50 MB` (Constants.swift:11) else `lowDiskSpace`; mic permission else `permissionDenied`; then `.recording`, idle timer disabled, `promptInterval = loadPromptInterval()` (:164), timer + level monitoring, Whisper preload staggered 1.5 s (:173-183).
- `stopRecording()` (:227-251) → `.processing`; audio stop → `pendingSave` buffer → `attemptSave` (:257-291): saves via `storageService.saveRecording`, `store.addRecording`, `.done`; if Whisper missing → `recording.status = .pendingTranscription` and skip transcription (:272-276); else background transcription chained after any prior one (:278-283). Save failure → `saveFailed = true`, state stays `.processing` (:284-290).
- `retrySave()` (:294-302), `discardFailedCapture()` deletes the buffered file → `.idle` (:306-313), `cancelRecording()` → `.idle` (:402-413), `reset()` → `.idle` (:415-420).
- Transcription outcomes (:316-366): `.completed` → `processingViewModel.processRawTranscription(...)`; cancel → `.failed` with transcript text "Transcription cancelled. Tap to retry in the recording detail view."; timeout → "Transcription timed out. Tap to retry in the recording detail view."; other → "Transcription failed: <localizedDescription>".
- VoiceOver gate: `activeVoiceThreshold = 0.1` (:60); `isSpeaking` from the audio-level stream; prompt announcements deferred until quiet (:63-71, :464-478).
- Text path `saveTextCheckIn(_:)` (:484-508): `store.persistCheckInNote(draft)`; if the trimmed note is non-empty → `processRawTranscription(..., fillOnly: true)`; then `.done`.

### Voice-prompt pacing ("Brisk / Relaxed")
- `enum PromptPace: Int` — `.relaxed = 10`, `.brisk = 6` seconds; labels **"Relaxed · 10 s"** / **"Brisk · 6 s"** (PromptPace.swift:3-15). Persisted as `AppSettings.promptPaceSeconds` (default relaxed, AppSettings.swift:11); read once per recording from the main SwiftData context (`loadPromptInterval()`, CheckInViewModel.swift:422-429) and set in Settings › Check-in › "Prompt Pace".
- Five `nudgePrompts` (:438-444), rotated by `Int((elapsed + 1e-6) / promptInterval) % 5` (:449-453); `promptProgress` = fraction inside the current window (:458-460):
  1. "How's your mood?" — "Heavy, light, flat, bright — whatever fits."
  2. "What's your energy like?" — "Wired, steady, or running low."
  3. "Able to focus?" — "Locked in, scattered, somewhere between."
  4. "How did you sleep?" — "Hours, and how rested you feel."
  5. "Any strong emotions?" — "Something sitting with you right now."

### Screen structure (CheckInView.swift)
Container: `ScreenContainer(title: "", showsMedicationBar: true, scrollable: false)` (:26); `.animation(Motion.smooth, value: state)` unless Reduce Motion (:29); `.trackScreen("CheckInView")` (:31). Auto-start: `onAppear` + `onChange(of: shouldAutoStart)` → `consumeAutoStart()` (:32-33, :98-106) — starts voice capture from `.idle`, resets-then-starts from `.done`, ignores while capturing. Any capture start sets `@AppStorage("checkInHintSeen") = true` (:16, :41, :111).

`content` (:119-133): `.done` → `CheckInSavedView`; every other state → `captureStage`.

**captureStage** (:143-193) — one `ZStack`, padding h 16 / bottom 16:
- Centre: `CrescentRing(isActive: state == .recording && !saveFailed)` at **300 × 300** (:148-149), plus `recordingCentre` when not idle else `idleRingCentre` (:152).
- Top chrome `VStack` pinned to top: `recordingHeader` when not idle else `idleHeader` (:156-159).
- Side effects: error haptic on save failure (:164-166); "Wrapping up soon" cue shown for 4 s once (:169-175); VoiceOver announcements "Saving…" / "Captured." (:186-192).

**Idle**
- `idleHeader` (:199-221), padding top 20, spacing 4: today's date `Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.wide))` (:115-117) in `Typography.label` uppercase `inkSecondary`; headline **"How do you feel?"** `Typography.text(24, .bold, relativeTo: .title2)` `inkPrimary`; first-launch whisper (until `checkInHintSeen`): **"Say whatever's on your mind — a few words is plenty."** `callout`, `inkSecondary.opacity(0.7)`.
- `idleRingCentre` (:223-233) — `VStack(spacing: 8)` inside the ring: hub pill **"Log meds"** (icon `Icons.medication` "pills.fill" tinted `Palette.medication`) → `showMedLogSheet`; **speak pill**; hub pill **"Type note"** (icon "square.and.pencil", ink) → `showComposer`.
- `speakButton` (:235-251): "mic.fill" + **"Speak check-in"** `headline`, `onSelection` on `Theme.meadowGreen` capsule, padding h 24, minHeight **48**, `.newLookCardShadow()`; a11y "Start voice check-in".
- `hubOption` (:255-268): `NewLook.card` capsule, padding h 24, minHeight 44, card shadow, `headline` ink label.

**Recording / processing**
- `recordingHeader` (:273-279) = `promptProgressBar` + `heroPrompt` on `.newLookCard()` (spacing 12).
- `promptProgressBar` (:334-350): capsule track `tintNeutral`, fill `Theme.meadowGreen`, height **4**, `.linear(0.1)`, re-identified per prompt so it snaps to 0.
- `heroPrompt` (:352-377): question `text(24, .bold, .title2)`; hint `callout` `inkSecondary`; `promptDots` (5 × 6 pt circles, spacing 6; active `meadowGreen`, others `inkSecondary.opacity(0.3)`, :379-390); question slides in from trailing/out to leading, `.easeInOut(0.35)`.
- `recordingCentre` (:285-332), `VStack(spacing: 12)` over the ring: timer `Typography.timer` (SF Mono 22) `inkPrimary` formatted `M:SS` (`AccessibilityHelpers.formatDuration`, AccessibilityHelpers.swift:10-14) with a11y "Recording, <t> elapsed"; ("Paused" `label` uppercase — unreachable, see above); `stopButton`; **Cancel** text button (`callout`, `inkSecondary`, `card` capsule, minHeight 38, padding h 16, card shadow, a11y "Cancel recording"); **"Wrapping up soon"** `caption` `inkSecondary.opacity(0.7)` (opacity-toggled).
- `stopButton` (:392-415): 11 pt rounded (r 3) stop square in `onSelection` + **"Stop & save"** `headline`; padding v 12 / h 24; minHeight 44; `meadowGreen` capsule; in `.processing` the label becomes a `ProgressView` and the button is disabled; a11y "Finish check-in".
- `failureRecovery` (:419-449) replaces the centre when `saveFailed`: **"Couldn't save that one."** `headline`; **"Your check-in is safe — tap to try again."** `callout` `inkSecondary`; **"Try again"** `headline` in `onInk` on an `inkPrimary` capsule (padding v 12 / h 24, minHeight 44); **"Discard"** plain text button.

**Saved** — private `CheckInSavedView` (:456-507): `Spacer` · disc **78 pt** `meadowGreen` with card shadow + "checkmark" 32 pt bold `onSelection`, pops from scale 0.6/opacity 0 with `.spring(response: 0.5, dampingFraction: 0.6)` + `Haptics.success()` · **"Captured."** `text(24, .bold)` · **"That's today's check-in. Talk to you next time."** `callout` `inkSecondary` max width 240 · `Spacer` · **"Done"** full-width `meadowGreen` capsule, minHeight 50, `onSelection`, bottom padding 40 → `viewModel.reset()`. The saved `Recording` is passed in but not rendered.

**Ring** (CrescentRing.swift): a **full circle stroke** (name is legacy — comment :3-4), `Theme.meadowGreen`, `lineWidth` 22, butt caps, inset by half the stroke (:30-35). Idle "breathing": scale 1.0↔1.035 + opacity 0.94↔1.0, `.easeInOut(5)` autoreverse (:43-49); active: 360° rotation `.linear(7)` repeat (:37-42) — visually a hold since the stroke is uniform. `breathing: false` variant used by onboarding Welcome. Reduce Motion → static.

### Sheets & alerts on the Check-in screen
- `.sheet` `MedicationLogSheet` (:34-38) → `medicationBarViewModel.logManualDose(...)`. Sheet (MedicationLogSheet.swift): custom nav "Log Dose" `Typography.title`, xmark close 30 pt circle, **"Save"** trailing (`meadowGreen` when enabled); sections "Medication" (horizontal chips from the catalog + "Name" field), "Dose" (menu picker of `doseOptions` + "Onset ≈ N min" + note "Typical values from product labeling — your response may differ."), "Effect Duration" ("Hours" decimal field), "Taken At" (hour-minute picker ≤ now). Chips: selected `Palette.medication.opacity(0.25)` + 1 pt medication border, unselected `tintNeutral`.
- `.sheet` `TextCheckInComposer` (:39-45) — returns `!viewModel.textSaveFailed`.
- Alerts (:46-88), title → buttons → message:
  - "Microphone Access Required" → "Open Settings" / "Cancel" → "Squirl needs microphone access to record voice notes. Enable it in Settings."
  - "Not Enough Storage" → "OK" → "Squirl needs at least 50 MB of free space to record. Free up some space and try again."
  - "Voice Processing Model" → "Download" (`startRecordingWithDownload`) / "Not Now" (`startRecordingWithoutDownload`) → "To transcribe your voice accurately and securely on-device, Squirl needs to download a small language model (approx. 40MB). It will take a minute on Wi-Fi." (**size copy conflicts** with "~150 MB" used everywhere else for Whisper.)
  - "Not Enough Storage for Model" → "OK" → "Squirl needs at least 150 MB of free space to install the language model. Free up some space and try again."
  - "Model Download Failed" → "OK" → "Something went wrong while downloading the language model. Please check your connection and try again."
  - "Not Enough Memory" → "OK" → "Squirl couldn't generate insights because your device is low on memory. Your note is saved — close some apps, then open the check-in to try again."
  - "Insights Model Not Downloaded" → "OK" → "Your note is saved, but mood, energy and focus weren't extracted because the insights model isn't on this device yet. Download it from Settings › AI Models."

### Text composer (TextCheckInComposer.swift)
- Full-screen-ish sheet on `NewLook.screen` with drag indicator (:16-30). Custom navbar (:34-57): xmark close in a `card` circle with 1 pt hairline (44 pt), title **"Type a check-in"** `Typography.title`, phantom trailing spacer.
- Content `VStack(alignment: .leading, spacing: 16)`, padding 16: three `SignalScaleRow`s "Mood" / "Energy" / "Focus" separated by hairline `Divider`s (:61-69); note box (:73-91) = `card` with placeholder **"Anything you want to remember about today?"** (`callout` `inkSecondary`), `TextEditor` `body`, min height **120**; save block (:98-120): **"Save check-in"** `.checkInPrimary`, disabled while `draft.isEmpty`; failure line **"Couldn't save — tap to try again. Your note is safe."** `callout` `inkSecondary` + error haptic.
- `SignalScaleRow` (:125-150): title `subheadline.semibold`, readout `mono12` `"<n> · <Label>"` or "—", then `GlyphRampPicker(kind:selection:)` — glyph size 30, tap-again clears, selected ring `RoundedRectangle(r 10)` 1.5 pt in **`ringTint` default `Theme.accent` (bronze `#B8842A`)** (GlyphRampPicker.swift:9-35). The composer never passes `ringTint`, so the selection ring is bronze, not check-in green — contrary to GlyphRampPicker's own doc comment (:6-7).
- Draft model `CheckInDraft` (CheckInDraft.swift): `mood/energy/focus` optional levels, `sleepQuality`, `meds` (unused by the composer UI), `note`; `isEmpty` when nothing set. Persisted by `RecordingStore.persistCheckInNote` (RecordingStore.swift:123-153): title = "Mood · Energy · Focus" labels, else first 5 note words, else "Check-in"; `audioFileName = "text-<uuid>"`, `duration 0`, `status .completed`.

### Post-capture pipeline (ProcessingViewModel.swift)
- Finds the `Recording` by `audioFileName` (:55-69); sets `summaryStatus = "generating"` (:71); `summarizationService.summarize(rawTranscription:)` (:76). `insufficientMemory` → `showMemoryError` + `ExtractionValidator.fallbackResult` (:77-80); `modelNotInstalled` → `showModelMissing` + fallback (:81-86); any other error → `summaryStatus = "failed"` (:87-93). Success → `recording.applySummary(result, fillOnly:)` + `setMedicationEvents(...)` + save (:97-103). `CheckInViewModel` forwards `showMemoryError` / `showModelMissing` for the two alerts (CheckInViewModel.swift:82-91).

---

## 3. Insights

### Files
- `app-four/Views/InsightsView.swift` (207)
- `app-four/Views/Insights/MonthSelectorScrollView.swift` (33) · `MoodBubbleChart.swift` (92) · `MoodLegend.swift` (42) · `SignalStripsView.swift` (117) · `SignalAverageGauges.swift` (137) · `DailyRhythmMatrix.swift` (102) · `ConnectionCardsView.swift` (170)
- `app-four/ViewModels/InsightsViewModel.swift` (74) · `InsightsViewModel+Signals.swift` (371)

### Container & states (InsightsView.swift)
- `ScreenContainer(title: "", scrollable: false, path: $path)` (:20); `.trackScreen("InsightsView")` (:41).
- `hasAnyData` (= any recording in the selected month, InsightsViewModel.swift:66) → `sectionsScroll`; else `monthSelector` + `emptyState` (:22-30).
- Empty state (:188-201): SF "chart.bar.doc.horizontal" `largeTitle` `inkSecondary` + **"Check in to see your month"** `headline` `inkSecondary`; padding top 80 / bottom 40.
- `navigationDestination(for: UUID.self)` → `RecordingDetailView` (:32-39) is wired, but **nothing in Insights pushes a UUID** (bead taps were removed with a07, SignalStripsView.swift:5-6; grep confirms no `path.append` / `NavigationLink(value:)`) — dead navigation path.
- `selectedTab` binding is received (:7) but unused inside the view.

### Section structure top→bottom (`sectionsScroll`, :84-100)
`ScrollView` › `VStack(alignment: .leading, spacing: 16)`, padding h 16 / top 16 / bottom 40, `.edgeFadeMask(top: 0, bottom: 36)`:
1. **Identity** (:53-64): **"Insights"** `text(24, .bold, .title2)` + subtitle **"<Month wide> · today vs your usual"** `subheadline` `inkSecondary`.
2. **Month chips** (`MonthSelectorScrollView`): horizontal, spacing 8, label `"MMM yyyy"` uppercased tracking 1.3, `.newLookChip(selected:)` role `.standard` → selected fill **`Theme.meadowGreen`** (the file comment says "solid selection fill" but the role maps to meadow). Months = every month from the earliest recording to now (InsightsViewModel.swift:25-36); tapping sets `currentMonth`.
3. **Breakdown card** (:129-140): header **"Your overall check-in breakdown"** with trailing **"N check-in(s)"** (`monthRecordings.count`); `MoodBubbleChart` + `MoodLegend` when `moodShares` non-empty (card shows header only otherwise).
4. **Signals card** (:142-150): **"Your month in three signals"**, subtitle **"Average by weekday — this month"**; `SignalStripsView(strips: weekdaySignalStrips)`; then the **"Sleep · not tracked yet"** dashed chip (`SignalGlyph(.sleep, 15)`, `caption`, hairline capsule dash `[4, 3]`, :67-80).
5. **Averages card** (:152-158): **"Where you averaged"**; `SignalAverageGauges(averages: signalAverages)`.
6. **Rhythm card** (:160-167): **"Your daily rhythm"**, subtitle **"Dominant level per signal by time of day"**; `DailyRhythmMatrix(matrix: rhythmMatrix)`.
7. **Connections block** (:171-186, padding top 12, not on a card): eyebrow **"CONNECTIONS"** `label` tracking 1.3 `inkSecondary`; caption **"Patterns across signals — 3 or more days to unlock"**; `ConnectionCardsView(connections:)`. **Copy mismatch:** the real thresholds are 4 / 5 / 3+3 days (below), not "3 or more".

Card header helper (:103-124): title `headline` `inkPrimary` (header trait), optional trailing `caption` `inkSecondary`, optional subtitle `caption`. Every card = `.newLookCard()` (padding 16, r 20, white, shadow).

### Component specs
- **MoodBubbleChart** (MoodBubbleChart.swift): frame height **160**; diameter `44 + (118 − 44) · sqrt(fraction / maxFraction)` (:31-36); x = one of 5 equal columns by mood 1→5 (:38-41); y = centre − (level − 3) · 14 (:43-47); bubble fill `level.bubbleFill` (radial); label "NN%" `label.semibold` and the mood word when diameter ≥ 68 (:66-74); ink via `Color.contrastingInk` (black/white).
- **MoodLegend** (MoodLegend.swift): `LazyVGrid(adaptive min 100, spacing 8)`; each = 8 pt `fillGradient` dot + label `caption` `inkPrimary` + "(count)" `caption` `inkSecondary`; white capsule + 1 pt hairline; padding h 12 / v 4.
- **SignalStripsView** (SignalStripsView.swift): per strip — header row `SignalGlyph(kind, level: modal, 18)` + kind label `subheadline.medium` + summary `caption` (`"mostly <Label>"` / `"no data"`); then 7 `BeadSlot`s = `SignalGlyph(size 28)` (dashed empty glyph when nil) + weekday label `text(9, .medium)` "Mo Tu We Th Fr Sa Su"; each slot `maxWidth ∞`, minHeight 44. Strips spacing 12.
- **SignalAverageGauges** (SignalAverageGauges.swift): `HStack(.bottom, spacing 16)` of three columns: `SignalGlyph(26)` at the average level (nil when empty) · track **64 × 280**, `tintNeutral`, r 10, five dashed tick lines (4 pt dashes, 2 pt gaps) at 1/5 steps · fill `fillGradient` of `average.level` with height `280 · fraction`, fill label `caption.semibold` in contrasting ink at the top · caption `caption` `inkSecondary` below (or "—").
- **DailyRhythmMatrix** (DailyRhythmMatrix.swift): row label width 56, blob **52**; column headers "Morning / Afternoon / Evening / Late" `caption`; cell = filled circle `level.fillGradient` + `displayLabel` `label` (min scale 0.7), or a dashed circle `inkSecondary.opacity(0.3)` dash `[3, 2]` 1.5 pt + "—" at 0.4 opacity; min 44 × 44.
- **ConnectionCardsView** (ConnectionCardsView.swift): `VStack(spacing 12)`. Unlocked card (:39-72) = title `label` uppercase tracking 0.5 `inkSecondary` · sentence **`Typography.display`** (28 semibold) `inkPrimary` · `MiniBar` (height 8, `tintNeutral` track, fill **`Palette.medication` for all three connections** :125, leading/trailing `caption`, percent `label.semibold` centred). Gated card (:74-108) = title + "lock" glyph `caption`, unlock copy `callout` `inkSecondary`, white `card` r 20 with a **dashed** 1 pt hairline border `[5, 3]` (the only bordered card in the app).

### Computations available (InsightsViewModel+Signals.swift) — data source is `Recording` in the selected month
Source fields: `createdAt` (Recording.swift:7), `mood: String?` (:29, resolved by `MoodLevel(name:)`), `energyLevel: String?` (:27, `EnergyLevel(rawValue: lowercased)`), `focusLevel: String?` (:28), `sleepQuality: String?` (:31), `medicationEvents` (:58-59). Resolver `signalLevel(for:from:)` :335-342.
- **`moodShares`** (:101-111): count of each `MoodLevel` across the month's recordings (recordings without a mood are excluded from the total); `fraction = count / total`; ordered low→great. Feeds the bubble chart + legend + the breakdown "%".
- **`weekdaySignalStrips`** (:132-157) — *the one the view uses*: group recordings by `Calendar.weekday`; slots `[(2,"Mo"),(3,"Tu"),(4,"We"),(5,"Th"),(6,"Fr"),(7,"Sa"),(1,"Su")]`; per slot the mean `numericValue` rounded (`Int(avg.rounded())`, half away from zero) → level; nil when no data. Summary via `stripSummary` = modal label over the whole month (:344-354).
- **`signalStrips`** (:115-128) — date mode, one bead per check-in day using the *latest* recording of that day; **not consumed by any view** (only tests). Available for the redesign.
- **`signalAverages`** (:161-187): mean of `numericValue` over recordings with that signal; `fraction = avg / 5`; whole number → `fillLabel = "<Label>"`, caption `"<Label> on average"`; otherwise `fillLabel = "<Lower>+"`, caption `"between <Lower> & <Upper>"`; `level = Int(avg)` (floor); empty → `"—"`, caption "", fraction 0, level 0.
- **`rhythmMatrix`** (:191-213): buckets `TimeBucket` (:49-72) — **morning 06–11, afternoon 12–17, evening 18–21, late 22–23 + 00–05** by `createdAt` hour; dominant = most frequent level, **ties break to the higher level**; `count` per cell.
- **`connections`** (:217-328), always three, in this order:
  1. **"Medication × focus"** — med days = distinct days with ≥1 `medicationEvents`; **gate: `medDayDates.count >= 4`**; gated copy `"Log medication on \(need) more day(s) to unlock this connection."`; unlocked: share of med days with any recording at focus ≥ 4 (Sharp / Locked In) → sentence `"On medication days, sharp focus appeared \(pct)% of the time."`, bar label `"\(pct)%"`, leading "Med days", trailing "Sharp+ focus".
  2. **"Energy × mood"** — high-energy days = distinct days with a recording at energy ≥ 4 (Alert / Charged); **gate: `>= 5` days**; copy `"Log high energy on \(need) more day(s) to unlock this connection."`; unlocked: share of those days with mood ≥ 4 → `"On high-energy days, good-or-better mood appeared \(pct)% of the time."`, leading "High energy", trailing "Good+ mood".
  3. **"Sleep × mood"** — string match on `sleepQuality` lowercased: good = `["good","great","excellent","well"]`, poor = `["poor","bad","terrible","awful","rough"]`; **gate: `goodDays.count >= 3 && poorDays.count >= 3`**; copy `"Note \(N) more good-sleep day(s) and \(M) more poor-sleep day(s) to unlock this connection."` (only the deficient side(s) named); unlocked: aligned = good-sleep days with mood ≥ 3 plus poor-sleep days with mood ≤ 2, over all good+poor days → `"Sleep quality and mood moved together \(pct)% of the time."`, leading "Sleep quality", trailing "Aligned mood".
- Unused-by-Insights VM API: `prevMonth() / nextMonth() / jumpToToday() / monthLabel / isCurrentMonth` (InsightsViewModel.swift:19-59) — only the calendar's own model uses the same method names; InsightsView binds `currentMonth` directly through the chips.

---

## 4. Settings

### Files
- `app-four/Views/SettingsView.swift` (302); `app-four/ViewModels/SettingsViewModel.swift` (264)
- Sections: `app-four/Views/Settings/DayCardSettingsSection.swift` (30) · `DoseGuardSection.swift` (101) · `JournalExportSection.swift` (86, `EncryptedJournalDocument` + `RecoveryKeySheet`) · `MedicalInfoSection.swift` (28) · `MedicationBarSettingsSection.swift` (30) · `MyMedicationSection.swift` (201) · `StickerSetupView.swift` (262, unmounted) · `YourDataSection.swift` (76)
- `app-four/Views/Components/ModelDownloadRow.swift` (246); `app-four/Models/AppSettings.swift`; `app-four/Models/DoseGuardMode.swift`; `app-four/Models/MedicationCatalog.swift`

### Container (SettingsView.swift)
- `ScreenContainer(title: "", showsMedicationBar: true, scrollable: false)` › `ScrollViewReader` › **`List` `.insetGrouped`**, `.scrollContentBackground(.hidden)` (sage ground shows through), `.listRowBackground(NewLook.card)` (:45-70). Native grouped chrome — Settings is the one screen that uses system `List`/`Label`/`Toggle`/`Picker` styling rather than New Look cards.
- Scrolls to top whenever the tab becomes `.settings` (unless a My-Medication focus is pending) (:74-79); the App-Intent "not configured" continuation scrolls to My Medication (anchor y 0.12) and expands the picker (:86-92). `.trackScreen("SettingsView")` (:95).

### Sections top→bottom (:47-67) with persistence keys
1. **"AI Models"** (:130-169) — two `ModelDownloadRow`s: **"Voice Transcription"** (icon "waveform", `.whisper`) and **"Journal Insights"** (icon "brain.head.profile", `.llm`). Installed state = filesystem truth `aiModelService.localPath(for:) != nil` (SettingsViewModel.swift:150-155, re-checked on `.aiModelAvailabilityDidChange`). Download via `ResilientModelDownload` with progress (:157-196); cancel (:200-205); delete (:227-234); error cause per model in `downloadErrors[type]`.
2. **"System"** (:171-185) — `LabeledContent("Storage")` value **"N recording(s) · X.X MB"** (`store.recordings.count`, `storageService.calculateTotalStorageUsed()` → MB); `Toggle` **"Download over Cellular"** (icon "antenna.radiowaves.left.and.right") → `AppSettings.downloadOverCellular` (SettingsViewModel.swift:108-111; default `false`, AppSettings.swift:37).
3. **"Check-in"** (:187-200) — `Picker("Prompt Pace")` over `PromptPace.allCases` ("Relaxed · 10 s" / "Brisk · 6 s"); footer **"How long each prompt stays on screen during a voice check-in."** → `AppSettings.promptPaceSeconds` (:113-116, default 10).
4. **"Calendar"** (`DayCardSettingsSection`) — `Toggle` **"Always expand cards"** (icon "rectangle.stack") → `@AppStorage("alwaysExpandCards")` default `false`; `Toggle` **"Auto-expand selected day"** (icon "rectangle.expand.vertical") → `@AppStorage("autoExpandOnSelection")` default `true`. Hints: "When on, every day's check-ins stay open in the calendar." / "When on, tapping a date opens that day's check-ins automatically."
5. **"My Medication"** (`MyMedicationSection` :21-62) — row `Label("Medication", "pills")` with a trailing value in three states: **"Set"** in `Color.accentColor` (nothing set) · plain name `.secondary` (name, no dose) · **"<Name> · <dose>"** `.semibold` `Palette.medication` (both set); chevron rotates 90° when expanded. Expanded: **"Medication"** chip flow (`MedicationCatalog.all` = **Concerta** [18/27/36/54 mg] · **Ritalin** [5/10/20 mg] · **Elvanse** [20–70 mg], MedicationCatalog.swift:20-39) then **"Dose"** chips for the selected entry; picking a medication clears the dose (`medicationDidChange`, SettingsViewModel.swift:121-124). **"Clear Medication"** destructive button when set. Footer: "Logged by the Log My Meds action — Siri or Shortcuts. Only this medication and dose are recorded; changing it never alters past logs." Keys → `AppSettings.defaultMedicationName` / `defaultMedicationDose` (:126-131). `SettingsChip` (:182-201): `subheadline.medium`, padding h 12 / v 8, capsule, selected `Palette.medication` + white, unselected `.quaternary` + `.primary`.
   - Second section **"Confirmations"** (:64-76): `Toggle` **"Name medication in confirmations"** (icon "quote.bubble") → `AppSettings.nameMedicationInConfirmations` (default `false`, :133-136); preview banner (:147-167): 26 pt "pills.fill" white on `Palette.medication` r 7, line **"Dose logged"** (off) or **"<Name> <dose> logged"** (on; falls back to "Elvanse" / "30 mg"), "· 17:42" mono digits, on `Color(.tertiarySystemFill)` r 12. Footer: "Off — discreet everywhere; the medication name stays inside the app. On — confirmations name the medication and dose (banner, spoken, and on the lock screen)."
6. **"Dose Guard"** (`DoseGuardSection`) — three selectable rows with "shield" icon and a `checkmark` in `accentColor`: **"Off"** / "Every trigger logs" · **"Total"** / "Blocked while a dose is still active" · **"Time window"** / "Blocked for a set time after a dose"; when `.window`, a segmented **"Blocked for"** picker 1 h / 2 h / 3 h / 4 h. Footers per mode (:90-100), each ending " The in-app Log Dose sheet is never blocked." Keys → `AppSettings.doseGuardModeRaw` ("off" | "total" | "window", default "off") and `doseGuardWindowHours` (default 2) (SettingsViewModel.swift:138-143; AppSettings.swift:17-18).
7. *(unmounted)* **Sticker setup** — `stickerSetupSection` (:212-222) is defined but deliberately not in the list (:56-59, "1.1 paid-tier holdback"). It would be `NavigationLink` **"Set up your sticker"** (icon "sensor.tag.radiowaves.forward") → `StickerSetupView`, footer "Turn a blank NFC sticker into a one-tap dose log or check-in. About a minute, once per sticker."
8. **"Medication Bar"** (`MedicationBarSettingsSection`) — `Toggle` **"Show Medication Bar"** (icon "pills.circle") → `@AppStorage("medicationBarVisible")` default `true`; when on, `Toggle` **"Show Medication Name"** (icon "pill") → `@AppStorage("medicationBarShowName")` default `true`.
9. **"Medication info"** (`MedicalInfoSection`) — body: "Squirl is a personal journal, not medical advice. Dose lists and effect times are typical values from the manufacturer's product information — your prescription and response may differ." Footer: "Talk with your clinician or pharmacist before changing how you take medication." (App Review 1.4.1.)
10. **"Accessibility"** (:228-234) — a single `caption` text: "Squirl follows the iOS motion setting. Turn on Reduce Motion in Settings › Accessibility to still animations." (no control).
11. **"Your data"** (`YourDataSection`) — conditional warning when `AppModelContainer.isEphemeral` ("exclamationmark.triangle" in `Theme.danger`): "Storage couldn't be opened this session, so new check-ins won't be saved. Restarting the app usually fixes this."; statement "Your recordings, check-ins, and signals stay on this device. Nothing is uploaded."; `Link` **"Privacy Policy"** (icon "hand.raised") → `https://squirl.pt/privacy`; `NavigationLink` **"Acknowledgements"** (icon "heart") → `AcknowledgementsView` (`ScreenContainer(title: "Acknowledgements", showsMedicationBar: false)`, one credit: **WhisperKit** — "On-device speech recognition that turns your voice into text without leaving the device."). **MLX / Qwen are not credited.**
12. **Journal export** (:236-267, no header) — `Button` `Label` **"Save a copy of my journal — yours to keep"** (icon "lock.doc") with an inline `ProgressView` while preparing; footer: "Saves one encrypted file you can keep or share. We'll show you a key to open it — keep it safe. If you lose the key, the backup can't be recovered — not even by us." Flow: `exportService.export` → `.fileExporter` (`EncryptedJournalDocument`, `.data`, filename **"Squirl Journal yyyy-MM-dd"**) → on success `RecoveryKeySheet`; failure alert **"Couldn't save a copy"** / "Something went wrong preparing your backup. Please try again." `RecoveryKeySheet` (JournalExportSection.swift:30-86): `NavigationStack`, title **"Keep this key safe"** `Typography.title`, body "This file can only be opened by a future version of Squirl, using this exact key. If you lose the key, the backup can't be recovered — not even by us. Save it somewhere only you can reach.", key in `mono12` on `tintNeutral` r 16, **"Copy key"** / **"Copied"** `.primary` (meadow gradient; local-only pasteboard, 120 s expiry), toolbar **"Done"**.
13. **Danger** (:269-277, no header) — destructive `Label` **"Clear All Data"** (icon "trash") → alert **"Clear All Data?"** / "Clear All Data" (destructive) / "Cancel" / "This permanently deletes all your recordings and check-ins. Your downloaded transcription model and preferences are kept. This can't be undone." → `clearAllData()` (SettingsViewModel.swift:249-263: deletes every recording + audio file and standalone medication events; keeps models and preferences).
14. **Version** (:279-296) — centred `caption` `inkSecondary` **"<CFBundleDisplayName> v<CFBundleShortVersionString>"** (fallback "Squirl v—"), clear row background.

Orphan setting: `SettingsViewModel.medicalPromptEnabled` (UserDefaults key `"medicalPromptEnabled"`, default true; SettingsViewModel.swift:43-51, Constants.swift:45-58) has **no row in SettingsView** (grep: unused in `app-four/Views`).

### `AppSettings` (SwiftData, AppSettings.swift) — full key list
`id` · `hasCompletedOnboarding` (false) · `defaultLanguage` ("en") · `downloadOverCellular` (false) · `transcriptionCount` (0) · `promptPaceSeconds` (10) · `defaultMedicationName` (nil) · `defaultMedicationDose` (nil) · `doseGuardModeRaw` ("off") · `doseGuardWindowHours` (2) · `nameMedicationInConfirmations` (false) · `declinedOnboardingModelDownload` (false) · `declinedOnboardingLLMDownload` (false).
`@AppStorage` keys outside SwiftData: `checkInHintSeen`, `alwaysExpandCards`, `autoExpandOnSelection`, `medicationBarVisible`, `medicationBarShowName`, plus UserDefaults `medicalPromptEnabled`, `debugMockMode`.

### `ModelDownloadRow` states (ModelDownloadRow.swift)
Layout: `VStack(spacing 8)` = `mainRow` + `subline`; long-press-free — a confirmation dialog **"<title> Options"** with **"Delete Model"** (destructive) / "Cancel" (:30-37).
- **Not installed, idle**: `Toggle` OFF (tint `meadowGreen`) with `Label(title, icon)` `body`; subline **"~150 MB · Wi-Fi recommended"** `caption` `inkSecondary` (:66-74, :81-84). Flipping ON calls `onDownload` immediately (:44-51).
- **Installed**: `Toggle` ON; no subline. Flipping OFF opens the delete dialog; cancelling leaves it ON (binding reads `isInstalled`).
- **Downloading**: `HStack` `Label` · linear `ProgressView` width 80 + **"NN%"** mono digits, or an indeterminate spinner (scale 0.8) + **"Starting…"** while progress is 0 · **"Cancel"** text in `meadowGreen` (:89-109).
- **Error**: `Label` + 8 pt `Theme.danger` dot; subline = message in `Theme.danger` `caption` + ghost pills (`caption.medium` `meadowGreen`, hairline capsule, minHeight 44, `FlowLayout`): **"Try again"**, and for a cellular block also **"Allow on cellular"** and **"Open Settings"** (:110-114, :127-158). Messages (Protocols.swift:153-164): noNetwork "No connection. Reconnect to the internet, then try again." · insufficientSpace "Not enough space on this device. Free up some room, then try again." · cellularDisabled "You're on cellular and downloads over cellular are off. Switch to Wi-Fi, or allow cellular downloads in Settings." · other "The download didn't finish. Try again in a moment."
- **Dead branch**: the `"Installed"` / `"Not installed"` text with a `Theme.statusDone` / `statusInProgress` dot (:115-123) sits in `trailingStatus`, which only renders when `isDownloading || hasError` — so an "Installed" label is never shown; the toggle position is the only installed indicator.
- **Copy bugs to carry into the plan**: the "~150 MB · Wi-Fi recommended" subline and the a11y hint "Downloads the on-device transcription model, about 150 megabytes" (:70-72, :171) are hard-coded for **both** rows, so the Journal Insights row understates ~740 MB (LLMDownloadView.swift:73; AppDelegate.swift:5 says "~1 GB") and misnames the model.

### StickerSetupView (unmounted; StickerSetupView.swift)
`ScreenContainer(title: "Set up your sticker", showsMedicationBar: false)`; intro `callout`; segmented **"Dose sticker"** / **"Check-in sticker"** (tints `Palette.medication` / `Theme.meadowGreen`); cards with eyebrow headers "What you'll need" (rows "A blank NFC sticker" / "A default medication set"), "Log a dose · 5 steps" / "Start a check-in · 5 steps" (numbered markers 28 pt, an "Open Shortcuts" `.borderedProminent` hand-off, a "Recommended" pill on step 5, a "Done." row), callouts "What to expect when you tap it" and "Can't get it to read?". Copy contract is tested (StickerSetupViewTests).

---

## 5. Onboarding (first-run, `fullScreenCover`)

Files: `app-four/Views/Onboarding/WelcomeView.swift` (96) · `SiriOnboardingView.swift` (111) · `DownloadPermissionView.swift` (117) · `LLMDownloadView.swift` (112) · `OnboardingViewModel.swift` (129).

Flow is a linear `NavigationStack` push chain: **Welcome → Siri → Whisper download → LLM download**, then the cover dismisses. (File comments in Welcome :4 and Siri :4 still say "three-screen"; there are four.) Every screen: `GeometryReader › ScrollView › content.frame(maxWidth: 600).frame(minHeight: geo.height)`, background `NewLook.screen`, padding h 24 / v 40, `VStack(spacing: 32)`.

1. **Welcome** (WelcomeView.swift): `CrescentRing(breathing: false)` **232 × 232** (static meadow ring) · **"Welcome to Squirl"** `largeTitle` · **"A calm place to speak your day. Everything stays on this device."** `body` `inkSecondary` · **"Squirl is a journal — it doesn't give medical advice."** `caption` `inkPrimary` · `NavigationLink` **"Start"** `.checkInPrimary` (+ `Haptics.success`).
2. **Siri** (SiriOnboardingView.swift, leading-aligned): eyebrow **"Hands-Free Voice"** `label` uppercase tracking 0.7 in `checkInGreen` · **"Speak to Siri Anytime"** `title.bold` · **"Squirl works hands-free with Siri right out of the box — zero setup required."** `callout` · card **"Siri Voice Phrases"** ("mic.fill") with two phrase bubbles **"Hey Siri, log my meds in Squirl"** ("pills.fill") and **"Hey Siri, check in on Squirl"** ("waveform") — `screen` fill, r 10, dashed hairline `[4, 3]`, icon `checkInGreen` · button **"Continue to Model Download"** + "arrow.right" `.checkInPrimary`.
3. **Whisper opt-in** (DownloadPermissionView.swift): "lock.shield" 64 pt `checkInGreen` · **"On-Device Privacy"** `largeTitle` · **"To keep your journal completely private, Squirl processes your voice directly on this device."** · error line `error.userMessage` in `Theme.danger` · idle: **"Download Now (~150 MB)"** `.checkInPrimary` + **"Skip for Now"** `.secondary`; downloading: linear `ProgressView` tint `checkInGreen` + **"Downloading model... NN%"**, back button hidden. Resolves (download or skip) → pushes LLM step.
4. **LLM opt-in** (LLMDownloadView.swift): "brain.head.profile" 64 pt · **"Journal Insights"** · **"A second on-device model reads your check-ins and picks out mood, energy, focus, sleep and medications — still private, still on this iPhone."** · **"Download Now (~740 MB)"** · **"Wi-Fi recommended"** `caption` · **"Skip for Now"**; downloading: **"Downloading insights model... NN%"**.

`OnboardingViewModel`: `didComplete`, `didResolveWhisper`, `isDownloading`, `downloadProgress`, `downloadError: ModelDownloadFailure?` (:23-32). `complete()` writes `hasCompletedOnboarding = true` and signals even if the save fails (:46-50). `skipModelDownload` → `declinedOnboardingModelDownload = true` (:60-64); `skipLLMDownload` → `declinedOnboardingLLMDownload = true` + complete (:77-80). A download of an already-installed model short-circuits to success (:94-97).

---

## 6. Feedback button
`app-four/Views/Feedback/FeedbackButton.swift` — compiled only under `#if DEBUG || TESTFLIGHT`; 48 × 48 `NewLook.card` circle, "exclamationmark.bubble" `title.semibold`, `.shadow(radius: 4)`, a11y "Report an issue", opens `IssueReportView` as a sheet. **Not mounted anywhere** (SquirlApp.swift:64; grep finds no `FeedbackButton()` call). `IssueReportView`, `MailComposeView`, `ScreenshotCapture`, `ShareSheetView` remain in the tree.

---

## 7. Paywall / purchase status on this branch
- `grep -rniE "Purchase|RevenueCat|Paywall"` over Swift, pbxproj, plist and Package.resolved in this worktree → **no matches**. There is no purchase service, entitlement gate, or paywall view on `feat/057-ui-refresh`.
- It lives on **`feat/055-revenuecat`** (unmerged; merge-base with this branch `2553e251`; ~15 commits ahead incl. `c6ffc876 feat(055): switch to RevenueCatUI paywall + Customer Center, add Lifetime plan`). Files there (read-only `git ls-tree`): `app-four/Services/Purchase/{EntitlementGate, EntitlementMapping, GateEvaluator, GrandfatherResolver, PreviewPurchaseService, PurchaseCopy, PurchasePersistence, PurchaseService, RevenueCatConfiguration, RevenueCatPurchaseService}.swift`; `app-four/Views/Paywall/{FailOpenView, PaywallButtonStyle, PaywallLegalFooter, PaywallStepView, PaywallView, PaywallViewModel, PlanCard, RevenueCatPaywallHost, TrialTimeline}.swift`; tests under `app-fourTests/Purchase/` (9 files) + `FakePurchaseService` / `FakePurchasePersistence` mocks.
- Implication for the UI plan: any paywall screen in the Pencil file must be planned against that branch's `PaywallView` / `RevenueCatPaywallHost`, and the CLAUDE.md monetization guardrails (fail-open, export never gated, grandfathering, no dark patterns) still bind. The HEAD `DESIGN.md` §Paywall & Purchase (lines 91–108) is the only design record of those screens and is currently deleted in the working tree.

---

## 8. Existing tests touching these screens (Swift Testing, `app-fourTests/`)
- `ViewModels/CheckInViewModelTests.swift` — **32** tests: prompt count/contents/rotation, `promptProgress` normalisation, text check-in (selectors-only skips processing; note runs fill-only; empty draft no-op; save failure), stop with/without Whisper (`pendingTranscription` vs transcribe), permission denied/granted, model-download prompt/with/without, re-entry no-op, stale flag reset, save-failure buffer/retry/discard, VoiceOver gate (threshold, deferral, coalescing), cap approach (window, one-shot), preload cancellation, tick after cancel, cap auto-stop.
- `ViewModels/ProcessingViewModelTests.swift` — 6: persists summary, marks failed on throw, fetch-by-filename, no-match no-op, insufficient memory, model not installed.
- `ViewModels/InsightsViewModelTests.swift` — **28**: moodShares, date-mode strips (chronological, modal summary, "no data"), averages ("+" half-step, whole word, empty, level ordinal), rhythm (dominant, tie→higher, late bucket wraps midnight), connections (med×focus gate <4 / unlock 4; energy×mood gate <5 / unlock 5; sleep×mood 3+3; gated copy counts, singular "day", both-sides copy; always three in order), weekday strips (grouping, round-up, half rounding, empty month, slot order, all kinds).
- `ViewModels/SettingsViewModelTests.swift` — **22**: storage MB, model check, recording count, no Reduce-Motion property, medicalPrompt UserDefaults key, download cause surfacing + messages, allow-cellular affordance, cancel → clean, retry clears error, per-model error scoping, My Medication round-trip / clear / change clears dose, name-in-confirmations default + sync, dose-guard round-trips, invalid raw → off.
- `ViewModels/OnboardingViewModelTests.swift` — 12: complete persists / no duplicate / idempotent / signals on save failure, whisper download resolves without completing, failure surfaces error, skip records decline, success no decline, unclassified error type-tag only, LLM success completes, LLM skip records decline + completes, LLM failure.
- `Views/StickerSetupViewTests.swift` — 9 (copy contract of `StickerPath`).
- `Intents/AppIntentRouterTests.swift` — 8 (tab + one-shot triggers, onboarding gate re-evaluated per call); `Intents/ConfirmationCopyTests.swift` — 7.
- `Models/AppSettingsTests.swift` — 4 (fresh defaults incl. dose-intent fields); `Models/DoseGuardModeTests.swift`; `Models/MedicationCatalogTests.swift`; `Store/CheckInNoteStoreTests.swift` — 5 (text check-in persistence: scalars, manual meds, title fallback, note→transcript, whitespace title).
- `ViewModels/MedicationBarViewModelTests.swift` — 14; `SignalGlyphTests.swift` — 9 (clamp, names, synonyms, a11y labels).
- **No view/snapshot tests** exist for `CheckInView`, `InsightsView`, `SettingsView`, `RootTabView`, `ModelDownloadRow`, or the onboarding views; view-level coverage is limited to pure-logic helpers (StickerSetup copy, DayCard state, calendar strip fade, folded header). Tests run through `xcodebuild` with the `app-four.xctestplan`.

---

## 9. Observations to feed the redesign plan (facts, not decisions)
1. **Dead / unreachable UI**: check-in `.paused` state + "Paused" label; `ModelDownloadRow` "Installed"/"Not installed" trailing text; Insights `navigationDestination(UUID)`; `InsightsViewModel.signalStrips` (date mode) unused by any view; `SettingsViewModel.medicalPromptEnabled` has no control; `stickerSetupSection` and `FeedbackButton` intentionally unmounted.
2. **Copy inconsistencies**: Whisper size "approx. 40MB" (CheckInView alert) vs "~150 MB" (Settings row, onboarding); LLM row reuses the 150 MB / "transcription model" strings; Connections caption "3 or more days" vs real gates 4 / 5 / 3+3; onboarding comments "three-screen" vs four screens.
3. **Token drift vs. the shipped New Look**: month chips and standard chips fill with `Theme.meadowGreen`, not `NewLook.selection` `#54B492`; the composer's glyph ring uses bronze `Theme.accent`; every connection mini-bar is medication purple; the "Crescent" is a full meadow ring; the medication bar is a white card, not glass despite comments; `RecoveryKeySheet` "Copy key" still uses the meadow→amber gradient `.primary`.
4. **Screen title convention**: all four tabs pass `title: ""` and render their own in-content headings (Check-in has none in idle beyond "How do you feel?"; Insights prints "Insights"; Settings shows no visible title at all).
5. **Settings is native `List`** (insetGrouped, system `Toggle`/`Picker`/`Label`, `Color.accentColor` for "Set"/checkmarks) — a different visual grammar from the card-based tabs; any Pencil redesign has to decide whether Settings stays List-exempt.
6. **Sleep is spec'd but not tracked** in Insights (dashed chip); `SleepLevel` enum and `Recording.sleepLevelValue/sleepHours/sleepQuality` exist, and the sleep×mood connection keys off free-text `sleepQuality`.
7. **`DESIGN.md` is deleted in the working tree**; the HEAD copy holds §9 Product Posture, §10 Paywall & Purchase and §13 Decisions Log, which no code file reproduces.
