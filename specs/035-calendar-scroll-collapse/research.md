<!-- Created: 2026-07-16 14:05 (WEST) · Updated: 2026-07-16 14:05 (WEST) -->
# Research — Calendar Strip Scroll-Collapse & Fade (spec-035)

No NEEDS CLARIFICATION markers survived spec authoring; the decisions below were resolved during the
2026-07-15/16 planning session (Explore + Plan agents over the post-merge worktree
`/Users/caesargrey/Projects/app-four-spm`, plus owner rulings). Sources: the owner's frame-by-frame
Tiimo scroll-effect analysis (2026-07-15), stale prior art `specs/001-calendar-header-scroll-fade/`
(drafted 2026-06-15, never implemented), and direct file reads cited inline.

---

**D1 — Strip placement: inside the scroll content (not fixed + height-animated)**
- **Decision**: Move `headerBlock` (CalendarHeaderView + Divider) inside the ScrollView as the first
  element of a plain `VStack(spacing: 0)`, ahead of the existing `LazyVStack` of DayCards.
- **Rationale**: The strip then scrolls away naturally and its space is reclaimed by layout, not by
  animating height (which would invalidate layout every frame — the jank spec-001's research already
  rejected, R1). A plain VStack (not LazyVStack) guarantees the strip is always materialized so its
  geometry is measurable. Laziness for the cards is preserved by the nested LazyVStack.
- **Alternatives considered**: (a) fixed strip + scroll-driven height collapse — rejected: per-frame
  layout thrash violates the GPU-only constraint; (b) `SliverPersistentHeader`-style pin-then-release
  (translate compensation while pinned) — rejected: adds zIndex/occlusion complexity for a nuance the
  Tiimo reference doesn't actually show (its strip scrolls from the first post-threshold pixel).

**D2 — Fade driver: single `onScrollGeometryChange` → quantized `@State` progress**
- **Decision**: One `onScrollGeometryChange(for: CGFloat.self)` on the ScrollView computing
  `CalendarStripFade.progress(offset: contentOffset.y + contentInsets.top, stripHeight:)`.
- **Rationale**: `contentOffset.y + contentInsets.top` is exactly 0 at rest by documented contract —
  the only clean origin for a 24pt dead zone under nav-bar + med-bar insets. The transform's clamped,
  1/100-quantized return means the action fires only inside the fade band (~≤100 updates/gesture).
  The pure function is unit-testable (Constitution X). The compact title needs the same geometry —
  one source of truth.
- **Alternatives considered**: `.visualEffect { content, proxy in … }` per-element fade — rejected:
  `proxy.frame(in: .scrollView).minY` has a nonzero, device-/Dynamic-Type-dependent rest value here
  (scroll bounds extend under status bar, nav bar, and the med-bar `safeAreaInset`), the closure is
  unreachable by tests, and it would be a second geometry pipeline running beside the one the title
  requires. `GeometryReader`+PreferenceKey — superseded API for this job (spec-001 R2 alternatives).
  `scrollTransition` — wrong tool: it animates items entering/leaving the viewport, not
  threshold-gated custom math.

**D3 — Programmatic scroll: edge-based `ScrollPosition`, `topDayID` deleted**
- **Decision**: Replace `.scrollPosition(id: $topDayID, anchor: .top)` with
  `@State listPosition = ScrollPosition(edge: .top)` + `listPosition.scrollTo(edge: .top)` in
  `scrollList(to:)`.
- **Rationale**: Correctness, not preference. With the strip in-content, `scrollTo(id, anchor: .top)`
  on the selected day (always index 0 in the filtered list) scrolls **the calendar itself** off-screen
  on every date tap. `topDayID` is written exactly once (`scrollList`, CalendarLibraryView.swift:125)
  and read nowhere else (grep-verified) — the filter invariant means "scroll to selected day" ≡
  "scroll to top". Edge-based is the exact pattern `ScreenContainer.swift:37/75` already uses.
- **Alternatives considered**: keeping id-based and anchoring the strip with a synthetic id — rejected:
  re-introduces the strip into the scroll-to target set and leaves a dead state variable's semantics
  ("top day") lying about what it does.

**D4 — Fade band scales with measured strip height**
- **Decision**: `band = max(stripHeight − deadZone, minFadeDistance)`; height measured with
  `onGeometryChange(for: CGFloat.self, of: { $0.size.height })` on `headerBlock`.
