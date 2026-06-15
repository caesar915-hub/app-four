> **⚠️ HISTORICAL SNAPSHOT — superseded.** Frozen 2026-06-15. Pre-app-four (WhisperNotes/app-two era); does not reflect current project state. Current architecture lives in the Notion `app-two` DB, [docs/BACKLOG.md](../BACKLOG.md), and [docs/DEVLOG.md](../DEVLOG.md). Any "Gemma" mention is historical — Gemma was removed before the app-four fork.

# WhisperNotes: Project Architecture

WhisperNotes is built on a **Service-Oriented MVVM** architecture, strictly adhering to **Swift 6 Concurrency** patterns and **SwiftData** for persistence.

## 1. Architectural Layers

### A. View Layer (SwiftUI)
- **Role**: Pure UI representation and user input handling.
- **Styling**: "Liquid Glass" aesthetic using `.ultraThinMaterial`, `.glassCard()` modifier, `24pt` rounded corners, and `GlassTypography` constants.
- **State Management**: `@State` to own ViewModels; `@Query` (SwiftData) for lists; `@Observable` observation for ViewModel properties.
- **Constraints**: Views are "dumb" — all business logic delegates to ViewModels.

Key views:
| View | Description |
| :--- | :--- |
| `RootTabView` | Tab container: Library (0), Record (1), Settings (2). |
| `LibraryView` | Recording list with search, topic filter chips, swipe-to-delete. |
| `RecordView` | Record/Stop/Cancel controls, `AudioWaveform`, `RecordingStatusPill`. |
| `RecordingDetailView` | Transcript, `SummaryCard`, topic chips, favorite/export/delete toolbar. |
| `SettingsView` | Model download rows, storage, Medical Prompt toggle, 5-tap debug sheet. |
| `IssueReportView` | Beta feedback form with opt-in sensitive data toggles; Mail/share sheet sending. |

### B. ViewModel Layer (@Observable)
- **Role**: State orchestration and bridge between Services and Views.
- **Concurrency**: `@MainActor` — thread-safe UI updates.
- **Dependency Injection**: Services injected via `AppDependencies`.
- **Communication**: ViewModels consume `AsyncStream` from Services using `for await` loops in `Task` closures.

Key ViewModels:
| ViewModel | Responsibilities |
| :--- | :--- |
| `RecordViewModel` | Recording lifecycle, timer, live transcription stream, background post-recording transcription (90s timeout). |
| `RecordingDetailViewModel` | Gemma summarization (generate/regenerate), model auto-download, favorite/delete/export. |
| `LibraryViewModel` | Filtered/searched recording list via `RecordingStore`. |
| `SettingsViewModel` | Model install status, storage bytes, preference toggles synced to SwiftData/`UserDefaults`. |

### C. Service Layer (Protocols + Actors)
- **Role**: Hardware interaction, AI inference, and storage.
- **Pattern**: Protocol-first design enables testing and swapping implementations.
- **Concurrency**: `actor` for services with shared mutable state.

Key services and protocols:

| Protocol | Implementation | Notes |
| :--- | :--- | :--- |
| `AudioRecordingService` | `AudioRecordingServiceImpl` | `AVAudioRecorder` (M4A file) + `AVAudioEngine` tap (16kHz PCM `AsyncStream`). |
| `TranscriptionService` | `WhisperKitTranscriptionService` | File-based transcription; medical prompt; model load/unload. |
| `LiveTranscriptionService` | `WhisperKitTranscriptionService` | Same actor; accumulates PCM frames, transcribes every 2s. |
| `AudioFileStorageService` | `AudioFileStorageServiceImpl` | Moves temp files; deletes; exports. |
| `AIModelService` | `AIModelServiceImpl` | Download/delete/status for Whisper and Gemma via SwiftData `ModelMetadata`. |
| `SummarizationService` | `GemmaSummarizationService` | Gemma load/infer/unload; 30s timeout; structured output parser. |

#### Audio Pipeline
```
Microphone → AVAudioEngine tap → AVAudioConverter (→ 16kHz PCM)
  ├─ liveAudioStream  → WhisperKitTranscriptionService.transcribe(liveStream:)
  │                      (accumulates 2s batches → AsyncStream<String>)
  │                      → RecordViewModel.liveTranscriptText
  └─ AVAudioRecorder  → M4A file → AudioFileStorageServiceImpl.saveRecording()
                          → WhisperKitTranscriptionService.transcribe(audioURL:)
                          → Recording.fullTranscriptText (background, 90s timeout)
```

