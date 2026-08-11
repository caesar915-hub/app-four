<!-- Created: 2026-07-27 15:10 (WEST) · Updated: 2026-07-27 15:10 (WEST) -->
# 06 — Insights

Documents branch `main` @ `43eb6515a63a0eca957a79aad257da380c73edd4`. All `path:line` citations are against `main`.

## Purpose

Describe the Insights tab: a per-month analytics screen over the user's check-in recordings — mood distribution, per-weekday signal averages, monthly signal averages, time-of-day rhythm, and cross-signal "connections" (correlation cards) — including its month selection, empty states, and minimum-data gates.

## Scope

- In scope: `InsightsView`, `InsightsViewModel`, `InsightsViewModel+Signals`, `MonthSelectorScrollView`, `MoodBubbleChart`, `MoodLegend`, `SignalStripsView`, `SignalAverageGauges`, `DailyRhythmMatrix`, `ConnectionCardsView`.
- Out of scope: how signals are extracted from recordings ([Processing & Extraction](04-processing-and-extraction.md)), per-day browsing ([Library & History](05-library-and-history.md)), medication logging semantics ([Medications](07-medications.md)).

## Actors & triggers

- **User** — opens the Insights tab; taps a month chip; scrolls the single-page layout. No other interactions exist: rhythm cells are non-interactive, beads have no tap handler (the old `onBeadTap` hook "was dead — never wired by any caller — and was removed with the a07 re-skin").
- **System triggers** — none; all computations are synchronous computed properties over the in-memory `RecordingStore.recordings`, recomputed on observation change. Analytics: `.trackScreen("InsightsView")`.

## Functional requirements

### Screen structure

- **FR-INS-01 — Tab & layout.** Insights is the third root tab (`Tab.insights`, label "Insights"). The screen is **one continuous scroll** (a former 5-page snap-pager was retired, owner ruling 2026-07-16) containing, in order: identity header, month selector, breakdown card (mood bubble chart + legend), signals card (weekday strips + deferred sleep chip), averages card (gauges), rhythm card (matrix), connections block (three cards). Hosted in `ScreenContainer(title: "", scrollable: false)` with `.edgeFadeMask(top: 0, bottom: 36)` (`RootTabView.swift:28-30`; `InsightsView.swift:3-5, 20, 84-100`).
- **FR-INS-02 — Identity header.** Title **"Insights"** (24 pt bold). Subtitle exactly `"<MonthName> · today vs your usual"` (e.g. "July · today vs your usual") — note the subtitle says "today vs your usual" **even when browsing a past month** (`InsightsView.swift:53-64`).
- **FR-INS-03 — Month data slicing.** `currentMonth` (default today) selects the month; `monthRecordings` = recordings whose `createdAt` falls in that month; `hasAnyData = !monthRecordings.isEmpty` gates the populated vs empty state **per selected month** — browsing to an earlier month with no check-ins shows the empty state with chips still available. `availableMonths` is a contiguous month list from the earliest recording's month through the current month — **months with no recordings are included**; falls back to `[currentMonth]` (`InsightsViewModel.swift:9-66`).
- **FR-INS-04 — Month chip scroller.** A horizontal `ScrollView` (indicators hidden) of one chip per `availableMonths` entry, labeled uppercased **"MMM yyyy"** (e.g. "JUL 2026", tracking 1.3), styled `.newLookChip(selected:)` (selected = solid fill + light label; unselected = white + hairline). Selection compares at month granularity; tapping sets `currentMonth` directly — **no animation and no scroll-to-selected**. Selected chip carries the `.isSelected` trait (`MonthSelectorScrollView.swift:9-31`).
- **FR-INS-05 — Empty-month state.** When the selected month has zero recordings, the screen shows the month chips above an SF Symbol `chart.bar.doc.horizontal` and the headline **"Check in to see your month"**; no cards render. No loading, error, or permission states exist anywhere in Insights (`InsightsView.swift:25-29, 188-201`).
- **FR-INS-06 — Push destination (wired, unused).** `navigationDestination(for: UUID.self)` → `RecordingDetailView` is wired with a stale-push guard (deleted recording → `Color.clear` + auto-pop), but **no view in the Insights area currently pushes a UUID** (the old bead-tap hook was removed) (`InsightsView.swift:32-39`; `SignalStripsView.swift:5-6`).

### Visualization 1 — mood bubble chart

