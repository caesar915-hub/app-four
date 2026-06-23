"""T026 — viewer-data shaping. Test-first."""
from judge.schema import parse_verdict
from judge.viewer import build_rows


def _pv(pid, presence):
    sig = {s: {"reason": f"{s} r", "present": p} for s, p in presence.items()}
    fld = {"reason": "x", "correct_items": [], "spurious_items": [], "missed_items": []}
    return parse_verdict({"id": pid, "signals": sig,
                          "fields": {k: fld for k in ("feelings", "activities", "sleep", "sideEffect")}})


def test_build_rows_derives_labels_and_escapes():
    verdicts = {"p1": _pv("p1", {"mood": False, "energy": False, "focus": True, "sleep": False})}
    joined = [{"id": "p1", "text": "<script>x</script> real focus today",
               "extraction": {"mood": "good", "energy": None, "focus": "sharp", "sleepHours": None}}]
    rows = {(r["signal"]): r for r in build_rows(verdicts, joined)}
    assert rows["mood"]["label"] == "FP"     # gold absent, ext detected -> FP
    assert rows["focus"]["label"] == "TP"    # gold present, ext detected -> TP
    assert rows["energy"]["label"] == "TN"
    assert "<script>" not in rows["mood"]["text"]  # escaped
    assert "&lt;script&gt;" in rows["mood"]["text"]
