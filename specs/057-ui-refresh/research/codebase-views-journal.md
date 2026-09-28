<!-- Created: 2026-09-27 22:04 WEST · Updated: 2026-09-27 22:04 WEST -->
# Current SwiftUI map — journal / detail / edit / medication surfaces

Ground truth for the 057 UI-refresh plan. Read-only survey of the worktree at
`/Users/caesargrey/Projects/app-four/.claude/worktrees/057-ui-refresh` (branch `feat/057-ui-refresh`).
All paths below are relative to that root. Line numbers are from the files as read on 2026-09-27.
Nothing here is a proposal — it is what ships today, including the seams the redesign must decide on.

---

## 0. Quick reference — vocabulary that the new design must map onto

| Axis | Stored as (`Recording` column) | Canonical raw values 1→5 | `displayLabel` 1→5 | `subtitle` (synonym) 1→5 | Source of truth |
|---|---|---|---|---|---|
| Mood | `mood: String?` (`Models/Recording.swift:29`) | `low` · `flat` · `okay` · `good` · `great` | `Low` · `Flat` · `Okay` · `Good` · `Great` (`MoodLevel+Palette.swift:65-73`) | "heavy, muted" · "neutral, still" · "steady, fine" · "warm, lifted" · "bright, thriving" | `Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift:8-51` |
| Energy | `energyLevel: String?` (`:27`) | `sluggish` · `tired` · `steady` · `alert` · `charged` | `rawValue.capitalized` → `Sluggish` … `Charged` (`SignalLevel.swift:57`) | "slow, heavy" · "low, dim" · "moderate, stable" · "awake, ready" · "electric, on" | `Levels.swift:53-96` |
| Focus | `focusLevel: String?` (`:28`) | `foggy` · `distracted` · `present` · `sharp` · `lockedIn` | `Foggy` · `Distracted` · `Present` · `Sharp` · `Locked In` (`Levels.swift:113-121`) | "hazy, drifting" · "pulled, unsteady" · "grounded, there" · "clear, on track" · "deep, flowing" | `Levels.swift:98-150` |
| Sleep level | `sleepLevelValue: String?` (`:37`) | `restless` · `light` · `okay` · `good` · `deep` | **none defined** — views use `rawValue.capitalized` | "broken, tossing" · "thin, barely resting" · "decent, adequate" · "solid, rested" · "restorative, refreshed" | `Levels.swift:152-171` |
| Sleep hours | `sleepHours: Double?` (`:30`) | free double | "7h sleep" / "7.5h sleep" | — | `Models/Recording+MoodDisplay.swift:94-103` |
| Sleep quality (legacy) | `sleepQuality: String?` (`:31`) | validator writes a `SleepLevel` rawValue here too | "\(quality) sleep" | — | `Services/NoteExtraction/ExtractionValidator.swift:63, 427` |

Medication status words (bar): `kicking in` (<20 %) · `active` (20–80 %) · `wearing off` (80–100 %) · `worn off` (100 %) — `Views/Components/MedicationBarView.swift:79-86`.
Medication row states (edit sheet): `Taken` / `Missed` — `Views/ExtractionReviewView.swift:300`. Detail meds line suffix: `(missed)`, `×½`, `×2` — `Views/Components/ADHDSummarySection.swift:45-57`.
Medication change (`MedEventChange`): `regular` · `started` · `stopped` (`Services/NoteExtraction/NoteExtraction.swift:133-137`) → rendered as ` ↑` / ` ↓` suffix only in `displayTags` (`Recording+MoodDisplay.swift:82`).

Glyph mapping today (`GlyphSignal`, `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/GlyphSignal.swift:7-30`): mood = **sprout** (`Glyphs/SproutGlyph.swift`), energy = **bolt** (`Glyphs/BoltGlyph.swift`), focus = **aperture** (`Glyphs/ApertureGlyph.swift`), sleep = **bed** (`Glyphs/BedIcon.swift`, single icon, no ramp), medication = **two-tone capsule** (`Glyphs/CapsuleGlyph.swift`, single icon). The Pen design (Frame 12) names them bolt / target / sprout / **moon** with 5 levels each — sleep icon and sleep ramp are therefore new; "target" ≈ current aperture (confirm visually, do not assume).

---

## 1. Shared foundations

### 1.1 App shell and navigation
- Tabs: `enum Tab { calendar, checkIn, insights, settings }` — `Views/RootTabView.swift:5-10`. Tab bar labels "Calendar" / "Check in" / "Insights" / "Settings", SF symbols from `Icons` (`calendar`, `checkmark.circle`, `chart.bar.fill`, `gear`) — `RootTabView.swift:19-35`, `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Icons.swift:7-10`. Tint `Theme.meadowGreen` — `RootTabView.swift:36`.
- Every tab root is wrapped in `ScreenContainer` (`DesignSystem/ScreenContainer.swift:26-85`): `NavigationStack(path:)`, inline title, `NewLook.screen` background on screen + nav bar + tab bar (`:53-60`), optional `ScrollView` with `edgeFadeMask(top: 0, bottom: 36)` (`:78`), and the medication bar via `.medicationBarOverlay(shown:)` (`:79, :82`).
- Medication bar placement: `safeAreaInset(edge: .top)` with `Spacing.l` horizontal / `Spacing.s` top padding — `DesignSystem/MedicationBarOverlay.swift:13-26`. When hidden in Settings, zero space is reserved (`MedicationBarView.swift:12` guards on `showBar && !activeDoses.isEmpty`).
- `RecordingDetailView` is pushed by value: `NavigationPath.append(UUID)` → `.navigationDestination(for: UUID.self)` — `Views/Library/CalendarLibraryView.swift:47-54, :137`. Same destination is registered from Insights — `Views/InsightsView.swift:34`.

### 1.2 `RecordingStore` surface (`Store/RecordingStore.swift`)
- `recordings: [Recording]` sorted `createdAt` desc, filtered by `isMockData == debugMockMode` — `:47-59`.
- `save()` re-fetches and posts `.medicationEventsDidChange` so the bar and calendar VM refresh — `:74-85`.
- `deleteRecording`, `toggleFavorite`, `updateTitle`, `addCorrectionTags(_:for:)` — `:67-104`.
- `createCheckInNote(_:)` / `persistCheckInNote(_:)` build a `Recording` from `CheckInDraft` with `status: .completed`, `duration: 0`, `audioFileName: "text-<uuid>"`, title `"Mood · Energy · Focus"` (displayLabels) or first five note words or `"Check-in"` — `:106-170`. Draft meds become `MedicationEvent(source: .manual, recording: recording)` — `:156-167`.
- Orphan recovery at launch: `.transcribing` → `.failed` with transcript text "Transcription was interrupted. Tap to retry in the recording detail view." — `:34-45`.
- `AppServices` (`Store/AppServices.swift`) exposes `storageService`, `transcriptionService`, `summarizationService` (= `MLXJournalService`, `Store/AppDependencies.swift:27`), `exportService`, etc. Single `MedicationBarViewModel` instance lives on `AppDependencies.medicationBarViewModel` (`:9`) and is injected via `.environment`.

