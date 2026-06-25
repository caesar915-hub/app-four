# Implementation Plan: QA fixes — med-bar scroll fade, calendar dot, Log-Dose colour

**Branch**: `018-qa-review-fixes` (spec dir) · land on a dedicated `fix/qa-review-2026-06-24` off `main` | **Date**: 2026-06-24 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/018-qa-review-fixes/spec.md`

## Summary

Three presentation-only fixes from the 2026-06-24 walkthrough, each an independent, revertable slice with no data/schema/behaviour change:

1. **A2 — top scroll-fade behind the medication bar** on Insights and Settings. Replace the hardcoded `top: 0` (and the absent mask on Settings' `List`) with a real top fade whose height reaches the bottom edge of the floating medication bar, measured so it tracks Dynamic Type. Reuse the existing `EdgeFadeMask`; correct the stale "frost under glass" rationale.
2. **A1 — keep the marker dot on greyed registered days**. In `CalendarDayCell`, stop returning `Color.clear` for above-selection days; render the normal marker and let the cell's existing `Opacity.deEmphasis` dim it. Amend spec 014's FR-011/FR-014 and keep the VoiceOver "has check-ins" label so the registered cue isn't opacity-only for assistive tech.
3. **A3 — tokenise the Log-Dose sheet** to Paper & Pollen. Reproduce the mismatch on-sim, then replace default-`Form` chrome and ad-hoc `Color.secondary.opacity(...)` chips with `Theme`/`Palette` tokens; verify light + dark.

Technical approach: all three are SwiftUI view edits — no new services, no view-model logic, no persistence. Per Constitution Principle X, SwiftUI views are exempt from test-first; correctness is proven by build + on-simulator run (Principle II) with the existing suite kept green. The only non-trivial design decision is **how to size the A2 top fade** (the `safeAreaInset` bar consumes the content's top inset, so a naïve `safeAreaInsets.top` read returns 0) — resolved in Phase 0 and validated on-sim.

## Technical Context

**Language/Version**: Swift 6+ (strict concurrency).

**Primary Dependencies**: SwiftUI (iOS 26). No new dependencies. Reuses `EdgeFadeMask` ([app-four/Views/Components/EdgeFadeMask.swift](../../app-four/Views/Components/EdgeFadeMask.swift)) and the existing `MedicationBarOverlay` / `ScreenContainer` placement.

**Storage**: SwiftData — **unchanged**. This feature touches no `@Model`, no schema, no persisted value (spec FR-015).

**Testing**: Swift Testing for the existing suite (must stay green). This feature adds no new logic tests — all three changes are view/styling and fall under the Principle X SwiftUI-view exemption (build + on-sim verification). Existing `CalendarHeaderScrollFadeTests` covers the *Calendar header* fade, a different feature; it must remain green (A2 does not touch it).

**Target Platform**: iOS 26 (primary), iPadOS (secondary).

**Project Type**: Single-target mobile app (`app-four`).

**Performance Goals**: Scroll stays at 60 fps with the top mask applied; the mask must not introduce per-frame layout thrash (mask height is derived once from the bar, not recomputed per scroll tick).

**Constraints**: Presentation-only. Must hold across light/dark, default → accessibility Dynamic Type sizes, and preserve VoiceOver labelling. Settings must keep its native grouped-`List` chrome (017 exemption) — the mask must not break list separators, selection, or scroll-to-top.

**Scale/Scope**: ~3 source files (`CalendarDayCell.swift`, `InsightsView.swift`, `SettingsView.swift` + possibly a small bar-height measurement helper in `MedicationBarOverlay.swift`/`ScreenContainer.swift`, and `MedicationLogSheet.swift`), plus a one-paragraph amendment to `specs/014-daily-card/spec.md`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.* (constitution v1.2.0)

- [x] **I. SwiftUI-First** — all edits are SwiftUI on iOS 26 APIs; no UIKit. No *new* views are introduced (existing views modified), so the "HTML mockup first" rule does not trigger; A4 (the redesign that needs a fresh mockup) is deferred out of this feature. **PASS**
- [x] **II. Test-Build-Ship** — plan ends in a build + full-suite run + on-sim verification of all three fixes before "done". **PASS**
- [x] **III. Correctness Over Speed** — fixes the root causes (hardcoded `top: 0`; dropped dot; untokenised sheet) and removes the now-false "frost under glass" comment rather than patching around it. No shims, no dead code. The A1 greyscale tradeoff is surfaced, not hidden. **PASS**
- [x] **IV. Minimal Surface** — reuses `EdgeFadeMask`; adds at most one small bar-height measurement seam (justified: FR-003 requires a measured, not constant, height). No new flags/abstractions. **PASS**
- [x] **V. Solo Git Discipline** — lands as one revertable feature on a dedicated `fix/qa-review-2026-06-24` branch off `main` (NOT stacked onto the multi-feature `feat/ux-improvements-015-017`), `/code-review` before merge. **PASS** (see Project Structure → Git).
- [x] **VI. On-Device Privacy** — N/A: no data, audio, logging, or network touched. **PASS**
- [x] **VII. Deterministic, Measured Extraction** — N/A: extraction pipeline untouched; eval harness not implicated. **PASS**
- [x] **VIII. Service-Oriented Architecture** — N/A: no new capability/service; no view-model logic added; any bar-height read is view-layout, not a service. **PASS**
- [x] **IX. Pre-Release Data Posture** — N/A: no schema change, no attributes added/removed (FR-015). **PASS**
- [x] **X. Test-First Development** — no new testable logic (models/services/VMs/extraction): all three changes are SwiftUI-view presentation, EXEMPT per Principle X and verified by build + on-sim run. No `/speckit-tasks` test-RED checkpoint is owed because there is no logic unit to RED. **PASS**

**Result: all gates PASS / N-A. No violations → Complexity Tracking is empty.**

## Project Structure

### Documentation (this feature)

```text
specs/018-qa-review-fixes/
├── plan.md              # This file
├── research.md          # Phase 0 — the 4 design decisions (fade sizing, List mask, dot, A3 audit)
├── data-model.md        # Phase 1 — explicitly: no data-model changes
├── quickstart.md        # Phase 1 — on-sim validation guide for A1/A2/A3
├── contracts/
│   └── ui-behavior.md   # Phase 1 — the visual/interaction contract for the three fixes
└── checklists/
    └── requirements.md  # (from /speckit-specify)
