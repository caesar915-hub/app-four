# DesignSystem Completion + UI Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the SwiftUI rewrite by completing the `DesignSystem/` token layer (7 new token files) and replacing every remaining hardcoded font, color, and spacing value in `Views/` with tokens, so the design system is the single source of visual truth.

**Architecture:** Two tracks. Track B adds new token files (each wired to ≥1 real usage so no dead abstractions ship). Track A deletes dead code and tokenizes stragglers. No business logic changes; no native-component swaps; no new dependencies. Verification is build + existing tests + acceptance greps + visual spot-check.

**Tech Stack:** SwiftUI, Swift 6.2, iOS (sim: iPhone 17 Pro). Build via `xcodebuild`. Existing `DesignSystem/` enum-namespace pattern (`Spacing`, `Radius`, `Typography`, `Theme`).

---

## File Structure

**New (Track B — DesignSystem completion):**
- `app-two/DesignSystem/Palette.swift` — generic tag/status colors
- `app-two/DesignSystem/Icons.swift` — SF Symbol name namespace
- `app-two/DesignSystem/Motion.swift` — animation tokens
- `app-two/DesignSystem/Layout.swift` — layout constants (tap target, content width)
- `app-two/DesignSystem/Elevation.swift` — one shadow recipe + `.elevated()` modifier
- `app-two/DesignSystem/Buttons.swift` — `PrimaryButtonStyle`, `SecondaryButtonStyle`
- `app-two/DesignSystem/Haptics.swift` — semantic feedback wrapper

**Modified (Track A — cleanup):**
- `app-two/Models/Recording+MoodDisplay.swift:38,63,77` — `.orange`/`.purple` → `Palette`
- `app-two/Views/Components/CalendarGrid.swift:54,63` — `Color.white` → semantic
- `app-two/Views/**` — 18 remaining `.font(.system(size:))` → `Typography.*` or `Layout` icon size
- `app-two/Views/**` — raw numeric padding/spacing → `Spacing.*`
- `app-two.xcodeproj/project.pbxproj` — remove deleted file, add new files

**Deleted:**
- `app-two/Views/Components/EmptyStateView.swift` — orphan (zero references)

**Left as-is (documented):**
- `app-two/Views/Components/EdgeFadeMask.swift` — `.black`/`.clear` are alpha-mask stops, not colors. Already commented.

---

## Build & Test Commands (used throughout)

**Build:**
```bash
xcodebuild build -project app-two.xcodeproj -scheme app-two \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -3
```
Expected on success: `** BUILD SUCCEEDED **`

**Tests:**
```bash
xcodebuild test -project app-two.xcodeproj -scheme app-two \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5
```
Expected: `** TEST SUCCEEDED **`

> **Adding new files to the Xcode target:** This project uses a `.pbxproj`. When you `Create` a new `.swift` file under `app-two/DesignSystem/`, it must be added to the `app-two` target or the build won't see it. After creating files, open the project in Xcode once to let it pick them up, OR confirm the project uses file-system synchronized groups (check whether existing DesignSystem files appear in `project.pbxproj` individually — if they do NOT, the target uses synchronized folders and new files are picked up automatically). Verify with a build after each new file.

---

## Track B — DesignSystem Completion

### Task 1: Palette token (tag/status colors)

**Files:**
- Create: `app-two/DesignSystem/Palette.swift`

- [ ] **Step 1: Create the Palette file**

```swift
import SwiftUI

/// Generic tag and status colors used outside the mood domain.
/// Mood colors live in `Recording+MoodDisplay` (domain logic). Use these for
/// energy, medication, and warning tags so no raw `.orange`/`.purple` literals
/// leak into models or views.
enum Palette {
    /// Energy level and side-effect tags
    static let energy = Color(.systemOrange)
    /// Medication-related tags
    static let medication = Color(.systemPurple)
    /// Warning / caution accents
    static let warning = Color(.systemOrange)
}
```

- [ ] **Step 2: Build to verify the file compiles and is in the target**