### 1.3 `Recording` model fields the journal surfaces read (`Models/Recording.swift`)
| Field | Line | Read by |
|---|---|---|
| `createdAt` | `:7` | day grouping, node time, nav date, meta line, edit-sheet date |
| `duration` / `formattedDuration` ("m:ss") / `durationString` | `:10`, `:122-126`, `:142` | detail meta line, `RecordingRow` |
| `status: RecordingStatus` (`recorded · transcribing · pendingTranscription · completed · failed · placeholder`) | `:12`; enum `Models/AppEnums.swift:5-15` | status pill, retry button, `displayTitle` |
| `fullTranscriptText` / `transcriptText` | `:13`, `:141` | Transcript card |
| `title` / `displayTitle` ("Transcribing…" / "Ready shortly…" / title) | `:14`, `:44-50` | detail title, row headline fallback |
| `summary`, `summaryStatus` (`notGenerated · generating · completed · failed`), `summaryBulletsJSON` → `summaryBullets` | `:19-20`, `:32`, `:145-150` | Summary card (bullets), `RecordingRow` checkmark |
| `hasMedication`, `medicationInfo` | `:25-26` | not rendered by these views (title only via `applySummary`) |
| `energyLevel`, `focusLevel`, `mood` | `:27-29` | everything (raw strings; see §0) |
| `sleepHours`, `sleepQuality`, `sleepLevelValue` → `decodedSleepLevel`, `sleepEventJSON` → `decodedSleepEvent` | `:30-31`, `:35`, `:37`, `:152-167` | sleep label / sleep card / edit sheet |
| `sideEffectsJSON` → `decodedSideEffects`, `emotionsJSON` → `decodedEmotions` | `:34`, `:36`, `:158-174` | chips, cards, edit sheet |
| `noteExtractionJSON` → `decodedNoteExtraction` (activities, triage arrays, `durationHours`) | `:33`, `:176-183` | edit-sheet round-trip only |
| `topicTagsJSON` → `topicCategories` (`Medications · Symptoms · Appointments · Procedures · General`) | `:21`, `:186-193`; `AppEnums.swift:62-90` | `displayTags` (RecordingRow) only |
| `medicationEvents: [MedicationEvent]` (cascade) | `:58-59` | meds line, chips, edit sheet, timeline nodes |
| `correctionTags: [RecordingTag]?` | `:55-56` | written on edit-sheet Save, never rendered |
| `isFavorite`, `cloudSyncStatus`, `isMockData` | `:15-16`, `:38` | favourite: VM method exists (`RecordingDetailViewModel.swift:30`), **no UI calls it** |

`applySummary(_:fillOnly:)` (`:202-284`) is the single writer of the signal columns: title becomes `"\(mood.capitalized) · \(energy.capitalized) · \(FocusLevel.displayLabel)"` (`:215-221`), JSON blobs are re-encoded, `summary` = bullets joined as "- …" lines (`:280`). `setMedicationEvents(from:durationHours:context:)` (`:301-344`) replaces `.transcript` rows, keeps `.manual` rows, defaults duration `med.durationHours ?? durationHours ?? 10.0` (`:331`).

### 1.4 `MedicationEvent` (`Models/MedicationEvent.swift`)
`name`, `dose: String?`, `takenAt`, `taken`, `quantity: Double?` (0.5 = half), `durationHours = 10.0`, `change: MedEventChange?`, `timeLabel` (raw phrase), `source: .manual | .transcript`, `recording: Recording?` — `:10-29`. `effectProgress(at:)` clamps 0…1 (`:68-72`), `isActive(at:)` = `taken && progress < 1` (`:75-77`). `resolvedTakenAt` parses "HH:mm", else fuzzy label → 8 / 13 / 19 / 22 h, else recording time — `:83-123`.
Catalog (`Models/MedicationCatalog.swift:20-39`): **Concerta** (18/27/36/54 mg, onset 60 min, 12 h), **Ritalin** (5/10/20 mg, 20 min, 3 h), **Elvanse** (20–70 mg, 90 min, 10 h). Copy rule in the doc-comment (`:16-18`): always present as typical ("≈", "may differ"), never guidance (App Review 1.4.1).

### 1.5 Design tokens actually used by these views
- Colours: `NewLook.screen #EFF2EB/#12140F`, `card #FFFFFF/#1C1E19`, `inkPrimary #1C1B1F/#F2F3EE`, `inkSecondary #8A8A8E/#9BA09A` (known AA failure in light, owner-locked — `NewLook.swift:22-25`), `hairline #DBDDDE/#33362F`, `tintNeutral #ECEAE6/#272A22`, `selection #54B492/#5FC49F`, `onSelection #FFFFFF/#1C1B1F`, `checkInGreen #5FB36E/#6FC47E`, `checkInGreenSoft #96C19F/#86BC9D` — `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/NewLook.swift:13-44`.
- `Palette.medication #7E5CA8/#957BC1`, `medicationFillEnd #AF99C3/#B3A1D6`, `warning #C2772E/#D98A3E`, `sleepIndigo #5566A6/#8E9BD4` — `Palette.swift:12-24`.
- Mood ramp base `#DA7A2A · #EDA94A · #9FCB79 · #5FB36E · #2E8B57`, partner `#EA9248 · #FDC06C · #B9DB9C · #7EC38A · #459B6B`, `wordColor` light `#8E470F · #8A5600 · #41691F · #2C6B3B · #1E5C38` / dark `#E89A5A · #EDA94A · #B7D897 · #79C98E · #57C98A`, `blockTint` = base @ 0.24, `badgeTint` = base @ 0.50 — `MoodLevel+Palette.swift:16-63`, `Opacity.swift:13-15`.
- Energy ramp `#7C6E2E · #A89236 · #D2BB40 · #EEDA4C · #FCEE64`; focus ramp `#44546E · #4E6F94 · #5889BA · #63A4E0 · #79C4FF` — `Palette+Signals.swift:10-33`.
- `Theme.accent #B8842A`, `meadowGreen #5F8A4C`, `meadowAmber #E0A33A`, `danger #B5503A`, `statusDone = meadowGreen` — `Theme.swift:8-16`.
- Typography (all SF, Dynamic-Type scaled): `title 22/semibold`, `moodWord 24/bold`, `headline 16/semibold`, `subheadline 14/medium`, `body 16`, `callout 15`, `caption 12`, `label 12/medium`, `mono12`, `duration` (mono 12), `text(size:weight:relativeTo:)` — `Typography.swift:21-64`.
- Spacing `xs 4 · s 8 · m 12 · l 16 · xl 20 · xxl 24 · section 32 · hero 40` — `Spacing.swift`. Radius `control 10 · chip 15 · card 16 · newLookCard 20` — `Radius.swift`. Metrics `minTapTarget 44`, `dayHeaderGlyph 40`, `summarySignal 15`, `rowSignal 12`, `rowMoodDisc 43`, `rowMoodGlyph 28`, `moreAffordance 21` — `Metrics.swift:10-34`.
- Card = `.newLookCard(padding:)` (white, radius 20, two-layer shadow 0.05/8/2 + 0.03/2/1, no border) — `NewLook.swift:52-66`. Chip = `.newLookChip(selected:role:)` (unselected: card fill + hairline; selected: role fill + `onSelection` ink; roles `standard` = meadowGreen, `medication` = purple, `checkIn` = checkInGreen) — `NewLook.swift:73-107`. `NewLookNavBar` = 24/bold centred title with leading/trailing pills — `NewLook.swift:116-148`.
- Motion: `snappy .snappy(0.3)`, `smooth .smooth(0.4)`, `expand .easeInOut(0.25)` — `Motion.swift:8-14`. Every animation is gated on `accessibilityReduceMotion`.

