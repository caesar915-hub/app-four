#!/usr/bin/env python3
"""Performance review for NLNoteExtractor, from the Swift harness JSON.

Stdlib only — runs under any python3, no venv. Computes per-category precision/recall
(matching the Swift EvalMetrics semantics: a wrong non-nil scalar counts as both a
false positive and a false negative), confusion matrices for the ordinal signals
(mood/energy/focus) so adjacent vs. polar misses are visible, and a full error table.
"""
import sys, json, csv, os, re
from collections import defaultdict
from evalmetrics import qwk, mae, one_off, classify_error

SCALAR = ["mood", "energy", "focus", "sleepHours", "sideEffect"]
SETS = ["feelings", "activities", "meds"]
# Natural ordering so confusion grids read from "good" to "bad". '∅' = not detected.
ORDER = {
    "mood":   ["great", "good", "okay", "low", "flat"],
    "energy": ["charged", "alert", "steady", "tired", "sluggish"],
    "focus":  ["lockedIn", "sharp", "present", "distracted", "foggy"],
}
NEG_TOKENS = {"not", "never", "no", "n't", "without"}

def _idx(cat, val):
    return ORDER[cat].index(val) if (val in ORDER.get(cat, [])) else None

def scalar_counts(exp, act):
    """(tp, fp, fn) for one scalar field — mirrors EvalCounts(expectedScalar:actualScalar:)."""
    if exp is None and act is None: return (0, 0, 0)
    if exp is None and act is not None: return (0, 1, 0)
    if exp is not None and act is None: return (0, 0, 1)
    return (1, 0, 0) if exp == act else (0, 1, 1)

def set_counts(exp, act):
    e, a = set(exp or []), set(act or [])
    return (len(e & a), len(a - e), len(e - a))

def pr(tp, fp, fn):
    p = 1.0 if tp + fp == 0 else tp / (tp + fp)
    r = 1.0 if tp + fn == 0 else tp / (tp + fn)
    return p, r

def norm(v):
    if isinstance(v, bool): return "yes" if v else None
    if isinstance(v, float): return ("%g" % v)
    return v

