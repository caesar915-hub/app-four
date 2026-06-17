# Implementation Plan: Screen design parity (Paper & Pollen)

**Branch**: `feat/screen-parity` | **Date**: 2026-06-17 | **Spec**: [spec.md](spec.md)

## Summary

Rework the live SwiftUI screens **in place** to match `squirl-design-system.html` §04–07 — Check-in (3 states), Type-note, Insights, Recording detail, Edit sheet, Medication bar — preserving all function. **Token-first**: align the shared `DesignSystem` (Palette / Typography / Theme / Buttons / Radius / Spacing) to the mockup so corrections propagate, then bring each screen's structure/styling to match. Verify every screen by build + on-simulator screenshot diffed against the mockup, in light + dark. The signal glyphs (feature 006) stay; Mood = sprout fixed.

## Technical Context

**Language**: Swift 6 · **UI**: SwiftUI, iOS 26 · **Deps**: none new
**Storage**: N/A (UI rework; reads existing models) · **Testing**: build + simulator screenshot per screen (Principle I/II); Swift Testing for any pure helper (Principle X)
**Project type**: single iOS app (`app-four/`) · **Perf**: 60fps; animations match the mockup
**Constraints**: light + dark parity; Dynamic Type no-clip; Reduce Motion; preserve the 249-test suite
**Scope**: 6 screen areas + the shared `DesignSystem` tokens; ~10–14 view files

## Constitution Check

- [x] **I. SwiftUI-First** — pure SwiftUI; the HTML mockup IS the design source. PASS.
- [x] **II. Test-Build-Ship** — each screen build + sim-verified; suite stays green. PASS.
- [x] **III. Correctness Over Speed** — replace ad-hoc styling with tokens; remove raw color/spacing literals, no shims. PASS.
- [x] **IV. Minimal Surface** — rework existing views; centralize in `DesignSystem`; no new abstractions beyond shared style helpers. PASS.
- [x] **V. Solo Git Discipline** — one feature on `feat/screen-parity` (off the glyph work); `/code-review` before merge. PASS.
- [x] **VI–IX** — UI only; no data leaves device, no extraction/service/schema change. N/A.
- [x] **X. Test-First** — views exempt (build+sim); any pure helper (e.g. crescent phase math) is test-first. PASS.

No violations → no Complexity Tracking.

## Project Structure

```text
app-four/DesignSystem/
  Palette.swift · Palette+Signals.swift · Typography.swift · Theme.swift
  Buttons.swift · Card.swift · Radius.swift · Spacing.swift · CrescentRing.swift   # token + shared-style alignment
app-four/Views/
  CheckIn/CheckInView.swift · CheckIn/CrescentRing.swift · CheckIn/TextCheckInComposer.swift
  Insights/*                       # title, signal rows, deferred sleep
  RecordingDetailView.swift · Components/RecordingRow.swift · Components/TimelineRow.swift
  ExtractionReviewView.swift
  DesignSystem/MedicationBarOverlay.swift
```

**Structure decision**: token-first then per-screen. Phase A aligns the shared tokens/buttons/cards/typography to the mockup (one source of truth). Phases B–G rework one screen each against its §, building + screenshotting each before the next.

## Phases

- **A. Tokens** — align Palette/Typography/Theme/Buttons/Card/Radius/Spacing to the mockup CSS (the `:root` + dark vars, the gradient pill, ghost pill, card shadow). Fixing these propagates to every screen.
- **B. Check-in (§05, P1)** — Idle/Listening/Saved + CrescentRing states.
- **C. Recording detail (§07, P1)**.
- **D. Edit sheet (§07, P2)**.
- **E. Type-note (§06, P2)**.
- **F. Insights (§06, P2)**.
- **G. Medication bar (§04, P3)**.
- **H. Polish** — full suite green, light+dark + Dynamic Type pass, DEVLOG/BACKLOG, `/code-review`.

## Complexity Tracking
*None.*
