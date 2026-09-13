<!-- Created: 2026-09-12 23:50 (WEST) · Updated: 2026-09-13 00:18 (WEST) -->
# Spec Kit brief — Gemma 4 E2B (text-only) on iPhone 12 Pro via LiteRT-LM

**Purpose:** everything needed to prepare + run a Spec Kit cycle to adopt **Gemma 4 E2B, text-only, via Google LiteRT-LM** for on-device extraction on the iPhone 12 Pro (A14, 6 GB). Self-contained. Companion docs: [gemma-ondevice-comparison-2026-09.md](gemma-ondevice-comparison-2026-09.md) (full matrix), [gemma3-1b-extraction-migration-brief.md](gemma3-1b-extraction-migration-brief.md) (the lower-risk MLX alternative). Evidence: two independent multi-agent runs (my 10-agent max-review + a 14-agent Antigravity run) that **converge** on this being feasible via LiteRT-LM (not MLX).

> **This is the higher-quality, higher-effort path.** It reaches the best JSON model on the shortlist (Gemma 4 E2B, IFEval 94.6) but requires adopting a **new inference runtime** (LiteRT-LM / MediaPipe) alongside/replacing MLX. The low-risk alternative — Gemma 3 1B QAT via the existing MLX runtime (IFEval 80.2, 733 MB, drop-in) — is in the companion brief. Pick one path in `/speckit-specify`.

---

## 0. How to run Spec Kit next session
Branch off `main`. The `speckit-*` skills aren't installed on disk — run each step via `.specify/scripts/bash/*` + `.specify/templates/*` (as specs 041–045 were).

**`/speckit-specify` description (ready to paste):**
> Adopt **Gemma 4 E2B, text-only, via Google LiteRT-LM** as a new `SummarizationService` backend for on-device extraction, targeting the iPhone 12 Pro (A14, 6 GB). Add the LiteRT-LM Swift runtime; download the mobile-QAT `.litertlm` artifact via the existing download-not-bundle pipeline; run the existing two-pass narrative→strict-JSON flow (`SummaryPromptBuilder` → `SignalPromptBuilder` → `ExtractionValidator`) retuned for Gemma 4's chat template; keep it strictly text-only; enforce sequential model residency (unload transcription + any MLX model first); gate by device RAM; and A/B against the current Qwen2.5-1.5B (MLX) baseline before switching the default. Verify resident `phys_footprint` and JSON quality on a physical iPhone 12 Pro.

Then `/speckit-plan` (Constitution Check will flag the runtime+model change — §9) → `/speckit-tasks` (TDD; tests-first for logic) → `/speckit-implement` (one task/session).

---