```

### Source Code (repository root)

```text
app-four/
├── Views/
│   ├── Components/
│   │   ├── CalendarDayCell.swift        # A1 — render marker for above-selection days (drop the Color.clear branch)
│   │   ├── EdgeFadeMask.swift           # A2 — reused as-is (or minor: clarify topFade semantics)
│   │   └── MedicationLogSheet.swift     # A3 — tokenise Form chrome + chips to Theme/Palette
│   ├── InsightsView.swift               # A2 — line 113: top:0 → measured bar height
│   └── SettingsView.swift               # A2 — apply top edge fade to the List
└── DesignSystem/
    ├── ScreenContainer.swift            # A2 — fix stale barFadeHeight=0 rationale; host bar-height measurement if shared
    └── MedicationBarOverlay.swift       # A2 — surface the measured bar height (if measured at the bar) 

specs/014-daily-card/spec.md             # A1 — amend FR-011/FR-014 (dot dimmed, not dropped) + record tradeoff
```

**Structure Decision**: Existing `app-four` single-target layout; no new directories. **Git:** land on a new `fix/qa-review-2026-06-24` branch cut from `main`, kept separate from `feat/ux-improvements-015-017` (which already bundles 015/016/017) so this QA pass stays a single revertable PR per Principle V. If the owner prefers to ride the existing branch, that's a conscious bundling decision to confirm — default is a dedicated branch.

## Complexity Tracking

> No Constitution violations — table intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (none)    | —          | —                                   |
