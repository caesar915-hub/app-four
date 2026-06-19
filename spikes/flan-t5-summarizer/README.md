# FLAN-T5-Base summarization spike

On-device journal summarization using FLAN-T5-Base INT8 via Core ML.
Goal: bullet-point summaries using the user's own phrases, no API.

## Gates (stop if any fail)

| Stage | Script | Gate |
|---|---|---|
| 1 Quality | `01_quality_check.py` | Bullets are concise, correct tone, user's phrases |
| 2 Convert | `02_convert.py` | Both .mlpackage files produced without error |
| 3 Quantize | `03_quantize.py` | INT8 models ~50% size of FP16 |
| 4 Benchmark | `04_benchmark.py` | Avg total latency < 20s (macOS); A14 estimate < 30s |

## Setup

```bash
cd spikes/flan-t5-summarizer
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Requires Apple Silicon Mac. First run downloads ~3GB (FLAN-T5-Base weights).

## Run in order

```bash
python 01_quality_check.py     # ~5 min, review output manually
python 02_convert.py           # ~15 min, produces FP16 .mlpackage files
python 03_quantize.py          # ~5 min, produces INT8 .mlpackage files
python 04_benchmark.py --fp16  # test FP16 latency
python 04_benchmark.py --int8  # test INT8 latency — compare both
```

## Architecture

```
Transcript
  → tokenize (T5 SentencePiece, seq_len=128, truncate/pad)
  → Encoder (run once) → encoder_hidden_states [1, 128, 768]
  → Decoder loop (greedy, no KV cache):
      step 0: decoder_input_ids=[0] → logits [1, 32128] → token_1
      step 1: decoder_input_ids=[0, token_1] → logits → token_2
      ...until EOS or max_new_tokens=80
  → detokenize → bullet string
```

No KV cache (use_past=False is the only supported export mode).
Decoder re-processes all previous tokens each step — acceptable for
short outputs (3-5 bullets ≈ 40-60 tokens).

## Known risks

- Flexible decoder shapes → CPU/GPU only (no ANE on iOS)
- A14 is ~2-3x slower than M-series Mac
- T5 SentencePiece tokenizer needs testing in Swift
- No working Swift encoder-decoder inference in swift-transformers yet

## Output models

| File | Size (approx) |
|---|---|
| FlanT5BaseEncoder.mlpackage | ~500MB |
| FlanT5BaseDecoder.mlpackage | ~1.0GB |
| FlanT5BaseEncoder_INT8.mlpackage | ~250MB |
| FlanT5BaseDecoder_INT8.mlpackage | ~500MB |
