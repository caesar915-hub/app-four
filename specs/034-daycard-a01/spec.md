# Feature Specification: DayCard a01 Redesign — Folded + Unfolded

**Feature Branch**: `feat/034-daycard-a01`

**Created**: 2026-07-12

**Status**: Draft

**Input**: User description: "DayCard a01 redesign (spec-034): rebuild the calendar DayCard folded + unfolded states to match Figma a01 (file Squil-Design M0Meys9X89X1NLyT14qrX5, page Screens (v2) 76:2, nodes 308:2122 folded / 308:1957 unfolded), Figma-exact per owner decisions 2026-07-12."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Folded day card reads as the a01 mood card (Priority: P1)

Scrolling the Calendar, each day appears as a single mood-tinted card: a large, confident mood word ("Great") beside a small uppercase weekday ("MON"), the mood sprout on the left, and one compact wrapping line of the day's signals — energy, focus, medication name, and sleep — separated by small dots. The card is glanceable: the day's whole story in one visual breath, matching the approved a01 design.

**Why this priority**: The folded card is the always-visible state — every Calendar visit renders it for every day. It is the largest single visual mismatch against the approved design and delivers the most user-facing value per unit of change.

**Independent Test**: Build only this story; fold/unfold still works and the expanded state (old style) still renders. Compare a folded day side-by-side with Figma node `308:2122` in light and dark.

**Acceptance Scenarios**:

1. **Given** a day with mood, energy, focus, a logged medication, and captured sleep, **When** the Calendar renders its folded card, **Then** the card shows the mood word large and bold in the mood's word colour, a middle dot, the 3-letter uppercase weekday, the mood sprout at the left, and a wrapping chip line "energy · focus · med-name · sleep" with small dot separators — med name in medication purple, sleep with the bed glyph.
2. **Given** a day where sleep was never captured, **When** the folded card renders, **Then** no sleep chip appears and no placeholder is shown.
3. **Given** a day with no check-ins at all, **When** the folded card renders, **Then** the existing calm empty-day copy appears on an untinted card (unchanged behaviour).
4. **Given** the user's text size is set to an accessibility size, **When** the folded card renders, **Then** the mood word and chips wrap onto more lines — nothing truncates.

---

### User Story 2 - Unfolded day card becomes the a01 entry list (Priority: P2)

Tapping a folded card expands it: the mood-tinted header collapses to a slim uppercase band ("GREAT · MON" with a collapse chevron), and each check-in appears as its own entry row — a round mood-tinted disc holding that check-in's sprout, the check-in's mood word large and bold, its time beside it, an outlined ⋯ affordance at the right, and a single wrapping dot-chip line underneath (energy · focus · medication name · sleep · ♥ feelings · side-effects). The vertical timeline line and the dose-phase ring are gone — rows breathe on the white card.

**Why this priority**: The expanded state is reached by an explicit tap — seen less often than folded, but it is where users actually read a day. Depends visually on US1's band/header but is independently buildable and testable.

**Independent Test**: Expand any multi-check-in day; compare against Figma node `308:1957` side-by-side in light and dark; tap a row and confirm it still opens the recording detail.

**Acceptance Scenarios**:

1. **Given** a folded day card, **When** the user taps it, **Then** the header collapses to a slim mood-tinted band showing the day's mood word and weekday in small uppercase letters with an upward chevron.
2. **Given** an expanded day with three check-ins, **When** the card renders, **Then** each check-in shows its own 43pt mood disc (tinted with that check-in's mood, holding that mood's sprout), its mood word in that mood's word colour, its time, an outlined ⋯ affordance, and its own wrapping chip line — with no vertical connector line between rows.
3. **Given** an expanded row for a check-in with a logged dose, **When** the chip line renders, **Then** the medication chip shows the medication name only (no "Taken" prefix, no dose amount), in medication purple with the capsule glyph.
4. **Given** an expanded row, **When** the user taps anywhere on the row (including the ⋯), **Then** the recording detail opens — same navigation as today.
5. **Given** a check-in with five feelings and five side-effects, **When** the chip line renders, **Then** feelings and side-effects each show at most four entries plus an overflow count (existing cap rule).

---

### Edge Cases

