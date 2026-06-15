# Implementation Plan: Calendar Header Scroll-Fade

**Branch**: `fix/calendar-header-scroll-fade` | **Date**: 2026-06-15 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-calendar-header-scroll-fade/spec.md`

## Summary

Today the Calendar tab pins the `CalendarHeaderView` + `Divider` as a `VStack` sibling **above** the timeline `ScrollView` ([CalendarLibraryView.swift:27-44](../../app-four/Views/Library/CalendarLibraryView.swift#L27-L44)), so timeline rows scroll *under* an opaque pinned header — the reported visual bug. The fix moves the header block **inside** the scroll content as the first item of the existing `LazyVStack`, and drives its opacity from the live scroll offset (read with `onScrollGeometryChange`): fully visible at the top, fading to 0 as the user scrolls up, with nothing replacing it. The day row stays tappable while partially visible; a status-bar tap (and scrolling back to the top) restores it. The medication bar is provided by `ScreenContainer`'s `.medicationBarOverlay()` outside the scroll content and is untouched. No new types, no data-model change.

## Technical Context

**Language/Version**: Swift 6 (strict concurrency)

**Primary Dependencies**: SwiftUI (iOS 26+), existing `CalendarHeaderView`, `ScreenContainer`, `EdgeFadeMask`, `MoodLibraryViewModel`

**Storage**: N/A — presentation-only change; reads existing SwiftData-backed view model, writes nothing

**Testing**: XCTest (unit/integration); existing calendar day-selection + scroll-sync tests are the regression baseline

**Target Platform**: iOS 26+ (primary), iPadOS (secondary)

**Project Type**: Mobile app (single SwiftUI target `app-four`)

**Performance Goals**: 60fps scroll; opacity update must not drop frames (offset→opacity is a cheap pure computation, no layout thrash)

**Constraints**: No new dependencies; preserve the two-way `scrollPosition(id:)` ↔ `selectedDay` sync; honor Reduce Motion and accessibility force-week; medication bar must be byte-for-byte unaffected

**Scale/Scope**: One screen (`CalendarLibraryView`), one component reused (`CalendarHeaderView`); ~1 file materially changed plus tests

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. SwiftUI-First** — Pure SwiftUI, modern scroll APIs (`onScrollGeometryChange`, `ScrollPosition`), no UIKit. HTML mockup exists first: [2026-06-15-calendar-scroll-fade-header.html](../../docs/superpowers/plans/2026-06-15-calendar-scroll-fade-header.html). **PASS**
- [x] **II. Test-Build-Ship** — Plan ends with a buildable change verified by `ios-debugger-agent` + full suite green before PR. **PASS**
- [x] **III. Correctness Over Speed** — No shims/stubs; the short-timeline "stuck partial fade" and programmatic-scroll desync edge cases are handled explicitly, not ignored. **PASS**
- [x] **IV. Minimal Surface** — No new types, no abstraction, no feature flag. Opacity is local `@State` derived from scroll offset; header moves into the existing `LazyVStack`. **PASS**
- [x] **V. Solo Git Discipline** — One revertable change on `fix/calendar-header-scroll-fade`; `/code-review` before merge; `main` stays releasable. **PASS**
- [x] **VI. On-Device Privacy** — No data leaves device; no new logging. **PASS**
- [x] **VII. Deterministic, Measured Extraction** — Does not touch `NLNoteExtractor` or the lexicon; eval harness not implicated. **N/A → PASS**
- [x] **VIII. Service-Oriented Architecture** — No new capability/service; `MoodLibraryViewModel` stays `@MainActor @Observable` with no added persistence logic. **PASS**
- [x] **IX. Pre-Release Data Posture** — No schema change. **N/A → PASS**

No violations → Complexity Tracking left empty.

## Project Structure

### Documentation (this feature)

```text
specs/001-calendar-header-scroll-fade/
├── plan.md              # This file
├── spec.md              # Feature spec
├── research.md          # Phase 0 — scroll-offset → opacity + scroll-to-top approach
├── quickstart.md        # Phase 1 — manual + automated validation guide
├── contracts/
│   └── scroll-fade-interaction.md   # UI interaction contract (behavioral)
└── checklists/
    └── requirements.md  # Spec quality checklist (from /speckit-specify)
```

### Source Code (repository root)

```text
app-four/
├── Views/
│   ├── Library/
│   │   └── CalendarLibraryView.swift        # CHANGED: header moves into ScrollView; offset→opacity; scroll-to-top
│   └── Components/
│       ├── CalendarHeaderView.swift         # UNCHANGED (rendered inside scroll content; opacity applied by parent)
│       ├── CalendarDayCell.swift            # UNCHANGED
│       ├── ScreenContainer.swift            # UNCHANGED (medication bar overlay; scrollable:false path stays)
│       └── EdgeFadeMask.swift               # UNCHANGED (reused on internal list)

app-fourTests/ (or existing test target)
└── CalendarHeaderScrollFadeTests.swift      # NEW: opacity-from-offset mapping + scroll-sync regression guards
```

**Structure Decision**: Single SwiftUI target. The change is localized to `CalendarLibraryView` — it owns the internal `ScrollView` (because it uses `ScreenContainer(scrollable: false)`), so both the header placement and the offset-driven opacity live there. `CalendarHeaderView` stays a dumb reusable component; the parent applies `.opacity()` and allows hit-testing while partially visible. Pure presentation; no new files beyond a focused test.

## Complexity Tracking

> No constitution violations — no entries.
