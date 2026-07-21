<!-- Created: 2026-07-20 19:19 (WEST) · Updated: 2026-07-20 20:45 (WEST) -->
# Tasks: Path A — Refine the New Look In Place (Figma)

**Input**: [plan.md](plan.md) · [spec.md](spec.md) · [research.md](research.md) (D1–D7) · [data-model.md](data-model.md) (delta matrix) · [contracts/refine-recipe.md](contracts/refine-recipe.md) · [quickstart.md](quickstart.md)

**Tests**: Contract-first verification (constitution N/A per plan): the refine-recipe contract predates all canvas work; every build task is followed by a measured verify task; the owner side-by-side is each screen's acceptance test. Parity baselines = `specs/039-path-b-grouped-table/inventories/`.

**Surface**: Squil-Design `M0Meys9X89X1NLyT14qrX5` · Screens v3 `552:1163` · backup `597:1393` (never modified) · standard `a02-a` `638:1465` · originals: a01 `578:1163` · a03 `578:1482` · a04 `578:1760` · a05 `578:3638` · a06 `578:3659` · a07 `578:3669` · a08 `578:3959`. All canvas work via `use_figma` with `figma-use` pre-loaded; Inter = SF stand-in. Method: clone-and-refine (D1); each `a0N-a` at its original's x, y≈1150. Standing gotchas in plan §Technical Context.

**Organization**: one phase per screen in priority order (a08 → a03 → a01 → a07 → trio); screens are independent after Foundational — owner reviews are batchable (D7), no blocking chain.

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: Setup

- [X] T001 Verify surface read-only: originals + `a02-a` + backup reachable at the IDs above; confirm nothing else was added to the a0N columns since 2026-07-20 (`use_figma` page scan, note drift at the bottom of specs/040-path-a-refine/tasks.md)

## Phase 2: Foundational (reference numbers — blocks screen work)

- [X] T002 Measure the accepted `a02-a` (`638:1465`) once and record the live contract values (root itemSpacing, spacer heights, card shadow spec, med-bar anatomy, merged-row metrics, bar/track metrics) into specs/040-path-a-refine/checklists/reference-a02a.md — every later verify compares against these numbers, not memory

**Checkpoint**: reference numbers recorded — all screen phases may proceed independently

---

## Phase 3: US1 — a08 Settings (P1)

**Goal**: worst card-soup screen consolidated + green discipline proven on real controls. **Independent test**: a08-a beside a08 — parity 100%, 12→~7 cards, one green, tiers measured.

- [X] T003 [US1] Clone a08 (`578:3959`) → `a08-a` at x aligned/y≈1150 on Screens v3; apply chrome + tiers: status bar (keep), med bar → accepted 44pt tint anatomy (clone from `a02-a` med bar), root gap → 20 with 32 section spacers per data-model; single shadow pass on all cards (contract §1/§2/§4)
- [X] T004 [US1] Merge pass on `a08-a` per research D2: System+Check-in+Calendar → one "Preferences" card (icon+kicker+row anatomy, contract §2); fold Accessibility + Your-data footnotes into the Your-data card; keep AI Models / My Medication / Dose Guard / Confirmations / Medication Bar / Clear-All-Data cards; capture FULL footnote strings from the canvas (039 inventory truncated at 60 chars) into specs/039-path-b-grouped-table/inventories/a08.md before restructuring
- [X] T005 [US1] Controls pass on `a08-a`: all toggles ON = `selection` green (rank-15); Prompt Pace + dose + BLOCKED-FOR chips → contract §5 chip family (h36/r18/≥8 gaps); Dose Guard → one card with three radio rows + chips under Time-window (research D5, rank-13); selection treatment uniform, never purple (med chips keep purple identity, selected = green ring)
- [X] T006 [US1] Verify `a08-a`: measured recipe walk (§1–§8) + parity vs inventories/a08.md + findings 1/2/3/6/9/13/15 gone + AA math → specs/040-path-a-refine/checklists/a08-verify.md; fix until clean; screenshot for the owner pack

---

## Phase 4: US2 — a03 Edit check-in (P1)

**Goal**: every chip tappable, one selection language. **Independent test**: a03-a — zero sub-44pt effective targets, one selected treatment, parity 100%.

- [X] T007 [US2] Clone a03 (`578:1482`) → `a03-a`; chrome + tiers: status bar (keep), root gap 20/32 tiers, single shadow pass, in-card rhythm normalization (contract §1/§2)
- [X] T008 [US2] Chip-family pass on `a03-a`: all 6 grids (sleep quality, durations, meds, doses + Taken/Missed, emotions ×2 groups, side effects) → h36/r18/≥8-gap family with re-wrapped rows (frame grows); one selected treatment = context-green fill + AA label (green-vs-purple ambiguity killed: med identity purple stays on identity marks only) (contract §5, ranks 7/12/13)
- [X] T009 [US2] Verify `a03-a`: measured chip-slot scan (every chip ≥44 effective) + recipe walk + parity vs inventories/a03.md (capture full strings where truncated) + findings 1/2/3/5/7/9/12/13 + AA → specs/040-path-a-refine/checklists/a03-verify.md; screenshot

---

## Phase 5: US3 — a01 Calendar (P2)

**Goal**: day card ranks its story, chrome consistent. **Independent test**: a01-a — one mood indicator in header (both states), tiers, chrome = a02-a.

