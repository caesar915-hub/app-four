# Quickstart / Device-QA — DayCard a01

Owner builds + QAs on a physical device (no simulator). Compare against Figma `308:2122` (folded) and `308:1957` (unfolded), light + dark.

## Build + test

1. Build `app-four` on device (branch `feat/034-daycard-a01`, iOS 26 target).
2. Run the test suite; confirm the new `FoldedDayCardHeaderTests` sleep cases pass (and demonstrably failed before `DayCardSummary.sleep` existed — RED→GREEN).

## Folded (US1 — spec §1)

- [ ] Each Calendar day is one mood-tinted card: bare sprout at left, "Great" large/bold in the mood word colour, "· MON" small caps, wrapping summary line. (AS-1, SC-001)
- [ ] Summary line shows only present signals — energy · focus · med-name (purple) · sleep (bed glyph) — with small dot separators. (AS-1)
- [ ] A day with no sleep shows no sleep chip. (AS-2)
- [ ] An empty day shows the calm copy on an untinted card. (AS-3)
- [ ] At an accessibility text size, the mood word and chips wrap; nothing truncates. (AS-4, SC-005)

## Unfolded (US2 — spec §2)

- [ ] Tapping a card collapses the header to a slim caps band ("GREAT · MON" + up chevron). (AS-1)
- [ ] Each check-in is a row: 43pt mood disc (that row's mood) + sprout, 24pt mood word, time, outlined ⋯, one wrapping chip line. No vertical connector line between rows. (AS-2, SC-001)
- [ ] Medication chip shows the name only — no "Taken", no dose amount. (AS-3)
- [ ] Sleep chip is indigo; feelings ("♥ …") and side-effects are secondary, each capped at 4 + overflow. (AS-5)
- [ ] Tapping a row (including the ⋯) opens the recording detail — same as before. (AS-4, SC-002)

## Cross-cutting

- [ ] Dark mode: tints/inks/word-colours read correctly in both states. (SC-001)
- [ ] VoiceOver: a folded day announces its full summary incl. sleep as one element; a row announces its check-in as one element. (SC-005)
- [ ] Reduce Motion: the fold/unfold chevron + expand animation respect the setting.
- [ ] Fold/unfold, auto-expand, and back navigation all still work first try. (SC-002)

## Flags to eyeball (owner-approved, confirm acceptable on device)

- **Med-phase ring is gone from the calendar** — dose phase now shows only in the medication bar + recording detail. Confirm nothing important was lost.
- **Weekday is 3-letter only** ("MON") — the date number no longer appears on the card. Confirm date context is adequate from the surrounding calendar.
- **Sleep styling differs by state** (folded = bed glyph + primary text; unfolded = indigo text, no glyph) — matches Figma per node. Confirm it doesn't read as inconsistent.
- **Sleep chip contrast in dark mode** — the unfolded sleep chip uses `Palette.sleepIndigo` (`#5566A6`, a single value with no dark variant), which measures ≈3.15:1 on the dark card (below WCAG AA 4.5:1). This is a **pre-existing** shared-token limitation (the old row's sleep line used the same colour), not introduced by 034. Left as-is per the "don't change shared DESIGN.md tokens without approval" rule. If you want it fixed: give `sleepIndigo` a lightened dark variant (improves it app-wide) — say the word.
- **inkSecondary in light mode** — the row time, separators, and feelings/side-effects chips use `NewLook.inkSecondary`, the **already owner-accepted** below-AA light token (documented on the token + DESIGN.md). No new decision needed; noted for completeness.
