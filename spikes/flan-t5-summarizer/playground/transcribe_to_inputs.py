#!/usr/bin/env python3
"""
Voice → transcript → inputs.json, using YOUR app's own WhisperKit pipeline (WhisperCLI).

Why this and not Apple dictation: WhisperCLI runs the exact transcription service the
app ships (../../../WhisperCLI), so the transcripts carry the real on-device ASR error
profile the summarizer will actually face. Testing on that beats testing on clean text.

PIPELINE
  1. Record on iPhone (Voice Memos, or a Shortcut → Save to iCloud Drive).
  2. Audio lands on the Mac (iCloud Drive folder, or AirDrop into a folder).
  3. Run this script → it transcribes each clip and merges into inputs.json.

USAGE
  # transcribe every audio file in a folder, merge into inputs.json
  python transcribe_to_inputs.py --audio-dir ~/Library/Mobile\\ Documents/com~apple~CloudDocs/JournalAudio

  # explicit files
  python transcribe_to_inputs.py clip1.m4a clip2.m4a

  # preview without writing
  python transcribe_to_inputs.py --audio-dir ./audio --dry-run

  # write to a separate file instead of merging into inputs.json
  python transcribe_to_inputs.py --audio-dir ./audio --output inputs-voice.json

FIRST RUN downloads the Whisper model (one-time). Build WhisperCLI once for speed:
  (cd ../../../WhisperCLI && swift build -c release)
Otherwise the script falls back to `swift run`, which compiles on first use.
"""

from __future__ import annotations  # `str | None` etc. on Python 3.9 (system python)

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).parent
REPO = HERE.parents[2]                       # .../app-four
WHISPERCLI_DIR = REPO / "WhisperCLI"
RELEASE_BIN = WHISPERCLI_DIR / ".build" / "release" / "WhisperCLI"
INPUTS = HERE / "inputs.json"

AUDIO_EXTS = {".m4a", ".wav", ".mp3", ".flac", ".aiff"}
MARKER = "📝 TRANSCRIPT:"


def kebab(stem: str) -> str:
    s = re.sub(r"[^a-zA-Z0-9]+", "-", stem.strip().lower())
    return re.sub(r"-+", "-", s).strip("-") or "entry"


def whispercli_prefix() -> list[str]:
    """Prefer the prebuilt release binary; fall back to `swift run`."""
    if RELEASE_BIN.exists():
        return [str(RELEASE_BIN)]
    return ["swift", "run", "--package-path", str(WHISPERCLI_DIR), "WhisperCLI"]


def extract_transcript(stdout: str) -> str | None:
    """Pull the final transcript out of WhisperCLI's decorated stdout."""
    lines = stdout.splitlines()
    try:
        start = next(i for i, l in enumerate(lines) if MARKER in l)
    except StopIteration:
        return None
    collected: list[str] = []
    for line in lines[start + 1:]:
        s = line.strip()
        if not s:
            if collected:
                break          # blank line after content → transcript ended
            continue           # skip any leading blank
        if s.startswith("(") or s.startswith("❌"):
            break              # CLI footer note / error
        collected.append(s)
    text = " ".join(collected).strip()
    return text or None


def transcribe(audio: Path) -> str | None:
    cmd = whispercli_prefix() + [str(audio)]
    print(f"  → transcribing {audio.name} ...", file=sys.stderr)
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    except subprocess.TimeoutExpired:
        print(f"  ✗ timed out: {audio.name}", file=sys.stderr)
        return None
    if proc.returncode != 0:
        print(f"  ✗ WhisperCLI failed ({proc.returncode}) on {audio.name}:\n{proc.stderr[-400:]}",
              file=sys.stderr)
        return None
    text = extract_transcript(proc.stdout)
    if not text:
        print(f"  ✗ empty transcript: {audio.name}", file=sys.stderr)
    return text


def collect_audio(args) -> list[Path]:
    files: list[Path] = []
    for p in args.files:
        files.append(Path(p))
    if args.audio_dir:
        d = Path(args.audio_dir).expanduser()
        files += sorted(f for f in d.iterdir() if f.suffix.lower() in AUDIO_EXTS)
    # de-dup, keep only real audio files
    seen, out = set(), []
    for f in files:
        if f.suffix.lower() not in AUDIO_EXTS:
            print(f"  · skipping non-audio {f.name}", file=sys.stderr)
            continue
        if not f.exists():
            print(f"  · missing {f}", file=sys.stderr)
            continue
        if f.resolve() in seen:
            continue
        seen.add(f.resolve())
        out.append(f)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="*", help="audio files to transcribe")
    ap.add_argument("--audio-dir", help="folder of audio files (e.g. an iCloud Drive folder)")
    ap.add_argument("--output", default=str(INPUTS), help="JSON to merge into (default: inputs.json)")
    ap.add_argument("--overwrite", action="store_true", help="replace entries whose id already exists")
    ap.add_argument("--dry-run", action="store_true", help="print result, do not write")
    args = ap.parse_args()

    audio = collect_audio(args)
    if not audio:
        print("No audio files found. Pass files or --audio-dir.", file=sys.stderr)
        sys.exit(1)

    out_path = Path(args.output)
    existing = json.loads(out_path.read_text()) if out_path.exists() else []
    by_id = {e["id"]: e for e in existing}
    order = [e["id"] for e in existing]

    added, skipped = 0, 0
    for f in audio:
        eid = kebab(f.stem)
        if eid in by_id and not args.overwrite:
            print(f"  · id '{eid}' exists — skip (use --overwrite to replace)", file=sys.stderr)
            skipped += 1
            continue
        text = transcribe(f)
        if not text:
            skipped += 1
            continue
        entry = {"id": eid, "note": f"voice import · {f.name}", "transcript": text}
        if eid not in by_id:
            order.append(eid)
        by_id[eid] = entry
        added += 1
        print(f"  ✓ {eid}: {text[:80]}{'…' if len(text) > 80 else ''}", file=sys.stderr)

    merged = [by_id[i] for i in order]

    if args.dry_run:
        print(json.dumps(merged, indent=2, ensure_ascii=False))
    else:
        out_path.write_text(json.dumps(merged, indent=2, ensure_ascii=False) + "\n")
        print(f"\nWrote {out_path}  (+{added} added, {skipped} skipped, {len(merged)} total)",
              file=sys.stderr)


if __name__ == "__main__":
    main()
