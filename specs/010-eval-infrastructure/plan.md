# Implementation Plan: Extractor Eval Infrastructure (010)

**Spec**: [spec.md](spec.md) · **Branch**: `spike-nlp-performance` (spike; not for direct merge)

> Lean plan for the overnight autonomous run. Formal `/speckit-tasks` can be re-run later; tasks are listed inline below.

## Constitution Check

- **VII (Deterministic, Measured Extraction)**: this IS the eval harness the principle mandates. No extractor code touched (SC-005). ✅
- **X (Test-First)**: ordinal-metric logic (QWK/MAE/1-off) and bucket assignment are testable logic → unit-tested. Python metric tests via a tiny self-check; Swift metric additions (if any) via Swift Testing. ✅
- **VI (Privacy)**: addrec corpus is public forum text, dev-only, not bundled (FR-013). ✅
- **III/IV (Correctness/Minimal)**: extend existing `spikes/extractor-eval/` tooling; no new abstractions. ✅

## Design

Two tracks, two harnesses, both macOS-standalone (swiftc + Python), compiling the **live** extractor sources.

**Track A — Detection-recall (PRIMARY), addrec corpus**
- `detect.swift` (generalize `detect500.swift`): read JSON-array OR JSONL; dedup by `id`; per record emit gold-present {mood,energy,focus} vs extractor-detected (non-nil), wordCount, snippet.
- `analyze_detect.py`: per-category + micro/macro recall, recall by length bucket, categorized example misses; precision flagged unreliable.
- Corpus: `addrec_1082_summaries.jsonl` (1082 → 1037 deduped).

**Track B — Ordinal value metrics (SECONDARY), 40-case set**
- `main.swift` already dumps per-case expected/actual values → `analyze.py`.
- Add to `analyze.py`: **QWK, MAE, 1-off** per ordinal category (mood/energy/focus), computed over cases where both expected & predicted are non-nil; nil-rate reported separately. Adjacent miss (3→4) must score better than polar (5→1).
- Add **error buckets** (negation miss / paraphrase / polysemy FP / clause-boundary / lexicon gap / trap / uncategorized) via deterministic heuristics.
- Add **slices**: negation-only, paraphrase-only, multi-clause, neutral-filler — derived from transcript content + id hints.

**Separation guard (FR-006)**: ordinal/value metrics run ONLY on Track B; addrec powers ONLY Track A. No combined number.

## Tasks (test-first)

1. **[test]** Python self-check: QWK/MAE/1-off on known fixtures (off-by-1 beats off-by-4). RED.
2. Implement QWK/MAE/1-off in `analyze.py`; GREEN.
3. **[test]** Bucket-assignment fixtures (each bucket hit by a crafted case). RED.
4. Implement bucket heuristics + slices in `analyze.py`; GREEN.
5. Generalize `detect.swift` → JSONL + dedup-by-id; run over 1082.
6. `analyze_detect.py`: micro/macro recall + length buckets + categorized misses.
7. `run_detect.sh` / `run.sh` updated; one-command per track.
8. Verify: both tracks run clean; baseline numbers captured to `out/`.

## Verification

Standalone harness (Q1 decision: harness-verify, app-suite deferred). Baseline detection-recall + 40-case ordinal numbers captured as the reference the 011/012 changes are measured against.
