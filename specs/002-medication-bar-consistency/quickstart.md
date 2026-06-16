# Quickstart & Validation: Medication Bar Consistency

**Feature**: `002-medication-bar-consistency` | **Branch**: `feat/feedback-specs` | **Date**: 2026-06-15
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)

This validates the feature against its acceptance scenarios and success criteria. Run the manual steps on a booted simulator/device with at least one active medication dose so the bar is visible. Then run the automated tests. The build gate (Principle II) closes the loop.

> **Scope note**: the fade-under-the-bar item (§1.3) is **out of scope** here — validated separately by `fix/calendar-header-scroll-fade`. This feature covers the tap target, fixed position, recording-detail-as-sheet, and below-bar spacing.

---

## Preconditions

- At least one **active** dose exists so the bar renders (the bar is hidden with zero active doses). For multi-row checks, have ≥2 active doses.
- The medication-bar visibility preference is ON.
- Have at least one recording in the timeline to open the detail.

---

## Manual validation — mapped to acceptance scenarios

### P1 · Tap target (US1 / FR-001–FR-003 / SC-001, SC-006)

1. With a single active dose shown, tap the **empty middle** of the row → the dose menu (log new dose / delete this dose / cancel) appears. *(US1 #1, SC-001)*
2. Tap the **far left**, **far right**, **over the progress fill**, and **trailing empty space** of the same row → the same menu appears each time, no dead zones. *(US1 #2, SC-001)*
3. With ≥2 active doses, tap the **middle of one specific row** → only that row's dose menu opens. *(US1 #3)*
4. As a first-time check, tap the bar without aiming for a specific spot → the menu opens on the first try. *(SC-006)*

### P2 · Fixed position across screens (US2 / FR-004–FR-007 / SC-002–SC-004)

5. On the **calendar** screen, note the bar's top-edge and horizontal position. Switch to **insights** → bar is in an identical position, no movement/reflow. *(US2 #1, SC-002)*
6. From the calendar, **open a recording** → the bar stays fixed at the same position; **no back chevron or navigation control** is rendered over or above it. *(US2 #2, FR-006, SC-004)*
7. **Swipe down** to dismiss the recording detail → it closes; the bar was unchanged throughout the open and the dismiss. *(US2 #3, SC-003)*
8. Rapidly switch calendar ↔ insights ↔ a recording several times → no flicker, reflow, or momentary reposition of the bar. *(Edge case: rapid switching, SC-002/SC-003)*

### P3 · Consistent spacing below the bar (US3 / FR-008 / SC-005)

9. Compare the **gap between the bar and the first content card** on calendar vs insights → equal. *(US3 #1, FR-008, SC-005)*
10. Increase system text size to the **largest Dynamic Type**; with 1 then ≥2 doses, re-check the gap → the below-bar spacing is preserved and the first card keeps a consistent gap as the bar grows taller. *(US3 #2, FR-008, SC-005)*

### Edge cases

11. Remove all active doses → the bar disappears and content occupies the reclaimed space. *(Edge: no active doses)*
12. Hide the bar via settings → no space reserved, positional/tap/spacing rules moot. *(Edge: bar hidden)*
13. Open a recording while mid-scroll, then dismiss → return to the prior screen with bar unchanged and prior scroll position intact. *(Edge: open while mid-scroll)*

---

## Automated tests to add

Place under `app-fourTests/` (unit/layout) and `app-fourUITests/` (flow). Names are indicative; finalize in `/speckit-tasks`.

| Test | Type | Asserts | Covers |
|---|---|---|---|
| Bar row hit-testing | Unit / interaction | A tap at the row's horizontal centre (and at left/right/fill) triggers the dose-selection action; the hittable region equals the full row frame, not just the sub-views | FR-001–FR-003, SC-001, SC-006 |
| Multi-row tap resolution | Unit / interaction | With ≥2 rows, a tap resolves to the correct row's dose only | FR-003 |
| Below-bar spacing token | Unit / layout | The gap below the bar resolves to the single shared token and is equal across the calendar and insights roots, including at the largest Dynamic Type size | FR-008, SC-005 |
| Cross-screen bar position | UI (XCUITest) | The bar's frame is identical (within tolerance) on calendar, insights, and the opened recording detail; no movement on navigation | FR-004, FR-005, FR-007, SC-002 |
| Recording detail as sheet | UI (XCUITest) | Opening a recording presents a sheet with **no** back chevron over the bar; swipe-down dismisses it; the bar is unchanged before/during/after | FR-006, SC-003, SC-004 |
| Selection path resolves | UI (XCUITest) | The recording selected from the timeline (by id) is the one shown in the sheet (deep-link/selection path intact after push→sheet swap) | §4.3 regression guard |

---

## Build gate (Principle II — non-negotiable)

Before this feature is reported done, run via the `ios-debugger-agent` skill (XcodeBuildMCP):

1. **Build** the `app-four` target clean → succeeds with no warnings introduced by this change.
2. **Run the full test suite** (unit + UI), including the new tests above → all green.
3. Manually verify steps 1–13 on a booted simulator with the preconditions met.

A PR is not ready until build + full test suite are green on `feat/feedback-specs` and `/code-review` has been run on the diff. `main` stays releasable (Principle V).
