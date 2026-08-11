<!-- Created: 2026-08-11 21:20 (WEST) · Updated: 2026-08-11 21:20 (WEST) -->
# 04a — WhisperKit Transcription & Model Management

Documents branch `main` @ `43eb6515a63a0eca957a79aad257da380c73edd4`. All `path:line` citations are against `main`. This document is **code-aligned** — every requirement traces to a verified source file and line range.

## Purpose

Describe how captured audio becomes a raw transcript string: the on-device WhisperKit transcription actor, the medical-context prompt, non-speech marker stripping, the pending-transcription queue, the AI model download/delete lifecycle, memory management (Peak Shaving), and the transcription flow through `CheckInViewModel` / `ProcessingViewModel` / `PendingTranscriptionServiceImpl`.

This document covers **everything up to the moment a clean transcript string is handed to the extraction service**. The extraction service itself (currently `NLSummarizationService`, migrating to `MLXJournalService`) is documented in [04b — LLM Extraction & Lexicon](04b-llm-extraction-lexicon.md).

## Scope

- **In scope**: `WhisperKitTranscriptionService`, `PendingTranscriptionServiceImpl`, `AIModelServiceImpl`, `CheckInViewModel` (transcription flow), `ProcessingViewModel` (orchestration), `SquirlApp` (drain triggers), `RecordingStore` (orphan recovery), `Constants.swift`, `AppEnums.swift`, `TranscriptionSegmentDTO`, `AudioConverter`.
- **Out of scope**: Audio capture mechanics ([03 — Check-in Capture](../fsd/03-check-in-capture.md)), extraction/summarization ([04b — LLM Extraction & Lexicon](04b-llm-extraction-lexicon.md)), rendering of results ([05 — Library & History](../fsd/05-library-and-history.md)).

## Actors & triggers

- **User** — records a voice check-in (up to 8 mins); taps "Stop & save"; downloads/deletes the Whisper model in Settings; taps "Tap to retry" / "Retry transcription" after a failure.
- **System triggers** — app launch (`.task`), every foreground (`scenePhase == .active`), and background model download completion all trigger a pending-queue drain. Recording stop triggers transcription when the Whisper model is installed; otherwise the recording enters the pending queue.

---

## Functional requirements

### TranscriptionService protocol

The extraction pipeline depends on a `TranscriptionService` protocol. The only production implementation is `WhisperKitTranscriptionService`. The protocol surface:

```swift
protocol TranscriptionService {
    func loadModel() async throws
    func transcribe(audioURL: URL) async throws -> AsyncStream<TranscriptionSegmentDTO>
    func unloadModel() async
    func cancelTranscription() async
}
```

Each segment in the stream carries `id`, `text`, `startTime`, `endTime`, `isFinal`, `confidence`, and `isError` (`TranscriptionSegmentDTO`).

---

### WhisperKit transcription actor (`WhisperKitTranscriptionService`)

