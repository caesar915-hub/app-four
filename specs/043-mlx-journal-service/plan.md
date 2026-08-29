# Implementation Plan: MLXJournalService — On-Device LLM Extraction

**Branch**: `043-mlx-journal-service` | **Date**: 2026-08-11 | **Spec**: [`spec.md`](file:///Users/caesargrey/Projects/app-four-llama/specs/043-mlx-journal-service/spec.md)

**Input**: Feature specification from `/specs/043-mlx-journal-service/spec.md`

**Source FSD**: [`04b-1-mlx-journal-service.md`](file:///Users/caesargrey/Projects/app-four-llama/docs/llama_migration/04b-1-mlx-journal-service.md) (Part 1 of 3)

## Feature Definition & Scope

This feature replaces the legacy deterministic extraction pipeline (`NLSummarizationService` → `NLNoteExtractor` → `CueMatcher`) with a new `MLXJournalService` that performs structured ADHD journal signal extraction using Llama 3.2 1B (4-bit quantised) via MLX-Swift, running 100% on-device.

> **Codebase reality check**: The research subagent verified all file paths and line numbers below against the actual codebase on 2026-08-11. Key differences from the FSD's abstract description: `SummarizationService` and `SummaryResult` live in [`Protocols.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/Protocols.swift) (not separate files), the DI binding is a `static let` in [`AppDependencies.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Store/AppDependencies.swift) (line 27, in `Store/` not `Services/`), `LexiconLoader` is in [`LexiconData.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/NoteExtraction/LexiconData.swift) (lines 119-130), and provenance tagging uses `TagSource` enum in [`RecordingTag.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Models/RecordingTag.swift) (line 4).

**What is being built**: A new `MLXJournalService` class that conforms to the existing [`SummarizationService`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/Protocols.swift#L207-L209) protocol (lines 207-209 of `Protocols.swift`), implementing `func summarize(rawTranscription: String) async throws -> SummaryResult`. The service loads the curated ADHD lexicon (718 entries, 27 categories) via [`LexiconLoader.loadBundled()`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/NoteExtraction/LexiconData.swift#L119-L130) (in `LexiconData.swift`, lines 119-130), constructs a lexicon-informed system prompt with exact signal labels from [`Levels.swift`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift), invokes MLX-Swift inference on a background actor, and returns a raw JSON string to the validation layer (Part 2, out of scope here).

**What is NOT being built**: JSON parsing/validation (Part 2), persistence via `Recording.applySummary()` / `setMedicationEvents()` (Part 2), `ExtractionReviewView` (Part 3), any UI changes beyond the existing "Synthesizing your journal…" shimmer (already managed by `ProcessingViewModel`).

**Integration boundary**: The [`SummarizationService`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/Protocols.swift#L207-L209) protocol is the only touch-point. Downstream consumers — [`ProcessingViewModel`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/ProcessingViewModel.swift) (lines 72-73: `summarizationService.summarize(rawTranscription: rawText)`), [`PendingTranscriptionServiceImpl`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/PendingTranscriptionServiceImpl.swift) (lines 74-75: `summarizationService.summarize(rawTranscription: text)`), `Recording`, and `ExtractionReviewView` — are completely unaware of the extraction backend and require **zero code changes**.

**The swap**: In [`AppDependencies.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Store/AppDependencies.swift#L27) line 27, the static binding changes from `NLSummarizationService()` to `MLXJournalService()`. This single line is the entirety of the DI wiring change. `AppServices` (also in `Store/`) receives the service via its initializer and passes it through to ViewModels — no changes needed there.

### Scope boundaries

| In scope (Part 1) | Out of scope |
|---|---|
| `MLXJournalService` class (new) | JSON parsing & validation (Part 2) |
| `SummarizationService` conformance | Persistence via `Recording.applySummary()` (Part 2) |
| Lexicon loading for prompt construction | `ExtractionReviewView` / `ExtractionReviewViewModel` (Part 3) |
| System prompt construction (labels + vocabulary + few-shot) | WhisperKit transcription (04a) |
| MLX-Swift model loading & inference | Audio capture (03) |
| Memory lifecycle (peak shaving, lazy load, abort) | Library rendering (05), Insights (06), Medications (07) |
| `RecordingTag.llm` case addition | |

---

## Technical Context

### 1. Language & Runtime Environment

Swift 6+ with strict concurrency enabled. The `MLXJournalService` will be a `Sendable` type (as required by the `SummarizationService` protocol which inherits `Sendable`). MLX-Swift inference runs off the main actor on a background queue/actor to avoid blocking the UI. The target deployment is iOS 26+ on A14 Bionic and above (iPhone 12 Pro minimum — 6 GB RAM).

The `increased-memory-limit` entitlement (`com.apple.developer.kernel.increased-memory-limit`) is assumed to already be present in the app's entitlements file, as documented in the FSD.

### 2. Core Dependencies & Frameworks

| Dependency | Role | Integration |
|---|---|---|
| **MLX-Swift** ([GitHub](https://github.com/ml-explore/mlx-swift)) | On-device inference framework for Apple Silicon | Added as a Swift Package dependency. Provides `MLXModel` loading and text generation APIs. |
| **mlx-swift-examples** (LLM module) | Higher-level LLM inference APIs built on MLX-Swift | Provides `LLMModel`, `ModelConfiguration`, and `generate()` helpers for chat-template inference. |
| **Llama 3.2 1B (4-bit)** ([HuggingFace](https://huggingface.co/meta-llama/Llama-3.2-1B-Instruct)) | LLM weights (~0.74 GB unified memory) | Bundled in app resources or downloaded on first use. Loaded lazily by `MLXJournalService`. |
| **`lexicon.json`** (existing) | 718 ADHD-specific vocabulary entries across 27 categories | Already bundled at [`app-four/Resources/lexicon.json`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Resources/lexicon.json). Loaded via existing [`LexiconLoader.loadBundled()`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/NoteExtraction/LexiconData.swift#L119-L130) in `LexiconData.swift`. |
| **`Levels.swift`** (existing) | Signal enum definitions (`MoodLevel`, `EnergyLevel`, `FocusLevel`, `SleepLevel`) | Already in [`SquirlSignals`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift). Labels are programmatically enumerated into the prompt via `CaseIterable`. |

MLX-Swift was chosen because it is the only production-quality Swift framework for running quantised LLMs on Apple Silicon unified memory. Core ML does not support the Llama architecture natively. llama.cpp has a Swift binding but MLX-Swift provides better Apple Silicon optimisation and a cleaner Swift API.

### 3. State Management & Data Flow

```
WhisperKit (04a)
    ↓ clean transcript (String)
ProcessingViewModel / PendingTranscriptionServiceImpl
    ↓ calls summarizationService.summarize(rawTranscription:)
MLXJournalService [background actor]
    ├── 1. Check os_proc_available_memory() ≥ 200 MB
    ├── 2. Load Llama weights if not already loaded (lazy)
    ├── 3. Build system prompt (lexicon + Levels.swift labels + few-shot)
    ├── 4. Inject transcript as user message
    ├── 5. Run MLX-Swift inference → raw JSON string
    └── 6. Return raw JSON to validation layer (Part 2)
         ↓
    SummaryResult (returned to caller)
```

**State ownership**: `MLXJournalService` owns:
- A reference to the loaded `Lexicon` (immutable, loaded once at init)
- The loaded MLX model instance (lazy, nullable — loaded on first inference)
- The constructed system prompt (derived from lexicon + Levels.swift, built once)

The service holds **no UI state** and **no persistence logic**. It is a pure transformation: `String → SummaryResult`.

**`SummaryResult` actual fields** (from [`Protocols.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/Protocols.swift#L188-L205) lines 188-205):

```swift
nonisolated struct SummaryResult: Sendable {
    let bullets: [String]
    let medications: [MedEvent]
    let generatedTitle: String
    let energyLevel: String?      // e.g. "steady"
    let focusLevel: String?       // e.g. "sharp"
    let mood: String?             // e.g. "good"
    let sleepHours: Double?
    let sleepQuality: String?
    let sleepEvent: SleepEvent?
    let sleepLevel: String?       // e.g. "deep"
    let sideEffects: [String]
    let emotions: [String]
    let topics: [String]
    let noteExtraction: NoteExtraction?
}
```

> **Critical**: The actual `SummaryResult` uses `String?` for signal levels (not the enum types directly). The `MLXJournalService` must return the `rawValue` strings from `Levels.swift` enums. The validation layer (Part 2) will parse these strings back to enums.

### 4. Storage & Persistence Strategy

Not applicable for Part 1. `MLXJournalService` does not persist any data. The raw JSON output is handed to the validation layer (Part 2), which parses it and calls `Recording.applySummary()` and `Recording.setMedicationEvents()` to persist to SwiftData.

The Llama model weights are either bundled in the app resources or stored in the app's documents directory if downloaded. This is a read-only asset, not user data.

### 5. Performance & Constraints

| Constraint | Value | Source |
|---|---|---|
| Model memory footprint | ~0.74 GB unified memory | Llama 3.2 1B 4-bit |
| Memory abort threshold | `os_proc_available_memory()` < 200 MB | FR-EXT-06 |
| Target hardware floor | iPhone 12 Pro (A14 Bionic, 6 GB RAM) | FSD |
| Inference latency | 5–15 seconds (15–30 tok/s on A14) | FR-EXT-08 |
| Max input size | ~1,600 tokens (~1,200 words / ~8 min transcript) | FR-EXT-04 |
| Model context window | 128k tokens | Llama 3.2 spec |

**Peak shaving**: Whisper (~400 MB) is unloaded before Llama (~740 MB) is loaded. At no point are both models in memory simultaneously. This is coordinated by the model lifecycle documented in 04a — `MLXJournalService` only needs to check `os_proc_available_memory()` before loading, not manage the Whisper unload itself.

**Impact on app footprint**: The Llama weights add ~740 MB to the app's download size (or first-use download). During inference, unified memory usage is ~740 MB for weights + ~50 MB for KV cache + inference overhead. The 200 MB headroom check ensures the device retains enough memory for the system and background processes.

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. SwiftUI-First** — N/A for this feature (no new UI). The existing "Synthesizing your journal…" shimmer in `ProcessingViewModel` is unchanged. No UIKit.
- [x] **II. Test-Build-Ship** — Plan includes test-first RED→GREEN for `MLXJournalService`, prompt construction, and memory lifecycle. Build verification via Xcode.
- [x] **III. Correctness Over Speed** — No stubs. The legacy `NLSummarizationService` is not deleted in Part 1 (it remains available as a fallback during development). No dead code introduced.
- [x] **IV. Minimal Surface** — One new class (`MLXJournalService`), one new enum case (`RecordingTag.llm`), one prompt builder. No unnecessary abstractions. The service uses the existing `Lexicon` struct, `LexiconLoader`, and `SummaryResult` types without modification.
- [x] **V. Solo Git Discipline** — Work is on `feat/043-mlx-journal-service` branch. PR + `/code-review` before merge. `main` untouched.
- [x] **VI. On-Device Privacy** — 100% on-device. Zero network calls. No audio/health/mood/medication data leaves the device. Llama inference is local.
- [x] **VII. On-Device LLM Extraction** — Direct implementation of this principle. Llama 3.2 1B via MLX-Swift, lexicon seeds prompt, signal output validated against `Levels.swift` rawValues, memory lifecycle follows peak shaving with `os_proc_available_memory()` check.
- [x] **VIII. Service-Oriented Architecture** — `MLXJournalService` sits behind the `SummarizationService` protocol in `Services/`, injected via `AppDependencies`/`AppServices`. Heavy work off main actor.
- [x] **IX. Pre-Release Data Posture** — No schema changes. `SummaryResult` is unchanged. `RecordingTag.llm` is additive (new enum case, not a schema migration).
- [x] **X. Test-First Development** — Tests are ordered before implementation in the task breakdown. Prompt construction, lexicon injection, memory checks, and `SummarizationService` conformance are all unit-testable. Swift Testing (`@Test`, `#expect`).
- [x] **XI. Architectural Exhaustiveness** — Full lexicon inventory (718 entries, 27 categories) documented. Signal schema (4 enums × 5 labels) explicitly listed. Memory thresholds, latency targets, and prompt structure fully specified.

---

## Project Structure

### Documentation (this feature)

```text
specs/043-mlx-journal-service/
├── spec.md              # Feature specification (speckit-specify output)
├── plan.md              # This file (speckit-plan output)
└── tasks.md             # Phase 2 output (speckit-tasks — NOT created by speckit-plan)
```

### Source Code (repository root)

```text
app-four/
├── Services/
│   ├── Protocols.swift                     # Contains SummarizationService + SummaryResult (UNCHANGED)
│   ├── MLXJournalService.swift             # NEW — LLM extraction service
│   ├── MLXPromptBuilder.swift              # NEW — System prompt construction
│   ├── NLSummarizationService.swift        # RETAINED (legacy, not deleted in Part 1)
│   ├── NoteExtraction/
│   │   ├── LexiconData.swift               # Contains LexiconLoader (UNCHANGED)
│   │   ├── NLNoteExtractor.swift           # Legacy extractor (RETAINED)
│   │   └── CueMatcher.swift                # Legacy matcher (RETAINED)
│   └── PendingTranscriptionServiceImpl.swift # UNCHANGED
├── Store/
│   ├── AppDependencies.swift               # MODIFIED — DI binding swap (1 line, line 27)
│   └── AppServices.swift                   # UNCHANGED (receives service via init)
├── Models/
│   └── RecordingTag.swift                  # MODIFIED — add TagSource.llm case
├── ViewModels/
│   └── ProcessingViewModel.swift           # UNCHANGED
└── Resources/
    └── lexicon.json                        # UNCHANGED

Packages/SquirlSignals/Sources/SquirlSignals/
└── Levels.swift                            # UNCHANGED

app-fourTests/
└── MLXJournalServiceTests.swift            # NEW — unit tests
```

**Structure Decision**: This feature adds exactly 2 new production files (`MLXJournalService.swift`, `MLXPromptBuilder.swift`) and modifies 2 existing files (`AppDependencies.swift` — 1 line DI change on line 27, `RecordingTag.swift` — 1 new `TagSource.llm` case). This follows the existing `Services/` architecture. The `MLXPromptBuilder` extraction is justified by the prompt's substantial size (~200 lines of structured text) and the need for independent unit testing of prompt correctness.

### File Manifest & Responsibilities

| File Path | Responsibility | Key Structs / Functions / Protocols |
|---|---|---|
| [`app-four/Services/MLXJournalService.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/MLXJournalService.swift) | **Core extraction service.** Conforms to `SummarizationService` (defined in [`Protocols.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/Protocols.swift#L207-L209)). Loads lexicon at init via `LexiconLoader.loadBundled()` (in [`LexiconData.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/NoteExtraction/LexiconData.swift#L119-L130)), manages MLX model lifecycle (lazy load, memory check, unload), invokes inference, returns raw JSON wrapped in `SummaryResult`. Uses `nonisolated struct` to match `NLSummarizationService`'s declaration style. | `nonisolated struct MLXJournalService: SummarizationService` — `init()`, `func summarize(rawTranscription:) async throws -> SummaryResult`, private `func loadModelIfNeeded() async throws`, private `func checkMemoryHeadroom() -> Bool` |
| [`app-four/Services/MLXPromptBuilder.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/MLXPromptBuilder.swift) | **System prompt construction.** Takes a `Lexicon` and builds the full system prompt string: JSON-only instruction, exact signal label enumeration from `Levels.swift` via `CaseIterable`, representative vocabulary from each lexicon tier, full medication list, and 3 few-shot examples (Short, Journal, Hybrid). | `enum MLXPromptBuilder` — `static func buildSystemPrompt(lexicon: Lexicon) -> String`, `static func buildUserMessage(transcript: String) -> String` |
| [`app-four/Store/AppDependencies.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Store/AppDependencies.swift#L27) | **DI binding change.** Line 27 changes from `NLSummarizationService()` to `MLXJournalService()`. This is a `static let` that flows into `AppServices` and from there into ViewModels. | Existing `AppDependencies` struct — 1-line static let change |
| [`app-four/Models/RecordingTag.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Models/RecordingTag.swift#L4-L8) | **Provenance tag.** Add `case llm` to `TagSource` enum (line 4) alongside existing `.nlp`, `.user`, `.userCorrected`. | `enum TagSource: String, Codable` — add `case llm` |
| [`app-fourTests/MLXJournalServiceTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/MLXJournalServiceTests.swift) | **Unit tests.** Tests for prompt construction (label correctness, lexicon injection, few-shot examples), `SummarizationService` conformance, memory check logic, empty-transcript handling, and `TagSource.llm` existence. | `@Suite struct MLXJournalServiceTests` — `@Test func promptContainsAllMoodLabels()`, `@Test func promptContainsAllEnergyLabels()`, etc. |

---

## Complexity Tracking

> **No constitution violations.** All principles pass. The feature introduces exactly 2 new files and modifies 2 existing files — well within Principle IV (Minimal Surface). The `MLXPromptBuilder` extraction is justified by the prompt's substantial size (~200 lines of structured text with lexicon injection) and the need for independent unit testing of prompt correctness.
