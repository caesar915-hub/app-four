<!-- Created: 2026-09-12 23:34 (WEST) · Updated: 2026-09-12 23:34 (WEST) -->
# Spec Kit brief — swap the extraction LLM to Gemma 3 1B (QAT int4) via MLX

**Purpose:** everything a fresh Spec Kit session needs to run `specify → plan → tasks → implement` for the extraction-model migration. Self-contained. Companion evidence: [gemma-ondevice-comparison-2026-09.md](gemma-ondevice-comparison-2026-09.md) (full Gemma 2/3/4 matrix, byte-verified, 17 sources).

Decision owner: caesargrey. Research: 12-agent Opus-4.8 workflow (7 research + 3 adversarial reconcile + comparison + review), 2026-09-12.

---

## 0. How to run Spec Kit next session (do this first)
Work from a branch off `main` (per constitution Git Workflow). Then:

1. `/speckit-clarify` (optional — resolve the open questions in §8 first) then **`/speckit-specify`** with this description:
   > Replace the on-device extraction LLM (`mlx-community/Qwen2.5-1.5B-Instruct-4bit`) with **`mlx-community/gemma-3-1b-it-qat-4bit`** (Google QAT int4, 733 MB) behind the existing `SummarizationService`/`MLXJournalService` boundary, keeping the two-pass narrative→strict-JSON pipeline and the MLX runtime. Goal: better instruction-following/JSON adherence at a smaller memory footprint than today, verified on the iPhone 12 Pro (A14, 6 GB). Retune both prompt passes for Gemma 3, keep grammar-constrained decoding + `ExtractionValidator` + retry, and A/B against the Qwen baseline before switching the default.
2. `/speckit-plan` — the Constitution Check will flag the Technology-Stack line (see §9). Use §3 (code seams) and §7 (constraints) as the technical context.
3. `/speckit-tasks` — TDD-ordered; tests-first for the extraction logic (Principle X). Note the eval harness already exists (`app-four-mlx-eval.xctestplan`).
4. `/speckit-implement` — one task per session.

The scripts live at `.specify/scripts/bash/` (`create-new-feature.sh`, `setup-plan.sh`, `check-prerequisites.sh`); the skill files are NOT installed on disk — execute each step manually via those scripts + `.specify/templates/*` (as specs 041–045 were done).

---

## 1. Decision & rationale
**Adopt `mlx-community/gemma-3-1b-it-qat-4bit` (733 MB) via the existing MLX runtime, replacing Qwen2.5-1.5B-4bit for both extraction passes.**

