#!/usr/bin/env python3
"""
Export side-by-side comparison of:
  original forum post | Claude teacher summary | g3-270m | g3-1b | g4-e4b
as a CSV importable into Numbers (macOS).

Output: gemma3/results/comparison_teacher_vs_gemma.csv
"""
import csv
import json
import re
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
RESULTS = Path(__file__).resolve().parent / "results"

TEACHER_JSONL = BASE / "addrec-data" / "addrec_500_summaries.jsonl"
INPUTS_JSON   = BASE / "playground" / "inputs-addrec-500.json"

RESULT_FILES = {
    "g3-270m": RESULTS / "g3-270m-gemma-faithful-20260620-230258.md",
    "g3-1b":   RESULTS / "g3-1b-gemma-faithful-20260621-025124.md",
    "g4-e4b":  RESULTS / "g4-e4b-gemma-faithful-20260621-084735.md",
}

OUT_CSV = RESULTS / "comparison_teacher_vs_gemma.csv"


def load_inputs(path: Path) -> dict[str, str]:
    return {e["id"]: e["transcript"] for e in json.load(open(path))}


def load_teacher(path: Path) -> dict[str, str]:
    out = {}
    for line in open(path):
        line = line.strip()
        if not line:
            continue
        r = json.loads(line)
        out[r["id"]] = r.get("summary", "")
    return out


def parse_result_md(path: Path) -> dict[str, dict]:
    """
    Join continuation lines (rows whose model output contained real newlines
    get split across multiple MD lines), then extract id->raw/post/fallback.
    """
    raw_text = path.read_text()

    # Collapse newlines inside table rows: a continuation line is any line
    # that doesn't start with '|' (or is a partial row lacking the UUID prefix).
    # Strategy: join lines that are not row-starts back onto the previous row.
    uuid_start = re.compile(r"^\| [0-9a-f-]{36} \|")
    joined_lines = []
    for line in raw_text.splitlines():
        if uuid_start.match(line) or line.startswith("# ") or line.startswith("## ") or line.startswith("### ") or line.startswith("| id ") or line.startswith("|---"):
            joined_lines.append(line)
        elif joined_lines:
            # continuation — append to previous line (the newline becomes a space)
            joined_lines[-1] += " " + line.strip()

    out = {}
    for line in joined_lines:
        if not uuid_start.match(line):
            continue
        # Split on ' | ' — MD table cols. Content may contain escaped pipes (\|).
        # We need exactly 8 cols (id|input|tags|raw|post|fallback|raw_q|proc_q).
        # Use a greedy split capped at 8 to tolerate extra pipes in content.
        cols = line.strip().strip("|").split(" | ", 7)
        if len(cols) < 6:
            continue
        cid      = cols[0].strip()
        raw_out  = cols[3].strip().replace("<br>", "\n").replace("\\|", "|")
        post_out = cols[4].strip().replace("<br>", "\n").replace("\\|", "|")
        fallback = cols[5].strip()
        out[cid] = {"raw": raw_out, "post": post_out, "fallback": fallback}
    return out


def main():
    inputs  = load_inputs(INPUTS_JSON)
    teacher = load_teacher(TEACHER_JSONL)
    results = {key: parse_result_md(path) for key, path in RESULT_FILES.items()}

    parsed_counts = {k: len(v) for k, v in results.items()}
    print("Parsed rows:", parsed_counts, file=sys.stderr)

    ids = list(inputs.keys())   # preserve order from inputs file (970 entries)

    rows_written = 0
    with open(OUT_CSV, "w", newline="", encoding="utf-8-sig") as f:
        # utf-8-sig adds BOM so Numbers/Excel auto-detects UTF-8
        writer = csv.writer(f)
        writer.writerow([
            "id",
            "original_post",
            "claude_teacher_summary",
            "g3_270m_output",
            "g3_270m_fallback",
            "g3_1b_output",
            "g3_1b_fallback",
            "g4_e4b_output",
            "g4_e4b_fallback",
        ])
        for cid in ids:
            orig    = inputs.get(cid, "")
            teacher_sum = teacher.get(cid, "")
            r270  = results["g3-270m"].get(cid, {})
            r1b   = results["g3-1b"].get(cid, {})
            re4b  = results["g4-e4b"].get(cid, {})
            writer.writerow([
                cid,
                orig,
                teacher_sum,
                r270.get("post", ""),   # post-processed (heuristic applied if fallback)
                r270.get("fallback", ""),
                r1b.get("post", ""),
                r1b.get("fallback", ""),
                re4b.get("post", ""),
                re4b.get("fallback", ""),
            ])
            rows_written += 1

    print(f"Written {rows_written} rows → {OUT_CSV}", file=sys.stderr)


if __name__ == "__main__":
    main()
