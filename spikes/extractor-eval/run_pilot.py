"""Calibration pilot (spec 013) — REAL run on 11 corpus posts.

I (Claude Code, Opus 4.8) act as TWO labelers on the same posts:
  - REFERENCE: a lenient, holistic careful annotator (human stand-in).
  - JUDGE: the strict adversarial per-signal judge (the production judge).
Both are the same model, so agreement is partly self-consistency — see the caveat
printed at the end. This proves the pipeline end-to-end on real data and exercises
the TNR>=0.70 gate; it is NOT validated accuracy.
"""
import json

from judge.io import SIGNALS, load_corpus, load_extractions, join, extractor_presence
from judge.schema import parse_verdict
from judge.calibration import agreement, gate, tnr, tpr
from judge.metrics import derive_label, tally, prf

S = SIGNALS  # mood, energy, focus, sleep

# --- REFERENCE (lenient careful annotation): present? per signal --------------
REF = {
    "39b916fd": (1, 0, 0, 0),  # "appreciative" own mild mood; "impulsive" != focus
    "7e3daf76": (0, 0, 0, 0),  # advice; "it helped me" past/ongoing, not present state
    "8ea8440b": (0, 0, 0, 0),  # "felt fine" PAST; rest advice
    "0874484b": (0, 0, 0, 0),  # all advice to OP
    "d90a0c80": (0, 0, 1, 0),  # lenient: own brain-fog/clarity experience
    "75c10258": (1, 0, 0, 0),  # lenient: present nostalgic enthusiasm
    "1fd60f2e": (1, 0, 0, 0),  # lenient: present anxiety ("still check religiously")
    "ab581be1": (0, 0, 1, 0),  # genuine own hyperfocus
    "863018b6": (1, 1, 0, 0),  # present low mood + tiredness
    "a914ed9a": (1, 0, 1, 0),  # present low mood + executive/focus difficulty
    "4aa5b28f": (1, 0, 1, 0),  # present overwhelm + can't-focus
}

# --- JUDGE (strict adversarial): present? per signal --------------------------
JUDGE = {
    "39b916fd": (0, 0, 0, 0),  # strict: advice-framed, no clear own affect
    "7e3daf76": (0, 0, 0, 0),
    "8ea8440b": (0, 0, 0, 0),
    "0874484b": (0, 0, 0, 0),
    "d90a0c80": (0, 0, 0, 0),  # strict: past-Sandoz + generics venting (excl. 3,5)
    "75c10258": (0, 0, 0, 0),  # strict: chit-chat about a videogame
    "1fd60f2e": (0, 0, 0, 0),  # strict: the affect described is a PAST episode
    "ab581be1": (0, 0, 1, 0),
    "863018b6": (1, 1, 0, 0),
    "a914ed9a": (1, 0, 1, 0),
    "4aa5b28f": (1, 0, 1, 0),
}

# --- richer-field verdicts (extractor items -> correct/spurious/missed) --------
FIELDS = {  # id: {field: (correct[], spurious[], missed[])}
    "39b916fd": {"activities": ([], ["Work"], [])},
    "7e3daf76": {"activities": (["Work"], [], [])},
    "0874484b": {"feelings": ([], ["guilty"], []), "activities": ([], ["Hanging Out"], [])},
    "d90a0c80": {"feelings": ([], ["curious"], []), "activities": ([], ["Errands", "Work"], [])},
    "1fd60f2e": {"activities": (["Errands"], ["Fitness"], [])},
    "ab581be1": {"activities": (["Work"], ["Hobbies", "Resting"], [])},
    "863018b6": {"activities": ([], ["Work"], [])},
    "a914ed9a": {"feelings": (["guilty"], [], [])},
    "4aa5b28f": {"feelings": (["overwhelmed"], ["guilty"], []), "activities": (["Work"], ["Hobbies", "Resting"], [])},
}

_REASON = {"present": "first-person present", "absent": "not author's own present experience"}


