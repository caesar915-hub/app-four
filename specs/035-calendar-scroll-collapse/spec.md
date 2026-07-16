<!-- Created: 2026-07-16 13:57 (WEST) · Updated: 2026-07-16 13:57 (WEST) -->
# Feature Specification: Calendar Strip Scroll-Collapse & Fade

**Feature Branch**: `feat/035-calendar-scroll-collapse`

**Created**: 2026-07-16

**Status**: Draft

**Input**: User description: "Calendar strip scroll-collapse & fade (spec-035, Tiimo-style). On the Calendar tab, the calendar strip scrolls up with the content after a small dead zone and fades out; a compact date title cross-fades into the nav bar; medication bar completely unaffected; supersedes spec-001." (Full technical plan: `~/.claude/plans/unified-doodling-pinwheel.md`; owner's frame-by-frame Tiimo reference analysis, 2026-07-15.)

> **Supersedes `specs/001-calendar-header-scroll-fade/`** (drafted 2026-06-15, never implemented).
> Two of its requirements are explicitly reversed/obsoleted by owner decision (2026-07-16):
> - 001-FR-004 ("no replacement header, compact title, or sticky chrome") is **reversed** — a compact date title now appears as the strip fades (User Story 2).
> - 001-FR-007 (scroll↔selection two-way sync) is **obsolete** — spec-029 made day selection tap/jump-only over a filtered list; scrolling never re-selects.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The calendar strip gets out of the way when browsing entries (Priority: P1)

A user with several check-ins on the selected day scrolls down through their day cards. The calendar strip at the top scrolls up naturally with the content — attached, like any other content — and once a definite scrolling intent is shown (a small dead zone of travel), it fades out smoothly as it slides toward the top of the screen, freeing the whole screen for the entries. Scrolling back down reverses everything exactly: the strip fades back in and settles at full opacity at rest. The floating medication bar never moves, fades, or changes.

**Why this priority**: This is the whole effect — the calendar currently consumes a fixed ~130–300pt of every Calendar-tab screenful even while reading old entries. It is the direct ask (Tiimo reference) and is valuable alone.

**Independent Test**: On a day with enough entries to scroll, scroll up slowly and confirm: no fade during the first ~24pt of travel; then the strip scrolls *with* the content while fading; fully transparent by the time it clears the top content area; exact reverse on the way back; medication bar untouched throughout.

**Acceptance Scenarios**:

1. **Given** the Calendar tab at rest, **When** the user scrolls up less than the dead zone (~24pt), **Then** the strip scrolls normally with content and remains fully opaque (no flicker on accidental nudges).
2. **Given** the user scrolls past the dead zone, **When** scrolling continues, **Then** the strip's opacity decreases proportionally to scroll distance and reaches fully transparent just as the strip clears the top of the content area — for both the week strip and the taller expanded month grid (the fade band scales with the strip's actual height).
3. **Given** the strip is partially or fully faded, **When** the user scrolls back to rest, **Then** the strip is fully opaque at rest with no residual dimming.
4. **Given** the list is at rest, **When** the user pulls down past the top (rubber-band), **Then** the strip never exceeds full opacity and never flashes.
5. **Given** any scroll state, **When** observing the floating medication bar, **Then** its position, opacity, and behavior are pixel-identical to before this feature.
6. **Given** a partially faded strip, **When** the user taps a still-visible date cell, **Then** the tap registers and the selection behaves as today (list resets to top, strip returns to full opacity).
7. **Given** the user taps a date in the strip, **When** the list scrolls to the top of that day's entries, **Then** the strip remains fully visible — the programmatic scroll must never push the calendar itself off-screen (regression guard for the positioning change this requires).

---

### User Story 2 - A compact date title keeps context when scrolled deep (Priority: P2)

Once the strip has (almost) fully faded away, a compact title with the selected day (e.g. "Today, 16 Jul" / "Wednesday, 15 Jul") snap-fades into the top navigation area — the Tiimo cross-fade — so the user always knows which day they're reading. It disappears the same way when the strip returns.

**Why this priority**: Without it the user loses all date context when scrolled deep. Valuable but meaningless without US1.

**Independent Test**: Scroll until the strip is nearly gone; confirm the title appears with a quick fade near full collapse (not gradually tracking the finger), shows the same day label used elsewhere in the app, and disappears when scrolling back.

**Acceptance Scenarios**:

1. **Given** the strip is visible (collapse progress below the reveal point ~80%), **When** the user looks at the navigation area, **Then** no title is shown (as today).
2. **Given** scrolling passes the reveal point, **When** the strip is nearly gone, **Then** the compact title snap-fades in with the selected day's label, matching the day-label wording used elsewhere in the app.
3. **Given** the title is visible, **When** the user scrolls back below the reveal point, **Then** the title snap-fades out.
4. **Given** Reduce Motion is on, **When** the reveal point is crossed, **Then** the title appears/disappears without animation.

---

### Edge Cases