Source: [`WhisperKitTranscriptionService.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift)

- **FR-WK-01 — Actor isolation.** `WhisperKitTranscriptionService` is an `actor`, guaranteeing single-threaded access to the WhisperKit engine. There is no runtime provider switch — this is the only transcription implementation (`WhisperKitTranscriptionService.swift:7`).

- **FR-WK-02 — Model variant.** Hard-coded to `openai_whisper-small` (`WhisperKitTranscriptionService.swift:11`). The `ModelConstants.whisperDownloadBase` directory is `~/Library/whisperkit` (`Constants.swift:15-18`).

- **FR-WK-03 — Hard-coded English.** `DecodingOptions(language: "en")` — the language is always English (`WhisperKitTranscriptionService.swift:133`).

- **FR-WK-04 — ADHD medical prompt (opt-out, defaults ON).** When `UserDefaults.standard.medicalPromptEnabled` is `true` (the default), transcription is seeded with a natural-language prompt designed to bias the Whisper decoder toward ADHD medication names and journal vocabulary. The prompt reads as a representative check-in entry — not a drug leaflet — so Whisper treats it as recently-spoken context rather than an off-topic glossary:

  ```
  "Daily ADHD check-in journal. Today I woke up fine, slept 6 hours, good mood,
  energy more or less ok but I feel focused. Took the medication two hours ago,
  Concerta 36mg. Other meds: Vyvanse, Elvanse, Adderall XR, Ritalin, Strattera,
  Focalin, Dexedrine, Wellbutrin, Modafinil, methylphenidate, lisdexamfetamine,
  dextroamphetamine, atomoxetine. Hyperfocused, brain fog, executive dysfunction,
  task paralysis, initiation paralysis, stimming, body doubling, rebound, wearing
  off, afternoon crash, flat affect, appetite loss, dry mouth."
  ```

  When off (`medicalPromptEnabled == false`), `promptTokens = nil` — non-medical audio isn't dragged toward medication vocabulary. The key defaults to `true` so existing users keep the bias until they explicitly opt out in Settings → Accessibility (`Constants.swift:22-33`; `WhisperKitTranscriptionService.swift:18-31, 133-141`; `SettingsViewModel.swift:34-40`).

- **FR-WK-05 — Prompt tokenization.** The prompt string is tokenized via `whisperKit.tokenizer?.encode(text:)` into `[Int]` prompt tokens. If WhisperKit isn't loaded yet, returns `nil` (no prompt bias on that run) (`WhisperKitTranscriptionService.swift:26-31`).

- **FR-WK-06 — Non-speech marker stripping.** Before handing text downstream, a static regex removes Whisper's literal non-speech markers. The markers stripped (case-insensitive, bracket `[]` or paren `()`, `_` or space variants):

  | Marker | Description |
  |---|---|
  | `BLANK_AUDIO` / `BLANK AUDIO` | Silent audio segment |
  | `SILENCE` | Silent gap |
  | `NO_SPEECH` / `NO SPEECH` | No detected speech |
  | `MUSIC` | Background music |
  | `INAUDIBLE` | Unintelligible speech |
  | `NOISE` | Background noise |
  | `SOUND` | Non-speech sound |
  | `PAUSE` | Speaker pause |
  | `APPLAUSE` | Clapping |
  | `LAUGHS` / `LAUGHTER` | Laughter |
  | `BEEP` | Beep tone |
  | `STATIC` | Static noise |
  | `CLICKING` | Click sound |

  After stripping, 2+ whitespace characters are collapsed to a single space, and the result is trimmed. Real parentheticals like `[sound of rain]` (multi-word, not in the marker list) are left untouched (`WhisperKitTranscriptionService.swift:39-46`).

- **FR-WK-07 — Model loading.** `loadModel()` is idempotent — concurrent calls share a single `modelLoadingTask`. The `WhisperKit` initializer receives `model: "openai_whisper-small"`, `downloadBase: ModelConstants.whisperDownloadBase`, and compute options resolved from `ComputeEnvironment.preferredUnits` (CPU/GPU/ANE). Verbose logging is enabled (`WhisperKitTranscriptionService.swift:48-81`).

- **FR-WK-08 — Transcription lifecycle.** `transcribe(audioURL:)`:
  1. Creates an `AsyncStream<TranscriptionSegmentDTO>`.
  2. Cancels any prior `activeTranscriptionTask` (single-inference discipline).
  3. If the model isn't loaded, yields a progress segment (`"Setting up on-device transcription…"`) and calls `loadModel()`.
  4. Yields a `"Transcribing…"` progress segment.
  5. Resolves `promptTokens` based on `medicalPromptEnabled`.
  6. Acquires a `UIApplication.shared.beginBackgroundTask(withName: "WhisperTranscription")` so the OS doesn't suspend the app during Metal/CoreML inference.
  7. Calls `kit.transcribe(audioPath:decodeOptions:)` — a single-shot batch transcription.
  8. Joins all result texts, applies `cleanTranscript()`.
  9. Guards against empty transcription (throws `conversionFailed`).
  10. Yields the final `isFinal: true` segment.
  11. **Calls `unloadModel()` before finishing the stream** (Peak Shaving — see FR-WK-09).
  12. Finishes the continuation.
  13. Records diagnostics (`whisperDurationMs`, `transcriptionTokenEstimate`).

  On error: yields an `isError: true` segment with the error description, then unloads the model and finishes (`WhisperKitTranscriptionService.swift:83-214`).

- **FR-WK-09 — Peak Shaving (memory handoff).** The Whisper model (~150MB in unified memory) is **explicitly unloaded** (`self.whisperKit = nil`) after transcription completes — both on success and on error — *before* the stream signals completion. This ensures Metal/CoreML buffers are freed before the downstream extraction service loads its own model (currently NLExtractor, migrating to Llama 3.2 at ~740MB). On the iPhone 12 Pro's 6GB RAM under Jetsam limits (~2.5–3GB), running both models simultaneously would cause an immediate Jetsam kill (`WhisperKitTranscriptionService.swift:175, 199`).

- **FR-WK-10 — Cancellation.** `cancelTranscription()` cancels the `activeTranscriptionTask` and nils it. The model is not unloaded on cancel — only on transcription completion or error (`WhisperKitTranscriptionService.swift:221-225`).

- **FR-WK-11 — Diagnostics.** Token estimate = `audioDuration * 100` (~100 tokens/sec for whisper-small). Start and end snapshots are recorded via `DiagnosticsStore` (`WhisperKitTranscriptionService.swift:86-95, 179-184, 203-208`).

---

### Transcription flow in CheckInViewModel

Source: [`CheckInViewModel.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/CheckInViewModel.swift)

