# LoRA Training Runbook — flan-t5-large on T4

VM: `flan-t5-spike` / `35.254.231.127` / zone `us-central1-a`  
SSH: `gcloud compute ssh flan-t5-spike --zone=us-central1-a`

---

## 0. One-time VM setup

```bash
# From local Mac — only needed once
gcloud compute ssh flan-t5-spike --zone=us-central1-a -- bash ~/app-four-spikes/spikes/flan-t5-summarizer/setup_vm.sh
```

---

## 1. Push data from Mac to VM

Run from your Mac after `prep_addrec.py` completes:

```bash
PLAYGROUND=/Users/caesargrey/Projects/app-four-spikes-local/spikes/flan-t5-summarizer/playground
VM=caesargrey@35.254.231.127
VM_DIR=~/app-four-spikes/spikes/flan-t5-summarizer/playground

# Training data
scp -i ~/.ssh/google_compute_engine \
  $PLAYGROUND/lora-train.jsonl \
  $PLAYGROUND/lora-test.json \
  $VM:$VM_DIR/

# Scripts (push the whole playground dir; rsync is faster on repeat)
rsync -avz -e "ssh -i ~/.ssh/google_compute_engine" \
  $PLAYGROUND/ \
  $VM:$VM_DIR/
```

Verify on VM:
```bash
wc -l ~/app-four-spikes/spikes/flan-t5-summarizer/playground/lora-train.jsonl
# Should show total rows; accepted count is printed separately by train_lora.py
```

---

## 2. Run LoRA training

```bash
# SSH in
gcloud compute ssh flan-t5-spike --zone=us-central1-a

# Activate venv
source ~/app-four-spikes/spikes/flan-t5-summarizer/.venv-lora/bin/activate
cd ~/app-four-spikes/spikes/flan-t5-summarizer/playground

# Train — fp32 mandatory (T5 fp16 = nan logits; T4 has no bf16)
python train_lora.py \
  --data lora-train.jsonl \
  --out adapters/flan-large-v1 \
  --epochs 5 \
  --batch 4 \
  --grad-accum 4 \
  --merge

# If CUDA OOM (T4 = 16 GB VRAM):
python train_lora.py \
  --data lora-train.jsonl \
  --out adapters/flan-large-v1 \
  --epochs 5 \
  --batch 2 \
  --grad-accum 8 \
  --merge
```

Expected output:
- `accepted training pairs: N` (where N = accepted rows from lora-train.jsonl)
- Trainable params printed (rank-16 LoRA ≈ 1.3M params out of 770M)
- Checkpoint saved after each epoch to `adapters/flan-large-v1/checkpoint-*`
- `adapter saved -> adapters/flan-large-v1`
- `merged model saved -> adapters/flan-large-v1-merged`

Expected time (T4, fp32, ~200 accepted pairs, effective batch 16):
- ~6–15 min total for 5 epochs

---

## 3. Eval each epoch with v3 stack

**MiniCheck faithfulness (primary):**
```bash
# The merged final model
python eval.py \
  --model adapters/flan-large-v1-merged \
  --prompt lora-short \
  --input-file lora-test.json \
  --out results/lora-v1-test.md

python minicheck_score.py \
  --inputs lora-test.json \
  --results results/lora-v1-test.md
```

**Per-epoch checkpoints** (to pick the best epoch, not just the last):
```bash
for EPOCH in 1 2 3 4 5; do
  CKPT="adapters/flan-large-v1/checkpoint-$(ls adapters/flan-large-v1 | grep checkpoint | sed -n "${EPOCH}p" | grep -oP '\d+')"
  python eval.py --model $CKPT --prompt lora-short --input-file lora-test.json \
    --out results/lora-v1-epoch${EPOCH}.md
  python minicheck_score.py --inputs lora-test.json --results results/lora-v1-epoch${EPOCH}.md
done
```

**Gold-signal recall** (completeness — the metric we're trying to fix):
```bash
# First push gold-signals.json to VM:
# scp -i ~/.ssh/google_compute_engine $PLAYGROUND/gold-signals.json $VM:$VM_DIR/
python gold_recall.py --md results/lora-v1-test.md --gold gold-signals.json
```

---

## 4. Success criteria (from LORA-SPIKE-SCOPE.md)

| Metric | Baseline (flan-large greedy) | Target |
|--------|------------------------------|--------|
| MiniCheck support (test-30) | 0.789 | ≥ 0.789 (must not regress) |
| Gold-signal recall | 68% | ≥ 85% |
| Confirmed fabrications | 0 | 0 |

Pick the epoch with the best recall **that keeps MiniCheck ≥ 0.789**.

---

## 5. Pull results back to Mac

```bash
scp -i ~/.ssh/google_compute_engine \
  caesargrey@35.254.231.127:~/app-four-spikes/spikes/flan-t5-summarizer/playground/results/lora-v1-test.md \
  /Users/caesargrey/Projects/app-four-spikes-local/spikes/flan-t5-summarizer/playground/results/
```

---

## 6. Failure modes

| Symptom | Fix |
|---------|-----|
| `CUDA OOM` | `--batch 2 --grad-accum 8` |
| `nan loss` after epoch 1 | T5 fp16 bug — confirm `--fp16` is NOT set; fp32 is default |
| `no accepted training pairs` | Check `lora-train.jsonl` has `"accepted": true` rows; re-run `prep_addrec.py` |
| MiniCheck regresses post-LoRA | Reduce epochs (overfit to addrec style); pick earlier epoch |
| Recall doesn't improve past epoch 2 | Domain mismatch — addrec signals ≠ voice-note signals; need real transcript data |
