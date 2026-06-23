"""Disputed-case minority veto (spec 013, FR-012, research R5).

For judge-vs-extractor disagreements, the judge is run N times (varied framing).
Confirm the verdict only on unanimity; any split flags the record for human review
(minority veto beats majority voting for the false-negative blindspot).
"""


def minority_veto(panel: list[bool]) -> dict:
    """panel: per-pass presence votes for one disputed signal.
    Confirmed only if all passes agree; otherwise needs_human_review."""
    if not panel:
        raise ValueError("empty panel")
    unanimous = all(panel) or not any(panel)
    return {
        "confirmed": unanimous,
        "present": panel[0] if unanimous else None,
        "needs_human_review": not unanimous,
        "votes": list(panel),
    }
