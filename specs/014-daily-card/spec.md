# Feature Specification: Daily Card — Folded Summary, Opens to the Day

**Feature Branch**: `feat/daycard-update`

**Created**: 2026-06-23

**Status**: Draft

**Input**: Redesign the calendar's day card per the 2026-06-22 final-decisions doc (`mockups/summary/index.html`, "The calendar, decided"), with `mockups/folded-card-final/` and `mockups/prototype/` as supporting artifacts. The card must read the whole day in one folded line and open to the day's check-ins, and selecting a date must focus that day (filter-above + jump-to-top + auto-expand). This is a behavioral redesign, deliberately **separate from 008-mockup-parity** (visual-only, calendar-frozen, keyed to the June-15 design-system mockup). It reuses the signal-glyph language (spec 006) and the Paper & Pollen visual tokens (spec 008 / `DESIGN.md`); it changes structure and interaction, not the visual identity.

## Clarifications

### Session 2026-06-23

**Asked:**

- Q: On a multi-medication day, which med shows in the folded summary line? → A: The **most-recent check-in's medication** (the day's newest node; lists are already newest-first).
- Q: How are more-recent (filtered-out) days de-emphasised in the calendar row? → A: **Opacity plus a second non-color cue** (e.g. lighter weight / dropped marker dot) so the de-emphasis survives greyscale.
- Q: Tapping the already-selected date again? → A: **Idempotent** — the day stays top-and-in-focus; folding is done via the card-header tap, never via re-selection.
- Q: Canonical name for the logged-moment entity? → A: **`Recording`** is the code source-of-truth; "check-in" is user-facing copy only (no model rename).

**Resolved by source analysis** (interactive prototype JS / live code — encoded without asking):

- Expand model: a card-header tap toggles that card independently (multiple cards MAY be open at once); selecting a date first collapses all open cards, then opens only the selected day. (`mockups/prototype/index.html`)
- Auto-expand-on-selection is a user setting, **default ON**; when off, selecting a date scrolls to that day without opening it. (`mockups/prototype/index.html`)
- Empty/quiet-day copy reads "No check-ins this day. That's alright." — never red, never "missed"/"overdue". (`mockups/prototype/index.html`)
- Medication-phase ring greyscale cue: the numeric **% beneath** the ring is the redundant, non-color readout (arc length + % text); no pattern fill needed.
- Oldest-day end of list: the list simply stops — no end-of-history marker or copy (calm, no-gamification stance).
- Fold/unfold and scroll-to-top honor Reduce Motion (no animation when enabled), mirroring the existing calendar interaction.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Read a whole day at a glance (Priority: P1)

A person opens the calendar and, without tapping anything, reads each day as a single folded card: a mood-glyph circle on the left, the weekday above, and one line beneath summarising the day — mood, energy, focus, and the medication name. They understand "how that day went" in one glance.

**Why this priority**: This is the core of "summary-first." Today the card is always fully expanded with no one-line read, so the list is a wall of detail. The folded summary is the smallest slice that delivers the product's central value and is independently shippable.

**Independent Test**: On the simulator, render a list of days with varied logged signals and confirm each folded card communicates mood/energy/focus/medication on one line with the mood circle, without opening.

**Acceptance Scenarios**:

1. **Given** a day with mood, energy, focus, and a medication logged, **When** the list renders, **Then** the folded card shows the mood-glyph circle, the weekday, and a single line "mood · energy · focus · medication-name" (medication is the name only — no dose or time).
2. **Given** a day where only mood was logged, **When** the card renders, **Then** the summary line shows only the mood and omits energy, focus, and medication entirely (no zeros, blanks, or placeholders).
3. **Given** a day with no check-ins, **When** the card renders, **Then** it reads as a calm empty state — no red, no "missed"/"overdue" wording, no streak or score.

---

### User Story 2 - Open a day to see its check-ins (Priority: P1)

The person taps a folded card. The one-line summary collapses (the mood circle and weekday stay), and the day's check-ins appear in time order — each a time-circle wrapped in the medication-phase ring with its percentage, then the mood word, energy and focus glyphs, and chips for medication, feelings, and side-effects.

**Why this priority**: "Detail on tap" is the other half of summary-first; without it the folded card is read-only. Pairs with US1 to form the complete card. Independently testable once US1 exists.

**Independent Test**: Tap a folded card on the simulator and confirm it expands to the time-ordered check-ins with phase rings and signals, and that tapping again collapses it back to the folded summary.

**Acceptance Scenarios**:

1. **Given** a folded card, **When** it is tapped, **Then** it expands: the summary line collapses, the mood circle + weekday remain, and the check-ins are revealed newest-to-oldest within the day.
2. **Given** an expanded check-in, **When** it renders, **Then** the time sits inside a medication-phase ring with the dose-phase percentage beneath it, followed by the mood word, energy + focus as level-encoding glyphs, and chips for medication / feelings / side-effects.
3. **Given** a check-in where only some fields were logged, **When** it renders, **Then** only the logged signals and chips appear (a partial check-in is never padded with empty slots).
4. **Given** an expanded card, **When** it is tapped again, **Then** it collapses back to the folded summary.

