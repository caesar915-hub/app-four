#!/usr/bin/env python3
"""Generate spikes/evalset.json from the Swift source of truth (EvalSet.swift).

Parses the EvalCase(...) literals so the Phase-0 spikes score on the SAME inputs
the in-app eval uses — no hand-copying of gold labels (which would risk a silent
error that corrupts the whole comparison). Re-run whenever EvalSet.swift changes.
"""
import json
import re
from collections import Counter
from pathlib import Path

SRC = Path(__file__).resolve().parent.parent / "app-fourTests" / "Eval" / "EvalSet.swift"
OUT = Path(__file__).resolve().parent / "evalset.json"


def grab(pattern, chunk):
    m = re.search(pattern, chunk)
    return m.group(1) if m else None


def main():
    text = SRC.read_text()
    # Each case is an EvalCase(...) literal; splitting on the constructor gives one
    # chunk per case (chunk = that case's fields, up to the next EvalCase).
    chunks = text.split("EvalCase(")[1:]
    rows = []
    for ch in chunks:
        rid = grab(r'id:\s*"([^"]*)"', ch)
        transcript = grab(r'transcript:\s*"((?:[^"\\]|\\.)*)"', ch)
        if not rid or not transcript:
            continue
        rows.append({
            "id": rid,
            "transcript": transcript,
            # mood is a quoted rawValue; energy/focus are .enumCase whose name == rawValue
            "mood": grab(r'\bmood:\s*"([^"]*)"', ch),
            "energy": grab(r'\benergy:\s*\.(\w+)', ch),
            "focus": grab(r'\bfocus:\s*\.(\w+)', ch),
        })

    OUT.write_text(json.dumps(rows, indent=2))
    print(f"wrote {OUT}  —  {len(rows)} cases")
    for k in ("mood", "energy", "focus"):
        present = Counter(r[k] for r in rows if r[k])
        print(f"  {k:7} labeled in {sum(present.values()):2d}/{len(rows)} cases: {dict(present)}")


if __name__ == "__main__":
    main()
