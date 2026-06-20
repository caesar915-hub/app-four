# Faithfulness Evaluation Methodology — v3 (LOCKED 2026-06-20)

Locked protocol for the FLAN-T5 / T5Gemma summarizer faithfulness spike. Supersedes
the ad-hoc v1 process and the v2 draft. All final numbers in EVALUATION.md must be
derived under this protocol; pre-lock numbers are provisional.

## 0. Scope
- **In:** inference-time faithfulness of frozen small encoder-decoders for ADHD journal
  summarization, plus a decoding/rerank "cheap tier."
- **Out (deferred, not abandoned):** LoRA distillation, real (non-synthetic) transcripts, quantization.
- **Structural limitation (not a post-hoc threat):** the primary set is **synthetic** (grounded
  vocabulary, but author-generated). Synthetic→real transfer carries a measurable drop, so external
  validity is capped until validated on real voice notes. Stated up front, by design.

## 1. Dataset & splits (fixes contamination)
- Deterministic split ([analyze_configs.py](playground/analyze_configs.py)): **test-30** = ids with `n % 10 ∈ {0,1,2}`; **dev-70** = remainder.
- **Binding rule:** dev-70 → selection only; **every reported result is computed on test-30 (and the external evalset-40), never dev-70.**
- **Acknowledged residual leakage:** prompt/rubric iteration informed by dev-70 is a weak procedural contamination deterministic ids can't remove. (In this spike the judge rubric was *not* iterated on dev outcomes, so the risk here is theoretical — but the protocol names it.)

## 2. Ground-truth signal anchor (fixes unmeasurable omission)
- `gold-signals.json` for **test-30** (required) + a **10–15 dev calibration subsample**.
- Schema per entry: `{ meds:[{name,dose,time}], sleep_hours, mood, energy, focus, side_effects:[], key_events:[] }` — extracted **from the SOURCE**.
- **Normalization pass before matching** (otherwise the recall denominator is uncalibrated):
  - dose: lowercase, strip spaces, words→digits (`"twenty milligrams"`→`20mg`, `"20 mg"`→`20mg`).
  - time: canonical `HH:MM` (`"7.30"`/`"07:30"`→`7:30`); coarse buckets (`"morning"`→AM) allowed and logged.
  - name: lowercased, exact after canonicalization.
  - match = exact-after-canonicalization for facts; presence-of-stated-valence for mood/energy/focus.
- **Provenance / IAA (right-sized):** I extract; **the user adjudicates the full 30** (reviews + corrects).
  Objective fields (med/dose/time/sleep) are near-deterministic reading. **Chosen path: adjudication, not
  independent re-labeling — Cohen's κ is NOT computed; recorded as a stated limitation** (gold is
  single-annotator + human-adjudicated). Acceptable because the subjective fields are diagnostic, not the
  hard gate; the gate rests on dangerous-fabrication (faithfulness), which is triangulated separately.

