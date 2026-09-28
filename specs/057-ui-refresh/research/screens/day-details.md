<!-- Created: 2026-09-27 21:57 WEST · Updated: 2026-09-27 21:57 WEST -->
# Screen spec — Day Details ("iPhone 17 - 1", pen node `v7jzk`, Figma id `78:11720`)

Sources used, in priority order: PNG render (`pen/named/iphone17-1-day-mode-details.png`, 804×1748 = 402×874 @2x) → Figma JSON (`figma/iphone17-1.json` / `.raw.json`) for every number → HTML export (`pen/html-lite/iPhone-17-1.html`) for layer names, padding and gap values. Design-system frames 2/3/4/5/12/15 were read for component and token names. The `.pen` file itself was not opened.

Conventions: all coordinates are in points inside the 402×874 frame, origin top-left. `[x, y, w, h]`. Hex values are quoted exactly as exported; a palette name in parentheses means the hex matches a swatch in Frame 5 (Color palettes). "off-palette" means no swatch in Frame 5 has that value.

---

## 1. Purpose and placement

**What it is.** A read-only detail view of one logged day (or one check-in — see Open Questions Q1) showing: the three signals (Mood / Focus / Energy) with level labels and progress bars, the emotion chips picked, the medication(s) logged, and the on-device-AI narrative summary with the original voice recording's audio player.

**Where it sits — inferred from chrome:**

| Evidence | Inference |
|---|---|
| Circular back button (`vuesax/outline/arrow-left`) top-left | Pushed onto a `NavigationStack`, not a modal sheet (a sheet would show a grabber or Close). |
| `Main_navbar` at the bottom with **Calendar** (`navigation/menu - home`) in the active green pill | Lives inside the **Calendar tab's** stack. The parent is the Calendar/Mood-Journal screen (`iPhone 17 - 19`), whose day card lists check-in rows, each with a `•••` button, and "Previous Days" cards. Tapping a row/card pushes this screen. |
| Tab bar still visible while pushed | The floating pill tab bar is app-level chrome and stays on pushed screens (not hidden by `.toolbar(.hidden, for: .tabBar)`). |
| Violet `Add Button` (FAB) still visible | A new check-in can be started from here; the FAB is global. |
| `•••` (`vuesax/outline/more`) top-right | Contextual actions for this record — presumably Edit (→ `iPhone 17 - 18` "Edit Check-In"), Delete, Export/Share. The menu itself is not designed. |
| Header title "Today's Mood" + date "Monday, Jun 29" | The screen is dated. The title is hard-coded to "Today" (see Copy issues). |

**Frame:** 402×874, corner radius 32 (device mask), background `#fbfffc` (off-palette near-white with a green tint; `green-50` is `#eaf4eb`). All content fits within 874 pt: the content stack ends at y = 714.75 and the tab bar starts at y = 779, so **nothing is below the fold in this state**. With more chips, more medications or a longer summary the stack would exceed the frame, so the body must be a vertical `ScrollView` with the tab bar floating over it (bottom content inset ≥ 95 pt = 60 tab bar + 34 home indicator + breathing room).

---

## 2. Layout, top → bottom

### 2.0 Global metrics

| Item | Value |
|---|---|
| Frame | 402 × 874, r 32, fill `#fbfffc` |
| Status bar | `[0, 0, 402, 52]`, iOS system style, "9:41", glyphs `#212529` (grey-500) |
| Header container | `[31, 74, 340, 42.6]` — **left inset 31, right inset 31** |
| Content stack `Frame 11` | `[28, 150, 344, 564.75]` — **left inset 28, right inset 30** |
| Tab bar `Main_navbar` | `[28, 779, 346, 60]` — **left inset 28, right inset 28** |
| Home indicator | `[0, 840, 402, 34]`; bar `[129, 861, 143, 5]`, r 10, fill `#212529` |
| Section gap (between `Frame 4/6/5/7`) | 24 |
| Title → content gap | 12 for the first section (20 pt title), 8 for the other three (16 pt titles) |
| Card style A (signals, medication) | fill `#ffffff`, r **12**, stroke 0.5 `#000000` @ 10 %, shadow `0 3 8 #183c28 @ 8 %` |
| Card style B (check-in) | fill `#ffffff`, r **24**, stroke 0.5 `#000000` @ 10 %, shadow `0 4 8 #183c28 @ 8 %` |
| Font family | Inter throughout (the shipping app is native SF; see Q13) |

Gutter inconsistency: the header is inset 31, the content 28/30, the tab bar 28 — three different values (see Copy/Consistency issues C-14).

### 2.1 Status bar `[0, 0, 402, 52]`
Standard iOS light status bar component: time "9:41" at `[32, 18, 40, 21]`, signal/wifi/battery cluster at `[301, 20, 69, 14]`, all `#212529`. Nothing custom.

### 2.2 Header `Container` `[31, 74, 340, 42.6]`
Row, space-between.

**Left group `Frame 1`** `[0, 0, 170.6, 42.6]`, row, gap 7:

