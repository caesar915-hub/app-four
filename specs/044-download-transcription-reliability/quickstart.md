# Quickstart: Verifying Model Download & Transcription Reliability (044)

**Spec**: [`spec.md`](file:///Users/caesargrey/Projects/app-four-llama/specs/044-download-transcription-reliability/spec.md) | **Date**: 2026-08-14

Ordered verification for each success criterion. Device tests require a physical iPhone (background transfer and thermal behavior do not reproduce on the Simulator); unit-level gates run under `xcodebuild`. Run them in order — Step 1 gates the rest.

---

## 1. SC-001 — Locked-device LLM download (User Story 1)

**Gate: also validates the swift-huggingface background-session risk from research.md Decision 1. If this fails, implement the `BackgroundLLMDownloadService` fallback before proceeding.**

1. On a physical device, delete the LLM model (Settings → model row → Delete) so the download starts from zero.
2. Start the ~1.05 GB LLM download from Settings (or trigger `SquirlApp.startBackgroundModelDownloadIfNeeded` on fresh install).
3. Immediately lock the screen. Do not touch the device for 5+ minutes.
4. Unlock and open the app. Verify: the settings row shows the model installed; `AIModelServiceImpl.findLLMModelDirectory` resolves (log line or debugger); a journal summarization runs end-to-end.
5. Repeat 3 consecutive runs — 100% success required (SC-001). Also swipe-kill the app mid-download once and relaunch: the transfer must continue or resume, and the completion handler path (`AppDelegate.handleEventsForBackgroundURLSession`) must fire (log "background session events finished" or equivalent).

**Pass**: download completes with the device locked the whole time; no frozen progress; model loads and generates.

## 2. SC-002 — Airplane-mode resume (User Story 2)

1. Start the LLM download on device with the console attached (`Console.app` or `xcrun devicectl`, filter process `app-four` / `Squirl`).
2. At ~50% progress, enable Airplane Mode for 30 seconds, then disable it.
3. Verify in logs: resume state captured (offset recorded), the retry issues a Range resume and receives **HTTP 206** (or the client's equivalent resume telemetry), and bytes transferred after reconnect ≈ remaining bytes only (≤ 5% redundant — SC-002).
4. Let it complete; verify the snapshot passes `findLLMModelDirectory` validation.
5. Negative case: delete the staged temp file mid-pause (or corrupt `llm-resume-state.json` in the Caches dir via the device container), then restore network — the engine must silently fall back to a clean download with no error surfaced (FR-008).

**Pass**: resume from offset confirmed by 206 + byte counts; stale-state fallback is silent.

## 3. SC-003 — Thermal timeout fixtures (User Story 3)

Unit/simulator gate (deterministic — `TranscriptionTimeoutCalculator` takes thermal state as a parameter):

1. `xcodebuild test` filter for `TranscriptionTimeoutCalculatorTests`:
   - 300 s audio + `.nominal` → budget **150 s**; 480 s + `.critical` → **414 s**; 30 s audio → floor **60 s**; `.serious` → RTF 0.6.
2. Transcription-level fixture: with the calculator forced to `.serious`, transcribe the 6-minute fixture audio (test bundle fixture or a recorded clip) — no `.timeout` fires.
3. Stall case: force a stall (e.g. transcription seam that never yields) on a 30 s clip — the recording is marked `.failed` with a timeout error within its ~60-72 s budget, and remains retryable from the detail view.

**Pass**: boundary values exact; long fixture completes; stalled short clip fails fast and recovers.

## 4. SC-004 — Save-count instrumentation (User Story 4)

1. Run the new save-count suite (`SaveCountTests` or as named in tasks): a save-counting `RecordingStore` seam wraps a full transcription.
2. Verify **exactly one** `store.save()` on the completion transition in the interactive path (`CheckInViewModel.transcribeInBackground`) and one per recording in the drain path (`PendingTranscriptionServiceImpl`).
3. Failure case: force a transcription error → exactly one save marking `.failed`, and `fullTranscriptText` contains only the error message (no partial transcript).
4. Manual spot-check on device: console log shows one "Transcription completed" per recording, and no per-segment saves (the old `writeSegment`/segment-loop saves are gone from `CheckInViewModel.swift:377-379`, `RecordingDetailViewModel.swift:114-121`, `PendingTranscriptionServiceImpl.swift:107-115`).

**Pass**: 1 save per transcription completion, both paths; failure path persists no partial text.

## 5. SC-005 — Memory gauge eviction (User Story 5)

1. On device with the Memory Gauge (Xcode debug navigator) attached, run a check-in with summarization; note the ~1.2-1.4 GB footprint increase after the LLM loads.
2. **Background eviction**: background the app immediately after summarization → footprint drops to within 100 MB of pre-load baseline at suspension.
3. **Idle eviction**: stay foregrounded after summarization → footprint drops to baseline within ~3 minutes of the last inference.
4. **Memory warning**: with the model loaded, trigger a simulated memory warning (Simulator: Debug → Simulate Memory Warning; device: memory-pressure tool) → immediate eviction.
5. **Timer reset**: issue a second inference before the 3-minute timer fires → no reload (log shows model reused), timer re-armed.
6. **Cache cap**: during decoding, MLX buffer cache stays ≤ 20 MB (`MLX.Memory.cacheLimit` — verify via gauge plateau or a debug assertion in DEBUG builds).
7. Repeat a background-switch loop 10× after journaling: zero Jetsam `per-process-limit` terminations in the device log (SC-005).

**Pass**: all four eviction triggers verified on the gauge; cache capped; no background OOMs.

## 6. SC-006 — Strict-concurrency build + full test suite (User Stories 6, 7 gate)

1. Build with strict concurrency: `xcodebuild -project app-four.xcodeproj -scheme app-four -destination 'platform=iOS Simulator,name=iPhone 17' build` — zero strict-concurrency diagnostics on the modified files (spec SC-006).
2. Static check: `DispatchSemaphore` no longer appears in `MLXJournalService.swift`; `isModelLoaded` is `get async`; `MLXJournalServiceTests` awaits it (`modelNotLoadedAtInit`, `coldStartDoesNotLoadModel`).
3. Full suite: `xcodebuild test ... ` (same scheme/destination, or the `app-four.xctestplan`) — everything green, including the new calculator/resume-store/eviction/save-count suites.
4. US6 spot-check on an A14/A15-class device: start/stop recordings of varying lengths — no CoreAudio underruns at capture start; logs show preload beginning ~1.5 s after record start; stopping within 1.5 s cancels the preload (no "Loading WhisperKit model" log).

**Pass**: clean build, no semaphore, full suite green, glitch-free recording start.

---

### Fixture / tooling notes

- Thermal states for Step 3 are injected via the calculator's parameter — no device throttling needed for the unit gate; device-level `.serious` validation is covered opportunistically during Step 5 runs.
- Byte counts for Step 2 come from the download service's own logs (counts/offsets only — Principle VI).
- The 6-minute fixture audio lives with the transcription tests (or is recorded on device once and copied into the test bundle); exact path finalized in `/speckit-tasks`.
