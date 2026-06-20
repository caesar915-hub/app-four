#!/usr/bin/env python3
"""
Collapse the v2 per-sentence corpora 5 levels -> 3 (Phase 0 decision) and split into
train / held-out test sets. Outputs corpus_v2_3lvl/{sig}_{train,test}.json.

Split strategy: SENTENCE-LEVEL stratified random 80/20 split.

Why not time-based for synthetic data: the time-based split + exact-text leakage removal
collapses to near-zero test sentences because a finite vocabulary bank means every phrase
in the last 25% of notes already appeared in the first 75%. Sentence-level stratified
split is the correct choice for synthetic corpora — each sentence is independent.

For REAL labelled transcripts (Phase 1 of the v2 plan), switch back to time-based:
  notes = json.loads(...); split = int(len(notes)*0.75)
  train_notes, test_notes = notes[:split], notes[split:]

3-level labels map back to app enum rawValues:
  mood:   low{low,flat}   okay{okay}          good{good,great}
  energy: tired{sluggish,tired}  steady{steady}  alert{alert,charged}
  focus:  distracted{foggy,distracted}  present{present}  sharp{sharp,lockedIn}

  python collapse_and_split.py
"""
import json
import random
from pathlib import Path
from collections import Counter, defaultdict

HERE = Path(__file__).resolve().parent
SRC = HERE / "corpus_v2"
OUT = HERE / "corpus_v2_3lvl"
OUT.mkdir(exist_ok=True)

MAP = {
    "mood":   {"low": "low", "flat": "low", "okay": "okay", "good": "good", "great": "good"},
    "energy": {"sluggish": "tired", "tired": "tired", "steady": "steady", "alert": "alert", "charged": "alert"},
    "focus":  {"foggy": "distracted", "distracted": "distracted", "present": "present", "sharp": "sharp", "lockedIn": "sharp"},
}

SEED = 20260619
TEST_FRAC = 0.20  # 80/20 split

notes = json.loads((SRC / "checkins.json").read_text())
print(f"notes: {len(notes)} total\n")


def all_rows(sig):
    """Collect all unique sentences for a signal, collapsed to 3-level labels."""
    seen, out = set(), []
    for n in notes:
        for s in n["sentences"]:
            lvl = s[sig]
            label = MAP[sig][lvl] if lvl else "none"
            key = s["text"].lower().strip()
            if key in seen:
                continue
            seen.add(key)
            out.append({"text": s["text"], "label": label})
    return out


def stratified_split(rows, test_frac, seed):
    """Stratified 80/20 split by label so every class is represented in test."""
    rng = random.Random(seed)
    by_label = defaultdict(list)
    for r in rows:
        by_label[r["label"]].append(r)
    train, test = [], []
    for label, items in by_label.items():
        rng.shuffle(items)
        n_test = max(1, int(len(items) * test_frac))
        test.extend(items[:n_test])
        train.extend(items[n_test:])
    return train, test


for sig in ["mood", "energy", "focus"]:
    rows = all_rows(sig)
    train, test = stratified_split(rows, TEST_FRAC, SEED)
    (OUT / f"{sig}_train.json").write_text(json.dumps(train, indent=2))
    (OUT / f"{sig}_test.json").write_text(json.dumps(test, indent=2))
    print(f"{sig}: train {len(train)} {dict(Counter(r['label'] for r in train))}")
    print(f"      test  {len(test)} {dict(Counter(r['label'] for r in test))}")
