<!-- Created: 2026-09-27 22:27 WEST · Updated: 2026-09-27 22:27 WEST -->
# Gap analysis — pen "iPhone 17 - 19" (Mood Journal · Calendar tab) vs the shipping SwiftUI

Inputs: `out/screens/mood-journal.md` (screen spec, read fully), `pen/named/iphone17-19-mood-journal.png`, `out/design-system.md`, the three codebase maps, `out/constraints.md`, and the Swift files named below (opened directly; line numbers are from the worktree `feat/057-ui-refresh` at `08ba8cba`, read 2026-09-27). All repo paths are relative to `/Users/caesargrey/Projects/app-four/.claude/worktrees/057-ui-refresh/`.

Planning only. No Swift was changed; nothing here authorises a change. Where the pen is ambiguous the entry says so and points at the owner question (§6) instead of guessing.

Conventions: **KEEP** = already matches (data and behaviour; styling may still take tokens) · **CHANGE** = exists, restyle/rearrange · **NEW** = does not exist · **REMOVE** = exists today, absent in the pen. "Pen" values are quoted from the screen spec verbatim (Inter sizes, hex, pt).

---

## 1. Mapping — what implements this surface today

| Pen region | Current view(s) | View model / model | Notes |
|---|---|---|---|
| Whole tab | `app-four/Views/Library/CalendarLibraryView.swift` (`ScreenContainer(title: "", showsMedicationBar: true, scrollable: false, path:)` at `:29`; `ZStack` `:35-46`; `timelineList` `:117-157`; empty state `:208-214`) | `app-four/ViewModels/MoodLibraryViewModel.swift` (`currentMonth :16`, `monthLabel :41`, `hasAnyEntries :47-49`, `calendarMonth :52-54`, `timelineDays :69-100`, `timelineDaysFilteredToSelectedDate :107-110`, `dayLabel :157-165`) | Tab root is `RootTabView.swift:20-22`; chrome from `app-four/DesignSystem/ScreenContainer.swift:49-61` |
| §2.2 Medication bar card | `app-four/Views/Components/MedicationBarView.swift` (card `:13-19`, row `:51-75`, `stateWord :79-86`, `DoseTrack :133-174`), pinned by `app-four/DesignSystem/MedicationBarOverlay.swift:18-23` (`safeAreaInset(edge: .top)`, padding `Spacing.l` / `Spacing.s`) | `app-four/ViewModels/MedicationBarViewModel.swift` (`DoseDisplay :25-38`, `refresh :59-109`, `progress :95`); `app-four/Models/MedicationEvent.swift:12-19, 68-72`; `app-four/Models/MedicationCatalog.swift` | App-wide singleton, shown on every tab, not a Calendar-only element |
| §2.3 Month header | `app-four/Views/Components/CalendarHeaderView.swift` `header :47-62`, `expandButton :64-85` (`chevron.right` rotating 90° when the month grid is open) | `monthLabel` "MMMM yyyy" | Today the chevron toggles week ↔ month grid, it does not page months |
| §2.4 Week strip | `CalendarHeaderView.swift` `weekdayCaps :87-96` (`["M","T","W","T","F","S","S"]` `:18`), `grid :98-114`, `monthSwipe :116-122`; `app-four/Views/Components/CalendarDayCell.swift:15-41` | `app-four/ViewModels/CalendarMonthModel.swift` (`DayMarker :5-9`, `DayCell :16-24`, `marker(for:) :70-74`) | Force-collapses to one week at `dynamicTypeSize >= .accessibility1` (`CalendarHeaderView.swift:20`) |
| §2.5 Expanded day card | `app-four/Views/Components/DayCard.swift:16-38` + `app-four/Views/Components/FoldedDayCardHeader.swift` `collapsedBand :128-146` + `app-four/Views/Components/TimelineRow.swift:34-44` per check-in | `app-four/Views/Components/DayCardSummary.swift` (day averages); `app-four/ViewModels/DayTimeline.swift` (`Node :9-20`, `build :44-67`); `app-four/Views/Library/ExpandedDayCards.swift:22-39` (expand state) | Selected day is the first card of the filtered list; auto-expanded via `expandedCards.selecting` (`CalendarLibraryView.swift:179`) |
| §2.6 "Previous Days" cards | Same `DayCard`, folded state = `FoldedDayCardHeader.foldedContent :37-68` | `DayCardSummary` | **No "Previous Days" heading exists**; the list is one `LazyVStack` (`CalendarLibraryView.swift:127-144`) whose first card is the selected day |
| Compact title band on scroll | `CalendarLibraryView.swift:82-96` + `app-four/Views/Library/CalendarStripFade.swift:9-41` | — | Not in the pen (spec §2.9: no scrolled state drawn) |
| §2.7 Tab bar + FAB | `app-four/Views/RootTabView.swift:19-36` — native `TabView` with `.tabItem { Label(_, systemImage: Icons.*) }`, `.tint(Theme.meadowGreen)`; tab-bar background forced to `NewLook.screen` in `ScreenContainer.swift:59-60` | `Tab` enum `RootTabView.swift:5-10`; icons `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Icons.swift:7-10` | **FAB does not exist.** Check In is the second tab |
| Row tap → detail | `TimelineRow.swift:21` → `onTapRecording` → `path.append(UUID)` `CalendarLibraryView.swift:137` → `navigationDestination` `:47-54` → `app-four/Views/RecordingDetailView.swift` | `RecordingDetailViewModel` | Pen: row is a list item, destination = iphone17-1 |
| Row ⋯ overflow | `TimelineRow.swift:88-95` — decorative only (`accessibilityHidden(true)`), no menu | edit: `ExtractionReviewViewModel` (instantiated in `RecordingDetailView.swift:55-59`); delete: `MoodLibraryViewModel.delete(_:)` `:147-149` (no UI caller) | **Menu does not exist** |
| Settings that shape the screen | `app-four/Views/Settings/DayCardSettingsSection.swift:7-8, 11-21` (`alwaysExpandCards`, `autoExpandOnSelection`); `MedicationBarView.swift:8-9` (`medicationBarVisible`, `medicationBarShowName`) | `@AppStorage` | Pen Settings (iphone17-16) also lists "Show Taken Time" / "Show End Time" — **neither exists** |

Not on this screen today and not in the pen: nothing else. The old DESIGN.md rule "Calendar. Unchanged … do not redesign without explicit ask" (constraints §3.7) is superseded by the owner's "pen file is the source of truth" — log it as a dated decision.

---

## 2. Delta table, section by section

### 2.0 Frame / ground

| Item | Pen | Code | Verdict | What changes |
|---|---|---|---|---|
| Screen ground | `#fbfffc` (off-palette) | `NewLook.screen` `#EFF2EB` / dark `#12140F` (`NewLook.swift:13`) via `ScreenContainer.swift:53-54` | CHANGE | One token swap at the DS level; needs a derived dark value (pen has none) |
| Content gutter | 30 pt (cards 342 wide) | `Spacing.l` = 16 on the list (`CalendarLibraryView.swift:141`) and on the header (`:108`) | CHANGE | 16 → 30 is a large jump; pen's own gutters drift 28–31 across screens (design-system §3.1). Decide one app-wide gutter token; do not hard-code 30 on this screen |
| Vertical rhythm | Column gap 24 between blocks; cards gap 8 | Header→list `Spacing.m` (12), cards `Spacing.m` (12) (`:127, :142`) | CHANGE | Card gap 12 → 8; section gap 12 → 24 |
| Nav bar | none (no title, no pills) | `navigationTitle("")` inline, opaque `NewLook.screen` toolbar background (`ScreenContainer.swift:51-54`) | KEEP | Already title-less; only the background token changes |
| Card surface (shared) | white, r **12**, 0.5 pt `#000000@10%` inside stroke, shadow `#183c28@8%` (0,3,8) | `.newLookCard()` r **20**, no border, two-layer black shadow (`NewLook.swift:52-66`); `DayCard` reuses `Radius.newLookCard` + `.newLookCardShadow()` (`DayCard.swift:14, 35-37`) | CHANGE (DS-level) | New card style token: radius 12, hairline stroke, tinted shadow. Contradicts the New Look "never a card border" rule — that rule is retired with the pen |

