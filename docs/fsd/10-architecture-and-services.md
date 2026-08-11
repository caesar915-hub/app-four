<!-- Created: 2026-07-27 15:10 (WEST) · Updated: 2026-07-27 15:10 (WEST) -->
# 10 · Architecture & Services

Documents branch `main` @ `43eb6515a63a0eca957a79aad257da380c73edd4`. Sibling documents: [Settings & Data Management](08-settings-and-data.md) · [Data Model](09-data-model.md) · [Non-Functional Requirements](11-nonfunctional.md).

## Purpose

Describe the application's runtime architecture as built: the composition root, environment-based dependency injection, the service protocol layer and its implementations, the repository (`RecordingStore`), and the two local SwiftPM packages (`SquirlDesignSystem`, `SquirlSignals`). Architectural decisions are recorded ADR-style (context → decision → consequence), with a component diagram.

## Component overview

```mermaid
graph TD
    subgraph App["App layer"]
        SA["SquirlApp (@main)<br/>startup, environment injection,<br/>deep links, intent triggers"]
        AD["AppDependencies<br/>(composition root, static singletons)"]
        AS["AppServices<br/>@Observable environment bundle"]
        AMC["AppModelContainer<br/>ModelContainer + recovery ladder"]
    end

    subgraph Store["Store layer"]
        RS["RecordingStore<br/>@Observable repository"]
        MBVM["MedicationBarViewModel"]
    end

    subgraph Services["Service layer (protocols)"]
        AR["AudioRecordingService<br/>→ AudioRecordingServiceImpl"]
        FS["AudioFileStorageService<br/>→ AudioFileStorageServiceImpl"]
        TR["TranscriptionService<br/>→ WhisperKitTranscriptionService (shared)"]
        AI["AIModelService<br/>→ AIModelServiceImpl"]
        SU["SummarizationService<br/>→ NLSummarizationService"]
        CO["Connectivity<br/>→ NetworkConnectivity (actor)"]
        PT["PendingTranscriptionService<br/>→ PendingTranscriptionServiceImpl (actor)"]
        EX["ExportService<br/>→ ExportServiceImpl"]
        DL["DoseLogService<br/>→ DoseLogServiceImpl"]
    end

    subgraph Platform["Platform & packages"]
        SD[("SwiftData store<br/>Application Support,<br/>backup-excluded")]
        DG["DiagnosticsStore (actor)<br/>MetricManager · ScreenTracker"]
        DS["SquirlDesignSystem<br/>(tokens + glyphs + components)"]
        SG["SquirlSignals<br/>(level enums, leaf module)"]
    end

    SA --> AD
    SA --> AMC
    AD --> RS
    AD --> AS
    AS --> AR & FS & TR & AI & SU & CO & PT & EX
    AD --> DL
    AD --> DG
    RS --> SD
    FS --> SD
    AMC --> SD
    DS --> SG
    SA -.->|@_exported| DS
    PT --> TR & SU & AI
```

## ADR-01 — Composition root owns all singletons; views never see the locator

**Context.** The app needs shared, long-lived services (audio, transcription, storage, AI model, summarization, connectivity, pending-transcription drain, export) plus shared stores, and SwiftUI views need them without reference cycles or hidden globals.

**Decision.** `AppDependencies` (`@MainActor enum`, `app-four/Store/AppDependencies.swift:6-7`) is a "global dependency locator — used ONLY at the composition root (App/ and Store/). Views and ViewModels receive their dependencies via SwiftUI Environment." It holds static singletons:

| Singleton | Type / implementation | Source |
|---|---|---|
| `store` | `RecordingStore(context: AppModelContainer.container.mainContext)` | `AppDependencies.swift:8` |
| `medicationBarViewModel` | `MedicationBarViewModel` | `:9` |
| `audioService` | `AudioRecordingService` → `AudioRecordingServiceImpl()` | `:10` |
| `storageService` | `AudioFileStorageService` → `AudioFileStorageServiceImpl(context:)` | `:11` |
| `transcriptionService` | `TranscriptionService` → shared `WhisperKitTranscriptionService(diagnosticsStore:)` (private `sharedWhisperKitService`) | `:12`, `:49-51` |
| `aiModelService` | `AIModelService` → `AIModelServiceImpl(context:)` | `:13` |
| `diagnosticsStore` | `DiagnosticsStore()` | `:14` |
| `screenTracker` | `ScreenTracker()` | `:15` |
| `appIntentRouter` | `AppIntentRouter(isOnboardingComplete:)` — reads live `AppSettings.hasCompletedOnboarding` at call time | `:18-23` |
| `doseLogService` | `any DoseLogService` → `DoseLogServiceImpl()` — "consumed only by `LogDefaultDoseIntent`, never by the in-app Log Dose sheet" | `:26` |
| `summarizationService` | `SummarizationService` → `NLSummarizationService()` | `:27` |
| `connectivity` | `Connectivity` → `NetworkConnectivity()` | `:28` |
| `pendingTranscriptionService` | wires store + transcription + summarization + aiModel services | `:29-34` |
| `exportService` | `ExportService` → `ExportServiceImpl()` | `:35` |
| `services` | `AppServices(...)` bundle of the eight environment services | `:38-47` |

**Consequence.** One construction site; startup order is explicit (`SquirlApp.swift:11-42`: storage migration → DEBUG mock-mode default / release key cleanup → touch store → MetricManager → AppDependencyManager registration of `doseLogService` + `appIntentRouter`, captured eagerly because a background intent launch runs init first). Testing seams exist per-service via protocol substitution at the composition root.

## ADR-02 — Environment bundle (`AppServices`) instead of passing the locator

**Context.** ViewModels need services but must not reference `AppDependencies` directly.

**Decision.** `AppServices` (`@Observable @MainActor final class`, `app-four/Store/AppServices.swift:9`) is a plain holder for the eight services: `audioService`, `storageService`, `transcriptionService`, `aiModelService`, `summarizationService`, `connectivity`, `pendingTranscriptionService`, `exportService`. It is injected via `@Environment(AppServices.self)` at the root alongside the store, medication-bar VM, screen tracker, router, and `\.diagnosticsStore` (`SquirlApp.swift:50-57`).

**Consequence.** `RecordingStore.preview` / `AppServices.preview` alias the shared production instances ("no extra allocation", `Store/PreviewSupport.swift`), and `View.withPreviewEnvironment()` (`Utils/PreviewEnvironment.swift:7`) gives `#Preview` blocks the full graph.

## ADR-03 — Protocol-oriented service layer

**Context.** Services cross actor boundaries (audio capture on the main run loop, transcription on an actor, connectivity on an `NWPathMonitor` queue) and need mockability.

**Decision.** Every service sits behind a `Sendable` protocol. Seven protocols live in `app-four/Services/Protocols.swift`; `ExportService` lives with its implementation (`Services/ExportService.swift:116-121`); `DoseLogService` lives in `Services/DoseLog/DoseLogService.swift:21-26`. Supporting DTOs/enums (`NetworkInterface`, `TranscriptionSegmentDTO`, `ModelDownloadFailure`, `SummaryResult`, `SummarizationError`) are defined beside the protocols.

**Consequence.** There is **no runtime provider switch** on main: `transcriptionService` is hard-wired to the shared WhisperKit service; `SpeechTranscriptionService` and `MockTranscriptionService` exist but are unwired (legacy/test). The single shared WhisperKit instance enforces single-inference discipline app-wide.

### Protocol inventory

| Protocol | Responsibility | Key surface | Implementation |
|---|---|---|---|
| `Connectivity` (`Protocols.swift:27-34`) | Network interface state | `currentInterface: NetworkInterface { get async }`; `interfaceChanges: AsyncStream<NetworkInterface>` (emits current value on subscription) | `NetworkConnectivity` (actor) |
| `PendingTranscriptionService` (`:41-45`) | Drain `.pendingTranscription` recordings in capture order when the model is ready | `drainIfModelReady() async` | `PendingTranscriptionServiceImpl` (actor) |
| `TranscriptionService` (`:69-87`) | Audio → streamed transcript segments | `transcribe(audioURL:) async throws -> AsyncStream<TranscriptionSegmentDTO>`; `cancelTranscription()`; `loadModel()` (default no-op) | `WhisperKitTranscriptionService` (actor, shared); unwired: `SpeechTranscriptionService`, `MockTranscriptionService` |
| `AudioRecordingService` (`:90-113`) | Mic capture lifecycle + levels | `audioLevelStream: AsyncStream<Float>` (0–1); `requestPermission()`; `startRecording() async throws -> URL`; `pause/resume/stop/cancelRecording` | `AudioRecordingServiceImpl` |
| `AudioFileStorageService` (`:116-134`) | Persist/retrieve/delete audio + Recording rows; transcript export; storage accounting | `saveRecording(from:duration:)`, `deleteRecording(_:)`, `getAudioURL(for:)`, `exportTranscript(_:format:)`, `calculateTotalStorageUsed()` (all main-actor); `availableStorage() async` | `AudioFileStorageServiceImpl` |
| `AIModelService` (`:149-164`) | Whisper model install state, download, delete | `status(for:)`, `download(_:) async throws -> AsyncThrowingStream<Double, Error>` (mid-download failure throws `ModelDownloadFailure`), `delete(_:)`, `localPath(for:)` | `AIModelServiceImpl` |
| `SummarizationService` (`:187-189`) | Transcript → structured extraction (`SummaryResult`) | `summarize(rawTranscription:) async throws -> SummaryResult` | `NLSummarizationService` |
| `ExportService` (`ExportService.swift:116-121`) | Encrypted journal backup | `@MainActor export(from: ModelContext) async throws -> ExportResult` | `ExportServiceImpl` (see [Settings](08-settings-and-data.md) FR-SET-36…39) |
| `DoseLogService` (`DoseLogService.swift:21-26`) | Expedited default-dose write (sticker/Siri/Shortcuts only) | `logDefaultDose(now:) async -> DoseLogOutcome`; `namesMedicationInConfirmations() async -> Bool` | `DoseLogServiceImpl` |

Supporting value types:
- `NetworkInterface: Sendable` — `wifi`, `cellular`, `other`, `unsatisfied`; custom `Equatable` (`Protocols.swift:9-23`).
- `TranscriptionSegmentDTO: Sendable` — id, text, startTime, endTime, isFinal (default true), confidence?, isError (default false); `isError` segments are converted by consumers into thrown errors (`:48-66`).
- `ModelDownloadFailure: Error, Sendable, Equatable` — `noNetwork`, `insufficientSpace`, `cellularDisabled`, `other(String)`. "Transient (never persisted) and content-free — it names the *condition*, never any transcript or medication data (Principle VI)" (`:142-147`).
- `SummaryResult: Sendable` — bullets, medications `[MedEvent]`, generatedTitle, energy/focus/mood/sleepQuality/sleepLevel `String?`, sleepHours `Double?`, sleepEvent, sideEffects/emotions/topics `[String]`, noteExtraction; computed `hasMedication` (`:168-185`).
- `SummarizationError` — `modelNotInstalled`, `contextTooLong`, `timeout`, `parsingFailed`, `inferenceFailed(String)` (`:191-197`).
- `DoseLogOutcome` — `logged(name:dose:at:)`, `guarded(activeSince:)`, `notConfigured`, `failed` (fails closed when dose history is unreadable while a guard is armed, or when save failed — always safe to retry) (`DoseLogService.swift:5-16`).

## ADR-04 — `RecordingStore` as the single repository

**Context.** Views need an observable, launch-consistent view of the journal with self-healing for interrupted states.

**Decision.** `@Observable @MainActor class RecordingStore` (`app-four/Store/RecordingStore.swift:4-6`) wraps a `ModelContext` (exposed read-only as `context`) with `recordings: [Recording] = []`.

Key behaviors:
- **Orphan recovery** (`:25-36`): any recording stuck in `.transcribing` at launch is set to `.failed`; empty transcripts get `"Transcription was interrupted. Tap to retry in the recording detail view."`. `.pendingTranscription` is explicitly untouched — those drain via `PendingTranscriptionService` once the model lands.
- **Mock-mode partitioning** (`:38-50`): fetch predicate `$0.isMockData == mockMode` (`UserDefaults` key `"debugMockMode"`), sorted `createdAt` descending; mock and real data are strictly partitioned.
- **Mutation surface**: `addRecording`, `deleteRecording` (row only — the audio FILE is owned by `AudioFileStorageService`), `save()` (posts `.medicationEventsDidChange`), `toggleFavorite`, `updateTitle`, `addCorrectionTags` (`:52-89`).
- **Text check-in creation** (`:94-155`): `createCheckInNote(_:)` / throwing `persistCheckInNote(_:)` build a `Recording` via `buildAndInsertCheckInNote` — title `"<Mood> · <Energy> · <Focus>"` display labels, else first 5 words of the note, else `"Check-in"`; `audioFileName = "text-<UUID>"`, `duration = 0`, `status = .completed`, user-picked signals written as authoritative scalars, `hasMedication = !draft.meds.isEmpty`, one manual `MedicationEvent` per draft med. The throwing variant exists so capture can surface a retry instead of silently dropping the draft (overridable for tests).

