# Feature Specification: Screen design parity (Paper & Pollen)

**Feature Branch**: `feat/screen-parity`

**Created**: 2026-06-17

**Status**: Draft

**Input**: Bring the live SwiftUI screens back into visual parity with the canonical design mockup `design-system-20260615/squirl-design-system.html` (§04–07). A visual rework of existing, working screens — preserve all function.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Check-in screen matches the design (Priority: P1)

The Check-in tab — the screen the user opens most — looks like the mockup across its three states: **Idle** (uppercase date, a Fraunces "Ready when you are." greeting, a 130-pt breathing crescent that fades green→amber, a green→amber gradient "Speak check-in" pill, two hairline ghost secondaries "Log meds"/"Type note", a medication overlay pill when a dose is active, and the bottom tab bar); **Listening** (a mono live timer with a pulsing record dot and an ✕ to cancel, a rotating Fraunces nudge, a thin progress bar with prompt dots, the spinning crescent, and a single dark "Stop & save" pill — no idle buttons); **Saved** (a gradient checkmark circle that pops once, "Captured." in Fraunces, a calm subtitle, a "Done" primary plus a "Check in again" ghost — and nothing else, no transcribing UI).

**Why this priority**: It's the home of the daily loop and the most-seen surface; its three states carry the whole "calm, effortless" identity.

**Independent Test**: Launch the app to Check-in and screenshot each state; compare against the mockup's §05 — type, crescent, buttons, spacing, and colors match in light and dark.

**Acceptance Scenarios**:

1. **Given** the Idle hub, **When** it renders, **Then** the greeting is Fraunces, the crescent is the green→amber conic arc breathing, the primary is the gradient pill, and the two secondaries are hairline ghosts.
2. **Given** an active medication dose, **When** Idle renders, **Then** a purple medication overlay pill sits above the actions.
3. **Given** Listening, **When** it renders, **Then** the nudge is a centered Fraunces line, the crescent spins, and the only action is the dark "Stop & save" pill.
4. **Given** Saved, **When** it renders, **Then** the gradient checkmark pops, "Captured." is Fraunces, and only Done + "Check in again" show — no card, no transcribing UI.

---

### User Story 2 - Recording detail matches the design (Priority: P1)

Opening a check-in from the Calendar shows the detail page like the mockup §07: a top bar with a ⋯ menu and the uppercase date and **no back button**; a Fraunces title; a mono meta line; a row of the signal glyphs as a summary; a Summary card with an ↻ regenerate control and a bulleted list (green bullet dots); a Meds card (capsule glyph + names); an Audio card with a gradient play button and a waveform **last**; and a green→amber gradient "Edit check-in" button.

**Why this priority**: It's the primary read surface after the timeline, and its order/structure is a locked design decision.

**Independent Test**: Open a recording's detail and screenshot; compare section order, card styling, the no-back-button bar, and the gradient buttons against §07.

**Acceptance Scenarios**:

1. **Given** the detail page, **When** it renders, **Then** there is no back chevron (swipe-left to go back), the title is Fraunces, and the audio player is the last card before "Edit check-in".
2. **Given** the summary card, **When** it renders, **Then** it carries an ↻ regenerate control and green-dotted bullets.

---

### User Story 3 - Edit sheet matches the design (Priority: P2)

"Edit check-in" opens one scrolling sheet like §07: a grab handle and a sticky header (Cancel / "Edit check-in" / Save in accent); numbered fields — **01 When** (date/time boxes), **02–04 Mood/Energy/Focus** glyph pickers each showing the current named level + synonym, **05 Sleep** (named scale + hour presets + a custom-hours input), **06 Medications** (a chip grid; a selected med expands inline with dose pills, a duration box, and an info-time line), **07 Feelings** and **08 Side-effects** chip groups; and a gradient "Save corrections".

**Why this priority**: Correcting extractions trains the lexicon; the sheet is detailed and must feel orderly.

**Independent Test**: Open Edit and screenshot; verify the numbered fields, the glyph pickers with name+synonym, the inline-expand med card, and the sticky header against §07.

**Acceptance Scenarios**:

1. **Given** Edit, **When** it renders, **Then** the header is sticky with Cancel/title/Save, and fields are numbered 01–08 in order.
2. **Given** a selected medication, **When** it expands, **Then** dose pills, a duration box, and an info-time line appear inline.

---

### User Story 4 - Type-note matches the design (Priority: P2)

"Type note" opens the composer like §06 Layout A: a small navbar (✕ + "Type a check-in"), the **signals-first** glyph pickers (mood/energy/focus), a note box with the prompt "Anything you want to remember about today?", and a gradient "Save check-in".

**Independent Test**: Open Type-note and screenshot; verify the navbar, the glyph pickers first, the note box, and the gradient save against §06.

**Acceptance Scenarios**:

1. **Given** Type-note, **When** it renders, **Then** the glyph pickers appear before the note field, and the save is a gradient pill.

---

### User Story 5 - Insights matches the design (Priority: P2)

Insights looks like §06: a Fraunces "Insights" title with a "today vs your usual" subtitle, signal rows read back with the glyphs, Sleep shown as a "not tracked yet" deferred chip, in a 5-section snapping scroll.

**Independent Test**: Open Insights and screenshot; verify the Fraunces title, glyph-led signal rows, and the deferred Sleep chip against §06.