## 1. Decision context
- **Feasible on the 12 Pro via LiteRT-LM.** Both runs agree: LiteRT-LM runs Gemma 4 E2B text-only at **~607 MB resident (CPU)** or **~1.45 GB (GPU)** — well under the A14 ceiling — because it **memory-maps weights and streams the ~1.1–1.32 GB Per-Layer-Embeddings (PLE) as clean pages** (iOS jetsam counts dirty memory, not clean mmap'd file pages). A real **iPhone 14 (A15, 6 GB)** runs it at **~12 tok/s, cool, no crash**.
- **MLX cannot** (charges all weights dirty ~3.0 GB → at/over the cap) → that's why this path exists.
- **Quality:** Gemma 4 E2B IFEval **94.6** / MMLU-Pro 60.0 — the ceiling of the shortlist (vs Gemma 3 1B 80.2, Qwen 1.5B 42.5).
- **Cost:** a new runtime dependency + a second model format; more integration + device-QA risk than the Gemma 3 1B/MLX drop-in.

---

## 2. Model artifact
- **Repo:** `litert-community/gemma-4-E2B-it-litert-lm` (Apache-2.0). Ships CPU and GPU `.litertlm` variants (mobile-QAT — quality-safe, avoids the 4-bit-PLE "garbage output" risk that afflicts the community MLX 4-bit build).
  - GPU build ≈ **1.87 GiB on disk / ~1.45 GB resident** (~12–15 tok/s on A14, est.).
  - CPU/XNNPACK build ≈ **~2.58 GB on disk / ~607 MB resident** (~6–8 tok/s on A14, est.).
  - **Verify exact filenames + byte sizes** via `https://huggingface.co/api/models/litert-community/gemma-4-E2B-it-litert-lm/tree/main` before wiring the downloader.
- **Text-only:** the model is natively multimodal; load/keep **text-only** (vision+audio towers ≈ +0.92 GiB → multimodal is **impossible** on 6 GB, both runs agree). Never pass image/audio inputs.
- Arch note: PLE (35 layers × 256 dim × 262,144 vocab ≈ 2.35B embedding params) is why "2B" is >3 GB in some formats; LiteRT keeps the PLE as clean mmap'd/streamed pages, which is the whole trick.

---

## 3. Runtime & Swift integration (LiteRT-LM / MediaPipe GenAI)
- **Package** (✅ verified 2026-09-13): SPM `https://github.com/google-ai-edge/LiteRT-LM`, product **`LiteRTLM`**, min **`0.12.0`** — first-party iOS/macOS runtime; `.cpu()` (XNNPACK) + `.gpu` (Metal) backends; `.litertlm` format. Status is **🚀 Early Preview** ([Swift API doc](https://developers.google.com/edge/litert-lm/swift)) — the API is moving; pin the version.
- **Verified API surface** (replaces the earlier guess; loads by **file path** ✓):
  ```swift
  // Load by FILE PATH — never as Data/bytes (defeats mmap → OOM). cacheDir is REQUIRED.
  let cfg = EngineConfig(
    modelPath: modelURL.path,
    backend: .cpu(),          // .cpu() on A14 for memory safety; .gpu is Metal
    maxNumTokens: 2048,       // default is 512 — raise for our two-pass prompts
    cacheDir: cacheURL.path
    // visionBackend / audioBackend default nil → text-only is free ✓ (never set them)
  )
  let engine = Engine(engineConfig: cfg)
  try await engine.initialize()
  let convo = try await engine.createConversation()            // ConversationConfig(tools:) for pass-2
  let reply = try await convo.sendMessage(message)             // or sendMessageStream(_:)
  ```
- **⚠️ Thinking model:** Gemma 4 E2B is a *reasoning* model; the API exposes `thinkingConfig` / a thinking-token budget. For deterministic pass-2 JSON, **bound thinking to ~0** or it emits reasoning before the payload.
- **✅ CLARIFY 2026-09-13 — structured/JSON decoding: NOT supported.** Confirmed across the repo README, [API overview](https://developers.google.com/edge/litert-lm/api_overview), and Swift API doc — **no grammar-constrained decoding, no JSON-schema enforcement, no `response_schema`.** There is **Tool Use / function calling** (Swift `Tool` protocol + `@ToolParam` + `run()`, registered via `ConversationConfig(tools:)`), but it is the *model deciding* to emit a typed call — not a decode-time schema guarantee. **Owner decision:** pass-2 is reframed as **Tool Use / function calling** (signals schema as a `Tool`), *not* free-form+validator. Residual risk: reliability now rests on Gemma 4's on-device tool-calling (itself Early Preview, unmeasured on A14) + `ExtractionValidator` retry — carry `ExtractionValidator` as the backstop.

---

## 4. Architecture in app-four
- **New service:** `LiteRTJournalService` (or `GemmaLiteRTSummarizationService`) conforming to **`SummarizationService`** ([Protocols.swift:215](../../app-four/Services/Protocols.swift#L215), `func summarize(rawTranscription:) -> SummaryResult`), registered in `AppDependencies` → `AppServices`. Downstream (VMs/Views) are engine-unaware — **no VM/View changes**.
- **Replaces** `MLXJournalService` for extraction (or coexists behind a runtime toggle for A/B). MLX (`mlx-swift`) can then be dropped from the extraction path if fully replaced — a real dependency reduction, but only after LiteRT is proven.
- **Reusable, model-agnostic:** the two-pass prompt builders ([SummaryPromptBuilder.swift](../../app-four/Services/SummaryPromptBuilder.swift), [SignalPromptBuilder.swift](../../app-four/Services/SignalPromptBuilder.swift)), [ExtractionValidator.swift](../../app-four/Services/NoteExtraction/ExtractionValidator.swift) (parse/validate/assemble + retry), and `Resources/lexicon.json` (718 entries) — **retune prompts for Gemma 4's chat template**; keep the validator + retry.
- **Model download:** the `.litertlm` is a single HF file. Reuse the existing download-not-bundle pipeline ([BackgroundLLMDownloadService.swift](../../app-four/Services/BackgroundLLMDownloadService.swift) / [AIModelServiceImpl.swift](../../app-four/Services/AIModelServiceImpl.swift)); it's snapshot/HF-based, so point it at the `litert-community` repo (or add a single-file download). `ModelConstants.llmHubRepoID`/`llmDownloadBase` ([Constants.swift:42,23](../../app-four/Utils/Constants.swift#L42)) become the LiteRT repo/path. `AIModelType.llm` ([AppEnums.swift:99](../../app-four/Models/AppEnums.swift#L99)) stays generic.

---

## 5. Critical implementation rules (from both runs — non-negotiable)
1. **Load by file path, not `Data`/bytes** — the one reported iOS OOM was caused by loading bytes (defeats mmap).
2. **Backend = CPU/XNNPACK on the A14** (~607 MB, safest) unless GPU (~1.45 GB) headroom is confirmed on-device. GPU is faster but heavier + hits thermals on the A14.
3. **Text-only:** build prompts from text only; never touch image/audio inputs (multimodal = instant OOM on 6 GB).
4. **Cap context ≤ 2048 tokens**; KV cache is negligible (~10–25 MB) for short prompts but is the only dirty-memory growth lever.
5. **Entitlements:** add `com.apple.developer.kernel.increased-memory-limit` + `com.apple.developer.kernel.extended-virtual-addressing`. (LiteRT GPU ~1.45 GB likely fits under the *default* cap, so the entitlement may be optional for LiteRT — but add it for headroom and it's mandatory if you ever fall back to a llama.cpp GGUF path at ~3.35–3.85 GB.)
6. **Sequential residency:** fully tear down SpeechAnalyzer/WhisperKit **and** any MLX model, `await` deinit, and confirm reclamation via `os_proc_available_memory()` **before** constructing the `Engine`. Never hold two model runtimes resident on 6 GB.
7. **Background lifecycle:** unload the engine on `sceneDidEnterBackground` (backgrounded apps get <50 MB).
8. **RAM gate:** `ProcessInfo.processInfo.physicalMemory` — enable this path on the A14 only if the on-device RSS check passes. **⚠️ AMENDED by CLARIFY 2026-09-13:** the owner chose to **drop MLX from the Shipaton build**, so the original "else fall back to Gemma 3 1B/MLX or Qwen" branch is **removed** — there is no runtime fallback in the submitted build. Gate-fail behavior therefore degrades to *no extraction* (transcription-only), not a fallback model. This is an **accepted risk on an unmeasured A14 (Q3)** and MUST be re-flagged in the plan's Constitution Check (reliability / fail-safe principles).

---

## 6. Memory model (why it fits)
iOS jetsam kills on `phys_footprint` = **dirty + compressed-anonymous + wired**; clean mmap'd file pages are evictable and **not counted**. LiteRT mmaps weights + streams the PLE as clean pages → ~607 MB (CPU) charged. MLX reads everything dirty (~3 GB) → over the cap. iPhone 12 Pro cap: **estimated** ~2–3 GB default / ~3.4–4.45 GB entitled — **not Apple-published and unmeasured on a real 12 Pro** (the only 6 GB datapoint is iPhone 14/A15). LiteRT's ~0.6–1.45 GB clears comfortably regardless of where the true cap lands.

---

## 7. Scope
**In:** LiteRT-LM runtime adoption; `LiteRTJournalService` behind `SummarizationService`; `.litertlm` download; Gemma 4 chat-template prompt retune (both passes); text-only enforcement; entitlements; RAM gating + sequential unload; A/B vs Qwen; device QA on a physical 12 Pro; constitution + docs updates.
**Out:** transcription (spec 045 / SpeechAnalyzer — separate); multimodal (impossible on 6 GB); SwiftData schema; `ExtractionValidator`/lexicon logic; the MLX Gemma-3-1B alternative (that's the companion brief — choose one).

---

## 8. Acceptance & success criteria (spec seeds)
- **SC-1:** On a physical iPhone 12 Pro with transcription torn down, extraction runs end-to-end without jetsam; logged `task_vm_info.phys_footprint` < device ceiling (record the number + backend).
- **SC-2:** JSON validity ≥ Qwen baseline on the two-pass eval, with pass-2 emitted via **Tool Use / function calling** (D1) and `ExtractionValidator` + retry as backstop. **SC-2a (revised):** tool-call schema-conformance rate measured on-device — no constrained decoding exists (Q1), so this is a model-reliability metric, not a guarantee.
- **SC-3:** Signal-field correctness ≥ Qwen baseline on `app-four-mlx-eval` fixtures (Gemma 4 should exceed it given IFEval 94.6).
- **SC-4:** Decode ≥ ~8 tok/s sustained on A14 (background task; not interactive).
- **SC-5:** Full `app-fourTests` green; `SummarizationService` API unchanged; no VM/View edits; **MLX removed from the extraction path in the Shipaton build (D2) — LiteRT is the sole runtime, no fallback.** A/B vs Qwen happens during dev only; the shipped build does not carry both runtimes.

---

## 9. Constitution impact
Bigger than the Gemma 3 path: it changes **both** the extraction *model* (Qwen → Gemma 4 E2B) **and** the *runtime* (MLX → LiteRT-LM) in the Technology Stack + Principle VII. Requires a **MINOR amendment** (bump + SYNC IMPACT) to `.specify/memory/constitution.md` and a lockstep CLAUDE.md §Stack update. Flag in the plan's Constitution Check before Phase 0.

---

## 10. Clarify resolutions (2026-09-13)
Research (WebFetch of the LiteRT-LM repo + Google AI Edge docs; HF tree API) + owner decisions from the `/speckit-clarify` pass. These are the inputs `/speckit-specify` consumes.

**Research-resolved (facts):**
- **[Q1 — RESOLVED: NO constrained decoding]** LiteRT-LM has no grammar/JSON-schema/`response_schema` enforcement. Tool Use (function calling) exists but is not a decode-time guarantee. → pass-2 reframed as Tool Use (see §3, decision below).
- **[Q2 — RESOLVED]** SPM `google-ai-edge/LiteRT-LM`, product `LiteRTLM`, min `0.12.0`, **🚀 Early Preview**. Verified API in §3. Loads by file path ✓; `cacheDir` required; text-only free (leave vision/audio backends nil).
- **[Q4 — RESOLVED]** iOS builds: CPU `gemma-4-E2B-it.litertlm` **2,588,147,712 B (2.41 GiB)** · GPU `gemma-4-E2B-it-gpu.litertlm` **2,008,432,640 B (1.87 GiB)**. The `-web`/`.task` and `_Google_Tensor_*`/`_intel_*`/`_qualcomm_*` files are **not for iOS** — never download them. (repo sha `b3ca0d2`, 2026-08-31.)
- **[Q5 — RESOLVED]** It's a **single `.litertlm` LFS file**, not a multi-file snapshot. Adapt the HF pipeline to a single-file download; provision a writable `cacheDir`.

**Owner decisions (the clarifications):**
- **[D1 — pass-2 strategy]** **Tool Use / function-calling reframe** (not free-form+validator). Signals schema → Swift `Tool` + `@ToolParam`; keep `ExtractionValidator` as the retry backstop. Rewrites SC-2/SC-2a.
- **[D2 — MLX fate (was Q6)]** **Drop MLX from the extraction path for the Shipaton build.** LiteRT is the *sole* extraction runtime in the submitted binary — **no runtime fallback** (amends rule #8, §5).
- **[D3 — timing]** **In-scope for Shipaton** (target ~Sep 23 App Review submission), accepting the Early-Preview runtime + Early-Preview Tool Use risk on the critical path.

**Still open — device QA, not clarifiable from a desk:**
- **[Q3 — OPEN]** No real iPhone 12 Pro (A14) measurement exists (only iPhone 14/A15). Resident `phys_footprint` + tok/s + thermals MUST be measured on a physical 12 Pro (becomes SC-1). With D2 there is no fallback, so a gate-fail = no extraction — Q3 is now load-bearing for the ship decision.

> **⚠️ Senior-engineer flag (recorded, overruled by owner):** D1+D2+D3 stack the highest-risk option on every axis — an Early-Preview runtime **and** Early-Preview Tool Use, sole-runtime with **no fallback**, on an **unmeasured A14**, feeding the **hardest deadline** in the sprint (~Sep 23). Recommended de-risk was: build in-scope behind a toggle (default off), keep Qwen/MLX as the shipping default + rule-#8 fallback until SC-1…SC-4 pass on a real 12 Pro, then drop MLX post-launch. Owner chose the literal drop. `/speckit-plan`'s Constitution Check must treat Q3 as a hard gate.

---

## 11. Alternatives (decide before specifying)
- **Gemma 3 1B QAT via MLX** (companion brief) — lower risk, stays on MLX, 733 MB, IFEval 80.2, drop-in. **Recommended default** unless the +14 IFEval points justify the LiteRT adoption.
- **llama.cpp GGUF text-only** — ~3.35–3.85 GB, needs the increased-memory-limit entitlement; a fallback runtime if LiteRT's Swift/iOS story disappoints.
- **Gemma 4 E2B via MLX** — infeasible on A14 (~3 GB dirty + PLE-4bit quality risk). Do not.

---

## 12. Sources
Two convergent multi-agent runs + primary sources (full list in the companion comparison doc): [LiteRT-LM repo](https://github.com/google-ai-edge/LiteRT-LM) · [litert-community/gemma-4-E2B-it-litert-lm](https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm) · [Google LiteRT-LM blog (607 MB CPU, PLE mmap)](https://developers.googleblog.com/blazing-fast-on-device-genai-with-litert-lm/) · [apple-silicon-llm-bench (LiteRT 497 MB vs MLX 3,010 MB)](https://github.com/john-rocky/apple-silicon-llm-bench) · [iPhone 14/A15 6 GB run (HN)](https://news.ycombinator.com/item?id=47652561) · [increased-memory-limit entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.kernel.increased-memory-limit) · [Always Processing: dirty-vs-clean memory](https://alwaysprocessing.blog/2022/02/20/size-matters) · [Gemma 4 Technical Report (arXiv 2607.02770)](https://arxiv.org/abs/2607.02770) · [MLX #615 (no GPU-mmap — why MLX can't)](https://github.com/ml-explore/mlx/discussions/615) · [HF: 4-bit PLE garbage-output risk](https://huggingface.co/mlx-community/gemma-4-e2b-4bit/discussions/1).
