#!/usr/bin/env python3
"""
Stage 4 — Core ML inference loop + latency benchmark.

Tests both FP16 and INT8 models against the evalset.
Reports per-stage latency (encode / decode / total) and output quality.

This is the go/no-go gate for iOS integration:
  PASS: total latency < 20s AND output quality matches PyTorch (01_quality_check.py)
  FAIL: latency > 20s → Core ML not viable on A14; reconsider architecture

A14 iPhone 12 Pro is ~2-3x slower than Apple Silicon Mac on GPU tasks.
Multiply macOS latency by 2.5 to estimate on-device worst case.

Run: python 04_benchmark.py
     python 04_benchmark.py --int8      (test INT8 models)
     python 04_benchmark.py --fp16      (test FP16 models, default)
"""

import argparse
import json
import time
from pathlib import Path

import coremltools as ct
import numpy as np
from transformers import AutoTokenizer

MODEL_NAME   = "google/flan-t5-base"
ENCODER_LEN  = 128
MAX_NEW_TOKENS = 80
EOS_TOKEN_ID   = 1    # T5 EOS
PAD_TOKEN_ID   = 0
DECODER_START  = 0    # T5 decoder_start_token_id

OUT_DIR      = Path(__file__).parent
EVALSET_PATH = Path(__file__).parent.parent / "evalset.json"

PROMPT_TEMPLATE = """Summarize the following journal entry as 3 short bullet points.
Use the person's own words and key phrases. Do not add anything not in the entry.
Start each bullet with "•".

Journal entry:
{transcript}

Bullet points:"""


def load_models(use_int8: bool):
    suffix = "_INT8" if use_int8 else ""
    enc_path = OUT_DIR / f"FlanT5BaseEncoder{suffix}.mlpackage"
    dec_path = OUT_DIR / f"FlanT5BaseDecoder{suffix}.mlpackage"

    for p in [enc_path, dec_path]:
        if not p.exists():
            stage = "03_quantize.py" if use_int8 else "02_convert.py"
            raise FileNotFoundError(f"Missing: {p}\nRun {stage} first.")

    print(f"Loading {'INT8' if use_int8 else 'FP16'} models...")
    encoder = ct.models.MLModel(str(enc_path))
    decoder = ct.models.MLModel(str(dec_path))
    print("Models loaded.\n")
    return encoder, decoder


def tokenize_prompt(tokenizer, transcript: str):
    prompt = PROMPT_TEMPLATE.format(transcript=transcript.strip())
    enc = tokenizer(
        prompt,
        return_tensors="np",
        max_length=ENCODER_LEN,
        truncation=True,
        padding="max_length",
    )
    return enc["input_ids"].astype(np.int32), enc["attention_mask"].astype(np.int32)


def greedy_decode(encoder, decoder, input_ids, attention_mask, max_new_tokens: int):
    # ── Encode ──────────────────────────────────────────────────────────
    t_enc_start = time.perf_counter()
    enc_out = encoder.predict({
        "input_ids":      input_ids,
        "attention_mask": attention_mask,
    })
    t_enc = time.perf_counter() - t_enc_start

    encoder_hidden_states  = enc_out["encoder_hidden_states"].astype(np.float32)

    # ── Decode (greedy, no KV cache) ─────────────────────────────────────
    decoder_input_ids = np.array([[DECODER_START]], dtype=np.int32)
    generated = []

    t_dec_start = time.perf_counter()
    for step in range(max_new_tokens):
        dec_out = decoder.predict({
            "decoder_input_ids":      decoder_input_ids,
            "encoder_hidden_states":  encoder_hidden_states,
            "encoder_attention_mask": attention_mask,
        })
        logits   = dec_out["logits"]           # [1, vocab_size]
        next_id  = int(np.argmax(logits[0]))   # greedy

        if next_id == EOS_TOKEN_ID:
            break

        generated.append(next_id)
        decoder_input_ids = np.concatenate(
            [decoder_input_ids, np.array([[next_id]], dtype=np.int32)],
            axis=1,
        )
    t_dec = time.perf_counter() - t_dec_start

    return generated, t_enc, t_dec


def main():
    parser = argparse.ArgumentParser()
    group  = parser.add_mutually_exclusive_group()
    group.add_argument("--int8",  action="store_true")
    group.add_argument("--fp16",  action="store_true", default=True)
    args = parser.parse_args()
    use_int8 = args.int8

    encoder, decoder = load_models(use_int8)
    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)

    with open(EVALSET_PATH) as f:
        cases = json.load(f)

    test_ids = [
        "en-med-day",
        "en-sleep",
        "en-overwhelm-then-focus",
        "en-neutral",
        "en-mood-great",
        "en-exec-stuck",
    ]
    test_cases = [c for c in cases if c["id"] in test_ids] or cases[:6]

    enc_times, dec_times, total_times = [], [], []

    for case in test_cases:
        print(f"── {case['id']} ────────────────────────────────")
        input_ids, attention_mask = tokenize_prompt(tokenizer, case["transcript"])

        token_ids, t_enc, t_dec = greedy_decode(
            encoder, decoder, input_ids, attention_mask, MAX_NEW_TOKENS
        )
        total = t_enc + t_dec
        enc_times.append(t_enc)
        dec_times.append(t_dec)
        total_times.append(total)

        text = tokenizer.decode(token_ids, skip_special_tokens=True)
        tokens_generated = len(token_ids)

        print(f"Output:\n{text}")
        print(f"Encode: {t_enc:.2f}s | Decode: {t_dec:.2f}s ({tokens_generated} tokens, "
              f"{tokens_generated/t_dec:.1f} tok/s) | Total: {total:.2f}s\n")

    # ── Summary ─────────────────────────────────────────────────────────
    print("══ BENCHMARK SUMMARY ════════════════════════════")
    label = "INT8" if use_int8 else "FP16"
    print(f"Model:           FLAN-T5-Large {label}")
    print(f"Avg encode:      {sum(enc_times)/len(enc_times):.2f}s")
    print(f"Avg decode:      {sum(dec_times)/len(dec_times):.2f}s")
    print(f"Avg total:       {sum(total_times)/len(total_times):.2f}s")
    print(f"Max total:       {max(total_times):.2f}s")
    print()

    avg_total = sum(total_times) / len(total_times)
    a14_estimate = avg_total * 2.5
    print(f"A14 estimate:    ~{a14_estimate:.0f}s (macOS × 2.5 rough multiplier)")
    print()

    if avg_total < 8:
        print("GATE: ✓ PASS — latency acceptable, proceed to Swift integration")
    elif avg_total < 20:
        print("GATE: ⚠ MARGINAL — check A14 estimate, may be acceptable as background task")
    else:
        print("GATE: ✗ FAIL — too slow for on-device use, reconsider architecture")


if __name__ == "__main__":
    main()
