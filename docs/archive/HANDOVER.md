> **⚠️ HISTORICAL SNAPSHOT — superseded.** Frozen 2026-06-15. Pre-app-four (WhisperNotes/app-two era); does not reflect current project state. Current architecture lives in the Notion `app-two` DB, [docs/BACKLOG.md](../BACKLOG.md), and [docs/DEVLOG.md](../DEVLOG.md). Any "Gemma" mention is historical — Gemma was removed before the app-four fork.

# WhisperNotes: Master Handover Document

This document primes a new agent with the full context, architectural rules, and current progress of the WhisperNotes project.

---

## Fast-Start Prompt

> "I am continuing work on **WhisperNotes**, a privacy-first iOS 26 app for on-device voice transcription and AI summarization.
>
> **Instructions:**
> 1. Read `system_instructions.md`, `project_architecture.md`, and `project_context.md`.
> 2. The core recording, transcription (WhisperKit `openai_whisper-small`), live transcription, Gemma summarization, diagnostics, and beta feedback systems are all **complete**.
> 3. Outstanding work: wire Pause/Resume in `RecordView`, implement Clear All Data in `SettingsView`, add Folders, SRT export, and Shortcuts integration.
> 4. Adhere strictly to **Swift 6 Concurrency**, **@Observable**, and the **Liquid Glass UI** system."

---

## Technical Foundation

### Core Stack
- **Architecture**: Service-Oriented MVVM.
- **Concurrency**: Swift 6 (Strict). `AsyncStream` for all hardware data flow (audio levels, buffers, transcription).
- **Persistence**: SwiftData for recordings; JSON flat file (`Documents/Diagnostics/sessionSnapshots.json`) for diagnostics.
- **AI**: WhisperKit (CoreML, `openai_whisper-small`) targeting the Apple Neural Engine.
- **Summarization**: Gemma 3 1B IT (CoreML) via `GemmaInferenceEngine`.

### Mandatory Constraints
- **Sampling Rate**: All audio is converted to **16kHz Mono PCM** before the AI engine (`AudioRecordingServiceImpl`).
- **File Limits**: Max **300 lines** per file.
- **UI**: `.ultraThinMaterial`, `.glassCard()` modifier, `24pt` corners, `GlassTypography` constants.
- **Privacy**: No audio or transcript data leaves the device. The only outbound network call is the Gemma model download from `ModelConstants.gemmaDownloadURL`.

---

## Current Status

### Completed ✅
1. **Phase 1 — UI Shell**: All tabs, Liquid Glass components, mock waveform.
2. **Phase 2A — Data Layer**: SwiftData schema (`Recording`, `TranscriptionSegment`, `ModelMetadata`, `AppSettings`), service protocols, enums.
3. **Phase 2B — Audio Engine**: `AVAudioEngine` + `AVAudioConverter` 16kHz resampling tap; interruption handling; max-duration auto-stop (8 min).
4. **Phase 2C — WhisperKit Transcription**: `WhisperKitTranscriptionService` with medical prompt conditioning, `MedicalTermCorrector` post-processing, live transcription via `liveAudioStream`, post-recording background transcription with 90s timeout.
5. **Phase 2D — Gemma Summarization**: `GemmaInferenceEngine` (dynamic CoreML feature inspection), `GemmaSummarizationService` with load/infer/unload pattern and 30s timeout; `RecordingDetailViewModel` drives generate/regenerate with model auto-download.
6. **Phase 2E — Diagnostics**: `SessionSnapshot` (thermal state, available RAM, inference duration, screen name), `DiagnosticsStore` (actor, rolling 50-snapshot JSON file), `MetricManager` (MetricKit subscriber), `ScreenTracker` (current visible screen).
7. **Phase 2F — Beta Feedback**: `FeedbackButton` (DEBUG/TESTFLIGHT overlay), `IssueReportView` (opt-in sensitive data toggles, MFMailComposeViewController with share sheet fallback), `MailComposeView`, `ShareSheetView`, `ScreenshotCapture`.
8. **Library Features**: Full-text title search, topic category filter chips (`TopicCategory`: Medications, Symptoms, Appointments, Procedures, General), swipe-to-delete.
9. **Settings**: Model download/delete for both Whisper and Gemma, storage display, Medical Context Prompt toggle (`UserDefaults["medicalPromptEnabled"]`), Reduce Motion toggle, cellular download toggle, 5-tap debug sheet.
10. **URL Scheme**: `whispernotes://checkin` deep link navigates to Record tab and auto-starts recording.

