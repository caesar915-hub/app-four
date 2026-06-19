#!/usr/bin/env python3
"""
Prompt optimization loop for FLAN-T5-large.

Runs several prompts over the same input set, computes aggregate metrics, and
ranks them by a combined faithfulness score.

Usage:
    source ../.venv/bin/activate
    python optimize_prompts.py --input-file inputs-quick.json
    python optimize_prompts.py --input-file inputs.json --save
"""

import argparse
import json
import sys
import time
from pathlib import Path

import run as run_mod
from eval import evaluate, extract_tags, fmt_metrics, post_process
from prompts import PROMPTS

HERE = Path(__file__).parent
RESULTS_DIR = HERE / "results"

PROMPT_LIST = [
    "faithful",
    "faithful-large-3to8",
    "faithful-large-preserve",
    "faithful-large-extract",
    "faithful-large-oneper",
    "faithful-large-fewshot",
    "faithful-large-fewshot-v2",
]


def parse_ratio(s: str) -> tuple[int, int]:
    a, b = s.split("/")
    return int(a), int(b)


def run_prompt(cfg, prompt_name: str, cases: list) -> dict:
    cfg = run_mod.replace(cfg, prompt=prompt_name)
    rows = []
    for case in cases:
        src = case["transcript"]
        raw, latency, n_in, n_out = run_mod.summarize(cfg, prompt_name, src)
        proc, reason = post_process(src, raw)
        m = evaluate(src, proc)
        rows.append({
            "id": case.get("id", "?"),
            "raw": raw,
            "proc": proc,
            "reason": reason,
            "metrics": m,
            "latency": latency,
        })

    n = len(rows)
    avg_coverage = sum(r["metrics"]["coverage"] for r in rows) / n
    avg_halluc = sum(r["metrics"]["hallucination"] for r in rows) / n
    avg_compress = sum(r["metrics"]["compression"] for r in rows) / n
    avg_latency = sum(r["latency"] for r in rows) / n

    med_hits = med_total = 0
    fx_hits = fx_total = 0
    arc_ok = 0
    fallback_count = 0
    for r in rows:
        h, t = parse_ratio(r["metrics"]["med_recall"])
        med_hits += h
        med_total += t
        h, t = parse_ratio(r["metrics"]["side_effect_recall"])
        fx_hits += h
        fx_total += t
        if r["metrics"]["arc_ok"]:
            arc_ok += 1
        if r["reason"] != "none":
            fallback_count += 1

    med_recall = med_hits / med_total if med_total else 1.0
    fx_recall = fx_hits / fx_total if fx_total else 1.0
    arc_rate = arc_ok / n
    fallback_rate = fallback_count / n

    # Combined score: high coverage, low hallucination, high med/fx/arc, low fallback
    score = (
        avg_coverage * 0.25
        + (1 - avg_halluc) * 0.25
        + med_recall * 0.20
        + fx_recall * 0.10
        + arc_rate * 0.10
        + (1 - fallback_rate) * 0.10
    )

    return {
        "prompt": prompt_name,
        "coverage": avg_coverage,
        "hallucination": avg_halluc,
        "compression": avg_compress,
        "med_recall": med_recall,
        "fx_recall": fx_recall,
        "arc_rate": arc_rate,
        "fallback_rate": fallback_rate,
        "avg_latency": avg_latency,
        "score": score,
        "rows": rows,
    }


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--input-file", default=str(HERE / "inputs-quick.json"))
    p.add_argument("--model", default="google/flan-t5-large")
    p.add_argument("--save", action="store_true")
    p.add_argument("--prompts", nargs="+", default=PROMPT_LIST,
                   help="prompt names to compare")
    args = p.parse_args()

    cfg = run_mod.cfg_mod.DEFAULT
    cfg = run_mod.replace(cfg, model_name=args.model)

    with open(args.input_file) as f:
        cases = json.load(f)

    print(f"Optimizing prompts on {len(cases)} cases using {args.model}...", file=sys.stderr)

    results = []
    for prompt_name in args.prompts:
        if prompt_name not in PROMPTS:
            print(f"Unknown prompt '{prompt_name}', skipping.", file=sys.stderr)
            continue
        print(f"  running {prompt_name}...", file=sys.stderr)
        results.append(run_prompt(cfg, prompt_name, cases))

    results.sort(key=lambda r: r["score"], reverse=True)

    lines = []
    def sink(s):
        print(s)
        lines.append(s)

    sink(f"# Prompt optimization results")
    sink(f"model={args.model} | input={args.input_file} | run={time.strftime('%Y-%m-%d %H:%M:%S')}")
    sink("")
    sink("| rank | prompt | score | coverage | halluc | compress | med_recall | fx_recall | arc_rate | fallback_rate | avg_latency |")
    sink("|---|---|---|---|---|---|---|---|---|---|---|")

    for i, r in enumerate(results, 1):
        sink(
            f"| {i} | {r['prompt']} | {r['score']:.3f} | {r['coverage']:.2f} | "
            f"{r['hallucination']:.2f} | {r['compression']:.1f}x | {r['med_recall']:.2f} | "
            f"{r['fx_recall']:.2f} | {r['arc_rate']:.2f} | {r['fallback_rate']:.2f} | {r['avg_latency']:.2f}s |"
        )

    sink("")
    sink("## Best per-case breakdown")
    best = results[0]
    sink(f"Prompt: **{best['prompt']}** | score={best['score']:.3f}")
    sink("")
    sink("| id | raw | post-processed | fallback | quality |")
    sink("|---|---|---|---|---|")
    for r in best["rows"]:
        raw = r["raw"].replace("|", "\\|").replace("\n", "<br>")
        proc = r["proc"].replace("|", "\\|").replace("\n", "<br>")
        sink(f"| {r['id']} | {raw} | {proc} | {r['reason']} | {fmt_metrics(r['metrics'])} |")

    if args.save:
        RESULTS_DIR.mkdir(exist_ok=True)
        stamp = time.strftime("%Y%m%d-%H%M%S")
        out = RESULTS_DIR / f"optimize-{stamp}.md"
        out.write_text("\n".join(lines) + "\n")
        print(f"\nSaved → {out}", file=sys.stderr)


if __name__ == "__main__":
    main()