Run the **Build** command above.
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add app-two/DesignSystem/Palette.swift app-two.xcodeproj/project.pbxproj
git commit -m "feat(design): add Palette tag/status color tokens"
```

---

### Task 2: Wire Palette into the model (lift `.orange`/`.purple`)

**Files:**
- Modify: `app-two/Models/Recording+MoodDisplay.swift:38,63,77`

- [ ] **Step 1: Replace the three raw literals**

Line 38 — energy tag:
```swift
// Before
tags.append(DisplayTag(id: "energy", label: "\(energy) energy", icon: "bolt.fill", color: .orange))
// After
tags.append(DisplayTag(id: "energy", label: "\(energy) energy", icon: "bolt.fill", color: Palette.energy))
```

Line 63 — side-effect tag:
```swift
// Before
tags.append(DisplayTag(id: "se-\(i)", label: effect.capitalized, icon: "bandage.fill", color: .orange))
// After
tags.append(DisplayTag(id: "se-\(i)", label: effect.capitalized, icon: "bandage.fill", color: Palette.energy))
```

Line 77 — medication tag:
```swift
// Before
tags.append(DisplayTag(id: "med-\(event.name)", label: label, icon: "pills.fill", color: .purple))
// After
tags.append(DisplayTag(id: "med-\(event.name)", label: label, icon: "pills.fill", color: Palette.medication))
```

- [ ] **Step 2: Verify no raw literals remain in Models/**

Run:
```bash
grep -rn "color: \.orange\|color: \.purple" app-two/Models/
```
Expected: no output.

- [ ] **Step 3: Build**

Run the **Build** command. Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add app-two/Models/Recording+MoodDisplay.swift
git commit -m "refactor(design): use Palette tokens for tag colors in Recording+MoodDisplay"
```

---

### Task 3: Icons token namespace

**Files:**
- Create: `app-two/DesignSystem/Icons.swift`
- Modify: `app-two/Views/RootTabView.swift` (wire ≥1 real usage)

- [ ] **Step 1: Create the Icons file**

```swift
import Foundation

/// SF Symbol names used across the app, centralized so icon choices are
/// consistent and changeable in one place.
enum Icons {
    // Tabs
    static let calendar = "calendar"
    static let record = "waveform.circle"
    static let insights = "chart.bar.fill"
    static let settings = "gear"

    // Domain
    static let medication = "pills.fill"
    static let energy = "bolt.fill"
    static let sideEffect = "bandage.fill"
}
```

- [ ] **Step 2: Wire Icons into RootTabView tab items**

In `app-two/Views/RootTabView.swift`, replace the literal `systemImage:` strings in the four `.tabItem { Label(...) }` calls:
```swift
// Before
.tabItem { Label("Calendar", systemImage: "calendar") }
// After
.tabItem { Label("Calendar", systemImage: Icons.calendar) }
```
Apply the same substitution for Record (`Icons.record`), Insights (`Icons.insights`), Settings (`Icons.settings`).

- [ ] **Step 3: Build**

Run the **Build** command. Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add app-two/DesignSystem/Icons.swift app-two/Views/RootTabView.swift app-two.xcodeproj/project.pbxproj
git commit -m "feat(design): add Icons namespace and use it in RootTabView"
```

---

### Task 4: Motion token

**Files:**
- Create: `app-two/DesignSystem/Motion.swift`

- [ ] **Step 1: Create the Motion file**

```swift
import SwiftUI

/// Standard animation curves. Use these instead of inline `.animation(.spring())`
/// so motion feels consistent. SwiftUI automatically honors Reduce Motion for
/// these system curves when applied to value-driven animations.
enum Motion {
    /// Quick, responsive — selections, toggles, small state changes
    static let snappy: Animation = .snappy(duration: 0.3)
    /// Gentle — larger transitions, content appearance
    static let smooth: Animation = .smooth(duration: 0.4)
}
```

- [ ] **Step 2: Build**

Run the **Build** command. Expected: `** BUILD SUCCEEDED **`

> Note: Motion is wired into a real usage in Task 11 (replacing an inline animation). It is created here but committed now; the first usage lands in Task 11.

- [ ] **Step 3: Commit**

```bash
git add app-two/DesignSystem/Motion.swift app-two.xcodeproj/project.pbxproj
git commit -m "feat(design): add Motion animation tokens"
```

---

### Task 5: Layout token

**Files:**
- Create: `app-two/DesignSystem/Layout.swift`

- [ ] **Step 1: Create the Layout file**

```swift
import CoreFoundation

