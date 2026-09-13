<!-- Created: 2026-09-13 06:35 WEST · Updated: 2026-09-13 06:35 WEST -->
# Full Codebase Audit — app-four `main` @ 2553e251

_Automated overnight audit, 2026-09-13. 10 independent Opus (max-effort) lens agents → one adversarial verifier per finding (reads the cited code, refutes by default) → an independent cross-check panel (completeness critic + false-positive auditor + fix-safety classifier). 88 agents, 0 errors. Code is the source of truth; findings that survived verification are below._

## Method & honest limits

- **Read-only** static audit of a detached `main` worktree. No behavior was exercised on a device; every finding is from reading the source and tracing call sites.
- Each lens agent cited `file:line` and quoted code. A separate verifier re-opened each finding and could REFUTE it; only survivors appear here. A false-positive auditor then re-checked the survivors and flagged **0** as overstated.
- Severity is the verifier's *corrected* severity, not the lens's initial guess.
- Out of scope: vendored `Packages/MLXLibraries`, `WhisperCLI`, `SandboxApp`, `mockups/`, `html-mockups/`.
- SwiftUI views carry no unit tests by design (constitution X), so view-behavior fixes are marked **device-QA** — they are reported, not auto-applied.

## Calibration (verified facts)

| Fact | Value |
|---|---|
| Target | `main` @ 2553e251 (2026-08-31) |
| Baseline build | **CLEAN + BUILD + TEST SUCCEEDED** on iPhone 17 Pro (iOS 26) simulator |
| Baseline tests | **544 tests / 70 suites, all passed** (Swift Testing) |
| Compiler warnings | 7 unique: 3 vendored MLX C++ (out of scope); **4 app-relevant** — `ResumeState`'s main-actor-isolated `Equatable` conformance used from `ResumeStateStoreTests` is a Swift-6-language-mode error-in-waiting |
| App module | 146 Swift files, ~19.6k LOC |
| Findings | **62 confirmed** (2 high, 17 medium, 43 low) + **4 cross-check additions** (1 high, 3 medium) |
| Fix disposition | 10 findings auto-fixed on `fix/audit-safe-cleanup` (14 files; Debug 544 tests + Release build both green); the rest reported for device QA |

## Headline

**`main` is releasable and well-built: it builds clean, all 544 tests pass, the June 2026 audit was fully remediated, and the modern-API surface (SwiftData, Observation, structured concurrency, native SF typography) is sound.** The audit surfaced no crash-on-launch or corruption bug. The findings that matter cluster in four places:

1. **🔴 A full 8-minute recording is silently lost at the max-duration cap.** Two independent auto-stop timers race on the same 480 s limit — the audio service's wall-clock timer and the ViewModel's tick-accumulated timer. The service always fires first, tears down the recorder, and reports back through no channel, so the ViewModel's later stop throws and resets to `.idle` with no save and no orphan recovery. Found by both the concurrency and services lenses. (`CheckInViewModel.swift:520`, `AudioRecordingServiceImpl.swift:251`)
2. **🔴 Deleting a check-in orphans the voice recording on disk forever.** `RecordingStore.deleteRecording` removes only the SwiftData row under a comment claiming the storage service deletes the file — it never calls it. Both single-delete UIs use this path, so the sensitive `.m4a` audio persists after the user deletes the entry, against the on-device-privacy posture. Surfaced independently by the cross-check panel. (`RecordingDetailViewModel.swift:35` → `RecordingStore.deleteRecording`)
3. **🟡 On-device health content is written to the log in Release,** and the LLM passes run in `Task.detached` that ignores cancellation. (auto-fixed the logging; cancellation reported)
4. **Dead code and false coverage.** ~2k LOC of the superseded NaturalLanguage pipeline still compiles into Release (a `chore/remove-dead-nlp` branch already stages its removal), 97 tests exercise that dead path, `SpeechTranscriptionService` (103 LOC) links the Speech framework though nothing uses it, and several debug-only surfaces shipped into Release (now gated).

## 🔴 High

### Confirmed by the lens audit

****#12** `app-four/ViewModels/CheckInViewModel.swift:520` — Two independent max-duration auto-stops run against the SAME 480s constant on DIFFERENT clocks; the audio service (wall-clock) always stops first and never tells the ViewModel, so the ViewModel's later stop attempt throws and resets to .idle — losing a full 8-minute recording.**

- _Failure:_ User records the full 8 minutes. At true 480s the audio service auto-stops and finalizes the file; the VM keeps showing .recording for the accumulated drift gap (seconds), then its elapsedTime reaches 480, it calls audioService.stopRecording() which throws RecordingError.unknown (recorder already nil), the catch resets state to .idle, and the 8-minute recording is silently lost (never saved, no retry buffer).
- _Fix:_ Make the audio recorder the single source of truth for the cap: either remove CheckInViewModel's elapsedTime-based stop and have AudioRecordingServiceImpl report auto-stop back to the VM (delegate/AsyncStream/continuation) so the VM runs its normal save path, or drive elapsedTime from the recorder's wall-clock currentTime so both cross 480 together. At minimum, CheckInViewModel.stopRecording()'s catch must NOT discard the capture on RecordingError.unknown when a file already exists.
- _Verifier:_ startRecording() launches BOTH the service's wall-clock cap timer (AudioRecordingServiceImpl.swift:86/254, `_ = try? await stopRecording()` discards the file) and the VM's sleep-accumulated cap timer (CheckInViewModel.swift:515/520), both at 480s; the service always crosses first, nils `recorder` in cleanup(), and signals the VM through no protocol member (only audioLevelStream, which never finishes), so the VM's later `try await audioService.stopRecording()` hits `guard let recorder else { throw .unknown }` (L115) and its catch sets state=.idle without ever setting pendingSave (L247) — deterministic silent loss of the full capped recording, with no orphan-file recovery.
- _Disposition:_ device-QA

****#19** `app-four/Services/Audio/AudioRecordingServiceImpl.swift:251` — AudioRecordingServiceImpl runs its OWN 8-minute max-duration timer that auto-stops the recorder and DISCARDS the returned (fileURL, duration) with no callback to the owner; it fires before CheckInViewModel's own cap, orphaning a capped recording.**

- _Failure:_ User records for 8 minutes. Service timer hits totalDuration>=480 first, calls its own stopRecording() -> cleanup() sets recorder=nil and deactivates the session, discarding (url,duration). Seconds later the VM's lagging tick reaches 480 and calls audioService.stopRecording() -> `guard let recorder = recorder else { throw RecordingError.unknown }` throws -> VM catch logs 'Failed to stop recording', sets state=.idle. The VM never received a fileURL (startRecording's was discarded), so pendingSave is never set: the full 8-minute recording is never saved through the pipeline and its temp file is orphaned. Data loss.
- _Fix:_ Remove the service-level startMaxDurationTimer entirely and let CheckInViewModel own the single cap (it already does, tested by reachingCapSavesThroughStopPathToDone); OR give AudioRecordingService an auto-stop AsyncStream/delegate the ViewModel consumes so a service-driven cap still routes through save. Do not keep two independent caps.
- _Verifier:_ AudioRecordingServiceImpl.startRecording() launches an off-main wall-clock startMaxDurationTimer (L86/L251) that at 480s calls its own stopRecording() and discards the result (`_ = try? await stopRecording()`, L256), nulling the recorder via cleanup(); the protocol (Protocols.swift:90) has no auto-stop callback, and CheckInViewModel's tick-accumulated `elapsedTime += 0.1` cap (L515-526) necessarily lags wall-clock so it fires later, then calls audioService.stopRecording() on the nil recorder → throws .unknown → state=.idle (L245-249), orphaning the finalized 8-min file. Production wires the real impl (AppDependencies.swift:10); the cited test uses MockAudioRecordingService, which has no such timer, so the race is untested, not handled.
- _Disposition:_ device-QA

### Raised independently by the cross-check panel

**`app-four/ViewModels/RecordingDetailViewModel.swift:35` — Deleting a check-in from the detail view removes only the SwiftData row and orphans the audio (.m4a) file on disk forever; the sensitive voice recording is never deleted, contradicting the app's on-device privacy posture and 'you control your data' promise.**

- _Failure:_ 
- _Fix:_ Route RecordingDetailViewModel.delete() (and MoodLibraryViewModel.delete) through AudioFileStorageService.deleteRecording, or make RecordingStore.deleteRecording remove the audio file before deleting the row (matching clearAllData). Add a test asserting the .m4a is gone after a single delete.
- _Verifier:_ RecordingStore.deleteRecording (L67-72) only does modelContext.delete + save under a comment claiming the storage service handles file deletion, but never calls it; both single-delete UIs (RecordingDetailViewModel.delete L35, MoodLibraryViewModel.delete L148) use it, so the real recording_<uuid>.m4a orphans on disk. Only clearAllData/DEBUG use the file-deleting AudioFileStorageServiceImpl.deleteRecording; no launch-time orphan sweep exists and cascade rules cover only SwiftData relations, not the audio file.

## 🟡 Medium

