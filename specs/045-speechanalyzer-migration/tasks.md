# Tasks: Adopt SpeechAnalyzer, fall back to DictationTranscriber, remove WhisperKit (Spec 045)

**Input**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/transcription-service.md`

**Tests**: Test-first is MANDATORY for logic (Principle X) — RED (write + run + confirm fail) → GREEN → refactor. Swift Testing (`@Test`/`#expect`). SwiftUI views exempt (build + on-device run). No test may hit the live Speech SDK (Simulator returns `isAvailable == false`).

**Sequencing**: **additive-first, destructive-last** — every completed phase leaves the app building + green, with WhisperKit intact until its replacement is wired and verified.

**Build/test gate (every code task)**:
`xcodebuild test -project app-four.xcodeproj -scheme app-four -destination 'platform=iOS Simulator,id=C49AC93D-B5BE-4CB2-A759-AB8B6731587A' -derivedDataPath /tmp/af-dd -skipMacroValidation CODE_SIGNING_ALLOWED=NO` — look for "Test run with N tests … passed".

**Session scope note**: Phase 2 (Foundational, additive) is executable + verifiable this autonomous session. Phases 3–5 change the live audio pipeline, flip the DI binding, and remove WhisperKit — they require on-device QA (owner) and are staged here for a follow-up session (device was unavailable during this run).

---

## Phase 1: Setup

- [x] `T001` **Confirm build/test gate on iOS 26 Simulator**
  - **File:** n/a (baseline)
  - **Action:** Build + run `app-fourTests` on the iPhone 17 Pro simulator to establish a green baseline before changes.
  - **Validation:** "Test run with 544 tests … passed" (achieved: 544/544).

---

## Phase 2: Foundational — additive SpeechAnalyzer engine (no behavior change) 🎯 THIS SESSION

**Purpose**: Introduce the new engine + capability logic behind the existing `TranscriptionService`, fully test-covered, WITHOUT touching WhisperKit, the audio pipeline, or the DI binding. Nothing is wired; runtime behavior is identical.