- **Rubber-band pull past top** → progress clamps at zero; strip stays at exactly full opacity.
- **Short list** (an old day with one entry that fits on screen) → the list must not bounce-scroll into a transient fade; the strip never rests partially faded.
- **Empty state** (no entries at all) → the current fixed, non-scrolling layout is kept: strip always opaque, no compact title.
- **Expanded month grid** → fades uniformly as one unit (including its divider); it is never auto-collapsed to week by scrolling. Expanding the month *while partially scrolled* re-scales the fade band and may step the opacity — accepted, verified visually.
- **First frame before the strip's height is measured** → a minimum fade distance guards against divide-by-zero/instant collapse; no visible flash.
- **Reduce Motion** → the scroll-tracked fade itself remains (it is direct manipulation — it follows the user's finger); only the title snap-fade and programmatic scroll animations are suppressed.
- **Accessibility text sizes** (strip force-collapses to week at very large sizes) → measured height keeps the fade band correct; the compact title must remain legible and not truncate to uselessness.
- **VoiceOver** → a fully faded strip must not be focusable; the compact title is announced when shown.
- **Leaving and re-entering the tab / pushing and popping a detail screen** → strip opacity, scroll position, and title state stay mutually consistent (all derived from the same scroll geometry).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The calendar strip (including its trailing divider) MUST scroll with the day-card list content instead of staying fixed above it.
- **FR-002**: The strip MUST remain fully opaque for the first ~24pt of scroll travel (dead zone), then fade linearly to fully transparent over a band that scales with the strip's current rendered height, completing exactly as the strip clears the top content area.
- **FR-003**: The fade MUST reverse symmetrically when scrolling back; at rest the strip is always fully opaque.
- **FR-004**: Rubber-band overscroll (negative travel) MUST clamp — opacity never exceeds 100% and never flickers.
- **FR-005**: A compact title with the selected day's label MUST appear in the top navigation area when collapse progress passes ~80%, using the same day-label wording as the rest of the app, and disappear below that point (supersedes 001-FR-004).
- **FR-006**: The title's appearance MUST be a quick snap-fade (not continuous finger-tracking), suppressed entirely under Reduce Motion.
- **FR-007**: The floating medication bar MUST be completely unaffected — position, opacity, behavior, and its show/hide setting all unchanged.
- **FR-008**: Tapping a date in the strip MUST behave as today (select + jump the list to top) and MUST NOT scroll the strip itself out of view — the existing top-item-anchored programmatic scroll is replaced by an edge-anchored one, and the now-unused top-item state is removed.
- **FR-009**: All existing strip interactions MUST keep working while it is visible: date taps (including on a partially faded strip), week↔month expand toggle, month swipe-paging, and the Today jump.
- **FR-010**: The expanded month grid MUST fade uniformly as one unit and MUST NOT auto-collapse on scroll.
- **FR-011**: Scrolling MUST stay smooth during the fade — only compositor-animatable properties (opacity) change per frame; no layout/height animation is driven by scroll.
- **FR-012**: The empty state (no entries) MUST keep its current fixed layout: always-opaque strip, no compact title.
- **FR-013**: Lists short enough not to scroll MUST NOT exhibit bounce-induced fading (bounce only when content actually exceeds the viewport).
- **FR-014**: The fade/reveal decision logic MUST live in a pure, unit-testable component, written test-first (Constitution X); the view layer only applies its outputs.
- **FR-015**: A fully faded strip MUST NOT be reachable by VoiceOver; the compact title MUST be announced when visible.

### Key Entities

- **Collapse progress**: a single 0–1 value derived from scroll travel and the strip's measured height (0 = at rest/dead zone, 1 = fully collapsed); the sole driver of strip opacity and title visibility.
- **Strip height**: the calendar strip's current rendered height (week vs expanded month vs accessibility-forced week); re-measured only when it changes.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: When scrolled past one strip-height of travel, 100% of the previously strip-occupied vertical space (~130–300pt depending on mode) is available to day-card content.
- **SC-002**: Accidental scroll nudges within the dead zone produce zero visible fade (no flicker) in every attempt.
- **SC-003**: A user can identify the selected day while scrolled deep in the list (via the compact title) without scrolling back — task success 100% once collapsed past the reveal point.
- **SC-004**: Scrolling through the fade remains visually smooth on device (no perceptible hitch at 120 Hz) across a 30+ card day in light and dark mode.
- **SC-005**: Every pre-existing Calendar-tab interaction (date tap, month page, expand toggle, Today jump, card fold/unfold, opening a recording) behaves identically to the pre-change build — zero behavioral regressions in the device-QA sweep.
- **SC-006**: All fade/reveal decision logic is covered by unit tests written before the implementation (RED→GREEN), including dead-zone boundary, completion point, rubber-band clamp, zero-height guard, and reveal threshold.

## Assumptions

- The Tiimo reference (owner's frame-by-frame analysis, 2026-07-15) is the behavioral target; where it and old spec-001 conflict, this spec wins.
- Dead zone ~24pt, reveal point ~80% collapse, and a ~44pt minimum fade band are the starting tuning values; the owner may adjust feel on device without re-speccing (they are named constants in one place).
- Losing direct access to the date picker while scrolled deep is accepted (Tiimo behavior): the user scrolls back to the top to change days.
- The strip's week↔month expand state is left untouched by scrolling; whatever mode it's in fades as-is.
- **Implementation is gated on PRs #28 (spec-033) and #31 (spec-034) merging to `main`** — this branch is cut from pre-merge `main` and will be rebased once they land; spec authoring is intentionally not gated.
- Untouched contracts: the screen container, the medication-bar overlay, and the calendar strip component's internals (only its placement and applied opacity change).
