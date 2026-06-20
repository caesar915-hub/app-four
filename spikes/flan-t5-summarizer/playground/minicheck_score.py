#!/usr/bin/env python3
"""
MiniCheck-DeBERTa-v3-Large faithfulness scoring (paraphrase-robust; supersedes the
generic NLI screen). MiniCheck is a doc→claim fact-checker that tops LLM-AggreFact;
the DeBERTa variant is non-T5, so it doesn't self-correlate with flan-large outputs.

Loaded directly via transformers (the pip package pulls vllm). Standard cross-encoder:
tokenizer(document, claim) -> P(label=1 == supported). Per entry, support = the MIN
over its bullets (worst bullet); entry is flagged unfaithful if that min < threshold.

Usage:
    python minicheck_score.py --inputs inputs-grounded-multi.json --test-only results/*.md
"""
import argparse
import json
import re
from pathlib import Path

MODEL = "lytang/MiniCheck-DeBERTa-v3-Large"


def is_test(cid: str) -> bool:
    return int(cid[1:]) % 10 in (0, 1, 2)


def extract_rows(md: Path):
    rows = []
    for line in md.read_text().splitlines():
        if not line.startswith("| g"):
            continue
        f = line.split(" | ")
        rows.append((f[0].lstrip("| ").strip(), f[3].strip() if len(f) > 3 else ""))
    return rows


def bullets(raw: str):
    parts = re.split(r"<br>|(?<=[.!?])\s+", raw)
    out = []
    for p in parts:
        p = p.strip().lstrip("-").strip().strip('"').strip()
        if len(p) >= 4:
            out.append(p)
    return out


_M = None


def support_probs(doc, claims):
    global _M
    if _M is None:
        import torch
        from transformers import AutoTokenizer, AutoModelForSequenceClassification
        tok = AutoTokenizer.from_pretrained(MODEL)
        model = AutoModelForSequenceClassification.from_pretrained(MODEL)
        model.eval()
        _M = (tok, model, torch)
    tok, model, torch = _M
    enc = tok([doc] * len(claims), claims, return_tensors="pt",
              truncation=True, max_length=512, padding=True)
    with torch.no_grad():
        logits = model(**enc).logits
    return torch.softmax(logits, dim=-1)[:, 1].tolist()  # P(supported)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--inputs", required=True)
    ap.add_argument("--threshold", type=float, default=0.5)
    ap.add_argument("--test-only", action="store_true")
    ap.add_argument("files", nargs="+")
    a = ap.parse_args()
    src = {e["id"]: e["transcript"] for e in json.load(open(a.inputs))}

    print("| file | n | mean_min_support | flagged(<thr) | flagged% |")
    print("|---|---|---|---|---|")
    for fp in a.files:
        path = Path(fp)
        per = {}
        for cid, raw in extract_rows(path):
            if a.test_only and not is_test(cid):
                continue
            doc, hyps = src.get(cid, ""), bullets(raw)
            if not doc or not hyps:
                continue
            per[cid] = round(min(support_probs(doc, hyps)), 3)
        n = len(per)
        if not n:
            print(f"| {path.name} | 0 | - | - | - |")
            continue
        flagged = {k: v for k, v in per.items() if v < a.threshold}
        print(f"| {path.name} | {n} | {sum(per.values())/n:.3f} | {len(flagged)} | {len(flagged)/n:.0%} |")
        path.with_suffix(".minicheck.json").write_text(json.dumps(per))


if __name__ == "__main__":
    main()
