# Phase 0 Research — Gemma 4 E2B via LiteRT-LM

All items resolved 2026-09-13 (research + `/speckit-clarify`). Primary sources: LiteRT-LM repo + Google AI Edge docs (WebFetch), HuggingFace tree API, and the codebase map. Full risk record: [brief §10](../../docs/engineering/gemma4-e2b-litertlm-integration-brief.md).

## Decisions

| # | Decision | Rationale | Alternatives rejected |
|---|----------|-----------|-----------------------|
| R1 | Runtime = **LiteRT-LM** (Early Preview, `LiteRTLM` ≥ 0.12.0) | Only runtime that fits Gemma 4 E2B under the A14 ceiling: mmaps weights + streams the PLE as **clean** pages (~607 MB CPU / ~1.45 GB GPU resident). iOS jetsam counts dirty+compressed+wired, not clean mmap'd file pages. | MLX: charges all weights dirty (~3 GB) → OOM. llama.cpp GGUF: ~3.35–3.85 GB, needs increased-memory entitlement; kept only as a documented last-resort. |
| R2 | Backend = **CPU/XNNPACK** default on A14 | ~607 MB resident, safest under the ceiling; ~6–8 tok/s acceptable for a background task. | GPU/Metal (~1.45 GB, ~12–15 tok/s) faster but heavier + thermals; opt-in only if on-device headroom confirmed (SC-1). |
| R3 | Pass-2 = **Tool Use + free-form fallthrough** (D1) | LiteRT has **no** constrained decoding; Tool Use is the nearest structured path. Free-form JSON + `ExtractionValidator` is the *proven* Qwen-equivalent (the current app has never used constrained decoding). | Tool-Use-only: risks total pass-2 failure if on-device tool-calling is unreliable. Free-form-only: leaves D1 unmet. |
| R4 | Chat template = **hand-written Gemma turn formatter** | Gemma's turn format is trivial and dependency-free to render; fully unit-testable. LiteRT does not auto-apply a tokenizer chat template (MLX did, via swift-transformers). | Importing swift-jinja to render the 12 KB `chat_template.jinja`: unnecessary for plain turns; Tool Use handles tool-call framing. |
| R5 | Download = **single `.litertlm` LFS file** | HF tree confirms one file per backend; `BackgroundLLMDownloadService` is generic over repo id. | Multi-file snapshot logic: not needed (single file). |
| R6 | **No runtime fallback** in shipped build (D2) | Owner decision; single runtime, smaller binary. | Keeping MLX/Qwen as fallback is *safer* on the unmeasured A14 — recommended, overruled, recorded as accepted risk. |
| R7 | Ship **additive/inert** this feature; switchover on device day | Early-Preview package can't be verified here (no A14; possible missing simulator slice). Keeps `main` releasable. | Adding the SPM dep + flipping DI now: would break the simulator build if the binary lacks a sim slice, and can't be device-verified. |

## Verified facts (2026-09-13)

- **Model files** (`litert-community/gemma-4-E2B-it-litert-lm`, sha `b3ca0d2`): CPU `gemma-4-E2B-it.litertlm` = **2,588,147,712 B (2.41 GiB)**; GPU `gemma-4-E2B-it-gpu.litertlm` = **2,008,432,640 B (1.87 GiB)**. `-web`/`.task` + `_Google_Tensor_*`/`_intel_*`/`_qualcomm_*` are **not for iOS** — never download.
- **Swift API** (Early Preview): SPM `github.com/google-ai-edge/LiteRT-LM`, product `LiteRTLM` ≥ `0.12.0`. `EngineConfig(modelPath: String, backend: Backend, maxNumTokens: Int = 512, cacheDir: String, visionBackend: Backend? = nil, audioBackend: Backend? = nil)` → `Engine(engineConfig:)` → `func initialize() async throws` → `func createConversation(with: ConversationConfig? = nil) async throws -> Conversation` → `func sendMessage(_:) async throws -> Message` / `sendMessageStream(_:)`. Backends `.cpu()`, `.gpu`. **Loads by file path.** `visionBackend`/`audioBackend` nil ⇒ text-only free. `thinkingConfig` bounds reasoning. Tool Use: Swift `Tool` protocol + `@ToolParam` + `run()`, registered via `ConversationConfig(tools:)`.
- **Q1 (constrained decoding): NOT supported** anywhere in LiteRT-LM. Not a regression — the app never used it.
- **Thinking model:** Gemma 4 E2B reasons; bound thinking ≈ 0 for deterministic pass-2 output.
- **Codebase reuse (verified):** `SummarizationService`, `SummaryResult`, `UnifiedExtraction`, `ExtractionValidator` (parse/validate/assemble), `SummaryPromptBuilder`/`SignalPromptBuilder`/`PromptLoader`, lexicon, and `BackgroundLLMDownloadService.downloadSnapshot` are model-agnostic — reused verbatim. Only new/model-specific: chat-template render, tool schema, engine wrapper, `.litertlm` installed-check.

## Open (device-only — cannot resolve here)

- **Q3:** no real iPhone 12 Pro (A14) measurement exists (only iPhone 14/A15). SC-1 (resident `phys_footprint`) and SC-4 (tok/s) are the load-bearing device gates. With D2 there is no fallback, so a gate-fail degrades to transcription-only.
- **API delta:** the Early-Preview Swift API may differ from the documented surface at integration time; localized to `LiteRTTextGenerator.swift`.
