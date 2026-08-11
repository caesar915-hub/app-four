# Insights Tab — Functional Specification

> Source of truth: the app code as of 2026-08-09. Where older spec/UX docs disagree with the code, this document follows the code. Written to be readable without any knowledge of the codebase; a source-file map is provided in the appendix.

## 1. Purpose & scope

The Insights tab answers one question for the user: **"what was my shape this month?"** It aggregates the user's voice check-ins for a single selected calendar month into five calm, glanceable panels — mood distribution, weekday signal patterns, monthly averages, time-of-day rhythm, and cross-signal connections — with no streaks, scores, or gamification. Everything on the tab is derived on the fly from the user's own check-in history; nothing is fetched from a server.

The tab is a single continuous vertical scroll (a previous five-page snap-pager design was retired). All sections recompute instantly when the user switches months.

## 2. Data inputs

All Insights content derives from the user's **check-ins** (voice recordings with transcriptions). Each check-in carries:

| Input | How it's produced | How Insights uses it |
|---|---|---|
| Timestamp | Set when the check-in is recorded | Month filtering, weekday grouping, time-of-day bucketing |
| Mood word | On-device language analysis of the transcript | Mood breakdown, mood gauge, rhythm row, two connections |
| Energy word | Same | Energy strip/gauge/rhythm, energy×mood connection |
| Focus word | Same | Focus strip/gauge/rhythm, medication×focus connection |
| Sleep quality word | Same | Sleep×mood connection only |
| Medication events | Same (name, dose, started/stopped) | Medication×focus connection — **presence on a day only**; names/doses are never shown in Insights |

Not used by Insights: sleep *hours*, emotions, side effects, topic tags, summaries, favorites. A check-in missing a given signal simply contributes nothing to that signal's numbers.

**Signal scales.** Mood, energy, and focus are each five-step ordinal scales with fixed labels and colors:

- **Mood** (burnt-orange → amber → green ramp): 1 Low, 2 Flat, 3 Okay, 4 Good, 5 Great
- **Energy** (olive → bright lemon ramp): 1 Sluggish, 2 Tired, 3 Steady, 4 Alert, 5 Charged
- **Focus** (slate → bright blue ramp): 1 Foggy, 2 Distracted, 3 Present, 4 Sharp, 5 Locked In

Matching is case-insensitive; an unrecognized or missing word counts as "no data" for that signal, never as level 1.

Each signal also has a distinct icon (a sprout for mood, a bolt for energy, an aperture for focus) whose appearance fills in with level, so color is never the only cue. A signal with no data renders as a faint dashed outline — never as a level-1 icon.

## 3. Screen structure

When the selected month contains at least one check-in, the tab shows, top to bottom:

1. **Screen header** — "Insights" title + a framing line
2. **Month selector** — horizontal scrolling month chips
3. **Card: "Your overall check-in breakdown"** — mood bubble chart + legend
4. **Card: "Your month in three signals"** — weekday-average strips + a deferred-sleep chip
5. **Card: "Where you averaged"** — three vertical gauges
6. **Card: "Your daily rhythm"** — signal × time-of-day matrix
7. **"CONNECTIONS" block** — three correlation cards (unlocked or gated)

Each card is a white rounded panel with a bold header, an optional trailing count or caption, and content at its natural height. The scroll fades out softly at the bottom edge.

## 4. Sections in detail

### 4.1 Screen header

- Title: **"Insights"**.
- Subtitle: **"&lt;Month name&gt; · today vs your usual"** — e.g. "August · today vs your usual". Only the month name is shown (no year), even when browsing a past month.

### 4.2 Month selector

A horizontally scrolling row of pill chips, one per month, ordered oldest → newest. Chips are formatted as abbreviated month + year, uppercased (e.g. "JUN 2026"). The selected chip has a solid fill with light text; unselected chips are white with a thin outline. Tapping a chip switches the entire tab to that month.

- The chip list spans from the month of the user's **earliest check-in** through the **current month**, inclusive. With no check-ins at all, only the current month appears.
- There is no swipe or arrow navigation between months and no "jump to today" button in the interface — chips are the only control.

### 4.3 "Your overall check-in breakdown" card

Header shows a trailing count: "N check-ins" (singular "check-in" for 1). Contains the mood bubble chart and, beneath it, the mood legend. If no check-in in the month has a recognizable mood, both are omitted and the card shows only its header and count.

**Mood bubble chart.** One bubble per mood level that occurred at least once during the month (levels with zero check-ins get no bubble).