## 3. Metric stack (fixes metric robustness + circularity)
- **Completeness (primary):** signal-recall / omission vs the gold anchor (objective).
- **Faithfulness — paraphrase-robust (primary):** **MiniCheck-DeBERTa-v3-Large (0.4B)**
  ([Tang et al., EMNLP 2024](https://aclanthology.org/2024.emnlp-main.499/)). Chosen over QAFactEval
  (heavy QG/QA pipeline) and SummaC (sentence-pair entailment mismatches fragmentary journal text).
  **DeBERTa variant, not Flan-T5** → avoids evaluator self-correlation with flan-large outputs.
- **Faithfulness — adversarial (kept):** blind adversarial Claude judge, **test-30 only**.
- **Generic [nli_score.py](playground/nli_score.py):** demoted to triage only.
- **Triangulation — two distinct uses, never conflated:**
  - **Reporting (precision):** AND-confirmed (MiniCheck *and* judge agree) = "high-confidence fabrications."
  - **Ship gate (recall-first):** **EITHER** instrument flags a dangerous fabrication → **mandatory
    human-review queue**; config ships only if that queue is adjudicated empty. A real fabrication
    caught by one instrument still blocks.
- **Viability diagnostic:** report Cohen's κ between the robust metric and the judge before trusting
  triangulation; very low κ → the disagreement→review queue is the binding workload.
- **Step-3 finding (2026-06-20):** MiniCheck-vs-judge κ=0.26 (vs generic-NLI 0.08). Structure: judge ⊂ MiniCheck
  (judge-only=1/180). So the gate runs as a **cascade**, not symmetric AND: MiniCheck = high-recall "unsupported"
  net → adversarial judge + human = high-precision "dangerous fabrication" adjudication → confirmed. Per-config
  human-review load = MiniCheck flag count (flan-large: 5/30).
- **Comparability only (labeled non-faithfulness):** ROUGE-1/2/L; optional external Claude-pipeline ceiling.

## 4. Decoding effect (fixes overconfident causal claim)
- **Single-variable ablation**, fixed model+prompt, one knob at a time: `greedy` · `no_repeat_ngram=3`
  alone · `rep_pen=1.15` alone · `rep_pen=1.3` alone · both · `beam=10` · `beam=10 + composite rerank`.
- Scored with MiniCheck + gold-anchor recall on test-30.
- **Claims discipline:** report the **isolated effect of knob X under metric Y** — not "causal." The
  "anti-loop doubled fabrication" line stays **correlational** unless it survives this ablation under MiniCheck.

## 5. Cheap-tier experiment (folded in)
- `rerank_decode.py`: per entry, **N=10** beams, rerank by a **composite** of inference-available signals
  (MiniCheck faithfulness + source-content-word coverage proxy — *not* gold-recall, which is eval-only),
  return top-1. Single-metric reranking overfits that metric's bias, so report cross-metric robustness.
- Sweep: 4 models × {greedy, beam-10, beam-10+composite-rerank} on test-30.

## 6. Validity threats (honest mitigation strength)
- **Synthetic data** — see §0 (structural).
- **Claude-as-judge** — **partially** mitigated (blind codes + adversarial refute + MiniCheck triangulation
  + human-verified gold); LLM judges retain intrinsic-knowledge bias — not fully controlled.
- **Deployment (not validity):** pin model versions / lock file; the HF cache evicted models mid-spike.

## 7. Decision gate (computed on held-out, with uncertainty)
- Evaluated on **evalset-40 (never used for selection) + test-30** = 70 unseen-by-selection entries.
- Gate: **zero dangerous fabrications surviving the §3 human-review queue** (hard) · signal-recall ≥ 0.9 · fallback ≤ 20%.
- **Report exact/Wilson CIs** on every rate. Stated plainly: 70 entries certify only ≈"<5% fabrication at 95%
  confidence" — a real ship requires a larger, ideally real-data, held-out set. n is not safety proof.

## 8. Execution order
1. (free) Re-report judge + analyze on **test-30**; soften EVALUATION.md claims. **+ κ(generic-NLI, judge) preview.**
2. Build gold-signals.json (test-30 + dev calibration) → **user verifies** (IAA on subjective fields) → freeze.
3. Stand up MiniCheck-DeBERTa-v3 → re-score outputs → **κ(MiniCheck, judge)** (triangulation viability).
4. Decoding ablation + cheap-tier composite rerank on test-30.
5. Rewrite EVALUATION.md §3–§9 from clean numbers; gate per §7.

## Changelog v2 → v3 (from external review)
- §0 synthetic reframed threat→structural limitation.
- §2 added normalization rules + right-sized IAA (subjective fields only).
- §3 MiniCheck-DeBERTa replaces QAFactEval/SummaC as primary (verified: lightweight, non-T5 variant); **report-vs-gate triangulation split** (the key fix — recall-first gate).
- §4 "causal"→"isolated effect."
- §5 N=5→10; rerank by composite of inference-available signals (not gold).
- §7 gate on evalset-40+test-30 with CIs + human-review queue; n-power stated as a ceiling.
