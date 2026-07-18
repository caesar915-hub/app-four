<!-- Created: 2026-07-18 20:13 (WEST) · Updated: 2026-07-18 20:13 (WEST) -->
# Tasks: Path B — Native iOS Grouped-Table Redesign (Figma)

**Input**: Design documents from `specs/039-path-b-grouped-table/` — [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md) (D1–D6), [data-model.md](data-model.md), [contracts/grouped-table-grammar.md](contracts/grouped-table-grammar.md), [quickstart.md](quickstart.md)

**Tests**: Adapted for a Figma-only feature (constitution N/A per plan.md ruling): TDD is replaced by **contract-first verification** — the visual contract was authored before any canvas work, and every build task is followed by explicit contract/parity/findings verification tasks. The pilot gate (FR-016, iterate-until-pass) is the acceptance test; the owner is the gate.

**Execution surface** (so tasks run without opening plan.md): Figma file **Squil-Design** `M0Meys9X89X1NLyT14qrX5` · working page **Screens v3** `552:1163` · frozen backup page `597:1393` · originals: a01 `578:1163` · a02 `578:1385` · a03 `578:1482` · a04 `578:1760` · a05 `578:3638` · a06 `578:3659` · a07 `578:3669` · a08 `578:3959`. All canvas work via `use_figma` with the `figma-use` skill pre-loaded (mandatory); canvas font is Inter (SF Pro stand-in — never apply SF). Backup page is never modified (FR-014).

**Organization**: Grouped by user story; pilot-first per FR-016 — US4/US5 canvas conversions are **blocked until the Phase 6 pilot gate passes**.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: parallelizable (different files / read-only canvas; canvas *mutations* stay sequential — one shared Figma canvas)
- **[Story]**: US1–US5 from spec.md

---

## Phase 1: Setup (verify the surface)

- [X] T001 Verify Figma surface: pages `552:1163` (8 original frames, node IDs above) and backup `597:1393` (8 frozen clones) reachable via `get_metadata`; record any node-ID drift as a correction note at the bottom of specs/039-path-b-grouped-table/tasks.md
- [X] T002 [P] Verify reusable tokens exist per research D1: Squirl Tokens `spacing/*` FLOATs (4/8/12/16/20/24/32/40) + `radius/control=10` + `radius/card=20` via `use_figma` variable scan; cross-check against design-database/tokens-variables.csv

---

## Phase 2: Foundational (tokens + component library — BLOCKS all user stories)

