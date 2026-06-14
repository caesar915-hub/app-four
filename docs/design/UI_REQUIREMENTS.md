# WhisperNotesApp UI/UX Requirements

This document outlines the visual, layout, and UX requirements for rebuilding the WhisperNotesApp frontend from scratch. It defines the central design system tokens and breaks down the core screens.

## 1. Design System & Tokens

The app follows a strict, tokenized design system to ensure absolute consistency and automatic support for iOS accessibility features like Dynamic Type and Dark Mode. **Do not use hardcoded sizes, raw hex colors, or arbitrary padding numbers.**

### 1.1 Colors (`Theme`)
Colors wrap `UIColor` dynamic system colors so they automatically flip for Dark Mode.
- **Backgrounds**:
  - `Theme.background`: Base app background (`.systemBackground` - pure white/black).
  - `Theme.cardBackground`: Container/Card background (`.secondarySystemBackground` - light gray/dark gray).
  - `Theme.elevatedBackground`: Overlapping cards (`.tertiarySystemBackground`).
- **Text**:
  - `Theme.textPrimary`: Primary body/titles (`Color.primary`).
  - `Theme.textSecondary`: Subtitles/metadata (`Color.secondary`).
- **Accent & Status**:
  - `Theme.accent`: Primary brand action color.
  - `statusDone`: Success/Completion (`Color.green`).
  - `statusInProgress`: Active states (`Color.orange`).
- **Separators & Borders**:
  - `Theme.separator`: Standard dividers (`.separator`).
  - `Theme.cardStroke`: Used strictly at a max `0.15` opacity for subtle card outlines.

### 1.2 Typography (`Typography`)
Typography maps strictly to SwiftUI's Dynamic Type roles. No arbitrary `.system(size: X)` usage.
- `largeTitle`: Screen heroes (`.largeTitle`).
- `title`: Primary section titles (`.title2`).
- `headline`: List row/card prominence (`.headline`).
- `subheadline`: Group headers (`.subheadline`).
- `body`: Primary copy (`.body`).
- `callout`: Supporting text (`.callout`).
- `caption`: Metadata and timestamps (`.caption`).
- `label`: Uppercase section labels (`.caption.weight(.medium)`).
- **Monospaced Variants**: Timers and durations use `.monospacedDigit()` modifiers on top of existing fonts to prevent layout jitter while scaling perfectly.

### 1.3 Spacing (`Spacing`)
A strict 4pt/8pt spacing scale.
- `xs (4pt)`: Tight gaps (icon + text).
- `s (8pt)`: Component internal gaps.
- `m (12pt)`: Compact section internals.
- `l (16pt)`: Standard outer screen margin, primary card padding.
- `xl (20pt)`: Wide margins.
- `xxl (24pt)`: Spacing between distinct screen sections.
- `section (32pt)`: Generous page section breathing room.
- `hero (40pt)`: Large visual gaps (e.g., above bottom safe areas).

### 1.4 Corner Radii (`Radius`)
- `Radius.card (12pt)`: Primary container shapes, text editors.
- `Radius.control (10pt)`: Interactive elements (chips, small buttons).
- *Note:* Main floating action buttons are perfectly circular (`Circle()`).

---

## 2. Core Navigation

The app is built around a standard bottom `TabView`. It uses four tabs, tinted with `Theme.accent`:
1. **Calendar** (`calendar` symbol)
2. **Check in** (`checkmark.circle` symbol)
3. **Insights** (`chart.bar.fill` symbol)
4. **Settings** (`gear` symbol)

---

## 3. Screen Specifications

### 3.1 Onboarding (`OnboardingView`)
A paginated, swipeable setup flow (`.tabViewStyle(.page)`).
- **Global Layout**: Centered content with large top-aligned imagery, bottom-anchored buttons.
- **Welcome Step**: Large SF symbol icon, header, description text, and a full-width `.borderedProminent` action button.
- **Permissions Step**: Contextual explanation for microphone access. Has a primary "Grant" button and a secondary "Skip for now" `.plain` button.
- **Download Step**: Shows live downloading of AI models. Features rows for each model with progress bars, precise percentage readouts, and success/failure indicators. Entry to the app is strictly gated until critical models finish downloading.

### 3.2 Check-in Screen (`CheckInView`)
A non-scrollable hub focused on immediacy, built around a How-We-Feel-style rotating crescent (`CrescentRing`). Serif headline ("How are you, right now?").
- **Top Bar**: Shows the global "Medication Bar" indicating today's context (separate from the in-hub "Log meds" action).
- **Hub (idle)**: The crescent rotates slowly with three options stacked in its center — **Log meds** (opens `MedicationLogSheet`, logs a standalone manual dose), **Speak check-in** (accent-filled primary, starts recording immediately), **Type note** (opens `TextCheckInComposer`).
- **Recording**: The crescent spins faster (`isActive`) as the live indicator. Three rotating "nudges" (Mood/Energy/Focus, then Sleep/Feelings/Side-effects) appear above a timer, a compact wave, and a red stop square. Tapping stop ends the check-in (no review step).
- **Saved**: A confirmation with a checkmark and chips for the picked-up mood/energy/focus/meds/sleep (extracted in the background; editable later on the entry).
- **Text composer (`TextCheckInComposer`)**: Mood/Energy/Focus 5-step scales, Meds and Sleep chips, then an optional free-text Note last, then Save. User-picked values are authoritative; the note's NLP only fills gaps.

### 3.3 Calendar/Library Screen (`CalendarLibraryView`)
Chronological timeline of user entries.
- **Layout**: A `LazyVStack` with pinned section headers.
- **Month Selector**: A horizontally scrollable pill-bar pinned at the top. Background must be an adaptive `.bar` material so lists scroll underneath it smoothly.
- **Day Headers**: Simple rows containing a tiny (8x8) mood-colored circle and uppercase `Typography.label` text.
- **Content Rows**: Tapable cards showing metadata and preview summaries.
- **Empty State**: Uses standard `ContentUnavailableView` styling (symbol + title + message).

### 3.4 Recording Detail Screen (`RecordingDetailView`)
A scrollable, expanded view of a processed note.
- **Medication Bar**: Pinned to the top safe area (`.safeAreaInset`).
- **Spacing Paradigm**: Uses heavy `Spacing.xxl (24pt)` spacing between the distinct vertical card blocks.
- **Header Card**:
  - Large (44x44) mood color circle.
  - Title and edit (pencil) icon.
  - Timestamps and duration formatted with monospaced digits.
- **AI Summary Card**: Renders structured lists of extracted data (e.g., ADHD symptoms, focus levels). Contains a "Regenerate" button.
- **Transcript Card**:
  - Accordion style: Tappable header that expands/collapses the full text. Uses a rotating chevron animation.
  - Text is spaced generously (`lineSpacing: 4`) using `Typography.body`.
- **Status Indicator**: Colored pills (`statusLabel`) indicating processing flow (e.g., "Transcribing" in blue, "Completed" in green).
- **Destructive Action**: A bottom-anchored, red text "Delete Recording" button inside a card.

## 4. Universal Component Behaviors

- **Cards**: Most content is wrapped in a standard modifier (`.card()`) which applies `Theme.cardBackground`, an optional subtle stroke, and an inner padding (usually `Spacing.l` or `Spacing.xxl`).
- **Animations**: Almost all state transitions (Record toggles, accordion expansions, segmentation shifts) are driven by standard `.easeInOut(duration: 0.2)` animation blocks.
- **Accessibility**: Standard elements require clear `.accessibilityLabel` strings. Headers use `.accessibilityAddTraits(.isHeader)` for screen reader discoverability.
