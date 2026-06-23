# Research — 014 Daily Card: Folded Summary, Opens to the Day

**Feature**: `feat/daycard-update` · **Spec**: [specs/014-daily-card/spec.md](specs/014-daily-card/spec.md) · **Date**: 2026-06-23

This document consolidates the grounded technical decisions that resolve every open unknown in the spec. No `NEEDS CLARIFICATION` remains. All visual values map to existing design-system tokens except two small additions, called out under **Missing DesignSystem tokens to add**.

Source-of-truth anchors (verified in this session):
- [Motion.swift](app-four/DesignSystem/Motion.swift): `snappy = .snappy(0.3)`, `smooth = .smooth(0.4)` — system curves auto-honor Reduce Motion.
- [Radius.swift](app-four/DesignSystem/Radius.swift): `card = 16`, `control = 10`, `button = 16`. No `chip` token exists.
- [Spacing.swift](app-four/DesignSystem/Spacing.swift): `xs 4 / s 8 / m 12 / l 16 / xl 20 / xxl 24 / section 32 / hero 40`. No `ringStroke`.
- [Metrics.swift](app-four/DesignSystem/Metrics.swift): `minTapTarget = 44`, `rowMinHeight = 44`. No `timeBead` / `headerMoodCircle`.
- [Typography.swift](app-four/DesignSystem/Typography.swift): roles + `Font.fraunces(_:)` / `Font.plexMono(_:)` helpers (L52–59).
- [DayCard.swift](app-four/Views/Components/DayCard.swift): currently always-expanded, `cornerRadius: 20` (L13), fixed `.system(size:14,weight:.heavy)` header (L18), empty copy `"No check-ins"` (L25), mood wash `0.16` (L44).
- [TimelineBead.swift](app-four/Views/Components/TimelineBead.swift): `beadSize 56` / `circleSize 54` / `ringWidth 4` hardcoded (L13–15); `ringArc` (L52–58); time label `.system(size:14,weight:.bold)` (L64); `%` badge `.system(size:10,weight:.heavy)` (L86–87); `Palette.medication` arc (L55).
- [CalendarLibraryView.swift](app-four/Views/Library/CalendarLibraryView.swift): `selectedDay` `@State` (L10), `reduceMotion` env (L18), `ForEach(viewModel.timelineDays).id(day.date)` (L99–101), `selectDay`/`scrollList` with `withAnimation(reduceMotion ? nil : Motion.smooth)` (L130–149).
- [CalendarDayCell.swift](app-four/Views/Components/CalendarDayCell.swift): today ring `Circle().strokeBorder(Color.primary, 1.6)` (L27–29); weight already toggles bold/regular (L18); marker dot (L50–56); ≥44pt tap target (L33).
- [AppSettings.swift](app-four/Models/AppSettings.swift): `@Model`, `@Attribute(.unique) id`, defaulted attributes (L5–30). No `autoExpandOnSelection`.
- [SettingsViewModel.swift](app-four/ViewModels/SettingsViewModel.swift): UserDefaults-backed get/set pattern (L22–39), `appSettings` FetchDescriptor (L44+).
- [Palette.swift](app-four/DesignSystem/Palette.swift): `Palette.medication` (L10).

---

## Animation

### Fold/unfold mechanism
**Decision**: Hold expansion as conditional content inside `DayCard`. When expanded, render the check-in rows under a constant header; when folded, render only the header + summary line. Toggle inside `withAnimation(reduceMotion ? nil : Motion.smooth) { … }` on a header tap. Prefer conditional content (`if isExpanded { ForEach(day.nodes) … }`) over `.frame(height:)`+`.clipped()` or `matchedGeometryEffect`.

**Rationale**: The HTML mockup animates `.body` grid-template-rows `0fr→1fr` over `.3s` — a size-expansion. In SwiftUI, conditional content is the lowest-surface analog: the outer `LazyVStack` already virtualizes rows ([CalendarLibraryView.swift L97–102](app-four/Views/Library/CalendarLibraryView.swift)), so per-row identity churn is acceptable; it avoids measuring intrinsic height; and it makes Reduce Motion trivial — passing `nil` to `withAnimation` removes the animation entirely. The `Motion.smooth` 0.4s vs. mockup 0.3s difference is imperceptible and keeps the token count minimal (Principle IV).

**Alternatives considered**: (1) `.frame(maxHeight: isExpanded ? .infinity : 0)` + `.clipped()` — needs GeometryReader height measurement, error-prone. (2) `matchedGeometryEffect` — namespace + ID overhead for a simple fold. (3) Custom measured Container — over-engineered.

