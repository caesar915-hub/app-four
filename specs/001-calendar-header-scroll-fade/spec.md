# Feature Specification: Calendar Header Scroll-Fade

**Feature Branch**: `001-calendar-header-scroll-fade`

**Created**: 2026-06-15

**Status**: Draft

**Input**: User description: "Calendar header scroll-fade. On the Calendar tab, the month/day header plus its trailing Divider currently sit pinned above the timeline ScrollView, so the day-grouped timeline scrolls *behind/under* them — visually wrong. Desired: the header block becomes part of the scroll content and, as the user scrolls the timeline up, the whole header block fades out together and is gone — nothing replaces it. The day row stays tappable until fully faded. While scrolled with the header faded away, the only way to bring it back is a scroll-to-top gesture. The pinned medication bar is independent and must NOT be affected."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Timeline reads cleanly while scrolling (Priority: P1)

A person reviewing their mood/medication history opens the Calendar tab and scrolls the day-grouped timeline upward to read older days. As they scroll, the month/day header drifts up with the content and fades away as one piece, leaving the timeline alone on screen — no content ever slides underneath a floating header, and no leftover header chrome clutters the view.

**Why this priority**: This is the entire reason for the feature. The current pinned header causes timeline content to visibly pass behind it, which reads as a layering bug. Fixing the scroll/fade interaction delivers the core value on its own and is independently shippable.

**Independent Test**: Open the Calendar tab with several days of entries, scroll the timeline up past the header's height, and confirm the header fades out in step with the scroll, no timeline content is ever occluded by the header, and nothing replaces the header once it is gone.

**Acceptance Scenarios**:

1. **Given** the Calendar tab is open and scrolled to the top, **When** the user scrolls the timeline upward, **Then** the header block (month label, chevron, "Today" pill, weekday caps, day row) and its divider move with the content and progressively fade toward fully transparent as one unit.
2. **Given** the user has scrolled far enough that the header is fully faded, **When** they look at the screen, **Then** no compact header, small title, or other replacement chrome is shown in the freed space — only the timeline (and the medication bar if present).
3. **Given** the timeline is scrolling, **When** any timeline content passes the vertical region the header occupied, **Then** that content is never visually occluded by an opaque pinned header.

---

### User Story 2 - Recover the header and change days after scrolling (Priority: P2)

After scrolling down into older entries, the person wants to jump to a different day or return to today. They use a scroll-to-top gesture (tapping the status bar, or scrolling back up) and the header smoothly returns to full visibility, restoring the day row, month label, and "Today" pill so they can navigate.

**Why this priority**: Without a recovery path, fading the header to nothing would strand the user with no day-selection controls. This makes the P1 fade safe to ship for real use, but the P1 visual fix can be demonstrated independently of it.

**Independent Test**: From a scrolled state with the header faded, perform the scroll-to-top gesture and confirm the header animates back to full opacity and is interactive again.

**Acceptance Scenarios**:

1. **Given** the header is faded out from scrolling, **When** the user taps the status bar, **Then** the timeline scrolls to the top and the header returns to full opacity and full interactivity.
2. **Given** the header is faded out from scrolling, **When** the user scrolls the content back up to the top, **Then** the header re-appears at full opacity as the top is reached.
3. **Given** the header is partially faded (mid-scroll), **When** the day row is still at least partially visible, **Then** tapping a day still selects that day.

---

### User Story 3 - Day selection stays in sync while scrolling (Priority: P2)

As the person scrolls through the timeline, the calendar's notion of "selected day" continues to follow the topmost visible day, exactly as it does today. Selecting a day from the (visible) header still scrolls the timeline to that day. None of the existing two-way sync behavior regresses.

**Why this priority**: The feature changes *where* the header lives and *how* it fades, but must not break the established scroll↔selection contract. Preserving it is essential for correctness, but it is verified as continuity rather than new value.

**Independent Test**: Scroll the timeline and confirm the selected day tracks the topmost visible day; tap a day in the header and confirm the timeline scrolls to it — both matching pre-feature behavior.

**Acceptance Scenarios**:

1. **Given** the timeline is being scrolled, **When** a new day becomes the topmost visible day, **Then** the selected day updates to that day (unchanged from current behavior).
2. **Given** the header is visible, **When** the user taps a day in the day row, **Then** the timeline scrolls to that day and that day becomes selected.
3. **Given** the user taps the "Today" pill, **When** the action completes, **Then** the timeline scrolls to today, the calendar collapses to week view, and the header is visible.

---

### Edge Cases