---

## 2. Screen A — Calendar / library tab

**Files:** `Views/Library/CalendarLibraryView.swift` (220 lines), `Views/Library/ExpandedDayCards.swift`, `Views/Library/CalendarStripFade.swift`, `Views/Components/CalendarHeaderView.swift`, `CalendarDayCell.swift`, `DayCard.swift`, `FoldedDayCardHeader.swift`, `DayCardSummary.swift`, `TimelineRow.swift`, `EdgeFadeMask.swift`.
**View models:** `ViewModels/MoodLibraryViewModel.swift` (owner of month + days), `ViewModels/CalendarMonthModel.swift` (pure grid), `ViewModels/DayTimeline.swift` (pure node builder). `RecordingRow.swift` is **not** mounted on this tab any more (its only live use is its own preview; grep shows no caller) — carry-over from the pre-034 list.

### 2.1 Structure top → bottom (as built)
1. `ScreenContainer(title: "", showsMedicationBar: true, scrollable: false, path: $path)` — `CalendarLibraryView.swift:29`. Nav bar has **no title**; medication bar sits under the nav bar as a safe-area inset.
2. `ZStack(alignment: .top)` — `:35`:
   - **Populated:** `timelineList` (`:117-157`) = `ScrollView { VStack { headerBlock; LazyVStack(DayCard…) } }` + `compactTitleBand` overlay (`:82-96`).
   - **Empty:** `pinnedHeader` (= `headerBlock`) + `ContentUnavailableView("No entries yet", systemImage: "calendar.badge.exclamationmark", description: "Record a voice note to see it here.")` — `:40-44`, `:208-214`.
3. `headerBlock` (`:98-113`) = `CalendarHeaderView` padded `Spacing.l` horizontal / `Spacing.s` top + `Divider()`.
   - `CalendarHeaderView` (`CalendarHeaderView.swift:38-45`): `VStack(spacing: Spacing.s) { header; weekdayCaps; grid }` with a horizontal `DragGesture(minimumDistance: 24)` paging months (`:116-122`).
   - `header` = month label button (`Typography.headline`, `monthLabel` "MMMM yyyy") + `chevron.right` rotating 90° when expanded — `:64-85`. At `dynamicTypeSize >= .accessibility1` the grid is force-collapsed to one week and the button becomes plain text — `:20-21`, `:49-55`.
   - `weekdayCaps` = `["M","T","W","T","F","S","S"]`, `Typography.caption`, `inkSecondary` — `:18`, `:87-96`.
   - `grid` = week rows (only the selected week when collapsed) of `CalendarDayCell` — `:98-114`.
   - `CalendarDayCell` (`CalendarDayCell.swift:15-41`): day number `Typography.callout`, bold when selected, `@ScaledMetric` 30 pt circle (max 40) filled `Color.primary` when selected with `systemBackground` number; 6 pt marker dot below: `.mood(color)` = average-mood deep colour, `.neutral` = `inkSecondary`, `.none` = clear (`:50-56`); future days `.disabled` + `tertiaryLabel`; out-of-month days `tertiaryLabel`; min height 44. AX label "<Weekday, d Month>, today, has check-ins | has entries | future | no check-ins" — `:58-67`.
4. Cards list: `LazyVStack(spacing: Spacing.m)` of `DayCard` for `viewModel.timelineDaysFilteredToSelectedDate(selectedDay)`, padded `l` horizontal, `m` top, `xxl` bottom — `:127-144`. `.edgeFadeMask(top: 0, bottom: Spacing.section)` — `:156`.
5. **Strip collapse:** `onScrollGeometryChange` → `CalendarStripFade.progress(offset:stripHeight:)` (dead zone 24 pt, min band 44, title reveal at 0.8) → strip opacity fades and `compactTitleBand` (day label `Typography.headline`, `NewLook.screen` background, hairline divider) snap-shows — `CalendarStripFade.swift:9-40`, `CalendarLibraryView.swift:73-96, :147-154`.

### 2.2 `DayCard` (folded ↔ expanded)
- Container: `VStack(spacing 0)`, background `NewLook.card`, clip `RoundedRectangle(Radius.newLookCard, .continuous)`, `.newLookCardShadow()` — `DayCard.swift:14-37`. Header is a `Button` → `onToggleExpand`; body appears only when `isExpanded && !day.nodes.isEmpty`: `VStack(spacing: Spacing.xxl)` of `TimelineRow`s padded `Spacing.l` — `:23-32`.
- **Folded header** (`FoldedDayCardHeader.swift:37-68`): `HStack(spacing m)` = `SignalGlyph(.mood, level, size: Metrics.dayHeaderGlyph=40)` · `VStack { foldedTitle; summaryLine | emptyCopy }` · `chevron.down`. Padding `l`/`m`, min height 44, background `level.blockTint` (mood base @ 0.24) or clear on an empty day.
  - `foldedTitle` = one concatenated `Text`: mood `displayLabel` in `Typography.moodWord` (24/bold) + `wordColor`, ` · `, weekday `"EEE"` uppercased in `text(13, .semibold)` tracking 1.3, `inkPrimary` — `:72-80`.
  - `summaryLine` = `FlowLayout(spacing s)` of chips with `·` separators; chip = `SignalGlyph(kind, level, size 15)` + `Typography.caption` text. Order: energy (`.primary`), focus (`.primary`), medication name (`Palette.medication`), sleep (`.primary`, bed glyph) — `:82-124`.
  - Empty day copy: `"No check-ins this day. That's alright."` — `DayCardSummary.swift:47`.
  - AX: single combined element, label "<day label>, <mood>, <energy>, <focus>, <med>, <sleep>", hint "Double tap to expand" — `:64-67`, `:159-163`.
