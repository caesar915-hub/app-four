#!/usr/bin/env python3
"""
Stage 4 — Core ML inference loop + latency benchmark.

Model selected via --model (see models.py). Tests FP16 or INT8 against the
evalset, reporting per-stage latency (encode / decode / total) and output.

  PASS: total latency < 20s (macOS) AND output matches the 01 quality gate
  FAIL: too slow on the A14 estimate → reconsider architecture

A14 iPhone 12 Pro ≈ 2.5× slower than Apple Silicon Mac on GPU tasks.

Run: python 04_benchmark.py --model flan-small --fp16
     python 04_benchmark.py --model flan-small --int8
"""

import argparse
import json
import time
from pathlib import Path

import coremltools as ct
import numpy as np
from transformers import AutoTokenizer

from models import (
    add_model_arg, resolve, build_prompt,
    EOS_TOKEN_ID, DECODER_START,
)

OUT_DIR      = Path(__file__).parent
EVALSET_PATH = Path(__file__).parent.parent / "evalset.json"


def load_models(prefix: str, use_int8: bool):
    suffix = "_INT8" if use_int8 else ""
    enc_path = OUT_DIR / f"{prefix}Encoder{suffix}.mlpackage"
    dec_path = OUT_DIR / f"{prefix}Decoder{suffix}.mlpackage"

    for p in (enc_path, dec_path):
        if not p.exists():
            stage = "03_quantize.py" if use_int8 else "02_convert.py"
            raise FileNotFoundError(f"Missing: {p}\nRun {stage} first.")

    print(f"Loading {'INT8' if use_int8 else 'FP16'} models ({prefix})...")
    encoder = ct.models.MLModel(str(enc_path))
    decoder = ct.models.MLModel(str(dec_path))
    print("Models loaded.\n")
    return encoder, decoder


def tokenize_prompt(tokenizer, prompt_style, transcript, encoder_len):
    prompt = build_prompt(prompt_style, transcript)
    enc = tokenizer(
        prompt,
        return_tensors="np",
        max_length=encoder_len,
        truncation=True,
        padding="max_length",
    )
    return enc["input_ids"].astype(np.int32), enc["attention_mask"].astype(np.int32)


def greedy_decode(encoder, decoder, input_ids, attention_mask, max_new_tokens):
    t0 = time.perf_counter()
    enc_out = encoder.predict({"input_ids": input_ids, "attention_mask": attention_mask})
    t_enc = time.perf_counter() - t0
    encoder_hidden_states = enc_out["encoder_hidden_states"].astype(np.float32)

    decoder_input_ids = np.array([[DECODER_START]], dtype=np.int32)
    generated = []

    t0 = time.perf_counter()
    for _ in range(max_new_tokens):
        dec_out = decoder.predict({
            "decoder_input_ids":      decoder_input_ids,
            "encoder_hidden_states":  encoder_hidden_states,
            "encoder_attention_mask": attention_mask,
        })
        next_id = int(np.argmax(dec_out["logits"][0]))
        if next_id == EOS_TOKEN_ID:
            break
        generated.append(next_id)
        decoder_input_ids = np.concatenate(
            [decoder_input_ids, np.array([[next_id]], dtype=np.int32)], axis=1,
        )
    t_dec = time.perf_counter() - t0
    return generated, t_enc, t_dec


def main():
    parser = argparse.ArgumentParser()
    add_model_arg(parser)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--int8", action="store_true")
    group.add_argument("--fp16", action="store_true", default=True)
    args = parser.parse_args()
    spec = resolve(args)
    use_int8 = args.int8

    encoder, decoder = load_models(spec["prefix"], use_int8)
    tokenizer = AutoTokenizer.from_pretrained(spec["hf"])

    with open(EVALSET_PATH) as f:
        cases = json.load(f)
    test_ids = [
        "en-med-day", "en-sleep", "en-overwhelm-then-focus",
        "en-neutral", "en-mood-great", "en-exec-stuck",
    ]
    test_cases = [c for c in cases if c["id"] in test_ids] or cases[:6]

    enc_times, dec_times, total_times = [], [], []
    for case in test_cases:
        print(f"── {case['id']} ────────────────────────────────")
        input_ids, attention_mask = tokenize_prompt(
            tokenizer, spec["prompt"], case["transcript"], spec["encoder_len"],
        )
        token_ids, t_enc, t_dec = greedy_decode(
            encoder, decoder, input_ids, attention_mask, spec["max_new_tokens"],
        )
        total = t_enc + t_dec
        enc_times.append(t_enc); dec_times.append(t_dec); total_times.append(total)

        text = tokenizer.decode(token_ids, skip_special_tokens=True)
        n = len(token_ids)
        print(f"Output:\n{text}")
        print(f"Encode: {t_enc:.2f}s | Decode: {t_dec:.2f}s ({n} tokens, "
              f"{n/t_dec:.1f} tok/s) | Total: {total:.2f}s\n")

    label = "INT8" if use_int8 else "FP16"
    print("══ BENCHMARK SUMMARY ════════════════════════════")
    print(f"Model:           {spec['hf']} {label}")
    print(f"Avg encode:      {sum(enc_times)/len(enc_times):.2f}s")
    print(f"Avg decode:      {sum(dec_times)/len(dec_times):.2f}s")
    avg_total = sum(total_times) / len(total_times)
    print(f"Avg total:       {avg_total:.2f}s")
    print(f"Max total:       {max(total_times):.2f}s")
    print(f"A14 estimate:    ~{avg_total*2.5:.0f}s (macOS × 2.5 rough multiplier)\n")

    if avg_total < 8:
        print("GATE: ✓ PASS — latency acceptable, proceed to Swift integration")
    elif avg_total < 20:
        print("GATE: ⚠ MARGINAL — check A14 estimate, may be OK as background task")
    else:
        print("GATE: ✗ FAIL — too slow for on-device use, reconsider architecture")


if __name__ == "__main__":
    main()
