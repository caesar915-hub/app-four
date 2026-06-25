# UI Behaviour Contract: QA fixes (018)

This feature exposes no API/CLI/network interface. Its "contracts" are the observable visual + interaction behaviours each fix must satisfy. Each row is verifiable on-device/simulator (the format that fits an app UI feature, per the plan template).

## A2 — Medication-bar top scroll fade (Insights + Settings)

| # | Given | When | Then |
|---|-------|------|------|
| C-A2-1 | Insights, med bar shown | content scrolls up toward the bar | content fades to transparent before/at the bar's bottom edge; no sharp text beside or above the floating capsule |
| C-A2-2 | Settings list, med bar shown | list scrolls up toward the bar | list content fades behind the bar at the top (not a hard cut under it) |
| C-A2-3 | either screen | compared to the bottom edge | top fade reads symmetric with the existing bottom dissolve into the tab bar |
| C-A2-4 | either screen at an accessibility Dynamic Type size | bar is taller | top fade still reaches the bar's bottom edge (no sharp band, no over-fade) |
| C-A2-5 | Settings, med bar hidden (toggle OFF) | scroll | no top fade applied where there is no bar |
| C-A2-6 | Settings list with the mask | tap a row / scroll-to-top via tab reselect | selection, separators, and scroll-to-top all still work |

## A1 — Greyed registered day keeps its dot

| # | Given | When | Then |
|---|-------|------|------|
| C-A1-1 | a past day selected; a more-recent day has check-ins | calendar greys the more-recent day | that day still shows its mood-coloured dot, dimmed with the cell |
| C-A1-2 | a more-recent greyed day with no entries | greyed | no dot (unchanged) |
| C-A1-3 | greyed day with a neutral entry (entries, no mood) | greyed | neutral dot still shown, dimmed |
| C-A1-4 | VoiceOver on, focus a greyed registered day | read | label still conveys "has check-ins"/"has entries" |
| C-A1-5 | greyed registered day vs non-greyed same-mood day | compare | greyed cell (number + dot) is uniformly dimmer, not a different colour/state |

## A3 — Log-Dose sheet matches the design system

| # | Given | When | Then |
|---|-------|------|------|
| C-A3-1 | Log-Dose sheet open | viewed | surface + control colours use `Theme`/`Palette` tokens (no foreign system-grey/ad-hoc opacity) |
| C-A3-2 | medication chips | selected vs unselected | colours use the medication/design tokens consistently with other chip surfaces |
| C-A3-3 | dark mode | sheet shown | all colours correct + legible |
| C-A3-4 | the specific element the owner flagged (confirmed on-sim) | re-checked after fix | renders correctly |

## Invariants (all fixes)

- **INV-1**: No persisted data, schema, or check-in/medication/calendar *behaviour* changes — rendering only.
- **INV-2**: The full existing test suite stays green (no logic touched; `CalendarHeaderScrollFadeTests` unaffected).
- **INV-3**: Each fix is independently revertable without breaking the other two.
