#!/bin/sh
# Build + run the 500-record DETECTION eval on macOS, then analyze in Python.
# Compiles the LIVE extractor sources (never drifts) + detect500.swift. The 500
# records are read from JSON at runtime (not compiled in), so no EvalSet needed.
set -e

ROOT="/Users/caesargrey/Projects/app-four"
SRC="$ROOT/app-four/Services/NoteExtraction"
EVAL="$ROOT/spikes/extractor-eval"
OUT="$EVAL/out"
mkdir -p "$OUT"

echo "Compiling detection harness..."
swiftc -O \
  "$SRC/NLNoteExtractor.swift" \
  "$SRC/CueMatcher.swift" \
  "$SRC/TenseClassifier.swift" \
  "$SRC/Lexicon.swift" \
  "$SRC/LexiconData.swift" \
  "$SRC/NoteExtraction.swift" \
  "$EVAL/detect500.swift" \
  -o "$OUT/detect500"

DATA="${1:-$EVAL/data/addrec_1082_summaries.jsonl}"
echo "Running detection over: $DATA ..."
time "$OUT/detect500" "$ROOT/app-four/Resources/lexicon.json" "$DATA" > "$OUT/detect.json"

echo "Analyzing..."
python3 "$EVAL/analyze_detect.py" "$OUT/detect.json"