### 2.1 Status bar
KEEP — system-drawn. Nothing to build (design-system §6).

### 2.2 Medication bar card

| Item | Pen | Code | Verdict | What changes |
|---|---|---|---|---|
| Container | 342 × 140, white, r 12, 0.5 pt hairline, shadow (0,3,8) `#183c28@8%`, padding 11, rows gap 14, 1 pt `#000@10%` divider | `.newLookCard(padding: Spacing.m)` (`MedicationBarView.swift:19`), `VStack(spacing: Spacing.s)`, `Divider().overlay(NewLook.hairline)` (`:15`) | CHANGE | Card style per §2.0; padding 12 → 11; row gap 8 → 14 |
| Placement | top of the content column at y 76, under the status bar | `safeAreaInset(edge: .top)` under the nav bar, `Spacing.l` horizontal / `Spacing.s` top (`MedicationBarOverlay.swift:18-23`) | KEEP | Same position semantically (top, above scrolling content). The pen draws it inside the scroll column — whether it scrolls away or stays pinned is not shown (§6 Q-J4) |
| Leading icon | 26 × 26 disc `#f4f0fb` [violet-50], 0.418 pt `#000@10%` stroke, flat filled capsule `#4d3974` [violet-800] | `SignalGlyph(.medication, size: 24)` = `CapsuleGlyph` two-tone `Palette.medication #7E5CA8` (`MedicationBarView.swift:55`; `SignalGlyph.swift:41`) | CHANGE | New "capsule badge" atom (disc + flat capsule) in the package; medication purple retunes `#7E5CA8` → `#4d3974` glyph / `#f4f0fb` tile |
| Title | `09:54` Inter 14/600 `#171a1d` · 3 pt dot · `Concerta 36 mg` Inter 12/500 `#4d5154` | one `Text` `"HH:mm · Name Dose"` in `Typography.text(15, .semibold, relativeTo: .subheadline)` `inkPrimary` (`:56-59`, `:99-104`) | CHANGE | Split into two runs (time 14/600, name 12/500 secondary); dot becomes a 3 pt ellipse, not a "·" character. `showName == false` path (`:101`) keeps only the time — pen does not draw that variant |
| Status word | `Active` / `Kicking In` Inter 12/600 **green-500 `#2a9134`**, right-aligned, Title Case | `stateWord(for:)` lower-case, `Typography.label` `.textCase(.uppercase)` tracking 0.5, **`Palette.medication`** (`:61-66`, `:79-86`) | CHANGE | Colour purple → green, uppercase → Title Case. `#2a9134` at 12 pt on white = 4.04:1 — fails AA body (design-system §1.1; constraints Q-C3). `stateWord` is a private view func — should move to the VM with tests (Constitution X) when touched |
| Status states | Only `Active`, `Kicking In` drawn | `kicking in` <20 % · `active` <80 % · `wearing off` <100 % · `worn off` (`:81-84`) | KEEP (data) | Pen's 6.25 % → "Kicking In" and 51.6 % → "Active" agree with the code thresholds. "wearing off"/"worn off" are undrawn (§6 Q-J1) |
| Track | 320 × **10**, `#fafafa`, 0.25 pt `#000@10%` stroke, r 9.5 | `DoseTrack` height **19**, `NewLook.tintNeutral` groove, no stroke (`:138, :146`) | CHANGE | Height 19 → 10, groove colour, add hairline. Min fill width `max(19, …)` (`:155`) must become `max(10, …)` |
| Fill | linear 90° `#8061bf` → `#8c68d3` [violet-500], left-anchored | `LinearGradient([Palette.medication, Palette.medicationFillEnd])` `#7E5CA8` → `#AF99C3` (`:148-154`) | CHANGE | Two gradient stops retune; direction already leading→trailing |
| Onset pulse | not drawn | opacity pulse 1 ↔ 0.55 every 1.3 s while `progress < 0.2`, Reduce-Motion gated (`:141, :167-173`) | KEEP (owner call) | Not in the pen but not contradicted; it is the only "kicking in" motion cue. Keep unless the owner says drop |
| Row tap | no affordance drawn | `Button` → `confirmationDialog` "Log new dose" / "Delete this dose" / "Cancel" (`:20-39`) → `MedicationLogSheet` (`:40-44`) | REMOVE? | **Removing loses the only in-app way to log or delete a dose from the bar.** The pen Settings screen references Dose Guard / Log Dose (spec §7), so the sheet survives elsewhere; the bar entry point does not. Recommend KEEP the tap (invisible affordance is acceptable; AX label already says "Tap to manage" `:112`) — §6 Q-J3 |
| Ordinal / count | not drawn | `doseNumber`, `totalDosesToday` used only in the AX label (`:111`) | KEEP | AX-only today; unchanged |
| End time | not drawn (settings "Show End Time" exists in the pen) | `DoseDisplay.endsAt` (`MedicationBarViewModel.swift:34`) used only in AX (`:109`) | NEW (toggle) | A `showEndTime` `@AppStorage` + rendering do not exist; nor `showTakenTime`. Not on this screen's pen, but the bar is this screen's element |

### 2.3 Month header

| Item | Pen | Code | Verdict | What changes |
|---|---|---|---|---|
| Label | `September 2026` Inter 14/600 `#212529` | `Text(monthLabel)` `Typography.headline` (16/semibold) `.primary` (`CalendarHeaderView.swift:70-72`) | CHANGE | 16 → 14, colour token |
| Chevron | `arrow-up` rotated 90° → **points right**, 16 pt, stroke `#212529` 1.71, gap 2 | `chevron.right` `.caption.weight(.semibold)` `inkSecondary`, rotates 90° when the month grid is open (`:74-78`), gap `Spacing.xs` | CHANGE (visual) / KEEP (interaction?) | Visually the pen equals the code's **collapsed** state. Whether the tap still expands to the month grid, pages forward, or opens a picker is undecided (§6 Q-J5). If it stays "expand to month", nothing but styling changes |
| Tap target | not specified | `minHeight: Metrics.minTapTarget` 44 (`:81`) | KEEP | |
| AX text sizes | not drawn | plain `Text` instead of a no-op button when `forceWeek` (`:49-55`) | KEEP | |

### 2.4 Week strip

