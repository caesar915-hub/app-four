"""T015/T021/T029 — re-audit changelog, reproducibility, minority veto. Test-first."""
import pytest

from judge.schema import parse_verdict
from judge.reaudit import reaudit
from judge.ensemble import minority_veto
from judge.score import signal_scorecard


def _pv(pid, presence):
    sig = {s: {"reason": f"{s} call", "present": p} for s, p in presence.items()}
    fld = {"reason": "x", "correct_items": [], "spurious_items": [], "missed_items": []}
    return parse_verdict({"id": pid, "signals": sig,
                          "fields": {k: fld for k in ("feelings", "activities", "sleep", "sideEffect")}})


# ---- re-audit changelog (T015) ----------------------------------------------

def test_reaudit_flags_each_changed_label():
    verdicts = {"p1": _pv("p1", {"mood": False, "energy": False, "focus": True, "sleep": False})}
    draft = {"p1": ["mood", "focus"]}  # draft had mood (judge removes) + focus (kept)
    corrected, changelog = reaudit(verdicts, draft)
    assert corrected == [{"id": "p1", "signals": ["focus"]}]
    assert len(changelog) == 1
    assert changelog[0] == {"id": "p1", "signal": "mood", "from": "present", "to": "absent",
                            "reason": "mood call"}


def test_reaudit_adds_missed_label():
    verdicts = {"p1": _pv("p1", {"mood": True, "energy": False, "focus": False, "sleep": False})}
    corrected, changelog = reaudit(verdicts, {"p1": []})  # draft empty, judge adds mood
    assert changelog[0]["to"] == "present" and changelog[0]["from"] == "absent"


# ---- reproducible aggregation (T021) ----------------------------------------

def test_scorecard_is_deterministic():
    verdicts = {"p1": _pv("p1", {"mood": True, "energy": False, "focus": True, "sleep": False})}
    joined = [{"id": "p1", "extraction": {"mood": "good", "energy": None, "focus": None, "sleepHours": None}}]
    a = signal_scorecard(verdicts, joined)
    b = signal_scorecard(verdicts, joined)
    assert a == b
    assert a["mood"]["raw"] == {"tp": 1, "fp": 0, "fn": 0, "tn": 0}   # gold+ ext+ -> TP
    assert a["focus"]["raw"] == {"tp": 0, "fp": 0, "fn": 1, "tn": 0}  # gold+ ext- -> FN


# ---- minority veto (T029) ---------------------------------------------------

def test_minority_veto_unanimous_confirms():
    assert minority_veto([True, True, True]) == {
        "confirmed": True, "present": True, "needs_human_review": False, "votes": [True, True, True]}
    assert minority_veto([False, False, False])["present"] is False


def test_minority_veto_split_flags_review():
    r = minority_veto([True, True, False])
    assert r["confirmed"] is False
    assert r["needs_human_review"] is True
    assert r["present"] is None


def test_minority_veto_empty_raises():
    with pytest.raises(ValueError):
        minority_veto([])
