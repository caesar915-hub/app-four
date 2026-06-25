# Interface Contract — DayCard (folded/open), Check-in Row, Calendar Cell

Spec: `specs/014-daily-card/spec.md`. This contract covers the **view layer** for the daily-card redesign: `DayCard` (folded summary ↔ expanded timeline), its extracted `FoldedDayCardHeader` summary, the check-in row + medication-phase ring, and the calendar-cell changes (today-ring removal, above-selection de-emphasis). The view-model / interaction surface is in `timeline-interaction.md`.

Ground truth files inspected: [DayCard.swift](app-four/Views/Components/DayCard.swift), [TimelineRow.swift](app-four/Views/Components/TimelineRow.swift), [TimelineBead.swift](app-four/Views/Components/TimelineBead.swift), [CalendarDayCell.swift](app-four/Views/Components/CalendarDayCell.swift), [Motion.swift](app-four/DesignSystem/Motion.swift), [DayTimeline.swift](app-four/ViewModels/DayTimeline.swift), [GlyphSignal.swift](app-four/DesignSystem/GlyphSignal.swift).

---

## 1. `DayCard`

Folding wrapper around a single `TimelineDay`. Constant header (mood circle + weekday + summary line) is always visible; the check-in rows are revealed/hidden by per-card state. Replaces today's always-expanded card ([DayCard.swift#L15-L48](app-four/Views/Components/DayCard.swift#L15)).

### Inputs
```swift
struct DayCard: View {
    let day: MoodLibraryViewModel.TimelineDay   // unchanged; .date is the stable LazyVStack id
    let isExpanded: Bool                         // owned by parent (CalendarLibraryView.expandedCardDates.contains(day.date))
    let onToggleExpand: () -> Void               // parent flips the day's membership in the Set, wrapped in withAnimation
    let onTapRecording: (UUID) -> Void           // unchanged; row → recording detail
}
```

**State in:** `isExpanded` is a *derived input*, not local `@State`. The open-set lives in the parent (`CalendarLibraryView`) so date-selection can collapse all cards (FR-009). DayCard does **not** own a private `isExpanded` — that would prevent the parent's "collapse others" command. (Two decisions in the input JSON conflict — "`@State private var isExpanded` in DayCard" vs. "parent `Set<Date>` + binding". The parent-owned Set is the only design that satisfies FR-009's "selecting a date collapses all open cards"; a child-private bool cannot be reset by the parent. This contract resolves to **parent-owned state, value `isExpanded` passed down**.)

**State out:** `onToggleExpand()` — fired on header tap only. The parent mutates `expandedCardDates` inside `withAnimation(reduceMotion ? nil : Motion.smooth)`.

**Reads from environment:** `@Environment(\.colorScheme)` (existing, for header tint), `@Environment(\.accessibilityReduceMotion)` (new — used to gate the reveal animation if DayCard ever animates locally; primary gate is parent-side).

### Behavior by FR

