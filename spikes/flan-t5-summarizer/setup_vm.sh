#!/usr/bin/env bash
# VM setup for LoRA fine-tuning of flan-t5-large on T4.
# Run once after provisioning. Safe to re-run.
set -euo pipefail

SPIKE_DIR="$HOME/app-four-spikes/spikes/flan-t5-summarizer"

echo "=== 1. System deps ==="
sudo apt-get update -q
sudo apt-get install -y python3.11 python3.11-venv python3-pip git

echo "=== 2. Python venv ==="
python3.11 -m venv "$SPIKE_DIR/.venv-lora"
source "$SPIKE_DIR/.venv-lora/bin/activate"

echo "=== 3. CUDA torch (T4 = CUDA 11.8) ==="
pip install --upgrade pip
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu118

echo "=== 4. Training deps ==="
# transformers <4.46: pinned to avoid Seq2SeqTrainer label regression for T5
pip install \
  "transformers>=4.40,<4.46" \
  "peft>=0.10" \
  "datasets>=2.18" \
  "accelerate>=0.28" \
  sentencepiece

echo "=== 5. Eval deps (MiniCheck on VM) ==="
# MiniCheck loaded directly via transformers AutoModelForSequenceClassification
# (lytang/MiniCheck-DeBERTa-v3-Large) — no pip install minicheck needed

echo "=== 6. HuggingFace cache dir ==="
# T4 VM has 100 GB boot disk; cache flan-t5-large (~3 GB) + MiniCheck (~1.7 GB)
export HF_HOME="$HOME/.cache/huggingface"
mkdir -p "$HF_HOME"

echo "=== 7. Pre-download models (do this before training to fail fast) ==="
python - <<'EOF'
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM, AutoModelForSequenceClassification
import torch
print("Downloading flan-t5-large...")
AutoTokenizer.from_pretrained("google/flan-t5-large")
AutoModelForSeq2SeqLM.from_pretrained("google/flan-t5-large")
print("Downloading MiniCheck-DeBERTa-v3-Large...")
AutoModelForSequenceClassification.from_pretrained("lytang/MiniCheck-DeBERTa-v3-Large")
print("All models cached.")
EOF

echo ""
echo "=== Setup complete ==="
echo "Venv:  $SPIKE_DIR/.venv-lora"
echo "Activate: source $SPIKE_DIR/.venv-lora/bin/activate"
echo "See RUNBOOK.md for the training + eval commands."
