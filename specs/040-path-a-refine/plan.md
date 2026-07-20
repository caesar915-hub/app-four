<!-- Created: 2026-07-20 19:16 (WEST) · Updated: 2026-07-20 19:16 (WEST) -->
# Implementation Plan: Path A — Refine the New Look In Place (Figma)

**Branch**: none (Figma-design feature; artifacts go to `main` as docs per house rules) | **Date**: 2026-07-20 | **Spec**: [spec.md](spec.md)

**Input**: `specs/040-path-a-refine/spec.md` (zero open clarifications — three pre-resolved by standing rulings + the accepted pilot)

## Summary

Roll the owner-accepted `a02-a` refine recipe across the remaining 7 screens: clone each original beside itself as `a0N-a`, apply only the deltas its content triggers (tiers, merges, single shadow, legible marks, purple/green discipline, chrome, AA), verify by measurement + parity, and gate each screen on the owner's side-by-side. Identity wins over any individual refinement (the 039 lesson). Figma-only; SwiftUI downstream.

## Technical Context

*(Design-tool plan — the "stack" is Figma + MCP.)*

**Surface**: Squil-Design `M0Meys9X89X1NLyT14qrX5` · working page **Screens v3** `552:1163` · frozen backup `597:1393` · accepted standard `a02-a` `638:1465` · originals: a01 `578:1163` · a03 `578:1482` · a04 `578:1760` · a05 `578:3638` · a06 `578:3659` · a07 `578:3669` · a08 `578:3959`

**Tooling**: `use_figma` (Plugin API; `figma-use` skill mandatory pre-load) + `get_screenshot`/`get_metadata` validation; canvas font Inter (SF stand-in — never apply SF)

**Method**: clone-and-refine (research D1) — sequential canvas mutations, measured self-checks per delta, screenshot validation per screen

**Standing gotchas** (from the pilot, memory `spec-039-rulings`): paint-level opacity stripped by `setBoundVariableForPaint` → tint via node-opacity rect · `resize()` resets sizing modes · `rescale()` scales stroke weights (re-set explicitly) · originals' roots ARE auto-layouts (tiering = `itemSpacing` + spacers) · instance sublayers hide via `visible=false`, not `remove()`

**Inputs**: 039 inventories (parity baselines) · perceptual-audit.csv (findings map) · 4-lens harness · brand collections (Tiimo Colors, Squirl Tokens); `iOS Semantic` values as AA references only

**Scale**: 7 screens (a08 → a03 → a01 → a07 → a04/a05/a06), ~30 discrete deltas total per the data-model matrix

## Constitution Check

**N/A — owner standing rulings (carried from 039, recorded in spec Assumptions + memory)**: constitution and DESIGN.md are non-gating for this Figma pipeline; DESIGN.md is rewritten *from* the accepted outcome at close-out. No Complexity Tracking entries.

## Project Structure

```text
specs/040-path-a-refine/
├── spec.md                       # done (16/16 checklist)
├── plan.md                       # this file
├── research.md                   # Phase 0 — D1–D7 resolved
├── data-model.md                 # Phase 1 — screen × delta × findings matrix
├── contracts/refine-recipe.md    # Phase 1 — the measurable recipe contract
├── quickstart.md                 # Phase 1 — per-screen gate + full acceptance
└── tasks.md                      # Phase 2 (/speckit-tasks)
```

**Structure Decision (canvas)**: each `a0N-a` at its original's x, y≈1150 (the accepted pilot's side-by-side column); originals untouched until full acceptance; backup page never modified.

## Phase 0 → [research.md](research.md): D1 method · D2 merge maps · D3 a07 charts · D4 chip family · D5 Dose Guard · D6 day card · D7 acceptance

## Phase 1 → [data-model.md](data-model.md) (per-screen deltas), [contracts/refine-recipe.md](contracts/refine-recipe.md) (measurable values from a02-a), [quickstart.md](quickstart.md) (gates)

## Complexity Tracking

Empty — no gates apply.