- [X] T003 Create Figma variable collection **`iOS Semantic`** with Light+Dark modes and the 8 variables at data-model.md §1 exact values (`role/action` #34C759/#30D158, `role/selectionTint`, `role/caption` #6C6C70/#AEAEB2, `role/destructive` #D54037/#FF453A, `role/status`, `surface/groupedBg` #EFF2EB/#12140F, `surface/groupContainer` #FFFFFF/#1C1E19, `separator/hairline` #3C3C43@29%/#545458@65%) via `use_figma`; return variable IDs+keys in the script result
- [X] T004 Register the 8 new variables (collection, name, type, light/dark values) as rows in design-database/tokens-variables.csv so the harness stays current for audits
- [X] T005 Create page **`iOS Grouped`** in Squil-Design and build group primitives per data-model.md §3 + contract §1: `Group/Container` (r10, `surface/groupContainer`, shadowless), `Group/CaptionHeader` (uppercase 13 `role/caption`, ± trailing action, sits OUTSIDE container), `Group/Footnote` (13 `role/caption`)
- [X] T006 Build row components on page `iOS Grouped` per data-model.md §3 + contract §2: `Row/Base` (leading-icon? · label · value?, ≥44pt, hairline separator inset to text leading edge, none after last row), `Row/Toggle` (on/off, system switch, `role/action` on), `Row/Disclosure` (chevron `role/caption`), `Row/Selection` (selected/unselected, checkmark `role/action` + `role/selectionTint`), `Row/Destructive` (centered `role/destructive`)
- [X] T007 Build `Control/Segmented` (2–4 segment variants) on page `iOS Grouped` per contract §3 — replaces detached pills on list screens
- [X] T008 Build chrome components on page `iOS Grouped` per contract §6: `Chrome/StatusBar` (one component, instanced on every frame) and `Chrome/MedBar` (dose-state variants, ~36pt, tinted not `surface/groupContainer`, unshadowed — must not read as content, FR-009)
- [X] T009 Build nav components on page `iOS Grouped` per contract §4: `NavBar/LargeTitle` (a02/a08) and `NavBar/Sheet` (Cancel · inline centered title · Save with `role/action` when enabled — a03)
- [X] T010 Validate the library against contract §1–§7 with `get_screenshot` + measured `get_metadata` (r10, 44pt floors, 16pt insets, separator inset, caption outside, role bindings — no raw hexes where a role exists); fix violations before any screen work

**Checkpoint**: tokens + "iOS Grouped" library exist and pass the contract — screen conversion can begin

---

## Phase 3: User Story 1 — a02 Recording detail pilot (P1) 🎯 MVP

**Goal**: a02 rebuilt as `a02-b` beside the original in grouped-table grammar with all mapped audit findings fixed (data-model §4 row 1) — proves the language before any rollout.

**Independent Test**: `a02-b` beside frozen a02 — reviewer confirms native iOS detail grammar and zero content loss (spec US1).

- [X] T011 [US1] Capture the a02 content inventory (every row, value, control, label, icon) from the backup-page a02 clone via `get_metadata`/`get_screenshot` into specs/039-path-b-grouped-table/inventories/a02.md — the SC-005 parity baseline
- [X] T012 [US1] Scaffold `a02-b` beside a02 on Screens v3 (`552:1163`): 390-wide frame, `surface/groupedBg` fill, `Chrome/StatusBar` + `Chrome/MedBar` instances pinned per contract §6, `NavBar/LargeTitle` with a02's title
- [X] T013 [US1] Build the signal-summary section in `a02-b` from inventories/a02.md: one grouped container, signal values as legible marks ≥3pt (kills rank-17 hairline bars), one title role per contract §7 (kills rank-9)
- [X] T014 [US1] Build the fact groups in `a02-b`: medications, sleep, emotions, side effects as separator-divided `Row/Base` instances inside `Group/Container`s with `Group/CaptionHeader`s — no card-per-fact (kills rank-1/3); footnotes where the original explains
- [X] T015 [US1] Build transcript + audio + delete groups in `a02-b`: transcript as a grouped long-form section; audio player with neutral/native controls not medication purple (kills rank-16); `Row/Destructive` "Delete recording" in its own group
- [X] T016 [US1] Consistency pass on `a02-b`: unify section-icon style/weight/tint (rank-5 fill-weight discipline; sprout/bolt/aperture shapes unchanged), ≥44pt touch floors (rank-7), collapse padding families to the spacing tiers (rank-10), med-bar reads as chrome not content (rank-6)
- [X] T017 [US1] Contract walk: check `a02-b` against every line of contracts/grouped-table-grammar.md §1–§7; record pass/fail per line in specs/039-path-b-grouped-table/checklists/a02-contract.md; fix and re-walk until all pass
- [X] T018 [US1] Content-parity check: every item in inventories/a02.md present on `a02-b` (100%, SC-005); log misses in checklists/a02-contract.md and fix
- [X] T019 [US1] Findings check: each a02-mapped audit finding (ranks 1/2/3/5/6/9/10/16/17 + icon set, data-model §4) verified gone on `a02-b`; record in checklists/a02-contract.md
- [X] T020 [US1] Agent re-audit: run the 4-lens audit workflow (fresh-eyes/checklist/consistency/HIG, 2026-07-18 harness) scoped to `a02-b`; zero high-severity findings required (SC-008 scope-of-one); fix and re-run until clean

**Checkpoint**: `a02-b` passes contract + parity + findings + agent audit — ready for US2/US3 system verification, then the owner gate

---

## Phase 4: User Story 2 — one meaning per color role (P1)

**Goal**: Prove on the pilot that no color token serves more than one semantic role (SC-002); full-set proof lands at Gate 2.

**Independent Test**: Variable-usage scan of `a02-b` shows every color binding maps to exactly one `iOS Semantic` role.

- [X] T021 [US2] Role scan on `a02-b` via `use_figma` boundVariables walk: every color binding resolves to one role; brand greens (#5F8A4C/#54B492/#5FB36E) absent from action/control/selection; mood ramp on data marks only (FR-006, SC-002); fix violations
- [X] T022 [US2] Selection-state audit on `a02-b`: any selected state uses checkmark/`role/selectionTint` only — no colored fill, no action green, no mood green (FR-007/Q3); fix violations
- [X] T023 [US2] AA contrast check on `a02-b`: captions/secondary text ≥4.5:1 against their resolved composited surfaces (FR-019 — waivers dead); compute from extracted fills, darken values if any fail (keep dark-mode counterparts canonical)

---

## Phase 5: User Story 3 — ranked content, chrome vs content (P2)

**Goal**: Spacing tiers measurably distinct and the med bar reads as global chrome on the pilot (SC-003 pilot-scope).

**Independent Test**: Measured gaps on `a02-b` show between-group (24) > within-group, section breaks (32) > between-group; med bar visually distinct from content.

- [X] T024 [US3] Measure spacing on `a02-b` via `get_metadata`: within-group vs between-group (`spacing/xxl` 24) vs section (`spacing/section` 32) form distinct tiers (SC-003); bind any hand-set paddings/gaps to `spacing/*` variables
- [X] T025 [US3] Chrome verification on `a02-b`: `Chrome/StatusBar` present; `Chrome/MedBar` pinned under it, thinner than a row, tinted, unshadowed — cannot be mistaken for a content group (FR-009/FR-010, rank-6)

---

## Phase 6: Pilot Gate (US1 acceptance — FR-016) 🚦

- [ ] T026 [US1] Owner side-by-side judgment: `a02-b` vs `a02` vs a native iOS grouped detail reference (SC-006), with checklists/a02-contract.md as evidence. **Pass → Phases 7–8 unblock. Fail → iterate T013–T025 until pass; no other screen converts meanwhile**

---

## Phase 7: User Story 4 — remaining list screens a03 + a08 (P2) — blocked by T026

**Goal**: a03 (sheet) and a08 (Settings) adopt the proven grammar/tokens; the list family reads as one system.

**Independent Test**: Both `-b` frames pass the same contract walk + parity + findings checks as the pilot.

- [X] T027 [P] [US4] Capture a03 content inventory from the backup clone into specs/039-path-b-grouped-table/inventories/a03.md
- [ ] T028 [US4] Build `a03-b` beside a03: `NavBar/Sheet` (Cancel/title/Save — large titles banned in sheets, FR-005), grouped sections from the inventory; chip grids become `Row/Selection` groups or wrap layouts with ≥44pt targets (rank-7); selection reads iOS-standard, no green-vs-purple ambiguity (rank-13); fix mapped ranks 1/2/3/5/9 (data-model §4)
- [ ] T029 [US4] Verify `a03-b`: contract walk §1–§7 + parity vs inventories/a03.md + mapped-findings check + role scan + AA → specs/039-path-b-grouped-table/checklists/a03-contract.md; fix until clean
- [X] T030 [P] [US4] Capture a08 content inventory from the backup clone into specs/039-path-b-grouped-table/inventories/a08.md
- [ ] T031 [US4] Build `a08-b` beside a08: `NavBar/LargeTitle`, settings groups with `Row/Toggle` (system switch on `role/action`, aligning the rank-15 outlier), `Row/Disclosure`, one `Control/Segmented` per multi-option choice (FR-004 — no detached pills), one visual grammar per choice type (rank-13 three-ways-one-choice); fix mapped ranks 1/2/3/6/9
- [ ] T032 [US4] Verify `a08-b`: contract walk §1–§7 + parity vs inventories/a08.md + mapped-findings check + role scan + AA → specs/039-path-b-grouped-table/checklists/a08-contract.md; fix until clean

**Checkpoint**: list family (a02/a03/a08) complete and internally consistent

---

## Phase 8: User Story 5 — non-list screens native-appropriate (P3) — blocked by T026

**Goal**: a01/a04–a06/a07 get native composition + shared tokens/tiers/chrome (FR-012) — never literal list rows; a07 gets one chart vocabulary (FR-011).

**Independent Test**: Five `-b` frames pass contract §5–§8 scope + parity + mapped findings; a07 shows ≤2 mark families.

- [X] T033 [P] [US5] Capture content inventories for a01/a04/a05/a06/a07 from backup clones into specs/039-path-b-grouped-table/inventories/a01.md, a04.md, a05.md, a06.md, a07.md
- [ ] T034 [US5] Build `a01-b` (Calendar, native composition): shared tokens + spacing tiers, day-card fix — remove duplicate indicator/disc, resolve green-on-green (rank-14) — with **expanded + collapsed day-card states**, density relief (rank-11), one chip shape (rank-12), `Chrome/MedBar` + `Chrome/StatusBar` (research D3)
- [ ] T035 [US5] Build `a04-b` + `a05-b` (Check-in states): ring recomposition + duplicate-indicator removal (rank-8), density (rank-11), role tokens (rank-2), `Chrome/StatusBar` (no med bar — D3)
- [ ] T036 [US5] Build `a06-b` (Check-in state): rebalance the unbalanced composition (rank-18), role tokens, `Chrome/StatusBar`
- [ ] T037 [US5] Build `a07-b` (Insights): one bar-family mark for all signal-over-time sections + at most one part-to-whole family (stacked bar or donut — bubbles banned; FR-011/research D5), retained r20 cards allowed per contract §8 (FR-017), retire the dashed idiom for a native empty/locked "not tracked" state (rank-18), glyph fill discipline (rank-5), density (rank-11), hierarchy/roles (ranks 1/2), `Chrome/MedBar` + `Chrome/StatusBar`
- [ ] T038 [US5] Verify the five non-list frames: contract §5–§8 scope + parity vs their inventories + mapped-findings check (data-model §4) + role scan + AA → specs/039-path-b-grouped-table/checklists/nonlist-verify.md; count a07 mark families ≤2 with family #2 part-to-whole only (SC-004); fix until clean

**Checkpoint**: all 8 `-b` frames built and individually verified

---

## Phase 9: Polish — Gate 2 full-set acceptance (quickstart §Gate 2)

- [ ] T039 Uniform-chrome sweep: instances of the single `Chrome/StatusBar` component on all 8 `-b` frames; `Chrome/MedBar` consistent on a01/a02/a07/a08 (SC-007)
- [ ] T040 Re-extract design-database/ from the converted set (screens, tokens-variables, typography-usage, components per design-database/README.md) — fresh CSVs are the SC evidence base
- [ ] T041 Full 4-lens agent re-audit across all 8 `-b` frames; require zero high-severity findings (SC-008) and zero HIG web/Material highs on list screens (SC-001)
- [ ] T042 Check SC-001…SC-008 against the fresh extraction + audit output; record verdicts in specs/039-path-b-grouped-table/checklists/gate2-acceptance.md
- [ ] T043 Owner final sign-off (Gate 2) → then delete original a01–a08 frames from Screens v3 only (backup page `597:1393` untouched — FR-014; rollback pre-sign-off = delete `-b` frames per quickstart §Rollback)
- [ ] T044 Update DESIGN.md *from* the accepted outcome (grouped-table baseline, `iOS Semantic` roles, spacing tiers, chart vocabulary) + Decisions Log row — per the non-gating ruling, DESIGN.md follows the result
- [ ] T045 [P] Trackers: move 039 in docs/BACKLOG.md, add docs/DEVLOG.md entry (real `date`), commit 039 artifacts, regenerate docs/WORKLOG.md via scripts/worklog.sh

---

## Dependencies & Execution Order

- **Phase 1 → 2 → 3**: strictly sequential (tokens/components block all screens)
- **Phases 4–5** (US2/US3 verification) run on the pilot after T016; they feed the gate
- **T026 pilot gate** consumes T017–T025 evidence; **fail loops back to T013–T025** (FR-016). T027–T045 are all blocked until it passes
- **Phase 7 vs Phase 8**: independent of each other after the gate; canvas mutations still execute sequentially (one canvas). Inventory tasks (T027/T030/T033) are read-only and may run any time after Setup
- **Phase 9**: after Phases 7+8 complete; T043 (owner) gates T044–T045

### Parallel opportunities

Single shared Figma canvas ⇒ canvas **mutations are inherently serial**. True parallelism is limited to read-only/doc work: T002 with T001 · inventory captures T027/T030/T033 alongside (or ahead of) build tasks · T045 alongside T044. The 4-lens audits (T020/T041) fan out internally as parallel agent lenses.

```text
# Example: while a02-b iterates (T013–T016), pre-capture the other inventories:
T027 inventories/a03.md · T030 inventories/a08.md · T033 inventories/a01+a04–a07 (read-only backup page)
```

## Implementation Strategy

**MVP = Phases 1–6** (T001–T026): tokens, library, `a02-b`, iterate-until-pass gate. Stop there and demo — the pilot decides whether Path B rolls out. Then increment: US4 list family → US5 non-list → Gate 2. Each `-b` frame is independently revertable (delete it; originals + backup intact by construction, FR-014).
