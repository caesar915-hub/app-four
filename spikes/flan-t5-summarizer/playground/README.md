# FLAN-T5 quality playground (PyTorch, laptop)

Test summarization quality in pure PyTorch **before** any Core ML / Swift work.
This answers "is FLAN-T5 good enough, and which prompt/size?" — not "does INT8
degrade it" (that's the Core ML path: `../02..04`).

## Setup

```bash
cd spikes/flan-t5-summarizer
python3.11 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cd playground
```

First run downloads the model (~1GB for base, ~3GB for large).

## Run

### Main runner

```bash
python run.py                       # all inputs.json, default (faithful) prompt
python run.py --interactive         # type entries live
python run.py --input "text..."     # one-off
python run.py --all-prompts         # compare faithful / balanced / fluent / one_line
python run.py --model google/flan-t5-large
python run.py --compare-models      # base vs large side-by-side
python run.py --evalset             # pull transcripts from ../../evalset.json
python run.py --save                # write results/<timestamp>.md
```

Generation knobs: `--num-beams 4`, `--sample --temperature 0.7 --top-p 0.9`,
`--repetition-penalty 1.3`, `--no-repeat-ngram 3`, `--max-new-tokens 80`.

### Quality evaluation (with fallback analysis)

```bash
python eval.py                       # quick eval on inputs-quick.json
python eval.py --input-file inputs.json --save
python eval.py --prompt faithful-large-fewshot-v2  # best Large prompt
```

`eval.py` runs the chosen prompt and applies a stack of safety fallbacks:
meta-language detection, hallucination detection, short-source handling,
repetition-loop detection, negation-flip detection, and a medical high-hallucination
fallback. It prints a markdown table of input → tags → raw output → post-processed
output → quality metrics, and writes to `results/eval-<timestamp>.md` when `--save`
is used.

### Prompt optimization

```bash
python optimize_prompts.py --input-file inputs-quick.json --save
```

`optimize_prompts.py` runs every candidate prompt over the same input set and
ranks them by a combined faithfulness score. Use it to compare new prompt
candidates against the current best.

### Aggregate stats from saved reports

```bash
python aggregate_eval.py results/eval-<timestamp>.md
```

## The three files you edit

| File | What |
|---|---|
| `config.py` | persistent defaults — model, dtype, device, generation params |
| `prompts.py` | named prompt templates — the biggest quality lever |
| `inputs.json` | your test transcripts — add your own real entries here |

## Fetching markdown transcripts from Google Drive

Two approaches:

### Simple: gdown (recommended, no setup)

```bash
# One-time setup
pip install gdown

# Download all .md files from your Drive folder
bash fetch_drive_simple.sh 1SMlbSBhQE9ClYo2uqdzPEhd3aopYVlzV

# Process the markdown files into inputs.json
python fetch_md_to_inputs.py --md-dir ./gdown_files
```

### Advanced: Google Drive API (if you prefer direct integration)

Set up OAuth credentials in [Google Cloud Console](https://console.cloud.google.com):
1. Create a project → Enable Google Drive API
2. OAuth Consent Screen → Create credentials (Desktop app)
3. Download JSON → update `CLIENT_ID`/`CLIENT_SECRET` in `fetch_drive_to_inputs.py`

```bash
pip install google-auth-oauthlib google-auth-httplib2 google-api-python-client
python fetch_drive_to_inputs.py --folder-id 1SMlbSBhQE9ClYo2uqdzPEhd3aopYVlzV
```

## Gotchas (verified)

- **float32, not float16.** T5 emits `nan` logits in fp16 (known issue) → empty
  output. Default is `float32`; `bfloat16` is the fast safe option on Apple Silicon.
- **MPS is auto-skipped.** On this torch/transformers combo, `torch.isin` (used
  inside `generate()` stopping criteria) is not implemented on MPS and crashes.
  `auto` therefore picks `cuda → cpu`. Pass `--device cpu` explicitly if needed.
- **Greedy by default** (`num_beams=1`, no sampling) to match the Core ML decoder.
  Beams/sampling read better but won't reflect on-device output.
- **Latency here ≠ on-device.** PyTorch on your Mac (esp. with KV cache, which
  `generate()` uses) is far faster than the no-KV-cache Core ML decoder. Use the
  Core ML benchmark (`../04_benchmark.py`) for the real on-device number.

## What to look for

For a health journal, the bar is **faithfulness** (no invented details, the
person's own voice) over fluency. Run `--all-prompts` on your real entries and
pick the template that summarizes without paraphrasing feelings into clinical
language. That choice carries straight into the Swift prompt.

## Current best known config

On the 53-entry `inputs.json` test set, the highest-quality output comes from
`google/flan-t5-large` + the `faithful-large-fewshot-v2` prompt, with the
post-processing fallback stack enabled:

| model / prompt | coverage | halluc | med_recall | fx_recall | arc_rate |
|---|---|---|---|---|---|
| google/flan-t5-base + faithful | 0.74 | 0.00 | 1.00 | 0.79 | 0.98 |
| google/flan-t5-large + faithful-large-fewshot-v2 | **0.80** | **0.00** | **1.00** | **1.00** | **1.00** |

Trade-off: Large is ~3–5× slower on CPU and ~3× larger than Base. If on-device
latency or model size matters more than the last few points of recall, Base
remains the practical choice.
