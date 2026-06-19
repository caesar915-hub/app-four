#!/usr/bin/env python3
"""
Convert markdown transcript files → inputs.json entries.

Works with files downloaded via gdown or copied manually.

USAGE:
  # Process all .md files in a folder
  python fetch_md_to_inputs.py --md-dir ./gdown_files

  # Preview without writing
  python fetch_md_to_inputs.py --md-dir ./gdown_files --dry-run

  # Merge into a separate file
  python fetch_md_to_inputs.py --md-dir ./gdown_files --output inputs-voice.json

TRANSCRIPT EXTRACTION:
  Looks for "## Transcript" marker in markdown.
  Pulls content from marker to next ## header or end of file.
  Falls back to full file content if no marker found.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).parent
INPUTS = HERE / "inputs.json"


def kebab(stem: str) -> str:
    s = re.sub(r"[^a-zA-Z0-9]+", "-", stem.strip().lower())
    return re.sub(r"-+", "-", s).strip("-") or "entry"


def extract_transcript(content: str) -> str:
    """
    Pull transcript from markdown.
    Looks for '## Transcript', '# Transcript', or '📝 TRANSCRIPT:'.
    Pulls content until next ## header or end of file.
    """
    lines = content.split("\n")

    # Try to find a transcript section
    markers = ["## Transcript", "# Transcript", "📝 TRANSCRIPT:", "TRANSCRIPT:"]
    for marker in markers:
        for i, line in enumerate(lines):
            if marker in line:
                # Collect lines after marker until next ## header or ---
                collected = []
                for j in range(i + 1, len(lines)):
                    s = lines[j].strip()
                    # Stop at next header or separator
                    if s.startswith("#") or s.startswith("---"):
                        break
                    # Collect non-empty lines
                    if s and not s.startswith("-"):  # skip bullet points
                        collected.append(s)
                text = " ".join(collected).strip()
                if text:
                    return text

    # Fallback: clean up the full content
    # Remove headers, metadata lines, separators
    collected = []
    for line in lines:
        s = line.strip()
        if s.startswith("#") or s.startswith("**Date") or s.startswith("**Time") or \
           s.startswith("---") or s.startswith("[") or not s:
            continue
        if s.startswith("- ["):  # Skip action items / checklists
            continue
        collected.append(s)

    text = " ".join(collected).strip()
    return text or content.strip()


def collect_md(md_dir: str) -> list[Path]:
    """Find all .md files in directory."""
    d = Path(md_dir).expanduser()
    if not d.exists():
        print(f"Directory not found: {d}", file=sys.stderr)
        sys.exit(1)
    files = sorted(f for f in d.iterdir() if f.suffix.lower() == ".md")
    return files


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--md-dir", required=True, help="folder of .md files")
    ap.add_argument("--output", default=str(INPUTS), help="JSON to merge into (default: inputs.json)")
    ap.add_argument("--overwrite", action="store_true", help="replace entries whose id already exists")
    ap.add_argument("--dry-run", action="store_true", help="print result, do not write")
    args = ap.parse_args()

    files = collect_md(args.md_dir)
    if not files:
        print(f"No .md files found in {args.md_dir}", file=sys.stderr)
        sys.exit(1)

    print(f"Found {len(files)} markdown file(s). Processing...", file=sys.stderr)

    out_path = Path(args.output)
    existing = json.loads(out_path.read_text()) if out_path.exists() else []
    by_id = {e["id"]: e for e in existing}
    order = [e["id"] for e in existing]

    added, skipped = 0, 0
    for f in files:
        eid = kebab(f.stem)
        if eid in by_id and not args.overwrite:
            print(f"  · id '{eid}' exists — skip (use --overwrite to replace)", file=sys.stderr)
            skipped += 1
            continue

        try:
            content = f.read_text(encoding='utf-8')
        except Exception as e:
            print(f"  ✗ failed to read {f.name}: {e}", file=sys.stderr)
            skipped += 1
            continue

        transcript = extract_transcript(content)
        entry = {"id": eid, "note": f"voice import · {f.name}", "transcript": transcript}

        if eid not in by_id:
            order.append(eid)
        by_id[eid] = entry
        added += 1
        print(f"  ✓ {eid}: {transcript[:80]}{'…' if len(transcript) > 80 else ''}", file=sys.stderr)

    merged = [by_id[i] for i in order]

    if args.dry_run:
        print(json.dumps(merged, indent=2, ensure_ascii=False))
    else:
        out_path.write_text(json.dumps(merged, indent=2, ensure_ascii=False) + "\n")
        print(f"\nWrote {out_path}  (+{added} added, {skipped} skipped, {len(merged)} total)",
              file=sys.stderr)


if __name__ == "__main__":
    main()