- **Back button** `Background+Border` `[0, 0, 42.6, 42.6]` — circle r 21.3, fill `#ffffff`, stroke 1.065 `#e4ece4` (off-palette light green-grey; same value as the DS Bill-shape outline stroke). Icon `vuesax/outline/arrow-left` 20×20 at `(11.3, 11.3)`, fill `#1e6725` (green-700). Chevron only, no label.
- **Title block `Frame 2`** `[49.6, 0, 121, 40]`, column, gap 3:
  - "Today's Mood" — Inter **18 / Semi Bold 600**, `#17501d` (green-800), `[0, 0, 121, 22]`, left-aligned, single line.
  - "Monday, Jun 29 " — Inter **12 / Medium 500**, `#6f7f75` (off-palette green-grey), `[0, 25, 102, 15]`. Note the trailing space in the text node.

**Right: More button** `Background+Border` `[297.4, 0, 42.6, 42.6]` — identical circle (r 21.3, `#ffffff`, stroke 1.065 `#e4ece4`). Icon `vuesax/outline/more` 25×25 at `(8.8, 8.8)`: three 5.73 pt dots, fill `#1e6725` (green-700). The icon instance carries a `#ffffff` fill of its own (harmless on a white circle).

Vertical rhythm: status bar ends 52 → 22 pt gap → header 74–116.6 → 33.4 pt gap → content 150.

### 2.3 Section 1 — "How Does It Feels Today?" `Frame 4` `[28, 150, 344, 149]`

- **Title** "How Does It Feels Today?" — Inter **20 / Semi Bold 600**, `#212529` (grey-500), `[0, 0, 344, 24]`.
- **Signal card** `Background` `[0, 36, 344, 113]` — card style A (r 12). Padding 16 top/bottom, 9 left/right. Row of three signal columns, vertically centred, separated by two diagonal hairlines.

Three **signal columns** (`270_frame`), each 94 wide, column layout, centred, gap 4 (glyph → label → value → bar):

| | Mood | Focus | Energy |
|---|---|---|---|
| Column box | `[9, 18.5, 94, 76]` | `[125, 19, 94, 75]` | `[241, 16, 94, 81]` |
| Glyph box | `svgexport-20 1` 28×28 at `(33, 0)` | `svgexport-20 (1) 1` 27×27 at `(33.5, 0)` | `ix:electrical-energy-filled` 33×33 at `(30.5, 0)` |
| Glyph fills | leaves `#4caf50`, stem `#388e3c` | ring `#4278a8` + `#447097`, arrow `#eda94a`, white core | bolt `#eda94a` only |
| Label | "Mood" 14/500 `#1e2225` (grey-600) `[27.5, 32, 39, 17]` | "Focus" 14/500 `#1e2225` `[27, 31, 40, 17]` | "Energy" 14/500 `#1e2225` `[23.5, 37, 47, 17]` |
| Value | "Great" 12/600 `#0e7718` (off-palette) `[30.5, 53, 33, 15]` | "Sharp" 12/600 `#447097` (off-palette blue) `[29.5, 52, 35, 15]` | "Charged" 12/600 `#e38400` (off-palette amber) `[22, 58, 50, 15]` |
| Bar track | `[4, 72, 86, 4]` r 2 `#e9e9ea` (grey-50) | `[4, 71, 86, 4]` r 2 `#e9e9ea` | `[4, 77, 86, 4]` r 2 `#e9e9ea` |
| Bar fill | `[0, 0.15, 78, 4]` r 2 `#2e8b57` (off-palette "seagreen") → **78/86 = 90.7 %** | `[0, 0, 48, 4]` r 2 `#447097` → **48/86 = 55.8 %** | `[0, 0, 21, 4]` r 52 `#e38400` → **21/86 = 24.4 %** |

Column pitch is 116 (x = 9, 125, 241); inter-column gap 22. Because the three glyph boxes are different heights (28 / 27 / 33) and the row is centre-aligned, **the labels and bars do not sit on one baseline**: "Energy" is 3–5 pt lower than "Mood"/"Focus" (visible in the PNG). Also the Mood bar fill has a 0.149 pt y-offset and the Energy fill uses r 52 while the others use r 2 (no visual difference at 4 pt height, but the layer is also named `Background` instead of `281_rectangle`).

**Diagonal separators** `Line 1` `[114, 16, 81, 0]` and `Line 3` `[230, 16, 81, 0]`: 1 pt lines, stroke `#000000` @ 10 %, rotated 90° inside an 81×81 box so they render as a `/` hairline (the diagonal of an 81 pt square, ≈ 114 pt long) running bottom-left → top-right between adjacent columns. In the PNG the visible span is ≈ 55 pt wide × 65 pt tall. Their 81 pt boxes overlap the neighbouring columns in the JSON (114–195 vs column 2 at 125; 230–311 vs column 3 at 241); the visual is fine, but the geometry is fragile — see Q8.

### 2.4 Section 2 — "Today's Emotional Condition" `Frame 6` `[28, 323, 344, 56]`

- **Title** "Today's Emotional Condition" — Inter **16 / 600**, `#212529`, `[0, 0, 344, 19]`.
- **Chip row `Frame 12`** `[0, 27, 162, 29]`, row, gap 8, left-aligned, hug width. Two `Bill-shape` instances, both in the **BG=solid** variant:
  - "Proud" `[0, 0, 72, 29]`
  - "Excited" `[80, 0, 82, 29]`
  - Chip anatomy: fill `#2a9134` (green-500), stroke 1 `#2a9134`, r 15, shadow `0 7 6 #183c28 @ 6 %`, padding 6 top/bottom · 16 left/right (HTML: `5px 15px` + 1 px border), text Inter **14 / Medium 500** `#ffffff`.
  - Deviation from the DS component (Frame 15): the DS `Bill-shape` text is **12/500** and the chip is **27** tall; this screen overrides to 14/500 → 29 tall.