**Acceptance Scenarios**:

1. **Given** Insights, **When** it renders, **Then** the title is Fraunces and Sleep shows a dashed "not tracked yet" chip.

---

### User Story 6 - Medication bar matches the design (Priority: P3)

The medication overlay bar looks like §04: a capsule glyph, the med name and a bold state label, a single purple bar that **fills empty→full** over the dose with a gentle onset pulse, and a mono sub-line — never red, never alarming.

**Independent Test**: With an active dose, screenshot the bar; verify the capsule glyph, the single purple fill, and the calm styling against §04.

**Acceptance Scenarios**:

1. **Given** a dose just taken, **When** the bar renders, **Then** the fill is near-empty and pulses ("kicking in"); worn off, it goes quiet — no red.

---

### Edge Cases

- **Dark mode**: every screen uses the dark token set (loam, not black) and stays legible.
- **Dynamic Type**: text scales without clipping or breaking the layout; fixed-by-design elements (banner, crescent) hold their size.
- **Real vs mockup data**: the mockup is a fixed sample; live screens use real recordings/levels and must keep the design's structure with variable content (long titles truncate, empty sections hide).
- **Empty states**: a screen with no data (no recordings, no signals) degrades gracefully and still reads as the design.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The **global visual tokens** MUST match the mockup: background `#F6F1E7`, surface `#FCF8EF`, surface-2 `#EFE8D8`, ink `#221E16`, muted `#7A7361`, hairline `#E3DAC7`, green `#5F8A4C`, amber `#E0A33A`, accent bronze `#B8842A`, medication `#7E5CA8` (+ the dark variants), with Fraunces (display) / DM Sans (body) / IBM Plex Mono (data).
- **FR-002**: Primary actions MUST be a **green→amber gradient pill**; secondary actions a **hairline ghost pill**; cards MUST be surface + hairline + soft shadow, radius 14–18.
- **FR-003**: **Check-in** MUST match §05 across Idle, Listening, and Saved (per US1).
- **FR-004**: **Recording detail** MUST match §07 (no back button, Fraunces title, signal-glyph summary, Summary/Meds/Audio cards in order, audio last, gradient Edit button).
- **FR-005**: **Edit sheet** MUST match §07 (grab handle, sticky Cancel/title/Save, numbered fields 01–08, glyph pickers with name+synonym, inline-expand med card, gradient Save).
- **FR-006**: **Type-note** MUST match §06 Layout A (navbar, signals-first glyph pickers, note box, gradient Save).
- **FR-007**: **Insights** MUST match §06 (Fraunces title, glyph-led signal rows, deferred Sleep chip, snapping scroll).
- **FR-008**: **Medication bar** MUST match §04 (capsule glyph, single purple fill empty→full, onset pulse, never alarms).
- **FR-009**: The **Calendar** MUST be left unchanged (owner-preferred).
- **FR-010**: The already-built **signal glyphs** (`SignalGlyph`) MUST be used and MUST NOT be reverted; **Mood icon stays fixed = sprout** (no user-selectable set); no emoji faces anywhere.
- **FR-011**: All screens MUST render correctly in **light and dark**.
- **FR-012**: All existing **functionality MUST be preserved** — recording, transcription, SwiftData persistence, navigation, medication logic — and the existing test suite MUST stay green.
- **FR-013**: The **motion** MUST match: crescent breathe (idle) → spin (listening) → settle (saved); checkmark pop on save; medication onset pulse; honor Reduce Motion.

### Key Entities

- **Screen** — one of: Check-in (Idle/Listening/Saved), Type-note, Insights, Recording detail, Edit sheet, Medication bar. Each has a target appearance defined by its design-system section.
- **Design token** — the shared color/type/spacing values that every screen draws from.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Each in-scope screen, screenshotted on the simulator, is visually faithful to its design-system section — type, color, layout, spacing, and components match (judged side-by-side against the mockup), in both light and dark.
- **SC-002**: Zero functional regressions — the existing **249-test suite stays green**, and recording/transcription/medication/navigation all still work.
- **SC-003**: No raw `.purple`/`.orange`/system-blue or SF-symbol signal icons remain in the reworked screens; all color comes from the shared tokens and all signals from `SignalGlyph`.
- **SC-004**: Every reworked screen is legible and correctly themed at the default size in light and dark, and does not clip at larger Dynamic Type sizes.
- **SC-005**: Motion matches the design (crescent states, checkmark pop, onset pulse) and collapses gracefully under Reduce Motion.

## Assumptions

- The design HTML is the **visual source of truth**; "match" means as faithful as SwiftUI allows for a live, dynamic app (the mockup is a fixed-size, fixed-data snapshot — real content varies, dark mode and Dynamic Type adapt).
- Screens are **reworked in place** (the existing files), preserving their data flow and view-models; this is not a from-scratch rebuild.
- The shared design tokens already largely exist in `DesignSystem/` (`Palette`, `Typography`, `Spacing`, `Radius`, `Theme`); gaps are filled there, not hard-coded per view.
- **Calendar** and the medication **dose math** are out of scope (Calendar unchanged; only the bar's *appearance* changes).
- The onboarding screen (the stale "Whisper Notes" first-run) is **out of scope** unless trivially in the way.
- Constitution applies: SwiftUI views are verified by build + on-simulator screenshot (Principle I/II); any pure helper added is test-first (Principle X).