**Consequence.** One place owns fetch/save semantics and cross-screen refresh notification; audio-file ownership stays with the storage service, keeping delete paths unambiguous (see [Data Model](09-data-model.md) FR-DAT-14).

## ADR-05 — Connectivity as a pure decision + actor monitor

**Decision.** `actor NetworkConnectivity: Connectivity` (`Services/Connectivity/NetworkConnectivity.swift:7`) wraps `NWPathMonitor` on dispatch queue `"app.squirl.connectivity"`, started lazily. `interfaceChanges` yields the current value immediately on subscription, then on change. Path mapping: unsatisfied unless `.satisfied`; wifi > cellular > other (`:80-85`).

The download policy is a **static pure function** — `shouldStartDownload(overCellular:interface:)` (`:38-44`): `.unsatisfied` → false; `.cellular` → the user's `downloadOverCellular` preference; `.wifi`/`.other` → true — "kept static so it is trivially testable without spinning up `NWPathMonitor`."

**Consequence.** First-run background download waits on `interfaceChanges` until a permitted interface appears, re-checking the model still isn't installed before starting (`SquirlApp.swift:148-155`).

## ADR-06 — Storage service owns the audio files

**Decision.** `AudioFileStorageServiceImpl` (`Services/Audio/AudioFileStorageServiceImpl.swift`) uses `AppPaths.recordings` / `AppPaths.exports`:
- `saveRecording(from:duration:)` (`:17-44`): moves the temp file to `recording_<uuid lowercase>.m4a`, reads file size (0 on failure), creates the `Recording` with `status: .recorded` and title `"Recording <abbreviated date, shortened time>"`, inserts + saves.
- `deleteRecording(_:)` (`:46-58`): removes the audio file if present, then deletes the model + saves — **the ONLY delete path that removes the audio file**.
- `getAudioURL(for:)` (`:60-63`): nil when the file is missing.
- `exportTranscript(_:format:)` (`:65-94`): despite the `ExportFormat` parameter, **always writes JSON** — `ExportDTO { id, title?, createdAt, duration, audioFormat: "16 kHz • M4A", transcript }`, ISO8601 dates, pretty-printed, to `Exports/<recording UUID>.json`.
- `calculateTotalStorageUsed()` (`:96-100`): sum of `fileSize` over all recordings (SwiftData values, not a disk walk).
- `availableStorage()` (`:102-106`): `.systemFreeSize` of the Documents volume, 0 on failure.

**Consequence.** File and row lifetimes are managed in exactly one place; Clear All Data deliberately routes through this service so files are removed too ([Settings](08-settings-and-data.md) FR-SET-23).

## SquirlDesignSystem package (summary level)

`Packages/SquirlDesignSystem/` — SwiftPM library, swift-tools 6.0, iOS 26 minimum, depends on local `SquirlSignals` (re-exported via `@_exported import` in `Reexport.swift`, so `MoodLevel`/`EnergyLevel`/`FocusLevel`/`SleepLevel` come transitively). 26 files. The app module additionally `@_exported import`s both packages (`SignalsReexport.swift:4-5`), so every app file sees tokens and levels unqualified.

### Token categories (public API surface)

