# Feature Specification: Model Download & Transcription Pipeline Reliability

**Feature Branch**: `feat/043-mlx-journal-service` (continues on existing branch per user instruction)

**Created**: 2026-08-14

**Status**: Draft (clarified)

**Input**: User description: "Engineering improvement report v3.1 covering: (1) true out-of-process background model downloads via URLSessionConfiguration.background replacing the 30-second UIBackgroundTask cap, (2) HTTP byte-range resumable downloads instead of file-level retries, (3) MLX unified memory lifecycle with 20MB buffer cache cap, post-inference clearCache(), and 3-minute idle auto-eviction, (4) dynamic transcription timeout scaling replacing the hardcoded 90s timeout, (5) eliminating the DispatchSemaphore synchronous bridge in MLXJournalService.isModelLoaded, (6) 1.5s staggered WhisperKit preload to avoid CoreAudio/CoreML startup contention, (7) real-time WhisperKit segment streaming with SwiftData main-thread decoupling."

**Source**: Model Download & Audio Transcription Engineering Improvement Report v3.1 (provided in conversation)

## Clarifications

### Session 2026-08-14

- Q: How should the LLM snapshot download replace the HubApi foreground session? → A: **Adopt `swift-huggingface`** (official HF client) rather than a hand-rolled session or keeping HubApi.
- Q: Which transcription paths get real-time segment streaming? → A: **None.** Real-time streaming is explicitly descoped. The priority is *lightweight, reliable, crash-free execution* — not live transcript UI. Transcription remains batch; persistence stays a single save per transcription.
- Q: Besides the 3-minute idle timer, what else triggers MLX eviction? → A: **Timer + memory warning + app background** — evict on idle timeout, `didReceiveMemoryWarning`, and `applicationDidEnterBackground`.
- Q: Timeout formula constants? → A: **Tighter** — margin 30s (not 45s), thermal RTF 0.4 / 0.6 / 0.8 (nominal|fair / serious / critical), floor 60s.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Model downloads survive screen lock and app backgrounding (Priority: P1)

When a user starts downloading the insights LLM (~1.05 GB) and then locks the screen or switches apps, the download continues to completion via a system-managed background transfer instead of freezing after ~30 seconds. (The Whisper model path already uses a background session via `WhisperKit.download(useBackgroundSession: true)`; this story targets the LLM/Hub path.)

**Why this priority**: A ~1.05 GB payload takes ~7 minutes on 20 Mbps LTE. With the current `UIApplication.beginBackgroundTask` assertion (capped at ~30s by runningboardd), LLM downloads reliably freeze whenever the user backgrounds the app — the single largest cause of failed model installs.

**Independent Test**: Start the LLM download on a physical device, lock the screen for 5+ minutes, unlock, and verify the download completed and the model loads and generates. No user interaction with the app during the locked period.

**Acceptance Scenarios**:

1. **Given** an LLM download in progress, **When** the user locks the device for longer than 30 seconds, **Then** the download continues and completes, and the app reconnects to the completed snapshot on next foreground/launch.
2. **Given** a background download in progress, **When** the app process is terminated by the system (Jetsam or user swipe-kill), **Then** the transfer continues (or resumes) and the app is relaunched to finish integration via the background-session completion handler.
3. **Given** the download completes, **When** the snapshot is integrated, **Then** downloaded files land in the app-owned model directory layout that `AIModelServiceImpl.findLLMModelDirectory` can locate, and a partial/incomplete directory is never handed to the MLX loader.

---

### User Story 2 — Interrupted downloads resume from the last byte, not from zero (Priority: P1)

When an LLM download is interrupted by a network drop, stall watchdog, or app suspension, the next attempt resumes from the exact byte offset using HTTP Range requests and persisted resume data, instead of discarding up to ~1 GB of partial progress.

**Why this priority**: Under file-level retry granularity, a stall at 94% of `model.safetensors` wipes ~990 MB. On flaky connections this can burn ~7 GB of cellular data across the 8-attempt cap without ever completing.

