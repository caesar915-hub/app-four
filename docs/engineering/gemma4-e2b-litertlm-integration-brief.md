<!-- Created: 2026-09-12 23:50 (WEST) · Updated: 2026-09-12 23:50 (WEST) -->
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
- **Package:** [google-ai-edge/LiteRT-LM](https://github.com/google-ai-edge/LiteRT-LM) — first-party iOS/Swift runtime; Metal (GPU) + XNNPACK (CPU) backends; `.litertlm` format. **Verify the current Swift package (SPM/CocoaPods) + exact API surface** — it is new and moving.
- **Shape of the API** (from research; confirm against the repo's iOS sample): `Engine` / `EngineConfig(modelPath:backend:)` → `Session`/`Conversation` → `generate`/stream.
- **Minimal sketch (verify against the shipping API):**
  ```swift
  // Load by FILE PATH — never as Data/bytes (that defeats mmap and OOMs).
  let cfg = EngineConfig(modelPath: modelURL.path, backend: .cpu)   // .cpu on A14 for memory safety
  let engine = try Engine(cfg)
  let session = try engine.createSession()
  let reply = try await session.generate(prompt)                    // apply Gemma 4 chat template
  ```
- **⚠️ OPEN — structured/JSON decoding:** MLX had `MLXGuidedGeneration` (grammar-constrained JSON). **Confirm whether LiteRT-LM/MediaPipe supports constrained/grammar decoding on iOS.** If not, pass-2 strict-JSON relies on the model + `ExtractionValidator` retry only — a real risk for a quantized model. This is the single biggest integration unknown — resolve in `/speckit-clarify`.

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
8. **RAM gate:** `ProcessInfo.processInfo.physicalMemory` — enable this path on the A14 only if the on-device RSS check passes; else fall back (Gemma 3 1B/MLX or Qwen).

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
- **SC-2:** JSON validity ≥ Qwen baseline on the two-pass eval (after `ExtractionValidator` + retry); confirm whether LiteRT constrained decoding is available (SC-2a).
- **SC-3:** Signal-field correctness ≥ Qwen baseline on `app-four-mlx-eval` fixtures (Gemma 4 should exceed it given IFEval 94.6).
- **SC-4:** Decode ≥ ~8 tok/s sustained on A14 (background task; not interactive).
- **SC-5:** Full `app-fourTests` green; `SummarizationService` API unchanged; no VM/View edits; MLX removed from the extraction path only if fully replaced.

---

## 9. Constitution impact
Bigger than the Gemma 3 path: it changes **both** the extraction *model* (Qwen → Gemma 4 E2B) **and** the *runtime* (MLX → LiteRT-LM) in the Technology Stack + Principle VII. Requires a **MINOR amendment** (bump + SYNC IMPACT) to `.specify/memory/constitution.md` and a lockstep CLAUDE.md §Stack update. Flag in the plan's Constitution Check before Phase 0.

---

## 10. Risks & open questions (resolve in /speckit-clarify)
- **[Q1 — biggest]** Does LiteRT-LM/MediaPipe support **grammar-constrained / structured-JSON decoding** on iOS? If not, pass-2 reliability rests on the model + validator retry only.
- **[Q2]** LiteRT-LM **iOS Swift API maturity + SPM availability** — new and moving; confirm the exact package + API before planning tasks.
- **[Q3]** **No A14 measurement** exists (only A15/iPhone 14). Confirm resident RSS + tok/s + thermals on a real 12 Pro.
- **[Q4]** Exact `.litertlm` filenames/sizes (CPU vs GPU) on the `litert-community` repo — verify via the HF tree API.
- **[Q5]** Download integration: the current pipeline is HF-snapshot-based; adapt for the single `.litertlm` file (or snapshot the litert-community repo).
- **[Q6]** Do we drop MLX entirely (extraction) or keep it for a Gemma-3-1B fallback? Two runtimes = more binary size + maintenance.

---

## 11. Alternatives (decide before specifying)
- **Gemma 3 1B QAT via MLX** (companion brief) — lower risk, stays on MLX, 733 MB, IFEval 80.2, drop-in. **Recommended default** unless the +14 IFEval points justify the LiteRT adoption.
- **llama.cpp GGUF text-only** — ~3.35–3.85 GB, needs the increased-memory-limit entitlement; a fallback runtime if LiteRT's Swift/iOS story disappoints.
- **Gemma 4 E2B via MLX** — infeasible on A14 (~3 GB dirty + PLE-4bit quality risk). Do not.

---

## 12. Sources
Two convergent multi-agent runs + primary sources (full list in the companion comparison doc): [LiteRT-LM repo](https://github.com/google-ai-edge/LiteRT-LM) · [litert-community/gemma-4-E2B-it-litert-lm](https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm) · [Google LiteRT-LM blog (607 MB CPU, PLE mmap)](https://developers.googleblog.com/blazing-fast-on-device-genai-with-litert-lm/) · [apple-silicon-llm-bench (LiteRT 497 MB vs MLX 3,010 MB)](https://github.com/john-rocky/apple-silicon-llm-bench) · [iPhone 14/A15 6 GB run (HN)](https://news.ycombinator.com/item?id=47652561) · [increased-memory-limit entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.kernel.increased-memory-limit) · [Always Processing: dirty-vs-clean memory](https://alwaysprocessing.blog/2022/02/20/size-matters) · [Gemma 4 Technical Report (arXiv 2607.02770)](https://arxiv.org/abs/2607.02770) · [MLX #615 (no GPU-mmap — why MLX can't)](https://github.com/ml-explore/mlx/discussions/615) · [HF: 4-bit PLE garbage-output risk](https://huggingface.co/mlx-community/gemma-4-e2b-4bit/discussions/1).