def main(path):
    rows = json.load(open(path))
    # Overall totals plus per-language-group totals (the lexicon is English-only, so
    # mixing PT/ES into the aggregate hides how the English extractor actually does).
    def new_totals(): return {c: [0, 0, 0] for c in SCALAR + SETS}
    totals = new_totals()
    by_lang = {"en": new_totals(), "pt+es": new_totals()}
    confusion = {c: defaultdict(lambda: defaultdict(int)) for c in ORDER}
    errors = []  # (category, id, expected, actual, transcript, bucket)
    ordinal_pairs = {c: [] for c in ORDER}      # (exp_idx, pred_idx) where both present
    ordinal_nil = {c: [0, 0] for c in ORDER}    # [gold_present, of_which_predicted_nil]
    bucket_tally = defaultdict(int)

    for row in rows:
        exp, act = row["expected"], row["actual"]
        tx = row["transcript"]
        grp = "en" if row.get("language") == "en" else "pt+es"
        for c in SCALAR:
            e, a = norm(exp.get(c)), norm(act.get(c))
            tp, fp, fn = scalar_counts(e, a)
            for i, v in enumerate((tp, fp, fn)):
                totals[c][i] += v; by_lang[grp][c][i] += v
            if c in ORDER:
                confusion[c][e or "∅"][a or "∅"] += 1
                ie, ia = _idx(c, e), _idx(c, a)
                if ie is not None:
                    ordinal_nil[c][0] += 1
                    if ia is not None:
                        ordinal_pairs[c].append((ie, ia))
                    else:
                        ordinal_nil[c][1] += 1
            if (fp or fn):
                kind = "value" if (e and a) else ("fp" if a else "fn")
                bucket = classify_error(kind=kind, expected=e, actual=a,
                                        transcript=tx, neg_tokens=NEG_TOKENS)
                bucket_tally[bucket] += 1
                errors.append((c, row["id"], e, a, tx, bucket))
        for c in SETS:
            e, a = exp.get(c) or [], act.get(c) or []
            tp, fp, fn = set_counts(e, a)
            for i, v in enumerate((tp, fp, fn)):
                totals[c][i] += v; by_lang[grp][c][i] += v
            miss = sorted(set(e) - set(a)); extra = sorted(set(a) - set(e))
            if miss or extra:
                bucket = "lexicon gap" if miss else "polysemy false positive"
                bucket_tally[bucket] += 1
                errors.append((c, row["id"], "miss=%s" % miss, "extra=%s" % extra, tx, bucket))

    n = len(rows)
    print(f"\n=== EXTRACTOR PERFORMANCE — {n} cases ===\n")
    print(f"{'category':<14}{'P':>7}{'R':>7}{'F1':>7}   {'tp':>4}{'fp':>4}{'fn':>4}")
    print("-" * 52)
    for c in SCALAR + SETS:
        tp, fp, fn = totals[c]
        p, r = pr(tp, fp, fn)
        f1 = 0.0 if p + r == 0 else 2 * p * r / (p + r)
        print(f"{c:<14}{p:>7.2f}{r:>7.2f}{f1:>7.2f}   {tp:>4}{fp:>4}{fn:>4}")

    # Same table, sliced by language — separates "English extraction quality" from
    # "multilingual coverage", which are two different problems with two different fixes.
    en_n = sum(1 for r in rows if r.get("language") == "en")
    print(f"\n--- by language: EN ({en_n} cases)  vs  PT+ES ({len(rows) - en_n} cases) ---")
    print(f"{'category':<14}{'P.en':>7}{'R.en':>7}{'F1.en':>7}    {'P.xl':>7}{'R.xl':>7}{'F1.xl':>7}")
    print("-" * 64)
    for c in SCALAR + SETS:
        pe, re_ = pr(*by_lang["en"][c]); px, rx = pr(*by_lang["pt+es"][c])
        f1e = 0.0 if pe + re_ == 0 else 2 * pe * re_ / (pe + re_)
        f1x = 0.0 if px + rx == 0 else 2 * px * rx / (px + rx)
        print(f"{c:<14}{pe:>7.2f}{re_:>7.2f}{f1e:>7.2f}    {px:>7.2f}{rx:>7.2f}{f1x:>7.2f}")

    # Confusion matrices for the ordinal signals — the thing the floor test can't show.
    for c in ORDER:
        labels = ORDER[c] + ["∅"]
        seen = set(confusion[c].keys()) | {a for d in confusion[c].values() for a in d}
        labels = [l for l in labels if l in seen] + sorted(seen - set(labels))
        if not seen: continue
        print(f"\n--- {c}: confusion (row = expected, col = actual) ---")
        head = "exp\\act".ljust(11) + "".join(l[:8].rjust(9) for l in labels)
        print(head)
        for e in labels:
            line = e[:10].ljust(11)
            for a in labels:
                cnt = confusion[c][e][a]
                line += (str(cnt) if cnt else "·").rjust(9)
            print(line)

    # Distance-aware ORDINAL metrics — the view nominal P/R can't give (spec 010).
    # Computed only on value-labeled cases where both expected & predicted are present;
    # nil predictions are excluded from QWK/MAE and reported as a separate nil-rate.
    print("\n--- ordinal value metrics (mood/energy/focus) ---")
    print(f"{'category':<10}{'QWK':>7}{'MAE':>7}{'1-off':>7}{'n_pairs':>9}{'nil%':>7}")
    print("-" * 47)
    for c in ORDER:
        pairs = ordinal_pairs[c]
        present, niled = ordinal_nil[c]
        nil_rate = (niled / present) if present else 0.0
        print(f"{c:<10}{qwk(pairs, len(ORDER[c])):>7.2f}{mae(pairs):>7.2f}"
              f"{one_off(pairs):>7.2f}{len(pairs):>9}{nil_rate*100:>6.0f}%")
    print("(QWK 1.0=perfect, 0=chance; MAE=avg level distance; 1-off=within one level;"
          " nil%=gold-present but predicted nothing.)")

    # Phenomenon slices — so a fix's effect is visible on the cases it targets.
    def neg(tx): return any(t in NEG_TOKENS or t.endswith("n't")
                            for t in re.findall(r"[a-z']+", tx.lower()))
    SLICES = {
        "negation":      lambda r: neg(r["transcript"]),
        "paraphrase":    lambda r: "paraphrase" in r["id"],
        "multi-clause":  lambda r: any(b in r["transcript"].lower()
                                       for b in (" but ", " however ", " and then ", " although ")),
        "neutral-filler": lambda r: ("neutral" in r["id"] or "traps" in r["id"]),
    }
    print("\n--- slices (cases / false-pos / false-neg across all categories) ---")
    print(f"{'slice':<16}{'cases':>7}{'fp':>6}{'fn':>6}")
    print("-" * 35)
    for name, pred in SLICES.items():
        sel = [r for r in rows if pred(r)]
        fp = fn = 0
        for r in sel:
            for c in SCALAR:
                _, x, y = scalar_counts(norm(r["expected"].get(c)), norm(r["actual"].get(c)))
                fp += x; fn += y
            for c in SETS:
                _, x, y = set_counts(r["expected"].get(c) or [], r["actual"].get(c) or [])
                fp += x; fn += y
        print(f"{name:<16}{len(sel):>7}{fp:>6}{fn:>6}")

    # Error buckets — which failure mode dominates (targets for 011/012).
    print("\n--- error buckets ---")
    for bucket, cnt in sorted(bucket_tally.items(), key=lambda kv: -kv[1]):
        print(f"  {bucket:<26} {cnt}")

    # Full categorized error table -> CSV, plus a console preview.
    out_csv = os.path.join(os.path.dirname(path), "errors.csv")
    with open(out_csv, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["category", "id", "expected", "actual", "bucket", "transcript"])
        for cat, cid, e, a, tx, bucket in errors:
            w.writerow([cat, cid, e, a, bucket, tx])
    print(f"\n=== ERRORS ({len(errors)}) — full table in {out_csv} ===\n")
    for cat, cid, e, a, tx, bucket in errors:
        snippet = tx if len(tx) <= 80 else tx[:77] + "..."
        print(f"[{cat:<10}|{bucket:<24}] {cid:<22} exp={e!s:<18} act={a!s:<18}")
        print(f"             “{snippet}”")

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "out/extractions.json")