- Horizontal position is fixed by mood rank: the chart width is divided into five equal slots, Low at the left through Great at the right. Bubbles are centered in their slot regardless of how many moods occurred.
- Vertical position floats by valence: Okay (the middle rank) sits at chart center; each rank above rises 14 pt, each below sinks 14 pt.
- Bubble **area** is proportional to that mood's share of mood-tagged check-ins, implemented as: diameter = 44 pt + (118 − 44) × √(share ÷ largest share). The most frequent mood is always the largest bubble at 118 pt; the smallest possible bubble is 44 pt. There is no collision avoidance, so neighboring large bubbles may overlap.
- Each bubble shows its percentage (share × 100, rounded). The mood name appears inside the bubble only when the bubble is at least 68 pt in diameter. Text color is black or white, whichever contrasts with the bubble fill.
- VoiceOver summary: "Good 33%, Okay 33%, …"; per bubble: "Good: 4 check-ins, 33%".

**Mood legend.** A wrapping grid of small white outlined capsules, one per occurred mood (same order as the chart: Low → Great). Each capsule shows a colored dot, the mood name, and the raw count in parentheses, e.g. "● Good (4)".

### 4.4 "Your month in three signals" card

Subtitle: "Average by weekday — this month". Contains three horizontal strips (Mood, Energy, Focus) plus a sleep chip.

**Weekday strips.** Each strip is a row of seven fixed slots labeled Mo Tu We Th Fr Sa Su (Monday-first). Each slot shows that signal's icon colored by the **average level for that weekday across the whole month** (see §5.4). A weekday with no qualifying check-ins shows the faint dashed "no data" icon. Slots are not tappable.

- Each strip has a header: the signal icon, the signal name, and a trailing summary — **"mostly &lt;label&gt;"** (the modal level across all of the month's check-ins for that signal, e.g. "mostly good") or **"no data"**. The header icon's fill level reflects the strip's modal level (middle level 3 when the strip is empty).
- VoiceOver per slot: "Mo: Good" or "Mo: no data".

**Sleep chip.** Below the strips, a dashed-outline capsule reads "Sleep · not tracked yet" with a bed icon. It is always shown and is informational only (not tappable). Note: sleep *quality* data does feed the Sleep × mood connection card (§4.7) — the chip refers to sleep not having its own strip/ramp, not to sleep being absent from the data.

### 4.5 "Where you averaged" card

Three vertical gauges side by side — Mood, Energy, Focus — showing the monthly average for each signal.

- Each gauge is a 64 pt × 280 pt rounded track with five dashed horizontal tick lines marking the five levels. The signal's icon sits above the gauge (filled to the average's level; dashed when empty).
- Fill grows from the bottom to a height of average ÷ 5 of the track, colored with the ramp of the level the label names. A label floats at the top of the fill.
- Whole-number average (e.g. exactly 3.0): label is the level word ("Steady"), caption below reads "Steady on average".
- Fractional average (e.g. 3.4): label is the lower level word with a plus ("Okay+"), caption reads "between Okay & Good". The fill color always corresponds to the **lower** level.
- Signal with no data all month: no fill, a dashed empty icon, and an em-dash "—" in place of label and caption.

### 4.6 "Your daily rhythm" card

Subtitle: "Dominant level per signal by time of day". A 3 × 4 matrix: rows are Mood / Energy / Focus; columns are four time-of-day buckets:

| Column | Hours |
|---|---|
| Morning | 06:00–11:59 |
| Afternoon | 12:00–17:59 |
| Evening | 18:00–21:59 |
| Late | 22:00–05:59 |

Each cell shows a 52 pt colored disc for the **dominant** (most frequent) level of that signal in that bucket during the month, with the level name beneath it. Ties resolve to the **higher** level. A cell with no check-ins in that bucket shows a dashed outlined circle and an em-dash. Cells are not tappable. VoiceOver: "Morning: Good" / "Morning: no data".

### 4.7 "CONNECTIONS" block

A small-caps "CONNECTIONS" heading with the caption **"Patterns across signals — 3 or more days to unlock"**, followed by three cards in fixed order:

1. **Medication × focus**
2. **Energy × mood**
3. **Sleep × mood**

Each card is in one of two states:

- **Unlocked** — an uppercase title, a full sentence finding (e.g. "On medication days, sharp focus appeared 75% of the time."), and a mini progress bar: a rounded track filled to the measured fraction in purple, with a leading label (e.g. "Med days"), the percentage in the center, and a trailing label (e.g. "Sharp+ focus"). The bar's fill has a minimum visible width even at small fractions.
- **Gated** — a dashed-border card with a lock icon and explicit unlock instructions, e.g. "Log medication on 2 more days to unlock this connection." Never a bare "not enough data".