Only two chips; the row is 162 wide, nothing is clipped at the frame edge (no horizontal scroll implied in this state).

### 2.5 Section 3 — "Your Medications" `Frame 5` `[28, 403, 344, 77]`

- **Title** "Your Medications" — Inter **16 / 600**, `#212529`, `[0, 0, 344, 19]`.
- **Medication card** `Background` `[0, 27, 342, 50]` — card style A (r 12), **342 wide (2 pt short of the 344 content width)**. Padding 11 all sides, row, gap 8, vertically centred:
  - **Leading badge** `[11, 11, 28, 28]`: circle r 14, fill `#f4f0fb` (violet-50), stroke 0.45 `#000000` @ 10 %. Inside, `SVG` 15×15 at `(6.5, 6.5)` with one vector `[0.64, 0.65, 13.72, 13.71]` fill `#4d3974` (violet-800): a capsule/pill outline drawn diagonally with a midline (line-style, not filled).
  - **Text** "Concerta · 36 mg" — Inter **14 / 500**, `#17501d` (green-800), `[47, 16.5, 117, 17]`, single line.

One row only. No time, no status (Calendar shows "09:54 • Concerta 36 mg  Active"), no taken/missed state.

### 2.6 Section 4 — "Daily Check-In" `Frame 7` `[28, 504, 344, 210.75]`

- **Title** "Daily Check-In" — Inter **16 / 600**, `#212529`, `[0, 0, 344, 19]`.
- **Check-in card** `Background` `[0, 27, 342, 183.75]` — card style B (**r 24**, shadow y-offset **4**), 342 wide. Padding 11 all sides, column, gap 11. Inner width 320.

  1. **AI caption row** `Frame 1707479438` `[11, 11, 320, 30]`, row, gap 6, top-aligned:
     - Sparkles glyph `Group` `[0, 0, 13.61, 16.37]`, single vector fill `#7f5fc0` (violet-600): one large 4-point star with two small stars (a "magic/AI" mark; no vuesax name — it is a pasted vector).
     - "Written by on-device AI from your Voice, tap to Correct" — Inter **12 / Regular 400**, `#8a8a8e` (off-palette grey), `[19.61, 0, 300.39, 30]`, wraps to 2 lines.
  2. **Divider** `Line 2` at y 52: 1 pt, `#000000` @ 10 %, full 320 width (drawn rotated 180°, harmless).
  3. **Summary body** `Frame 1707479437` `[11, 63, 320, 60]`: text Inter **12 / 400**, `#1e2225` (grey-600), 4 lines (≈ 15 pt line height, auto):
     "Took my Concerta around nine. Slept about seven hours, felt rested. Focus kicked in mid-morning — got through the backlog. Bit of dry mouth and some jitters after the second coffee."
  4. **Divider** `Line 1` at y 134: same as above.
  5. **Audio player row** `Container` `[11, 145, 320, 27.75]`, row, space-between, gap 6, vertically centred:
     - **Play button** `Background` `[0, 0, 27.75, 27.75]`: circle r 13.875, fill `#8c68d3` (violet-500), stroke 0.75 `#000000` @ 10 %. Icon `tabler:player-play-filled` 17.25×17.25 at `(5.25, 5.25)`; triangle vector `[4.31, 2.16, 10.78, 12.94]` fill `#ffffff`. State shown: **play** (not pause).
     - **Waveform** `Frame 1707479433` `[35.375, 1.5, 251, 24.75]`: **55 bars**, each 2.496 wide, pitch 4.602 (gap ≈ 2.106), fully rounded (cornerRadius exported as 1053191.5 = pill), vertically centred. Bar heights are quantised to five values: 5.79 · 10.0 · 13.16 · 18.43 · 24.75 (ratios 0.23 / 0.40 / 0.53 / 0.74 / 1.0). **Bars 1–23 (41.8 %) fill `#8c68d3` (violet-500) = played; bars 24–55 fill `#eaf4eb` (green-50) = unplayed.** Height sequence: `5.79, 18.43, 13.16, 18.43, 5.79, 13.16, 18.43, 18.43, 13.16, 18.43, 13.16, 13.16, 18.43, 18.43, 24.75, 18.43, 18.43, 24.75, 18.43, 24.75, 24.75, 18.43, 13.16 | 18.43, 18.43, 13.16, 18.43, 13.16, 13.16, 18.43 ×13, 24.75, 18.43, 18.43, 24.75, 13.16, 10.0`.
     - **Duration** "03:24" — Inter **9 / 600**, `#4d5154` (grey-400), `[294, 8.375, 26, 11]`, centre-aligned.

Card bottom = 27 + 183.75 = 210.75 → section ends at frame y 714.75.

### 2.7 Empty band 714.75 → 779
64 pt of page background between the last card and the tab bar.

### 2.8 Tab bar `Main_navbar` `[28, 779, 346, 60]`
Row, gap 22, right-aligned: `Navigation` pill + `Add Button`.

**Navigation** `[0, 0, 274, 60]` — fill `#ffffff`, r 75 (pill), shadow `0 8 24 #183c28 @ 16 %`, four items, space-between:

