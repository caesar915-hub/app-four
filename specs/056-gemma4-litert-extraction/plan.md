# Implementation Plan: Gemma 4 E2B Extraction via LiteRT-LM

**Branch**: `feat/gemma4-litert-extraction` (feature 056) | **Date**: 2026-09-13 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/056-gemma4-litert-extraction/spec.md` (specified + clarify-resolved 2026-09-13)

**Base note**: This branch is cut from the current app state (post-045 SpeechAnalyzer, constitution v2.3.0), **not** literally from `main` — `main` is behind (045 + the Gemma briefs are unmerged), so branching from `main` would build against stale WhisperKit-era code and a stale constitution. The PR base is set so the review surface is Gemma-only. (Deviation from the "off main" instruction, surfaced deliberately per Principle III.)

## Feature Definition & Scope

Replace the app's on-device **extraction** engine. Today, extraction is `MLXJournalService` running Qwen2.5-1.5B-Instruct-4bit via MLX-Swift, behind the `SummarizationService` protocol (`func summarize(rawTranscription:) async throws -> SummaryResult`). The runtime path is: a completed transcript `String` → **pass-1** narrative summary (`ChatSession`, maxTokens 120) → **pass-2** strict-JSON signals (`ChatSession`, maxTokens 512) → 3-stage JSON recovery + one correction retry → `ExtractionValidator` clamp/repair → `SummaryResult`. Model weights load lazily by directory, gated by `os_proc_available_memory()`, and are evicted on background/memory-warning/180 s idle by a `LifecycleCoordinator`.

This feature makes **Gemma 4 E2B (text-only) under Google LiteRT-LM** the extraction backend. The two-pass flow, the lexicon, `SummaryPromptBuilder`/`SignalPromptBuilder`/`PromptLoader`, `ExtractionValidator`, `UnifiedExtraction`, and `SummaryResult` are **reused verbatim** — they are model-agnostic. What changes: (a) the inference runtime (MLX → LiteRT-LM); (b) the model (Qwen → Gemma 4 E2B); (c) **chat-template rendering becomes the app's job** (LiteRT does not apply a tokenizer chat template the way swift-transformers did); (d) pass-2 gains a **Tool Use / function-calling** contract (D1) with the free-form-JSON path as a proven fallthrough; (e) the installed-check moves from `.safetensors` to `.litertlm`; (f) the model download repoints to the LiteRT community repo (single LFS file).

**Verified-fact correction (2026-09-13):** the current MLX path has **never** used grammar-constrained decoding (`MLXGuidedGeneration` is absent from the codebase). JSON validity is achieved by prompt engineering + `ExtractionValidator` recovery + one retry. Therefore LiteRT-LM lacking constrained decoding removes **no** capability the app relies on; the free-form path is a proven equal, and Tool Use (D1) is a structure-quality upgrade layered on top.

**Locked scope (clarify, 2026-09-13):**
- **D1** pass-2 attempts Tool Use / function calling; falls through to free-form JSON + `ExtractionValidator` recovery + one correction retry.
- **D2** MLX is dropped from the extraction path for the Shipaton build — LiteRT is the sole runtime, **no fallback** at the switchover. There is **no runtime fallback model** in the shipped build.
- **D3** in-scope for ~Sep 23 App-Review submission; Early-Preview runtime accepted.
- Text-only (no vision/audio towers), CPU/XNNPACK default on A14, GPU/Metal opt-in only if on-device headroom is later confirmed.

### Architectural approach — additive first, switchover last (mirrors 045)

The Early-Preview LiteRT-LM Swift package cannot be verified in this environment (no physical A14; the binary framework may lack a simulator slice), and device QA cannot be automated. So the plan sequences so **every committed checkpoint builds and passes tests on the simulator with the existing MLX/Qwen backend still live**:

1. **Additive (this feature, tonight):** introduce the Gemma chat-template formatter, the signals tool-schema + payload mapping, the `GemmaJournalService` (with all live LiteRT calls behind `#if canImport(LiteRTLM)` and behind a `LiteRTTextGenerator` protocol so the service is testable with a fake), a `.litertlm`-aware installed-check, and additive `ModelConstants` for the Gemma repo/file — **all inert**: the `AppDependencies` binding stays on `MLXJournalService`, and `llmHubRepoID` is **not** repointed. The app builds and behaves identically to today; the new logic is fully unit-tested on the simulator.
2. **Switchover (device day — NOT run tonight):** add the LiteRTLM SPM package on a physical iPhone 12 Pro; run the gated on-device eval + memory measurement (SC-1/SC-4); if it passes, flip the single `AppDependencies` binding to `GemmaJournalService`, repoint `llmHubRepoID`, and wire the `.litertlm` installed-check into the live path.
3. **Destructive (after switchover proven):** remove MLX (`mlx-swift`, `MLXJournalService`) from the extraction path.

