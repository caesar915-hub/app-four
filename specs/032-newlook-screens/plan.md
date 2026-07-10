# Implementation Plan: New Look Screens — Edit Check-in & Recording Detail Re-skin

**Branch**: `feat/032-newlook-screens` | **Date**: 2026-07-10 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/032-newlook-screens/spec.md`

## Summary

Re-skin two existing screens — Edit check-in (`ExtractionReviewView`) and Recording detail
(`RecordingDetailView`) — into the "New Look" visual language approved in Figma (file
Squil-Design → "Screens (v2)", a03/a02), while the rest of the app stays Paper & Pollen (an
accepted, temporary mixed look). The approach is **tokens-first**: add a parallel `NewLook`
static token namespace + `.newLookCard()`/chip/nav grammar to `SquirlDesignSystem` (light+dark),
then switch only the two target views to consume it. Zero behavioral change; the existing
view-model test suites are the regression gate; owner device QA (light + dark, default +
accessibility sizes) is the acceptance gate. The calendar timeline (a01) is a **gated US3** that
must not start until spec-029's fate is decided (it edits the same views).

## Technical Context

**Language/Version**: Swift 6 (strict concurrency), SwiftUI, iOS 26 deployment target

**Primary Dependencies**: `SquirlDesignSystem` local SPM package (token + glyph + card layer);
app target `app-four`

**Storage**: N/A — no persisted data added or changed (design-token + view feature)

**Testing**: Swift Testing (`@Test`/`#expect`); existing `ExtractionReviewViewModelTests` and
`RecordingDetailViewModelTests` are the regression gate; views verified by build + device run

**Target Platform**: iOS 26+, iPhone (iPhone 12 / A14 class is the floor)

**Project Type**: Native iOS app (mobile) with a local SPM design-system package

**Performance Goals**: No runtime perf target — static token swap; no new allocations, no
extra view work; scroll/render parity with current screens

**Constraints**: Offline/on-device (Principle VI, unaffected); no literals in re-skinned view
code (FR-006); `.card()` and all non-target screens must remain byte-identical in appearance
(FR-011); mixed look accepted (FR-010)

**Scale/Scope**: 2 screens re-skinned now (US1, US2) + 1 token file (US0); US3 (calendar,
1 more screen cluster) gated out. ~2 view files (~465 + ~259 lines) restyled, 1 new token file,
DESIGN.md amended.

## Constitution Check

*GATE: passed before Phase 0; re-checked after Phase 1 design (below). See constitution v1.2.0.*

- [x] **I. SwiftUI-First** — pure SwiftUI, modern APIs; **mockup-before-view satisfied** by the
      binding Figma trio (token-bound, pixel-measured, QA'd 2026-07-09) per the spec assumption.
- [x] **II. Test-Build-Ship** — plan ends on build-green + full-suite-green + device QA; no step
      ships unverified.
- [x] **III. Correctness Over Speed** — re-skin replaces token references in place; no dead code,
      no shim, `.card()` left intact for its other consumers.
- [x] **IV. Minimal Surface** — parallel static namespace, **no runtime theme system** (D1); type
      maps to existing roles, **no near-duplicate SF sizes** (D2). Complexity table empty.
- [x] **V. Solo Git Discipline** — one revertable feature on `feat/032-newlook-screens`;
      `/code-review` before the PR; US1+US2 in one PR, US3 separate; `main` stays releasable.
- [x] **VI. On-Device Privacy** — visual only; no data path, network, or logging touched.
- [N/A] **VII. Deterministic, Measured Extraction** — no extraction/NLP code in scope.
- [x] **VIII. Service-Oriented Architecture** — no new services; VMs unchanged; no new capability.
- [x] **IX. Pre-Release Data Posture** — no schema, no `@Model`, no attributes touched.
- [x] **X. Test-First Development** — no new **logic** (D5); views exempt (build+run); existing VM
      suites stay green as the regression gate.

**Result: PASS, no violations.** Complexity Tracking table intentionally empty.

## Project Structure

### Documentation (this feature)

```text
specs/032-newlook-screens/
├── spec.md              # complete (clarified)
├── plan.md              # this file
├── research.md          # Phase 0 — D1–D5 decisions
├── data-model.md        # Phase 1 — token schema (no persisted entities)
├── quickstart.md        # Phase 1 — validation/QA guide
├── contracts/
│   └── newlook-tokens.md # Phase 1 — token→Figma→component contract
├── checklists/
│   └── requirements.md   # spec quality checklist (all pass)
└── tasks.md             # Phase 2 — /speckit-tasks (NOT created here)
```

### Source Code (repository root = `app-four-spm` worktree)

```text
Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/
├── NewLook.swift         # NEW — NewLook color namespace (light+dark) + .newLookCard() +
│                         #       newLookChip/newLookPill style + nav-row helper
├── Radius.swift          # EDIT — add `newLookCard = 20` (keep `card = 16`)
├── Theme.swift           # UNCHANGED (P&P — other screens depend on it)
├── Palette.swift         # UNCHANGED — Palette.medication reused as-is
└── Typography.swift      # UNCHANGED — mapped to existing roles (D2)

app-four/Views/
├── ExtractionReviewView.swift   # EDIT (US1, a03) — Theme.* → NewLook.*, chips/nav re-skinned
└── RecordingDetailView.swift    # EDIT (US2, a02) — Theme.* → NewLook.*, hero + cards re-skinned

app-fourTests/ViewModels/
├── ExtractionReviewViewModelTests.swift   # UNCHANGED — regression gate (must stay green)
└── RecordingDetailViewModelTests.swift    # UNCHANGED — regression gate (must stay green)

DESIGN.md                # EDIT (US0) — add "New Look" section (palette, radius, which screens)
```

**Structure Decision**: Native iOS app + local SPM design package (existing layout). The New
Look is one new file in the design package plus in-place edits to exactly two views and DESIGN.md
— no new module, no new target, no new architectural layer (Constitution IV, VIII).

## Implementation Phasing (maps to user stories)

- **US0 — Foundation (blocks US1/US2)**: `NewLook.swift` (light+dark tokens per D3), `Radius.newLookCard`,
  `.newLookCard()` + chip/pill/nav grammar (D4); DESIGN.md New Look section (FR-007). Build green.
- **US1 — a03 Edit check-in (P1)**: switch `ExtractionReviewView` to New Look tokens + grammar;
  bold sentence-case headers + a03 naming; centered nav title; selection-green chips, medication
  purple; device QA vs a02… a03. Existing VM suite green.
- **US2 — a02 Recording detail (P2)**: switch `RecordingDetailView`; signal hero strip, info
  cards, audio card, delete row per a02. Existing VM suite green.
- **US3 — a01 Calendar timeline (P3, GATED)**: excluded from this PR; starts only when spec-029
  is merged/abandoned (FR-012). Separate follow-up PR.
- **Ship**: build + full suite green on branch → `/code-review` → PR to `main` (US1+US2+US0) →
  owner device QA (light+dark, default+AX sizes) → merge.

## Complexity Tracking

> No Constitution violations. Table intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |

## Post-Design Constitution Re-Check

Re-evaluated after Phase 1 artifacts (data-model, contracts, quickstart): **still PASS.** The
design adds one file + two enum/modifier extensions + two in-place view edits; no new entity, no
runtime indirection, no logic. Minimal Surface (IV) and Correctness (III) hold; the regression
gate (X, II) is the existing VM suites plus device QA.
