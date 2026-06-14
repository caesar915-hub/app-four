# DesignSystem Completion + UI Cleanup — Design

**Date:** 2026-06-10
**Status:** Approved (design), pending spec review → implementation plan
**Branch context:** `main` (UI rewrite already merged: DesignSystem token layer, split libraries, native components)

## Goal

The UI rewrite is already substantially on `main`: a `DesignSystem/` token layer exists,
the duplicate library screens are reconciled, glass orphans are deleted, Settings uses a
native `List`, and empty states use `ContentUnavailableView`. This phase **finishes** that
work along two tracks:

- **Track A — Cleanup:** delete remaining dead code and replace every leftover hardcoded
  font size, color, and spacing value in `Views/` with the existing tokens, so the
  DesignSystem is genuinely the single source of visual truth.
- **Track B — Completion:** add the missing token layers so the DesignSystem is *complete*
  — tag/status colors, icons, motion, elevation, button styles, haptics, layout constants.

This directly fixes the original complaint ("the same component in different shapes and
sizes") at the root: visual decisions live in one place and are reused everywhere.

## Non-Goals (explicitly deferred)

- **Native component sweep** (e.g. converting the calendar day-list to `List` with swipe
  actions, adding `.searchable`, `ShareLink`). Deferred to a later phase.
- **Notes-list library decision.** The flat notes-list tab was removed (4 tabs now). Whether
  to bring it back as a 5th tab or a toggle inside Calendar is a separate decision, not this phase.
- **No business-logic changes.** `Models/`, `Services/`, `Store/`, and the logic inside
  `ViewModels/` stay as-is. The only model edit is lifting two generic color literals
  (`.orange`/`.purple`) out of `Recording+MoodDisplay`.
- **No new third-party dependencies. No UIKit** beyond the system feedback generators in `Haptics`.

## Current State (verified 2026-06-10)

- `moodColor` and `moodIcon` are already centralized in `Models/Recording+MoodDisplay.swift`
  using semantic system colors. **Mood is not color-only and not scattered** — already solved.
- `SettingsView` already uses native `List` + `Section`.
- `CalendarLibraryView` already uses `ContentUnavailableView`.
- No `Glass*` (GlassCard / glassCard / floatingCard / GlassTypography) references remain.
- `Typography.swift` already maps to system text styles with `monospacedDigit()` for timers.

Remaining hardcoded styling (the actual work):

| Category | Count | Files |
|----------|-------|-------|
| `.font(.system(size:` | 19 | RecordView, ExtractionReviewView, OnboardingView, AudioPlayerView, FeedbackButton, RecordingRow, Insights/{TimeOfDayBars, MoodLegend, MonthSelectorScrollView, WeeklyBars, EmotionFrequencyBars}, Components/EmptyStateView |
| Hardcoded color | 2 | Components/CalendarGrid (real), Components/EdgeFadeMask (gradient mask — legitimate) |
| Raw numeric padding/spacing | ~51 | across Views/ |

Confirmed orphans / non-orphans:
- `EmptyStateView.swift` — **orphan** (zero references). Delete.
- `CalendarGrid.swift` — **NOT an orphan** (used by `InsightsCarousel`). Keep; fix its color.

## Architecture

No new architecture. Finish the existing `DesignSystem/` and tokenize stragglers. Two
parallel tracks (A: cleanup, B: completion). Everything stays native.

### Track B — DesignSystem completion (7 new files)

Each is its own file, following the existing `enum`-namespace pattern. **Every new token gets
at least one real usage wired in the same phase** — no speculative dead abstractions.

**`DesignSystem/Palette.swift`** — generic tag/status colors (lifts `.orange`/`.purple` out of the model):
```swift
enum Palette {
    static let energy = Color(.systemOrange)
    static let medication = Color(.systemPurple)
    static let warning = Color(.systemOrange)
}
```
Mood colors stay in `Recording+MoodDisplay` (domain logic, already semantic). Only the
generic literals move.

**`DesignSystem/Icons.swift`** — SF Symbol names in one namespace:
```swift
enum Icons {
    static let calendar = "calendar"
    static let record = "waveform.circle"
    static let insights = "chart.bar.fill"
    static let settings = "gear"
    static let medication = "pills.fill"
    static let energy = "bolt.fill"
    // …filled as found
}
```

**`DesignSystem/Motion.swift`** — animation tokens, Reduce-Motion aware at call sites:
```swift
enum Motion {
    static let snappy: Animation = .snappy(duration: 0.3)
    static let smooth: Animation = .smooth(duration: 0.4)
}
```

**`DesignSystem/Elevation.swift`** — one canonical shadow recipe (an `.elevated()` modifier)
so nobody hand-rolls a shadow. Wired to at least one real card.

**`DesignSystem/Buttons.swift`** — `PrimaryButtonStyle` + `SecondaryButtonStyle`, tinted from
`Theme.accent`, 44pt min tap target. Applied to the record / regenerate-summary buttons.

**`DesignSystem/Haptics.swift`** — semantic feedback, one call site:
```swift
enum Haptics {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
```
Wired on save / record-complete.

**`DesignSystem/Layout.swift`** — layout constants:
```swift
enum Layout {
    static let minTapTarget: CGFloat = 44
    static let maxContentWidth: CGFloat = 600   // iPad
    static let rowMinHeight: CGFloat = 44
}
```

Resulting complete system: existing (Spacing, Radius, Typography, Theme, Card,
ScreenContainer, MedicationBarOverlay) + 7 new = the full token layer.

### Track A — Cleanup

**Deletion:** `Views/Components/EmptyStateView.swift` (orphan) + remove from `project.pbxproj`.

**Tokenize font sizes (19 hits):** map each `.font(.system(size: N…))` to a `Typography.*`
role. Chart numeric labels → `Typography.duration`/`.caption` (monospacedDigit where digits
align). If a size has no matching role, **add the role to `Typography.swift`** rather than
leave a literal.

**Tokenize colors (2 files):**
- `CalendarGrid.swift` → `Theme.*` / `moodColor` / `Palette.*`.
- `EdgeFadeMask.swift` → verify it's an alpha-gradient mask (`.white`/`.clear` as opacity
  stops, not a visible color). If so, **leave it** and add a one-line comment so it doesn't
  read as a violation.

**Tokenize spacing (~51 hits):** replace numeric padding/spacing with `Spacing.*`.
- On-grid values (8/12/16/20…) → swap to matching token.
- **Off-grid values (e.g. 14, 26)** → snap to nearest grid token; each off-grid value is
  flagged in the plan, not silently changed (this is where the "different shapes/sizes" bug hides).

## Testing & Acceptance

UI-token refactoring with no logic change → verification is build + visual + grep, not new
unit tests.

1. **Build green** — `xcodebuild build -project app-two.xcodeproj -scheme app-two
   -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` succeeds after each track.
2. **Existing tests green** — `app-twoTests` still passes (no logic touched).
3. **Acceptance greps (objective done bar):**
   - `.font(.system(size:` in `Views/` → **0**
   - `.white.opacity` / `Color.black` / `Color(red:` in `Views/` → **0** (except documented `EdgeFadeMask`)
   - raw `.orange`/`.purple` literals in `Models/` → **0** (moved to `Palette`)
   - every new DesignSystem file has **≥1 real usage** (no dead tokens)
4. **Visual spot-check** — run the app; eyeball all 4 tabs in light + dark; confirm nothing shifted.

## Guardrails

- No logic changes (Models/Services/Store/VM internals untouched).
- No native-component swaps (deferred).
- No notes-list decision (deferred).
- No new third-party dependencies.
- Tests stay green at every track boundary.