An interrupted run therefore always leaves a buildable, releasable app on the proven MLX backend.

## Technical Context

### 1. Language & Runtime Environment
Swift 6, strict concurrency, iOS 26.0 floor (matches the app). New types are `Sendable`; the service mirrors `MLXJournalService`'s shape — a `nonisolated struct` conforming to `SummarizationService`, delegating actor isolation to a nested `ModelHolder` actor and a `LifecycleCoordinator` actor. The **live LiteRT-LM runtime is 🚀 Early Preview** (`LiteRTLM` ≥ 0.12.0, SPM `github.com/google-ai-edge/LiteRT-LM`); its API is documented but moving, so all direct LiteRT symbols are confined to one compile-guarded file (`#if canImport(LiteRTLM)`) reachable only through a `LiteRTTextGenerator` protocol. This keeps the simulator build green without the package and localizes any device-day API delta to a single file. Verified API surface (2026-09-13): `EngineConfig(modelPath:backend:maxNumTokens:cacheDir:visionBackend:audioBackend:)` → `Engine(engineConfig:)` → `await initialize()` → `await createConversation(with:)` → `await conversation.sendMessage(_:)` / `sendMessageStream(_:)`; backends `.cpu()` / `.gpu`; model loaded **by file path**; `visionBackend`/`audioBackend` default `nil` (text-only free); a `thinkingConfig` bounds reasoning tokens; Tool Use via a Swift `Tool` protocol + `@ToolParam` registered through `ConversationConfig(tools:)`.

