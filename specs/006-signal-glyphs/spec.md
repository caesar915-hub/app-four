# Feature Specification: Paper & Pollen signal glyphs

**Feature Branch**: `feat/signal-glyphs`

**Created**: 2026-06-17

**Status**: Draft

**Input**: User description: "Implement the canonical Paper & Pollen signal glyphs (sprout · lightning · aperture · bed · horizontal capsule) as level-driven SwiftUI Shapes, replacing the SF Symbols the app currently uses everywhere signals render."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Signals read as the Paper & Pollen glyphs in the timeline (Priority: P1)

When the user opens Calendar and reads a day's check-ins, each entry shows the Mood / Energy / Focus / Medication signals as the designed glyphs — Mood = sprout, Energy = lightning, Focus = aperture, Medication = capsule — and the glyph's form communicates the 1→5 level at a glance, beside its word.

**Why this priority**: The timeline is the primary read surface and the place the current SF Symbols (`sparkles`/`bolt.fill`/`target`/`pills.fill`) most visibly betray the "no SF, no generic icons" identity. Replacing them here delivers the identity win on its own.

**Independent Test**: Open Calendar on a day with check-ins; confirm every signal renders as the custom glyph (not an SF Symbol) and that a high-level entry visibly differs in glyph form from a low-level one with color ignored.

**Acceptance Scenarios**:

1. **Given** a check-in with Energy = 4 (Alert), **When** the entry renders in the timeline, **Then** it shows the lightning glyph at its level-4 form beside the word "Alert", not `bolt.fill`.
2. **Given** two entries with Focus = 1 and Focus = 5, **When** both render, **Then** their aperture glyphs are distinguishable by shape alone (grayscale), not only by hue.
3. **Given** a check-in with a logged dose, **When** the entry renders, **Then** the medication chip shows the horizontal capsule glyph in medication purple.

---

### User Story 2 - Setting and correcting a level with the glyph picker (Priority: P1)

In Type-note and the Edit sheet, the user sets or corrects Mood / Energy / Focus by tapping a row of the signal's glyph at levels 1→5; the current level is ringed in the bronze accent and shown as a named level plus a synonym line.

**Why this priority**: The glyph is the input control, not just a readout. Low-friction correction trains the personal lexicon; the picker is used on every manual check-in and every correction.

**Independent Test**: Open the Edit sheet, tap level 2 then level 5 on the Mood row; confirm the ring moves, the glyph form changes per level, and the label updates ("5 · Great — bright, thriving").

**Acceptance Scenarios**:

1. **Given** the Mood picker at level 3, **When** the user taps the level-5 glyph, **Then** the ring moves to level 5 and the label reads the level-5 name + synonym.
2. **Given** the Focus picker, **When** displayed, **Then** all five aperture glyphs render in the focus ramp and the current one is ringed in accent.

---

### User Story 3 - Reading the glyph ramps in Insights (Priority: P2)

In the Insights signals section, each dimension shows its glyph rendered across levels 1→5 as an ordinal ramp the user can read back; Sleep shows "not tracked yet".

**Why this priority**: Reinforces the same vocabulary on the review surface; lower frequency than capture/correction.

**Independent Test**: Open Insights → signals; confirm Mood/Energy/Focus each render a 1→5 glyph ramp and Sleep shows the deferred state.

**Acceptance Scenarios**:

1. **Given** the Insights signals section, **When** it renders, **Then** Mood/Energy/Focus each show five glyphs in ascending level form, and Sleep shows the bed icon with "not tracked yet".

---

### User Story 4 - Accessible and legible at every size (Priority: P2)

Every glyph stays distinguishable (by signal and by level) in grayscale and for colorblind users, remains legible from the smallest timeline size up through large Dynamic Type, and is announced by VoiceOver as its signal and named level.

**Why this priority**: The audience (ADHD adults) and the triple-redundant encoding rule make accessibility a correctness requirement, not a nicety — but it can be verified once the glyphs exist.

**Independent Test**: Enable grayscale + a large Dynamic Type size + VoiceOver; confirm levels remain distinct, nothing clips, and VoiceOver reads "Energy, Alert, 4 of 5".

**Acceptance Scenarios**:

1. **Given** display set to grayscale, **When** any signal ramp renders, **Then** each of the five levels is distinguishable from its neighbors by shape + fill alone.
2. **Given** VoiceOver on, **When** focusing a glyph, **Then** it announces the signal name and the named level.

---

### Edge Cases