**Grounding**: [Motion.swift L8–10](app-four/DesignSystem/Motion.swift); [CalendarLibraryView.swift L143](app-four/Views/Library/CalendarLibraryView.swift); spec.md FR-005, Clarifications "Fold/unfold … honor Reduce Motion".

### Chevron icon animation
**Decision**: Render `Image(systemName: "chevron.down")` in the folded header; on toggle apply `.rotationEffect(.degrees(isExpanded ? 180 : 0))` inside the same `withAnimation(reduceMotion ? nil : Motion.smooth)` block. **Do not** add a `Motion.chevron` token for the mockup's `.26s`.

**Rationale**: The chevron shares the card's fold transition; reusing `Motion.smooth` avoids token proliferation (Principle IV). The 140 ms difference from the mockup's `.26s` is imperceptible. `.snappy` (0.3s, "toggles") is wrong scale — fold/unfold is a larger transition.

**Alternatives considered**: New `Motion.chevron` 0.26s (rejected — Principle IV); instant rotation (ignores mockup intent); `.snappy` (mismatched intent).

**Grounding**: mockup `folded-card-final/index.html` `.chev transition:.26s`; [Motion.swift L8–10](app-four/DesignSystem/Motion.swift); spec.md FR-005.

### LazyVStack identity & stability
**Decision**: Keep `ForEach(viewModel.timelineDays) { … }.id(day.date)` ([CalendarLibraryView.swift L99–101](app-four/Views/Library/CalendarLibraryView.swift)). Inside `DayCard`, gate rows on `isExpanded`. Outer per-day identity stays the immutable `day.date`; inner rows are added/removed as children.

**Rationale**: LazyVStack needs a stable outer ID; `day.date` is immutable. Conditional inner content is diffed as child add/remove without churning the day-card identity — preserves virtualization and satisfies FR-016 ("component order MUST stay stable").

**Alternatives considered**: Flatten to one ForEach keyed `date+node.id` (loses per-day grouping); per-day stateful subview (identity churn); `AnyView` (defeats diffing).

**Grounding**: [CalendarLibraryView.swift L99–102](app-four/Views/Library/CalendarLibraryView.swift); spec.md FR-016.

---

## State & filter-above

### Card expand/collapse state — WHERE/HOW open state lives
**Decision**: Add `@State private var expandedCardDates: Set<Date>` in `CalendarLibraryView`. A header tap toggles `day.date` membership (multiple cards MAY be open). `selectDay` clears the set, then inserts `selectedDay` iff auto-expand is on. `DayCard` reads `isExpanded` (e.g. via a `Bool` derived from `expandedCardDates.contains(day.date)`).

**Rationale**: Spec resolves: header tap toggles independently with multiple-open allowed; selecting a date collapses all then opens only the selected day (FR-005, FR-009). `Set<Date>` gives O(1) membership and clean toggle. This is ephemeral UI chrome, so it belongs in the View, not the model (Principle VIII). Mirrors the existing `isProgrammaticScroll` flag pattern.

