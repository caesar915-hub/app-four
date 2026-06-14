# Handover — Calendar Mood + Medication Check-in Timeline

**Date:** 2026-06-11
**Branch:** `main` (the user explicitly chose to work directly on main — this is intended)
**Plan:** [2026-06-11-calendar-mood-med-timeline.md](2026-06-11-calendar-mood-med-timeline.md)
**Mockups:** [v1](2026-06-11-calendar-timeline-mockup.html) · [v2](2026-06-11-calendar-timeline-mockup-v2.html) · [v3 (current/approved look)](2026-06-11-calendar-timeline-mockup-v3.html)

---

## ⚠️ READ FIRST — current state in one paragraph

The feature is **built, tested, and committed** to `main` (7 commits). A follow-up **polish phase is finished and verified but NOT yet committed** — it's sitting in the working tree. Two things remain: **(1) commit the polish**, and **(2) build an HTML mockup v4 that matches the final Swift exactly** (the user asked for this and it was not started). Everything compiles; all 23 unit tests pass; the app runs on the simulator and renders the Calendar timeline.

---

## What the feature is

The Calendar tab renders each day as a **vertical timeline**. Each node = one moment in time carrying a mood/voice check-in (a `Recording`, placed at `createdAt`) and/or one or more medication doses (a `MedicationEvent`, placed at `takenAt`).

- **Bead centre:** filled with the mood colour for a recording (gray if no mood); **hollow** for a medication-only node.
- **Rings:** one concentric **flat-purple** (`Palette.medication`) arc per medication dose active at that instant, **oldest = outermost**, max 3. A ring grows to a full circle at 99% and **disappears at 100%** (`activeRings` excludes `instant >= end`). The `%` label is truncated (`Int(progress*100)`) so a visible ring never reads "100%".
- **Same-instant events collapse into one node** (a recording + its live dose = one combined bead). A **back-dated** dose (spoken earlier time) stays a separate hollow node and also overlays the recording's node as an active ring.
- **Manual doses** (med-bar taps, no recording) appear as hollow med-only nodes. Voice notes with neither mood nor med appear as neutral gray nodes (nothing hidden).

### Locked design decisions (do not relitigate)
1. Percentages in mockups are illustrative; real progress = `MedicationEvent.effectProgress(at:)` over `durationHours` (default 10h).
2. Combined vs separate node rule above (live = merge; back-dated = separate + overlay).
3. Manual doses included; 4. neutral gray nodes for moodless notes; 5. active doses only, 3 most-recent, oldest-outermost.
6. **Flat purple** rings + % (NOT the med-bar colour ramp). Ring vanishes at 100%; % truncated.
7. **Dynamic Type:** at **accessibility text sizes** the percentages move OUT of the bead (which then shows only the time) into the row's content column; the bead grows modestly via `@ScaledMetric` (capped at 96pt). This replaced an earlier `minimumScaleFactor(0.5)` cramming hack.

---

## Git state

### Committed on `main` (in order)
| SHA | What |
|-----|------|
| `a77c6cf` | chore: delete `AppTwoUIPlayground` target + orphaned `MoodDaySection.swift` |
| `f2c22e2` | docs: plan + HTML mockups (v1/v2/v3) |
| `d9e590c` | feat: `DayTimelineBuilder` (pure merge logic) + 8 tests |
| `23a2c0d` | feat: `MoodLibraryViewModel.timelineDays` + 4 tests |
| `13509a2` | feat: `TimelineBead` |
| `718f170` | feat: `TimelineRow` |
| `f24c5fe` | feat: wire `CalendarLibraryView`; remove dead `DayGroup`/`groupedDays` |

