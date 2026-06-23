#!/bin/sh
# Build + run the standalone extractor performance harness, then analyze in Python.
#
# Compiles the LIVE extractor sources (so it never drifts from the app) + main.swift.
# The gold cases come from the real EvalSet.swift, de-test-ified at build time (the
# `@testable import app_four` line is stripped) so there is one source of truth.
set -e

ROOT="/Users/caesargrey/Projects/app-four"
SRC="$ROOT/app-four/Services/NoteExtraction"
EVAL="$ROOT/spikes/extractor-eval"
OUT="$EVAL/out"
mkdir -p "$OUT"

# Single source of truth for the gold set: strip the test-only import so EvalSet
# compiles as part of this standalone module.
sed '/@testable import app_four/d' "$ROOT/app-fourTests/Eval/EvalSet.swift" > "$OUT/EvalSetData.swift"

echo "Compiling extractor + harness..."
swiftc \
  "$SRC/NLNoteExtractor.swift" \
  "$SRC/CueMatcher.swift" \
  "$SRC/TenseClassifier.swift" \
  "$SRC/Lexicon.swift" \
  "$SRC/LexiconData.swift" \
  "$SRC/NoteExtraction.swift" \
  "$OUT/EvalSetData.swift" \
  "$EVAL/main.swift" \
  -o "$OUT/extractor_eval"

echo "Running extraction over EvalSet..."
"$OUT/extractor_eval" "$ROOT/app-four/Resources/lexicon.json" > "$OUT/extractions.json"

echo "Analyzing..."
python3 "$EVAL/analyze.py" "$OUT/extractions.json"
