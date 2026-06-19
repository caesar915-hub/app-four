# FLAN-T5 model concepts — knowledge notes

Reference notes (not a task). Captures how the model behaves re: state, memory,
learning, and personalization, for the on-device summarizer spike. Latency/KV-cache
tuning is deliberately out of scope here — see README for the build pipeline.

## Core fact: the model is stateless and frozen

FLAN-T5 inference is a **pure function** — same input → same output, every time,
with zero memory of any previous run. Spinning it up again is always a blank slate.
It does **not** learn, remember, or adapt on its own. Any sense of the app
"remembering the user" is engineered *around* the model, never *by* it.

## Three separate layers (don't conflate them)

| Layer | What it is | Lifetime | Changes how? | Is it "memory"? |
|---|---|---|---|---|
| **Weights** (the brain) | The 248M (Base) / 783M (Large) numbers that *are* the model | Permanent, frozen at inference | Only by **fine-tuning**, offline | Long-term knowledge |
| **KV cache** (scratchpad) | K/V vectors for the current generation | One summary, then discarded | Not tunable — deterministic byproduct | ❌ No. Pure speed. |
| **App state** (SwiftData) | Preferences, past entries, history *you* save | Whatever you decide | You write/read it | ✅ The product's real memory |

The mistake to avoid: thinking the KV cache or the model itself holds
personalization or "learning." It doesn't. **The model is stateless; the app
supplies all memory.**

## Quick answers

- **Use KV cache for my use case?** It's only a per-generation speed optimization.
  Irrelevant to memory/personalization. Out of scope until on-device latency work.
- **Tune the KV cache?** No knob — deterministic from weights + input. (Serving
  tricks like cache quantization / prefix-reuse exist; none personalize anything.)
- **Fine-tune the model?** **Yes** — the real lever. Offline (Mac/cloud) with
  (transcript → desired summary) pairs, then re-export to Core ML. Not on-device.
- **Does it use RAM?** Yes while loaded (weights + activations). Stores nothing
  about users or past runs.
- **Remember past processing between runs?** No. Fully amnesiac.
- **Store the processing (KV cache)?** Only useful for a *shared prefix* (prompt
  caching). Useless for remembering different user content.
- **Store "methods" / prompt templates / rules?** Yes — as app config
  (SwiftData/JSON). The model holds none of it.
- **Store user preferences?** Yes — SwiftData, then inject relevant ones into the
  prompt each run.
- **Optimize?** Always ask "optimize *what*": quality → fine-tune + better prompts;
  personalization → inject app state; latency/size → quant/KV/ANE (later).
- **"Learn" from user inputs?** Not by itself. Two meanings below.

## "Learning" — two meanings, both available

1. **Real learning (weights change) = fine-tuning.** Offline, deliberate, batched —
   not per-tap. Bakes in tone/style permanently.
   - Cheapest path: **LoRA / adapters** — train a few million extra params instead
     of all 248M, on the Mac. Mergeable, re-exportable to Core ML.
2. **In-context "learning" (weights frozen).** Put preferences / a few past entries /
   example phrasings *into the prompt*. The model conditions on them for that one
   call, then forgets. This is how to make it *feel* adaptive on-device with no
   training.
   - e.g. prepend "This user prefers terse, lowercase bullets. Past phrasing: '…'",
     pulled from SwiftData.

## Recommended shape for this app

Use **in-context injection + optionally a one-time fine-tune for house tone** —
never on-device training.

- **Personalization / "memory" → SwiftData.** Own a store of preferences + past
  entries; a small selector picks what to inject per prompt. Model stays frozen.
- **Consistent house style → one offline LoRA fine-tune** on a few hundred example
  summaries, re-exported. Done once, shipped, repeated rarely.
- **Don't** try to make the model remember across runs or learn live — dead end on
  a frozen on-device model.

## Two insights worth keeping

- **Amnesia is a privacy feature.** A stateless on-device model that forgets every
  input is exactly right for an ADHD journaling app — nothing leaks between sessions
  unless *you* persisted it in SwiftData. The privacy story lives in what the app
  stores, not in the model.
- **Fine-tune vs. inject is a latency/flexibility trade.** Fine-tuning is fast at
  runtime (style baked in, no extra tokens) but rigid (re-train to change).
  In-context injection is instant to change (edit SwiftData) but costs prompt tokens
  every run and eats the 128-token encoder budget (`02_convert.py` `ENCODER_LEN`).
  For a 128-token-input model that budget pressure is real → bake durable style into
  weights, inject only the volatile user-specific bits.
