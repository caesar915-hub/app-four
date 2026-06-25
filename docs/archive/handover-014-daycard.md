# Handover — spec 014 daily-card redesign
**Written:** 2026-06-23  
**Branch:** `feat/daycard-update` → PR #10 https://github.com/caesar915-hub/app-four/pull/10  
**Status:** 28/31 tasks done · full serial test suite GREEN · pushed

---

## What's done

Full Spec Kit pipeline ran end-to-end (spec → clarify → plan → tasks → implement) for the DayCard redesign "folded big, opens to the day."

### Files written / rewritten
| File | Change |
|---|---|
| `app-four/DesignSystem/Opacity.swift` | NEW — `moodWash=0.16`, `deEmphasis=0.34`, `moodCircle=0.55` |
| `app-four/DesignSystem/Radius.swift` | added `chip=15` |
| `app-four/DesignSystem/Spacing.swift` | added `ringStroke=3.3` |
| `app-four/DesignSystem/Metrics.swift` | added `timeBead=54`, `headerMoodCircle=58` |
| `app-four/Views/Library/ExpandedDayCards.swift` | NEW — pure value type wrapping `Set<Date>`, `toggling(_:)`, `selecting(_:autoExpand:)` |
| `app-four/Views/Components/DayCardSummary.swift` | NEW — pure struct, `latestRecording`, `mood/energy/focus`, `mostRecentMedicationName`, `emptyCopy` |
| `app-four/Views/Components/FoldedDayCardHeader.swift` | NEW — mood circle + weekday + FlowLayout summary line, combined a11y element |
| `app-four/Views/Components/DayCard.swift` | REWRITTEN — folded/expanded toggle, `Radius.card`, `Opacity.moodWash`, no selection border |
| `app-four/Views/Library/CalendarLibraryView.swift` | added `@State expandedCards`, `@AppStorage("autoExpandOnSelection")`, filter-above + auto-expand |
| `app-four/ViewModels/MoodLibraryViewModel.swift` | added `timelineDaysFilteredToSelectedDate(_:)` |
| `app-four/Views/Components/CalendarDayCell.swift` | added `isAboveSelection`, no today-ring, opacity for future days |
| `app-four/Views/Components/CalendarHeaderView.swift` | passes `isAboveSelection` |
| `app-four/Views/Settings/DayCardSettingsSection.swift` | NEW — `@AppStorage("autoExpandOnSelection")` toggle |
| `app-four/Views/Settings/SettingsView.swift` | added `dayCardSection` |
| `app-four/Views/Components/TimelineBead.swift` | token sizes (`Metrics.timeBead`), `.plexMono` fonts |
| `app-four/App/SquirlApp.swift` | DEBUG-only `-skipOnboarding` launch arg (for headless sim QA) |
| `app-fourTests/Views/DayCardExpandStateTests.swift` | NEW |
| `app-fourTests/Views/FoldedDayCardHeaderTests.swift` | NEW |
| `app-fourTests/ViewModels/MoodLibraryViewModelTests.swift` | added filter cases |

### Key decisions
- `@AppStorage("autoExpandOnSelection")` everywhere — NOT AppSettings/SettingsViewModel (that's disabled in this app).
- Summary line uses **FlowLayout** (not HStack) so long medication names wrap instead of truncating.
- Tests run **SERIALLY** (`-parallel-testing-enabled NO`) — project convention; parallel clones are flaky.
- `debugMockMode` UserDefaults must be cleared after screenshots or it poisons the test host (filters real data as mock).

### Verified on sim ✅
- Light + dark + largest Dynamic Type (A18 Pro, iPhone 16 Pro)
- Folded card, FlowLayout wrap, no-today-ring, future-day opacity, mood-wash card background

---

## What's missing (3 open tasks)

**T024** `[US4]` — VoiceOver: folded card = one combined element (`accessibilityElement(children:.combine)` is in code; needs live VoiceOver confirmation on sim), expanded rows individually focusable, mood glyph hidden.

**T025** `[US4]` — Greyscale (Color Filters) legibility + Reduce Motion makes fold/scroll instant + section order stable across data states.

**T028** — Run [quickstart.md](../../specs/014-daily-card/quickstart.md) scenarios end-to-end: expand/collapse, date-select filter-above, auto-expand toggle, light + dark.

All three need **tap injection + accessibility control** = XcodeBuildMCP (`xcrun mcpbridge`).

---

## XcodeBuildMCP
Configured as `xcode` server in `.claude/settings.local.json` (`xcrun mcpbridge`). Load only works in a **fresh session** — MCP servers attach at session start.

Once loaded, the `ios-debugger-agent` skill drives the flow. Pick up at T024.

---

## Next steps
1. Open a fresh Claude session in `/Users/caesargrey/Projects/app-four`
2. Confirm XcodeBuildMCP tools are live (`describe_ui`, `tap`, `screenshot` etc. appear)
3. `git checkout feat/daycard-update`
4. Run `/ios-debugger-agent` and close T024 → T025 → T028 in sequence
5. Mark all three `[X]` in `specs/014-daily-card/tasks.md`
6. Trigger `/code-review` on PR #10 diff (user-triggered, not CodeRabbit)
7. Merge PR #10 → `main`, update `docs/BACKLOG.md` (🔨 → ✅), tag if TestFlight build follows
