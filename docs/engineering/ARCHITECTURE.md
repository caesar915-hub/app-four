# WhisperNotesApp Architecture Document

_Last updated: 2026-06-14. Codebase target is `WhisperNotesApp`; the app ships as **Squirl** (display name)._

This document outlines the architectural patterns, service interactions, design decisions, and machine learning model management for WhisperNotesApp.

## 1. High-Level Architecture

The application employs an **MVVM (Model-View-ViewModel)** architectural pattern augmented by a centralized **Store** and a **Dependency Injection (DI)** container.

- **Model Layer (`Models/`)**: Defines the data structures. `SwiftData` is used for persistence. The container schema is `Recording`, `TranscriptionSegment`, `ModelMetadata`, `AppSettings`, `RecordingTag`, and `MedicationEvent` (see `App/AppModelContainer.swift`).
- **Store (`Store/RecordingStore.swift`)**: Wraps the `ModelContext` to provide a single, thread-safe access point for CRUD operations. This prevents scattered database logic across the app.
- **Service Layer (`Services/`)**: Contains protocol-driven local backend services. They handle low-level operations like audio recording, file storage, AI model downloading, and ML inference.
- **ViewModel Layer (`ViewModels/`)**: Coordinates between Views, Services, and the Store. They are marked `@Observable` and run on the `@MainActor`. They handle state changes, error catching, and async task orchestration.
- **View Layer (`Views/`)**: Pure SwiftUI views that observe ViewModels or the Store. They do not contain complex business logic.

## 2. Frontend-Backend Interaction

Because WhisperNotesApp is an entirely **local, offline-first application**, the "backend" consists of local services and CoreML inference engines rather than a remote API. 

**Dependency Injection Flow**:
1. At app launch, `AppDependencies` creates global singletons for the Store and all Services (e.g., `AudioRecordingServiceImpl`, `WhisperKitTranscriptionService`).
2. These services are bundled into an `@Observable` class called `AppServices`.
3. `AppServices` is injected into the SwiftUI view hierarchy using `.environment(AppDependencies.services)`.
4. Views instantiate their ViewModels and pass the required services from the environment into the ViewModel's initializer.

**Asynchronous Communication**:
- **Async/Await**: ViewModels interact with services using Swift Concurrency. 
- **Streaming**: Services return `AsyncStream<T>` for incremental work — live audio levels during recording (`audioLevelStream`) and decoded transcription segments (`TranscriptionSegmentDTO`) emitted as a *finished* recording is transcribed. The ViewModel iterates the stream in a background `Task` and updates its published properties, which in turn drive the UI. (Real-time transcription of the live mic was removed: its `AVAudioEngine` tap muted the recorder.)
- **Task Management**: ViewModels maintain references to active `Task`s. If a user cancels an operation (like recording), the ViewModel calls `.cancel()` on the task, and the service cleans up resources.

## 3. Design Decisions

- **Strict Protocol-Oriented Services**: Every core capability (Audio, Storage, Transcription, Summarization) is hidden behind a protocol. This makes it trivial to swap out implementations or inject mocks (like `MockTranscriptionService`) for testing and SwiftUI Previews. The `TranscriptionService` protocol already has two real backends — `WhisperKitTranscriptionService` (the wired default) and an alternate `SpeechTranscriptionService` (Apple Speech framework) — selectable at the DI seam in `AppDependencies`.
- **Offline First for Privacy**: To ensure user privacy (especially for medical/journaling contexts), all ML processing happens on-device. No audio or transcriptions are sent to a server. The SwiftData store directory is also flagged `isExcludedFromBackupKey`, keeping sensitive transcript/medication data out of iCloud backups.
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
