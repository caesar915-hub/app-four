# Feature Specification: Medication Bar Consistency

**Feature Branch**: `feat/feedback-specs` (Spec Kit feature `002-medication-bar-consistency`)

**Created**: 2026-06-15

**Status**: Draft

**Input**: Screen-recording feedback (`docs/superpowers/2026-06-15-screen-recording-feedback-plan.md`), items §1.5, §2.1, §4.3, §4.4 and the "Cross-cutting themes" / "Decisions — resolved 2026-06-15" sections. Consolidated per the plan's recommendation that the bar be "a single, fixed, always-tappable element … never overlaps, never moves, never half-responds." **The fade-under-the-bar item (§1.3) is intentionally out of scope here** — it is covered by the separate calendar header scroll-fade work (`fix/calendar-header-scroll-fade`).

## User Scenarios & Testing *(mandatory)*

The medication bar is the spine of the product's main surfaces: a small floating element pinned at the top of every primary screen, showing each active dose and how much of its effect window has elapsed. Today it behaves inconsistently — it only responds to taps at its edges, the gap below it differs per screen, and it shifts position when the user opens a recording. This feature makes the bar a single, fixed, fully-interactive anchor with identical placement and behaviour on every screen that shows it.

### User Story 1 - Tapping anywhere on a dose opens its menu (Priority: P1)

A person looks at the medication bar, sees a dose row, and taps it — anywhere along the row, including the empty space in the middle — to open the menu that lets them log a new dose or remove this one.

**Why this priority**: This is the most direct, highest-frequency interaction with the bar and the most jarring defect — the owner demonstrated tapping the middle of the bar and "nothing happens." A control that visibly looks tappable but only responds at its ends breaks the user's basic trust in the surface. It is also independently shippable and delivers value on its own. (§2.1)

**Independent Test**: With at least one active dose shown, tap at the horizontal centre of a dose row (the region between the two text labels, beyond the progress fill) and confirm the dose menu appears. Repeat at the far left, far right, and over the progress fill — all must open the same menu.

**Acceptance Scenarios**:

1. **Given** the medication bar shows a single active dose, **When** the user taps the empty middle of that row, **Then** the dose's menu (log new dose / delete this dose / cancel) appears.
2. **Given** the medication bar shows a single active dose, **When** the user taps anywhere else along that same row (left label, right label, progress fill, or trailing empty space), **Then** the same menu appears.
3. **Given** the medication bar shows multiple stacked dose rows, **When** the user taps the middle of a specific row, **Then** the menu opens for that row's dose and no other.
4. **Given** the medication bar shows a dose, **When** the user taps it, **Then** the visible bounds that respond to the tap match the full visible bounds of the row (no dead zones).

---

### User Story 2 - The bar holds one fixed position across every screen (Priority: P2)

As the user moves between the main screens — the calendar timeline, the insights screen, and opening a recording's detail — the medication bar stays in exactly the same place and never jumps, shifts, or reflows. Opening a recording does not push the bar down or surface a competing back control over it.

**Why this priority**: The owner's strongest stated requirement: "The medication bar must be consistent across all screens; we can't have it moving when this screen appears" and "you can't interfere with it." Inconsistent placement undermines the bar's role as a stable anchor. It is the prerequisite for the detail screen feeling correct, and resolving the recording-detail navigation (no competing back control) is part of the same requirement. (§4.3, §4.4)

**Independent Test**: Note the bar's on-screen position on the calendar screen. Navigate to insights, then open a recording from the timeline, then dismiss it. At every step the bar's top edge and horizontal position are unchanged, and no navigation chevron or other control overlaps it.

**Acceptance Scenarios**:

1. **Given** the bar is visible on the calendar screen, **When** the user switches to the insights screen, **Then** the bar appears at an identical position with no movement or reflow.
2. **Given** the user is on the calendar screen, **When** they open a recording's detail, **Then** the bar remains fixed at the same position and no back chevron or navigation control is rendered over or above it.
3. **Given** the recording detail is open, **When** the user dismisses it with a swipe-down gesture, **Then** the detail closes and the bar is unchanged throughout.
4. **Given** any screen that shows the bar, **When** that screen appears, **Then** the top chrome above the bar is consistent across all such screens (no screen introduces extra chrome that displaces the bar).

---

### User Story 3 - Consistent spacing below the bar (Priority: P3)

As the user moves between screens, the gap between the medication bar and the first content card below it is the same everywhere — the bar sits a consistent distance above the content on every screen that shows it.

**Why this priority**: A polish/consistency ask the owner called out ("always align — something like this space — between the daily card and the medication bar"). It is visually important but the bar is fully usable without it, so it ranks below interaction and positional consistency. (§1.5)

**Independent Test**: Measure the gap between the bar and the first content card on the calendar screen and on the insights screen and confirm they are equal.