- **No entries**: When the Calendar has no entries (empty state), there is no scrollable timeline; the header MUST remain fully visible and not fade (nothing to scroll against).
- **Few entries (short timeline)**: When the timeline is shorter than the viewport (not enough content to scroll the header fully off), the header MUST NOT get stuck in a partially-faded state; at rest it MUST settle to fully visible.
- **Month expanded to full grid**: When the calendar is expanded to the full-month grid and the user scrolls, the entire expanded header block fades as one unit (consistent with the collapsed week case).
- **Accessibility large text (force-week)**: At accessibility text sizes the header is force-collapsed to a single week; the fade behavior MUST still apply to that taller-text single-week header.
- **Reduce Motion enabled**: With Reduce Motion on, the header opacity change MUST still occur (so content is not occluded) but without gratuitous animation flourish, consistent with the app's existing motion handling.
- **Medication bar present vs absent**: The fade behavior MUST be identical whether or not the medication bar is shown; the medication bar's presence MUST NOT shift, delay, or alter the header fade.
- **Programmatic scroll (day tap / Today)**: When a day tap or "Today" triggers a programmatic scroll, the header opacity MUST end in a state consistent with the resulting scroll position (e.g., visible at top) and MUST NOT flicker or desync from the selection.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The calendar header block (month label, expand chevron, "Today" jump pill, weekday caps, and day row) together with its trailing divider MUST scroll together with the timeline content rather than remaining pinned above it.
- **FR-002**: Timeline content MUST NOT be visually occluded by the header at any scroll position; no timeline row may pass behind an opaque pinned header.
- **FR-003**: As the timeline scrolls upward, the entire header block MUST fade out as a single unit (uniform opacity across all its elements, not staggered).
- **FR-004**: Once the header has fully faded, no replacement header, compact title, or sticky chrome MUST appear in its place.
- **FR-005**: The day row MUST remain tappable for day selection while it is at least partially visible, up until it is fully faded.
- **FR-006**: A scroll-to-top gesture (status-bar tap and/or scrolling the content back to the top) MUST return the header to full visibility and full interactivity.
- **FR-007**: The existing two-way sync MUST be preserved: scrolling updates the selected day to the topmost visible day, and selecting a day scrolls the timeline to that day.
- **FR-008**: The pinned medication bar MUST be unaffected — it MUST stay pinned and visually unchanged before, during, and after the header fade, regardless of scroll position.
- **FR-009**: All existing calendar header behaviors MUST be preserved: collapsible week↔month grid, month-paging swipe, mood-colour day marker dots, neutral selection circle, the list's existing edge-fade masking, accessibility force-week at large text sizes, and the "Today" jump pill.
- **FR-010**: When there is no scrollable content (empty state or a timeline shorter than the viewport), the header MUST rest at full visibility and MUST NOT become stuck partially faded.
- **FR-011**: The header opacity MUST track scroll position continuously (fade in as the top is approached, fade out as the user scrolls away), so the visible/hidden state is always consistent with the current scroll offset.
- **FR-012**: The fade and recovery behavior MUST honor the Reduce Motion accessibility setting consistent with the rest of the app.

### Key Entities

Not applicable — this feature changes presentation/interaction of existing calendar data; it introduces no new data entities.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: At every scroll position on the Calendar tab, 0 timeline rows are rendered behind/under the header (no occlusion), verified across collapsed-week, expanded-month, and accessibility-large-text states.
- **SC-002**: After scrolling the timeline up past the header's height, the header reaches fully transparent and no replacement header element is visible (header pixels contribute nothing to the top region).
- **SC-003**: From a fully-faded state, a single scroll-to-top gesture restores the header to full visibility and interactivity in 100% of attempts.
- **SC-004**: Day-selection parity holds: scrolling-to-select-topmost-day and tap-day-to-scroll behave identically to the pre-feature build in 100% of tested cases (no regression).
- **SC-005**: The medication bar's position and appearance are pixel-identical before vs. after the header fades, in both the bar-present and bar-absent configurations.
- **SC-006**: With a timeline shorter than the viewport, the header rests at full opacity (never stuck partially faded) in 100% of cases.

## Assumptions

- The feature targets the Calendar tab's library screen and its calendar header component; no other tab is affected.
- "Nothing replaces the header" is a deliberate product decision (confirmed with the requester); day navigation while scrolled relies on the scroll-to-top recovery plus the existing scroll→selection sync.
- The scroll-to-top gesture leverages the platform-standard status-bar-tap-to-top behavior plus normal upward scrolling; no custom floating "back to top" button is in scope.
- The medication bar continues to be provided by the existing screen container as a pinned element outside the scroll content; this feature does not modify the medication bar.
- The reference HTML mockup (`docs/superpowers/plans/2026-06-15-calendar-scroll-fade-header.html`) illustrates the four target states (header present/faded × medication bar present/absent) and is design-exploration input, not a binding implementation detail.
- Existing automated tests for calendar day-selection and scroll-sync remain the regression baseline and must continue to pass.