#### AI Inference Pattern
Both Whisper and Gemma use a **load → infer → unload** pattern to prevent jetsam:
- Model is loaded on demand, never kept resident.
- `defer { model.unload() }` ensures release even on error.

### D. Data Layer (SwiftData)
- **Role**: Persistent storage of recordings, transcripts, model metadata, and settings.
- **Schema**:

| Model | Key Fields |
| :--- | :--- |
| `Recording` | `audioFileName`, `duration`, `status`, `fullTranscriptText`, `title`, `isFavorite`, `summary`, `summaryStatus`, `topicTagsJSON`, `summaryGeneratedAt`. |
| `TranscriptionSegment` | `text`, `startTime`, `endTime`, `isFinal`, `confidence`; cascade-deleted with parent `Recording`. |
| `ModelMetadata` | `modelName`, `modelType` (`AIModelType`), `isDownloaded`, `isCorrupted`. |
| `AppSettings` | `hasCompletedOnboarding`, `defaultLanguage`, `reduceMotionEnabled`, `downloadOverCellular`. |

`RecordingStore` is an `@Observable` wrapper that keeps an in-memory `[Recording]` array always in sync with SwiftData.

### E. Diagnostics Layer
Captures lightweight, privacy-safe system snapshots before/after every heavy operation. Complements MetricKit (which only delivers aggregated 24h payloads).

| Component | Role |
| :--- | :--- |
| `SessionSnapshot` | `Codable` struct: thermal state, available RAM (MB), Whisper/Gemma inference duration (ms), screen name, app build, iOS version. **Never includes transcript or audio data.** |
| `DiagnosticsStore` | `actor`; rolling 50-snapshot buffer; persists to `Documents/Diagnostics/sessionSnapshots.json`. |
| `MetricManager` | `MXMetricManagerSubscriber`; logs jetsam counts, CPU exceptions, disk write exceptions to console. |
| `ScreenTracker` | `@Observable @MainActor`; tracks `currentScreen` string; set from each view's `.onAppear`. |

### F. Feedback System
Available in `DEBUG` and `TESTFLIGHT` builds only (`#if DEBUG || TESTFLIGHT`).

| Component | Role |
| :--- | :--- |
| `FeedbackButton` | Floating overlay button (bottom-trailing, above tab bar). |
| `IssueReportView` | Form sheet; auto-captures context from `DiagnosticsStore` and `ScreenTracker`; all sensitive-data toggles default OFF. |
| `MailComposeView` | `UIViewControllerRepresentable` wrapping `MFMailComposeViewController`. |
| `ShareSheetView` | Fallback `UIActivityViewController` when Mail is unavailable. |
| `ScreenshotCapture` | Captures a screenshot at report time for attachment. |

---

## 2. Key Technical Patterns

### Reactive Streams (AsyncStream)
Services push data via `AsyncStream`. ViewModels pull using `for await` in `Task` closures (cancelled via `task.cancel()` on ViewModel deallocation or state change).

### Global Dependency Locator
`AppDependencies` provides a single, strictly typed access point for all services. Services are singletons shared across the app to avoid redundant model loading.

`WhisperKitTranscriptionService` is a shared `actor` instance registered for both `TranscriptionService` and `LiveTranscriptionService` so it can be cancelled from either interface.

### UserDefaults Preferences
Two settings are stored in `UserDefaults` rather than SwiftData for lightweight read access from inside actor contexts:
- `reduceMotion` (Bool)
- `medicalPromptEnabled` (Bool) — read by `WhisperKitTranscriptionService` when building `DecodingOptions`.

### URL Scheme Deep Link
`whispernotes://checkin` is handled in `WhisperNotesApp.body` via `.onOpenURL`. It navigates to the Record tab and sets `shouldAutoStartRecording = true`, which `RecordView` consumes on `.onAppear`.

### Unified Logging
`AppLogger.log()` provides a central point for all significant events (hardware start/stop, AI inference progress, disk errors). Visible in the Xcode console and appended to feedback reports.