---

### User Story 3 - Focus a date by selecting it (Priority: P2)

The person taps a date in the calendar week-row. That day jumps to the top of the list and opens automatically; days more recent than it drop out of the list (and grey out in the calendar row); older days remain below to scroll.

**Why this priority**: This is the new interaction the redesign introduces (today selection only scroll-syncs). It depends on US1/US2 being in place, so it follows them, but it is the decided navigation model and is independently demonstrable.

**Independent Test**: Select several different dates on the simulator and confirm each selected day moves to the top, auto-expands, removes more-recent days from the list, greys them in the week-row, and leaves older days scrollable below.

**Acceptance Scenarios**:

1. **Given** the list scrolled to any position, **When** a date is selected, **Then** that day moves to the top of the list and is expanded.
2. **Given** a selected date, **When** the list renders, **Then** days more recent than the selected date are absent from the list and older days remain below.
3. **Given** a selected date, **When** the calendar week-row renders, **Then** days more recent than the selected date are de-emphasised (greyed), not removed.
4. **Given** a selected day, **When** it renders, **Then** it carries no accent border or outline — its top position and expanded state are the only selection cues.
5. **Given** the calendar row, **When** today is shown, **Then** today is marked only by the "Today" pill — there is no ring around today's number.

---

### User Story 4 - Read the day without color or with large text (Priority: P3)

A person who is color-blind, using greyscale, or running a large Dynamic Type size can still read every signal and all card text.

**Why this priority**: Accessibility is a constitution-level requirement (redundant encoding; Dynamic Type) and a current-state gap — the card today uses a fixed font that does not scale. It is cross-cutting but separately verifiable.

**Independent Test**: View the screen desaturated and at the largest standard Dynamic Type size on the simulator; confirm every signal is still distinguishable and no text becomes illegible.

**Acceptance Scenarios**:

1. **Given** the screen in greyscale, **When** signals render, **Then** each level is still distinguishable by shape and fill (color is never the only cue).
2. **Given** the largest standard Dynamic Type size, **When** a card renders, **Then** the weekday, summary line, mood words, times, and percentages all scale and remain legible.
3. **Given** VoiceOver, **When** a folded card is focused, **Then** it is announced as a single element summarising the day and its logged signals; expanding exposes the individual check-ins.

---

### Edge Cases

- **Selecting today**: today jumps to top and expands; nothing is more recent, so no days are filtered out and only the "Today" pill marks it.
- **Selecting the oldest available day**: it moves to top and expands; the list below is empty (no older days) without an error or empty-list glitch. The list simply stops — there is **no end-of-history marker or copy**.
- **Re-selecting the same date**: tapping the already-selected date again is idempotent — the day stays at top and open; it is not collapsed or re-animated (folding is done only via the card-header tap).
- **A day with many check-ins**: the expanded card scrolls within the list normally; the folded summary still reduces to one line regardless of check-in count.
- **A check-in with no medication logged**: the time-circle still renders; the medication-phase ring/percentage is omitted rather than shown as 0%.
- **All signals unlogged for a day vs. a day with zero check-ins**: both read as calm/empty, but a day with at least one check-in still shows its time-circle(s); a day with no check-ins shows the empty-state card.
- **Rapid re-selection**: selecting a new date while a previous day is expanded re-focuses to the new day (top + expanded) predictably, without leaving the list in a mixed state.

## Requirements *(mandatory)*

### Functional Requirements

**Folded card (US1)**

- **FR-001**: Each day MUST render as a folded card showing a mood-glyph circle on the left, the weekday above, and a single summary line beneath reading the day's mood, energy, focus, and medication.
- **FR-002**: The folded summary line MUST show only the signals that were logged that day; an unlogged signal MUST be omitted, never shown as zero, blank, or placeholder.
- **FR-003**: Medication in the folded line MUST be shown by name only — no dose, no time. On a day spanning more than one medication, the folded line MUST show the **most-recent check-in's** medication name (one name only).
- **FR-004**: A day with no check-ins MUST render as a calm empty-state card that communicates no failure, lateness, streak, or score (no red, no "missed"/"overdue"). The empty-state copy MUST read "No check-ins this day. That's alright." (per the prototype).

**Open / shrink-on-open (US2)**

- **FR-005**: Tapping a folded card's header MUST toggle that card's expansion independently — it collapses the one-line summary (leaving the mood circle and weekday in place) and reveals the check-ins, and tapping again folds it back. More than one card MAY be open at once via header taps.
- **FR-006**: When expanded, the day's check-ins MUST appear in time order, each showing the time inside a medication-phase ring with the dose-phase percentage beneath, then the mood word, energy and focus as level-encoding glyphs, and chips for medication, feelings, and side-effects.
- **FR-007**: A check-in MUST display only the signals and chips that were actually logged; partial check-ins MUST NOT be padded with empty slots.
- **FR-008**: Expansion MUST be reversible — tapping an expanded card MUST collapse it back to the folded summary.

**Selection / filter-above (US3)**