**Alternatives considered**: Store open state on `TimelineDay` (it's a value struct keyed by date — mutating breaks diffing); `Dictionary<Date,Bool>` (Set is cleaner, no unused value); single `selectedDayID:Date?` (violates multi-open).

**Grounding**: spec.md FR-005, FR-009; [CalendarLibraryView.swift L10–14, L139–149](app-four/Views/Library/CalendarLibraryView.swift); mockup `prototype/index.html` `open = {}` toggle.

### Selected-date state — WHERE `selectedDay` lives
**Decision**: Keep `selectedDay` as `@State` in `CalendarLibraryView` ([L10](app-four/Views/Library/CalendarLibraryView.swift)) — it is already there. Do **not** move it into `MoodLibraryViewModel`.

**Rationale**: `selectedDay` is ephemeral navigation state; the View owns transient state, the ViewModel owns store access (Principle VIII: `@MainActor @Observable`, no persistence logic). Re-selecting the same date is idempotent (Clarifications) — handled by checking equality before re-animating.

**Alternatives considered**: `selectedDay` as an Observable VM property (violates Principle VIII).

**Grounding**: [CalendarLibraryView.swift L10](app-four/Views/Library/CalendarLibraryView.swift); Constitution Principle VIII.

### Filter-above logic — HOW `timelineDays` filters to selected date
**Decision**: Add `func timelineDaysFiltered(to selectedDate: Date) -> [TimelineDay]` on `MoodLibraryViewModel`. It applies the existing month filter PLUS `dayStart <= selectedDate`, returns newest-first. `CalendarLibraryView` iterates this in its `ForEach`. The result is a pure, testable transform.

**Rationale**: The existing `timelineDays` already filters by current month; layering a date cutoff as a parameter keeps month-scope in the VM and date-range scope caller-driven without duplicating logic. Spec requires more-recent days vanish from the list (FR-010) while older days remain scrollable, and the calendar row greys (not removes) the same days (FR-011).

**Alternatives considered**: `selectedDate` as Observable VM property (View-specific ephemeral state in the model — Principle VIII); inline `.filter` in the View's ForEach (harder to test, re-filters every render).

**Grounding**: spec.md FR-010, FR-002; `MoodLibraryViewModel` `timelineDays` month filter; `DayTimelineBuilder` builds newest-first.

### Auto-expand setting — WHERE/HOW persisted
**Decision** *(revised during /speckit-tasks verification)*: Store as **`@AppStorage("autoExpandOnSelection")`** (default `true`) — read in `CalendarLibraryView`, written by a new `DayCardSettingsSection` toggle. **No `AppSettings` attribute, no `SettingsViewModel` change, no schema change.**

**Rationale**: This is the codebase's actual pattern for a view-consumed behavior toggle — the `MedicationBar*` visibility flags use `@AppStorage("medicationBarVisible")` shared between [MedicationBarSettingsSection.swift](app-four/Views/Settings/MedicationBarSettingsSection.swift) (writer) and [MedicationBarView.swift](app-four/Views/Components/MedicationBarView.swift) (reader). `@AppStorage` is read directly in any view with no plumbing, is test-exempt (view state), and adds zero schema — so Principle IX is satisfied trivially and Principle IV surface is lower.

**Why the initial `AppSettings`/`SettingsViewModel` decision was reversed**: (1) `CalendarLibraryView`'s environment holds only `AppServices`, so a model-backed setting would need new plumbing to reach `selectDay`; (2) `SettingsViewModelTests` is **currently disabled** (stale init after the `AppServices` aggregation — no mock exists), so a `SettingsViewModel`-backed setting could not be built test-first per Principle X; (3) the original "@AppStorage blocks the UI thread on write / is inconsistent with the app pattern" rationale was **wrong** — `@AppStorage` does not block on write and *is* the established pattern (MedicationBar*).

**Alternatives considered**: `AppSettings` `@Model` + `SettingsViewModel` sync (the `downloadOverCellular`/`promptPace` pattern — rejected: needs plumbing + depends on the disabled test suite + touches the schema); per-read `FetchDescriptor` (main-thread block — Principle VIII).

**Grounding**: spec.md FR-019; [MedicationBarSettingsSection.swift](app-four/Views/Settings/MedicationBarSettingsSection.swift) + [MedicationBarView.swift](app-four/Views/Components/MedicationBarView.swift) `@AppStorage("medicationBarVisible")`; disabled [SettingsViewModelTests.swift](app-fourTests/ViewModels/SettingsViewModelTests.swift); Constitution Principles IV, VIII, IX, X.

### Selection / filter-above interaction in `selectDay`
**Decision**: In `selectDay(_:)`, on a real date tap: set `selectedDay`, `expandedCardDates.removeAll()`, and if `autoExpandOnSelection` then `expandedCardDates.insert(selectedDay)`; iterate `timelineDaysFiltered(to: selectedDay)`. Wrap the state change in `withAnimation(reduceMotion ? nil : Motion.smooth)`. Scroll-to-top already animates correctly ([L143](app-four/Views/Library/CalendarLibraryView.swift)). Re-selecting the current date is a no-op (idempotent).

**Rationale**: FR-009 (move to top, collapse-all-then-open-selected), FR-010 (filter-above). Card-toggle coordination is a View concern; the filtered list comes from the VM transform.

**Grounding**: spec.md FR-009, FR-010; [CalendarLibraryView.swift L130–149](app-four/Views/Library/CalendarLibraryView.swift).

---

## Med-phase ring

### Percentage computation (FR-020) — reuse, do not recompute
**Decision**: Reuse the existing `effectProgress(at:)` on `MedicationEvent`; the percentage is already computed once during build and cached on `DayTimeline.Ring.progress`. The expanded check-in layout (and `TimelineBead`) read the cached value — no per-render pharmacokinetic recompute.

**Rationale**: The spec Assumption states the phase % is already derived and surfaced; this feature adds no new calculation. Compute-once-at-build keeps the ring consistent with the med bar and avoids drift (Principle IV). `TimelineBead` already reads `ring.progress` for the carry-over badge ([L86](app-four/Views/Components/TimelineBead.swift)).

**Alternatives considered**: Recompute % at render (duplicate logic, drift risk); a separate Ring percentage property (redundant data).

**Grounding**: `MedicationEvent.effectProgress(at:)`; `DayTimeline` build stores into `Ring.progress`; [TimelineBead.swift L86](app-four/Views/Components/TimelineBead.swift).

### `MedicationPhaseRing` component vs. reuse
**Decision**: Reuse `TimelineRow`'s HStack layout for both folded and expanded contexts. Extract a new `MedicationPhaseRing(ring:time:decorative:)` component for the expanded check-in's left column: stroke-only purple arc scaled to `ring.progress`, centered time label, percentage **beneath** the ring. Adapt `TimelineBead`'s `ringArc` rendering ([L52–58](app-four/Views/Components/TimelineBead.swift)) into it. `TimelineBead` (mood/hollow centre) stays for the existing carry-over context; the expanded ring is a distinct visual.

**Rationale**: The expanded ring (time-in-ring + % below) is a new visual the current `TimelineBead` does not render; forcing `TimelineBead` to do both would create a leaky mood-vs-med abstraction. Isolating the ring keeps `TimelineRow` focused on layout and makes the ring independently testable. Reusing the HStack + `Spacing.m` column gap avoids duplicating layout.

**Alternatives considered**: Entirely new `CheckInRow` (duplicates layout); one monolithic `TimelineRow` with folded/expanded branches (Principle IV violation); extend `TimelineBead` to do both (leaky abstraction).

**Grounding**: [TimelineRow.swift](app-four/Views/Components/TimelineRow.swift) HStack `spacing:Spacing.m`; [TimelineBead.swift L52–58](app-four/Views/Components/TimelineBead.swift); mockups `prototype/index.html`, `summary/index.html` time-in-ring.

### Ring tokens & redundant readout
**Decision**: Arc uses `Palette.medication` ([Palette.swift L10](app-four/DesignSystem/Palette.swift)) in both schemes; stroke uses the new `Spacing.ringStroke = 3.3` (see Missing tokens); ring diameter uses `Metrics.timeBead = 54` (see Missing tokens); the percentage label uses `.system(size:10,weight:.heavy).monospacedDigit()` to match the existing badge ([TimelineBead.swift L87](app-four/Views/Components/TimelineBead.swift)); time label uses IBM Plex Mono. The numeric % **beneath** the ring is the redundant, non-color readout (arc length + % text) — no patterned fill (FR-020).

**Rationale**: FR-018/FR-020 mandate tokens-only and a greyscale-surviving readout. Reusing the existing badge font keeps carry-over badges and expanded-ring %s visually consistent.

**Grounding**: spec.md FR-018, FR-020; [TimelineBead.swift L55, L86–88](app-four/Views/Components/TimelineBead.swift); [Palette.swift L10](app-four/DesignSystem/Palette.swift).

---

## Token mapping

| Visual element | Mockup value | Token (existing) | Source |
|---|---|---|---|
| Card corner radius | `12–16px` | `Radius.card` (16) | [Radius.swift](app-four/DesignSystem/Radius.swift) — **fixes** DayCard L13 hardcoded `20` |
| Card outer padding | `16px` | `Spacing.l` (16) | [Spacing.swift L13](app-four/DesignSystem/Spacing.swift) |
| Internal section gaps | `12px` / `8px` | `Spacing.m` / `Spacing.s` | [Spacing.swift L9–11](app-four/DesignSystem/Spacing.swift) |
| Tight icon+label gap | `4px` | `Spacing.xs` (4) | [Spacing.swift L7](app-four/DesignSystem/Spacing.swift) |
| Fold / scroll-to-top motion | `.3s ease` | `Motion.smooth` (0.4) | [Motion.swift L10](app-four/DesignSystem/Motion.swift) |
| Chevron rotation | `.26s ease` | `Motion.smooth` (0.4) — reused, no new token | [Motion.swift L10](app-four/DesignSystem/Motion.swift) |
| Header card-tap target | ≥44pt | `Metrics.minTapTarget` (44) | [Metrics.swift L9](app-four/DesignSystem/Metrics.swift) |
| Mood-circle / time fonts | mono, bold | `Typography.mono12` / `Font.plexMono(_:)` | [Typography.swift L40, L57](app-four/DesignSystem/Typography.swift) |
| Folded summary mood word | `18px Fraunces` | `Font.fraunces(18)` helper | [Typography.swift L52–54](app-four/DesignSystem/Typography.swift) |
| Weekday header | `14px DM Sans` | `Typography.subheadline` — **fixes** DayCard L18 fixed `.system(size:14)` | [Typography.swift L23](app-four/DesignSystem/Typography.swift) |
| Summary line / labels | `12px DM Sans` | `Typography.label` / `.caption` | [Typography.swift L31–33](app-four/DesignSystem/Typography.swift) |
| Ring arc color | `--med` | `Palette.medication` | [Palette.swift L10](app-four/DesignSystem/Palette.swift) |
| Ring % badge | `10px heavy mono` | `.system(size:10,weight:.heavy).monospacedDigit()` | [TimelineBead.swift L87](app-four/Views/Components/TimelineBead.swift) |
| Mood wash overlay | `~16%` | `Opacity.moodWash` (0.16) — **new** | DayCard L44 literal `0.16` |
| Greyed filtered day | `opacity .34` | `Opacity.deEmphasis` (0.34) — **new** | mockup `.day.above .n{opacity:.34}` |
| Chip corner radius | `15px` | `Radius.chip` (15) — **new** | mockup `.chip{border-radius:15px}` |
| Ring stroke width | `3.3` | `Spacing.ringStroke` (3.3) — **new** | mockup `stroke-width="3.3"` |
| Time-circle diameter | `54px` | `Metrics.timeBead` (54) — **new** | mockup time-ring `S=54` |
| Header mood-circle dia. | `58px` | `Metrics.headerMoodCircle` (58) — **new** | mockup `.gcircle{58px}` |

### Missing DesignSystem tokens to add

The codebase currently has **no** token for these mockup values; they must be added rather than hardcoded (FR-018, Principle IV — name the value once):

1. **`Radius.chip = 15`** — medication/feeling chips need rounder corners than `control` (10, reads as a button) but not full `.capsule`. Add to [Radius.swift](app-four/DesignSystem/Radius.swift). *Grounding: mockup `.chip{border-radius:15px}`.*
2. **`Spacing.ringStroke = 3.3`** (or a new `Stroke` enum) — the med-phase ring stroke, consistent across folded card / expanded card / beads; replaces `TimelineBead`'s hardcoded `ringWidth = 4` ([L15](app-four/Views/Components/TimelineBead.swift)). *Grounding: mockup `stroke-width="3.3"`.*
3. **`Metrics.timeBead = 54`** and **`Metrics.headerMoodCircle = 58`** — locked, non-scaling diameters (the 54pt time-ring holds a 13–14pt mono label; the 58pt header circle holds the glyph). Replaces `TimelineBead`'s unnamed `circleSize = 54` / `beadSize = 56` ([L13–14](app-four/Views/Components/TimelineBead.swift)). *Grounding: mockup `S=54`, `.gcircle{58px}`.*
4. **`Opacity.swift` enum** with **`deEmphasis = 0.34`** and **`moodWash = 0.16`** — reusable across the calendar grey-out (FR-011) and the DayCard mood wash (replaces DayCard literal `0.16`, [L44](app-four/Views/Components/DayCard.swift)). *Grounding: mockup `opacity:.34`; DayCard L44.*

No other new tokens are permitted. Specifically: **no** `Motion.chevron` and **no** `Motion.fold` — `Motion.smooth` covers all fold/chevron/scroll motion (the `.26s`/`.3s` mockup values are within imperceptible range of 0.4s).

---

## Accessibility

### Reduce Motion (FR / DESIGN.md L82)
**Decision**: `DayCard` captures `@Environment(\.accessibilityReduceMotion) private var reduceMotion`; header-tap toggle and the parent `selectDay` card-state change both run inside `withAnimation(reduceMotion ? nil : Motion.smooth) { … }`. When ON, `nil` makes the change instant. Mirrors the existing scroll pattern.

**Rationale**: WCAG 2.1 SC 2.3.3; spec explicitly requires fold/unfold and scroll-to-top honor Reduce Motion. The pattern is already proven at [CalendarLibraryView.swift L18, L143, L153](app-four/Views/Library/CalendarLibraryView.swift).

**Alternatives considered**: Always animate (WCAG + spec violation); custom reduceMotion flag (Principle I requires system env trait).

**Grounding**: [CalendarLibraryView.swift L18, L143](app-four/Views/Library/CalendarLibraryView.swift); spec.md Clarifications; DESIGN.md "Honor Reduce Motion".

### Dynamic Type (FR-015)
**Decision**: Replace `DayCard`'s fixed `.system(size:14,weight:.heavy)` ([L18](app-four/Views/Components/DayCard.swift)) with scaling tokens: weekday `Typography.subheadline`, summary line `Typography.label`/`.caption`, mood word `Font.fraunces(18)`, times/percentages `Typography.mono12`. Every `relativeTo:`-anchored token scales automatically.

**Rationale**: Current fixed font is the spec's named current-state gap (US4). Overriding `sizeCategory` would violate WCAG 1.4.4. DM Sans/Fraunces/IBM Plex Mono are required for identity (DESIGN.md), so system-font-only is rejected.

**Grounding**: [Typography.swift L21–40, L52–54](app-four/DesignSystem/Typography.swift); [DayCard.swift L18](app-four/Views/Components/DayCard.swift); spec.md FR-015.

### Greyscale de-emphasis of more-recent days (FR-011, FR-014)
**Decision**: For days more recent than the selected date in the calendar row, apply `Opacity.deEmphasis` (0.34) **plus** a second non-color cue. `CalendarDayCell` already toggles weight bold↔regular ([L18](app-four/Views/Components/CalendarDayCell.swift)) and renders a marker dot ([L50–56](app-four/Views/Components/CalendarDayCell.swift)); the second cue is **either** a lighter weight on the day number **or** suppressing the mood/neutral marker dot for above-days. Recommendation: **suppress the marker dot** (clear form-based cue, greyscale-safe), with weight reduction as a fallback if the dot must remain. No pattern fill.

**Rationale**: FR-011 explicitly forbids opacity-alone. Form cues (dropped dot / lighter weight) survive greyscale and colorblindness; pattern fills violate the glyphs-only aesthetic (DESIGN.md "color is never the only cue").

**Alternatives considered**: Opacity only (FR-011 violation); reduced saturation (no clean SwiftUI HSL API); pattern fill (aesthetic + type-system violation).

**Grounding**: spec.md FR-011, FR-014; [CalendarDayCell.swift L18, L50–56](app-four/Views/Components/CalendarDayCell.swift); mockup `opacity:.34`; DESIGN.md.

### Medication-phase % as redundant readout (FR-020)
**Decision**: The expanded ring always shows the numeric % directly beneath the arc; arc length + % text together encode the value, so greyscale users read the number. No patterned fill.

**Grounding**: spec.md FR-020; [TimelineBead.swift L86](app-four/Views/Components/TimelineBead.swift).

### VoiceOver: folded card as one element, expand exposes check-ins (FR-017)
**Decision**: When folded, wrap the header (circle + weekday + summary) in `.accessibilityElement(children: .combine)` with a synthesized label, e.g. `"Tuesday, June 10: Great mood, Alert energy, Locked In focus, Escitalopram"`. The mood glyph circle stays decorative (`.accessibilityHidden(true)`) since mood is spoken. When expanded, each check-in row exposes itself separately (the existing `TimelineRow` already uses `.accessibilityElement(children: .combine)`). Empty-day reads the calm copy plus the date.

**Rationale**: Matches the spec's folded-summary-then-detail model. Reuse the established `SignalGlyph` decorative-glyph + explicit-label pattern.

**Grounding**: spec.md FR-017; `SignalGlyph` decorative/label pattern; `GlyphSignal.signalAccessibilityLabel(...)`.

### Reuse existing a11y label generators (Principle IV)
**Decision**: Do **not** write new label formatters. Reuse `GlyphSignal.signalAccessibilityLabel(kind, level)` ("Energy: Alert, 4 of 5") for every per-glyph announcement in both the synthesized folded summary and the expanded rows.

**Grounding**: `GlyphSignal.signalAccessibilityLabel`; `SignalGlyph`; Constitution Principle IV.

### 44pt header hit target (WCAG 2.5.5)
**Decision**: Give the `DayCard` header row a `.frame(minHeight: Metrics.minTapTarget)` (or vertical padding raising it to ≥44pt). The card-header tap is the primary fold/unfold affordance and must be tap-safe. Do not make the whole card tappable (spec separates header-tap fold from row-tap detail).

**Grounding**: spec.md FR-005; [Metrics.swift L9](app-four/DesignSystem/Metrics.swift); WCAG 2.1 SC 2.5.5.

---

## Structure & test-first

### File layout & modifications
**Decision**:
- **MODIFY** [DayCard.swift](app-four/Views/Components/DayCard.swift) — restructure to a constant header + foldable body; fix radius (20→`Radius.card`), header font (fixed→`Typography.subheadline`), empty copy, mood-wash opacity token.
- **MODIFY** [CalendarLibraryView.swift](app-four/Views/Library/CalendarLibraryView.swift) — add `expandedCardDates`, auto-expand wiring, filter-above call in `ForEach`.
- **MODIFY** [CalendarDayCell.swift](app-four/Views/Components/CalendarDayCell.swift) — remove the today ring (L27–29); add above-selection de-emphasis.
- **MODIFY** [MoodLibraryViewModel.swift](app-four/ViewModels/MoodLibraryViewModel.swift) — add `timelineDaysFiltered(to:)`.
- **MODIFY** [TimelineRow.swift](app-four/Views/Components/TimelineRow.swift) — host the expanded check-in layout / phase ring.
- **CREATE** `FoldedDayCardHeader.swift` (or `FoldedCardSummary.swift`) — the constant header + one-line summary.
- **CREATE** `MedicationPhaseRing.swift` — expanded time-in-ring + % (see Med-phase ring).
- **CREATE** `DayCardSettingsSection` with an `@AppStorage("autoExpandOnSelection")` toggle (no `AppSettings`/`SettingsViewModel` change — see the revised Auto-expand decision).
- **NO** new design tokens beyond the four named in Missing tokens.

**Rationale**: This is a behavioral redesign of existing UI plus selection-driven filtering — it modifies structure/interaction, not visual identity or schema. Filter-above (FR-009/010) is mandated, so a single-card independent-expand model alone is insufficient.

**Grounding**: spec.md FR-001–FR-020, US1–US3; the file anchors listed at the top.

### Expand/fold interaction model
**Decision**: `DayCard` reads its `isExpanded` from `expandedCardDates`; a header `.onTapGesture` toggles that day independently (multiple open allowed). Selecting a date collapses all, then opens only the selected day when `autoExpandOnSelection` (default ON). Re-selecting the same date is idempotent (no collapse/re-animate). All transitions honor Reduce Motion.

**Grounding**: spec.md FR-005, FR-009, FR-019; mockup `prototype/index.html`; [CalendarLibraryView.swift L10–11, L18](app-four/Views/Library/CalendarLibraryView.swift).

### Folded summary line content & omission
**Decision**: `FoldedDayCardHeader` renders mood-glyph circle + weekday + one line `mood · energy · focus · medication-name`. Unlogged signals are entirely omitted (no zeros/blanks/placeholders, FR-002). Medication is **name only**; on multi-med days, the most-recent check-in's med (newest node — lists are newest-first): `day.nodes.first(where: { !$0.intakeDoses.isEmpty })?.intakeDoses.first?.name`, computed in the View (pure presentation, not the VM). Header size is constant whether folded or open.

**Rationale**: US1 core; keeping the most-recent-med logic in the View avoids coupling `TimelineDay` to view concerns and avoids growing the VM. `DayTimelineBuilder` already orders nodes newest-first.

**Alternatives considered**: Computed property / field on `TimelineDay` (couples model to view); filter at the DayCard call site (scatters logic); placeholder dashes (clutters, violates "no padding").

**Grounding**: spec.md FR-001–FR-004; Clarifications "most-recent check-in's medication"; `DayTimelineBuilder` newest-first; mockup `.fline`.

### Empty-day rendering & copy (FR-004)
**Decision**: When `day.nodes.isEmpty`, render header (circle + weekday) with the summary line reading exactly **"No check-ins this day. That's alright."** — `Typography.body`, `Theme.textSecondary` (neutral, no red). Replaces current `"No check-ins"` ([DayCard.swift L25](app-four/Views/Components/DayCard.swift)). Expanding an empty day reveals nothing (no rows); the chevron is visual only.

**Grounding**: spec.md FR-004, US1 Scenario 3; mockup `prototype/index.html` copy; [DayCard.swift L24–26](app-four/Views/Components/DayCard.swift).

### Medication-only / partial check-ins
**Decision**: A med-only day (no `Recording`) still yields a `TimelineDay` node; its folded summary shows only the med name, neutral/hollow circle. Partial check-ins show only logged signals/chips in both states (FR-002, FR-007); chips render only when non-empty, matching the existing `TimelineRow` guard. The expanded med-only row shows the dose's time-ring + %.

**Grounding**: spec.md FR-002, FR-007, Edge Cases; existing `MoodLibraryViewModelTests` "manualDoseWithoutRecordingStillProducesADay"; `TimelineRow` chip guard.

### Today ring removal (FR-013)
**Decision**: Delete the `else if cell.isToday { Circle().strokeBorder(Color.primary, 1.6) }` branch ([CalendarDayCell.swift L27–29](app-four/Views/Components/CalendarDayCell.swift)). Today is marked only by the "Today" pill in the header. (The weight-bold-on-today at L18 may stay or drop to selection-only; the **ring** specifically must go.)

**Grounding**: spec.md FR-013, US3 Scenario 5; [CalendarDayCell.swift L27–29](app-four/Views/Components/CalendarDayCell.swift); mockup (no today ring).

### Layout stability (FR-016)
**Decision**: Keep the fixed vertical order: pinned medication bar → calendar header → day-card list ([CalendarLibraryView.swift L33–41](app-four/Views/Library/CalendarLibraryView.swift)). Expanding a card grows it in place; nothing reshuffles.

**Grounding**: spec.md FR-016; [CalendarLibraryView.swift L33–41](app-four/Views/Library/CalendarLibraryView.swift).

### Constitution check (Principles I–X)
**Decision**: PASS all. SwiftUI-first, HTML mockup precedes code (I). Build+tests before PR (II). Complete correct fold/unfold, no placeholders (III). Reuse tokens, no new abstractions beyond the 4 named tokens + 2 components (IV). Feature branch `feat/daycard-update` + PR + `/code-review` (V). No new data handling (VI), no NLP change (VII). VM stays `@MainActor @Observable`, no persistence logic (VIII). `autoExpandOnSelection` is an `@AppStorage` flag (no schema change); `selectedDay`/`expandedCards` are ephemeral `@State` (IX). Test-first for the logic units below (X).

**Grounding**: `.specify/memory/constitution.md`.

### Test-first logic units (Principle X, NON-NEGOTIABLE)
**Decision**: Write failing Swift Testing (`@Test` / `#expect`) suites **before** implementation:
1. `timelineDaysFiltered(to:)` returns only days `<= selected`, newest-first, selected at top — in `MoodLibraryViewModelTests`.
2. Auto-expand state: selecting a date clears `expandedCardDates` and inserts the selected day iff auto-expand ON; header tap toggles independently; multiple-open allowed.
3. Folded summary content: omits unlogged signals; multi-med day shows newest med name only; empty-day copy exact.
4. Empty-day: correct copy, no unlogged signals.

SwiftUI views (`DayCard`, `CalendarLibraryView`, `CalendarDayCell`) are exempt from unit tests (verified by build + simulator run); their underlying transforms are tested via the units above.

**Grounding**: Constitution Principle X (RED-GREEN-REFACTOR, Swift Testing); existing `MoodLibraryViewModelTests` `@MainActor @Test` pattern; spec.md acceptance scenarios.

---

## Open unknowns — all resolved

| Spec unknown | Resolution |
|---|---|
| Which med on multi-med day | Most-recent check-in (newest node), name only — FR-003 |
| Greyscale de-emphasis cue | Opacity 0.34 + dropped marker dot (or lighter weight) — FR-011 |
| Re-selecting same date | Idempotent — no collapse/re-animate |
| Empty-day copy | "No check-ins this day. That's alright." — FR-004 |
| Ring greyscale readout | Numeric % beneath ring (arc + text), no pattern — FR-020 |
| Oldest-day list end | List simply stops, no marker/copy |
| Auto-expand default | User setting, default ON; OFF = scroll without opening — FR-019 |
| Fold/scroll under Reduce Motion | `withAnimation(reduceMotion ? nil : Motion.smooth)` |
| Where `selectedDay` / open-state live | View `@State`; auto-expand persisted via `@AppStorage` (no schema change) |
| New tokens needed | `Radius.chip 15`, `Spacing.ringStroke 3.3`, `Metrics.timeBead 54` + `headerMoodCircle 58`, `Opacity.deEmphasis 0.34` + `moodWash 0.16` |

No `NEEDS CLARIFICATION` remains.