| Item | Pen | Code | Verdict | What changes |
|---|---|---|---|---|
| Weekday label | `Tue` … 3-letter, "mixed" family 12/500 lh 18 `#717680`, per column | single letters `M T W T F S S` (`:18`), `Typography.caption` `inkSecondary` in a separate `weekdayCaps` row (`:87-96`) | CHANGE | Use `.dateTime.weekday(.abbreviated)` per cell (locale-correct; also fixes the pen's `Thur`) and fold label + number into one column view. Colour `#717680` is off-palette (§6 Q-J8) |
| Column geometry | 7 columns, widths 44–56, space-between, padding 8/12, gap 6 | `HStack(spacing: 0)` of equal-width cells (`:101-109`) | KEEP (equal widths) | Pen widths are text-hugging; equal columns are the sane implementation and match the pen within 2 pt |
| Day number | 12/600 lh 18 `#414651`; selected `#ffffff` | `Typography.callout` (15/regular), bold when selected, `.monospacedDigit()`, `minimumScaleFactor(0.6)` (`CalendarDayCell.swift:18-25`) | CHANGE | 15 → 12 (this is a real legibility regression for a tappable 44 pt cell; flag), colour token |
| Selected disc | **32 × 32** `#17501d` [green-800], white number | `@ScaledMetric` 30 (max 40) `Circle().fill(Color.primary)` with `Color(.systemBackground)` number (`:13, :25-29, :44`) | CHANGE | Fill `Color.primary` (black/white) → green-800; 30 → 32 base; keep `@ScaledMetric` |
| Indicator dot | **5 × 5** `#55a75d` [green-400], **only under the selected day**, 6 pt gap | 6 × 6 dot under **every** day with entries: `.mood(color)` = average-mood `deepFill`, `.neutral` = `inkSecondary`, `.none` clear (`:31, :50-56`; `CalendarMonthModel.swift:70-74`) | CHANGE (semantics undecided) | Two readings: (a) pen dot = "selected" marker → the per-day mood dots are REMOVED (loses the at-a-glance "which days have check-ins" cue and the AX state text `:58-67`); (b) pen shows a placeholder week where only day 10 has entries → dots stay, recoloured to green-400 (loses the mood-colour encoding). **§6 Q-J6 — do not build until answered** |
| Future days | not drawn (Sat 11 / Sun 12 look identical to past days) | `.disabled(cell.isFuture)` + `tertiaryLabel` colour (`:37, :45`) | KEEP | Pen gives no future style; keep the current rule |
| Out-of-month days | not drawn | `tertiaryLabel` (`:46`) | KEEP | Only relevant if the month grid survives |
| Month grid (week ↔ month) | **not drawn** — one week, no page dots | `isExpanded` toggle, full `weeks` grid (`CalendarHeaderView.swift:23-36, :98-114`), `Motion.smooth` animated | REMOVE? | Loses month-at-a-glance browsing and the only way to reach a day outside the visible week other than swiping. §6 Q-J5 |
| Month swipe | not drawn | `DragGesture(minimumDistance: 24)` pages months (`:116-122`), bounded by `canPage` (`CalendarLibraryView.swift:191-198`) | KEEP (owner call) | Spec §7 infers a week-to-week swipe; the code pages **months**. If the strip becomes week-only, a week swipe is NEW and month paging is REMOVED |
| Selection behaviour | tap a day → expanded card switches to it (inferred) | `selectDay` → `scrollList(to:)` sets `selectedDay`, scrolls to top, `expandedCards.selecting(_, autoExpand:)` (`CalendarLibraryView.swift:161-181`) | KEEP | Exactly the pen's implied behaviour, including the "Auto-expand selected day" setting |
| Tab re-entry | — | `jumpToToday()` on switching to the tab (`:57-62, :183-188`) | KEEP | |
| Cell AX | — | label "Friday 10 October, today, has check-ins", `.isSelected`, Voice Control "tap 10" (`CalendarDayCell.swift:38-40, :58-67`) | KEEP | Update the state words if the dot semantics change |

### 2.5 Expanded day card

| Item | Pen | Code | Verdict | What changes |
|---|---|---|---|---|
| Container | 342 × 266, white, r **24**, 0.5 pt **centre** stroke, shadow (0,**4**,8), gap 15, padding-bottom 15 | `DayCard`: `NewLook.card`, r 20 continuous, `.newLookCardShadow()`, rows in `VStack(spacing: Spacing.xxl)` padded `Spacing.l` (`DayCard.swift:14, :23-32, :35-37`) | CHANGE | Radius 20 → 24 (pen's only r-24 card on this screen), add stroke, rows gap 24 → 13 + dividers |
| Header band | 342 × 52, fill `#e6f5ee` (off-palette mint), radii 24/24/0/0, padding 14/15; `Okay ` 14/600 `#17501d` · 3 pt dot `#4d5154` · `Fri 08` 14/600 `#17501d` | `collapsedBand`: `"GREAT · MON"` all-caps 13/semibold tracking 1.3 (mood in `level.wordColor`, weekday `inkPrimary`), background `level.blockTint` = mood base @ 0.24 (`FoldedDayCardHeader.swift:128-155`; `MoodLevel+Palette.swift:46`; `Opacity.swift:13`) | CHANGE | Band is a **fixed mint** in the pen, not mood-tinted (every mood gets `#e6f5ee`); title becomes Title Case 14/600 green-800 with the **day number** (`Fri 08`), which the band lacks today. Data: `DayCardSummary.mood` + `day.date` |
| Collapse control | 24 × 24 white circle, 0.6 pt `#e4ece4` stroke, `arrow-up` 13 pt `#26842f` [green-600] | `chevron.down` rotated 180°, `.caption.weight(.semibold)` `inkSecondary`, bare icon (`:132-135`) | CHANGE | New "circular icon button 24" atom (shared with §2.6 and the ⋯ button). Whole band stays the button (`DayCard.swift:18-21`) — keep that; the drawn 24 pt pill is under the 44 pt floor |
| Row layout | 312 × 44, avatar · text column at x 96 · more button; 1 pt `#000@10%` dividers between rows, x 45→357 | `HStack(alignment: .top, spacing: Spacing.l)` disc · `VStack(spacing: Spacing.s)` headline + chip line (`TimelineRow.swift:34-44`); no dividers | CHANGE | Add dividers; spacing 16 → 8 (pen avatar 44 + gap 8 = x 96 − 44 − 44) |
| Mood avatar | **44 × 44**, r 35, fill + 1 pt stroke tinted per mood (`#ddf4de` great · `#f4dddd` low · `#e5f7e5` okay; `#fee8d1` flat from §2.6; **good not drawn**), sprout **33.56** | `Circle` **43** (`Metrics.rowMoodDisc`) filled `level.badgeTint` = base @ 0.50, `SignalGlyph(.mood, size: 28)` (`Metrics.rowMoodGlyph`) (`TimelineRow.swift:46-53`; `Metrics.swift:29-32`) | CHANGE | Disc 43 → 44 (trivial); tint model changes from "base @ opacity" to **five explicit pastel tokens** (one missing); glyph 28 → 33.56; sprout redrawn (§2.5 glyph row below). `Opacity.moodBadge` and `MoodLevel.badgeTint` become unused if the tokens are explicit |
| Mood word | Inter **14/600**, colour per mood (`Great` `#17501d`, `Low` `#842626`, `Okey` `#1e6725`) | `Typography.moodWord` **24/bold** in `level.wordColor` (light `#1E5C38 · #8E470F · #41691F · #2C6B3B · #8A5600`) (`TimelineRow.swift:75`; `MoodLevel+Palette.swift:55-63`) | CHANGE | 24 → 14 is the single biggest hierarchy change on the screen; word colours retune to the pen's (inconsistent: two greens for Great/Okay, see spec §4.2 #12). `DayCardPaletteTests` pins `wordColor` AA ≥ 4.5 on `blockTint` over `NewLook.card` — the test's premise (word on a mood tint) no longer matches the pen (word on white) and must be rewritten, not deleted |
| Time | `18:30` Inter 14/500 `#212529`, bottom-aligned beside the word, gap 6 | `.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)` in `Typography.text(13, relativeTo: .subheadline)` `inkSecondary`, concatenated after the word with two spaces (`:71-76`) | CHANGE | 13 → 14, secondary → primary ink; keep the single-`Text` concatenation (it is what makes the word never truncate at AX sizes, `:66-69`) |
| Signals line | `[energy 18 pt + Alert] · [focus 18 pt + Distracted]`, labels Inter 12/500 `#212529`, glyph-label gap 3, item gap 6 | `FlowLayout(spacing: Spacing.s)` of chips with "·" text separators; glyph **12 pt** (`Metrics.rowSignal`), `Typography.caption` (12/regular) `.primary` (`:106-127`) | CHANGE | Glyph 12 → 18; caption regular → medium; dot as a 3 pt ellipse. **Labels: the row prints the raw stored string** (`recording.energyLevel` / `focusLevel`, `:131-135`) → "lockedIn"; the pen's `Locked In` needs `FocusLevel.displayLabel` (`Levels.swift:113-121`) — PR #45 already makes this fix (constraints §5.1) |
| Row extras | **only energy + focus** | also: each medication name in `Palette.medication` (`:137-139`), sleep label in `Palette.sleepIndigo` with no glyph (`:142-144`), `"♥ " + feelings` ≤4 `+N` and side effects ≤4 `+N` in `inkSecondary` (`:145-153`; `Recording+MoodDisplay.swift:106-113`) | REMOVE | Loses the calendar-level scan of meds / sleep / emotions / side effects per check-in. All four remain on the detail screen (`ADHDSummarySection`), and meds + sleep move to the collapsed card in the pen (§2.6). Emotions and side effects have **no home** on this screen in the pen — §6 Q-J2 |
| More button | 22.6 × 22.6 white, 0.565 pt `#e4ece4` stroke, three dots `#1e6725` [green-700] | 21 pt `ellipsis` `.caption` `inkSecondary` inside a 1.5 pt `inkSecondary` ring, **decorative** (`accessibilityHidden(true)`, `:88-95`; `Metrics.moreAffordance`) | CHANGE + NEW (menu) | Restyle is trivial; the menu behind it does not exist (see §4). The pen implies it is a real control, which also changes the row's AX tree (one combined element today, `:28-29`) |
| Row tap | list item → detail (spec §7) | whole row is a `Button` → `onTapRecording` (`:20-23`) | KEEP | |
| Dose-only node | not drawn | a node with `recording == nil` renders time-only, no ⋯, not tappable (`:24-25, :84`) | KEEP (undesigned) | The pen has no visual for a manual dose logged without a check-in. §6 Q-J7 |
| Transcribing / pending row | not drawn | `recording.displayTitle` ("Transcribing…" / "Ready shortly…") takes the headline slot (`:78-83`; `Recording.swift:44-50`) | KEEP (undesigned) | Same question |
| Card AX | — | header combined with hint "Expanded, double tap to collapse" (`FoldedDayCardHeader.swift:142-145`); row combined label (`TimelineRow.swift:172-187`) | KEEP | Add the ⋯ menu as its own element |

**Glyphs on this card (Frame 12 vs `Packages/SquirlDesignSystem/.../Glyphs/`)**

| Signal | Pen (Frame 12) | Code | Verdict |
|---|---|---|---|
| Mood | sprout, **shape constant, colour ramp only** (`#bc4749` low … `#175723` great) | `SproutGlyph` (57 lines, Canvas): shape varies by level (bud → open, size lift, stem notch, crown dot) + `MoodLevel.color` | CHANGE — new drawing. **The pen sprout encodes level by colour alone**, which breaks PRODUCT.md principle 5 / old DESIGN.md "colour is never the only cue" (constraints §3.2). Either keep a shape cue or get an explicit owner waiver (§6 Q-J9) |
| Energy | bolt, fill height 30 → 100 % (mask exported as black blocks) | `BoltGlyph` (39 lines): size/fill/stroke vary by level, `Palette.energyRamp` | CHANGE — new drawing; blocked on the black-box question (spec §8 #1) |
| Focus | target ring + rising arrow, arc grows | `ApertureGlyph` (44 lines), `Palette.focusRamp` | CHANGE — new drawing (a ring that fills is close to the aperture idea; "target" is not the same silhouette) |
| Sleep (§2.6 only) | crescent moon + star, 5 levels | `BedIcon` (35 lines), single icon, `GlyphSignal.sleep.variesByLevel == false` (`GlyphSignal.swift:24-29`; `SignalGlyph.swift:38-39`) | NEW — glyph + ramp + `variesByLevel = true`; `SignalGlyphTests` pins `"Sleep"` as the level-less label |
| Medication (§2.2 badge, §2.6 pill) | two different icons | `CapsuleGlyph` (25 lines) | CHANGE (badge) + NEW (multicolour pill) — §6 Q-J10 |

### 2.6 "Previous Days"

| Item | Pen | Code | Verdict | What changes |
|---|---|---|---|---|
| Section heading | `Previous Days` Inter 16/600 `#212529`, 24 above / 8 below | none | NEW | Heading + section split of the existing list: card 0 = selected day (expanded), cards 1… = previous. Data: `timelineDaysFilteredToSelectedDate(selectedDay)` (`MoodLibraryViewModel.swift:107-110`) — first element vs the rest. Edge: when the selected day has no entries the pen shows nothing for it (there is no "empty selected day" card in the pen); the code today simply has no card for it either (`timelineDays` skips empty days `:92`) |
| Card container | 342 × 99, **fill and stroke tinted per mood** (`#f8fffc`/`#abbba3@50%` great · `#fffdfd`/`#f3b09a@50%` low · `#fefdfa`/`#f6cc8a@50%` flat; okay/good not drawn), r 12, shadow (0,3,8) | white `DayCard` with a mood-tinted **header band** `level.blockTint` (base @ 0.24) (`FoldedDayCardHeader.swift:62`) | CHANGE | Tint model flips: whole-card faint tint + tinted stroke instead of a tinted band. Needs 5 fill + 5 stroke tokens (3 given). A card with **no mood** (medication-only day, `summary.isEmpty == false`, `level == nil`) has no pen style — reuse plain white |
| Avatar | 44 × 44 tinted disc + 33.56 sprout (as §2.5) | bare `SignalGlyph(.mood, size: 40)` **no disc** (`:39-41`; `Metrics.dayHeaderGlyph`) | CHANGE | Same avatar atom as the expanded rows |
| Title | `Great` **16/600** mood colour + gap 6 + `Aug 30` **16/600** `#212529` | `Great` 24/bold `wordColor` + ` · ` + `MON` 13/semibold caps tracking 1.3 (`:72-80`) | CHANGE | 24 → 16; weekday → `MMM d`. Note the pen uses `Fri 08` in the expanded header but `Aug 30` here (spec §4.2 #9) |
| Signals row | `[energy 23 + Alert] · [focus 24 + Distracted] · [sleep 20 + 8h Sleep]`, labels 12/500 `#4d5154` | `FlowLayout` chips: energy · focus · **medication name** · sleep, glyph 15 (`Metrics.summarySignal`), `Typography.caption`, `.primary` / `Palette.medication` (`:82-124`) | CHANGE | Medication leaves this line for its own row; sleep gains a moon glyph at a level; glyph sizes 15 → 23/24/20 (three different sizes in the pen — treat as one size, §6 Q-J11); label colour grey-400 vs grey-500 in the expanded card (spec §4.2 #14) |
| Medication row | pill illustration 12 × 12 + `Concerta 36mg` 12/500 `#4d5154` | name only, no dose, inline with the signals (`DayCardSummary.mostRecentMedicationName`, `DayCardSummary.swift:29-31`) | CHANGE + small NEW | Dose text needs a new computed on `DayCardSummary` (`node.intakeDoses.first?.dose`, `MedicationEvent.swift:13`) + a test in `FoldedDayCardHeaderTests`. Multi-medication days: pen shows one line; code shows the newest name — keep that rule |
| Expand control | 24 × 24 white pill, `arrow-up` flipped → chevron-down, `#26842f` | bare `chevron.down` `inkSecondary` (`:55-57`) | CHANGE | Same atom as §2.5 |
| Card tap | ambiguous (body vs chevron) | whole header is the toggle button (`DayCard.swift:18-21`) | KEEP | Whole card toggles; chevron is the visual cue |
| Expanded previous day | not drawn | any card can expand independently (`ExpandedDayCards.toggling`, `ExpandedDayCards.swift:22-27`); "Always expand cards" opens all (`:38-40`) | KEEP | An expanded previous-day card would presumably take the §2.5 anatomy (mint band + rows) — confirm (§6 Q-J12) |
| Empty day | not drawn | copy `"No check-ins this day. That's alright."` (`DayCardSummary.swift:47`), no tint, no glyph (`FoldedDayCardHeader.swift:45-49`) | KEEP (undesigned) | Only reachable today for a day with doses but no recordings; keep the copy (it is a locked "never red/missed" rule) |
| Filter rule | previous days = older than the selected day | `timelineDaysFilteredToSelectedDate` drops days **newer** than the selection (`:107-110`) | KEEP | Matches the pen's structure exactly |

### 2.7 Tab bar + FAB — see §4 (navigation delta). Summary: **NEW** custom floating bar + **NEW** FAB, or a styled native bar; both replace `RootTabView.swift:19-36`.

### 2.8 Home indicator — KEEP (system).

### 2.9 Scroll / fold behaviour

| Item | Pen | Code | Verdict | What changes |
|---|---|---|---|---|
| Bottom inset | not drawn; card 1 sits half behind the floating bar | opaque tab bar (`ScreenContainer.swift:59-60`) + `edgeFadeMask(top: 0, bottom: Spacing.section)` (`CalendarLibraryView.swift:156`) + `padding(.bottom, Spacing.xxl)` (`:143`) | NEW | A floating bar needs a bottom `safeAreaInset`/`contentMargins` ≥ 60 + 8 so the last card can clear it, plus a decision on the fade (§6 Q-J13) |
| Strip collapse + compact title band | not drawn | `CalendarStripFade` (dead zone 24, title reveal 0.8) + `compactTitleBand` (`CalendarLibraryView.swift:73-96, :125-126, :147-154`) | REMOVE? | Loses date context on deep scrolls (spec-035 rationale). 10 tests in `app-fourTests/Views/CalendarStripFadeTests.swift` go with it. §6 Q-J13 |
| Scroll bounce | — | `.scrollBounceBehavior(.basedOnSize)` (`:155`) | KEEP | |
| Empty state | not drawn | `ContentUnavailableView("No entries yet", systemImage: "calendar.badge.exclamationmark", description: "Record a voice note to see it here.")` (`:208-214`) + pinned header | NEW (design) | The pen has no empty state; the first-launch screen under a hard paywall is exactly this one (Calendar is the launch tab, `SquirlApp.swift:9`). Needs a design, not just a restyle |

---

## 3. Data availability — every field the pen shows

| # | Pen field | Available? | Source (path:line) / what is needed |
|---|---|---|---|
| 1 | Med row time `09:54` | **YES** | `DoseDisplay.takenAt` (`MedicationBarViewModel.swift:33`) formatted "HH:mm" (`MedicationBarView.swift:90-94, :100`) |
| 2 | Med name `Concerta` | **YES** | `DoseDisplay.name` (`:27`) |
| 3 | Dose `36 mg` | **YES, unnormalised** | `DoseDisplay.effectiveDose` (`:32`) = `MedicationEvent.dose` free text: catalog picks write `"36 mg"` (`MedicationCatalog.swift:23`), transcript extraction may write `"36mg"`. The pen itself shows both spellings (spec §4.2 #8). A formatter is needed if one spelling is wanted |
| 4 | `Vyvans` with no dose | **YES** | `effectiveDose == nil` branch (`MedicationBarView.swift:102`) |
| 5 | Status `Active` / `Kicking In` | **YES (view-private)** | `stateWord(for:)` (`MedicationBarView.swift:79-86`), fill-fraction thresholds 0.2 / 0.8 / 1.0. Not onset-aware: `MedicationCatalogEntry.onsetMinutes` (`MedicationCatalog.swift:10`) is read only by `MedicationLogSheet.swift:105`. Hoist to the VM + tests when touched |
| 6 | Progress fraction (51.6 %, 6.25 %) | **YES** | `DoseDisplay.progress` (`MedicationBarViewModel.swift:95`); `MedicationEvent.effectProgress(at:)` (`MedicationEvent.swift:68-72`) |
| 7 | End time (settings "Show End Time") | **YES data / NO setting** | `DoseDisplay.endsAt` (`:34`, `:94`); no `showEndTime` / `showTakenTime` keys exist (`MedicationBarView.swift:8-9` has only `medicationBarVisible`, `medicationBarShowName`) |
| 8 | `September 2026` | **YES** | `MoodLibraryViewModel.monthLabel` "MMMM yyyy" (`:35-41`) |
| 9 | Month chevron → next month | **PARTIAL** | `nextMonth()` / `prevMonth()` (`:138-145`), bounded to `[earliest month with data … current month]` (`CalendarLibraryView.swift:190-198`). A forward chevron is a no-op on the current month — the pen draws it enabled on September 2026 (= "today"), so it is probably not "next month" |
| 10 | Weekday `Tue` + day `7` | **YES** | `DayCell.date` / `dayNumber` (`CalendarMonthModel.swift:16-24`); labels are single letters today (`CalendarHeaderView.swift:18`) |
| 11 | Selected day | **YES** | `@State selectedDay` (`CalendarLibraryView.swift:9`) |
| 12 | Dot under a day | **YES, different meaning** | `DayCell.marker` ∈ `.mood(color)` / `.neutral` / `.none` (`CalendarMonthModel.swift:5-9, :70-74`) — "has check-ins" per day, not "selected" |
| 13 | Which week is shown | **YES** | `selectedWeekIndex` (`CalendarHeaderView.swift:28-32`) |
| 14 | Header `Okay` (day-level mood) | **YES** | `DayCardSummary.mood` = rounded-half-up average of the day's moods (`DayCardSummary.swift:13-15`; `MoodLevel.average(of:)` `Levels.swift:45-50`). This answers spec §8 #4: it is an **average**, tested in `FoldedDayCardHeaderTests` (`moodAveragesRoundHalfUp`) |
| 15 | `Fri 08` | **YES** | `TimelineDay.date` (`MoodLibraryViewModel.swift:10`) → `"EEE dd"`. Existing `dayLabel(for:)` gives "Today, 27 Sep" / "Yesterday, …" / "Friday, 8 Aug" (`:157-165`) — a third format; pick one |
| 16 | Row mood word + colour | **YES** | `MoodLevel(name: recording.mood)?.displayLabel` (`TimelineRow.swift:16, :75`; `MoodLevel+Palette.swift:65-73`); colour tokens differ (§2.5) |
| 17 | Row time `18:30` | **YES** | `node.time` 24 h (`TimelineRow.swift:71`). Spec §4.2 #10 (12 h vs 24 h) → follow locale: `.dateTime.hour().minute()` without `amPM: .omitted` |
| 18 | Energy label `Alert` / `Tired` | **YES** | `EnergyLevel.displayLabel` = `rawValue.capitalized` (`SignalLevel.swift:57`); row currently prints the raw string (`TimelineRow.swift:131`) — same text for energy by coincidence |
| 19 | Focus label `Distracted` / `Locked In` | **YES** | `FocusLevel.displayLabel` (`Levels.swift:113-121`); row prints raw `lockedIn` (`TimelineRow.swift:134-135`) — must switch to `displayLabel` (PR #45 does this) |
| 20 | Energy / focus glyph level | **YES** | `numericValue` (`Levels.swift:65, :110`) → `SignalGlyph(kind, level:)`. The pen's glyph/label mismatches (spec §4.2 #13) are placeholder noise; code is consistent |
| 21 | Level-1 words `Sluggish` / `Foggy` | **YES** | `Levels.swift:54, :99` — never drawn in the pen (constraints Q-V1); they will appear |
| 22 | Row ⋯ menu contents | **NO menu; actions exist** | Edit: `ExtractionReviewViewModel(recording:store:onComplete:)` + `.sheet(item:)` pattern (`RecordingDetailView.swift:53-73`). Delete: `MoodLibraryViewModel.delete(_:)` (`:147-149`) → `RecordingStore.deleteRecording`; the detail's confirmation copy `"Delete this check-in?"` (`RecordingDetailView.swift:79`) is reusable. Favourite exists on the VM (`RecordingDetailViewModel.swift:30`) with no UI anywhere. Contents = §6 Q-J2 |
| 23 | Previous-day mood word / colour | **YES** | `DayCardSummary.mood` |
| 24 | `Aug 30` | **YES** | `TimelineDay.date` → `"MMM d"` |
| 25 | Card energy `Alert` / focus `Distracted` | **YES** | `DayCardSummary.energy` / `.focus` — day **averages** with `displayLabel` (`DayCardSummary.swift:17-24`), not the latest check-in. The pen does not say which; the tested rule is average |
| 26 | `8h Sleep` text | **YES (casing differs)** | `DayCardSummary.sleep` (`:36-41`) → `Recording.sleepLabel` `"8h sleep"` / `"7.5h sleep"` / `"deep sleep"` (`Recording+MoodDisplay.swift:94-103`); prefers `decodedSleepEvent.hours`, then `sleepHours`, then `sleepQuality` |
| 27 | Sleep glyph level (`sleep-great`) | **YES data / NO glyph** | `Recording.decodedSleepLevel: SleepLevel?` (`Recording.swift:165-167`, `sleepLevelValue :37`), populated on the live LLM path by `ExtractionValidator.deriveSleepLevel(hours:)` — `<5 restless · <6 light · <7 okay · <9 good · else deep` (`ExtractionValidator.swift:759-766`, `:884`). This answers spec §8 #9 (hour thresholds exist). `DayCardSummary.sleep` returns only the label; a `sleepLevel` computed is needed. No moon glyph / ramp in the package (`GlyphSignal.swift:24-29`) |
| 28 | `Concerta 36mg` on the card | **PARTIAL** | Name: `DayCardSummary.mostRecentMedicationName` (`:29-31`). Dose: `node.intakeDoses.first?.dose` (`DayTimeline.swift:16`; `MedicationEvent.swift:13`) — new computed + test. Includes manual doses (`MoodLibraryViewModel.loadMedicationEvents` `:129-136` fetches `taken == true`, both sources) |
| 29 | Pill illustration | **NO asset** | `CapsuleGlyph` only. §6 Q-J10 |
| 30 | Tab bar active tab | **YES** | `selectedTab: Tab` (`RootTabView.swift:13`; `SquirlApp.swift:9`) |
| 31 | FAB `+` action | **PLUMBING YES / target undesigned here** | `selectedTab = .checkIn` + `shouldAutoStartRecording` binding (`RootTabView.swift:14`; `SquirlApp.swift:72-76` per the capture map) — a FAB can reuse the same path as the deep link. What it opens (voice / text / meds chooser, iphone17-4) is another screen's gap |
| 32 | "Previous Days" list membership | **YES** | `timelineDaysFilteredToSelectedDate(selectedDay).dropFirst()` |
| 33 | Dose-only node / transcribing row / empty day / empty state | **YES data, NO design** | `DayTimeline.Node.recording == nil` (`DayTimeline.swift:13`); `Recording.displayTitle` (`Recording.swift:44-50`); `DayCardSummary.emptyCopy` (`:47`); `emptyState` (`CalendarLibraryView.swift:208-214`) |
| 34 | Weekday dominant level, `24 check-ins`, connection thresholds, `Installed`, `34MB` | n/a | Insights / Settings fields, not on this screen (spec §6 last line). Listed in the brief; nothing here depends on them |

---

## 4. Navigation delta

| Element | Pen | Code | Delta |
|---|---|---|---|
| Tab bar | Floating white pill **274 × 60**, r 75, shadow `#183c28@16%` (0,8,24), 28 pt gutters; active item = **64 × 44 green-500 pill, icon-only** (`vuesax/bold/calendar` white); inactive = outline icons `#999b9d` [grey-200] 24 pt, **no labels**; order Calendar · Check In · Insights · Settings | Native `TabView(selection:)` with four `.tabItem { Label(…, systemImage:) }` (`RootTabView.swift:19-35`), SF symbols `calendar` / `checkmark.circle` / `chart.bar.fill` / `gear` (`Icons.swift:7-10`), labels "Calendar / Check in / Insights / Settings", `.tint(Theme.meadowGreen)` (`:36`); background painted opaque `NewLook.screen` from every tab root (`ScreenContainer.swift:57-60`) | **NEW**. Two routes: (a) custom bar — `TabView` + `.toolbarVisibility(.hidden, for: .tabBar)` + an overlay pill; you own hit areas, VoiceOver tab traits, Reduce Transparency, keyboard avoidance, iPad sidebar adaptation and the iOS 26 scroll-minimise behaviour. (b) native iOS 26 tab bar (`Tab(…)` builder) styled with `.tint(green-500)` — already a floating rounded pill on iOS 26; labels cannot be dropped and the active-item fill is glass, not a solid green pill. The pen's icon-only active pill + separate circle at the trailing end is visually the iOS 26 tab bar + `Tab(role: .search)` layout; using the search role for a "+" would be a semantic hack. **Owner decision (§6 Q-J14)**. Note the compact bar variant on this screen vs the labelled full bar on Settings (design-system §4.4) — two bar layouts to reconcile |
| FAB | 50 × 50 `#8c68d3` [violet-500] circle, `+` `#e9e9ea` 1.71, shadow `#000@17%` (0,7,17), at x 324, vertically centred on the bar (Frame 15 `Add Button`) | none | **NEW** (shared component, Frame 15). Action target = start a check-in; plumbing exists (§3 #31). Conflicts: Check In is already a tab (two entry points to one action, "one primary action per screen" — constraints Q-L1); violet was the medication-only hue (Q-P7) |
| Back pill | none (root tab) | none | KEEP |
| Push to detail | row → iphone17-1 (with back pill + tab bar + FAB) | `path.append(UUID)` → `RecordingDetailView` pushed inside the `NavigationStack`, system back (`CalendarLibraryView.swift:47-54, :137`) | KEEP mechanism. Whether the tab bar stays visible on the pushed screen is another screen's question (constraints Q-L2) |
| Sheets | none drawn on this screen | `MedicationLogSheet` from the bar (`MedicationBarView.swift:40-44`); `ExtractionReviewView` only from the detail (`RecordingDetailView.swift:70-72`) | If the row ⋯ menu gets "Edit", the edit sheet is presented **from the calendar** for the first time — `editViewModel` state + `.sheet(item:)` move up to `CalendarLibraryView` (NEW) |
| Overflow menus | row ⋯ (contents undrawn) | none on this screen (`TimelineRow.swift:87-95` decorative) | **NEW** `Menu` per row |
| Tab switch side-effects | — | leaving the tab pops the whole path; entering calls `jumpToToday()` (`CalendarLibraryView.swift:57-62`) | KEEP |
| Deep link / intent | — | `whispernotes://checkin` → `.checkIn` tab (capture map §1) | KEEP; a FAB shares it |

---

## 5. Accessibility, Dynamic Type, dark mode — this screen

**Contrast (light, as drawn)**
- `#2a9134` `Active` / `Kicking In` at 12/600 on white = **4.04:1 — fails AA body**. Frame 5 lists green-600 `#26842f` 4.75 / green-700 `#1e6725` 6.95 as the compliant steps (design-system §1.1). The current purple state word is `Palette.medication #7E5CA8` on white ≈ 5.0:1, so this is a regression to accept or fix.
- `#da7a2a` `Flat` at 16/600 on `#fefdfa` ≈ **3.0:1 — fails** (600 weight at 16 pt is not WCAG "large"). The code's `wordColor.flat` `#8A5600` was chosen precisely to clear 4.5 (`MoodLevel+Palette.swift:49-54`). Same for `#842626` → fine (~9:1); `#17501d` 9.5; `#1e6725` 6.95.
- Week strip `#717680` 12/500 on `#fbfffc` ≈ 4.6:1 — borderline pass; `#414651` fine.
- Inactive tab icons `#999b9d` on white = **2.79:1 — fails the 3:1 UI-component floor** (design-system §1.1 grey-200). Active white glyph on `#2a9134` = 4.04 (icon ≥ 3:1, passes).
- `#e9e9ea` plus on `#8c68d3` ≈ 3.7:1 (icon, passes).
- Hairlines at `#000@10%` are decorative; fine.
- `#4d5154` grey-400 captions 8.0:1 — good, and **better than today's `inkSecondary #8A8A8E` (3.4:1)** used on the row time and chips (`TimelineRow.swift:73, :114`). The pen fixes an owner-accepted failure on this screen.

**Touch targets** — the pen's ⋯ (22.6 pt) and chevron pills (24 pt) are under 44. Code today: the ⋯ is not a control; the header/row are whole-surface buttons ≥ 44 (`FoldedDayCardHeader.swift:61`, `TimelineRow.swift:43`). Rule for the build: draw small, hit ≥ 44 (`.frame(minWidth: 44, minHeight: 44).contentShape(.rect)`), and keep the whole header as the expand toggle. Day cells already enforce `minHeight: 44` (`CalendarDayCell.swift:33`).

**Dynamic Type** — pen is Inter at fixed 12/14/16. Code scales every role via `UIFontMetrics` (`Typography.swift`), and this screen already handles the hard cases: force-week at ≥ AX1 (`CalendarHeaderView.swift:20`), `@ScaledMetric` day disc capped at 40 (`CalendarDayCell.swift:13, :25`), `minimumScaleFactor(0.6)` on the number, `FlowLayout` chip wrapping (`FoldedDayCardHeader.swift:83`, `TimelineRow.swift:110`), concatenated mood+time `Text` that wraps rather than truncates (`TimelineRow.swift:58, :66-69`). Keep all of it. New risks from the pen: (1) a 12 pt number in a 32 pt disc at AX5 (≈ 2.6×) needs the disc to scale or the number to shrink — the existing `@ScaledMetric` + `minimumScaleFactor` pair covers it; (2) the 3-letter weekday labels in seven equal columns at AX3+ will exceed 342/7 ≈ 49 pt — allow two lines or fall back to single letters at AX sizes; (3) the collapsed-card title row (`Great Aug 30` + 24 pt pill) must wrap before the pill; (4) the signals row with 18–24 pt fixed glyphs next to 12 pt scaling text — glyphs stay fixed by design (`Metrics.swift:36-37` "imagery, not copy"), so align to `.firstTextBaseline`; (5) the medication bar title split into two runs must remain one `Text` so the dot never orphans.

**VoiceOver** — keep the combined elements and label formats: day cell "Friday 10 October, today, has check-ins" (`CalendarDayCell.swift:58-67`), folded card "day label, mood, energy, focus, med, sleep" + "Double tap to expand" (`FoldedDayCardHeader.swift:64-67, :159-163`), row "Great, 18:30, alert, lockedIn, …" (`TimelineRow.swift:172-187` — note it also speaks the raw `lockedIn`), bar "1st dose, Concerta 36 mg, taken at 09:54, 51% elapsed, ends 21:54. Tap to manage." (`MedicationBarView.swift:106-113`). Changes the pen forces: the ⋯ becomes a real `Menu` (own element, label "More options for the 18:30 check-in"); if the strip dot changes meaning, the "has check-ins / has entries" state words change; a custom tab bar must reproduce `.isSelected` + "Tab, 1 of 4" semantics by hand; the FAB needs a label ("New check-in"). `Metrics.moreAffordance` is currently `accessibilityHidden` — that flips.

**Reduce Motion** — every animation here is gated (`CalendarLibraryView.swift:93, :133, :177, :185-186`; `CalendarHeaderView.swift:67, :112-113`; `DoseTrack` `:141`). The pen adds no motion; keep the gates, and give the new expand pill the same `Motion.expand` (`Motion.swift`) rotation.

**Dark mode** — the pen is light-only (design-system §1.6: the only dark value anywhere is `#1C1E19`). Every code token this screen uses has a dark value (`NewLook.*`, `MoodLevel.wordColor`, `Palette.medication`). The pen introduces ~18 off-palette light literals with no dark counterpart: ground `#fbfffc`; mint band `#e6f5ee`; pill stroke `#e4ece4`; strip greys `#717680` / `#414651`; avatar tints `#ddf4de` `#f4dddd` `#e5f7e5` `#fee8d1`; card fills `#f8fffc` `#fffdfd` `#fefdfa`; card strokes `#abbba3` `#f3b09a` `#f6cc8a`; word colours `#842626` `#da7a2a` `#1e6725`/`#17501d`; track `#fafafa`; gradient start `#8061bf`; shadow `#183c28`. Each needs a **derived** dark value documented per token (spec-033 precedent, constraints Q-C10) — otherwise this screen ships light-only, which the app has never done. The black glyph blocks (energy/sleep) vanish on a dark ground (Q-C9).

---

## 6. Risks and open questions for the owner

### Risks
1. **`DayCardPaletteTests` and `RecordingMoodDisplayTests` pin the mood hexes** (`app-fourTests/Models/…`, codebase-designsystem §13). The pen retunes every mood colour and replaces "base @ opacity" tints with explicit pastels; both suites must be rewritten to the new token model (AA of word-on-card-fill, not word-on-block-tint). `SignalGlyphTests` pins `"Sleep"` as level-less — a sleep ramp breaks 1–2 assertions.
2. **Mood sprout varies by colour only** in Frame 12; the code's glyph shapes are what keep mood readable in greyscale (PRODUCT.md principle 5). Implementing the pen literally drops a product rule silently — needs a waiver or a shape cue.
3. **Two label bugs are already fixed on an unmerged PR** (#45: `lockedIn` → `Locked In` in the day timeline). Restyling `TimelineRow` before #45 lands creates a conflict on the same lines (`TimelineRow.swift:129-156`).
4. **Contrast regressions introduced by the pen** on this screen: green-500 status words, `Flat` word colour, grey-200 inactive tab icons (§5). The pen's own Frame 5 contrast cards flag two of the three.
5. **Custom tab bar cost is invisible in the mockup**: hit areas, VoiceOver tab semantics, iPad, keyboard, Reduce Transparency, and the loss of the iOS 26 minimise-on-scroll behaviour. Route (a) in §4 is the largest single item on this screen and it is app-wide, not Calendar-only.
6. **Black-block export artefact** (spec §8 #1) blocks the energy and sleep glyph assets — every signal row on this screen shows a bolt.
7. **Sleep ramp vs medication violet**: the moon is violet-500, the same hue as the FAB and the medication bar fill; the old rule kept sleep "bluer/cooler so it never collides with medication purple" (constraints Q-P8). On a collapsed card, `sleep-great` moon and the `Concerta 36mg` pill sit 30 pt apart.
8. **Gutter 30 vs 16** is app-wide; changing it only here leaves the medication bar (shared, `Spacing.l`) misaligned with the cards unless the overlay changes too.
9. **Removing the compact title band + month grid** deletes spec-035 behaviour with 10 tests and an owner ruling (2026-07-16, "the earlier nav-bar title displaced the bar") — the pen offers no replacement for date context on scroll.
10. **Empty state and first-launch** are undesigned; with a hard paywall this is the first screen a new user lands on after onboarding (`selectedTab` starts at `.calendar`).

### Open questions (only the ones that block this screen)
- **Q-J1** Medication status vocabulary: keep `wearing off` / `worn off` (undrawn) with the same quiet green, or collapse to two states? And does `Kicking In` stay fill-based (< 20 %) or move to `onsetMinutes` from the catalog (which would make Ritalin "kick in" in 20 min and Elvanse in 90)?
- **Q-J2** Row ⋯ menu contents (Edit · Delete · anything else?), and where **emotions and side effects** live on this screen — the pen shows them nowhere on the Calendar tab.
- **Q-J3** Keep the medication-bar tap (Log new dose / Delete this dose)? It is invisible in the pen but it is the only bar-level dose management.
- **Q-J4** Does the medication bar scroll with the content (pen places it in the column) or stay pinned above it (code)?
- **Q-J5** Month chevron: expand to the month grid (today), page months, or open a picker — and does the month grid + month swipe survive at all?
- **Q-J6** Week-strip dot: "selected", "today", or "has check-ins" (today's semantics, mood-coloured)? Decides whether `DayMarker` survives.
- **Q-J7** Visual for a dose-only node and a transcribing/pending check-in row (both exist in data, neither is drawn).
- **Q-J8** Week-strip font and greys: confirm Inter/SF and snap `#717680` / `#414651` to Frame 5 neutrals (grey-300 / grey-400)?
- **Q-J9** Mood glyph: accept colour-only level encoding, or keep a shape cue per level?
- **Q-J10** One medication icon (flat violet capsule) or two (plus the multicolour pill on cards)?
- **Q-J11** Glyph sizes: 18 in expanded rows vs 23 / 24 / 20 on collapsed cards — one size?
- **Q-J12** Expanded previous-day card = same anatomy as the selected day's card (mint band + rows)?
- **Q-J13** Fold behaviour: bottom inset, scroll-edge fade, bar hide-on-scroll; and does the compact title band go?
- **Q-J14** Tab bar route: custom floating bar (literal pen) vs styled native iOS 26 bar; and is the FAB a duplicate of the Check In tab or does Check In become something else?
- **Q-J15** Placeholder confirmation: `18:30` ×3, `Aug 30` ×3, identical signals, `Fri 08` under a selected `10` — lorem, not a required state (spec §8 #20).

---

## 7. Effort — senior SwiftUI engineer, focused hours

Assumes the app-wide tokens (Frame 5 palette + derived dark values, card style r12/hairline/shadow, capsule badge, circular icon button 24, custom tab bar + FAB, the four Frame 12 glyph views incl. the sleep ramp) already exist in `SquirlDesignSystem`. Excludes those. Includes tests for logic (Constitution X) and one device QA pass for this screen.

| Bucket | Work | h |
|---|---|---|
| NEW | "Previous Days" heading + first-card/rest split | 0.5 |
| NEW | Row ⋯ `Menu` (Edit → `ExtractionReviewView` sheet hoisted to `CalendarLibraryView`; Delete → confirmation → `MoodLibraryViewModel.delete`) + AX | 2.5 |
| NEW | Collapsed card: medication line with dose (`DayCardSummary` computed + test), sleep level (`DayCardSummary.sleepLevel` + test) wired to the moon glyph | 1.5 |
| NEW | Tinted previous-day card variant (per-mood fill/stroke lookup incl. the undrawn okay/good/no-mood cases) | 1.5 |
| NEW | Bottom inset / fade for the floating bar on this screen; FAB action wiring to the check-in route | 1.0 |
| NEW | Empty state to the new language (design decision needed first) | 0.5 |
| **NEW subtotal** | | **7.5** |
| CHANGE | Medication bar: badge, split title, green Title-Case status, 10 pt track + hairline, gradient stops; hoist `stateWord` to VM + tests | 3.0 |
| CHANGE | Month header (14/600, chevron style) + week strip (3-letter labels per cell, 32 pt green-800 disc, dot rule) + AX strings | 2.0 |
| CHANGE | Expanded card: fixed mint band, `Okay · Fri 08` title, r 24 + stroke, dividers, 24 pt chevron pill | 2.0 |
| CHANGE | `TimelineRow`: 44 pt avatar tint tokens, 14/600 word + 14/500 time, 12/500 signals with 18 pt glyphs, `displayLabel` fix (or rebase on #45), styled ⋯ | 2.5 |
| CHANGE | `FoldedDayCardHeader`: avatar disc, 16/600 word + `MMM d`, signals row w/ sleep glyph, med row, chevron pill | 2.0 |
| CHANGE | Ground / gutter / spacing tokens on this screen; date-format helpers (`EEE dd`, `MMM d`) | 0.5 |
| CHANGE | Rewrite `DayCardPaletteTests` / `FoldedDayCardHeaderTests` expectations to the new token model | 2.0 |
| **CHANGE subtotal** | | **14.0** |
| REMOVE | Row chips for meds / sleep / feelings / side effects (+ AX label trim) | 0.5 |
| REMOVE | Month grid + month swipe + strip fade + compact band (`CalendarStripFade` and its 10 tests, `isCalendarExpanded`, `collapseProgress`) — only if Q-J5/Q-J13 say so | 2.0 |
| REMOVE | Bar tap dialog — recommended **not** removed; 0.25 if it is | 0.25 |
| **REMOVE subtotal** | | **2.75** |
| QA | Device pass: AX1–AX5, dark mode, VoiceOver, Reduce Motion, empty / dose-only / transcribing states | 3.0 |
| **Total** | | **≈ 27** |

Not counted (app-wide, shared with every screen): palette + dark derivation, card/badge/button atoms, custom tab bar + FAB (est. 8–14 h on their own), Frame 12 glyph views (est. 6–10 h, blocked on the black-block question), Inter-vs-SF decision, gutter token change.