| # | Area | File:line | Finding | Fix | Disposition |
|---|---|---|---|---|---|
| 0 | A1 | `app-four/Views/Components/TimelineRow.swift:135` | The day-timeline chip line lowercases the stored focus value before the FocusLevel lookup, which fails for the level-5 value "lockedIn" (rawValue is camelCase), so the focus glyph renders with no level fill; and it shows the raw s | Resolve the enum once and use its own members: `let fl = FocusLevel(rawValue: focus)` then `Chip(kind: .focus, level: fl?.numericValue, text: fl?.displayLabel ?? focus, color: .pri | auto-fixed |
| 4 | A2 | `app-four/Views/Components/ModelDownloadRow.swift:82` | ModelDownloadRow hardcodes Whisper's size/description ('~150 MB', 'transcription model') and reuses it verbatim for the 'Journal Insights' (LLM) row, which is ~740 MB — misstating the download size and model type in both the visib | Add `sizeLabel` and a model-type description (or a full subtitle/a11y string) to ModelDownloadRow's init and pass '~150 MB'/'transcription model' from the Whisper call site and '~7 | auto-fixed |
| 8 | B | `app-four/ViewModels/MedicationBarViewModel.swift:121` | Multiple ViewModels contain persistence logic (fetch/insert/delete/save on ModelContext), violating Constitution VIII which states ViewModels must hold no persistence logic. | Move medication CRUD, AppSettings read/write, and the audioFileName lookup behind RecordingStore (or a small MedicationStore/SettingsStore) so VMs call store methods; or, if the pa | device-QA |
| 14 | C | `app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift:97` | WhisperKit transcription is only serialized WITHIN each driver, not across the three that share the single actor instance; `activeTranscriptionTask?.cancel()` cannot stop an in-flight `kit.transcribe` (the task body never checks T | Serialize transcription at the actor: queue requests (or await the previous activeTranscriptionTask before starting a new one) instead of cancel-and-replace, and add `try Task.chec | device-QA |
| 20 | D1 | `app-four/Services/BackgroundLLMDownloadService.swift:38` | The in-app 'Download over Cellular = off' preference is not enforced for Settings-initiated downloads: the transport never sets allowsCellularAccess=false and the Settings path does not pre-gate the first attempt on the interface. | Gate the first attempt: in ResilientModelDownload.run() (or its callers) call waitForPermittedNetwork()/shouldStartDownload before the initial download() as SquirlApp does; and/or  | device-QA |
| 21 | D1 | `app-four/Services/PendingTranscriptionServiceImpl.swift:87` | The pending-drain transcription path applies no timeout, unlike the interactive paths, so a hung WhisperKit inference hangs the drain and leaves isDraining stuck true, disabling the pending queue for the process lifetime. | Wrap the drain stream consumption in the same TranscriptionTimeoutCalculator-based timeout (task-group race) the ViewModels use, cancelling transcription and marking the recording  | device-QA |
| 22 | D1 | `app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift:145` | Transcription's background task is begun without an expiration handler, so if the background window expires mid-transcription the assertion is never invalidated and the app risks OS termination. | Use beginBackgroundTask(withName:expirationHandler:) and in the handler cancel the active transcription and endBackgroundTask(backgroundTaskID), matching the download service's pat | device-QA |
| 23 | D1 | `app-four/Services/AIModelServiceImpl.swift:43` | AIModelServiceImpl DOES have in-flight dedup (contradicting the SquirlApp comment), but the dedup returns an immediately-finished stream that a resilient RETRY can read as a false success when the prior attempt's cleanup defer has | Have the duplicate-request path either throw (so the retry surfaces) or return the SAME live progress stream instead of a finished one; and/or clear inFlightDownloads synchronously | device-QA |
| 29 | D2 | `app-four/Services/MLXJournalService.swift:117` | The extraction pipeline prints transcript-derived personal-health content — the signals JSON (extracted medication names, mood, emotions, side effects) and the Pass-1 summary paraphrase — to the console in RELEASE builds via an un | Gate all content-bearing AppLogger.log calls behind #if DEBUG (or strip the interpolated payload in Release), and/or migrate AppLogger to os.Logger with `.private` interpolation. A | auto-fixed |
| 30 | D2 | `app-four/ViewModels/RecordingDetailViewModel.swift:146` | The Regenerate path calls applySummary but never calls setMedicationEvents, so regenerating a summary refreshes the summary/medicationInfo string yet leaves the structured MedicationEvent rows and the hasMedication flag stale — th | In performSummarization, after `recording.applySummary(result)` (both the success path line 146 and consider the fallback at 155), call `recording.setMedicationEvents(from: result. | device-QA |
| 31 | D2 | `app-four/Services/NoteExtraction/ExtractionValidator.swift:77` | The sleepHours work-hours guard nulls legitimately-extracted sleep duration for the common phrasing "slept for 8 hours" (and "...for 5 hours straight"), because the onlyWorkOrWake blocklist matches the substring "for 8 hours"/"for | Make the work-hours blocklist context-aware rather than substring-based — e.g. only treat "for N hours" as work/wake when NOT preceded by a sleep verb (slept/sleep/dormi), or drop  | auto-fixed |
| 32 | D2 | `app-four/Services/MLXJournalService.swift:85` | Both LLM passes run inside Task.detached, which does not inherit cancellation. When the caller cancels (ProcessingViewModel.cancelProcessing / a Pending-queue drain cancel), the parent task is cancelled but the detached MLX genera | Run generation as a structured child (async let / task group) or await holder.generateText directly instead of Task.detached so cancellation propagates, and have generateText honor | device-QA |
| 36 | E | `app-four/Models/Recording.swift:6` | The SwiftData schema is not CloudKit-compatible, contradicting an explicit in-code claim of compatibility (and the constitution rule that comment cites). `@Attribute(.unique) var id: UUID` appears on 4 models (Recording:6, ModelMe | Decide the sync stance now. If CloudKit is intended: remove all 4 `.unique` (rely on UUID uniqueness in app logic), make medicationEvents optional, give non-optional attributes sto | device-QA |
| 47 | G | `app-four/Services/Speech/SpeechTranscriptionService.swift:5` | SpeechTranscriptionService (103 LOC) is fully unused (zero references anywhere) yet ships in Release, linking the Speech framework (SFSpeechRecognizer) — and the app declares NSSpeechRecognitionUsageDescription for a speech-recogn | Delete SpeechTranscriptionService; remove the NSSpeechRecognitionUsageDescription purpose string (verify nothing else uses Speech) and confirm PrivacyInfo.xcprivacy + the App Store | device-QA |
| 55 | H | `app-fourTests/Eval/ExtractionEvalTests.swift:63` | 97 ungated tests across 12 files exercise the DEAD legacy NL extraction pipeline (NLNoteExtractor / NLSummarizationService / PersonalLexiconBuilder), while the only regression gate on the LIVE on-device LLM pipeline (MLXExtraction | Delete the 12 NL-pipeline test files together with the dead production code (the chore/remove-dead-nlp branch already stages the prod removal). Keep the live-pipeline tests (Extrac | device-QA |
| 56 | H | `app-four/Services/BackgroundLLMDownloadService.swift:135` | BackgroundLLMDownloadService — the load-bearing ~1GB background LLM download — has zero test coverage, including its pure resume-completeness (isCompleteFile/isCompleteDirectory), atomic staging→final promotion (promote), and repo | Promote isCompleteFile/isCompleteDirectory/parseRepoID/promote to `internal` (or add a testable seam) and add filesystem-only unit tests mirroring WhisperModelIntegrityTests: exact | auto-fixed |
| 57 | H | `app-four/App/AppModelContainer.swift:167` | The ~260-LOC SwiftData store recovery/quarantine logic — the data-loss safety net behind the app's fail-open posture — has zero test coverage, despite being largely pure FileManager-on-URL logic that is unit-testable exactly like  | Add a suite that constructs a fake store trio (default.store/-wal/-shm) in a temp dir and drives quarantine → makeContainer-fails → undoQuarantine, plus recoverInterruptedQuarantin | auto-fixed |

**Medium cross-check additions**

| Area | File:line | Finding | Fix |
|---|---|---|---|
| correctness | `app-four/ViewModels/InsightsViewModel+Signals.swift:232` | The confirmed focus-lowercasing defect (finding #0, scoped to TimelineRow) is replicated in LIVE, higher-impact sites the lens missed: it silently drops every 'Locked In' (focus level 5, the maximum) day from the monthly Insights  | Match focusLevel verbatim (no .lowercased()) everywhere, mirroring RecordingDetailView:137 / applySummary:219: `FocusLevel(rawValue: $0)`. (Energy lowercasing is a harmless no-op s |
| performance | `app-four/Services/ExportService.swift:129` | ExportService serializes the entire journal — fetch + read every audio file into memory + base64 + JSONEncoder.encode (up to ~200MB of audio) — on the MainActor, contradicting its own doc claim that it 'serializes off the main act | Move the JSONEncoder().encode (and ideally the per-file base64) off the main actor — do the SwiftData fetch/DTO mapping on main, then hand the Sendable JournalArchive to a detached |
| data-loss | `app-four/Services/Audio/AudioFileStorageServiceImpl.swift:22` | saveRecording moves the captured temp file to its final location BEFORE the SwiftData save; if context.save() throws after the move, the audio file is orphaned in the recordings dir (no row) AND the capture-retry path is broken be | Insert+save the Recording first (or copy rather than move, deleting the temp only after a successful save); on a post-move save failure, move the file back to the buffer URL so ret |

## 🟢 Low (grouped by category)

**accessibility** (1)

| # | File:line | Finding | Disposition |
|---|---|---|---|
| 1 | `app-four/Views/Components/PlaybackWaveformBars.swift:34` | The waveform is a seek control (tap/drag to seek) exposed to VoiceOver as a single ignore-children element with only a static progress label and no adjustable action, so VoiceOver  | device-QA |

**architecture** (1)

| # | File:line | Finding | Disposition |
|---|---|---|---|
| 9 | `app-four/Views/RecordingDetailView.swift:14` | RecordingDetailView threads store/services both through its init (to seed the @State ViewModel) and via @Environment (for body/child use); the same dependency is injected two ways  | device-QA |

**background-task** (2)

| # | File:line | Finding | Disposition |
|---|---|---|---|
| 13 | `app-four/Services/AIModelServiceImpl.swift:62` | The model-download background-task expiration handler ends the task but neither nulls the identifier nor cancels the work, so the Task's defer calls endBackgroundTask a SECOND time | device-QA |
| 15 | `app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift:146` | beginBackgroundTask is called with no expiration handler, so if background time expires before transcription ends the OS terminates the app without a chance to clean up. | device-QA |

**concurrency** (2)

| # | File:line | Finding | Disposition |
|---|---|---|---|
| 16 | `app-four/ViewModels/RecordingDetailViewModel.swift:88` | retryTask/summaryTask capture self strongly, so `deinit { retryTask?.cancel() }` can never cancel an in-flight task (self is retained by the task until it finishes); a retry transc | device-QA |
| 17 | `app-four/Services/AIModelServiceImpl.swift:27` | Two test-only overrides are exposed on the production @MainActor type as `nonisolated(unsafe) var`, opting out of isolation checking on mutable state; safe today only because produ | device-QA |

**config** (11)

| # | File:line | Finding | Disposition |
|---|---|---|---|
| 7 | `app-four/Views/Feedback/IssueReportView.swift:6` | The feedback subsystem ships into App Store Release as unreachable code: its sole entry point (FeedbackButton) is wholly `#if DEBUG \|\| TESTFLIGHT`, but IssueReportView, MailCompo | auto-fixed |
| 18 | `app-four.xcodeproj/project.pbxproj:296` | The app-fourTests target does not set SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor while the app target does, so unannotated types have different default isolation across targets; combi | device-QA |
| 24 | `app-four/Services/ResumeState.swift:9` | ResumeState's synthesized Equatable conformance is main-actor-isolated under SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor, which is an error in Swift 6 language mode (a Swift 6 migratio | device-QA |
| 35 | `app-four/Services/NoteExtraction/NoteExtraction.swift:6` | The doc comment on NoteExtraction.mood lists MoodLevel raw values as "dark/low/flat/okay/good/high", but the actual MoodLevel enum has no 'dark' or 'high' cases; it is low/flat/oka | auto-fixed |
| 37 | `app-four/Models/Recording.swift:16` | `var cloudSyncStatus: String?` is a dead persisted column: a repo-wide grep finds exactly one occurrence — this declaration — with no reader or writer anywhere in app-four. It is a | device-QA |
| 43 | `DESIGN.md:60` | DESIGN.md has drifted from the code in three places: a stale glyph 'build gap', a phantom .card() modifier, and radius/spacing scales that no longer match the tokens. | auto-fixed |
| 45 | `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/SignalLevel.swift:50` | Two design-system comments misstate where the mood-color SSOT lives. | auto-fixed |
| 50 | `app-four.xcodeproj/project.pbxproj:528` | The project builds in Swift 5 language mode with no strict-concurrency checking, contradicting the constitution's 'Swift 6+ (strict concurrency enabled)'. Doc drift, plus a real Sw | device-QA |
| 52 | `app-four/Utils/MockDataGenerator.swift:5` | MockDataGenerator has no #if DEBUG guard though every call site is DEBUG- or preview-only; 125 LOC of mock-data generation (hardcoded med names) ships in Release. | auto-fixed |
| 53 | `app-four.xcodeproj/project.pbxproj:436` | No warnings-as-errors are enabled in any configuration, so the four Swift-6-mode conformance warnings (and any future warnings) pass silently. | device-QA |
| 54 | `.github/workflows:1` | There is no CI pipeline; the build/test suite is never run automatically on push or PR. | auto-fixed |