/// Layout constants that aren't spacing or radius: tap targets, content width
/// limits, and standard decorative icon sizes.
enum Layout {
    /// Minimum interactive target per Apple HIG
    static let minTapTarget: CGFloat = 44
    /// Maximum readable content width (used to inset content on iPad)
    static let maxContentWidth: CGFloat = 600
    /// Standard minimum row height
    static let rowMinHeight: CGFloat = 44

    /// Decorative SF Symbol sizes (large hero glyphs, not Dynamic Type text).
    /// These use a fixed point size intentionally because they are imagery, not copy.
    enum IconSize {
        /// Inline control glyphs (play/pause, close)
        static let control: CGFloat = 32
        /// Empty-state / section illustration glyph
        static let illustration: CGFloat = 48
        /// Onboarding hero glyph
        static let hero: CGFloat = 72
    }
}
```

- [ ] **Step 2: Build**

Run the **Build** command. Expected: `** BUILD SUCCEEDED **`

> Note: `Metrics.IconSize` is wired into real usages in Task 9 (RecordView control glyphs) and Task 10 (Onboarding hero glyphs). `minTapTarget`/`maxContentWidth` are referenced by Buttons (Task 7).

- [ ] **Step 3: Commit**

```bash
git add app-two/DesignSystem/Layout.swift app-two.xcodeproj/project.pbxproj
git commit -m "feat(design): add Layout constants and decorative icon sizes"
```

---

### Task 6: Elevation token

**Files:**
- Create: `app-two/DesignSystem/Elevation.swift`
- Modify: `app-two/DesignSystem/Card.swift` (wire ≥1 real usage — opt-in elevated variant)

- [ ] **Step 1: Create the Elevation file**

```swift
import SwiftUI

/// One canonical shadow recipe so nobody hand-rolls per-card shadows.
/// Subtle by default — the app is mostly flat/native; use only where depth helps.
extension View {
    func elevated() -> some View {
        self.shadow(color: Color(.label).opacity(0.08), radius: 8, y: 2)
    }
}
```

- [ ] **Step 2: Add an opt-in elevated card variant to Card.swift**

Read `app-two/DesignSystem/Card.swift` first. Add an `elevated` parameter to the existing `.card(...)` modifier that applies `.elevated()` when true, defaulting to `false` (so all existing call sites are unchanged):
```swift
// In the card(...) modifier, after the .background(...) line, add:
//   .modifier(ElevatedIfNeeded(isElevated: elevated))
// OR, simplest form — wrap with a conditional:
func card(padding: CGFloat = Spacing.l, elevated: Bool = false) -> some View {
    let base = self.padding(padding)
        .background(Theme.cardBackground, in: .rect(cornerRadius: Radius.card))
    return Group {
        if elevated { base.elevated() } else { base }
    }
}
```
(Match the exact existing signature/body of `card(...)` — adapt the above to whatever Card.swift currently contains. The key change: add `elevated: Bool = false` and apply `.elevated()` when true.)

- [ ] **Step 3: Build**

Run the **Build** command. Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add app-two/DesignSystem/Elevation.swift app-two/DesignSystem/Card.swift app-two.xcodeproj/project.pbxproj
git commit -m "feat(design): add Elevation shadow + opt-in elevated card variant"
```

---

### Task 7: Button styles

**Files:**
- Create: `app-two/DesignSystem/Buttons.swift`

- [ ] **Step 1: Create the Buttons file**

```swift
import SwiftUI

/// Filled primary action button — one accent-tinted style for the main action
/// on a screen. Honors the 44pt minimum tap target.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget)
            .padding(.horizontal, Spacing.l)
            .background(Theme.accent, in: .rect(cornerRadius: Radius.control))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Tinted secondary action — accent text on a subtle fill.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.headline)
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget)
            .padding(.horizontal, Spacing.l)
            .background(Theme.accent.opacity(0.15), in: .rect(cornerRadius: Radius.control))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}
extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}
```