def _post_verdict(pid, presence):
    sig = {s: {"reason": _REASON["present"] if p else _REASON["absent"], "present": bool(p)}
           for s, p in zip(S, presence)}
    fv = FIELDS.get(pid, {})
    fields = {}
    for f in ("feelings", "activities", "sleep", "sideEffect"):
        c, sp, m = fv.get(f, ([], [], []))
        fields[f] = {"reason": "set audit", "correct_items": c, "spurious_items": sp, "missed_items": m}
    return {"id": pid, "signals": sig, "fields": fields}


def main():
    corpus = {r["id"]: r for r in load_corpus("data/addrec_1082_summaries.jsonl")}
    extr = load_extractions("out/extractions_500.json")
    FULL = {cid[:8]: cid for cid in corpus}  # our annotation keys are 8-char prefixes

    # write calibration_labels.jsonl (reference)
    strata = {  # rough stratum tags
        "39b916fd": "noise", "7e3daf76": "noise", "8ea8440b": "noise", "0874484b": "noise",
        "d90a0c80": "ambiguous", "75c10258": "ambiguous", "1fd60f2e": "ambiguous",
        "ab581be1": "pure", "863018b6": "pure", "a914ed9a": "pure", "4aa5b28f": "pure",
    }
    with open("data/calibration_labels.jsonl", "w") as f:
        for pid, pres in REF.items():
            f.write(json.dumps({"id": pid, "stratum": strata[pid],
                                "human_signals": dict(zip(S, [bool(x) for x in pres]))}) + "\n")

    # write pilot_verdicts.json (judge) and validate every one
    raw = [_post_verdict(pid, JUDGE[pid]) for pid in JUDGE]
    verdicts = {pv.id: pv for pv in (parse_verdict(r) for r in raw)}
    json.dump(raw, open("out/pilot_verdicts.json", "w"), indent=1)

    # --- calibration: judge presence vs reference ---
    reference = {pid: dict(zip(S, [bool(x) for x in pres])) for pid, pres in REF.items()}
    per = agreement(reference, verdicts)
    passed, tnrs = gate(per, floor=0.70)

    print("=== CALIBRATION (judge vs reference annotation, n=%d) ===" % len(REF))
    print(f"{'signal':7} {'TNR':>5} {'TPR':>5}   cells(tp/fp/fn/tn)")
    for s in S:
        print(f"{s:7} {tnr(per[s]):>5.2f} {tpr(per[s]):>5.2f}   "
              f"{per[s]['tp']}/{per[s]['fp']}/{per[s]['fn']}/{per[s]['tn']}")
    print(f"GATE (min TNR >= 0.70): {'PASS' if passed else 'BLOCK'}  min TNR = {min(tnrs.values()):.2f}")

    # --- mini scorecard: extractor vs corrected gold (=judge presence) ---
    print("\n=== EXTRACTOR SCORECARD (presence, vs judge-corrected gold, n=%d) ===" % len(JUDGE))
    print(f"{'signal':7} {'P':>5} {'R':>5} {'F1':>5}   labels")
    for i, s in enumerate(S):
        labels = []
        for pid in JUDGE:
            gold_present = bool(JUDGE[pid][i])
            ext_present = extractor_presence(extr[FULL[pid]])[s]
            labels.append(derive_label(gold_present, ext_present))
        c = tally(labels)
        r = prf(c["tp"], c["fp"], c["fn"])
        print(f"{s:7} {r['precision']:>5.2f} {r['recall']:>5.2f} {r['f1']:>5.2f}   {labels}")

    # --- re-audit vs DRAFT gold (independent prior labels) ---
    flips = 0
    for pid in JUDGE:
        draft = set(corpus[FULL[pid]].get("signals", []))
        corrected = {s for i, s in enumerate(S) if JUDGE[pid][i]}
        flips += len(draft ^ corrected)
    print(f"\n=== RE-AUDIT vs DRAFT gold: {flips} label flips across {len(JUDGE)} posts "
          f"(={flips/len(JUDGE):.1f}/post) — draft gold over-labels advice/quote posts ===")

    print("\n*** CAVEAT: both labelers are the same model (lenient vs strict framing), so "
          "TNR=1.0 reflects 'no over-flagging' but is self-consistency, NOT validated accuracy. "
          "Real human labels are needed to trust the gate/bias bars. ***")


if __name__ == "__main__":
    main()
