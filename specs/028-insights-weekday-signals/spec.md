# Spec 028 — Insights Weekday Signal Strips

## Problem

The Insights §2 signal strips show one bead per calendar day in a horizontally scrollable row. A month with 30 days produces 30+ beads — too dense to see patterns, and scrolling within a paging section creates friction. Users want to know "how are my Mondays?" not "what happened on June 3rd?".

## Solution

Collapse each signal strip to 7 fixed weekday slots (Mo–Su). Each slot shows the signal glyph coloured by the arithmetic mean of all recordings on that weekday during the current month. A weekday with no recordings shows a dashed placeholder. No scroll — all 7 slots fit in one row.

## Mockups

- `html-mockups/signal-strips-weekday.html` — focused weekday strip mockup
- `html-mockups/insights-reference.html` — §2 in context (page 2)

## User Stories (P1)

- As a user I see 7 fixed glyph slots (Mo–Su) per signal strip — no horizontal scroll.
- Each glyph colour encodes the average signal level for that weekday across the current month.
- A weekday with no recordings shows a dashed placeholder glyph.
- The section subtitle reads "Average by weekday — this month".

## Out of Scope

- Tap-to-drill-down on weekday slots (non-interactive in this design).
- Sleep strip (remains deferred — separate dashed chip unchanged).

## Constitution Check

| Principle | Status |
|-----------|--------|
| I. SwiftUI-First | ✅ Pure SwiftUI |
| II. Test-Build-Ship | ✅ Unit tests required for averaging logic |
| III. Correctness Over Speed | ✅ Deterministic arithmetic mean + rounding |
| IV. Minimal Surface | ✅ Additive: `weekdayLabel` field + new computed property |
| V. Solo Git Discipline | ✅ `feat/028-weekday-signals` off `main` |
| VI. On-Device Privacy | ✅ No data leaves the device |
| X. Test-First | ✅ Tests written before `weekdaySignalStrips` implementation |
