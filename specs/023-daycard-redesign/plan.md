# Implementation Plan: DayCard redesign — no-pill rows, no-disc tinted header, push-to-detail

**Branch**: `023-daycard-redesign` | **Date**: 2026-06-25 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/023-daycard-redesign/spec.md`

## Summary

Redesign the Calendar `DayCard` so read-only check-in data reads as calm glyph+text
(no pill containers), the day's mood is carried by a tint + a fixed prominent mood
glyph (no cream disc), and a check-in opens its full detail via a **push** (not a
sheet). The data reorganises into four ordered lines per check-in
(mood+time / energy+focus / medication+sleep / feelings+side-effects), medication
is the single accent, sleep moves to line 3 in blue, and feelings/side-effects cap
at four each. Grounded by NN/g · Material · Refactoring UI · Polaris · WCAG · Apple
HIG research and 14 true-scale mockups (`html-mockups/daycard-*`, final
`daycard-prototype-v8.html`).

**Approach**: a self-contained presentation change. Logic (capping, sleep-line,
line-composition, taken-med dedup) lands as test-first computed helpers on the
`Recording` model; the views (`DayCard`, `FoldedDayCardHeader`, `TimelineRow`) are
rewritten and verified by build + on-sim run; the caller switches from `.sheet` to
value-based `navigationDestination`. **Prerequisite (separate PR, see Complexity
Tracking): app-wide SF typography migration** — this plan assumes it has landed.

## Technical Context

**Language/Version**: Swift 6 (strict concurrency)

**Primary Dependencies**: SwiftUI (iOS 26+), `SquirlDesignSystem` SPM package
(Typography, Spacing, Radius, Metrics, Palette, MoodLevel), SwiftData (`Recording`)

**Storage**: SwiftData — read-only here (no schema change)

**Testing**: Swift Testing (`@Test`/`#expect`), test-first per Principle X

**Target Platform**: iOS 26+

**Project Type**: Mobile app (single Xcode target `app-four` + local SPM packages)

**Performance Goals**: 60 fps fold/unfold; no extra allocations per row beyond the
existing `LazyVStack` of `DayCard`s

**Constraints**: on-device only; WCAG 3:1 for informative glyphs + muted ink, light
+ dark; no `minimumScaleFactor`; Dynamic Type wraps rather than truncates the
leading word

**Scale/Scope**: one component family on the Calendar tab — `DayCard`,
`FoldedDayCardHeader`, `TimelineRow`, `TimelineBead` (unchanged), the
`CalendarLibraryView` caller, `Recording` display helpers; delete `TimelineChip`

## Constitution Check

*GATE: Must pass before Phase 0. Re-checked after Phase 1 — still PASS.*

- [x] **I. SwiftUI-First** — PASS. Pure SwiftUI on iOS 26 APIs; 14 HTML mockups
      precede implementation (Principle I / new-UI rule satisfied).
- [x] **II. Test-Build-Ship** — PASS. Build + full suite green before done; on-sim
      light/dark verification of the views via `ios-debugger-agent`.
- [x] **III. Correctness Over Speed** — PASS. `TimelineChip` is deleted (no dead
      code); the SF-prerequisite and the §07 "no back button" reversal are surfaced
      explicitly, not silently cut.
- [x] **IV. Minimal Surface** — PASS. New code is four small computed helpers on
      `Recording` + view rewrites; no new protocol, service, flag, or abstraction.
- [x] **V. Solo Git Discipline** — PASS. Two revertable PRs: PR1 `feat/sf-typography`
      (prerequisite), PR2 `feat/daycard-redesign`; `/code-review` before each merge;
      `main` stays releasable.
- [ ] **VI. On-Device Privacy** — N/A. No data leaves the device; no logging change;
      presentation only.
- [ ] **VII. Deterministic, Measured Extraction** — N/A. Extraction is untouched;
      this changes only how already-extracted fields are displayed and capped. The
      eval harness is not affected.
- [x] **VIII. Service-Oriented Architecture** — PASS. No new capability/service.
      Display helpers live on the `Recording` model (pure, `@MainActor` where the
      existing `displayTags` are); the row is a view reading the model — no
      persistence or heavy work added.
