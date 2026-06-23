"""T004 — verdict schema parse + validation (spec 013, FR-014, R6).

Test-first. The judge writes per-signal presence + per-field item sets; this
validates it so malformed output is retried/quarantined, never miscounted.
"""
import pytest

from judge.schema import PostVerdict, parse_verdict, VerdictError


def _valid_raw():
    sig = {"reason": "first-person present", "present": True}
    fld = {"reason": "ok", "correct_items": ["curious"], "spurious_items": [], "missed_items": []}
    return {
        "id": "abc-123",
        "signals": {"mood": sig, "energy": sig, "focus": sig, "sleep": sig},
        "fields": {"feelings": fld, "activities": fld, "sleep": fld, "sideEffect": fld},
    }


def test_valid_verdict_parses():
    v = parse_verdict(_valid_raw())
    assert isinstance(v, PostVerdict)
    assert v.id == "abc-123"
    assert v.signals["focus"].present is True
    assert v.fields["feelings"].correct_items == ["curious"]


def test_accepts_json_string():
    import json
    assert parse_verdict(json.dumps(_valid_raw())).id == "abc-123"


def test_non_bool_present_rejected():
    raw = _valid_raw()
    raw["signals"]["mood"]["present"] = "yes"
    with pytest.raises(VerdictError):
        parse_verdict(raw)


def test_missing_present_rejected():
    raw = _valid_raw()
    del raw["signals"]["mood"]["present"]
    with pytest.raises(VerdictError):
        parse_verdict(raw)


def test_empty_reason_rejected():
    raw = _valid_raw()
    raw["signals"]["mood"]["reason"] = ""
    with pytest.raises(VerdictError):
        parse_verdict(raw)


def test_missing_signal_key_rejected():
    raw = _valid_raw()
    del raw["signals"]["sleep"]
    with pytest.raises(VerdictError):
        parse_verdict(raw)


def test_malformed_garbage_rejected():
    with pytest.raises(VerdictError):
        parse_verdict("not json at all {")
