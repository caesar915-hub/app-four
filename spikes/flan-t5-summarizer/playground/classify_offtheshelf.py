#!/usr/bin/env python3
"""
Smoke test: off-the-shelf, BENCHMARKED encoder-only classifiers for the `mood`
signal — no fine-tuning, no training data needed.

This is NOT a precision measurement. The 6 sample entries are unlabeled, and 6
points give a ±35pt 95% CI regardless of model (see Raschka, ML CIs). The real
precision is each model's PUBLISHED number:
  - distilbert-sst-2 (67M): 91.3% SST-2 dev  (arXiv:1910.01108)
  - j-hartmann emotion (~82M): 66% 7-class    (HF model card)

Purpose here: does sentiment/emotion mapping produce SENSIBLE mood reads on this
app's journal style? Energy/Focus are deliberately absent — no off-the-shelf
model or benchmark exists for them; they need custom-labeled data.
"""
import json
from pathlib import Path

from transformers import pipeline

HERE = Path(__file__).parent
INPUTS = json.loads((HERE / "inputs-sample6.json").read_text())

print("Loading distilbert-sst-2 (67M, binary sentiment)...", flush=True)
sst2 = pipeline(
    "sentiment-analysis",
    model="distilbert-base-uncased-finetuned-sst-2-english",
)

print("Loading j-hartmann emotion (7-class)...", flush=True)
emo = pipeline(
    "text-classification",
    model="j-hartmann/emotion-english-distilroberta-base",
    top_k=None,
)

print("\n" + "=" * 72)
print("OFF-THE-SHELF MOOD CLASSIFIERS — qualitative smoke test (NOT precision)")
print("=" * 72)

for case in INPUTS:
    text = case["transcript"]
    s = sst2(text)[0]
    e = emo(text)[0]  # list of {label, score} sorted desc
    top_emo = e[0]
    runner = e[1]
    print(f"\n── {case['id']} · {case.get('note','')} " + "─" * 20)
    print(f"INPUT: {text}")
    print(f"  sentiment : {s['label']:<8} ({s['score']:.2f})")
    print(
        f"  emotion   : {top_emo['label']:<8} ({top_emo['score']:.2f})"
        f"   [runner-up: {runner['label']} {runner['score']:.2f}]"
    )
