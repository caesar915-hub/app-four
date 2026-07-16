# Research — DayCard a01 (the Figma→code authority)

Source: file `M0Meys9X89X1NLyT14qrX5`, page Screens (v2) `76:2`. Read live via `get_design_context` + `get_variable_defs` (folded `308:2122`, unfolded `308:1957`). Figma's `get_design_context` emits a variable's *base* hex, not the layer's fill opacity — the screenshots are the truth where they disagree (see the two tint notes below). This table is the authority the implementation maps to; no raw literals in views.

## Shared tokens (both states) — all already exist

| Figma variable / value | Code token |
|---|---|
| `radius/card` = 20 | `Radius.newLookCard` |
| `Tiimo/Shadow/Card` (0.05 y2 r8 + 0.03 y1 r2) | the 2-layer shadow already on `DayCard`/`newLookCard()` |
| `surface/card` #FFFFFF | `NewLook.card` |
| `color/mood/base-N` | `MoodLevel.color` |
| `color/mood/wordColor-N` | `MoodLevel.wordColor` (light/dark pairs already match Figma's light values) |
| `ink/primary` #1c1b1f | `NewLook.inkPrimary` |
| `ink/secondary` #8a8a8e | `NewLook.inkSecondary` |
| `accent/medication` #7e5ca8 | `Palette.medication` |
| `color/palette/sleepIndigo` #5566a6 | `Palette.sleepIndigo` |
| `Tiimo/Display/Title-24` (Inter Bold 24) | `Typography.text(24, weight: .bold, relativeTo: .title2)` (native SF per DESIGN.md) |
| `Tiimo/Label/Caps-13` (Semi Bold 13, tracking 1.3) | `Typography.text(13, weight: .semibold, relativeTo: .subheadline)` + `.tracking(1.3)` + `.textCase(.uppercase)` |
| `Tiimo/Body/Small-13` (Regular 13) | `Typography.caption` / `Typography.text(13, relativeTo: .subheadline)` |

**Tint note (screenshots vs metadata):** folded card and the unfolded band show `bg base-5` in metadata but render as a light wash → `MoodLevel.blockTint` (`Opacity.moodBlock` = 0.24). Unfolded row discs show `bg base-N` but render as medium tints → `MoodLevel.badgeTint` (`Opacity.moodBadge` = 0.50). **Both opacities already equal Figma exactly — zero new colour tokens.**

## New layout dimensions (Metrics — not colours)

| Purpose | Figma | Token to add |
|---|---|---|
| Unfolded row mood disc | 43 | `Metrics.rowMoodDisc = 43` |
| ⋯ affordance circle | 30, 1.5 border | `Metrics.moreAffordance = 30` (border uses `Spacing`-adjacent 1.5 as a named local) |
| Row sprout inside disc | ~30 | reuse `Metrics.summarySignal`-scale; pass `size: 30` |

Folded sprout stays `Metrics.dayHeaderGlyph` (40 ≈ Figma 37×40). Chip glyphs stay `Metrics.summarySignal` (15). Dot separators: 5px `NewLook.inkSecondary` circles (existing pattern — `Circle().frame(3)`-style; use `Spacing`-derived).

## Folded `308:2122` — element map

- Card: `blockTint` fill (mood base @ .moodBlock), radius 20, 2-layer shadow, padding 16h / 14v (≈ `Spacing.l` / `Spacing.m`+), `gap 16` (`Spacing.l`), items centered.
- Sprout: bare `SignalGlyph(.mood, level:, size: 40)` on the tint (no disc — the Figma avatar frame is the card tint, invisible).
- Headline: mood word `24 Bold` in `wordColor` · caps-13 "·" secondary · caps-13 weekday primary (3-letter uppercase).
- Summary chips (wrapping, gap 8/10, 5px dot separators): energy (bolt glyph @level + word, primary) · focus (aperture @level + word, primary) · medication (capsule glyph + name, `Palette.medication`) · **sleep (bed glyph + "Nh Sleep", `ink/primary`)**. Fidelity note: folded sleep *text* is primary ink in Figma (the bed glyph itself is indigo via `SignalGlyph(.sleep)`).
- Trailing: `⌄` (down chevron) secondary.

## Unfolded `308:1957` — element map

- Card: white `NewLook.card`, radius 20, 2-layer shadow, flex-col.
- **Band** (`308:1958`): `blockTint` strip, padding 16h / 9v, `justify-between`: "GREAT · MON" caps-13 (GREAT=wordColor, ·=secondary, MON=primary) + `⌃` (up chevron) secondary.
- **Entries** (`308:1965`): `gap 22`, padding 16h / top 16 / bottom 18. Each row `gap 16`, items-start:
  - Avatar: `Circle().fill(rowLevel.badgeTint)` Ø43, holding `SignalGlyph(.mood, level: rowLevel, size: ~30)`.
  - Content: headline `justify-between` — lead = mood word `24 Bold` wordColor + time `13 regular` secondary; trailing = **⋯ affordance**: Ø30 circle, 1.5 `inkSecondary` stroke, 3-dot ellipsis inside.
  - Chip line (single wrapping row, gap 10, 5px dot separators): energy (bolt+word primary) · focus (aperture+word primary) · medication name (capsule + name, `Palette.medication`) · **sleep (text only, no glyph, `Palette.sleepIndigo`)** · feelings ("♥ " + comma-joined, `inkSecondary`, cap 4 + overflow) · side-effects (comma-joined, `inkSecondary`, cap 4 + overflow).
- **No** timeline bead, **no** connector line, **no** medication-phase ring.

## Decisions / consequences

- **Med-phase ring removed from the calendar** (owner-approved). Dose phase remains in the medication bar + recording detail. `TimelineBead` becomes unused by `TimelineRow` → remove if no other consumer (grep gate).
- **Per-node sleep fidelity** (deliberate, matches Figma): folded = bed glyph + primary-ink text; unfolded = indigo text, no glyph. Flag at QA — if the owner prefers uniform sleepIndigo, it's a one-line change each.
- **Med chip = name only** (no "Taken", no dose) in both states — `DayCardSummary.mostRecentMedicationName` already returns the name only; the unfolded row must switch from today's "Taken Concerta 36mg" to the name-only chip.
- **Weekday = 3-letter uppercase** ("MON") — replaces today's full "Tuesday, 10 Jun" label. Needs a short weekday string; `TimelineDay.label` is currently "d MMM" — derive the 3-letter weekday from `TimelineDay.date` (add a formatted value, no model change).