**Acceptance Scenarios**:

1. **Given** the bar is visible on a screen, **When** the first content card is laid out below it, **Then** the gap between the bar and that first card equals the gap used on every other screen that shows the bar.
2. **Given** the user has increased the system text size, **When** the bar grows taller to fit, **Then** the spacing below the bar is preserved so the first card keeps a consistent gap.

---

### Edge Cases

- **No active doses**: when there are no active doses, the bar is not shown; the spacing rule applies only when the bar is present, and content occupies the space the bar would have used.
- **Bar hidden by preference**: the user can hide the bar in settings; when hidden, no space is reserved, and the tap-target, positional, and spacing rules are moot.
- **Multiple stacked rows**: with several active doses the bar is taller; tap targeting must resolve to the correct row, and the below-bar spacing must track the taller bar height.
- **Largest Dynamic Type**: at the largest accessibility text sizes the bar is at its tallest; the below-bar spacing must remain correct so the first card keeps a consistent gap.
- **Opening a recording while content is mid-scroll**: dismissing the recording must return to the prior screen with the bar unchanged and the prior scroll position intact.
- **Rapid screen switching**: quickly moving between calendar, insights, and a recording must not cause the bar to flicker, reflow, or momentarily reposition.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The entire visible area of each medication-bar dose row MUST be tappable; a tap anywhere within a row's bounds MUST open that row's dose menu. (§2.1)
- **FR-002**: The dose menu opened by tapping a row MUST offer the same actions as today (log a new dose, delete this dose, cancel) and MUST act on the tapped row's dose. (§2.1)
- **FR-003**: With multiple stacked dose rows, a tap MUST resolve to exactly the row under the user's finger and open only that dose's menu. (§2.1)
- **FR-004**: The medication bar MUST occupy an identical on-screen position across every screen that shows it (calendar timeline, insights, recording detail). (§4.4)
- **FR-005**: Navigating into or out of any screen MUST NOT move, reflow, resize, or momentarily reposition the bar. (§4.4)
- **FR-006**: Opening a recording's detail MUST NOT render any navigation control (e.g. a back chevron) over or above the bar; the recording detail MUST be dismissable with a swipe-down gesture and MUST keep the bar fixed throughout. (§4.3)
- **FR-007**: Every screen that shows the bar MUST present consistent top chrome above the bar, such that no screen introduces extra chrome that displaces the bar relative to the others. (§4.4)
- **FR-008**: The vertical gap between the bar and the first content item below it MUST be a single consistent value applied on every screen that shows the bar, and MUST be preserved as the bar grows taller (more rows, larger text size). (§1.5)

### Key Entities *(include if feature involves data)*

Not applicable. This feature changes only presentation and interaction behaviour; it introduces, removes, and alters no persisted data. The bar's content is derived from existing active-dose records that are unchanged by this work.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of the visible area of each dose row opens that dose's menu when tapped; there are zero unresponsive regions within a row's bounds.
- **SC-002**: The bar's measured top-edge position and horizontal placement are identical (within rendering tolerance) on the calendar screen, the insights screen, and the recording detail.
- **SC-003**: Opening and dismissing a recording produces zero observable change in the bar's position at any point during the transition.
- **SC-004**: No navigation chevron or back control is visible over or above the bar on the recording detail; the detail is fully dismissable by swipe-down.
- **SC-005**: The measured gap between the bar and the first content card is equal on every screen that shows the bar, including at the largest Dynamic Type size.
- **SC-006**: A first-time user can open the dose menu on their first attempt by tapping the bar without needing to find a specific spot.

## Assumptions

- The owner's resolved decisions (2026-06-15) are binding: recording detail presented so it dismisses by swipe-down with no back chevron (§4.3), the bar kept fixed and consistent everywhere (§4.4). These are treated as settled, not open questions.
- **The fade-under-the-bar treatment (§1.3) is out of scope for this feature** — it is handled by the separate calendar header scroll-fade work (`fix/calendar-header-scroll-fade`), which reworks how content meets the top of the screen.
- The set of screens that show the bar is the current set: the calendar timeline, the insights screen, and the recording detail. No new screens are added by this feature.
- The dose menu's existing actions (log / delete / cancel) are correct and unchanged; only the area that triggers it changes.
- The "interval" data and any medication-picker changes are out of scope here — they belong to the separate medication-picker feature (§3.1) and are not part of this spec.
- The mock-data crash (§1.1) and the bar-missing-in-mock-mode behaviour (§1.2) are separate bug investigations, not part of this feature.
- Hiding the bar via the existing settings preference continues to reserve no space and is unaffected by these changes.
- The behavioural contract for this feature is the set of acceptance scenarios above; there is no external API or network contract (on-device UI only).