### ⚠️ UNCOMMITTED in the working tree (the polish phase — verified, build green, 23 tests pass)
```
 M app-two/Views/Components/TimelineBead.swift      # adaptive Dynamic Type (relocate % at AX sizes, @ScaledMetric size cap 96, dropped minimumScaleFactor(0.5) multi-line hack, kept a single-line 0.7 guard on the time)
 M app-two/Views/Components/TimelineRow.swift       # @Environment(\.dynamicTypeSize) + shows the % line in the content column at accessibility sizes (accessibilityHidden — bead's label already announces them)
 M app-two/Views/Library/CalendarLibraryView.swift  # uses the new TimelineDaySection; removed the inline timelineSection(day:) func
?? app-two/Views/Components/TimelineDaySection.swift # NEW extracted day-section subview (header + ForEach of TimelineRow)
```
**To commit the polish (suggested):**
```bash
cd /Users/caesargrey/Projects/app-two
git add app-two/Views/Components/TimelineDaySection.swift \
        app-two/Views/Components/TimelineBead.swift \
        app-two/Views/Components/TimelineRow.swift \
        app-two/Views/Library/CalendarLibraryView.swift
git commit -m "refactor(calendar): extract TimelineDaySection + adapt bead to Dynamic Type

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Remaining work (TODO for the next session)

1. **Commit the polish changes** (command above).
2. **HTML mockup v4 matching the final Swift EXACTLY** — the user explicitly requested "make html css or js mockups that match exactly the swift design." Not started. It must reflect: flat-purple rings, ring-vanishes-at-100% (full circle at 99%), % purple, gray-track REMOVED (purple dot at 0%), mood-colour/hollow centres, oldest-outermost rings, connector line, uppercase titles — AND a **second variant showing the accessibility-text-size layout** (bead shows time only; percentages as a purple line in the content column). Base it on v3 ([2026-06-11-calendar-timeline-mockup-v3.html](2026-06-11-calendar-timeline-mockup-v3.html)) which is already very close; the only thing v3 lacks is the AX variant. Save as `2026-06-11-calendar-timeline-mockup-v4.html` and `open` it (per the user's working style — see memory `feedback-html-mockup-first`).
3. **(Optional) Fuller simulator visual check.** The default-size render is confirmed (see below) but rings/combined/multi-day weren't visually exercised because the sim's store was sparsely seeded. To see rings: erase the sim data so `MockDataGenerator` reseeds richer data (`xcrun simctl erase A97FF1D1-7C91-48CD-9988-962AC80EAAF9`), reinstall+launch, screenshot. Also grab an **accessibility text size** screenshot (Settings ▸ Accessibility ▸ Larger Text, or `xcrun simctl ui <udid> content_size accessibility-extra-extra-extra-large`) to confirm the % relocation visually.

---

## Verification status (evidence)

- **Unit tests:** 23/23 pass — `DayTimelineBuilderTests` (8) + `MoodLibraryViewModelTests` (4) + `MedicationBarViewModelTests` (11, regression). Last run after the polish: `** TEST SUCCEEDED **`.
- **Build:** `** BUILD SUCCEEDED **` for `app-two` on iPhone 17 sim, after the polish.
- **Simulator:** app launches straight to the Calendar tab and renders the timeline. Confirmed visually: month selector "JUN 2026", day header "MONDAY, 8 JUN", and a node — a **red filled bead "16:25"** (red = "low" mood) titled "LOW · ALERT", with the Liquid Glass tab bar (Calendar selected). This confirms bead + mood colour + header + month nav + tab rendering. **Not yet visually confirmed:** rings, combined nodes, multiple days, AX-size layout (store was sparsely seeded — see TODO 3).
- Screenshot saved at `/tmp/calendar_default.png` (ephemeral).

---

## File map

| File | Role |
|------|------|
| [app-two/ViewModels/DayTimeline.swift](../../../app-two/ViewModels/DayTimeline.swift) | `enum DayTimeline { Node, Ring }` + pure `DayTimelineBuilder.build(recordings:doses:)`. The core logic. |
| [app-two/ViewModels/MoodLibraryViewModel.swift](../../../app-two/ViewModels/MoodLibraryViewModel.swift) | `timelineDays` (groups recordings + fetched medication events by day), `TimelineDay`, med-event fetch + `.medicationEventsDidChange` observer. |
| [app-two/Views/Components/TimelineBead.swift](../../../app-two/Views/Components/TimelineBead.swift) | The circular bead: centre + concentric rings + in-bead time/%, adaptive Dynamic Type. |
| [app-two/Views/Components/TimelineRow.swift](../../../app-two/Views/Components/TimelineRow.swift) | One row: bead column + connector line + tappable content; % line at AX sizes. |
| [app-two/Views/Components/TimelineDaySection.swift](../../../app-two/Views/Components/TimelineDaySection.swift) | Day header + the day's `TimelineRow`s (extracted from CalendarLibraryView). |
| [app-two/Views/Library/CalendarLibraryView.swift](../../../app-two/Views/Library/CalendarLibraryView.swift) | The Calendar tab; renders `TimelineDaySection` per `timelineDays`. |
| [app-twoTests/ViewModels/DayTimelineBuilderTests.swift](../../../app-twoTests/ViewModels/DayTimelineBuilderTests.swift) | 8 builder tests. |
| [app-twoTests/ViewModels/MoodLibraryViewModelTests.swift](../../../app-twoTests/ViewModels/MoodLibraryViewModelTests.swift) | 4 VM tests. |

Reused (unchanged): `MedicationEvent.effectProgress(at:)`, `MedicationBarViewModel.effectColor` (NOT used — we chose flat purple), `Recording.moodColor` (`Recording+MoodDisplay.swift`), design tokens (`Palette.medication`, `Theme.*`, `Spacing.*`, `Typography.*`).

---

## Commands

```bash
cd /Users/caesargrey/Projects/app-two
SIM='platform=iOS Simulator,name=iPhone 17'   # NOTE: no iPhone 16 sims on this machine

