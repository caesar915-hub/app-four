# Implementation Plan: DayCard a01 Redesign — Folded + Unfolded

**Branch**: `feat/034-daycard-a01` (stacked on `feat/033-newlook-app-wide`, PR #28) | **Date**: 2026-07-12 | **Spec**: [spec.md](spec.md)

## Summary

Rebuild the calendar `DayCard` folded and unfolded states to match Figma a01 (`308:2122` folded, `308:1957` unfolded). Folded: 24pt-Bold mood word + caps-13 weekday + a wrapping glyph-chip summary that gains a sleep chip. Unfolded: the mood header collapses to a slim caps band, and each check-in becomes a 43pt mood-disc row with a 24pt mood word, time, an outlined ⋯ affordance, and one wrapping dot-chip line — the `TimelineBead`/connector column (and its medication-phase ring) is removed. One logic change (`DayCardSummary` gains sleep) is test-first. Zero new colour tokens.

## Technical Context

- **Language/Platform**: Swift 6 / SwiftUI, iOS 26 deployment target (post-033 rebase).
- **Files touched** (all exist):
  - `app-four/Views/Components/DayCard.swift` — swap the expanded header for a collapsed band; keep the white card + radius-20 + 2-layer shadow.
  - `app-four/Views/Components/FoldedDayCardHeader.swift` — folded layout to a01 (24pt word, caps weekday, glyph-chip summary + sleep); add the collapsed caps band.
  - `app-four/Views/Components/TimelineRow.swift` — remove the bead/connector column; new 43pt-disc row with 24pt word + time + ⋯ + single wrapping chip line.
  - `app-four/Views/Components/DayCardSummary.swift` — add `sleep` (derived, `@MainActor`).
  - `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Metrics.swift` — add layout dims (row disc, ⋯ affordance). No colour tokens.
  - `app-fourTests/Views/FoldedDayCardHeaderTests.swift` — add sleep-derivation tests (RED→GREEN).
- **`TimelineBead.swift`**: no longer referenced by `TimelineRow` after this change; grep for other consumers (T014) and remove if orphaned (Constitution IV).
- **Design source**: Figma file `M0Meys9X89X1NLyT14qrX5`, page Screens (v2) `76:2`, nodes `308:2122` / `308:1957`. Token authority in [research.md](research.md).
- **Testing**: Swift Testing (`@Test`/`@Suite`), pure-value tests only (owner builds/QAs on device; no simulator). The one logic change is unit-tested; the rest is visual (device QA per [quickstart.md](quickstart.md)).

## Constitution Check

- **I. SwiftUI-First**: ✅ pure SwiftUI; no UIKit.
- **II. Test-Build-Ship**: owner builds + device-QAs on the branch before PR-ready (no simulator here).
- **III. Correctness Over Speed**: ✅ the one behavioural change is test-first; visual parity verified against the design references at QA.
- **IV. Minimal Surface**: ✅ removes the bead/connector column and (if orphaned) `TimelineBead`; no dead code left.
- **V. Solo Git Discipline**: ✅ one branch = one revertable feature; stacks on #28, merges after it; `/code-review` before merge.
- **VI. On-Device Privacy**: ✅ no data leaves the device; purely presentational + one derived summary field.
- **VII. Deterministic Extraction**: N/A (no extraction/lexicon/eval touched).
- **VIII. Service-Oriented Architecture**: ✅ views only; `DayCardSummary` stays a pure derivation.
- **IX. Pre-Release Data Posture**: ✅ no schema/persistence change (`sleep` is derived, nothing stored).
- **X. Test-First (NON-NEGOTIABLE)**: ✅ `DayCardSummary.sleep` gets a failing test before the property exists (T-RED → T-GREEN).

No violations. No Complexity-Tracking entries required.

## Phase 0 — Research

See [research.md](research.md): the Figma→code token/dimension mapping for both nodes, the two intentional per-node fidelity notes (folded sleep text = primary ink vs unfolded = sleepIndigo; unfolded sleep has no glyph), and the med-phase-ring removal consequence.

## Phase 1 — Design

- [data-model.md](data-model.md): `DayCardSummary.sleep` derivation + the render contract for both states.
- [quickstart.md](quickstart.md): device-QA scenarios mapped to the spec's acceptance scenarios + SC-001..005.
- Agent context: CLAUDE.md SPECKIT pointer updated to this plan.

## Phase 2 — Implementation ordering

Foundational (Metrics dims) → US1 folded (test-first summary sleep → folded view → collapsed band) → US2 unfolded (TimelineRow rebuild, delete bead column) → polish (grep for orphaned `TimelineBead`, style-literal audit, a11y pass) → adversarial review → owner device QA. Full breakdown in [tasks.md](tasks.md).
