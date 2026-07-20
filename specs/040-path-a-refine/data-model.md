<!-- Created: 2026-07-20 19:14 (WEST) · Updated: 2026-07-20 19:14 (WEST) -->
# Data Model — Path A Refine Deltas (Phase 1)

The "entities" are per-screen delta lists: screen × triggered recipe items × mapped audit findings. Inventories in `specs/039-path-b-grouped-table/inventories/` are the parity baselines. Node IDs: originals a01 `578:1163` · a03 `578:1482` · a04 `578:1760` · a05 `578:3638` · a06 `578:3659` · a07 `578:3669` · a08 `578:3959` (Screens v3 `552:1163`); accepted `a02-a` = `638:1465`.

## Screen × delta matrix

| Screen | Deltas (contract §) | Findings it must kill | Notes |
|---|---|---|---|
| **a08 Settings** (US1) | tiers §1 · **merge System+Check-in+Calendar → "Preferences" card** + footnote merges (research D2) §2 · single shadow §2 · chrome §4 · one green on toggles/chips §5 · chip family §5 · **Dose Guard radio-rows** (D5) §5 · AA §7 | 1 · 2 · 3 · 6 · 9 · 13 (three-ways) · 15 (toggle green → `selection`) | Clear All Data stays isolated; med chips keep purple identity (medication), selection state distinct from it |
| **a03 Edit check-in** (US2) | tiers §1 · in-card rhythm §1 · single shadow §2 · **chip family h36/r18/≥8 gaps on all 6 grids** §5 · one selected treatment §5 · status bar §4 · AA §7 | 1 · 2 · 3 · 5 · **7** · 9 · **12** · **13** (green-vs-purple selection) | No card merges; grids re-wrap (frame grows — fine, it's a sheet); med chips: purple = identity, selected = green ring not purple fill |
| **a01 Calendar** (US3) | tiers §1 · **day-card header: drop duplicate disc, word+band stay, AA on band** (D6) §2/§7 · entry-row breathing §1 · one chip shape §5 · med bar + status bar §4 · single shadow §2 | 1 · 2 · 6 · 11 · 12 · **14** | Both day-card states refined (expanded + collapsed, both on canvas) |
| **a07 Insights** (US4) | tiers §1 · **bubbles → one stacked part-to-whole bar; gauges → bars-on-tracks (one family)** (D3) §3 · **one locked/empty pattern** §3 · glyph weight §3 · med bar + status bar §4 · single shadow §2 · AA §7 | 1 · 2 · **4** · 5 · 11 · 18-dashed | Rhythm matrix = table, keeps badge-tint grid; connections' purple bar = med identity ✓ stays |
| **a04 + a05 Check-in** (US5) | **ring recomposition: one progress encoding** (rank-8) · tiers §1 · status bar §4 · single shadow §2 · capture green §5 | 2 · **8** · 11 | No med bar (by design); prompt card + hub keep their anatomy |
| **a06 Saved** (US5) | **composition rebalance** (rank-18) · tiers §1 · status bar §4 | 2 · **18** | Copy verbatim; balance via spacing/scale only |

## Merged-card row anatomy (reusable unit, from a02-a)

`row := icon(22×22 slot, cloned from original) · gap12 · col[ kicker(10 caps +0.6, caption-gray AA) · gap3 · fact(15 Semi Bold, ink) ]` — rows stacked gap 14 inside card padding 16.

## Chrome pair (from a02-a)

- Status bar: canonical clone, 44pt, y0, all 8 frames.
- Med bar: 358×44 r14, tint = `accent/medication` rect @ node-opacity 10%, capsule + `09:15 · Concerta 36mg` (13 SB `accent/medicationText`) + `ACTIVE` (10, +0.6) — a01/a02/a07/a08.

## Verification data

Baselines the final scans run against: 8 high-severity audit findings → 0 (SC-001) · 12pt uniform gap → 20/32 tiers measured (SC-002) · a08 card count 12 → ~7 with parity 100% (SC-003) · a07 mark families ≤2 (SC-004) · ~37 sub-44pt targets → 0 (SC-005) · purple/green scans clean (SC-006) · chrome 8/8 + 4/4 (SC-007) · AA 100% on refined text (SC-008) · per-screen owner passes → full sign-off (SC-009).
