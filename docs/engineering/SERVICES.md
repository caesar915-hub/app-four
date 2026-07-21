<!-- Created: 2026-06-28 00:00 (WEST) · Updated: 2026-07-20 09:20 (WEST) -->
# Service Layer Reference

_Last updated: 2026-07-20_

This document describes the service layer in Squirl: the protocols that define capabilities, the concrete implementations, and how they are wired together.

---

## Table of Contents

- [Design Principles](#design-principles)
- [Protocol Reference](#protocol-reference)
- [Implementation Map](#implementation-map)
- [Dependency Wiring](#dependency-wiring)
- [Mock Implementations](#mock-implementations)
- [Adding a New Service](#adding-a-new-service)

---

## Design Principles

1. **Protocol-first.** Every service capability is defined by a protocol in `app-four/Services/Protocols.swift`.
2. **Sendable.** Service protocols and DTOs conform to `Sendable` so they can be used safely across actors.
3. **Observable only at the boundary.** Services themselves are not `@Observable`; ViewModels observe them through `AsyncStream` or by polling status.
4. **No view access.** Views and ViewModels receive services through the SwiftUI environment, never via global singletons.
5. **Actor isolation for mutable state.** Stateful services like `WhisperKitTranscriptionService`, `NetworkConnectivity`, `PendingTranscriptionServiceImpl`, and `CloudSyncServiceImpl` are `actor`s.

---

## Protocol Reference

The core protocols live in `app-four/Services/Protocols.swift`. Four newer capabilities are declared next to their implementations instead: `ExportService` in [`ExportService.swift`](../../app-four/Services/ExportService.swift), `DoseLogService` in [`DoseLog/DoseLogService.swift`](../../app-four/Services/DoseLog/DoseLogService.swift), `CloudSyncService` in [`Sync/CloudSyncService.swift`](../../app-four/Services/Sync/CloudSyncService.swift), and `NoteExtractor` in [`NoteExtraction/NoteExtraction.swift`](../../app-four/Services/NoteExtraction/NoteExtraction.swift).

### `AudioRecordingService`

Manages microphone recording state and hardware.

```swift
protocol AudioRecordingService: Sendable {
    var audioLevelStream: AsyncStream<Float> { get }
    func requestPermission() async -> Bool
    func startRecording() async throws -> URL
    func pauseRecording() async
    func resumeRecording() async throws
    func stopRecording() async throws -> (fileURL: URL, duration: TimeInterval)
    func cancelRecording() async
}
```

| Method | Purpose |
|--------|---------|
| `audioLevelStream` | Normalized audio power (0.0–1.0) for the waveform UI. |
| `requestPermission()` | Requests microphone access. |
| `startRecording()` | Begins recording and returns the temporary file URL. |
| `pauseRecording()` / `resumeRecording()` | Pause/resume within a single session. |
| `stopRecording()` | Finalizes the file and returns `(fileURL, duration)`. |
| `cancelRecording()` | Discards the current recording. |

### `AudioFileStorageService`

Manages persistent audio files and storage metrics.

```swift
protocol AudioFileStorageService: Sendable {
    @MainActor func saveRecording(from temporaryURL: URL, duration: TimeInterval) throws -> Recording
    @MainActor func deleteRecording(_ recording: Recording) throws
    @MainActor func getAudioURL(for recording: Recording) -> URL?
    @MainActor func exportTranscript(_ recording: Recording, format: ExportFormat) async throws -> URL
    @MainActor func calculateTotalStorageUsed() async -> Int64
    func availableStorage() async -> Int64
}
```

### `TranscriptionService`

Transcribes a completed audio file.

```swift
protocol TranscriptionService: Sendable {
    func transcribe(audioURL url: URL) async throws -> AsyncStream<TranscriptionSegmentDTO>
    func cancelTranscription() async
    func loadModel() async throws
}
```

The stream emits `TranscriptionSegmentDTO`:

```swift
struct TranscriptionSegmentDTO: Sendable {
    let id: UUID
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let isFinal: Bool
    let confidence: Double?
    let isError: Bool
}
```

### `SummarizationService`

Runs NLP extraction on a transcript.

```swift
protocol SummarizationService: Sendable {
    func summarize(rawTranscription: String) async throws -> SummaryResult
}
```

`SummaryResult` is a flat DTO containing extracted signals:

```swift
struct SummaryResult: Sendable {
    let bullets: [String]
    let medications: [MedEvent]
    let generatedTitle: String
    let energyLevel: String?
    let focusLevel: String?
    let mood: String?
    let sleepHours: Double?
    let sleepQuality: String?
    let sleepEvent: SleepEvent?
    let sleepLevel: String?
    let sideEffects: [String]
    let emotions: [String]
    let topics: [String]
    let noteExtraction: NoteExtraction?
}
```

### `AIModelService`

Manages the lifecycle of downloadable models (currently Whisper Small).

```swift
protocol AIModelService: Sendable {
    func status(for type: AIModelType) async -> ModelMetadata?
    func download(_ type: AIModelType) async throws -> AsyncThrowingStream<Double, Error>
    func delete(_ type: AIModelType) async throws
    nonisolated func localPath(for type: AIModelType) -> URL?
}
```

Failures are reported through `ModelDownloadFailure`:

```swift
enum ModelDownloadFailure: Error, Sendable, Equatable {
    case noNetwork
    case insufficientSpace
    case cellularDisabled
    case other(String)
}
```

### `Connectivity`

Abstracts network state for download policy decisions.

```swift
protocol Connectivity: Sendable {
    var currentInterface: NetworkInterface { get async }
    var interfaceChanges: AsyncStream<NetworkInterface> { get }
}
```

### `PendingTranscriptionService`

Drains recordings captured before the transcription model was ready.

```swift
protocol PendingTranscriptionService: Sendable {
    func drainIfModelReady() async
}
```

### `ExportService`

Produces a single encrypted file from the SwiftData journal so the user can keep or share a copy without plaintext ever leaving the device sandbox.

```swift
protocol ExportService: Sendable {
    @MainActor func export(from context: ModelContext) async throws -> ExportResult
}
```

`export` reads the whole `Recording` graph on the main actor, maps the non-`Sendable` `@Model` types to `Codable` DTOs (`JournalArchive` / `RecordingDTO` / `SegmentDTO` / `TagDTO` / `MedicationEventDTO`, including base64 audio), then JSON-encodes and AES-GCM-seals it under a fresh 256-bit key off the main actor. The returned `ExportResult` carries the sealed `data` plus the one-time `key` (surfaced once as a recovery key, never persisted):

```swift
struct ExportResult: Sendable {
    let data: Data          // AES-GCM combined blob (nonce + ciphertext + tag)
    let key: SymmetricKey   // fresh per export; never stored
    var keyBase64: String { get }
}
```

Failures surface as `ExportError.sealFailed` or `ExportError.audioTooLarge(totalBytes:limitBytes:)` (a 200 MB in-memory budget guards against OOM on the A14 minimum target).

### `NoteExtractor`

Extracts structured ADHD-journal data from a transcript. Composed internally by `NLSummarizationService` (its `NLNoteExtractor` field) — not injected through `AppServices`.

```swift
public protocol NoteExtractor: Sendable {
    func extract(from transcript: String) -> NoteExtraction
}
```

`extract` is synchronous, CPU-bound, and `nonisolated`; the summarization service runs it on a detached task so the UI never blocks. `NoteExtraction` is the flat, `Codable` schema (mood/energy/focus/emotions/activities/medications/sideEffects/sleep/tasks/wins/… plus regex-derived dose, sleep hours, onset, duration).

### `DoseLogService`

Records a dose of the user's default medication without opening the app — the single owner of settings resolution, catalog re-validation, dose-guard evaluation, and the event write (spec 030). Instances cross into the App Intents runtime, so the protocol is `Sendable`.

```swift
protocol DoseLogService: Sendable {
    func logDefaultDose(now: Date) async -> DoseLogOutcome
    func namesMedicationInConfirmations() async -> Bool
}
```

The write result is a `DoseLogOutcome`: `.logged(name:dose:at:)`, `.guarded(activeSince:)`, `.notConfigured`, or `.failed` (fails closed if dose history is unreadable while a guard is armed).

### `CloudSyncService`

**In progress — spec 038 (`feat/038-icloud-sync`).** Opt-in iCloud sync over the user's private CloudKit database, behind a mockable seam. Off by default (FR-001). The Settings US1 consumer now exists in the working tree (verified 2026-07-20): [`SyncSettingsViewModel`](../../app-four/ViewModels/SyncSettingsViewModel.swift) takes `any CloudSyncService` (defaulting to `AppDependencies.cloudSyncService`) and drives the consent-gated toggle in [`ICloudSyncSection`](../../app-four/Views/Settings/ICloudSyncSection.swift), mounted at `SettingsView.swift:60`. All of it is still uncommitted.

```swift
protocol CloudSyncService: Sendable {
    func accountStatus() async -> SyncAccountStatus
    var isSyncEnabled: Bool { get async }
    func setSyncEnabled(_ enabled: Bool) async throws
    func removeFromICloud() async throws
    var state: AsyncStream<SyncState> { get }
}
```

All associated types are transient and content-free — they name the *condition*, never any transcript/medication content (Constitution VI):

- `SyncAccountStatus` — `.available` / `.noAccount` / `.restricted` / `.temporarilyUnavailable` / `.couldNotDetermine`, mapped from `CKAccountStatus`.
- `SyncFailure` — `.quotaExceeded` / `.network` / `.notAuthenticated` / `.rateLimited(retryAfterSeconds:)` / `.other(String)`, mapped from `CKError` (the `.other` payload carries only the error code name).
- `SyncPhase` — `.idle` / `.syncing` / `.stalled(SyncFailure)` / `.unavailable(SyncAccountStatus)`.
- `SyncState` — `{ enabled, accountStatus, phase, lastSyncedAt }`; `.off` is the disabled default.

`CloudSyncServiceImpl` is an `actor` backed by CloudKit and the off-by-default `SyncFlags` `UserDefaults` toggle. **Pattern A:** `setSyncEnabled` only persists the flag — the actual local↔CloudKit mirroring is (dis)engaged when `AppModelContainer` is next built at relaunch, because SwiftData has no supported live container hot-swap. The container ([`AppModelContainer.swift`](../../app-four/App/AppModelContainer.swift)) is partitioned into two `ModelConfiguration`s: **Synced** (`Recording`, `TranscriptionSegment`, `RecordingTag`, `MedicationEvent` — `cloudKitDatabase: .private(…)` only when `SyncFlags.iCloudSyncEnabled`, else `.none`) and **Local** (`AppSettings`, `ModelMetadata` — never synced). `removeFromICloud` disables the flag, then deletes the private-database custom zones (cloud copy only; other devices' local stores are untouched).

---

## Implementation Map

| Protocol | Default Implementation | Notes |
|----------|------------------------|-------|
| `AudioRecordingService` | `AudioRecordingServiceImpl` | `app-four/Services/Audio/` (`final class`, `AVAudioRecorderDelegate`) |
| `AudioFileStorageService` | `AudioFileStorageServiceImpl` | `app-four/Services/Audio/` (`final class`) |
| `TranscriptionService` | `WhisperKitTranscriptionService` | `app-four/Services/WhisperKit/` (actor) — the wired default |
| `TranscriptionService` (alt) | `SpeechTranscriptionService` | `app-four/Services/Speech/` (actor) — Apple Speech backend; defined but not currently wired |
| `SummarizationService` | `NLSummarizationService` | `app-four/Services/NLSummarizationService.swift` (`struct`; composes `NLNoteExtractor`) |
| `NoteExtractor` | `NLNoteExtractor` | `app-four/Services/NoteExtraction/` (`struct`); consumed by `NLSummarizationService`, not `AppServices` |
| `AIModelService` | `AIModelServiceImpl` | `app-four/Services/AIModelServiceImpl.swift` (`final class`) |
| `Connectivity` | `NetworkConnectivity` | `app-four/Services/Connectivity/` (actor) |
| `PendingTranscriptionService` | `PendingTranscriptionServiceImpl` | `app-four/Services/PendingTranscriptionServiceImpl.swift` (actor) |
| `ExportService` | `ExportServiceImpl` | `app-four/Services/ExportService.swift` (`struct`) |
| `DoseLogService` | `DoseLogServiceImpl` | `app-four/Services/DoseLog/` (`@MainActor class`); wired for App Intents, not `AppServices` |
| `CloudSyncService` | `CloudSyncServiceImpl` | `app-four/Services/Sync/` (actor) — **spec 038, in progress**; consumed by `SyncSettingsViewModel` (Settings ▸ iCloud Sync), uncommitted |

---

## Dependency Wiring

All services are constructed in `AppDependencies.swift` and bundled into `AppServices`:

```swift
static let services = AppServices(
    audioService: audioService,
    storageService: storageService,
    transcriptionService: transcriptionService,
    aiModelService: aiModelService,
    summarizationService: summarizationService,
    connectivity: connectivity,
    pendingTranscriptionService: pendingTranscriptionService,
    exportService: exportService
)
```

`AppServices` is injected at the root of the view hierarchy in `SquirlApp.swift`:

```swift
.environment(AppDependencies.services)
```

ViewModels read the bundle:

```swift
@Environment(AppServices.self) private var services
```

### Services wired outside `AppServices`

Not every service flows through the `AppServices` environment bundle. Two are constructed in `AppDependencies` but injected differently:

- **`doseLogService`** — registered with `AppDependencyManager.shared.add(dependency:)` in `SquirlApp.init` so the App Intents runtime can resolve it. Its only consumer is [`LogDefaultDoseIntent`](../../app-four/Intents/LogDefaultDoseIntent.swift); the in-app Log Dose sheet does not use it.
- **`cloudSyncService`** — constructed at `AppDependencies.cloudSyncService` (spec 038), not in the `AppServices` bundle. Consumed directly by `SyncSettingsViewModel` (default init argument), which backs Settings' `ICloudSyncSection` (`SettingsView.swift:60`) — both working-tree only, uncommitted. The actual local↔CloudKit mirroring is still engaged at the SwiftData layer via `AppModelContainer` reading `SyncFlags.iCloudSyncEnabled` at container-build time.

---

## Mock Implementations

Mock services live in `app-four/Services/Mock/` and are used for:

- Unit tests (`app-fourTests/`)
- SwiftUI previews
- Debug builds and design-system iteration

Two mocks exist today:

| Mock | Substitutes for | Notes |
|------|-----------------|-------|
| `MockTranscriptionService` | `TranscriptionService` | Scripted segments without WhisperKit. |
| `MockCloudSyncService` | `CloudSyncService` | `@MainActor` scriptable account status / failures for sync gating tests. |

To use a mock in a preview or test, construct a ViewModel with the mock service directly, or provide a custom `AppServices` bundle via `.environment(...)`.

---

## Adding a New Service

1. Define the protocol in `app-four/Services/Protocols.swift`.
2. Create the implementation in a logical subdirectory of `app-four/Services/`.
3. Provide a mock implementation in `app-four/Services/Mock/`.
4. Wire the default implementation in `AppDependencies.swift`.
5. Add it to the `AppServices` initializer and stored property.
6. Inject it into the environment in `SquirlApp.swift`.
7. Update this document.
