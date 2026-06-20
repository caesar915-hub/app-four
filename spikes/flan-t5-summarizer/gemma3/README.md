# Edge-Gemma summarization arm

Decoder-only counterpart to the flan-t5 spike. **Hypothesis:** can a tiny/edge
*decoder-only* Gemma faithfully summarize ADHD voice-note journal entries —
preserving meds/doses/times/sleep/mood without fabricating — at ~4-bit?

The locked v3 result ([../ROADMAP.md](../ROADMAP.md)): `flan-t5-large` is faithful
(MiniCheck **0.789** on test-30) but omits ~32% of signals; the T5Gemma
encoder-decoders are complete but fabricate. This arm tests a different model class.

## Models

| key | hf_id | quant | notes |
|---|---|---|---|
| `g3-270m` | `google/gemma-3-270m-it` | f16 | too small to quantize; expect heavy fabrication (a finding) |
| `g3-1b` | `google/gemma-3-1b-it` | int4 NF4 | gated(manual) |
| `g4-e4b` | `google/gemma-4-E4B-it` | int4 NF4 | multimodal (`any-to-any`), used text-only |

`g3-270m-it`/`g3-1b-it` are **gated** — accept each model's license on its HF page
with the account behind `HF_TOKEN` before downloading.

## ⚠ NF4 is a proxy, not the shipped artifact

The int4 weights here are **bitsandbytes dynamic NF4 inside transformers** — a
*proxy* for edge quantization, **not** Google's shipped QAT-`q4_0` GGUF that runs on
device via llama.cpp / MediaPipe. Two consequences:
1. **Quality** can differ either way — QAT is trained-for-4bit and may beat post-hoc
   NF4 at the same bit-width.
2. **Latency / VRAM** here (PyTorch+bnb on a T4) are **not** representative of phone
   inference.

This arm answers *"can a tiny decoder-only Gemma summarize faithfully at ~4-bit?"* —
not *"what exactly ships."* State alongside [../METHODOLOGY.md](../METHODOLOGY.md) §0's
synthetic-data limitation.

## Why a separate script + venv

These models are **decoder-only**: `generate()` returns prompt+completion, so
[summarize.py](summarize.py) slices the prompt tokens (`out[:, input_len:]`) before
decoding. The seq2seq path in `../playground/run.py` decodes the whole output and
would echo the prompt. The spike also pins `transformers==4.40.0` (predates Gemma
3/4), so this arm needs its own `.venv-gemma` — separate from the LoRA `.venv-lora`.

The harness **reuses** the LOCKED-v3 row metrics (`evaluate`, `post_process`,
`fmt_*`) and the `gemma-faithful` prompt from `../playground/`, so the rule-based
numbers are directly comparable to the flan-t5 runs.

## Run

**Local CPU smoke test** (270m is f16 — no GPU/bitsandbytes needed):
```bash
python summarize.py --model g3-270m --device cpu --limit 2
```
Confirms cross-dir imports, chat template, and the slicing contract (the raw cell
must NOT contain the prompt). The int4 models require CUDA.

**On the T4 VM** (one-time env, then one model per process — 16 GB VRAM):
```bash
HF_TOKEN=hf_xxx bash gemma3/setup_vm_gemma.sh        # builds .venv-gemma, prefetches
source ../.venv-gemma/bin/activate
cd ..                                                # spike root
python gemma3/summarize.py --model g3-1b   --save
python gemma3/summarize.py --model g3-270m --save
python gemma3/summarize.py --model g4-e4b  --save --no-repeat-ngram 3 --repetition-penalty 1.2
```
Watch `nvidia-smi` for OOM. If outputs loop, add `--no-repeat-ngram 3
--repetition-penalty 1.2`.

**Faithfulness fast-follow** (MiniCheck, comparable to flan-large 0.789):
```bash
python ../playground/minicheck_score.py \
  --inputs ../playground/inputs-test30.json --test-only results/*.md
```

## Files

| file | role |
|---|---|
| [models.py](models.py) | `GemmaSpec` registry (hf_id, quant, gated, multimodal) |
| [summarize.py](summarize.py) | harness: load → generate (slice) → reuse eval.py metrics → markdown + aggregate |
| [download_models.py](download_models.py) | prefetch weights, fail fast on gating |
| [setup_vm_gemma.sh](setup_vm_gemma.sh) | build `.venv-gemma` on the existing VM |
| [requirements.txt](requirements.txt) | transformers 5.x + bitsandbytes + accelerate |
