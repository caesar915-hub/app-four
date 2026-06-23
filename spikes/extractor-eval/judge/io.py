"""Loaders + id-join for corpus and extractor dumps (spec 013, FR-014).

Join is by post `id`, never by position. Extractor presence maps the real dump
keys: mood/energy/focus non-null, and `sleepHours` non-null -> sleep present.
"""
import json

SIGNALS = ("mood", "energy", "focus", "sleep")


def load_corpus(path):
    """Load the JSONL corpus (id, clean_text, signals, flagged_truncated)."""
    with open(path) as f:
        return [json.loads(line) for line in f if line.strip()]


def load_extractions(path):
    """Load the extractor dump JSON into {id: record}."""
    with open(path) as f:
        return {r["id"]: r for r in json.load(f)}


def extractor_presence(ext):
    """Per-signal boolean: did the extractor detect this signal?"""
    return {
        "mood": ext.get("mood") is not None,
        "energy": ext.get("energy") is not None,
        "focus": ext.get("focus") is not None,
        "sleep": ext.get("sleepHours") is not None,
    }


def join(corpus, extractions):
    """Merge corpus + extractions by id. Posts without an extraction are dropped
    (extractor scoring can only cover posts the extractor actually ran on)."""
    out = []
    for r in corpus:
        ext = extractions.get(r["id"])
        if ext is None:
            continue
        out.append({
            "id": r["id"],
            "text": r["clean_text"],
            "gold": list(r.get("signals", [])),
            "extraction": ext,
        })
    return out
