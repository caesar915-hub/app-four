#!/usr/bin/env python3
"""Test-first (Principle X) for the ordinal eval metrics. Stdlib only.

Run: python3 test_evalmetrics.py   ->   prints PASS/FAIL, exits non-zero on failure.
"""
import sys
from evalmetrics import qwk, mae, one_off, classify_error

# Ordinal scale 0..4 (e.g. great..flat). Pairs are (expected_idx, predicted_idx).
def approx(a, b, eps=1e-9): return abs(a - b) < eps

fails = []
def check(name, cond):
    print(f"{'PASS' if cond else 'FAIL'}  {name}")
    if not cond: fails.append(name)

# --- QWK ---
perfect = [(0, 0), (1, 1), (2, 2), (3, 3), (4, 4)]
check("qwk perfect agreement == 1.0", approx(qwk(perfect, 5), 1.0))

adjacent = [(2, 3), (1, 1), (0, 0), (4, 4), (3, 3)]   # one case off by 1
polar    = [(2, 0), (1, 1), (0, 0), (4, 4), (3, 3)]   # one case off by 2
# More distant disagreement must yield a STRICTLY lower kappa.
check("qwk off-by-1 beats off-by-larger", qwk(adjacent, 5) > qwk(polar, 5))

# --- MAE ---
check("mae perfect == 0", approx(mae(perfect), 0.0))
check("mae off-by-1 beats off-by-4",
      mae([(0, 1)]) < mae([(0, 4)]))
check("mae averages distances", approx(mae([(0, 1), (0, 3)]), 2.0))

# --- 1-off accuracy ---
check("one_off counts adjacent as correct",
      approx(one_off([(2, 2), (2, 3), (2, 1)]), 1.0))
check("one_off counts polar as wrong",
      approx(one_off([(2, 2), (2, 4)]), 0.5))

# --- error bucket classifier (heuristics over a case) ---
NEG = {"not", "never", "no", "n't", "without"}
# A wrong value with a negation token nearby -> negation miss
check("bucket negation miss",
      classify_error(kind="value", expected="good", actual="low",
                     transcript="i don't feel good today", neg_tokens=NEG) == "negation miss")
# A spurious detection (gold absent) -> trap/polysemy false positive
check("bucket polysemy FP",
      classify_error(kind="fp", expected=None, actual="sluggish",
                     transcript="my gym bag felt heavy", neg_tokens=NEG) == "polysemy false positive")
# A miss with no obvious cause -> lexicon gap
check("bucket lexicon gap",
      classify_error(kind="fn", expected="sluggish", actual=None,
                     transcript="wading through wet sand all morning", neg_tokens=NEG) == "lexicon gap")

print()
if fails:
    print(f"{len(fails)} FAILED: {fails}")
    sys.exit(1)
print("ALL PASS")
