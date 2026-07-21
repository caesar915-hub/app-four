<!-- Created: 2026-06-14 15:00 (WEST) · Updated: 2026-07-20 09:20 (WEST) -->
# WhisperNotesApp Architecture Document

_Last updated: 2026-07-20. Version 0.8.0 (build 2) — `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `app-four.xcodeproj/project.pbxproj`._

_Naming: this document keeps its legacy title, but there is no `WhisperNotesApp` target. The Xcode target and product are **`app-four`** (`productName = "app-four"`), the compiled Swift module is **`app_four`** (`@testable import app_four` in the test target), and the shipping product/display name is **Squirl** (`INFOPLIST_KEY_CFBundleDisplayName = Squirl`; the Stable channel ships as "Squirl Stable"). "WhisperNotes" survives only as the internal codename and the `whispernotes://` deep-link scheme (`App/SquirlApp.swift:53`)._

This document outlines the architectural patterns, service interactions, design decisions, and machine learning model management for the app. It is grounded in the code as of the `feat/038-icloud-sync` branch; the five Architecture Decision Records in [`docs/ADRs/`](../ADRs/) hold the canonical rationale for each decision below.

## 1. High-Level Architecture

The application employs an **MVVM (Model-View-ViewModel)** architectural pattern augmented by a centralized **Store** and a **Dependency Injection (DI)** container.

- **Model Layer (`Models/`)**: Defines the data structures. `SwiftData` is used for persistence. The versioned schema `SquirlSchemaV1` (`App/SquirlSchema.swift`) declares six `@Model` types — `Recording`, `TranscriptionSegment`, `RecordingTag`, `MedicationEvent`, `AppSettings`, and `ModelMetadata`. `App/AppModelContainer.swift` builds them into a single `ModelContainer` split across two `ModelConfiguration`s: a **Synced** store (`Recording`, `TranscriptionSegment`, `RecordingTag`, `MedicationEvent`) and a **Local** store (`AppSettings`, `ModelMetadata`, never synced) — see §6.
- **Store (`Store/RecordingStore.swift`)**: Wraps the `ModelContext` to provide a single, thread-safe access point for CRUD operations. This prevents scattered database logic across the app.
- **Service Layer (`Services/`)**: Contains protocol-driven local backend services. They handle low-level operations like audio recording, file storage, AI model downloading, and ML inference.
- **ViewModel Layer (`ViewModels/`)**: Coordinates between Views, Services, and the Store. They are marked `@Observable` and run on the `@MainActor`. They handle state changes, error catching, and async task orchestration.
- **View Layer (`Views/`)**: Pure SwiftUI views that observe ViewModels or the Store. They do not contain complex business logic.

## 2. Frontend-Backend Interaction

Because WhisperNotesApp is an entirely **local, offline-first application**, the "backend" consists of local services and CoreML inference engines rather than a remote API. 

**Dependency Injection Flow**:
1. At app launch, `AppDependencies` creates global singletons for the Store and all Services (e.g., `AudioRecordingServiceImpl`, `WhisperKitTranscriptionService`).
2. These services are bundled into an `@Observable` class called `AppServices`.
3. `AppServices` is injected into the SwiftUI view hierarchy using `.environment(AppDependencies.services)`. Alongside it, `SquirlApp` injects a few singletons directly rather than through the bundle — `RecordingStore`, `MedicationBarViewModel`, `ScreenTracker`, `AppIntentRouter`, and `DiagnosticsStore` (`App/SquirlApp.swift:42-47`).
4. Views instantiate their ViewModels and pass the required services from the environment into the ViewModel's initializer.

**Asynchronous Communication**:
- **Async/Await**: ViewModels interact with services using Swift Concurrency. 
- **Streaming**: Services return `AsyncStream<T>` for incremental work — live audio levels during recording (`audioLevelStream`) and decoded transcription segments (`TranscriptionSegmentDTO`) emitted as a *finished* recording is transcribed. The ViewModel iterates the stream in a background `Task` and updates its published properties, which in turn drive the UI. (Real-time transcription of the live mic was removed: its `AVAudioEngine` tap muted the recorder.)
- **Task Management**: ViewModels maintain references to active `Task`s. If a user cancels an operation (like recording), the ViewModel calls `.cancel()` on the task, and the service cleans up resources.

## 3. Design Decisions