| Category | File | Surface (names only — not every value) |
|---|---|---|
| Color — semantic | `Theme.swift` | `accent`, `meadowGreen`, `meadowAmber`, `statusDone` (= meadowGreen), `statusInProgress` (= meadowAmber), `danger`, `meadowGradient` (signature LinearGradient) |
| Color — "Paper & Pollen" neutrals | `NewLook.swift` | `screen`, `card`, `inkPrimary`, `onInk`, `inkSecondary`, `hairline`, `tintNeutral`, `selection`, `onSelection`, `checkInGreen`, `checkInGreenSoft` (all light/dark pairs); `View` card-style extension, `NewLookChipRole`, `NewLookNavBar<Leading, Trailing>` |
| Color — domain | `Palette.swift` | `medication`, `medicationFillEnd`, `warning`, `sleepIndigo` |
| Color — signal ramps | `Palette+Signals.swift` | `energyRamp` ("Lemon"), `focusRamp` ("Voltage" blue) — 5-step, static across light/dark |
| Color — mood grammar | `MoodLevel+Palette.swift` | per-`MoodLevel` `color`, `gradientPartner`, `fill`, `deepFill`, `blockTint`, `badgeTint`, `wordColor`, `displayLabel`, `onColor`; `averageDeep(of:)` |
| Color infra | `Color+Hex.swift` | `Color(hex:)` and light/dark hex initializers backing all tokens |
| Typography | `Typography.swift` | SF Pro/Mono, Dynamic-Type-scaled roles: `display`, `largeTitle`, `title`, `dayCardDate`, `moodWord`, `headline`, `subheadline`, `body`, `callout`, `caption`, `label`, mono `timer`/`duration`/`mono12`; bespoke `text(_:weight:relativeTo:)` / `mono(_:weight:relativeTo:)`; `View` font extensions |
| Spacing | `Spacing.swift` | xs 4 · s 8 · m 12 · l 16 · xl 20 · xxl 24 · section 32 · hero 40 · ringStroke 3.3 |
| Radius | `Radius.swift` | card 16 · control 10 · button 16 · chip 15 · newLookCard 20 |
| Metrics | `Metrics.swift` | `minTapTarget` 44, `maxContentWidth` 600, `rowMinHeight` 44, signal/glyph sizes (`headerMoodBadge` 42, `summarySignal` 15, `rowSignal` 12, `dayHeaderGlyph` 40, `rowMoodDisc` 43, `rowMoodGlyph` 28, `moreAffordance` 21), nested `IconSize` (control 32, illustration 48, hero 72), `CheckIn` metrics (crescent 300, stopGlyph 11, promptDot 6, promptBarHeight 4, savedDisc 78, savedCheck 32) |
| Opacity | `Opacity.swift` | `deEmphasis` 0.34, `moodBlock` 0.24, `moodBadge` 0.50 |
| Motion | `Motion.swift` | `snappy` (.snappy 0.3 s), `smooth` (.smooth 0.4 s), `expand` (.easeInOut 0.25 s) |
| Haptics | `Haptics.swift` | `success()`, `error()`, `selection()` |
| Icons | `Icons.swift` | centralized SF Symbol names: tabs (`calendar`, `checkmark.circle`, `chart.bar.fill`, `gear`), domain (`pills.fill`, `bandage.fill`) |
| Buttons | `Buttons.swift` | `PrimaryButtonStyle`, `CheckInPrimaryButtonStyle`, `SecondaryButtonStyle` registered as `.primary`, `.checkInPrimary`, `.secondary` |
| Card | `Card.swift` | `Text.cardEyebrow()` section-eyebrow style |

### Signal glyph component inventory

- `SignalGlyph.swift` — view rendering the level-encoded marks.
- `GlyphSignal.swift` — `enum GlyphSignal { mood, energy, focus, sleep, medication }`; `selfState` = the three ramped signals; `title` "Mood"/"Energy"/"Focus"/"Sleep"/"Medication"; `variesByLevel` true only for the three self-state signals; `GlyphBadge` descriptor; pure helpers `clampedSignalLevel(_:)` (clamps 1…5, nil passes through) and `signalName(_:level:)`.
- `SignalLevel.swift` — shared color/contrast grammar: `Color.contrastingInk(for:in:)`, level fill/bubble gradients, energy/focus ramp accessors.
- `Glyphs/` — `SproutGlyph` (mood, bud→bloom across 1–5), `BoltGlyph` (energy, grows/fills 1–5), `ApertureGlyph` (focus, dashed ring → concentric rings + core), `BedIcon` (sleep, fixed), `CapsuleGlyph` (medication, fixed two-tone capsule).
- Level encoding is shape-based — "a shape ladder, never opacity alone" — for grayscale legibility.

## SquirlSignals package

`Packages/SquirlSignals/` — swift-tools 6.0, library `SquirlSignals`, platforms iOS 26.0, single target, `swiftLanguageModes: [.v5]`. The four 5-step ordinal scales were "hoisted out of NoteExtraction.swift into a leaf module so both the app (NoteExtraction service) and SquirlDesignSystem (glyphs + palette) can depend on them without a SwiftUI edge. Pure Foundation value types." (`Levels.swift:1-7`)

