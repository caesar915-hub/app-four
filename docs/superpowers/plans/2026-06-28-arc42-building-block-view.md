# arc42 Building Block View — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce `docs/ARCHITECTURE-arc42.md` — a complete arc42 Building Block View of the Squirl app, documenting every layer and file with its responsibility, interfaces, and rationale.

**Architecture:** Hierarchical markdown document following the [arc42 section-5 spec](https://docs.arc42.org/section-5/). Level 1 = whole-system white-box. Level 2 = per-layer black-box tables. Level 3 = per-file detail within each layer. No code is written — this is a documentation artifact.

**Tech Stack:** Markdown, arc42 template, `swiftui-app-architecture-workflow` (boundary validation), `swift-architecture-skill` (structural guidance), `document-generate` (output production)

**Skills to invoke before each layer:**
- `swiftui-app-architecture-workflow` — validates ownership boundary (app / scene / view-tree / local) for each layer
- `swift-architecture-skill` — confirms structural pattern used per layer

---

## File Structure

| Output file | Purpose |
|---|---|
| `docs/ARCHITECTURE-arc42.md` | The arc42 Building Block View — created by this plan |

---

### Task 1: Scaffold the document and write Level 1 (System White-Box)

**Files:**
- Create: `docs/ARCHITECTURE-arc42.md`

- [ ] **Step 1: Invoke `swiftui-app-architecture-workflow`**

Run the skill to classify the overall system ownership boundary. Expected output: `App`-level ownership of `ModelContainer`, scene-level navigation, view-tree-level state.

- [ ] **Step 2: Write the Level 1 white-box overview**

Create `docs/ARCHITECTURE-arc42.md` with:

```markdown
# Squirl — arc42 Building Block View

> arc42 §5 · Static decomposition of the Squirl iOS app into layers and files.
> Generated: 2026-06-28 · Updated whenever a file is added/removed/renamed.

---

## Level 1 — System White-Box

Squirl is a voice-first ADHD journaling app. The user records a voice note; the app
transcribes it (on-device via WhisperKit or Apple Speech), extracts signals (energy,
focus, mood) via NLP, stores the result in SwiftData, and surfaces insights over time.

### Contained Building Blocks

| Block | Responsibility |
|---|---|
| **App** | Entry point, `ModelContainer` ownership, environment injection |
| **Models** | SwiftData `@Model` types + domain enums |
| **Services** | Protocol-defined capabilities (audio, transcription, AI, NLP) |
| **Store** | Dependency wiring — assembles concrete services, exposes `RecordingStore` |
| **ViewModels** | Per-screen observable state, orchestrates Services + Models |
| **Views** | SwiftUI render layer — screens, components, reusable sub-views |
| **DesignSystem** | App-wide layout primitives (`ScreenContainer`, overlays) |
| **Diagnostics** | Internal metrics, session snapshots, screen tracking |
| **Utils** | Cross-cutting helpers (logging, constants, environment keys, converters) |
| **wireframes** | Design-reference SwiftUI wireframes — not shipped in production |

### Key Interfaces Between Blocks

| From | To | Via |
|---|---|---|
| App | Store | `.environment(AppDependencies(...))` |
| Store | Services | Direct initializer injection |
| ViewModels | Store | `@Environment(\.appDependencies)` |
| ViewModels | Models | SwiftData `@Query` / `ModelContext` |
| Views | ViewModels | `@StateObject` / `@ObservedObject` |
| Services | Models | `ModelContext` passed at call site |
```

- [ ] **Step 3: Commit scaffold**

```bash
git add docs/ARCHITECTURE-arc42.md
git commit -m "docs: scaffold arc42 Building Block View — Level 1"
```

---

### Task 2: Level 2 — App Layer

**Files:**
- Modify: `docs/ARCHITECTURE-arc42.md`
- Read: `app-four/App/SquirlApp.swift`, `app-four/App/AppModelContainer.swift`, `app-four/App/SignalsReexport.swift`

- [ ] **Step 1: Read all three App files**

Open each file. Confirm:
- `SquirlApp.swift` — `@main`, attaches `ModelContainer`, injects `AppDependencies` environment
- `AppModelContainer.swift` — constructs and configures the SwiftData `ModelContainer`
- `SignalsReexport.swift` — re-exports SquirlSignals package types into the app module

- [ ] **Step 2: Append Level 2 App section**

```markdown
---

## Level 2 — App Layer (`app-four/App/`)

Owns the SwiftUI app lifecycle, the single `ModelContainer`, and top-level environment injection.
All scene and view-level code receives dependencies from here — nothing constructs its own container.

### Black-Box Table

| File | Responsibility | Key Interface |
|---|---|---|
| `SquirlApp.swift` | `@main` entry point; attaches model container; injects `AppDependencies` | `.environment(appDeps)`, `.modelContainer(container)` |
| `AppModelContainer.swift` | Constructs `ModelContainer` for all `@Model` types; isolates SwiftData configuration | Returns `ModelContainer` consumed by `SquirlApp` |
| `SignalsReexport.swift` | Re-exports `SquirlSignals` package types so callers need only import the app module | `public typealias` / `@_exported import` |

### Ownership Boundary
`App`-level. `ModelContainer` must not be owned by a scene or view — SwiftData requires a single container shared across all scenes.
```

- [ ] **Step 3: Commit**

```bash
git add docs/ARCHITECTURE-arc42.md
git commit -m "docs(arc42): add Level 2 — App layer"
```

---

### Task 3: Level 2 — Models Layer

**Files:**
- Modify: `docs/ARCHITECTURE-arc42.md`
- Read: all 11 files in `app-four/Models/`

- [ ] **Step 1: Read all Model files**

Open each file. Map the `@Model` types, enums, and extensions:
- `Recording.swift` — primary `@Model`; stores audio path, transcript, extracted signals
- `RecordingTag.swift` — `@Model` tag attached to recordings
- `TranscriptionSegment.swift` — `@Model` per-word timestamped segment
- `MedicationEvent.swift` — `@Model` log entry for a dose taken
- `AppSettings.swift` — `@Model` singleton for user preferences
- `CheckInDraft.swift` — transient draft state for the check-in flow (not persisted)
- `MedicationCatalog.swift` — in-memory catalog of known medications and doses
- `AppEnums.swift` — shared enums (signal types, moods, transcription state)
- `ModelMetadata.swift` — versioning/migration helpers for the SwiftData schema
- `PromptPace.swift` — enum/value type controlling how frequently the app prompts the user
- `Recording+MoodDisplay.swift` — extension on `Recording` for display-layer mood logic

- [ ] **Step 2: Append Level 2 Models section**

```markdown
---

## Level 2 — Models Layer (`app-four/Models/`)

Pure SwiftData `@Model` types and domain value types. No UI, no service calls, no business logic
beyond computed display properties. All mutations go through `ModelContext` at the call site.

### Black-Box Table

| File | Type | Responsibility |
|---|---|---|
| `Recording.swift` | `@Model` | Primary entity: audio file path, transcript text, extracted signal scores, tags |
| `RecordingTag.swift` | `@Model` | User-defined tag associated with one or more recordings |
| `TranscriptionSegment.swift` | `@Model` | Per-word/segment timestamped transcription entry; child of `Recording` |
| `MedicationEvent.swift` | `@Model` | A single logged medication dose with timestamp and catalog reference |
| `AppSettings.swift` | `@Model` | Singleton user preferences (prompt pace, display options, onboarding state) |
| `CheckInDraft.swift` | `struct` | Transient in-memory draft for the check-in composer; never persisted |
| `MedicationCatalog.swift` | `struct` / static | In-memory catalog of known ADHD medications, doses, and durations |
| `AppEnums.swift` | `enum` | Shared domain enums: `SignalType`, `MoodLevel`, `TranscriptionState` |
| `ModelMetadata.swift` | helpers | SwiftData schema version, migration stages |
| `PromptPace.swift` | `enum` | Controls check-in prompt frequency (aggressive / moderate / quiet) |
| `Recording+MoodDisplay.swift` | extension | Display-layer mood label and color derived from `Recording.moodScore` |

### Ownership Boundary
No boundary ownership — pure data. Consumed by ViewModels via `@Query` and `ModelContext`.
```

- [ ] **Step 3: Commit**

```bash
git add docs/ARCHITECTURE-arc42.md
git commit -m "docs(arc42): add Level 2 — Models layer"
```

---

### Task 4: Level 2 — Services Layer

**Files:**
- Modify: `docs/ARCHITECTURE-arc42.md`
- Read: `app-four/Services/Protocols.swift` + representative files from each sub-folder

- [ ] **Step 1: Read `Protocols.swift` first**

This file defines all service interfaces. Map these protocols (confirmed from source): `Connectivity`, `PendingTranscriptionService`, `TranscriptionService`, `AudioRecordingService`, `AudioFileStorageService`, `AIModelService`, `SummarizationService`. Note: `ExportService` is a protocol defined separately in `ExportService.swift`, not in `Protocols.swift`.

- [ ] **Step 2: Read one concrete per sub-group**

- `Services/Audio/AudioRecordingServiceImpl.swift` — AVFoundation recording
- `Services/Audio/AudioFileStorageServiceImpl.swift` — file I/O for recordings
- `Services/Speech/SpeechTranscriptionService.swift` — Apple on-device Speech
- `Services/WhisperKit/WhisperKitTranscriptionService.swift` — WhisperKit transcription
- `Services/NoteExtraction/NLNoteExtractor.swift` — NLP signal extraction pipeline
- `Services/AIModelServiceImpl.swift` — Claude API calls for summarization/extraction
- `Services/NLSummarizationService.swift` — NL summarization
- `Services/ExportService.swift` — journal export (CSV/text)
- `Services/PendingTranscriptionServiceImpl.swift` — queue for offline transcription
- `Services/Connectivity/NetworkConnectivity.swift` — reachability
- `Services/Mock/MockTranscriptionService.swift` — preview/test double

- [ ] **Step 3: Append Level 2 Services section**

```markdown
---

## Level 2 — Services Layer (`app-four/Services/`)

Protocol-defined capabilities. `Protocols.swift` owns all interfaces; concrete implementations
are injected at startup via `Store/AppDependencies`. Views and ViewModels depend only on protocols,
never on concrete types.

### Protocols (`Protocols.swift`)

All seven protocols below are defined in `Protocols.swift`. `ExportService` is defined separately in `ExportService.swift`. There is no `NoteExtractorService` protocol — note extraction is done via the concrete `NLNoteExtractor` struct.

| Protocol | Responsibility |
|---|---|
| `Connectivity` | Network interface monitoring (Wi-Fi / cellular / unsatisfied); gates cloud calls |
| `PendingTranscriptionService` | Drains `.pendingTranscription` recordings on launch / background-download completion |
| `TranscriptionService` | Convert audio to text (async streaming via `AsyncStream<TranscriptionSegmentDTO>`) |
| `AudioRecordingService` | Start/stop/pause/cancel microphone capture; stream audio levels |
| `AudioFileStorageService` | Save, delete, and export audio files; calculate storage usage |
| `AIModelService` | Download, delete, and query status of on-device AI models |
| `SummarizationService` | Extract structured `SummaryResult` (signals, emotions, medications) from raw transcript |

### Implementations

| File | Protocol | Backend |
|---|---|---|
| `Audio/AudioRecordingServiceImpl.swift` | `AudioRecordingService` | AVFoundation |
| `Audio/AudioFileStorageServiceImpl.swift` | `AudioFileStorageService` | FileManager |
| `Speech/SpeechTranscriptionService.swift` | `TranscriptionService` | Apple Speech framework |
| `WhisperKit/WhisperKitTranscriptionService.swift` | `TranscriptionService` | WhisperKit (on-device LLM) |
| `AIModelServiceImpl.swift` | `AIModelService` | Anthropic Claude API (network) |
| `NLSummarizationService.swift` | `SummarizationService` | Apple NaturalLanguage (`NLNoteExtractor` pipeline) |
| `ExportService.swift` | `ExportService` (defined here, not in Protocols.swift) | Foundation string serialisation |
| `PendingTranscriptionServiceImpl.swift` | `PendingTranscriptionService` | Persists jobs for offline retry |
| `Connectivity/NetworkConnectivity.swift` | internal | Network.framework reachability |
| `Mock/MockTranscriptionService.swift` | `TranscriptionService` | Hardcoded fixture — SwiftUI Previews only |

### NoteExtraction Sub-Pipeline (`Services/NoteExtraction/`)

| File | Role |
|---|---|
| `NLNoteExtractor.swift` | Orchestrates the extraction pipeline |
| `CueMatcher.swift` | Regex/lexicon pattern matching for cue phrases |
| `Lexicon.swift` + `LexiconData.swift` | Vocabulary tables for signal words |
| `TenseClassifier.swift` | NL tense detection to distinguish past vs. current state |
| `PersonalLexiconBuilder.swift` | Builds a user-specific vocabulary from recording history |
| `NoteExtraction.swift` | Shared types: `ExtractedNote`, `SignalScore`, etc. |

### Ownership Boundary
Scene-level injection via `AppDependencies` environment object. Services are stateful
(recording session, model download) so they live at scene scope, not view scope.
```

- [ ] **Step 4: Commit**

```bash
git add docs/ARCHITECTURE-arc42.md
git commit -m "docs(arc42): add Level 2 — Services layer"
```

---

### Task 5: Level 2 — Store Layer

**Files:**
- Modify: `docs/ARCHITECTURE-arc42.md`
- Read: `app-four/Store/AppDependencies.swift`, `app-four/Store/AppServices.swift`, `app-four/Store/RecordingStore.swift`, `app-four/Store/PreviewSupport.swift`

- [ ] **Step 1: Read all four Store files**

Confirm:
- `AppDependencies` — `@Observable` or `ObservableObject` that holds all injected service references
- `AppServices` — constructs concrete service instances (the composition root)
- `RecordingStore` — `@Observable` state for the recording flow (active recording, processing state)
- `PreviewSupport` — convenience constructors for SwiftUI Preview environments

- [ ] **Step 2: Append Level 2 Store section**

```markdown
---

## Level 2 — Store Layer (`app-four/Store/`)

The composition root. Constructs concrete service instances and exposes them as an
`AppDependencies` environment object. This is the only place that knows about concrete types.

### Black-Box Table

| File | Responsibility |
|---|---|
| `AppDependencies.swift` | `@Observable` container holding all service references; injected into SwiftUI environment at `App` level |
| `AppServices.swift` | Constructs and wires concrete service instances at startup; single source of service instantiation |
| `RecordingStore.swift` | `@Observable` state machine for the active recording session (idle → recording → processing → done) |
| `PreviewSupport.swift` | Builds mock `AppDependencies` for SwiftUI Previews; keeps preview boilerplate out of Views |

### Ownership Boundary
App/scene boundary. `AppDependencies` is injected at `App` level; `RecordingStore` is
scene-scoped (one active recording at a time). Never instantiated inside a View.
```

- [ ] **Step 3: Commit**

```bash
git add docs/ARCHITECTURE-arc42.md
git commit -m "docs(arc42): add Level 2 — Store layer"
```

---

### Task 6: Level 2 — ViewModels Layer

**Files:**
- Modify: `docs/ARCHITECTURE-arc42.md`
- Read: all 13 files in `app-four/ViewModels/`

- [ ] **Step 1: Read all ViewModel files** — confirm each one's screen ownership and service dependencies.

- [ ] **Step 2: Append Level 2 ViewModels section**

```markdown
---

## Level 2 — ViewModels Layer (`app-four/ViewModels/`)

Per-screen `@Observable` / `ObservableObject` types. Each ViewModel owns one screen's state,
calls into Services for side-effects, and exposes only what the View needs (no raw model exposure).

### Black-Box Table

| File | Screen | Key Dependencies |
|---|---|---|
| `RecordingDetailViewModel.swift` | Recording detail | `RecordingStore`, `SummarizationService`, `TranscriptionService` |
| `CheckInViewModel.swift` | Check-in composer | `AudioRecordingService`, `TranscriptionService`, `AIModelService` |
| `InsightsViewModel.swift` | Insights dashboard | `ModelContext` (`@Query`) |
| `InsightsViewModel+Signals.swift` | Insights signal computations | Extension on `InsightsViewModel` |
| `MoodLibraryViewModel.swift` | Library / mood calendar | `ModelContext` |
| `CalendarMonthModel.swift` | Calendar month grid | `ModelContext` |
| `DayTimeline.swift` | Day timeline data | `ModelContext` |
| `ProcessingViewModel.swift` | Post-recording processing | `TranscriptionService`, `SummarizationService` |
| `ExtractionReviewViewModel.swift` | Extraction review sheet | `ModelContext`, `SummarizationService` |
| `AudioPlaybackViewModel.swift` | Audio playback controls | `AudioFileStorageService`, AVFoundation |
| `MedicationBarViewModel.swift` | Medication bar overlay | `ModelContext`, `MedicationCatalog` |
| `MedicationPickerViewModel.swift` | Medication log picker | `MedicationCatalog` |
| `SettingsViewModel.swift` | Settings screen | `AppSettings` (`ModelContext`) |

### Ownership Boundary
View-tree level — created as `@StateObject` by the owning screen View. Not injected via environment
(except `AppDependencies` which they consume). Scoped to the screen's lifecycle.
```

- [ ] **Step 3: Commit**

```bash
git add docs/ARCHITECTURE-arc42.md
git commit -m "docs(arc42): add Level 2 — ViewModels layer"
```

---

### Task 7: Level 2 — Views Layer

**Files:**
- Modify: `docs/ARCHITECTURE-arc42.md`
- Read: `app-four/Views/RootTabView.swift` + representative files from each sub-folder

- [ ] **Step 1: Read `RootTabView.swift`** — confirms the four tab structure (Record, Library, Insights, Settings).

- [ ] **Step 2: Append Level 2 Views section**

```markdown
---

## Level 2 — Views Layer (`app-four/Views/`)

SwiftUI render layer. Views are passive: they display ViewModel state and forward user actions.
No business logic, no direct service calls, no `ModelContext` access (except via ViewModel).

### Screens (top-level Views)

| File | Screen | ViewModel |
|---|---|---|
| `RootTabView.swift` | Tab bar container (Record · Library · Insights · Settings) | none |
| `Views/CheckIn/CheckInView.swift` | Voice/text check-in composer | `CheckInViewModel` |
| `Views/InsightsView.swift` | Monthly insights dashboard | `InsightsViewModel` |
| `Views/Library/CalendarLibraryView.swift` | Calendar-based recording library | `MoodLibraryViewModel` / `CalendarMonthModel` |
| `Views/RecordingDetailView.swift` | Single recording detail (transcript, signals, notes) | `RecordingDetailViewModel` |
| `Views/SettingsView.swift` | App settings | `SettingsViewModel` |
| `Views/ExtractionReviewView.swift` | AI extraction review sheet | `ExtractionReviewViewModel` |
| `Views/Onboarding/WelcomeView.swift` | First-launch onboarding | `WelcomeViewModel` |
| `Views/TestServicesView.swift` | Internal debug screen — not shown in production nav | none |

### Reusable Components (`Views/Components/`)

| File | Purpose |
|---|---|
| `DayCard.swift` | Summary card for one day's recordings |
| `DayCardSummary.swift` | Compact signal-strip summary within `DayCard` |
| `DayDetailSheet.swift` | Bottom sheet expanding a day's detail |
| `RecordingRow.swift` | Single row in a recording list |
| `TimelineRow.swift` / `TimelineBead.swift` | Day-timeline entries |
| `AudioPlayerView.swift` + `PlaybackWaveformBars.swift` | Audio playback controls |
| `MedicationBarView.swift` | Floating medication dose bar |
| `MedicationLogSheet.swift` | Medication logging bottom sheet |
| `GlyphRampPicker.swift` | Signal glyph selector (sprout/lightning/aperture) |
| `ADHDSummarySection.swift` | ADHD-specific summary block in detail view |
| `TagFlowView.swift` | Horizontally-wrapping tag chip display |
| `Chip.swift` | Single tag/label chip |
| `CalendarDayCell.swift` / `CalendarHeaderView.swift` | Calendar grid cells |
| `FoldedDayCardHeader.swift` | Collapsed DayCard header |
| `EdgeFadeMask.swift` | Scroll-edge gradient mask |
| `ModelDownloadRow.swift` | WhisperKit model download progress row |

### Sub-screen groups

| Folder | Content |
|---|---|
| `CheckIn/` | `CrescentRing.swift` (animated ring), `TextCheckInComposer.swift` (text-mode composer) |
| `Insights/` | `ConnectionCardsView`, `DailyRhythmMatrix`, `MoodBubbleChart`, `SignalStripsView`, `SignalAverageGauges`, `MonthSelectorScrollView`, `MoodLegend`, `InsightsSectionHeader` |
| `Library/` | `ExpandedDayCards.swift` — full-screen expanded day card list |
| `Settings/` | `DayCardSettingsSection`, `JournalExportSection`, `MedicationBarSettingsSection`, `YourDataSection` |
| `Feedback/` | `FeedbackButton`, `IssueReportView`, `MailComposeView`, `ScreenshotCapture`, `ShareSheetView` |
| `Onboarding/` | `WelcomeView`, `WelcomeViewModel` |
```

- [ ] **Step 3: Commit**

```bash
git add docs/ARCHITECTURE-arc42.md
git commit -m "docs(arc42): add Level 2 — Views layer"
```

---

### Task 8: Level 2 — Support Layers (DesignSystem, Diagnostics, Utils, wireframes)

**Files:**
- Modify: `docs/ARCHITECTURE-arc42.md`
- Read: `app-four/DesignSystem/`, `app-four/Diagnostics/`, `app-four/Utils/`, `app-four/wireframes/`

- [ ] **Step 1: Read all files in these four folders** — they are small (2–5 files each).

- [ ] **Step 2: Append Level 2 Support Layers section**

```markdown
---

## Level 2 — DesignSystem Layer (`app-four/DesignSystem/`)

| File | Responsibility |
|---|---|
| `ScreenContainer.swift` | App-wide layout wrapper: safe-area handling, background paper texture |
| `MedicationBarOverlay.swift` | Floating medication bar positioned above tab bar |

---

## Level 2 — Diagnostics Layer (`app-four/Diagnostics/`)

Internal-only telemetry. Never surfaces to the user. Consumed by `Utils/Logger.swift` and
crash/feedback flows.

| File | Responsibility |
|---|---|
| `DiagnosticsStore.swift` | Central in-memory store for session events |
| `MetricManager.swift` | Collects and aggregates timing/count metrics |
| `ScreenTracker.swift` | Tracks screen transitions for session replay |
| `SessionSnapshot.swift` | Point-in-time snapshot of app state for bug reports |

---

## Level 2 — Utils Layer (`app-four/Utils/`)

Cross-cutting helpers with no business logic. Pure functions and extension points.

| File | Responsibility |
|---|---|
| `Logger.swift` | Unified `os.Logger` wrapper with subsystem/category routing |
| `Constants.swift` | App-wide string/numeric constants |
| `EnvironmentKeys.swift` | SwiftUI `EnvironmentKey` definitions for custom environment values |
| `AccessibilityHelpers.swift` | `accessibilityLabel` / `accessibilityHint` utilities |
| `AudioConverter.swift` | AVFoundation audio format conversion helpers |
| `ComputeEnvironment.swift` | Detects device capability tier (A14+, Neural Engine) |
| `MockDataGenerator.swift` | Generates fake `Recording` fixtures for Previews |
| `PreviewEnvironment.swift` | Convenience `View` modifier to inject Preview-safe environment |
| `View+Tracking.swift` | `ViewModifier` wiring `ScreenTracker` to `onAppear` |

---

## Level 2 — wireframes Layer (`app-four/wireframes/`)

Design-reference SwiftUI files. **Not compiled into the production target.**
Used to iterate on layout without touching live views.

| File | Screen modelled |
|---|---|
| `CalendarWireframe.swift` | Calendar library screen |
| `DetailWireframe.swift` | Recording detail screen |
| `InsightsWireframe.swift` | Insights dashboard |
| `SettingsWireframe.swift` | Settings screen |
| `SharedWireframes.swift` | Shared wireframe components |
```

- [ ] **Step 3: Commit**

```bash
git add docs/ARCHITECTURE-arc42.md
git commit -m "docs(arc42): add Level 2 — DesignSystem, Diagnostics, Utils, wireframes"
```

---

### Task 9: Final review — validate against actual files

**Files:**
- Read: `docs/ARCHITECTURE-arc42.md` (full review pass)

- [ ] **Step 1: Cross-check file count**

Run:
```bash
find app-four -name "*.swift" | wc -l
```
Expected: 118. If the count differs, find the missing/extra files and add/remove their entries.

- [ ] **Step 2: Verify no file is documented under the wrong layer**

Scan the table for files whose folder path doesn't match the documented layer. Fix any mismatches.

- [ ] **Step 3: Verify Level 1 interfaces match Level 2 boundaries**

Every `Key Interface` row in the Level 1 table must be backed by a concrete file in Level 2. If a row references a symbol that doesn't exist, remove or correct it.

- [ ] **Step 4: Final commit**

```bash
git add docs/ARCHITECTURE-arc42.md
git commit -m "docs(arc42): finalize Building Block View — all layers documented"
```

---

## Self-Review

**Spec coverage:** All 10 top-level layers (App, Models, Services, Store, ViewModels, Views, DesignSystem, Diagnostics, Utils, wireframes) have dedicated Level 2 sections, plus the NoteExtraction sub-pipeline within Services. Level 1 white-box table covers all blocks. Key interfaces between blocks documented.

**Placeholder scan:** No TBD/TODO in any step. Every table row names a real file visible in the directory listing.

**Type consistency:** File names used in tasks match the exact paths returned by `find app-four -name "*.swift"`.
