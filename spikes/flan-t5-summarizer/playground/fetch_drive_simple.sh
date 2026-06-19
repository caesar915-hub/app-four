#!/bin/bash
# Simpler approach: download markdown files from Google Drive folder using gdown
# No OAuth setup required.
#
# SETUP (one-time):
#   pip install gdown
#
# USAGE:
#   bash fetch_drive_simple.sh 1SMlbSBhQE9ClYo2uqdzPEhd3aopYVlzV
#   python fetch_md_to_inputs.py --md-dir ./gdown_files
#

FOLDER_ID="${1:-1SMlbSBhQE9ClYo2uqdzPEhd3aopYVlzV}"
OUT_DIR="${2:-./gdown_files}"

echo "Downloading markdown files from Google Drive folder: $FOLDER_ID"
echo "Saving to: $OUT_DIR"

mkdir -p "$OUT_DIR"
gdown --folder "$FOLDER_ID" -O "$OUT_DIR" --quiet

echo "✓ Downloaded to $OUT_DIR"
echo "Next: python fetch_md_to_inputs.py --md-dir $OUT_DIR"
