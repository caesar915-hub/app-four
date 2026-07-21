<!-- Created: 2026-07-18 20:01 (WEST) · Updated: 2026-07-18 20:01 (WEST) -->
# Quickstart — Validation Runbook (Path B)

How to validate the work at the two gates (research D6). No implementation steps here — see tasks.md.

## Prerequisites
- Figma file Squil-Design open; pages **Screens v3** (working) and **Screens v3 — Backup** (frozen reference).
- `design-database/` present (baseline CSVs incl. `perceptual-audit.csv`).
- The 4-lens audit workflow from 2026-07-18 (fresh-eyes / checklist / consistency / HIG) — reusable script in the session workflow store.

## Gate 1 — a02 pilot (iterate until pass)
1. Confirm `a02-b` sits beside `a02` on Screens v3 (build-beside, research D2).
2. **Contract check**: walk `contracts/grouped-table-grammar.md` §1–§7 as a checklist against `a02-b` (container/rows/controls/nav/roles/chrome/type). Every line must hold.
3. **Content parity (SC-005)**: list every row/value/control on backup-a02; verify 100% present on `a02-b` (grammar changed, information identical — FR-015).
4. **Findings check (FR-018)**: for each a02 row in data-model §4's matrix (ranks 1/2/3/5/6/9/10/16/17 + icon set), confirm the specific defect is gone.
5. **Agent re-audit**: run the 4-lens workflow scoped to `a02-b`; expect zero high-severity findings on it (SC-008 scope-of-one).
6. **Owner side-by-side**: owner compares `a02-b` vs `a02` vs a native iOS grouped detail screen (SC-006). Pass → gate opens. Fail → iterate (steps 2–6); nothing else converts meanwhile (FR-016).

## Gate 2 — full-set acceptance (all 8)
1. All screens converted per data-model §4 (list = grouped-table; non-list = native composition + shared tokens).
2. Uniform status bar on 8/8; med bar styled as chrome on a01/a02/a07/a08 (SC-007).
3. Re-extract `design-database` from the converted set; re-run the 4-lens audit.
4. Check SCs against the fresh extraction: SC-001 (zero HIG web/Material highs on list screens) · SC-002 (one role per token — variable scan) · SC-003 (spacing tiers measurable) · SC-004 (≤2 mark families on a07, #2 part-to-whole only) · SC-005 (content parity per screen) · SC-008 (zero high-severity on converted screens).
5. Owner final sign-off → delete original frames from v3 (backup page remains) → update DESIGN.md *from* the outcome + Decisions Log row → BACKLOG/DEVLOG entries.

## Expected outcomes
- Pilot: `a02-b` passes contract + parity + re-audit + owner judgment.
- Full set: all SCs green against a fresh extraction; v3 holds only Path-B frames; backup page untouched.

## Rollback
Any point pre-acceptance: delete `a0N-b` frames; originals and the frozen backup are intact by construction (FR-014, D2).