**Independent Test**: Start the LLM download on device, disable Wi-Fi at ~50%, re-enable, and verify the transfer resumes from the recorded offset (log confirms an HTTP 206 partial-content response or equivalent resume telemetry from swift-huggingface) and the final snapshot passes validation.

**Acceptance Scenarios**:

1. **Given** a download interrupted at N bytes with valid resume state, **When** the retry executes, **Then** a Range-resume request is sent and only the remaining bytes transfer.
2. **Given** resume state whose temp file was purged by the OS or whose remote file changed (ETag mismatch), **When** the resume attempt fails, **Then** the engine discards the stale state and falls back to a clean full download without surfacing an error to the user.
3. **Given** the app is relaunched after being killed mid-download, **When** the model download is requested again, **Then** persisted resume state is loaded and the transfer continues from the saved offset.

---

### User Story 3 — Long recordings transcribe without false timeout failures (Priority: P1)

A user recording a 5–8 minute check-in on an older or thermally throttled device gets a successful transcription instead of a spurious `.failed` status caused by a fixed 90-second watchdog.

**Why this priority**: Under thermal throttling, an 8-minute recording can need ~6+ minutes of processing. The current hardcoded 90s timeout (present in both `CheckInViewModel` and `RecordingDetailViewModel`) guarantees failure for exactly the longest, most valuable recordings — while an overly generous timeout would delay detection of genuine stalls. The user chose a tighter formula to keep stall detection fast.

**Independent Test**: Transcribe a 6-minute fixture audio with the timeout calculator forced to a throttled thermal state and verify no timeout fires; separately verify a genuinely stalled short transcription still times out near its computed (much shorter) budget.

**Acceptance Scenarios**:

1. **Given** a 300-second recording on a device in `.nominal` thermal state, **When** transcription starts, **Then** the timeout budget is max(60s, 300 × 0.4 + 30s) = 150s and a healthy transcription completes without timing out.
2. **Given** a 480-second recording with `.critical` thermal state, **When** transcription starts, **Then** the budget is 480 × 0.8 + 30 = 414s and the transcription completes.
3. **Given** any recording where the transcription engine genuinely stalls, **When** the computed budget elapses with no completion, **Then** the recording is marked failed with a timeout error and the user can retry.

---

### User Story 4 — Transcription executes lean: batch result, single persistence write (Priority: P2)

Transcription remains a batch operation (no live token/segment streaming — explicitly descoped by the user). The pipeline's job is to run lightweight and not crash: one transcription produces one final transcript and exactly one SwiftData save; no partial text is ever written to disk, and no full-table re-fetch or NotificationCenter broadcast fires mid-transcription.

**Why this priority**: The user's stated priority is reliable, crash-free execution over live UI. Keeping the batch path avoids the streaming complexity entirely while the single-save rule eliminates the SQLite write-thrash / main-thread hitch risk flagged in the report should multiple segments ever be yielded.

**Independent Test**: Instrument `store.save()` call count during a full transcription (both the interactive `CheckInViewModel` path and the background `PendingTranscriptionServiceImpl` drain) and verify exactly one save per transcription, with status transitioning cleanly from `.transcribing` to terminal state.

**Acceptance Scenarios**:

1. **Given** any recording transcribed to completion, **When** the result returns, **Then** the cleaned transcript is persisted in exactly one SwiftData save and the recording status transitions to its terminal state.
2. **Given** the background pending-transcription drain processing a queue, **When** each recording transcribes, **Then** intermediate status/text updates do not each trigger `store.save()` + full re-fetch cycles (at most one save per recording state transition).
3. **Given** a transcription failure or timeout, **When** the error is handled, **Then** the recording is marked `.failed` with one save and no partial transcript text is persisted.

---

### User Story 5 — App memory returns to baseline after journaling, and never survives backgrounding (Priority: P2)

After the user's last LLM interaction, the ~1.2–1.4 GB MLX model footprint is evicted from unified memory — at the latest when the 3-minute idle timer fires, and immediately on a memory warning or when the app enters the background — so the app is never Jetsam-killed while suspended, and a subsequent voice check-in never forces WhisperKit and MLX to coexist in RAM.