### Outstanding ⏭️
1. **Pause/Resume in UI**: `RecordViewModel.pauseRecording()` / `resumeRecording()` exist but are not wired to the pause button in `RecordView` (currently `break`).
2. **Clear All Data**: Button is rendered in `SettingsView` but has no implementation.
3. **Folders**: No `Folder` model or grouping UI exists.
4. **SRT Export**: `ExportFormat.srt` is declared but not implemented in `AudioFileStorageServiceImpl`.
5. **Shortcuts Integration**: Not started.

---

## Critical File Map

| File | Purpose |
| :--- | :--- |
| `system_instructions.md` | **Read first.** Mandated coding and design standards. |
| `App/WhisperNotesApp.swift` | App entry; initializes `AppDependencies.store`, `MetricManager`, handles URL scheme. |
| `App/AppModelContainer.swift` | SwiftData `ModelContainer` (production + preview). |
| `Store/AppDependencies.swift` | Central dependency injector for all services and stores. |
| `Store/RecordingStore.swift` | `@Observable` SwiftData wrapper; in-memory recordings array. |
| `Services/Protocols.swift` | All service protocol definitions + `TranscriptionSegmentDTO` + `GemmaAnalysisResult`. |
| `Services/Audio/AudioRecordingServiceImpl.swift` | AVAudioEngine recording + 16kHz resampling tap. |
| `Services/WhisperKit/WhisperKitTranscriptionService.swift` | Whisper transcription (file + live stream); model load/unload; medical prompt. |
| `Services/GemmaSummarizationService.swift` | Gemma inference actor; load/predict/unload; structured output parser. |
| `Services/GemmaInferenceEngine.swift` | CoreML wrapper for Gemma; dynamic string feature discovery. |
| `Services/AIModelServiceImpl.swift` | Model download/delete/status for both Whisper and Gemma. |
| `ViewModels/RecordViewModel.swift` | Orchestrates recording, live transcription, post-recording background transcription. |
| `ViewModels/RecordingDetailViewModel.swift` | Drives Gemma summarization, model auto-download, favorite/delete/export. |
| `ViewModels/LibraryViewModel.swift` | Filtered/searched recordings list. |
| `ViewModels/SettingsViewModel.swift` | Model install status, storage, preference toggles. |
| `Diagnostics/DiagnosticsStore.swift` | Actor; rolling 50-snapshot JSON persistence. |
| `Diagnostics/SessionSnapshot.swift` | Lightweight, privacy-safe system snapshot (thermal, RAM, duration). |
| `Diagnostics/MetricManager.swift` | MetricKit subscriber; logs jetsam, CPU exceptions, disk writes. |
| `Diagnostics/ScreenTracker.swift` | `@Observable` current screen name for feedback attribution. |
| `Models/Recording.swift` | SwiftData root entity; summarization fields; `topicCategories` computed property. |
| `Models/AppEnums.swift` | `RecordingStatus`, `TopicCategory`, `SummaryStatus`, `AIModelType`, etc. |
| `Utils/Constants.swift` | `AudioConstants` (16kHz, mono), `LayoutConstants` (8-min max), `ModelConstants` (Gemma URL/filename). |
| `Utils/MedicalTermCorrector.swift` | Post-processing for ADHD/therapy terminology. |
| `Views/Feedback/IssueReportView.swift` | Beta feedback form with opt-in sensitive data and Mail/share sheet sending. |

---

## Tribal Knowledge

- **Model names**: WhisperKit uses `openai_whisper-small` (stored at `Library/whisperkit/openai_whisper-small`). Gemma is `gemma-3-1b-it.coreml` (stored at `Library/gemma/`).
- **RAM management**: Both Whisper and Gemma unload their models after every inference cycle to prevent jetsam.
- **5-Tap Gesture**: In `SettingsView`, tap the version label 5× to open `TestServicesView` (debug only).
- **Medical Prompt**: Enabled via `UserDefaults["medicalPromptEnabled"]`. Whisper receives a conditioning prompt with ADHD medication names before transcribing.
- **Thread Safety**: ViewModels are `@MainActor`. Audio/AI services are `actor` types. `DiagnosticsStore` is an `actor` to keep I/O off the main thread.
- **FeedbackButton**: Only compiled in `DEBUG` or `TESTFLIGHT` builds (`#if DEBUG || TESTFLIGHT`).
- **URL Scheme**: `whispernotes://checkin` auto-navigates to tab index 1 (Record) and sets `shouldAutoStartRecording = true`.
- **HuggingFace**: WhisperKit downloads models from HuggingFace to the app's Library directory automatically on first transcription if the model is not present.
- **Whisper Download indicator**: On first use, `WhisperKitTranscriptionService` yields a "Downloading AI Model (~150MB)..." segment to the UI before downloading.
