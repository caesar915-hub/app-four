# Feature Specification: Mockup-Exact Visual Parity

**Feature Branch**: `feat/screen-parity`

**Created**: 2026-06-17

**Status**: Draft

**Input**: Bring every screen shown in the Squirl "Paper & Pollen" design-system mockup (`~/.gstack/projects/caesar915-hub-app-four/designs/design-system-20260615/squirl-design-system.html`) to **exact visual parity**. Visual-only; the mockup is the single source of truth.

## Governing Rules *(apply to every story)*

1. **Mockup is truth.** If the mockup shows it, build it exactly as shown — layout, structure, type, color, spacing, corner radius, and per-state appearance.
2. **Unshown = untouched.** If the mockup does not show something, leave the existing code exactly as-is. No additions, removals, or "improvements" beyond the mockup.
3. **No logic change.** Data flow, navigation, recording/transcription/medication behavior, and persistence stay exactly as they are. A control that *is* shown but needs a minimal model hook to function (only the Edit-sheet per-med duration box) gets that hook to back the visible control — it must not alter existing behavior, and it is called out, never hidden.
4. **Tokens only.** Views reference existing `DesignSystem/` tokens (`Spacing`, `Radius`, `Typography`, `Theme`, `Palette`) and shared modifiers (`.card()`, `.cardEyebrow()`). No raw literals in views (corner radii, font sizes, paddings, tracking, colors). Each mockup value maps to the nearest existing token; tiny deltas (e.g. radius 16 vs 18) are accepted. A genuinely missing token is a separate DesignSystem decision, never a literal in a view.
5. **Owner exclusions.** The §03b selectable Mood-icon set stays **removed** (Sprout is the one fixed Mood glyph; no Settings picker). **Calendar** stays unchanged (the mockup says so).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Edit sheet matches §07 (Priority: P1)

The owner taps "Edit check-in" and sees the §07 Edit sheet exactly as drawn: a grab handle and sticky **Cancel / "Edit check-in" / Save** header; one scroll of **hairline-separated fields** (not per-field cards), each with a mono number + uppercase label on the left and its current value on the right.

**Why this priority**: It is the screen furthest from the mockup today (segmented fill-box pickers instead of bare-glyph rows; per-field cards instead of hairlines; the inline-expand medication editor does not exist) and it carries the interaction the owner specifically flagged.

**Independent Test**: Open the Edit sheet on the simulator and diff every field against §07 in light and dark.

**Acceptance Scenarios**:

1. **Given** the Edit sheet, **When** it renders, **Then** Mood/Energy/Focus are **bare 1→5 glyph ramps** (no fill boxes) with the selected glyph wrapped in an accent ring, and the current **name + synonym** ("Great · bright, thriving", name accent / synonym muted) sits on that field's header line.
2. **Given** the Sleep field, **When** it renders, **Then** it shows a bed glyph + "05 Sleep" + a muted "no synonyms", a named segmented pill scale Restless→Deep (selected = purple tint), and hour presets 2h/4h/6h/8h/10h **plus a custom-hours text input**.
3. **Given** a selected medication, **When** it renders, **Then** it is an **inline-expand card**: capsule + name + a purple "Taken" pill + an × remove; a Dose row of selectable dose pills from the catalog; a Time row "08:00 · info"; a Dur row with an editable duration box defaulted to the med's shortest, labelled "shortest"; with a wrapping grid of stimulant add/remove chips and the helper line below.
4. **Given** the 01 When field, **When** it renders, **Then** it shows two boxes "Date [15 Jun]" and "Time [16:12]"; **and** the bottom shows a gradient "Save corrections".

---

### User Story 2 - Recording detail matches §07 (Priority: P1)

The owner opens a recording and sees the §07 detail page top-to-bottom: no back button (empty left slot + centered mono date + circular ⋯), two-line Fraunces title, mono meta, a signal-glyph summary row, then **Summary** (↻ + green-dot bullets), **Meds** (capsule + single line "Concerta 36mg · Ritalin 10mg"), **Audio** last (gradient play + waveform), and a gradient "Edit check-in".

**Why this priority**: It is the entry point to the Edit sheet and the most-viewed read screen.

**Independent Test**: Open a recording detail on the simulator and diff against §07 in light and dark.

**Acceptance Scenarios**:

1. **Given** the detail screen, **When** it renders, **Then** the Meds card is a **single line** (capsule + "Name dose · Name dose"), not a per-dose row list.
2. **Given** the detail screen, **When** it renders, **Then** the Audio card is the **last** card and there is no back button or pencil.

---

### User Story 3 - Type-note matches §06 Layout A (Priority: P1)

The owner taps "Type note" and sees Layout A: a custom navbar (circular ✕, centered Fraunces "Type a check-in", balancing spacer); three signal rows (DM-Sans-semibold name + mono "5 · Great" readout + a bare glyph ramp with the selected glyph ringed, hairline divider between rows); an editable note box with the muted placeholder; and a gradient "Save check-in". Signals + note + save only.

**Why this priority**: It is the second capture path and was the screen the owner called out as visibly wrong.

**Independent Test**: Open Type-note on the simulator and diff against §06 in light and dark.

**Acceptance Scenarios**:

1. **Given** Type-note, **When** it renders, **Then** the glyph rows are bare (no fill boxes), the selected glyph is ringed, and each row shows the mono "level · name" readout.
2. **Given** Type-note, **When** it renders, **Then** there are no meds or sleep rows.

---

### User Story 4 - Medication bar matches §04 (Priority: P2)

