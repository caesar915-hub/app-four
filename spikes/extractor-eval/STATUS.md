# NLP Extractor Improvement — Overnight Run STATUS / Resume Guide

**Branch**: `spike-nlp-performance` · **Started**: 2026-06-23 · **Owner directive**: improve the
rule-based `NLNoteExtractor` (no new features), measure it, judge it, have it ready by morning.

> **This is the resume point.** If the run stops (credits/session), re-read this file + `git log`
> + the todo list, then continue from "NEXT" below. Everything is committed in checkpoints — nothing
> is lost on a hard stop. The agent does NOT auto-resume; you re-engage it and it picks up here.

## Locked decisions (from owner Q&A)
- **Themed specs** 010 (eval-infra) → 011 (logic) → 012 (lexicon), **depth-first, in order**.
- **Eval-first**: 010 builds the rulers before any extractor change.
- **Detection-recall proxy** on addrec data (presence-only labels); 40-case set = value gold.
- **Verify via standalone swiftc harness** (app Xcode suite may not run headless); flag app-suite items for morning.
- **No merge to main, no PRs** overnight. Commit checkpoints to `spike-nlp-performance` only.
- `swiftui-pro` was the wrong skill (no SwiftUI here) → use `swift-concurrency-pro` + manual review.

## Pipeline & progress
- [x] Specs 010, 011, 012 written + committed (`3f7aa3e`).
- [x] 010 plan (`specs/010-eval-infrastructure/plan.md`).
- [x] 010 Track B (value): ordinal metrics QWK/MAE/1-off + error buckets + slices — `evalmetrics.py`
      (+ `test_evalmetrics.py`, test-first GREEN), wired into `analyze.py`. Runs via `run.sh`.
- [ ] 010 Track A (detection): generalize `detect500.swift` → JSONL + dedup-by-id; run over
      `addrec_1082_summaries.jsonl` (1037 unique). **← NEXT**
- [ ] 011 logic fixes (temporal energy/focus, negation flip/scope/token-anchor, clause scoping,
      sleep worded-numbers, tense), test-first, measured.
- [ ] 012 lexicon (energy/focus coverage, activity blocklists, JSON/Swift de-dup, determinism), measured.
- [ ] 40-case baseline-vs-improved review.
- [ ] 500-case extraction over original `text`.
- [ ] LLM-judge over 500 → `NLP_EVALUATION_RESULTS.md`.
- [ ] Final commit + this STATUS updated.

## Baseline numbers (pre-improvement, 40-case, captured this run)
- mood P0.75/R0.60, energy P0.67/R0.25, focus P0.40/R0.33, activities P0.30/R0.43, meds 1.0/1.0.
- Ordinal: mood QWK 0.97 (33% nil), energy QWK 1.00 (75% nil), focus QWK 0.40 (50% nil)
  → **failure is detection/coverage, not level**. Buckets: lexicon-gap 35, polysemy-FP 15.
- addrec-500 detection recall (earlier run): mood 0.69, energy **0.31**, focus 0.81.

## How to run
- Value track:     `sh spikes/extractor-eval/run.sh`
- Detection track: `sh spikes/extractor-eval/run_detect.sh`   (currently 500; being generalized to 1082)
- Metric tests:    `python3 spikes/extractor-eval/test_evalmetrics.py`

## Key paths
- Extractor (live, compiled by harness): `app-four/Services/NoteExtraction/*.swift`
- Lexicon data: `app-four/Resources/lexicon.json`
- Value gold: `app-fourTests/Eval/EvalSet.swift` (40 cases)
- Detection data: `spikes/extractor-eval/data/addrec_500_clean.json` (+ 1082 to be copied)
- Research/reports: `spikes/extractor-eval/research/`

## NEXT
1. Copy `addrec_1082_summaries.jsonl` into `data/`; generalize `detect500.swift` (JSONL + dedup); run.
2. Then 011 logic fixes (start with temporal energy/focus — lowest risk, code exists).