- **FR-INS-07 — Mood shares input.** `moodShares` counts per `MoodLevel` over `monthRecordings` with a parseable mood (case-insensitive); recordings without mood are excluded from the total. Levels with zero check-ins are omitted; order is low→great; `fraction = count / total`. Empty input → `[]`, and the chart **and legend are hidden entirely** while the card header and check-in count still show (`InsightsViewModel+Signals.swift:101-111`; `InsightsView.swift:134-137`).
- **FR-INS-08 — Area-proportional sizing.** Chart height 160 pt; bubble diameter is **area-proportional to share**: `d = minD + (maxD − minD) × sqrt(fraction / maxFraction)` with `minD = 44`, `maxD = 118` (maxFraction 0 → minD fallback). Position: five equal columns indexed by `numericValue − 1` (low left → great right); y offset `−(numericValue − 3) × 14` — higher moods float up 14 pt per step, lower sink ("great floats up, low sinks down") (`MoodBubbleChart.swift:10-47`).
- **FR-INS-09 — Bubble content & legend.** Each bubble shows the rounded percent (semibold) and the level's `displayLabel` **only when diameter ≥ 68 pt**, in a radial `bubbleFill` gradient with contrasting ink (black/white by luminance). Below the chart, `MoodLegend` renders adaptive capsule chips (8 pt circle in `fillGradient` + `displayLabel` + `"(count)"`). Card header: **"Your overall check-in breakdown"** with trailing **"<count> check-in"** / **"<count> check-ins"** (singular when 1). AX: container `"<Label> <pct>%, ..."`; per-bubble `"<Label>: <count> check-in(s), <pct>%"` (`MoodBubbleChart.swift:49-80`; `MoodLegend.swift:8-28`; `InsightsView.swift:132-133`).

### Visualization 2 — weekday signal strips

- **FR-INS-10 — Seven fixed weekday slots.** `weekdaySignalStrips` has fixed slots `Mo, Tu, We, Th, Fr, Sa, Su` (Monday first, `Calendar` weekday numbers). All `monthRecordings` are grouped by weekday; per signal × weekday the `numericValue`s are **averaged (mean), then `Int(avg.rounded())`** — Swift's default to-nearest-or-away-from-zero rounding, so **3.5→4 and 2.5→3** — and resolved back to the level enum. Empty slots get `level = nil` (`InsightsViewModel+Signals.swift:132-157`).
- **FR-INS-11 — Strip presentation.** Card header **"Your month in three signals"**, subtitle **"Average by weekday — this month"**. Three fixed rows (Mood, Energy, Focus — `SignalKind` declaration order); each row: signal glyph (modal representative level, **defaults to 3** when all beads empty) + label + trailing summary; each bead: 28 pt glyph in an equal-width slot (44 pt hit-target floor) with a 9 pt weekday label below; empty beads show the level-less glyph (the glyph itself conveys "no data" — no separate placeholder) (`SignalStripsView.swift:23-93`; `InsightsView.swift:144-147`).
- **FR-INS-12 — Strip summary text.** `"no data"` when no recording carries that signal in the month; otherwise the **modal** level → `"mostly \(displayLabel)"` (e.g. "mostly Okay"). Ties are dictionary-order dependent (unspecified) (`InsightsViewModel+Signals.swift:344-354`).
- **FR-INS-13 — Deferred sleep chip.** Below the strips, a dashed capsule chip: sleep glyph + **"Sleep · not tracked yet"** (dash `[4, 3]`, AX label "Sleep, not tracked yet") — sleep's ramp is spec'd but deferred (`InsightsView.swift:66-80, 147`).
- **FR-INS-14 — Date-mode strips (computed, dormant).** `signalStrips` (one bead per check-in day, latest recording per day) is fully computed and `SignalStripsView` supports date mode, but **the screen never reads it** — it passes `weekdaySignalStrips` (`InsightsViewModel+Signals.swift:115-128`; `InsightsView.swift:146`).

### Visualization 3 — signal average gauges

