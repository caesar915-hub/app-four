#!/usr/bin/env python3
"""Detection-recall analysis for the 500 addrec records (mood/energy/focus presence).

Recall is the headline (does the extractor catch a signal the gold says is there —
the paraphrase-blindness question). Precision is shown but flagged: these are coarse,
possibly auto-generated presence labels, so a missing label != signal truly absent.
Stdlib only.
"""
import sys, json
from collections import defaultdict

CATS = ["mood", "energy", "focus"]

def pr(tp, fp, fn):
    p = 1.0 if tp + fp == 0 else tp / (tp + fp)
    r = 1.0 if tp + fn == 0 else tp / (tp + fn)
    return p, r

def main(path):
    rows = json.load(open(path))
    n = len(rows)
    counts = {c: [0, 0, 0] for c in CATS}   # tp, fp, fn
    buckets = defaultdict(lambda: [0, 0])    # word-bucket -> [gold_present, detected_of_those]
    misses = defaultdict(list)               # cat -> example FN snippets

    for r in rows:
        g, p = set(r["gold"]), set(r["detected"])
        wc = r.get("wordCount", 0)
        b = "0-100" if wc < 100 else "100-200" if wc < 200 else "200-300" if wc < 300 else "300+"
        for c in CATS:
            if c in g and c in p: counts[c][0] += 1
            elif c in p and c not in g: counts[c][1] += 1
            elif c in g and c not in p:
                counts[c][2] += 1
                if len(misses[c]) < 4: misses[c].append((r["id"][:8], r.get("snippet", "")))
            if c in g:
                buckets[b][0] += 1
                if c in p: buckets[b][1] += 1

    print(f"\n=== DETECTION on {n} records (gold = presence labels) ===\n")
    print(f"{'category':<10}{'support':>8}{'recall':>8}{'prec*':>8}{'F1':>8}   {'tp':>4}{'fp':>5}{'fn':>4}")
    print("-" * 56)
    tp_t = fp_t = fn_t = 0
    for c in CATS:
        tp, fp, fn = counts[c]
        tp_t += tp; fp_t += fp; fn_t += fn
        p, r = pr(tp, fp, fn)
        f1 = 0.0 if p + r == 0 else 2 * p * r / (p + r)
        support = tp + fn
        print(f"{c:<10}{support:>8}{r:>8.2f}{p:>8.2f}{f1:>8.2f}   {tp:>4}{fp:>5}{fn:>4}")
    P, R = pr(tp_t, fp_t, fn_t)
    print("-" * 56)
    print(f"{'micro':<10}{tp_t+fn_t:>8}{R:>8.2f}{P:>8.2f}{0.0 if P+R==0 else 2*P*R/(P+R):>8.2f}   {tp_t:>4}{fp_t:>5}{fn_t:>4}")
    print("\n* precision is unreliable here: coarse presence labels — a missing label")
    print("  does NOT mean the signal is truly absent. Recall is the trustworthy number.")

    print("\n--- detection recall by text length (does longer text help?) ---")
    print(f"{'words':<10}{'gold':>7}{'caught':>8}{'recall':>8}")
    for b in ["0-100", "100-200", "200-300", "300+"]:
        gp, dt = buckets[b]
        rec = (dt / gp) if gp else 0.0
        print(f"{b:<10}{gp:>7}{dt:>8}{rec:>8.2f}")

    print("\n--- example misses (gold present, extractor detected nothing for that cat) ---")
    for c in CATS:
        for cid, snip in misses[c]:
            print(f"[{c:<6}] {cid}  “{snip}”")

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "out/detect500.json")
