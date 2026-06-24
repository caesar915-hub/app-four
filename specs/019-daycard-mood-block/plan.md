# Implementation Plan: Day-card mood-block redesign (Paper & Pollen #4)

**Branch**: `019-daycard-mood-block` (see Solo Git note) | **Date**: 2026-06-24 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/019-daycard-mood-block/spec.md`

## Summary

Restyle the calendar `DayCard` to the approved mockup ("#4 Divided · Cream disc", `mockups/summary/index.html`). The card's **mood tint moves from the whole-card wash onto the header**, so a folded card reads as one solid mood-tinted block and an expanded card keeps that tint as a strip with the check-in rows dropping onto the cream card surface. The mood glyph moves into a **cream-disc badge**; the **mood word moves up beside the weekday**; a **divider** separates the title from the folded summary. In each expanded row the **mood glyph moves into the medication-phase ring** (the time leaves the bead) and the **timestamp sits inline** after the mood word, with energy/focus ramp glyphs and a trailing **details chevron**. `MoodBanner` (the full-width colored band) is deleted. No data, schema, state-machine, filter-above, auto-expand, or summary-derivation change — presentation only. Generalises across all five moods.

**Technical approach**: edit four existing SwiftUI views (`DayCard`, `FoldedDayCardHeader`, `TimelineRow`, `TimelineBead`), delete one (`MoodBanner`), add a small set of design tokens and one pure mood→tint palette helper (test-first). Reuse `DayCardSummary`, the `ExpandedDayCards` state machine, `SignalGlyph`, the medication-phase ring, and the existing expand animation (already Reduce-Motion-aware).

## Technical Context

**Language/Version**: Swift 6 (strict concurrency)

**Primary Dependencies**: SwiftUI (iOS 26+), the app's `DesignSystem/` tokens (`Theme`, `Palette`, `Metrics`, `Opacity`, `Radius`, `Spacing`, `Typography`, `Motion`), `SignalGlyph`/`GlyphSignal`, `MoodLevel` (+`MoodLevel+Palette`)

**Storage**: SwiftData (unchanged — read-only here; no schema touch)

**Testing**: Swift Testing (`@Test`/`#expect`) for the one new pure helper; existing 014 logic tests (`ExpandedDayCards`, date filter, `DayCardSummary`) must stay green; views verified by build + on-simulator run + mockup parity

**Target Platform**: iOS 26+ (iPhone primary), light + dark, full Dynamic Type, Reduce Motion, greyscale

**Project Type**: Mobile app (single SwiftUI target `app-four`, display name **Squirl**)

**Performance Goals**: 60 fps scroll/fold; no measurable regression in the calendar list (this removes a per-card averageFill pass and a per-row banner fill)

**Constraints**: DesignSystem tokens only (no magic numbers in views); 44 pt tap targets; redundant encoding (shape+hue+fill); no clipped/ellipsised mood word at largest Dynamic Type; light + dark

**Scale/Scope**: 4 views edited, 1 deleted, ~3 new tokens, 1 new pure helper + its test; one screen (Calendar day list) + the day card used there

## Constitution Check

*GATE: passed before Phase 0; re-checked after Phase 1 (below).*