**correctness** (6)

| # | File:line | Finding | Disposition |
|---|---|---|---|
| 3 | `app-four/Views/Components/PlaybackWaveformBars.swift:46` | `abs(hasher.finalize())` is a latent trap: abs(Int.min) overflows and crashes. | auto-fixed |
| 5 | `app-four/Views/Components/MedicationBarView.swift:45` | The medication bar's progress is a stale snapshot: it is recomputed only on `.onAppear` and on a dose-change notification — there is no clock-driven refresh anywhere, and the root  | device-QA |
| 11 | `app-four/Store/RecordingStore.swift:78` | RecordingStore's mutating operations swallow persistence errors with `try?`, silently dropping data on non-capture paths (favorite, title, summary/status writes). | device-QA |
| 26 | `app-four/Services/Audio/AudioRecordingServiceImpl.swift:60` | startRecording checks a hardcoded 20 MB disk threshold instead of LayoutConstants.minDiskSpaceForRecordingBytes (50 MB) used by the ViewModel, so the two disk gates disagree. | device-QA |
| 28 | `app-four/Services/Audio/AudioRecordingServiceImpl.swift:160` | Only AVAudioSession.interruptionNotification is observed; there is no routeChangeNotification handler, so mid-recording route changes (headphones/Bluetooth unplug) are unhandled. | device-QA |
| 33 | `app-four/Services/NoteExtraction/UnifiedExtraction.swift:70` | A single malformed medication object in the model's JSON (missing the required "name") throws through the outer decodeIfPresent and fails the entire UnifiedExtraction decode, disca | auto-fixed |

**dead-code** (9)

| # | File:line | Finding | Disposition |
|---|---|---|---|
| 2 | `app-four/Views/Components/Chip.swift:7` | The shared `Chip` component (Chip.topic / Chip.filter) now has zero production references — the current ExtractionReviewView uses chipButton/newLookChip instead of Chip.filter. Onl | auto-fixed |
| 6 | `app-four/Views/Components/RecordingRow.swift:15` | RecordingRow is dead code — it has no production or test call sites; the only references are inside its own #Preview. Its doc comment claims it is 'used by both the Calendar librar | auto-fixed |
| 27 | `app-four/Utils/AudioConverter.swift:20` | AudioConverter.convertToPCM(url:) has zero call sites — a dead placeholder compiled into every build. | auto-fixed |
| 34 | `app-four/Services/Protocols.swift:214` | SummarizationError declares timeout/contextTooLong/parsingFailed/inferenceFailed but the pipeline never throws them (only modelNotInstalled and insufficientMemory are thrown), and  | auto-fixed |
| 40 | `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Radius.swift:12` | Three design tokens are dead: Radius.chip (15), Spacing.ringStroke (3.3), Icons.sideEffect ("bandage.fill"). | auto-fixed |
| 46 | `app-four/Services/NLSummarizationService.swift:5` | The legacy NaturalLanguage extraction pipeline (~1,500 LOC: NLSummarizationService + NLNoteExtractor + CueMatcher + TenseClassifier + PersonalLexiconBuilder) is a member of the app | device-QA |
| 48 | `app-four/wireframes/figma/Calendar.svg:1` | Five Figma design wireframe SVGs are copied into the shipping app bundle, and five wireframe SwiftUI files (486 LOC) compile into the app target unreferenced — internal design sour | auto-fixed |
| 49 | `app-four/Views/TestServicesView.swift:4` | TestServicesView — a debug console (mock-data toggle, service probes, 'Create Fake Recording') — has no #if DEBUG guard and compiles into the Release/App Store binary (RC-30). | auto-fixed |
| 51 | `app-four/Services/Mock/MockTranscriptionService.swift:4` | MockTranscriptionService (41 LOC) has zero references anywhere — not prod, not tests, not previews — yet compiles into the Release binary. | auto-fixed |

**design-conformance** (5)

| # | File:line | Finding | Disposition |
|---|---|---|---|
| 38 | `app-four/Models/Recording+MoodDisplay.swift:62` | Sleep and emotion display-tags use raw SwiftUI system colors (.indigo, .pink) instead of Palette tokens; the sleep chip defeats the deliberate sleepIndigo/medication-purple separat | device-QA |
| 39 | `app-four/Views/CheckIn/TextCheckInComposer.swift:141` | The Type-note ramp picker defaults to the Paper & Pollen bronze ring (Theme.accent) on a New Look surface, diverging from the identical Edit-sheet picker which uses NewLook.checkIn | device-QA |
| 41 | `app-four/Views/CheckIn/CheckInView.swift:246` | The capture flow renders two visibly different greens: the Check-in screen + CrescentRing use Theme.meadowGreen while onboarding, Type-note and the Edit sheet use NewLook.checkInGr | device-QA |
| 42 | `app-four/Views/Onboarding/LLMDownloadView.swift:32` | Onboarding hero glyphs bypass the Metrics.IconSize.hero token with a literal .font(.system(size: 64)). | device-QA |
| 44 | `app-four/Views/Components/AudioPlayerView.swift:50` | Raw .white labels/glyphs on Palette.medication fills bypass NewLook.onSelection, which exists to flip to dark ink in dark mode for AA. | device-QA |

**efficiency** (1)

| # | File:line | Finding | Disposition |
|---|---|---|---|
| 10 | `app-four/Store/RecordingStore.swift:110` | RecordingStore.createCheckInNote re-fetches all recordings redundantly (save() already reloads) and has no production callers — only tests use it; the live text-check-in path is pe | auto-fixed |

