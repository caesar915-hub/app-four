#!/usr/bin/env python3
"""
Deterministic temporal grounding post-editor (fixes extrinsic am/pm hallucination).

A faithful summary must not assert specificity the source never gave. T5Gemma
appends a meridiem to bare source times ("at 8" -> "8:00 am", "2:30" -> "2:30 am"),
which for an afternoon event is a *wrong* and dangerous temporal claim. This is a
textbook extrinsic hallucination (Maynez et al. 2020); for a structured field the
correction is deterministic, not learned (cf. Chen et al. 2021 contrast-candidate
correction).

Rule (strip, don't guess): for each meridiem-bearing time in the output, keep the
meridiem ONLY if the source states that same (hour, am/pm). Otherwise strip the
meridiem back to the bare time the source actually supports. We never *infer* the
correct meridiem — that would substitute one unsupported claim for another.

Usage:
    python ground_times.py --inputs inputs-grounded-multi.json results/multi-gemma-*.md
    -> writes results/<name>.grounded.md and prints a per-file correction count.
"""
import argparse
import json
import re
from pathlib import Path

TIME_MER = re.compile(r"\b(\d{1,2})(:\d{2})?\s*([ap])\.?m\.?\b", re.I)


def source_meridiems(source: str):
    return {(int(m.group(1)) % 12, m.group(3).lower())
            for m in TIME_MER.finditer(source)}


def ground_output(source: str, output: str):
    """Return (corrected_output, n_stripped)."""
    grounded = source_meridiems(source)
    n = 0

    def fix(m):
        nonlocal n
        hour, mins, mer = int(m.group(1)), m.group(2) or "", m.group(3).lower()
        if (hour % 12, mer) in grounded:
            return m.group(0)
        n += 1
        return f"{m.group(1)}{mins}"

    return TIME_MER.sub(fix, output), n


def _selftest():
    cases = [
        ("Took my Concerta at 8. Crash came in early, maybe 2:30. The meeting at 3.",
         "- Took my Concerta at 8:00 am.<br>- Crash at 2:30 am.<br>- Meeting at 3:00 am.",
         "- Took my Concerta at 8:00.<br>- Crash at 2:30.<br>- Meeting at 3:00.", 3),
        ("Took my Elvanse 50mg at 7:30 anyway.",
         "Took Elvanse 50mg at 7:30 am.", "Took Elvanse 50mg at 7:30.", 1),
        ("Focus held until about 1pm.",  # source HAS pm -> keep
         "Focus lasted until 1:00 pm.", "Focus lasted until 1:00 pm.", 0),
    ]
    for src, out, want, wantn in cases:
        got, n = ground_output(src, out)
        assert got == want and n == wantn, f"FAIL\n got={got!r} n={n}\nwant={want!r} {wantn}"
    print("selftest ok")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--inputs", required=True)
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("files", nargs="*")
    a = ap.parse_args()
    if a.selftest:
        _selftest()
        return
    src = {e["id"]: e["transcript"] for e in json.load(open(a.inputs))}
    for fp in a.files:
        path = Path(fp)
        total = 0
        rows_changed = []
        out_lines = []
        for line in path.read_text().splitlines():
            if line.startswith("| g"):
                f = line.split(" | ")
                cid = f[0].lstrip("| ").strip()
                if len(f) > 3 and cid in src:
                    new, n = ground_output(src[cid], f[3])
                    if n:
                        total += n
                        rows_changed.append(cid)
                        f[3] = new
                        line = " | ".join(f)
            out_lines.append(line)
        dst = path.with_suffix(".grounded.md")
        dst.write_text("\n".join(out_lines))
        print(f"{path.name}: stripped {total} ungrounded meridiems across "
              f"{len(rows_changed)} rows {rows_changed} -> {dst.name}")


if __name__ == "__main__":
    main()
