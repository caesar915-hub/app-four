# Feature Specification: Multilingual On-Device Check-in Extraction (Demo)

**Feature Branch**: `feat/nlp-multilang-demo`

**Created**: 2026-06-25

**Status**: Draft

**Input**: User description: "Multilingual on-device NL extractor (DEMO build for investors). Port the improved extractor lineage from the nlp-spike so the app extracts 6 signals — mood, energy, focus, sleep, medications, and side-effects — across four packs: English (en), European Portuguese (pt-PT), European Spanish (es-ES), and Mexican Spanish (es-MX). The pack is selected per check-in by detected language + device locale region. On-device, no added dependencies. Documented demo limitations acceptable. Preserve the `emotions` field name + spec-020's curated 20-word vocabulary and the existing PersonalLexicon overlay."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - English check-in keeps working after the engine upgrade (Priority: P1)

A person who logs ADHD check-ins in English writes a free-text note ("Took Concerta 36mg this
morning. Slept five hours, woke up tired. Focus good in the morning but energy low in the
afternoon. Dry mouth all day. Mood low."). The app extracts the same six signals it does today —
mood, energy, focus, sleep, medications, side-effects — at the same or better quality, and any
terms the user has personally corrected are still recognized.

**Why this priority**: The richer extractor is swapped in underneath every existing English
user. If English regresses, the demo is net-negative regardless of the new languages. This is the
foundation slice — it can ship and be valuable even if no other language is added.

**Independent Test**: Run the extraction eval harness on the English ground-truth set; every
tracked precision/recall floor must still hold. Manually enter the English sample and confirm all
six signals appear. Confirm a user-corrected term is still extracted.

**Acceptance Scenarios**:

1. **Given** the upgraded extractor, **When** the eval harness runs over the English check-in set, **Then** no category's precision or recall falls below its current floor.
2. **Given** an English check-in naming a medication, sleep hours, mood, energy, focus, and a side-effect, **When** it is processed, **Then** all six signals are populated.
3. **Given** a user who previously corrected a personal term (e.g. a nickname for a medication), **When** they write a new check-in using that term, **Then** it is still recognized.
4. **Given** the curated 20-word emotion vocabulary from spec-020, **When** an English check-in mentions one of those emotions, **Then** it surfaces and no de-curated (removed) emotion word resurfaces.

---

### User Story 2 - Portuguese and Spanish check-ins are understood in-language (Priority: P2)

A Portuguese-speaking user writes their check-in in Portuguese, and a Spanish-speaking user in
Spain writes theirs in Spanish. Each note's language is recognized from its own text, and the app
extracts the six signals using vocabulary in that language rather than guessing from English words.

**Why this priority**: This is the headline of the demo — "the app understands check-ins in
Portuguese and Spanish, on-device." It depends on US1 (the engine must be in place first).

**Independent Test**: Enter the Portuguese sample and the Spain-Spanish sample; confirm each is
detected as its language, the matching pack is selected, and all six signals surface.

**Acceptance Scenarios**:

1. **Given** a Portuguese check-in, **When** it is processed, **Then** the Portuguese pack is selected and mood, energy, focus, sleep, medications, and side-effects are extracted.
2. **Given** a Spanish check-in on a device set to Spain, **When** it is processed, **Then** the European Spanish pack is selected and the six signals are extracted.
3. **Given** a very short check-in in Portuguese or Spanish, **When** language detection runs, **Then** it still resolves to a supported pack rather than failing.

---

### User Story 3 - Mexican vs. European Spanish is chosen by region (Priority: P3)

A user in Mexico and a user in Spain both write Spanish, but use regionally different phrasing
(e.g. "Ando agüitado" for low mood in Mexico). The app uses the device region to pick the Mexican
or European Spanish vocabulary, because language detection alone cannot tell the two apart.

**Why this priority**: A polish slice that demonstrates regional nuance. Valuable for the demo
narrative but the smallest scope; the es-ES pack already covers Spanish if region data is absent.

**Independent Test**: With the device region set to Mexico, enter the Mexican sample and confirm
the es-MX pack is used and low mood is detected from "Ando agüitado"; switch region to Spain and
confirm es-ES is used.

**Acceptance Scenarios**:

1. **Given** a Spanish check-in on a device with region Mexico, **When** it is processed, **Then** the Mexican Spanish pack is selected.
2. **Given** the same check-in on a device with region Spain (or any non-MX region), **When** it is processed, **Then** the European Spanish pack is selected.

---

### Edge Cases

- **Unsupported language**: a check-in detected as neither English, Portuguese, nor Spanish falls back to the English pack (best-effort) rather than producing nothing.
- **Missing or malformed pack resource**: if a language pack cannot be loaded, extraction falls back to the English/default behavior instead of crashing or returning empty.
- **Mixed-language or code-switched check-in**: the dominant language wins; partial mismatch is an accepted demo limitation.
- **Non-English negation / medication phrasing**: for Portuguese and Spanish, negation handling, medication-clause parsing, ADHD-pattern detection, title generation, and word morphology still use English rules — a documented limitation, not a defect.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST detect the dominant language of each check-in from its own text, constrained to English, Portuguese, and Spanish, with a fallback that still resolves short check-ins to a supported pack.
- **FR-002**: System MUST disambiguate the two Spanish variants by device region — Mexico selects Mexican Spanish, any other region selects European Spanish — because language detection cannot distinguish them.
- **FR-003**: System MUST extract all six demo signals — mood, energy, focus, sleep, medications, side-effects — using the vocabulary of the selected pack (English, Portuguese, European Spanish, or Mexican Spanish).
- **FR-004**: The upgraded extractor MUST NOT regress any tracked extraction precision/recall floor on the existing evaluation set (Principle VII).
- **FR-005**: The English pack MUST preserve spec-020's curated 20-word Mood-Meter emotion vocabulary; the pre-curation emotion list MUST NOT be reintroduced.
- **FR-006**: The data model field name `emotions` MUST be preserved; the ported engine MUST write its emotion output into `emotions` (not `feelings`).
- **FR-007**: The existing per-user personalization overlay MUST continue to apply after the extractor is rewired to per-check-in pack selection.
- **FR-008**: A missing or malformed language-pack resource MUST degrade gracefully to English/default extraction rather than failing.
- **FR-009**: All processing MUST remain on-device with no added third-party dependencies and no cloud calls (Principle VI).
- **FR-010**: Language selection (detector) and pack loading (loader) MUST be covered by automated tests, including the Mexico-vs-Spain region branch and the missing-pack fallback.
- **FR-011**: Side-effect display MUST count the appetite-loss bucket as a side effect alongside the existing side-effect buckets.
- **FR-012**: Documented demo limitation — for Portuguese and Spanish, negation, medication-clause parsing, ADHD-pattern detection, title generation, and morphology remain English-based; this MUST be stated in the delivery notes, not hidden.

### Key Entities *(include if feature involves data)*

- **Language Pack**: the per-locale extraction resources — a vocabulary set (lexicon) plus a language-configuration set (numbers, sleep patterns, weak mood/energy tables, tense markers). Keyed by `en`, `pt-PT`, `es-ES`, `es-MX`. English uses an in-code default configuration; the others ship as data.
- **Check-in Extraction**: the structured result of one check-in — the six demo signals plus the existing auxiliary fields — written into the app's existing extraction model (which already uses `emotions`).
- **Personalization Overlay**: the user's corrected terms, merged on top of the selected pack's vocabulary so personalization survives language selection.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Each of the four reference check-ins (English, Portuguese, Spain-Spanish, Mexico-Spanish) surfaces all six signals — mood, energy, focus, sleep, medications, side-effects.
- **SC-002**: Every tracked English extraction precision/recall floor holds after the upgrade (zero regressions).
- **SC-003**: Language detection selects the correct pack for 100% of the four reference check-ins.
- **SC-004**: With device region set to Mexico the Mexican pack is selected, and with any other region the European Spanish pack is selected, for the same Spanish check-in.
- **SC-005**: A previously user-corrected term is still recognized in a new check-in, confirming personalization survived the rewire.

## Assumptions

- The four packs cover the demo set: English (en), European Portuguese (pt-PT), European Spanish (es-ES), Mexican Spanish (es-MX). No other languages are in scope.
- The Portuguese and Spanish lexicon/config packs are **drafts** authored for the demo, not natively reviewed; native-review quality and pharmacy brand verification (e.g. COFEPRIS) are out of scope.
- The app's extraction model, eval harness, sibling extractor files, and personalization overlay already exist and are reused; this feature swaps the engine and adds pack selection rather than rebuilding extraction.
- Demo verification of the non-English packs is by the four manual reference check-ins; the automated eval harness remains the English regression guard and is not extended to score the draft packs in this feature.
- The Spanish-variant decision uses device region only; in-text dialect detection is not attempted.