**flaky-test** (1)

| # | File:line | Finding | Disposition |
|---|---|---|---|
| 59 | `app-fourTests/ViewModels/CheckInViewModelTests.swift:472` | preloadTaskIsCancelledOnDiscard / preloadTaskIsCancelledOnStopWithinStaggerWindow assert a NEGATIVE (`loadCount == 0`) after a fixed `Task.sleep(100ms)`, which is timing-dependent  | auto-fixed |

**privacy** (1)

| # | File:line | Finding | Disposition |
|---|---|---|---|
| 25 | `app-four/Utils/AppPaths.swift:15` | Sensitive health audio and transcript exports get no explicit FileProtectionType; they rely on the OS default (completeUntilFirstUserAuthentication) rather than protecting data whi | device-QA |

**test-architecture** (1)

| # | File:line | Finding | Disposition |
|---|---|---|---|
| 61 | `app-fourTests/Services/DoseLogServiceTests.swift:14` | 22 suites are `.serialized` and several share a single static in-memory ModelContainer wiped per-test. This is a documented workaround for a SwiftData-under-xcodebuild limitation ( | device-QA |

**test-coverage** (1)

| # | File:line | Finding | Disposition |
|---|---|---|---|
| 58 | `app-fourTests/Services/AudioInterruptionPolicyTests.swift:8` | Two capture-critical services are effectively untested at the behavior level: AudioRecordingServiceImpl is covered only for its pure `interruptionResponse` decision function, and W | device-QA |

**test-quality** (1)

| # | File:line | Finding | Disposition |
|---|---|---|---|
| 60 | `app-fourTests/MLXJournalServiceTests.swift:34` | memoryCheckReturnsValue is near-tautological: it only probes the degenerate 0 / .max bounds of a `>=` comparison and, per its own comment, os_proc_available_memory() returns 0 on t | device-QA |

## Per-lens summary

| Lens | Findings kept | Clean notes |
|---|---|---|
| A1-views-capture | 4 | 16 |
| A2-views-shell | 5 | 13 |
| B-viewmodels-di | 5 | 11 |
| C-concurrency | 10 | 15 |
| D1-services-io | 10 | 13 |
| D2-services-extraction | 7 | 12 |
| E-data-privacy | 5 | 12 |
| F-design-system | 8 | 9 |
| G-deadcode-config | 9 | 6 |
| H-tests | 7 | 8 |

## Prior-audit regression check (2026-06-25 views audit)

**Fully remediated.** All five dead-code files the June audit flagged are gone from `main` (`LibraryViewModel`, `TopicChip`, `SummaryCard`, `Elevation.swift`, `TestSchemaView`), and its one 🔴 correctness bug — `RecordingDetailView` losing its toolbar on the Calendar sheet path — is fixed: both entry points now push through `ScreenContainer`'s `NavigationStack` via `.navigationDestination(for: UUID.self)`, and Delete was moved into the scroll body so it no longer depends on the nav bar at all.

## Verification & false positives

Every finding above was re-opened by an adversarial verifier told to refute by default; findings it marked REFUTED were dropped before this report. The independent false-positive auditor then reviewed all 62 survivors and flagged **0** as overstated. Two lens claims were corrected during verification and are reflected above: the focus-lowercasing bug's "apply the same fix everywhere" guidance is **wrong for `FoldedDayCardHeader:115`** (it derives its label from `FocusLevel.average`, which lowercases internally — a blanket no-lowercase edit would break it); and the CloudKit-compat and dedup findings were re-scoped to match the code.

## Confirmed clean (115 verified)

What the lenses checked and found sound. A representative subset (full list in the run's `clean_list.txt`):

- REGRESSION FIXED (2026-06-25 High #1): RecordingDetailView no longer loses its toolbar on the Calendar path. Both call sites push it via `.navigationDestination(for: UUID.self)` inside ScreenContainer's NavigationStack — InsightsView.swift:32-34 and CalendarLibraryView.swift:47-49 (Calendar taps do `path.append($0)` at :137, no longer a bare `.sheet`). The date title (.principal, :46) and Edit button (.topBarTrailing, :53) always render; Delete was additionally moved into the scroll body (:302), so it never depends on the bar at all.
- RecordingDetailView delete-after-teardown is correct: `.onDisappear { if pendingDelete { viewModel.delete() } }` (:78) with a deferred `Task { @MainActor in dismiss() }` (:84) from the confirmationDialog avoids the documented SwiftData detached-fault trap; the edit sheet (`.sheet(item: $editViewModel)`, :71) and model-missing alert (:87) are wired soundly.
- RecordingDetailView state ownership sound: `@State` VM built in init, `@Environment` for store/services/dismiss; levelBar GeometryReader (:163) is a fixed 4pt bar in ≤3 hero columns — cheap; div-by-5 with `level ?? 0` is safe.
- CheckInView state ownership correct: @State VM, @Binding shouldAutoStart (reset via consumeAutoStart), @Environment MedicationBarViewModel; `.task(id: viewModel.isApproachingCap)` (:169) is structured and cancels with the view; all seven `.alert`s bind to VM booleans; VoiceOver announcements + `.updatesFrequently` live-region timer (:293-300); reduceMotion honored throughout.
- ExtractionReviewView uses a custom NewLookNavBar (:34) so it is correctly NavigationStack-independent as a sheet; @Bindable VM, `.presentationDetents([.large])`, the DurationField local-@State typing buffer (:356-387), and the customHours onChange clearing logic (:246-252) are all sound; chips carry isSelected traits and per-item accessibilityLabels.
- TextCheckInComposer onSave-returns-Bool retry pattern is correct (:100-107 dismiss only on true, else show retry + haptic); TextEditor placeholder overlay with allowsHitTesting(false); close button meets min tap target; SignalScaleRow readout labeled.
- Onboarding flow: WelcomeView owns the single NavigationStack (:31) and is presented via `.fullScreenCover` in SquirlApp.swift:109 (fresh context — no nested stacks); SiriOnboardingView/DownloadPermissionView/LLMDownloadView correctly take the @Observable OnboardingViewModel as plain `let`/`var` properties (reads are tracked; no $bindings needed, so no @Bindable); GeometryReader+ScrollView minHeight centering keeps the CTA reachable at AX Dynamic Type sizes; navigationDestination(isPresented:) chaining and navigationBarBackButtonHidden(isDownloading) are correct; every #Preview wraps in NavigationStack + previewContainer.
- Onboarding download Tasks (`Task { await viewModel.download...(modelContext:) }`) are intentionally unstructured so a download survives view teardown; they inherit MainActor from the view, so passing the non-Sendable ModelContext is safe under the Swift 5 language mode.
- GlyphRampPicker: stable ForEach id (\.numericValue), isSelected trait + per-glyph accessibilityLabel, tokens only.
- CrescentRing: `.id(isActive)` forces child recreation to reset the animation cleanly; reduceMotion yields a nil animation (no infinite spin/breathe); decorative and accessibilityHidden.
- TagFlowView + FlowLayout: FlowLayout is a correct custom Layout (sizeThatFits/placeSubviews consistent, row wrapping sound); ForEach over Identifiable DisplayTag; glyph vs SF-symbol branch with accessibilityHidden on the decorative icon.
- EdgeFadeMask: gradient top/bottom mask modifier is correct and parameterized by measured bar height.
- ADHDSummarySection: renders off decoded model accessors; index-based ids are on freshly-built arrays (no reorder animation); three healthy #Previews (Full / No medication / Empty).
- AudioPlayerView: `.onDisappear { viewModel.cleanup() }` tears down playback; the progress computation guards `duration > 0` before dividing (:20); play/pause button is labeled per state; lives in a non-lazy ScrollView so it is not torn down on scroll.
- Decorative fixed sizes are acceptable: `.font(.system(size: 64))` on onboarding hero icons and `.font(.system(size: Metrics.CheckIn.savedCheck))` on the saved checkmark are SF Symbols marked accessibilityHidden — not Dynamic Type text.
- Dark mode / theming: every view in this lens draws exclusively from NewLook / Theme / Palette / Typography tokens; no hardcoded Color(.sRGB)/black/white text colors found in the capture & review views.
- ScreenContainer NavigationStack + toolbar placement is correct: `.toolbarBackground(.tabBar)` and `.toolbarBackgroundVisibility(.visible, for: .tabBar)` are hoisted onto each tab's NavigationStack root (ScreenContainer.swift:59-60) with a comment explaining they no-op on the TabView — the 2026-06-25 NavigationStack toolbar bug pattern is not present here.
- RootContainerView drain path is sound: the three `.task` blocks (onboarding gate, background download, drainIfModelReady) plus `onChange(of: scenePhase){.active}` correctly drain pending transcription (SquirlApp.swift:111-139); the download task is re-entry-guarded by `downloadKicked`, handles CancellationError quietly, and logs (not surfaces) failures per FR-010.
- Onboarding presentation is correct: `.task` sets `showOnboarding = !hasCompletedOnboarding` once and `.onChange(of: hasCompletedOnboarding){ if completed { showOnboarding = false } }` dismisses on completion; @Query resolves during body evaluation so a returning user does not flash onboarding.
- @Query usage in views is minimal and correct — the only @Query in the lens is RootContainerView.settingsQuery, read via a computed `hasCompletedOnboarding` and for download prefs; all other screens use @Observable ViewModels + @Environment.
- ForEach identity is stable across all list/chart views: MedicationBarView keys by `\.element.eventID`, timeline cards by TimelineDay.id (Date), MoodBubbleChart/MoodLegend by `\.level`, SignalStripsView by `\.kind` and beads by `\.date`, DailyRhythmMatrix by `\.kind`; index/offset ids are used only on genuinely fixed-order arrays (weekday caps, rhythm cells, sticker steps).
- CalendarHeaderView weekday caps ('M T W T F S S', Monday-first) are consistent with CalendarMonthModel's fixed Monday-first construction (`leading = (weekdayOfFirst + 5) % 7`, CalendarMonthModel.swift:44) — not a locale-misalignment bug.
- Calendar timeline scroll/perf is fine: cards live in a LazyVStack, the strip is intentionally eager to drive fade geometry, and `timelineDaysFilteredToSelectedDate` is an O(n) filter over a bounded day list returning Identifiable TimelineDay.
- Encrypted export flow is never gated behind an entitlement (plain Button in journalExportSection, SettingsView.swift:236-251), the recovery key is surfaced only after a successful file write (SettingsView.swift:113-115), is never persisted, and the clipboard copy is `.localOnly` with a 120s expiry (JournalExportSection.swift:60-66) — matches the monetization 'export never gated' and privacy rules.
- Accessibility is thorough across the lens: combined/contained elements, explicit labels/values/hints, `.isSelected`/`.isHeader`/`.isButton` traits, decorative glyphs hidden, and 44pt tap-target floors (CalendarDayCell, DailyRhythmMatrix cells, ghost pills, expand button).
- Dynamic Type and Reduce Motion are honored: @ScaledMetric discs (CalendarDayCell, StickerSetupView), force-collapse to a single week at accessibility1 (CalendarHeaderView.forceWeek), fixedSize wrapping in day-card/insight headers, and every withAnimation is guarded by `reduceMotion ? nil : …`.
- MedicationBarViewModel notification observer uses `[weak self]` and removes its token in deinit (MedicationBarViewModel.swift:42-55) — no retain cycle; the confirmationDialog/sheet bindings in MedicationBarView are correct.
- DoseTrack pulse lifecycle is correct: the repeatForever onset pulse is started/stopped via `onChange(of: onsetPulsing)` rather than latched at onAppear, and collapses to a static fill under Reduce Motion (MedicationBarView.swift:160-173).
- SettingsView My-Medication focus intent is handled correctly with `task(id: router.shouldFocusMyMedication)` (consumes the one-shot, expands the picker, scrolls) and the tab-reset onChange defers to a pending focus (SettingsView.swift:74-92).
- @MainActor @Observable conformance: all 11 real ViewModels are correctly `@MainActor @Observable final class` — CheckInViewModel, ProcessingViewModel, RecordingDetailViewModel, SettingsViewModel, MoodLibraryViewModel, MedicationBarViewModel, MedicationPickerViewModel, ExtractionReviewViewModel, AudioPlaybackViewModel, InsightsViewModel, OnboardingViewModel.
- @Observable seed concern REFUTED: CalendarMonthModel is a value-type `struct` (CalendarMonthModel.swift:14), DayTimeline + DayTimelineBuilder are stateless `enum` namespaces (DayTimeline.swift:5,37), and InsightsViewModel+Signals is an `extension InsightsViewModel` (line 97) on the already-@Observable class — none require @Observable; they are value types / an extension by design, not gaps.
- NotificationCenter + MainActor.assumeIsolated pattern is sound: MedicationBarViewModel:42-49 and MoodLibraryViewModel:115-122 register observers with `queue: .main` and wrap the callback in `MainActor.assumeIsolated`, which is safe because main-queue delivery runs on the main actor's executor; both capture `[weak self]` and remove the token in deinit (MedicationBarViewModel:53, MoodLibraryViewModel:125).
- AudioPlaybackViewModel progress-polling Task lifecycle: the strongly-self-capturing Task (startProgressPolling line 84) is cancelled on pause() (line 61), on the AVAudioPlayerDidFinish delegate (line 103), and on cleanup() — and AudioPlayerView calls viewModel.cleanup() in .onDisappear (AudioPlayerView.swift:32). No retain-cycle leak in normal flow.
- AppDependencies static-let singleton graph: all members are lazy `static let` on a @MainActor enum; interdependencies (store→container.mainContext, transcriptionService→sharedWhisperKitService→diagnosticsStore, services bundle→individual services, pendingTranscriptionService→store+services) resolve correctly regardless of declaration order due to lazy init. Composition-root-only usage is respected (VMs/views pull via @Environment).
- SquirlApp.init composition-root ordering: debugMockMode is read/cleared before `_ = AppDependencies.store` touches the container (SquirlApp.swift:24-38), and App Intent dependencies are registered eagerly (doseLogService, router) before any perform() (lines 44-47) with values captured to avoid MainActor hops — correct per the D11 comment.
- DI injection at the scene root: .modelContainer + .environment(store/medicationBarViewModel/screenTracker/services/router/diagnosticsStore) at SquirlApp.swift:56-63, mirrored exactly in withPreviewEnvironment (PreviewEnvironment.swift:7-15) so previews and production share the same graph.
- OnboardingViewModel injection + fail-open: takes only aiModelService (line 42), exposes an injectable `persist` seam for the save-failure test path (line 38), and sets didComplete even when persist throws (complete() line 46-50) so the cover always dismisses (FR-005). No AppDependencies reference.
- WelcomeView/RecordingDetailView init-injection of services/store to seed their @State ViewModels is the standard SwiftUI idiom (Environment is not readable during init); WelcomeView (WelcomeView.swift:25) injects only, and its call site (SquirlApp.swift:109) feeds the ambient @Environment services.
- Observer cleanup in deinit is present where VMs are per-view/allocated: MoodLibraryViewModel:125, SettingsViewModel:102, MedicationBarViewModel:53 (singleton, deinit effectively never runs but is correct). RecordingDetailViewModel and ProcessingViewModel cancel their tasks (deinit line 26 / cancelProcessing).
- EnvironmentKeys/PreviewEnvironment/View+Tracking helpers are correct: trackScreen modifier reads ScreenTracker via @Environment and sets currentScreen onAppear; DiagnosticsStoreKey supplies a default so views degrade gracefully when the env value is not injected.
- PromptLoader.Cache (@unchecked Sendable, PromptLoader.swift:233) is a correct manual-Sendable: all storage access is guarded by an NSLock (value/set L237-247). Sound.
- BackgroundLLMDownloadService continuation handling is resume-once safe: the CheckedContinuation<URL,Error> is only ever resumed after entries.removeValue gates it (complete L448, cancel L418), and the register/cancel handshake via cancelledIDs (register L374-384, cancel L418-422) closes the pre-registration cancel race. Verified no double-resume and no hang path within a process.
- SpeechTranscriptionService (Speech/SpeechTranscriptionService.swift): requestAuthorization continuation resumes exactly once (L99); the transcribe AsyncStream's multiple continuation.finish() calls are idempotent (AsyncStream, not CheckedContinuation); recognitionTask mutation runs on the actor. Sound (though the type may be dead code — out of lens).
- NetworkConnectivity actor + DispatchQueue (Connectivity/NetworkConnectivity.swift): the DispatchQueue is only NWPathMonitor's callback queue; pathUpdateHandler hops back into the actor via Task (L51-54); interfaceChanges registers/yields-current/unregisters with correct continuation lifetime (L25-33,70-78). No missed-update race. Sound.
- MainActor.assumeIsolated at MoodLibraryViewModel.swift:121 and MedicationBarViewModel.swift:48 are safe: both observers are registered with `queue: .main`, which guarantees main-thread delivery, so the assumeIsolated assertion cannot trip. The 'delivered on the main queue → already on the main actor' comments are accurate.
- ResumeStateStore (actor, ResumeStateStore.swift): all mutations are actor-isolated with atomic file writes (persist L52-73); load/set/remove/removeAll are correctly serialized. Sound.
- MLXJournalService.ModelHolder.loadIfNeeded() in-flight dedup (MLXJournalService.swift:169-180) is correct under actor reentrancy: concurrent callers await the same inFlightLoad task; the local bind survives the defer-nil; failures clear it for retry. The LifecycleCoordinator idle timer arms/cancels correctly (Task.sleep + CancellationError catch, L308-324) and captures only [holder] (no retain cycle back to the coordinator).
- MLXJournalService's 4 Task.detached generation passes (L85,110,128,313) are justified: under SWIFT_APPROACHABLE_CONCURRENCY the nonisolated async methods run on the caller's actor, so detaching is what moves the heavy MLX inference off-main. Cancellation is deliberately not propagated so extraction completes.
- PendingTranscriptionServiceImpl (actor) correctly coalesces concurrent/re-entrant drainIfModelReady() via `guard !isDraining` (L39) and re-resolves @Model objects by UUID on the MainActor at each hop (L57-63,99-114). Its own drains are serialized (cross-driver serialization is the separate WhisperKit finding).
- RootContainerView's three .task blocks + onChange(scenePhase) drain path (SquirlApp.swift:129-139) are safe: all drain entry points funnel into the isDraining-coalesced actor method; the fire-and-forget Task in onChange is harmless because of that coalescing.
- ResilientModelDownload.StallMonitor (actor) uses monotonic ContinuousClock for beat/isStalled — no wall-clock drift or DST hazard. Sound.
- WhisperKitTranscriptionService.loadModel() (L49-81) and AIModelServiceImpl.download() inFlightDownloads dedup (L43-46) both correctly dedup concurrent load/download requests; download() guards context writes behind `!Task.isCancelled` before context.save (L89,100) to avoid writing to a torn-down ModelContext.
- ExportService Task.detached (ExportService.swift:130) is justified: the @Model graph is snapshotted+encoded on the MainActor, then only Sendable Data crosses to the detached task for AES-GCM sealing. Sound.
- No Foundation.Timer/CADisplayLink/DispatchSourceTimer exist anywhere; all periodic work is Task.sleep-based (verified by grep). The checklist's '12 Timer' count is method/property names (startTimer, maxDurationTimer, idle timer), not timer objects — so cancellation is via Task.cancel(), which is wired correctly in CheckInViewModel.stopTasks (L545-561) and MLX LifecycleCoordinator.
- All 8 Task.detached sites accounted for (CheckInViewModel x2, MLXJournalService x4, NLSummarizationService x1, ExportService x1); each moves CPU/GPU/crypto work off the caller's (main) actor and is stored+cancelled where lifecycle requires (modelPreloadTask) or intentionally fire-and-forget for work meant to outlive the view (startRecordingWithDownload).
- ResilientModelDownload.run() retry loop is sound: bounded maxAttempts, CancellationError rethrown without retry, only .noNetwork/.cellularDisabled treated retryable (.insufficientSpace/.other rethrown), and the stall watchdog is a correct throwing-task-group race that cancels the attempt and maps to a retryable failure (ResilientModelDownload.swift:50-146).
- BackgroundLLMDownloadService partial-file/resume handling is sound: per-file staging with isCompleteFile size-skip on resume, atomic whole-directory promote (creating the parent first), 412/416 stale-resume single clean restart (FR-008), and register-BEFORE-resume plus cancelledIDs marker correctly close the fast-completion/cancel races; double-complete is guarded by removeValue (BackgroundLLMDownloadService.swift:54-115,167-256,366-473).
- URLSession resume validators are handled by URLSession itself (the resumeData blob) and the 412/416 clean-restart path, so the unused app-level etag/lastModified/totalBytesExpected fields on ResumeState are harmless metadata, not an integrity hole.
- ResumeStateStore is correct: actor-isolated mutations, .atomic writes, deletes the file when empty, and load() tolerates corrupt/missing JSON by resetting in-memory state (ResumeStateStore.swift).
- NetworkConnectivity is sound: NWPathMonitor off-main adapter, per-subscriber continuations keyed by UUID with onTermination unregister, change stream dedups identical interfaces, and shouldStartDownload(overCellular:interface:) is a correct, testable pure decision (NetworkConnectivity.swift, Protocols.swift:9-44).
- PendingTranscriptionServiceImpl serializes the single WhisperKit engine correctly: isDraining coalesces re-entrant drains, recordings cross the actor hop by UUID and are re-resolved on the MainActor so a deleted @Model is skipped rather than crashing, and the model-deleted-mid-drain guard stops the loop (PendingTranscriptionServiceImpl.swift:37-114).
- WhisperKit peak-shaving order is correct: unloadModel() (whisperKit=nil) runs BEFORE continuation.finish() on both success and error, so Metal/CoreML buffers are released before downstream LLM extraction begins (WhisperKitTranscriptionService.swift:172-201).
- AudioRecordingServiceImpl interruption policy is sound and unit-tested via the pure interruptionResponse(): .began while recording -> pause, .ended + .shouldResume -> resume, .ended without -> stay paused; it never stops/discards on interruption, preserving the in-progress recording (AudioRecordingServiceImpl.swift:177-249).
- AIModelServiceImpl treats the filesystem as source of truth: localPath validates config.json + tokenizer.json + a .safetensors for the LLM and AudioEncoder weights + config for Whisper, and it guards every ModelContext write behind !Task.isCancelled so a torn-down context is never touched after a cancelled download (AIModelServiceImpl.swift:88-92,242-297).
- Model-download error surfaces are content-free per privacy: ModelDownloadFailure and classify() derive only the condition (network/disk/cellular) with a short type tag for .other, and userMessage strings carry no transcript or medication data (Protocols.swift:142-165, AIModelServiceImpl.swift:117-139).
- ComputeEnvironment's compute-unit selection (development-signed/simulator -> cpuAndGPU; distribution -> cpuAndNeuralEngine) is correct and well-reasoned for the ANE-compiler-over-developer-tunnel hang (ComputeEnvironment.swift).
- TranscriptionTimeoutCalculator is a correct thermal-scaled pure function and IS wired into the interactive transcription paths (CheckInViewModel.swift:319, RecordingDetailViewModel.swift:91), refuting any 'transcription has no timeout' concern for the interactive flow.
- AppPaths correctly isolates health data under Application Support (not Documents, invisible to Files/iTunes) and sets isExcludedFromBackup on the private root; ModelConstants' library paths and the legacy llama->llm one-shot migration are sound (AppPaths.swift, Constants.swift:14-43).
- App Intent dependency registration timing is correct: SquirlApp.init (App/SquirlApp.swift:44-47) eagerly captures doseLogService and appIntentRouter into locals and registers them via AppDependencyManager.shared.add(dependency:) at the end of init, before any perform(); the eager local capture avoids the @Sendable autoclosure hopping back to the MainActor accessors. LogDefaultDoseIntent/StartCheckInIntent resolve these via @AppDependency.
- DoseLogServiceImpl.logDefaultDose (Services/DoseLog/DoseLogServiceImpl.swift:18-64) is correct and defensive: it fails CLOSED on a guard-history read error (returns .failed rather than bypassing the guard), withdraws the orphaned insert (context.delete(event)) if persist() throws so mainContext autosave can't turn a reported failure into a silent double-log, and mostRecentDose filters taken==true && isMockData==false.
- Export is never gated: SettingsViewModel.exportJournal (ViewModels/SettingsViewModel.swift:240-242) and ExportServiceImpl.export (Services/ExportService.swift:124-133) contain no PurchaseService/entitlement check. AES-GCM seal uses a fresh per-export SymmetricKey that is never persisted (ExportService.swift:217-224), the DTO maps the full Recording graph including audio base64, and a 200MB in-memory guard (ExportService.swift:145-149) throws audioTooLarge instead of risking OOM.
- PromptLoader prompt cache is thread-safe: the static Cache (PromptLoader.swift:233-248) is @unchecked Sendable guarding a [String:String] with an NSLock on both value(for:) and set(value:for:).
- Validator clamps mood/energy/focus/sleepQuality to valid Levels rawValues: normalize() (ExtractionValidator.swift:569-575) returns an exact canonical rawValue, a synonym mapping, or nil; and every hardcoded literal assigned in the deterministic cue-recovery blocks (steps 1-21) is a valid rawValue — mood {low,flat,okay,good,great}, energy {sluggish,tired,steady,alert,charged}, focus {foggy,distracted,present,sharp,lockedIn}, sleep {restless,light,okay,good,deep} per Levels.swift.
- Two-pass flow is correct: Pass 1 (summary) owns the summary field and Pass 2 (signals) owns signals; merge is `merged.summary = summaryText ?? extraction?.summary` (MLXJournalService.swift:61-62); Pass 2 has a 3-stage JSON recovery plus one correction-prompt retry (MLXJournalService.swift:121-141); all failures are non-fatal with graceful fallback to raw transcript as the summary bullet (ExtractionValidator.swift:855-861).
- ModelHolder load ordering is sound: loadIfNeeded (MLXJournalService.swift:169-180) dedups concurrent loads via inFlightLoad; performLoad refuses to trigger an implicit hub download (throws modelNotInstalled if AIModelServiceImpl.findLLMModelDirectory returns nil, :186-191) and checks memory headroom (:193-196); evict() guards !isGenerating (:230-233) and the LifecycleCoordinator re-arms when eviction is deferred mid-generation (:336-340).
- Prompts.yaml and lexicon.json DO ship despite being absent from project.pbxproj: the project is objectVersion 77 using PBXFileSystemSynchronizedRootGroup (Xcode 16 synchronized folder groups), so individual Resources files are not listed by design; lexicon.json loads at runtime and the baseline build/tests are green, confirming the folder is bundled.
- Intents are correctly thin: LogDefaultDoseIntent/StartCheckInIntent delegate all domain logic to DoseLogService/AppIntentRouter (Constitution VIII); the onboarding gate (requestCheckIn returns .gatedOnboarding) and one-shot consumption (consumeCheckIn/consumeMyMedicationFocus with defer-clear) live in AppIntentRouter, and DoseConfirmationCopy never emits journal content beyond the just-logged fact.
- Three of four applySummary call sites correctly pair setMedicationEvents (ProcessingViewModel, PendingTranscriptionServiceImpl, ExtractionReviewViewModel); only the Regenerate path omits it (reported as a finding).
- NoteExtraction custom decoder (NoteExtraction.swift:101-130) tolerates the last-added 'appointments' key and all trailing optionals via decodeIfPresent, so recordings persisted before 'appointments' still decode instead of nulling the whole extraction under Recording's try?.
- Baseline is green: ** BUILD SUCCEEDED ** and ** TEST SUCCEEDED ** in baseline.log; the one extraction-related test (pipelineMarksRecordingFailedWhenSummarizationThrows) passes.
- Relationship graph is correct: Recording.swift:52-59 declares three .cascade relationships whose inverses all exist — TranscriptionSegment.recording (L14), RecordingTag.recording (L27), MedicationEvent.recording (L29). Deleting a Recording correctly cascades to its segments/tags/med-events; standalone manual doses (recording == nil) are unaffected.
- Migration-stability: every enum persisted in a @Model is String-backed Codable (AppEnums.swift RecordingStatus/SummaryStatus/AIModelType etc.; MedicationEvent.Source; MedEventChange). String raw values are stable across builds (no integer-ordinal fragility). Baseline build + 544 tests pass, so the schema is valid.
- SquirlMigrationPlan is correctly wired: AppModelContainer.swift:35 passes `migrationPlan: SquirlMigrationPlan.self`; the plan has a single V1 schema and empty stages, which is correct for one version. The forward-looking V2/MigrationStage design is documented in SquirlSchema.swift.
- Backup exclusion covers the entire sensitive subtree. AppPaths.swift:18 excludes privateRoot (Application Support/SquirlData); Recordings/Exports/Diagnostics are subdirectories and inherit the exclusion. AppModelContainer.swift:38 additionally excludes the SwiftData store directory. The raw audio (voice) is therefore excluded from iCloud/Finder backup — refuting a suspected gap.
- isExcludedFromBackup is effectively applied per launch: both exclusions run in lazy static-let initializers (AppPaths.privateRoot, AppModelContainer.container) on first access each process, and the resource-value attribute persists on disk. privateRoot is touched at launch via StorageMigration.run() before any store/recording read.
- SessionSnapshot (Diagnostics) is deliberately PII-free — documented 'intentionally NEVER includes transcript text, summary text, or audio file paths'; fields are thermal state, available memory, durations, token-count *estimates* (not content), OS/build, screen name. DiagnosticsStore persists only these to an app-sandbox JSON (rolling 50). No health content in diagnostics.
- StorageMigration is idempotent and file-by-file with careful dir-vs-file collision handling (.legacy aside) and mtime tie-breaking; it runs as the first statement of SquirlApp.init (SquirlApp.swift:16) before AppDependencies.store and before the modelContainer is attached — correct ordering, no DB rows change (only audio files move by name).
- Container recovery never destroys release data: the quarantine path renames (never deletes) the store trio, undoQuarantine restores it, a crash mid-cycle self-heals via the pending marker on next launch, and the in-memory fallback is a last resort. The destructive wipe-and-retry is gated `#if DEBUG`; MockDataGenerator seeding is gated `#if DEBUG && !underTest` — no mock data or wipes in Release.
- Info.plist / pbxproj config: NSMicrophoneUsageDescription is present (INFOPLIST_KEY_NSMicrophoneUsageDescription) so mic access won't crash; the whispernotes:// URL scheme is registered in INFOPLIST_KEY_CFBundleURLTypes and matches the onOpenURL handler (SquirlApp.swift:69) — the deep link is wired, not orphaned.
- Privacy manifest is internally consistent for the required-reason APIs used: DiskSpace (E174.1) matches the `.systemFreeSize` reads (AIModelServiceImpl:13, AudioFileStorageServiceImpl:105, AudioRecordingServiceImpl:267); no SystemBootTime/systemUptime API is used (correctly undeclared); NSPrivacyTracking=false and empty NSPrivacyCollectedDataTypes are consistent with the on-device-only, no-network-of-user-content design.
- Logging is centralized: zero bare print() calls exist outside Utils/Logger.swift — every log goes through AppLogger. The defect is the content at 4 MLXJournalService sites plus the print() mechanism, not scattered ad-hoc logging. MetricManager logs only aggregate MetricKit metrics and app-own call stacks (no user content).
- isMockData columns (Recording:38, MedicationEvent:25) are defaulted-false and honored only by DEBUG mock filtering; SquirlApp.init clears the debugMockMode UserDefaults key in Release (SquirlApp.swift:35) so real data is never hidden after a Debug->Release transition.
- Typography = native SF app-wide (spec 023 reversal fully realized in code): zero Font.custom / Fraunces / DM Sans / IBMPlex / SquirlFonts / UIAppFonts anywhere in app-four; Typography.swift routes every role through UIFontMetrics(forTextStyle:).scaledFont so custom point sizes still respond to Dynamic Type.
- New Look (spec 033) adoption is complete: every screen and sheet grounds on NewLook.screen (ScreenContainer for all four tabs, SettingsView, ExtractionReviewView, RecordingDetailView, MedicationLogSheet, TextCheckInComposer, JournalExportSection, CalendarLibraryView, all onboarding views); 29 .newLookCard() calls and zero old .card() calls in Views; no dangling removed Paper&Pollen tokens (Theme.paper/surface/ink, Palette.paper/ink/hairline).
- Haptics are fully tokenized: no direct UIFeedbackGenerator / notificationOccurred / impactOccurred / selectionChanged anywhere outside Haptics.swift; 9 Haptics.* call sites.
- Glyph language is correctly centralized: SignalGlyph is the single render surface, maps all five GlyphSignal cases to Canvas/GeometryReader Shapes (Sprout/Bolt/Aperture/Bed/Capsule), owns the VoiceOver label via signalAccessibilityLabel, clamps out-of-range levels via clampedSignalLevel, and renders a dashed EmptySignalGlyph for an absent level rather than a misleading level-1 (FR-015). 16 call sites across Insights/Extraction/RecordingDetail/RecordingRow/TagFlowView/GlyphRampPicker/etc. SF Symbols appear only for non-signal chrome (tab icons, the 'AI' sparkles affordance, the medication hub icon).
- Signal color ramps are sound: energy/focus hexes in Palette+Signals.swift match DESIGN.md; SignalLevel provides one shared fillGradient/bubbleFill (no hand-rolled per-view gradients); MoodLevel+Palette.swift is the single mood SSOT with per-appearance AA-tuned wordColor; energyRampPartner/focusRampPartner are used (via SignalLevel), not dead.
- Spacing/radius token adoption is strong: 341 Spacing./Radius./Metrics. token uses in Views vs 14 literal .padding and 36 literal spacing: — and nearly all of those literals are spacing: 0 (legitimate 'no gap') or data-viz micro-spacing (1/2/4/6 in gauges/matrices/charts); none of DESIGN.md's explicitly-banned numbers (14/18/26/34) appear.
- Motion is mostly tokenized: 23 Motion.* uses; the only 3 inline animation curves are bespoke (medication kicking-in pulse, saved-state pop spring, prompt-progress bar) and CrescentRing honors accessibilityReduceMotion.
- Documented contrast limitations are owner-accepted, not new bugs: NewLook.inkSecondary #8A8A8E (light-mode AA fail) and NewLook.selection #54B492 used as chip label text (Chip.swift:58, ~2.52:1) both match the DESIGN.md Decisions-Log rulings of 2026-07-12 and 2026-07-16.
- Color literals are otherwise absent from Views: no inline Color(hex:) or Color(red:...) in app-four/Views; the only raw system color is .red in TestServicesView (a debug surface, out of this lens); other white/black uses are the sanctioned text-on-coloured-fill pattern (SignalLevel.swift:11).
- MedicationBarOverlay is LIVE, not dead — REFUTES the seed. The public modifier `.medicationBarOverlay()` (MedicationBarOverlay.swift:33) is called from ScreenContainer.swift:79 and :82 (the single shared placement) and RecordingDetailView.swift:40. Both are core shipping screens.
- ExtractionValidator, UnifiedExtraction, Lexicon, LexiconData, LexiconLoader, and PersonalLexicon are LIVE (not dead) — used by the on-device LLM path: MLXJournalService.swift (validate/assembleSummaryResult/parseExtraction, loadBundled), ProcessingViewModel.swift:79/85 and RecordingDetailViewModel.swift:155 (fallbackResult), SignalPromptBuilder/PromptLoader. This matches CLAUDE.md's 'decoded through ExtractionValidator'. The dead-NL removal must preserve these files (they share the NoteExtraction/ folder).
- Stable bundle-id config drift: REFUTED as an active bug. All twelve XCBuildConfiguration blocks were read. Project-level Debug (pbxproj:371-434) is byte-identical to Debug-Stable (:571-634), and Release (:436-493) to Release-Stable (:636-693). App-target Debug/Release vs Debug-Stable/Release-Stable differ only in ASSETCATALOG_COMPILER_APPICON_NAME (AppIcon vs AppIcon-Stable), PRODUCT_BUNDLE_IDENTIFIER (squirl-app.app-four vs .stable) and CFBundleDisplayName (Squirl vs 'Squirl Stable') — the intended sibling-install pattern. Test-target's four configs are identical. Residual risk is only the maintenance surface of four hand-duplicated configs; no live drift today.
- Dependency pin risk: largely REFUTED. Package.resolved is committed at app-four.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved and pins exact revisions (mlx-swift 0.29.1, whisperkit 1.0.0, swift-collections 1.5.1, yams 5.4.0, etc.), so normal builds are reproducible. The loose `upToNextMajorVersion` ranges (WhisperKit 1.0.0, pre-1.0 mlx-swift 0.29.1) only bite on an explicit 'Update to Latest Package Versions'.
- Only two native targets exist (app-four app + app-fourTests). Info.plist is the sole membershipException on the app target's synchronized folder, which is correct — it is referenced via INFOPLIST_FILE (pbxproj:505) and must not be compiled.
- Baseline is green: BUILD SUCCEEDED and TEST SUCCEEDED — 544 tests in 70 suites passed. The only non-vendored warnings are the four ResumeState Equatable Swift-6-mode conformance warnings (test code); the other 39 warnings are vendored mlx-swift C++17 metal-kernel warnings, out of scope.
- No test performs live network I/O. ResilientModelDownloadTests drives the retry/backoff/stall/cancel loop entirely through an injected AttemptScript + DownloadAttempt closure (ResilientModelDownloadTests.swift:33-63), MockAIModelService yields a scripted AsyncThrowingStream, and the HF tree/resolve URLSession calls (BackgroundLLMDownloadService.fetchTreeEntries) are never reached from any test. grep for URLSession(/data(for:/downloadTask against a real host is empty (the only `downloadTask` match is a local `Task {}` wrapping the mock stream).
- Filesystem tests are collision-safe under parallel/serialized execution: ResumeStateStoreTests, DiagnosticsStoreTests, WhisperModelIntegrityTests, AIModelServiceImplTests and StorageMigrationTests each build a unique per-call directory (UUID under temporaryDirectory/NSTemporaryDirectory) and clean up with defer removeItem.
- MLXJournalServiceTests never triggers an implicit ~740MB model download or a real load in CI: empty/whitespace transcripts short-circuit to 'Empty Note' before any load, and the lifecycle/eviction tests use MLXJournalService(idleEvictionInterval:notificationCenter:) + modelHolder.markLoadedForTesting(); eviction is observed with a bounded poll (waitForEviction, 100×20ms) rather than a fixed sleep, and the re-arm test asserts task cancellation deterministically instead of racing a wall clock.
- Mocks conform faithfully to their production protocols including error and cancellation paths: MockSummarizationService covers insufficientMemory/modelNotInstalled/inferenceFailed and a cancellable hang; MockTestTranscriptionService/MockAudioRecordingService/MockAIModelService implement the full protocol surface (loadModel, cancelTranscription, download stream with onTermination cancel, delete). MockAIModelService deliberately mirrors the real impl's nonisolated filesystem-as-truth accessors (status/localPath).
- EvalCounts precision/recall vacuous-1.0 on empty denominators (EvalMetrics.swift:36-37) is intentional, unit-covered by EvalMetricsTests.emptyDenominatorsAreOne, and does not distort the real regression floors because they aggregate over the full EvalSet where per-category tp+fp and tp+fn are non-zero.
- The MLX eval gate logic is correct: MLXEvalGate.isEnabled requires MLX_EVAL=1 AND findLLMModelDirectory != nil, so the ~15-20 min on-device inference suite cannot run (or burn CI time) by accident; filtered subset runs (MLX_EVAL_FILTER, used by the -smoke plan) correctly skip the P/R floors and run only the deterministic hard-gate assertions.
- Diagnostic tests that use Issue.record(Comment(...)) to dump a report (ExtractionEvalTests.report, Gate0DiagnosticTests.anisotropyAndSeparation) are correctly env-gated (EVAL_REPORT=1 / GATE0=1) and do not run in the default plan, so their always-records-an-issue behavior does not affect the baseline result.
- ExtractionValidatorTests, UnifiedExtractionTests, PromptBuilderTests, SummaryResultAssemblyTests and LexiconDataTests were checked and correctly test LIVE code — ExtractionValidator.parseExtraction/validate/assembleSummaryResult and LexiconLoader.loadBundled are on the MLXJournalService path — so they are NOT part of the dead-NL false-coverage set.

## Auto-fixed this run — `fix/audit-safe-cleanup` (PR, not merged)

10 findings were fixed autonomously and are on the `fix/audit-safe-cleanup` branch. Scope was deliberately limited to changes a build and the test suite can fully verify without a device: dead-code deletion, debug-surface gating, the PHI-logging privacy gate, a pure-function overflow hardening, and comment fixes. **Verified: Debug build + 544 tests pass, and a Release simulator build succeeds** (the Release build caught and forced a correction to the preview-container gating). Nothing was merged — device QA is the owner's gate.

| # | Change | Files | Category |
|---|---|---|---|
| 2 | Delete orphaned shared `Chip` component (zero prod refs) | `Views/Components/Chip.swift` | dead-code |
| 6 | Delete orphaned `RecordingRow` (zero refs) | `Views/Components/RecordingRow.swift` | dead-code |
| 51 | Delete unused `MockTranscriptionService` (zero refs) | `Services/Mock/MockTranscriptionService.swift` | dead-code |
| 27 | Delete dead `AudioConverter.convertToPCM` (kept the used error enum + `getDuration`) | `Utils/AudioConverter.swift` | dead-code |
| 49 | Gate the debug console in `#if DEBUG` (**closes RC-30**) | `Views/TestServicesView.swift` | config |
| 52 | Gate mock-data generator in `#if DEBUG`; gate its call inside `previewContainer` so Release still compiles (**RC-30**) | `Utils/MockDataGenerator.swift`, `App/AppModelContainer.swift` | config |
| 7 | Gate the feedback subsystem in `#if DEBUG \|\| TESTFLIGHT` to match its only entry point | `Views/Feedback/{IssueReportView,MailComposeView,ScreenshotCapture,ShareSheetView}.swift` | config |
| 29 | Gate the three transcript/medication-bearing log lines in `#if DEBUG` (privacy) | `Services/MLXJournalService.swift` | privacy |
| 3 | Replace `abs(hasher.finalize())` with `.magnitude % 1000` (removes an `Int.min` overflow trap) | `Views/Components/PlaybackWaveformBars.swift` | correctness |
| 35 | Correct the `MoodLevel` raw-value comment (`dark/…/high` → `low/flat/okay/good/great`) | `Services/NoteExtraction/NoteExtraction.swift` | config |

**Deliberately NOT auto-fixed (reported for the owner):** the two 🔴 data-loss/privacy bugs and every 🟡 that changes runtime behavior or view output (recording-cap race, orphaned-audio-on-delete, save-before-move, LLM cancellation, focus level-5 in Insights/TimelineRow, download/transcription hardening). Also held back as owner decisions: the `SummarizationError` unused-case removal (public error type on a load-bearing protocol), the `RecordingStore.createCheckInNote` deletion (touches tests), the wireframe bundle exclusion (needs a project-file membership change), the design-system token prune and `DESIGN.md` sync (owner-curated), and the CI workflow (can't be validated here — a ready-to-use file is in the run STATUS). The focus-lowercasing fix specifically must be applied per-site, not as a blanket edit (see Verification note).

## Recommended fix order

1. **🔴 Recording-cap data loss** (`CheckInViewModel` / `AudioRecordingServiceImpl`) — make the recorder the single source of truth for the 480 s cap and route its auto-stop through the normal save path. Needs device QA (audio session).
2. **🔴 Orphaned audio on delete** — route `RecordingStore.deleteRecording` through `AudioFileStorageService.deleteRecording` (or delete the file first), add a test asserting the `.m4a` is gone. Privacy-critical.
3. **🟡 Save-throw orphan + broken retry** (`AudioFileStorageServiceImpl:22`) — insert+save before moving the temp file, or move it back on failure.
4. **🟡 Extraction cancellation** (`MLXJournalService:85`) — the detached LLM passes ignore cancellation; wrap so caller-cancel actually stops generation.
5. **🟡 Focus level-5 dropped from Insights** (`InsightsViewModel+Signals:232/340`) — match `FocusLevel(rawValue:)` verbatim (no `.lowercased()`), and fix `TimelineRow:135` — but NOT via the blanket edit (see Verification note).
6. **🟡 Cellular-off not enforced / no drain timeout / background-task expiration** (`BackgroundLLMDownloadService`, `PendingTranscriptionServiceImpl`, `WhisperKitTranscriptionService`) — load-bearing download/transcription hardening; device QA.
7. **Merge the safe-cleanup PR** (below) after device QA, then land `chore/remove-dead-nlp` and add the missing tests for `BackgroundLLMDownloadService` and the store-recovery logic.

## Proposed backlog tickets (not added to the board)

- **AUD-01 (P0):** Fix the 480 s recording-cap data-loss race. _(high, device QA)_
- **AUD-02 (P0):** Delete the audio file on single-delete; add regression test. _(high, privacy)_
- **AUD-03 (P1):** Save-before-move in `AudioFileStorageServiceImpl` + retry recovery. _(medium)_
- **AUD-04 (P1):** Cancellation-correct LLM extraction. _(medium)_
- **AUD-05 (P1):** Focus level-5 in Insights + TimelineRow (careful per-site fix). _(medium)_
- **AUD-06 (P2):** Download/transcription hardening trio (cellular, timeout, bg expiration). _(medium)_
- **AUD-07 (P2):** Tests for `BackgroundLLMDownloadService` + store recovery; delete the 97 dead-NL tests with `chore/remove-dead-nlp`. _(medium)_
- **AUD-08 (P3):** Delete `SpeechTranscriptionService` (unused, links Speech framework in Release). _(medium)_
- **AUD-09 (P3):** CI pipeline running the test plan on PRs (constitution II). Ready-to-use workflow in the run's STATUS. _(low)_
- **AUD-10 (P3):** Design-system token prune + `DESIGN.md` sync (owner-curated; not auto-applied). _(low)_