- **FR-CVM-01 — Model preloading during recording.** When `startRecording()` begins, a detached `Task.detached(priority: .utility)` preloads the Whisper model via `transcriptionService.loadModel()` while the user is still speaking. Failure is logged but non-fatal — the model will be loaded in `transcribe()` if needed (`CheckInViewModel.swift:158-164`).

- **FR-CVM-02 — Model download intercept.** If the Whisper model is not installed and not currently downloading, `startRecording()` shows `showModelDownloadPrompt` instead of starting the recording. The user can choose "Download & Record" (`startRecordingWithDownload()`) or "Record without model" (`startRecordingWithoutDownload()`). The recording proceeds either way — without the model, it will be `pendingTranscription` (`CheckInViewModel.swift:125-129, 171-201`).

- **FR-CVM-03 — Stop → save → transcribe.** `stopRecording()`:
  1. Stops timer/level tasks (but **does not cancel** any prior transcription — `cancelTranscription: false`).
  2. Awaits `audioService.stopRecording()` to get the file URL and duration.
  3. Saves to `PendingSave` buffer for retry resilience.
  4. Calls `attemptSave()` which persists the `Recording`, adds it to the store, then:
     - If the Whisper model is absent → sets `recording.status = .pendingTranscription`, saves, and returns (no transcription).
     - If present → creates `transcriptionTask` that **chains after any prior transcription** (`await priorTranscription?.value`) before calling `transcribeInBackground()`.
  
  (`CheckInViewModel.swift:203-228`)

- **FR-CVM-04 — Transcription serialization.** The prior recording's transcription task is captured before stopping, and the new transcription chains after it via `await priorTranscription?.value`. This ensures the single WhisperKit actor never runs two inferences simultaneously, and a back-to-back recording never cancels the previous one's work (`CheckInViewModel.swift:213-214, 255-260`).

- **FR-CVM-05 — 90-second transcription timeout.** `transcribeInBackground()` calls `consumeStreamWithTimeout(stream, for: recording, timeoutSeconds: 90)`, which uses a `ThrowingTaskGroup`:
  - **Consumer task** (`@MainActor`): iterates the stream, writes each segment's text to `recording.fullTranscriptText`, sets `recording.status = .transcribing`, and saves. Guards on each segment that the recording still exists in the store (user may delete it via multi-select).
  - **Timeout task**: sleeps for 90 seconds, then throws `RecordingError.timeout`.
  - Whichever finishes first wins; the other is cancelled.
  
  On timeout: `transcriptionService.cancelTranscription()` is called, then the recording is marked `.failed` with text `"Transcription timed out. Tap to retry in the recording detail view."` (`CheckInViewModel.swift:292-341, 345-376`).

- **FR-CVM-06 — Error handling.** After `consumeStreamWithTimeout`:
  - **Success**: `recording.status = .completed`, then hands off to `processingViewModel.processRawTranscription()`.
  - **CancellationError**: Marks `.failed` in a fresh, uncancelled `Task { @MainActor }` so the await to the actor doesn't get skipped by the cancellation. Text: `"Transcription cancelled. Tap to retry..."`.
  - **RecordingError.timeout**: As above.
  - **Other errors**: Marks `.failed` with the error description.
  
  All paths guard that the recording still exists in the store before touching it (`CheckInViewModel.swift:313-340`).

- **FR-CVM-07 — Deleted-during-transcription guard.** Before writing the final `.completed` status, the code checks `store.recordings.contains(where: { $0.id == recording.id })` — if the recording was deleted during transcription, the result is silently discarded (`CheckInViewModel.swift:300-303`).