- [ ] `T002` `[US2]` **RED: capability/locale ladder tests**
  - **File:** `app-fourTests/Services/SpeechAnalyzerCapabilityTests.swift`
  - **Action:** Write Swift Testing cases for `SpeechAnalyzerCapability.resolve(isAvailable:resolvedSpeechLocale:resolvedDictationLocale:) -> TranscriptionEngineChoice`: (a) available + speech locale → `.speechTranscriber`; (b) unavailable + dictation locale → `.dictation`; (c) available but only dictation locale resolves → `.dictation`; (d) neither → `.unavailable`. Run; confirm FAIL (type doesn't exist yet).
  - **Validation:** Suite fails to compile/RED before T003.
- [ ] `T003` `[US2]` **GREEN: `SpeechAnalyzerCapability` + `TranscriptionEngineChoice`**
  - **File:** `app-four/Services/Speech/SpeechAnalyzerCapability.swift`
  - **Action:** Add `enum TranscriptionEngineChoice: Sendable` and `struct SpeechAnalyzerCapability` with the pure `resolve(...)` branch logic (ladder from research §1–2). No SDK calls in the struct — the async locale resolution is done by the caller and passed in.
  - **Dependencies:** T002
  - **Validation:** T002 turns GREEN; full suite still passes.
- [ ] `T004` `[US1]` **RED: result→DTO mapping + error mapping tests**
  - **File:** `app-fourTests/Services/SpeechAnalyzerTranscriptionServiceTests.swift`
  - **Action:** Test a pure/`nonisolated` mapping function `mapResult(text:range:isFinal:) -> TranscriptionSegmentDTO` (and an error→`isError` DTO / `SFSpeechError` mapping) with synthetic inputs (no `SpeechAnalyzer`). Cover volatile (`isFinal=false`) vs final, start/end times from the range, empty text → "no speech". Run; confirm RED.
  - **Validation:** Fails before T005.
- [ ] `T005` `[US1]` **GREEN: `SpeechAnalyzerTranscriptionService` (file-based, existing protocol)**
  - **File:** `app-four/Services/Speech/SpeechAnalyzerTranscriptionService.swift`
  - **Action:** Add an `actor` conforming to the CURRENT `TranscriptionService` (file-based `transcribe(audioURL:)` via `SpeechAnalyzer.analyzeSequence(from:)`, `cancelTranscription()`, `loadModel()` = `AssetInventory.assetInstallationRequest`+`downloadAndInstall`). Engine selection via `SpeechAnalyzerCapability` + async `supportedLocale(equivalentTo:)`. Factor the DTO mapping (T004) as a `nonisolated` function. Compiles against the Speech SDK (verified by the probe); NOT wired into DI.
  - **Dependencies:** T003, T004
  - **Validation:** T004 GREEN; full suite passes; app builds (additive file compiles).

**Checkpoint**: New engine + capability exist, tested, compiling. WhisperKit still the live engine; zero behavior change. Commit.

---

## Phase 3: Switchover — SpeechAnalyzer is the live engine (Priority: P1) — file-based switchover DONE; live streaming pending

**Done (file-based switchover, on-device QA-able):** DI now binds `SpeechAnalyzerTranscriptionService`; readiness moved to `TranscriptionService.isModelReady()`; the whisper "download model" intercept removed (SpeechAnalyzer asset self-installs); pending decision + `PendingTranscriptionServiceImpl` gate reconciled to `isModelReady()`. Tests green 556/556. The real check-in flow records → transcribes via SpeechAnalyzer (record-then-transcribe; live partial text is the T007–T010 enhancement).
**Dormant (Phase-5 cleanup):** the whisper download-prompt UI (`showModelDownloadPrompt`, `startRecordingWith(out)Download`, the CheckInView alerts) + `SettingsViewModel.whisperModelInstalled` remain but never fire.

**Goal**: Live/streaming capture with volatile→final partial results, primary engine = SpeechTranscriber.

### Tests (RED, MANDATORY)
- [ ] `T006` `[US1]` Live-stream reconciliation tests (volatile replace-in-place, final commit) against a fake stream in `SpeechAnalyzerTranscriptionServiceTests`.

### Implementation
- [ ] `T007` `[US1]` **Extend `TranscriptionService` with a live entry point** — `Services/Protocols.swift`; update ALL conformers (`WhisperKit…`, `Mock…`, `SpeechTranscription…` until removed) + test doubles so the target still builds. (Touches many files — reason it's staged.)
- [ ] `T008` `[US1]` **`AVAudioEngine` dual-sink** in `Services/Audio/AudioRecordingServiceImpl.swift` — tap → `AVAudioFile` (stored audio) + converted `AnalyzerInput` stream (`AVAudioConverter` to `bestAvailableAudioFormat`); preserve pause/resume/cancel/interruption/max-duration/`audioLevelStream`.
- [ ] `T009` `[US1]` **Live transcription in the engine** — implement `transcribeLive` (`.progressiveTranscription`, consume `results` in a task, finalize correctly).
- [ ] `T010` `[US1]` **Wire live path in `CheckInViewModel`** — concurrent record+transcribe, live UI text.
- [x] `T011` `[US1]` **Flip the DI binding** — DONE: `Store/AppDependencies.swift` binds `SpeechAnalyzerTranscriptionService`.

**Checkpoint**: Primary path live on device; owner QA.

---

## Phase 4: User Story 2 — fallback + pending queue (Priority: P2) — partially done (additive)

- [x] `T012` `[US2]` **DictationTranscriber path in the engine** (used when capability = `.dictation`). DONE additively: `SpeechAnalyzerTranscriptionService` now resolves both engines (`resolveChoice`) and runs `DictationTranscriber(locale:preset:.longDictation)` for the `.dictation` branch. Not yet exercised at runtime (engine unwired until the DI swap, T011).
- [x] `T013` `[US2]` **Pending-queue reconciliation** — DONE: `PendingTranscriptionServiceImpl.drainIfModelReady()` now attempts `loadModel()` (asset install) then gates on `transcriptionService.isModelReady()`; the `.whisper` `localPath` gates are gone; `aiModelService` dependency removed; `PendingTranscriptionServiceTests` updated to drive readiness via the transcription mock. (Readiness decision from `SpeechAnalyzerCapability.isModelInstalled`, unit-tested.)
- [ ] `T014` `[US2]` Unavailable-engine UX (persist audio, surface state; edge cases from spec) + MIN-2 (`SFSpeechError.Code` → clearer copy). ⏭ DEFERRED (ties to wiring).

**Checkpoint**: Fallback + deferred transcription verified.

---

## Phase 5: User Story 3 — remove WhisperKit + SFSpeech (Priority: P3) ⏭ DEFERRED (destructive-last)

- [ ] `T015` `[US3]` Remove `Services/Speech/SpeechTranscriptionService.swift` (SFSpeech) + `NSSpeechRecognitionUsageDescription` build setting.
- [ ] `T016` `[US3]` Remove `AIModelType.whisper` (`Models/AppEnums.swift`) + fix all exhaustive switches.
- [ ] `T017` `[US3]` Strip Whisper from `AIModelServiceImpl` (download/integrity/space) + `ModelConstants.whisperDownloadBase` (`Utils/Constants.swift`) + `.whisper` background download in `App/SquirlApp.swift`.
- [ ] `T018` `[US3]` Remove Whisper download/onboarding/Settings UI + `YourDataSection` acknowledgement.
- [ ] `T019` `[US3]` Delete `Services/WhisperKit/WhisperKitTranscriptionService.swift` and remove the `argmaxinc/WhisperKit` SPM package from `app-four.xcodeproj/project.pbxproj` + `Package.resolved`.
- [ ] `T020` `[US3]` Update/trim `WhisperModelIntegrityTests` + `AIModelServiceImplTests` (whisper cases). Decide `WhisperCLI/` (separate package) fate.
- [ ] `T021` `[US3]` **SC-006 gate:** `grep -rn WhisperKit app-four app-four.xcodeproj/project.pbxproj` → 0.

**Checkpoint**: WhisperKit fully gone; app builds + tests green; footprint down ~500 MB.

---

## Phase 6: Polish
- [ ] `T022` Regenerate `docs/WORKLOG.md` (if `scripts/worklog.sh` exists); update BACKLOG stage.
- [ ] `T023` Owner device-QA per `quickstart.md`; then PR merge decision.

---

## Dependencies & Execution Order
- Phase 2 (additive) has no dependency on 3–5 and is safe/verifiable now.
- Phase 3 requires T007 (protocol extension) before T008–T011.
- Phase 5 (removal) MUST come last — only after the SpeechAnalyzer path is live + verified, so `main`/branch always builds.
- Within each story: tests RED before implementation; models/pure logic before services; services before wiring; wiring before removal.
