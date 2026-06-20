#!/usr/bin/env python3
"""
Objective gold-anchored concrete-signal recall — the completeness metric (omission = 1 - recall).
Scores a model's summaries (the raw-output column of an eval.py results .md) against the
human-adjudicated gold-signals.json. Concrete signals only: med name/dose/time, sleep hours,
side-effects. mood/energy/focus are subjective → judged separately, not auto-scored here.

Usage:
    python gold_recall.py --md results/eval-XXXX.md --gold gold-signals.json
"""
import argparse
import json
import re

NUM = {1: "one", 2: "two", 3: "three", 4: "four", 5: "five", 6: "six",
       7: "seven", 8: "eight", 9: "nine", 10: "ten", 11: "eleven", 12: "twelve"}


def sleep_forms(h):
    forms = {str(h)}
    if float(h).is_integer():
        i = int(h)
        forms.add(str(i))
        if i in NUM:
            forms.add(NUM[i])
    else:
        i = int(h)
        forms.add(f"{i} and a half")
        if i in NUM:
            forms.add(f"{NUM[i]} and a half")
    return forms


def canon(s):
    return re.sub(r"\s+", "", s.lower())


def out_rows(md):
    d = {}
    for line in open(md):
        if line.startswith("| g"):
            f = line.split(" | ")
            d[f[0].lstrip("| ").strip()] = f[3].replace("<br>", " ").lower()
    return d


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--md", required=True, help="eval.py results markdown (raw-output column)")
    ap.add_argument("--gold", default="gold-signals.json")
    a = ap.parse_args()
    gold = {e["id"]: e for e in json.load(open(a.gold))}
    outs = out_rows(a.md)

    hit = tot = 0
    misses = []
    for cid, g in gold.items():
        o = outs.get(cid, "")
        sigs = []
        for m in g["meds"]:
            if m["name"] and m["name"] not in ("medication", "meds", "dose"):
                sigs.append(("med:" + m["name"], m["name"] in o))
            if m["dose"]:
                sigs.append(("dose:" + m["dose"], canon(m["dose"]) in canon(o)))
            if m["time"]:
                sigs.append(("time:" + m["time"], m["time"].split(":")[0] in o))
        if g["sleep_hours"] is not None:
            sigs.append(("sleep", any(s in o for s in sleep_forms(g["sleep_hours"]))))
        for se in g["side_effects"]:
            sigs.append(("fx:" + se, se.split()[0] in o))
        for lbl, m in sigs:
            tot += 1
            if m:
                hit += 1
            else:
                misses.append(f"{cid} {lbl}")

    if not tot:
        print("no concrete signals in gold")
        return
    print(f"concrete-signal recall: {hit}/{tot} = {hit/tot:.0%}  (omission {1-hit/tot:.0%})")
    print(f"misses ({len(misses)}): " + ", ".join(misses[:25]) + (" ..." if len(misses) > 25 else ""))


if __name__ == "__main__":
    main()
