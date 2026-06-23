"""T006 — loaders + id-join. Test-first."""
import json

from judge.io import load_corpus, load_extractions, extractor_presence, join


def _write(tmp_path):
    corpus = tmp_path / "corpus.jsonl"
    corpus.write_text(
        json.dumps({"id": "a", "clean_text": "post A", "signals": ["focus"], "flagged_truncated": False}) + "\n"
        + json.dumps({"id": "b", "clean_text": "post B", "signals": [], "flagged_truncated": False}) + "\n"
    )
    ext = tmp_path / "ext.json"
    ext.write_text(json.dumps([
        {"id": "a", "mood": "good", "energy": None, "focus": "sharp", "sleepHours": 6, "feelings": ["calm"], "activities": [], "sideEffect": False},
    ]))
    return corpus, ext


def test_loaders_and_join(tmp_path):
    corpus, ext = _write(tmp_path)
    c = load_corpus(corpus)
    e = load_extractions(ext)
    assert len(c) == 2 and set(e) == {"a"}
    merged = join(c, e)
    # only "a" has an extraction -> "b" is dropped
    assert [m["id"] for m in merged] == ["a"]
    assert merged[0]["gold"] == ["focus"]
    assert merged[0]["text"] == "post A"


def test_extractor_presence_maps_sleephours():
    p = extractor_presence({"mood": "good", "energy": None, "focus": "sharp", "sleepHours": 6})
    assert p == {"mood": True, "energy": False, "focus": True, "sleep": True}


def test_extractor_presence_all_absent():
    p = extractor_presence({"mood": None, "energy": None, "focus": None, "sleepHours": None})
    assert p == {"mood": False, "energy": False, "focus": False, "sleep": False}
