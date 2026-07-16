<!-- Created: 2026-07-16 14:05 (WEST) · Updated: 2026-07-16 14:41 (WEST) -->
# Implementation Plan: Calendar Strip Scroll-Collapse & Fade

**Branch**: `feat/035-calendar-scroll-collapse` | **Date**: 2026-07-16 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/035-calendar-scroll-collapse/spec.md`

> **Base-state note**: this branch is cut from pre-merge `main`, but every technical fact below was
> verified against the **post-merge target** — the `feat/034-daycard-a01` worktree at
> `/Users/caesargrey/Projects/app-four-spm` (PRs #28 + #31, approved pending device QA). Implementation
> starts only after both merge and this branch rebases onto the result. The pre-baked design this plan
> consumes lives at `~/.claude/plans/unified-doodling-pinwheel.md`.

## Summary

Move the Calendar tab's strip (`CalendarHeaderView` + Divider) from a fixed sibling **into** the day-card list's scroll content so it scrolls away naturally, and drive a threshold-gated opacity fade (dead zone 24pt → linear fade over a band scaled to the strip's measured height) plus a compact date title that snap-fades into the empty inline nav bar at ≥80% collapse. All decision math lives in a pure, test-first `CalendarStripFade` enum; the view applies its outputs via the app's first `onScrollGeometryChange` reader. The medication bar (a `safeAreaInset` sibling outside the content) is structurally unaffected. Supersedes spec-001.

## Technical Context

**Language/Version**: Swift 6.2 (Xcode 16), SwiftUI

**Primary Dependencies**: SwiftUI only — `onScrollGeometryChange` (iOS 18+), `onGeometryChange`, `ScrollPosition(edge:)`, `scrollBounceBehavior`; local SPM package `SquirlDesignSystem` (Motion/Spacing/Typography tokens)

**Storage**: N/A (no persisted state; collapse progress is derived per-frame from scroll geometry)

**Testing**: Swift Testing (`@Suite`/`@Test`/`#expect`); pure-logic pattern per `app-fourTests/Views/DayCardExpandStateTests.swift`

**Target Platform**: iOS 26.0 (deployment target; all APIs used are ≤ iOS 18)

**Project Type**: mobile-app (single Xcode project + local SPM design-system package)

**Performance Goals**: no perceptible hitch at 120 Hz through the fade band on a 30+ card day; fade driver fires ≤ ~100 quantized state updates per gesture and is silent outside the band

**Constraints**: GPU-only animated properties (opacity; zero scroll-driven layout/height animation); Reduce-Motion pattern `reduceMotion ? nil : Motion.X`; zero style literals outside named constants; med bar, `ScreenContainer`, `MedicationBarOverlay`, `CalendarHeaderView` internals untouched

**Scale/Scope**: 1 screen (`CalendarLibraryView`), 1 new pure-logic file, 1 new test file, ~0 design-system changes

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.* (v1.2.0)

