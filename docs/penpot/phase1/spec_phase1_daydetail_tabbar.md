# Squirl Penpot Reproduction Spec: DayDetailSheet + RootTabView

**Status:** Phase 1 — Static Hi-Fi Light Mode (Paper #F6F1E7) — Ready for Penpot boards.

**Source of truth:** SwiftUI source files in `/Users/caesargrey/Projects/app-four/app-four`.

---

## 1. DayDetailSheet Spec

### 1.1 Presentation Context
- **File:** `/Users/caesargrey/Projects/app-four/app-four/Views/Components/DayDetailSheet.swift` (lines 3–45)
- **Triggers from:** `/Users/caesargrey/Projects/app-four/app-four/Views/InsightsView.swift` — `.sheet(item: $viewModel.selectedDay)` — tapping a calendar day in Insights view
- **Sheet modifiers:** `.presentationDetents([.medium, .large])` (line 42), `.presentationDragIndicator(.visible)` (line 43)
- **Presentation:** **Standard iOS modal sheet** with two detents (medium/large) and visible grabber handle (pill shape at top)

### 1.2 Layout & Structure (Top-to-Bottom)

```
┌─────────────────────────────────────────────────┐
│  ╭─ Grabber pill (visible) ─────╮              │
│                                                 │
│  "Today" / "Yesterday" / "Friday, 28 Jun"      │ ← navigationTitle
│  [Done]                              (right)   │ ← toolbar button
├─────────────────────────────────────────────────┤
│  ScrollView {                                   │
│    VStack(spacing: Spacing.s = 8pt) {          │
│                                                 │
│      [RecordingRow 1]                          │
│      [RecordingRow 2]                          │
│      [RecordingRow 3]                          │
│      ...                                        │
│                                                 │
│    }                                            │
│    .padding(Spacing.xl = 20pt)  // all sides   │
│  }                                              │
└─────────────────────────────────────────────────┘
```

### 1.3 Header Section

| Element | Value | Source |
|---------|-------|--------|
| **Title format** | "Today" (if today), "Yesterday" (if yesterday), or "EEEE, d MMM" format (e.g. "Friday, 28 Jun") | DayDetailSheet.swift:9–15 |
| **Title typography** | `.navigationTitle()` with `.navigationBarTitleDisplayMode(.inline)` → Standard iOS nav title, SF Pro (system) | DayDetailSheet.swift:34–35 |
| **Title color** | System default (black in light mode) | Implicit SwiftUI default |
| **Toolbar button** | "Done" text button, positioned `.confirmationAction` (right side) | DayDetailSheet.swift:37–39 |
| **Button typography** | System default blue (accent) | Implicit SwiftUI |
| **Grabber** | Visible drag indicator, default iOS pill shape | DayDetailSheet.swift:43 |

### 1.4 Content: Recording List

Each row is a **RecordingRow** component. Layout per row:

| Subcomponent | Geometry | Source |
|---|---|---|
| **Mood dot** | 10pt diameter circle, positioned top-left with 5pt top padding (optical alignment) | RecordingRow.swift:37–43 |
| **Spacing** | 12pt (Spacing.m) horizontal gap between dot and text block | RecordingRow.swift:19 |
| **Title row** | HStack with title (headline SF Pro 16 semibold), status badge (right) | RecordingRow.swift:45–52 |
| **Meta row** | Timestamp · Duration (caption SF 12 regular, secondary text color) | RecordingRow.swift:55–68 |
| **Tag row** | Horizontal scroll of tag chips if `!recording.displayTags.isEmpty` — scrollDisabled if ≤3 tags | RecordingRow.swift:72–94 |
| **Card wrapper** | `.card(padding: Spacing.m)` — 12pt padding, cardBackground (#FCF8EF light), 16pt corner radius, 1pt border (cardStroke #E3DAC7), subtle shadow | RecordingRow.swift:30, Card.swift:18–27 |

#### Recording Row Spacing
- **VStack inner spacing:** `Spacing.xs` = 4pt (gap between title row, meta row, tag row)
- **ScrollView outer padding:** `Spacing.xl` = 20pt (all sides of the VStack container)
- **Row-to-row spacing:** `Spacing.s` = 8pt (gap between each RecordingRow card)

### 1.5 Tag Chip Style (if tags present)

| Property | Value | Source |
|---|---|---|
| **Horizontal padding** | Spacing.s = 8pt | RecordingRow.swift:87 |
| **Vertical padding** | Spacing.xs = 4pt | RecordingRow.swift:88 |
| **Background** | `tag.color.opacity(0.12)` — tint at 12% opacity | RecordingRow.swift:89 |
| **Corner radius** | .capsule (full-height pill shape) | RecordingRow.swift:89 |
| **Icon size** | Typography.caption (12pt) | RecordingRow.swift:81, 84 |
| **Glyph option** | May show SignalGlyph if tag has glyph, else SF Symbol (icon) | RecordingRow.swift:77–82 |

### 1.6 Status Badge

| State | Display | Color | Source |
|---|---|---|---|
| `.transcribing` | Spinner + "Processing" text (caption 12pt) | textSecondary | RecordingRow.swift:99–105 |
| `.completed` (with summary) | ✓ checkmark circle filled glyph (caption size) | statusDone (meadowGreen #5F8A4C) | RecordingRow.swift:107–109 |
| `.completed` (no summary) or `.draft` | (empty) | — | RecordingRow.swift:110–112 |

### 1.7 Colors & Typography (DayDetailSheet context)

| Element | Typography | Color (light) | Source |
|---|---|---|---|
| **Title (navigationTitle)** | System iOS title style | textPrimary #221E16 | Implicit |
| **Recording title** | Typography.headline (SF Pro 16 semibold) | Theme.textPrimary #221E16 | RecordingRow.swift:48 |
| **Timestamp · Duration** | Typography.caption (SF Pro 12 regular) | Theme.textSecondary #7A7361 | RecordingRow.swift:58–59 |
| **"Processing"** | Typography.caption (SF Pro 12 regular) | Theme.textSecondary #7A7361 | RecordingRow.swift:102 |
| **Card background** | — | Theme.cardBackground #FCF8EF | Card.swift:21 |
| **Card border** | 1pt stroke | Theme.cardStroke #E3DAC7 | Card.swift:24 |
| **Card shadow** | 10pt radius, 3pt Y offset | #221E16 @ 6% opacity | Card.swift:26 |

### 1.8 Empty State
- **Not explicitly defined** in DayDetailSheet.swift — list will be empty if `day.recordings.isEmpty`, showing only scroll container.
- For Penpot: Show a sample with at least 2–3 RecordingRow cards populated.

### 1.9 Difference from RecordingDetailView
- **DayDetailSheet:** Many-recording view for a whole calendar day; each row is tap-to-navigate to detail
- **RecordingDetailView:** Single-recording detail page (not reproduced here, out of scope)
- **Key distinction:** Sheet is a wrapper around a list, not a detail view.

---

## 2. RootTabView Spec

### 2.1 Source & Structure
- **File:** `/Users/caesargrey/Projects/app-four/app-four/Views/RootTabView.swift` (lines 12–38)
- **Type:** Standard SwiftUI `TabView(selection:)` with four tabs
- **Enum:** `Tab` (calendar, checkIn, insights, settings) — lines 5–10

### 2.2 Tab Bar Configuration

| Tab | Label Text (verbatim) | SF Symbol Icon | Icon name (Icons.swift) | Placement | Source |
|---|---|---|---|---|---|
| 1 | "Calendar" | calendar | Icons.calendar = "calendar" | .tabItem | RootTabView.swift:20–22 |
| 2 | "Check in" | checkmark.circle | Icons.checkIn = "checkmark.circle" | .tabItem | RootTabView.swift:24–26 |
| 3 | "Insights" | chart.bar.fill | Icons.insights = "chart.bar.fill" | .tabItem | RootTabView.swift:28–30 |
| 4 | "Settings" | gear | Icons.settings = "gear" | .tabItem | RootTabView.swift:32–34 |

### 2.3 Tab Bar Styling

| Property | Value | Source |
|---|---|---|
| **Tint color (selected state)** | `Theme.meadowGreen` = `Color(lightHex: "#5F8A4C", darkHex: "#6E9A58")` | RootTabView.swift:36, Theme.swift:29 |
| **Tint color (light mode resolved)** | **#5F8A4C** | Theme.swift:29 |
| **Background material** | Default iOS TabView bar (opaque light background in light mode) | Implicit SwiftUI |
| **Selected icon state** | SF Symbol fills (default behavior for .tabItem) | Implicit |
| **Unselected icon state** | SF Symbol outlines (default behavior) | Implicit |
| **Tab bar position** | Bottom (standard iOS) | Implicit SwiftUI TabView |
| **Badges** | None visible | RootTabView.swift (no badge modifiers) |

### 2.4 Tab Order & Navigation Targets

| Order | Tab | Target View | File |
|---|---|---|---|
| 1 | calendar | CalendarLibraryView(store:, selectedTab:) | RootTabView.swift:20 |
| 2 | checkIn | CheckInView(store:, services:, shouldAutoStart:) | RootTabView.swift:24 |
| 3 | insights | InsightsView(store:, selectedTab:) | RootTabView.swift:28 |
| 4 | settings | SettingsView(store:, services:, selectedTab:) | RootTabView.swift:32 |

### 2.5 Selection Binding
- **Selected tab state:** Bound to `$selectedTab: Tab` (SwiftUI @Binding)
- **Currently selected tab:** Passed as `.tag(Tab.*)` on each view — allows external control of active tab
- **Preview default:** `.constant(.calendar)`

### 2.6 Icon Details (SF Symbols)
Resolved from `/Users/caesargrey/Projects/app-four/Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Icons.swift`:

| Icon Token | SF Symbol Name | Usage |
|---|---|---|
| Icons.calendar | "calendar" | Calendar tab icon |
| Icons.checkIn | "checkmark.circle" | Check in tab icon |
| Icons.insights | "chart.bar.fill" | Insights tab icon (filled, not outline) |
| Icons.settings | "gear" | Settings tab icon |

### 2.7 Color Tokens (Resolved)

| Token | Light Value | Dark Value | Resolved (Light) | Source |
|---|---|---|---|---|
| Theme.meadowGreen (tint) | #5F8A4C | #6E9A58 | **#5F8A4C** | Theme.swift:29 |
| Theme.textPrimary (unselected icon) | #221E16 | #F3EEE0 | **#221E16** | Theme.swift:18 |

---

## 3. Token Resolution Table

### Typography (all text in both views)

| Token | Point Size | Weight | Font Face | Dynamic Type Style | Light Mode | Source |
|---|---|---|---|---|---|---|
| Typography.headline | 16 | .semibold | SF Pro | .headline | #221E16 | Typography.swift:31 |
| Typography.caption | 12 | .regular | SF Pro | .caption1 | #7A7361 | Typography.swift:41 |
| Typography.label | 12 | .medium | SF Pro | .caption1 (uppercase + tracking 0.7) | #7A7361 | Typography.swift:43 |
| System nav title | (iOS system) | — | SF Pro | — | #221E16 | Implicit |

### Spacing

| Token | Value | Usage | Source |
|---|---|---|---|
| Spacing.xs | 4pt | Gap between title/meta/tag rows within RecordingRow | Spacing.swift:7 |
| Spacing.s | 8pt | Gap between RecordingRow cards; padding in tag chips | Spacing.swift:9 |
| Spacing.m | 12pt | Card padding in RecordingRow, HStack spacing (dot to text) | Spacing.swift:11 |
| Spacing.l | 16pt | Standard outer margin (not used in DayDetailSheet, but reference) | Spacing.swift:13 |
| Spacing.xl | 20pt | ScrollView outer padding in DayDetailSheet | Spacing.swift:15 |

### Radius

| Token | Value | Usage | Source |
|---|---|---|---|
| Radius.card | 16pt | RecordingRow card corner radius, CardBackground overlay | Radius.swift:6 |
| Radius.control | 10pt | Chips, small buttons (not used in these views) | Radius.swift:8 |
| Radius.chip | 15pt | Signal/emotion chips (expanded row, not in basic RecordingRow) | Radius.swift:12 |

### Colors (Light Mode Only — Paper Theme)

| Token | Light Hex | Usage | Source |
|---|---|---|---|
| Theme.background | #F6F1E7 | Main screen background (DayDetailSheet sheet background implicit) | Theme.swift:9 |
| Theme.cardBackground | #FCF8EF | RecordingRow card fill | Theme.swift:11 |
| Theme.cardStroke | #E3DAC7 | RecordingRow card border (1pt) | Theme.swift:24 |
| Theme.textPrimary | #221E16 | Recording title, system nav title | Theme.swift:18 |
| Theme.textSecondary | #7A7361 | Timestamp, duration, "Processing" badge text | Theme.swift:19 |
| Theme.statusDone / meadowGreen | #5F8A4C | Checkmark badge, tab bar tint | Theme.swift:29, 33 |
| Theme.separator | #E3DAC7 | Card borders (same as cardStroke) | Theme.swift:23 |

### Opacity

| Token | Value | Usage | Source |
|---|---|---|---|
| Opacity.deEmphasis | 0.34 | Not used in these views | Opacity.swift:8 |
| Opacity.moodBlock | 0.24 | Not used in these views | Opacity.swift:13 |
| Opacity.moodBadge | 0.50 | Not used in these views | Opacity.swift:15 |
| **Tag chip fill** | 0.12 (custom) | tag.color at 12% opacity (not in Opacity enum) | RecordingRow.swift:89 |
| **Card shadow** | 0.06 | Shadow color opacity (#221E16 @ 6%) | Card.swift:26 |

### Metrics (Mood Dots, Interaction Targets)

| Token | Value | Usage | Source |
|---|---|---|---|
| Metrics.minTapTarget | 44pt | Not directly visible in these views (underlying system) | Metrics.swift:10 |
| (Mood dot diameter) | 10pt | Circle in RecordingRow, 5pt top padding for alignment | RecordingRow.swift:38–41 |

---

## 4. Penpot Reproduction Flags & Gotchas

### 4.1 DayDetailSheet

#### Sheet Presentation & Detents
- **Not a static frame:** The sheet has two detents (medium, large) — in Penpot, show the **medium detent** as the primary static frame, with a note that it's springy/draggable in code.
- **Grabber:** Include the iOS-standard white pill shape at the top center (dismiss affordance). Height ~5pt, width ~40pt.
- **Safe area insets:** The sheet respects notch/bottom safe area; in light prototype, ignore notch, but preserve ~20pt bottom safe area margin for content padding.

#### NavigationStack
- **Not directly visual:** SwiftUI's NavigationStack is a routing container. In Penpot, show the sheet as a static view with no nav chrome visible (title appears in standard iOS nav bar, "Done" button on right).

#### Scroll Behavior
- **ScrollView:** Content is scrollable vertically if it exceeds sheet height. For Penpot board, show a static frame with 3–4 RecordingRow cards visible in medium detent; indicate overflow with a "scroll indicator" hint or note.

#### Shadow & Material
- **Card shadow:** 10pt blur, 3pt Y offset, #221E16 @ 6% — baked into each row card, not the sheet itself.

### 4.2 RootTabView

#### Tab Bar Material & Safe Area
- **Standard iOS tab bar:** Opaque light background (Paper #F6F1E7 with system translucency). In Penpot light mode, use **#F6F1E7 or slightly lighter** for the bar background.
- **Bottom safe area:** Tab bar respects home indicator area on modern iPhones — show ~8pt of clearance above the bar edge (system handling; Penpot can ignore this detail, but note it).
- **No transparency/blur in code:** The tab bar uses default iOS materials (not explicitly set); for Penpot static reproduction, treat as a solid light background.

#### Icon States
- **Selected icon:** Filled (for "chart.bar.fill", already filled; for others, system rendering applies fill tint). Color: **#5F8A4C**.
- **Unselected icon:** Outline/default glyph rendered in **#221E16** (system gray, scaled down by SwiftUI).
- **No custom badges:** No notification counts or badges are visible.

#### Label Rendering
- **TabItem labels:** "Calendar", "Check in", "Insights", "Settings" — rendered in system font (SF Pro, 10–12pt caption size in tab bar). **Verbatim text — do not alter or abbreviate.**

#### Tint Binding
- **`.tint(Theme.meadowGreen)`:** Applied to the entire TabView, tinting selected state (icon + label) to **#5F8A4C**.

---

## 5. Penpot Board Outline

### Board 1: DayDetailSheet (Medium Detent)
- **Dimensions:** 390 × 844pt (iPhone 14 / standard width) for full context, but sheet content area is ~390 × 500pt (medium detent estimate).
- **Layers:**
  1. Background (Paper #F6F1E7, full screen behind sheet)
  2. Sheet container (rounded top corners 12pt, medium detent height)
  3. Grabber pill (white, 5pt × 40pt, top-center, ~12pt from top)
  4. Nav bar area (nav title "Friday, 28 Jun", "Done" button right, ~56pt tall, system light gray background)
  5. ScrollView content area (white/Paper background)
     - VStack with 8pt row spacing
     - 3–4 RecordingRow cards (each is a group: mood dot + text block + card styling)
  6. Overflow indicator (optional: small hint showing more content below)

**Key measurements:**
- Sheet top corner radius: **16pt** (Radius.card)
- Card padding: **12pt** (Spacing.m)
- Row-to-row gap: **8pt** (Spacing.s)
- Outer scroll padding: **20pt** (Spacing.xl)

### Board 2: RootTabView (Tab Bar Only)
- **Dimensions:** 390 × 60pt (iPhone 14 tab bar) — or include 390 × 100pt to show a sample tab view above (context).
- **Layers:**
  1. Tab bar background (Paper #F6F1E7, or lighter; ~60pt tall)
  2. Four tab items, each with:
     - Icon (SF Symbol, 24–25pt size, tinted or grayscale)
     - Label text below (10pt caption, SF Pro)
  3. Tint indicator (e.g., selected tab "Insights" shows #5F8A4C for icon + label)
  4. Safe area clearance hint (8pt space below bar for home indicator)

**Key measurements:**
- Tab bar height: **49–60pt** (iOS standard, bottom safe area adds ~34pt on notched devices)
- Icon size: **25pt** (SF Symbol)
- Label size: **10pt** SF Pro, medium weight
- Selected tint: **#5F8A4C**
- Unselected icon/label: **#221E16**

---

## 6. Verbatim Text & Symbol Reference

### DayDetailSheet
| Element | Verbatim Text | SF Symbol / Notes |
|---|---|---|
| Done button | "Done" | (no symbol) |
| Date (example) | "Friday, 28 Jun" | (formatted dynamically; show example) |
| Processing badge | "Processing" | checkmark.circle.fill (status done variant) |

### RootTabView
| Tab | Label (verbatim) | Icon (SF Symbol name) | Icon variant (light mode) |
|---|---|---|---|
| 1 | Calendar | calendar | outline (unselected) / filled (selected) |
| 2 | Check in | checkmark.circle | outline / filled |
| 3 | Insights | chart.bar.fill | (already filled) |
| 4 | Settings | gear | outline / filled |

---

## 7. Code References Summary

| Component | File | Lines | Key Properties |
|---|---|---|---|
| DayDetailSheet | `/Users/caesargrey/Projects/app-four/app-four/Views/Components/DayDetailSheet.swift` | 3–45 | `.presentationDetents([.medium, .large])`, `.presentationDragIndicator(.visible)`, navigationTitle, .sheet() trigger |
| RecordingRow (content) | `/Users/caesargrey/Projects/app-four/app-four/Views/Components/RecordingRow.swift` | 15–128 | `.card(padding: Spacing.m)`, mood dot, title/meta/tag layout |
| RootTabView | `/Users/caesargrey/Projects/app-four/app-four/Views/RootTabView.swift` | 12–38 | `.tint(Theme.meadowGreen)`, four tabs, TabView(selection:) |
| Typography | `/Users/caesargrey/Projects/app-four/Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Typography.swift` | 1–72 | SF Pro/SF Mono, Dynamic Type scaling, headline, caption, label |
| Spacing | `/Users/caesargrey/Projects/app-four/Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Spacing.swift` | 1–25 | xs (4), s (8), m (12), l (16), xl (20) |
| Theme | `/Users/caesargrey/Projects/app-four/Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Theme.swift` | 1–44 | meadowGreen #5F8A4C, cardBackground #FCF8EF, textPrimary #221E16, textSecondary #7A7361 |
| Radius | `/Users/caesargrey/Projects/app-four/Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Radius.swift` | 1–13 | card (16pt), control (10pt), chip (15pt) |
| Card modifier | `/Users/caesargrey/Projects/app-four/Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Card.swift` | 1–60 | padding + background + border + shadow |
| Opacity | `/Users/caesargrey/Projects/app-four/Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Opacity.swift` | 1–16 | deEmphasis (0.34), moodBlock (0.24), moodBadge (0.50), tag fill custom (0.12) |
| Metrics | `/Users/caesargrey/Projects/app-four/Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Metrics.swift` | 1–68 | minTapTarget (44), mood dot (10pt), header badge (42pt) |
| Icons | `/Users/caesargrey/Projects/app-four/Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Icons.swift` | 1–15 | calendar, checkmark.circle, chart.bar.fill, gear |

---

## 8. Penpot Board Setup Instructions

1. **Create two boards** in a single Penpot file:
   - **Board A: "DayDetailSheet — Medium Detent"** — 390 × 600pt, light mode (Paper #F6F1E7 background)
   - **Board B: "RootTabView — Tab Bar"** — 390 × 120pt, same background

2. **Use Penpot's "Paper" / light mode** (user selects in Penpot theme dropdown if available, or manually apply light hex values).

3. **Resolveall hex values** directly (e.g., #5F8A4C, #FCF8EF, #221E16) — no dynamic token names (Penpot doesn't natively support SwiftUI token resolution, so hardcode the light values).

4. **Typography**: Apply SF Pro (or San Francisco if not available) with exact weights and sizes from Typography.swift table above.

5. **Symbols/Icons**: Use Penpot's SF Symbol library or manually import SVG icons matching the SF Symbol names (calendar, checkmark.circle, chart.bar.fill, gear).

6. **Shadows**: Use the card shadow formula: blur 10pt, Y offset 3pt, #221E16 @ 6% opacity (or adjust per Penpot's shadow UI).

7. **Interactions**: Penpot doesn't animate detents or scrolling; add notes/comments to indicate "medium/large detents in code" and "scrollable on overflow".

---

## Checklist for Penpot Artist

- [ ] Create Board A (DayDetailSheet)
  - [ ] Sheet background with 16pt top radius
  - [ ] Grabber pill (5pt × 40pt, white, centered)
  - [ ] Nav bar (56pt tall, Paper background, nav title + Done button)
  - [ ] Mood dot (10pt circle) — place in RecordingRow
  - [ ] RecordingRow card (card styling with 12pt corner radius, 1pt border, shadow)
  - [ ] Title row (headline SF Pro 16 semibold, #221E16)
  - [ ] Meta row (caption SF Pro 12 regular, #7A7361, timestamp · duration)
  - [ ] Tag chips (8pt h-padding, 4pt v-padding, capsule shape, tag.color @ 12% opacity background)
  - [ ] 3–4 complete rows, 8pt spacing between each
  - [ ] 20pt outer padding (Spacing.xl) applied to entire VStack

- [ ] Create Board B (RootTabView)
  - [ ] Tab bar background (60pt tall, Paper #F6F1E7)
  - [ ] Four tab items (Calendar, Check in, Insights, Settings)
  - [ ] Icons in SF Symbol style (outline + filled states)
  - [ ] Selected state: Insights tab with icon + label tinted #5F8A4C
  - [ ] Unselected state: Other tabs with icon + label in #221E16
  - [ ] Label text (10pt SF Pro, verbatim)
  - [ ] Safe area clearance hint (8pt below bar)

- [ ] Color palette in Penpot:
  - [ ] Paper #F6F1E7
  - [ ] Card #FCF8EF
  - [ ] Border #E3DAC7
  - [ ] Text primary #221E16
  - [ ] Text secondary #7A7361
  - [ ] Tint (meadowGreen) #5F8A4C

- [ ] Link boards to design system or create shared components for RecordingRow cards (reusable pattern).

---

## Final Notes

- **Light mode only:** This spec covers Paper theme (light). Dark mode (Loam) would swap hex values per Theme.swift dark values.
- **Dynamic Type not modeled:** Penpot static reproduction uses fixed point sizes; note that typography scales on device per `UIFontMetrics`.
- **No animations:** Penpot boards are static; gestures/transitions (sheet detent drag, tab switching) are noted but not animated.
- **Accessibility:** RecordingRow includes `.accessibilityElement(children: .combine)` and labels — not visible in static design, but listed for completeness.
- **Future extension:** If RecordingDetailView or other views are needed, follow the same pattern — read source, resolve tokens, create static Penpot boards per component.

