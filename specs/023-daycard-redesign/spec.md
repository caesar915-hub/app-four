# Feature Specification: DayCard redesign — no-pill rows, no-disc tinted header, push-to-detail

**Feature Branch**: `023-daycard-redesign`

**Created**: 2026-06-25

**Status**: Draft

**Input**: Owner-driven redesign of the Calendar tab's `DayCard` after the existing
card "felt off." Grounded by web research (NN/g, Material, Smart Interface Design
Patterns, Refactoring UI, Polaris, WCAG, Apple HIG) and ~14 true-scale HTML mockup
iterations under `html-mockups/daycard-*`. The final interactive prototype is
`html-mockups/daycard-prototype-v8.html` (folded + expanded, light/dark).

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Read a day's check-ins without pill clutter (Priority: P1)

When a person opens a day, they want to read what happened in each check-in
calmly and quickly — mood, when, how regulated they were, what they took, how
they slept, how they felt, any side effects — without the screen shouting every
datum at equal volume.

**Why this priority**: This is the defect that triggered the redesign. The current
expanded row wraps medication, sleep, emotions, and side-effects each in a rounded
pill — an interactive affordance applied to read-only data — so equal-weight
information competes and nothing recedes. Fixing it is the core value.

**Independent Test**: Expand a day with a rich check-in. Verify there are **no
pill/capsule containers** anywhere in the row, that the data reads as quiet
glyph+text lines, and that the medication line is the only colour-emphasised datum.

**Acceptance Scenarios**:

1. **Given** an expanded day with a check-in that has medication, sleep, two
   emotions and two side-effects, **When** the row renders, **Then** no datum sits
   inside a filled or bordered capsule; medication renders in the medication accent
   colour and sleep in the sleep blue; emotions and side-effects render in a muted
   secondary ink.
2. **Given** a check-in with five or more emotions, **When** the row renders,
   **Then** at most four are shown followed by a "+N" overflow indicator.
3. **Given** a check-in with five or more side-effects, **When** the row renders,
   **Then** at most four are shown followed by a "+N" overflow indicator.
4. **Given** a check-in whose only extra data is a free-text topic, **When** the row
   renders, **Then** the topic is not shown (topics carry no signal here).

### User Story 2 — Scan the mood of each day at a glance (folded) (Priority: P1)

Scrolling the calendar, a person wants to read each day's overall mood and a
one-line summary instantly, and to fit more days on screen.

**Why this priority**: The folded card is what's seen most. The current card is
taller than it needs to be and its mood marker is a cream disc; the redesign drops
the disc, lets the day's mood tint plus a prominent fixed mood glyph carry the
mood, and reduces height.

**Independent Test**: View the calendar list. Verify each folded day is a
mood-tinted card with a prominent mood glyph (no cream disc), a title
(mood · weekday), and a one-line summary; verify the folded card is shorter than
the prior design.

**Acceptance Scenarios**:

1. **Given** a day with check-ins, **When** the card is folded, **Then** it shows a
   mood-tinted background, a fixed-size mood glyph, the title, and a one-line
   summary (energy · focus · medication name), with no cream disc and no full-width
   divider.
2. **Given** a folded day, **When** the user taps it to expand, **Then** the summary
   line disappears and the title settles to vertically centre against the glyph; the
   glyph does not change size.
3. **Given** an empty day, **When** the card is folded, **Then** it shows the date
   and a calm "no check-ins" message, with no mood glyph and no tint.

### User Story 3 — Open a check-in's full detail (Priority: P2)

From an expanded day, a person wants to open the full detail of a specific
check-in (transcript, audio, edit) and get back easily.

**Why this priority**: Detail is a secondary, deliberate action. The right chevron
on each row signals navigation into a page; tapping the row body should do the same.

**Independent Test**: Expand a day, tap a check-in row (anywhere in its content, and
separately the chevron). Verify the Recording Detail opens as a pushed page with a
standard back control, and that returning lands back in the same expanded day.

**Acceptance Scenarios**:

1. **Given** an expanded day, **When** the user taps a check-in row's content,
   **Then** the Recording Detail opens as a pushed page (not a bottom sheet).
2. **Given** an expanded day, **When** the user taps the row's right chevron,
   **Then** the same Recording Detail page opens.
3. **Given** the Recording Detail page, **When** it is shown, **Then** a standard
   back control returns to the calendar with the previously expanded day still open.

### Edge Cases

- Check-in with no mood/energy/focus signals (e.g. only audio) — the row still
  opens detail and shows whatever data exists without empty lines.
- Day with a single bare morning check-in (mood only) — no medication, sleep,
  feeling, or side-effect lines render (no empty placeholders).
- A medication dose still active from earlier (carry-over) — shown on the bead ring
  + % badge, not duplicated as a medication line.
- Dark mode — tint, accent, sleep blue, and muted secondary ink all remain legible.
- Large Dynamic Type / accessibility text sizes — lines wrap rather than truncate
  the leading word; the layout does not rely on `minimumScaleFactor`.
- VoiceOver — each row is one element naming all its data and announcing it opens
  detail.

## Requirements *(mandatory)*

### Functional Requirements

**Expanded check-in row (no pills):**

