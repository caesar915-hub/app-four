# Feature Specification: Emotions Lexicon (replace "Feelings")

**Feature Branch**: `feat/rename-feelings-to-emotions`

**Created**: 2026-06-24

**Status**: Draft

**Input**: User description: Replace the check-in "Feelings" category with an "Emotions" category backed by a reduced, curated lexicon of ~20 main emotions derived from the How We Feel app's Mood Meter model (valence × energy, four quadrants, 5 emotions per quadrant). Wipe the existing ~60-word feelings lexicon entirely. Rename every "feelings" identifier, persisted column, tag-category value, extraction key, lexicon key, UI label, and nudge copy to "emotions". The app already tracks mood and energy on separate axes, so the emotions list must exclude pure energy/mood/cognitive states. Inline mood cue-phrases containing the word "feeling" must remain untouched. Store wipe on schema change is accepted (pre-release). The extraction eval must be re-pointed to the new vocabulary without regressing its floors.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Name and curate the category as "Emotions" (Priority: P1)

A person reviewing what their check-in captured sees a section called **Emotions** (no longer "Feelings"), and the choices offered are a short, recognizable set of ~20 emotions rather than a sprawling ~60-word list. The word the app prompts with ("Any strong emotions?") and the chips it shows all speak in terms of *emotions*.

**Why this priority**: This is the entire user-facing point of the change — a clearer category name backed by a focused, scientifically-grounded vocabulary. It delivers value on its own even before extraction tuning.

**Independent Test**: Open the extraction-review screen for a check-in; confirm the section header reads "Emotions", the nudge prompt asks about emotions, and the selectable list is exactly the curated 20. No surface anywhere in the app reads "Feelings" as a category.

**Acceptance Scenarios**:

1. **Given** a completed check-in, **When** the user opens its review/edit screen, **Then** the affective-state section is titled "Emotions" and offers exactly the 20 curated emotions.
2. **Given** the check-in composer nudges, **When** the emotion nudge appears, **Then** it asks "Any strong emotions?" (not "feelings").
3. **Given** a check-in with detected emotions, **When** its timeline/summary chips render, **Then** each emotion chip shows a curated emotion label.

---

### User Story 2 - Detect only genuine emotions, deferring to the other axes (Priority: P2)

When a person describes their day, the extractor surfaces the discrete emotions they mention (e.g. "anxious", "grateful") but does **not** pull energy words ("exhausted", "wired") or mood/cognitive states ("indifferent", "curious") into the Emotions category — those belong to the app's separate mood, energy, and focus axes.

**Why this priority**: Correct extraction is what makes the curated list trustworthy. It depends on US1's vocabulary existing but is independently testable via the eval harness.

**Independent Test**: Run the extraction eval; confirm emotion samples map to the new 20, that dropped words (e.g. "exhausted") are no longer emitted as emotions, and that the emotions precision/recall floors hold or improve.

**Acceptance Scenarios**:

1. **Given** a transcript that says "I felt grateful", **When** extraction runs, **Then** "grateful" is detected as an emotion.
2. **Given** a transcript that says "I was exhausted", **When** extraction runs, **Then** "exhausted" is NOT emitted as an emotion (energy axis owns it).
3. **Given** a transcript that says "I'm feeling down", **When** extraction runs, **Then** mood detection still fires on the "feeling down" cue and the Emotions category is unaffected.

---

### User Story 3 - Clean update with no migration (Priority: P3)

A person updating from a prior build (which used the "feelings" schema) lands in a working app: because the schema is pre-release, an incompatible store is wiped and rebuilt rather than migrated. The app opens to the new Emotions category without crashing; previously-logged feelings data is not preserved, and that is acceptable for this pre-release stage.

**Why this priority**: A safety/robustness guarantee. Lowest priority because the project's data posture already accepts the wipe, but it must be verified, not assumed.

**Independent Test**: Launch the build against a store created by the prior (feelings) schema; confirm the app starts cleanly with the Emotions category and no crash.

**Acceptance Scenarios**:

1. **Given** a store written by the previous "feelings" schema, **When** the updated app launches, **Then** it recovers by wipe-and-rebuild and presents the Emotions category without error.

---

### Edge Cases

