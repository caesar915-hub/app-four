# Spike Scope — LoRA Distillation to Fix Omission

Seeds a new spike (`spikes/lora-distillation/`). Continuation of the FLAN-T5 summarizer
evaluation; reuses its locked [METHODOLOGY.md](METHODOLOGY.md), gold anchor, and metric stack.

## Hypothesis
LoRA-fine-tuning flan-t5-large on rejection-sampled teacher summaries **raises gold-signal recall
from 68% → ≥85%** (fixes omission) **while preserving its faithfulness** (MiniCheck support ≥0.789,
**0 confirmed dangerous fabrications**).

**Scope: flan-t5-large ONLY.** T5Gemma is out of this spike — it's gated, a different architecture +
chat format, and fabricates ~2× more at baseline (MiniCheck 0.46 vs 0.789), so it has further to climb.
A gemma LoRA retry is a possible *follow-up* only if flan-large succeeds and completeness still needs more.

## Why (grounded)
Prompting and decoding are exhausted: zero-shot coverage prompts backfired (fallback 3%→47%,
EVALUATION §5/§8), and beam+rerank didn't beat greedy (§8). These T5 models follow demonstrations,
not instructions — LoRA bakes coverage demonstrations into weights *at scale*, beyond a few-shot
prompt's slots. This is Apple's on-device recipe ([rank-16 LoRA on rejection-sampled synthetic
summaries](https://machinelearning.apple.com/research/introducing-apple-foundation-models)).

## Workflow — LOCKED: prep data with Claude HERE → push to cloud VM → train+eval on VM
1. **Here (Claude Code):** generate gold summaries for the TRAIN transcripts, rejection-sample, and write
   the `(transcript → gold-summary)` pairs to a dataset file. This session is the teacher — **no API key
   on the VM**.
2. **Push** the dataset to the cloud Linux VM.
3. **On the VM (GPU):** LoRA-fine-tune flan-t5-large on the pairs, then eval with the v3 metric stack.

Acceptable because the **eval stays external** (MiniCheck + human gate) and pairs are rejection-sampled on
faithfulness — Claude is the *teacher*, never the *grader*. Caveat: a Claude→student dependency exists in
the *training data* (not the evaluation); the real-data human gate ([NEXT-STEPS](NEXT-STEPS.md) A5) is the
ultimate certifier.

## Data recipe (the quality gate)
1. Teacher generates a 3–8 bullet faithful+complete summary for each **train** transcript.
2. **Rejection-sample** — keep a pair only if it passes: MiniCheck support ≥0.7 **and** gold-signal
   recall ≥0.85 **and** no fabrication (judge/human spot-check). Discard + regenerate otherwise.
   Only high-quality teacher outputs become training targets — this is what prevents distilling hallucination.
3. Target ~300–1500 `(transcript → gold summary)` pairs (synthetic-grounded now; add real entries from
   [NEXT-STEPS](NEXT-STEPS.md) A1 when available).

## Data schemas

**1. Input transcripts (what you prepare).** JSON array, same shape as `inputs-grounded-multi.json`.
`note` optional. Keep real entries in their OWN file; **test-30 ids must NEVER appear in training.**
```json
[ { "id": "r001", "transcript": "Took my Concerta 36mg at 8 ...", "note": "optional source tag" } ]
```

**2. Teacher output (what Claude returns per transcript).** Strict JSON, one object per transcript:
```json
{ "id": "r001",
  "summary": ["Took Concerta 36mg at 8", "Crashed around 2:30", "Slept ~5 hours", "Mood went flat after"] }
```
- `summary`: 3–8 bullets, **faithful** (no fabrication), in the person's own words, collectively covering
  every signal present in the source (meds/dose/time, sleep, mood, energy, focus, side-effects, key events).

**3. Training record (after rejection-sampling → pushed to VM).** JSONL, one object per line:
```json
{ "id": "r001",
  "input": "Summarize this ADHD journal entry as 3 to 8 short bullet points in the person's own words. Keep every medication, dose, time, sleep detail, mood, energy, focus, and side-effect that appears. Do not add anything not in the entry.\n\nEntry:\n<transcript>\n\nBullets:",
  "target": "- Took Concerta 36mg at 8\n- Crashed around 2:30\n- Slept ~5 hours\n- Mood went flat after",
  "meta": { "teacher": "claude-<model>", "minicheck_support": 0.91, "gold_recall": 0.88, "source": "real", "accepted": true } }
```
- `input` = the **short fine-tuning prompt** — *no* few-shot examples (LoRA learns the task, so we drop the
  demos; this also keeps the transcript inside flan-t5's 512-token budget). **Identical prompt at train and inference.**
- `target` = the accepted teacher `summary` joined as `- ` bullet lines (the product's output format).
- `meta` = provenance + rejection-sampling scores; **not fed to the model**, kept for audit/repro.

## Method
- LoRA (peft) on flan-large: **rank 16** (Apple), target attn + FFN, seq2seq via `Seq2SeqTrainer`.
- lr ~1e-4–3e-4, few epochs, early-stop on val (faithfulness + recall).
- **Compute — LOCKED: cloud Linux VM (GPU).** flan-t5-large LoRA on the Mac CPU is impractical; train
  **and** eval on the VM. GPU also slashes eval latency (flan-large ~6.5s/entry on Mac CPU → far less on GPU).
- Adapter ships at ~tens of MB (Apple-style, on-device-friendly).

## Splits (no leakage)
- **Train:** teacher-distilled pairs from train/dev transcripts only.
- **Val:** held-out subset for early stopping.
- **Test:** the SAME **test-30** + real held-out — never in training. Evaluated with the identical
  v3 triangulated stack (MiniCheck + judge + gold recall + Wilson CIs + cascade gate) so it's directly
  comparable to the greedy baseline.

## Success criteria
- **Primary:** test-30 gold-signal recall ≥85% (from 68%) **with** MiniCheck support ≥0.789 **and**
  0 confirmed dangerous fabrications. I.e. fix omission *without* trading away faithfulness.
- Head-to-head vs base flan-large (greedy) on the same held-out.
- Report adapter size + on-device latency feasibility.

## Risks / failure modes
- **Distilling hallucination** if the teacher fabricates → mitigated by rejection-sampling on faithfulness.
- **Overfitting to synthetic style** → mitigated by including real data + evaluating on real held-out.
- **Extractive ceiling:** omission may be a fundamental bias LoRA can't move → that's exactly what the
  hypothesis tests; negative result → escalate to two-pass extract-then-condense or a larger base.
- **Teacher = Claude** contamination → eval stays external; note in writeup.

## Conclusion criteria
- **Pass:** recall ≥85% + faithfulness held → proceed to the real-data ship gate (NEXT-STEPS B).
- **Fail:** LoRA insufficient → next spike = two-pass architecture or larger base model.
