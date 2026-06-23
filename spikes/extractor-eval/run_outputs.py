"""Emit all pipeline output artifacts from the current verdicts (spec 013)."""
import json

from judge.io import load_corpus, load_extractions, join
from judge.reaudit import reaudit
from judge.score import load_verdicts, signal_scorecard, field_scorecard
from judge.calibration import agreement, gate, tnr, tpr
from judge import viewer


def main():
    corpus = list({r["id"]: r for r in load_corpus("data/addrec_1082_summaries.jsonl")}.values())
    extr = load_extractions("out/extractions_500.json")
    joined = join(corpus, extr)
    verdicts = load_verdicts()
    judged = [m for m in joined if m["id"] in verdicts]
    full = {cid[:8]: cid for cid in {r["id"] for r in corpus}}

    # re-audit gold
    draft = {r["id"]: r.get("signals", []) for r in corpus}
    corrected, changelog = reaudit(verdicts, draft)
    json.dump(corrected, open("out/corrected_gold.json", "w"), indent=1)
    json.dump(changelog, open("out/gold_changelog.json", "w"), indent=1)

    # scorecard
    sc = {"n_posts": len(judged),
          "signals": signal_scorecard(verdicts, judged),
          "fields": field_scorecard(verdicts, judged)}
    json.dump(sc, open("out/scorecard.json", "w"), indent=1)

    # calibration agreement (reference labels vs judge verdicts)
    cal = [json.loads(l) for l in open("data/calibration_labels.jsonl")]
    reference = {}
    for c in cal:
        fid = full.get(c["id"], c["id"])
        if fid in verdicts:
            reference[fid] = c["human_signals"]
    agree = {}
    if reference:
        per = agreement(reference, verdicts)
        passed, tnrs = gate(per)
        agree = {s: {"tpr": round(tpr(per[s]), 3), "tnr": round(tnr(per[s]), 3),
                     "n": sum(per[s].values())} for s in per}
        agree["_gate_pass"] = passed
        json.dump(agree, open("out/judge_agreement.json", "w"), indent=1)

    viewer.main()
    print(f"corrected_gold: {len(corrected)} posts | changelog: {len(changelog)} flips "
          f"({len(changelog)/max(1,len(corrected)):.1f}/post)")
    print(f"scorecard: out/scorecard.json ({len(judged)} judged)")
    print(f"calibration agreement: {len(reference)} ref posts, gate={agree.get('_gate_pass')}")


if __name__ == "__main__":
    main()
