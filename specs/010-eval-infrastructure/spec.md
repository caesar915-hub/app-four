# Feature Specification: Extractor Eval Infrastructure

**Feature Branch**: `010-eval-infrastructure`

**Created**: 2026-06-23

**Status**: Draft

**Input**: User description: "Eval infrastructure for the NLNoteExtractor performance review — the measurement foundation that must land BEFORE any extraction-logic change, so every later fix is provable. Two tracks: (1) detection-recall over the full addrec dataset (presence labels), (2) distance-aware ordinal metrics + categorized errors + slices on the 40-case value set. Changes no extractor code."

## Overview

This feature builds the **measurement foundation** for improving the `NLNoteExtractor`. It is deliberately sequenced FIRST: the three planned extractor-improvement specs (logic correctness, lexicon hygiene) cannot be honestly evaluated until the rulers exist. The "user" here is the developer measuring extraction quality; the value is *provable* change.

It establishes two non-conflatable measurement tracks:

- **Detection-recall (PRIMARY)** — over a large presence-labeled corpus (addrec, ~1037 deduped records). Answers "does the extractor *fire* on a category the gold marks present?" This is the coverage proxy that makes lexicon-improvement gains visible (energy detection recall is currently ~0.31).
- **Ordinal value metrics (SECONDARY)** — over the existing 40-case value-labeled set. Answers "when the extractor fires, is the *level* right, and how far off?" Distinguishes an adjacent miss (3→4) from a polar miss (5→1), which nominal precision/recall hides.

This spec changes **no extractor code**. It only builds measurement.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Detection-recall at scale (Priority: P1)

The developer runs a single command and sees per-category mood/energy/focus **detection recall** over the full deduped addrec corpus, so a lexicon-coverage change (e.g., adding energy paraphrases) shows up as a measurable recall movement instead of a guess.

**Why this priority**: This is the primary ruler. The biggest known weakness (energy detection recall ~0.31) and every lexicon/coverage improvement in the downstream specs is measured here. Without it, "did the fix help?" stays unanswerable at scale.

**Independent Test**: Run the detection harness over the addrec corpus; confirm it reports per-category recall, micro/macro recall, recall by text-length bucket, and a list of categorized example misses — on ≥1000 deduped records, with no extractor source modified.

**Acceptance Scenarios**:

1. **Given** the full addrec corpus with duplicate IDs, **When** the detection harness runs, **Then** records are deduplicated by `id` before scoring and the run reports the deduped count.
2. **Given** a record whose gold `signals` marks "energy" present, **When** the extractor returns a non-nil energy value, **Then** it is counted as a detection true-positive for energy; when the extractor returns nil, it is a false-negative (a miss).
3. **Given** the full corpus, **When** analysis completes, **Then** per-category recall, micro+macro recall, recall bucketed by text length, and example misses per category are reported, and precision is shown with an explicit "unreliable — presence-only labels" caveat.

---

### User Story 2 - Distance-aware ordinal metrics (Priority: P2)

The developer sees Quadratic Weighted Kappa, Mean Absolute Error, and 1-off accuracy for mood/energy/focus on the 40-case value set, so a wrong-but-adjacent prediction is scored more kindly than a polar one — surfacing severity that nominal precision/recall flattens.

**Why this priority**: The downstream logic-correctness fixes (negation flip, temporal weighting) change *values*, not just detection. Nominal P/R treats every wrong value identically; ordinal metrics are the only view that can register "less wrong."

**Independent Test**: Run the value harness over the 40-case set; confirm QWK, MAE, and 1-off accuracy are reported per ordinal category, and that an injected adjacent miss scores strictly better than an injected polar miss on the same category.

**Acceptance Scenarios**:

1. **Given** a category's predicted and expected ordinal values across the 40 cases, **When** metrics compute, **Then** QWK, MAE, and 1-off accuracy are reported per category (mood, energy, focus).
2. **Given** two hypothetical prediction sets identical except one case is off by 1 level and the other off by 4 levels, **When** QWK/MAE compute, **Then** the off-by-1 set scores strictly better.
3. **Given** the addrec presence-only corpus, **When** the developer requests ordinal metrics, **Then** the system refuses/omits them for that corpus — ordinal value metrics run ONLY on value-labeled data.