- **Old word in speech**: a check-in mentions a word dropped from the curated 20 (e.g. "nostalgic", "restless") → it is simply not surfaced as an emotion; no crash, no empty chip. If the word belongs to another axis (energy/mood), that axis may still capture it.
- **Personal vocabulary**: a user had previously added a custom emotion tag → the personal-lexicon overlay continues to work under the renamed category; custom emotions still match.
- **Mood/emotion lexical overlap**: cue phrases that literally contain "feeling" (`feeling down`, `feeling empty`, `feeling seen`) must keep driving *mood/other* detection and must NOT be renamed or moved into Emotions.
- **Empty emotions**: a check-in with no emotion mentioned renders the Emotions section empty/absent gracefully (unchanged from prior behavior).
- **Eval sample collision**: an eval transcript previously asserting a now-dropped emotion must be re-pointed to a curated emotion (or moved to the correct axis) so floors stay meaningful rather than trivially passing.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The check-in affective-state category MUST be presented to users as **"Emotions"** everywhere it currently reads "Feelings" — section header, nudge prompt, chips, and accessibility labels.
- **FR-002**: The Emotions category MUST be backed by a curated set of **exactly 20 emotions** derived from the How We Feel / Mood Meter model, balanced across its four valence×energy quadrants (5 per quadrant).
- **FR-003**: The previous ~60-item feelings vocabulary MUST be removed in full; only the curated 20 (plus minimal cue surface forms needed to match them in speech) remain as the emotions vocabulary.
- **FR-004**: The emotions vocabulary MUST exclude states already represented by the app's separate **mood**, **energy**, and **focus** axes (e.g. exhausted/energised/wired/recharged/restless as energy; indifferent/curious/reflective/motivated as mood/cognitive).
- **FR-005**: Mood (and other-axis) cue-phrases that contain the substring "feeling" (e.g. `feeling down`, `feeling empty`, `feeling seen`) MUST continue to drive their existing detection and MUST NOT be altered, renamed, or reclassified by this change.
- **FR-006**: The extractor MUST detect emotions via whole-token / contiguous multi-word lexicon matching only — no substring matching, no sentiment-valence fallback, no word-vector rescue (Constitution VII).
- **FR-007**: User-corrected / personal emotion tags MUST continue to overlay the curated vocabulary so custom emotions still match under the renamed category.
- **FR-008**: The extraction eval harness MUST be re-pointed so its emotion samples reference the curated 20, and the tracked emotions precision/recall floors MUST hold or improve (MUST NOT regress).
- **FR-009**: On launch against an incompatible (prior "feelings") store, the app MUST recover by wipe-and-rebuild without crashing; no migration of prior feelings data is required (Constitution IX).
- **FR-010**: Every persisted or serialized artifact that named the category "feelings" — the `Recording` emotions column, the tag-category value, the extraction JSON key, and the lexicon top-level key — MUST consistently use "emotions" naming so the data model has no mixed terminology.
- **FR-011**: The new emotions column MUST remain CloudKit-compatible: optional or defaulted, no unique constraint (Constitution IX).

### Key Entities

- **Emotion**: a discrete affective state a person names in a check-in; a member of the curated set of 20. Conceptually tagged with a Mood-Meter quadrant (valence: pleasant/unpleasant × energy: high/low) which guides *selection* but is not necessarily a stored field.
- **Emotions lexicon**: the data list (in `lexicon.json` under the `emotions` key, with a curated default subset in code) of the 20 emotion words plus the minimal surface forms used to match them.
- **Check-in (Recording)**: stores the user-selected and/or detected emotions for a logged moment (the renamed emotions column), independent of its mood, energy, focus, sleep, and medication fields.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user inspecting any screen finds the affective-state category labeled "Emotions" and **zero** occurrences of "Feelings" as a category label in the UI.
- **SC-002**: The list of selectable emotions contains **exactly 20** items, evenly covering the four valence×energy quadrants (5 per quadrant).
- **SC-003**: **None** of the 20 emotions duplicates a state already owned by the mood, energy, or focus axes.
- **SC-004**: The extraction eval for the emotions category meets or exceeds its pre-change precision/recall floors (no regression).
- **SC-005**: Updating the app over a prior ("feelings") install starts cleanly with the new category and no crash in 100% of launches.
- **SC-006**: A reviewer scanning the codebase finds no remaining `feeling`/`feelings` **identifier** for this category (the only surviving "feeling" tokens are the intentional mood cue-phrases of FR-005).

## Assumptions

- The concrete 20 emotions are produced by the citation-backed How We Feel research pass and finalized during planning; the spec fixes the *shape* (20, quadrant-balanced, exclusions), the plan fixes the *words*.
- Store wipe on schema change is acceptable for this pre-release stage (Constitution IX); preserving prior testers' feelings data is explicitly out of scope.
- English-only vocabulary for this change; multilingual emotion lists are a future follow-up.
- The picker keeps its existing **grouped-chip** structure, reduced from 3 groups (Positive/Neutral/Difficult) to **2 valence groups** (Pleasant/Unpleasant, 10 each, energy-ordered within); the four Mood-Meter quadrants inform curation but are not surfaced as four UI sections.
- Synonym/inflection expansion for the 20 is kept minimal (enough for reliable matching); broad surface-form expansion is a separate follow-up tracked in the backlog.
- The existing extraction architecture (data-driven `lexicon.json` + personal overlay, off-main-actor `NLNoteExtractor`) is reused unchanged except for the renamed key and replaced word-list.
