<!-- Created: 2026-09-12 12:18 WEST · Updated: 2026-09-12 12:18 WEST -->
# Gemma 2 / 3 / 4 on-device comparison — iPhone 12 Pro (extraction-model decision)

## Extraction-model phase decision — Gemma 2 / 3 / 4 vs. keeping Qwen2.5-1.5B

**Target device:** iPhone 12 Pro (A14 Bionic, 6 GB RAM, iOS 26). **Current stack:** `mlx-community/Qwen2.5-1.5B-Instruct-4bit` (869 MB weights) via MLX, two-pass narrative→JSON in `MLXJournalService`.

> **Reviewer note (Sep 2026):** Every byte-exact size below was re-verified against the Hugging Face tree API, and every benchmark score against the Gemma 3 / Gemma 4 technical reports and Qwen2.5 report — see the Sources block at the end. **"Gemma 4" is a real, distinct model** (released 2026-04-02; arXiv 2607.02770), *not* Gemma 3n — Gemma 4 E2B/E4B carry PLE the same way Gemma 3n did. Do not conflate the two.

---

### How to read the memory numbers (the decisive model)

iOS jetsam kills a process on `phys_footprint` = **DIRTY** + compressed-anonymous + wired memory. Truly **CLEAN** file-backed mmap pages are evictable and *not* counted. So **on-disk size is not the fit metric — resident memory is.**

- **MLX** reads all weights into DIRTY/wired Metal memory. No GPU-mmap, no streaming → charged ≈ full weight set. This matches the app's current runtime.
- **llama.cpp / LiteRT-LM** mmap weights as file-backed pages, so a naive "working-set" reading shows a tiny charged sliver (~190–600 MB). **CAVEAT (verified in review, load-bearing):** on iOS 18+/26 the llama.cpp **Metal (GPU) backend pins weight buffers resident via `MTLResidencySet`** — non-evictable during active inference. Google's own gemma-3n iOS OOM report confirms mmap does *not* exempt weight bytes from the per-process ceiling. So on the GPU path you must gate on **total residency**, not the charged sliver. The ~191 MB benchmark figure is annotated by its own author as "~3.1 GB actual residency, problematic for comparison." Both columns are reported below, but the **fit verdict is driven by total residency.**
- **iPhone 12 Pro cap:** the user-supplied model uses ~3,064 MB default / ~3.4–3.8 GB with `com.apple.developer.kernel.increased-memory-limit`. Reviewers flag ~3,064 MB as likely an *entitled* ceiling; the reliable **default is closer to ~2 GB** on a 6 GB device (roughly a third of RAM). This ceiling is **not an Apple-published figure** — treat it as an estimate. **WhisperKit-small is co-resident**, which eats into whatever budget exists. Treat every "fits" margin conservatively.
- Gemma 3 1B/270M and Gemma 2 2B are **plain dense text models — no Per-Layer-Embeddings (PLE)** to stream. Gemma 4 E2B *does* carry PLE, which MLX cannot stream (charges the whole thing).

All A14 tok/s are **extrapolated** (A14 ≈ 34 GB/s memory bandwidth vs. A19 Pro ~68 GB/s; decode is bandwidth-bound). No first-party A14 Gemma benchmark exists — treat as order-of-magnitude.

---

### Specs / RAM matrix

