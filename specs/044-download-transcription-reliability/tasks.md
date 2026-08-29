# Tasks: Model Download & Transcription Pipeline Reliability

**Input**: Design documents from `/specs/044-download-transcription-reliability/`

**Prerequisites**: [plan.md](file:///Users/caesargrey/Projects/app-four-llama/specs/044-download-transcription-reliability/plan.md) (required), [spec.md](file:///Users/caesargrey/Projects/app-four-llama/specs/044-download-transcription-reliability/spec.md) (required for user stories), [research.md](file:///Users/caesargrey/Projects/app-four-llama/specs/044-download-transcription-reliability/research.md), [data-model.md](file:///Users/caesargrey/Projects/app-four-llama/specs/044-download-transcription-reliability/data-model.md), [quickstart.md](file:///Users/caesargrey/Projects/app-four-llama/specs/044-download-transcription-reliability/quickstart.md)

**Tests**: Test-first is MANDATORY for logic (services, calculator, resume store, eviction lifecycle) per Constitution **Principle X** — write the test, run it, confirm it **FAILS (RED)**, then implement just enough to make it pass (**GREEN**), then refactor. SwiftUI **views are EXEMPT** (no views in this feature; AppDelegate/DI wiring is build-verified). Tests use **Swift Testing** (`@Test`/`#expect`/`#require`). Each user story's Tests block below is REQUIRED, not optional.

**Organization**: Tasks are grouped by user story, but story phases are ordered by the execution strategy in plan.md: low-risk concurrency fixes first (US7, US3, US6), then MLX memory lifecycle (US5), then save coalescing (US4), then networking last and gated by an on-device spike (US1 → US2). Each story remains independently testable.

**Skills applied**: swift-concurrency (async property replacing `DispatchSemaphore`, actor + `@MainActor` coordinator wiring, `OSAllocatedUnfairLock` for delegate state), swift-testing (`@Suite`, parameterized `@Test(arguments:)`), ios-networking (background session is delegate-only, synchronous temp-file move in `didFinishDownloadingTo`, HTTP status validation), swiftdata (no `@Model` across actors, single save per transcription).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Link the already-declared swift-huggingface product into the app target so US1/US2 code can import it.

- [x] `T001` `[Setup]` **Link `HuggingFace` product into the app target**
  - **File:** `app-four.xcodeproj/project.pbxproj`
  - **Action:** The `XCRemoteSwiftPackageReference "swift-huggingface"` (0.9.0, lines 232, 842-849) and `XCSwiftPackageProductDependency "HuggingFace"` (lines 933-937) already exist. Add the `HuggingFace` product to the `app-four` target's `packageProductDependencies` list (~line 180) and its Frameworks build phase (~line 82). Do NOT remove `Hub`/`Tokenizers` yet — `Hub` is deleted in T029 after migration. Prefer Xcode's UI (target → Frameworks → + → HuggingFace) to avoid pbxproj merge hazards.
  - **Dependencies:** None
  - **Validation:** `xcodebuild -resolvePackageDependencies` succeeds; a scratch `import HuggingFace` compiles in the app target.

**Checkpoint**: `HuggingFace` product linked. All subsequent phases can begin.

---

## Phase 2: User Story 7 — Deadlock-Free Model State Checks (Priority: P3, executed first — low risk)

**Goal**: Delete the `DispatchSemaphore` bridge in `MLXJournalService.isModelLoaded`; the property becomes a non-blocking async actor read.

**Independent Test**: Static inspection shows no semaphore; full suite passes with the property awaited.

### Tests for User Story 7 (test-first · RED — MANDATORY) ⚠️

> **RED**: Convert the tests FIRST and RUN them — they MUST FAIL to compile against the current synchronous property (a compile failure is the RED state for a signature change).

- [x] `T002` `[US7]` **RED — Convert `modelNotLoadedAtInit` to async**
  - **File:** [`app-fourTests/MLXJournalServiceTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/MLXJournalServiceTests.swift) (lines 40-43)
  - **Action:** Change `@Test func modelNotLoadedAtInit()` to `@Test func modelNotLoadedAtInit() async` and the assertion to `#expect(await service.isModelLoaded == false)`.
  - **Dependencies:** None
  - **Validation:** Test target **FAILS to compile** — `isModelLoaded` is still synchronous. This is the RED state.

- [x] `T003` `[US7]` **RED — Convert `coldStartDoesNotLoadModel` to await**
  - **File:** [`app-fourTests/MLXJournalServiceTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/MLXJournalServiceTests.swift) (lines 57-61)
  - **Action:** The test is already `async`; change `#expect(service.isModelLoaded == false)` to `#expect(await service.isModelLoaded == false)`.
  - **Dependencies:** T002 (same file)
  - **Validation:** Same compile failure (RED).

### Implementation for User Story 7

- [x] `T004` `[US7]` **GREEN — Make `isModelLoaded` async, delete the semaphore**
  - **File:** [`app-four/Services/MLXJournalService.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/MLXJournalService.swift) (lines 137-154)
  - **Action:** Replace the `DispatchSemaphore` bridge with `var isModelLoaded: Bool { get async { await modelHolder.isLoaded } }`. Delete the semaphore, the `Task { ... sema.signal() }` block, and the stale comment block above the property. Grep the whole repo (`isModelLoaded`) to confirm the two tests were the only consumers.
  - **Dependencies:** T002, T003 (RED confirmed)
  - **Validation:** T002, T003 compile and turn **GREEN**. `grep -n DispatchSemaphore app-four/Services/MLXJournalService.swift` returns nothing. No new strict-concurrency diagnostics on this file.

**Checkpoint**: No blocking sync-over-async bridges remain. Independently shippable.

---

## Phase 3: User Story 3 — Thermal-Scaled Transcription Timeout (Priority: P1)

**Goal**: Replace both hardcoded 90s timeouts with `max(60s, duration × thermalRTF + 30s)` from a pure, testable calculator.

**Independent Test**: Unit tests pin the formula boundaries; a forced-throttle 6-minute fixture transcription completes; a stalled 30s transcription fails within ~60-72s.

### Tests for User Story 3 (test-first · RED — MANDATORY) ⚠️

- [x] `T005` `[P]` `[US3]` **RED — Test: formula boundaries and floor**
  - **File:** `app-fourTests/TranscriptionTimeoutCalculatorTests.swift` [NEW]
  - **Action:** Create `@Suite struct TranscriptionTimeoutCalculatorTests`. Add `@Test func nominalLongRecordingBudget()` — `#expect(TranscriptionTimeoutCalculator.budget(audioDuration: 300, thermalState: .nominal) == 150)`; `@Test func criticalLongRecordingBudget()` — `480s/.critical → 414`; `@Test func shortRecordingFloorsAtSixty()` — `30s/.nominal → 60` and `0s → 60`.
  - **Dependencies:** None
  - **Validation:** Test **FAILS** — `TranscriptionTimeoutCalculator` does not exist.

- [x] `T006` `[P]` `[US3]` **RED — Test: thermal state → RTF mapping**
  - **File:** `app-fourTests/TranscriptionTimeoutCalculatorTests.swift`
  - **Action:** Add `@Test(arguments: [(ProcessInfo.ThermalState.nominal, 0.4), (.fair, 0.4), (.serious, 0.6), (.critical, 0.8)]) func realTimeFactorMapping(state: ProcessInfo.ThermalState, expected: Double)` — `#expect(TranscriptionTimeoutCalculator.realTimeFactor(for: state) == expected)`.
  - **Dependencies:** T005 (same file)
  - **Validation:** Test **FAILS** (type doesn't exist).

### Implementation for User Story 3

- [x] `T007` `[US3]` **GREEN — Implement `TranscriptionTimeoutCalculator`**
  - **File:** `app-four/Services/TranscriptionTimeoutCalculator.swift` [NEW]
  - **Action:** Create `struct TranscriptionTimeoutCalculator: Sendable` with `static func realTimeFactor(for state: ProcessInfo.ThermalState) -> Double` (0.4 nominal/fair, 0.6 serious, 0.8 critical — `@unknown default` → 0.6, conservative middle) and `static func budget(audioDuration: TimeInterval, thermalState: ProcessInfo.ThermalState) -> TimeInterval` returning `max(60, audioDuration * rtf + 30)`. Pure functions, no stored state, no I/O.
  - **Dependencies:** T005, T006 (RED confirmed)
  - **Validation:** T005, T006 turn **GREEN**.

- [x] `T008` `[US3]` **Wire calculator into `CheckInViewModel`**
  - **File:** [`app-four/ViewModels/CheckInViewModel.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/CheckInViewModel.swift) (line 313)
  - **Action:** Replace `timeoutSeconds: 90` with `timeoutSeconds: UInt64(TranscriptionTimeoutCalculator.budget(audioDuration: recording.duration, thermalState: ProcessInfo.processInfo.thermalState))`. Read the thermal state at transcription start (single read; per research Decision 5). `consumeStreamWithTimeout` signature is unchanged.
  - **Dependencies:** T007
  - **Validation:** Build succeeds; existing CheckIn tests pass; no remaining `90` literal on this path.

- [x] `T009` `[US3]` **Wire calculator into `RecordingDetailViewModel`**
  - **File:** [`app-four/ViewModels/RecordingDetailViewModel.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/RecordingDetailViewModel.swift) (line 87)
  - **Action:** Replace `timeoutSeconds: 90` with the same calculator call using `recording.duration` and the current `ProcessInfo.thermalState`. `consumeTranscription` signature unchanged.
  - **Dependencies:** T007
  - **Validation:** Build succeeds; `grep -n "timeoutSeconds: 90" app-four/` returns nothing.

**Checkpoint**: Both timeout call sites scale with duration and thermal state. Independently shippable (quickstart Step 3 covers device verification later).

---

## Phase 4: User Story 6 — Glitch-Free Recording Start (Priority: P3)

**Goal**: Stagger WhisperKit preload ~1.5s behind audio engine start; cancellable within the window.

**Independent Test**: Logs show preload starting ~1.5s after record start; stopping within the window cancels preload (no model-load log).

### Tests for User Story 6

> ViewModel scheduling glue; the timing is verified by device QA (quickstart Step 6.4). Add one focused test for the cancellation path since it's logic-bearing.

- [x] `T010` `[US6]` **RED — Test: preload cancelled within window does not load model**
  - **File:** `app-fourTests/ViewModels/CheckInViewModelTests.swift` (existing suite)
  - **Action:** Using the existing mock `TranscriptionService` seam, add `@Test func preloadCancelledBeforeStaggerDoesNotLoadModel() async` — start recording on mocks, immediately stop (within the stagger window), wait briefly, `#expect(mockTranscriptionService.loadModelCallCount == 0)`. Add a call counter to the mock if it lacks one.
  - **Dependencies:** None
  - **Validation:** Test **FAILS** — preload currently fires immediately (no stagger).

### Implementation for User Story 6

- [x] `T011` `[US6]` **GREEN — Add 1.5s stagger to the preload task**
  - **File:** [`app-four/ViewModels/CheckInViewModel.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/CheckInViewModel.swift) (lines 169-177)
  - **Action:** Inside the existing `Task.detached(priority: .utility)` preload closure, insert before `loadModel()`: `try await Task.sleep(for: .milliseconds(1500))` and `try Task.checkCancellation()` (wrap the do/catch to treat `CancellationError` quietly — a stopped recording is not an error). In `stopTasks(cancelTranscription:)` (line 539-), add `modelPreloadTask?.cancel(); modelPreloadTask = nil` so a stop within the window cancels the pending sleep (stop re-loads on demand via the transcription path — research Decision 7). The detached task is the documented, justified exception to the no-detached rule.
  - **Dependencies:** T010 (RED confirmed)
  - **Validation:** T010 turns **GREEN**. Manual log check: preload log line appears ~1.5s after record start.

**Checkpoint**: Capture start is protected from CoreML/CoreAudio contention. Independently shippable.

---

## Phase 5: User Story 5 — MLX Memory Lifecycle (Priority: P2)

**Goal**: 20MB cache cap, post-inference `clearCache()`, and eviction of the model container on idle timer (3 min), memory warning, and background entry — wired lawfully under Swift 6 isolation.

**Independent Test**: Memory gauge verification (quickstart Step 5); unit tests pin timer cancel/reset and eviction semantics.

### Tests for User Story 5 (test-first · RED — MANDATORY) ⚠️

- [x] `T012` `[P]` `[US5]` **RED — Test: idle eviction timer fires and evicts**
  - **File:** [`app-fourTests/MLXJournalServiceTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/MLXJournalServiceTests.swift)
  - **Action:** Add an eviction suite with an injectable idle interval (the coordinator's timer duration must be an init parameter with a 3-minute default so tests use ~50ms). `@Test func idleTimerEvictsModel() async` — construct the service/coordinator with a short interval, simulate a completed inference (arm the timer), wait past the interval, `#expect(await service.isModelLoaded == false)`.
  - **Dependencies:** T004 (async `isModelLoaded` exists)
  - **Validation:** Test **FAILS** — no timer/coordinator exists.

- [x] `T013` `[P]` `[US5]` **RED — Test: new inference cancels and re-arms the timer**
  - **File:** [`app-fourTests/MLXJournalServiceTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/MLXJournalServiceTests.swift)
  - **Action:** `@Test func inferenceBeforeExpiryCancelsEviction() async` — short-interval coordinator; arm timer; before expiry, simulate another inference (reset); verify the model is still loaded past the original expiry point, and that eviction happens only after the *re-armed* interval elapses.
  - **Dependencies:** T012 (same suite)
  - **Validation:** Test **FAILS**.

- [x] `T014` `[P]` `[US5]` **RED — Test: memory-warning and background notifications evict**
  - **File:** [`app-fourTests/MLXJournalServiceTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/MLXJournalServiceTests.swift)
  - **Action:** `@Test func memoryWarningEvictsImmediately() async` and `@Test func backgroundEntryEvictsImmediately() async` — with a loaded (or stub-loaded) holder, post `UIApplication.didReceiveMemoryWarningNotification` / `UIApplication.didEnterBackgroundNotification` to `NotificationCenter.default`, yield, `#expect(await service.isModelLoaded == false)`.
  - **Dependencies:** T012 (same suite)
  - **Validation:** Tests **FAIL** — no observers exist.

### Implementation for User Story 5

- [x] `T015` `[US5]` **GREEN — Add `evict()` to `ModelHolder`**
  - **File:** [`app-four/Services/MLXJournalService.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/MLXJournalService.swift) (`private actor ModelHolder`, lines 95-133)
  - **Action:** Add `func evict() { modelContainer = nil; isLoaded = false; MLX.Memory.clearCache() }`. Add an `isGenerating` guard (set true at the top of `generateText`, false in a `defer`) so eviction requested mid-inference is a no-op — the caller re-arms instead (research Decision 3).
  - **Dependencies:** T012–T014 (RED confirmed)
  - **Validation:** Compiles; actor isolation intact (no locks introduced).

- [x] `T016` `[US5]` **GREEN — Implement the `@MainActor` lifecycle coordinator**
  - **File:** [`app-four/Services/MLXJournalService.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/MLXJournalService.swift)
  - **Action:** Add `private final class LifecycleCoordinator` (`@MainActor`): init takes the `ModelHolder` reference and `idleInterval: Duration = .seconds(180)`; owns two NotificationCenter observer tokens (memory warning, background entry) removed in `deinit`/`invalidate()`; owns a cancellable `Task` idle timer with `arm()` (cancel existing, sleep interval, then `await holder.evict()` unless generating → re-arm) and `cancel()`. Observers call the same evict-or-rearm logic immediately.
  - **Dependencies:** T015
  - **Validation:** T012–T014 turn **GREEN**. No strict-concurrency diagnostics.

- [x] `T017` `[US5]` **Wire cache cap, clearCache, and coordinator into the service**
  - **File:** [`app-four/Services/MLXJournalService.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/MLXJournalService.swift)
  - **Action:** In `init`: set `MLX.Memory.cacheLimit = 20 * 1024 * 1024` and create the coordinator (created lazily on first use if `@MainActor` init from a nonisolated init is awkward — decide during implementation, keep it simple). In `summarize(rawTranscription:)`: call `MLX.Memory.clearCache()` and `await coordinator.arm()` in a `defer`-style position after each inference completes (both the first-pass and correction-prompt paths).
  - **Dependencies:** T016
  - **Validation:** All Phase 5 tests GREEN; manual gauge check (deferred to T036) shows cap and eviction.

**Checkpoint**: MLX footprint returns to baseline on timer/warning/background. Independently verifiable.

---

## Phase 6: User Story 4 — Batch Transcription, Single Persistence Write (Priority: P2)

**Goal**: Exactly one `store.save()` per transcription completion across all three consumers; no partial transcript persisted on failure.

**Independent Test**: Save-count instrumentation suite (quickstart Step 4).

### Tests for User Story 4 (test-first · RED — MANDATORY) ⚠️

- [x] `T018` `[US4]` **RED — Test: exactly one save per transcription, all paths**
  - **File:** `app-fourTests/SaveCountTests.swift` [NEW]
  - **Action:** Create a save-counting wrapper around the `RecordingStore` seam (subclass or counter-injected store, matching how existing tests substitute the store). `@Test func interactiveTranscriptionSavesExactlyOnce() async` — drive a mocked `TranscriptionService` emitting progress + one final segment through `CheckInViewModel.transcribeInBackground`; `#expect(store.saveCount == 1)` for the completion transition. `@Test func failedTranscriptionSavesOnceWithNoPartialText() async` — error-emitting mock; one save; `fullTranscriptText` is the error message only. `@Test func pendingDrainSavesOncePerRecording() async` — `PendingTranscriptionServiceImpl` drain over one pending recording; one save for `.completed`.
  - **Dependencies:** None (uses existing mocks; extend them as needed)
  - **Validation:** Tests **FAIL** — current code saves per segment (3 sites).

### Implementation for User Story 4

- [x] `T019` `[US4]` **GREEN — Coalesce saves in `CheckInViewModel`**
  - **File:** [`app-four/ViewModels/CheckInViewModel.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/CheckInViewModel.swift) (lines 371-380)
  - **Action:** In `consumeStreamWithTimeout`'s segment loop, remove `self.store.save()` (line 379): mutate `recording.fullTranscriptText`/`status` in memory only. Progress placeholder segments ("Setting up…", "Transcribing…") must not be committed as transcript content — only the final `isFinal` segment's text is kept. The existing single saves on `.completed` (line 322) and each failure path (lines 343, 351, 357) remain the terminal writes.
  - **Dependencies:** T018 (RED confirmed)
  - **Validation:** First two T018 tests turn **GREEN** for the interactive path.

- [x] `T020` `[US4]` **GREEN — Coalesce saves in `RecordingDetailViewModel`**
  - **File:** [`app-four/ViewModels/RecordingDetailViewModel.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/RecordingDetailViewModel.swift) (lines 108-130)
  - **Action:** Remove the per-segment `self.store.save()` (line 120) from `consumeTranscription`'s loop; text/status mutate in memory. Terminal saves stay: completion (line 89) and `finishFailed` (lines 102-106).
  - **Dependencies:** T018
  - **Validation:** Retry-path saves exactly once (extend T018 or assert via existing detail-view tests).

- [x] `T021` `[US4]` **GREEN — Coalesce saves in `PendingTranscriptionServiceImpl`**
  - **File:** [`app-four/Services/PendingTranscriptionServiceImpl.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/PendingTranscriptionServiceImpl.swift) (lines 106-115)
  - **Action:** Remove `store.save()` from `writeSegment` (line 113) — it now only mutates and returns the still-present Bool. The existing single saves in `applyResult` (line 132) and `markFailed` (line 143) remain the terminal writes.
  - **Dependencies:** T018
  - **Validation:** `pendingDrainSavesOncePerRecording` turns **GREEN**. Full suite still green.

**Checkpoint**: One save per transcription everywhere; no partial text persisted on failure.

---

## Phase 7: User Story 1 — Background LLM Downloads (Priority: P1) 🎯 GATED

**Goal**: LLM snapshot downloads survive screen lock/backgrounding via a system-managed background session through swift-huggingface — or the app-owned fallback if the spike fails.

**Independent Test**: quickstart Step 1 — locked-device download completes 3/3 runs.

**⚠️ GATE**: T022 decides the engine. Never ship both paths (Constitution III/IV; plan Complexity Tracking).

- [x] `T022` `[US1]` **SPIKE — Validate swift-huggingface background session on-device**
  - **File:** `app-four/Services/AIModelServiceImpl.swift` (spike code, temporary DEBUG-only harness acceptable) + `app-four/Utils/Constants.swift` (read-only)
  - **Action:** With the `HuggingFace` product linked (T001), wire a minimal DEBUG-only spike: start downloading the `mlx-community/Qwen2.5-1.5B-Instruct-4bit` snapshot via swift-huggingface configured for a background `URLSession` (stable identifier, `waitsForConnectivity = true`), lock a physical device for 5+ minutes, observe whether transfer continues and completes. Inspect swift-huggingface's API surface first — if it exposes no background-session configuration at all, the spike fails immediately without device time.
  - **Dependencies:** T001
  - **Validation:** **Decision record appended to `specs/044-download-transcription-reliability/research.md` Decision 1**: PASS (background transfer completes while locked → proceed to T023) or FAIL (crashes / foreground-only / no API → skip to T024 fallback). Remove any temporary spike code after recording the decision.

- [ ] `T023` `[US1]` **PRIMARY PATH — Migrate `downloadLLMModel` to swift-huggingface background download** *(only if T022 PASS)*
  - **File:** [`app-four/Services/AIModelServiceImpl.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/AIModelServiceImpl.swift) (lines 11-18, 49-59, 205-209)
  - **Action:** Re-implement `downloadLLMModel(progress:)` on swift-huggingface with background transfer: resolve CDN binary URLs (never Git LFS pointers — FR-005), download into a staging subdirectory of `ModelConstants.llmDownloadBase`, atomically rename into the final layout so `findLLMModelDirectory` (lines 217-250) never sees a partial snapshot (FR-002). Delete the `beginBackgroundTask` block (lines 49-59) and the stale HubApi comment (lines 11-17). Throttle progress yields to 1% steps before forwarding to the continuation (FR-004): track last-emitted integer percent, skip yields until it advances.
  - **Dependencies:** T022 (PASS recorded)
  - **Validation:** Build succeeds; quickstart Step 1 passes 3/3 on device; partial-directory state can never satisfy `findLLMModelDirectory` (interrupt mid-transfer and confirm `localPath(for: .llm) == nil`).

- [x] `T024` `[US1]` **FALLBACK PATH — App-owned `URLSessionConfiguration.background` download service** *(only if T022 FAIL — replaces T023)*
  - **File:** `app-four/Services/BackgroundLLMDownloadService.swift` [NEW — fallback only]
  - **Action:** Create `final class BackgroundLLMDownloadService: NSObject, URLSessionDownloadDelegate` owning a `URLSessionConfiguration.background(identifier:)` session (stable identifier, `waitsForConnectivity = true`, launch events enabled). Delegate-only APIs (no async convenience methods on background configs — ios-networking skill). Resolve each snapshot file's CDN URL, create download tasks per file into staging. In `urlSession(_:downloadTask:didFinishDownloadingTo:)` move the temp file **synchronously** into staging. Validate HTTP status in `didCompleteWithError` (200/206 OK; 412/416 → clear resume state and restart clean). Task→file bookkeeping guarded by `OSAllocatedUnfairLock`, never held across `await`. Then re-point `AIModelServiceImpl.downloadLLMModel` at this service (same staging/atomic-rename/throttle requirements as T023).
  - **Dependencies:** T022 (FAIL recorded)
  - **Validation:** Same as T023. Fallback exists only in the FAIL branch; T023's code is never written.

**Checkpoint**: Locked-device download works via exactly one engine. Record which engine shipped in research.md.

---

## Phase 8: User Story 2 — Byte-Range Resume (Priority: P1)

**Goal**: Interrupted downloads resume from the last byte via persisted resume state + HTTP Range, with silent fallback to clean download on stale state.

**Independent Test**: quickstart Step 2 — airplane-mode resume shows HTTP 206 and ≤5% redundant bytes.

### Tests for User Story 2 (test-first · RED — MANDATORY) ⚠️

- [x] `T025` `[P]` `[US2]` **RED — Test: resume-state round-trip and corruption handling**
  - **File:** `app-fourTests/ResumeStateStoreTests.swift` [NEW]
  - **Action:** Create `@Suite struct ResumeStateStoreTests` with an injected temp directory. `@Test func saveLoadRoundTrip()` — save a `ResumeState`, load returns an equal value. `@Test func corruptJSONReturnsNilAndDeletesFile()` — write garbage bytes; load → nil and file gone. `@Test func atomicWriteLeavesNoPartialFile()` — assert no temp artifacts remain after save. `@Test func clearIsIdempotent()`.
  - **Dependencies:** None
  - **Validation:** Tests **FAIL** — `ResumeStateStore` doesn't exist.

- [x] `T026` `[P]` `[US2]` **RED — Test: staleness rules**
  - **File:** `app-fourTests/ResumeStateStoreTests.swift`
  - **Action:** `@Test func missingTempFileInvalidatesState()`, `@Test func repoMismatchInvalidatesState()`, `@Test func zeroOffsetInvalidatesState()` — each must return nil and delete the file (FR-008 silent fallback).
  - **Dependencies:** T025 (same file)
  - **Validation:** Tests **FAIL**.

### Implementation for User Story 2

- [x] `T027` `[US2]` **GREEN — Implement `ResumeState` + `ResumeStateStore`**
  - **File:** `app-four/Services/ResumeStateStore.swift` [NEW]
  - **Action:** `struct ResumeState: Codable, Equatable, Sendable` (`repoID`, `fileURL`, `tempFileID`, `byteOffset: Int64`, `etag: String?`). `struct ResumeStateStore: Sendable` with injected directory (default `Library/Caches`): `load(for repoID:) -> ResumeState?` (all staleness rules from data-model.md §1, deletes invalid state), `save(_:) throws` (`.atomic` write), `clear(for:)`. File name `llm-resume-state.json`.
  - **Dependencies:** T025, T026 (RED confirmed)
  - **Validation:** T025, T026 turn **GREEN**.

- [x] `T028` `[US2]` **Integrate resume into the download engine**
  - **File:** [`app-four/Services/AIModelServiceImpl.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/AIModelServiceImpl.swift) (T023 branch) **or** `app-four/Services/BackgroundLLMDownloadService.swift` (T024 branch)
  - **Action:** On cancellation/failure of an attempt, capture `ResumeState` (offset from staged file size, ETag from response headers) via `ResumeStateStore` (FR-007). On attempt start, load state; if valid, send `Range: bytes=<offset>-` (manual header on the fallback; client resume support on the primary if exposed). Accept HTTP 206 (append from offset) and HTTP 200 (restart file from byte 0). On 412/416/ETag-mismatch: clear state, restart clean, no user-facing error (FR-008). Extend `classify(_:)` only if new error cases must surface distinctly.
  - **Dependencies:** T027; T023 or T024 (whichever shipped)
  - **Validation:** quickstart Step 2 on device: 206 logged, ≤5% redundant bytes (SC-002); stale-state negative case silently restarts.

**Checkpoint**: Resume works end-to-end inside the shipped engine.

---

## Phase 9: US1/US2 Integration — AppDelegate Hook, ResilientModelDownload, Cleanup

**Goal**: Reconnect background sessions across process death; keep `ResilientModelDownload` as the outer harness; retire `Hub`.

- [x] `T029` `[US1]` **Remove `HubApi` and the `Hub` product**
  - **File:** [`app-four/Services/AIModelServiceImpl.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/AIModelServiceImpl.swift) + `app-four.xcodeproj/project.pbxproj`
  - **Action:** Delete `import Hub` (line 4), the `llmHub` property (line 18), and its init (line 30). Remove the `Hub` product from the target's `packageProductDependencies` and Frameworks phase (pbxproj lines 14, 83, 182). Keep `Tokenizers` (still used by MLX inference). Keep the swift-transformers package reference itself.
  - **Dependencies:** T028
  - **Validation:** Build succeeds; `grep -rn "HubApi\|import Hub" app-four/` returns nothing.

- [x] `T030` `[US1]` **Add `AppDelegate` with the background-URLSession completion hook**
  - **File:** `app-four/App/AppDelegate.swift` [NEW] + [`app-four/App/SquirlApp.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/App/SquirlApp.swift)
  - **Action:** Create `final class AppDelegate: NSObject, UIApplicationDelegate` implementing `application(_:handleEventsForBackgroundURLSession:completionHandler:)`: stash the completion handler, re-instantiate the background session with the same identifier so queued delegate events drain, call the handler from `urlSessionDidFinishEvents(forBackgroundURLSession:)`, then post `.aiModelAvailabilityDidChange` so rows settle to filesystem truth (FR-003). In `SquirlApp`, add `@UIApplicationDelegateAdaptor private var appDelegate: AppDelegate`. No other scene/init changes. (Build-verified — SwiftUI-adjacent wiring, exempt from test-first.)
  - **Dependencies:** T028
  - **Validation:** Build succeeds; quickstart Step 1.5: swipe-kill mid-download, relaunch → transfer continues/resumes and the completion handler fires (log line).

- [x] `T031` `[US1]` **Verify `ResilientModelDownload` harness compatibility**
  - **File:** [`app-four/Services/ResilientModelDownload.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/ResilientModelDownload.swift) (expected unchanged — verification task) + [`app-four/App/SquirlApp.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/App/SquirlApp.swift) (`startBackgroundModelDownloadIfNeeded`, line 156)
  - **Action:** Confirm the attempt loop, stall watchdog (45s), connectivity wait, and 8-attempt cap still wrap the new engine correctly: the watchdog's cancellation must now trigger resume-state capture (T028) instead of discarding progress. Adjust wiring only if a seam is missing — do not change the retry policy (spec Assumptions). Re-check the launch-time background fetch path still calls through the same `AIModelService.download(.llm)` entry point.
  - **Dependencies:** T028, T030
  - **Validation:** Existing `ResilientModelDownload` tests pass unmodified; a forced stall on device resumes from offset on the next attempt rather than from zero.

**Checkpoint**: US1 + US2 complete end-to-end: background-survivable, byte-resumable downloads behind the existing retry harness.

---

## Phase 10: Polish & Verification (SC-001..SC-006)

**Purpose**: Full device + suite verification per quickstart.md. Each task maps to a success criterion.

- [x] `T032` `[Verify]` **SC-001 — Locked-device download, 3 consecutive runs**
  - **File:** N/A (device QA, quickstart Step 1)
  - **Action:** Physical device; delete LLM; start download; lock 5+ minutes; verify completion + model generates. 3/3 runs required.
  - **Dependencies:** T031
  - **Validation:** 100% success across 3 runs; `findLLMModelDirectory` resolves; summarization works.

- [ ] `T033` `[Verify]` **SC-002 — Airplane-mode resume measurement**
  - **File:** N/A (device QA, quickstart Step 2)
  - **Action:** Interrupt at ~50% via Airplane Mode; confirm HTTP 206 resume and ≤5% redundant bytes from byte-count logs; run the stale-state negative case.
  - **Dependencies:** T031
  - **Validation:** ≤5% redundant bytes; silent clean fallback on stale state.

- [ ] `T034` `[P]` `[Verify]` **SC-003 — Thermal timeout fixtures**
  - **File:** `app-fourTests/TranscriptionTimeoutCalculatorTests.swift` + device/simulator fixture run (quickstart Step 3)
  - **Action:** Calculator boundary tests already green (T005/T006). Transcribe the 6-minute fixture with forced `.serious` — no timeout. Forced-stall 30s clip fails within ~60-72s and is retryable.
  - **Dependencies:** T009
  - **Validation:** Long fixture completes; stalled clip fails fast and recovers.

- [ ] `T035` `[P]` `[Verify]` **SC-004 — Save-count audit**
  - **File:** `app-fourTests/SaveCountTests.swift` (quickstart Step 4)
  - **Action:** Save-count suite green (T018); manual console spot-check shows one completion save per transcription on device.
  - **Dependencies:** T021
  - **Validation:** Exactly 1 save per completion on both paths; no partial text on failure.

- [ ] `T036` `[Verify]` **SC-005 — Memory gauge eviction matrix**
  - **File:** N/A (device QA, quickstart Step 5)
  - **Action:** Verify all four eviction triggers on the memory gauge (background, 3-min idle, memory warning, timer reset on re-inference); cache ≤20MB during decode; 10× background-switch loop with zero Jetsam `per-process-limit` terminations.
  - **Dependencies:** T017
  - **Validation:** Footprint returns within 100MB of baseline on every trigger; zero background OOMs.

- [x] `T037` `[Verify]` **SC-006 — Strict-concurrency clean build + full test suite**
  - **File:** N/A (build/test runner, quickstart Step 6)
  - **Action:** `xcodebuild -project app-four.xcodeproj -scheme app-four -destination 'platform=iOS Simulator,name=iPhone 17' build` — zero strict-concurrency diagnostics on modified files. `grep -n DispatchSemaphore app-four/Services/MLXJournalService.swift` → empty. Full `xcodebuild test` (or `app-four.xctestplan`) — entire suite green including all new suites.
  - **Dependencies:** All previous tasks
  - **Validation:** Clean build, zero new warnings, full suite green.

- [ ] `T038` `[P]` `[Verify]` **US6 device spot-check — glitch-free recording start**
  - **File:** N/A (device QA, quickstart Step 6.4)
  - **Action:** On A14/A15-class hardware: start/stop recordings of varying lengths; no CoreAudio underruns at capture start; preload log at ~1.5s; stop-within-window cancels preload (no model-load log).
  - **Dependencies:** T011
  - **Validation:** No capture-start artifacts; stagger timing confirmed (tune the 1.5s constant if QA disagrees — single site, `CheckInViewModel`).

- [x] `T039` `[Polish]` **Update docs: research.md engine record + DEVLOG/backlog**
  - **File:** `specs/044-download-transcription-reliability/research.md` (Decision 1 outcome — may already be updated by T022) + `docs/DEVLOG.md` + `docs/BACKLOG.md`
  - **Action:** Ensure the spike outcome and shipped engine are recorded; log the feature at its checkpoint in DEVLOG; move the backlog item stage.
  - **Dependencies:** T032–T037
  - **Validation:** Docs reflect what actually shipped.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies. T001 unblocks networking phases only — Phases 2-6 do NOT depend on it.
- **Phase 2 (US7 semaphore)**: No dependencies. Lowest risk; do first.
- **Phase 3 (US3 timeout)**: No dependencies. Independent of Phase 2.
- **Phase 4 (US6 stagger)**: No dependencies (shares `CheckInViewModel.swift` with Phases 3/6 — sequence edits to that file: T008, T011, T019).
- **Phase 5 (US5 MLX lifecycle)**: Depends on T004 (async `isModelLoaded` used by eviction tests).
- **Phase 6 (US4 save coalescing)**: No hard dependencies; ordered after Phase 5 to keep `CheckInViewModel` edits sequential.
- **Phase 7 (US1 gated networking)**: Depends on T001. T022 gates T023 XOR T024.
- **Phase 8 (US2 resume)**: Depends on the shipped engine (T023 or T024).
- **Phase 9 (integration)**: Depends on T028.
- **Phase 10 (verification)**: Each task depends on its story's completion; T037 depends on everything.

### Critical Path

```
T022 (spike) → T023/T024 (engine) → T027/T028 (resume) → T029–T031 (integration) → T032/T033/T037 (device + suite gates)
```

### Within Each User Story

- Tests MUST be written, RUN, and confirmed FAILING (RED) before implementation (GREEN); refactor after green (Principle X)
- Logic units (calculator, resume store, ModelHolder/coordinator) before their call-site wiring
- `CheckInViewModel.swift` edits are sequential: T008 → T011 → T019
- Networking is last and gated: spike decides engine; fallback replaces primary — never both

### Parallel Opportunities

- Phases 2, 3, 4 can run in parallel (different files except the noted `CheckInViewModel` sequencing)
- T005/T006, T012–T014, T025/T026 — same-file test batches, write together
- T034, T035, T038 verification tasks are independent once their stories land

---

## Implementation Strategy

### Incremental Delivery

1. Phases 2-4 (US7/US3/US6): quick, independently shippable concurrency and reliability fixes — could land alone as a first PR slice.
2. Phase 5 (US5): memory lifecycle — second slice.
3. Phase 6 (US4): save coalescing — third slice.
4. Phases 7-9 (US1/US2): networking, gated by the on-device spike — final slice.
5. Phase 10: verification gates before merge (`/code-review` per Constitution V).

### MVP Definition

There is no partial-networking MVP: the spec's P1 stories require the full download path. The minimal *mergeable* increment is Phases 2-4 (no new dependencies, pure reliability wins).

---

## Notes

- `[P]` tasks = different files, no dependencies
- `[Story]` label maps task to spec user story (US1..US7) for traceability
- Verify tests FAIL (RED) before implementing; never write implementation ahead of its test (Principle X)
- Commit after each task or logical group
- Stop at any checkpoint to validate the story independently
- The fallback service (`BackgroundLLMDownloadService`, T024) exists ONLY in the spike-FAIL branch — do not create it speculatively (Principle III: no dead code)
- All logging added in this feature: counts, durations, byte offsets, thermal states only — never transcript content (Principle VI)
