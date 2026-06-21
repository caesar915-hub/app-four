#!/usr/bin/env bash
# Pull both Gemma models into the running Ollama container and verify co-residency.
# Run AFTER `docker compose up -d`, from this directory.
set -euo pipefail

SVC=ollama
GEMMA3="gemma3:1b"
GEMMA4="hf.co/google/gemma-4-E4B-it-qat-q4_0-gguf"   # vendor QAT q4_0, ~5.15 GB, apache-2.0

run() { docker compose exec -T "$SVC" "$@"; }

echo ">> Pulling ${GEMMA3} ..."
run ollama pull "$GEMMA3"

echo ">> Pulling ${GEMMA4} ..."
if ! run ollama pull "$GEMMA4"; then
  cat >&2 <<EOF

!! Direct HF pull failed for ${GEMMA4}.
   Fallback (no substitute model):
     1) On the VM, download the .gguf from
        https://huggingface.co/google/gemma-4-E4B-it-qat-q4_0-gguf
     2) Place it in a dir, create a Modelfile containing:  FROM ./<file>.gguf
     3) docker compose cp <dir> ollama:/models && \\
        docker compose exec ollama ollama create gemma4-e4b-qat -f /models/Modelfile
   Do NOT swap in a different model.
EOF
  exit 1
fi

echo ">> Warming both models so they load concurrently ..."
run ollama run "$GEMMA3" "ok" >/dev/null
run ollama run "$GEMMA4" "ok" >/dev/null

echo ">> Resident models (expect BOTH, combined < 16 GB):"
run ollama ps

echo ">> GPU memory:"
run nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader || true

echo ">> Done. Open the UI, click + in the model selector, add both models, send one prompt."
