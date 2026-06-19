#!/usr/bin/env python3
"""
Generate ~3 months of REALISTIC synthetic check-ins, then split into per-sentence
labeled corpora (Phase 1.2). Unlike v1's clean single-sentence exemplars, this builds
messy multi-sentence notes with: correlated daily states (poor sleep -> low energy ->
worse focus), realistic level distribution (mostly mid, extremes rare), ~30% signal
omission, medication/sleep/activity/plan noise, and explicit temporal-recency pairs
("had energy all day. but right now I'm wiped.").

Design choice: ONE signal per sentence (clean per-sentence label) but MANY sentences
per note (realistic structure). Cross-signal `none` is therefore abundant and natural.

Outputs (corpus_v2/):
  checkins.json      notes: [{id, date, text, sentences:[{text,mood,energy,focus}], gold:{...}}]
  mood.json/energy.json/focus.json   per-sentence training rows {text,label}

Deterministic (fixed seed). Does NOT read evalset.json — keeps EvalSet a fair test.
  python gen_checkins.py
"""

import json, random
from pathlib import Path

OUT = Path(__file__).resolve().parent / "corpus_v2"
OUT.mkdir(exist_ok=True)
RNG = random.Random(20260618)

# Reuse v1's 70-per-level varied phrasings (pristine, before cross-domain none was added)
# as the level phrase banks — gives real variety; the generator adds realistic structure.
_V1 = Path(__file__).resolve().parent / "corpus" / "v1_backup"
def _bank(sig):
    rows = json.loads((_V1 / f"{sig}.json").read_text())
    out = {}
    for r in rows:
        if r["label"] != "none":
            out.setdefault(r["label"], []).append(r["text"])
    return out

# ─────────────────────────────────────────────────────────────────────────────
# Phrase banks — messy, varied, real-journal voice (lowercase, filler, run-ons).
# Each level has many surface forms so a single user's 3 months has variety + some
# natural repetition.
# ─────────────────────────────────────────────────────────────────────────────
MOOD = _bank("mood")
ENERGY = _bank("energy")
FOCUS = _bank("focus")
# negation / hypothetical phrasings -> labeled by intent (semantic A for negation)
NEG_FOCUS = [("i couldn't focus to save my life", "distracted"), ("zero focus today", "foggy"),
             ("my concentration was completely gone", "foggy"), ("not focused at all", "distracted")]
NEG_ENERGY = [("had nothing left in me", "sluggish"), ("no energy whatsoever", "sluggish"),
              ("not energetic at all today", "tired")]
NEG_MOOD = [("just didn't feel good at all", "low"), ("not happy today honestly", "low")]

# `none` content — meds, sleep, activities, plans, filler. All three signals = none.
MEDS = ["took my elvanse 50mg at 8 with breakfast", "took my meds a bit late today",
        "skipped my medication this morning", "did my usual elvanse 50",
        "took vyvanse around 7am", "forgot my meds until like 11", "no meds today, drug holiday",
        "took my dose, lets see how it goes", "elvanse kicked in around 9"]
SLEEP = ["slept about 7 hours", "barely slept last night, maybe 4 hours", "slept like a rock for 8",
         "had a rough night, kept waking up", "went to bed late again", "slept in this morning",
         "decent sleep, woke up naturally", "only got 5 hours, restless"]
ACTIVITY = ["went for a walk after lunch", "had back to back meetings all morning",
            "did some laundry and tidied up", "long commute today, stuck in traffic",
            "had a call with my therapist", "made a proper dinner for once",
            "spent the morning answering emails", "went to the gym", "did the grocery shop",
            "worked from home today", "had coffee with a friend", "finished that report finally"]
PLAN = ["going to try and sleep earlier tonight", "hope tomorrow's a better one",
        "i'll see if i can focus once the meds kick in", "planning to take it easy this weekend",
        "want to get back into a routine", "going to do a deep work session later",
        "let's see how the afternoon goes", "i should really hydrate more"]
FILLER = ["okay so", "yeah", "honestly", "i mean", "let me think", "right so", "um", "today",
          "so yeah", "anyway"]

# Realistic level distributions (weights) — mid common, extremes rare.
W_MOOD = {"low": 2, "flat": 2, "okay": 4, "good": 4, "great": 1}
W_ENERGY = {"sluggish": 1, "tired": 4, "steady": 4, "alert": 2, "charged": 1}
W_FOCUS = {"foggy": 2, "distracted": 4, "present": 4, "sharp": 2, "lockedIn": 1}


def weighted(rng, weights):
    keys = list(weights); ws = [weights[k] for k in keys]
    return rng.choices(keys, ws)[0]


def pick(rng, bank):
    return rng.choice(bank)