- [X] T010 [US3] Clone a01 (`578:1163`) → `a01-a`; chrome + tiers: ADD status bar (a01 lacks it), med bar → accepted anatomy, gap 20/32, single shadow (contract §1/§2/§4)
- [X] T011 [US3] Day-card pass on `a01-a` per research D6: remove duplicate mood disc in expanded AND collapsed headers (word + tinted band stay); AA-fix header text on the band (darker wordColor step if needed); entry-row breathing (rank-11); one chip shape (rank-12)
- [X] T012 [US3] Verify `a01-a`: recipe walk + parity vs inventories/a01.md + findings 1/2/6/11/12/14 + AA (incl. band composite math) → specs/040-path-a-refine/checklists/a01-verify.md; screenshot

---

## Phase 6: US4 — a07 Insights (P2)

**Goal**: one chart language. **Independent test**: a07-a — ≤2 mark families (2nd = part-to-whole only), no bubbles, one empty-state pattern.

- [X] T013 [US4] Clone a07 (`578:3669`) → `a07-a`; chrome + tiers: status bar (keep), med bar → accepted anatomy, gap 20/32, single shadow (contract §1/§2/§4)
- [X] T014 [US4] Chart pass on `a07-a` per research D3: breakdown bubbles → one horizontal stacked bar (legend + % strings verbatim); gauges → bars-on-tracks (≥6pt, ramp fills); weekday strips stay (primary family); rhythm matrix untouched (table); locked connections + untracked sleep → one muted empty-state pattern, dashed idiom retired (rank-18); glyph ink-weight unified (rank-5)
- [X] T015 [US4] Verify `a07-a`: mark-family count ≤2 + recipe walk + parity vs inventories/a07.md (capture full connection strings) + findings 1/2/4/5/11/18 + AA → specs/040-path-a-refine/checklists/a07-verify.md; screenshot

---

## Phase 7: US5 — a04/a05/a06 Check-in trio (P3)

**Goal**: light-touch pass, ring encodes progress once. **Independent test**: three frames — one progress encoding, a06 balanced, parity 100%.

- [X] T016 [US5] Clone a04 (`578:1760`) + a05 (`578:3638`) → `a04-a`/`a05-a`; ring recomposition: one progress encoding in `checkInGreen` (rank-8, remove duplicate indicator); tiers + single shadow; status bar kept (contract §1/§2/§5)
- [X] T017 [US5] Clone a06 (`578:3659`) → `a06-a`; rebalance composition via spacing/scale only, copy verbatim (rank-18); tiers; status bar kept
- [X] T018 [US5] Verify the trio: recipe walk + parity vs inventories/a04/a05/a06.md (capture a06's full subtitle) + findings 2/8/11/18 → specs/040-path-a-refine/checklists/trio-verify.md; screenshots

---

## Phase 8: Owner gates (per-screen, batchable — D7) 🚦

- [ ] T019 Owner side-by-side reviews: each `a0N-a` vs its original vs `a02-a` ("still Squirl, now ranked", SC-009). Fail on any screen → fix its named deltas (identity wins, FR-017) and re-present; passes unblock Phase 9

## Phase 9: Full acceptance (quickstart §Full)

- [ ] T020 Full 4-lens agent re-audit across the 8 refined frames (incl. a02-a); zero high-severity required (SC-001); fix + re-run until clean
- [ ] T021 Measured SC scans vs baselines (SC-002 tiers · SC-003 counts+parity · SC-004 families · SC-005 44pt · SC-006 purple/green · SC-007 chrome · SC-008 AA) → specs/040-path-a-refine/checklists/acceptance.md
- [ ] T022 Owner final sign-off → delete originals from Screens v3 (backup remains) → rename `a0N-a` frames to canonical screen names
- [ ] T023 Rewrite DESIGN.md from the accepted outcome (tiers, merge anatomy, chrome, chip family, green/purple discipline, chart vocabulary) + Decisions Log row
- [ ] T024 [P] Trackers: BACKLOG stage move + DEVLOG entry (real `date`) + commit + regenerate docs/WORKLOG.md via scripts/worklog.sh

---

## Dependencies & execution order

- T001 → T002 → screen phases. **Phases 3–7 are mutually independent** (canvas mutations still execute serially — one canvas); priority order a08 → a03 → a01 → a07 → trio is the default build sequence, not a dependency.
- T019 consumes Phases 3–7; T020–T024 blocked until all screens owner-passed.
- Parallel opportunities: verification-doc writing alongside next screen's build; T024 alongside T023; the 4-lens audit (T020) fans out internally.

## Implementation strategy

Each screen = clone → chrome/tiers → screen-specific pass → measured verify → screenshot for the owner pack. Screens ship to review incrementally; the owner can pass them one at a time or in batches. Rollback at any point = delete `a0N-a` frames (FR-016).

---

## SHELVED — 2026-07-20 (owner ruling at T019)

Owner reviewed the full rollout and ruled: **keep the current design unchanged**. All 8 refined frames (incl. the a02-a pilot) moved to Figma page **"Archive — Path A refine (shelved 2026-07-20)"** (`662:1163`); Screens v3 restored to the 8 untouched originals; frozen backup page also intact. T020–T024 will not run. Nothing was swapped, deleted, or applied to the originals; DESIGN.md untouched. The archive preserves the complete refined set + per-screen evidence should the owner ever revisit.
