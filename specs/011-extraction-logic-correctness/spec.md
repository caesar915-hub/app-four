# Feature Specification: Extraction-Logic Correctness

**Feature Branch**: `011-extraction-logic-correctness`

**Created**: 2026-06-23

**Status**: Draft

**Input**: User description: "Correctness fixes to the existing NLNoteExtractor extraction logic — temporal symmetry, negation correctness (token-anchored, clause-scoped, middle-tier flip), clause-scoped aggregation, sleep worded-numbers, tense hardening. No new features; improves what exists. Measured against the eval harness (spec 010)."

## Overview

This feature fixes correctness bugs in the *existing* `NLNoteExtractor` logic. It adds no capability and no vocabulary — it makes the rules the extractor already runs behave correctly. Every change is gated by the eval harness from spec **010** (Principle VII): it MUST NOT regress the tracked floors, and where measurable it should improve them.

Scope is the eight logic items from the architecture review: temporal weighting for energy/focus, symmetric-flip correction, negation scope and token-anchoring, clause-scoped aggregation, sleep worded-numbers, tense-coverage hardening, and extracting the opaque aggregation policy into a testable unit.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Temporal symmetry for energy & focus (Priority: P1)

A check-in that says "I was wired this morning but I'm dragging now" should report **current** energy (dragging), the same way mood already prefers the present. Today energy/focus ignore tense entirely and pick the longest phrase regardless of when it was true.

**Why this priority**: The asymmetry is a logged-but-unjustified design gap; the fix reuses code that already exists (`TenseClassifier`), and mis-timed energy/focus directly corrupts the daily signal the app exists to capture.

**Independent Test**: Feed a transcript with a past energy phrase and a present energy phrase of equal/greater length; confirm the present one wins, mirroring mood. Confirm no mood regression.

**Acceptance Scenarios**:

1. **Given** a sentence with a past-tense energy phrase and a later present-tense energy phrase, **When** extraction runs, **Then** the present-tense energy value is selected.
2. **Given** identical input, **When** focus is extracted, **Then** the present-tense focus value wins over a longer past-tense one.
3. **Given** the existing 40-case set, **When** the change lands, **Then** mood selection is unchanged and no floor regresses.

---

### User Story 2 - Negation correctness (Priority: P1)

Negation must (a) match the negated word as a whole token, not a substring; (b) respect clause boundaries so it doesn't bleed across "but"/"however"; and (c) map a negated ordinal to the adjacent/middle tier, not the polar opposite ("not great" → okay, not low).

**Why this priority**: Negation is applied identically across mood/energy/focus and all set categories — a systemic correctness surface. Substring matching also directly violates Principle VII ("never substrings: window ≠ win"). Polar flipping manufactures false extreme states.

**Independent Test**: Run negation cases — "I don't feel tired at all, just a bit anxious" (scope), "not great" (middle-tier), and a target word embedded in a longer word (token-anchor). Confirm correct polarity and no cross-clause bleed.

**Acceptance Scenarios**:

1. **Given** a negation cue and a target signal word that is a substring of a different word elsewhere, **When** negation is checked, **Then** only a whole-token match triggers the flip.
2. **Given** "I don't feel tired, just anxious", **When** extraction runs, **Then** the negation scopes to its own clause and does not flip "anxious".
3. **Given** "I don't feel great", **When** the mood flip applies, **Then** the result is a middle tier (okay/flat), not the polar opposite (low).
4. **Given** the existing negation tests, **When** the change lands, **Then** all pass and no floor regresses.

---

### User Story 3 - Clause-scoped aggregation for mood/energy/focus (Priority: P2)

"Was tired but now alert" should resolve per clause — alert wins — using the clause splitter that medications already rely on, instead of treating the whole sentence as one bucket.

**Why this priority**: Generalizes a proven mechanism (`clauseRanges`, used only by meds today) to the subjective signals, reducing within-sentence cross-talk. Lower priority than US1/US2 because it compounds them rather than standing alone.

**Independent Test**: Feed a single sentence with opposing energy clauses joined by "but"; confirm the post-conjunction clause's value wins, consistent with the temporal rule.

**Acceptance Scenarios**:

1. **Given** a sentence with two opposing energy clauses, **When** extraction runs, **Then** attribute scoping respects the clause boundary.
2. **Given** the 40-case set, **When** the change lands, **Then** medication clause-scoping behavior is unchanged and no floor regresses.

---

### User Story 4 - Sleep worded-numbers & tense hardening (Priority: P3)

"Slept maybe three hours" and "a solid nine hours" should yield sleep hours, not nil. Tense detection should cover the common gaps (worded numbers, a slightly larger irregular-verb/marker set) without inventing new capability.

**Why this priority**: Targeted recall fixes; smaller blast radius. Sleep recall is among the worst (≈0.27–0.50) and the cause is concrete (digit-only regex).

