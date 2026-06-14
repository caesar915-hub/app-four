# Insights View — Snap Scroll Spec

**Date:** 2026-06-12
**Status:** Spec only — no implementation plan, no code yet.
**Reference:** Daylio "Monthly / Analyze" stats view (`ScreenRecording_06-12-2026 13-31-34_1.MP4`).

## Goal

Apply Daylio's **snap-to-section scroll** mechanic to the existing Meadow insights
sections. Reuse the *behavior and affordance*, not Daylio's content (emotion
calendar, weekday charts, etc.).

## What the pattern is called

**Snap scrolling** / **scroll snapping** — specifically **view-aligned,
snap-to-section**. The scroll never rests where the finger lifts; it settles so a
section's heading lands at a fixed top anchor. In Apple terms this is a *scroll
target behavior* (view-aligned snapping to each child, not full-container paging).

## Decisions (locked)

1. **Granularity — snap per section, variable height.** Each insights section is
   its own snap target. Not fixed full-page paging.
2. **Tall sections allowed.** A section may exceed one screen. Inside a tall
   section the scroll moves freely; it snaps only at the section's top/bottom
   boundary. Result is a **hybrid**: crisp one-flick = one-snap for ~screen-height
   sections; snap-in → free-scroll → snap-out for tall ones.
3. **Affordances — peek yes, page dots no.**
   - Keep the **dimmed next-title peek**: at a rest position the next section's
     title is visible at the bottom edge, dimmed (~40–50% opacity); the active
     section's title is full emphasis.
   - **Skip the right-edge page dots.** They assume one dot ≈ one equal-height
     screen; tall free-scrolling sections break that (dot sits frozen while you
     scroll a long section → reads as stuck). Reconsider only if all sections end
     up ~one screen.
4. **Content = existing Meadow insights sections.** This spec governs the scroll
   shell + affordances; section content is unchanged.

## Accepted tradeoff

"Match the video" now means *match the snap mechanic + peek affordance*. It is
**not** a 1:1 visual match, because decision #2 (tall sections) opts out of the
video's "every section is one screen" constraint that produces its uniformly
paged feel. Tall sections will scroll normally before snapping.

## Behavior spec

- **Vertical scroll that snaps.** Rest position = a section's leading edge / title
  pinned to a fixed top anchor (identical Y for every section).
- **Snap targets = sections.** Each section container is a snap target.
- **Momentum:** a flick advances by section then snaps; no resting at arbitrary
  offsets. Tall sections: free internal scroll, snap at their boundaries.
- **Consistent anchor:** every section title lands at the same screen row,
  directly below the pinned top chrome.

## Layout / chrome

- **Top chrome pinned, outside the scroll view:** view title + any selector strip
  (the video's `Monthly ▾` + month tab strip equivalent). Does not move on snap.
- **Bottom chrome pinned:** the Liquid Glass floating tab bar; content scrolls
  behind it.
- Only the middle content layer scrolls/snaps.

## Affordance spec (peek)

- At each rest position, render the **next** section's title at the bottom edge,
  dimmed (~40–50% opacity).
- Active section title at full emphasis (full-white).
- As you scroll toward the next section, its title rises from dim → full as it
  snaps to the active anchor.
- For tall sections the peek only appears once scrolled to the section's bottom —
  acceptable.
- First section: no peek above. Last section: no peek below.

## Edge cases

- **Section taller than screen:** free-scroll inside, snap at top/bottom (decision
  #2).
- **First / last section:** clamp; no peek beyond ends.
- **Short section (< screen):** snaps title to anchor; empty space below until the
  next title peek — keep sections close to ~screen height where possible to
  minimize this.

## Out of scope

- Daylio's specific content (emotion calendar grid, weekday stacked bars, etc.).
- Right-edge page-dot indicator (explicitly dropped).
- Any Swift/SwiftUI implementation — to be planned separately.