- **FR-INS-15 — Monthly averages with floor-ordinal labeling.** Per signal: mean of `numericValue`s; `fraction = avg / 5.0`; `lower = Int(avg)` (truncation = floor for positive values). Whole average → `fillLabel = <level word>`, `caption = "<level word> on average"` (e.g. "Steady", "Steady on average"). Fractional average → `fillLabel = "<lower word>+"`, `caption = "between <lower word> & <upper word>"` (e.g. "Okay+", "between Okay & Good"). Empty → `fillLabel = "—"`, `caption = ""`, `fraction = 0`, `level = 0`. The `level` (floor ordinal) is **shipped explicitly** so the gauge never re-derives it from the lossy float `fraction` (spec-036 FR-010) (`InsightsViewModel+Signals.swift:38-47, 161-187`).
- **FR-INS-16 — Gauge rendering.** Card header **"Where you averaged"**. Three 280×64 pt vertical gauges; track with five dashed tick lines at heights level/5 (4 pt dashes, 2 pt spacing); bottom-anchored fill `280 × fraction` in the level's `fillGradient`, with `fillLabel` floating at the top of the fill in contrasting ink. The gauge clamps the VM's `level` to 1…5 and never re-derives from `fraction`. Caption below: `average.caption` or **"—"** when empty. Empty signals render track + ticks with no fill and a level-less glyph. AX: `"<Kind>: <fillLabel>, <caption>"` (e.g. "Mood: Okay+, between Okay & Good"; empty: "Focus: —, ") (`SignalAverageGauges.swift:23-127`; `InsightsView.swift:154`).

### Visualization 4 — daily rhythm matrix

- **FR-INS-17 — 3×4 matrix with exact hour buckets.** Card header **"Your daily rhythm"**, subtitle **"Dominant level per signal by time of day"**. 3 rows (Mood, Energy, Focus) × 4 cells in `TimeBucket` order with exact hour ranges on `Calendar.current` hour-of-day: **Morning** 6–11 (`6..<12`), **Afternoon** 12–17 (`12..<18`), **Evening** 18–21 (`18..<22`), **Late** 22–23 and 00–05 (`hour >= 22 || hour < 6`) (`DailyRhythmMatrix.swift`; `InsightsViewModel+Signals.swift:49-72, 191-213`; `InsightsView.swift:162-163`).
- **FR-INS-18 — Dominant = mode, ties to higher.** Each cell's dominant level is the **mode** of `numericValue`s in the bucket; **ties break to the higher level** (`freq.filter { $0.value == maxCount }.keys.max()`). Cell count is computed but never rendered. Filled cell: 52 pt circle in the dominant level's `fillGradient` + `displayLabel` below. Empty cell: 52 pt circle with dashed stroke (`inkSecondary.opacity(0.3)`, dash `[3, 2]`) + literal **"—"** at 40% secondary ink ("dashed outlines (not foggy grey)"). Every cell has a 44×44 pt minimum frame; **cells are not interactive**. AX: `"<Bucket>: <displayLabel>"` or `"<Bucket>: no data"` (`InsightsViewModel+Signals.swift:191-213`; `DailyRhythmMatrix.swift:4-80`).

### Visualization 5 — connection cards