- **Expanded header** = `collapsedBand` (`:128-155`): all-caps 13 pt "GREAT · MON" (mood word in `wordColor`), up-chevron, same `blockTint`, padding `l`/`s`.
- **Data (`DayCardSummary.swift`):** `mood` / `energy` / `focus` = rounded-half-up **average** across the day's recordings (`MoodLevel.average(of:)` etc., `Levels.swift:45-50`) → `displayLabel`; `mostRecentMedicationName` = newest node's first intake dose name only (no dose, no time) — `:29-31`; `sleep` = newest recording's `sleepLabel` — `:36-41`.

### 2.3 `TimelineRow` (one check-in inside an expanded card)
- `HStack(alignment: .top, spacing l) { disc; VStack(spacing s) { headline; chipLine } }` — `TimelineRow.swift:34-44`. Whole row is a `Button` → `onTapRecording(recording.id)` (hint "Opens recording detail"); a **dose-only node** (manual dose, no recording) renders the same row without the ⋯ and is not tappable — `:18-30`.
- `disc` = 43 pt `Circle` filled `level.badgeTint` (mood @ 0.50) or `NewLook.tintNeutral`, overlaid with `SignalGlyph(.mood, level, size 28)` — `:46-53`.
- `headlineText` = mood `displayLabel` in `moodWord` + `wordColor`, two spaces, time `HH:mm` (24 h, `text(13)`, `inkSecondary`). No mood → `recording.displayTitle` in `text(17, .semibold)`. Dose-only → time alone — `:70-85`.
- `moreAffordance` = 21 pt outlined `ellipsis` circle, 1.5 pt `inkSecondary` stroke, decorative — `:88-95`.
- `chipLine` (`:106-156`): `FlowLayout` with `·` separators, `Typography.caption`: energy (glyph 12 pt, text = **raw stored string**, `.primary`) · focus (glyph, **raw stored string**) · each distinct medication name (capsule glyph, purple) · sleep label (no glyph, `Palette.sleepIndigo`) · `"♥ " + feelings` (≤4, `+N` overflow, `inkSecondary`) · side effects (≤4, `+N`, `inkSecondary`).
- `DayTimeline.Node` (`DayTimeline.swift:9-31`) also carries `rings: [Ring]` (active dose progress at that instant, max 3) — **computed but no longer rendered** since spec 034 removed the phase ring (`TimelineRow.swift:3-8`).

### 2.4 Navigation and state
- Selection: tapping a `CalendarDayCell` → `selectDay` (pages month first if the cell is out-of-month) → `scrollList(to:)`: sets `selectedDay`, scrolls list to top edge, `expandedCards = expandedCards.selecting(date, autoExpand:)` — `CalendarLibraryView.swift:161-181`. Filtering is **tap/jump only**; scrolling never re-filters (`MoodLibraryViewModel.swift:102-110`).
- Month paging bounded to `[earliest month with data … current month]` — `:190-206`. Switching **to** the Calendar tab calls `jumpToToday()` (collapses strip, selects today); switching **away** pops the whole `NavigationPath` — `:57-62`, `:183-188`.
- Expand state: `ExpandedDayCards` value type (`ExpandedDayCards.swift:7-41`): `toggling` (independent per card), `selecting` (collapse all, open selected if auto-expand), `shouldExpand(_, alwaysExpand:)`.
- Day label (`MoodLibraryViewModel.swift:157-165`): `"Today, d MMM"`, `"Yesterday, d MMM"`, else `"EEEE, d MMM"`. Used by the compact band and AX only — the card itself shows the 3-letter weekday.
- Data pipeline (`MoodLibraryViewModel.swift:69-100`): month-scoped recordings + **taken** `MedicationEvent`s (manual + transcript, `:129-136`) grouped by start-of-day → `DayTimelineBuilder.build` (`DayTimeline.swift:44-67`: one node per distinct instant, newest first) → future days dropped, empty days skipped. `hasAnyEntries` = any recording **or** any dose — `:47-49`. `calendarMonth` = `CalendarMonthModel(month:days:today:)` — `:52-54`; marker rule `CalendarMonthModel.marker(for:)` — `CalendarMonthModel.swift:70-74`.

### 2.5 Settings that shape this screen
- `@AppStorage("autoExpandOnSelection") = true`, `@AppStorage("alwaysExpandCards") = false` — `CalendarLibraryView.swift:15-16`; UI rows "Always expand cards" / "Auto-expand selected day" in `Views/Settings/DayCardSettingsSection.swift:11-21`.
- `medicationBarVisible` / `medicationBarShowName` (see §5) change the safe-area inset height.
- `debugMockMode` (`UserDefaults`, `Views/TestServicesView.swift:12`, `App/SquirlApp.swift:25-35`) swaps the whole dataset.
- System Reduce Motion + Dynamic Type ≥ AX1 (force-week).

---

## 3. Screen B — Recording detail (`Views/RecordingDetailView.swift`, 322 lines)

**View model:** `ViewModels/RecordingDetailViewModel.swift` (`recording`, `showModelMissing`, `delete()`, `retryTranscription()`, `startRegenerate()`, `updateTitle/Date/Mood` — `:30-75`). Regenerate / `updateTitle` / `updateDate` / `updateMood` / `toggleFavorite` have **no UI entry point** in the current view (only `delete` and `retryTranscription` are wired — `RecordingDetailView.swift:78, :236`).

### 3.1 Chrome
- Plain `ScrollView` (not `ScreenContainer`) with `NewLook.screen` background, `.medicationBarOverlay()` (bar rides above as a shared seam — comment `:38-40`), inline nav bar with `toolbarBackground(NewLook.screen)` — `:24-44`.
- Principal toolbar item: `navDate` = `"EEE · d MMMM"` (e.g. "Sat · 27 September"), `Typography.label` uppercase tracking 0.6 `inkSecondary` — `:46-52`, `:109-112`.
- Trailing toolbar item: 44 pt circle (`NewLook.card` fill) with `pencil` glyph, AX "Edit check-in" → creates `ExtractionReviewViewModel(recording:store:onComplete:)` and presents `ExtractionReviewView` as `.sheet(item:)` — `:53-73`.
- Back = system back control (pushed from Calendar/Insights).
- Alert "Insights Model Not Downloaded" / "Your note is saved, but mood, energy and focus weren't extracted because the insights model isn't on this device yet. Download it from Settings › AI Models." — `:87-91`.
- Delete flow: bottom `Button("Delete check-in", role: .destructive)` in `Theme.danger` (`:302-310`) → `confirmationDialog("Delete this check-in?")` → `pendingDelete = true; dismiss()` → deletion happens in `onDisappear` (`:74-86`).