| Layer name (as in file) | DS meaning | Box | Icon (24×24) | State |
|---|---|---|---|---|
| `navigation/menu - home` | **Calendar** | outer `[0, 0, 94, 60]` (pad 8/15); inner pill `[15, 8, 64, 44]` fill `#2a9134` (green-500) r 44 (pad 10/20) | `vuesax/bold/calendar`, fill `#ffffff` | **Active** — icon-only (the DS `Status=Calendar` variant also shows a "Calendar" 12/500 white label and is 122 wide; this screen and the Calendar screen both drop the label → 64 wide) |
| `navigation/menu - wallet` | **Check In** | `[89, 1.5, 65, 57]` (pad 16.5/20.5) | `vuesax/linear/task-square`, stroke 1.5 `#999b9d` (grey-200) | Inactive |
| `navigation/menu - analysis` | **Insights** | `[149, 1.5, 65, 57]` | `vuesax/outline/chart`, fill `#999b9d` | Inactive |
| `navigation/menu - profile` | **Settings** | `[209, 1.5, 65, 57]` | `vuesax/twotone/setting-2`, stroke 1.5 `#999b9d` | Inactive |

The layer names `wallet / analysis / profile` are template leftovers; the DS frame 4 names the tabs Calendar / Check In / Insights / Settings.

**Add Button (FAB)** `[296, 5, 50, 50]` — fill `#8c68d3` (violet-500), r 75 (circle), shadow `0 7 17 #000000 @ 17 %`. Icon `vuesax/twotone/add` in a 41×41 box at (4.5, 4.5): two 20.5 pt strokes, weight 1.826, round caps, colour `#e9e9ea` (grey-50 — **not** white). Matches the DS `Add Button` component in Frame 15 exactly.

---

## 3. Component inventory and visible states

| # | Component (proposed name) | Instances here | Visible state | Other states known from DS / sibling screens |
|---|---|---|---|---|
| 1 | **Circle Icon Button** (`Background+Border` 42.6 circle, `#e4ece4` stroke) | Back, More | Default, enabled | Not in the Buttons frame (Frame 3) — undocumented component. No pressed/disabled state designed. |
| 2 | **Page Title + Date** (18/600 green-800 + 12/500 `#6f7f75`) | 1 | — | Same pattern on Edit Check-In (title only). |
| 3 | **Section Title** (16/600 grey-500; first one 20/600) | 4 | — | Two sizes on one screen (20 vs 16). |
| 4 | **Signal Card** (card style A, 3 columns + diagonal separators) | 1 | Shows Mood=Great, Focus=Sharp, Energy=Charged | No empty/"not logged" state designed. |
| 5 | **Signal Column** (glyph · label · value · 86×4 bar) | 3 | Bars at 91 % / 56 % / 24 % | Bar fills are not on a 5-step grid (20/40/60/80/100). |
| 6 | **Bill-shape chip** (DS Frame 15) | 2 | **BG=solid** (green-500, white text) — 14/500 override | DS variants: `BG=outline` (white, stroke `#e4ece4`, text `#193024` 12/500), `BG=With Dot` (outline + 8 pt `#d9d9d9` dot), `BG=solid`. Edit Check-In uses outline = unselected, solid = selected. |
| 7 | **Medication Row** (card style A, 28 pt violet-50 badge + capsule + 14/500 text) | 1 | Display only | Calendar's medication bar variant adds time, status word (Active / Kicking In) and a violet progress bar. |
| 8 | **AI Summary Card** (card style B r 24) | 1 | Caption + body + player | No "transcribing…", "no recording", or "edited by you" state designed. |
| 9 | **Audio Player** (27.75 play circle + 55-bar waveform + duration) | 1 | Play icon shown while 42 % of the waveform is "played" — reads as **paused mid-track** or as a static mock (Q11) | No pause/scrubbing/finished state designed. |
| 10 | **Main_navbar → Navigation** (DS Frame 4) | 1 | `Status=Calendar, Mode=Light`, icon-only active pill | DS has Calendar / Check In / Insights / Settings variants, all with a text label in the active pill; only `Mode=Light` exists. |
| 11 | **Add Button** (DS Frame 15) | 1 | Default | No pressed state. |
| 12 | Status bar, Home indicator | 1 each | iOS light | — |

Rows clipped at the frame edge: **none** on this screen (the chip row is 162 pt wide). Compare Edit Check-In, where chip rows do clip and imply horizontal scroll.

---

## 4. Copy inventory (verbatim) and copy issues

### 4.1 Every text string, in reading order