---

### User Story 3 - Categorized errors and metric slices (Priority: P3)

The developer gets every 40-case error bucketed by failure type (negation miss, paraphrase miss, polysemy false positive, clause-boundary error, lexicon gap, trap word) and metric slices (negation-only, paraphrase-only, multi-clause, neutral-filler precision), so each downstream fix targets a named bucket and its effect is visible on the relevant slice.

**Why this priority**: Turns "the number moved" into "the negation bucket shrank." Enables the fix→re-run→diff workflow per failure mode. Valuable but dependent on US1/US2 existing first.

**Independent Test**: Run the value harness; confirm each error case is assigned exactly one failure bucket and that per-slice metrics (negation-only, paraphrase-only, multi-clause, neutral-filler) are reported separately from the aggregate.

**Acceptance Scenarios**:

1. **Given** the 40-case errors, **When** categorization runs, **Then** each error is assigned exactly one bucket from the fixed set, and any uncategorized error is reported explicitly (not silently dropped).
2. **Given** the eval cases tagged by phenomenon, **When** slice metrics compute, **Then** negation-only, paraphrase-only, multi-clause, and neutral-filler (precision) slices are reported independently.

### Edge Cases

- A record with an empty `signals` list or empty/whitespace text → excluded from recall denominators, counted in a skipped tally.
- A record flagged truncated (`flagged_truncated`) → included by default but counted/visible as a slice (truncation may depress recall).
- A 40-case prediction that is nil where a value was expected → counted as a detection miss AND excluded from QWK/MAE (which require a predicted class), with the nil-rate reported separately so the two views don't double-distort.
- The existing `EvalFloors` ratchet → unchanged in role; it remains a pass/fail regression guard and is NOT repurposed as proof of small gains.
- Duplicate IDs across addrec → deduped before scoring; the dropped-duplicate count is reported.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The detection harness MUST ingest the full addrec corpus and deduplicate records by `id` before scoring, reporting both raw and deduped counts.
- **FR-002**: For each tracked category (mood, energy, focus), the system MUST compute detection recall as: gold marks the category present AND the extractor produces a non-nil value for it.
- **FR-003**: The detection report MUST include per-category recall, micro and macro recall, recall bucketed by text length, and a sample of categorized example misses per category.
- **FR-004**: The detection report MUST present precision with an explicit "unreliable — presence-only, possibly auto-generated labels" caveat; recall is the trustworthy figure.
- **FR-005**: The value harness MUST compute distance-aware ordinal metrics — Quadratic Weighted Kappa, Mean Absolute Error, and 1-off accuracy — per ordinal category (mood, energy, focus) on the 40-case value set.
- **FR-006**: The system MUST keep the two tracks separate: ordinal/value metrics MUST run ONLY on value-labeled data; the presence-only addrec corpus MUST power detection-recall ONLY. The two MUST NOT be conflated in any combined number.
- **FR-007**: The value harness MUST emit a per-case error dump that assigns each error exactly one failure bucket from a fixed set {negation miss, paraphrase miss, polysemy false positive, clause-boundary error, lexicon gap, trap word, uncategorized}.
- **FR-008**: The value harness MUST report metric slices independently: negation-only, paraphrase-only, multi-clause, and neutral-filler (precision) cases.
- **FR-009**: The existing precision/recall floor ratchet MUST remain a regression guard with its current role unchanged; this feature MUST NOT repurpose it as evidence of improvement.
- **FR-010**: Both harnesses MUST run standalone on the development host (no simulator, no device), compiling the live extractor sources so results never drift from the app.
- **FR-011**: This feature MUST NOT modify any extractor source file; its diff MUST be confined to evaluation tooling and test/data assets.
- **FR-012**: The ordinal metric computations (QWK, MAE, 1-off) MUST be developed test-first with unit tests that pin known inputs to known outputs (Principle X).
- **FR-013**: The addrec evaluation corpus MUST NOT be bundled into the shipping app target; it is development-only data.
- **FR-014**: A single documented entry point MUST run each track end-to-end (build → extract → analyze → report) and be re-runnable for the fix→re-run→diff workflow.

### Key Entities *(include if feature involves data)*