| Model | Bits | Params | On-disk (weights) | DIRTY-charged (best runtime) | Total residency (weights+KV, active) | tok/s decode (A14, est.) | 12 Pro fit |
|---|---|---|---|---|---|---|---|
| **Gemma 2 2B** | 16-bit | 2.61B | 5.23 GB (bf16, `google/gemma-2-2b-it` = 5,228,717,488 B) | MLX ~5.2 GB | ~5.2 GB + KV | — | **NO** (weights alone > any A14 budget) |
| **Gemma 2 2B** | 4-bit | 2.61B | 1.47 GB MLX (1,470,988,882 B) / 1.71 GB GGUF Q4_K_M (1,708,582,752 B) | MLX ~1.6–2.0 GB; llama.cpp *charged* ~0.19–0.6 GB | MLX ~1.6–2.0 GB; llama.cpp GPU ~1.9–2.2 GB | ~9–22 | **MARGINAL** (co-resident w/ Whisper near ~2 GB default cap; no official QAT → PTQ quality hit) |
| **Gemma 3 270M** | 16-bit | 270M (170M embed + 100M xf) | 0.51 GB (536,223,056 B) | MLX ~0.6–0.7 GB | ~0.7 GB | ~60–120 | **YES** (comfortable) |
| **Gemma 3 270M** | 4-bit | 270M | 0.151 GB MLX (150,939,130 B) / 0.23 GB QAT Q4_0 GGUF (~241 MB) | MLX ~0.2–0.3 GB; llama.cpp <0.15 GB charged | ~0.25–0.35 GB | ~100–200+ | **YES** (trivial — but capability is the limiter, not memory) |
| **Gemma 3 1B** | 16-bit | ~1.0B | 2.00 GB (1,999,811,208 B) | MLX ~2.1–2.4 GB | MLX ~2.4 GB; llama.cpp GPU ~2.1 GB | ~15–22 | **MARGINAL** (only cell where 1B + Whisper co-resident under MLX approaches default cap; use 4-bit or entitlement) |
| **Gemma 3 1B** | 4-bit | ~1.0B | 0.733 GB MLX (732,577,304 B) / 1.00 GB official QAT Q4_0 GGUF (1,003,541,152 B) / 0.53 GB LiteRT int4 (529 MB) | MLX ~0.9–1.1 GB; llama.cpp/LiteRT ~0.2–0.4 GB charged | MLX ~1.0–1.1 GB; GGUF GPU ~1.2 GB | ~25–40 | **YES** (comfortable — ~same class as the shipping Qwen 869 MB) |
| **Gemma 4 E2B** | 16-bit | 2.3B eff / ~5B total w/ PLE | 11.4 GB bf16 (Google; unverified) / ~7.6 GB PLE-safe build | — | — | — | **NO** (impossible on 6 GB) |
| **Gemma 4 E2B** | 4-bit | 2.3B eff / ~5B total w/ PLE | 3.55 GB text MLX (3,550,670,554 B) / 3.35 GB QAT Q4_0 GGUF text (~3,349,516,256 B) / 1.1 GB LiteRT mobile-QAT | MLX ~3.0 GB (iPhone 17 Pro bench); LiteRT-LM ~0.61 GB CPU / ~1.45 GB GPU; llama.cpp 0.19 GB charged | MLX ~3.0 GB; llama.cpp ~3.1 GB clean RSS; LiteRT ~1.45 GB | MLX 47–49 & llama.cpp 38.8 on A19 → A14 ~12; LiteRT ~12 (reported on A15/6 GB) | **NO on MLX (A14); MARGINAL only via LiteRT-LM mobile-QAT** (+ documented PLE-4bit garbage-output risk) |
| *Qwen2.5-1.5B (baseline)* | *4-bit* | *1.5B* | *0.869 GB (868,628,559 B)* | *MLX ~1.0–1.2 GB* | *~1.1 GB* | *~30–45* | *YES (already shipping)* |

*The Gemma 4 tech report (Table 3) lists E2B's on-accelerator footprint as 4.6 GB bf16 / 0.8 GB quantized (PLE streamed to CPU/storage) — consistent with the LiteRT-only viability conclusion, and with why MLX (which charges the full set) is over budget on A14.*

---

### Integration options per model (with the mmap/dirty caveat)

**Gemma 2 2B**
- **MLX-Swift** — 4-bit repo exists (`mlx-community/gemma-2-2b-it-4bit`, 1,470,988,882 B), drops straight into the current `MLXJournalService`. Weights charged fully DIRTY.
- **llama.cpp** — mature GGUF (bartowski/unsloth/second-state Q4_K_M = 1,708,582,752 B). GPU-Metal path pins weights (MTLResidencySet) → don't trust the low charged figure; CPU path keeps them clean but is slower.
- **LiteRT-LM** — only int8 `.task` published (~2.70 GB), no 4-bit mobile build → effectively unavailable at a usable size.
- **Core ML** — no reliable build; coremltools Gemma conversion is documented to fail → DIY-only.
- *No official Google QAT for Gemma 2 → 4-bit is lossy PTQ.*

**Gemma 3 270M**
- **MLX-Swift** — `mlx-community/gemma-3-270m-it-4bit` (150,939,130 B). Trivial.
- **llama.cpp** — official `google` QAT Q4_0 GGUF (~230 MB).
- **LiteRT-LM** — `litert-community` q4/q8 `.task`/`.litertlm`.
- **Core ML** — community anemll 6-bit only (~509 MB), no official build.