---

### ProcessingViewModel (orchestration)

Source: [`ProcessingViewModel.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/ProcessingViewModel.swift)

- **FR-PVM-01 — Entry point.** `processRawTranscription(_:duration:language:audioFileName:fillOnly:)` is called by `CheckInViewModel` after transcription completes. It cancels any prior active task, then calls `run()` (`ProcessingViewModel.swift:27-40`).

- **FR-PVM-02 — Recording resolution.** `run()` fetches the `Recording` by `audioFileName` using a `FetchDescriptor` with `fetchLimit: 1`. If not found, logs and returns (`ProcessingViewModel.swift:49-66`).

- **FR-PVM-03 — Status lifecycle.** Sets `recording.summaryStatus = SummaryStatus.generating.rawValue` before calling `summarizationService.summarize()`. On success: `applySummary()` + `setMedicationEvents()` + save. On failure: sets `summaryStatus = SummaryStatus.failed.rawValue` + save (`ProcessingViewModel.swift:68-80`).

- **FR-PVM-04 — fillOnly mode.** Text check-ins pass `fillOnly: true`, which is forwarded to `recording.applySummary(result, fillOnly: true)` — only nil scalar columns are filled, user-entered values are never overwritten (`ProcessingViewModel.swift:36, 84`).

---

### Pending-transcription lifecycle (`PendingTranscriptionServiceImpl`)

Source: [`PendingTranscriptionServiceImpl.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/PendingTranscriptionServiceImpl.swift)

- **FR-PND-01 — Actor isolation.** `PendingTranscriptionServiceImpl` is an `actor`. It depends on `RecordingStore`, `TranscriptionService`, `SummarizationService`, and `AIModelService` (`PendingTranscriptionServiceImpl.swift:17-35`).

- **FR-PND-02 — Drain gating.** `drainIfModelReady()` returns immediately if:
  - `aiModelService.localPath(for: .whisper)` is `nil` (model not installed).
  - `isDraining` is already `true` (coalesces concurrent triggers).
  
  (`PendingTranscriptionServiceImpl.swift:37-41`)

- **FR-PND-03 — Drain triggers.** Wired in `SquirlApp.swift`:
  1. App launch (`.task`) → `await services.pendingTranscriptionService.drainIfModelReady()` (`SquirlApp.swift:132`).
  2. Every foreground transition (`scenePhase == .active`) → same call (`SquirlApp.swift:134-137`).
  3. Background download completion → called after the download stream finishes (`SquirlApp.swift:180`).

- **FR-PND-04 — Oldest-first ordering.** `pendingRecordingIDsOldestFirst()` runs on `@MainActor`, filters `.pendingTranscription` recordings, sorts by `createdAt` ascending, returns only UUIDs (not `@Model` references — safe to cross the actor boundary) (`PendingTranscriptionServiceImpl.swift:57-63`).

- **FR-PND-05 — Re-verification between recordings.** The drain loop re-checks `aiModelService.localPath(for: .whisper)` before each recording. If the model was deleted between recordings, the loop stops (`PendingTranscriptionServiceImpl.swift:48-50`).

- **FR-PND-06 — Identical pipeline.** Each drained recording runs through the exact same path as the post-recording flow:
  1. Resolve `audioURL` from the recording by UUID (returns `nil` if deleted — skip).
  2. Stream transcription, writing each segment's text to the recording (`status = .transcribing`).
  3. `Task.checkCancellation()`.
  4. `summarizationService.summarize(rawTranscription:)`.
  5. `applySummary()` + `setMedicationEvents()` + `status = .completed`.
  
  Cancellation is logged and swallowed; other errors mark `.failed` with the error message (`PendingTranscriptionServiceImpl.swift:68-82, 118-134`).

- **FR-PND-07 — Deleted-during-drain guard.** `writeSegment()` returns `false` if the recording can't be found, causing the transcription loop to throw `CancellationError`. `applyResult()` and `markFailed()` both guard on recording existence (`PendingTranscriptionServiceImpl.swift:92-93, 108, 122`).

---

### Orphan recovery (`RecordingStore`)