- A signal with **no recorded level** (absent) must render a clear empty/placeholder state, never a misleading level-1 glyph.
- **Sleep** has no 1→5 level yet — it renders a single bed icon and never appears on a level ramp.
- **Medication** is a chip (single capsule), never rendered on the 1→5 ramp.
- A **level outside 1–5** (data error) must clamp safely, not crash or draw nothing.
- **Dark mode**: glyphs use the dark-variant hues and stay legible on loam.
- **Smallest size (~18–22px)** and **Dynamic Type XXL**: glyphs scale without clipping or becoming an indistinct blob.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST render **Mood** as a sprout glyph whose crown grows/opens across levels 1→5.
- **FR-002**: System MUST render **Energy** as a lightning-bolt glyph that grows and fills across levels 1→5.
- **FR-003**: System MUST render **Focus** as an aperture glyph (scattered dashed ring at low → tight concentric rings + sharp center at high) across levels 1→5.
- **FR-004**: Each self-state glyph (Mood/Energy/Focus) MUST encode its level by **shape + hue + fill simultaneously**, remaining distinguishable with hue removed (grayscale) and for colorblind users.
- **FR-005**: System MUST render **Sleep** as a single bed icon that does not vary by level (ramp deferred), in cool indigo `#5566A6` (light) / `#8090C8` (dark).
- **FR-006**: System MUST render **Medication** as a single **horizontal two-tone capsule** in medication purple `#7E5CA8` (light) / `#9277BE` (dark), shown as a chip and never on a 1→5 ramp.
- **FR-007**: The new glyphs MUST replace the current SF Symbols for signals **everywhere they appear**: Calendar timeline tags, the mood/summary banners, the ADHD summary section, the signal pickers (Type-note + Edit), the Insights signals ramps, and the recording-detail signal summary.
- **FR-008**: The **Mood icon is fixed** (sprout). No user-selectable mood-icon set.
- **FR-009**: Glyphs MUST use the existing signal ramp colors (Mood Meadow·Burnt, Energy Lemon, Focus Voltage blue) — ramps are unchanged.
- **FR-010**: The signal picker MUST present a tappable row of the glyph at levels 1→5, with the current level ringed in the bronze accent and a label showing the named level + a synonym (Mood/Energy/Focus).
- **FR-011**: Glyphs MUST be legible at timeline size (~22px) and scale with Dynamic Type without clipping.
- **FR-012**: Each glyph MUST expose a VoiceOver label of the form "{Signal}: {named level}, {n} of 5" (Sleep/Medication: signal name only).
- **FR-013**: No emoji faces anywhere.
- **FR-014**: Glyphs MUST render correctly in both light and dark appearance.
- **FR-015**: An absent/unknown level MUST render a clear empty state, and an out-of-range level MUST clamp without crashing.

### Key Entities

- **Signal dimension**: one of Mood, Energy, Focus, Sleep, Medication. Determines glyph shape and hue family.
- **Signal level**: ordinal 1–5 for Mood/Energy/Focus (absent allowed); not applicable to Sleep/Medication (single icons).
- **Glyph**: the level-driven vector form for a signal, plus its accessibility label.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For each self-state signal, all five levels are visually distinguishable from their neighbors with color removed (grayscale) at ~22px.
- **SC-002**: At ~22px, each signal's glyph is distinguishable from the other signals' glyphs.
- **SC-003**: 100% of signal renderings across Calendar, Check-in/Type-note, Insights, Edit, and Recording detail use the Paper & Pollen glyphs — zero SF Symbols remain for Mood/Energy/Focus/Sleep/Medication.
- **SC-004**: Glyphs render without clipping from the smallest in-app size (~18px) through Dynamic Type accessibility-XXL.
- **SC-005**: VoiceOver announces every glyph's signal and (where applicable) named level.
- **SC-006**: No emoji faces appear anywhere in signal rendering.

## Assumptions

- Glyphs are pure SwiftUI drawing (Shapes/Views parameterised by level); **no new dependencies**.
- The existing `SignalLevel` type and `Palette+Signals` ramp colors are reused; ramps are not changed.
- The medication **dose-progress bar** (`MedicationBarOverlay`) is a separate component and is **out of scope** here (only the capsule *glyph* used as a chip is in scope).
- The **Sleep 1→5 ramp** is out of scope (deferred — single bed icon now).
- Calendar layout is unchanged; only the icons used inside it change.
- Constitution **Principle X**: glyph Shapes/Views are SwiftUI views → verified by build + simulator render, not unit tests; any pure level→geometry helper that is *not* a View is implemented test-first.
- Exact glyph geometry follows the canonical generators in `docs/superpowers/plans/2026-06-16-design-decisions-ALL.html` and DESIGN.md §Iconography.