- **FR-INS-19 — Three cards, fixed order.** Always exactly three, in fixed order: **"Medication × focus"**, **"Energy × mood"**, **"Sleep × mood"** (multiplication sign ×). Each is independently gated by a minimum-data threshold; below threshold it shows explicit remaining-days unlock copy — "never ambiguous 'not enough data'". Pluralization: "day" if 1 else "days" (`InsightsViewModel+Signals.swift:217-333`; `ConnectionCardsView.swift:3-37`).
- **FR-INS-20 — Medication × focus gate (≥ 4 med days).** Med days = distinct days of `monthRecordings` where `!recording.medicationEvents.isEmpty` (the event's `taken` flag is **not** checked). Gate **≥ 4 distinct med days**; gated copy exactly `"Log medication on \(need) more day(s) to unlock this connection."` (need = 4 − med days). Unlocked: good-focus med days = med days where any recording has `FocusLevel.numericValue >= 4` (Sharp or Locked In); `frac = goodFocusDays / medDays`; `pct = Int((frac * 100).rounded())`. Sentence `"On medication days, sharp focus appeared \(pct)% of the time."`; bar labels leading "Med days", center "<pct>%", trailing "Sharp+ focus" (`InsightsViewModel+Signals.swift:221-248`).
- **FR-INS-21 — Energy × mood gate (≥ 5 high-energy days).** High-energy = `EnergyLevel.numericValue >= 4` (Alert or Charged); high-energy days = distinct days of those. Gate **≥ 5 distinct high-energy days**; gated copy `"Log high energy on \(need) more day(s) to unlock this connection."`. Unlocked: days among them where any recording has `MoodLevel.numericValue >= 4` (Good or Great). Sentence `"On high-energy days, good-or-better mood appeared \(pct)% of the time."`; bar labels "High energy" / "<pct>%" / "Good+ mood" (`InsightsViewModel+Signals.swift:250-280`).
- **FR-INS-22 — Sleep × mood gate (≥ 3 + ≥ 3 sleep days).** `recording.sleepQuality` (lowercased) keyword-matched: good = `["good", "great", "excellent", "well"]`; poor = `["poor", "bad", "terrible", "awful", "rough"]`; other/nil values ignored. Gate: **≥ 3 distinct good-sleep days AND ≥ 3 distinct poor-sleep days**. Gated copy composes only the sides still short: `"Note \(needGood) more good-sleep day(s) and \(needPoor) more poor-sleep day(s) to unlock this connection."` (a satisfied side is omitted). Unlocked: aligned-good = good-sleep days with any mood `numericValue >= 3` (Okay or better); aligned-poor = poor-sleep days with any mood `<= 2` (Flat or worse); `frac = (alignedGood + alignedPoor) / (goodDays + poorDays)`. Sentence `"Sleep quality and mood moved together \(pct)% of the time."`; bar labels "Sleep quality" / "<pct>%" / "Aligned mood" (`InsightsViewModel+Signals.swift:282-328`).
- **FR-INS-23 — Eyebrow copy inconsistency.** The block eyebrow reads **"CONNECTIONS"** with caption **"Patterns across signals — 3 or more days to unlock"**. **Known inconsistency:** the actual gates are 4 med days (Medication × focus) and 5 high-energy days (Energy × mood); only Sleep × mood uses 3+3. The caption understates the two higher gates (`InsightsView.swift:174-179`).
- **FR-INS-24 — Card rendering.** Unlocked card: uppercased title, serif sentence (`Typography.display`), and a `MiniBar` — 8 pt capsule track with a `Palette.medication` fill of width `max(8, width × fraction)` (the **medication palette color is used for all three** connections), with leading/center/trailing labels below. Gated card: title + trailing `lock` symbol + the VM-composed unlock copy, white card with dashed border (dash `[5, 3]`). AX: `"<title>: <sentence> <barLabel>"` / `"<title>: locked. <unlockCopy>"` (`ConnectionCardsView.swift:39-148`).

### Minimum-data behaviors (consolidated)

- **FR-INS-25 — Per-element degradation.** When `hasAnyData` is true, card shells always render and individual visualizations degrade per element: no mood data → breakdown card shows header + count only (chart + legend hidden); signal absent all month → level-less beads + "no data" summary, gauge track with no fill and caption "—", all rhythm cells for that row dashed/"—"; connections show gated cards with explicit unlock copy (`InsightsView.swift:134-137`; notes §11).

## User flows

### Happy path

1. User opens the Insights tab → current month selected; if the month has check-ins, the five blocks render with data.
2. User scrolls through breakdown → strips → gauges → rhythm → connections.
3. User taps an earlier month chip → all computations re-slice to that month instantly (synchronous computed properties).

### Alternate flows

- **Month with no check-ins:** month chips + "Check in to see your month" (chips remain tappable).
- **Fresh user / early month:** connection cards show gated variants with exact remaining-day copy; strips/gauges/rhythm degrade per FR-INS-25.
- **Recording deleted under an open detail push:** the (currently unreachable) destination auto-pops.

## UI states

- **Empty (selected month has zero recordings):** chips + icon + "Check in to see your month". The card shells do not render.
- **Partial data:** per-element degradation per FR-INS-25; the `SleepLevel`-based sleep signal never appears (deferred chip only).
- **Loading / error / permission:** none exist — all data is local SwiftData and computations are synchronous.

## Validation rules & constants

| Rule / constant | Value | Source |
|---|---|---|
| Signals | exactly three, fixed order: Mood, Energy, Focus | `InsightsViewModel+Signals.swift:6-17` |
| Bubble chart | height 160; min diameter 44; max diameter 118; area-proportional `sqrt(fraction / maxFraction)`; y offset ±14 pt per level step; label only when diameter ≥ 68 | `MoodBubbleChart.swift:10-70` |
| Weekday strips | 7 fixed slots Mo–Su; mean then `Int(avg.rounded())` (half away from zero: 3.5→4, 2.5→3); representative level defaults to 3 | `InsightsViewModel+Signals.swift:132-157`; `SignalStripsView.swift:23-28` |
| Gauges | 280×64 pt; `fraction = avg/5`; floor-ordinal word ("Okay+", "between Okay & Good"); explicit `level` never re-derived from fraction | `InsightsViewModel+Signals.swift:161-187`; `SignalAverageGauges.swift:89-90` |
| Rhythm buckets | Morning 6–11, Afternoon 12–17, Evening 18–21, Late 22–23 & 00–05; dominant = mode, ties to higher level; cells 52 pt, 44 pt hit floor, non-interactive | `InsightsViewModel+Signals.swift:49-72, 191-213`; `DailyRhythmMatrix.swift` |
| Connection gates | med×focus ≥ 4 med days; energy×mood ≥ 5 high-energy days; sleep×mood ≥ 3 good AND ≥ 3 poor days | `InsightsViewModel+Signals.swift:221-328` |
| Connection thresholds | Sharp focus ≥ 4; high energy ≥ 4; good mood ≥ 4; aligned-good mood ≥ 3; aligned-poor mood ≤ 2; pct = `(frac*100).rounded()` | `InsightsViewModel+Signals.swift:221-328` |
| Sleep keywords | good: good/great/excellent/well; poor: poor/bad/terrible/awful/rough | `InsightsViewModel+Signals.swift:282-328` |
| MiniBar | 8 pt track; fill width `max(8, width × fraction)`; medication palette for all three | `ConnectionCardsView.swift:110-148` |
| Month chips | "MMM yyyy" uppercased, tracking 1.3, direct assignment | `MonthSelectorScrollView.swift:9-31` |

## Edge cases

- **Rounding:** weekday averages round half away from zero (3.5→4); gauge fractions are unrounded (`avg/5`) but the word uses the floor ordinal + "+"; connection percentages round to nearest.
- **Ties:** rhythm dominant ties resolve to the higher level (explicit); strip `representativeLevel` and `stripSummary` modal ties are dictionary-order dependent (unspecified).
- **Late-night data:** 22:00–05:59 all map to the single "Late" bucket, including post-midnight hours of the same calendar day.
- **Unparseable level strings** (typos, legacy values) are silently dropped from every aggregation.
- **Multiple check-ins per day:** mood shares and averages count each recording; weekday strips average all of them; connections are day-granular (any qualifying recording on the day counts).
- **Medication × focus** ignores whether medication was marked taken — any `MedicationEvent` linked to the recording qualifies the day.
- **Unused API surface on main:** `monthLabel`, `prevMonth()`, `nextMonth()`, `jumpToToday()`, `signalStrips` (date mode), `RhythmCell.count`, and the `selectedTab` binding are computed/declared but not consumed by the a07 UI.
- **Caption inconsistency:** "Patterns across signals — 3 or more days to unlock" understates the 4-day (medication) and 5-day (energy) gates (FR-INS-23).

## Acceptance criteria

1. A month with recordings renders all five blocks in order; a month without renders only chips + "Check in to see your month".
2. The mood bubble chart sizes bubbles by area (√-scaled), omits zero-count levels, and hides entirely (with the legend) when no recording has a mood — while the card header and "N check-in(s)" count still show.
3. Weekday strips average all recordings per weekday with half-away rounding (two recordings at 3 and 4 → 4; average 2.5 → 3) and show "mostly <modal label>" or "no data".
4. An average of 3.5 renders fillLabel "Okay+", caption "between Okay & Good", fraction 0.70, level 3; a whole average 3.0 renders "Steady" / "Steady on average" (energy) with no "+".
5. A 1–1 tie in a rhythm cell resolves to the higher level; a 02:00 check-in lands in "Late".
6. With 3 med days, the Medication × focus card is gated with exactly "Log medication on 1 more day to unlock this connection."; at 4 med days it unlocks. With 4 high-energy days the Energy × mood card reads "Log high energy on 1 more day to unlock this connection."; at 5 it unlocks. Sleep × mood requires 3 good AND 3 poor days and omits satisfied sides from its gated copy.

## Source references

- `app-four/Views/InsightsView.swift:3-201` · `app-four/Views/Insights/MonthSelectorScrollView.swift:9-31` · `MoodBubbleChart.swift:10-80` · `MoodLegend.swift:8-28` · `SignalStripsView.swift:5-93` · `SignalAverageGauges.swift:23-134` · `DailyRhythmMatrix.swift:4-80` · `ConnectionCardsView.swift:3-148`
- `app-four/ViewModels/InsightsViewModel.swift:5-74` · `app-four/ViewModels/InsightsViewModel+Signals.swift:4-370`
- `app-four/Views/RootTabView.swift:5-30` · `app-four/Models/Recording.swift:7-59` · `app-four/Store/RecordingStore.swift:7`
- `Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift:8-99` · `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/SignalLevel.swift:12-64` · `MoodLevel+Palette.swift:16-105` · `GlyphSignal.swift:7-8`
- `app-fourTests/ViewModels/InsightsViewModelTests.swift:43-241` (behavior-confirming tests)
- Sibling FSD: [Processing & Extraction](04-processing-and-extraction.md) · [Library & History](05-library-and-history.md) · [Medications](07-medications.md)