| # | String (verbatim) | Style | Colour |
|---|---|---|---|
| 1 | `9:41` | status bar | `#212529` |
| 2 | `Today’s Mood` | Inter 18/600 | `#17501d` |
| 3 | `Monday, Jun 29 ` (trailing space) | Inter 12/500 | `#6f7f75` |
| 4 | `How Does It Feels Today?` | Inter 20/600 | `#212529` |
| 5 | `Mood` | Inter 14/500 | `#1e2225` |
| 6 | `Great` | Inter 12/600 | `#0e7718` |
| 7 | `Focus` | Inter 14/500 | `#1e2225` |
| 8 | `Sharp` | Inter 12/600 | `#447097` |
| 9 | `Energy` | Inter 14/500 | `#1e2225` |
| 10 | `Charged` | Inter 12/600 | `#e38400` |
| 11 | `Today’s Emotional Condition` | Inter 16/600 | `#212529` |
| 12 | `Proud` | Inter 14/500 | `#ffffff` |
| 13 | `Excited` | Inter 14/500 | `#ffffff` |
| 14 | `Your Medications` | Inter 16/600 | `#212529` |
| 15 | `Concerta · 36 mg` (U+00B7 middle dot) | Inter 14/500 | `#17501d` |
| 16 | `Daily Check-In` | Inter 16/600 | `#212529` |
| 17 | `Written by on-device AI from your Voice, tap to Correct` | Inter 12/400 | `#8a8a8e` |
| 18 | `Took my Concerta around nine. Slept about seven hours, felt rested. Focus kicked in mid-morning — got through the backlog. Bit of dry mouth and some jitters after the second coffee.` (U+2014 em dash) | Inter 12/400 | `#1e2225` |
| 19 | `03:24` | Inter 9/600 | `#4d5154` |

Apostrophes in 2 and 11 are typographic (U+2019).

### 4.2 Typos, grammar, and cross-screen inconsistencies

| ID | Issue | Where | Suggested fix |
|---|---|---|---|
| C-01 | **"How Does It Feels Today?"** — subject/verb agreement error. | §2.3 title | "How does it feel today?" — or, since the card shows all three signals, "How today felt" / "Today's signals". |
| C-02 | **"Today's Mood"** as the page title of a dated detail screen — wrong on any day that is not today, and the screen shows Focus, Energy, emotions, meds and the transcript, not just mood. | header | Title = relative date ("Today", "Yesterday", else "Mon, Jun 29") with the full date as subtitle, or "Check-in" / "Day". |
| C-03 | Trailing space in "Monday, Jun 29 ". | header subtitle | Trim. |
| C-04 | **"Today's Emotional Condition"** — clinical; the same list is called "Emotions" on Edit Check-In. | §2.4 | "Emotions". |
| C-05 | "Your Medications" (here) vs "Medication" (Edit Check-In) vs "Medication Bar" (Settings). | §2.5 | Pick one: "Medication". |
| C-06 | **"Concerta · 36 mg"** here vs "Concerta 36 mg" (Calendar medication bar) vs "Concerta 36mg" (Calendar previous-day cards) vs "36mg" (Edit dose chips) — four dose formats. | §2.5 | One format app-wide; recommend "Concerta 36 mg" (SI spacing). |
| C-07 | **"Written by on-device AI from your Voice, tap to Correct"** — random capitals ("Voice", "Correct") and a comma splice. | §2.6 caption | "Written by on-device AI from your voice. Tap to correct." |
| C-08 | **"Daily Check-In"** implies one per day, but the Calendar day card shows three check-ins on one day (18:30 ×3). | §2.6 | "Check-in" or "Voice note", or show the check-in time. |
| C-09 | **"03:24"** — leading-zero minutes; iOS shows short durations as "3:24". | §2.6 | "3:24". |
| C-10 | Signal labels "Mood / Focus / Energy" here vs "mood / Energy Level / focus level" (Edit) vs "Mood / Energy Level / Focus" (Insights) — case and wording differ, and the order differs (Mood-Focus-Energy here, Mood-Energy-Focus elsewhere). | §2.3 | Fix one label set and one order app-wide. |
| C-11 | Header case is mixed: Title Case section headers vs sentence-case caption. | all | Pick Title Case or sentence case for headers (Apple HIG: Title Case for nav titles, sentence case for body). |
| C-12 | "Okay" is spelled "Okey" on the Calendar and Insights screens (not on this screen, but the same enum). | sibling screens | "Okay". |
| C-13 | Sample data: this screen is "Monday, Jun 29" but the Calendar shows "September 2026"; harmless but confusing in review. | — | Align sample dates. |
| C-14 | Layout gutters differ: header 31/31, content 28/30, tab bar 28/28; two cards are 342 wide inside a 344 stack. | §2.0 | One horizontal inset (recommend 28 to match the tab bar, or 24/16 per HIG), cards fill the stack width. |
| C-15 | Card radius 12 (signals, medication) vs 24 (check-in); shadow y 3 vs 4. | §2.0 | One card radius (16 is a sensible middle) and one shadow. |
| C-16 | Chip text 14/500 here vs 12/500 in the DS component and on Edit Check-In. | §2.4 | Decide 12 or 14 and update the component. |
| C-17 | Tab-bar layer names `wallet / analysis / profile` are template leftovers. | §2.8 | Rename layers to Check In / Insights / Settings. |

---

## 5. Glyph and icon usage

### 5.1 Signal glyphs (DS Frame 12 "Glyphs")

The DS defines 5 levels per signal (`*-low, *-flat, *-okay, *-good, *-great`) with these fills:

| Signal | low | flat | okay | good | great |
|---|---|---|---|---|---|
| mood (sprout) | `#d97773`/`#bc4749` | `#e8b964`/`#c58b37` | `#b1c194`/`#82936b` | `#75ba4f`/`#2a9134` | `#428d52`/`#175723` |
| focus (target) | ring quarter `#4278a8` on `#d6e5f0`, `#8ab8d6`, arrow `#eda94a` | … | … | … | full ring `#4278a8` |
| energy (bolt) | `#eda94a` bolt + `#d98232` + `#f8e4c7` + a **`#000000` block** that grows with level | | | | |
| sleep (moon + star) | `#8c68d3` / `#bca5e8` / `#e3d7f3` + `#eda94a` star + **`#000000` blocks** | | | | |

