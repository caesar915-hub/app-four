# Quickstart & Validation: Calendar Header Scroll-Fade

How to build, run, and prove the feature works end-to-end. Implementation details live in
`tasks.md`; behavioral assertions live in `contracts/scroll-fade-interaction.md`.

## Prerequisites

- Branch `fix/calendar-header-scroll-fade` checked out.
- Builds on the iPhone 17 simulator (current green baseline).
- Mock data seeded (Debug → Mock Mode → Seed) so the timeline has several days of entries across more than one viewport height.

## Build & test

Use `ios-debugger-agent` (XcodeBuildMCP):

1. Build the `app-four` scheme for an iPhone simulator.
2. Run the full test suite **serially** (`-parallel-testing-enabled NO`) — the suite is only reliably green serially (known tech-debt item). Expect the existing calendar tests plus the new `CalendarHeaderScrollFadeTests` to pass.

## Manual validation (on simulator)

Map each step to the contract clauses it proves.

| # | Action | Expected | Proves |
|---|---|---|---|
| 1 | Open Calendar tab, do not scroll | Header fully visible; first timeline day selected | C1, C11 |
| 2 | Slowly scroll the timeline up | Header drifts up with content and fades smoothly; no row ever passes behind it | C3, C4, C8 |
| 3 | Scroll up past the header height | Header fully gone; nothing replaces it at the top | C2, C7 |
| 4 | While header ~50% faded, tap a visible day | That day selects + timeline scrolls to it | C6, C12 |
| 5 | While header fully faded, tap the status bar | Timeline scrolls to top; header animates back to full opacity & is tappable | C9, C10 |
| 6 | Scroll back up manually instead of tapping status bar | Header re-appears at the top by the same fade mapping | C9 |
| 7 | Expand to month grid, then scroll | Entire expanded header fades as one unit; fade completes as it clears | C3, C4 (with larger `headerHeight`) |
| 8 | Repeat steps 1–3 with the medication bar visible, then with it hidden | Header fade is identical both ways; med bar frame/appearance unchanged before vs after | C5, C16 |
| 9 | Open a day with a short timeline (less than one screen) | Header rests fully visible, never stuck mid-fade | C15 |
| 10 | Open an empty calendar (wipe data) | Header fully visible and non-fading; empty state shown | C14 |
| 11 | Enable Settings → Accessibility → Reduce Motion, repeat steps 2 & 5 | Fade still tracks the gesture; programmatic restore is non-animated | FR-012 |
| 12 | Set an accessibility (AX) text size, repeat steps 1–3 | Force-week header still fades correctly with its taller height | edge case |

## Automated validation

`CalendarHeaderScrollFadeTests` asserts the pure opacity mapping and the sync guards:

- Opacity mapping: offset 0 → 1.0; offset == height → 0.0; offset == height/2 → ~0.5; monotonic non-increasing across a sweep (C1–C3).
- Clamp: negative/rubber-band offset → 1.0; offset > height → 0.0 (C15).
- Interactivity threshold: `headerInteractive` flips at opacity 0.05 (C6).
- Sync regression: scrolling to a new top day updates `selectedDay`; tapping a day scrolls to it (C11–C12) — reuse/extend existing calendar day-selection tests.

> The opacity computation MUST be a testable pure function (free function or static) so these
> assertions don't require driving a live `ScrollView`. The view applies it; the test checks it.

## Done when

- All 12 manual steps pass on-device.
- Full suite green serially, including the new tests.
- `/code-review` run on the diff with findings addressed.
- DEVLOG entry added; BACKLOG row moved to 🔨 In code with branch/PR.
