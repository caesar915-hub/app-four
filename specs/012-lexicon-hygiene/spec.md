# Feature Specification: Lexicon & Matching Hygiene

**Feature Branch**: `012-lexicon-hygiene`

**Created**: 2026-06-23

**Status**: Draft

**Input**: User description: "Improve the existing lexicon and matching layer of NLNoteExtractor — coverage rebalance for energy/focus, activity-precision blocklists, single-source lexicon (remove Swift/JSON duplication), sim/device matching determinism, expanded deterministic inflections, overlay de-dup, principled lemma policy, generalized layered defense, highlight weight hygiene. No new categories, no embeddings/ML."

## Overview

This feature improves the *existing* vocabulary-and-matching layer so the rules already in place fire more completely (recall) and more precisely (fewer false positives), and so the lexicon stops being maintained in two places. It adds no new signal categories and no learned representations — it is data hygiene and matching-precision work, gated by the spec-010 eval harness (Principle VII).

The headline target is **energy/focus detection recall** (energy ≈0.31 on the addrec corpus) via coverage rebalance, and **activities precision** (≈0.30 on the 40-case set) via collocational blocklists.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Energy/focus coverage rebalance (Priority: P1)

The energy/focus lexicons are 5–6× skewed to negative states (energySluggish 37 vs energyAlert 7; focusFoggy 39 vs focusPresent 6). Add positive-state and common-paraphrase entries within the existing categories so the extractor stops being structurally blind to good days.

**Why this priority**: Energy detection recall is the single worst measured number; the cause is coverage, and the fix is the lowest-risk lever with the largest measurable upside on the detection-recall ruler.

**Independent Test**: Run the detection-recall harness before/after adding entries; confirm energy (and focus) recall rises with no precision collapse on the 40-case set.

**Acceptance Scenarios**:

1. **Given** the addrec detection harness, **When** positive-state/paraphrase energy entries are added, **Then** energy detection recall increases versus baseline.
2. **Given** the 40-case value set, **When** the entries land, **Then** no precision floor regresses (added coverage does not over-fire).

---

### User Story 2 - Activities precision via blocklists (Priority: P1)

Activity matching over-fires on surface words ("breakfast"→Eating, "meeting"→Work, "gym bag"→Fitness, "running on fumes"→Fitness). Generalize the existing stoplist pattern into collocational blocklists / context gating for the ~20–30 trap words.

**Why this priority**: Activities precision (0.30) is the worst precision number and the most likely to make a user distrust the app. The fix reuses the medication stoplist pattern already proven in the codebase.

**Independent Test**: Run the 40-case set; confirm activity false positives drop (precision rises) without losing true activities (recall held).

**Acceptance Scenarios**:

1. **Given** "my gym bag felt heavy", **When** activity detection runs, **Then** Fitness is not emitted.
2. **Given** the 40-case set, **When** blocklists land, **Then** activities precision rises and activities recall does not regress below floor.

---

### User Story 3 - One lexicon source & device-stable matching (Priority: P2)

The vocabulary lives twice (Swift defaults + `lexicon.json`), kept in sync by hand. Make the JSON the single source. And the verb-lemma bridge behaves differently on simulator (model absent) vs device — make matching deterministic across environments.

**Why this priority**: Removes a real drift/maintenance hazard and a sim/device divergence that undermines CI trust. Structural, not user-visible, so below the coverage/precision wins.

**Independent Test**: Confirm a single source of truth feeds extraction (no duplicated default list), and that lemma-dependent matches resolve identically with and without the lemma model (via the deterministic inflection path).

**Acceptance Scenarios**:

1. **Given** the lexicon loads, **When** the JSON is the source, **Then** there is no second hand-maintained vocabulary copy that can drift.
2. **Given** an inflected feeling/state word, **When** the lemma model is unavailable, **Then** the deterministic inflection table still resolves it (no sim/device divergence for covered forms).

---

### User Story 4 - Hygiene: inflections, overlay de-dup, lemma policy, highlight weights (Priority: P3)

Expand the deterministic `canonicalInflections` table beyond its single entry; de-dup the personal overlay against the base; make the per-category lemma on/off decision principled and documented; document/justify the highlight-scoring weights.

**Why this priority**: Low-risk cleanups that reduce ambiguity and future bugs; smallest measurable impact, so last.

**Independent Test**: Confirm expanded inflections resolve their forms; overlay entries already in base are not duplicated; lemma policy is documented per category; highlight weights are justified.

**Acceptance Scenarios**:

1. **Given** several common inflected state-verbs, **When** matched, **Then** they resolve via the deterministic table.
2. **Given** a personal overlay term identical to a base term, **When** the overlay is applied, **Then** it is not duplicated.