What this screen actually uses:

| Column | Layer | Fills | Match to DS |
|---|---|---|---|
| Mood | `svgexport-20 1` (28×28) | `#4caf50` leaves, `#388e3c` stem | **Off-system.** These are Material Design greens; they match neither `mood-good` (`#75ba4f/#2a9134`) nor `mood-great` (`#428d52/#175723`), although the label says "Great". |
| Focus | `svgexport-20 (1) 1` (27×27) | `#4278a8`, `#447097`, `#eda94a`, `#ffffff` | **Visually ≈ `focus-great`** (full ring) but a different asset: `#447097` does not occur in the DS glyph. |
| Energy | `ix:electrical-energy-filled` (33×33, Iconify "ix" set) | `#eda94a` only | **Off-system.** The DS energy glyph carries a black level block at every level (see Q6); this screen substitutes a plain filled bolt with no level indication. |
| Sleep | — | — | **Absent.** The DS has a sleep glyph, Edit Check-In has "Your Sleep", Calendar cards show "8h Sleep" — this screen omits the fourth signal. |

All three glyphs are **filled/flat-colour illustrations**, not line icons, and they differ in box size (28 / 27 / 33) which is what breaks the column baselines.

### 5.2 UI icons

| Icon | Library name | Size | Style | Colour | Where |
|---|---|---|---|---|---|
| Back chevron | `vuesax/outline/arrow-left` | 20 | outline (filled path) | `#1e6725` green-700 | header |
| Ellipsis | `vuesax/outline/more` | 25 | outline (3 filled dots) | `#1e6725` | header |
| Capsule / pill | unnamed vector (`SVG`) | 15 in 28 badge | line-style outline | `#4d3974` violet-800 on `#f4f0fb` violet-50 | medication row |
| Sparkles (AI) | unnamed vector (`Group`) | 13.6×16.4 | filled | `#7f5fc0` violet-600 | AI caption |
| Play | `tabler:player-play-filled` | 17.25 in 27.75 circle | filled | `#ffffff` on `#8c68d3` | player |
| Calendar (active tab) | `vuesax/bold/calendar` | 24 | **bold/filled** | `#ffffff` on `#2a9134` | tab bar |
| Check-in (tab) | `vuesax/linear/task-square` | 24 | **linear** (1.5 stroke) | `#999b9d` grey-200 | tab bar |
| Insights (tab) | `vuesax/outline/chart` | 24 | **outline** (filled path) | `#999b9d` | tab bar |
| Settings (tab) | `vuesax/twotone/setting-2` | 24 | **twotone** (1.5 stroke) | `#999b9d` | tab bar |
| Plus (FAB) | `vuesax/twotone/add` | 41 box in 50 circle | stroke 1.826, round caps | `#e9e9ea` grey-50 on `#8c68d3` | FAB |

Style rule implied: **active = vuesax bold (filled), inactive = vuesax line variants** — but the three inactive tabs use three different vuesax families (linear / outline / twotone), so stroke weights and corner treatments are not uniform. Icons on the screen come from four libraries (vuesax, tabler, Iconify-ix, hand-pasted SVG). The DS icon library file lists vuesax only.