The exact rules and thresholds for each connection are in §5.7. (Note: the section caption says "3 or more days", but the actual gates are 4 days, 5 days, and 3+3 days respectively — see Known ambiguities.)

### 4.8 Empty state

When the selected month has **no check-ins at all**, the tab shows only the month selector plus an empty state: a chart icon and the headline **"Check in to see your month"**. All other sections are hidden. (Because the month selector offers months back to the first-ever check-in, the user can always navigate to a populated month.)

## 5. Background calculations

All calculations share one input set: the check-ins whose timestamp falls within the currently selected calendar month (device locale/timezone). Multiple check-ins per day are all kept; nothing is pre-aggregated per day unless a rule says so.

### 5.1 Month window

- "Selected month" is calendar-month granularity. The default on opening the tab is the current month.
- Available months = every calendar month from the month of the earliest check-in through the current month, inclusive.

### 5.2 Signal parsing

For each check-in and each of mood/energy/focus, the stored word is matched case-insensitively against the five level names of that signal's scale (§2). Unrecognized or absent words yield "no data" and are excluded from that signal's counts, averages, and distributions.

### 5.3 Mood distribution (bubble chart + legend)

- Take all check-ins in the month with a recognizable mood. Count occurrences per level.
- Share per level = count ÷ total mood-tagged check-ins. Levels with zero occurrences are omitted entirely.
- Display order is always Low → Great.

### 5.4 Weekday-average strips

- Group the month's check-ins by day of week (Monday … Sunday).
- For each signal × weekday: collect the level (1–5) of every check-in that day-of-week with that signal present; average arithmetically; round to the nearest integer; that rounded value selects the displayed level. **Each check-in counts equally** — a weekday on which the user checked in three times weighs those three check-ins the same as one check-in on another week of the same weekday; there is no per-day pre-averaging.
- A weekday with zero qualifying check-ins renders as "no data".

### 5.5 Monthly averages (gauges)

- For each signal: average the 1–5 levels of all check-ins in the month with that signal present.
- Fill fraction = average ÷ 5.
- If the average is a whole number, label = that level's word. Otherwise label = floor(average)'s word + "+", caption names the floor and floor+1 levels. The displayed fill color and the icon's level are always the floor level.

### 5.6 Daily rhythm matrix

- Bucket each check-in by the hour of its timestamp (table in §4.6; "Late" spans midnight).
- For each signal × bucket: count the frequency of each level among check-ins in the bucket with that signal present. The dominant level is the most frequent; **ties go to the highest level**. Empty bucket → "no data" cell.

### 5.7 Connections

Common conventions: a "day" is a calendar day. Percentages are rounded to the nearest whole number. In all three cards, a day qualifies when **at least one** check-in that day meets the condition — so "X% of the time" means "X% of those days had at least one qualifying check-in".

**Medication × focus** — unlocks at **≥ 4 distinct days** in the month that contain at least one check-in with a logged medication event.
- Denominator: those medication days.
- Numerator: medication days on which at least one check-in (any check-in that day, with or without medication) has focus level ≥ 4 (Sharp or Locked In).
- Sentence: "On medication days, sharp focus appeared N% of the time." Bar: "Med days" → N% → "Sharp+ focus".
- Gated copy: "Log medication on K more day(s) to unlock this connection." (K = 4 − current days)

**Energy × mood** — unlocks at **≥ 5 distinct days** containing at least one check-in with energy level ≥ 4 (Alert or Charged).
- Denominator: those high-energy days.
- Numerator: high-energy days on which at least one check-in that day has mood level ≥ 4 (Good or Great).
- Sentence: "On high-energy days, good-or-better mood appeared N% of the time." Bar: "High energy" → N% → "Good+ mood".
- Gated copy: "Log high energy on K more day(s) to unlock this connection." (K = 5 − current days)

**Sleep × mood** — unlocks at **≥ 3 distinct good-sleep days AND ≥ 3 distinct poor-sleep days**. Sleep quality is matched case-insensitively against fixed vocabularies:
- Good sleep: "good", "great", "excellent", "well"
- Poor sleep: "poor", "bad", "terrible", "awful", "rough"
- Any other sleep-quality word counts toward neither set. (The same day can land in both sets if different check-ins that day recorded different qualities; it then counts in both.)
- Denominator: good-sleep days + poor-sleep days.
- Numerator: good-sleep days where at least one check-in that day has mood ≥ 3 (Okay or better), **plus** poor-sleep days where at least one check-in that day has mood ≤ 2 (Flat or Low).
- Sentence: "Sleep quality and mood moved together N% of the time." Bar: "Sleep quality" → N% → "Aligned mood".
- Gated copy names whichever side is short: "Note K more good-sleep day(s) and J more poor-sleep day(s) to unlock this connection." (only the deficient side(s) are mentioned)