- **Strict Protocol-Oriented Services**: Every core capability (Audio, Storage, Transcription, Summarization) is hidden behind a protocol. This makes it trivial to swap out implementations or inject mocks (like `MockTranscriptionService`) for testing and SwiftUI Previews. The `TranscriptionService` protocol already has two real backends — `WhisperKitTranscriptionService` (the wired default) and an alternate `SpeechTranscriptionService` (Apple Speech framework) — selectable at the DI seam in `AppDependencies`.
- **On-Device First for Privacy** (ADR 002/003/005): All capture, transcription, and NL extraction happen on-device — no audio or transcript is sent to any third-party server. The SwiftData store directory is flagged `isExcludedFromBackupKey` (`App/AppModelContainer.swift:65`) to keep sensitive transcript/medication data out of iCloud *device backup*. This is now distinct from the opt-in iCloud *sync* seam (§6): when a user turns sync on, the Synced store mirrors to *their own* private CloudKit database (off by default), which the code notes is end-to-end-encryptable under Advanced Data Protection — it is never a shared or Squirl-operated server.
- **Debug-Only Seeded Data**: On `#if DEBUG` builds, `MockDataGenerator` seeds ~10 days of synthetic recordings and medication events into an empty store (and a separate in-memory `previewContainer` for SwiftUI Previews), so Insights/Calendar/Library can be exercised without real check-ins. Never present in release builds.
- **Eager Memory Management (RAM Isolation)**: Whisper is heavy, so `WhisperKitTranscriptionService.unloadModel()` is called *immediately* after a transcription finishes, explicitly freeing Metal/CoreML RAM before any downstream work runs.
- **Model Availability**: Filesystem presence is the absolute source of truth for whether the Whisper model is installed; SwiftData `ModelMetadata` mirrors it.
- **Timeouts and Fallbacks**: Asynchronous tasks like transcription are wrapped in `withThrowingTaskGroup` with explicit timeouts. If the model hangs or takes too long, the task throws a timeout error, preventing the UI from locking up indefinitely and allowing the user to retry later.

## 4. How Models are Loaded and Used

Transcription uses one primary on-device model — **OpenAI Whisper Small**. Summarization/extraction is **not** model-based: it runs on Apple's `NaturalLanguage` framework via `NLNoteExtractor` (instant, no download). See [Services/NoteExtraction/README.md](../../app-four/Services/NoteExtraction/README.md).

**Model Management (`AIModelServiceImpl`)**:
- Manages the download and lifecycle of the Whisper model (via `WhisperKit`) into the app's Library directory.

**Whisper (`WhisperKitTranscriptionService`)**:
- **Loading**: Loaded asynchronously using `WhisperKit`. Can be pre-loaded in the background while the user is still recording to eliminate wait time when they hit stop.
- **Usage**: Transcribes a completed `URL` audio file, emitting `TranscriptionSegmentDTO`s as an `AsyncStream` while it decodes. Uses a specialized `DecodingOptions` prompt heavily biased towards ADHD vocabulary and medication names to improve domain-specific accuracy.
- **Unloading**: Explicitly set to `nil` upon completion to release Metal/CoreML resources.

**Summarization (`NLSummarizationService` → `NLNoteExtractor`)**:
- On-device, deterministic lexicon + `NaturalLanguage` extraction. No CoreML model, no download, runs off the main actor.

## 5. Isolation of Concerns

- **Separation of State and Logic**: The Views only define *how* things look based on state. The ViewModels own the state and define *what* happens when a user taps a button.
- **MainActor Enforcement**: All UI updates and SwiftData mutations are forced onto the `@MainActor` to prevent data races. Heavy lifting (transcription, file manipulation, downloading, NL extraction) happens off the main actor (e.g., `WhisperKitTranscriptionService` is an `actor`; `NLNoteExtractor` is a `nonisolated` value type run via `Task.detached`).
- **Diagnostics Isolation**: Metrics and session snapshots (timing how long transcription takes, token counts) are handled by a dedicated `DiagnosticsStore`, ensuring telemetry code doesn't clutter business logic.
- **File System Abstraction**: The ViewModels never construct file paths or deal with URLs directly. They ask `AudioFileStorageService` to persist audio, and the service returns an abstracted `Recording` object.

## 6. System Integration Layers