A dose-on-board bar renders as §04: capsule glyph + bold name·dose, a bold purple state word (kicking in / active / wearing off / worn off), a slim track with a solid-purple fill that grows empty→full, an onset pulse while kicking in, and a mono sub-line — one purple, never red.

**Why this priority**: Largely built; this is a fidelity confirm/refine.

**Independent Test**: Surface the bar on the simulator (a dose on board) and diff against §04 in light and dark.

**Acceptance Scenarios**:

1. **Given** a dose at <12% elapsed, **When** the bar renders, **Then** the state word reads "kicking in", the fill pulses, and the sub-line shows "taken HH:mm · onset".

---

### User Story 5 - Check-in three states match §05 (Priority: P2)

Idle (date + Fraunces greeting + breathing crescent + gradient Speak + ghost Log-meds/Type-note + med overlay when on board), Listening (timer + rec-dot + ✕ + Fraunces nudge + progress bar + 4 dots + revolving crescent + dark Stop & save), and Saved (popping gradient checkmark + "Captured." + Done/Check-in-again, no machinery) each match §05.

**Why this priority**: Largely built (Phase B); fidelity confirm/refine.

**Independent Test**: Drive each state on the simulator and diff against §05 in light and dark.

**Acceptance Scenarios**:

1. **Given** each state, **When** it renders, **Then** it matches the §05 column for that state with no extra chrome.

---

### User Story 6 - Insights matches §06 (Priority: P2)

Insights shows a Fraunces "Insights" title + a muted "June · today vs your usual" subtitle, the existing 5-section snapping scroll, signals read back via the glyph ramp, and a dashed "Sleep · not tracked yet" chip.

**Why this priority**: Mostly built; small additions.

**Independent Test**: Open Insights with data on the simulator and diff against §06.

**Acceptance Scenarios**:

1. **Given** Insights with data, **When** it renders, **Then** the title/subtitle and the dashed Sleep chip are present.

---

### Edge Cases

- A medication that is not in the catalog: the inline-expand shows the name + remove + the existing free-text dose, and omits dose pills / duration box (no catalog data to drive them).
- A recording whose only doses are manual (no transcript meds): the detail Meds card does not render an empty header.
- Reduce Motion on: the med-bar onset pulse and crescent motion collapse to static.
- Dynamic Type at large sizes: text scales via the existing Typography roles without clipping the glyph rows.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Every reworked screen MUST visually match its mockup section (§04–§07) in structure, type, color, spacing, radius, and per-state appearance, in both light and dark.
- **FR-002**: Reworked views MUST reference only existing DesignSystem tokens and shared modifiers; they MUST contain zero raw literal corner radii, font sizes, paddings, tracking values, or colors.
- **FR-003**: The Edit-sheet Mood/Energy/Focus pickers MUST be bare glyph ramps with an accent ring on the selected glyph, and MUST show the current name + synonym on the field header line.
- **FR-004**: The Edit-sheet fields MUST be separated by hairlines (no per-field card backgrounds).
- **FR-005**: The Edit-sheet Sleep field MUST provide a named segmented scale, hour presets, and a custom-hours text input.
- **FR-006**: The Edit-sheet Medications field MUST render each selected med as an inline-expand card (Taken pill, × remove, selectable dose pills from the catalog, info time, editable duration box defaulted to the med's shortest) plus a stimulant add/remove grid.
- **FR-007**: The detail Meds card MUST render as a single capsule + concatenated "Name dose · Name dose" line.
- **FR-008**: Type-note MUST be Layout A only (signals + note + save) with bare glyph rows and the mono "level · name" readout; no meds or sleep rows.
- **FR-009**: The system MUST NOT change any app logic, data flow, navigation, or persistence; the only sanctioned model hook is a per-med duration field that backs the Edit-sheet duration box and does not change existing behavior.
- **FR-010**: The §03b Mood-icon picker MUST remain absent and Calendar MUST remain unchanged.
- **FR-011**: The already-built signal glyphs (SignalGlyph) MUST be preserved (not reverted); no emoji.
- **FR-012**: The full existing test suite MUST stay green (no logic touched; SwiftUI views are exempt per Constitution Principle X).

### Key Entities

- **MedEvent (existing DTO)**: gains one optional `durationHours` field — the only sanctioned model addition — to back the Edit-sheet duration box. Backward-compatible (decodes as nil when absent); does not change extraction or existing behavior.

## Success Criteria *(mandatory)*

- **SC-001**: On-simulator screenshots of §04, §05 (×3 states), §06 (Type-note + Insights), and §07 (detail + Edit sheet) match their mockup sections in both light and dark.
- **SC-002**: A grep of the reworked view files finds zero raw literal radii / font sizes / paddings / tracking / colors (all references go through tokens or shared modifiers).
- **SC-003**: The full Swift Testing suite passes (unchanged count; no logic modified).
- **SC-004**: Light, dark, Dynamic Type, and Reduce Motion all render correctly on the reworked screens.
- **SC-005**: Nothing outside the mockup's scope is changed (Calendar, §03b, and any unshown element are byte-identical to their pre-feature state).

## Assumptions

- The committed screen-parity work (`1b43fac` + `91b0fd0` on `feat/screen-parity`) is the baseline; this feature refines it to exact mockup fidelity rather than rebuilding from scratch.
- The medication catalog (`MedicationCatalog`) is the source for the Edit-sheet dose pills and default durations; its current stimulant set is authoritative (the mockup's longer list is illustrative).
- "Map to existing tokens" (owner decision) governs all radius/type/spacing choices; small pixel deltas from the mockup are acceptable and expected.
- Verification is by build + on-simulator screenshot (light + dark) using the ios-debugger-agent; no XcodeBuildMCP/idb tap tooling is assumed.
