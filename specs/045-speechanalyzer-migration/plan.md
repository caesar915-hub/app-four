# Implementation Plan: Adopt SpeechAnalyzer/SpeechTranscriber, fall back to DictationTranscriber, remove WhisperKit

**Branch**: `feat/speech-transcriber-probe` (feature 045) | **Date**: 2026-09-06 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/045-speechanalyzer-migration/spec.md` (specified + clarified)

## Feature Definition & Scope

Replace the app's on-device transcription engine. Today, transcription is WhisperKit running `openai_whisper-small` (~500 MB, downloaded and app-managed) behind the `TranscriptionService` protocol; the runtime path is **record-to-file (`AVAudioRecorder`) → transcribe file later**, with a `PendingTranscriptionService` queue that defers transcription until the model is present. This feature makes **Apple's iOS 26 `SpeechAnalyzer`/`SpeechTranscriber`** the primary engine, adds **`DictationTranscriber`** as an automatic fallback for hardware/locales `SpeechTranscriber` does not support, converts capture to **live/streaming** (partial results while speaking), and **removes WhisperKit** (dependency, model-download subsystem, `AIModelType.whisper`) **and the dormant `SFSpeechRecognizer` path** (`SpeechTranscriptionService`) entirely.

Locked scope (from spec Clarifications, 2026-09-06):
- Fallback ladder is exactly `SpeechTranscriber` → `DictationTranscriber` (no third tier).
- **Live/streaming** capture with volatile→final partial results.
- **No** transcription-layer vocabulary biasing (domain handling stays in extraction).
- **No** existing-user data migration; historical audio is not re-transcribed.
- The extraction seam (`SummarizationService`/`MLXJournalService`) is untouched — it consumes a `String` and is engine-agnostic.

Requirements carried from the spec: FR-001…FR-020, SC-001…SC-007. The binding technical constraints: on-device only (Principle VI); iOS 26.0 deployment floor (so no legacy OS path is needed); model assets are system-managed via `AssetInventory` (0 MB app cost); the transcription capability stays behind a `Services/` protocol (Principle VIII) with exactly one composition-root binding to swap.

### Architectural approach — additive first, destructive last

Because this is a large, multi-file migration on an app whose transcription is currently load-bearing, and because device QA cannot be automated, the plan sequences so **every committed checkpoint builds and passes tests**:

1. **Additive** — introduce the SpeechAnalyzer engine + capability/locale logic + a live-streaming capture path **alongside** WhisperKit, fully test-covered, without changing the composition-root binding.
2. **Switchover** — flip the single `AppDependencies` binding to the SpeechAnalyzer engine; wire live streaming into the capture flow; reconcile the pending queue.
3. **Destructive (last)** — remove WhisperKit (SPM dependency, `WhisperKitTranscriptionService`, `AIModelType.whisper`, download/onboarding/Settings surfaces), remove the `SFSpeechRecognizer` `SpeechTranscriptionService`, and drop `NSSpeechRecognitionUsageDescription`.

This ordering means an interrupted run still leaves a buildable app (WhisperKit intact until its replacement is green + wired).

## Technical Context

### 1. Language & Runtime Environment
Swift 6 with strict concurrency, targeting **iOS 26.0** (confirmed `IPHONEOS_DEPLOYMENT_TARGET = 26.0` across all four build configs). This is the decisive enabler: the entire `SpeechAnalyzer` stack (`SpeechAnalyzer`, `SpeechTranscriber`, `DictationTranscriber`, `AssetInventory`, `AnalyzerInput`) is iOS 26.0+, so there is **no back-deployment requirement** and WhisperKit can be removed outright rather than retained as a pre-26 floor. All new types are `Sendable`; the transcription engine is an `actor` (as WhisperKit's is today) and view-models remain `@MainActor @Observable`. The on-device probe (`Probes/SpeechTranscriberProbe`) has already compiled and run this exact API against the iOS 26.5/26.6 device SDK, so the API surface is verified to link.

### 2. Core Dependencies & Frameworks
Adds Apple's first-party **`Speech`** framework (no SPM dependency — it ships with the OS) and **`AVFoundation`** (`AVAudioEngine`, `AVAudioConverter`) for the live capture tap. Removes the third-party **`argmaxinc/WhisperKit`** SPM package (declared in `app-four.xcodeproj/project.pbxproj` + `Package.resolved`). MLX/`swift-transformers`/`swift-huggingface` remain (they power the untouched extraction pipeline). `Speech` is chosen over `SFSpeechRecognizer` because it is the documented long-form/streaming on-device engine (the current WhisperKit rationale), and over keeping WhisperKit because the system-managed model removes the ~500 MB app-owned download (the failure surface specs 041/044 exist to harden). `DictationTranscriber` (same framework) covers devices/locales where `SpeechTranscriber.isAvailable` is false.

### 3. State Management & Data Flow
UI → `CheckInViewModel` (`@MainActor @Observable`) → `TranscriptionService` (protocol, `actor` impl) → results stream → `ProcessingViewModel` → `SummarizationService`. Today the flow is sequential (record whole file, then transcribe). The target flow is **concurrent**: `AudioRecordingServiceImpl` runs an `AVAudioEngine` tap that fans out to (a) an `AVAudioFile` writer (preserving the stored `Recording` audio for playback/export) and (b) an `AsyncStream<AnalyzerInput>` feeding `SpeechAnalyzer`; volatile results update live UI, final results commit. The **pending-transcription queue is preserved** for the "assets not yet installed at capture time" case: such recordings are saved as `.pendingTranscription` and transcribed **file-based** (`analyzeSequence(from:)`) when `AssetInventory` reports the model installed — the same `SpeechTranscriber` module supports both live and file input. Potential bottleneck: the `SpeechAnalyzer` concurrent-analysis limit (`SFSpeechError.insufficientResources`) if transcription overlaps the MLX extraction pass — handled as back-pressure (serialize), never `ignoresResourceLimits`.

### 4. Storage & Persistence Strategy
No SwiftData schema change. The `Recording` model, `AudioFileStorageService`, and transcript persistence are unchanged; the audio file is still written to disk (now via the engine tap rather than `AVAudioRecorder`, same on-disk artifact contract). Transcripts remain plain text on the existing model. Model assets move **out of app storage** entirely — `AssetInventory` manages them in shared system storage, so `ModelConstants.whisperDownloadBase` (`Library/whisperkit`) and the ~600 MB free-space precheck are removed for transcription (the LLM/MLX download path is untouched). No migration: `AIModelType.whisper` is removed from the enum, which requires updating its (few) switch/usage sites; historical recordings keep their stored transcripts.

### 5. Performance & Constraints
App **download/disk footprint drops by ~484–500 MB** (the removed Whisper model; SC-001). Runtime memory: the in-process Whisper CoreML buffers (loaded/unloaded per run today) are gone; `SpeechAnalyzer` runs against the system model. This changes the "Peak Shaving" memory lifecycle (Principle VII currently says "Whisper unloads before Llama loads") — after migration only the MLX/Llama model loads in-process, so the constitution's memory language must be amended. Latency: live streaming shows first partial results in well under the current record-then-transcribe wait; the `.progressiveTranscription` preset is chosen for low-latency UI. Hard constraints unchanged: everything on-device; logs are counts/durations only (Principle VI).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.* Constitution `.specify/memory/constitution.md` — **an amendment is part of this plan** (see Complexity Tracking + Governance below); the checks reflect the post-amendment state.

- [x] **I. SwiftUI-First** — No new UIKit. Live-transcription/permission/asset states surface in existing SwiftUI views; any new UI state gets an HTML mockup first before SwiftUI. PASS.
- [x] **II. Test-Build-Ship** — Every checkpoint builds + runs the full `app-fourTests` suite (Simulator this session; device QA by owner before merge). PASS.
- [x] **III. Correctness Over Speed** — Additive-first/destructive-last avoids half-migrated states; WhisperKit code is fully removed (no shims/dead code) in the final phase. PASS.
- [x] **IV. Minimal Surface** — Reuses the existing `TranscriptionService`/`PendingTranscriptionService`/`AudioRecordingService` seams; adds only the engine, a capability resolver, and the streaming entry point the live-UX requirement demands. No speculative abstraction, no third fallback tier. PASS.
- [x] **V. Solo Git Discipline** — One feature branch (`feat/speech-transcriber-probe`), one revertable migration, `/code-review` before merge, `main` stays releasable. PASS.
- [x] **VI. On-Device Privacy** — `SpeechAnalyzer` is on-device; no audio/transcript leaves the device; diagnostics stay counts/durations only. Removing WhisperKit removes no privacy guarantee. PASS.
- [x] **VII. On-Device LLM Extraction** — Extraction (`MLXJournalService`, Llama/Qwen) is untouched; the transcription→summarization `String` seam is unchanged. The Principle's *transcription-engine* clause (Whisper) is amended to name SpeechAnalyzer; the memory-lifecycle clause is updated (no in-process Whisper to unload). PASS (post-amendment).
- [x] **VIII. Service-Oriented Architecture** — Capability stays behind `TranscriptionService` in `Services/`, injected via `AppDependencies`→`AppServices`→`@Environment`; VMs stay `@MainActor @Observable`; capture/transcription run off-main. PASS.
- [x] **IX. Pre-Release Data Posture** — No schema change; no new `@Attribute(.unique)` or required attribute; CloudKit-compatibility preserved. PASS.
- [x] **X. Test-First Development** — All new logic (capability resolver, engine result-mapping, selector, pending-queue reconciliation) is built RED→GREEN with Swift Testing; SwiftUI views build+run only. Tests never hit the live Speech SDK (Simulator returns `isAvailable == false`) — pure logic + fakes. PASS.
- [x] **XI. Architectural Exhaustiveness** — This plan + `research.md`/`data-model.md`/`contracts/` define the engine surface, capability ladder, streaming data flow, pending-queue reconciliation, error taxonomy, and every removal site. PASS.

## Project Structure

### Documentation (this feature)
```text
specs/045-speechanalyzer-migration/
├── spec.md              # what & why (done: specify + clarify)
├── plan.md              # this file
├── research.md          # Phase 0: decisions + rationale
├── data-model.md        # Phase 1: types/state (no SwiftData change)
├── quickstart.md        # Phase 1: how to build/test/verify
├── contracts/
│   └── transcription-service.md   # the protocol surface + engine contracts
├── convergence.md       # (converge step)
├── tasks.md             # (/speckit-tasks)
└── RUN_SUMMARY.md       # (final report)
```

### Source Code (repository root — real paths)
```text
app-four/
├── Services/
│   ├── Protocols.swift                      # MODIFY: extend TranscriptionService with a live-streaming entry point + volatile results
│   ├── Speech/
│   │   ├── SpeechAnalyzerCapability.swift    # NEW: availability + locale resolution (pure, testable)
│   │   ├── SpeechAnalyzerTranscriptionService.swift  # NEW: actor — file + live, SpeechTranscriber/Dictation
│   │   └── SpeechTranscriptionService.swift  # DELETE (SFSpeechRecognizer path)
│   ├── WhisperKit/WhisperKitTranscriptionService.swift  # DELETE (last)
│   ├── AIModelServiceImpl.swift              # MODIFY: drop .whisper download/integrity; keep LLM
│   ├── PendingTranscriptionServiceImpl.swift # MODIFY: readiness via AssetInventory, file-based deferred transcription
│   └── Audio/AudioRecordingServiceImpl.swift # MODIFY: AVAudioEngine dual-sink (file + analyzer stream)
├── Models/AppEnums.swift                     # MODIFY: remove AIModelType.whisper
├── Utils/Constants.swift                     # MODIFY: remove whisperDownloadBase / whisper free-space
├── Store/AppDependencies.swift               # MODIFY: bind SpeechAnalyzerTranscriptionService (the swap)
├── ViewModels/CheckInViewModel.swift         # MODIFY: live streaming; drop whisper preload comment/logic
├── ViewModels/RecordingDetailViewModel.swift # MODIFY: retry via new engine (protocol unchanged mostly)
├── Views/Settings/YourDataSection.swift      # MODIFY: remove Whisper download row/ack; asset state if any
├── App/SquirlApp.swift                       # MODIFY: drop .whisper background download; keep queue drain
└── (Onboarding views keyed on .whisper)      # MODIFY/REMOVE: model-download step (assets are system-managed)