- [x] **I. SwiftUI-First** — pure SwiftUI on iOS-26-era APIs; no UIKit. No *new views* are created (an existing screen's motion behavior changes; the strip, cards, and nav chrome all already exist), so no new HTML mockup is required; the behavioral reference is the owner's frame-by-frame Tiimo analysis (2026-07-15).
- [x] **II. Test-Build-Ship** — RED→GREEN unit suite for the math; restructure lands at behavioral parity before the fade is wired; owner device-QA gate before PR.
- [x] **III. Correctness Over Speed** — the `topDayID` deletion is mandatory correctness (in-content strip + top-item-anchored programmatic scroll = calendar ejects itself on every date tap); no shims.
- [x] **IV. Minimal Surface** — no generic `ScrollCollapseHeader` abstraction, no SPM addition; one consumer → logic lives beside it (`app-four/Views/Library/`). Constants are file-local named statics, not new token-system surface.
- [x] **V. Solo Git Discipline** — one revertable feature on `feat/035-calendar-scroll-collapse`; `/code-review` + owner device QA before merge.
- [x] **VI. On-Device Privacy** — N/A surface (no data leaves the view layer).
- [x] **VII. Deterministic, Measured Extraction** — N/A (no NLP/extraction surface).
- [x] **VIII. Service-Oriented Architecture** — N/A (no new capability/service; view-local presentation math; no VM changes — `dayLabel(for:)` reused as-is).
- [x] **IX. Pre-Release Data Posture** — N/A (no schema).
- [x] **X. Test-First Development** — `CalendarStripFade` (the only logic) is built RED→GREEN with Swift Testing before any view wiring; SwiftUI wiring itself is view-exempt (build + device QA).

**Post-design re-check (after Phase 1)**: unchanged — all PASS / N-A. No Complexity Tracking entries needed.

## Project Structure

### Documentation (this feature)

```text
specs/035-calendar-scroll-collapse/
├── spec.md              # /speckit-specify output (done)
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output (device-QA guide)
├── contracts/
│   └── strip-fade-behavior.md   # UI behavior contract (scroll↔opacity↔title)
└── tasks.md             # /speckit-tasks output (NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
app-four/
├── Views/Library/
│   ├── CalendarLibraryView.swift      # MODIFIED — restructure + wiring + toolbar; topDayID deleted
│   └── CalendarStripFade.swift        # NEW — pure math + named constants (no SwiftUI import)
├── Views/Components/
│   ├── CalendarHeaderView.swift       # UNTOUCHED (placement changes, internals don't)
│   └── EdgeFadeMask.swift             # UNTOUCHED (kept as-is on the ScrollView)
└── DesignSystem/
    ├── ScreenContainer.swift          # UNTOUCHED (read-only contract: nav bar, med bar, tab bar)
    └── MedicationBarOverlay.swift     # UNTOUCHED (safeAreaInset sibling — the med-bar guarantee)

app-fourTests/
└── Views/
    └── CalendarStripFadeTests.swift   # NEW — RED before CalendarStripFade.swift exists
```

**Structure Decision**: single-project app target; the new logic file sits beside its only consumer in `Views/Library/` (mirrors `DayTimelineBuilder` naming: domain noun, enum of pure statics). Nothing enters `SquirlDesignSystem` — collapse tuning values are gesture metrics scoped to this screen, not app-wide layout tokens.

## Architecture (verified against the post-merge worktree)

### A. Restructure — strip INTO the ScrollView (FR-001)

`CalendarLibraryView.timelineList` today: `VStack { pinnedHeader; ScrollView { LazyVStack { DayCard… } } }` — strip fixed above the scroll. Target:

```swift
ScreenContainer(title: "", showsMedicationBar: true, scrollable: false, path: $path) {
    Group {                                     // ← replaces the outer VStack: the ScrollView must own the top edge
        if viewModel.hasAnyEntries {
            ScrollView {
                VStack(spacing: 0) {            // plain VStack — the strip is ALWAYS materialized (it drives geometry)
                    headerBlock                 // strip + Divider fade as ONE unit
                        .opacity(CalendarStripFade.stripOpacity(progress: collapseProgress))
                        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { stripHeight = $0 }
                    LazyVStack(spacing: Spacing.m) { /* DayCards — unchanged */ }
                        .padding(...)           // existing paddings move inside unchanged
                }
            }
            .scrollPosition($listPosition)      // NEW state: ScrollPosition(edge: .top) — replaces topDayID
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                CalendarStripFade.progress(offset: geo.contentOffset.y + geo.contentInsets.top,
                                           stripHeight: stripHeight)
            } action: { _, new in collapseProgress = new }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)   // FR-013
            .edgeFadeMask(top: 0, bottom: Spacing.section)         // unchanged
        } else {
            VStack(spacing: 0) { pinnedHeader; /* empty state */ } // unchanged path (FR-012)
        }
    }
    .toolbar { compactTitle }                   // propagates — content is inside ScreenContainer's NavigationStack
    // .navigationDestination — unchanged
}
```

Load-bearing subtlety: the old outer `VStack` must become `Group` so the ScrollView is the top-edge view — the med-bar `safeAreaInset` then insets the scroll content while the content scrolls *under* the floating capsule and nav area (same look as Insights). Keeping the VStack would hard-clip the list below the med bar.

### B. The `topDayID` correctness fix (FR-008)

`.scrollPosition(id: $topDayID, anchor: .top)` + `scrollList(to:)` writing `topDayID = target` would, with the strip in-content, scroll the strip off-screen on **every date tap** (the filtered list puts the selected day at index 0). Replace with the `ScreenContainer` pattern: `@State listPosition = ScrollPosition(edge: .top)` + `withAnimation(reduceMotion ? nil : Motion.smooth) { listPosition.scrollTo(edge: .top) }`. `topDayID` is written in exactly one place and read nowhere else (grep-verified) → delete it.

### C. Fade driver — one `onScrollGeometryChange`, not `visualEffect` (FR-002/003/004/011)

- `contentOffset.y + contentInsets.top` is **exactly 0 at rest** by documented contract — a clean origin for the dead zone; `visualEffect`'s `proxy.frame(in: .scrollView).minY` has no such origin under nav-bar + med-bar insets.
- The math must be unit-testable (Constitution X); a `visualEffect` closure is unreachable by tests.
- The compact title needs scroll geometry anyway — one source of truth, no desync.
- Progress is clamped and quantized to 1/100 → the `action` only fires inside the fade band (~≤100 updates/gesture), and the only animated property is opacity (compositor-only).

### D. Pure math — `CalendarStripFade` (FR-014)

```swift
enum CalendarStripFade {
    static let deadZone: CGFloat = 24          // scroll travel absorbed before any fade (anti-flicker)
    static let minFadeDistance: CGFloat = 44   // zero-height guard (pre-measurement frame)
    static let titleReveal: CGFloat = 0.8      // collapse progress that reveals the compact title

    static func progress(offset: CGFloat, stripHeight: CGFloat) -> CGFloat {
        let band = max(stripHeight - deadZone, minFadeDistance)
        let raw = (offset - deadZone) / band
        return (min(max(raw, 0), 1) * 100).rounded(.down) / 100   // FLOOR: never completes early (C4)
    }
    static func stripOpacity(progress: CGFloat) -> CGFloat { 1 - progress }
    static func showsTitle(progress: CGFloat) -> Bool { progress >= titleReveal }
}
```

Band scales with **measured** height → the week strip (~130pt) and expanded month (~290pt) both finish fading exactly as they clear (FR-002); negative offsets clamp (FR-004).

### E. Compact title (FR-005/006, US2)

`ToolbarItem(placement: .principal)` in `CalendarLibraryView` (content sits inside the container's `NavigationStack`; `navigationTitle("")` leaves principal free): `Text(viewModel.dayLabel(for: selectedDay))` in `Typography.headline`, `.opacity(showsTitle ? 1 : 0)`, `.animation(reduceMotion ? nil : Motion.snappy, value: showsTitle)` where `showsTitle = CalendarStripFade.showsTitle(progress: collapseProgress)`. Snap-fade, native large-title-handoff feel. Reuses `MoodLibraryViewModel.dayLabel(for:)` — zero VM changes.

### F. Reduce Motion (FR-006, edge cases)

The scroll-tracked fade is direct manipulation (follows the finger) — it stays. Gated: the title snap-fade and the programmatic scroll-to-top (already gated today).

### G. What NOT to do

1. No fixed strip + height animation (per-frame layout thrash; re-creates spec-001's occlusion complaint).
2. No `visualEffect` strip fade (origin ambiguity, untestable, second geometry pipeline).
3. No retention of `.scrollPosition(id:)` (see B).
4. No generic DesignSystem/SPM modifier (one consumer — Principle IV).
5. No auto-collapse of the expanded month on scroll (layout animation mid-scroll; fights the user; FR-010).
6. No zIndex/background chrome on the strip (in-content → collision impossible).
7. No `GeometryReader`+PreferenceKey pipeline and no `scrollTransition` (superseded APIs for this job).

## Phase 0 → [research.md](research.md) · Phase 1 → [data-model.md](data-model.md), [contracts/strip-fade-behavior.md](contracts/strip-fade-behavior.md), [quickstart.md](quickstart.md)

## Complexity Tracking

*(empty — no constitution violations)*
