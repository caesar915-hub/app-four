# Implementation Plan: Validation & Persistence — `parseExtraction`, `UnifiedExtraction`, `Recording`

**Branch**: `043-mlx-journal-service` | **Date**: 2026-08-12 | **Spec**: [`spec-part2.md`](file:///Users/caesargrey/Projects/app-four-llama/specs/043-mlx-journal-service/spec-part2.md)

**Input**: Feature specification from `/specs/043-mlx-journal-service/spec-part2.md`

**Source FSD**: [`04b-2-validation-persistence.md`](file:///Users/caesargrey/Projects/app-four-llama/docs/llama_migration/04b-2-validation-persistence.md) (Part 2 of 3)

## Feature Definition & Scope

This feature implements the **validation and persistence bridge** between raw LLM JSON output (produced by Part 1's [`MLXJournalService`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/MLXJournalService.swift)) and the persisted `Recording` model columns consumed by downstream views (DayCard, Insights, Extraction Review UI).

> **Codebase reality check**: The research subagent verified all file paths and line numbers against the actual codebase on 2026-08-12. Critical findings:
> - Part 1's `MLXJournalService.swift` already exists and uses a private `LLMExtractionResponse` struct (lines 20-36) as its JSON decode target. This struct does **not** match the spec's `UnifiedExtraction` schema — it has `sleep` (single string) instead of `sleepHours`/`sleepQuality`, uses `lexiconPhrases` instead of `lexicon`, and lacks `activities`, `sideEffects`, and `summary` separation. **Part 2 must replace `LLMExtractionResponse` with `UnifiedExtraction`.**
> - The existing `summarize()` method (lines 84-115) performs direct `JSONDecoder` decode with no recovery stages — backtick stripping and substring extraction are missing. **Part 2 must add the 3-stage `parseExtraction()` function.**
> - The existing `summarize()` performs **zero validation** on decoded values — hallucinated mood/energy/focus labels pass straight through to `SummaryResult`. **Part 2 must add the clamping layer.**
> - `NLSummarizationService` (lines 33-103) already contains `deriveTopics()` and SleepLevel derivation logic that Part 2 must replicate (not call — the legacy service is being replaced).
> - `Recording.applySummary()` and `setMedicationEvents()` are unchanged and require a correctly-shaped `SummaryResult` and `[MedEvent]` respectively.

**What is being built**: 

1. **`UnifiedExtraction`** — A new public `Codable` struct replacing the private `LLMExtractionResponse`. Contains all extraction fields: mood, energy, focus, sleepHours, sleepQuality, medications, emotions, activities, topics, lexicon, summary, sideEffects. Nested `MedicationExtraction` struct for medication entries.

2. **`parseExtraction(from:)`** — A new function implementing 3-stage JSON recovery: direct decode → backtick strip → substring extraction. Returns `UnifiedExtraction?` (nil on total failure).

3. **`ExtractionValidator`** — A new static validation layer implementing FR-EXT-10 through FR-EXT-12: field-by-field clamping against `Levels.swift` enum allowlists, emotion/activity/sideEffect filtering against `lexicon.json` allowlists, SleepLevel derivation from hours, and topic injection rules.

4. **Integration into `MLXJournalService.summarize()`** — The existing `summarize()` method (lines 84-115) is refactored to use `parseExtraction()` → `ExtractionValidator.validate()` → `SummaryResult` assembly, replacing the current direct decode + pass-through.

**What is NOT being built**: Inference (Part 1 — exists), prompt construction (Part 1 — exists), model loading (Part 1 — exists), `Recording.applySummary()` / `setMedicationEvents()` changes (unchanged), ExtractionReviewView (Part 3), any UI changes.

**What is NOT being changed**: `SummaryResult` struct (unchanged), `SummarizationService` protocol (unchanged), `Recording.applySummary()` (unchanged), `Recording.setMedicationEvents()` (unchanged), `ProcessingViewModel` (unchanged), `PendingTranscriptionServiceImpl` (unchanged), `Levels.swift` (unchanged), `lexicon.json` (unchanged), `LexiconLoader` (unchanged).

### Scope boundaries

| In scope (Part 2) | Out of scope |
|---|---|
| `UnifiedExtraction` / `MedicationExtraction` structs (new) | LLM inference & prompt construction (Part 1) |
| `parseExtraction()` — 3-stage JSON recovery (new) | `ExtractionReviewView` / `ExtractionReviewViewModel` (Part 3) |
| `ExtractionValidator` — field clamping & derivation (new) | Audio capture (03), Whisper transcription (04a) |
| SleepLevel derivation from hours (replicated from legacy) | Library rendering (05), Insights (06), Medications (07) |
| Topic injection rules (replicated from legacy) | `Recording.applySummary()` / `setMedicationEvents()` — unchanged |
| `SummaryResult` assembly from validated extraction | `SummaryResult` schema changes — none |
| Refactoring `MLXJournalService.summarize()` to use validation pipeline | MLX model loading, memory checks — unchanged |
| Removing private `LLMExtractionResponse` (replaced by `UnifiedExtraction`) | |

---

## Technical Context

### 1. Language & Runtime Environment

Swift 6+ with strict concurrency enabled. All new types (`UnifiedExtraction`, `MedicationExtraction`, `ExtractionValidator`) are value types (`struct` / `enum`) conforming to `Sendable`. The validation logic is pure functional (input → output, no side effects, no state) and runs on whatever actor/queue the caller provides — currently `Task.detached(priority: .userInitiated)` in `MLXJournalService.summarize()`.

No new concurrency actors or isolation boundaries are introduced. The validation pipeline is synchronous — it receives a raw `String`, parses/validates it, and returns a `SummaryResult`. The async boundary is managed by the existing `MLXJournalService`.

### 2. Core Dependencies & Frameworks

| Dependency | Role | Status |
|---|---|---|
| **Foundation** (`JSONDecoder`) | JSON decode in `parseExtraction()` | Existing — no new import |
| **`Levels.swift`** (`SquirlSignals` package) | Canonical signal enum rawValues for clamping | Existing — used via `CaseIterable` + `allCases.map(\.rawValue)` |
| **`lexicon.json`** / `Lexicon` struct | Allowlists for emotions, activities, medications, sideEffects | Existing — loaded by `LexiconLoader.loadBundled()` in `MLXJournalService.init()` |
| **`NoteExtraction.swift`** | `MedEvent`, `SleepEvent`, `NoteExtraction` structs | Existing — `SummaryResult` requires `[MedEvent]`, `SleepEvent?`, `NoteExtraction?` |

No new external dependencies. Everything is Foundation + existing codebase types.

### 3. State Management & Data Flow

```
MLXJournalService.summarize(rawTranscription:)
    ├── Part 1: systemPrompt + MLX inference → rawJSON (String)
    │
    ├── Part 2 (NEW):
    │   ├── 1. parseExtraction(from: rawJSON) → UnifiedExtraction?
    │   │      ├── Stage 1: Direct JSONDecoder decode
    │   │      ├── Stage 2: Strip ```json ``` wrappers, retry
    │   │      └── Stage 3: First { to last }, retry
    │   │
    │   ├── 2. ExtractionValidator.validate(extraction, lexicon:) → UnifiedExtraction
    │   │      ├── Clamp mood/energy/focus/sleepQuality against Levels.swift enums
    │   │      ├── Clamp sleepHours to 0...24
    │   │      ├── Filter emotions against lexicon.emotions (20)
    │   │      ├── Filter activities against lexicon.activityKeywords categories (11)
    │   │      ├── Filter sideEffects against lexicon.sideEffectCues ∪ physicalSideEffects
    │   │      ├── Truncate topics to max 4, lexicon to max 5
    │   │      ├── Derive SleepLevel from sleepHours if sleepQuality is nil
    │   │      ├── Inject "Medications" topic if medications non-empty
    │   │      ├── Inject "Symptoms" topic if sideEffects/reboundTerms non-empty
    │   │      ├── Inject "Appointments" topic if appointment cues detected
    │   │      └── Nil empty summary string
    │   │
    │   └── 3. Assemble SummaryResult from validated UnifiedExtraction
    │          ├── Map MedicationExtraction → MedEvent
    │          ├── Construct SleepEvent from sleepHours/sleepQuality
    │          ├── Generate title from signal parts ("Good · Alert · Sharp")
    │          └── Build NoteExtraction for noteExtractionJSON (optional)
    │
    └── Return SummaryResult to ProcessingViewModel
              ├── recording.applySummary(result)     ← UNCHANGED
              ├── recording.setMedicationEvents(...)  ← UNCHANGED
              └── haptic feedback                     ← UNCHANGED
```

**State ownership**: The validation pipeline is stateless. It takes a `String` and a `Lexicon` as input and produces a `SummaryResult` as output. The `Lexicon` is already loaded and owned by `MLXJournalService` (immutable, loaded at init).

**Key type mappings** (validated `UnifiedExtraction` → `SummaryResult`):

| `UnifiedExtraction` field | `SummaryResult` field | Mapping |
|---|---|---|
| `mood` | `mood` | Pass-through (already clamped to valid rawValue or nil) |
| `energy` | `energyLevel` | Pass-through |
| `focus` | `focusLevel` | Pass-through |
| `sleepHours` | `sleepHours` | Pass-through |
| `sleepQuality` | `sleepQuality` | Pass-through |
| derived SleepLevel | `sleepLevel` | Derived from hours or quality → rawValue |
| `medications` | `medications` | `MedicationExtraction` → `MedEvent` |
| `emotions` | `emotions` | Pass-through (already filtered) |
| `topics` | `topics` | Pass-through (already injected/truncated) |
| `sideEffects` | `sideEffects` | Pass-through (already filtered) |
| `summary` | `bullets` | Split into bullet array or wrap as single bullet |
| `lexicon` | included in `noteExtraction` | Preserved for display |
| `activities` | included in `noteExtraction` | Preserved for display |

### 4. Storage & Persistence Strategy

Part 2 does **not** introduce any schema changes. All persistence flows through the existing `Recording.applySummary()` and `Recording.setMedicationEvents()` methods, which are unchanged.

The `SummaryResult` type is unchanged. The difference from the legacy pipeline is only in **how** the `SummaryResult` is assembled — from a validated LLM extraction rather than a deterministic NLP extraction — but the downstream persistence code is oblivious to this.

**Mapping to `Recording` columns** (via unchanged `applySummary()`):

| `SummaryResult` field | `Recording` column | Type |
|---|---|---|
| `mood` | `mood` | `String?` |
| `energyLevel` | `energyLevel` | `String?` |
| `focusLevel` | `focusLevel` | `String?` |
| `sleepHours` | `sleepHours` | `Double?` |
| `sleepQuality` | `sleepQuality` | `String?` |
| `sleepLevel` | `sleepLevelValue` | `String?` |
| `bullets` | `summaryBulletsJSON` | `String` (JSON) |
| `emotions` | `emotionsJSON` | `String` (JSON) |
| `sideEffects` | `sideEffectsJSON` | `String` (JSON) |
| `sleepEvent` | `sleepEventJSON` | `String` (JSON) |
| `topics` | `topicTagsJSON` | `String` (JSON) |
| `noteExtraction` | `noteExtractionJSON` | `String` (JSON, with scalar fields stripped) |
| `generatedTitle` | `title` | `String` |
| `medications` → `setMedicationEvents` | `MedicationEvent` rows | SwiftData `@Model` |

### 5. Performance & Constraints

| Constraint | Value | Impact |
|---|---|---|
| JSON parsing + validation | < 10 ms | Negligible vs 5-15s inference |
| `lexicon.json` in-memory | Already loaded by `MLXJournalService.init()` | No additional memory |
| Clamping computation | O(n) per field, n ≤ 90 (medications) | Negligible |
| Memory abort threshold | < 200 MB (`os_proc_available_memory()`) | Handled in Part 1 — before validation runs |

The validation pipeline adds negligible overhead. JSON decode + field clamping + topic derivation is < 10 ms total. The performance bottleneck remains inference (Part 1, 5-15s).

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. SwiftUI-First** — N/A for this feature (no new UI). All validation and persistence logic is backend (Services layer). No views created or modified.
- [x] **II. Test-Build-Ship** — Plan includes test-first RED→GREEN for `parseExtraction()`, `ExtractionValidator`, `UnifiedExtraction` decoding, and `SummaryResult` assembly. Build verification via Xcode.
- [x] **III. Correctness Over Speed** — No stubs. The private `LLMExtractionResponse` is deleted (replaced by `UnifiedExtraction`). No dead code. Every clamping rule is explicit and exhaustive.
- [x] **IV. Minimal Surface** — Two new files (`UnifiedExtraction.swift`, `ExtractionValidator.swift`) with clear single responsibilities. No unnecessary abstractions — validation is a static enum with pure functions.
- [x] **V. Solo Git Discipline** — Work continues on `feat/043-mlx-journal-service` branch. PR + `/code-review` before merge.
- [x] **VI. On-Device Privacy** — 100% on-device. Zero network calls. Validation is pure computation on in-memory data.
- [x] **VII. On-Device LLM Extraction** — Direct implementation of Layer 4 validation. Signal output validated against `Levels.swift` rawValues. Any value not in canonical set is clamped to `nil`. Lexicon allowlists for emotions, activities, sideEffects.
- [x] **VIII. Service-Oriented Architecture** — Validation integrates into existing `MLXJournalService` (which sits behind `SummarizationService` protocol). No new protocol needed — validation is internal to the service implementation.
- [x] **IX. Pre-Release Data Posture** — No schema changes. `SummaryResult` unchanged. `Recording` columns unchanged. No new `@Attribute(.unique)` or required attributes.
- [x] **X. Test-First Development** — Tests are ordered before implementation. `parseExtraction()` (3 recovery stages), `ExtractionValidator` (clamping, derivation, injection), `UnifiedExtraction` decoding, and `SummaryResult` assembly are all unit-testable with Swift Testing (`@Test`, `#expect`).
- [x] **XI. Architectural Exhaustiveness** — Every clamping rule is enumerated in the spec (FR-EXT-10 table). Every SleepLevel derivation boundary is explicit. Topic injection rules are complete. Allowlists (20 emotions, 11 activities, ~90 medications, 58 side effects) are documented with sources.

---

## Project Structure

### Documentation (this feature)

```text
specs/043-mlx-journal-service/
├── spec.md              # Part 1 spec (MLXJournalService Core)
├── spec-part2.md        # Part 2 spec (Validation & Persistence) — THIS FEATURE
├── plan.md              # Part 1 plan
├── plan-part2.md        # Part 2 plan — THIS FILE
└── tasks.md             # Part 1 tasks
```

### Source Code (repository root)

```text
app-four/
├── Services/
│   ├── MLXJournalService.swift             # MODIFIED — refactor summarize() to use parseExtraction + validate
│   ├── MLXPromptBuilder.swift              # UNCHANGED
│   ├── Protocols.swift                     # UNCHANGED (SummarizationService + SummaryResult)
│   ├── NLSummarizationService.swift        # UNCHANGED (retained as legacy reference)
│   ├── NoteExtraction/
│   │   ├── UnifiedExtraction.swift         # NEW — UnifiedExtraction + MedicationExtraction structs
│   │   ├── ExtractionValidator.swift       # NEW — clamping, derivation, topic injection
│   │   ├── LexiconData.swift              # UNCHANGED (LexiconLoader)
│   │   ├── Lexicon.swift                  # UNCHANGED (Lexicon struct)
│   │   ├── NoteExtraction.swift           # UNCHANGED (MedEvent, SleepEvent, NoteExtraction)
│   │   ├── NLNoteExtractor.swift          # UNCHANGED (legacy)
│   │   └── CueMatcher.swift               # UNCHANGED (legacy)
│   └── PendingTranscriptionServiceImpl.swift # UNCHANGED
├── Models/
│   └── Recording.swift                    # UNCHANGED
├── ViewModels/
│   └── ProcessingViewModel.swift          # UNCHANGED
└── Resources/
    └── lexicon.json                       # UNCHANGED

Packages/SquirlSignals/Sources/SquirlSignals/
└── Levels.swift                           # UNCHANGED

app-fourTests/
├── UnifiedExtractionTests.swift           # NEW — JSON decode tests
├── ExtractionValidatorTests.swift         # NEW — clamping, derivation, topic tests
├── ParseExtractionTests.swift             # NEW — 3-stage recovery tests
├── SummaryResultAssemblyTests.swift       # NEW — end-to-end assembly tests
├── MLXJournalServiceTests.swift           # EXISTING — may extend
└── MLXPromptBuilderTests.swift            # EXISTING — unchanged
```

**Structure Decision**: Two new production files in `Services/NoteExtraction/` (co-located with the existing extraction infrastructure) and four new test files. The `ExtractionValidator` is placed in `NoteExtraction/` rather than directly in `Services/` because it validates extraction-specific data using extraction-specific allowlists — it is an extraction concern, not a generic service concern.

### File Manifest & Responsibilities

| File Path | Responsibility | Key Structs / Functions |
|---|---|---|
| [`app-four/Services/NoteExtraction/UnifiedExtraction.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/NoteExtraction/UnifiedExtraction.swift) | **Extraction output schema.** Public `Codable` struct defining the complete LLM output schema. Replaces the private `LLMExtractionResponse` in `MLXJournalService.swift`. Contains `UnifiedExtraction` (12 fields: mood, energy, focus, sleepHours, sleepQuality, medications, emotions, activities, topics, lexicon, summary, sideEffects) and nested `MedicationExtraction` (3 fields: name, dose, taken). Both conform to `Codable, Sendable, Equatable`. | `struct UnifiedExtraction: Codable, Sendable, Equatable` — all fields `var` with `?` or array defaults. `struct MedicationExtraction: Codable, Sendable, Equatable` — `name: String`, `dose: String?`, `taken: Bool`. |
| [`app-four/Services/NoteExtraction/ExtractionValidator.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/NoteExtraction/ExtractionValidator.swift) | **Field clamping and derivation.** Pure static validation layer implementing FR-EXT-10 through FR-EXT-12. Takes a decoded `UnifiedExtraction` + `Lexicon` and returns a validated copy with invalid values nulled, out-of-range values truncated, SleepLevel derived from hours, and mandatory topics injected. Also contains the `parseExtraction(from:)` function implementing 3-stage JSON recovery (FR-EXT-09), and `assembleSummaryResult(from:lexicon:transcript:)` for building the final `SummaryResult`. | `enum ExtractionValidator` — `static func parseExtraction(from rawJSON: String) -> UnifiedExtraction?`, `static func validate(_ extraction: UnifiedExtraction, lexicon: Lexicon) -> UnifiedExtraction`, `static func deriveSleepLevel(hours: Double?) -> String?`, `static func deriveTopics(_ topics: [String], extraction: UnifiedExtraction, lexicon: Lexicon) -> [String]`, `static func assembleSummaryResult(from extraction: UnifiedExtraction, lexicon: Lexicon, rawTranscript: String) -> SummaryResult` |
| [`app-four/Services/MLXJournalService.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/MLXJournalService.swift) | **Refactor `summarize()`.** Remove private `LLMExtractionResponse` and `LLMMedicationEntry` structs (lines 8-36). Replace the direct decode + pass-through (lines 84-115) with: `ExtractionValidator.parseExtraction(from: rawJSON)` → `ExtractionValidator.validate(extraction, lexicon: lexicon)` → `ExtractionValidator.assembleSummaryResult(from: validated, lexicon: lexicon, rawTranscript: trimmed)`. The fallback path (parse returns nil) returns a transcript-only `SummaryResult`. | Modified `func summarize(rawTranscription:)` — now calls into `ExtractionValidator`. Removed `LLMExtractionResponse`, `LLMMedicationEntry`. |
| [`app-fourTests/UnifiedExtractionTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/UnifiedExtractionTests.swift) | **JSON decode tests.** Verifies `UnifiedExtraction` correctly decodes well-formed JSON matching the LLM output schema. Tests all fields, optional handling, default values, and partial JSON (missing fields). | `@Suite struct UnifiedExtractionTests` — `@Test func decodesCompleteJSON()`, `@Test func decodesPartialJSON()`, `@Test func defaultsEmptyArrays()` |
| [`app-fourTests/ParseExtractionTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/ParseExtractionTests.swift) | **3-stage recovery tests.** Verifies each stage of `parseExtraction()`: clean JSON, backtick-wrapped, prose-surrounded, and total failure. | `@Suite struct ParseExtractionTests` — `@Test func directDecode()`, `@Test func backtickStrip()`, `@Test func substringExtraction()`, `@Test func totalFailure()` |
| [`app-fourTests/ExtractionValidatorTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/ExtractionValidatorTests.swift) | **Clamping and derivation tests.** Parameterised tests for every clamping rule (FR-EXT-10), SleepLevel derivation (FR-EXT-11), and topic injection (FR-EXT-12). | `@Suite struct ExtractionValidatorTests` — `@Test(arguments:) func moodClamping()`, `@Test(arguments:) func energyClamping()`, `@Test(arguments:) func focusClamping()`, `@Test func sleepHoursRange()`, `@Test(arguments:) func sleepLevelDerivation()`, `@Test func emotionFiltering()`, `@Test func activityFiltering()`, `@Test func topicInjection()`, `@Test func topicTruncation()`, `@Test func sideEffectFiltering()`, `@Test func lexiconTruncation()`, `@Test func summaryNilOnEmpty()` |
| [`app-fourTests/SummaryResultAssemblyTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/SummaryResultAssemblyTests.swift) | **End-to-end assembly tests.** Verifies `assembleSummaryResult()` produces a `SummaryResult` with correct field mapping: `MedicationExtraction` → `MedEvent`, SleepEvent construction, title generation, bullet formatting. | `@Suite struct SummaryResultAssemblyTests` — `@Test func mapsValidatedExtractionToSummaryResult()`, `@Test func mapsMedicationExtractionToMedEvent()`, `@Test func generatesTitleFromSignals()`, `@Test func fallbackOnNilExtraction()` |

---

## Complexity Tracking

> **No constitution violations.** All principles pass. The feature introduces exactly 2 new production files and modifies 1 existing file. The `ExtractionValidator` as a separate file from `UnifiedExtraction` is justified by the Single Responsibility Principle: `UnifiedExtraction.swift` is a data type (Codable schema), `ExtractionValidator.swift` is behaviour (parsing, clamping, derivation, assembly). They have different reasons to change and different test surfaces.

| Decision | Rationale | Alternative Rejected Because |
|---|---|---|
| `ExtractionValidator` as `enum` (no instances) | Pure namespace for static functions. No state needed. | `struct` with init would imply statefulness that doesn't exist. |
| Validation inside `NoteExtraction/` directory | Co-located with extraction types (`NoteExtraction`, `MedEvent`, `Lexicon`) | Placing in `Services/` root would separate validation from the types it validates. |
| Replace `LLMExtractionResponse` entirely | The Part 1 struct is a private implementation detail with a different schema than what the prompt actually requests. `UnifiedExtraction` matches the prompt's JSON schema exactly. | Keeping both would create dead code (Constitution III violation). |
| `parseExtraction` inside `ExtractionValidator` | It's the entry point of the validation pipeline (parse → validate → assemble). | Separate file for a single function would violate Minimal Surface (Constitution IV). |