- Empty day (no check-ins): folded keeps the current calm empty copy on an untinted card; expanding shows nothing extra (unchanged).
- Day with mood but no energy/focus/med/sleep: chip line shows only what exists; card height shrinks naturally.
- Multiple distinct medications in one check-in: one chip per distinct medication name, names only.
- Sleep captured on more than one check-in in a day: the folded summary shows the day's most recent captured sleep.
- Largest accessibility text sizes: mood word, band label, and chips wrap — never truncate; the ⌄/⌃ affordances and ⋯ remain visible.
- Dose-phase visibility: removing the timeline bead's medication-phase ring means dose phase is no longer visible anywhere on the Calendar — accepted by owner; the phase remains visible in the medication bar and the recording detail.
- Dark mode: all tints/inks come from existing adaptive tokens; the mood tint opacities are identical in both modes (current behaviour).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The folded day card MUST render as one mood-tinted rounded card (existing tint opacity, corner radius, and two-layer shadow tokens) with the mood sprout at the left, the mood word large and bold in the mood's word colour, a middle-dot separator, and the weekday as a 3-letter uppercase, letter-spaced label; a downward chevron sits at the trailing edge.
- **FR-002**: The folded summary MUST be a single wrapping chip line with small dot separators, showing only the signals present on the day, in this order: energy (bolt glyph at the day's energy level + word), focus (aperture glyph at level + word), most recent medication (capsule glyph + name, medication purple), sleep (bed glyph + "_N_h Sleep").
- **FR-003**: The day summary MUST gain a sleep value derived from the day's check-ins (most recent captured sleep), with the derivation covered by tests written before the implementation (Constitution X).
- **FR-004**: The expanded header MUST collapse to a slim mood-tinted band: the day's mood word in uppercase letter-spaced small type in the mood's word colour, a middle dot, the uppercase weekday, and an upward chevron; tapping it folds the card (unchanged toggle behaviour).
- **FR-005**: Each expanded check-in row MUST show: a 43pt round disc tinted with that check-in's mood (existing badge-tint opacity) holding that mood's sprout; the check-in's mood word large and bold in that mood's word colour; the time in small regular type; and an outlined ⋯ affordance at the trailing edge.
- **FR-006**: Each expanded row MUST show one wrapping dot-separated chip line: energy (bolt + word), focus (aperture + word), each distinct medication name (capsule glyph, medication purple, name only — no "Taken" prefix, no dose amount), sleep ("_N_h sleep" in the sleep indigo, text only), feelings (♥ prefix, capped at four plus overflow, secondary ink), side-effects (capped at four plus overflow, secondary ink).
- **FR-007**: The vertical timeline column (bead, medication-phase ring, connector line) MUST be removed from the expanded card; rows are separated by whitespace only.
- **FR-008**: Tapping an expanded row (anywhere, including the ⋯ affordance) MUST open that check-in's recording detail — identical navigation to today.
- **FR-009**: All existing interactions and persisted values MUST be unchanged: fold/unfold toggle, auto-expand setting, selection semantics, and every stored model value. This feature is purely visual except FR-003's summary addition.
- **FR-010**: Both states MUST remain accessible: each folded header and each row reads as one combined VoiceOver element carrying at least today's announced content plus sleep; text wraps rather than truncates at accessibility sizes; tap targets keep at least the minimum size; the fold animation honours Reduce Motion.
- **FR-011**: Every colour, opacity, radius, shadow, and spacing MUST come from existing design-system tokens; no new colour tokens and zero style literals in views.
- **FR-012**: The empty-day folded card MUST keep its current copy and untinted appearance (the approved design does not define an empty state).

### Key Entities

- **Day summary**: the derived per-day digest shown folded — mood, energy, focus, most recent medication name, and (new) most recent captured sleep. Purely derived; nothing new is persisted.
- **Day / check-in nodes**: the existing per-day timeline data (mood, time, signals, medications, feelings, side-effects) — read-only to this feature.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A folded day card and an expanded three-check-in day card each read as visually equivalent to their approved design references (`308:2122`, `308:1957`) in a side-by-side device comparison, light and dark — verified at owner device QA.
- **SC-002**: Every existing Calendar interaction still works on first try: fold/unfold, auto-expand, row tap → recording detail, back navigation.
- **SC-003**: The full test suite passes, including new sleep-summary tests that demonstrably failed before the implementation landed (red → green).
- **SC-004**: A repository-wide style audit of the touched files finds zero hard-coded colour/opacity/radius/shadow values outside design-system tokens.
- **SC-005**: With VoiceOver, a folded day announces its complete summary (including sleep when present) as one element; an expanded row announces its check-in content as one element.

## Assumptions

- The three content decisions are owner-locked (2026-07-12): weekday renders as the 3-letter uppercase form only; medication chips show the name only; the medication-phase ring disappears from the Calendar.
- The a01 design's typefaces map to the app's native type system (the design file's Inter is a documented stand-in for SF).
- Scope is the DayCard component family only (folded header, expanded band, entry rows, day summary). Other a01 screen elements — week strip, day title, screen chrome, medication bar — are out of scope (the bar shipped in spec-033).
- The spec-032 US3 gate ("calendar timeline gated on spec-029") is lifted by the owner for this visual redesign; when spec-029 (calendar day context) is built, its context line joins the chip line as another chip.
- The empty-day state keeps its current design; the approved design defines no empty state.
- This feature stacks on `feat/033-newlook-app-wide` (PR #28) because it rewrites the same files; it merges after PR #28.
- Owner builds and QAs on a physical device; no simulator anywhere in the workflow.