**Why this priority**: Prevents background OOM terminations (which destroy in-flight state and inflate crash metrics) and WhisperKit/MLX memory collisions (~1.8 GB combined). The user explicitly chose the strongest eviction policy (timer + memory warning + background).

**Independent Test**: Run a check-in with summarization; verify via memory gauges that (a) footprint drops to ~baseline immediately after backgrounding the app, (b) footprint drops within ~3 minutes of last inference if left foregrounded, (c) a simulated memory warning evicts immediately, and (d) the MLX buffer cache never exceeds the 20 MB cap during decoding.

**Acceptance Scenarios**:

1. **Given** a completed LLM inference, **When** it finishes, **Then** the MLX Metal buffer cache is flushed immediately and the idle eviction timer (~3 min) is (re)armed.
2. **Given** a loaded model, **When** the app enters the background or receives a memory warning, **Then** the model container is released and the cache cleared before/at suspension.
3. **Given** an armed eviction timer, **When** a new inference request arrives before expiry, **Then** the timer is cancelled and the loaded model is reused with zero reload latency.
4. **Given** any eviction, **When** the next inference request arrives, **Then** the model cold-loads cleanly through the existing memory-headroom gate.

---

### User Story 6 — Recording start is glitch-free while the model preloads (Priority: P3)

When the user taps record, microphone capture starts cleanly (no clicks, pops, or dropped initial frames) even though WhisperKit begins preloading shortly after.

**Why this priority**: Audio artifacts affect a narrow window (recording start) and are mitigated, not user-blocking. Preload staggering is a small, low-risk scheduling change.

**Independent Test**: Start and stop recordings of varying lengths on an A14/A15-class device; verify (a) no CoreAudio buffer underruns in logs at capture start, (b) preload begins ~1.5s after record start, (c) stopping within 1.5s cancels the preload without loading weights.

**Acceptance Scenarios**:

1. **Given** the user starts recording, **When** the audio engine activates, **Then** model preload is deferred ~1.5 seconds so CoreML weight compilation never collides with audio HAL startup.
2. **Given** the user cancels/stops recording within the 1.5s window, **When** the preload task wakes, **Then** it observes cancellation and no model weights are loaded.

---

### User Story 7 — Deadlock-free model state checks (Priority: P3)

Any caller checking whether the LLM is loaded does so through a non-blocking asynchronous API, eliminating the `DispatchSemaphore.wait()` bridge that can starve the Swift cooperative thread pool.

**Why this priority**: The deadlock is probabilistic (requires pool saturation) and hasn't been observed as a user-facing hang, but it is a hard Swift 6 concurrency violation with unbounded worst-case cost — and "no crashes" is the user's stated top priority.

**Independent Test**: Static inspection confirms no semaphore remains; the previously synchronous consumer (test) is updated to `await` the property; full test suite passes under strict concurrency.

**Acceptance Scenarios**:

1. **Given** any thread context, **When** `isModelLoaded` is queried, **Then** the check is an `async` actor read with no thread blocking.
2. **Given** the synchronous consumer (test), **When** updated to await the async property, **Then** it passes and the project compiles with no strict-concurrency warnings on this path.

---

### Edge Cases & Error Handling