### 5.8 Strip summaries

- Each strip's trailing "mostly X" is the **modal level** across all of the month's check-ins for that signal (not per-weekday). With no data: "no data".
- The strip header icon's fill level uses the same modal level, defaulting to the middle level (3) when empty.

## 6. Edge cases and states

| Situation | Behavior |
|---|---|
| No check-ins in selected month | Empty state (§4.8); month selector still visible |
| Check-ins exist but none have a mood | Breakdown card shows header + count only; no chart or legend |
| A signal missing all month | Strip shows seven "no data" slots and summary "no data"; gauge empty with "—"; rhythm row all dashed cells |
| Single check-in in month | Everything renders: count reads "1 check-in", chart has one 118 pt bubble at 100%, averages are whole-number, connections almost certainly gated |
| Partial signals on a check-in | Each signal's panels use whatever is present; missing signals are simply excluded from that signal's math |
| Ties in dominant-level calculations | Rhythm matrix: highest level wins. Strip summary / header icon: tie outcome is not guaranteed stable (see Known ambiguities) |
| Unrecognized signal words (data drift, older app versions) | Treated as "no data"; never guessed or coerced |
| Future months | Not offered — the selector ends at the current month |

### Known ambiguities / surprises (documented as-implemented)

1. **Connections caption vs. actual gates.** The section caption says "3 or more days to unlock", but the real gates are 4 (Medication × focus), 5 (Energy × mood), and 3+3 (Sleep × mood).
2. **Sleep is half-present.** The signals card declares "Sleep · not tracked yet", while the Sleep × mood connection actively consumes sleep-quality words.
3. **"N% of the time" counts days, not check-ins.** A connection day qualifies if *any* check-in that day meets the bar, which overstates the association relative to a per-check-in rate.
4. **Weekday averages don't pre-aggregate per day.** Three check-ins on one Monday outvote one check-in on each of three other Mondays.
5. **Tie-breaking is inconsistent.** The rhythm matrix deterministically picks the higher level on a frequency tie; the strip summary ("mostly X") and the strip header icon pick an arbitrary winner on ties.
6. **Dead affordances.** The check-in-detail navigation destination and previous/next-month and jump-to-today actions exist but nothing in the current Insights UI triggers them; beads and rhythm cells are display-only. A per-day bead mode (one bead per check-in day, tappable) is still computed but not rendered anywhere.
7. **Bubble chart has no overlap/bounds handling.** Adjacent large bubbles can overlap, and a maximally sized bubble at an edge slot can clip.
8. **Header subtitle omits the year** even when viewing past months ("August · today vs your usual" in any year).
9. **Mixed-quality sleep days** count in both the good-sleep and poor-sleep sets of the Sleep × mood connection.

## Appendix — source map

| Feature | Source |
|---|---|
| Tab layout, cards, empty state | `app-four/Views/InsightsView.swift` |
| Month filtering, available months | `app-four/ViewModels/InsightsViewModel.swift` |
| All aggregations, connections, thresholds | `app-four/ViewModels/InsightsViewModel+Signals.swift` |
| Mood bubble chart / legend | `app-four/Views/Insights/MoodBubbleChart.swift`, `MoodLegend.swift` |
| Weekday strips | `app-four/Views/Insights/SignalStripsView.swift` |
| Average gauges | `app-four/Views/Insights/SignalAverageGauges.swift` |
| Rhythm matrix | `app-four/Views/Insights/DailyRhythmMatrix.swift` |
| Connection cards | `app-four/Views/Insights/ConnectionCardsView.swift` |
| Month chips | `app-four/Views/Insights/MonthSelectorScrollView.swift` |
| Signal scales, colors, glyphs | `Packages/SquirlSignals/.../Levels.swift`, `Packages/SquirlDesignSystem/.../SignalLevel.swift`, `SignalGlyph.swift`, `Palette+Signals.swift`, `MoodLevel+Palette.swift` |
| Check-in data & transcript extraction | `app-four/Models/Recording.swift`, `app-four/Services/NoteExtraction/` |