- [ ] **Step 2: Build**

Run the **Build** command. Expected: `** BUILD SUCCEEDED **`

> Note: `.primary`/`.secondary` button styles are wired into a real usage in Task 12 (regenerate-summary / a primary action button).

- [ ] **Step 3: Commit**

```bash
git add app-two/DesignSystem/Buttons.swift app-two.xcodeproj/project.pbxproj
git commit -m "feat(design): add Primary/Secondary button styles"
```

---

### Task 8: Haptics

**Files:**
- Create: `app-two/DesignSystem/Haptics.swift`

- [ ] **Step 1: Create the Haptics file**

```swift
import UIKit

/// Semantic haptic feedback. One call site for each meaning so feedback is
/// consistent and easy to audit. Call on the main actor (UI events).
@MainActor
enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
```

- [ ] **Step 2: Build**

Run the **Build** command. Expected: `** BUILD SUCCEEDED **`

> Note: `Haptics.success()` is wired into a real usage in Task 12 (on a save / record-complete action).

- [ ] **Step 3: Commit**

```bash
git add app-two/DesignSystem/Haptics.swift app-two.xcodeproj/project.pbxproj
git commit -m "feat(design): add semantic Haptics wrapper"
```

---

## Track A — Cleanup

### Task 9: Delete EmptyStateView orphan + tokenize RecordView control glyphs

**Files:**
- Delete: `app-two/Views/Components/EmptyStateView.swift`
- Modify: `app-two/Views/RecordView.swift:125,136`
- Modify: `app-two.xcodeproj/project.pbxproj`

- [ ] **Step 1: Re-confirm EmptyStateView is unreferenced**

Run:
```bash
grep -rln "EmptyStateView" app-two/ --include="*.swift" | grep -v "Components/EmptyStateView.swift"
```
Expected: no output. If there IS output, STOP — it is not an orphan; do not delete. Report back.

- [ ] **Step 2: Delete the file**

```bash
git rm app-two/Views/Components/EmptyStateView.swift
```

- [ ] **Step 3: Tokenize RecordView control glyphs**

`app-two/Views/RecordView.swift:125` and `:136` use `.font(.system(size: 32))` on control glyphs (a large symbol and an `xmark.circle.fill`). These are control imagery → use `Metrics.IconSize.control`:
```swift
// Before (line 125)
.font(.system(size: 32))
// After
.font(.system(size: Metrics.IconSize.control))
```
```swift
// Before (line 136)
Image(systemName: "xmark.circle.fill").font(.system(size: 32))
// After
Image(systemName: "xmark.circle.fill").font(.system(size: Metrics.IconSize.control))
```

- [ ] **Step 4: Build (confirms EmptyStateView deletion broke nothing)**

