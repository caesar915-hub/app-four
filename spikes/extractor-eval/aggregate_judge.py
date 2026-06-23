#!/usr/bin/env python3
"""Aggregate the LLM-judge verdicts into stats + a markdown verdict table."""
import json, collections, sys, os

OUT = sys.argv[1] if len(sys.argv) > 1 else \
    '/private/tmp/claude-501/-Users-caesargrey-Projects-app-four/2bd59a0d-87c6-4703-ad54-6ccdad6e961d/tasks/wc3mesdcy.output'

v = json.loads(open(OUT).read())['result']['verdicts']
json.dump(v, open('spikes/extractor-eval/out/judge_verdicts.json', 'w'), ensure_ascii=False, indent=1)

SIG = ['mood', 'energy', 'focus', 'meds']
print('verdicts:', len(v))
rows = []
for s in SIG:
    c = collections.Counter(x.get(s, 'na') for x in v)
    scored = sum(c[k] for k in ('correct', 'partial', 'missed', 'false_positive'))
    acc = c['correct'] / scored if scored else 0.0
    soft = (c['correct'] + c['partial']) / scored if scored else 0.0
    rows.append((s, c['correct'], c['partial'], c['missed'], c['false_positive'], c['na'], scored, acc, soft))
    print(f"{s:8} correct={c['correct']:3} partial={c['partial']:3} missed={c['missed']:3} "
          f"fp={c['false_positive']:3} na={c['na']:3} | scored={scored:3} "
          f"strict={acc:.2f} soft={soft:.2f}")

ov = collections.Counter(x.get('overall', '?') for x in v)
print('overall:', dict(ov), '| good+ok rate = %.2f' % ((ov['good'] + ov['ok']) / len(v)))

# Save a compact markdown table of the per-signal stats for the doc.
with open('spikes/extractor-eval/out/judge_stats.md', 'w') as f:
    f.write('| signal | correct | partial | missed | false_pos | n/a | strict acc | soft (+partial) |\n')
    f.write('|---|---|---|---|---|---|---|---|\n')
    for s, cor, par, mis, fp, na, sc, acc, soft in rows:
        f.write(f'| {s} | {cor} | {par} | {mis} | {fp} | {na} | {acc:.2f} | {soft:.2f} |\n')
    f.write(f'\nOverall: good {ov["good"]}, ok {ov["ok"]}, poor {ov["poor"]} '
            f'(good+ok = {(ov["good"]+ov["ok"])/len(v)*100:.0f}%)\n')

# Dump worst examples (poor + false_positive heavy) for the doc.
poor = [x for x in v if x.get('overall') == 'poor']
print('\npoor-rated:', len(poor))
for x in poor[:8]:
    print(' -', x['id'][:8], x.get('note', '')[:130])