### 3.2 Sections top → bottom (`VStack(spacing: Spacing.m)`, padded `Spacing.l` — `:24-36`)
1. **titleBlock** (`:96-107`): `recording.displayTitle` in `Typography.title` (22/semibold) `inkPrimary`; `metaLine` `"<short time> · <m:ss>"` in `Typography.mono12` `inkSecondary` (`:114-117`). Note: for a text check-in `duration == 0` → "0:00" is shown.
2. **signalHeroStrip** (only if mood/energy/focus present — `:121-125`): `.newLookCard()` with up to three `heroColumn`s (`:127-161`): `SignalGlyph(kind, level, 30)` · word (`Typography.headline`) · `kind.title` uppercased `Typography.label` tracking 0.6 · 4 pt `levelBar` (capsule, `hairline` groove, tint fill width = level/5 — `:163-172`). Mood word = `mood.capitalized` tinted `level.deepFill`; energy/focus use `displayLabel` and `Palette.energyRamp/focusRamp[level-1]` (`:129-139`, `:174-181`). Focus/energy strings must match enum rawValue **verbatim** (comment `:132-133`).
3. **ADHDSummarySection** (`Views/Components/ADHDSummarySection.swift`) — a `VStack(spacing l)` of up to four `.newLookCard()`s, each headed by `Typography.headline` sentence-case text (`:24-28`):
   - "Medications" (only when there are `.transcript` events, sorted by `takenAt`): capsule glyph 18 pt + `medsLine` `"Name dose ×½ (missed) · Name2 …"` — `:15-19`, `:30-57`. **Manual doses logged inside a text check-in are excluded here** (filter `source == .transcript`).
   - "Sleep": one chip via `TagFlowView` — `decodedSleepLevel.rawValue.capitalized` else `"7h sleep"`, colour `Palette.sleepIndigo`, bed glyph — `:61-83`.
   - "Emotions": `decodedEmotions` capitalised, `heart.fill`, colour `Theme.accent` (bronze) — `:87-99`.
   - "Side effects": `decodedSideEffects` capitalised, `bandage.fill`, colour `Palette.warning` — `:103-115`.
   - `TagFlowView` chip = 15 pt glyph or SF symbol + `.caption/.medium` label, padding `s`/`xs`, background `tag.color.opacity(0.13)`, capsule — `Views/Components/TagFlowView.swift:6-27` (uses raw `.caption`, not `Typography`).
4. **summaryCard** (`:193-221`) if `summaryBullets` non-empty and ≠ `[fullTranscriptText]`: header "Summary", bullets as `Typography.body` paragraphs (line spacing 4), caption `Label("Written by on-device AI from your voice — tap Edit to correct", systemImage: "sparkles")`.
5. **transcriptSection** (`:225-262`): header "Transcript" + status pill (`Recorded` meadowAmber · `Transcribing` selection · `Completed` statusDone · `Failed` danger; `.pendingTranscription`/`.placeholder` show nothing — `:264-287`); `.failed` → `Button("Retry transcription").buttonStyle(.secondary)`; `.transcribing` → spinner + "Transcribing…"; empty → "No transcript available yet."; else body text.
6. **audioCard** (`:291-298`): header "Audio" + `AudioPlayerView` (`Views/Components/AudioPlayerView.swift:12-35`): 44 pt play/pause circle filled **`Palette.medication`** (purple — `:52`), `PlaybackWaveformBars` (32 seeded bars 4–24 pt, played bars `Theme.accent @ 0.6`, rest `tintNeutral`, tap-to-seek — `PlaybackWaveformBars.swift`), `mm:ss` in `Typography.duration`. Backed by `AudioPlaybackViewModel` (`AVAudioPlayer`, 250 ms polling, states `idle/loading/playing/paused/finished/error`). **Rendered for text check-ins too** (no audio file → `.error("Audio file not found")` on tap).
7. **deleteButton** — see §3.1.

### 3.3 Data fields → source
`displayTitle`, `createdAt`, `durationString`, `mood`, `energyLevel`, `focusLevel`, `summaryBullets`, `fullTranscriptText`, `status`, `medicationEvents(.transcript)`, `decodedSleepLevel`, `sleepHours`, `decodedEmotions`, `decodedSideEffects`, `id` (waveform seed) — all straight off `viewModel.recording` (a `@Model`, observed directly). Nothing is computed in the VM for display.

---

## 4. Screen C — Edit check-in sheet (`Views/ExtractionReviewView.swift`, 446 lines)

**View model:** `ViewModels/ExtractionReviewViewModel.swift` (310 lines). Presented as `.sheet(item: $editViewModel)` from the detail view; `presentationDetents([.large])`, drag indicator visible — `ExtractionReviewView.swift:53-54`.

### 4.1 Chrome
`NewLookNavBar("Edit check-in")` — leading `cancelPill` (44 pt circle, `chevron.backward` in `NewLook.checkInGreen`, AX "Cancel") → `viewModel.cancel(); dismiss()`; trailing `savePill` (capsule "Save" `Typography.headline` `checkInGreen`, AX "Save corrections") → `viewModel.confirm(); dismiss()` — `:34-38`, `:60-84`, `:442-445`. Background `NewLook.screen`. Cards in `VStack(spacing m)` padded `l`.

### 4.2 Cards top → bottom
1. **"When"** (`:118-147`): two `dateBox`es "Date" / "Time" (caption label + `DatePicker` bound to the same `viewModel.date`, max `Date()`, `Radius.control` box with hairline border).
2. **"Signals"** (`:151-184`): three `signalRow`s with eyebrows `MOOD` / `ENERGY` / `FOCUS` (`Typography.label` uppercase), right-aligned current value `"<displayLabel> · <subtitle>"` (name in `checkInGreen`, synonym in `inkSecondary` — `:107-114`), and a `GlyphRampPicker` (`Views/Components/GlyphRampPicker.swift`): five 30 pt glyphs in an `HStack(spacing m)`, selected one ringed 1.5 pt `Radius.control` in `checkInGreen`; tapping the selected level clears it; AX "<kind.title> <displayLabel>".
   Bindings: mood ↔ `viewModel.mood: String` via `MoodLevel(rawValue:)`; energy/focus ↔ typed optionals — `:186-194`.