**Independent Test**: Run sleep cases with worded numbers; confirm extraction yields the numeric hours. Confirm digit-based cases still work.

**Acceptance Scenarios**:

1. **Given** "slept maybe three hours", **When** sleep extraction runs, **Then** sleepHours = 3.
2. **Given** "I got about 7 hours", **When** sleep extraction runs, **Then** sleepHours = 7 (unchanged).

### Edge Cases

- A word that is both a substring of a signal cue and a real different word (e.g., "win" in "window") MUST NOT trigger via substring (Principle VII).
- A double negation or a negation cue belonging to a different clause MUST NOT flip a target in the current clause.
- A sentence with no clause boundary behaves exactly as today (single clause).
- A worded number outside the supported range (e.g., "a couple hours") MAY remain unmatched and is documented, not silently guessed.
- A negated ordinal at the scale extreme (e.g., "not flat") maps per an explicit table, not a hard polar rule.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Energy and focus aggregation MUST incorporate the existing temporal weight so a present-tense value is preferred over a past-tense one, consistent with mood.
- **FR-002**: Negation detection MUST match the negated target as a whole token (or contiguous multi-word phrase), never as a substring (Principle VII).
- **FR-003**: Negation scope MUST be bounded by clause boundaries (coordinating conjunctions / terminators) so a cue does not flip a target in a different clause.
- **FR-004**: A negated ordinal value MUST map to an adjacent/middle tier via an explicit, reviewable mapping — not to the polar opposite.
- **FR-005**: Mood, energy, and focus attribute resolution MUST be able to scope to a clause using the existing clause-splitting mechanism, consistent with medication scoping.
- **FR-006**: Sleep-hours extraction MUST recognize worded numbers (at least three through twelve) in addition to digits, without regressing digit-based extraction.
- **FR-007**: Tense detection MUST cover the documented common gaps (worded-number-adjacent markers; a modestly expanded irregular-verb/marker set) without adding future/conditional *capability* beyond discarding hypotheticals already in scope.
- **FR-008**: The mood/energy/focus aggregation policy MUST be extracted into an explicitly testable unit so the selection rule (temporal weight, then specificity, then recency) can be unit-tested in isolation.
- **FR-009**: Every change MUST run the spec-010 eval harness and MUST NOT regress any tracked precision/recall floor (Principle VII).
- **FR-010**: All logic changes MUST be developed test-first with failing Swift Testing cases written and confirmed RED before implementation (Principle X).
- **FR-011**: This feature MUST NOT add vocabulary to the lexicon, add new signal categories, or introduce embeddings/ML — those are other specs or out of scope.

### Key Entities *(include if feature involves data)*

- **Aggregation policy**: The rule selecting the winning mood/energy/focus value across candidates — currently inline, to be made an explicit unit.
- **Negation decision**: The (cue, target, clause, polarity) determination that flips or suppresses a signal.
- **Tense weight**: The present/past/neutral weight already produced by `TenseClassifier`, to be consumed by energy/focus.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: No tracked precision/recall floor regresses on the 40-case set after all changes land.
- **SC-002**: On a targeted present-vs-past slice, energy/focus select the present value in 100% of constructed cases.
- **SC-003**: On a negation slice, no target is flipped across a clause boundary, and no substring-only match triggers a flip.
- **SC-004**: "Not great"-style negated-ordinal cases resolve to a middle tier, verified by explicit cases.
- **SC-005**: Sleep worded-number cases (three…twelve) yield the correct numeric hours; digit cases unchanged.
- **SC-006**: The aggregation policy is exercised by isolated unit tests independent of full-transcript extraction.

## Assumptions

- "Adjacent/middle tier" for negated ordinals is defined by an explicit per-scale mapping reviewed in the plan, not derived.
- Worded-number support is bounded (three…twelve) — the common sleep range; out-of-range phrases stay unmatched and documented.
- Clause boundaries reuse the existing `clauseRanges` split words; no dependency parser is introduced (Principle IV — minimal surface).
- Verification is via the standalone eval harness where the Xcode app suite cannot run headless; app-suite confirmation is deferred to a follow-up (team decision for the overnight run).

## Dependencies

- **Spec 010 (eval infrastructure)** MUST be in place first — it is the ruler that gates every change here (Principle VII).
- The existing `TenseClassifier`, `clauseRanges`, `isNegatedBefore`, `flipMood/flipEnergy/flipFocus`, and `ADHDRegexPatterns` in `app-four/Services/NoteExtraction/`.

## Constitution Alignment *(informative)*

- **Principle VII**: FR-002 (whole-token, never substring) directly enforces the constitution's "window ≠ win" rule; FR-009 enforces the non-regression-on-eval mandate.
- **Principle X**: FR-010 — logic changes are test-first.
- **Principle III/IV**: corrections to existing logic; no new abstractions beyond extracting the aggregation policy (FR-008), which removes opacity rather than adding surface.