- **Capability up, memory down.** IFEval **80.2** (Gemma 3 1B) vs **42.5** (Qwen2.5-1.5B) — ~2× instruction-following, the best proxy for JSON-schema adherence — in a **smaller** footprint (733 MB vs 869 MB on disk; ~1.0–1.1 GB dirty resident vs ~1.0–1.2 GB).
- **Zero runtime risk.** Same MLX-Swift path, same `ModelConfiguration(directory:)` load, same dirty-memory profile. No llama.cpp Metal-residency surprises, no LiteRT rewrite.
- **Official Google QAT** → 4-bit ≈ bf16 quality (unlike Gemma 2's community PTQ).
- **Fits the A14 with headroom** even with WhisperKit-small co-resident.

Weakness to watch: Gemma 3 1B MMLU-Pro is only 14.7 (weak world-knowledge reasoning) — low risk here because extraction is transcript-grounded, but validate on signal-derivation cases.

---

## 2. The exact model artifact
- **Primary:** `mlx-community/gemma-3-1b-it-qat-4bit` — on-disk **732,577,304 B** (byte-identical to the non-QAT `mlx-community/gemma-3-1b-it-4bit`; the QAT-derived weights are the pick). arch `gemma3`, text-only, **no Per-Layer-Embeddings** (unlike Gemma 3n/4 — simpler memory story). `LLMModelFactory` auto-detects the arch → no new Swift model class needed.
- **Alt runtimes** (not needed for this migration, for reference): Google official QAT GGUF `google/gemma-3-1b-it-qat-q4_0-gguf` (1,003,541,152 B); LiteRT int4 `litert-community/Gemma3-1B-IT` (529 MB).
- Baseline being replaced: `mlx-community/Qwen2.5-1.5B-Instruct-4bit` (868,628,559 B).

---

## 3. Current stack & the exact code seams to change
The pipeline is repo-id-driven, so the model swap is tiny; the substance is prompt retuning + eval.

| # | File | What it is | Change |
|---|---|---|---|
| 1 | [Utils/Constants.swift:42](../../app-four/Utils/Constants.swift#L42) `ModelConstants.llmHubRepoID` | the single model id, consumed by download + load | **→ `"mlx-community/gemma-3-1b-it-qat-4bit"`** (the core swap) |
| 2 | [Services/MLXJournalService.swift](../../app-four/Services/MLXJournalService.swift) | `SummarizationService` impl; loads via `ModelConfiguration(directory: findLLMModelDirectory(in: llmDownloadBase))` (L186–204), `ChatSession(…, instructions:, generateParameters:)` (L220); two passes L81–137 | no load change (arch auto-detected). **Re-tune `generateParameters` (temp/topP) for Gemma 3**; verify EOS/stop behavior |
| 3 | [Services/SummaryPromptBuilder.swift](../../app-four/Services/SummaryPromptBuilder.swift) | pass-1 system+user prompt (maxTokens 120) | **retune for Gemma 3** instruction style |
| 4 | [Services/SignalPromptBuilder.swift](../../app-four/Services/SignalPromptBuilder.swift) | pass-2 strict-JSON system+user prompt (maxTokens 512) + lexicon seed | **retune for Gemma 3**; keep grammar-constrained/guided decoding |
| 5 | [Services/NoteExtraction/ExtractionValidator.swift](../../app-four/Services/NoteExtraction/ExtractionValidator.swift) | `parseExtraction` / `validate` / `assembleSummaryResult`; retry-correction path | unchanged (model-agnostic); it guarantees JSON validity + retries |
| 6 | [Services/AIModelServiceImpl.swift:196,228](../../app-four/Services/AIModelServiceImpl.swift#L196) + [BackgroundLLMDownloadService.swift](../../app-four/Services/BackgroundLLMDownloadService.swift) | downloads `repoID: ModelConstants.llmHubRepoID` → `llmDownloadBase/models/<repoID>/` | no change (repo-id-driven); it fetches the new repo automatically |
| 7 | [Models/AppEnums.swift:99](../../app-four/Models/AppEnums.swift#L99) `AIModelType {.whisper, .llm}` | model-type enum | no change (`.llm` is generic) |
| 8 | `Resources/lexicon.json` (718 entries) + `PromptLoader.swift` | ADHD vocabulary seeding + validation allowlists | unchanged; re-verify it still seeds well under Gemma 3 |

**Integration boundary:** `SummarizationService` ([Protocols.swift:215](../../app-four/Services/Protocols.swift#L215), `func summarize(rawTranscription:) -> SummaryResult`). Downstream consumers are engine-unaware — no VM/View changes.

**A/B tip:** both models are the same runtime + size class, so a temporary second `SummarizationService` impl (or a `llmHubRepoID` toggle behind the debug console) lets you A/B Gemma 3 1B vs Qwen on-device before switching the default.

---

## 4. Scope
**In:** model swap (constant), prompt retuning for both passes, `generateParameters` tuning, eval on the fixed extraction schema, device-RSS verification on the 12 Pro, A/B vs Qwen, docs/backlog updates, constitution amendment (§9).
**Out:** transcription (that's spec 045, SpeechAnalyzer — separate); changing the SwiftData schema; changing `ExtractionValidator`/lexicon logic; any runtime switch (no LiteRT/llama.cpp); multimodal; Gemma 4 (see §10).

---

## 5. Acceptance criteria & success metrics (spec seeds)
- **SC-1:** On the iPhone 12 Pro (A14, 6 GB) with WhisperKit-small resident, extraction runs end-to-end without jetsam; measured `task_vm_info.phys_footprint` stays under the device ceiling (record the number).
- **SC-2:** Structured-output validity ≥ the Qwen baseline on the two-pass eval (JSON parses + schema-valid after `ExtractionValidator` + retry).
- **SC-3:** Signal-field correctness (mood/energy/focus/meds/etc.) ≥ Qwen baseline on the existing MLX eval set (`app-four-mlx-eval.xctestplan`); no regression on the ADHD-journal fixtures.
- **SC-4:** On-disk footprint ≤ current (733 MB ≤ 869 MB); no increase in download-path failure surface.
- **SC-5:** Full `app-fourTests` green; `SummarizationService` API unchanged; no VM/View edits.

---

## 6. Validation plan (before switching the default)
1. **Device RSS:** run a full extraction on a physical iPhone 12 Pro with Whisper-small co-loaded; log `phys_footprint` at real prompt+generation length (the ~2–3 GB jetsam ceiling is an estimate, not Apple-published).
2. **Structured-output eval:** run BFCL / JSON-Schema-Bench-style checks on the two real prompts (Gemma 3 1B vs Qwen); keep grammar-constrained decoding so JSON validity is guaranteed and you're measuring *field* correctness.
3. **A/B on the eval set:** the existing `app-four-mlx-eval` harness; compare signal accuracy Gemma 3 1B vs Qwen on the ADHD fixtures.
4. **Prompt-retune loop:** Gemma 3 uses its own chat template/EOS (`ChatSession` applies it); iterate temp/topP + prompt phrasing until pass-2 JSON is stable.

---

## 7. Memory model & iPhone 12 Pro constraints
- **iOS jetsam kills on `phys_footprint` = DIRTY + compressed-anonymous + wired; clean mmap'd file pages don't count.** On-disk size is not the fit metric — dirty resident is.
- **MLX reads all weights into DIRTY memory** (no GPU-mmap, no streaming). For Gemma 3 1B that's ~1.0–1.1 GB — comfortable. (This is exactly why Gemma 4 E2B fails on MLX/A14: it charges ~3 GB dirty.)
- iPhone 12 Pro cap ≈ ~2 GB default / ~3.4–3.8 GB with `com.apple.developer.kernel.increased-memory-limit` (estimates; verify on device). **WhisperKit-small is co-resident** — enforce the existing sequential unload discipline.
- A14 ≈ 34 GB/s bandwidth → est. **~25–40 tok/s** decode for Gemma 3 1B 4-bit (extrapolated; fine for background extraction).

---

## 8. Risks & open questions (resolve in /speckit-clarify)
- **[Q1]** Does Gemma 3 1B's weaker MMLU-Pro (14.7) hurt any *inference-heavy* signal derivation (vs transcript-grounded fields)? → measure on fixtures.
- **[Q2]** Exact jetsam headroom on a real 12 Pro with Whisper co-resident — unmeasured; gate on it.
- **[Q3]** Keep Qwen as a runtime-selectable fallback, or hard-replace? (Recommend: A/B first, then replace; keep the toggle only if QA shows schema regressions.)
- **[Q4]** Prompt-retune effort: Qwen prompts are tuned to Qwen; budget iteration for Gemma 3's instruction style.
- **[Q5]** Does the ~1.05 GB→~0.73 GB change interact with the peak-shaving/eviction lifecycle (Principle VII)? Re-verify `os_proc_available_memory()` gating.

---

## 9. Constitution impact (Principle-VII / Technology-Stack)
`.specify/memory/constitution.md` Technology Stack currently names the extraction model as `mlx-community/Qwen2.5-1.5B-Instruct-4bit`. This migration requires a **MINOR amendment** (bump + SYNC IMPACT) to name Gemma 3 1B QAT-int4. CLAUDE.md §Stack must be updated in lockstep. (Note: a separate pending amendment exists on `docs/llm-fsd-alignment` for the transcription engine; keep the two changes distinct.) The plan's Constitution Check must call this out before Phase 0.

---

## 10. Alternatives considered (why not — full matrix in the companion doc)
- **Gemma 4 E2B** — quality ceiling (IFEval 94.6) but **disqualified on A14 via MLX** (~3.0 GB dirty + PLE-4bit garbage-output risk); only fits via a LiteRT-LM runtime switch. Revisit if min device rises to A16+ or a LiteRT adoption is on the table (that's its own spec).
- **Gemma 2 2B** — superseded/dominated by the smaller Gemma 3 1B; no official QAT (lossy PTQ); MARGINAL on memory beside Whisper.
- **Gemma 3 270M** — 151 MB, trivial fit, but IFEval 51.2 too weak zero-shot for free-form strict JSON. Hold as a **fine-tune target** for a locked schema (~190 MB) — a future option.
- **Keep Qwen2.5-1.5B** — the safe default; only if device A/B shows Gemma 3 1B regresses on the ADHD signal schema.

---

## 11. Sources
All byte-exact sizes + benchmarks are verified in the companion [gemma-ondevice-comparison-2026-09.md](gemma-ondevice-comparison-2026-09.md) Sources block (17 primary sources: HF tree APIs for every size; Gemma 3 report arXiv 2503.19786; Gemma 2 report arXiv 2408.00118; Gemma 4 report arXiv 2607.02770; Qwen2.5 report arXiv 2412.15115). Gemma 4 / MLX / iPhone-memory deep dives: the prior runs summarized in that doc and in this conversation's research.
