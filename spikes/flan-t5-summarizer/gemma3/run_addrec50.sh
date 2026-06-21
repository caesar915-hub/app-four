#!/usr/bin/env bash
# Run the addrec-structured prompt on the first 50 teacher entries for all three
# Gemma models. Run this ON THE VM after git pulling the branch.
#
# Prerequisites (already done from the prior spike run):
#   - .venv-gemma built (setup_vm_gemma.sh)
#   - Model weights cached in ~/.cache/huggingface
#
# Usage (from spike root on the VM):
#   bash gemma3/run_addrec50.sh
#
# Results land in gemma3/results/ as:
#   g3-270m-addrec-structured-<stamp>.md
#   g3-1b-addrec-structured-<stamp>.md
#   g4-e4b-addrec-structured-<stamp>.md
set -euo pipefail

SPIKE="$HOME/app-four-spikes/spikes/flan-t5-summarizer"
VENV="$SPIKE/.venv-gemma"
INPUT="$SPIKE/playground/inputs-addrec-50.json"
SIGNALS="$SPIKE/playground/addrec-signals.json"
LOGS="$SPIKE/gemma3/logs"
RESULTS="$SPIKE/gemma3/results"

mkdir -p "$LOGS" "$RESULTS"
source "$VENV/bin/activate"
cd "$SPIKE"

echo "=== g3-270m (f16, CPU-fallback ok but slow; use cuda) ==="
python gemma3/summarize.py \
  --model g3-270m \
  --prompt addrec-structured \
  --input-file "$INPUT" \
  --signals-file "$SIGNALS" \
  --save \
  2>&1 | tee "$LOGS/addrec50-g3-270m.log"

echo "=== g3-1b (nf4) ==="
python gemma3/summarize.py \
  --model g3-1b \
  --prompt addrec-structured \
  --input-file "$INPUT" \
  --signals-file "$SIGNALS" \
  --save \
  2>&1 | tee "$LOGS/addrec50-g3-1b.log"

echo "=== g4-e4b (nf4) ==="
python gemma3/summarize.py \
  --model g4-e4b \
  --prompt addrec-structured \
  --input-file "$INPUT" \
  --signals-file "$SIGNALS" \
  --no-repeat-ngram 3 \
  --repetition-penalty 1.2 \
  --save \
  2>&1 | tee "$LOGS/addrec50-g4-e4b.log"

echo ""
echo "=== All done. Results in $RESULTS ==="
ls -lh "$RESULTS"/*addrec-structured*.md 2>/dev/null || echo "No addrec-structured results found."