3. **"Sleep"** (`:198-225`): header trailing `SignalGlyph(.sleep, 16)` + "no synonyms"; row 1 = `SleepLevel.allCases` chips `rawValue.capitalized` (`Restless · Light · Okay · Good · Deep`); row 2 = duration chips `2h · 4h · 6h · 8h · 10h` + `customHoursBox` (`TextField("7.5")` + "h", capsule, border `checkInGreen` when a custom value is active). Chips use `.newLookChip(role: .checkIn)`.
4. **"Medications"** (`:275-399`): header trailing "Stimulants · no limit"; one `selectedMedCard` per `viewModel.medications` (keyed `editRowID` = `name|time|timeLabel|quantity` — `ExtractionReviewViewModel.swift:309`): capsule glyph 22 pt, name `subheadline/semibold`, `Taken`/`Missed` toggle pill (purple fill when taken), `xmark` remove; for catalog meds a `Grid` with eyebrows `Dose` (dose chips, role `.medication`), `Time` (`"\(med.time ?? "08:00") · info"` — **time is not editable**), `Dur` (`DurationField` + "shortest"); card border `Palette.medication @ 0.35`, radius 20. Below: `medGrid` = catalog chips (Concerta / Ritalin / Elvanse) toggling add/remove-all; helper caption "Tap to add · expands inline · × to remove · independent events".
5. **"Emotions"** (`:403-422`): two eyebrow groups — `Pleasant`: excited, joyful, proud, thrilled, inspired, content, grateful, peaceful, secure, serene; `Unpleasant`: angry, anxious, frustrated, irritated, jealous, sad, lonely, disappointed, hopeless, discouraged (`:17-22`, hard-coded copy of `Lexicon.defaultEmotions`, `Services/NoteExtraction/Lexicon.swift:271-278`). Chips capitalised, toggle.
6. **"Side effects"** (`:424-438`): hard-coded 15 — dry mouth, headache, nausea, appetite gone, insomnia, jittery, heart racing, stomach ache, dizzy, irritable, rebound, crash, sweating, grinding teeth, flat affect (`:24-28`). **Not** the same list as `Lexicon.defaultSideEffectCues` (`Lexicon.swift:311-318`, 30 cues) — a stored side effect outside the 15 (e.g. "palpitations") is shown nowhere in the sheet but is preserved on Save because the set is seeded from `decodedSideEffects`.

### 4.3 View-model contract (`ExtractionReviewViewModel.swift`)
- Seeded from the recording via a `SummaryResult` rebuilt from columns (`:61-103`); `.transcript` `MedicationEvent`s are mapped back to `MedEvent` with `time` = "HH:mm" of `takenAt` and the persisted `durationHours` (`:68-85`). **Manual doses attached to the recording are not editable here.**
- `name` is editable in the VM (`:10-19`) but the sheet has **no title field**; auto-title `"Mood · Energy · Focus"` is regenerated on confirm (`:196-201`).
- `confirm()` (`:191-295`): sets `recording.createdAt = date` first, rebuilds `NoteExtraction` + `SleepEvent`, calls `applySummary` and `setMedicationEvents`, writes `RecordingTag` provenance rows (`source: .userCorrected` if the field was touched, else `.llm`; categories mood/energy/focus/medication/emotions — sleep and side effects get no tag), `store.save()`, `onComplete`.
- `cancel()` (`:297-302`): if `summaryStatus != completed` it is set to `failed`.
- Sleep setters: `setSleepLevel`, `setSleepHours`, `setSleepHours(fromString:)` (comma → dot) — `:122-136`.

### 4.4 Related composer (for vocabulary parity only)
The text check-in composer (`Views/CheckIn/TextCheckInComposer.swift:141`) uses the same `GlyphRampPicker`; `CheckInDraft` (`Models/CheckInDraft.swift`) carries `mood/energy/focus` as enums, `sleepQuality: String?`, `meds: [DraftMedication]` (`name`, `dose`, `takenAt`, `durationHours = 10`), `note`. Voice path writes via `ProcessingViewModel.swift:97` / `PendingTranscriptionServiceImpl.swift:124` → `applySummary`.

---

## 5. Screen D — Medication bar and Log Dose sheet

**Files:** `Views/Components/MedicationBarView.swift` (193 lines), `Views/Components/MedicationLogSheet.swift` (203 lines). **View models:** `ViewModels/MedicationBarViewModel.swift` (app-singleton), `ViewModels/MedicationPickerViewModel.swift`.

### 5.1 Bar
- Visible only when `@AppStorage("medicationBarVisible")` is true **and** `activeDoses` non-empty — `MedicationBarView.swift:8, :12`. Card `.newLookCard(padding: Spacing.m)`, rows separated by hairline `Divider`s — `:13-19`.
- Row (`:51-75`): `SignalGlyph(.medication, 24)` · `titleLine` `"HH:mm · Name Dose"` (`text(15, .semibold)`; with `medicationBarShowName == false` only `"HH:mm"`) · spacer · state word (`Typography.label`, uppercase, tracking 0.5, `Palette.medication`) · `DoseTrack`.
- `DoseTrack` (`:133-174`): 19 pt capsule, groove `tintNeutral`, fill `LinearGradient(medication → medicationFillEnd)` width = progress, min width 19; opacity pulses 1 ↔ 0.55 every 1.3 s while `progress < 0.2` and Reduce Motion is off.
- Tap a row → `confirmationDialog` titled `"Name Dose"` with `Log new dose` / `Delete this dose` (destructive) / `Cancel` — `:20-39`. "Log new dose" presents `MedicationLogSheet` — `:40-44`.
- AX label: `"<ordinal> dose, Name Dose, taken at HH:mm, NN% elapsed, ends HH:mm. Tap to manage."` — `:106-122`.
- VM (`MedicationBarViewModel.swift:59-109`): fetches `taken == true`, `takenAt > now-24h`, `isMockData == mock`, keeps ≤3 whose `takenAt + durationHours*3600 > now`, ordered oldest → newest; `DoseDisplay` = `eventID, name, dose, effectiveDose, takenAt, endsAt, doseNumber, totalDosesToday, progress`. Refreshes on `.medicationEventsDidChange`. `logManualDose(name:dose:takenAt:durationHours:)` inserts `source: .manual`, `recording: nil` — `:111-124`.
- No onset/catalog awareness in the bar: the state word is purely fill-fraction based (0.2 / 0.8 thresholds), not `MedicationCatalogEntry.onsetMinutes`.