app-fourTests/
├── Services/SpeechAnalyzerCapabilityTests.swift            # NEW
├── Services/SpeechAnalyzerTranscriptionServiceTests.swift  # NEW (logic/mapping via fakes)
├── Services/PendingTranscriptionServiceTests.swift         # MODIFY: asset-readiness reconciliation
└── (WhisperModelIntegrityTests / AIModelServiceImplTests)  # MODIFY/REMOVE whisper cases

app-four.xcodeproj/project.pbxproj                # MODIFY (last): remove WhisperKit package refs + NSSpeechRecognitionUsageDescription
WhisperCLI/                                        # DECISION: remove (separate SPM tool) or leave out of app target — see research.md
```

**Structure Decision**: No new module or target. The migration lives inside the existing `app-four` app target and `app-fourTests`, reusing the `Services/`/DI/`@Environment` architecture. New Speech code is grouped under `app-four/Services/Speech/`.

### File Manifest & Responsibilities

| File Path | Responsibility | Key Structs / Functions / Protocols |
|-----------|----------------|-------------------------------------|
| `app-four/Services/Speech/SpeechAnalyzerCapability.swift` | Pure, testable capability + locale resolution and engine selection (the fallback ladder). No I/O. | `enum TranscriptionEngineChoice { case speechTranscriber(Locale); case dictation(Locale); case unavailable }`; `struct SpeechAnalyzerCapability { static func resolve(current: Locale, isAvailable: Bool, speechSupported: [Locale], dictationSupported: [Locale]) -> TranscriptionEngineChoice }` — uses `supportedLocale(equivalentTo:)` semantics, never `contains(.current)` (FR-004). |
| `app-four/Services/Speech/SpeechAnalyzerTranscriptionService.swift` | `actor` conforming to `TranscriptionService`; builds a `SpeechTranscriber`/`DictationTranscriber`, installs assets via `AssetInventory`, runs file (`analyzeSequence(from:)`) and live (`AnalyzerInput` stream) transcription, maps results→`TranscriptionSegmentDTO`, handles finalize/cancel + error taxonomy. | `func transcribe(audioURL:)`, live entry point (see contract), `cancelTranscription()`, `loadModel()` (asset install); private result→DTO mapping; `SFSpeechError` mapping to `ModelDownloadFailure`/error DTO. |
| `app-four/Services/Protocols.swift` | Extend the boundary for live streaming + volatile results while keeping the file-based method for the deferred/pending path. | Add e.g. `func transcribeLive(_ input: AsyncStream<AVAudioPCMBuffer>) -> AsyncStream<TranscriptionSegmentDTO>` (exact shape in contracts); DTO gains no fields (volatile handled by existing `isFinal`). |
| `app-four/Services/Audio/AudioRecordingServiceImpl.swift` | Replace `AVAudioRecorder` with `AVAudioEngine` tap fanning out to an `AVAudioFile` (stored audio) and a buffer stream (analyzer). Preserve pause/resume/cancel/interruption/max-duration + `audioLevelStream`. | `startRecording()`, `stopRecording()`, tap → `AVAudioConverter` → `AnalyzerInput`; unchanged protocol signature. |
| `app-four/Services/PendingTranscriptionServiceImpl.swift` | Readiness now = `AssetInventory` reports installed for the selected module; deferred transcription runs file-based. | `drainIfModelReady()`. |
| `app-four/Store/AppDependencies.swift` | The single swap: bind `SpeechAnalyzerTranscriptionService`. | `transcriptionService = sharedSpeechAnalyzerService`. |
| `app-four/Models/AppEnums.swift` | Remove `AIModelType.whisper`; keep `.llm`/`.llama`. | `enum AIModelType`. |
| `app-four/Services/AIModelServiceImpl.swift` | Remove Whisper download/integrity/space logic; keep the LLM model path. | drop `downloadWhisperModel`, `findWhisperModelFolder`, whisper metadata. |
| `app-four.xcodeproj/project.pbxproj` | Remove the WhisperKit SPM package product/refs and `NSSpeechRecognitionUsageDescription`; keep `NSMicrophoneUsageDescription`. | package refs 12/82/178/221/833-838. |
| `app-fourTests/Services/SpeechAnalyzerCapabilityTests.swift` | RED-first tests for the ladder + locale resolution. | `@Test` cases: available+supported→speechTranscriber; unavailable→dictation; unsupported locale→equivalent; none→unavailable. |
| `app-fourTests/Services/SpeechAnalyzerTranscriptionServiceTests.swift` | RED-first tests for result→DTO mapping, volatile/final handling, error mapping, using injected fakes (no live SDK). | `@Test` cases via a seam that feeds synthetic results. |

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Extend `TranscriptionService` with a live-streaming entry point (adds surface beyond the current single file-based method) | FR-018 (clarified) requires live partial results while speaking, which the file-based `transcribe(audioURL:)` cannot express | Keeping only the file-based method would make live UX impossible; a wholly separate protocol would fragment the seam and break the pending-queue reuse |
| `AVAudioRecorder` → `AVAudioEngine` rework in `AudioRecordingServiceImpl` | Live streaming needs raw buffers tapped in real time and converted to the analyzer format; `AVAudioRecorder` only writes a file | Recording to file then transcribing (current design) cannot show partial results; rejected by the clarified live-streaming requirement |
| Constitution amendment (Technology Stack + Principle VII) | The constitution names WhisperKit as THE transcription engine and encodes "Whisper unloads before Llama"; removing WhisperKit contradicts both | Not amending would leave the constitution self-contradictory after merge; a silent divergence violates Governance |

## Governance / constitution amendment

Removing WhisperKit requires amending `.specify/memory/constitution.md` (MINOR bump **2.2.0 → 2.3.0**): update the **Technology Stack** on-device-ML line to name `SpeechAnalyzer`/`SpeechTranscriber` (+ `DictationTranscriber` fallback) as the transcription engine instead of WhisperKit/Whisper Small; update **Principle VII**'s memory-lifecycle sentence (no in-process Whisper to unload before Llama). Add a SYNC IMPACT REPORT. This is a MINOR change (no principle removed/redefined) and is applied as part of Phase A so the plan's Constitution Check reflects the amended state.

## Phase 0 → research.md · Phase 1 → data-model.md + contracts/ + quickstart.md
See the sibling documents. Constitution re-check after Phase 1: unchanged — PASS.
