#!/usr/bin/env python3
"""
Cross-config comparison with a fixed dev/test split.

Iterating prompts on all 100 entries and picking the best is selection on the
test set. To keep it honest, this splits entries deterministically by id: config
selection happens on dev, final numbers are reported on the held-out test split.
Metrics are read from the raw_quality column (true model output) and stratified
by fallback, matching eval.py's aggregate.

Usage: python analyze_configs.py results/multi-*.md results/rematch-*.md
"""
import re
import sys
from pathlib import Path

ROW = re.compile(
    r"coverage=([\d.]+)\s+halluc=([\d.]+)\s+compress=([\d.]+)x\s+"
    r"med=(\d+)/(\d+)\s+sleep=(True|False)\s+fx=(\d+)/(\d+)\s+arc=(True|False)"
)


def is_test(cid: str) -> bool:
    n = int(cid[1:])
    return (n % 10) in (0, 1, 2)  # ~30 held-out, deterministic


def parse(path: Path):
    rows = []
    for line in path.read_text().splitlines():
        if not line.startswith("| g"):
            continue
        cid = line.split(" | ")[0].lstrip("| ").strip()
        rs = re.search(r"\|\s*([a-z_]+)\s*\|\s*coverage=", line)
        reason = rs.group(1) if rs else "none"
        m = ROW.search(line)  # first match = raw_quality column
        if not m:
            continue
        rows.append((cid, reason, m))
    return rows


def agg(rows):
    n = len(rows)
    if not n:
        return None
    clean = [r for r in rows if r[1] == "none"]
    nc = len(clean)

    def cv(i):
        return sum(float(r[2].group(i)) for r in clean) / nc if nc else 0.0

    medh = sum(int(r[2].group(4)) for r in clean)
    medt = sum(int(r[2].group(5)) for r in clean)
    return dict(n=n, fb=(n - nc) / n, nc=nc, cov=cv(1), hal=cv(2),
                comp=cv(3), med=medh / medt if medt else 1.0)


def main():
    print("| config | split | n | fb% | cov | hal | comp | med |")
    print("|---|---|---|---|---|---|---|---|")
    for f in sys.argv[1:]:
        rows = parse(Path(f))
        for label, subset in (("dev", [r for r in rows if not is_test(r[0])]),
                              ("test", [r for r in rows if is_test(r[0])])):
            a = agg(subset)
            if a:
                print(f"| {Path(f).stem} | {label} | {a['n']} | {a['fb']:.0%} | "
                      f"{a['cov']:.2f} | {a['hal']:.2f} | {a['comp']:.1f}x | {a['med']:.2f} |")


if __name__ == "__main__":
    main()
