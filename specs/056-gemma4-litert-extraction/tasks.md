---
description: "Task list — Gemma 4 E2B via LiteRT-LM (056)"
---

# Tasks: Gemma 4 E2B Extraction via LiteRT-LM

**Input**: Design documents from `/specs/056-gemma4-litert-extraction/`

**Tests**: Test-first is MANDATORY for logic (Principle X) — write the test, RUN it, confirm **RED**, then implement to **GREEN**, then refactor. Swift Testing (`@Test`/`#expect`). No test touches the live LiteRT runtime (fake `LiteRTTextGenerator`; no `.litertlm` loaded).

**Execution note (autonomous run 2026-09-13):** Phases 1–7 are implemented tonight on the simulator, additive/inert (DI unchanged, `llmHubRepoID` unchanged). Phases 8–9 (**device-gated switchover + destructive MLX removal**) are **NOT run tonight** — they require a physical iPhone 12 Pro (SC-1/SC-4) and owner QA.

---

## Phase 1: Setup

- [ ] `T001` **Create Gemma source + test groups**
  - **File:** `app-four/Services/Gemma/` and `app-fourTests/Gemma/` (folders created implicitly by first file in each)
  - **Action:** Establish the module grouping per plan.md Project Structure. No code.
  - **Validation:** Paths exist after first file lands.

---

## Phase 2: US3 — Gemma chat-template rendering (Priority: P1)

**Goal:** Pure, dependency-free renderer of Gemma's turn format. Foundational for the service.

### Tests (RED — MANDATORY) ⚠️
- [ ] `T002` `[US3]` **Chat-template tests (RED)**
  - **File:** `app-fourTests/Gemma/GemmaChatTemplateTests.swift`
  - **Action:** Assert `GemmaChatTemplate.singleTurn(system:user:)` returns exactly `"<start_of_turn>user\n{system}\n\n{user}<end_of_turn>\n<start_of_turn>model\n"`; assert `render([.user(a), .model(b), .user(c)])` interleaves role markers and appends the trailing `<start_of_turn>model\n`; assert empty system folds cleanly (no leading blank block).
  - **Validation:** Tests compile and FAIL (type/methods absent).

### Implementation
- [ ] `T003` `[US3]` **GemmaChatTemplate**
  - **File:** `app-four/Services/Gemma/GemmaChatTemplate.swift`
  - **Action:** `enum GemmaChatTemplate` with `startOfTurn`/`endOfTurn` constants, `struct GemmaTurn { enum Role: String { case user, model }; let role; let text }`, `singleTurn(system:user:)`, `render(_:)`. Fold system into the first user turn (no system role).
  - **Dependencies:** T002
  - **Validation:** T002 GREEN.

---

## Phase 3: US4 — Pass-2 signals tool schema + mapping (Priority: P2, built early — pure)

**Goal:** Typed pass-2 payload and its `UnifiedExtraction` mapping; free-form equivalence.

### Tests (RED) ⚠️
- [ ] `T004` `[US4]` **Signals mapping tests (RED)**
  - **File:** `app-fourTests/Gemma/GemmaSignalsToolTests.swift`
  - **Action:** (a) `SignalsToolArguments` decodes from the exact signals JSON keys; (b) `SignalsTool.unifiedExtraction(from:)` maps field-for-field to `UnifiedExtraction` (collections default `[]`, no clamping); (c) **convergence invariant** — for a representative payload, `unifiedExtraction(from: args)` equals `ExtractionValidator.parseExtraction(from: equivalentJSON)`; (d) malformed/missing fields degrade gracefully (nil/empty), never throw.
  - **Validation:** Compiles, FAILS.

### Implementation
- [ ] `T005` `[US4]` **SignalsToolArguments + mapping**
  - **File:** `app-four/Services/Gemma/GemmaSignalsTool.swift`
  - **Action:** `struct SignalsToolArguments: Codable, Sendable` mirroring `UnifiedExtraction` keys; `static func unifiedExtraction(from:) -> UnifiedExtraction`. Add the compile-guarded `#if canImport(LiteRTLM) struct RecordSignalsTool: Tool { @ToolParam … func run() … } #endif` (not compiled on sim).
  - **Dependencies:** T004
  - **Validation:** T004 GREEN.