def gen_note(rng, day_idx):
    """One realistic check-in. Correlated states; ~30% omit each signal; some temporal pairs."""
    # latent day quality drives correlation
    sleep_poor = rng.random() < 0.35
    # energy correlated with sleep
    if sleep_poor:
        energy_lvl = weighted(rng, {"sluggish": 3, "tired": 4, "steady": 2, "alert": 1, "charged": 0})
    else:
        energy_lvl = weighted(rng, W_ENERGY)
    # focus correlated with energy
    if energy_lvl in ("sluggish", "tired"):
        focus_lvl = weighted(rng, {"foggy": 3, "distracted": 4, "present": 2, "sharp": 1, "lockedIn": 0})
    else:
        focus_lvl = weighted(rng, W_FOCUS)
    mood_lvl = weighted(rng, W_MOOD)

    # signal omission (~30% each) — the note simply doesn't mention that signal
    has_mood = rng.random() > 0.30
    has_energy = rng.random() > 0.28
    has_focus = rng.random() > 0.30

    sents = []  # (text, mood, energy, focus)

    def add(text, m=None, e=None, f=None):
        sents.append({"text": text, "mood": m, "energy": e, "focus": f})

    # optional filler opener (none for all)
    if rng.random() < 0.5:
        add(pick(rng, FILLER).capitalize() + ".")
    # meds (common)
    if rng.random() < 0.55:
        add(pick(rng, MEDS).capitalize() + ".")
    # sleep (sometimes)
    if rng.random() < 0.4:
        add(pick(rng, SLEEP).capitalize() + ".")
    # mood
    if has_mood:
        if rng.random() < 0.15 and mood_lvl == "low":
            t, lvl = pick(rng, NEG_MOOD); add(t.capitalize() + ".", m=lvl)
        else:
            add(pick(rng, MOOD[mood_lvl]).capitalize() + ".", m=mood_lvl)
    # energy (with occasional temporal-recency pair)
    if has_energy:
        if rng.random() < 0.18 and energy_lvl in ("tired", "sluggish"):
            # earlier good -> now low (tests recency); label each sentence by what it states
            add("i had decent energy earlier.", e="steady")
            add(pick(rng, ENERGY[energy_lvl]).capitalize() + ".", e=energy_lvl)
        elif rng.random() < 0.12:
            t, lvl = pick(rng, NEG_ENERGY); add(t.capitalize() + ".", e=lvl)
        else:
            add(pick(rng, ENERGY[energy_lvl]).capitalize() + ".", e=energy_lvl)
    # focus (with occasional temporal pair + negation)
    if has_focus:
        if rng.random() < 0.18 and focus_lvl in ("distracted", "foggy"):
            add("i was able to focus this morning.", f="sharp")
            add(pick(rng, FOCUS[focus_lvl]).capitalize() + ".", f=focus_lvl)
        elif rng.random() < 0.15:
            t, lvl = pick(rng, NEG_FOCUS); add(t.capitalize() + ".", f=lvl)
        else:
            add(pick(rng, FOCUS[focus_lvl]).capitalize() + ".", f=focus_lvl)
    # activity (common, none)
    if rng.random() < 0.6:
        add(pick(rng, ACTIVITY).capitalize() + ".")
    # plan/hypothetical (sometimes, none)
    if rng.random() < 0.45:
        add(pick(rng, PLAN).capitalize() + ".")

    rng.shuffle_in_place = None  # keep order natural (don't shuffle)

    # note-level gold = the LAST stated (present) value per signal (recency = current state)
    gold = {"mood": None, "energy": None, "focus": None}
    for s in sents:
        for k in ("mood", "energy", "focus"):
            if s[k] is not None:
                gold[k] = s[k]

    text = " ".join(s["text"] for s in sents)
    return {"id": f"day{day_idx:03d}", "text": text, "sentences": sents, "gold": gold}


def main():
    notes = []
    day = 0
    while len([n for n in notes]) < 90:   # ~3 months of check-ins
        day += 1
        if RNG.random() < 0.72:           # realistic adherence ~72% of days
            notes.append(gen_note(RNG, day))

    (OUT / "checkins.json").write_text(json.dumps(notes, indent=2))

    # Phase 1.2 — split into per-sentence labeled corpora
    rows = {"mood": [], "energy": [], "focus": []}
    seen = {"mood": set(), "energy": set(), "focus": set()}
    for n in notes:
        for s in n["sentences"]:
            for sig in ("mood", "energy", "focus"):
                label = s[sig] if s[sig] is not None else "none"
                key = s["text"].lower().strip()
                if key in seen[sig]:
                    continue
                seen[sig].add(key)
                rows[sig].append({"text": s["text"], "label": label})
    from collections import Counter
    for sig in ("mood", "energy", "focus"):
        (OUT / f"{sig}.json").write_text(json.dumps(rows[sig], indent=2))
        c = Counter(r["label"] for r in rows[sig])
        nonepct = round(100 * c["none"] / len(rows[sig]))
        print(f"{sig}: {len(rows[sig])} sentences, none={c['none']} ({nonepct}%)  {dict(c)}")
    print(f"\nnotes: {len(notes)} check-ins over {day} days")
    # show a couple of sample notes
    print("\n--- sample notes ---")
    for n in notes[:3]:
        print(f"[{n['id']}] gold={n['gold']}")
        print(f"   {n['text']}")


if __name__ == "__main__":
    main()
