# UI Interaction Contract: Calendar Header Scroll-Fade

This is a behavioral contract for a SwiftUI screen (no network/API surface). It defines
the observable input→output relationship the implementation MUST satisfy, expressed so it
can be asserted in tests and verified on-device.

## State

| Name | Type | Meaning |
|---|---|---|
| `scrollOffset` | points (≥ 0) | Distance the timeline content has scrolled up from the top, relative to content insets. |
| `headerHeight` | points (> 0) | Measured natural height of the header block (varies: week / expanded month / AX text). |
| `headerOpacity` | 0.0…1.0 | Applied opacity of the header block (month label, chevron, "Today" pill, weekday caps, day row, divider). |
| `headerInteractive` | Bool | Whether the header accepts taps. |
| `selectedDay` | Date | The calendar's selected day (existing). |
| `topDayID` | Date? | The topmost visible timeline day (existing `scrollPosition(id:)`). |

## Contract: opacity is a pure function of offset

```
headerOpacity == clamp(1 - (scrollOffset / headerHeight), 0, 1)
```

- **C1** `scrollOffset == 0` ⇒ `headerOpacity == 1.0` (top of list, header fully visible).
- **C2** `scrollOffset >= headerHeight` ⇒ `headerOpacity == 0.0` (header fully faded).
- **C3** `0 < scrollOffset < headerHeight` ⇒ `0 < headerOpacity < 1` and `headerOpacity` is **monotonically non-increasing** as `scrollOffset` increases.
- **C4** The mapping is **uniform across the whole block** — every header element shares the same `headerOpacity` (no staggered fade). *(FR-003)*
- **C5** `headerOpacity` is identical for any given `scrollOffset` whether or not the medication bar is shown. *(FR-008, SC-005)*

## Contract: interactivity

- **C6** `headerInteractive == (headerOpacity > 0.05)`. Day taps register while the header is at least faintly visible and are ignored once effectively invisible. *(FR-005)*

## Contract: no replacement chrome

- **C7** At `headerOpacity == 0` the top region contains no header-derived pixels and no compact/sticky title is introduced. The only persistently pinned element that may occupy the top is the medication bar overlay. *(FR-004)*

## Contract: occlusion-free

- **C8** For all `scrollOffset`, no timeline row is drawn behind an opaque header region; the header shares the scroll plane with the content (it translates with the content rather than floating over it). *(FR-002, SC-001)*

## Contract: recovery

- **C9** Reducing `scrollOffset` back toward 0 (scrolling up) raises `headerOpacity` back toward 1 by the same C1–C3 mapping. *(FR-006, FR-011)*
- **C10** A status-bar tap (or programmatic scroll-to-top) sets `scrollOffset → 0`, hence `headerOpacity → 1` and `headerInteractive → true`, animated unless Reduce Motion is on. *(FR-006, FR-012)*

## Contract: selection sync unchanged

- **C11** Scrolling such that a new day becomes `topDayID` updates `selectedDay := topDayID` (existing behavior, must not regress). *(FR-007)*
- **C12** Tapping a visible day sets `selectedDay` and scrolls the timeline to that day. *(FR-007)*
- **C13** Tapping "Today" scrolls to today, collapses the grid to week, and (because it scrolls to top) results in `headerOpacity == 1`. *(FR-007, edge case)*

## Contract: degenerate content

- **C14** When the timeline is empty (empty state) the header is rendered at `headerOpacity == 1` and never fades. *(FR-010)*
- **C15** When the timeline is shorter than the viewport, the resting `scrollOffset` is 0, so `headerOpacity` rests at 1 and is never stuck in `(0,1)`. *(FR-010, SC-006)*

## Contract: medication bar independence

- **C16** The medication bar overlay's frame and appearance are invariant under all values of `scrollOffset`/`headerOpacity`, in both bar-present and bar-absent configurations. *(FR-008, SC-005)*
