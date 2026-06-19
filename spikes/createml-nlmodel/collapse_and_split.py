#!/usr/bin/env python3
"""
Collapse the v2 per-sentence corpora 5 levels -> 3 (Phase 0 decision), and split into
a TIME-BASED held-out test set (earlier check-ins train, later test) per Apple's method.

3-level labels are valid app enum rawValues so they map back to the app for free:
  mood:   low{low,flat}     okay{okay}      good{good,great}
  energy: tired{sluggish,tired}  steady{steady}  alert{alert,charged}
  focus:  distracted{foggy,distracted}  present{present}  sharp{sharp,lockedIn}

Exact-text leakage from train is removed from test. Outputs corpus_v2_3lvl/{sig}_{train,test}.json.
  python collapse_and_split.py
"""
import json
from pathlib import Path
from collections import Counter

HERE = Path(__file__).resolve().parent
SRC = HERE / "corpus_v2"
OUT = HERE / "corpus_v2_3lvl"
OUT.mkdir(exist_ok=True)

MAP = {
    "mood":   {"low": "low", "flat": "low", "okay": "okay", "good": "good", "great": "good"},
    "energy": {"sluggish": "tired", "tired": "tired", "steady": "steady", "alert": "alert", "charged": "alert"},
    "focus":  {"foggy": "distracted", "distracted": "distracted", "present": "present", "sharp": "sharp", "lockedIn": "sharp"},
}

notes = json.loads((SRC / "checkins.json").read_text())
split = int(len(notes) * 0.75)
train_notes, test_notes = notes[:split], notes[split:]
print(f"notes: {len(notes)} total -> {len(train_notes)} train (earlier) / {len(test_notes)} test (later)\n")

def rows_for(subset, sig):
    seen, out = set(), []
    for n in subset:
        for s in n["sentences"]:
            lvl = s[sig]
            label = MAP[sig][lvl] if lvl else "none"
            key = s["text"].lower().strip()
            if key in seen:
                continue
            seen.add(key)
            out.append({"text": s["text"], "label": label})
    return out

for sig in ["mood", "energy", "focus"]:
    train = rows_for(train_notes, sig)
    test = rows_for(test_notes, sig)
    train_texts = {r["text"].lower().strip() for r in train}
    leak = [r for r in test if r["text"].lower().strip() in train_texts]
    test = [r for r in test if r["text"].lower().strip() not in train_texts]
    (OUT / f"{sig}_train.json").write_text(json.dumps(train, indent=2))
    (OUT / f"{sig}_test.json").write_text(json.dumps(test, indent=2))
    print(f"{sig}: train {len(train)} {dict(Counter(r['label'] for r in train))}")
    print(f"      test  {len(test)} {dict(Counter(r['label'] for r in test))}  (dropped {len(leak)} leaked)")
