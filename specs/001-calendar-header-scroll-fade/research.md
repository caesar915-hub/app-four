# Phase 0 Research: Calendar Header Scroll-Fade

All Technical Context unknowns resolved below. No open `NEEDS CLARIFICATION`.

## R1 — Where the header must live

**Decision**: Move `CalendarHeaderView` + its `Divider` from the pinned `VStack` sibling into the internal `ScrollView`'s `LazyVStack` as the first child (above the `DayCard` rows).

**Rationale**: The occlusion bug is structural — at [CalendarLibraryView.swift:27-44](../../app-four/Views/Library/CalendarLibraryView.swift#L27-L44) the header is a sibling rendered *above* `timelineList`'s `ScrollView`, so scrolling content passes behind it. The only way content stops going "behind" the header is for the header to be part of the same scroll content and physically move with it. This is also why "fade to nothing" is natural: a scrolled-away in-content header is gone by definition; no compact replacement is needed.

**Alternatives considered**:
- *Keep header pinned, just fade it*: rejected — fading a pinned header still leaves the content scrolling behind it during the fade, and a faded-but-present pinned header still consumes hit-test space. Doesn't fix occlusion.
- *`safeAreaInset(edge:.top)` for the header*: rejected — that re-pins it (same class as today's bug) and is how the medication bar is intentionally pinned; using it for the header would conflate the two.

## R2 — Reading scroll offset to drive opacity

**Decision**: Use `onScrollGeometryChange(for: CGFloat.self)` on the internal `ScrollView` to observe `geometry.contentOffset.y` (relative to `contentInsets`), store it in local `@State`, and compute header opacity as `1 - clamp(offset / fadeDistance, 0, 1)` where `fadeDistance` ≈ the header's natural height.

**Rationale**: `onScrollGeometryChange` (iOS 18+, present on the iOS 26 target) is the modern, allocation-free way to read live scroll offset without a `GeometryReader` preference-key dance. Opacity from offset is a pure, cheap function — no layout invalidation, safe at 60fps. Clamping guarantees opacity ∈ [0,1] and a stable resting state.

**Alternatives considered**:
- *`GeometryReader` + `PreferenceKey`*: rejected — more code, more allocations, the classic source of scroll-jank; `onScrollGeometryChange` supersedes it.
- *`scrollTransition`*: rejected — applies per-item transitions as items cross viewport edges; awkward for "one header fades over the first N points of scroll" and harder to make the opacity exactly track offset for the short-timeline rest state.
- *Deriving opacity from `topDayID`/`scrollPosition(id:)`*: rejected — that's an item-identity signal, not a continuous offset; can't produce a smooth fade.

**Note on `fadeDistance`**: the header's height varies (week vs expanded month, and taller at accessibility text sizes / force-week). Use a measured height (read once via `onGeometryChange`/`background(GeometryReader)` on the header) rather than a hardcoded constant, so the fade completes exactly as the header clears — avoids a magic number and respects Dynamic Type. A measured value also keeps the resting state correct when the month grid expands.

## R3 — Day row tappable until faded

**Decision**: Apply `.opacity(headerOpacity)` to the header and gate interaction with `.allowsHitTesting(headerOpacity > epsilon)` (epsilon ≈ 0.05).

**Rationale**: SwiftUI keeps hit-testing a view at low opacity unless told otherwise; explicitly disabling hits only once effectively invisible prevents "ghost taps" on an invisible header while satisfying FR-005 (tappable until fully faded).

**Alternatives considered**: leaving hit-testing always on — rejected, invisible-but-tappable header would intercept taps meant for the now-top timeline content.

## R4 — Scroll-to-top recovery (status-bar tap + scroll up)

**Decision**: (a) Scrolling up naturally restores opacity because it's offset-driven — no extra code (FR-006 scroll-up half). (b) For status-bar-tap-to-top, give the internal `ScrollView` a `ScrollPosition` and rely on the system's status-bar-tap behavior; verify it targets this `ScrollView`. If the system tap does not reach the inner `ScrollView` (because the screen uses `ScreenContainer(scrollable: false)` and the inner scroll view isn't the "main" one), wire an explicit `scrollPosition.scrollTo(edge: .top)` triggered the same way `ScreenContainer` already does via `scrollResetToken` — i.e. mirror that pattern on the inner `ScrollView`.

**Rationale**: `ScreenContainer` already documents and implements a `scrollResetToken` → `scrollPosition.scrollTo(edge:.top)` pattern for its *own* scroll view ([ScreenContainer.swift](../../app-four/Views/Components/ScreenContainer.swift)). Because `CalendarLibraryView` opts out (`scrollable: false`) and runs its own `ScrollView`, the same mechanism must be applied locally. Status-bar tap is the OS-standard "scroll to top"; we confirm it during implementation on-device and fall back to the explicit token only if needed (avoids speculative code per Principle IV).

**Alternatives considered**:
- *Custom floating "back to top" button*: rejected — out of scope (spec Assumptions) and adds persistent chrome the user explicitly rejected.

## R5 — Preserving the two-way scroll/selection sync

**Decision**: Keep `.scrollPosition(id: $topDayID, anchor: .top)` and the existing `onChange(of: topDayID)` → `selectedDay` logic untouched. The new offset observer (`onScrollGeometryChange`) is additive and independent — one reads *which item* is at the top (selection), the other reads *how far* scrolled (opacity).

**Rationale**: Two orthogonal signals on the same `ScrollView` don't conflict. Moving the header *into* the scroll content does not change item identities used by `scrollPosition(id:)` because the header is not `.id`-tagged as a day; only `DayCard`s carry `.id(day.date)`.

**Risk**: the header now occupies space *above* the first `DayCard`, so the day that `scrollPosition(id:)` reports as "top" at rest is unchanged (first DayCard still anchors once the header scrolls under the top inset). Verify the at-rest selected day still equals the first timeline day. Covered by a regression test (T-sync).

## R6 — Edge cases: short timeline & empty state

**Decision**:
- *Empty state*: the `else` branch renders `emptyState` with no `ScrollView`; the header is not in a scroll context, so opacity stays 1 (FR-010). Keep the header rendering path so an empty calendar still shows the (full, non-fading) header for navigation.
- *Short timeline*: because opacity is `clamp(offset/fadeDistance)` and a non-scrollable `ScrollView` reports offset ≈ 0, opacity rests at 1 (FR-010, SC-006). Bounce/rubber-band briefly perturbs offset but clamping + returning to 0 settles it back to full.

**Rationale**: Offset-driven opacity is self-correcting for "not enough to scroll" — no special-casing needed beyond keeping the header present in the empty branch.

## R7 — Reduce Motion

**Decision**: The opacity *value* always tracks offset (so occlusion never happens — FR-002 is not motion, it's correctness). Only the *animated* restoration on programmatic scroll-to-top is wrapped in `withAnimation(reduceMotion ? nil : Motion.smooth)`, mirroring the existing `scrollList`/`jumpToToday` pattern in the file.

**Rationale**: Matches the codebase's established Reduce Motion handling (`CalendarHeaderView` and `CalendarLibraryView` already branch on `reduceMotion`). The continuous fade is driven by the user's own scroll gesture (direct manipulation), which Reduce Motion does not suppress.

## Summary of decisions

| Topic | Decision |
|---|---|
| Header placement | Inside internal `ScrollView` `LazyVStack`, first child |
| Offset source | `onScrollGeometryChange(for: CGFloat.self)` → `contentOffset.y` |
| Opacity | `1 - clamp(offset / measuredHeaderHeight, 0, 1)` |
| Tappable-until-faded | `.allowsHitTesting(opacity > 0.05)` |
| Scroll-to-top | System status-bar tap; fallback `scrollTo(edge:.top)` via local token |
| Selection sync | Unchanged `scrollPosition(id:)` + `onChange`; additive offset observer |
| Short/empty | Self-correcting via clamp; header kept in empty branch at opacity 1 |
| Reduce Motion | Value always tracks; only programmatic restore animation gated |