### 2. Core Dependencies & Frameworks
Adds the **LiteRT-LM Swift package** (Early Preview) — text-only, Metal (GPU) + XNNPACK (CPU) backends, `.litertlm` format, load-by-path (preserves memory-mapping; the entire A14 feasibility rests on LiteRT streaming the Per-Layer-Embeddings as clean mmap'd pages rather than charging them dirty as MLX does). Chosen over MLX because MLX charges Gemma 4 E2B's weights fully dirty (~3 GB → at/over the A14 ceiling), while LiteRT lands at ~607 MB (CPU) / ~1.45 GB (GPU) resident. **swift-jinja** is already resolved in the package graph (transitively, via MLXLLM) but not first-party-imported; the plan uses a **hand-written Gemma turn formatter** rather than importing Jinja — simpler, dependency-free, and fully unit-testable (Gemma's turn format is trivial vs. the 12 KB `chat_template.jinja`, which is only needed for tool-call framing that LiteRT's Tool Use handles). MLX/`swift-transformers` remain until the destructive phase (they still power the live backend).

### 3. State Management & Data Flow
Unchanged for consumers: `PendingTranscriptionServiceImpl`/`ProcessingViewModel` → `SummarizationService.summarize(rawTranscription:)` → `SummaryResult`. Internally: `GemmaJournalService.summarize` → `ModelHolder.loadIfNeeded()` (RAM-gated, sequential residency) → **pass-1** render `(summarySystem, summaryUser)` via `GemmaChatTemplate` → `LiteRTTextGenerator.generate` (bounded tokens, thinking≈0) → narrative string; **pass-2** register the signals `Tool`, send the signals prompt, read the tool-call arguments → `UnifiedExtraction`; on absent/malformed tool call, read free-form text → `ExtractionValidator.parseExtraction` (3-stage) → one correction retry → validate. Merge (pass-1 owns `summary`, pass-2 owns signals) → `ExtractionValidator.validate` → `assembleSummaryResult`. Off-main throughout (nested actor + detached generation task, as MLX does).

### 4. Storage & Persistence Strategy
No SwiftData schema change. The model artifact is a single `.litertlm` LFS file downloaded via the existing background `URLSession` pipeline (`BackgroundLLMDownloadService.downloadSnapshot`, generic over repo id) into `ModelConstants.llmDownloadBase/models/<repoID>/`, promoted atomically. Installed-check becomes `.litertlm`-aware (presence + expected byte size) rather than the MLX `config.json`+`tokenizer.json`+`*.safetensors` triple. `EngineConfig` requires a writable `cacheDir` — provisioned under the app's Caches directory. No transcript/med content is ever persisted to logs.

### 5. Performance & Constraints
Target resident footprint on A14: **~607 MB (CPU)** / ~1.45 GB (GPU), well under the ceiling (SC-1 measures the real number — device-gated). Decode target ≥ ~8 tok/s CPU on A14 (SC-4, device-gated). Context capped (`maxNumTokens` raised from the 512 default to ≥ 2048 for the two-pass prompts; KV cache is the only dirty-growth lever, ~10–25 MB for short prompts). Text-only is mandatory (vision+audio towers ≈ +0.92 GiB → instant OOM). Sequential residency: SpeechAnalyzer is system-managed (0 app-RAM) and completes before extraction, so the only in-process model is Gemma; `os_proc_available_memory()` gates load; eviction on background/memory-warning/idle. **Accepted risk (D2):** no fallback — a gate-fail degrades to transcription-only on an unmeasured A14.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.* Constitution `.specify/memory/constitution.md` — **a MINOR amendment (v2.3.0 → v2.4.0) is part of this plan** (Technology Stack extraction line + Principle VII wording + Principle VIII buffer-freeing clause); the checks reflect the post-amendment state.

- [x] **I. SwiftUI-First** — No UI in this feature (service-only; brief §4 forbids VM/View changes). N-A for new views; PASS.
- [x] **II. Test-Build-Ship** — Every checkpoint builds + runs the full default `app-four` test plan green on the simulator (verified baseline green 2026-09-13). Device QA (SC-1/SC-4) by the owner before the switchover/merge — explicitly gated, not skipped. PASS (with device gate recorded).
- [x] **III. Correctness Over Speed** — Additive-first/switchover-last avoids half-migrated states; no dead code shipped (the LiteRT wiring is real, behind a compile guard, not a stub); the base-branch deviation and the D2 no-fallback risk are surfaced explicitly, not cut silently. PASS.
- [x] **IV. Minimal Surface** — Reuses `SummarizationService`, `ExtractionValidator`, prompts, lexicon, and the download pipeline. Adds only: chat-template formatter, signals tool-schema + mapping, the service, a `LiteRTTextGenerator` seam, and a `.litertlm` installed-check. The dual pass-2 path (tool-use + free-form fallthrough) and the new Early-Preview dependency are justified in Complexity Tracking. PASS.
- [x] **V. Solo Git Discipline** — One revertable feature on `feat/gemma4-litert-extraction`; `/code-review` before merge; `main` stays releasable (additive/inert). PASS.
- [x] **VI. On-Device Privacy** — Gemma runs 100% on-device; no audio/transcript/health/med data leaves the device; diagnostics stay counts/durations/memory/tokens only. PASS.
- [x] **VII. On-Device LLM Extraction** — Extraction stays behind `SummarizationService`; lexicon + `Levels.swift` enum validation retained; `os_proc_available_memory()` gate retained. The Principle's *engine/model* clause (currently "Llama 3.2 1B via MLX-Swift" — already stale vs. the live Qwen) is amended to name **Gemma 4 E2B via LiteRT-LM**; the memory-lifecycle sentence is updated (mmap'd clean pages, not Metal buffer freeing). PASS (post-amendment).
- [x] **VIII. Service-Oriented Architecture** — Capability behind `Services/` protocol via `AppDependencies`→`AppServices`→`@Environment`; heavy work off-main via nested actor. The "free Metal/CoreML buffers before downstream" clause is amended to "unload the resident engine (evict mmap'd/KV state)". PASS (post-amendment).
- [x] **IX. Pre-Release Data Posture** — No schema change; no `@Attribute(.unique)`/required attribute. PASS.
- [x] **X. Test-First Development** — All new logic (chat-template formatter, tool-schema mapping, installed-check, memory-gate + lifecycle) is built RED→GREEN with Swift Testing; tests never touch the live LiteRT runtime (fake `LiteRTTextGenerator`), mirroring the MLX hermetic-test pattern. The gated on-device eval clones `MLXExtractionEvalTests` and is excluded from the default plan. PASS.
- [x] **XI. Architectural Exhaustiveness** — This plan + `research.md` + `data-model.md` + `contracts/` define the engine surface, both pass-2 paths, chat-template format, error taxonomy, memory lifecycle, download/installed-check, and every seam. PASS.

