"""Confusion-matrix, derived labels, P/R/F1, and Rogan-Gladen bias correction.

Pure, judge-independent. The judge decides presence; labels are DERIVED here from
(gold presence x extractor presence), then corrected for the judge's measured
imperfection (FR-007, SC-004, research R4).
"""

_LABELS = ("TP", "FP", "FN", "TN")


def derive_label(gold_present: bool, extractor_present: bool) -> str:
    """Confusion-matrix cell from corrected-gold presence x extractor prediction."""
    if extractor_present and gold_present:
        return "TP"
    if extractor_present and not gold_present:
        return "FP"
    if not extractor_present and gold_present:
        return "FN"
    return "TN"


def tally(labels):
    counts = {"tp": 0, "fp": 0, "fn": 0, "tn": 0}
    for label in labels:
        if label not in _LABELS:
            raise ValueError(f"unknown verdict label: {label!r}")
        counts[label.lower()] += 1
    return counts


def prf(tp, fp, fn):
    """Precision / recall / F1. Zero (never NaN) on empty denominators."""
    precision = tp / (tp + fp) if (tp + fp) else 0.0
    recall = tp / (tp + fn) if (tp + fn) else 0.0
    f1 = 2 * precision * recall / (precision + recall) if (precision + recall) else 0.0
    return {"precision": precision, "recall": recall, "f1": f1}


def field_prf(correct, spurious, missed):
    """Per-field set-based P/R/F1 (counts of correct/spurious/missed items)."""
    return prf(tp=correct, fp=spurious, fn=missed)


def rogan_gladen(apparent: float, sens: float, spec: float) -> float:
    """Bias-correct an apparent positive rate for an imperfect classifier (judge).

    corrected = (apparent + spec - 1) / (sens + spec - 1), clamped to [0, 1].
    A perfect judge (sens=spec=1) returns `apparent` unchanged. Raises when the
    judge carries no information (sens + spec == 1).
    """
    denom = sens + spec - 1.0
    if abs(denom) < 1e-12:
        raise ValueError("uninformative judge: sens + spec == 1")
    corrected = (apparent + spec - 1.0) / denom
    return min(1.0, max(0.0, corrected))
