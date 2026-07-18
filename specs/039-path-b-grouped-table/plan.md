<!-- Created: 2026-07-18 20:01 (WEST) · Updated: 2026-07-18 20:01 (WEST) -->
# Implementation Plan: Path B — Native iOS Grouped-Table Redesign (Figma)

**Branch**: none yet (Figma-design feature; a docs branch is optional — spec/plan artifacts may go to `main` per house rules for non-code) | **Date**: 2026-07-18 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/039-path-b-grouped-table/spec.md` (5 clarifications resolved 2026-07-18, Fable cross-check)

## Summary

Convert the three list-grammar screens (a02, a03, a08) of the Squil-Design Figma file from "New Look" borderless cards to native iOS inset-grouped-table grammar, give the five non-list screens (a01, a04–a06, a07) native-appropriate composition on the same shared token system, and remediate every `perceptual-audit.csv` finding on any touched screen. **Pilot = a02 Recording detail, iterate until pass; all other conversions blocked until the gate opens.** Deliverable is Figma-only; SwiftUI is a downstream spec.

## Technical Context

*(This is a design-tool plan, not a code plan — the "stack" is Figma + MCP.)*

**Design surface**: Figma file **Squil-Design** (`M0Meys9X89X1NLyT14qrX5`) · working page **Screens v3** (`552:1163`) · frozen reference **Screens v3 — Backup (pre Path B)** (`597:1393`) · v3 frame ids: a01 `578:1163` · a02 `578:1385` · a03 `578:1482` · a04 `578:1760` · a05 `578:3638` · a06 `578:3659` · a07 `578:3669` · a08 `578:3959`

**Tooling**: official Figma MCP (`use_figma` Plugin-API scripts) with skills `figma-use` (mandatory pre-load), `figma-generate-design` (screen assembly), `figma-generate-library` (component/variant creation); `get_screenshot`/`get_metadata` for validation

**Existing token base**: Tiimo Colors (27 color vars, Light+Dark since 2026-07-18) · Squirl Tokens (incl. an **unused `spacing/*` FLOAT scale 4/8/12/16/20/24/32/40** and `radius/control=10`) · `design-database/` catalog (14 CSVs) as the extraction/verification harness

**Canvas font**: Inter as SF Pro stand-in (never apply SF to canvas — width-0 collapse); `production_font` mapping in the DB

**Grammar reference**: iOS inset-grouped-list conventions (HIG): ~10pt container radius, 44pt min row height, 16pt screen margins, hairline separators inset to text, caption headers/footers outside the container — exact values fixed in `contracts/grouped-table-grammar.md`

**Verification**: side-by-side vs backup page + 4-lens agent re-audit (same workflow as the 2026-07-18 audit) + `design-database` re-extraction; owner is the gate reviewer

**Scale/Scope**: 8 screens (3 grouped-table conversions, 5 native-appropriate passes), ~10 new components, 1 new variable collection + reuse of existing spacing FLOATs, 18 audit findings mapped to screens

## Constitution Check

**N/A — owner ruling (2026-07-18, recorded in spec Assumptions and memory `spec-039-rulings`):** the constitution is a code-era artifact and does not gate this Figma-design feature; DESIGN.md is likewise non-gating for the whole 039 pipeline. No principle checks apply; no Complexity Tracking entries required. (The downstream SwiftUI spec re-enters the normal gates.)

## Project Structure

### Documentation (this feature)

```text
specs/039-path-b-grouped-table/
├── spec.md              # done (clarified ×5)
├── plan.md              # this file
├── research.md          # Phase 0 — the 6 deferred plan-level decisions, resolved
├── data-model.md        # Phase 1 — token set, component library, screen×findings matrix
├── quickstart.md        # Phase 1 — pilot review + acceptance procedure
├── contracts/
│   └── grouped-table-grammar.md   # Phase 1 — the visual contract (metrics, anatomy, per-screen nav)
└── tasks.md             # Phase 2 (/speckit-tasks — not created here)
```

### Design surface (in lieu of source tree)

```text
Squil-Design (Figma)
├── Screens v3 (552:1163)            # working page — Path-B frames built BESIDE originals (research D2)
│   ├── a01…a08 (originals)          # deleted only after full acceptance
│   └── a0N-b (Path-B rebuilds)      # pilot: a02-b first
├── Screens v3 — Backup (597:1393)   # frozen; never modified (FR-014)
└── Components: "iOS Grouped" set    # new local components (research D1 / data-model)
```

**Structure Decision**: build-beside on the working page (research D2) — each Path-B frame lands next to its original for side-by-side review; the backup page stays the untouched historical reference; originals removed only after the full-set acceptance so iterate-until-pass always has its comparison surface.

## Phase 0 → [research.md](research.md) — resolves the 6 decisions clarify deferred:
D1 variable home · D2 page mechanics · D3 med-bar coverage · D4 dark-mode authoring · D5 chart-vocabulary strictness · D6 review/acceptance procedure

## Phase 1 → [data-model.md](data-model.md) (semantic tokens with exact values; component inventory; screen × grammar-class × audit-findings matrix), [contracts/grouped-table-grammar.md](contracts/grouped-table-grammar.md) (the visual contract every converted screen must satisfy), [quickstart.md](quickstart.md) (pilot-gate and full-acceptance validation runbook)

## Complexity Tracking

Empty — no constitution gates apply (see Constitution Check).