Source: [`RecordingStore.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Store/RecordingStore.swift)

- **FR-ORP-01 — Recovery at init.** `recoverOrphanedTranscriptions()` runs at `RecordingStore.init()`, after `loadRecordings()`. Any recording with `status == .transcribing` at launch cannot have a live task — the app was killed mid-transcription. These are recovered to `.failed` with text `"Transcription was interrupted. Tap to retry in the recording detail view."` (`RecordingStore.swift:17-36`).

- **FR-ORP-02 — Pending is NOT orphaned.** `.pendingTranscription` recordings are explicitly **not** swept — they are legitimately waiting for the model and drain via `PendingTranscriptionServiceImpl` (`RecordingStore.swift:22-24`).

---

### AI model management (`AIModelServiceImpl`)

Source: [`AIModelServiceImpl.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/AIModelServiceImpl.swift)

- **FR-AIM-01 — MainActor binding.** `AIModelServiceImpl` is `@MainActor final class`. It owns a `ModelContext` for SwiftData metadata operations (`AIModelServiceImpl.swift:5-6`).

- **FR-AIM-02 — Model metadata.** `ModelMetadata` (SwiftData `@Model`) tracks `modelName` (`"openai_whisper-small"`), `modelType` (`AIModelType.whisper.rawValue`), `modelSize` (`74_000_000` bytes), `isDownloaded`, and `isCorrupted`. `ensureMetadata(for:)` creates the row if absent (`AIModelServiceImpl.swift:142-150`).

- **FR-AIM-03 — Download lifecycle.** `download(_:)` returns an `AsyncThrowingStream<Double, Error>`:
  1. Sets `isDownloading = true`.
  2. Pre-flight: checks free disk space via `freeSpaceProvider()` — if < 150MB, throws `.insufficientSpace`.
  3. Acquires a `UIApplication.shared.beginBackgroundTask` to keep the download alive.
  4. Calls `WhisperKit.download(variant:downloadBase:progressCallback:)`.
  5. Progress callback yields `min(fractionCompleted, 0.99)` — progress is clamped below 1.0 until the download is fully finalized.
  6. On success: sets `metadata.isDownloaded = true`, `isCorrupted = false`, yields exactly `1.0`, finishes.
  7. On cancellation: finishes quietly — never writes to metadata (the `ModelContext` may be torn down).
  8. On failure: sets `metadata.isCorrupted = true`, classifies the error, finishes with the classified error.
  
  `continuation.onTermination` cancels the download task (`AIModelServiceImpl.swift:30-85`).

- **FR-AIM-04 — Error classification.** `classify(_:)` is `nonisolated static`, mapping raw errors to `ModelDownloadFailure`:
  - `URLError.dataNotAllowed` → `.cellularDisabled`
  - `.notConnectedToInternet`, `.networkConnectionLost`, `.cannotConnectToHost`, `.timedOut` → `.noNetwork`
  - `NSFileWriteOutOfSpaceError`, `NSFileWriteVolumeReadOnlyError`, `ENOSPC` → `.insufficientSpace`
  - Everything else → `.other(String(describing: type(of: error)))` — content-free by design.
  
  (`AIModelServiceImpl.swift:91-113`)

- **FR-AIM-05 — Delete.** `delete(_:)` removes the download directory at `ModelConstants.whisperDownloadBase`, resets `isDownloaded = false`, `isCorrupted = false` (`AIModelServiceImpl.swift:115-127`).

- **FR-AIM-06 — Filesystem as source of truth.** `localPath(for:)` is `nonisolated`. It calls `findWhisperModelFolder(in:)` which enumerates `~/Library/whisperkit`, looking for a directory named `openai_whisper-small` that contains both `AudioEncoder.mlmodelc/weights/` and `config.json`. SwiftData `isDownloaded` mirrors this but the filesystem wins (`AIModelServiceImpl.swift:129-136, 160-181`).

---

### Constants & enums

#### Constants (`Constants.swift`)

Source: [`Constants.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Utils/Constants.swift)

| Constant | Value | Source |
|---|---|---|
| `AudioConstants.sampleRate` | 16000 Hz | `Constants.swift:4` |
| `AudioConstants.channels` | 1 (mono) | `Constants.swift:5` |
| `AudioConstants.formatLabel` | `"16 kHz • M4A"` | `Constants.swift:6` |
| `LayoutConstants.maxRecordingDuration` | 480 s (8 minutes) | `Constants.swift:10` |
| `LayoutConstants.minDiskSpaceForRecordingBytes` | 50 MB | `Constants.swift:11` |
| `ModelConstants.whisperDownloadBase` | `~/Library/whisperkit` | `Constants.swift:15-18` |
| `SettingsKeys.medicalPromptEnabled` | `"medicalPromptEnabled"` | `Constants.swift:22` |
| `UserDefaults.medicalPromptEnabled` | defaults to `true` | `Constants.swift:28-33` |

#### AppEnums (`AppEnums.swift`)

Source: [`AppEnums.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Models/AppEnums.swift)

