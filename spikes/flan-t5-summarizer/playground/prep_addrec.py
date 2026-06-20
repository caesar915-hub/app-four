#!/usr/bin/env python3
"""
Adapt the addrec teacher data into the LoRA training contract, WITH rejection-sampling.

Input : addrec_500_summaries.jsonl  ({id, clean_text, summary, signals, flagged_truncated})
Steps : drop flagged_truncated + posts > --max-words (flan-t5 512-token truncation hazard)
        -> deterministic ~--test-frac held-out test split (posts only, never trained)
        -> MiniCheck faithfulness filter on TRAIN (min bullet support >= --thr) = accepted
Emits :
  lora-train.jsonl : {input, target, meta}     (train_lora.py contract; uses accepted rows)
  lora-test.json   : [{id, transcript, note}]  (eval.py contract; held-out posts)

Run from the playground dir (imports prompts + minicheck_score):
  python prep_addrec.py
"""
import argparse
import hashlib
import json

import prompts as prompt_mod
import minicheck_score as mc


def words(t):
    return len(t.split())


def in_test(cid, frac):
    h = int(hashlib.md5(cid.encode()).hexdigest(), 16)
    return (h % 100) < int(frac * 100)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="../addrec-data/addrec_500_summaries.jsonl")
    ap.add_argument("--thr", type=float, default=0.4)
    ap.add_argument("--agg", choices=["min", "mean"], default="mean",
                    help="aggregate over bullets: min (strict) or mean (forum-post abstraction)")
    ap.add_argument("--max-words", type=int, default=380)
    ap.add_argument("--test-frac", type=float, default=0.15)
    ap.add_argument("--out-train", default="lora-train.jsonl")
    ap.add_argument("--out-test", default="lora-test.json")
    a = ap.parse_args()

    recs = [json.loads(l) for l in open(a.data) if l.strip()]
    kept = [r for r in recs if not r["flagged_truncated"] and words(r["clean_text"]) <= a.max_words]
    d_trunc = sum(1 for r in recs if r["flagged_truncated"])
    d_long = sum(1 for r in recs if not r["flagged_truncated"] and words(r["clean_text"]) > a.max_words)

    train_rows, test_rows = [], []
    n_train, n_acc = 0, 0
    for r in kept:
        cid, txt = r["id"], r["clean_text"]
        if in_test(cid, a.test_frac):
            test_rows.append({"id": cid, "transcript": txt, "note": "+".join(r["signals"])})
            continue
        n_train += 1
        bl = mc.bullets(r["summary"]) or [r["summary"]]
        probs = mc.support_probs(txt, bl)
        supp = (sum(probs) / len(probs)) if a.agg == "mean" else min(probs)
        acc = supp >= a.thr
        n_acc += int(acc)
        train_rows.append({
            "input": prompt_mod.build("lora-short", txt),
            "target": r["summary"].strip(),
            "meta": {"id": cid, "minicheck_support": round(supp, 3), "accepted": acc, "source": "addrec-real"},
        })

    with open(a.out_train, "w") as f:
        for row in train_rows:
            f.write(json.dumps(row) + "\n")
    json.dump(test_rows, open(a.out_test, "w"))

    print(f"input records: {len(recs)}")
    print(f"dropped: flagged_truncated={d_trunc}, >{a.max_words}w={d_long}")
    print(f"held-out test posts: {len(test_rows)} -> {a.out_test}")
    print(f"train candidates: {n_train}; ACCEPTED (MiniCheck>={a.thr}): {n_acc} "
          f"({n_acc/n_train:.0%}) -> {a.out_train}")
    print("train_lora.py will use only the accepted rows.")


if __name__ == "__main__":
    main()