---

## Phase 4: US5 — `.litertlm` installed-check + constants (Priority: P2, pure)

### Tests (RED) ⚠️
- [ ] `T006` `[US5]` **Installed-check tests (RED)**
  - **File:** `app-fourTests/Gemma/GemmaInstalledCheckTests.swift`
  - **Action:** Given a temp dir with a stub file named `gemma-4-E2B-it.litertlm` of the expected size → `installed == true`; absent or wrong-size → `false`. Uses a temp base URL (no network).
  - **Validation:** Compiles, FAILS.

### Implementation
- [ ] `T007` `[US5]` **Constants (additive) + installed-check**
  - **File:** `app-four/Utils/Constants.swift`, `app-four/Services/AIModelServiceImpl.swift`
  - **Action:** Add `gemmaLiteRTRepoID`, `gemmaLiteRTFileName`, `gemmaLiteRTExpectedBytes` to `ModelConstants` (do NOT touch `llmHubRepoID`). Add `nonisolated func gemmaLiteRTModelInstalled(in base: URL) -> Bool` to `AIModelServiceImpl` (presence + size; mirror `findLLMModelDirectory` style, keep the MLX check intact).
  - **Dependencies:** T006
  - **Validation:** T006 GREEN; existing `AIModelServiceImplTests` still green.

---

## Phase 5: US6/US2 — Runtime seam + fake generator (Priority: P1 foundation)

### Tests (RED) ⚠️
- [ ] `T008` `[US2]` **Fake generator + seam tests (RED)**
  - **File:** `app-fourTests/Gemma/GemmaJournalServiceTests.swift` (seam portion)
  - **Action:** Define expectations against `LiteRTTextGenerator`: a `FakeLiteRTGenerator` returns scripted text/tool-args; assert the service can be constructed with an injected fake.
  - **Validation:** Compiles, FAILS (types absent).

### Implementation
- [ ] `T009` `[US6]` **LiteRTTextGenerator protocol + Fake + guarded real impl**
  - **File:** `app-four/Services/Gemma/LiteRTTextGenerator.swift`
  - **Action:** `protocol LiteRTTextGenerator: Sendable { func generate(prompt:maxTokens:) async throws -> String; func callSignalsTool(prompt:) async throws -> SignalsToolArguments? }`. `struct FakeLiteRTGenerator` (test/DEBUG). `#if canImport(LiteRTLM) actor LiteRTEngineGenerator: LiteRTTextGenerator { … EngineConfig(modelPath:backend:.cpu():maxNumTokens:cacheDir:) → Engine → initialize → createConversation → sendMessage; thinking≈0; text-only … } #endif`.
  - **Dependencies:** T008, T005 (SignalsToolArguments)
  - **Validation:** T008 GREEN on sim (fake path); real impl compiles only with the package (device day).

---

## Phase 6: US1/US2/US6 — GemmaJournalService (Priority: P1) 🎯 MVP

### Tests (RED) ⚠️
- [ ] `T010` `[US1]` **Service behaviour tests (RED)**
  - **File:** `app-fourTests/Gemma/GemmaJournalServiceTests.swift`
  - **Action:** With an injected `FakeLiteRTGenerator`: (a) empty/whitespace transcript → empty result, generator NOT called; (b) scripted pass-1 + tool-call pass-2 → validated `SummaryResult` with expected mood/energy/focus/meds; (c) fake emits no tool call but valid free-form JSON → same result via fallthrough; (d) fake emits garbage twice → non-fatal, `SummaryResult` still returns raw transcript as bullet; (e) `checkMemoryHeadroom(minimumBytes:)` bounds (`Int.max` → false, `1` → true); (f) `isModelLoaded == false` at init; (g) idle-timer eviction via DEBUG hooks + fresh `NotificationCenter()`; (h) installed-check absent → `.modelNotInstalled` thrown.
  - **Validation:** Compiles, FAILS.