Run the **Build** command. Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor(ui): delete EmptyStateView orphan; tokenize RecordView control glyphs"
```

---

### Task 10: Tokenize Onboarding hero glyphs

**Files:**
- Modify: `app-two/Views/Onboarding/OnboardingView.swift:68,112,165`

- [ ] **Step 1: Replace the three hero glyph sizes**

Lines 68 and 112 use `.font(.system(size: 80))`; line 165 uses `.font(.system(size: 72))`. These are onboarding hero illustration glyphs → `Metrics.IconSize.hero` (72). Standardizing 80→72 is intentional (removes an off-system size):
```swift
// Before (lines 68, 112)
.font(.system(size: 80))
// After
.font(.system(size: Metrics.IconSize.hero))
```
```swift
// Before (line 165)
.font(.system(size: 72))
// After
.font(.system(size: Metrics.IconSize.hero))
```

- [ ] **Step 2: Build**

Run the **Build** command. Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Visual check (onboarding only)**

Run the app, trigger onboarding (fresh install or reset), confirm the three hero glyphs look right at the unified size in light + dark.

- [ ] **Step 4: Commit**

```bash
git add app-two/Views/Onboarding/OnboardingView.swift
git commit -m "refactor(ui): tokenize Onboarding hero glyph sizes to Metrics.IconSize.hero"
```

---

### Task 11: Tokenize text font sizes (Insights + Components + misc) and wire Motion

**Files:**
- Modify: `app-two/Views/Insights/MoodLegend.swift:15`
- Modify: `app-two/Views/Insights/TimeOfDayBars.swift:24,34,37`
- Modify: `app-two/Views/Insights/EmotionFrequencyBars.swift:15,29`
- Modify: `app-two/Views/Insights/WeeklyBars.swift:25,29`
- Modify: `app-two/Views/Insights/MonthSelectorScrollView.swift:22`
- Modify: `app-two/Views/Components/RecordingRow.swift:78`
- Modify: `app-two/Views/Components/AudioPlayerView.swift:51`
- Modify: `app-two/Views/Feedback/FeedbackButton.swift:18`
- Modify: `app-two/Views/ExtractionReviewView.swift:303`

- [ ] **Step 1: Map each text size to a Typography role**

Apply these substitutions (text labels, not icons). Mapping rule: 18→`title`, 16→`headline`, 15/14→`body`/`callout`, 13→`callout`, 12/11/9→`caption`; numeric chart values that need digit alignment → `duration`. Preserve any conditional `weight` by appending `.weight(...)` to the token where it existed.

```swift
// MoodLegend.swift:15  — symbol/label size
.font(.system(size: 18))            →  .font(Typography.title)

// TimeOfDayBars.swift:24 — bold numeric value on a bar
.font(.system(size: 12, weight: .bold))   →  .font(Typography.duration.weight(.bold))
// TimeOfDayBars.swift:34
.font(.system(size: 13, weight: .semibold)) → .font(Typography.callout.weight(.semibold))
// TimeOfDayBars.swift:37
.font(.system(size: 11))            →  .font(Typography.caption)

// EmotionFrequencyBars.swift:15
.font(.system(size: 16, weight: .semibold)) → .font(Typography.headline.weight(.semibold))
// EmotionFrequencyBars.swift:29 — numeric count
.font(.system(size: 14, weight: .bold))   →  .font(Typography.duration.weight(.bold))

// WeeklyBars.swift:25
.font(.system(size: 12, weight: .semibold)) → .font(Typography.caption.weight(.semibold))
// WeeklyBars.swift:29
.font(.system(size: 11))            →  .font(Typography.caption)

// MonthSelectorScrollView.swift:22 — keep conditional weight
.font(.system(size: 15, weight: isSelected ? .bold : .semibold))
   →  .font(Typography.body.weight(isSelected ? .bold : .semibold))

// RecordingRow.swift:78 — tiny badge
.font(.system(size: 9))             →  .font(Typography.caption)

// AudioPlayerView.swift:51
.font(.system(size: 16, weight: .semibold)) → .font(Typography.headline.weight(.semibold))

// FeedbackButton.swift:18 — button glyph (control imagery, but inline with text → headline is fine)
.font(.system(size: 20, weight: .semibold)) → .font(Typography.title.weight(.semibold))

// ExtractionReviewView.swift:303 — keep conditional weight
.font(.system(size: 11, weight: isSelected ? .semibold : .regular))
   →  .font(Typography.caption.weight(isSelected ? .semibold : .regular))
```

- [ ] **Step 2: Wire Motion into one real animation**

Find an existing inline animation in the Insights views (e.g. a bar height/selection animation in `MonthSelectorScrollView.swift` or `TimeOfDayBars.swift`). Replace one inline curve with the token:
```swift
// Before (example)
.animation(.spring(), value: selectedMonth)
// After
.animation(Motion.snappy, value: selectedMonth)
```
If no inline animation exists in these files, add `.animation(Motion.snappy, value: viewModel.currentMonth)` to the `MonthSelectorScrollView` selection highlight so the token has a real call site.

- [ ] **Step 3: Verify zero text font-size literals remain (excluding intentional icon sizes)**

Run:
```bash
grep -rn "\.font(.system(size: [0-9]" app-two/Views/ --include="*.swift" | grep -v "Metrics.IconSize"
```
Expected: no output. (All remaining `size:` references must be `Metrics.IconSize.*`.)

- [ ] **Step 4: Build**

Run the **Build** command. Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add app-two/Views/
git commit -m "refactor(ui): tokenize remaining text font sizes to Typography; wire Motion"
```