- **Rationale**: The strip is ~130pt as a week and ~250–300pt as an expanded month (measured in the
  worktree; cells are 44pt-min rows). A fixed band would fade the month grid out long before it clears
  (or the week strip long after). Height-scaling makes both complete exactly as the strip clears —
  same *feel* in both modes (FR-002). `onGeometryChange` fires only on real changes (expand toggle,
  Dynamic Type, rotation) — not per scroll frame.
- **Alternatives considered**: fixed 100pt band (the Tiimo doc's example numbers) — rejected: tuned for
  a fixed-height header, wrong for a 2.2× variable one.

**D5 — Compact title: principal ToolbarItem, snap-fade at progress ≥ 0.8**
- **Decision**: `ToolbarItem(placement: .principal)` in `CalendarLibraryView` with
  `viewModel.dayLabel(for: selectedDay)` (existing formatter, MoodLibraryViewModel.swift:157),
  `Typography.headline`, opacity driven by the boolean `showsTitle(progress:)`, animated
  `Motion.snappy` (Reduce-Motion-gated).
- **Rationale**: Owner decision 2026-07-16 reverses 001-FR-004 (Tiimo cross-fade wanted). Boolean
  snap-fade over continuous tracking: matches the system large-title handoff feel, avoids a
  half-visible title fighting the half-visible strip, and costs one state flip instead of continuous
  re-render. Content sits inside `ScreenContainer`'s NavigationStack, so toolbar items propagate;
  `navigationTitle("")` leaves the principal slot free (device-verify).
- **Alternatives considered**: continuous opacity tracking (`opacity = progress`) — rejected: two
  simultaneously semi-visible date displays reads as clutter; not what iOS large-title collapse does.

**D6 — Reduce Motion: fade stays, animations gated**
- **Decision**: Keep the scroll-tracked fade under Reduce Motion; gate only the title snap-fade and the
  programmatic scroll-to-top (already gated today).
- **Rationale**: The fade is direct manipulation — opacity proportional to the user's own finger
  travel, not autonomous motion; removing it would replace a smooth tracked fade with a pop. Matches
  spec-001 R7's conclusion and the app-wide `withAnimation(reduceMotion ? nil : Motion.X)` pattern
  (~20 sites, e.g. CalendarLibraryView.swift:16/90/124/132).
- **Alternatives considered**: instant show/hide at the threshold under RM — rejected: introduces the
  exact flicker the dead zone exists to prevent.

**D7 — Expanded month: fade uniformly, never auto-collapse on scroll**
- **Decision**: The whole `headerBlock` fades as one unit regardless of week/month mode (FR-010).
- **Rationale**: Auto-collapsing would run `Motion.smooth` height animation *inside* moving scroll
  content — a layout animation mid-scroll (forbidden) that also fights user intent. Expanding at rest
  inside a ScrollView is safe (content grows downward from an anchored top; progress is 0 → opacity
  unaffected). Expanding while partially scrolled re-scales the band → a small opacity step; accepted
  and listed in quickstart QA.
- **Alternatives considered**: auto-collapse-to-week at fade start — rejected per above.

**D8 — Short lists: `.scrollBounceBehavior(.basedOnSize, axes: .vertical)`**
- **Decision**: Add it to the Calendar list ScrollView (FR-013).
- **Rationale**: A one-card old day fits on screen; without this, rubber-band bouncing a non-scrollable
  list can produce transient positive offsets → flicker-fade. `.basedOnSize` disables bounce exactly
  when content fits. Flagged in the spec as a deliberate (benign) behavior change.
- **Alternatives considered**: clamping in the math only — insufficient: bounce produces *genuine*
  positive offsets indistinguishable from real scrolling.

**D9 — Constants live on `CalendarStripFade`, not in the token system**
- **Decision**: `deadZone = 24`, `minFadeDistance = 44`, `titleReveal = 0.8` as documented statics on
  the enum in `app-four/Views/Library/CalendarStripFade.swift`.
- **Rationale**: They are gesture metrics for one screen, not app-wide layout language — putting a
  24pt scroll threshold in `Spacing`/`Metrics` (SPM) would be semantic abuse and widen the design
  system's surface (Principle IV). One place, named, owner-tunable without re-speccing (spec
  Assumptions).
- **Alternatives considered**: `Metrics.Calendar.*` in the SPM package — rejected per above.
