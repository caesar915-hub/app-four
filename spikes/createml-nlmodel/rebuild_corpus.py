#!/usr/bin/env python3
"""
Rebuild the mood/energy/focus training corpora to fix the two proven failures:

  1. Cross-domain over-firing (energy fired "charged" on "I have no focus")
     FIX: every level-labeled sentence in ONE dimension becomes a `none`
          example in the OTHER two (filtered so we never relabel a sentence
          that actually carries this dimension's signal).

  2. Negation handled wrong ("no focus" -> none instead of a low level)
     FIX (semantic A): negation of the positive pole = the negative pole.
          "no focus" -> foggy, "no energy" -> sluggish, "I feel bad" -> low.

Also: down-skew the extreme levels (realistic prior; real journals are mostly
mid-level) and make `none` ~50% of each corpus.

Originals are backed up to corpus/v1_backup/ before overwrite. Deterministic.
"""

import json, re
import random
from pathlib import Path
from collections import Counter, defaultdict

BASE = Path(__file__).resolve().parent / "corpus"
DIMS = ["mood", "energy", "focus"]

# Words that signal each dimension. Used to FILTER cross-domain `none` candidates:
# a sentence borrowed from another dimension is only safe as `none` here if it does
# NOT contain this dimension's vocabulary.
KEYWORDS = {
    "mood":   r"\b(mood|happy|happiness|sad|down|low|great|flat|depress\w*|miser\w*|cheer\w*|content|joy\w*|gloom\w*|hopeless|elated|euphoric|numb|empty|apath\w*|upbeat|bleak|despair|glad|blue|spirits)\b",
    "energy": r"\b(energy|energetic|tired|exhaust\w*|sluggish|charged|drained|wired|fatigue\w*|awake|alert|nap|stamina|lethargic|depleted|drowsy|vigor|crash\w*)\b",
    "focus":  r"\b(focus\w*|distract\w*|concentrat\w*|foggy|fog|flow|locked|sharp|attention|clarity|scattered|zone|hyperfocus|absorbed|sidetrack\w*|wander\w*|mental)\b",
}
KW = {k: re.compile(v, re.I) for k, v in KEYWORDS.items()}

# Semantic A: negation of the positive pole -> the negative pole (a real low state).
NEGATIONS = {
    "focus": [
        ("I have no focus", "foggy"), ("I really have no focus", "foggy"),
        ("no focus at all today", "foggy"), ("zero concentration", "foggy"),
        ("no concentration left", "foggy"), ("I have no mental clarity", "foggy"),
        ("my focus is completely gone", "foggy"), ("no focus whatsoever", "foggy"),
        ("can't focus at all", "distracted"), ("couldn't concentrate today", "distracted"),
        ("not able to focus", "distracted"), ("I lost my focus completely", "distracted"),
        # expanded negation coverage (model failed to learn these from 12 examples)
        ("no focus", "foggy"), ("zero focus today", "foggy"),
        ("I have absolutely no focus", "foggy"), ("no ability to concentrate", "foggy"),
        ("my concentration is shot", "foggy"), ("focus is completely gone", "foggy"),
        ("no mental focus whatsoever", "foggy"), ("my focus has vanished", "foggy"),
        ("I have zero focus right now", "foggy"), ("no concentration at all today", "foggy"),
        ("I can't focus", "distracted"), ("couldn't focus on anything", "distracted"),
        ("I can't concentrate at all", "distracted"), ("totally unable to focus", "distracted"),
        ("I have no attention span today", "distracted"), ("not focused at all", "distracted"),
        ("can't keep my mind on anything", "distracted"), ("I couldn't focus to save my life", "distracted"),
        ("now I really have no focus", "foggy"), ("I have lost all focus", "foggy"),
    ],
    "energy": [
        ("no energy", "sluggish"), ("I have no energy left", "sluggish"),
        ("zero energy today", "sluggish"), ("no energy to do anything", "sluggish"),
        ("completely out of energy", "sluggish"), ("running on no energy", "sluggish"),
        ("nothing left in the tank", "sluggish"), ("no energy in me at all", "sluggish"),
        ("not energetic at all", "tired"), ("I have no stamina today", "tired"),
    ],
    "mood": [
        ("not happy", "low"), ("I don't feel good", "low"), ("feeling no joy", "low"),
        ("I'm not okay", "low"), ("no happiness today", "low"), ("I feel bad", "low"),
        ("I'm really not happy", "low"), ("no joy in anything today", "low"),
        ("I don't feel good at all", "low"), ("not in a good place", "low"),
    ],
}