---

### Task 12: Wire Buttons + Haptics into a real action

**Files:**
- Modify: one real primary-action button (e.g. regenerate-summary in `app-two/Views/Components/ADHDSummarySection.swift`, or the record button in `RecordView.swift` — pick the clearest primary action)

- [ ] **Step 1: Locate a primary action button**

Run:
```bash
grep -rn "Button" app-two/Views/Components/ADHDSummarySection.swift app-two/Views/RecordView.swift | head
```
Pick the most clearly "primary" action (a full-width or main CTA). If a regenerate-summary button exists, prefer that.

- [ ] **Step 2: Apply the primary button style + success haptic**

```swift
// Before
Button("Regenerate") { viewModel.regenerate() }
// After
Button("Regenerate") {
    Haptics.success()
    viewModel.regenerate()
}
.buttonStyle(.primary)
```
(Adapt label/action to the actual button found. The two required changes: add `.buttonStyle(.primary)` and a `Haptics` call inside the action.)

- [ ] **Step 3: Build**

Run the **Build** command. Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add app-two/Views/
git commit -m "refactor(ui): apply PrimaryButtonStyle + success haptic to primary action"
```

---

### Task 13: Tokenize CalendarGrid colors

**Files:**
- Modify: `app-two/Views/Components/CalendarGrid.swift:54,63`

- [ ] **Step 1: Inspect the context**

Read `app-two/Views/Components/CalendarGrid.swift` around lines 50–70. The colors are the **foreground text color of a day number** that sits on a mood-colored circle when `day.hasEntries`. White text on a saturated mood fill is the intent.

- [ ] **Step 2: Replace hardcoded white with semantic color**

```swift
// Before (line 54)
day.hasEntries ? Color.white.opacity(0.55) : Color.primary,
// After
day.hasEntries ? Color(.systemBackground).opacity(0.55) : Color.primary,
```
```swift
// Before (line 63)
day.hasEntries ? Color.white :
// After
day.hasEntries ? Color(.systemBackground) :
```
Rationale: `Color(.systemBackground)` is white in light mode and near-black in dark mode. On a saturated mood circle, the system background gives a readable, adaptive contrast instead of forced white. **If the visual check in Step 4 shows poor contrast in dark mode, fall back to `.white` with a one-line comment documenting that white-on-mood-fill is intentional** (acceptable per spec's documented-exception rule).

- [ ] **Step 3: Verify zero hardcoded color literals remain in Views/ (except documented EdgeFadeMask)**

Run:
```bash
grep -rn "Color\.white\|Color\.black\|Color(red:\|Color(white:" app-two/Views/ --include="*.swift" | grep -v "EdgeFadeMask"
```
Expected: no output.

- [ ] **Step 4: Build + visual check**

Run the **Build** command. Expected: `** BUILD SUCCEEDED **`
Then run the app, open the Calendar tab, and confirm day numbers on mood circles are readable in **both** light and dark mode.

- [ ] **Step 5: Commit**

```bash
git add app-two/Views/Components/CalendarGrid.swift
git commit -m "refactor(ui): replace hardcoded white with semantic color in CalendarGrid"
```

---

### Task 14: Tokenize raw spacing values

**Files:**
- Modify: various `app-two/Views/**` files containing raw numeric padding/spacing

- [ ] **Step 1: Enumerate raw spacing hits**

Run:
```bash
grep -rn "padding(\.\?[a-z]*, [0-9]\|spacing: [0-9]\|\.frame(height: [0-9]\|\.frame(width: [0-9]" \
  app-two/Views/ --include="*.swift" | grep -viE "Spacing\.|Layout\.|Radius\." | grep -vE "EdgeFadeMask"
```
This lists every remaining raw numeric layout value. Note: some `.frame(width:height:)` are legitimate fixed sizes (e.g. an 8×8 dot, waveform bar widths) — those are **dimensions, not spacing/padding**, and may stay if they're intrinsic to the component. Tokenize **padding and spacing**; leave intrinsic element dimensions, adding a brief comment only if it's ambiguous.

- [ ] **Step 2: Map each padding/spacing value to a Spacing token**

For every `.padding(_, N)` and `spacing: N`, substitute the matching token:
`4→Spacing.xs`, `8→Spacing.s`, `12→Spacing.m`, `16→Spacing.l`, `20→Spacing.xl`, `24→Spacing.xxl`, `32→Spacing.section`, `40→Spacing.hero`.

For **off-grid values** (e.g. 14, 18, 26, 36): snap to the nearest token and note it in the commit body. Example:
```swift
// Before
.padding(.vertical, 14)
// After
.padding(.vertical, Spacing.m)   // was 14 → snapped to 12
```
Do this file by file. Build after every 2–3 files to catch mistakes early.

- [ ] **Step 3: Verify raw padding/spacing is gone**

Run the same grep from Step 1.
Expected: only legitimate intrinsic element dimensions remain (document any that are non-obvious). No raw `.padding`/`spacing:` literals.

- [ ] **Step 4: Build**

Run the **Build** command. Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add app-two/Views/
git commit -m "refactor(ui): tokenize raw padding/spacing to Spacing grid; snap off-grid values"
```

---

## Task 15: Final acceptance + full verification

**Files:** none (verification only)

- [ ] **Step 1: Run all acceptance greps**

```bash
echo "font sizes (expect only Metrics.IconSize):"
grep -rn "\.font(.system(size:" app-two/Views/ --include="*.swift" | grep -v "Metrics.IconSize"
echo "--- hardcoded colors (expect none, EdgeFadeMask excluded):"
grep -rn "Color\.white\|Color\.black\|Color(red:\|Color(white:" app-two/Views/ --include="*.swift" | grep -v "EdgeFadeMask"
echo "--- raw model tag colors (expect none):"
grep -rn "color: \.orange\|color: \.purple" app-two/Models/
echo "--- new DesignSystem files exist:"
ls app-two/DesignSystem/{Palette,Icons,Motion,Layout,Elevation,Buttons,Haptics}.swift
```
Expected: first three produce **no output**; the `ls` lists all 7 files.

- [ ] **Step 2: Confirm every new token has ≥1 real usage**

```bash
grep -rl "Palette\." app-two/Models app-two/Views | head -1     # Palette
grep -rl "Icons\." app-two/Views | head -1                       # Icons
grep -rl "Motion\." app-two/Views | head -1                      # Motion
grep -rl "Metrics.IconSize" app-two/Views | head -1               # Layout
grep -rl "\.elevated()\|elevated:" app-two | head -1             # Elevation
grep -rl "buttonStyle(.primary)\|buttonStyle(.secondary)" app-two/Views | head -1  # Buttons
grep -rl "Haptics\." app-two/Views | head -1                     # Haptics
```
Expected: each line prints at least one file path. If any is empty, the token is dead — wire it before finishing.

- [ ] **Step 3: Full build**

Run the **Build** command. Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Full test suite**

Run the **Tests** command. Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Visual spot-check all 4 tabs, light + dark**

Run the app. Walk Calendar, Record, Insights, Settings in both light and dark mode. Confirm nothing shifted unexpectedly (spacing rhythm, text sizes, colors). Note any regression and fix before final commit.

- [ ] **Step 6: Final commit (if any visual fixes were needed)**

```bash
git add -A
git commit -m "chore(ui): final design-system cleanup pass — acceptance verified"
```

---

## Self-Review Notes (for the planner, not a task)

- **Spec coverage:** Palette (T1–2), Icons (T3), Motion (T4,11), Layout (T5,9,10), Elevation (T6), Buttons (T7,12), Haptics (T8,12), EmptyStateView deletion (T9), font tokenization (T9,10,11), CalendarGrid color (T13), EdgeFadeMask left documented (noted, no task needed), spacing tokenization (T14), acceptance greps + tests + visual (T15). All spec requirements mapped.
- **No-dead-token guarantee:** every new file is wired to a real usage (verified in T15 Step 2).
- **Deferred items stay deferred:** no native sweep, no notes-list decision, no logic changes.
