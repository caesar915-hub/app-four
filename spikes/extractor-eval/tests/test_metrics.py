"""T005/T019/T020/T022 — metric core: derived labels, P/R/F1, Rogan-Gladen.

Test-first (Constitution X). Pure logic, judge-independent.
"""
import math

import pytest

from judge.metrics import derive_label, tally, prf, field_prf, rogan_gladen


# ---- derived labels (gold x extractor) --------------------------------------

@pytest.mark.parametrize("gold,ext,expected", [
    (True, True, "TP"),
    (False, True, "FP"),
    (True, False, "FN"),
    (False, False, "TN"),
])
def test_derive_label(gold, ext, expected):
    assert derive_label(gold, ext) == expected


# ---- tally + prf ------------------------------------------------------------

def test_tally_counts():
    assert tally(["TP", "TP", "FP", "FN", "TN"]) == {"tp": 2, "fp": 1, "fn": 1, "tn": 1}


def test_tally_rejects_unknown():
    with pytest.raises(ValueError):
        tally(["TP", "MAYBE"])


def test_prf_typical():
    r = prf(tp=80, fp=33, fn=41)
    p, rec = 80 / 113, 80 / 121
    assert r["precision"] == pytest.approx(p)
    assert r["recall"] == pytest.approx(rec)
    assert r["f1"] == pytest.approx(2 * p * rec / (p + rec))


def test_prf_zero_not_nan():
    r = prf(tp=0, fp=0, fn=5)
    assert (r["precision"], r["recall"], r["f1"]) == (0.0, 0.0, 0.0)
    assert not math.isnan(r["f1"])


def test_field_prf_from_set_counts():
    # 3 correct, 1 spurious, 2 missed
    r = field_prf(correct=3, spurious=1, missed=2)
    assert r["precision"] == pytest.approx(3 / 4)
    assert r["recall"] == pytest.approx(3 / 5)


# ---- Rogan-Gladen bias correction -------------------------------------------

def test_rogan_gladen_perfect_judge_is_identity():
    assert rogan_gladen(0.42, sens=1.0, spec=1.0) == pytest.approx(0.42)


def test_rogan_gladen_corrects_downward_when_judge_over_calls():
    # apparent 0.50, sens 0.90, spec 0.80 -> (0.5+0.8-1)/(0.9+0.8-1) = 0.3/0.7
    assert rogan_gladen(0.50, sens=0.90, spec=0.80) == pytest.approx(0.3 / 0.7)


def test_rogan_gladen_clamps_to_unit_interval():
    assert rogan_gladen(0.05, sens=0.9, spec=0.9) == 0.0   # would be negative
    assert rogan_gladen(0.99, sens=0.9, spec=0.9) == 1.0   # would exceed 1


def test_rogan_gladen_uninformative_judge_raises():
    with pytest.raises(ValueError):
        rogan_gladen(0.5, sens=0.5, spec=0.5)  # sens+spec==1
