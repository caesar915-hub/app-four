# Squirl Architecture

_Last updated: 2026-06-28_

This document describes the architecture of Squirl: the layers that make up the app, how data flows between them, and the key design decisions that shape the codebase.

---

## Table of Contents

- [Overview](#overview)
- [Architectural Layers](#architectural-layers)
- [Dependency Injection](#dependency-injection)
- [Data Flow](#data-flow)
- [Concurrency Model](#concurrency-model)
- [Privacy & Security](#privacy--security)
- [Machine Learning Pipeline](#machine-learning-pipeline)
- [Key Design Decisions](#key-design-decisions)
- [Module Map](#module-map)

---

## Overview

Squirl is an offline-first iOS app built with SwiftUI and SwiftData. All user data — audio recordings, transcripts, medication events, and extracted signals — stays on device. The app has no remote API, no cloud sync, and no analytics SDK.

The architecture follows **MVVM + centralized Store + protocol-oriented services**:

- **Views** are pure SwiftUI and contain no business logic.
- **ViewModels** own screen-level state and coordinate between Views, the Store, and Services.
- **Store** (`RecordingStore`) is the single source of truth for recordings and mutations.
- **Services** implement low-level capabilities behind protocols so they can be mocked or swapped.
- **Models** are SwiftData `@Model` objects persisted to a local store.

---

## Architectural Layers

```
┌─────────────────────────────────────────────────────────────┐
│                         Views                               │
│  CheckInView  ·  CalendarLibraryView  ·  InsightsView  ·   │
│  RecordingDetailView  ·  SettingsView  ·  Onboarding       │
├─────────────────────────────────────────────────────────────┤
│                      ViewModels                             │
│  CheckInViewModel  ·  ProcessingViewModel  ·  InsightsVM   │
├─────────────────────────────────────────────────────────────┤
│                         Store                               │
│                    RecordingStore                           │
├─────────────────────────────────────────────────────────────┤
│                       Services                              │
│  Audio  ·  Storage  ·  Transcription  ·  Summarization   │
│  AI Model Management  ·  Connectivity  ·  Export           │
├─────────────────────────────────────────────────────────────┤
│                        Models                               │
│  SwiftData: Recording, MedicationEvent, AppSettings, ...   │
└─────────────────────────────────────────────────────────────┘
```

### Views (`app-four/Views/`)

- Pure SwiftUI.
- Observe `@Observable` ViewModels or SwiftData `@Model` objects.
- Never access singletons directly; dependencies arrive via SwiftUI Environment.
- Complex views are decomposed into small subviews in `Views/Components/`.

### ViewModels (`app-four/ViewModels/`)

- Marked `@Observable` and `@MainActor`.
- Own transient UI state (recording progress, sheet presentation, validation).
- Delegate heavy work to services via `async/await`.
- Persist results through `RecordingStore` or directly via `ModelContext`.

### Store (`app-four/Store/`)

- `RecordingStore` is the single access point for `Recording` CRUD and queries.
- Loads recordings on init, handles mock-mode filtering, and recovers orphaned `.transcribing` states.
- Posts `NotificationCenter` notifications (e.g., `.medicationEventsDidChange`) for cross-screen refresh.

### Services (`app-four/Services/`)

- Protocol-driven. Every capability is behind a protocol in `Services/Protocols.swift`.
- Implementations are swapped in `AppDependencies.swift`.
- Heavy services are actor-isolated; lightweight helpers are `Sendable` value types.

### Models (`app-four/Models/`)

- SwiftData `@Model` classes.
- `Recording` is the central entity; `MedicationEvent`, `TranscriptionSegment`, `RecordingTag`, `AppSettings`, and `ModelMetadata` support it.
- JSON-encoded arrays are stored as strings for complex sub-structures (e.g., `summaryBulletsJSON`).

---

## Dependency Injection

Injection happens at the composition root (`app-four/App/SquirlApp.swift`):

```swift
RootContainerView(...)
    .modelContainer(AppModelContainer.container)
    .environment(AppDependencies.store)
    .environment(AppDependencies.medicationBarViewModel)
    .environment(AppDependencies.screenTracker)
    .environment(AppDependencies.services)
    .environment(\.diagnosticsStore, AppDependencies.diagnosticsStore)
```

`AppDependencies` is a `@MainActor` enum that constructs singletons:

```swift
enum AppDependencies {
    static let store = RecordingStore(context: AppModelContainer.container.mainContext)
    static let audioService: AudioRecordingService = AudioRecordingServiceImpl()
    static let transcriptionService: TranscriptionService = sharedWhisperKitService
    static let summarizationService: SummarizationService = NLSummarizationService()
    static let services = AppServices(...)
}
```

Views read the bundle through `@Environment(AppServices.self)`. This rule keeps views and ViewModels decoupled from concrete implementations and makes unit testing and SwiftUI previews straightforward.

---

## Data Flow

### Voice Check-In Flow

1. `CheckInViewModel` asks `AudioRecordingService` to start recording.
2. User stops recording; service returns `(fileURL, duration)`.
3. `AudioFileStorageService` moves the file to the persistent `Recordings/` directory and creates a `Recording` with status `.recorded`.
4. `CheckInViewModel` asks `TranscriptionService` to transcribe the file.
5. `TranscriptionService` emits `TranscriptionSegmentDTO`s via `AsyncStream`; the ViewModel appends them to `Recording.fullTranscriptText`.
6. When transcription completes, `SummarizationService` extracts structured signals from the transcript.
7. `Recording.applySummary(_:)` writes the extraction result onto the model in one place.
8. `Recording.setMedicationEvents(from:durationHours:context:)` creates or updates `MedicationEvent` rows.
9. `RecordingStore.save()` persists changes and notifies observers.

### Pending-Transcription Queue

If a recording is captured before the Whisper model is downloaded, it is saved with status `.pendingTranscription`. On app launch, foreground, and download completion, `PendingTranscriptionService.drainIfModelReady()` processes the queue serially.

### Text Check-In Flow

1. User selects mood/energy/focus, optionally types a note, and picks medications.
2. `RecordingStore.createCheckInNote(_:)` (or `persistCheckInNote(_:)`) creates a `Recording` with status `.completed` and user-authoritative scalar values.
3. If a note is present, `SummarizationService` runs `applySummary(fillOnly: true)` so NLP fills only the fields the user left blank.

---

## Concurrency Model

- **Main actor** for all UI updates and SwiftData mutations.
- **Actor-isolated services** for stateful heavy work (`WhisperKitTranscriptionService` is an `actor`).
- **`Task.detached`** for CPU-bound NLP extraction (`NLNoteExtractor`).
- **`AsyncStream`** for progress events (audio levels, transcription segments, download progress).
- **Serial test execution** — the suite is not parallel-safe because it shares the in-memory SwiftData container and file system.

---

## Privacy & Security

- All audio, transcripts, and extracted signals stay on device.
- Whisper transcription and NLP extraction run locally.
- The SwiftData store directory is marked `isExcludedFromBackupKey` to keep health data out of iCloud backups.
- `ExportService` produces encrypted exports before any data leaves the device.
- No analytics SDK or remote logging is wired.

---

## Machine Learning Pipeline

### Transcription

- **Model:** OpenAI Whisper Small via `WhisperKit`.
- **Service:** `WhisperKitTranscriptionService` (actor-isolated).
- **Download:** `AIModelServiceImpl` downloads the model to the app Library directory. Filesystem presence is the source of truth.
- **Prompt:** `DecodingOptions` include ADHD-biased vocabulary and medication names to improve domain accuracy.
- **Memory:** `unloadModel()` is called immediately after transcription to free Metal/CoreML RAM.

### Extraction

- **Engine:** Apple `NaturalLanguage` + custom lexicon-driven `NLNoteExtractor`.
- **Service:** `NLSummarizationService` adapts the extractor output to `SummaryResult`.
- **Characteristics:** Deterministic, instant, no model download, runs off the main actor.

---

## Key Design Decisions

See [`docs/ADRs/`](../ADRs/) for full decision records. Summary:

| Decision | Rationale |
|----------|-----------|
| MVVM + Store + DI | Keeps views testable and business logic centralized. |
| Protocol-oriented services | Enables mocks, previews, and backend swaps without view changes. |
| SwiftData for persistence | Native iOS 17 solution with SwiftUI integration; schema migrations are a known pre-launch gap. |
| Offline-first / on-device ML | Privacy requirement for health/journaling data. |
| Whisper Small + deterministic NLP | Whisper gives accurate transcription; deterministic NLP keeps extraction explainable and offline. |
| `@Observable` ViewModels | Modern SwiftUI observation with granular updates. |
| Environment-based DI | No singleton access from views; dependencies are explicit and replaceable. |
| Debug-only mock seeding | Keeps release builds clean while giving developers populated timelines. |

---

## Module Map

### App Target (`app-four/`)

| Directory | Responsibility |
|-----------|----------------|
| `App/` | Composition root, model container, package re-exports |
| `Models/` | SwiftData schema and enums |
| `Services/` | Protocols and implementations |
| `Store/` | Central state and dependency wiring |
| `ViewModels/` | Screen coordinators |
| `Views/` | SwiftUI screens and components |
| `DesignSystem/` | App-specific chrome and overlays |
| `Utils/` | Cross-cutting helpers |
| `Resources/` | Info.plist and bundled resources |

### Local Packages (`Packages/`)

| Package | Responsibility |
|---------|----------------|
| `SquirlSignals` | Level enums shared across app and design system |
| `SquirlDesignSystem` | Tokens, typography, palette, signal glyphs, reusable components |

### Supporting Projects

| Project | Responsibility |
|---------|----------------|
| `WhisperCLI/` | macOS SPM executable for WhisperKit experimentation |
| `SandboxApp/` | XcodeGen-driven design-system sandbox |
