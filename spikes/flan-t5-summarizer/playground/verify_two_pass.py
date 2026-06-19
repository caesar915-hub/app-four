#!/usr/bin/env python3
"""
Reproducible two-pass verification: topics + signals-classify + summary-technical
across FLAN-T5 and T5Gemma instruction-tuned models.

Run from the .venv-gemma interpreter (transformers >= 4.53 is required for
T5Gemma). Example:

    ../.venv-gemma/bin/python verify_two_pass.py --save

Why this script exists:
- `run.py` is optimized for interactive exploration; this script pins the exact
  benchmark the user asked about (4 models × 6 entries × 3 prompts) and emits a
  clean markdown table that can be diffed against any prior run.
- It keeps each model loaded while sweeping prompts/entries, so reported
  latency is generate-time only (model load is excluded per model).
"""

import argparse
import json
import sys
import time
from dataclasses import replace
from pathlib import Path

import run as run_mod
from prompts import build

HERE = Path(__file__).parent
RESULTS_DIR = HERE / "results"

MODELS = [
    "google/flan-t5-base",
    "google/flan-t5-large",
    "google/t5gemma-b-b-prefixlm-it",
    "google/t5gemma-b-b-ul2-it",
]

PROMPTS = ["topics-only", "signals-classify", "summary-technical"]

INPUTS_PATH = HERE / "inputs-sample6.json"


def run():
    p = argparse.ArgumentParser()
    p.add_argument("--save", action="store_true", help="write results/verify-<stamp>.md")
    p.add_argument("--device", default="auto", help="auto | cpu | mps | cuda")
    args = p.parse_args()

    with open(INPUTS_PATH) as f:
        cases = json.load(f)

    lines = []
    def sink(s):
        print(s)
        lines.append(s)

    sink("# Two-pass verification")
    sink(f"models={MODELS}")
    sink(f"prompts={PROMPTS}")
    sink(f"inputs={INPUTS_PATH.name}")
    sink(f"run={time.strftime('%Y-%m-%d %H:%M:%S')}")
    sink("")

    for model_name in MODELS:
        sink(f"## Model: {model_name}")
        cfg = replace(run_mod.cfg_mod.DEFAULT, model_name=model_name, device=args.device)
        device = run_mod.pick_device(cfg.device)

        # Warm cache once per model.
        print(f"[loading] {model_name} ...", file=sys.stderr)
        t0 = time.perf_counter()
        run_mod.load(model_name, cfg.dtype, device)
        print(f"[loaded] {model_name} in {time.perf_counter()-t0:.1f}s", file=sys.stderr)

        for prompt_name in PROMPTS:
            sink(f"\n### Prompt: {prompt_name}")
            sink("| id | output | latency | in_tok | out_tok |")
            sink("|---|---|---|---|---|")
            for case in cases:
                text, latency, n_in, n_out = run_mod.summarize(cfg, prompt_name, case["transcript"])
                out_cell = text.replace("|", "\\|").replace("\n", "<br>")
                sink(f"| {case['id']} | {out_cell} | {latency:.2f}s | {n_in} | {n_out} |")
        sink("")

    if args.save:
        RESULTS_DIR.mkdir(exist_ok=True)
        stamp = time.strftime("%Y%m%d-%H%M%S")
        out = RESULTS_DIR / f"verify-{stamp}.md"
        out.write_text("\n".join(lines) + "\n")
        print(f"\nSaved → {out}", file=sys.stderr)


if __name__ == "__main__":
    run()
