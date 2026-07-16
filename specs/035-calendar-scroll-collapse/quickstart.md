<!-- Created: 2026-07-16 14:05 (WEST) · Updated: 2026-07-16 14:05 (WEST) -->
# Quickstart / Device-QA — Calendar Strip Scroll-Collapse (spec-035)

Owner builds + QAs on a physical device (no simulator). Behavioral reference: the owner's Tiimo
frame-by-frame analysis (2026-07-15). Contract table: [contracts/strip-fade-behavior.md](contracts/strip-fade-behavior.md).

## Prerequisites

1. **PRs #28 (spec-033) and #31 (spec-034) merged to `main`**; `feat/035-calendar-scroll-collapse`
   rebased onto the result (expect a trivial CLAUDE.md pointer conflict — take this branch's side).
2. Build `app-four` on device (iOS 26 target).

## Unit gate (before any device time)

- Run the test suite; `CalendarStripFadeTests` must be green **and** must demonstrably have been RED
  before `CalendarStripFade.swift` existed (RED→GREEN per Constitution X). Covers contract C1–C8.

## US1 — collapse effect (spec §US1)

- [ ] Rest parity: strip + divider + list look pixel-identical to the pre-change build; med bar identical with the bar **shown and hidden** via Settings (C10).
- [ ] Slow scroll up: zero fade for the first ~24pt (C2); then the strip moves *with* the content while fading; fully transparent as it clears the top content area (C4); no flicker at the threshold.
- [ ] Scroll back: exact reverse; opacity exactly 1 at rest, no residual dimming (C1).
- [ ] Rubber-band pull past top: never over-brightens, no flash (C2).
- [ ] The list scrolls under the nav area and frosts under the floating med bar — same look as Insights (confirms the `Group` top-edge/safe-area change).
- [ ] Date tap: list jumps to top of the filtered day and the **strip stays fully visible** (C9 — regression guard for the `topDayID` → edge-scroll swap); tapping a **partially faded** strip still selects.
- [ ] Month expand at rest: grid opens with no scroll jump; scroll while expanded: whole grid fades uniformly, band feels proportional (C8); expand **while partially scrolled**: small opacity step acceptable, no glitch/jump.
- [ ] Month swipe-paging still works; Today jump (tab re-tap) lands at rest with a fully opaque week strip.
- [ ] Short list (an old day with one card): no bounce, strip never rests part-faded (FR-013).
- [ ] Empty state: fixed opaque strip, no title (FR-012).

## US2 — compact title (spec §US2)

- [ ] Title snap-fades in only near full collapse (~80%), not gradually tracking the finger (C7).
- [ ] Correct strings: "Today, 16 Jul" / "Yesterday, …" / "Wednesday, 15 Jul" — identical wording to the day labels used elsewhere.
- [ ] Disappears the same way scrolling back; no ghost title at rest; no conflict with the empty inline `navigationTitle`.

## Cross-cutting

- [ ] 120 Hz: no hitch through the fade band on a 30+ card day; light **and** dark mode.
- [ ] Reduce Motion ON: fade still tracks the finger; title appears without animation; date-tap jump is instant with the strip visible (C12).
- [ ] AX text sizes (strip force-collapses to week): fade band still completes as the strip clears; title legible, not truncated to uselessness.
- [ ] VoiceOver: fully faded strip not focusable; title announced when shown (C11).
- [ ] Push a recording detail and pop back; switch tabs away/back: strip opacity, scroll position, and title state mutually consistent.

## Flags to eyeball (owner-approved trade-offs, confirm acceptable on device)

- **Date picker inaccessible while scrolled deep** — changing days requires scrolling back to top (Tiimo behavior, spec Assumption).
- **Expand-while-partially-scrolled opacity step** — the band re-scales mid-fade (D7); confirm it reads as benign.
- **Bounce disabled on fits-on-screen lists** (`.basedOnSize`) — confirm short days feel right without bounce.
