"""Resumable bulk judging store (spec 013, research R3, R6, FR-014).

Verdicts are appended to out/verdicts_1082.json keyed by FULL post id. A run skips
ids already present (resume, never restart). Malformed verdicts go to quarantine,
never miscounted. The judging itself is done by Claude Code (no API key); this
module only validates + persists what the judge produced.
"""
import json
import os

from judge.schema import parse_verdict, VerdictError

VERDICTS = "out/verdicts_1082.json"
QUARANTINE = "out/verdicts_quarantine.json"


def _load(path):
    return json.load(open(path)) if os.path.exists(path) else []


def done_ids(path=VERDICTS):
    return {v["id"] for v in _load(path)}


def ingest(raw_list, verdicts=VERDICTS, quarantine=QUARANTINE):
    """Validate + append new verdicts. Returns (added, quarantined, total)."""
    store = _load(verdicts)
    quar = _load(quarantine)
    existing = {v["id"] for v in store}
    added = bad = 0
    for raw in raw_list:
        try:
            pv = parse_verdict(raw)
        except VerdictError as e:
            quar.append({"raw": raw, "error": str(e)})
            bad += 1
            continue
        if pv.id in existing:
            continue
        store.append(raw)
        existing.add(pv.id)
        added += 1
    json.dump(store, open(verdicts, "w"), indent=1)
    if quar:
        json.dump(quar, open(quarantine, "w"), indent=1)
    return added, bad, len(store)


def pending(all_ids, path=VERDICTS):
    """Ids in all_ids not yet judged, preserving order."""
    have = done_ids(path)
    return [i for i in all_ids if i not in have]