Not present on this screen (from the task's checklist): list-check (task-square is the closest), bars (chart), gear (setting-2 present), chevron down/up, mic, pencil, lock.

---

## 6. Data the screen implies

| Field | Type / values seen | Notes |
|---|---|---|
| `date` | calendar day — "Monday, Jun 29" (weekday, abbreviated month, day; no year) | Year shown elsewhere ("September 2026"). |
| `mood.level` | 5-level enum: **Low · Flat · Okay · Good · Great** (from Edit Check-In "Your Sleep"/Insights axis and Calendar) — here **Great** | Value colour per level not tokenised (here `#0e7718`; Calendar uses `#17501d` Great, `#842626` Low, `#da7a2a` Flat, `#1e6725` Okay). |
| `mood.score` | bar fill 78/86 = 0.907 | Not on the 5-step grid — is the bar a continuous score, or should it be level/5 (Q3)? |
| `focus.level` | enum seen across screens: **Distracted · Present · Sharp · Locked In** (+ one unseen low value); here **Sharp**; Insights axis mislabels it "Low/Flat/Okay/Good/Great" | Order and the fifth label are unconfirmed. |
| `focus.score` | 48/86 = 0.558 | Contradicts "Sharp" if Sharp is level 4 of 5 (would be 0.8). |
| `energy.level` | enum seen: **Tired · Steady · Alert · Charged** (+ one unseen); here **Charged**; Insights axis mislabels it "Steady/Alert/Tired/Good/Great" | Order unconfirmed. |
| `energy.score` | 21/86 = 0.244 | **Contradicts "Charged"** (top of scale) — the bar and the label disagree. |
| `emotions[]` | chip labels; here **Proud, Excited** — both from the Edit screen's "Pleasant" list (Excited, Joyful, Proud, Serene, Thrilled, Inspired, Content, Grateful, Peaceful, Secure); "Unpleasant" list: Angry, Anxious, Frustrated, Irritated, Jealous, Sad, Lonely, Disappointed, Hopeless, Discouraged | Are unpleasant emotions rendered in the same green solid chip? (Q5) |
| `sideEffects[]` | not shown, though the transcript mentions "dry mouth" and "jitters" and Edit Check-In has a Side Effects list (Dry Mouth, Headache, Nausea, Appetite Gone, Insomnia, Jittery, Heart Racing, Stomach Ache, Dizzy, Irritable, Rebound, Crash, Sweating, Grinding Teeth, Flat Affect) | Missing section (Q4). |
| `sleepHours` / `sleep.level` | not shown; elsewhere "8h Sleep", "Your Sleep: Low/Flat/Good/Okay/Great" | Missing (Q4). |
| `medications[]` | `{ name: "Concerta", dose: 36, unit: "mg" }`; other names seen: Ritalin, Elvense (sic — "Elvanse"), Vyvans (sic — "Vyvanse"); doses 18/27/36/60 mg; status Taken/Missed; time "09:54"; active-state words Active / Kicking In | Time, status, and taken/missed are not displayed here. |
| `summary.text` | AI narrative, on-device, editable ("tap to Correct") | Needs `isEdited` / provenance flag for the caption. |
| `recording` | `{ duration: 204 s ("03:24"), waveform: [55 amplitudes quantised to 5 levels], playbackPosition: 0.418 }` | 55 bars ≈ 1 bar per 3.7 s at 251 pt — bar count should be derived from available width, not fixed. |
| `checkInTime` | not shown here; sibling screens show "9:15 AM", "18:30", "09:54" — 12 h and 24 h both appear | Pick one (device locale). |

---

## 7. Interactions implied

| Target | Size | Gesture / result | Notes |
|---|---|---|---|
| Back (circle) | 42.6 × 42.6 | tap → pop to Calendar | 1.4 pt under Apple's 44 pt minimum; extend hit area. |
| More `•••` (circle) | 42.6 × 42.6 | tap → menu (Edit → Edit Check-In screen; Delete; Export?) | Menu contents undesigned. Export must never be gated (CLAUDE.md). |
| Signal card / columns | 344 × 113 | probably none; could tap → Edit | Not indicated (no chevron). |
| Emotion chips | 72–82 × 29 | display-only on a detail screen; if tappable they need ≥ 44 pt hit height | Solid = selected everywhere else; here every chip is solid, so they read as "the ones you picked". |
| Medication row | 342 × 50 | probably tap → medication detail / log dose | Not indicated. |
| AI caption "tap to Correct" | 300 × 30 | tap → edit the summary text (inline editor or Edit Check-In?) | Which target is ambiguous (Q10). Is the whole card or only the caption tappable? |
| Summary body | 320 × 60 | same as above? | — |
| Play button | 27.75 circle | tap → play/pause the recording | Far under 44 pt; needs a 44 pt hit area. Icon must swap to pause while playing. |
| Waveform | 251 × 24.75 | drag → scrub (implied by played/unplayed colouring) | Undesigned; if scrubbable, hit height must be extended. |
| Duration "03:24" | 26 × 11 | none (or tap to toggle elapsed/remaining) | — |
| Tab bar items | 65 × 57 (inactive), 94 × 60 (active) | tap → switch tab (pops this screen? or keeps stack?) | Standard iOS: re-tapping the active tab pops to root. |
| FAB `+` | 50 circle | tap → new check-in (Check-in recording flow, `iPhone 17 - 4/5/6`) | From a detail screen, does "+" create a check-in for **this** date or for today? (Q12) |
| Body | — | vertical scroll when content exceeds the frame; **no horizontal scroll** on this screen | Bottom inset must clear the floating tab bar. |
| Swipe from left edge | — | back (system) | — |

No save action exists on this screen (it is read-only); saving happens on Edit Check-In ("Save Changes").

---

## 8. Open questions and ambiguities for the owner

**Q1 — Is this one check-in or the whole day?** Header ("Today's Mood", date only), section titles ("How Does It Feels Today?", "Today's Emotional Condition") and the single signal card say *day*; "Daily Check-In" with one summary and one recording says *one check-in*. The Calendar shows three check-ins on one day. If it is a day view, how are multiple check-ins aggregated (latest? average?) and where are the others listed? If it is one check-in, the title needs the time.

**Q2 — Where is Sleep?** The DS has a sleep glyph, Edit Check-In captures "Your Sleep", Calendar cards show "8h Sleep". This screen shows three signals. Intentional omission or oversight?

**Q3 — What do the bars encode?** 90.7 % / 55.8 % / 24.4 % are not on a 5-step grid, and Energy 24 % is labelled "Charged". Either the bars are a continuous score (then the app needs a numeric score the current 5-level enums don't have) or the fills are placeholder art. Decide: bar = level/5, or drop the bars.

**Q4 — Side effects are missing.** The transcript names dry mouth and jitters; Edit Check-In has a Side Effects chip list. Should a "Side Effects" section (same chip component) appear between Emotions and Medications?

**Q5 — Chip semantics on a read-only screen.** Every chip is `BG=solid` green. Do "Unpleasant" emotions also render green-solid? Are chips tappable here (→ Edit) or static? Should they be the `BG=outline` variant since nothing is being selected?

**Q6 — The DS energy and sleep glyphs render a black block at every level.** (Frame 12, and the Calendar screen.) Is that an unexported mask/clip in the pen file, or an intentional "fill level" indicator that is missing its colour? This screen avoids the issue by using a different bolt (`ix:electrical-energy-filled`) — which one is canonical?

**Q7 — Which sprout/target assets are canonical?** This screen's Mood glyph (`#4caf50/#388e3c`) is not one of the five DS sprouts, and its Focus glyph is a different asset from the DS target. Should the screen use `mood-great` / `focus-great` from Frame 12? If yes, the DS glyphs need one common box size (recommend 32×32) so the three columns align.

**Q8 — Diagonal separators.** They are 81 pt rotated lines whose boxes overlap the neighbouring columns; visually a `/` hairline. Keep as a deliberate stylistic device (then define it as a component), or replace with vertical 1 pt dividers?

**Q9 — Card radius 12 vs 24 and chip 12 pt vs 14 pt.** Which is the rule? (C-15, C-16.)

**Q10 — "tap to Correct" — what opens?** An inline text editor on this card, a dedicated "Correct summary" sheet, or the Edit Check-In screen (which has no summary text field)? And should an edited summary drop the "Written by on-device AI" caption or change it to "Edited by you"?

**Q11 — Player state.** Play icon + 42 % played waveform = paused mid-track, or just static art? Need: playing (pause icon), scrubbing, finished, and "no recording / typed check-in" states. Is "03:24" total or remaining?

**Q12 — FAB on a past day.** Does `+` create a check-in dated today or for the day being viewed?

**Q13 — Typeface.** All text is Inter; DESIGN.md (spec 023) and the shipping app are native SF. Is Inter a stand-in, or is the owner reverting the typography decision? Type sizes assume Inter metrics; SF at the same point sizes will run slightly wider.

**Q14 — Accessibility (numbers, on this screen's colours):**
- "Charged" `#e38400` on white: **2.78 : 1** — fails AA (4.5) and even large-text AA (3.0) at 12/600.
- AI caption `#8a8a8e` on white: **3.44 : 1** — fails AA for 12 pt text.
- Date `#6f7f75` on `#fbfffc`: **4.19 : 1** — fails AA for 12 pt text.
- Chip text white on green-500 `#2a9134`: **4.04 : 1** — fails AA for 14/500 (the Frame 5 "4.04 AA" badge only holds for large text); green-600 `#26842f` gives 4.75.
- Inactive tab icons `#999b9d` on white: **2.79 : 1** — under the 3 : 1 non-text minimum.
- FAB plus `#e9e9ea` on `#8c68d3`: **3.44 : 1** — passes 3 : 1 for icons; pure white would give 4.17.
- Energy bar `#e38400` on track `#e9e9ea`: **2.29 : 1** — bar is hard to read; Mood 3.50, Focus 4.32.
- Unplayed waveform `#eaf4eb` on white: **1.13 : 1** — nearly invisible; also it is *green*-50 inside an otherwise violet player (violet-100 `#dbd0f1` would give ≈ 1.5 : 1 and match).
- Text sizes: the narrative body is 12 pt and the duration is 9 pt (below iOS's 11 pt floor); nothing on the screen is ≥ 17 pt body. Dynamic Type scaling of a 12 pt body and 9 pt caption needs a plan.
- Hit targets: back/more 42.6 pt, play 27.75 pt, chips 29 pt tall — all under 44 pt.

**Q15 — Dark mode.** Only `Mode=Light` variants exist in the DS. Is a dark appearance in scope for the refresh? Several fills (`#fbfffc`, `#e4ece4`, `#6f7f75`, `#8a8a8e`, `#0e7718`, `#447097`, `#e38400`, `#2e8b57`) are off-palette and would need tokens before a dark variant can be derived.

**Q16 — Tab bar label.** The DS `Navigation` component shows a text label in the active pill ("Calendar", 12/500 white, pill 122 wide); this screen and the Calendar screen use an icon-only 64 pt pill. Which is intended?

**Q17 — Medication row content.** Calendar shows time + status + progress for the same medication; this screen shows only name·dose. Should this row show the logged time and taken/missed state, and should tapping it open the medication bar/detail?

---

### Off-palette colour register (for the DESIGN.md token pass)

| Hex | Used for | Nearest DS swatch |
|---|---|---|
| `#fbfffc` | page background | green-50 `#eaf4eb` (too dark), or add `surface` token |
| `#e4ece4` | circle-button stroke, DS chip outline | none — add `stroke-subtle` |
| `#6f7f75` | date subtitle (also used on Check-in and Settings screens) | grey-300 `#6a6d70` |
| `#8a8a8e` | AI caption | grey-200 `#999b9d` / grey-300 |
| `#0e7718` | "Great" | green-700 `#1e6725` |
| `#2e8b57` | Mood bar fill | green-500 `#2a9134` |
| `#447097`, `#4278a8` | Focus label/bar/glyph | no blue ramp exists in Frame 5 |
| `#e38400`, `#eda94a`, `#d98232` | Energy label/bar/glyph | no amber ramp exists in Frame 5 |
| `#4caf50`, `#388e3c` | Mood glyph (Material greens) | mood-good/great glyph colours |
| `#000000` @ 10 % | all card strokes and dividers | none — add `stroke-hairline` |
| `#183c28` @ 6–16 % | all shadows | none — add `shadow` token |
