# Quickstart — validate the day-card mood-block redesign

How to build, test, and verify this feature end-to-end. Implementation detail lives in `tasks.md`; this is the run/validation guide.

## Prerequisites

- Xcode (iOS 26 SDK), an iPhone simulator booted.
- Tooling note (from DEVLOG 2026-06-24): XcodeBuildMCP / `ios-debugger-agent` is **not connected** in this environment, so build/test run via the **`xcodebuild` CLI + `xcrun simctl`**. The app has a DEBUG-only `-skipOnboarding` launch arg to reach the calendar headlessly.
- Mock data: the calendar is seeded with `isMockData` check-ins spanning all five moods (used for parity across moods).

## Build + unit tests (Principle II / X gate)

```sh
# Build
xcodebuild -scheme app-four -destination 'platform=iOS Simulator,name=iPhone 17' build

# Test — the new palette test + the existing 014 logic tests (run SERIAL; the project's
# convention is the serial suite is the source of truth, parallel flakes on shared state)
xcodebuild test -scheme app-four -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:app-fourTests
```

**Expected**: build succeeds; `DayCardPaletteTests` green (5 levels + nil); the existing `ExpandedDayCards` / date-filter / `DayCardSummary` tests still green (SC-007). Full serial suite **TEST SUCCEEDED, 0 failures**.

## On-simulator visual validation (views are mockup-verified, Principle I/X)

Launch with `-skipOnboarding`, open **Calendar**:

1. **Folded parity (C1–C5, SC-001/SC-002)** — every day card is one mood-tinted block with a cream-disc badge, mood word + weekday on one line, a divider, and an energy · focus · medication-name summary. Compare side-by-side to `mockups/summary/index.html` (folded). Confirm **all five moods** tint differently (seed days at low→great).
2. **Unfolded parity (C6–C11)** — tap a card: the mood strip stays as the header; rows drop onto cream; each row shows ring+glyph+%, mood word with inline time, energy/focus ramp glyphs, and a trailing details chevron. No full-width colored band remains.
3. **Dark mode (A5)** — repeat 1–2 in dark; tint, badge, word, and rows all legible.
4. **Dynamic Type (A1, SC-003)** — set the largest accessibility text size: no card text clips/ellipsises; the mood word is always fully visible; the badge doesn't crowd the wrapped title.
5. **Reduce Motion (A2, SC-004)** — On: fold/unfold is instant. Off: the reveal animates.
6. **Greyscale / colour-blind (A3, SC-005)** — enable a colour filter: each signal stays distinguishable by glyph shape; the day's mood still reads from glyph + word.
7. **Tap targets (A4)** — header and row each ≥ 44 pt; tapping a row opens its detail (unchanged).
8. **Empty/partial days (edge cases)** — a logged day with no rows, and a check-in with mood only, both render cleanly (no exposed corners, no crash).

## Token audit (T1, SC-006)

```sh
# No magic-number visual literals in the changed views (as in 007/008/014)
grep -nE '(cornerRadius|\.padding\(|frame\(width:|opacity\(0)' \
  app-four/Views/Components/{DayCard,FoldedDayCardHeader,TimelineRow,TimelineBead}.swift
```
**Expected**: only `Radius.*`, `Spacing.*`, `Metrics.*`, `Opacity.*` token references — no bare numbers (sanctioned glyph-internal constants excepted, as in prior specs).

## Done = all of: build green · serial suite green · folded+unfolded match the mockup across 5 moods in light+dark · Dynamic Type/Reduce Motion/greyscale pass · token audit clean.