### 5.2 Log Dose sheet (`MedicationLogSheet.swift`)
- Custom `sheetNav` (`:36-64`): 30 pt `xmark` circle (card fill, hairline border, AX "Cancel") · title "Log Dose" `Typography.title` · "Save" (`subheadline/semibold`, `Theme.meadowGreen`, disabled/`inkSecondary` when name empty). **Different nav idiom** from the Edit sheet's `NewLookNavBar`.
- Sections (eyebrow `Typography.label/semibold` `inkSecondary`, each in `.newLookCard()`):
  1. "Medication": horizontal chip picker of `viewModel.pickableNames` (catalog first, then history names deduped by base name — `MedicationPickerViewModel.swift:40-50`), selected chip `Palette.medication @ 0.25` + purple 1 pt border, unselected `tintNeutral`; hairline; `TextField("Name")`.
  2. "Dose": catalog med → `Picker` menu (`"—"` + `doseOptions`) + row `Onset` / `"≈ N min"` + caption "Typical values from product labeling — your response may differ."; free-text med → `TextField("Dose (optional)")`.
  3. "Effect Duration": `Hours` + numeric `TextField` (60 pt, decimal pad).
  4. "Taken At": `DatePicker(hourAndMinute, max now)`.
- Picking a catalog name auto-fills `durationHours` and the first dose option — `:192-198`.
- Callback `onLog(name, dose?, takenAt, durationHours)` → `viewModel.logManualDose` — `MedicationBarView.swift:41-43`.

### 5.3 Settings that shape the bar
`Views/Settings/MedicationBarSettingsSection.swift:9-21`: "Show Medication Bar" (`medicationBarVisible`, hint "Shows a medication progress bar at the top of each screen.") and, when on, "Show Medication Name" (`medicationBarShowName`, hint "Displays the medication name and dose in the bar."). `debugMockMode` filters events. Dose guard (`Models/DoseGuardMode.swift`, `AppSettings.doseGuardModeRaw/doseGuardWindowHours`) governs **expedited** logs only (Shortcuts/sticker) — the in-app sheet never consults it (`:4-5`).

---

## 6. Cross-cutting facts

### 6.1 Where each signal string comes from
- **LLM path:** `MLXJournalService` → `ExtractionValidator` normalises mood/energy/focus to enum `rawValue` (`ExtractionValidator.swift:51-63`) and `sleepQuality` to a `SleepLevel` rawValue; `SummaryResult.sleepLevel = sleepQuality ?? deriveSleepLevel(hours)` (thresholds <5 restless, <6 light, <7 okay, <9 good, else deep — `:759-766`, `:884`). The only `sleepLevel: nil` in `MLXJournalService.swift:144-160` is the `emptyResult()` fallback for an empty note, so on the live path `sleepLevelValue` is populated whenever hours or quality were extracted.
- **Text composer:** enum `rawValue`s written directly (`RecordingStore.swift:149-152`); `sleepQuality` string from the draft.
- **Edit sheet:** enum `rawValue`s via `confirm()`.
- Consequence: `focusLevel` is stored as `"lockedIn"`. Views that show it **raw** (`TimelineRow.swift:135`, `Recording+MoodDisplay.swift:16-21, :48`) print "lockedIn"; views that map through the enum (`FoldedDayCardHeader`, `RecordingDetailView`, `ExtractionReviewView`, `applySummary` title) print "Locked In". Energy raw values happen to equal their lower-cased labels so the seam is invisible there.

### 6.2 Sleep — three coexisting representations
`sleepHours: Double?` (chip "7h sleep"), `sleepLevelValue: String?` (`SleepLevel`, chip "Deep"), `sleepQuality: String?` (legacy string, only used as a label fallback and in `SummaryResult`), plus `sleepEventJSON` (`SleepEvent`: `mentioned, hours, quality, bedtime, wakeTime, latencyMinutes` — `NoteExtraction.swift:173-196`) which `sleepLabel` prefers over the columns (`Recording+MoodDisplay.swift:94-103`). Calendar shows hours-first ("7h sleep" / "deep sleep"), detail Sleep card shows level-first ("Deep" / "7h sleep"), edit sheet edits both independently. There is **no sleep glyph ramp** (`BedIcon` is a single icon; `GlyphSignal.sleep.variesByLevel == false`).

### 6.3 Emotions and side effects
- Emotions: `emotionsJSON` on `Recording`, filtered at extraction to `Lexicon.emotions` (`ExtractionValidator.swift:405-406`); the edit sheet's 20-item list is a hard-coded mirror. `RecordingTag(category: .emotions)` rows are written on edit but never read by UI (`Models/RecordingTag.swift`, `TagCategory` = mood/energy/focus/medication/emotions; `TagSource` = nlp/user/userCorrected/llm).
- Side effects: `sideEffectsJSON`, normalised by `normalizeSideEffects` (`ExtractionValidator.swift:418`) against `Lexicon.defaultSideEffectCues` (30 cues, `Lexicon.swift:311-318`). No `RecordingTag` category exists for side effects or sleep.
- Rendering caps: calendar row shows ≤4 feelings / ≤4 side effects with `+N` (`Recording+MoodDisplay.swift:106-113`); detail cards show all.

### 6.4 Medication vocabulary summary
| Surface | Words | File |
|---|---|---|
| Bar state | kicking in · active · wearing off · worn off | `MedicationBarView.swift:79-86` |
| Bar title | "HH:mm · Name Dose" | `:99-104` |
| Bar dialog | Log new dose · Delete this dose · Cancel | `:28-38` |
| Log sheet | Log Dose · Medication · Dose · Onset ≈ N min · Effect Duration · Hours · Taken At · Save | `MedicationLogSheet.swift` |
| Calendar chips | name only | `FoldedDayCardHeader.swift:117-119`, `TimelineRow.swift:137-139` |
| Detail card | "Name dose ×½ (missed) · …" | `ADHDSummarySection.swift:45-57` |
| Edit sheet | Taken / Missed · Dose · Time · Dur · "Stimulants · no limit" | `ExtractionReviewView.swift:277-346` |
| `displayTags` (RecordingRow, unused) | "Name ½ ↑/↓" | `Recording+MoodDisplay.swift:78-86` |
| Change enum | regular · started · stopped | `NoteExtraction.swift:133-137` |