- [ ] **IX. Pre-Release Data Posture** — N/A. No schema change; no new attribute,
      no unique constraint.
- [x] **X. Test-First Development** — PASS. The capping (`feelings(max:)`,
      `sideEffects(max:)`), `sleepLine`, `takenMedicationLines`, and line-composition
      helpers are model logic → RED→GREEN, tests ordered before implementation, Swift
      Testing. Views (`DayCard`/`FoldedDayCardHeader`/`TimelineRow`) are EXEMPT
      (build + on-sim run + mockup).

**Result: PASS** — one justified breadth item (SF migration) in Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/023-daycard-redesign/
├── spec.md          # what & why (done)
├── plan.md          # this file
├── research.md      # Phase 0 — design decisions + sources (next)
├── data-model.md    # Phase 1 — Recording display helpers + line mapping (next)
├── quickstart.md    # Phase 1 — how to verify on sim (next)
├── contracts/       # Phase 1 — helper signatures + acceptance mapping (next)
└── tasks.md         # Phase 2 — /speckit-tasks (TDD-ordered)
```

### Source Code (repository root)

```text
Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/
├── Metrics.swift            # + dayHeaderGlyph (40), rowHeadTop (7, optical), SF row sizes
├── Typography.swift         # (PR1) Fraunces/DM Sans/Plex → SF Pro / SF Mono
└── Palette.swift            # sleepIndigo already present (no change)

app-four/Views/
├── Components/
│   ├── DayCard.swift             # container: tinted header + animated expanding body
│   ├── FoldedDayCardHeader.swift # rewrite: no-disc, fixed inline glyph, summary collapses, title re-centres
│   ├── TimelineRow.swift         # rewrite: 4-line no-pill body; row = push button
│   ├── TimelineBead.swift        # unchanged (mood disc + carry-over ring + %)
│   └── TimelineChip.swift        # DELETE
├── Library/CalendarLibraryView.swift  # .sheet(item:) → path.append + navigationDestination
└── RecordingDetailView.swift          # remove navigationBarBackButtonHidden → standard back

app-four/Models/
└── Recording+MoodDisplay.swift   # + feelings(max:), sideEffects(max:), sleepLine, takenMedicationLines

app-fourTests/
├── Models/RecordingDisplayTests.swift     # NEW (test-first): caps, sleep-line, dedup, line mapping
└── Views/FoldedDayCardHeaderTests.swift   # update for no-disc / summary-collapse state
```

**Structure Decision**: Existing single-target + local-SPM layout. No new modules.
Design tokens stay in `SquirlDesignSystem`; feature views in `app-four/Views`;
display logic on the `Recording` model alongside the existing `displayTags`.

## Phase 0 — research.md (decisions to record)

The design decisions are already made and sourced; `research.md` will capture:
no-pill rationale (chips are interactive affordances — Material/SIDP), grouping by
proximity not boxes (NN/g), medication-as-sole-accent (Polaris/Refactoring UI),
colour-as-reinforcement + 3:1 informative glyphs (WCAG 1.4.1 / G207), SF context
icons + the DESIGN.md icon-language change, and the sheet→push reversal of feature
002. Sources are the workflow output already in this session.

## Phase 1 — data-model.md / contracts (signatures)

`Recording` gains (pure, testable):

```text
takenMedicationLines        -> [String]                  // deduped "Taken <name> <dose>"
sleepLine                   -> (label: String, color)?   // Palette.sleepIndigo
feelings(max: Int = 4)      -> (shown: [String], overflow: Int)
sideEffects(max: Int = 4)   -> (shown: [String], overflow: Int)
```

Line mapping (which category → which line), topics suppressed, carry-over excluded
from the medication line (it lives on the bead). Contracts/ maps each FR + acceptance
scenario to a test.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Breadth: app-wide SF typography migration (Principle IV — touches the whole app, not just this feature) | The owner chose SF app-wide; the card's row/header sizes are tuned for SF and would read wrong over Fraunces. Centralised in `Typography.swift` (call sites unchanged). | "SF on the card only" rejected — it creates the two-app inconsistency the design-principles skill and DESIGN.md warn against. Isolated as **PR1**, independently revertable, so it does not entangle the card diff. |