Two capability layers sit outside the core capture → transcribe → extract pipeline: one exposes the app to the OS, the other to iCloud. They differ sharply in maturity — one is shipped, the other is in-progress scaffolding.

### App Intents (`Intents/`, spec 030) — shipped

The app exposes actions to Siri, Spotlight, and Shortcuts via App Intents, merged to `main`:

- **`LogDefaultDoseIntent`** ("Log My Meds") — a background intent that logs the default medication dose without opening the app, translating over `DoseLogService` (`Services/DoseLog/`); its `.foreground(.dynamic)` path serves only the not-configured case.
- **`StartCheckInIntent`** ("Check In") — a foreground intent that lands the app in an active voice check-in.
- Both route through the single `AppIntentRouter` choke point (`Intents/AppIntentRouter.swift`), which also backs the legacy `whispernotes://checkin` deep link and enforces the onboarding gate. `SquirlAppShortcuts` (an `AppShortcutsProvider`) makes them discoverable from install with zero setup.
- Wiring: `SquirlApp.init()` registers `doseLogService` and `router` with `AppDependencyManager` before any `perform()` runs (`App/SquirlApp.swift:28-31`). `doseLogService` is intentionally NOT part of the `AppServices` bundle — it owns the expedited dose write consumed only by the intent, never by the in-app Log Dose sheet (`Store/AppDependencies.swift:24-26`).

### iCloud Sync (`Services/Sync/`, spec 038) — IN PROGRESS, not yet shipped

> Status (branch `feat/038-icloud-sync`, verified 2026-07-20): scaffolded and wired at the composition root but **uncommitted** — `Services/Sync/`, `App/SyncFlags.swift`, `App/SquirlSchema.swift`, and `Services/Mock/MockCloudSyncService.swift` are still untracked, and the branch has zero commits beyond `main` (`git rev-list --count main..HEAD` → 0). A first UI consumer now exists in the working tree: `SyncSettingsViewModel` (`ViewModels/SyncSettingsViewModel.swift`) driving Settings' `ICloudSyncSection` (`Views/SettingsView.swift:60`) — also uncommitted, and the iCloud entitlement is not yet in the build target. Treat everything below as in-progress, not live.

- **Off by default (FR-001).** The toggle lives in `UserDefaults` via `SyncFlags` (`App/SyncFlags.swift`), *not* in SwiftData — the container reads it at build time before any store is open, and the flag must never itself sync across devices.
- **Two-configuration container.** `AppModelContainer` gives the Synced store `cloudKitDatabase: .private("iCloud.Rythm-App.app-four")` only when the flag is on, else `.none`; the Local store is always `.none` (`App/AppModelContainer.swift:35-49`). Enabling/disabling takes effect on the *next* container build (app relaunch) — SwiftData has no supported live hot-swap ("Pattern A").
- **Mockable seam (ADR 004 / Constitution VIII).** `CloudSyncService` (`Services/Sync/CloudSyncService.swift`) is a `Sendable` protocol; `CloudSyncServiceImpl` is an `actor` over CloudKit; `MockCloudSyncService` substitutes in tests. It is registered in `AppDependencies` (`cloudSyncService`, `Store/AppDependencies.swift:38`) and deliberately absent from the `AppServices` bundle; the Settings sync view-model (`SyncSettingsViewModel`, US1) reads it directly via its default init argument.
- **Content-free status types.** `SyncAccountStatus`, `SyncFailure`, `SyncPhase`, and `SyncState` name only the *condition* (mapped from `CKAccountStatus` / `CKError`), never any transcript or medication content, and never report a success that did not happen.
- **Versioned schema wired ahead.** `SquirlSchemaV1` + the empty-stage `SquirlMigrationPlan` (`App/SquirlSchema.swift`) exist so the next schema change is a clean V1→V2 migration; moving from the pre-038 single `default.store` to the two named stores abandons old rows once, acceptable pre-release (Constitution IX).
- **Reconciliation with ADR 002.** ADR 002 (Accepted) still records "no cloud sync … CloudKit sync: rejected." Spec 038 revisits that stance with an opt-in, off-by-default, user-private-database design; ADR 002 has **not** yet been superseded or updated. This tension must be resolved in the ADRs when 038 ships — the sync layer above is not a repudiation of ADR 002's privacy stance but an evolution of it, and until 038 lands the ADR remains authoritative.