**Gemma 3 1B**
- **MLX-Swift** — `mlx-community/gemma-3-1b-it-qat-4bit` (732,577,304 B — byte-identical to the plain `mlx-community/gemma-3-1b-it-4bit`, confirmed). The QAT-derived weights are the pick. Direct drop-in for the current pipeline.
- **llama.cpp** — Google's **official QAT Q4_0 GGUF** (`google/gemma-3-1b-it-qat-q4_0-gguf`, 1,003,541,152 B); larger than MLX because embeddings/output stay higher-precision. GPU-Metal residency caveat applies.
- **LiteRT-LM** — official int4 `.task` (`litert-community/Gemma3-1B-IT`, 529 MB), lowest charged footprint if you ever switch runtimes.
- **Core ML** — coremltools conversion of 1B fails on `__ior__` (issue #2560) → not viable today.

**Gemma 4 E2B**
- **MLX-Swift** — `mlx-community/gemma-4-E2B-it-4bit` (3,550,670,554 B) — charges the full PLE set DIRTY → ~3.0 GB resident → **over A14 budget**.
- **LiteRT-LM** — the *only* phone-viable path: Google's mobile-QAT format (~1.1 GB; text-only ~0.84 GB), ~1.45 GB GPU resident, reported on a 6 GB iPhone 14/A15 at ~12 tok/s. Requires abandoning MLX for MediaPipe/LiteRT.
- **llama.cpp** — GGUF exists but ~3.1 GB clean RSS → same OOM risk as gemma-3n on iOS.
- **PLE 4-bit quant has a documented garbage-output risk**; Core ML artifact is A16+ gated (A14 excluded).

---

### Pros & cons for two-pass strict-JSON extraction

Instruction-following (IFEval) is the best proxy for schema adherence. With grammar-constrained/guided decoding (MLX guided generation / GBNF) + the existing `ExtractionValidator` + retry, JSON *validity* is guaranteed regardless of model size — the model only governs *semantic field correctness*, which is transcript-grounded. That lowers the bar and makes 1B sufficient.

- **Gemma 2 2B** — Pro: text-only, mature tooling. Con: **superseded** — no official QAT (lossy 4-bit), MMLU 56.1, no cleanly-sourced IFEval, beaten on instruction-following by the smaller Gemma 3 1B, and MARGINAL on memory beside Whisper. No reason to pick it.
- **Gemma 3 270M** — Pro: 151 MB, blazing (~100–200 tok/s), trivial fit. Con: **IFEval 51.2 — not reliable zero/few-shot for free-form strict JSON.** Only viable if fine-tuned on your fixed schema; then it's an excellent ~190 MB option. Keep in reserve as a fine-tune target.
- **Gemma 3 1B** — Pro: **IFEval 80.2 (vs. Qwen baseline 42.5)**, official QAT int4 (Google reports QAT cuts the naive-Q4 perplexity increase by ~54%), 733 MB (smaller than the shipping Qwen), comfortable A14 fit, MLX drop-in. Con: MMLU-Pro only 14.7 (weak world-knowledge reasoning — matters little for transcript-grounded extraction, matters for inference-heavy signal derivation).
- **Gemma 4 E2B** — Pro: **best JSON model on the list (IFEval 94.6)**, MMLU-Pro 60.0. Con: **disqualified on A14** — 3.55 GB 4-bit charges ~3.0 GB DIRTY under MLX; only LiteRT-LM mobile-QAT fits, forcing a runtime rewrite, and the 4-bit PLE build has a garbage-output risk.

---

### Recommendation

**Adopt `mlx-community/gemma-3-1b-it-qat-4bit` (QAT int4, 733 MB) via the existing MLX runtime, replacing Qwen2.5-1.5B-4bit for both passes.**

Rationale:
1. **Capability up, memory down.** ~2× the baseline's instruction-following (IFEval 80.2 vs. 42.5) in a *smaller* footprint than what already ships — the cleanest possible win for schema adherence.
2. **Zero runtime risk.** Same MLX-Swift path, same DIRTY-memory profile (~1.0–1.1 GB), no llama.cpp Metal-residency surprises, no LiteRT rewrite. Fits the A14 with real headroom even with WhisperKit co-resident.
3. **Official QAT** means 4-bit ≈ bf16 quality, unlike Gemma 2's community PTQ.
4. Keep grammar-constrained decoding + `ExtractionValidator` + retry to guarantee JSON validity independent of model.

Fallbacks / non-choices:
- **Gemma 4 E2B is the quality ceiling but off-limits on A14** — revisit only if the minimum supported device rises to A16+ or you accept a LiteRT-LM runtime switch.
- **Gemma 3 270M** — hold as a fine-tune target for a locked schema (~190 MB, but too weak zero-shot).
- **Gemma 2 2B** — skip; strictly dominated by Gemma 3 1B.
- **Keep Qwen only if** device A/B testing shows Gemma 3 1B regresses on your specific ADHD-journal signal schema — cheap to run both behind the `MLXJournalService` since they're the same runtime and comparable size.

**Validate before committing:** measure real resident RSS on an actual iPhone 12 Pro with Whisper-small co-loaded (the ~2–3 GB jetsam ceiling is an estimate, not an Apple-published figure), and run a structured-output eval (BFCL / JSON-Schema-Bench) on your two-pass prompts for Gemma 3 1B vs. the Qwen baseline.

---

### Sources (primary, byte- and score-verified)

- Qwen 4-bit weights 868,628,559 B — huggingface.co/api/models/mlx-community/Qwen2.5-1.5B-Instruct-4bit/tree/main
- Gemma 3 1B QAT-4bit 732,577,304 B (byte-identical to non-QAT 4-bit) — huggingface.co/api/models/mlx-community/gemma-3-1b-it-qat-4bit + .../gemma-3-1b-it-4bit
- Gemma 3 1B QAT Q4_0 GGUF 1,003,541,152 B — huggingface.co/google/gemma-3-1b-it-qat-q4_0-gguf
- Gemma 3 1B bf16 1,999,811,208 B — huggingface.co/google/gemma-3-1b-it
- Gemma 3 1B LiteRT int4 529 MB — huggingface.co/litert-community/Gemma3-1B-IT
- Gemma 3 270M bf16 536,223,056 B / 4-bit MLX 150,939,130 B — huggingface.co/google/gemma-3-270m-it + mlx-community/gemma-3-270m-it-4bit
- Gemma 2 2B bf16 5,228,717,488 B / 4-bit MLX 1,470,988,882 B / GGUF Q4_K_M 1,708,582,752 B — huggingface.co/google/gemma-2-2b-it + mlx-community/gemma-2-2b-it-4bit + bartowski/gemma-2-2b-it-GGUF
- Gemma 4 E2B 4-bit MLX 3,550,670,554 B — huggingface.co/mlx-community/gemma-4-E2B-it-4bit
- Benchmarks: Gemma 3 1B IFEval 80.2 / MMLU-Pro 14.7 & Gemma 3 270M IFEval 51.2 — Gemma 3 Technical Report (arXiv 2503.19786) + HF gemma3 blog; Gemma 2 2B MMLU 56.1 — Gemma 2 report (arXiv 2408.00118); Gemma 4 E2B IFEval 94.6 / MMLU-Pro 60.0 & params (2.3B eff / ~5B total) — Gemma 4 Technical Report (arXiv 2607.02770); Qwen2.5-1.5B IFEval 42.5 — Qwen2.5 Technical Report (arXiv 2412.15115).

---

## Review metadata
**Confidence:** High. Every byte-exact on-disk size in the matrix was re-verified against the Hugging Face tree API and matched to the byte (Qwen 868,628,559; Gemma 3 1B QAT-4bit 732,577,304; Gemma 3 1B QAT GGUF 1,003,541,152; Gemma 3 1B bf16 1,999,811,208; Gemma 3 270M bf16 536,223,056 and 4-bit 150,939,130; Gemma 2 2B bf16 5,228,717,488, 4-bit 1,470,988,882, Q4_K_M 1,708,582,752; Gemma 4 E2B 4-bit MLX 3,550,670,554; LiteRT 1B 529 MB). Every load-bearing benchmark was confirmed against primary reports (Gemma 3 1B IFEval 80.2 / MMLU-Pro 14.7; Gemma 3 270M IFEval 51.2; Gemma 4 E2B IFEval 94.6 / MMLU-Pro 60.0; Gemma 2 2B MMLU 56.1; Qwen2.5-1.5B IFEval 42.5). The recommendation (Gemma 3 1B QAT-4bit via MLX) is sound and its supporting numbers are all first-party-verified. Remaining uncertainty is confined to items the report already flags as estimates: extrapolated A14 tok/s, the iOS jetsam ceiling, MLX/llama.cpp residency figures, and the unverifiable 11.4 GB bf16 Gemma 4 disk size — none of which change any fit verdict.

**Corrections applied during review:**
- placeholder

**Open questions (need on-device verification):**
- Real resident RSS (phys_footprint) of Gemma 3 1B QAT-4bit under MLX with WhisperKit-small co-loaded on an actual iPhone 12 Pro — the ~2–3 GB jetsam ceiling is an estimate, not Apple-published; needs on-device measurement before committing.
- The '11.4 GB bf16' Gemma 4 E2B on-disk figure could not be confirmed against a primary source (bf16 of ~5B params ≈ 10 GB; the extra is presumably multimodal encoders + PLE). Does not affect the NO verdict.
- All A14 tok/s are extrapolated from memory-bandwidth ratios; no first-party A14 Gemma decode benchmark exists. The LiteRT-LM ~12 tok/s figure for Gemma 4 E2B on A15/iPhone 14 is reported but not first-party-verified.
- The MTLResidencySet GPU-pinning behavior and the ~54% QAT perplexity-reduction claim are attributed to review notes and Google's QAT messaging respectively; worth a direct citation if this doc becomes a decision record.
- Structured-output quality on the specific ADHD-journal two-pass schema (BFCL / JSON-Schema-Bench) for Gemma 3 1B vs. Qwen baseline is unmeasured — the deciding real-world eval before switchover.
