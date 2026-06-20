#!/usr/bin/env python3
"""
Compute aggregate statistics from a saved eval.py markdown report.

Usage:
    python aggregate_eval.py results/eval-20260618-164910.md
"""

import argparse
import re
import sys
from pathlib import Path


def parse_eval_md(path: Path) -> list[dict]:
    text = path.read_text()
    rows = []
    # Match quality column: coverage=0.24 halluc=0.0 compress=4.5x med=0/0 sleep=True fx=2/2 arc=True
    for line in text.splitlines():
        if not line.startswith("| "):
            continue
        # Fallback reason = the token immediately before the first quality column.
        rm = re.search(r"\|\s*([a-z_]+)\s*\|\s*coverage=", line)
        m = re.search(
            r"coverage=([\d.]+)\s+halluc=([\d.]+)\s+compress=([\d.]+)x\s+"
            r"med=(\d+)/(\d+)\s+sleep=(True|False)\s+fx=(\d+)/(\d+)\s+arc=(True|False)",
            line,
        )
        if not m:
            continue
        rows.append({
            "reason": rm.group(1) if rm else "none",
            "coverage": float(m.group(1)),
            "hallucination": float(m.group(2)),
            "compression": float(m.group(3)),
            "med_hits": int(m.group(4)),
            "med_total": int(m.group(5)),
            "sleep_ok": m.group(6) == "True",
            "fx_hits": int(m.group(7)),
            "fx_total": int(m.group(8)),
            "arc_ok": m.group(9) == "True",
        })
    return rows


def summarize(rows: list[dict]) -> dict:
    n = len(rows)
    if not n:
        return {}

    # Stratify: quality is measured on non-fallback rows only. The post-processor
    # echoes the source on fallback, which would inflate coverage and zero out
    # hallucination. Fallback rate is the headline model-failure metric.
    clean = [r for r in rows if r.get("reason", "none") == "none"]
    nc = len(clean)

    def avg(key):
        return sum(r[key] for r in clean) / nc if nc else 0.0

    med_hits = sum(r["med_hits"] for r in clean)
    med_total = sum(r["med_total"] for r in clean)
    fx_hits = sum(r["fx_hits"] for r in clean)
    fx_total = sum(r["fx_total"] for r in clean)

    return {
        "n": n,
        "fallback_rate": (n - nc) / n,
        "n_clean": nc,
        "coverage": avg("coverage"),
        "hallucination": avg("hallucination"),
        "compression": avg("compression"),
        "med_recall": med_hits / med_total if med_total else 1.0,
        "fx_recall": fx_hits / fx_total if fx_total else 1.0,
        "sleep_rate": sum(r["sleep_ok"] for r in clean) / nc if nc else 0.0,
        "arc_rate": sum(r["arc_ok"] for r in clean) / nc if nc else 0.0,
    }


def main():
    p = argparse.ArgumentParser()
    p.add_argument("files", nargs="+", help="saved eval markdown files")
    args = p.parse_args()

    print("| file | n | fallback% | n_clean | coverage | halluc | compress | med_recall | fx_recall | sleep_rate | arc_rate |")
    print("|---|---|---|---|---|---|---|---|---|---|---|")

    for f in args.files:
        path = Path(f)
        rows = parse_eval_md(path)
        s = summarize(rows)
        if not s:
            print(f"| {path.name} | 0 | - | - | - | - | - | - | - | - | - |")
            continue
        print(
            f"| {path.name} | {s['n']} | {s['fallback_rate']:.0%} | {s['n_clean']} | "
            f"{s['coverage']:.2f} | {s['hallucination']:.2f} | "
            f"{s['compression']:.1f}x | {s['med_recall']:.2f} | {s['fx_recall']:.2f} | "
            f"{s['sleep_rate']:.2f} | {s['arc_rate']:.2f} |"
        )


if __name__ == "__main__":
    main()
