"""Calibration: judge presence vs reference annotation, per signal, + TNR gate.

The judge's per-signal `present` is compared to the reference annotator's presence.
The gate (FR-006, SC-002, Clarification Q2) blocks the bulk run unless every
signal's true-negative rate (ability to call an ABSENT signal absent) >= 0.70.
"""
from judge.io import SIGNALS


def agreement(reference: dict, judge: dict) -> dict:
    """reference: {id: {signal: bool}}; judge: {id: PostVerdict}.
    Returns per-signal confusion of judge-vs-reference presence."""
    per = {s: {"tp": 0, "fp": 0, "fn": 0, "tn": 0} for s in SIGNALS}
    for pid, ref in reference.items():
        pv = judge[pid]
        for s in SIGNALS:
            jp = pv.signals[s].present
            rp = bool(ref[s])
            cell = "tp" if (jp and rp) else "fp" if (jp and not rp) else "fn" if (not jp and rp) else "tn"
            per[s][cell] += 1
    return per


def tpr(cell) -> float:
    d = cell["tp"] + cell["fn"]
    return cell["tp"] / d if d else 1.0


def tnr(cell) -> float:
    d = cell["tn"] + cell["fp"]
    return cell["tn"] / d if d else 1.0


def fpr(cell) -> float:
    return 1.0 - tnr(cell)


def gate(per: dict, floor: float = 0.70):
    """Return (passed, {signal: tnr}). Passes only if every signal's TNR >= floor."""
    rates = {s: tnr(c) for s, c in per.items()}
    return all(v >= floor for v in rates.values()), rates
