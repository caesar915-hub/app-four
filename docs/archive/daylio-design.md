> **⚠️ HISTORICAL SNAPSHOT — superseded.** Frozen 2026-06-15. Pre-app-four (WhisperNotes/app-two era); does not reflect current project state. Current architecture lives in the Notion `app-two` DB, [docs/BACKLOG.md](../BACKLOG.md), and [docs/DEVLOG.md](../DEVLOG.md). Any "Gemma" mention is historical — Gemma was removed before the app-four fork.

# Daylio iOS App — Design Reference

## Color Palette

| Role | Usage |
|---|---|
| Primary green `#4DB87A` (approx) | FAB, selected chips, Save button, active tab tint, section dot indicators |
| Mood: rad `#4CAF50` | Bright green — highest mood |
| Mood: good `#8BC34A` | Yellow-green |
| Mood: meh `#78909C` | Blue-gray — neutral |
| Mood: bad `#FFA726` | Orange |
| Mood: awful `#EF5350` | Red-pink |
| Background `#F2F2F7` | System grouped background (iOS default) |
| Card surface `#FFFFFF` | White cards on gray background |
| Text primary `#1C1C1E` | Navigation titles, mood names, list labels |
| Text secondary `#8E8E93` | Timestamps, tag text, section labels |
| Separator | Standard iOS hairline separator |

Never use hardcoded hex values in code — use asset catalog semantic colors or system colors (`.systemGroupedBackground`, `.secondarySystemGroupedBackground`, etc.) so the palette adapts to light/dark mode automatically.


## Typography

| Style | Usage |
|---|---|
| `.title2.bold` | Navigation bar title ("More", "June 2026") |
| `.headline` | Activity section headers ("Emotions", "Sleep"), mood count label |
| `.title3.bold` colored | Mood name in entry row (e.g. "good", "rad", "bad") — tinted with mood color |
| `.body` | List row labels, activity grid labels |
| `.subheadline` | Date section headers ("TODAY, 2 JUN") — uppercased, secondary color |
| `.caption` | Timestamps, inline tag text, badge counts |

- Avoid `.caption2` — too small to read comfortably.
- Mood names use bold weight and the mood's accent color, not a generic tint.
- Date section headers are uppercased via `.textCase(.uppercase)`, not manually typed in caps.


## Spacing & Layout Constants

```swift
enum DaylioLayout {
    static let screenPadding: CGFloat = 16
    static let cardCornerRadius: CGFloat = 16
    static let iconCornerRadius: CGFloat = 10        // list row app-icon style
    static let chipSize: CGFloat = 52                // activity circle chip diameter
    static let chipSpacing: CGFloat = 8              // between chips in grid
    static let chipColumns = 5                       // activity grid columns
    static let sectionSpacing: CGFloat = 12          // gap between card groups
    static let rowHeight: CGFloat = 54               // standard list row height
    static let fabSize: CGFloat = 56                 // floating action button
    static let calendarDaySize: CGFloat = 38         // calendar day circle
    static let listIconSize: CGFloat = 30            // rounded-square icon in list rows
    static let moodAvatarSmall: CGFloat = 36         // mood face in entry row
    static let moodAvatarLarge: CGFloat = 52         // mood face in nav bar (entry detail)
}
```


## Components

### Floating Action Button (FAB)
- Circular, `DaylioLayout.fabSize` (56pt), primary green fill, white `+` SF Symbol.
- Positioned bottom-right, above tab bar, with standard safe area inset.
- Always visible on main tab screens.

### Entry Card
- White rounded card (`cornerRadius: 16`), shadow-free (flat on grouped background).
- Contains: mood face avatar (left), mood name (bold, mood color), timestamp (secondary), tag row (icons + text, secondary), overflow `...` button (top-right).
- Cards are grouped under a date section header; no border between card and section header.
- Multiple entries on the same day share one card with a vertical connector line between mood avatars.