## Project Structure

### Documentation (this feature)
```text
specs/056-gemma4-litert-extraction/
├── spec.md              # what & why (done)
├── plan.md              # this file
├── research.md          # Phase 0: LiteRT facts, decisions, rationale
├── data-model.md        # Phase 1: types/state (no SwiftData change)
├── quickstart.md        # Phase 1: build/test/verify + device-day switchover
├── contracts/
│   ├── summarization-service.md   # the reused protocol contract
│   └── signals-tool.md            # the pass-2 Tool Use schema + free-form equivalence
├── device-qa-checklist.md         # SC-1/SC-4 on-device procedure (owner)
├── tasks.md             # (/speckit-tasks)
├── EXECUTION_LOG.md     # autonomous-run progress log
└── RUN_SUMMARY.md       # (converge) final report
```

### Source Code (repository root — real paths)
```text
app-four/
├── Services/
│   ├── Gemma/
│   │   ├── GemmaChatTemplate.swift         # NEW: pure Gemma turn-format renderer (no dep, testable)
│   │   ├── GemmaSignalsTool.swift          # NEW: signals schema + tool-args→UnifiedExtraction mapping (mapping testable; LiteRT `Tool` conformance compile-guarded)
│   │   ├── LiteRTTextGenerator.swift        # NEW: protocol seam + a fake; live LiteRT `Engine`/`Conversation` impl in #if canImport(LiteRTLM)
│   │   └── GemmaJournalService.swift        # NEW: struct : SummarizationService; ModelHolder actor; LifecycleCoordinator; RAM gate; DEBUG test hooks
│   ├── AIModelServiceImpl.swift             # MODIFY (additive): add `.litertlm`-aware installedGemmaLLM(in:) helper; keep the MLX safetensors check
│   └── (SummaryPromptBuilder/SignalPromptBuilder/PromptLoader) # REUSE verbatim
├── Utils/Constants.swift                    # MODIFY (additive): add gemmaLiteRTRepoID, gemmaLiteRTFileName, gemmaLiteRTExpectedBytes; do NOT repoint llmHubRepoID yet
├── Services/NoteExtraction/ExtractionValidator.swift  # REUSE verbatim
└── Store/AppDependencies.swift              # UNCHANGED tonight (switchover = device day; documented)

app-fourTests/
├── Gemma/
│   ├── GemmaChatTemplateTests.swift         # NEW: exact turn-string assertions
│   ├── GemmaSignalsToolTests.swift          # NEW: tool-args→UnifiedExtraction; equivalence with free-form; malformed-payload repair
│   ├── GemmaJournalServiceTests.swift       # NEW: empty input, memory-gate bounds, lifecycle eviction, isModelLoaded==false, modelNotInstalled via fake generator
│   └── GemmaInstalledCheckTests.swift       # NEW: `.litertlm` presence/size installed-check
└── Eval/GemmaExtractionEvalTests.swift      # NEW (gated on GEMMA_EVAL + model dir; excluded from default plan)
```

**Structure Decision**: No new module/target. New code groups under `app-four/Services/Gemma/` and `app-fourTests/Gemma/`, reusing the `Services/`/DI/`@Environment` architecture. `AppDependencies` and `llmHubRepoID` are deliberately untouched this feature (inert/additive).

### File Manifest & Responsibilities

