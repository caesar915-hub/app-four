# Tasks: MLXJournalService — On-Device LLM Extraction

**Input**: Design documents from `/specs/043-mlx-journal-service/`

**Prerequisites**: [plan.md](file:///Users/caesargrey/Projects/app-four-llama/specs/043-mlx-journal-service/plan.md) (required), [spec.md](file:///Users/caesargrey/Projects/app-four-llama/specs/043-mlx-journal-service/spec.md) (required for user stories)

**Tests**: Test-first is MANDATORY for logic (Services, prompt builder) per Constitution **Principle X** — write the test, run it, confirm it **FAILS (RED)**, then implement just enough to make it pass (**GREEN**), then refactor. SwiftUI **views are EXEMPT** (no views in this feature). Tests use **Swift Testing** (`@Test`/`#expect`/`#require`). Each user story's Tests block below is REQUIRED, not optional.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

**Skills applied**: swift-concurrency (nonisolated struct, `@concurrent`/`Task.detached`, Sendable), swift-testing (parameterized `@Test(arguments:)`, `#expect`/`#require`), swift-language (`enum` as namespace, `CaseIterable` for labels, guard-else), swift-codable (private `Decodable` response struct), swift-architecture (service-layer protocol, no `@Observable`).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Add MLX-Swift package dependency and the `TagSource.llm` provenance case.

- [ ] `T001` `[P]` `[Setup]` **Add MLX-Swift and mlx-swift-examples SPM dependencies**
  - **File:** `app-four.xcodeproj` (Package.resolved / project settings)
  - **Action:** Add `https://github.com/ml-explore/mlx-swift` and `https://github.com/ml-explore/mlx-swift-examples` as Swift Package dependencies. Link `MLX`, `MLXNN`, `MLXRandom`, and `MLXLLM` products to the `app-four` target.
  - **Dependencies:** None
  - **Validation:** `xcodebuild -resolvePackageDependencies` succeeds. `import MLX` and `import MLXLLM` compile.

- [ ] `T002` `[P]` `[Setup]` **Add `TagSource.llm` case**
  - **File:** [`app-four/Models/RecordingTag.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Models/RecordingTag.swift#L4-L8)
  - **Action:** Add `case llm` to the `TagSource: String, Codable` enum (line 4) alongside existing `.nlp`, `.user`, `.userCorrected`. This is an additive enum change — no schema migration needed (String-backed Codable enum).
  - **Dependencies:** None
  - **Validation:** Project builds. Existing tests pass. `TagSource.llm.rawValue == "llm"`.

**Checkpoint**: Dependencies resolved, `TagSource.llm` available. All subsequent phases can begin.

---

## Phase 2: User Story 3 — Lexicon-Informed Prompt Construction (Priority: P1)

**Goal**: Build the system prompt that seeds the 1B model with ADHD vocabulary, exact signal labels, medication list, and few-shot examples.

**Independent Test**: Inspect the prompt string and verify it contains all required labels, vocabulary, and examples.

**Rationale for ordering US3 first**: The prompt builder has zero dependencies on MLX-Swift. It is a pure `String`-producing function that can be fully tested without model loading. US1 (inference) and US2 (protocol swap) both depend on the prompt being correct.

### Tests for User Story 3 (test-first · RED — MANDATORY) ⚠️

> **RED**: Write these tests FIRST and RUN them — they MUST FAIL before any implementation.

- [ ] `T003` `[P]` `[US3]` **RED — Test: prompt contains all mood labels**
  - **File:** [`app-fourTests/MLXPromptBuilderTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/MLXPromptBuilderTests.swift) [NEW]
  - **Action:** Create `@Suite struct MLXPromptBuilderTests`. Add `@Test(arguments: MoodLevel.allCases) func promptContainsMoodLabel(_ level: MoodLevel)` — load a real `Lexicon` via `LexiconLoader.loadBundled()`, build the system prompt via `MLXPromptBuilder.buildSystemPrompt(lexicon:)`, and `#expect(prompt.contains(level.rawValue))`.
  - **Dependencies:** None (uses existing `Levels.swift` and `LexiconLoader`)
  - **Validation:** Test compiles but **FAILS** because `MLXPromptBuilder` does not exist yet.

- [ ] `T004` `[P]` `[US3]` **RED — Test: prompt contains all energy labels**
  - **File:** [`app-fourTests/MLXPromptBuilderTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/MLXPromptBuilderTests.swift)
  - **Action:** Add `@Test(arguments: EnergyLevel.allCases) func promptContainsEnergyLabel(_ level: EnergyLevel)` — same pattern as T003 for energy.
  - **Dependencies:** T003 (same file)
  - **Validation:** Test compiles but **FAILS**.

- [ ] `T005` `[P]` `[US3]` **RED — Test: prompt contains all focus labels**
  - **File:** [`app-fourTests/MLXPromptBuilderTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/MLXPromptBuilderTests.swift)
  - **Action:** Add `@Test(arguments: FocusLevel.allCases) func promptContainsFocusLabel(_ level: FocusLevel)` — same pattern for focus.
  - **Dependencies:** T003 (same file)
  - **Validation:** Test compiles but **FAILS**.

- [ ] `T006` `[P]` `[US3]` **RED — Test: prompt contains all sleep labels**
  - **File:** [`app-fourTests/MLXPromptBuilderTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/MLXPromptBuilderTests.swift)
  - **Action:** Add `@Test(arguments: SleepLevel.allCases) func promptContainsSleepLabel(_ level: SleepLevel)` — same pattern for sleep.
  - **Dependencies:** T003 (same file)
  - **Validation:** Test compiles but **FAILS**.

- [ ] `T007` `[US3]` **RED — Test: prompt includes medication list from lexicon**
  - **File:** [`app-fourTests/MLXPromptBuilderTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/MLXPromptBuilderTests.swift)
  - **Action:** Add `@Test func promptContainsMedicationVocabulary()` — load lexicon, build prompt, `#expect(prompt.contains("Vyvanse"))`, `#expect(prompt.contains("Concerta"))`, `#expect(prompt.contains("addy"))` (slang), `#expect(prompt.contains("vyvance"))` (misspelling).
  - **Dependencies:** T003 (same file)
  - **Validation:** Test compiles but **FAILS**.

- [ ] `T008` `[US3]` **RED — Test: prompt includes lexicon vocabulary tiers**
  - **File:** [`app-fourTests/MLXPromptBuilderTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/MLXPromptBuilderTests.swift)
  - **Action:** Add `@Test func promptContainsLexiconVocabulary()` — verify representative entries from mood (`"bouncing off the walls"`), focus (`"brain fog"`), energy (`"no spoons"`), executive dysfunction (`"doom pile"`), sleep (`"tossed and turned"`) appear in the prompt. Verify `negationTokens`, `medNotTakenVerbs`, `timeOfDayKeywords` are **NOT** in the prompt.
  - **Dependencies:** T003 (same file)
  - **Validation:** Test compiles but **FAILS**.

- [ ] `T009` `[US3]` **RED — Test: prompt includes 3 few-shot examples**
  - **File:** [`app-fourTests/MLXPromptBuilderTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/MLXPromptBuilderTests.swift)
  - **Action:** Add `@Test func promptContainsFewShotExamples()` — verify the prompt contains at least 3 distinct JSON example blocks. Check for the Short check-in pattern (`"summary": null`), Journal pattern (with summary), and Hybrid pattern.
  - **Dependencies:** T003 (same file)
  - **Validation:** Test compiles but **FAILS**.

- [ ] `T010` `[US3]` **RED — Test: prompt instructs JSON-only output**
  - **File:** [`app-fourTests/MLXPromptBuilderTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/MLXPromptBuilderTests.swift)
  - **Action:** Add `@Test func promptInstructsJsonOnly()` — verify the prompt contains an instruction to output ONLY JSON with no surrounding text and no markdown backticks.
  - **Dependencies:** T003 (same file)
  - **Validation:** Test compiles but **FAILS**.

### Implementation for User Story 3

- [ ] `T011` `[US3]` **GREEN — Implement `MLXPromptBuilder`**
  - **File:** [`app-four/Services/MLXPromptBuilder.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/MLXPromptBuilder.swift) [NEW]
  - **Action:** Create `enum MLXPromptBuilder` (caseless enum per swift-language skill — prevents accidental instantiation). Implement:
    - `static func buildSystemPrompt(lexicon: Lexicon) -> String` — constructs the full system prompt:
      1. JSON-only instruction (no markdown, no surrounding text)
      2. Signal label enumeration using `MoodLevel.allCases.map(\.rawValue)`, `EnergyLevel.allCases`, `FocusLevel.allCases`, `SleepLevel.allCases` (never hardcode labels — use `CaseIterable`)
      3. Representative vocabulary injection from each lexicon tier (exclude `negationTokens`, `medNotTakenVerbs`, `timeOfDayKeywords`)
      4. Full medication list from `lexicon.medications`
      5. 3 few-shot examples: Short check-in (`summary: null`), Journal entry (summary + topics + phrases), Hybrid
    - `static func buildUserMessage(transcript: String) -> String` — wraps the transcript for the user-turn message.
  - **Dependencies:** T001 (for build), T003–T010 (tests must exist and FAIL first)
  - **Validation:** All T003–T010 tests turn **GREEN**. Refactor if needed while keeping tests green.

**Checkpoint**: Prompt builder is fully tested and produces correct output. No MLX dependency needed for this phase.

---

## Phase 3: User Story 1 — LLM-Based Signal Extraction (Priority: P1) 🎯 MVP

**Goal**: Implement the core `MLXJournalService` that loads Llama, runs inference, and returns `SummaryResult`.

**Independent Test**: Pass a transcript to `MLXJournalService.summarize(rawTranscription:)` and verify it returns a valid `SummaryResult`.

### Tests for User Story 1 (test-first · RED — MANDATORY) ⚠️

> **RED**: Write these tests FIRST. Tests that require actual model inference are marked as integration tests and may need a device/Simulator with sufficient memory.

- [ ] `T012` `[P]` `[US1]` **RED — Test: empty transcript returns "Empty Note"**
  - **File:** [`app-fourTests/MLXJournalServiceTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/MLXJournalServiceTests.swift) [NEW]
  - **Action:** Create `@Suite struct MLXJournalServiceTests`. Add `@Test func emptyTranscriptReturnsEmptyNote() async throws` — create `MLXJournalService()`, call `summarize(rawTranscription: "")`, `#expect(result.generatedTitle == "Empty Note")`, `#expect(result.mood == nil)`, `#expect(result.energyLevel == nil)`, `#expect(result.focusLevel == nil)`.
  - **Dependencies:** None
  - **Validation:** Test compiles but **FAILS** because `MLXJournalService` does not exist yet.

- [ ] `T013` `[P]` `[US1]` **RED — Test: whitespace-only transcript returns "Empty Note"**
  - **File:** [`app-fourTests/MLXJournalServiceTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/MLXJournalServiceTests.swift)
  - **Action:** Add `@Test func whitespaceOnlyTranscriptReturnsEmptyNote() async throws` — call with `"   \n  \t  "`, verify same empty result as T012.
  - **Dependencies:** T012 (same file)
  - **Validation:** Test compiles but **FAILS**.

- [ ] `T014` `[US1]` **RED — Test: SummarizationService conformance compiles**
  - **File:** [`app-fourTests/MLXJournalServiceTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/MLXJournalServiceTests.swift)
  - **Action:** Add `@Test func conformsToSummarizationService()` — create `let service: SummarizationService = MLXJournalService()`, call `_ = try await service.summarize(rawTranscription: "")`. This verifies protocol conformance and `Sendable` at compile time.
  - **Dependencies:** T012 (same file)
  - **Validation:** Test compiles but **FAILS** because `MLXJournalService` does not exist yet.

- [ ] `T015` `[US1]` **RED — Test: service uses lexicon from `LexiconLoader`**
  - **File:** [`app-fourTests/MLXJournalServiceTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/MLXJournalServiceTests.swift)
  - **Action:** Add `@Test func serviceLoadsLexicon()` — verify `MLXJournalService` can be instantiated and does not crash, implying successful lexicon load. (Lexicon load is validated at init.)
  - **Dependencies:** T012 (same file)
  - **Validation:** Test compiles but **FAILS**.

### Implementation for User Story 1

- [ ] `T016` `[US1]` **Define private `LLMExtractionResponse: Decodable`**
  - **File:** [`app-four/Services/MLXJournalService.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/MLXJournalService.swift) [NEW — start of file]
  - **Action:** Define a private `struct LLMExtractionResponse: Decodable` that mirrors the JSON schema the LLM produces. Fields: `mood: String?`, `energy: String?`, `focus: String?`, `sleep: String?`, `summary: String?`, `title: String?`, `medications: [LLMMedicationEntry]?`, `emotions: [String]?`, `topics: [String]?`, `lexiconPhrases: [String]?`. Include nested `LLMMedicationEntry: Decodable` with `name: String`, `dosage: String?`, `taken: Bool?`, `timeOfDay: String?`. Use explicit `CodingKeys` for snake_case JSON keys.
  - **Dependencies:** T011 (prompt builder must exist for the service to reference), T001 (MLX-Swift dependency)
  - **Validation:** Struct compiles and can decode a sample JSON string.

- [ ] `T017` `[US1]` **GREEN — Implement `MLXJournalService` core**
  - **File:** [`app-four/Services/MLXJournalService.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/MLXJournalService.swift)
  - **Action:** Create `nonisolated struct MLXJournalService: SummarizationService` (matching `NLSummarizationService`'s declaration style). Implement:
    - **Stored properties:** `private let lexicon: Lexicon`, `private let systemPrompt: String` (built once at init via `MLXPromptBuilder`)
    - **`init()`:** Call `LexiconLoader.loadBundled()` to load lexicon. Call `MLXPromptBuilder.buildSystemPrompt(lexicon:)` to build system prompt.
    - **`func summarize(rawTranscription: String) async throws -> SummaryResult`:**
      1. `guard` — trim whitespace, return `SummaryResult(generatedTitle: "Empty Note")` for empty input
      2. Call `loadModelIfNeeded()` (see T019)
      3. Build user message via `MLXPromptBuilder.buildUserMessage(transcript:)`
      4. Run inference via MLX-Swift `generate()` in `Task.detached(priority: .userInitiated)` for off-main-actor execution
      5. Parse raw JSON response via `JSONDecoder` into `LLMExtractionResponse`
      6. Map `LLMExtractionResponse` fields to `SummaryResult` (matching existing field types: `String?` for levels, `[MedEvent]` for medications, etc.)
      7. Return `SummaryResult`
  - **Dependencies:** T011 (MLXPromptBuilder), T016 (LLMExtractionResponse), T001 (MLX-Swift), T012–T015 (tests must exist and FAIL first)
  - **Validation:** T012, T013, T014, T015 turn **GREEN**. Build succeeds.

**Checkpoint**: `MLXJournalService` exists, conforms to `SummarizationService`, handles empty transcripts. Inference path exists but model loading is a stub for Phase 4.

---

## Phase 4: User Story 4 — Memory Lifecycle & Peak Shaving (Priority: P2)

**Goal**: Implement safe model loading with `os_proc_available_memory()` check and lazy lifecycle.

**Independent Test**: Simulate low-memory and verify graceful abort.

### Tests for User Story 4 (test-first · RED — MANDATORY) ⚠️

- [ ] `T018` `[US4]` **RED — Test: memory check function exists and returns Bool**
  - **File:** [`app-fourTests/MLXJournalServiceTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/MLXJournalServiceTests.swift)
  - **Action:** Add `@Test func memoryCheckReturnsValue()` — verify that a `checkMemoryHeadroom()` function can be called and returns a `Bool`. Test that on a development machine/Simulator with ample memory, it returns `true`.
  - **Dependencies:** T017 (service must exist)
  - **Validation:** Test compiles but **FAILS** until memory check is implemented.

- [ ] `T019` `[US4]` **RED — Test: model not loaded at init**
  - **File:** [`app-fourTests/MLXJournalServiceTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/MLXJournalServiceTests.swift)
  - **Action:** Add `@Test func modelNotLoadedAtInit()` — verify that after `MLXJournalService()` init, no model is in memory (check `isModelLoaded` property or equivalent).
  - **Dependencies:** T017
  - **Validation:** Test compiles but **FAILS** until lazy loading is implemented.

### Implementation for User Story 4

- [ ] `T020` `[US4]` **GREEN — Implement memory headroom check**
  - **File:** [`app-four/Services/MLXJournalService.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/MLXJournalService.swift)
  - **Action:** Implement `private static func checkMemoryHeadroom(minimumBytes: UInt64 = 200 * 1024 * 1024) -> Bool` — calls `os_proc_available_memory()` and returns `true` if available memory ≥ `minimumBytes`. Import `os` for the function. If headroom insufficient, log a warning and return `false`.
  - **Dependencies:** T018, T019 (tests must FAIL first)
  - **Validation:** T018 turns **GREEN**.

- [ ] `T021` `[US4]` **GREEN — Implement lazy model loading with memory guard**
  - **File:** [`app-four/Services/MLXJournalService.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/MLXJournalService.swift)
  - **Action:** Implement model lifecycle:
    - Use a `class` or `actor` wrapper for mutable model state (since the struct is `nonisolated`, model state needs thread-safe shared storage — e.g., a private `actor ModelHolder` or a class with a lock).
    - `loadModelIfNeeded()` checks `isModelLoaded`, calls `checkMemoryHeadroom()`, and loads Llama weights via MLXLLM's `ModelConfiguration` and `LLMModel.load()` if headroom is sufficient.
    - If memory check fails, throw `SummarizationError.modelNotInstalled` (or a new `.insufficientMemory` case) — caller handles gracefully.
    - Model is retained after first load; subsequent calls skip loading.
  - **Dependencies:** T020, T017
  - **Validation:** T019 turns **GREEN**. Model is not loaded at init. Model loads on first `summarize()` call.

**Checkpoint**: Memory lifecycle is safe. Model loads lazily with memory guard. Graceful abort on low memory.

---

## Phase 5: User Story 2 — SummarizationService Protocol Swap (Priority: P1)

**Goal**: Wire `MLXJournalService` into the DI container, replacing `NLSummarizationService`.

**Independent Test**: Build and run the app — `ProcessingViewModel` and `PendingTranscriptionServiceImpl` call `summarize()` without code changes.

**Rationale for ordering last**: The DI swap is a single line change, but it should only happen after the service is fully implemented and tested. This phase is the "flip the switch" moment.

### Tests for User Story 2 (test-first · RED — MANDATORY) ⚠️

- [ ] `T022` `[US2]` **RED — Test: `MLXJournalService` is `Sendable`**
  - **File:** [`app-fourTests/MLXJournalServiceTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/MLXJournalServiceTests.swift)
  - **Action:** Add `@Test func serviceIsSendable()` — assign `let _: any Sendable = MLXJournalService()`. This is a compile-time check that validates `Sendable` conformance required by the `SummarizationService` protocol.
  - **Dependencies:** T017 (service must exist)
  - **Validation:** Compiles successfully (this is a compile-time conformance check).

- [ ] `T023` `[US2]` **RED — Test: `TagSource.llm` exists**
  - **File:** [`app-fourTests/MLXJournalServiceTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/MLXJournalServiceTests.swift)
  - **Action:** Add `@Test func tagSourceLlmExists()` — `#expect(TagSource.llm.rawValue == "llm")`. Verifies the provenance tag is available.
  - **Dependencies:** T002 (TagSource.llm must be added)
  - **Validation:** Test passes after T002.

### Implementation for User Story 2

- [ ] `T024` `[US2]` **Swap DI binding in AppDependencies**
  - **File:** [`app-four/Store/AppDependencies.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Store/AppDependencies.swift#L27)
  - **Action:** Change line 27 from `static let summarizationService: SummarizationService = NLSummarizationService()` to `static let summarizationService: SummarizationService = MLXJournalService()`. This is the sole DI wiring change.
  - **Dependencies:** T017 (MLXJournalService implemented), T021 (memory lifecycle), T011 (prompt builder)
  - **Validation:** Project builds. `ProcessingViewModel` and `PendingTranscriptionServiceImpl` call `summarize()` via the protocol — no code changes needed in either.

**Checkpoint**: Full end-to-end: transcript → MLXJournalService → SummaryResult. All downstream consumers work unchanged.

---

## Phase 6: User Story 5 — Cold Start Lazy Loading (Priority: P2)

**Goal**: Verify and refine the cold-start behaviour — model loads on first extraction, not at app launch.

**Independent Test**: Launch the app, verify no model in memory. Trigger check-in, verify model loads.

> **Note**: This is largely covered by T019/T021 in Phase 4. Phase 6 adds explicit app-level verification.

- [ ] `T025` `[US5]` **Integration test: app launches without loading Llama**
  - **File:** [`app-fourTests/MLXJournalServiceTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/MLXJournalServiceTests.swift)
  - **Action:** Add `@Test func coldStartDoesNotLoadModel() async` — create `MLXJournalService()`, verify `isModelLoaded == false`. This confirms lazy loading works at the service level.
  - **Dependencies:** T021
  - **Validation:** Test passes. Model memory footprint at app launch is zero.

**Checkpoint**: Cold start verified — model only loads on first extraction.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final cleanup, documentation, and full test suite run.

- [ ] `T026` `[P]` `[Polish]` **Run full test suite and verify all GREEN**
  - **File:** N/A (test runner)
  - **Action:** Run `xcodebuild test` for the `app-four` scheme. Verify all existing tests pass (no regressions) and all new tests (T003–T025) pass.
  - **Dependencies:** All previous tasks
  - **Validation:** Full suite green. Zero test failures.

- [ ] `T027` `[P]` `[Polish]` **Verify build succeeds for release configuration**
  - **File:** N/A (build system)
  - **Action:** Run `xcodebuild build -scheme app-four -configuration Release` to verify no release-only build issues (dead code stripping, optimisation-level differences).
  - **Dependencies:** T024
  - **Validation:** Release build succeeds with no errors or warnings.

- [ ] `T028` `[Polish]` **Commit and push branch**
  - **File:** N/A (git)
  - **Action:** Stage all changes, commit with message `feat(043): MLXJournalService — on-device LLM extraction via MLX-Swift`. Push `feat/043-mlx-journal-service` branch.
  - **Dependencies:** T026, T027
  - **Validation:** Branch pushed. Ready for `/code-review`.

---

## Phase 8: Convergence

- [x] `T029` `[US1]` **Implement actual MLX-Swift LLM generation per FR-EXT-01 (missing)**
  - **File:** `app-four/Services/MLXJournalService.swift`
  - **Action:** Replace mocked `rawJSON` with actual MLX-Swift `generate()` call.
  - **Dependencies:** T017
- [x] `T030` `[US4]` **Implement actual MLX-Swift LLMModel lazy loading per FR-EXT-06 and FR-EXT-07 (missing)**
  - **File:** `app-four/Services/MLXJournalService.swift`
  - **Action:** Replace mocked model loading in `ModelHolder` with actual `LLMModelFactory.shared.loadContainer(configuration:)`.
  - **Dependencies:** T021

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately. T001 and T002 run in parallel.
- **Phase 2 (US3 — Prompt Builder)**: Depends on T001 for build. Tests T003–T010 can be written before T001 completes (they'll fail at compile time, which is expected for RED).
- **Phase 3 (US1 — Core Service)**: Depends on T011 (prompt builder). Tests T012–T015 can be written in parallel with Phase 2.
- **Phase 4 (US4 — Memory)**: Depends on T017 (core service).
- **Phase 5 (US2 — DI Swap)**: Depends on T017, T021. This is the "flip the switch" — must be last production change.
- **Phase 6 (US5 — Cold Start)**: Depends on T021. Can run in parallel with Phase 5.
- **Phase 7 (Polish)**: Depends on all previous phases.

### Critical Path

```
T001 (SPM deps) → T011 (prompt builder) → T017 (core service) → T021 (memory lifecycle) → T024 (DI swap) → T026 (full test)
```

### Within Each User Story

- Tests MUST be written, RUN, and confirmed FAILING (RED) before implementation (GREEN); refactor after green (Principle X)
- Prompt builder before service (US3 before US1)
- Memory lifecycle before DI swap (US4 before US2)
- Story complete before moving to next priority

### Parallel Opportunities

- T001 and T002 can run in parallel (Phase 1)
- T003–T010 can all be written in parallel (same file, different test functions)
- T012–T015 can be written in parallel with Phase 2 implementation
- T022–T023 can be written in parallel
- T025 can run in parallel with T024

---

## Implementation Strategy

### MVP First (US3 + US1 + US2)

1. Complete Phase 1: Setup (SPM + TagSource)
2. Complete Phase 2: Prompt Builder (fully tested, no MLX needed)
3. Complete Phase 3: Core Service (inference path)
4. **STOP and VALIDATE**: Run all tests, verify extraction works on Simulator
5. Complete Phase 5: DI Swap (flip the switch)
6. Deploy/demo if ready

### Incremental Delivery

1. Setup → Prompt builder tested → Core service tested → MVP ready
2. Add memory lifecycle → Robust on low-memory devices
3. DI swap → Full integration
4. Each phase adds value without breaking previous phases

---

## Notes

- `[P]` tasks = different files, no dependencies
- `[Story]` label maps task to specific user story for traceability
- Each user story is independently completable and testable
- Verify tests FAIL (RED) before implementing; never write implementation ahead of its test (Principle X)
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- `nonisolated struct` for `MLXJournalService` to match `NLSummarizationService` style
- `enum MLXPromptBuilder` (caseless) to prevent accidental instantiation
- Use `CaseIterable` for all label enumerations — never hardcode signal strings
- `Task.detached(priority: .userInitiated)` for off-main-actor inference (matching legacy pattern)