| Enum | Cases | Usage |
|---|---|---|
| `RecordingStatus` | `recorded`, `transcribing`, `pendingTranscription`, `completed`, `failed`, `placeholder` | Recording lifecycle state |
| `RecordingState` | `idle`, `recording`, `paused`, `processing`, `done` | Audio recording UI state |
| `ModelStatus` | `notInstalled`, `downloading`, `installing`, `ready`, `corrupted` | Model download UI state |
| `SummaryStatus` | `notGenerated`, `generating`, `completed`, `failed` | Extraction pipeline state |
| `AIModelType` | `whisper` | Model type identifier (single variant currently) |
| `DownloadStatus` | `notInstalled`, `downloading`, `installed`, `failed` | Download UI state |
| `TopicCategory` | `medications`, `symptoms`, `appointments`, `procedures`, `general` | Topic tag categories |
| `RecordingError` | `permissionDenied`, `hardwareFailure`, `storageFull`, `deviceDiskFull`, `interruption(InterruptionType)`, `timeout`, `unknown` | Recording error types |

---

## User flows

### Happy path — voice recording to clean transcript
1. User taps Record. `CheckInViewModel.startRecording()` checks model availability, disk space, and mic permission.
2. If the Whisper model is missing: shows download prompt. User chooses "Download & Record" or "Record without model".
3. Recording starts. A detached task preloads the Whisper model in the background.
4. User speaks for up to 8 minutes. Timer ticks at 0.1s intervals.
5. User taps "Stop & save" (or 8-min cap auto-stops).
6. Audio file is saved to disk. `Recording` is persisted to SwiftData.
7. If model is absent → `status = .pendingTranscription` ("Ready shortly…"). End.
8. If model is present → transcription chains after any prior transcription task.
9. WhisperKit loads (if not preloaded), runs batch transcription.
10. Non-speech markers are stripped, whitespace collapsed.
11. Final transcript is written to `recording.fullTranscriptText`.
12. **Whisper model is unloaded from memory** (Peak Shaving).
13. `recording.status = .completed`. Stream finishes.
14. `ProcessingViewModel.processRawTranscription()` is called with the clean transcript → hands off to extraction service.

### Pending transcription drain
1. App launches / foregrounds / model download completes.
2. `PendingTranscriptionServiceImpl.drainIfModelReady()` is called.
3. If model is absent or already draining → no-op.
4. Fetches pending recording UUIDs, oldest first.
5. For each: re-resolves by UUID, streams transcription, writes segments, calls extraction service, marks `.completed`.
6. If model disappears between recordings → stops draining.

### Error flows
- **Transcription timeout (90s):** Cancels transcription, marks `.failed`, shows retry copy.
- **Transcription cancellation:** Marks `.failed` in a fresh uncancelled task.
- **Model download failure:** Classified error surfaces in UI (no network / no space / cellular disabled).
- **Recording deleted during transcription:** Guard catches it, work is silently discarded.
- **Orphaned `.transcribing` at launch:** Recovered to `.failed` with retry copy.

---

## UI states

| State | `RecordingStatus` | `SummaryStatus` | UI Display |
|---|---|---|---|
| Recording in progress | `recorded` | `notGenerated` | Timer + waveform |
| Transcribing | `transcribing` | `notGenerated` | Spinner + "Transcribing…" |
| Pending model | `pendingTranscription` | `notGenerated` | "Ready shortly…" (no error language) |
| Extracting | `completed` | `generating` | "Synthesizing your journal…" + shimmer |
| Complete | `completed` | `completed` | Full check-in card |
| Failed | `failed` | `failed` or `notGenerated` | "Tap to retry" |

## Validation rules & constants