### Edge Cases

- A newly added energy paraphrase that overlaps a polysemous word MUST be guarded (blocklist/context) so coverage does not cost precision.
- A blocklist that is too aggressive MUST NOT suppress a genuine activity — verified on the recall slice.
- Removing the Swift default list MUST keep a safe behavior if the JSON is missing/malformed (extraction must not crash) — the fallback path is reconsidered, not silently deleted.
- An inflected form that is genuinely ambiguous MUST NOT be added to the deterministic table if it would over-fire.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Energy and focus lexicons MUST gain positive-state and common-paraphrase entries within existing categories to reduce the negative-state skew, increasing detection recall.
- **FR-002**: Activity matching MUST gain collocational blocklists / context gating for the known trap words, generalizing the existing stoplist pattern, to raise precision without regressing activity recall below floor.
- **FR-003**: The lexicon MUST have a single source of truth (the JSON data); the duplicated hand-maintained Swift default vocabulary MUST be eliminated or reduced to a documented, non-drifting safety fallback justified in the plan.
- **FR-004**: Lemma-dependent matching MUST be deterministic across simulator and device for covered forms — i.e., the deterministic inflection table covers the forms the app relies on, so behavior does not depend on the lemma model's presence.
- **FR-005**: The `canonicalInflections` table MUST be expanded beyond its single entry to cover the common state/feeling inflections surfaced by eval errors.
- **FR-006**: The personal overlay MUST de-duplicate against the base lexicon when applied.
- **FR-007**: The per-category lemma-enabled decision MUST be documented with its rationale (why activities are surface-only, why feelings use lemmas), removing the ad-hoc inconsistency.
- **FR-008**: The highlight-scoring weights MUST be documented/justified (and centralized if that reduces opacity), without changing behavior unless an eval-measured improvement justifies it.
- **FR-009**: Every change MUST run the spec-010 eval harness; coverage changes are judged on detection-recall (addrec) and the 40-case floors; precision MUST NOT regress below floor (Principle VII).
- **FR-010**: Vocabulary remains DATA in `Resources/lexicon.json` (Principle VII) — no hardcoding of new vocabulary into Swift.
- **FR-011**: This feature MUST NOT add new signal categories, embeddings, ML, or a semantic-similarity layer (other specs / out of scope).
- **FR-012**: Any matching-logic change (blocklists, determinism) MUST be developed test-first (Principle X).

### Key Entities *(include if feature involves data)*

- **Lexicon (data)**: `Resources/lexicon.json` — the single source of vocabulary across all categories.
- **Blocklist / context gate**: A trap-word → forbidden-collocation rule that suppresses a false activity/state match.
- **canonicalInflections**: The deterministic inflected-form → canonical-surface table that makes matching model-independent.
- **Personal overlay**: User-derived vocabulary layered on the base, to be de-duplicated.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Energy detection recall on the addrec corpus rises measurably versus the spec-010 baseline (target: a clear, attributable increase), with 40-case precision floors held.
- **SC-002**: Activities precision on the 40-case set rises versus baseline, with activities recall not regressing below floor.
- **SC-003**: Exactly one hand-maintained vocabulary source remains; no duplicated default list can drift out of sync.
- **SC-004**: For the inflected forms the app relies on, matching results are identical whether or not the lemma model is present.
- **SC-005**: No tracked precision/recall floor regresses on the 40-case set after all changes land.

## Assumptions

- The addrec detection-recall harness (spec 010) is the primary ruler for coverage gains; the 40-case set guards precision.
- "Positive-state/paraphrase entries" are added conservatively and guarded against polysemy — coverage must not cost precision (the negative-bias trap).
- The Swift default lexicon either becomes a thin documented fallback or is removed; the choice is justified in the plan against Principle III (no dead code) and the missing-JSON edge case.
- Verification is via the standalone eval harness where the Xcode app suite cannot run headless (overnight team decision).

## Dependencies

- **Spec 010 (eval infrastructure)** MUST exist first — detection-recall and ordinal metrics are how coverage/precision changes here are judged.
- Existing `Lexicon.swift`, `LexiconData.swift`, `lexicon.json`, `CueMatcher` (canonicalInflections, lemma bridge), `PersonalLexiconBuilder`, and the activity/stoplist code in `NLNoteExtractor`.

## Constitution Alignment *(informative)*

- **Principle VII**: FR-010 keeps vocabulary as DATA; FR-009 enforces eval-gated, non-regressing changes.
- **Principle X**: FR-012 — matching-logic changes are test-first.
- **Principle III/IV**: removing the dual-lexicon duplication and ad-hoc lemma policy reduces surface and dead weight; new blocklists are the minimal mechanism (generalizing an existing one), not a new abstraction.
