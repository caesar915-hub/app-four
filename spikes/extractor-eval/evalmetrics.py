#!/usr/bin/env python3
"""Ordinal eval metrics + error-bucket heuristics for the value track. Stdlib only.

Tracks the spec-010 requirement that adjacent misses (3->4) are scored more kindly
than polar ones (5->1). Pairs are (expected_index, predicted_index) on a 0..n-1 scale.
"""
import re


def qwk(pairs, n):
    """Quadratic Weighted Kappa over (expected, predicted) index pairs, n classes."""
    if not pairs:
        return 1.0
    O = [[0] * n for _ in range(n)]
    for e, p in pairs:
        O[e][p] += 1
    w = [[((i - j) ** 2) / ((n - 1) ** 2) for j in range(n)] for i in range(n)]
    row = [sum(O[i]) for i in range(n)]
    col = [sum(O[i][j] for i in range(n)) for j in range(n)]
    total = len(pairs)
    E = [[row[i] * col[j] / total for j in range(n)] for i in range(n)]
    num = sum(w[i][j] * O[i][j] for i in range(n) for j in range(n))
    den = sum(w[i][j] * E[i][j] for i in range(n) for j in range(n))
    return 1.0 if den == 0 else 1.0 - num / den


def mae(pairs):
    """Mean absolute ordinal distance."""
    if not pairs:
        return 0.0
    return sum(abs(e - p) for e, p in pairs) / len(pairs)


def one_off(pairs):
    """Fraction of cases within 1 ordinal level (adjacent counts as correct)."""
    if not pairs:
        return 1.0
    return sum(1 for e, p in pairs if abs(e - p) <= 1) / len(pairs)


def _has_neg(transcript, neg_tokens):
    toks = re.findall(r"[a-z']+", (transcript or "").lower())
    return any(tok in neg_tokens or tok.endswith("n't") for tok in toks)


def classify_error(kind, expected, actual, transcript, neg_tokens):
    """Assign a single failure bucket. kind ∈ {value, fp, fn}.

    - value: both present but different level
    - fp:    gold absent, extractor produced something
    - fn:    gold present, extractor produced nothing
    """
    t = (transcript or "").lower()
    if kind == "value":
        return "negation miss" if _has_neg(t, neg_tokens) else "level error"
    if kind == "fp":
        return "negation miss" if _has_neg(t, neg_tokens) else "polysemy false positive"
    if kind == "fn":
        if any(b in t for b in (" but ", " however ", " although ", " though ")):
            return "clause-boundary error"
        return "lexicon gap"
    return "uncategorized"
