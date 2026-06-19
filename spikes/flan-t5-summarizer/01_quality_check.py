#!/usr/bin/env python3
"""
Stage 1 — Quality gate (PyTorch only, no Core ML).

Verify the selected model produces usable summaries from real journal
transcripts before spending time on conversion.

Pass: output is concise, faithful, correct tone for a health journal.
Fail: news-register prose, hallucinations, refuses/ignores the format.

The prompt is chosen PER MODEL by models.py (instruction template for flan,
"summarize: " prefix for the plain-t5 medical models) — see build_prompt().

Run: python 01_quality_check.py --model flan-small
     python 01_quality_check.py --model medical-falcon
Time: ~2-5 min (first run downloads the model)
"""

import argparse
import json
import time
from pathlib import Path

import torch
from transformers import T5ForConditionalGeneration, AutoTokenizer

from models import add_model_arg, resolve, build_prompt

EVALSET_PATH = Path(__file__).parent.parent / "evalset.json"


def summarize(model, tokenizer, prompt_style, transcript, encoder_len, max_new_tokens):
    prompt = build_prompt(prompt_style, transcript)
    inputs = tokenizer(
        prompt,
        return_tensors="pt",
        max_length=encoder_len,
        truncation=True,
    )
    with torch.no_grad():
        t0 = time.perf_counter()
        output_ids = model.generate(
            **inputs,
            max_new_tokens=max_new_tokens,
            num_beams=1,        # greedy — matches what Core ML will do
            do_sample=False,
        )
        latency = time.perf_counter() - t0

    return tokenizer.decode(output_ids[0], skip_special_tokens=True), latency


def main():
    parser = argparse.ArgumentParser()
    add_model_arg(parser)
    args = parser.parse_args()
    spec = resolve(args)

    print(f"Loading {spec['hf']} ...")
    tokenizer = AutoTokenizer.from_pretrained(spec["hf"])
    model = T5ForConditionalGeneration.from_pretrained(spec["hf"], torch_dtype=torch.float32)
    model.eval()
    print(f"Loaded. prompt='{spec['prompt']}', encoder_len={spec['encoder_len']}\n")

    with open(EVALSET_PATH) as f:
        cases = json.load(f)

    test_ids = [
        "en-med-day", "en-sleep", "en-overwhelm-then-focus",
        "en-neutral", "en-mood-great", "en-exec-stuck",
    ]
    test_cases = [c for c in cases if c["id"] in test_ids] or cases[:6]

    latencies = []
    for case in test_cases:
        print(f"── {case['id']} ──────────────────────────────")
        print(f"Transcript: {case['transcript'][:120]}{'...' if len(case['transcript']) > 120 else ''}")
        summary, latency = summarize(
            model, tokenizer, spec["prompt"], case["transcript"],
            spec["encoder_len"], spec["max_new_tokens"],
        )
        latencies.append(latency)
        print(f"Output:\n{summary}")
        print(f"Latency: {latency:.2f}s\n")

    avg = sum(latencies) / len(latencies)
    print("══ RESULTS ══════════════════════════════════")
    print(f"Model: {spec['hf']}  (prompt='{spec['prompt']}')")
    print(f"Average latency (PyTorch, macOS): {avg:.2f}s  | Min {min(latencies):.2f}s  Max {max(latencies):.2f}s\n")
    print("GATE: review output above before proceeding to 02_convert.py")
    print("  PASS → concise, faithful, correct tone")
    print("  FAIL → wrong format, hallucinations, clinical/news prose")


if __name__ == "__main__":
    main()
