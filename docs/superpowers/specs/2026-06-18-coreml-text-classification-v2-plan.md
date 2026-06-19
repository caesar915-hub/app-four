# Core ML Text Classification v2 — From-Scratch Plan

**Date:** 2026-06-18 · **Status:** planned · **Branch (work):** `spike/ml-signal-extractor-DO-NOT-MERGE` (v1, failed) → new branch for v2
**Goal:** mood/energy/focus classifiers that **beat the lexicon floors** (mood 0.73/0.58, energy 0.65/0.23, focus 0.38/0.31) on a *held-out* test set AND the 40-case EvalSet.

## Why v1 failed (measured, not guessed)

ML-path EvalSet: **mood P=0.27, energy P=0.00, focus P=0.04** — far below the lexicon. Three root mistakes, each confirmed against Apple docs / the literature:

1. **No held-out test set.** Apple's method is 80/20 train/test + auto-validation, then `evaluation(on:)` on unseen data. We had only auto-validation and "tested" on probes we'd trained on → the 100% and probe wins were invalid. ([Apple: Creating a Text Classifier Model](https://sosumi.ai/documentation/createml/creating-a-text-classifier-model))
2. **Synthetic data for an open-set problem.** This is open-set / out-of-domain classification; it requires *real, abundant negatives*. Synthetic single-dimension sentences can't teach abstention. ([Open-Set survey arXiv 2502.12965](https://arxiv.org/html/2502.12965v3), [Novelty Detection arXiv 2009.11119](https://arxiv.org/pdf/2009.11119))
3. **Max-aggregation across sentences** surfaces the single worst false positive in a long note. Literature uses noisy-or / logsumexp / averaging. ([arXiv 1901.00400](https://arxiv.org/pdf/1901.00400))

Embedding confirmed: **BERT is Apple's recommendation** (context handles negation/modality) but needs downloadable assets (`hasAvailableAssets`/`requestAssets`) — the simulator failure. ([WWDC23 10042](https://sosumi.ai/videos/play/wwdc2023/10042))

## Phase 0 — Architecture decisions (locked)

| Decision | Choice | Rationale |
|---|---|---|
| Embedding | BERT (contextual) | Apple rec; context for negation/modality; accept asset dep |
| Assets | `requestAssets()` at onboarding; gate on `hasAvailableAssets` | one-time first-run download; never blocks lexicon |
| Test host | Device or My Mac, never Simulator | Simulator lacks the asset |
| Granularity | start 3 levels (low/mid/high), expand to 5 only if confusion matrix supports | present/sharp/lockedIn overlap sank focus |
| `none` strategy | two-stage: binary "about X?" gate → level classifier on positives | attacks cross-domain FP; separates outlier-detection from classification |
| Aggregation | tense-gated + noisy-or (not max) | robust to a single FP in long notes |
| Models | 3 separate (per signal), shared abundant cross-domain negatives | matches lexicon composition |

## Phase 1 — Real data (the lever) · user has "months of entries"

1. **Export** real transcripts from SwiftData (`Recording.transcriptText` + `createdAt`) → JSON. Debug-only export feature, run on device, retrieve file.
2. **Sentence-split + hand-label** each sentence: level **or** `none`. Few hundred real labeled sentences/signal, `none` the plurality. Pre-fill with current lexicon extraction to speed labeling, but human corrects (never trust lexicon labels — that teaches its bug).
3. Augment with synthetic **only** for rare classes (e.g. "charged").
4. **Time-based split:** earlier months = train, latest month = held-out test → no paraphrase leakage.

## Phase 2 — Training (reproducible CLI)

5. `train.swift`: BERT embedding, explicit 80/20 train/test, print `trainingMetrics` + `validationMetrics` + **`evaluation(on:)` on held-out test**.
6. Two-stage per signal (gate + level).
7. Per-class confusion matrix in output.

## Phase 3 — Validation (the gate)

8. Held-out test `evaluation(on:)` — the Apple-correct number.
9. 40-case EvalSet via `eval_ml.swift` (built) on device/Mac — independent integration test.
10. **Ship gate:** beat lexicon floors on BOTH held-out test AND EvalSet, or it does not ship. Non-negotiable.

## Phase 4 — Integration (only if Phase 3 passes)

11. Rewrite `NLModelExtractor`: tense-gate + noisy-or, two-stage gate→level, tau calibrated from the test set.
12. Re-run EvalSet via `reportML` on device/Mac.
13. Wire into `NLSummarizationService` behind a flag; keep lexicon fallback.

## Honest risk

Multi-week, gated on labeling. **May still not beat the lexicon** (0.73/0.65/0.38 is a high bar for single-user ML). Phase 3 is the cheap, honest go/no-go — that's the point.

## Reusable assets from v1

`spikes/createml-nlmodel/`: `rebuild_corpus.py`, `train.swift`, `predict.swift`, `eval_ml.swift` (macOS ML-path eval), `verify.swift`. `ExtractionEvalTests.runEvalML()/reportML()`. The failed v1 models + `NLModelExtractor` stay on the spike branch as reference.
