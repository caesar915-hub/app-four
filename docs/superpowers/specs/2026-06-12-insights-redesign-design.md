# Insights Redesign — Design Spec

**Date:** 2026-06-12
**Status:** Approved (mockup v5)
**Mockups:** `docs/superpowers/plans/2026-06-11-insights-redesign-mockup{,-v2,-v3,-v4,-v5}.html` — v5 is the approved final; earlier versions + `…-focus-color-options.html`, `…-insights-signal-palettes.html`, `…-insights-palette-combinations.html` document the exploration.

## Summary

Rebuild `InsightsView` as a single vertical scroll of five sections treating **mood, energy, and focus as co-equal signals**, in the **Meadow palette system** (M2 + E2 + F2). Visual language adapted from How We Feel — serif display headers, gradient fills, generous spacing — but fully adaptive light/dark via existing `Theme` tokens. Medication purple is untouched and remains exclusive to meds.

## Goals

- One scroll, no carousel; each section under a large left-aligned serif header.
- Mood + energy + focus visualized with one shared grammar (5-step ordinal ramps).
- No color collisions with medication purple; colorblind-aware.
- Ship-ready for TestFlight: this is the last UI redesign before release.

## Non-goals

- Activities view ("What you were doing…") — removed entirely.
- Emotion calendar grid and emotion-frequency bars in Insights — dropped (the Calendar tab timeline already covers per-day exploration).
- HWF-style per-emotion blob shapes, data export, personalization — out of scope.

## Screen structure (top to bottom)

Retained chrome: `ScreenContainer`, `MonthSelectorScrollView`, scroll-reset on tab re-select, day-detail sheet → recording navigation.

1. **Your overall check-in breakdown** — `MoodBubbleChart`: overlapping circles, area-proportional to mood share, % label inside each (real text); legend below. Replaces `MoodPieChart`.
2. **Your month in three signals** — `SignalStripsView`: three labeled strips (Mood / Energy / Focus); one bead per check-in in chronological order; per-strip summary ("mostly Okay"). **Bead tap opens the existing day-detail sheet** (44 pt hit target per bead).
3. **Where you averaged** — `SignalAverageGauges`: three vertical gauges, 5 dashed ticks, fill = month average; label inside fill top ("Okay+", "Steady", "Sharp"); caption below.
4. **Your daily rhythm** — `DailyRhythmMatrix`: rows = Mood/Energy/Focus, columns = Morning/Afternoon/Evening/Late night; each cell = dominant level (gradient blob + level word beneath).
5. **Connections** — `ConnectionCardsView`: serif-sentence insight cards with a mini bar. Order: med×focus first, then energy×mood, then sleep×mood. Cards below their data threshold render **gated** (dashed border, explicit unlock copy: "check in on 3 more days with sleep noted to unlock").

## Palette — Meadow system

### Mood (M2) — replaces the shipped palette at the SSOT `Recording+MoodDisplay.moodColor`

| Level | Base | Gradient partner (light end) |
|---|---|---|
| low | `#C2503F` | `#D4705F` |
| flat | `#DE8050` | `#EA9D72` |
| okay | `#E5C46A` | `#EFD68C` |
| good | `#94C56F` | `#AED68C` |
| great | `#4CAF6E` | `#6BC68A` |

**Accepted consequence:** calendar timeline, mood library, and detail views re-color automatically (one mood language app-wide).

### Energy (E2 "Voltage") — new `Palette.energyRamp`

sluggish `#44546E` · tired `#4E6F94` · steady `#5889BA` · alert `#63A4E0` · charged `#79C4FF` (gradient partners: +~12% lightness, see mockup v5 `--en-*-l`). Existing single-color orange energy tags migrate to the ramp mid step. `Palette.warning` stays orange — energy and warnings no longer share a color.

### Focus (F2 "Graphite") — new `Palette.focusRamp`, **dynamic colors**

| Level | Dark mode | Light mode |
|---|---|---|
| foggy | `#3A3A3E` | `#D8D8DE` |
| distracted | `#58585E` | `#B4B4BC` |
| present | `#7E7E86` | `#8A8A94` |
| sharp | `#ABABB5` | `#5A5A64` |
| locked-in | `#ECECF4` | `#26262C` |

Built with `UIColor { trait in … }` so the ramp inverts automatically. Sleep tags keep indigo (no longer shared with focus). Medication keeps `systemPurple` everywhere.

### Gradient rule

Every filled element uses `LinearGradient(lightPartner → base)`; one shared helper in the DesignSystem (do not hand-roll per view).

## Typography

New `Typography.display` = `.title` weight `.bold` + `.fontDesign(.serif)` (New York, Dynamic Type). Used only for Insights section headers, left-aligned. `InsightsHeaderSection` (centered) is deleted.

## Empty & edge states

- **Empty ≠ foggy:** "no data" is always a dashed `strokeBorder` outline; graphite foggy is always a solid fill. Applies to beads, matrix cells, and connection gating.
- Whole-month empty: one shared empty state ("Check in to see your month") instead of five headers over blank charts.
- A check-in missing one signal (e.g. mood extracted, focus not) simply contributes no bead/weight to that signal — never a zero.

## Component inventory

**New (one file each, `Views/Insights/`):** `MoodBubbleChart`, `SignalStripsView`, `SignalAverageGauges`, `DailyRhythmMatrix`, `ConnectionCardsView`.

**Deleted:** `InsightsCarousel`, `InsightsCardKind`, `TimeOfDayBars`, `WeeklyBars`, `ActivityPillsGrid`, `MoodPieChart`, `EmotionFrequencyBars`, `InsightsHeaderSection`, `CalendarGrid` (only used by the carousel), `SectionDivider` (no remaining usages — sections separate by whitespace).

**Kept:** `MonthSelectorScrollView`, `MoodLegend` (reused under the bubble chart), `DayDetailSheet`.

## InsightsViewModel additions

- `signalSequences` — chronological per-check-in `(mood?, energy?, focus?)` triples for the month.
- `signalAverages` — per signal: mean of ordinal values mapped to a label; half-steps render as "Okay+".
- `rhythmMatrix` — dominant level per (signal × time bucket); bucket boundaries reuse the existing time-of-day definitions.
- `connections` — computed pairings with hard minimum-N gates: med×focus ≥ 4 medication days; energy×mood ≥ 5 high-energy check-ins; sleep×mood ≥ 3 days on each side. Below threshold → gated card with exact unlock copy. Copy templates always express co-occurrence ("moved together"), never causation.

All derived on the existing store pipeline; no new persistence.

## Accessibility

- Headers and % labels are real text (Dynamic Type scaling).
- Each chart: `accessibilityElement(children: .contain)` + summary label (e.g. "Mood strip: 8 check-ins, mostly okay").
- Level words always appear as text next to color; counts everywhere; color is never the only signal.
- M2's red↔green axis is the classic CVD pair — mitigated by monotonic luminance steps and labels. **Pre-TestFlight task: one grayscale-filter pass over the whole screen.**
- 44 pt minimum hit targets (beads, matrix cells).

## Testing

- Unit tests for the four new ViewModel computations, including gating thresholds and the missing-signal case.
- Update mood-color assertions to M2 hexes (`Recording+MoodDisplay` tests).
- Light/dark previews for every new component; verify focus-ramp inversion.
- Manual: VoiceOver pass + grayscale pass before TestFlight build.

## Open items (not blockers)

- `Recording+MoodDisplay.swift` has uncommitted local changes on `nlp-extraction-hardening` — reconcile before the palette migration lands.
- Decide whether the redesign branch starts from `main` or waits for `nlp-extraction-hardening` to merge.