- **FR-001**: The system MUST render all read-only check-in data as bare glyph+text,
  with NO capsule/pill/filled/bordered container anywhere in the row.
- **FR-002**: Each check-in row MUST present its data in four ordered lines:
  (1) mood word + timestamp + a navigation chevron; (2) energy + focus signals;
  (3) medication (accent colour) + sleep (sleep blue); (4) feelings + side-effects.
- **FR-003**: Sleep MUST appear on line 3 alongside medication, rendered in the
  sleep blue (`Palette.sleepIndigo`), not in the feelings/side-effects line.
- **FR-004**: Line 4 MUST show at most four feelings and at most four side-effects,
  each capped group followed by a "+N" indicator when more exist.
- **FR-005**: Topics MUST NOT be shown on the row (no signal value).
- **FR-006**: Medication MUST be the only colour-and-weight-emphasised datum among
  the read-only data; feelings, side-effects, and sleep recede to a muted tier
  (sleep distinguished only by its blue ink + glyph).
- **FR-007**: The leading category glyphs MUST be: medication
  `capsule.righthalf.filled`, feeling `heart.fill`, sleep `zzz`, side-effect
  `medical.thermometer`; mood/energy/focus keep the existing custom signal glyphs.
- **FR-008**: The row head MUST be vertically positioned toward the top of the
  check-in bead (a "mid-high" optical offset), not centred on it.

**Folded / expanded header:**

- **FR-009**: The folded card MUST show a mood-tinted background, a fixed-size mood
  glyph (no cream disc, no full-width divider), the title (mood word coloured ·
  weekday), and a one-line summary (energy · focus · medication name).
- **FR-010**: The mood glyph MUST stay the SAME size when folded and expanded (it
  does not resize on toggle).
- **FR-011**: On expand, the summary line MUST collapse and the title MUST settle to
  vertical centre against the glyph; on collapse, the reverse.
- **FR-012**: An empty day's folded card MUST show the date + a calm "no check-ins"
  message, with no mood glyph and no tint.
- **FR-013**: Expanding MUST hide the folded summary from the header (the tinted
  strip + title remain as the section header above the timeline).

**Navigation:**

- **FR-014**: Tapping a check-in row's content OR its right chevron MUST push the
  Recording Detail as a navigation page (NOT present it as a bottom sheet).
- **FR-015**: The Recording Detail page MUST provide a standard back control that
  returns to the calendar with the previously expanded day still expanded.

**Quality:**

- **FR-016**: Every informative glyph and the muted secondary ink MUST meet WCAG
  3:1 contrast on the cream card and on the mood-tinted header, in light and dark.
- **FR-017**: Each check-in row MUST be exposed to assistive technology as one
  combined element that names mood, time, energy, focus, medication, sleep,
  feelings, and side-effects, and announces that it opens detail.
- **FR-018**: The redesign MUST NOT introduce any pill/chip component; the existing
  `TimelineChip` component is removed.

### Key Entities *(include if feature involves data)*

- **DayCard**: one calendar day. States: folded (tinted header + summary) and
  expanded (tinted header + timeline of check-ins). Carries the day's
  representative mood (tint + glyph + title colour).
- **Check-in row**: one timestamped recording within a day. Renders a mood bead
  (with optional carry-over medication ring + %) and the four data lines.
- **Data categories** (already extracted, read-only here): mood, energy, focus,
  medication (taken at this instant + carry-over), sleep, feelings, side-effects,
  topics (suppressed).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Zero pill/capsule containers render in any DayCard state (folded,
  expanded, light, dark) — verifiable by inspection and by the absence of the
  `TimelineChip` type in the build.
- **SC-002**: A folded day card with a one-line summary is measurably shorter than
  the prior (disc + divider) design at the default text size.
- **SC-003**: Every check-in row opens the Recording Detail in a single tap from
  either the row content or the chevron, presented as a push.
- **SC-004**: All informative glyphs and muted text in the row meet ≥3:1 contrast on
  cream and on every mood tint, in light and dark (audited via
  `html-mockups/color-contrast-audit.html` parity + on-device check).
- **SC-005**: Line 4 never shows more than four feelings or four side-effects; the
  overflow count is correct for 0, 4, 5, and many.
- **SC-006**: The full test suite stays green (Principle II), with new test-first
  coverage for the capping, sleep-line, and line-composition logic (Principle X).

## Assumptions

- **Dependency — SF typography**: this spec assumes the app has adopted the Apple
  SF system font (SF Pro for text, SF Mono for time/data). That app-wide migration
  is a **separate prerequisite change** (own branch/PR, possibly its own spec) and
  is NOT in scope here; this spec's row/header type sizes assume SF.
- The custom Paper & Pollen palette and `Palette.sleepIndigo` already exist; the
  mood ramp and `MoodLevel` colours are unchanged.
- The Recording Detail view is already built for push presentation (date on nav
  bar, ⋯ menu); this spec switches its caller from sheet to push and restores a
  standard back control.
- The feelings, side-effects, sleep, and medication fields are already extracted by
  the NLP pipeline; this feature only changes their presentation and capping.
- The calendar's day-grouping, month paging, and selection/filter behaviour are
  unchanged.
- Out of scope: changes to the Insights tab, the Check-in capture flow, extraction
  logic, and the calendar week/month header.
