#!/usr/bin/env bash
# Env setup for the edge-Gemma summarization arm on the EXISTING T4 VM.
# This does NOT provision a VM — it builds a SEPARATE .venv-gemma alongside the
# LoRA track's .venv-lora (whose transformers>=4.40,<4.46 can't load Gemma 3/4).
# Run once on the VM. Safe to re-run.
#
#   gcloud compute ssh flan-t5-spike --zone=us-central1-a
#   HF_TOKEN=hf_xxx bash ~/app-four-spikes/spikes/flan-t5-summarizer/gemma3/setup_vm_gemma.sh
set -euo pipefail

SPIKE_DIR="$HOME/app-four-spikes/spikes/flan-t5-summarizer"
GEMMA_DIR="$SPIKE_DIR/gemma3"
VENV="$SPIKE_DIR/.venv-gemma"

echo "=== 1. System deps ==="
sudo apt-get update -q
sudo apt-get install -y python3.11 python3.11-venv python3-pip git

echo "=== 2. Python venv (.venv-gemma) ==="
python3.11 -m venv "$VENV"
source "$VENV/bin/activate"
pip install --upgrade pip

echo "=== 3. CUDA torch (T4 = CUDA 11.8) ==="
# bitsandbytes NF4 needs a CUDA build of torch, not the CPU/mac wheel.
pip install torch --index-url https://download.pytorch.org/whl/cu118

echo "=== 4. Gemma arm deps ==="
pip install -r "$GEMMA_DIR/requirements.txt"

echo "=== 5. HuggingFace cache ==="
export HF_HOME="$HOME/.cache/huggingface"
mkdir -p "$HF_HOME"

echo "=== 6. Pre-download models (fail fast on gating) ==="
if [ -z "${HF_TOKEN:-}" ]; then
  echo "WARNING: HF_TOKEN not set — gated g3-270m-it / g3-1b will 401." >&2
  echo "  export HF_TOKEN=hf_xxx and re-run, after accepting each model's license." >&2
fi
cd "$GEMMA_DIR"
python download_models.py

echo ""
echo "=== Setup complete ==="
echo "Venv:     $VENV"
echo "Activate: source $VENV/bin/activate"
echo "Run:      cd $SPIKE_DIR && python gemma3/summarize.py --model g3-1b --save"