# Extra hand-authored level examples (focus expansion — the underfit dimension).
# Clearer, more separable exemplars per level + more variety on the subtle ones.
EXTRA = {
    "mood": [], "energy": [],
    "focus": [
        ("My head is in a complete fog", "foggy"), ("I can't think clearly at all", "foggy"),
        ("Brain feels like soup today", "foggy"), ("Everything is mentally hazy", "foggy"),
        ("I keep blanking out", "foggy"), ("My mind is mush today", "foggy"),
        ("Cognitively I'm just not here today", "foggy"), ("Thinking feels impossible right now", "foggy"),
        ("I keep getting pulled away from tasks", "distracted"),
        ("My attention won't settle on anything", "distracted"),
        ("I bounce between things constantly", "distracted"),
        ("Can't stay on one task today", "distracted"),
        ("I'm scattered all over the place", "distracted"),
        ("Every notification derails me", "distracted"),
        ("I lose my train of thought constantly", "distracted"),
        ("I'm keeping up with things mentally", "present"),
        ("My focus is steady enough today", "present"),
        ("I can stay with my work okay", "present"),
        ("Mentally I'm present and tracking", "present"),
        ("Focus is fine, nothing remarkable", "present"),
        ("I'm engaged with what I'm doing", "present"),
        ("My mind is razor sharp today", "sharp"), ("I'm thinking fast and clearly", "sharp"),
        ("Everything clicks mentally today", "sharp"), ("I'm cutting through work easily", "sharp"),
        ("My focus is crisp and strong", "sharp"), ("Mentally on point all day", "sharp"),
        ("I'm in deep flow right now", "lockedIn"), ("Completely locked into my work", "lockedIn"),
        ("Hours passed without me noticing, total flow", "lockedIn"),
        ("I'm in the zone and unstoppable", "lockedIn"), ("Deep focus, nothing reaches me", "lockedIn"),
    ],
}

# Realistic skew: keep more mid-level examples, fewer extremes.
SKEW = {
    "mood":   {"low": 50, "flat": 55, "okay": 70, "good": 65, "great": 50},
    "energy": {"sluggish": 50, "tired": 65, "steady": 70, "alert": 60, "charged": 50},
    "focus":  {"foggy": 50, "distracted": 60, "present": 70, "sharp": 60, "lockedIn": 50},
}


def load(dim):
    return json.loads((BASE / f"{dim}.json").read_text())


def build(dim, raw):
    rng = random.Random(DIMS.index(dim) + 1)
    out, seen = [], set()

    def add(text, label):
        t = text.strip()
        k = t.lower()
        if k in seen:
            return
        seen.add(k)
        out.append({"text": t, "label": label})

    levels = {d: [r for r in raw[d] if r["label"] != "none"] for d in DIMS}
    nones = [r for r in raw[dim] if r["label"] == "none"]

    # 1. level examples, down-skewed
    bylevel = defaultdict(list)
    for r in levels[dim]:
        bylevel[r["label"]].append(r["text"])
    for lvl, cap in SKEW[dim].items():
        rows = bylevel.get(lvl, [])[:]
        rng.shuffle(rows)
        for t in rows[:cap]:
            add(t, lvl)

    # 2. negation -> level (semantic A)
    for text, lvl in NEGATIONS[dim]:
        add(text, lvl)
    # 2b. extra hand-authored level exemplars (guaranteed in, not subject to skew cap)
    for text, lvl in EXTRA[dim]:
        add(text, lvl)

    n_levels = len(out)

    # 3. none pool = cross-domain (filtered) + existing none rows
    pool, pseen = [], set()

    def push(t):
        k = t.lower().strip()
        if k in pseen or k in seen:
            return
        pseen.add(k)
        pool.append(t)

    for other in DIMS:
        if other == dim:
            continue
        for r in levels[other]:
            if not KW[dim].search(r["text"]):     # don't relabel real signal as none
                push(r["text"])
    for r in nones:
        push(r["text"])

    rng.shuffle(pool)
    for t in pool[:n_levels]:                      # cap none ~= levels -> ~50%
        add(t, "none")

    return out


def main():
    # Pristine seed = v1_backup (created once, never clobbered). Always build from it
    # so the script is idempotent and re-runnable as we add EXTRA/NEGATIONS examples.
    backup = BASE / "v1_backup"
    if not backup.exists():
        backup.mkdir()
        for d in DIMS:
            (backup / f"{d}.json").write_text(json.dumps(load(d), indent=2))
    raw = {d: json.loads((backup / f"{d}.json").read_text()) for d in DIMS}

    for d in DIMS:
        rows = build(d, raw)
        (BASE / f"{d}.json").write_text(json.dumps(rows, indent=2))
        c = Counter(r["label"] for r in rows)
        nonepct = round(100 * c["none"] / len(rows))
        print(f"{d}: {len(rows)} rows  none={c['none']} ({nonepct}%)")
        print(f"   {dict(c)}")


if __name__ == "__main__":
    main()
