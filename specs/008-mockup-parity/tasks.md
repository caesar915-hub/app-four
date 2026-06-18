# Tasks: Mockup-Exact Visual Parity

**Feature**: `specs/008-mockup-parity/` · **Branch**: `feat/screen-parity`
**Inputs**: [plan.md](plan.md) · [spec.md](spec.md) · [research.md](research.md) (token map) · [data-model.md](data-model.md) · [contracts/ui-parity.md](contracts/ui-parity.md) · [quickstart.md](quickstart.md)

**Rules (every task):** mockup = truth; unshown = untouched; no logic change; **tokens only, no literals in views** (use the [research.md](research.md) token map); keep glyphs; §03b & Calendar untouched; build + light/dark screenshot-verify each screen; keep the suite green.

---

## Phase 1: Setup

- [X] T001 Confirm baseline is clean at `91b0fd0` and the [research.md](research.md) token-mapping table is the authority for all radius/type/spacing/color choices (no literals in views).

## Phase 2: Foundational (blocks US1 + US3)

**The shared glyph ramp and the one sanctioned model hook. Must complete before the Edit sheet (US1) and Type-note (US3).**

- [X] T002 [P] Create the shared `GlyphRampPicker<Level>` in app-four/Views/Components/GlyphRampPicker.swift — bare 1→5 glyph ramp (`SignalGlyph`), selected glyph wrapped in a `Radius.control` accent ring (lineWidth 1.5), `Spacing.m` gaps, tap-to-toggle, `.isSelected` a11y trait. Tokens only.
- [X] T003 [US1] Add `var durationHours: Double?` (default nil) to `MedEvent` in app-four/Services/NoteExtraction/NoteExtraction.swift — additive, backward-compatible Codable (per [data-model.md](data-model.md)).
- [X] T004 [US1] Write the RED test app-fourTests/Models/MedEventDurationTests.swift: a `MedEvent(durationHours: 5)` materialized via `Recording.setMedicationEvents` produces a `MedicationEvent.durationHours == 5`; a nil `durationHours` falls back to the catalog/default. Confirm it FAILS first (Principle X).
- [X] T005 [US1] Wire per-med duration in `Recording.setMedicationEvents` (app-four/Models/Recording.swift): `med.durationHours ?? durationHours ?? MedicationCatalog.entry(matching: med.name)?.durationHours ?? 10.0`. Make T004 GREEN.
- [X] T006 [US1] In app-four/ViewModels/ExtractionReviewViewModel.swift: add `setMedDuration(_:hours:)`, change `setMedDose`/`toggleMedTaken`/`setMedDuration` to look up the row **by name** (not value equality), and seed `addMedication` dose+duration from `MedicationCatalog`.

**Checkpoint**: build green; T004 GREEN; `GlyphRampPicker` compiles.

---

## Phase 3: US1 — Edit sheet matches §07 (Priority: P1) 🎯 MVP

**Goal**: `ExtractionReviewView` matches the §07 Edit sheet exactly. **Independent test**: open the Edit sheet on the sim, diff every field vs §07 in light + dark.

- [X] T007 [US1] Rework app-four/Views/ExtractionReviewView.swift scaffold: hairline-separated **fields** (not `.sectionCard()` cards) on `Theme.background`; sticky toolbar Cancel / Fraunces "Edit check-in" / accent Save; one `save()` path; gradient "Save corrections" at the bottom. Tokens only.
- [X] T008 [US1] 01 When: two Date/Time boxes (`Theme.cardBackground` + `Theme.separator`, `Radius.control`) wrapping compact DatePickers; label left, value right.
- [X] T009 [US1] 02/03/04 Mood/Energy/Focus: replace the segmented `scaleRow` with `GlyphRampPicker` (bare glyphs + ring); move the current **name · synonym** onto the field header (name `Theme.accent`, synonym `Theme.textSecondary`); bridge `viewModel.mood/energy/focus` via `Binding`s.
- [X] T010 [US1] 05 Sleep: header = bed glyph + "05 Sleep" + muted "no synonyms"; named segmented pills Restless→Deep (selected = `Palette.sleepIndigo` tint, `Radius.control`); hour presets 2/4/6/8/10h + a custom-hours `TextField`.
- [X] T011 [US1] 06 Medications inline-expand: each selected med = a card (`Radius.card`, `Palette.medication` hairline) with capsule + name + purple "Taken" pill + × remove; a `Grid` of Dose (selectable dose pills from `MedicationCatalog`) / Time ("08:00 · info") / Dur (editable duration box bound to `durationHours`, defaulted to shortest, "shortest" label); below, a `FlowLayout` of stimulant add/remove chips + the helper line. Tokens only.
- [X] T012 [US1] 07 Feelings / 08 Side effects: numbered hairline fields with the existing `Chip.filter` groups (unchanged behavior).
- [X] T013 [US1] Build + screenshot the Edit sheet (light + dark) via the temporary root-swap harness; diff vs §07; iterate; revert the harness.

**Checkpoint**: Edit sheet matches §07 in light + dark; suite green.

---

## Phase 4: US2 — Recording detail matches §07 (Priority: P1)

**Goal**: `RecordingDetailView` matches §07. **Independent test**: open a recording detail, diff vs §07 light + dark.