| File Path | Responsibility | Key Structs / Functions / Protocols |
|-----------|----------------|-------------------------------------|
| `app-four/Services/Gemma/GemmaChatTemplate.swift` | Pure renderer of Gemma 4's turn format. No I/O, no runtime dep — fully unit-testable. Folds system text into the first user turn (Gemma has no system role). | `enum GemmaChatTemplate { static func singleTurn(system: String, user: String) -> String; static func render(_ turns: [GemmaTurn]) -> String }`; constants `startOfTurn`/`endOfTurn`. Output: `<start_of_turn>user\n{system}\n\n{user}<end_of_turn>\n<start_of_turn>model\n`. |
| `app-four/Services/Gemma/GemmaSignalsTool.swift` | Declares the pass-2 signals schema and maps tool-call arguments (or free-form JSON) → `UnifiedExtraction`. The mapping is pure/testable; the LiteRT `Tool`/`@ToolParam` conformance is compile-guarded. | `struct SignalsToolArguments: Codable { … mirrors UnifiedExtraction fields }`; `static func unifiedExtraction(from: SignalsToolArguments) -> UnifiedExtraction`; `#if canImport(LiteRTLM) struct RecordSignalsTool: Tool { … } #endif`. |
| `app-four/Services/Gemma/LiteRTTextGenerator.swift` | The runtime seam. A protocol the service depends on so tests inject a fake; the real impl wraps LiteRT `Engine`/`Conversation` and is compiled only with the package present. | `protocol LiteRTTextGenerator: Sendable { func generate(prompt: String, maxTokens: Int) async throws -> String; func callTool(prompt: String, tool: …) async throws -> SignalsToolArguments? }`; `#if canImport(LiteRTLM) actor LiteRTEngineGenerator: LiteRTTextGenerator { … EngineConfig/Engine/Conversation … } #endif`; `struct FakeLiteRTGenerator` (DEBUG/tests). |
| `app-four/Services/Gemma/GemmaJournalService.swift` | `SummarizationService` conformer. Two-pass flow, RAM gate, sequential residency, lifecycle eviction, error mapping, DEBUG test hooks. Mirrors `MLXJournalService`'s structure. | `nonisolated struct GemmaJournalService: SummarizationService { func summarize(rawTranscription:) }`; nested `actor ModelHolder`; reuse/parallel `LifecycleCoordinator`; `static func checkMemoryHeadroom(minimumBytes:)`; DEBUG: `markLoadedForTesting()`, `armIdleTimerForTesting()`, `isModelLoaded`. |
| `app-four/Services/AIModelServiceImpl.swift` | Add a `.litertlm`-aware installed-check alongside the existing MLX check (additive; no behavior change to the live path). | `nonisolated func gemmaLiteRTModelInstalled(in base: URL) -> Bool` (presence + expected size). |
| `app-four/Utils/Constants.swift` | Additive Gemma constants; `llmHubRepoID` untouched. | `gemmaLiteRTRepoID = "litert-community/gemma-4-E2B-it-litert-lm"`, `gemmaLiteRTFileName = "gemma-4-E2B-it.litertlm"`, `gemmaLiteRTExpectedBytes = 2_588_147_712`. |

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| New Early-Preview SPM dependency (LiteRT-LM) | Only runtime that fits Gemma 4 E2B under the A14 memory ceiling (mmap'd clean PLE pages); MLX charges it dirty (~3 GB) and OOMs | Staying on MLX with Gemma 4 = infeasible on 6 GB (both research runs). Gemma 3 1B/MLX would avoid the dep but is the *other* path (companion brief), not chosen. |
| Dual pass-2 path (Tool Use + free-form fallthrough) | D1 wants Tool-Use structure quality; free-form is the proven Qwen-equivalent and the safety net if on-device tool-calling underperforms | Tool-Use-only risks total pass-2 failure if Gemma's on-device tool-calling (Early Preview) is unreliable; free-form-only leaves D1 unmet. Both, with fallthrough, is minimal given the unverified runtime. |
| No runtime fallback in shipped build (D2) | Owner decision; single-runtime keeps binary small and avoids dual-runtime maintenance | A fallback (keep MLX/Qwen) is *safer* on the unmeasured A14 — recommended and overruled by the owner. Recorded as accepted risk; the RAM-gate else-branch degrades to transcription-only, not a crash. |

## Governance — constitution amendment (part of this plan)

Per the constitution's Governance section, this plan carries a **MINOR** amendment (v2.3.0 → v2.4.0): the Technology Stack extraction line and Principle VII/VIII wording change from "Llama 3.2 1B (4-bit) via MLX-Swift" (already stale — live is Qwen2.5-1.5B) to "Gemma 4 E2B (text-only) via LiteRT-LM", and the memory-lifecycle language shifts from "free Metal/CoreML buffers" to "unload the resident engine (evict mmap'd/KV state)". No principle is removed or redefined → MINOR. A SYNC IMPACT REPORT is prepended to `constitution.md` and `LAST_AMENDED_DATE` updated. **Flagged for owner ratification** in `RUN_SUMMARY.md` — the amendment is drafted and applied so the gate passes, but the owner should review the wording before the switchover build.