All four are `public enum X: String, Sendable, Codable, Equatable, CaseIterable` with `numericValue: Int` (1…5) and `subtitle: String`:

| Enum | Cases (1→5) | Subtitles |
|---|---|---|
| `MoodLevel` (`Levels.swift:8`) | `low`, `flat`, `okay`, `good`, `great` | "heavy, muted" / "neutral, still" / "steady, fine" / "warm, lifted" / "bright, thriving" |
| `EnergyLevel` (`:29`) | `sluggish`, `tired`, `steady`, `alert`, `charged` | — |
| `FocusLevel` (`:50`) | `foggy`, `distracted`, `present`, `sharp`, `lockedIn` | `displayLabel` "Foggy"/"Distracted"/"Present"/"Sharp"/"Locked In" |
| `SleepLevel` (`:80`) | `restless`, `light`, `okay`, `good`, `deep` | — |

Design-system extensions add palette/display concerns (`MoodLevel+Palette.swift`: `init?(name:)` case-insensitive from a recording's raw mood string, `displayLabel`, ramp colors, `wordColor`, `onColor`) without polluting the leaf module.

## Cross-cutting architecture notes

- **Startup order is contractual** (ADR-01): `StorageMigration.run()` runs before any store/service reads disk; DEBUG registers `"debugMockMode": true` (skipped under XCTest) before `AppDependencies.store` is touched because the store reads the key eagerly; release unconditionally removes the key (`SquirlApp.swift:14-30`).
- **Single-inference discipline:** the shared WhisperKit actor cancels any prior `activeTranscriptionTask` before starting a new one, and `CheckInViewModel` chains a new transcription after the prior one completes — the engine never runs two inferences at once (`WhisperKitTranscriptionService.swift:97`; `CheckInViewModel.swift:164-167`).
- **Pending-transcription drain** runs on launch, every foreground, and background-download completion; an `isDraining` latch coalesces re-entrant calls, and UUIDs (not `@Model` objects) cross the actor hop (`PendingTranscriptionServiceImpl.swift:37-82`; `SquirlApp.swift:125-130,161`).
- **RAM management:** the Whisper model is unloaded at the end of every transcription (success or error) so Metal/CoreML buffers are freed before NL extraction (`WhisperKitTranscriptionService.swift:163-201,216-219`).
- **Compute units:** `.cpuAndGPU` on Simulator or debugger-attached runs (ANE compiler unreachable from Xcode-run processes), else `.cpuAndNeuralEngine` (`Utils/ComputeEnvironment.swift`).

## Acceptance criteria

- Every service consumed by a ViewModel arrives via `AppServices` environment injection; no ViewModel references `AppDependencies`.
- `Protocols.swift` remains the single definition site for the seven core service protocols and their DTOs; `ExportService` and `DoseLogService` remain co-located with their implementations.
- `RecordingStore` launch performs orphan recovery exactly as specified; `.pendingTranscription` rows are never swept to `.failed` by it.
- `AudioFileStorageServiceImpl.deleteRecording` remains the only code path that deletes audio files.
- Package boundaries hold: `SquirlSignals` stays SwiftUI-free; `SquirlDesignSystem` re-exports it; token and glyph additions land in the package, not the app target.

## Source references

| Area | Files (branch `main`) |
|---|---|
| Composition root / bundle | `app-four/Store/AppDependencies.swift:6-51`, `app-four/Store/AppServices.swift:9`, `app-four/Store/PreviewSupport.swift`, `app-four/Utils/PreviewEnvironment.swift:7` |
| App wiring | `app-four/App/SquirlApp.swift:11-81` |
| Protocols | `app-four/Services/Protocols.swift:9-197`, `app-four/Services/ExportService.swift:116-121`, `app-four/Services/DoseLog/DoseLogService.swift:5-26` |
| Repository | `app-four/Store/RecordingStore.swift:4-155` |
| Connectivity | `app-four/Services/Connectivity/NetworkConnectivity.swift:7-85` |
| Audio storage | `app-four/Services/Audio/AudioFileStorageServiceImpl.swift:13-106` |
| Transcription impl | `app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift:7-225` |
| Pending drain | `app-four/Services/PendingTranscriptionServiceImpl.swift:4-144` |
| Design system | `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/` (26 files; see token table) |
| Signals | `Packages/SquirlSignals/Package.swift`, `Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift:1-90` |
