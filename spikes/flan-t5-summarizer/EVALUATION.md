# FLAN-T5 Summarizer — Deep Evaluation (v3, corrected)

**Date:** 2026-06-20 · **Protocol:** [METHODOLOGY.md](METHODOLOGY.md) (locked v3)
**Question:** Can a small, on-device encoder-decoder faithfully summarize ADHD voice-note journal entries (preserving medications/doses/times, sleep, mood, side-effects, emotional arcs) — where fabricating or corrupting a medical/temporal/emotional detail is *dangerous*?

**Answer:** The best available config is **`google/flan-t5-large` + `faithful-large-fewshot-v2` + greedy decoding** — the most faithful candidate by every instrument, with **0 confirmed dangerous fabrications on the held-out test-30** (Wilson 95% CI [0, 11%]). Its cost is **omission**: it drops ~32% of concrete gold signals — objectively measured, real, and *not* cheaply fixable. T5Gemma is more *complete* (copies more) but fabricates far more and is not recommendable for a health record under prompting/decoding. flan-base is capacity-bound. **No config is "ship-safe" on this evidence** — n is too small to certify a safety gate; see §9–§10.

> All numbers below are on the held-out **test-30** (and external **evalset-40**), never the dev-70 used to select prompts. Faithfulness is triangulated across three instruments; completeness is measured against a human-adjudicated gold anchor.

---

## 1. Why the original results were untrustworthy (and what was fixed)
The first harness computed every metric on the **post-processed** output, so `hallucination`≈0 *by construction* on the 76–98% of rows that fell back — it measured the safety net, not the model. v2/v3 rebuilt measurement: stratified raw-vs-processed metrics + fallback rate ([eval.py](playground/eval.py)); deterministic dev/test split ([analyze_configs.py](playground/analyze_configs.py)); and a triangulated faithfulness stack (below). An external review then caught that final numbers were still being reported on the full-100 (dev contamination), the omission metric had no ground truth, the AND-gate was false-negative-prone, and the anti-loop claim was overconfident — all corrected here.

## 2. Models
| model | params | enc/dec | note |
|---|---|---|---|
| flan-t5-base | ~250M | 12/12 | capacity-bound on this task |
| **flan-t5-large** | ~770M | 24/24 | **the candidate** |
| t5gemma-b-b-{ul2,prefixlm}-it | ~0.6B | Gemma-2 enc-dec | gated; chat-tuned |

## 3. Data, splits, gold anchor
- [inputs-grounded-multi.json](playground/inputs-grounded-multi.json): 100 multi-signal ADHD transcripts (synthetic, grounded vocabulary). Deterministic **test-30 / dev-70** split (`n%10∈{0,1,2}`).
- External held-out: [evalset.json](../../evalset.json) (40), never used for selection.
- [gold-signals.json](playground/gold-signals.json): per-test-entry ground-truth signals (meds/dose/time, sleep-h, mood, energy, focus, side-effects), Claude-extracted + **human-adjudicated** (single-annotator; κ not computed — stated limitation).