### Implementation
- [ ] `T011` `[US1]` **GemmaJournalService**
  - **File:** `app-four/Services/Gemma/GemmaJournalService.swift`
  - **Action:** `nonisolated struct GemmaJournalService: SummarizationService`. Build prompts eagerly (reuse `SummaryPromptBuilder`/`SignalPromptBuilder`/`LexiconLoader`). Nested `actor ModelHolder` (holds an injected `LiteRTTextGenerator`; `loadIfNeeded()` dedup; installed + headroom guards; `evict()`). `LifecycleCoordinator` (reuse the MLX pattern: memory-warning/background/idle → evict). `summarize`: empty guard → load → pass-1 (`GemmaChatTemplate.singleTurn` + `generate`) → pass-2 (`callSignalsTool` → `SignalsTool.unifiedExtraction`; else free-form `ExtractionValidator.parseExtraction` + one correction retry) → merge → `ExtractionValidator.validate` → `assembleSummaryResult`. Map errors to `SummarizationError`. DEBUG test hooks (parity with MLX). Init takes an optional generator factory (default: the guarded real impl if available, else a generator that throws `.modelNotInstalled`).
  - **Dependencies:** T003, T005, T007, T009, T010
  - **Validation:** T010 GREEN; full default test plan GREEN.

---

## Phase 7: US1 — Gated on-device eval harness (Priority: P1 quality; device-run)

- [ ] `T012` `[US1]` **Gemma eval suite (gated) + test plan**
  - **File:** `app-fourTests/Eval/GemmaExtractionEvalTests.swift`, `app-four-gemma-eval.xctestplan`
  - **Action:** Clone `MLXExtractionEvalTests` pattern: gate on `GEMMA_EVAL=1` AND `gemmaLiteRTModelInstalled`; reuse `MLXEvalSet.cases`; micro-averaged P/R vs `MLXEvalFloors`; on-device memory gate (phys_footprint load/reclaim). Add the xctestplan (excluded from default `app-four` plan).
  - **Dependencies:** T011
  - **Validation:** Compiles + is SKIPPED under the default plan on the simulator (gate off); runs on device with `GEMMA_EVAL=1`.

**Checkpoint (end of tonight): default `app-four` test plan GREEN on the simulator; app builds; behaviour identical to today (MLX/Qwen live).**

---

## Phase 8: US2 — Switchover (⚠️ DEVICE-GATED — NOT run tonight)

- [ ] `T013` `[US2]` **Add LiteRTLM SPM package** (device) — add `github.com/google-ai-edge/LiteRT-LM`, product `LiteRTLM` ≥ 0.12.0, to the `app-four` target; reconcile any API delta in `LiteRTTextGenerator.swift` only.
- [ ] `T014` `[US2]` **Device eval + memory gate** — run `device-qa-checklist.md`; record SC-1/SC-2/SC-2a/SC-3/SC-4. Go/no-go.
- [ ] `T015` `[US2]` **Flip the binding** — `AppDependencies.summarizationService = GemmaJournalService()`; repoint `ModelConstants.llmHubRepoID = gemmaLiteRTRepoID`; wire `gemmaLiteRTModelInstalled` into the live download/preflight. Single reversible change set.

---

## Phase 9: Destructive (⚠️ AFTER switchover proven on device — NOT run tonight)

- [ ] `T016` **Remove MLX from the extraction path** — delete `MLXJournalService`, drop `mlx-swift` from the extraction dependency (keep only if another consumer needs it), remove dead constants. One revertable commit, full suite green.

---

## Dependencies & Execution Order
- Phase 1 → 2 → 3 → 4 → 5 → 6 → 7 (tonight, sequential; each RED→GREEN, commit per task).
- Phases 8–9 device-gated, owner-run, after SC gates pass.
- Within each story: test (RED) before implementation (GREEN); pure types (template, mapping, constants, seam) before the service that composes them.

## Notes
- Commit after each GREEN task.
- The real LiteRT calls live only in `#if canImport(LiteRTLM)` blocks — the simulator build never compiles them, so the default plan stays green without the package.
- Never repoint `llmHubRepoID` or flip DI tonight — that is the device-gated switchover.