# Build
xcodebuild build -scheme app-two -destination "$SIM" 2>&1 | tail -8

# Run the feature tests
xcodebuild test -scheme app-two -destination "$SIM" \
  -only-testing:app-twoTests/DayTimelineBuilderTests \
  -only-testing:app-twoTests/MoodLibraryViewModelTests \
  -only-testing:app-twoTests/MedicationBarViewModelTests 2>&1 | grep -E "Executed|TEST (SUCCEEDED|FAILED)" | tail

# Run on simulator + screenshot (mock data auto-seeds when the store is empty)
UDID=A97FF1D1-7C91-48CD-9988-962AC80EAAF9   # iPhone 17
APP="$HOME/Library/Developer/Xcode/DerivedData/app-two-egxmjviiwzarfodlbiqyyqgkaqhr/Build/Products/Debug-iphonesimulator/app-two.app"
xcrun simctl boot "$UDID"; xcrun simctl bootstatus "$UDID" -b
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" Rythm-App.app-two
xcrun simctl io "$UDID" screenshot /tmp/calendar.png
# erase to force a richer reseed:  xcrun simctl erase "$UDID"
```

---

## Environment notes / gotchas

- **XcodeBuildMCP is NOT available** in this environment (the `ios-debugger-agent` skill's `mcp__XcodeBuildMCP__*` tools don't load). Drive the simulator with `xcrun simctl` instead — note it cannot tap UI, but the app defaults to the Calendar tab on launch (`WhisperNotesApp.selectedTab = .calendar`), so no tap is needed. Onboarding (`fullScreenCover`) only shows on a truly empty store.
- **Xcode project is file-system-synchronized** (`PBXFileSystemSynchronizedRootGroup`). Files dropped into `app-two/…` and `app-twoTests/…` are auto-included — **do not** add them to `project.pbxproj` manually. For target-level surgery, the **`xcodeproj` Ruby gem is installed user-local**: `GEM_PATH="$HOME/.gem/ruby/2.6.0:$(gem env gempath)" ruby <script>`. (Removing a target also requires deleting its synchronized-group exception set + product ref + build configs — see how `a77c6cf` was done; scripts are in `/tmp/*.rb`, `project.pbxproj` backup at `/tmp/project.pbxproj.backup`.)
- **Bundle id:** `Rythm-App.app-two`. App entry: `app-two/App/WhisperNotesApp.swift`. Tabs: `Tab` enum in `RootTabView.swift`.
- **Mock data:** `MockDataGenerator.generate()` runs on the simulator (`#if targetEnvironment(simulator)`) only when `Recording` count is 0 (`AppModelContainer.swift`). It creates ~10 days × 2–4 recordings with random mood/energy/focus, ~50% with a linked `MedicationEvent` whose `takenAt == recording.createdAt` (so they form **combined** nodes; it does NOT create back-dated or manual-only doses, so those node types aren't exercised by mock data).
- **Pre-existing test debt (out of scope):** 11 failing NLP mood tests + 3 disabled VM suites needing a mock `AppServices` (memory `test-debt-followups`). Unrelated to this feature.

---

## Pointers
- Project memory index: `MEMORY.md` in the agent memory dir. Relevant: `feedback-html-mockup-first` (build HTML mockup before/with UI work — that's why TODO 2 matters), `feedback-working-style` (plan → ask → execute), `feedback-never-overwrite-files`, `project-liquid-glass-ui`.
