# NLP Extractor Improvement — Overnight Run STATUS / Resume Guide

**Branch**: `spike-nlp-performance` · **Updated**: 2026-06-23 (mid-run, pre-compact)

> Resume point. If the run stops, re-read this + `git log` + todos and continue from NEXT.
> The agent does not auto-resume; re-engage it on THIS Mac (extractor needs Apple
> NaturalLanguage — cloud/Linux cannot run it). Everything is committed in checkpoints.

## Locked decisions
- Themed specs 010→011→012, depth-first; eval-first; detection-recall proxy on addrec; 40-case = value gold.
- Verify via standalone swiftc harness (Xcode app suite deferred to morning). NO merge to main / no PRs.

## Progress
- [x] Specs 010/011/012 written + committed (`3f7aa3e`).
- [x] 010 eval-infra: Track B ordinal QWK/MAE/1-off + buckets + slices (`cfd9b97`), Track A detection JSONL+dedup over 1082 (`c705d07`).
- [x] 011 batch 1 (`c204bc5`): temporal weighting energy/focus (#1), middle-tier negation flip (#2), sleep worded-numbers (#24, sleepHours R 0.29→0.57). + coupled lexicon fix "couldn't focus"→distracted. No floor regression.
- [x] 012 energy coverage (`6c21509`): added exhausted/no energy/full of energy/etc. Energy detection recall 0.35→0.39 (addrec-1037); 40-case energy R 0.25→0.50, P 0.67→0.80.
- [x] **LLM-judge DONE** (`wc3mesdcy`): 467 verdicts over 468 posts. Results → `NLP_EVALUATION_RESULTS.md`, raw verdicts → `results/judge_verdicts.json`, stats → `results/judge_stats.md`.

## RESULT — the headline finding
On real ADHD forum text the extractor's dominant error is **FALSE POSITIVES**, not misses:
mood fp=123 (vs missed 55), focus fp=113 (vs 19) — asserting affect that belongs to *someone else*,
is quoted/hypothetical, or vents about externals. Meds stay strong (0.82). **BUT** this is Reddit
register (advice/3rd-person), not the app's first-person check-ins — a worst-case stress test. On the
40 on-register cases the extractor is decent (meds 1.0, feelings 0.94, mood P0.75, energy P0.80).
**Takeaway: the #1 next lever is the deferred experiencer/quote/clause gating (011 #3/#23 + experiencer),
not more lexicon coverage.** Full writeup + tables: `NLP_EVALUATION_RESULTS.md`.

## RUN COMPLETE — overnight goals met
Specs (3) + eval-infra (2 tracks) + 011 batch 1 + 012 energy coverage shipped & measured; 500-record
extraction + LLM-judge + evaluation document delivered. All committed on `spike-nlp-performance`.
No merge to main (awaiting owner review).

## Quantitative baseline → improved (for the doc)
| metric | baseline | improved |
|---|---|---|
| 40-case energy P/R | 0.67 / 0.25 | 0.80 / 0.50 |
| 40-case sleepHours R | 0.29 | 0.57 |
| addrec-1037 energy detection recall | 0.35 | 0.39 |
| addrec-1037 focus detection recall | 0.79 | 0.80 |
| addrec-1037 micro recall | 0.64 | 0.65 |
| meds (unchanged) | 1.0 / 1.0 | 1.0 / 1.0 |
Ordinal (improved, 40-case): mood QWK 0.97, energy QWK 1.00, focus QWK 0.40 — failure is detection/coverage not level.

## DEFERRED to next session (specced, not built)
- 011: negation token-anchoring (#23, Principle VII substring), clause-scoped negation (#3), clause scoping for mood/energy/focus (#4), tense hardening (#5), extract aggregation policy (#14).
- 012: activity blocklists (precision 0.30), JSON/Swift lexicon de-dup (#6), sim/device determinism (#10), canonicalInflections expansion (#9), overlay de-dup (#13), lemma policy (#12), highlight weights (#16).

## Commands
- `sh spikes/extractor-eval/run.sh` (40-case value) · `sh spikes/extractor-eval/run_detect.sh` (detection 1082) · `python3 spikes/extractor-eval/test_evalmetrics.py`
- Full 500 extraction: `spikes/extractor-eval/out/extract_dump …` → `out/extractions_500.json` (468 deduped).