| FR | Behavior | Test-first logic unit? |
|----|----------|------------------------|
| FR-001 | Folded card renders a one-line summary (delegated to `FoldedDayCardHeader`). | Summary text → unit-testable (see §2). |
| FR-002 | Unlogged signals omitted entirely from the summary — no `0`, no blank, no `–` placeholder. | Yes — `FoldedDayCardHeaderTests`. |
| FR-005 | Header tap toggles **this** card independently; multiple cards may be open. Tap fires `onToggleExpand()`; expansion of other cards is unaffected. | Interaction → `DayCardExpandStateTests` (Set membership toggle). |
| FR-004 | Empty day (`day.nodes.isEmpty`): header + summary line read **"No check-ins this day. That's alright."** Replaces current `"No check-ins"` ([DayCard.swift#L25](app-four/Views/Components/DayCard.swift#L25)). Neutral color (`Theme.textSecondary`), never red, no "missed"/"overdue"/streak. Expanding an empty day reveals nothing (chevron is visual only, idempotent). | Copy string → testable in `FoldedDayCardHeaderTests`. |
| FR-006 | When `isExpanded == true`: header stays, check-in rows appear below via `ForEach(day.nodes)` of `TimelineRow` (existing loop, [DayCard.swift#L29-L35](app-four/Views/Components/DayCard.swift#L29)). | View — build/sim only. |
| FR-016 | Component order never reshuffles: outer `ForEach(viewModel.…) { day in }.id(day.date)` and inner `ForEach(day.nodes, id: \.id)` are unchanged. Expanding grows the card downward in place; LazyVStack identity is the immutable `day.date`. | N/A. |
| FR-018 | All visual values from design tokens. Card corner radius MUST move from the hardcoded `cornerRadius: 20` ([DayCard.swift#L13](app-four/Views/Components/DayCard.swift#L13)) to `Radius.card` (16pt). Padding `Spacing.l`, gaps `Spacing.m`/`Spacing.s`, mood wash `Opacity.moodWash` (0.16, replacing literal `0.16` at [DayCard.swift#L44](app-four/Views/Components/DayCard.swift#L44)). | N/A. |
| FR-015 | Dynamic Type: the weekday label MUST drop the fixed `.system(size: 14, weight: .heavy)` ([DayCard.swift#L18](app-four/Views/Components/DayCard.swift#L18), which the file itself comments "no Dynamic Type scaling") and use a `relativeTo:`-based `Typography` token. Mood word in the summary uses `Typography.fraunces(18)` (existing helper). | N/A. |

### Animation contract (FR-005, FR Reduce-Motion clarification, spec line 29)
- Reveal/hide of rows uses `Motion.smooth` (0.4s, [Motion.swift#L10](app-four/DesignSystem/Motion.swift#L10)). The 0.26s/0.3s in the HTML mockups is intentionally **not** ported to a new token (Constitution Principle IV); 0.4s is the single fold token.
- Reduce Motion: the toggle that drives expansion is wrapped `withAnimation(reduceMotion ? nil : Motion.smooth)`. When Reduce Motion is on, the state change is instant — mirrors the established scroll pattern at [CalendarLibraryView.swift#L143](app-four/Views/Library/CalendarLibraryView.swift#L143).
- Chevron: SF Symbol `chevron.down` rotated `.rotationEffect(.degrees(isExpanded ? 180 : 0))` inside the same animation gate. No `Motion.chevron` token.

### Accessibility contract
- **VoiceOver, folded (FR-017):** the header (mood circle + weekday + summary) is one element — `.accessibilityElement(children: .combine)`. Label synthesized from logged signals, e.g. `"Tuesday, 10 Jun: Great mood, Alert energy, Locked In focus, Escitalopram"`. The mood-glyph circle is `.accessibilityHidden(true)` (mood is already spoken).
- **VoiceOver, expanded (FR-017):** rows are exposed individually — each `TimelineRow` keeps its own `.accessibilityElement(children: .combine)` ([TimelineRow.swift#L18](app-four/Views/Components/TimelineRow.swift#L18)). Signal labels reuse `signalAccessibilityLabel(_:level:)` ([GlyphSignal.swift#L72](app-four/DesignSystem/GlyphSignal.swift#L72)) — **no new label generator** (Principle IV).
- **Hit target (WCAG 2.5.5):** the header row (the toggle affordance) MUST have `.frame(minHeight: 44)` + `.contentShape(Rectangle())` so the whole header strip is tappable. Current card has no height floor on the header.
- **Reduce Motion:** as above; honored on every fold/unfold.
- **Dynamic Type:** every text token scales (`relativeTo:`); see FR-015.

---

## 2. `FoldedDayCardHeader` (new component)

Extracted so the constant top (circle + weekday + summary) is reusable and the most-recent-med derivation lives in one place. Always visible regardless of `isExpanded`.

### Inputs
```swift
struct FoldedDayCardHeader: View {
    let day: MoodLibraryViewModel.TimelineDay
    let isExpanded: Bool          // drives chevron rotation only
}
```
No callbacks; the tap gesture lives on `DayCard`'s header container so the whole strip (including this view) is one hit target.

### Derived presentation (pure, testable)
```swift
// Most-recent check-in's medication NAME only (no dose, no time). FR-003.
var mostRecentMedicationName: String? {
    day.nodes.first { !$0.intakeDoses.isEmpty }?.intakeDoses.first?.name
}
// nodes are newest-first by construction (DayTimelineBuilder sorts $0.time > $1.time,
//   DayTimeline.swift#L66; TimelineDay list is newest-first, MoodLibraryViewModel#L99).
```

### Behavior by FR

| FR | Behavior | Test-first? |
|----|----------|-------------|
| FR-001 | Summary line: `mood · energy · focus · medication-name`, `·`-joined, only the present pieces. | Yes |
| FR-002 | Omit any unlogged field — never render zeros/blanks/placeholders. Mirrors the existing chip rule (`!taken.isEmpty || !inputs.isEmpty`) at [TimelineRow.swift#L73](app-four/Views/Components/TimelineRow.swift#L73). | Yes |
| FR-003 | On a multi-medication day, exactly one name appears — the most-recent check-in's (see `mostRecentMedicationName`). | **Yes — "multi-med day shows newest med only".** |
| FR-004 | Empty day: summary text is exactly `"No check-ins this day. That's alright."` | **Yes — exact copy.** |
| FR-014 | Signals encoded by shape + hue + fill (reuse `SignalGlyph` from spec 006); the summary's energy/focus use glyphs, not color alone. | View. |
| FR-018 | Mood word `Typography.fraunces(18)`; summary body a `relativeTo:` token; med name reuses chip/`Palette.medication` styling. No literals. | N/A |

---

## 3. Check-in row + medication-phase ring (`TimelineRow` / `MedicationPhaseRing`)

The expanded card shows one row per `DayTimeline.Node`. The row layout (HStack: left column + content) is unchanged ([TimelineRow.swift#L12-L19](app-four/Views/Components/TimelineRow.swift#L12)).

### Medication-phase ring (FR-006, FR-020)
The ring + percentage already exist in `TimelineBead` ([TimelineBead.swift#L52-L96](app-four/Views/Components/TimelineBead.swift#L52)): a `Palette.medication` arc trimmed to `ring.progress` plus a `"\(Int(progress*100))%"` badge. The contract requirements:
- **Source of the percentage:** read-only from `DayTimeline.Ring.progress`, already computed at build time via `dose.effectProgress(at:)` ([DayTimeline.swift#L83](app-four/ViewModels/DayTimeline.swift#L83)). **Never recompute** in the view (Principle IV; avoids drift from the med bar).
- **FR-020 redundant readout:** the numeric `%` text is the non-color cue; arc length + `%` together survive greyscale. No pattern fill.
- **No-medication node (spec edge case, line 107):** time-circle still renders; ring/percentage omitted (already handled — `carryoverRing` is `nil` ⇒ no arc/badge, [TimelineBead.swift#L78-L81](app-four/Views/Components/TimelineBead.swift#L78)).
- If an expanded-only ring component (`MedicationPhaseRing(ring:time:decorative:)`) is introduced, it MUST be initialized from `DayTimeline.Ring` and `Date` only, render arc + centered mono time + `%` beneath, and reuse `ringArc`/badge styling. This is optional — reusing `TimelineBead` satisfies the spec.

### FR-015 (Dynamic Type) for rows
- Replace fixed sizes (`TimelineBead` time `.system(size:14)`, badge `.system(size:10)`) with `relativeTo:` tokens where they carry text. Mono digits keep `.monospacedDigit()`.

---

## 4. `CalendarDayCell` changes

File: [CalendarDayCell.swift](app-four/Views/Components/CalendarDayCell.swift). Two changes; both are pure view logic.

### 4a. Remove today ring (FR-013)
- Delete the `else if cell.isToday { Circle().strokeBorder(...) }` branch ([CalendarDayCell.swift#L27-L29](app-four/Views/Components/CalendarDayCell.swift#L27)). Today is marked **only** by the "Today" pill in the header (`CalendarHeaderView`).
- The selection fill (`isSelected → Circle().fill(Color.primary)`, [L25-L26](app-four/Views/Components/CalendarDayCell.swift#L25)) stays.
- The bold-on-today rule at [L18](app-four/Views/Components/CalendarDayCell.swift#L18) (`isSelected || cell.isToday ? .bold`) should drop `cell.isToday` so today carries no special weight either (ring removal must not leak into weight).

### 4b. De-emphasize days more recent than selection (FR-011, FR-014)
Applies to cells where `cell.date > selectedDay` and `cell.date <= today`. Requires a new input so the cell knows the selection:
```swift
let isAboveSelection: Bool   // cell.date > selectedDay && not future
```
Two redundant, non-color cues (opacity alone fails greyscale, per FR-011):
1. **Opacity** `Opacity.deEmphasis` (0.34) on the number + marker.
2. **Second cue:** reduce the day-number font weight to `.regular` **and** suppress the mood marker dot (render `Color.clear` in place of the `.mood`/`.neutral` marker at [L50-L56](app-four/Views/Components/CalendarDayCell.swift#L50)). The dropped dot is the form-based, greyscale-safe cue.

| FR | Behavior | Test-first? |
|----|----------|-------------|
| FR-011 | Above-selection days greyed (opacity) **plus** a second non-color cue (weight + dropped marker). | De-emphasis predicate (`isAboveSelection`) is computed in the parent — testable there. |
| FR-013 | No ring around today; pill only. | View. |
| FR-014 | Marker/weight cues remain distinguishable without color. | View. |

**Note:** these cells stay **visible and de-emphasized** in the week row (FR-011), whereas the *list* removes more-recent days entirely (FR-010, see `timeline-interaction.md`). Two different surfaces, two different rules — do not conflate.