#### 1. Network & Connectivity Failures
- **Scenario:** Wi-Fi drops mid-download; cellular handover stalls the socket; server ignores the Range request and returns HTTP 200 (full file).
- **System Behavior:** Resume state is captured (from the client's resume support or `URLError.userInfo`) and persisted atomically to the caches directory; retry issues a Range-resume; an HTTP 200 response is accepted as a valid fresh stream from byte 0; exhausted retries surface the existing `ResilientModelDownload` error.
- **User Experience (UX):** Download progress resumes from its last percentage after connectivity returns; no duplicate data usage; on final failure the existing error UI with retry affordance is shown.

#### 2. Data Validation & Bad Input
- **Scenario:** Corrupted or tampered downloaded model file; resume state unreadable after an OS update; swift-huggingface background session unavailable on-device (the same class of limitation that broke swift-transformers).
- **System Behavior:** Snapshot validation rejects invalid/incomplete directories (`findLLMModelDirectory` already returns nil for partial snapshots); unreadable resume state is discarded and a clean download starts. If swift-huggingface's background path proves broken on-device, the plan MUST fall back to an app-owned delegate-driven `URLSessionConfiguration.background` session for the weight files rather than shipping a foreground-only download.
- **User Experience (UX):** The model simply re-downloads; the user is never shown a corrupt-model inference failure.

#### 3. State Restoration & Interruptions
- **Scenario:** App terminated mid-download; app backgrounded during transcription or right after summarization; phone call interrupts recording.
- **System Behavior:** Background session state is owned by the system daemon and reconnected on launch via the background-URLSession completion hook; MLX eviction on background-entry guarantees the model is never resident while suspended; WhisperKit already unloads post-transcription; existing recording-interruption handling is unchanged.
- **User Experience (UX):** On relaunch, downloads either completed (model ready) or resume transparently; no phantom "downloading" state stuck in the UI.

#### 4. Hardware/Permission Denials & Resource Pressure
- **Scenario:** Device in `.critical` thermal state; memory headroom below the 200 MB floor; WhisperKit and MLX requests arriving close together.
- **System Behavior:** Timeout budget scales to 0.8× real-time under `.critical`; the existing `checkMemoryHeadroom()` gate still blocks LLM load with `.insufficientMemory`; background/memory-warning eviction plus WhisperKit's post-transcription unload guarantee the two models never coexist.
- **User Experience (UX):** Long transcriptions still succeed (slower); if memory is genuinely insufficient, the user sees the existing "model unavailable/insufficient memory" state rather than a crash.

## Requirements *(mandatory)*

### Functional Requirements

**Background downloads**
- **FR-001**: LLM model transfers MUST run on a system-managed background session (via swift-huggingface's background support, or an app-owned `URLSessionConfiguration.background` fallback if the client proves broken on-device) with a stable identifier, launch events enabled, and `waitsForConnectivity = true`, replacing `UIApplication.beginBackgroundTask` as the suspension-resilience mechanism.
- **FR-002**: Completed downloads MUST be integrated into the app-owned model directory atomically, and a partial snapshot directory MUST never be treated as installed (`findLLMModelDirectory` semantics preserved).
- **FR-003**: The app MUST reconnect the system background completion handler via the background-URLSession finish-events hook and the corresponding app-lifecycle callback.
- **FR-004**: Download progress callbacks MUST be throttled (≤ one UI update per 1% of progress) to avoid SwiftUI view-invalidation storms.
- **FR-005**: The LLM download path MUST migrate from swift-transformers `HubApi` to the official `swift-huggingface` client (user decision); downloads MUST resolve CDN binary URLs, never Git LFS pointer files. The Whisper path (`WhisperKit.download(useBackgroundSession: true)`) is already background-capable and unchanged.

**Byte-range resumption**
- **FR-006**: Interrupted downloads MUST resume via HTTP Range semantics (client resume support or manual `Range` header + persisted offset), accepting both HTTP 206 partial and HTTP 200 full responses.
- **FR-007**: Resume state MUST survive app termination (persisted atomically to disk) and MUST be captured on both explicit cancellation and failure.
- **FR-008**: Stale or invalid resume state (purged temp file, ETag mismatch, HTTP 412) MUST trigger a silent fallback to a clean full download.

**MLX memory lifecycle**
- **FR-009**: The MLX buffer allocator cache MUST be capped at 20 MB (`MLX.Memory.cacheLimit`) at service initialization.
- **FR-010**: `MLX.Memory.clearCache()` MUST be invoked after every inference completes.
- **FR-011**: The loaded model container MUST be evicted — releasing the container and clearing the cache — on ANY of: (a) ~3 minutes idle (cancellable, resetting timer), (b) `UIApplication.didReceiveMemoryWarningNotification`, (c) `UIApplication.didEnterBackgroundNotification`.

**Transcription reliability (batch — streaming descoped)**
- **FR-012**: The transcription timeout MUST be computed as `max(60s, audioDuration × thermalRTF + 30s)` where `thermalRTF` derives from `ProcessInfo.thermalState` (0.4 nominal/fair, 0.6 serious, 0.8 critical); the hardcoded 90s value MUST be removed from all call sites (`CheckInViewModel`, `RecordingDetailViewModel`).
- **FR-013**: Transcription MUST remain batch-oriented (real-time token/segment streaming is **out of scope** — user decision); the transcription API MAY keep its existing AsyncStream shape but partial segments are not required.
- **FR-014**: Each completed transcription MUST result in exactly one SwiftData save of the final cleaned transcript; intermediate status transitions SHOULD coalesce saves (at most one save per state transition), and no partial transcript text may be persisted.
- **FR-015**: WhisperKit preload during recording MUST be staggered by ~1.5 seconds after audio engine start and MUST be cancellable if recording stops within that window.

**Concurrency safety**
- **FR-016**: `MLXJournalService.isModelLoaded` MUST become a non-blocking `async` property; the `DispatchSemaphore` bridge MUST be deleted and all consumers (including tests) updated to `await` it.
- **FR-017**: All new download/transcription state shared across tasks MUST be protected by actor isolation or `OSAllocatedUnfairLock`, with zero strict-concurrency warnings.

### Key Entities

- **Model Download Task**: A single snapshot transfer — source repo, destination directory, resume state, throttled progress state.
- **Resume State**: Persisted record (temp-file reference, byte offset, ETag/validator) enabling byte-range continuation; lives in the caches directory and is disposable.
- **Transcription Result**: Final cleaned transcript text + audio duration; persisted exactly once per transcription.
- **Model Holder State**: Loaded/unloaded status, idle-eviction timer handle, and lifecycle observers (memory warning, background entry) for the MLX container.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A ~1.05 GB LLM download completes with the device locked for the entire transfer — 100% success across 3 consecutive device runs, vs. ~0% today beyond the 30s assertion window.
- **SC-002**: An interrupted download resumed after a network drop transfers ≤ 5% redundant bytes (measured via bytes-transferred logs), vs. up to 100% re-download today.
- **SC-003**: An 8-minute recording transcribes successfully under simulated `.serious` thermal throttling with zero false-positive timeouts; a genuinely stalled 30-second transcription still fails within its ~60–72s budget.
- **SC-004**: A full transcription (interactive and background-drain paths) produces exactly one SwiftData save per completion, verified by instrumenting `store.save()` call count; no partial transcript is ever persisted on the failure path.
- **SC-005**: Resident memory returns to within 100 MB of pre-load baseline immediately upon backgrounding (and within 3 minutes idle foreground) after the last LLM inference; zero Jetsam `per-process-limit` terminations in background-switch testing after journaling.
- **SC-006**: The project compiles with no strict-concurrency diagnostics on the modified files, and the full existing test suite passes.

## Out of Scope

- **Real-time transcription streaming / live transcript UI** — explicitly descoped by the user (2026-08-14): priority is lightweight, crash-free execution, not live partial text.
- New user-facing screens or progress UI redesigns (existing surfaces reused).
- Whisper model download path changes (already background-capable).
- Storage pre-flight checks and iCloud backup exclusion flags (excluded per the source report's stated scope).

## Assumptions

- Hugging Face's CDN continues to emit `Accept-Ranges: bytes` and stable `ETag` validators for model artifacts; if a future host does not, FR-008's fallback keeps behavior at today's file-level granularity.
- swift-huggingface supports (or can be configured for) delegate-driven background `URLSession` transfers on iOS; this MUST be validated on-device early in implementation, with the app-owned background session as the documented fallback (see Edge Case 2).
- The deployment target supports `OSAllocatedUnfairLock` (iOS 16+) and modern async `URLSession` patterns.
- Existing `ResilientModelDownload` stall-watchdog and retry policy remain the outer harness; this spec replaces the inner transfer mechanism, not the retry policy.
- The work lands on the current branch `feat/043-mlx-journal-service` (per explicit user instruction) rather than a new feature branch.
- The 1.5s preload stagger is a heuristic; device QA on A14/A15-class hardware confirms or tunes the value.