### 6.5 Settings / preferences influencing these views (complete list)
| Key | Default | Set in | Read in |
|---|---|---|---|
| `autoExpandOnSelection` | true | `DayCardSettingsSection.swift:7` | `CalendarLibraryView.swift:15` |
| `alwaysExpandCards` | false | `DayCardSettingsSection.swift:8` | `CalendarLibraryView.swift:16` |
| `medicationBarVisible` | true | `MedicationBarSettingsSection.swift:5` | `MedicationBarView.swift:8` |
| `medicationBarShowName` | true | `MedicationBarSettingsSection.swift:6` | `MedicationBarView.swift:9` |
| `debugMockMode` (UserDefaults) | false | `TestServicesView.swift:12`, `SquirlApp.swift:25-35` | `RecordingStore.swift:49`, `MoodLibraryViewModel.swift:130`, `MedicationBarViewModel.swift:61, :120` |
| System Reduce Motion | — | iOS | every animated view |
| System Dynamic Type | — | iOS | `CalendarHeaderView.swift:20` (force-week ≥ AX1), all `Typography` |
`AppSettings` (`Models/AppSettings.swift`) fields — `defaultMedicationName/Dose`, `doseGuardModeRaw`, `doseGuardWindowHours`, `nameMedicationInConfirmations`, `promptPaceSeconds` — affect Check-in / Intents, **not** these four surfaces.

---

## 7. Existing tests (Swift Testing, `app-fourTests/`)

| Test file | `@Test` count | Covers |
|---|---|---|
| `ViewModels/MoodLibraryViewModelTests.swift` | 9 | empty state, manual-dose-only day, node merge, untaken excluded, month filtering newest-first, no future days, selected-date filter (`:33-151`) |
| `ViewModels/CalendarMonthModelTests.swift` | 3 | Monday-first grid, today/future flags, marker mood/neutral/none |
| `ViewModels/DayTimelineBuilderTests.swift` | 8 | node merge, back-dated dose, ring order/cap/expiry, hollow node, newest-first |
| `Views/DayCardExpandStateTests.swift` | 8 | `ExpandedDayCards` toggling/selecting/shouldExpand |
| `Views/CalendarStripFadeTests.swift` | 10 | dead zone, clamping, quantisation, title reveal |
| `Views/FoldedDayCardHeaderTests.swift` | 13 | `DayCardSummary` averaging (half-up), most-recent med, sleep fallback, empty copy |
| `Models/DayCardPaletteTests.swift` | 5 | blockTint/badgeTint opacities, wordColor AA on tint, pinned mood tokens |
| `Models/RecordingMoodDisplayTests.swift` | 7 | mood hex SSOT, displayLabels, feelings/side-effects cap + overflow, sleepLabel |
| `ViewModels/RecordingDetailViewModelTests.swift` | 3 | regenerate cancels previous task, retry saves once, delete |
| `ViewModels/ExtractionReviewViewModelTests.swift` | 12 | title preservation/auto-title, med time vs new date, JSON parity, provenance tags, sleep comma parsing, cancel status |
| `ViewModels/MedicationBarViewModelTests.swift` | 14 | duration default, ≤3 active, ordinals, progress, expired/missed hidden, delete, cascade |
| `ViewModels/MedicationPickerViewModelTests.swift` | 5 | merge order, base-name folding, catalog lookup |
| `Models/MedicationCatalogTests.swift` / `MedEventDurationTests.swift` / `DoseGuardModeTests.swift` | 7 / 2 / 9 | catalog resolution, effect window, guard modes |
| `Models/RecordingApplySummaryTests.swift` / `RecordingDisplayTitleTests.swift` | 9 / 3 | `applySummary` column + JSON writes, `displayTitle` states |
| `SignalGlyphTests.swift` | 9 | `clampedSignalLevel`, `signalName`, `signalSynonym`, AX label |
| `Store/RecordingStoreTests.swift` / `CheckInNoteStoreTests.swift` | 8 / 5 | store CRUD, text check-in creation |

No snapshot/UI tests exist; the "view" tests above exercise pure value types (`ExpandedDayCards`, `CalendarStripFade`, `DayCardSummary`). `CalendarLibraryView`, `DayCard`, `TimelineRow`, `RecordingDetailView`, `ExtractionReviewView`, `MedicationBarView`, `MedicationLogSheet` bodies are untested — any redesign that keeps the pure helpers intact keeps 60+ tests green; renaming labels (`displayLabel`, `emptyCopy`, state words) breaks `FoldedDayCardHeaderTests`, `RecordingMoodDisplayTests`, `SignalGlyphTests`.

---

## 8. Seams and inconsistencies the plan must decide on (observed, not fixed)

1. **Raw vs display focus label** — `TimelineRow` chips and `Recording.headline` print `"lockedIn"`; every other surface prints `"Locked In"` (§6.1).
2. **Two nav idioms on sheets** — Edit sheet uses `NewLookNavBar` + 44 pt green pills; Log Dose uses a bespoke 30 pt `xmark` + meadow-green "Save" text (§4.1 vs §5.2).
3. **Two chip grammars** — `.newLookChip` (Edit sheet) vs `tag.color.opacity(0.13)` capsule (`TagFlowView` on detail) vs `Palette.medication.opacity(0.25)` capsule (Log sheet) vs dot-separated bare text+glyph (calendar).
4. **Sleep chip styling differs by state** — folded header: bed glyph + primary ink; expanded row: no glyph + indigo text (`TimelineRow.swift:140-144` cites a01 nodes as the reason).
5. **Emotion colour** — bronze `Theme.accent` on detail (`ADHDSummarySection.swift:89`) vs `.pink` in `displayTags` vs `inkSecondary` "♥ …" on the calendar row.
6. **Play button is medication purple** (`AudioPlayerView.swift:52`) and the audio card renders for text check-ins with no file.
7. **Detail "Medications" card hides manual doses** logged inside a text check-in (`.transcript` filter), while the calendar row and bar show them.
8. **Edit sheet cannot edit** the dose time, manual doses, sleep glyph level, or the title (VM supports `name`).
9. **Dead code / unused surfaces**: `RecordingRow` + `Chip` (`Views/Components/Chip.swift`) + `displayTags`/`chipTags` have no live caller; `DayTimeline.Ring` is built but never drawn; `RecordingDetailViewModel.toggleFavorite/updateTitle/updateDate/updateMood/startRegenerate` have no UI; `Card.swift` `cardEyebrow()` is no longer used by these four screens (its one remaining caller is `Views/Settings/StickerSetupView.swift:241`, which is unmounted for 1.1).
10. **Duration "0:00"** meta line and `Recorded`-amber pill semantics for text check-ins; `.pendingTranscription` has no status pill.
11. **`inkSecondary` light `#8A8A8E`** fails AA on `screen`/`card` for body text — owner-locked (`NewLook.swift:22-24`); the Pen palette (Frame 5) ships its own neutral 50–900 ramp with contrast values, so this decision should be revisited explicitly rather than inherited.
12. **Side-effect vocabulary split** — 15 chips in the sheet vs 30 lexicon cues; stored values outside the 15 are invisible in the editor.
13. **Nav title empty** on the Calendar tab (`ScreenContainer(title: "")`) with the date context carried by the in-content compact band — a Pen tab-bar/nav design (Frame 4) will need to state where the date lives.
