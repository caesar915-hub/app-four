<!-- Created: 2026-07-16 14:05 (WEST) · Updated: 2026-07-16 14:41 (WEST) -->
# Data Model — Calendar Strip Scroll-Collapse & Fade (spec-035)

No persisted entities, no SwiftData schema surface, no view-model changes. All state is ephemeral,
view-local, and derived from scroll geometry.

## Ephemeral view state (`CalendarLibraryView`)

| Name | Type | Source of truth | Notes |
|---|---|---|---|
| `collapseProgress` | `CGFloat` (0…1, quantized 1/100) | `onScrollGeometryChange` transform | Sole driver of strip opacity + title visibility. 0 at rest and throughout the dead zone; 1 at/after full collapse. Never persisted; re-derives on every appearance. |
| `stripHeight` | `CGFloat` | `onGeometryChange` on `headerBlock` | Current rendered strip height (week ≈130pt · expanded month ≈250–300pt · AX force-week). Changes only on expand toggle / Dynamic Type / rotation. `0` before first measurement — guarded by `minFadeDistance`. |
| `listPosition` | `ScrollPosition(edge: .top)` | programmatic scrolls only | Replaces `topDayID: Date?` (deleted). Used exclusively by `scrollList(to:)` / `jumpToToday()`. |

## Derived values (pure, `CalendarStripFade`)

| Function | Signature | Range / contract |
|---|---|---|
| `progress` | `(offset: CGFloat, stripHeight: CGFloat) → CGFloat` | 0 ∀ offset ≤ deadZone (incl. negative rubber-band); 1 at offset ≥ deadZone + band; linear between; **floor**-quantized to 1/100 (Equatable dedupe, never completes early — C4/C6) |
| `stripOpacity` | `(progress: CGFloat) → CGFloat` | `1 − progress` |
| `showsTitle` | `(progress: CGFloat) → Bool` | `progress ≥ titleReveal (0.8)` |

Constants: `deadZone = 24`, `minFadeDistance = 44`, `titleReveal = 0.8` (documented statics; owner-tunable).

## State transitions

```
rest (progress 0, strip opaque, no title)
  │ scroll up past deadZone
  ▼
fading (0 < progress < 1, strip opacity 1−p, no title while p < 0.8)
  │ p crosses 0.8 ────────────► title snap-fades IN (Motion.snappy, RM-gated)
  │ scroll up past band end
  ▼
collapsed (progress 1, strip invisible + non-focusable, title shown)
  ▲ all transitions reverse symmetrically on scroll down
  │ date tap / Today jump → listPosition.scrollTo(edge: .top) → rest
```

Invariants:
- The medication bar and `ScreenContainer` chrome are **not** part of this state machine (structurally decoupled via `safeAreaInset`).
- The empty-state branch never enters the machine (fixed strip, progress conceptually pinned at 0).
- `selectedDay`, `isCalendarExpanded`, `expandedCards` are untouched by the collapse machinery; only `topDayID` is removed.
