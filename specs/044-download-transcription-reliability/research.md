# Phase 0 Research: Model Download & Transcription Pipeline Reliability

**Spec**: [`spec.md`](file:///Users/caesargrey/Projects/app-four-llama/specs/044-download-transcription-reliability/spec.md) (clarified 2026-08-14) | **Date**: 2026-08-14

All decisions below are locked by the 2026-08-14 clarification session or by this research; alternatives are recorded as rejected, not open.

---

## Decision 1: LLM download engine — swift-huggingface on a system-managed background session

> **Implementation outcome (2026-08-14)**: The **fallback shipped**. swift-huggingface ≥ 0.9.0
> does not expose a delegate-driven `URLSessionConfiguration.background` snapshot API nor
> resume-data persistence hooks, so it cannot satisfy SC-001/SC-002. The implementation is
> the app-owned **`BackgroundLLMDownloadService`** (`app-four/Services/BackgroundLLMDownloadService.swift`):
> a singleton `URLSessionDownloadDelegate` background session
> (`com.squirl.app.llm.background-download`) that fetches the repo tree via the HF REST API
> (`/api/models/<ns>/<name>/tree/<rev>?recursive=true`) on a separate ephemeral foreground
> session, downloads each file from `/resolve/<rev>/<path>` into `staging/<repoID>/`,
> persists byte-range `resumeData` via `ResumeStateStore`, and atomically promotes the
> completed staging directory to `models/<repoID>/`. Reconnection on background relaunch is
> wired through `AppDelegate.application(_:handleEventsForBackgroundURLSession:completionHandler:)`.
> All app-side `import Hub` / `HubApi` usage was removed; `Hub` remains in the package graph
> only because swift-transformers' `Tokenizers` depends on it. The rationale and rejection of
> the status quo below still stand; the "rejected by user decision" alternative became the ship.
>
> **Hardening during device-QA prep (2026-08-14)**: three defects fixed before SC-001/SC-002
> runs: (1) cancellation resumed no continuation and captured no resume data — `cancel` now
> uses `cancelByProducingResumeData()`, persists it, and resumes the caller with
> `CancellationError`; (2) `didFinishDownloadingTo` now validates HTTP status — only 200/206
> bodies move into staging, 412/416 clear the stored resume state; (3) a failed resume
> attempt without fresh resumeData drops the stored state and `downloadFile` retries once
> clean, preventing an infinite stale-resume loop (FR-008).

**Decision**: Migrate `AIModelServiceImpl.downloadLLMModel` ([`AIModelServiceImpl.swift:205-209`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/AIModelServiceImpl.swift#L205)) from swift-transformers `HubApi.snapshot(from:)` (foreground session + `UIApplication.beginBackgroundTask` assertion at line 50) to the official **swift-huggingface** package (product `HuggingFace`, ≥ 0.9.0) driving a system-managed background `URLSession` with a stable identifier, launch events enabled, and `waitsForConnectivity = true`.

**Rationale**: The ~1.05 GB snapshot (~7 min on 20 Mbps LTE) cannot fit in the ~30 s runningboardd cap of `beginBackgroundTask` — LLM downloads freeze whenever the user locks the screen or backgrounds the app (the single largest model-install failure cause). swift-transformers' own background-session path was tried and crashes on iOS ("Completion handler blocks are not supported in background sessions" — documented in the comment at `AIModelServiceImpl.swift:11-17`, verified on-device). The user explicitly chose swift-huggingface as the replacement client.

**Alternatives considered**:
- *Keep HubApi + beginBackgroundTask* — rejected: provably broken beyond 30 s of backgrounding (this is the bug).
- *Hand-rolled background URLSession as primary* — rejected by user decision in favor of the official client; retained as the fallback (below).
- *WhisperKit-style `useBackgroundSession: true` for the LLM* — not applicable: WhisperKit's background flag is internal to WhisperKit's own download of Whisper models; it does not generalize to arbitrary HF snapshots.

**Open risks**:
- **swift-huggingface's iOS background-session support is unverified on-device.** It may carry the same URLSession-delegate limitation that broke swift-transformers. First implementation task on-device: start an LLM snapshot download, lock the screen 5 minutes, confirm completion (SC-001 harness). If it fails, fall back to the documented **app-owned delegate-driven `URLSessionConfiguration.background`** service (`BackgroundLLMDownloadService`, fallback-only — never both shipped).
- Integration detail: the package reference and `HuggingFace` product dependency are **already present** in `project.pbxproj` (lines 232, 842-849, 933-937) but the product is **not yet linked** into the app target's `packageProductDependencies`/Frameworks phase — linkage must be added, and the `Hub` product removed once `import Hub` is gone.
- Cache layout mapping: swift-huggingface's snapshot cache layout must resolve to a directory that `findLLMModelDirectory` (`AIModelServiceImpl.swift:217-250`) accepts (config.json + tokenizer.json + ≥1 .safetensors). Integration must stage into a temp directory and atomically rename into `ModelConstants.llmDownloadBase` so a partial snapshot is never visible (FR-002).

---

## Decision 2: Resume-state persistence format — small atomic JSON in Caches

**Decision**: Persist resume state as a single JSON file (`llm-resume-state.json`) under `Library/Caches`, written atomically (Foundation `.atomic` write = temp file + rename). Record: temp-file reference, byte offset, ETag (or Last-Modified) validator, repo ID, file URL. On retry, issue a `Range: bytes=<offset>-` request (or the client's native resume support); accept HTTP 206 (resume) and HTTP 200 (server ignored Range — treat as fresh stream from byte 0); on 412/416, ETag mismatch, purged temp file, or unreadable state, delete the state and start clean without surfacing an error (FR-008).

**Rationale**: Caches is the correct domain — resume state is disposable and the OS may purge it; every consumer already treats absence as "start clean". JSON via `Codable` is dependency-free and unit-testable with an injected directory. Atomic write prevents half-written state on kill-mid-write. Capturing state on both explicit cancellation and failure (FR-007) makes the stall watchdog's cancellation (`ResilientModelDownload.consume`) resume-capable instead of discarding up to ~990 MB.

**Alternatives considered**:
- *SwiftData / UserDefaults* — rejected: resume state is large-blob-adjacent IO state, not user data; SwiftData schema changes are out of scope (Principle IX posture) and UserDefaults is wrong for file references.
- *NSURLSession resumeData blobs only* — rejected as sole mechanism: resume data is opaque, version-fragile across OS updates (spec Edge Case 2), and doesn't carry an ETag for staleness checks. Offset+ETag is the durable core; session resume data may supplement where the client provides it.
- *Re-resume via Hub cache file-skip (status quo)* — rejected: file-level granularity restarts a 94%-complete `model.safetensors` from zero (SC-002 targets ≤ 5% redundant bytes).

**Open risks**: HF CDN must keep emitting `Accept-Ranges: bytes` and stable ETags (spec Assumption); FR-008 keeps today's file-level behavior as the floor if a future host doesn't.

---

## Decision 3: MLX eviction trigger wiring under Swift 6 isolation

**Decision**: `MLXJournalService` stays a `nonisolated struct` with its `private actor ModelHolder` (`MLXJournalService.swift:95-135`). Eviction triggers are owned by a `@MainActor` **lifecycle coordinator** created in `init`: it holds the NotificationCenter observer tokens (`UIApplication.didReceiveMemoryWarningNotification`, `UIApplication.didEnterBackgroundNotification`) and the 3-minute idle timer (a cancellable `Task` that is cancelled and re-armed after every inference). Each trigger calls `await modelHolder.evict()` — actor hop, no shared mutable state, no locks. `MLX.Memory.cacheLimit = 20 MB` is set once in `init`; `MLX.Memory.clearCache()` runs after every inference completes (FR-009/010/011).

**Rationale**: `ModelHolder`'s state (`modelContainer`, `isLoaded`) is actor-isolated; touching it from NotificationCenter callbacks requires an async hop regardless. A MainActor coordinator is the minimal lawful wiring: observer tokens must be removed on deinit (MainActor-safe), `Task`-based sleep timers are trivially cancellable/resetting, and the coordinator captures only the actor reference (Sendable). This satisfies the swift-concurrency skill's rules: no locks inside actors, nothing held across `await`.

**Alternatives considered**:
- *NotificationCenter AsyncSequence feeding the actor directly* — viable (`for await _ in NotificationCenter.default.notifications(named:)` inside a task that calls `modelHolder.evict()`), but the task handles must live somewhere; the coordinator is that somewhere, and it also owns the timer, keeping one owner for all three triggers. The AsyncSequence form may be used *inside* the coordinator if plain `addObserver` blocks prove awkward under strict concurrency.
- *Make MLXJournalService itself @MainActor* — rejected: inference must stay off-main and the struct's `SummarizationService` conformance / `Sendable` shape is shared with `NLSummarizationService`.
- *OSAllocatedUnfairLock-guarded shared state* — rejected: unnecessary; there is no synchronous cross-isolation read once `isModelLoaded` becomes async (Decision 4).

**Open risks**: eviction racing an in-flight inference — the timer is re-armed only *after* inference completes, and notification-triggered eviction during active inference must be deferred (coordinator checks with the actor; eviction of a busy holder is skipped and the timer re-arms). Covered by eviction tests.

---

## Decision 4: `isModelLoaded` becomes async; semaphore deleted

**Decision**: `MLXJournalService.isModelLoaded` ([`MLXJournalService.swift:137-154`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/MLXJournalService.swift#L137)) becomes `var isModelLoaded: Bool { get async }`; the `DispatchSemaphore` bridge is deleted outright. Consumers updated: `modelNotLoadedAtInit()` ([`MLXJournalServiceTests.swift:40-43`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/MLXJournalServiceTests.swift#L40) — becomes `async` and awaits) and `coldStartDoesNotLoadModel()` (`MLXJournalServiceTests.swift:57-61` — already `async`, adds `await`). These are the only two consumers found (grep over `app-four` + `app-fourTests`).

**Rationale**: `sema.wait()` blocks a cooperative-pool thread on a task scheduled onto that same pool — a probabilistic deadlock under pool saturation, and a hard Swift 6 violation (FR-016). There is no legitimate synchronous caller.

**Alternatives considered**: *Keep a cached nonisolated Bool mirror* — rejected: a second source of truth for one property; async read is cheap and correct.

**Open risks**: none.

---

## Decision 5: Timeout constants — max(60s, duration × thermalRTF + 30s), RTF 0.4/0.6/0.8

**Decision**: New pure `Sendable` struct `TranscriptionTimeoutCalculator` with `budget(audioDuration:thermalState:) = max(60, duration × rtf + 30)`; `rtf` = 0.4 for `.nominal`/`.fair`, 0.6 for `.serious`, 0.8 for `.critical`, read from `ProcessInfo.processInfo.thermalState` at call time (injected in tests). Replaces `timeoutSeconds: 90` at [`CheckInViewModel.swift:313`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/CheckInViewModel.swift#L313) and [`RecordingDetailViewModel.swift:87`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/RecordingDetailViewModel.swift#L87).

**Rationale**: The fixed 90 s guarantees false failures for 5-8 min recordings under throttling (an 8-min clip can need ~6+ min at 0.8 RTF → 414 s budget). The user chose the *tighter* constants (30 s margin, not 45 s) so genuinely stalled short transcriptions still fail fast (~60-72 s, SC-003). A pure function of (duration, thermalState) is deterministic and test-first friendly.

**Alternatives considered**:
- *Larger margin (45 s) / higher RTFs* — rejected by user decision 2026-08-14 (fast stall detection prioritized).
- *Adaptive measurement of actual RTF* — rejected: unbounded complexity for a watchdog; thermal buckets are observable and stable enough.

**Open risks**: thermal state read at transcription start may drift mid-run; accepted — re-reading mid-transcription adds no actionable behavior (the budget is already set).

---

## Decision 6: Streaming descoped — batch transcription with exactly one save

**Decision**: No real-time segment streaming, no live transcript UI (user decision 2026-08-14: priority is lightweight, crash-free execution, not live partial text). `WhisperKitTranscriptionService` keeps its existing AsyncStream shape (progress yields + one final `isFinal` segment — see `WhisperKitTranscriptionService.swift:83-214`). FR-014 is enforced by removing per-segment `store.save()` calls at **three** sites: `CheckInViewModel.consumeStreamWithTimeout` ([`CheckInViewModel.swift:377-379`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/CheckInViewModel.swift#L377)), `RecordingDetailViewModel.consumeTranscription` ([`RecordingDetailViewModel.swift:114-121`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/RecordingDetailViewModel.swift#L114)), and `PendingTranscriptionServiceImpl.writeSegment` ([`PendingTranscriptionServiceImpl.swift:107-115`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/PendingTranscriptionServiceImpl.swift#L107)). Exactly one save per terminal transition (existing save sites on completion/failure are retained).

**Rationale**: Streaming would add SwiftData main-thread write churn (write-thrash + full re-fetch per segment — the exact risk the report flagged) for UI value the user explicitly deprioritized. Coalescing removes the thrash from the batch path too, should the stream ever yield more than one content segment. Failure paths persist an error message, never partial transcript text (US4 AC3).

**Alternatives considered**: *Real-time streaming with a decoupled persistence buffer* — the report's original recommendation; descoped by the user. Recorded here so the reasoning isn't lost if revisited.

**Open risks**: progress yields currently write "Setting up…"/"Transcribing…" placeholder text through the same segment path; after coalescing, those must not be persisted as transcript content — the final `isFinal` segment is the only text committed (or the existing status-only handling kept, per implementation).

---

## Decision 7: WhisperKit preload stagger — 1.5 s heuristic, cancellable

**Decision**: In `CheckInViewModel.startRecording` ([`CheckInViewModel.swift:169-177`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/CheckInViewModel.swift#L169)), the existing `Task.detached(priority: .utility)` preload gains `try await Task.sleep(for: .milliseconds(1500))` + `try Task.checkCancellation()` before `transcriptionService.loadModel()`. Cancellation already flows: `cancelRecording` cancels `modelPreloadTask` (line 398); `stopTasks` must also cancel it (verified: `stopRecording` currently does **not** cancel the preload — implementation must add cancellation there too, since recording-stop is exactly when the model should load anyway via the transcription path… except the preload *is* desirable at stop. Resolution: the stagger window only matters at start; a stop within 1.5 s cancels the pending preload, and the normal transcription path re-loads the model on demand — matching spec US6 AC2).

**Rationale**: CoreML weight compilation colliding with CoreAudio HAL startup causes capture-start clicks/underruns on A14/A15-class devices. 1.5 s is a heuristic from the source report; device QA confirms or tunes it (spec Assumptions). `Task.detached` here is the justified exception to the no-detached rule: the preload must outlive potential ViewModel teardown and is already established in the codebase.

**Alternatives considered**: *No preload (load on stop)* — rejected: adds model-load latency to every post-recording transcription. *Longer/shorter fixed delay or audio-engine-callback trigger* — rejected: no reliable "HAL settled" signal; a fixed small delay is the simple, testable choice.

**Open risks**: 1.5 s may be wrong for some hardware (tunable constant, single site).

---

## Decision 8: Keep WhisperKitTranscriptionService's own beginBackgroundTask

**Decision**: The `beginBackgroundTask("WhisperTranscription")` at [`WhisperKitTranscriptionService.swift:145-147`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L145) **stays**. Transcription is a foreground-bound, seconds-to-minutes operation (budget ≤ ~7 min worst case per Decision 5, typically far less); the assertion is a cheap hedge against brief suspensions and its 30 s cap is irrelevant to the download problem being fixed. Only the *download* path's assertion (`AIModelServiceImpl.swift:49-59`) is removed.

**Alternatives considered**: *Remove it for consistency* — rejected: transcription mid-flight during a transient backgrounding would lose GPU work; keeping it costs nothing. Documented here so a future reader doesn't "clean it up" thinking it was missed.
