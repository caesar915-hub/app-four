"""Extractor scorecard from persisted verdicts (spec 013, FR-007/008, T024/T025).

Reads out/verdicts_1082.json (corrected gold = judge presence), derives confusion
labels vs the extractor's presence, and reports per-signal + per-field P/R/F1.
Bias-corrected CIs (Rogan-Gladen) plug in once a validated calibration set exists.
"""
import json

from judge.io import SIGNALS, load_corpus, load_extractions, join, extractor_presence
from judge.schema import parse_verdict
from judge.metrics import derive_label, tally, prf, field_prf

FIELDS = ("feelings", "activities", "sleep", "sideEffect")


def load_verdicts(path="out/verdicts_1082.json"):
    return {v["id"]: parse_verdict(v) for v in json.load(open(path))}


def signal_scorecard(verdicts, joined):
    rows = {}
    for s in SIGNALS:
        labels = []
        for m in joined:
            v = verdicts.get(m["id"])
            if not v:
                continue
            labels.append(derive_label(v.signals[s].present, extractor_presence(m["extraction"])[s]))
        c = tally(labels)
        rows[s] = {**prf(c["tp"], c["fp"], c["fn"]), "raw": c, "n": len(labels)}
    return rows


def field_scorecard(verdicts, joined):
    rows = {}
    for f in FIELDS:
        tp = fp = fn = 0
        for m in joined:
            v = verdicts.get(m["id"])
            if not v:
                continue
            fv = v.fields[f]
            tp += len(fv.correct_items)
            fp += len(fv.spurious_items)
            fn += len(fv.missed_items)
        rows[f] = {**field_prf(tp, fp, fn), "raw": {"tp": tp, "fp": fp, "fn": fn}}
    return rows


def main():
    rows = [json.loads(l) for l in open("data/addrec_1082_summaries.jsonl") if l.strip()]
    corpus = list({r["id"]: r for r in rows}.values())  # dedupe by id
    extr = load_extractions("out/extractions_500.json")
    joined = join(corpus, extr)
    verdicts = load_verdicts()
    judged = [m for m in joined if m["id"] in verdicts]

    print(f"=== EXTRACTOR SCORECARD — {len(judged)}/{len(joined)} scoring-eligible posts judged ===")
    print(f"{'signal':9} {'P':>5} {'R':>5} {'F1':>5}   tp/fp/fn/tn")
    for s, r in signal_scorecard(verdicts, judged).items():
        c = r["raw"]
        print(f"{s:9} {r['precision']:>5.2f} {r['recall']:>5.2f} {r['f1']:>5.2f}   {c['tp']}/{c['fp']}/{c['fn']}/{c['tn']}")
    print(f"\n{'field':9} {'P':>5} {'R':>5} {'F1':>5}   tp/fp/fn (items)")
    for f, r in field_scorecard(verdicts, judged).items():
        c = r["raw"]
        print(f"{f:9} {r['precision']:>5.2f} {r['recall']:>5.2f} {r['f1']:>5.2f}   {c['tp']}/{c['fp']}/{c['fn']}")


if __name__ == "__main__":
    main()
