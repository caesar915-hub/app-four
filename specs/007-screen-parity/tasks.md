# Tasks: Screen design parity (Paper & Pollen)

**Input**: spec.md + plan.md + `squirl-design-system.html` §04–07 (visual source of truth).
**Tests**: SwiftUI views → build + on-sim screenshot vs the mockup (Principle I/II). Any pure helper → Swift Testing first (Principle X). Suite of 249 must stay green.

## Phase A — Shared tokens (propagates to every screen)

- [X] T001 Align `Palette`/`Theme` colors to the mockup `:root` + dark vars (bg `#F6F1E7`, surface `#FCF8EF`, surface-2 `#EFE8D8`, ink `#221E16`, muted `#7A7361`, hairline `#E3DAC7`, green `#5F8A4C`, amber `#E0A33A`, accent `#B8842A`, med `#7E5CA8`).
- [X] T002 Align `Typography` roles to Fraunces (display, +italic) / DM Sans (body/UI) / IBM Plex Mono (data/time), matching the mockup sizes.
- [X] T003 Align shared components: primary = green→amber **gradient pill**, secondary = **ghost** hairline pill (`Buttons.swift`); card = surface + hairline + soft shadow, radius 14–18 (`Card.swift`).
- [X] T004 Build green after token changes (no regressions).

## Phase B — Check-in §05 (P1) 🎯

- [X] T005 `CrescentRing`: 130-pt conic green→amber arc; **breathe** (idle ~5s) / **spin** (listening ~7s) / **settle-to-check** (saved); honor Reduce Motion.
- [X] T006 `CheckInView` Idle: uppercase date · Fraunces "Ready when you are." · crescent · gradient "Speak check-in" · two ghost secondaries · medication overlay pill · tab bar.
- [X] T007 `CheckInView` Listening: mono timer + pulsing rec dot + ✕ · rotating Fraunces nudge · thin progress bar + prompt dots · spinning crescent · dark "Stop & save".
- [X] T008 `CheckInView` Saved: gradient checkmark pop · Fraunces "Captured." · subtitle · "Done" + "Check in again" ghost · no transcribing UI.
- [X] T009 Build + screenshot all 3 states (light + dark) vs §05.

## Phase C — Recording detail §07 (P1)

- [ ] T010 `RecordingDetailView`: ⋯ + uppercase date bar, **no back** · Fraunces title · mono meta · signal-glyph summary row · Summary card (↻ + green-dot bullets) · Meds card · Audio card (gradient play + waveform) **last** · gradient "Edit check-in".
- [ ] T011 Build + screenshot detail (light + dark) vs §07.

## Phase D — Edit sheet §07 (P2)

- [ ] T012 `ExtractionReviewView`: grab handle · sticky Cancel/"Edit check-in"/Save header · numbered fields 01 When · 02–04 glyph pickers (name + synonym) · 05 Sleep scale + hour presets + custom input · 06 Medications chip grid + inline-expand card (dose pills · duration box · info time) · 07/08 chip groups · gradient "Save corrections".
- [ ] T013 Build + screenshot Edit vs §07.

## Phase E — Type-note §06 (P2)

- [ ] T014 `TextCheckInComposer`: navbar (✕ + "Type a check-in") · signals-first glyph pickers · note box ("Anything you want to remember about today?") · gradient "Save check-in".
- [ ] T015 Build + screenshot Type-note vs §06.

## Phase F — Insights §06 (P2)

- [ ] T016 Insights: Fraunces "Insights" + "today vs your usual" · glyph-led signal rows · Sleep "not tracked yet" dashed chip · 5-section snapping scroll.
- [ ] T017 Build + screenshot Insights vs §06.

## Phase G — Medication bar §04 (P3)

- [ ] T018 `MedicationBarOverlay`: capsule glyph · name + bold state label · single purple fill empty→full · onset pulse · mono sub · never alarms.
- [ ] T019 Build + screenshot the bar vs §04.

## Phase H — Polish

- [ ] T020 Full Swift Testing suite serial → green (no regressions, SC-002).
- [ ] T021 Light + dark + Dynamic Type pass across all reworked screens (SC-004); Reduce Motion (SC-005).
- [ ] T022 grep for raw `.purple`/`.orange`/system-blue + hard-coded hexes in reworked screens → tokens (SC-003).
- [ ] T023 Update DEVLOG + BACKLOG; `/code-review` the diff before PR.

## Dependencies
Phase A first (tokens propagate). B–G independent after A (any order; P1 = B, C). H last.
