<!-- Created: 2026-07-20 19:10 (WEST) · Updated: 2026-07-20 19:10 (WEST) -->
# Research — Path A Refine (Phase 0)

Most decisions were made by the accepted `a02-a` pilot; this resolves the seven that remain plan-level. Grounding: the 039 inventories, the perceptual audit, the a02-a build log (DEVLOG 2026-07-20), and shipped-code color assignments (spec 033/036 DEVLOG entries).

## D1 — Method: clone-and-refine, not rebuild

**Decision**: Every screen is built by **cloning its original and applying deltas in place** (the a02-a method), named `a0N-a`, beside the original on Screens v3.
**Rationale**: The owner accepted a clone-refined screen and rejected a from-scratch rebuild; cloning preserves identity by construction and makes every delta reviewable. The originals are auto-layout frames, so tier changes are often single-property edits.
**Alternatives**: fresh builds from the component library (rejected — that was Path B's failure mode); in-place edits of originals (rejected — destroys the side-by-side).

## D2 — Merge maps (which cards consolidate)

**Decision**, from the inventories:
- **a08**: 12 cards → ~7: keep AI Models, My Medication, Dose Guard, Confirmations as their own cards (control-rich); merge **System + Check-in + Calendar** into one "Preferences" card (toggle/value rows w/ kickers); merge **Accessibility + Your data footnotes** into the Your-data card; Medication Bar's 4 toggles stay one card (already consolidated); Clear All Data stays isolated (destructive isolation is correct iOS-and-Squirl practice).
- **a03**: no card merges (each section is already multi-fact); the fix is per-card internal rhythm + chip family (D4).
- **a01**: no card merges (timeline + day card); fix is day-card internals (D6) + tiers.
- **a07**: no card merges; fix is chart vocabulary (D3) + tiers + empty-state unification.
**Rationale**: merging is for *runs of single-fact cards* (the a02/a08 disease); control-dense cards keep their identity. Fewer, richer cards — not fewer sections.

## D3 — a07 chart vocabulary

**Decision**: **Primary family = the existing weekday bar/strip marks** (glyph-annotated bars, already 2 of 5 sections); gauges re-expressed as horizontal bars on tracks (same family); **part-to-whole exception = one horizontal stacked bar** for the breakdown (replaces overlapping bubbles); rhythm matrix keeps its badge-tint grid (it is a table, not a chart); locked/empty = one pattern (muted card + lock/line copy, no dashed strokes).
**Rationale**: bars are the family the accepted a02-a signal rows already use (fill-on-track); stacked bar is the least-ink part-to-whole that fits card width; the audit's own recommendation was "commit to 1–2 marks".
**Alternatives**: donut for breakdown (rejected: introduces radial idiom the screen otherwise drops); keeping bubbles (prohibited by FR-011).

## D4 — Chip anatomy family (a03/a08)

**Decision**: one family: **height 36pt visual, radius 18 (pill), 13pt label, ≥8pt gaps** → ≥44pt effective touch slot (36 + 8 gap); selected = interactive-green fill + white/ink AA label; unselected = white + hairline. Grids re-wrap accordingly (taller sections accepted).
**Rationale**: 36+8 hits the 44pt effective floor without ballooning a03's six grids; pill radius matches the app's existing chip identity; one family kills rank-12's four heights/radii.
**Alternatives**: literal 44pt chips (rejected: a03 becomes ~40% taller and reads clunky); keeping mixed heights (prohibited by FR-010).

## D5 — Dose Guard "three-ways-one-choice" (a08, rank-13)

**Decision**: the three options become **three selectable rows inside one card** — radio-style: selected row = interactive-green ring/check + its detail line; unselected rows quiet — with the BLOCKED-FOR hour chips (D4 family) revealed under the selected Time-window row.
**Rationale**: it is one mutually-exclusive choice; rows-with-radio is the app's own selection grammar (chips stay for values, rows for modes), and it keeps every string.
**Alternatives**: segmented control (rejected: Path B idiom, and 3 labels + detail lines don't fit segments).

## D6 — Day-card duplicate indicator (a01, rank-14)

**Decision**: header keeps **mood word + tinted header band**; the duplicate mood **disc is removed**; the collapsed card applies the same rule; entry rows keep their glyphs (those are per-entry data, not duplicates). Header text must pass AA on the band (darken band or use wordColor ramp step as needed).
**Rationale**: word + band is the richer, more Squirl pair; the disc is the redundant third encoding the audit flagged.
**Alternatives**: keep disc, drop band (rejected: band is the day-card's identity feature).

## D7 — Review & acceptance

**Decision**: two-stage, both owner-gated, lighter than 039:
1. **Per-screen**: after each `a0N-a`, a measured self-check against the recipe contract + parity vs its inventory; owner reviews side-by-side (batchable). No iterate-until-pass blocking chain — screens are independent.
2. **Full acceptance**: when all 7 are owner-passed — full 4-lens re-audit (SC-001) + scans for SC-002–SC-008 → owner final sign-off → originals removed from v3 (backup remains) → DESIGN.md rewritten from the outcome + Decisions Log; BACKLOG/DEVLOG/WORKLOG close-out.
**Rationale**: mirrors the shape that caught Path B early while acknowledging Path A's low per-screen risk (clone + deltas).

## Resolved-unknowns summary

| # | Unknown | Resolution |
|---|---|---|
| D1 | Build method | Clone-and-refine beside original (`a0N-a`) |
| D2 | Merge maps | a08 12→~7 cards (Preferences merge; destructive isolated); others internal-only |
| D3 | a07 charts | Bar family primary; one stacked-bar part-to-whole; matrix = table; one empty-state pattern |
| D4 | Chip family | h36 r18 pill, 13pt, ≥8 gaps (≥44 effective); one selected treatment |
| D5 | Dose Guard | One card, three radio rows, chips under selected row |
| D6 | Day card | Word + band stay; disc removed; AA on band |
| D7 | Acceptance | Per-screen owner review (batchable) → full-set re-audit + sign-off → originals removed, DESIGN.md rewritten |