## 4. Metric stack (triangulated)
- **Faithfulness, paraphrase-robust:** MiniCheck-DeBERTa-v3-Large (0.4B; [Tang et al. 2024](https://aclanthology.org/2024.emnlp-main.499/)) — doc→claim support, min over bullets.
- **Faithfulness, adversarial:** blind Claude judge panel (skeptic defaults to refuting).
- **Completeness:** gold-anchored concrete-signal recall.
- **Operational:** fallback rate; **Comparability:** (ROUGE deferred).
- **Gate = cascade, not AND** (the key fix): MiniCheck = high-recall "unsupported" net → judge + human = high-precision "dangerous fabrication" adjudication. Justified by κ(MiniCheck,judge)=0.26 with judge⊂MiniCheck (judge-only=1/180); generic-NLI κ was 0.08.

## 5. Faithfulness (test-30)
| config | MiniCheck support | MiniCheck flagged% | judge dangerous entries /30 | Wilson 95% CI |
|---|---|---|---|---|
| **flan-large-baseline** | **0.789** | **17%** | **0** | **[0%, 11%]** |
| flan-base-fewshot | 0.551 | 37% | 3 | [3%, 26%] |
| gemma-ul2-baseline | 0.460 | 50% | 3 | [3%, 26%] |
| gemma-prefixlm-baseline | 0.395 | 63% | 6 | [10%, 37%] |
| gemma-prefixlm-medslot (anti-loop) | 0.317 | 70% | 8 | [14%, 44%] |
| gemma-ul2-strict (anti-loop) | 0.087 | 97% | 10 | [19%, 51%] |

Three instruments agree: **flan-large is the most faithful.** A *paraphrase-robust* metric flagging the anti-loop config at 97% confirms the anti-loop degradation is **real, not a paraphrase artifact**.

## 6. Completeness (gold-anchored recall, test-30)
| config | concrete-signal recall | omission |
|---|---|---|
| gemma-ul2-baseline | 93% | 7% |
| gemma-prefixlm-medslot | 75% | 25% |
| **flan-large-baseline** | **68%** | **32%** |
(Concrete signals: med name/dose/time, sleep-h, side-effects. Subjective mood/energy/focus recall not auto-scored.)

## 7. The core tradeoff
flan-large = **most faithful (0.789), least complete (68%)**. gemma-ul2 = **most complete (93%), least faithful (0.460)** — it retains signals by copying, and fabricates in the copy. For a health record: **fabrication corrupts, omission is recoverable** → flan-large's profile is the right one, with omission as the known, quantified cost.

## 8. Decoding experiment — cheap tier (negative result)
beam-10 + MiniCheck-composite rerank on flan-large/test-30 vs greedy:
| decoding | MiniCheck support |
|---|---|
| true greedy (num_beams=1) | **0.789** |
| beam-10 top-1 | 0.698 |
| beam-10 + rerank | 0.770 |
Rerank vs greedy: better 4 / worse 13 / ~equal 13. **Beam+rerank does not beat greedy** — beam degrades the pool for this small model; rerank only recovers. **flan-large's omission is not fixable by decoding** → needs the expensive tier.

## 9. Ranking & recommendation
1. **flan-large + `faithful-large-fewshot-v2` + greedy — best available.** Faithful (0 dangerous/30, [0,11%]; MiniCheck 0.789). Cost: 32% concrete-signal omission. Cascade-gate review queue = 5 entries/30.
2. **T5Gemma — not recommended (under prompting/decoding).** More complete (93%) but fabricates (MiniCheck 0.46, judge 3–10/30); prompting and anti-loop decoding did not help (anti-loop made it worse). **Fine-tuning untested.**
3. flan-base-fewshot — recovered (few-shot) but still fabricates (3/30). 4. flan-base baseline — dead.

**Recommendation:** flan-large + greedy as the starting point. **Do not ship on this evidence** — fix omission via **LoRA distillation** (Apple's on-device recipe) or a **two-pass extract-then-condense** architecture, then re-gate on a larger, ideally real-data, held-out set.

## 10. Generalization (evalset-40, external held-out)
flan-large held up on data never used for selection: fallback 10%, hallucination 0.03, med recall 8/8 (legacy metrics; pre-MiniCheck). No fabrication blowup — the low-fabrication result is not a synthetic-set artifact.

## 11. Limitations
- **Synthetic primary data** (structural; external validity capped until real voice notes).
- **n=30 underpowered for a safety gate** — 0/30 only bounds fabrication at ≈[0,11%]; even test-30+evalset-40 (70) certifies only ≈"<5% at 95%." Real ship needs more, ideally real, data.
- **Gold = single-annotator + adjudication** (κ not computed).
- **MiniCheck over-flags** (high recall, used as the cascade's sensitive stage, not as a verdict); may over-penalize fragmentary text.
- **Claude-as-judge** partially mitigated (blind + adversarial + MiniCheck triangulation), not fully controlled.
- **Deployment, not validity:** HF cache was evicted mid-spike under disk pressure (pin versions before relying on reproducibility).

## 12. Next spikes
- **LoRA distillation** of flan-large (and a fair gemma retry) on rejection-sampled gold summaries — the actual on-device recipe; the only untested path to fixing omission/fabrication "for real."
- **Two-pass** extract-then-condense to attack flan-large's truncation directly.
- **Real transcribed voice notes** + a larger gate set.
- **Quantization** (int8/4-bit) faithfulness check; bf16/Core ML latency (flan-large ~6.5s/entry CPU float32).