- **Addrec record**: A presence-labeled corpus row — `id`, presence `signals` (subset of {mood, energy, focus}), text, length. Gold is presence only, no values.
- **Eval case (value gold)**: A 40-case hand-curated row with ordinal VALUES for mood/energy/focus plus set-valued categories. The only value-level ground truth.
- **Detection result**: Per record, the gold-present categories vs. the categories the extractor fired on, plus length bucket and (for misses) an example snippet.
- **Ordinal metric**: Per category, QWK / MAE / 1-off accuracy computed from paired (expected, predicted) ordinal values.
- **Error bucket**: A categorized failure on a value case, drawn from the fixed bucket set.
- **Metric slice**: A named subset of cases (negation-only, paraphrase-only, multi-clause, neutral-filler) with its own metrics.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A single command produces detection recall for mood/energy/focus over the full deduped addrec corpus (≥1000 records) and completes in under 60 seconds on the development host.
- **SC-002**: The ordinal metrics demonstrably distinguish severity — given two prediction sets differing only by one case off-by-1 versus off-by-4 on the same category, the off-by-1 set scores strictly higher QWK and lower MAE.
- **SC-003**: Every error on the 40-case value set is assigned exactly one failure bucket; the share left "uncategorized" is reported and is the only acceptable residual (no error silently dropped).
- **SC-004**: No reported number combines presence-only and value-labeled data; value metrics appear only for the 40-case set, detection recall only for addrec.
- **SC-005**: Running either track changes zero extractor source files — the produced diff touches only evaluation tooling, tests, and development-only data.
- **SC-006**: A controlled lexicon-coverage change of known size (e.g., adding K energy paraphrase entries that match J corpus records) moves the energy detection-recall figure in the expected direction by a visible amount, confirming the ruler is sensitive enough to guide the downstream specs.

## Assumptions

- The addrec `signals` field is treated as gold for **presence** only. Its provenance is likely auto-generated and coarse; therefore detection precision is reported but explicitly flagged unreliable, and recall is the headline. (Acknowledged risk, accepted by the team in lieu of hand-labeling a larger value set.)
- The 40-case `EvalSet` remains the sole value-level ground truth; growing it is explicitly out of scope for this feature (team chose the addrec detection-recall proxy instead).
- The development host's `NaturalLanguage` lemma model is present (as on a physical device, unlike the iOS simulator), so the standalone macOS harness is a faithful proxy for on-device extraction behavior.
- "Detection" is defined as the extractor producing a non-nil value for a category — independent of whether that value is correct.
- Error-bucket assignment uses deterministic heuristics over the case (e.g., a negation token adjacent to the missed cue → negation miss; the gold cue absent from the lexicon → lexicon gap), with "uncategorized" as the explicit fallback. Heuristic categorization is acceptable; perfect attribution is not required.
- Ordinal metrics exclude nil predictions from QWK/MAE (they require a predicted class) and report the nil-rate separately, so detection-miss and value-error views stay distinct.

## Dependencies

- The existing `spikes/extractor-eval/` tooling (detection harness `detect500.swift`, `analyze_detect.py`, `run_detect.sh`; value harness `main.swift`/`analyze.py`) is extended, not rebuilt from scratch.
- The existing 40-case value harness — `EvalSet`, `EvalMetrics`, `ExtractionEvalTests`, `EvalFloors` — is the value-track foundation.
- The `addrec_1082_summaries.jsonl` corpus (and the copy under `spikes/extractor-eval/data/`).
- The live extractor sources under `app-four/Services/NoteExtraction/` (compiled, never copied).

## Constitution Alignment *(informative)*

- **Principle VII (Deterministic, Measured Extraction)**: This feature builds the eval harness that Principle VII requires every extraction change to run against; it strengthens, and does not alter, the non-regression floor obligation.
- **Principle X (Test-First, NON-NEGOTIABLE)**: The metric logic (QWK/MAE/1-off, error-bucket assignment) is testable logic and MUST be built test-first (FR-012).
- **Principle VI (On-Device Privacy)**: The addrec corpus is public forum text used only as a dev-time benchmark; it is not user data and MUST NOT ship in the app (FR-013).
- **Principles III/IV (Correctness / Minimal Surface)**: The harness extends existing tooling; no new abstractions beyond the two tracks and their reports.