- [X] T014 [US2] Confirm/refine app-four/Views/RecordingDetailView.swift vs §07: no-back navbar (empty left · centered mono date · circular ⋯), 2-line Fraunces title, mono meta, signal-glyph summary row, cards order Summary → Meds → Audio, gradient "Edit check-in". Tokens only; fix any literal.
- [X] T015 [US2] In app-four/Views/Components/ADHDSummarySection.swift make the **Meds card a single line**: capsule glyph + concatenated "Name dose · Name dose" (`Typography.body`); remove the now-dead per-row helpers (`medicationRow`/`changeBadge`/`badge`/`doseText`/`medicationRowLabel`).
- [X] T016 [US2] Confirm app-four/Views/Components/AudioPlayerView.swift + PlaybackWaveformBars.swift match §07 (gradient play disc, accent/hairline waveform, mono time) with tokens only.
- [X] T017 [US2] Build + screenshot the detail (light + dark); diff vs §07; revert harness.

**Checkpoint**: detail matches §07; suite green.

---

## Phase 5: US3 — Type-note matches §06 Layout A (Priority: P1)

**Goal**: `TextCheckInComposer` matches §06 Layout A. **Independent test**: open Type-note, diff vs §06 light + dark.

- [X] T018 [US3] Refactor app-four/Views/CheckIn/TextCheckInComposer.swift: navbar (circular ✕ + Fraunces "Type a check-in" + spacer); three signal rows via `GlyphRampPicker` (semibold name + mono "5 · Great" readout + bare ramp, hairline divider between rows); editable note box (`Theme.cardBackground` + `Theme.separator`, `Radius.card`) with muted placeholder; gradient "Save check-in". No meds/sleep rows. Tokens only.
- [X] T019 [US3] Build + screenshot Type-note (light + dark); diff vs §06; revert harness.

**Checkpoint**: Type-note matches §06; suite green.

---

## Phase 6: US4 — Medication bar matches §04 (Priority: P2)

**Goal**: `MedicationBarView` matches §04. **Independent test**: surface the bar (dose on board), diff vs §04 light + dark.

- [X] T020 [US4] Confirm/refine app-four/Views/Components/MedicationBarView.swift vs §04 (capsule + bold name·dose + purple state word + slim track-fill + onset pulse + mono sub-line; never red); tokens only; fix any literal.
- [X] T021 [US4] Build + screenshot the bar at onset + active (light + dark); diff vs §04; revert harness.

**Checkpoint**: med bar matches §04; suite green.

---

## Phase 7: US5 — Check-in three states match §05 (Priority: P2)

**Goal**: `CheckInView` + `CrescentRing` match §05 (idle/listening/saved). **Independent test**: drive each state, diff vs §05 light + dark.

- [X] T022 [US5] Confirm/refine app-four/Views/CheckIn/CheckInView.swift + CrescentRing.swift vs §05 across all three states (idle hub, listening, saved); tokens only; fix any literal.
- [X] T023 [US5] Build + screenshot each state (light + dark); diff vs §05; revert harness.

**Checkpoint**: check-in matches §05; suite green.

---

## Phase 8: US6 — Insights matches §06 (Priority: P2)

**Goal**: `InsightsView` matches §06. **Independent test**: open Insights with data, diff vs §06.

- [X] T024 [US6] Confirm/refine app-four/Views/InsightsView.swift + Insights/* vs §06 (Fraunces "Insights" + "June · today vs your usual", glyph-ramp readback, dashed "Sleep · not tracked yet" chip); tokens only; fix any literal.
- [X] T025 [US6] Build + screenshot Insights with mock data (light + dark); diff vs §06; revert harness.

**Checkpoint**: Insights matches §06; suite green.

---

## Phase 9: Polish & Cross-Cutting

- [X] T026 Token-cleanliness grep (SC-002) across all reworked view files → zero literal radii/font-sizes/paddings/tracking/colors (sanctioned exceptions only). Fix any stragglers.
- [X] T027 Light + dark + Dynamic Type + Reduce Motion pass across all reworked screens (SC-004).
- [X] T028 Full Swift Testing suite serial → green (SC-003); confirm Calendar + §03b + any unshown element are byte-identical (SC-005).
- [X] T029 Update docs/DEVLOG.md + docs/BACKLOG.md; run code-review on the diff and address findings before the PR.

---

## Dependencies & order

- **Setup (T001)** → **Foundational (T002–T006)** → user stories.
- **T002 (GlyphRampPicker)** blocks **US1 (T009)** and **US3 (T018)**.
- **T003–T006 (duration hook + VM)** block **US1 (T011)**.
- US1–US6 are otherwise independent (different view files) and could be done in any order after Foundational; recommended order = priority (US1 → US2 → US3 → US4 → US5 → US6).
- **Polish (T026–T029)** last.

## Parallel opportunities

- T002 ‖ T003 (different files).
- After Foundational, US2 (detail), US4 (med bar), US5 (check-in), US6 (insights) touch disjoint files and can proceed in parallel with US1/US3 — but each needs the single simulator for its screenshot step, so verification is serial.

## MVP

**US1 (Edit sheet)** is the MVP — it's the screen furthest from the mockup and contains the inline-expand the owner flagged. Foundational + Phase 3 delivers it standalone.

## Implementation strategy

Foundational first (shared ramp + duration hook, test-first). Then one screen at a time, priority order: implement view (tokens only) → build → light/dark screenshot vs mockup → iterate → revert harness → next. Polish (grep + a11y/motion/type pass + suite + docs + review) at the end.
