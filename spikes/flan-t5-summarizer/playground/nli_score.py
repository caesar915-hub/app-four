#!/usr/bin/env python3
"""
NLI contradiction screening for summarizer outputs.

Bag-of-words coverage/hallucination cannot catch a negation flip ("didn't drink
water" -> "drank water") or a logical contradiction — the words overlap. This
screens each saved eval.py report's RAW model output against the source with a
local NLI model, flagging entries whose worst bullet contradicts the source, so
they can be hand-judged. Triage, not a verdict.

Usage:
    python nli_score.py --inputs inputs-grounded-multi.json results/rematch-*.md
"""
import argparse
import json
import re
from pathlib import Path

import eval as eval_mod


def extract_rows(md_path: Path) -> list[tuple[str, str]]:
    rows = []
    for line in md_path.read_text().splitlines():
        if not line.startswith("| g"):
            continue
        f = line.split(" | ")
        cid = f[0].lstrip("| ").strip()
        raw = f[3].strip() if len(f) > 3 else ""
        rows.append((cid, raw))
    return rows


def bullets(raw: str) -> list[str]:
    parts = re.split(r"<br>|(?<=[.!?])\s+", raw)
    out = []
    for p in parts:
        p = p.strip().lstrip("-").strip().strip('"').strip()
        if len(p) >= 4:
            out.append(p)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--inputs", required=True)
    ap.add_argument("--threshold", type=float, default=0.5)
    ap.add_argument("files", nargs="+")
    args = ap.parse_args()

    src = {e["id"]: e["transcript"] for e in json.load(open(args.inputs))}

    print("| file | n | mean_max_contradiction | flagged(>thr) | flagged% |")
    print("|---|---|---|---|---|")
    for fpath in args.files:
        path = Path(fpath)
        per_entry = []
        flagged = []
        for cid, raw in extract_rows(path):
            source = src.get(cid, "")
            hyps = bullets(raw)
            if not source or not hyps:
                continue
            scores = [eval_mod.contradiction_score(source, h) for h in hyps]
            mx = max(scores)
            per_entry.append(mx)
            if mx >= args.threshold:
                flagged.append((cid, round(mx, 2), hyps[scores.index(mx)]))
        n = len(per_entry)
        if not n:
            print(f"| {path.name} | 0 | - | - | - |")
            continue
        meanmax = sum(per_entry) / n
        nf = len(flagged)
        print(f"| {path.name} | {n} | {meanmax:.3f} | {nf} | {nf/n:.0%} |")
        detail = path.with_suffix(".nli.txt")
        with open(detail, "w") as fh:
            for cid, sc, worst in sorted(flagged, key=lambda x: -x[1]):
                fh.write(f"[{sc}] {cid}: {worst}\n  SRC: {src.get(cid, '')}\n\n")


if __name__ == "__main__":
    main()