| Rule / constant | Value | Source |
|---|---|---|
| Whisper model variant | `openai_whisper-small` | `WhisperKitTranscriptionService.swift:11` |
| Whisper model size | ~74 MB (metadata), ~150 MB in unified memory | `AIModelServiceImpl.swift:145` |
| Download base path | `~/Library/whisperkit` | `Constants.swift:15-18` |
| Language | hard-coded `"en"` | `WhisperKitTranscriptionService.swift:133` |
| Medical prompt default | ON (`true`) | `Constants.swift:30-31` |
| Audio format | 16 kHz, mono, M4A | `Constants.swift:4-6` |
| Max recording duration | 480 s (8 minutes) | `Constants.swift:10` |
| Min disk space for recording | 50 MB | `Constants.swift:11` |
| Min disk space for download | 150 MB | `AIModelServiceImpl.swift:51` |
| Transcription timeout | 90 s | `CheckInViewModel.swift:296` |
| Token estimate formula | `audioDuration × 100` | `WhisperKitTranscriptionService.swift:88` |
| Progress clamp | `min(fractionCompleted, 0.99)` until final `1.0` | `AIModelServiceImpl.swift:156` |
| Model integrity check | `AudioEncoder.mlmodelc/weights/` + `config.json` | `AIModelServiceImpl.swift:171-176` |
| Orphan recovery scope | `.transcribing` only (not `.pendingTranscription`) | `RecordingStore.swift:22-24` |

## Edge cases

- **Back-to-back recordings**: The new transcription chains after the prior one (`await priorTranscription?.value`). Neither cancels the other. The single WhisperKit actor serialises them (`CheckInViewModel.swift:213-214, 255-260`).
- **Cancel discards, stop preserves**: `cancelRecording()` cancels the transcription task. `stopRecording()` does not — it chains. This ensures a back-to-back recording never cancels the previous one's transcription (`CheckInViewModel.swift:204, 380-384`).
- **Model deleted during drain**: The loop re-checks `localPath(for: .whisper)` before each recording and stops if `nil` (`PendingTranscriptionServiceImpl.swift:48-50`).
- **Recording deleted during transcription/drain**: Both paths guard on `store.recordings.contains(where: { $0.id == recording.id })` before every write. Writes to a vanished `@Model` are prevented (`CheckInViewModel.swift:300-303`; `PendingTranscriptionServiceImpl.swift:87-91`).
- **Cancelled download metadata safety**: A cancelled download does not write `isDownloaded`/`isCorrupted` — the `ModelContext` may already be torn down (`AIModelServiceImpl.swift:59-62`).
- **backgroundTask**: Both download and transcription hold `UIBackgroundTaskIdentifier`s so the OS doesn't suspend CoreML/Metal inference or a download in the last seconds of a background cycle (`WhisperKitTranscriptionService.swift:150-155`; `AIModelServiceImpl.swift:38-41`).

## Acceptance criteria

1. A voice recording produces a clean transcript string with all non-speech markers stripped and whitespace normalised.
2. The Whisper model is fully unloaded from memory before the transcript is handed to the extraction service (Peak Shaving).
3. A recording saved without the model shows "Ready shortly…" (`pendingTranscription`) and is transcribed automatically when the model arrives.
4. Transcription times out at 90 seconds with a clear retry message.
5. Back-to-back recordings serialise on the single WhisperKit actor; neither cancels the other.
6. Orphaned `.transcribing` recordings are recovered to `.failed` at launch; `.pendingTranscription` recordings are never swept.
7. Model download progress is clamped to 0.99 until finalized, then yields exactly 1.0.
8. Model deletion resets all metadata flags and `localPath(for:)` returns `nil`.

## Source references

- [`WhisperKitTranscriptionService.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift)
- [`PendingTranscriptionServiceImpl.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/PendingTranscriptionServiceImpl.swift)
- [`AIModelServiceImpl.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/AIModelServiceImpl.swift)
- [`CheckInViewModel.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/CheckInViewModel.swift)
- [`ProcessingViewModel.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/ProcessingViewModel.swift)
- [`SquirlApp.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/App/SquirlApp.swift)
- [`RecordingStore.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Store/RecordingStore.swift)
- [`Constants.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Utils/Constants.swift)
- [`AppEnums.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Models/AppEnums.swift)
- WhisperKit: [GitHub](https://github.com/argmaxinc/WhisperKit) · [Docs](https://docs.argmaxinc.com/whisperkit/)
- Sibling: [04b — LLM Extraction & Lexicon](04b-llm-extraction-lexicon.md) · [03 — Check-in Capture](../fsd/03-check-in-capture.md)