- **FR-009**: Selecting a date MUST move that day to the top of the list; when auto-expand (FR-019) is on, selecting a date MUST first collapse any open cards and then open only the selected day. Re-selecting the already-selected date is idempotent (the day stays top-and-open; it does not collapse).
- **FR-010**: Selecting a date MUST remove days more recent than the selected date from the list while leaving older days below, scrollable.
- **FR-011**: In the calendar week-row, days more recent than the selected date MUST be de-emphasised (greyed), not removed. The de-emphasis MUST NOT rely on opacity alone — it MUST carry a second, non-color cue (e.g. lighter weight or a dropped marker dot) so it remains distinguishable in greyscale.
- **FR-012**: The selected day MUST NOT be indicated by an accent border or outline; position (top) and expanded state are the only selection affordances.
- **FR-013**: Today MUST NOT be marked by a ring in the calendar week-row; the only today affordance is the "Today" pill.

**Cross-cutting (US4 / principles)**

- **FR-014**: Every signal MUST be distinguishable without color — by shape and fill as well as hue — so the card is legible in greyscale and to color-blind users.
- **FR-015**: All card text (weekday, summary line, mood words, times, percentages) MUST scale with the user's Dynamic Type setting.
- **FR-016**: The screen's component order (medication bar, calendar row, day list) MUST stay stable and MUST NOT reshuffle as data changes.
- **FR-017**: A folded card MUST be exposed to assistive technology as a single element summarising the day and its logged signals; expanding MUST expose the individual check-ins.
- **FR-018**: All visual values (color, type, spacing, corner radius) MUST come from the shared design system, not ad-hoc per-view values.
- **FR-019**: Auto-expand-on-selection MUST be a user-controllable setting, default ON. When off, selecting a date scrolls to that day without opening it (the day can still be opened by a header tap).
- **FR-020**: The medication-phase ring MUST carry its numeric percentage beneath it as the redundant, non-color readout (arc length + % text), so the ring's value survives greyscale without a patterned fill.

### Key Entities *(include if feature involves data)*

- **Day**: a calendar date with its set of check-ins and a derived average mood used to wash the card. Drives the folded summary (whose medication name is taken from the day's most-recent check-in) and the expand target.
- **Check-in**: a single logged moment within a day — time, optional mood, energy, focus, medication(s), feelings, side-effects, and a medication-phase percentage at that time. Any field may be absent (partial check-in). *Terminology: "check-in" is the user-facing name; the code source-of-truth is the `Recording` model (and `day.nodes` in the view-model). FRs use "check-in" to mean a `Recording`.*
- **Signal level**: mood / energy / focus expressed on a 1→5 scale, each with a name and a glyph whose shape + hue + fill encode the level (defined in spec 006, reused).
- **Medication**: identified by name (folded line) and name + dose (expanded chip); its dose-phase percentage is surfaced, not newly computed here.
- **Selected date**: the date currently in focus; determines which day is top-and-expanded and which more-recent days are filtered from the list / greyed in the row.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can state a day's mood, energy, focus, and medication from the folded card alone, without opening it and without scrolling inside the card.
- **SC-002**: Opening a day reveals its check-ins in a single tap, and collapsing returns to the folded summary in a single tap.
- **SC-003**: Selecting a date brings that day to the top, expanded, in one action, with more-recent days removed from the list.
- **SC-004**: With the display desaturated, every signal level is still correctly identifiable from shape and fill alone.
- **SC-005**: At the largest standard Dynamic Type size, all card text remains legible (no text clipped to illegibility).
- **SC-006**: For a quiet or partial day, no element communicates failure, lateness, a streak, or a score.
- **SC-007**: A partial check-in shows only the signals that were logged — zero empty or placeholder slots appear.
- **SC-008**: The medication bar, calendar row, and day list keep the same vertical order across all data states (no reshuffle).

## Assumptions

- **Source of truth**: `mockups/summary/index.html` (2026-06-22), with `mockups/folded-card-final/` and `mockups/prototype/` as supporting artifacts; this satisfies the constitution's "HTML mockup precedes SwiftUI" rule (Principle I).
- **Expand model** (resolved 2026-06-23 from the interactive prototype, see Clarifications): a card-header tap toggles that card independently and multiple cards may be open at once; selecting a date collapses all open cards then opens only the selected day (when auto-expand is on, default ON). See FR-005, FR-009, FR-019.
- **Reused, not redesigned**: the signal-glyph language (sprout / lightning / aperture + medication capsule) and the 1→5 signal scales come from spec 006 unchanged; the Paper & Pollen palette and type identity come from `DESIGN.md` / spec 008 unchanged. This feature changes card structure and interaction only.
- **Medication-phase percentage** is already derived for the medication bar and is surfaced in the check-in ring; this feature does not introduce new pharmacokinetic calculation.
- **Calendar grid** is otherwise unchanged except the two stated changes: no ring around today, and more-recent days greyed on selection.
- **Out of scope**: medication-bar internals, the feelings / side-effects catalog, and check-in creation/editing (the Edit sheet is owned by 008 / §07).
- **Relationship to 008**: this spec supersedes any day-card assumptions in 008-mockup-parity; 008 stays the authority for shared visual tokens. The two ship as separate, independently revertable PRs.