- [x] **I. SwiftUI-First** — all edits are SwiftUI on modern APIs; no UIKit. The HTML mockup (`mockups/summary/index.html`, "#4") precedes this and is the parity reference (Principle I "mockup first" satisfied).
- [x] **II. Test-Build-Ship** — plan ends in a build + full Swift Testing suite run before "done"; nothing ships unverified.
- [x] **III. Correctness Over Speed** — `MoodBanner` and the old whole-card wash are **removed**, not left dead; the relocated time is removed from `TimelineBead`. No shims, no stubs. The one tradeoff (block tinted by *representative* not *average* mood) is surfaced (research R2).
- [x] **IV. Minimal Surface** — reuses existing tokens/derivations; adds only ~3 tokens and one tiny pure helper. No new abstraction, protocol, service, or flag.
- [x] **V. Solo Git Discipline** — one revertable feature; `/code-review` before merge; `main` stays releasable. ⚠️ *Base note*: 014's `DayCard` is unmerged (lives on the `feat/daycard-update` / `feat/ux-improvements-015-017` lineage, not `main`), so 019 MUST branch off that lineage, not bare `main`, or it has no `DayCard` to edit. Recommended branch `feat/019-daycard-mood-block` cut from the current integration branch; flagged as merge-debt to resolve when 014/015–017 land. Not a constitution violation, a sequencing constraint.
- [x] **VI. On-Device Privacy** — N/A in effect: no data leaves the device, no network, no new logging. Purely how existing on-device data is drawn.
- [x] **VII. Deterministic, Measured Extraction** — N/A: does not touch `NLNoteExtractor`, the lexicon, or the eval harness.
- [x] **VIII. Service-Oriented Architecture** — N/A: no new capability/service; no VM logic added. The new mood→tint helper is a pure value mapping on `MoodLevel`, not a service.
- [x] **IX. Pre-Release Data Posture** — N/A: no schema change, no new/required/unique attribute; CloudKit-compatibility untouched.
- [x] **X. Test-First Development** — the only new *logic* (the mood→tint palette mapping) is built test-first (RED→GREEN). The four views are EXEMPT (Principle X) — verified by build + simulator + the mockup. 014's existing logic tests are run and MUST stay green (SC-007).

**Result: PASS** — no violations; Complexity Tracking empty (the Git base note is a sequencing flag, not a justified complexity).

## Project Structure

### Documentation (this feature)

```text
specs/019-daycard-mood-block/
├── plan.md              # this file
├── spec.md              # /speckit-specify output
├── research.md          # Phase 0 — decisions (tint placement, mood source, bead/row, token list)
├── data-model.md        # Phase 1 — "no new data"; reused inputs + new presentation tokens
├── quickstart.md        # Phase 1 — how to build + validate on-sim + mockup parity
├── contracts/
│   └── daycard-ui.md     # Phase 1 — per-state visual/interaction contract mapped to FRs + mockup
├── checklists/
│   └── requirements.md  # spec quality checklist (passed)
└── tasks.md             # Phase 2 — /speckit-tasks (NOT created here)
```

### Source Code (repository root)

```text
app-four/
├── Views/Components/
│   ├── DayCard.swift              # EDIT — tint moves from whole-card wash → header; source average→representative mood
│   ├── FoldedDayCardHeader.swift  # EDIT — cream-disc badge; mood word → title line; folded divider; header mood-block bg
│   ├── TimelineRow.swift          # EDIT — replace MoodBanner with row head (mood word + inline time + ramp glyphs) + trailing details chevron
│   ├── TimelineBead.swift         # EDIT — mood glyph in the ring centre; remove the time from the bead
│   └── MoodBanner.swift           # DELETE — superseded by the row head (no dead code, Principle III)
├── Models/
│   └── MoodLevel+Palette.swift    # EDIT — add pure block/badge tint + word-colour accessors (test-first)
└── DesignSystem/
    ├── Opacity.swift              # EDIT — add moodBlock (~0.22) + moodBadge (~0.50); moodWash retired if unused elsewhere
    └── Metrics.swift              # EDIT — add headerMoodBadge (~42); summary/row metrics as needed

app-fourTests/
└── Components/ (or Models/)
    └── DayCardPaletteTests.swift  # NEW — RED→GREEN for the mood→tint palette mapping (5 levels)
```

**Structure Decision**: Single iOS SwiftUI target (`app-four`). This feature lives entirely in `Views/Components` + `DesignSystem` + one `Models` palette extension, with a matching test file under `app-fourTests`. No new module, directory, or layer.

## Complexity Tracking

> No constitution violations to justify. (The Git-base sequencing note under Principle V is a workflow constraint, not added complexity.)

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |
