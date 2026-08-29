# Implementation Plan: Model Download & Transcription Pipeline Reliability

**Branch**: `feat/043-mlx-journal-service` (work continues on the current branch per explicit user instruction — no new branch) | **Date**: 2026-08-14 | **Spec**: [`spec.md`](file:///Users/caesargrey/Projects/app-four-llama/specs/044-download-transcription-reliability/spec.md)

**Input**: Feature specification from `/specs/044-download-transcription-reliability/spec.md` (clarified 2026-08-14)

**Source**: Model Download & Audio Transcription Engineering Improvement Report v3.1, as amended by the Clarifications session (swift-huggingface adoption; streaming descoped; strongest MLX eviction policy; tighter timeout formula).

## Feature Definition & Scope

This feature makes the two model pipelines — LLM snapshot download (~1.05 GB) and WhisperKit transcription — survive real device conditions (screen lock, backgrounding, network drops, thermal throttling) and return memory to baseline after journaling. It is a reliability refactor of existing paths: **no new UI, no new SwiftData schema, no new screens**.

Seven workstreams, each locked by user decision (do not re-litigate):

1. **True background LLM downloads (US1, FR-001…005).** Replace the `UIApplication.beginBackgroundTask` assertion at [`AIModelServiceImpl.swift:50`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/AIModelServiceImpl.swift#L50) (~30 s runningboardd cap) and the foreground `HubApi.snapshot` call at [`AIModelServiceImpl.swift:205-209`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/AIModelServiceImpl.swift#L205) with the official **swift-huggingface** client driving a **system-managed background `URLSession`** (stable identifier, launch events, `waitsForConnectivity = true`). Open risk: swift-huggingface's iOS background-session support is unverified on-device — swift-transformers' equivalent path crashes on iOS (see the comment at `AIModelServiceImpl.swift:11-17`). The documented fallback is an app-owned delegate-driven `URLSessionConfiguration.background` session for the weight files. The Whisper path (`WhisperKit.download(useBackgroundSession: true)`, `AIModelServiceImpl.swift:192-199`) is unchanged.
2. **Byte-range resume (US2, FR-006…008).** Persist resume state (temp-file reference, byte offset, ETag/validator) atomically in the Caches directory; accept HTTP 206 and 200; silently fall back to a clean download on stale state (purged temp file, ETag mismatch, HTTP 412). [`ResilientModelDownload`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/ResilientModelDownload.swift) stays as the outer retry/stall-watchdog harness — this feature replaces the inner transfer mechanism, not the retry policy.
3. **MLX unified-memory lifecycle (US5, FR-009…011).** In [`MLXJournalService`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/MLXJournalService.swift): set `MLX.Memory.cacheLimit = 20 MB` at init; call `MLX.Memory.clearCache()` after every inference; evict the `ModelHolder` container on (a) a 3-minute idle timer (cancellable, resetting), (b) `UIApplication.didReceiveMemoryWarningNotification`, (c) `UIApplication.didEnterBackgroundNotification`. `MLXJournalService` is a `nonisolated struct` with a `private actor ModelHolder` (`MLXJournalService.swift:95-135`), so notification observers must be wired without violating Swift 6 isolation — a `@MainActor` lifecycle coordinator owning the observer tokens, feeding the actor via async calls (see research.md Decision 3).
4. **Thermal-scaled transcription timeout (US3, FR-012).** New pure `Sendable` struct `TranscriptionTimeoutCalculator`: `max(60s, duration × thermalRTF + 30s)` with RTF 0.4 (nominal/fair) / 0.6 (serious) / 0.8 (critical) from `ProcessInfo.thermalState`. Replaces the hardcoded 90s at [`CheckInViewModel.swift:313`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/CheckInViewModel.swift#L313) **and** [`RecordingDetailViewModel.swift:87`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/RecordingDetailViewModel.swift#L87).
5. **Remove the `DispatchSemaphore` bridge (US7, FR-016).** `MLXJournalService.isModelLoaded` (`MLXJournalService.swift:137-154`) becomes `var isModelLoaded: Bool { get async }`; the synchronous test consumer is updated to `await`.
6. **WhisperKit preload stagger (US6, FR-015).** In `CheckInViewModel.startRecording` ([`CheckInViewModel.swift:169-177`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/CheckInViewModel.swift#L169)), delay `transcriptionService.loadModel()` by ~1.5 s via `Task.sleep` inside the existing detached preload task, observing cancellation if recording stops first.
7. **Single-save batch transcription (US4, FR-013/014).** Transcription stays batch — streaming is explicitly descoped (user decision 2026-08-14). Exactly one `store.save()` per transcription completion in both the interactive and background-drain paths.

> **Codebase reality check** (verified 2026-08-14 against the working tree):
> - **swift-huggingface is already in the project.** `project.pbxproj` contains `XCRemoteSwiftPackageReference "swift-huggingface"` (`https://github.com/huggingface/swift-huggingface.git`, `upToNextMajorVersion` 0.9.0) at lines 232 and 842-849, plus an `XCSwiftPackageProductDependency` for product `HuggingFace` at lines 933-937. However the product does **not** appear in the app target's `packageProductDependencies` list (line 180-…) or the Frameworks build phase (line 82-…) — the reference exists but target linkage must still be added during implementation. No package-manager step is needed to add the dependency itself.
> - **The report missed a second *and third* per-segment save site.** Beyond `RecordingDetailViewModel.consumeTranscription` saving on every segment at `RecordingDetailViewModel.swift:114-121`, `CheckInViewModel.consumeStreamWithTimeout` also saves per segment at `CheckInViewModel.swift:377-379`. FR-014 coalescing must touch all three consumers (`CheckInViewModel`, `RecordingDetailViewModel`, `PendingTranscriptionServiceImpl.writeSegment` at `PendingTranscriptionServiceImpl.swift:107-115`).
> - **`WhisperKitTranscriptionService` has its own `beginBackgroundTask`** at `WhisperKit/WhisperKitTranscriptionService.swift:145-147` ("WhisperTranscription"). Decision: **keep it.** Transcription runs seconds-to-minutes in the foreground by design and the 30s assertion is a cheap suspension hedge; the eviction work (US5) and timeout scaling (US3) address the real failure modes. Noted so it isn't mistaken for the download-path assertion being removed.
> - **There is no `AppDelegate`.** `SquirlApp` (`app-four/App/SquirlApp.swift:6`) is a pure SwiftUI `App` with no `UIApplicationDelegateAdaptor`. FR-003's `handleEventsForBackgroundURLSession` hook therefore requires adding a small `AppDelegate` via `@UIApplicationDelegateAdaptor` — a new (UIkit-lifecycle, not UI) file, justified in Complexity Tracking.
> - **The LLM is actually Qwen, not Llama.** `ModelConstants.llmHubRepoID` = `mlx-community/Qwen2.5-1.5B-Instruct-4bit` ([`Constants.swift:41`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Utils/Constants.swift#L41)); the constitution's "Llama 3.2 1B" text is stale relative to the code. This plan describes the pipeline for the Qwen snapshot (~1.05 GB per `requiredFreeSpace` at `AIModelServiceImpl.swift:164`).
> - **`downloadLLMModel` writes directly under the repo root**, not `snapshots/<hash>/` — `findLLMModelDirectory` (`AIModelServiceImpl.swift:217-250`) already tolerates both layouts, and the swift-huggingface cache layout must be mapped onto what this function accepts (FR-002).
> - **Two tests call `isModelLoaded` synchronously**: `modelNotLoadedAtInit()` ([`MLXJournalServiceTests.swift:40-43`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/MLXJournalServiceTests.swift#L40), sync `@Test`) and `coldStartDoesNotLoadModel()` (`MLXJournalServiceTests.swift:57-61`, already `async` but reads the property without `await`).

**What is NOT being built**: real-time segment streaming or live transcript UI (descoped); Whisper download-path changes; new screens or progress-UI redesign; storage pre-flight checks or iCloud backup flags (excluded by the source report); `tasks.md` (later `/speckit-tasks` phase).

---

## Technical Context

### 1. Language & Runtime Environment

Swift 6+ with strict concurrency enabled (constitution stack; zero new strict-concurrency diagnostics is a success criterion, SC-006). Deployment target iOS 26 on A14+ hardware (iPhone 12 Pro floor, 6 GB RAM). All new cross-task state is actor-isolated or guarded by `OSAllocatedUnfairLock` (available iOS 16+, so no runtime gate needed at this deployment target); UI-bound ViewModels stay `@MainActor @Observable`. Background `URLSession` work is delegate/task-API only — the async convenience methods are unavailable on background configurations — so the download layer is a delegate-driven service, with delegate-callback state protected by `OSAllocatedUnfairLock` per the swift-concurrency skill. `MLXJournalService` remains a `nonisolated struct` (matching `NLSummarizationService` style and the `Sendable` requirement of `SummarizationService`); all mutable state lives inside its `private actor ModelHolder` and a new `@MainActor` lifecycle coordinator for observer tokens.

### 2. Core Dependencies & Frameworks

| Dependency | Role | Integration |
|---|---|---|
| **swift-huggingface** (0.9.0+, product `HuggingFace`) | Official HF client; replaces swift-transformers `HubApi` for the LLM snapshot download, driving a background `URLSession` | Package reference **already present** in `project.pbxproj` (lines 232, 842-849); product dependency declared (lines 933-937). Implementation adds the product to the app target's `packageProductDependencies` + Frameworks phase and deletes the `Hub` product linkage once `HubApi` usage is gone (`import Hub` at `AIModelServiceImpl.swift:4`). |
| **swift-transformers** (`Hub`, `Tokenizers`) | `Tokenizers` still required by MLX inference; `Hub` usage ends with this feature | `Hub` product removed from the target when `AIModelServiceImpl` migrates; `Tokenizers` stays. |
| **WhisperKit** (≥1.0) | Whisper model download + transcription | Unchanged. `WhisperKit.download(useBackgroundSession: true)` already background-capable (`AIModelServiceImpl.swift:192-199`). |
| **MLX-Swift / mlx-swift-examples** (`MLX`, `MLXNN`, `MLXLLM`, `MLXLMCommon`) | LLM inference + memory management (`MLX.Memory.cacheLimit`, `MLX.Memory.clearCache()`) | Existing remote packages (pbxproj lines 227-228); no version change required. |
| **Foundation URLSession (background)** | Fallback transfer engine if swift-huggingface's iOS background path is broken on-device | App-owned `URLSessionConfiguration.background(identifier:)` service, delegate-driven, temp-file moved synchronously inside `urlSession(_:downloadTask:didFinishDownloadingTo:)` per the ios-networking skill. |

swift-huggingface was chosen by explicit user decision over hand-rolling a session or keeping `HubApi` (whose background path crashes on iOS — verified on-device, per the comment at `AIModelServiceImpl.swift:11-17`). The fallback exists because swift-huggingface's background support on iOS is unverified; validating it on-device is the first implementation gate.

### 3. State Management & Data Flow

**Download path (after migration):**

```
SettingsViewModel / SquirlApp.startBackgroundModelDownloadIfNeeded (SquirlApp.swift:156)
    ↓
ResilientModelDownload (UNCHANGED outer harness: retry, stall watchdog, connectivity wait)
    ↓ DownloadAttempt closure
AIModelServiceImpl.download(.llm)  →  swift-huggingface snapshot on background URLSession
    ↓ throttled progress (≤ 1 update per 1%, FR-004)          ↓ per-file completion
AsyncThrowingStream<Double> → UI                    ResumeStateStore (atomic Caches write on
                                                           cancel/failure: offset + ETag + temp ref)
    ↓ completion
Atomic move into llmDownloadBase layout → findLLMModelDirectory validates (config.json +
tokenizer.json + *.safetensors, AIModelServiceImpl.swift:224-232) → metadata.isDownloaded = true
→ NotificationCenter .aiModelAvailabilityDidChange (existing, line 280)
```

`AppDelegate.handleEventsForBackgroundURLSession` (new, via `@UIApplicationDelegateAdaptor` in `SquirlApp`) stores the system completion handler and re-instantiates the background session so delegate callbacks drain; on `urlSessionDidFinishEvents` the handler is called and `.aiModelAvailabilityDidChange` is posted so UI rows settle to filesystem truth.

**Transcription path (unchanged shape, tighter discipline):**

```
CheckInViewModel.stopRecording → attemptSave → transcribeInBackground (CheckInViewModel.swift:310)
    → transcriptionService.transcribe(audioURL:) → AsyncStream<TranscriptionSegmentDTO>
      (existing shape: progress yields + one final isFinal segment; WhisperKitTranscriptionService
       unchanged except it keeps its beginBackgroundTask)
    → consumeStreamWithTimeout races the stream against
      TranscriptionTimeoutCalculator.budget(forDuration:thermalState:)  ← replaces 90s literal
    → recording.fullTranscriptText = final text; status = .completed; store.save()   ← ONE save
    → processingViewModel.processRawTranscription(...) (existing)
```

**MLX lifecycle path:**

```
MLXJournalService.init → MLX.Memory.cacheLimit = 20 MB; arm MainActor lifecycle coordinator
summarize(rawTranscription:) → ModelHolder.loadIfNeeded (200 MB headroom gate, existing)
    → generateText → MLX.Memory.clearCache() → coordinator resets 3-min idle timer
Coordinator observes didReceiveMemoryWarning / didEnterBackground / timer fire
    → await modelHolder.evict() (container = nil, isLoaded = false, clearCache)
Next summarize() → cold-load through the existing headroom gate (spec US5 AC4)
```

**Potential bottlenecks**: progress-callback frequency into SwiftUI (mitigated by the 1% throttle, FR-004); delegate callbacks on a background queue touching shared download state (mitigated by `OSAllocatedUnfairLock`, never held across `await`); per-segment `store.save()` write thrash (eliminated by FR-014 coalescing — exactly one save per transcription).

### 4. Storage & Persistence Strategy

**No SwiftData schema changes and no new `@Model` types.** The persisted `Recording`/`ModelMetadata` models are untouched; `isDownloaded`/`isCorrupted` keep mirroring filesystem truth (`AIModelServiceImpl.swift:149-157` semantics preserved). Constitution Principle IX is trivially satisfied (no new attributes at all).

New on-disk state, all disposable and all under `Library/Caches` (OS may purge; every consumer treats absence as "start clean"):

- **Resume state** (`ResumeStateStore`): one small JSON file per download (`llm-resume-state.json`), written atomically (`.atomic` write option — write-temp-then-rename). Fields: temp-file identifier, byte offset, ETag/Last-Modified validator, repo ID, file URL. Unreadable or mismatched state is deleted and ignored (FR-008 silent fallback).
- **Downloaded snapshot**: integrated atomically into `ModelConstants.llmDownloadBase` (`Constants.swift:22-`) so `findLLMModelDirectory` never sees a partial directory — files move into a staging subdirectory first, then the directory is renamed into place.
- **Transcript text**: persisted exactly once per transcription (FR-014); failure paths persist only an error message string, never partial transcript text (US4 AC3).

### 5. Performance & Constraints

| Constraint | Value | Enforcement |
|---|---|---|
| MLX Metal buffer cache | ≤ 20 MB | `MLX.Memory.cacheLimit` at service init (FR-009) |
| MLX residency after last inference | ≤ 3 min foreground; 0 on background/memory-warning | Idle timer + notification eviction (FR-011) |
| Memory headroom gate before LLM load | ≥ 200 MB (`os_proc_available_memory`) | Existing `checkMemoryHeadroom` (`MLXJournalService.swift:156-158`), unchanged |
| Transcription timeout | `max(60s, duration × RTF + 30s)`, RTF 0.4/0.6/0.8 | `TranscriptionTimeoutCalculator` (FR-012) |
| Download UI progress churn | ≤ 1 update per 1% | Throttle in `AIModelServiceImpl` progress bridge (FR-004) |
| SwiftData writes per transcription | exactly 1 completion save (≤ 1 per status transition) | Coalesced consumers (FR-014) |
| Combined model residency | Whisper and MLX never coexist | Eviction + WhisperKit's existing post-transcription `unloadModel()` (`WhisperKitTranscriptionService.swift:175`) |
| Logging | counts/durations/offsets only — never transcript content | Principle VI; existing `AppLogger` call sites already comply, new ones must too |

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design. Re-checked 2026-08-14 after Phase 1 outputs.*

- [x] **I. SwiftUI-First** — **N-A.** No new UI and no UIKit views. The one UIKit-adjacent addition is an `AppDelegate` for the background-URLSession lifecycle hook — an app-lifecycle integration point with no SwiftUI equivalent, which the principle explicitly permits.
- [x] **II. Test-Build-Ship** — Plan orders tests before implementation for all logic; quickstart.md ends with a strict-concurrency build + full `xcodebuild test` gate (SC-006).
- [x] **III. Correctness Over Speed** — No stubs or shims. The `HubApi`→swift-huggingface migration deletes the old path (including `import Hub`), not layers over it. The semaphore bridge is deleted, not deprecated. The swift-huggingface background risk is surfaced explicitly with a fallback, per this principle.
- [x] **IV. Minimal Surface** — New surface is: `TranscriptionTimeoutCalculator`, `ResumeStateStore`, an `AppDelegate`, a lifecycle coordinator inside `MLXJournalService`, and (only if the fallback fires) one background-session download service. No feature flags, no speculative configurability.
- [x] **V. Solo Git Discipline** — Work lands on the existing `feat/043-mlx-journal-service` branch per explicit user instruction (spec Assumptions). Branch discipline otherwise unchanged; `/code-review` before merge.
- [x] **VI. On-Device Privacy** — Downloads are model weights from HF CDN only; no user data leaves the device. Logs record counts, durations, byte offsets, and thermal states only — never transcript text.
- [x] **VIII. Service-Oriented Architecture** — Download changes stay behind the existing `AIModelService` protocol via `AppDependencies` (`AppDependencies.swift:13`); transcription behind `TranscriptionService`; summarization behind `SummarizationService`. ViewModels remain `@MainActor @Observable`; heavy work stays off-main.
- [x] **IX. Pre-Release Data Posture** — **N-A.** Zero schema changes; no new attributes, no `@Model` types. Resume state is plain JSON in Caches, outside SwiftData entirely.
- [x] **X. Test-First Development** — RED→GREEN tests ordered first for: `TranscriptionTimeoutCalculator` (formula boundaries, thermal mapping), `ResumeStateStore` (round-trip, corruption, atomicity, stale-validator fallback), eviction timer semantics (reset/cancel/fire), `ModelHolder` async `isModelLoaded`, and save-count instrumentation for FR-014. SwiftUI surfaces exempt (none added).
- [x] **XI. Architectural Exhaustiveness** — Every workstream above names exact files, line numbers, API surfaces, error states (HTTP 206/200/412, purged temp, ETag mismatch, stall, timeout, eviction races), and data structures; research.md records rejected alternatives per decision.

**Gate result: PASS.** Two items requiring explicit complexity justification are tracked below (new dependency reliance + fallback service; AppDelegate addition).

---

## Project Structure

### Documentation (this feature)

```text
specs/044-download-transcription-reliability/
├── spec.md              # Feature specification (speckit-specify output, clarified 2026-08-14)
├── plan.md              # This file (speckit-plan output)
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output (state entities; no SwiftData schema changes)
├── quickstart.md        # Phase 1 output (on-device verification per SC-001..006)
└── tasks.md             # Phase 2 output (speckit-tasks — NOT created by speckit-plan)
```

### Source Code (repository root)

```text
app-four/
├── App/
│   ├── SquirlApp.swift                        # MODIFIED — add @UIApplicationDelegateAdaptor
│   └── AppDelegate.swift                      # NEW — background-URLSession completion hook
├── Services/
│   ├── AIModelServiceImpl.swift               # MODIFIED — swift-huggingface background download,
│   │                                          #   resume integration, progress throttle; HubApi removed
│   ├── BackgroundLLMDownloadService.swift     # NEW (FALLBACK ONLY) — app-owned
│   │                                          #   URLSessionConfiguration.background delegate session
│   ├── ResumeStateStore.swift                 # NEW — atomic resume-state persistence in Caches
│   ├── TranscriptionTimeoutCalculator.swift   # NEW — pure Sendable timeout formula
│   ├── MLXJournalService.swift                # MODIFIED — cacheLimit, clearCache, eviction,
│   │                                          #   async isModelLoaded (semaphore deleted)
│   ├── ResilientModelDownload.swift           # UNCHANGED — outer retry/stall harness
│   ├── PendingTranscriptionServiceImpl.swift  # MODIFIED — coalesce writeSegment saves (FR-014)
│   └── WhisperKit/WhisperKitTranscriptionService.swift  # UNCHANGED (keeps its
│                                                #   beginBackgroundTask — documented decision)
├── ViewModels/
│   ├── CheckInViewModel.swift                 # MODIFIED — timeout calculator (line 313),
│   │                                          #   1.5s preload stagger (lines 169-177),
│   │                                          #   single-save stream consumption (lines 371-380)
│   └── RecordingDetailViewModel.swift         # MODIFIED — timeout calculator (line 87),
│                                              #   single-save consumption (lines 108-130)
├── Store/
│   └── AppDependencies.swift                  # MODIFIED only if fallback service needs wiring
├── Utils/
│   └── Constants.swift                        # UNCHANGED (llmDownloadBase / llmHubRepoID reused)
└── app-four.xcodeproj/project.pbxproj         # MODIFIED — link HuggingFace product to app target;
                                               #   drop Hub product linkage after migration

app-fourTests/
├── MLXJournalServiceTests.swift               # MODIFIED — await isModelLoaded (lines 40-43, 57-61);
│                                              #   eviction timer tests
├── TranscriptionTimeoutCalculatorTests.swift  # NEW — formula + thermal mapping boundaries
├── ResumeStateStoreTests.swift                # NEW — persistence round-trip, corruption, staleness
└── SaveCountTests.swift (name TBD in tasks)   # NEW — exactly-one-save instrumentation (FR-014/SC-004)
```

**Structure Decision**: Everything lands in the existing single-target layout (`app-four/` + `app-fourTests/`). New files are small, single-purpose services in `Services/` matching the house pattern; the fallback download service is only created if the on-device swift-huggingface validation fails, and is otherwise absent (no speculative dead code — Principle III).

### File Manifest & Responsibilities

| File Path | Responsibility | Key Structs / Functions / Protocols |
|---|---|---|
| [`app-four/App/AppDelegate.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/App/AppDelegate.swift) (NEW) | **Background-session lifecycle bridge.** Receives `application(_:handleEventsForBackgroundURLSession:completionHandler:)`, stashes the system completion handler, re-instantiates the background session so pending delegate events drain, posts `.aiModelAvailabilityDidChange` when events finish. No other responsibilities. | `final class AppDelegate: NSObject, UIApplicationDelegate` — `func application(_:handleEventsForBackgroundURLSession:completionHandler:)` |
| [`app-four/App/SquirlApp.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/App/SquirlApp.swift) (MODIFIED) | Adopt the AppDelegate via `@UIApplicationDelegateAdaptor` (1 property + no behavioral change to scenes or `init()` bootstrap). | `@UIApplicationDelegateAdaptor private var appDelegate` |
| [`app-four/Services/AIModelServiceImpl.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/AIModelServiceImpl.swift) (MODIFIED) | **LLM download migration.** `downloadLLMModel` (line 205) re-implemented on swift-huggingface with a background session; the `beginBackgroundTask` block (lines 49-59) deleted for the LLM path; resume-state capture on cancel/failure; progress throttled to 1% increments before stream yield; `findLLMModelDirectory` validation semantics preserved (FR-002); `import Hub` removed. Whisper path untouched. | `private func downloadLLMModel(progress:)` (rewritten), `nonisolated static func classify(_:)` (extended for HTTP 416/412 resume-invalid cases if surfaced), existing `download(_:)`, `localPath(for:)` unchanged signatures |
| `app-four/Services/BackgroundLLMDownloadService.swift` (NEW — **fallback only**) | **App-owned background transfer engine.** Created only if swift-huggingface's iOS background session fails on-device validation. Delegate-driven `URLSessionConfiguration.background(identifier: "com.squirl.llm-download")` session; moves temp file synchronously inside `didFinishDownloadingTo`; validates HTTP status (200/206 accepted, 412/416 → discard resume state); issues manual `Range` requests from `ResumeStateStore` offsets; delegate state guarded by `OSAllocatedUnfairLock`, never held across `await`. | `final class BackgroundLLMDownloadService: NSObject, URLSessionDownloadDelegate` — `func downloadSnapshot(repo:files:into:progress:) async throws`, `func urlSession(_:downloadTask:didFinishDownloadingTo:)`, `func urlSession(_:task:didCompleteWithError:)` |
| `app-four/Services/ResumeStateStore.swift` (NEW) | **Atomic resume-state persistence.** One JSON record per download in `Library/Caches`; write-temp-then-rename atomicity; load returns nil on unreadable/corrupt/mismatched state and deletes the file (FR-008 silent fallback). Pure file IO, `Sendable`, fully unit-testable with injected directory. | `struct ResumeState: Codable, Sendable` (`tempFileID`, `byteOffset`, `etag`, `repoID`, `fileURL`), `struct ResumeStateStore` — `func load(for:) -> ResumeState?`, `func save(_:) throws`, `func clear(for:)` |
| `app-four/Services/TranscriptionTimeoutCalculator.swift` (NEW) | **Pure timeout formula.** `max(60s, duration × thermalRTF + 30s)`; maps `ProcessInfo.ThermalState` → RTF (0.4 nominal/fair, 0.6 serious, 0.8 critical). `Sendable` struct with injected thermal-state provider for deterministic tests. | `struct TranscriptionTimeoutCalculator: Sendable` — `static func budget(audioDuration: TimeInterval, thermalState: ProcessInfo.ThermalState) -> TimeInterval`, `static func realTimeFactor(for:) -> Double` |
| [`app-four/Services/MLXJournalService.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/MLXJournalService.swift) (MODIFIED) | **Memory lifecycle + concurrency fix.** `init` sets `MLX.Memory.cacheLimit = 20 MB` and starts the lifecycle coordinator; `summarize` calls `MLX.Memory.clearCache()` after inference; `ModelHolder` gains `evict()`; `isModelLoaded` becomes `get async` (semaphore at lines 137-154 deleted); a `@MainActor` coordinator owns NotificationCenter observer tokens + the 3-min cancellable/resetting idle timer and calls `await modelHolder.evict()`. | `var isModelLoaded: Bool { get async }`, `private actor ModelHolder.evict()`, `private final class LifecycleCoordinator` (MainActor; timer + observers) |
| [`app-four/Services/PendingTranscriptionServiceImpl.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/PendingTranscriptionServiceImpl.swift) (MODIFIED) | **Save coalescing (FR-014).** `writeSegment` (lines 106-115) stops calling `store.save()` per segment: text/status mutate in memory during the stream; exactly one save on completion in `applyResult` (existing, line 132) and one on failure in `markFailed` (existing, line 143). | `private func writeSegment(_:to:) -> Bool` (save removed), `applyResult`/`markFailed` unchanged |
| [`app-four/ViewModels/CheckInViewModel.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/CheckInViewModel.swift) (MODIFIED) | **Timeout + stagger + single save.** Line 313: `timeoutSeconds: 90` → `TranscriptionTimeoutCalculator.budget(audioDuration: recording.duration, thermalState:)`; lines 169-177: preload task sleeps ~1.5 s (`Task.sleep`) and checks cancellation before `loadModel()`; lines 371-380: segment loop mutates without `store.save()` — one save on `.completed` (line 322, existing) and one per failure path (existing). | `consumeStreamWithTimeout(_:for:)` (save removed from loop; timeout param source changed), preload `Task.detached` (sleep added) |
| [`app-four/ViewModels/RecordingDetailViewModel.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/RecordingDetailViewModel.swift) (MODIFIED) | **Timeout + single save on retry path.** Line 87: `timeoutSeconds: 90` → calculator budget; `consumeTranscription` (lines 108-130): per-segment `store.save()` (line 120) removed — one save on completion (line 89, existing) or via `finishFailed` (existing). | `retryTranscription()`, `consumeTranscription(_:timeoutSeconds:)` (param source changed) |
| `app-four.xcodeproj/project.pbxproj` (MODIFIED) | Link the already-declared `HuggingFace` product into the app target's `packageProductDependencies` (line 180-…) and Frameworks build phase (line 82-…); remove `Hub` product linkage (lines 14, 83, 182) once `HubApi` usage is deleted. | — |
| [`app-fourTests/MLXJournalServiceTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/MLXJournalServiceTests.swift) (MODIFIED) | `modelNotLoadedAtInit()` (lines 40-43) made `async` with `await service.isModelLoaded`; `coldStartDoesNotLoadModel()` (lines 57-61) adds `await`; new eviction tests (timer fire, reset on inference, memory-warning/background notification → evicted). | `@Test func modelNotLoadedAtInit() async`, eviction suite |
| `app-fourTests/TranscriptionTimeoutCalculatorTests.swift` (NEW) | Boundary tests: 300s nominal → 150s; 480s critical → 414s; short audio floor → 60s; serious → 0.6; stalled-short-recording budget ~60-72s (SC-003). | `@Suite struct TranscriptionTimeoutCalculatorTests` |
| `app-fourTests/ResumeStateStoreTests.swift` (NEW) | Round-trip persistence; corrupt JSON → nil + file removed; ETag mismatch → nil; atomic write leaves no partial file; clear() idempotent. Uses a temp directory injection. | `@Suite struct ResumeStateStoreTests` |
| `app-fourTests/SaveCountTests.swift` (NEW, name finalized in tasks) | Instrument a save-counting `RecordingStore` seam: full interactive transcription → exactly 1 completion save; failed transcription → 1 failure save, no partial text; drain path → 1 save per recording. | `@Suite` FR-014/SC-004 instrumentation |

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| New third-party dependency (swift-huggingface) + a conditional fallback download service | Explicit user decision (Clarifications 2026-08-14) to replace `HubApi`, whose iOS background-session path crashes on-device. The fallback (`BackgroundLLMDownloadService`) is required by the spec's Edge Case 2: background download MUST NOT ship foreground-only if the client proves broken. | Keeping `HubApi` + `beginBackgroundTask`: proven to freeze at ~30s (the bug being fixed). Hand-rolled session as primary: rejected by user decision. No fallback: violates FR-001/Edge Case 2. Fallback is only built if validation fails — never both shipped. |
| `AppDelegate` addition (UIKit lifecycle API in a SwiftUI-first codebase) | FR-003 requires `handleEventsForBackgroundURLSession`, which has no SwiftUI equivalent; Principle I permits UIKit where SwiftUI has no API. | `UIApplication.shared.beginBackgroundTask` (current code): capped ~30s — the defect. Scene-phase observers: no background-URLSession completion delivery. |
