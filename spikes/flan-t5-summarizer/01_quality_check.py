#!/usr/bin/env python3
"""
Stage 1 — Quality gate (PyTorch only, no Core ML).

Goal: verify FLAN-T5-Large produces usable bullet summaries from
real journal transcripts before spending time on conversion.

Pass: bullets are concise, use the user's own phrases, correct tone.
Fail: news-register prose, hallucinations, refuses the format.

Run: python 01_quality_check.py
Time: ~2-5 min (first run downloads ~3GB model)
"""

import time
import json
from pathlib import Path
import torch
from transformers import T5ForConditionalGeneration, AutoTokenizer

MODEL_NAME = "google/flan-t5-base"
EVALSET_PATH = Path(__file__).parent.parent / "evalset.json"

PROMPT_TEMPLATE = """Summarize the following journal entry as 3 short bullet points.
Use the person's own words and key phrases. Do not add anything not in the entry.
Start each bullet with "•".

Journal entry:
{transcript}

Bullet points:"""

def summarize(model, tokenizer, transcript: str, max_new_tokens: int = 120) -> str:
    prompt = PROMPT_TEMPLATE.format(transcript=transcript.strip())
    inputs = tokenizer(
        prompt,
        return_tensors="pt",
        max_length=512,
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

    decoded = tokenizer.decode(output_ids[0], skip_special_tokens=True)
    return decoded, latency


def main():
    print(f"Loading {MODEL_NAME}...")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
    model = T5ForConditionalGeneration.from_pretrained(MODEL_NAME, torch_dtype=torch.float32)
    model.eval()
    print("Model loaded.\n")

    # Load evalset transcripts
    with open(EVALSET_PATH) as f:
        cases = json.load(f)

    # Test on a representative subset
    test_ids = [
        "en-med-day",        # medication + crash + win
        "en-sleep",          # sleep + medication skip + foggy
        "en-overwhelm-then-focus",  # arc: overwhelmed → locked in
        "en-neutral",        # should produce minimal/no bullets
        "en-mood-great",     # short positive entry
        "en-exec-stuck",     # executive dysfunction
    ]

    test_cases = [c for c in cases if c["id"] in test_ids]
    if not test_cases:
        # Fallback: use first 6
        test_cases = cases[:6]

    latencies = []
    for case in test_cases:
        print(f"── {case['id']} ──────────────────────────────")
        print(f"Transcript: {case['transcript'][:120]}{'...' if len(case['transcript']) > 120 else ''}")
        print(f"Labels: mood={case.get('mood')}, energy={case.get('energy')}, focus={case.get('focus')}")
        summary, latency = summarize(model, tokenizer, case["transcript"])
        latencies.append(latency)
        print(f"Output:\n{summary}")
        print(f"Latency: {latency:.2f}s\n")

    avg = sum(latencies) / len(latencies)
    print(f"══ RESULTS ══════════════════════════════════")
    print(f"Average latency (PyTorch, macOS): {avg:.2f}s")
    print(f"Min: {min(latencies):.2f}s  Max: {max(latencies):.2f}s")
    print()
    print("GATE: review output above before proceeding to 02_convert.py")
    print("  PASS → bullets are concise, use original phrases, correct tone")
    print("  FAIL → wrong format, hallucinations, news-style prose")


if __name__ == "__main__":
    main()
