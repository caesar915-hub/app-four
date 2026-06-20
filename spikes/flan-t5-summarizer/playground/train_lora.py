#!/usr/bin/env python3
"""
LoRA fine-tune flan-t5-large for faithful + complete ADHD journal summarization.
Runs on the cloud Linux VM (T4 GPU).

DATA CONTRACT (what build_lora_data.py must emit) — JSONL, one object per line:
    {
      "input":  "<final input text: short prompt + transcript already substituted>",
      "target": "- bullet 1\n- bullet 2\n...",
      "meta":   { "accepted": true, ... }      # optional; rows with accepted=false are skipped
    }
Only `input` and `target` are consumed for training. `input` must be the FINAL string fed to the
model (transcript already inlined) — this script does NOT apply any prompt template. Keep the same
prompt at train and inference.

DEPS (VM):  pip install "transformers>=4.40,<4.46" peft datasets accelerate sentencepiece
            (+ a CUDA torch build for the T4)
USAGE:
    python train_lora.py --data lora-train.jsonl --out adapters/flan-large-v1 --epochs 5 --merge
EVAL each saved epoch with the v3 stack (pick the best — we do NOT trust train loss alone):
    python eval.py --model adapters/flan-large-v1-merged --prompt <same short prompt> --input-file inputs-test30.json
    python minicheck_score.py --inputs inputs-grounded-multi.json --test-only results/<that-run>.md

NOTE ON PRECISION: T5 is numerically unstable in fp16 (known nan-logit issue; see config.py). The T4
has no bf16. So this trains in **fp32** by default — slower but correct. --fp16 is available but risky.
If you hit CUDA OOM on the T4 (16 GB), drop --batch to 2 and raise --grad-accum to 8.
"""
import argparse
import json


def load_pairs(path):
    rows = []
    for line in open(path):
        line = line.strip()
        if not line:
            continue
        r = json.loads(line)
        if not r.get("meta", {}).get("accepted", True):
            continue
        if "input" in r and "target" in r:
            rows.append({"input": r["input"], "target": r["target"]})
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", required=True, help="training JSONL (see DATA CONTRACT)")
    ap.add_argument("--base", default="google/flan-t5-large")
    ap.add_argument("--out", required=True, help="adapter output dir")
    ap.add_argument("--epochs", type=float, default=5)
    ap.add_argument("--lr", type=float, default=3e-4)        # LoRA tolerates higher LR than full FT
    ap.add_argument("--rank", type=int, default=16)          # Apple on-device uses rank 16
    ap.add_argument("--alpha", type=int, default=32)
    ap.add_argument("--dropout", type=float, default=0.05)
    ap.add_argument("--batch", type=int, default=4)          # T4-safe; drop to 2 if OOM
    ap.add_argument("--grad-accum", type=int, default=4)     # effective batch = batch * grad_accum
    ap.add_argument("--max-in", type=int, default=512)       # flan-t5 encoder limit
    ap.add_argument("--max-out", type=int, default=160)
    ap.add_argument("--fp16", action="store_true", help="risky for T5 (nan logits); default fp32")
    ap.add_argument("--merge", action="store_true", help="also save a merged full model for eval/Core ML")
    a = ap.parse_args()

    from transformers import (AutoTokenizer, AutoModelForSeq2SeqLM, Seq2SeqTrainer,
                              Seq2SeqTrainingArguments, DataCollatorForSeq2Seq)
    from peft import LoraConfig, get_peft_model, TaskType
    from datasets import Dataset

    pairs = load_pairs(a.data)
    if not pairs:
        raise SystemExit(f"no accepted training pairs in {a.data}")
    print(f"accepted training pairs: {len(pairs)}")

    tok = AutoTokenizer.from_pretrained(a.base)

    def tokenize(batch):
        enc = tok(batch["input"], max_length=a.max_in, truncation=True)
        enc["labels"] = tok(text_target=batch["target"], max_length=a.max_out, truncation=True)["input_ids"]
        return enc

    ds = Dataset.from_list(pairs).map(tokenize, batched=True, remove_columns=["input", "target"])

    model = AutoModelForSeq2SeqLM.from_pretrained(a.base)
    # q,v = canonical, well-tested T5 LoRA targets. For more capacity, add k,o,wi_0,wi_1,wo.
    model = get_peft_model(model, LoraConfig(
        task_type=TaskType.SEQ_2_SEQ_LM, r=a.rank, lora_alpha=a.alpha,
        lora_dropout=a.dropout, target_modules=["q", "v"]))
    model.print_trainable_parameters()

    args = Seq2SeqTrainingArguments(
        output_dir=a.out,
        per_device_train_batch_size=a.batch,
        gradient_accumulation_steps=a.grad_accum,
        learning_rate=a.lr,
        num_train_epochs=a.epochs,
        warmup_ratio=0.03,
        fp16=a.fp16,                 # default False → fp32 (T5 fp16 = nan risk; T4 has no bf16)
        logging_steps=10,
        save_strategy="epoch",       # save every epoch; eval each externally with the v3 stack
        save_total_limit=5,
        report_to="none",
    )
    trainer = Seq2SeqTrainer(
        model=model, args=args, train_dataset=ds,
        data_collator=DataCollatorForSeq2Seq(tok, model=model), tokenizer=tok)
    trainer.train()

    model.save_pretrained(a.out)
    tok.save_pretrained(a.out)
    print(f"adapter saved -> {a.out}")

    if a.merge:
        merged = model.merge_and_unload()
        mp = a.out + "-merged"
        merged.save_pretrained(mp)
        tok.save_pretrained(mp)
        print(f"merged model saved -> {mp}  (eval: eval.py --model {mp})")


if __name__ == "__main__":
    main()
