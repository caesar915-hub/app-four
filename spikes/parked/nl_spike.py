#!/usr/bin/env python3
"""
NL logic spike (scratch — delete when done).

Reproduces app-four's NLNoteExtractor logic for the THREE failing-class sentences
from the screenshot, and shows BEFORE (current behaviour) vs AFTER (the three
proposed fixes): irrealis gate, inflection table, sentiment fallback.

This is NOT Apple NaturalLanguage (unavailable in Python). spaCy/VADER stand in
for NLTagger.lemma / sentimentScore. Both are OPTIONAL — the core rule logic runs
with pure stdlib. Run:  python3 nl_spike.py
"""
import re

FAILING = [
    "Felt good today.",                                  # C: mood missed ("felt" != "feel")
    "Lack of energy end of the day.",                    # B: energy missed (paraphrase)
    "Took elvanse 50mg, lets see if I can focus now.",   # A: focus falsely "Sharp" (irrealis)
]

# ── Mini lexicon (shape mirrors the real Lexicon.swift) ──────────────────────
FOCUS = {"sharp": ["sharp", "focused", "focus", "clear", "on track"]}
ENERGY = {"tired": ["tired", "low energy", "exhausted"],
          "sluggish": ["sluggish", "drained"]}
MOOD = {"good": ["feel good", "feeling good"], "low": ["feel low", "down"]}
NEGATION = {"not", "no", "never", "without", "n't", "cant", "couldnt"}
INFLECTIONS = {"felt": "feel"}                            # FIX C: deterministic, not lemma

# FIX A: irrealis markers — hypothetical / conditional / ability / future / wish
IRREALIS = {"if", "lets", "let", "hope", "want", "wanna", "gonna", "will",
            "might", "maybe", "could", "can", "should", "trying", "try"}


def tokens(s):
    return re.findall(r"[a-z0-9']+", s.lower())


def longest_match(toks, cue_map):
    """Return (label, phrase) of the longest cue phrase present, else None."""
    best = None
    for label, cues in cue_map.items():
        for cue in cues:
            ct = cue.split()
            if _contains(toks, ct) and (best is None or len(cue) > len(best[1])):
                best = (label, cue)
    return best


def _contains(toks, ct):
    if len(ct) == 1:
        return ct[0] in toks
    for i in range(len(toks) - len(ct) + 1):
        if toks[i:i + len(ct)] == ct:
            return True
    return False


def negated_before(phrase, low, window=5):
    idx = low.find(phrase)
    if idx < 0:
        return False
    prefix = low[:idx].split()[-window:]
    return any(w in NEGATION or w.endswith("n't") for w in prefix)


def is_irrealis(s):
    """FIX A: clause is hypothetical/conditional → not a state report."""
    toks = set(tokens(s))
    return bool(toks & IRREALIS) or s.strip().endswith("?")


# ── Sentiment backend (VADER if installed, else tiny built-in) ───────────────
def make_sentiment():
    try:
        from vaderSentiment.vaderSentiment import SentimentIntensityAnalyzer
        a = SentimentIntensityAnalyzer()
        return lambda t: a.polarity_scores(t)["compound"], "VADER"
    except Exception:
        neg = {"lack", "no", "tired", "drained", "exhausted", "low", "bad",
               "awful", "foggy", "crash", "worse", "cant", "struggle"}
        pos = {"good", "great", "calm", "proud", "sharp", "focused", "energetic"}
        def crude(t):
            ts = set(tokens(t))
            return (len(ts & pos) - len(ts & neg)) / max(1, len(ts))
        return crude, "built-in"


SENTIMENT, SENT_BACKEND = make_sentiment()
SENT_NEG_THRESHOLD = -0.4   # FIX B: calibrate against EvalSet


def extract(sentence, use_fixes):
    low = sentence.lower()
    toks = tokens(sentence)

    # FIX C: rewrite known inflections before matching (felt -> feel)
    if use_fixes:
        toks = [INFLECTIONS.get(t, t) for t in toks]
        low = " ".join(toks)

    out = {"focus": None, "energy": None, "mood": None}

    # FIX A: skip state assertion entirely for irrealis clauses
    irrealis = use_fixes and is_irrealis(sentence)

    f = longest_match(toks, FOCUS)
    if f and not negated_before(f[1], low) and not irrealis:
        out["focus"] = f[0]

    e = longest_match(toks, ENERGY)
    if e and not negated_before(e[1], low) and not irrealis:
        out["energy"] = e[0]
    elif use_fixes and not irrealis and "energy" in toks and out["energy"] is None:
        # FIX B: paraphrase fallback — energy mentioned, no cue → use sentiment
        if SENTIMENT(sentence) <= SENT_NEG_THRESHOLD:
            out["energy"] = "tired"

    m = longest_match(toks, MOOD)
    if m and not negated_before(m[1], low) and not irrealis:
        out["mood"] = m[0]

    return out


def main():
    print(f"sentiment backend: {SENT_BACKEND}  (install vaderSentiment for the real analog)\n")
    print(f"{'sentence':<52} {'signal':<7} {'BEFORE':<8} {'AFTER':<8} fix")
    print("-" * 86)
    fixmap = {"Felt good today.": "C", "Lack of energy end of the day.": "B",
              "Took elvanse 50mg, lets see if I can focus now.": "A"}
    for s in FAILING:
        before = extract(s, use_fixes=False)
        after = extract(s, use_fixes=True)
        for sig in ("focus", "energy", "mood"):
            b, a = before[sig], after[sig]
            if b == a and a is None:
                continue
            mark = "  <-- " + fixmap[s] if b != a else ""
            short = (s[:49] + "…") if len(s) > 50 else s
            print(f"{short:<52} {sig:<7} {str(b):<8} {str(a):<8}{mark}")
    print("\nExpected AFTER: focus stays None (A), energy=tired (B), mood=good (C).")
    print("sentiment per sentence:")
    for s in FAILING:
        print(f"  {SENTIMENT(s):+.2f}  {s}")


if __name__ == "__main__":
    main()
