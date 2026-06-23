"""Gold re-audit (spec 013, FR-004, SC-003).

Turns judge verdicts (corrected-gold presence) into a corrected-gold set plus a
change log of every draft label the re-audit flipped, with the judge's reason.
"""
from judge.io import SIGNALS


def reaudit(verdicts: dict, draft_signals: dict):
    """verdicts: {id: PostVerdict}; draft_signals: {id: iterable[str]}.
    Returns (corrected_gold, changelog)."""
    corrected, changelog = [], []
    for pid, pv in verdicts.items():
        cg = {s for s in SIGNALS if pv.signals[s].present}
        corrected.append({"id": pid, "signals": sorted(cg)})
        draft = set(draft_signals.get(pid, ()))
        for s in SIGNALS:
            in_draft, in_corrected = s in draft, s in cg
            if in_draft != in_corrected:
                changelog.append({
                    "id": pid,
                    "signal": s,
                    "from": "present" if in_draft else "absent",
                    "to": "present" if in_corrected else "absent",
                    "reason": pv.signals[s].reason,
                })
    return corrected, changelog