### Date Section Header
- Uppercased `.subheadline`, secondary color.
- Small filled circle indicator (primary green) to the left of the date label.
- No background — sits directly above the card group.

### Tag Row
- Inline: small monoline SF Symbol icon + tag name, separated by `•` bullet.
- No pill/chip backgrounds — tags are plain text with icons.
- Text style: `.caption`, secondary color.

### Activity Grid Chip
- Circle background, `DaylioLayout.chipSize` (52pt diameter).
- Default state: light gray circle + tinted green monoline icon.
- Selected state: filled primary green circle + white icon.
- Label below: `.caption`, centered, 2-line max, secondary color.
- Grid: 5 columns, uniform spacing. Use `LazyVGrid` with fixed columns.

### Activity Section Card
- White rounded card wrapping a collapsible grid.
- Header row: bold section name + green dot indicator (left), `+` button (right), expand/collapse chevron (right).
- Section collapses/expands with animation; chevron rotates.

### List Row (Settings/More screen)
- Standard `List` row: rounded-square icon (30pt, colored background + white symbol) + label + disclosure chevron.
- Rows grouped into sections with rounded card style (`.insetGrouped` list style).
- Accessory value (e.g., "22:00" for Reminders) shown in secondary color before chevron.

### Mood Face Avatar
- Circular, emoji-style face illustration — not SF Symbols.
- Color matches mood tier (rad → good → meh → bad → awful).
- Used at multiple sizes: small (36pt) in entry rows, large (52pt) in nav bar back button area.

### Calendar Day Circle
- Empty days: light gray circle.
- Days with entries: colored circle matching the dominant mood of that day.
- Today: outlined circle with accent, or visually distinct from past days.

### Mood Count Chart
- Semi-circle (donut/gauge) chart showing mood distribution.
- Each segment colored with the mood's accent color.
- Mood face avatars with count badges arranged below the chart.
- Badge: small circle (primary green) with white count number, overlaid top-right of avatar.

### Save Button
- Green pill button, top-right of navigation bar.
- Contains checkmark SF Symbol + "Save" label.
- Use `.borderedProminent` button style with primary green tint.

### "Scroll Down to Save" Tooltip
- Dark rounded pill overlay anchored near bottom of screen.
- White text + pointing hand emoji.
- Dismisses after delay or on scroll.


## Navigation Patterns

- Standard `NavigationStack` with inline title style.
- Entry detail: back button replaced with mood face avatar (tappable to change mood).
- Save action always in trailing nav bar position as a green pill button.
- Search available via magnifying glass icon in trailing nav bar.
- Calendar navigation: leading back chevron + month/year title + trailing forward chevron + search.


## Tab Bar

- 4 tabs: Entries, Stats, Calendar, More.
- Active tab tinted primary green; inactive tabs use default secondary gray.
- FAB (`+`) floats above tab bar, not inside it.
- Tab labels: `.caption` size.


## Interaction & Motion

- Activity chip selection: immediate color fill toggle (no delay), no spring overshoot.
- Section expand/collapse: smooth height animation, chevron rotation ~0.2s ease.
- Tooltip nudge ("Scroll Down to Save"): fades in after ~1s idle, fades out after ~3s or on scroll.
- Entry overflow menu (`...`): standard iOS context menu / action sheet.
- Mood selection (entry creation flow): face avatars in a horizontal scroll or grid; tapping one sets the mood color throughout the flow immediately.


## Accessibility

- All mood faces need `.accessibilityLabel` with the mood name (e.g., "rad", "bad") — the face illustration carries no inherent meaning to VoiceOver.
- Activity chips: label = activity name, value = "selected" or empty.
- FAB: `.accessibilityLabel("New entry")`.
- Minimum tap target 44×44pt — chip size (52pt) already satisfies this; ensure label area is included in the tap target.
- Mood-colored text (entry mood names) must not rely on color alone to convey meaning; the word itself ("good", "bad") carries the semantic meaning.
- Use `.accessibilityAddTraits(.isButton)` on custom tappable views that aren't `Button`.
