"""T013/T014 — calibration agreement + TNR gate. Test-first."""
from judge.schema import parse_verdict
from judge.backend import FixtureBackend
from judge.calibration import agreement, gate, tnr, tpr


def _verdict(id_, presence):
    sig = {s: {"reason": "x", "present": p} for s, p in presence.items()}
    fld = {"reason": "x", "correct_items": [], "spurious_items": [], "missed_items": []}
    return {"id": id_, "signals": sig,
            "fields": {k: fld for k in ("feelings", "activities", "sleep", "sideEffect")}}


def test_agreement_and_perfect_gate():
    # reference and judge agree exactly -> all TNR = 1.0, gate passes
    ref = {
        "p1": {"mood": True, "energy": False, "focus": True, "sleep": False},
        "p2": {"mood": False, "energy": False, "focus": True, "sleep": False},
    }
    raw = {pid: _verdict(pid, presence) for pid, presence in ref.items()}
    judge = {pid: parse_verdict(raw[pid]) for pid in ref}
    per = agreement(ref, judge)
    passed, rates = gate(per, floor=0.70)
    assert passed
    assert all(r == 1.0 for r in rates.values())


def test_gate_fails_when_judge_over_calls_absent_signals():
    # reference says mood absent on both posts; judge says present on both -> mood TNR=0
    ref = {
        "p1": {"mood": False, "energy": False, "focus": False, "sleep": False},
        "p2": {"mood": False, "energy": True, "focus": False, "sleep": False},
    }
    judge_presence = {
        "p1": {"mood": True, "energy": False, "focus": False, "sleep": False},
        "p2": {"mood": True, "energy": True, "focus": False, "sleep": False},
    }
    raw = {pid: _verdict(pid, judge_presence[pid]) for pid in ref}
    judge = {pid: parse_verdict(raw[pid]) for pid in ref}
    per = agreement(ref, judge)
    passed, rates = gate(per, floor=0.70)
    assert not passed
    assert rates["mood"] == 0.0          # both absent-mood cases called present
    assert tnr(per["energy"]) == 1.0     # energy fine


def test_fixture_backend_roundtrips():
    raw = {"p1": _verdict("p1", {"mood": True, "energy": False, "focus": True, "sleep": False})}
    be = FixtureBackend(raw)
    [pv] = be.judge_batch([{"id": "p1"}])
    assert pv.signals["focus"].present is True
