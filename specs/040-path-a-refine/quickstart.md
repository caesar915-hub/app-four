<!-- Created: 2026-07-20 19:15 (WEST) · Updated: 2026-07-20 19:15 (WEST) -->
# Quickstart — Validation Runbook (Path A)

## Prerequisites
- Squil-Design open: **Screens v3** (working, `552:1163`) with accepted `a02-a` (`638:1465`); frozen backup `597:1393`.
- Parity baselines: `specs/039-path-b-grouped-table/inventories/a0N.md`.
- Contract: [contracts/refine-recipe.md](contracts/refine-recipe.md). 4-lens audit harness from 2026-07-18 reusable.

## Per-screen gate (each `a0N-a`, batchable)
1. Confirm `a0N-a` sits beside its untouched original (x aligned, y≈1150).
2. **Recipe check**: walk contract §1–§8 lines applicable to the screen; measure, don't eyeball (tiers, shadow count, bar heights, chip slots, green/purple scans, AA math).
3. **Parity check**: 100% of the screen's inventory strings present; transforms documented.
4. **Findings check**: the screen's mapped audit findings (data-model matrix) verified gone.
5. **Owner side-by-side**: original vs `a0N-a` vs `a02-a` (the standard) — "still Squirl, now ranked". Fail → fix the named deltas; identity wins over any refinement (FR-017).

## Full acceptance (all 7 owner-passed)
1. Full 4-lens agent re-audit across the refined set → zero high-severity (SC-001).
2. Scans vs baselines: SC-002 tiers · SC-003 card counts + parity · SC-004 a07 families · SC-005 44pt targets · SC-006 purple/green · SC-007 chrome · SC-008 AA.
3. Owner final sign-off → delete originals from Screens v3 (backup page remains) → rename `a0N-a` frames to canonical names.
4. DESIGN.md rewritten **from** the outcome (+ Decisions Log row) · BACKLOG stage move · DEVLOG entry · commit + WORKLOG regen.

## Rollback
Any point pre-acceptance: delete `a0N-a` frames — originals and the frozen backup are intact by construction (FR-016).
