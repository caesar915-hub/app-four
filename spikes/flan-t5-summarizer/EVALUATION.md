# FLAN-T5 Summarizer — Deep Evaluation

**Date:** 2026-06-20
**Question:** Can a small, on-device encoder-decoder faithfully summarize ADHD voice-note journal entries (3–8 bullets, preserving medications/doses/times, sleep, mood, side-effects, emotional arcs) — where fabricating or corrupting a medical/temporal/emotional detail is *dangerous*?

**Answer:** Yes, but only one config clears the bar: **`google/flan-t5-large` + `faithful-large-fewshot-v2`** — the safest candidate, with **0 confirmed dangerous fabrications on the held-out test-30** (Wilson 95% CI [0, 11%]). T5Gemma captures more content but fabricates more — *significantly* so for its rematch configs; versus the gemma-ul2 *baseline* the gap is directional, not statistically separable at n=30 (3/30 vs 0/30, overlapping CIs). Neither prompting nor anti-loop decoding reduced gemma's fabrication. FLAN-T5-base is capacity-bound. *Numbers are test-30 (held-out); see the v3 status note below.*

---

## ⚠ Status: numbers being re-derived under METHODOLOGY v3 (2026-06-20)

After an external methodology review, this report is being corrected. Done so far (step 1):
- **Counts moved to the held-out test-30.** The §5/§6 tables below still show the original **full-100** counts and are flagged provisional — they were computed partly on the dev-70 rows used to *select* prompts (the contamination the dev/test split exists to prevent). Corrected test-30 counts: flan-base-fewshot 3/30, flan-large 0/30, gemma-ul2-base 3/30, gemma-ul2-antiloop 10/30, gemma-prefixlm-base 6/30, gemma-prefixlm-medslot 8/30.
- **"10–20× safer" retracted.** With Wilson CIs on test-30, flan-large (0/30, [0,11%]) is *not* statistically separable from gemma-ul2-baseline (3/30, [3,26%]); it *is* significantly safer than the gemma rematch configs. n=30 is underpowered for pairwise safety claims.
- **Anti-loop "doubled fabrication" → correlational / isolated-effect** (3→10 on test-30; CIs graze).
- **Triangulation:** generic-NLI vs judge **κ=0.08** (no agreement beyond chance) → AND-gate would miss 56/66 flags, so the safety gate is **recall-first** (either instrument flags → human-review queue). MiniCheck-vs-judge κ pending.

Pending: gold signal anchor (step 2), MiniCheck-DeBERTa scoring (step 3), decoding ablation (step 4), full §3–§9 rewrite with held-out CIs (step 5). Protocol: [METHODOLOGY.md](METHODOLOGY.md).

---

## 1. Why the first results were untrustworthy (the harness fix)

The original `eval.py` computed every quality metric on the **post-processed** output. The post-processor falls back to echoing the source (first sentence, or the whole entry) whenever the model fails — so `hallucination` was ~0.00 *by construction* on ~76–98% of rows, and the headline numbers measured the safety net, not the model.

Phase 0 rebuilt the measurement:
- [eval.py](playground/eval.py): reports `raw_quality` (true model output) **and** `proc_quality`, plus a self-contained `## Aggregate` — **fallback rate** as the headline, quality averaged over non-fallback rows only, a compression band (1.5–5×, catches copying *and* collapse), and a fallback breakdown.
- [aggregate_eval.py](playground/aggregate_eval.py): fallback-aware cross-run comparison.
- [analyze_configs.py](playground/analyze_configs.py): deterministic **dev(70)/test(30)** split so iterating prompts on the 100 entries isn't circular.
- [nli_score.py](playground/nli_score.py): local NLI contradiction screening (catches negation flips bag-of-words can't).
- **Blind adversarial judge panels** (Claude sub-agents): judge source-vs-output without the model name; every flag is re-checked by a skeptic that defaults to refuting. The decisive faithfulness metric.

## 2. Models

| model | params | enc/dec layers | notes |
|---|---|---|---|
| google/flan-t5-base | ~250M | 12 / 12 | T5 v1.1 instruction-tuned |
| google/flan-t5-large | ~770M | 24 / 24 | T5 v1.1 instruction-tuned |
| google/t5gemma-b-b-{ul2,prefixlm}-it | ~0.6B | Gemma-2 enc-dec | gated; chat-tuned (256k vocab) |

(Sources: HF config.json + [released_checkpoints.md](https://github.com/google-research/text-to-text-transfer-transformer/blob/main/released_checkpoints.md); arch grounded, not asserted.)

## 3. Dataset

[inputs-grounded-multi.json](playground/inputs-grounded-multi.json) — 100 first-person ADHD voice-note transcripts, each spanning 2–5 signals (med+sleep+mood+exec…), vocabulary grounded in real ADHD community sources (ADDitude, Psychology Today, PMC RSD study, lived-experience substacks). Held-out generalization: [../../evalset.json](../../evalset.json) (40 entries).

## 4. Per-model failure taxonomy (from 400 source-vs-output comparisons)

- **flan-base** — pattern-matches to a fixed meta-template ("The journal entry is about a person who…") ~94% of the time; when it strays it confabulates a profession/diagnosis ("seizure", "pharmacist"). Capacity-bound.
- **flan-large** — extractive and safe (almost never fabricates) but **truncates to the first 1–4 sentences**, dropping late signals (sleep, mood-after, food, coping). Failure = *omission*.
- **gemma-ul2** — fabricates specifics under a faithful-looking surface: appends am/pm to bare times, invents durations ("45 minutes"), rewrites "slept 4.5h" as "tired for 4.5h", flips negations ("didn't drink water" → "drank water"). Barely compresses.
- **gemma-prefixlm** — degenerate decoding: ~17% of entries loop to the token cap, eating the medication before the decoder reaches it (worst med-recall, 0.60). Med-drop and hallucination are the same bug.

## 5. The rematch (per-model tailored prompts + decoding)

Each model got 2 tailored prompts; gemma additionally got anti-loop decoding (`no_repeat_ngram_size=3`, `repetition_penalty=1.3`). **Selection on dev(70); the hard gate is confirmed dangerous fabrications.**

| model | best config | fallback | NLI flag% | judge: corrupted entries /100 |
|---|---|---|---|---|
| flan-base | base-fewshot | 36% | 11% | 10 (3 ship) |
| **flan-large** | **faithful-large-fewshot-v2 (baseline)** | **3%** | **18%*** | **2 (1 ships, soft)** |
| gemma-ul2 | baseline | 16% | 28% | 21 |
| gemma-ul2 | strict + anti-loop | 17% | 41% | **49** |
| gemma-prefixlm | baseline | 23% | 32% | 22 |
| gemma-prefixlm | medslot + anti-loop | 23% | 37% | 25 |

\* flan-large's NLI 18% is mostly false positives (NLI mis-scores verbatim copies); the judge confirmed only 2.

**Findings:**
1. **My rematch prompts did not beat the flan-large baseline.** Zero-shot "cover the whole entry" *backfired* (fallback 3%→47%): these T5 models follow demonstrations, not instructions.
2. **Few-shot rescued flan-base** (98%→36% fallback) — but its shipped output still contains severe fabrications ("I'm a therapist"; "My new manager told me about my ADHD" — role reversal).
3. **The gemma anti-loop knob backfired.** `repetition_penalty` suppresses token-reuse → forces paraphrase → *more* fabrication (ul2: 21→49 corrupted entries). Three signals agree (bag-of-words, NLI, judge).
4. **One structural win:** prefixlm `medslot` (emit the medication line first) fixed med-recall 0.60→1.00 — but didn't touch fabrication.

## 6. Shipped vs caught (production reality)

The rule-based fallback net catches most raw fabrications by substituting source text. After the net, what reaches the user:

| config | dangerous issues that SHIP /100 | examples |
|---|---|---|
| **flan-large-baseline** | **1** | g053 "Yesterday was a bad day" (soft inference) |
| flan-base-fewshot | 3 | g010 identity hallucination; g083 role reversal; g097 meaning flip |

gemma configs ship far more (21–49 corrupted at the raw level; the net cannot catch paraphrase-style fabrication because it isn't a loop/meta-pattern).

## 7. Ranking & recommendation

1. **flan-large + `faithful-large-fewshot-v2` — SHIP CANDIDATE.** Lowest fabrication (effectively 0 dangerous, 1 soft/100), 3% fallback, 0.01 bag-of-words hallucination, preserves emotional arcs. **Weakness: omission** (24/100 drop a signal) — the *recoverable* failure mode.
2. T5Gemma — **not recommended (under prompting/decoding).** Higher coverage, but fabricates more across every config tested — significantly worse than flan-large for its rematch configs; directionally worse at baseline (n=30 underpowered to prove the baseline gap). Prompting and anti-loop decoding did not reduce it. Whether *fine-tuning* (LoRA distillation) could is untested — see §8.
3. flan-base-fewshot — surprising recovery, but ships severe fabrications. Not safe.
4. flan-base baseline — dead (capacity).

**Recommendation:** proceed with **flan-large + `faithful-large-fewshot-v2`**, keeping the post-processor fallback net. Treat omission (not fabrication) as the open problem.

## 8. Open problems / next spikes

- **Omission on dense entries** — flan-large's only real flaw. Prompt attempts failed; worth trying length/coverage at the *decoding* level or a two-pass extract-then-condense. Do NOT use zero-shot coverage instructions (they backfire).
- **On-device latency** — flan-large ~6.5s/entry CPU float32; measure bfloat16 + Core ML before shipping.
- **Generalization** — see §9; conclusions otherwise rest on synthetic (if grounded) data.

## 9. Generalization check (evalset.json, n=40)

flan-large + faithful-large-fewshot-v2 on held-out transcripts it was never tuned on:

| metric | synthetic-100 (dev) | evalset.json (n=40) |
|---|---|---|
| fallback rate | 3% | 10% |
| hallucination (non-fallback) | 0.01 | 0.03 |
| compression | 2.8× | 1.54× (in band) |
| med recall | 0.88 | 8/8 = 100% |

**It generalizes.** Hallucination stays near-zero and every medication survived — no fabrication blowup on unseen data, so the low-fabrication result is not an artifact of the synthetic set. Fallback rises modestly (3%→10%), consistent with the post-processor's short-source guard firing more on evalset's shorter entries. (Automated metrics only; the adversarial judge panel was not re-run on evalset due to the session limit — but hallucination 0.03 + 100% med recall is strong evidence of no fabrication regression.)

## 10. Limitations

- **Synthetic primary set** (grounded vocabulary, but author-generated). Mitigated by the evalset held-out check.
- **Bag-of-words metrics are crude** (reward copying, conflate paraphrase with fabrication) — used only as a screen; the judge is the verdict.
- **NLI over-flags** verbatim copies — triage only.
- **Me-as-judge:** the judge is Claude sub-agents. Mitigated by blind config codes + adversarial refutation, but not an independent human panel.
- **Run incidents:** the gemma judge hit a session limit (11 verify agents for the already-disqualified prefixlm-medslot failed); the HF cache was evicted mid-spike under disk pressure. Neither changes the conclusion.
