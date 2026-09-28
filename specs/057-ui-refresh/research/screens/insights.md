<!-- Created: 2026-09-27 22:06 WEST · Updated: 2026-09-27 22:06 WEST -->
# Insights (Statistics) — pen screen "iPhone 17 - 7" (node `xjEsl`, Figma id `78:10620`)

Sources: PNG `pen/named/iphone17-7-statistics.png` (804×4288 @2x = 402×2144 pt, ground truth) · HTML `pen/html-lite/iPhone-17-7.html` · Figma JSON `figma/iphone17-7.json` / `.raw.json`. Design-system frames referenced: Typography (Frame 2), Buttons (Frame 3), Navs (Frame 4), Color palettes (Frame 5), Glyphs (Frame 12), Design Components — Bill-shape + Add Button (Frame 15).

All numbers are 1x points. Font is **Inter** everywhere in the pen file (size/weight written `12/500`). Line height is `AUTO`, letter-spacing `0` on every text node unless noted.

> **Metric caveat (PNG vs JSON).** The PNG and the JSON disagree on one thing: the legend chip row in card 1. In the pen render (PNG, ground truth) the chips are a single non-wrapping flex row (`display:flex; flex-direction:row; gap:7px; width:100%`, no `flex-wrap`) that is clipped at the card's right edge, so card 1 is **284.65 pt tall** (PNG: y 221 → ≈505). The Figma JSON wraps the chips onto two rows (`Frame 1707479481` = 312×57) and makes card 1 **316.65 pt tall** (221 → 537.65). Consequently every JSON y-coordinate from card 2 downward is **32.65 pt lower** than the PNG. Card tops below are quoted from the PNG; internal offsets are quoted relative to the card so they hold in both.

---

## 1. Purpose and placement

- **What it is:** the Insights tab — a monthly statistics read-out of the three signals (Mood, Energy, Focus) with a mood distribution, weekday averages, average ranges, a time-of-day matrix, and cross-signal "Connections".
- **Where it sits:** a **root tab screen**. Evidence: no back pill / nav bar; the floating `Main_navbar` tab bar (Calendar · Check-In · Insights · Settings) plus the violet `Add Button` FAB are present at the bottom; large 34 pt page title at top like Settings (`iPhone 17 - 16`) and Check-In (`iPhone 17 - 4`). It is not a sheet and not pushed.
- **Scroll:** vertical. Frame is 402×2144 (device viewport is 402×874), i.e. this is the full scroll content laid out flat. The tab bar + FAB are placed at y 2041–2101 (bottom of the tall frame), which in the app means they **float over content** and the scroll view needs a bottom inset of ≥ 103 pt (2144 − 2041) plus breathing room.
- **Tab bar state bug:** the selected pill is the **Calendar** item (`vuesax/bold/calendar`, green pill), not the Insights/chart item. The DS Navs frame has a `Status=Insights` variant (chart icon + "Insights" label, 116×44 pill). See §8.
- **Above the fold (0–874 on device):** status bar, title block, month selector, the whole "Mood Check-In Breakdown" card (ends ≈505), and the top of "Your month in three signals" (title, subtitle, Mood row, divider, Energy Level row header + glyph row ≈739–791, divider ≈806, Focus row header ≈821–838; the Focus glyph row ≈848–900 straddles the fold). Because the tab bar floats at ≈771–831 in a real viewport, the Energy glyph row is partly behind it on first paint. Everything from "Where you averaged" down is below the fold.

---

## 2. Layout, top → bottom

### 2.0 Frame
- `iPhone 17 - 7` 402×2144, fill **#fbfffc** (page background), corner radius 32 (device mock), clips content.
- Horizontal gutter: content column `Frame 11` at x = 29, width 344 → **29 pt left/right gutters** (the title block `Frame 2` sits at x = 30).
- Vertical rhythm between sections: **24 pt** (selector→card 1, card→card, card 4→Connections header). Header block→selector: 22. Connections header→first card: 12.

### 2.1 Status bar (`Status Bar` instance) — y 0–52
- Time "9:41" at (32,18) in a 40×21 pill; icons (network 20×14, wifi 16×14, battery 25×14, gap 4) at (301,20). All glyphs **#212529**. Stock iOS light status bar.

### 2.2 Title block (`Frame 2`) — (30,74) 167×63
| Element | Text | Style | Pos |
|---|---|---|---|
| Page title | `Insights` | Inter **34/600**, **#17501d** (green-800) | (30,74) 131×41 |
| Subtitle | `Your Month At Glance` | Inter **16/500**, **#6a6d70** (grey-300) | (30,118) 167×19, 3 pt below title box |

### 2.3 Month selector (`Background`) — (29,159) 344×38
- Container: fill **#fafafa**, stroke **#000000 @ 4 %** 1 pt inside, radius **19**, padding **4**, gap **4**, three equal segments (`flex:1` → 109.33×30 each), radius 15.
- Segment x: 33 / 146.33 / 259.67; text centred.
- **Unselected** (`Container`): no fill; text Inter **12/400 #6a6d70** — `June 2026`, `Aug 2026`.
- **Selected** (`Background+Shadow`): fill **#ffffff**, drop shadow **#193024 @ 7 %**, offset (0,1), blur 3, spread 0; text Inter **12/500 #1e6725** (green-700) — `July 2026`.
- Nothing is clipped; exactly three months visible.

### 2.4 Card 1 — "Mood Check-In Breakdown" (`Frame 5` › `Background`) — top y 221, PNG height ≈284.65 (JSON 316.65)
- Card: **342 wide** (note: 2 pt narrower than every other card, which is 344), fill **#ffffff**, stroke **#000000 @ 10 %** 0.5 pt inside, radius **24**, shadow **#183c28 @ 8 %** offset (0,3) blur 8 spread 0. Padding **15** all sides; internal column gap **20** (header→content).
- **Header row** (`Frame 1707479480`, 312×19, space-between, gap 8) at card+15:
  - `Mood Check-In Breackdoen` Inter **16/600 #212529** (215×19, left).
  - `24 check-ins` Inter **12/500 #4d5154** (grey-400), right-aligned, 2 pt down (vertically centred).
- **Bubble chart** (`bubbleChart`, 306×160.65 at card-x+18 / card+54, i.e. abs (47,275)). Five absolutely-positioned circles, later = on top (z-order Low < Flat < Okay < Good < Great — PNG confirms Great is topmost). Centre y rises ≈13 pt per step left→right. Each bubble is a column stack of two centred texts, gap ≈1: percent Inter **14/500**, label Inter **12/500**.

| Bubble (`bubble/*`) | Fill | Diameter | Top-left (abs) | Centre | Texts | Text colour |
|---|---|---|---|---|---|---|
| Low | **#da7a2a** | 70.76 | (47, 350.54) | (82.4, 385.9) | `8%` / `Low` | #1c1b1f |
| Flat | **#eda94a** | 84.15 | (99.59, 330.46) | (141.7, 372.5) | `17%` / `Flat` | #1c1b1f |
| Okay | **#9dcca2** (green-200) | 103.28 | (153.14, 307.51) | (204.8, 359.2) | `33%` / `Okay` | #1c1b1f |
| Good | **#55a75d** (green-400) | 98.49 | (218.65, 296.51) | (267.9, 345.8) | `29%` / `Good` | #1c1b1f |
| Great | **#2a9134** (green-500) | 78.41 | (284.15, 293.17) | (323.4, 332.4) | `13%` / `Great` | **#ffffff** |

  - Diameter vs percentage is roughly linear, d ≈ 60 + 1.3·pct (8→70.8, 13→78.4, 17→84.2, 29→98.5, 33→103.3). Not a true area scale — formula needs confirmation (§8).
- **Divider** (`Line 2`): 312×1, stroke **#000000 @ 10 %**, 15 pt below the chart (abs y 450.65).
- **Legend row** (`Frame 1707479481`): 15 pt below the divider; horizontal flex row, gap **7**, no wrap. Five `Bill-shape` instances, variant **`BG=With Dot`** (DS Frame 15): height 25, radius 15, fill **#ffffff**, stroke **#e4ece4** 1 pt inside, padding 4 × 12 (HTML) / dot at x+13 (JSON), dot 8×8, gap 4 to text, text Inter **12/500** (JSON reports "mixed" fills; DS component text is **#193024**).

| Chip | Width | Dot | Text |
|---|---|---|---|
| 1 | 82 | #da7a2a | `Low (2)` |
| 2 | 80 | #eda94a | `Flat (4)` |
| 3 | 88 | #9dcca2 | `Okey (8)` |
| 4 | 89 | #55a75d | `Good (7)` |
| 5 | 90 | #2a9134 | `Great (3)` |

  - Sum of widths + gaps = 457 > 312 available. **PNG:** one row, `Good (7)` clipped at the card edge, `Great (3)` not visible → implies a horizontally scrolling legend (or a layout defect). **JSON:** wraps to two rows (row 2 at +32: `Good (7)`, `Great (3)`).
- Bottom padding 15.

### 2.5 Card 2 — "Your month in three signals" (`Frame 4`) — PNG top ≈529.65 (JSON 561.65), height 386.65
- Card: 344×386.65, same skin as card 1 (white, 0.5 pt #000 @ 10 % inside stroke, r 24, shadow #183c28 @ 8 % (0,3) 8). Padding 15; header→content gap 20.
- **Header** (`Frame 1707479484`, 314×38): `Your month in three signals` Inter **16/600 #212529**; 2 pt gap; `Average Across Weekdays In July` Inter **14/400 #6a6d70**.
- **Three signal rows** (`Container`, 312×79.55 each), separated by a 1 pt divider (#000 @ 10 %, 314 wide) with **15 pt above and below**. Each row:
  - **Row header** (`Paragraph`, 312×17, space-between): leading icon + label (gap 5) and a trailing summary tag.
  - 10 pt gap.
  - **Weekday glyph row** (`842_frame`, 312×52.55, overflow hidden): 7 equal columns (`flex:1` → 44.57 wide), each a centred column of glyph **33.55×33.55** + gap 4 + weekday label Inter **12/500 #4d5154** (15 tall). Nothing clipped horizontally.
  - Column 7 (Sunday) is the **empty state**: an 18×18 circle, stroke **#8e8e93 @ 30 %**, 1.33 pt, no fill, centred in the 33.55 glyph slot; label `Su`.

| Row | Header icon | Label (Inter 14/500 #292d32) | Trailing tag (Inter 12/600) | Mo | Tu | We | Th | Fr | Sa | Su |
|---|---|---|---|---|---|---|---|---|---|---|
| Mood | `svgexport-20` sprout 14×14 (#4caf50 / #388e3c) | `Mood` | `Mostly Okay` **#2a9134** | mood-low | mood-flat | mood-okay | mood-good | mood-great | mood-okay | empty |
| Energy | bolt vector 9×14 fill **#eda94a** | `Energy Level` | `Mostly Steady` **#e38400** | energy-low | energy-flat | energy-okay | energy-great (label reads `Fr`) | energy-good (label `Fr`) | energy-okay | empty |
| Focus | target 14×14 (#4278a8 / #447097 / #eda94a / #ffffff) | `Focus` | `Mostly Sharp` **#4278a8** | focus-low | focus-flat | focus-okay | focus-good | focus-great | focus-great | empty |

  - Weekday labels: Mood/Focus rows `Mo Tu We Th Fr Sa Su`; **Energy row reads `Mo Tu We Fr Fr Sa Su`** (Th missing, Fr duplicated).
  - One energy cell (`energy-good 1`, Friday) is 33×33 instead of 33.55 — negligible.
- Bottom padding 15.

### 2.6 Card 3 — "Where you averaged" (`Frame 8`) — PNG top ≈940.3 (JSON 972.3), height 365
- Card 344×365, same skin. Padding 15; header→content 20.
- **Header**: `Where you averaged` Inter **16/600 #212529** (title only, 19 tall).
- **Three rows**, 1 pt dividers with 15 above/below. Row 1 (Mood) is 82 tall (header 17 + **15** gap + bar block 50); rows 2–3 are 77 tall (header 17 + **10** gap + 50) — inconsistent by 5 pt.
  - **Row header** (`Paragraph`, 312×17, space-between): icon + label as in card 2 (Inter 14/500 #292d32); trailing caption Inter **12/400 #6a6d70**.
  - **Bar block** (`Frame 1707479487`, 312×50): a **range bracket** (`Vector 13`, 73×21, stroke **#4d5154** 1.25 pt, round caps, "⊓" shape: horizontal top + two legs) at block-top, absolutely positioned; then at block+24 the **segment row** (`Frame 1707479475`): 5 pills **60.8×7**, radius 999, gap **2**, each with a centred label 4 pt below, Inter **12/400 #6a6d70**.
  - Segment fills, left→right, identical for all three rows: **#da7a2a · #eda94a · #9dcca2 · #55a75d · #2a9134** (the mood ramp is reused for Energy and Focus).

| Row | Caption | Segment labels (1→5) | Bracket x (rel. to row) | Bracket spans |
|---|---|---|---|---|
| Mood | `Between Okay & Good` | `Low` `Flat` `Okay` `Good` `Great` | 147 → 220 | segments 3–4 (Okay–Good) ✔ |
| Energy Level | `Between Tired & Steady` | `Steady` `Alert` `Tired` `Good` `Great` | 77 → 150 | segments 2–3 (Alert–Tired) ✘ caption |
| Focus | `Between Present & Sharp` | `Low` `Flat` `Okay` `Good` `Great` | 217 → 290 | segments 4–5 (Good–Great) ✘ labels |

- Bottom padding 15.

### 2.7 Card 4 — "Your Daily Rhythm" (`Frame 9`) — PNG top ≈1329.3 (JSON 1361.3), height 356
- Card 344×356, same skin. Padding 15; header→matrix 20.
- **Header**: `Your Daily Rhythm` Inter **16/600 #212529**; 2 pt; `Dominant level per signal by time of day` Inter **14/400 #6a6d70**.
- **Column header row** (`1045_frame`, 314×30, overflow hidden): a 48 pt spacer, then four `flex:1` cells (66.5 wide) with centred Inter **12/500 #4d5154** text: `MORNING` `AFTERNOON` `EVENING` `LATE`. Strings are typed in caps (no `textCase`). `AFTERNOON` does not fit 66.5 pt and **wraps to two lines** (`AFTERNOO` / `N`) — the cell is 66.5×30, the others 66.5×15.
- 11 pt gap, then **three matrix rows** (`1051_frame`/`1080_frame`/`1103_frame`, 314×61, align centre), 1 pt dividers (#000 @ 10 %) with **11 pt** above/below.
  - **Row label cell** (`Frame 1707479485`, 41 wide, centred column, gap 3): signal icon + label Inter **12/500 #292d32**. Mood icon = sprout 20×20 (#4caf50/#388e3c); Energy = bolt 13×19 #eda94a; Focus = target 17×17.
  - **Four value cells** (`flex:1` → 68.25 wide; NB header cells are 66.5 wide from x 92 while value cells start at x 85 — column centres drift by up to ~5 pt): centred column of a **44×44 circle (r 22)** containing a 33.55 glyph, gap 4, label Inter **11/500 #6a6d70**.
  - **Empty cell** (`LATE` column, all rows): 44×44 circle, **no fill, stroke #dbddde 1 pt inside**; label `—` Inter **11/400 #8a8a8e @ 60 % opacity**.

| Row | Morning | Afternoon | Evening | Late |
|---|---|---|---|---|
| `Mood` | mood-okay on **#ddf4de @ 20 %** · `Okay` | mood-good on **#9dcca2 @ 20 %** · `Good` | mood-great on **#9dcca2 @ 30 %** · `Great` | empty · `—` |
| `Energy` | energy-flat on **#fdf6eb** (opaque) · `Steady` | energy-good on **#eda94a @ 30 %** · `Alert` | energy-okay on **#c79043 @ 20 %** · `Tired` | empty · `—` |
| `Focus` | focus-great on **#4278a8 @ 10 %** · `Sharp` | focus-great on **#4278a8 @ 10 %** · `Sharp` | focus-flat on **#72a3ff @ 8 %** · `Present` | empty · `—` |

  - The energy glyphs inside rhythm cells use a paler bolt shadow **#f0cf9e** (vs **#f8e4c7** in card 2).
- Bottom padding 15.

### 2.8 Connections (`Frame 10`) — PNG top ≈1709.3 (JSON 1741.3), 344×324
- **Section header on the page background** (not in a card): `Connections` Inter **16/600 #212529**; 2 pt; `Patterns across signals — 3 or more days to unlock` Inter **14/400 #6a6d70**. 12 pt to the first card.
- **Three cards** stacked with gap **5** (`Frame 1707479499`): 344 wide, fill #ffffff, stroke #000 @ 10 % 0.5 inside, radius **18** (smaller than the 24 of the stat cards), shadow #183c28 @ 8 % (0,3) 8. Padding 15. Row layout: **icon tile 42×42 r 11** (stroke #000 @ 10 % 0.45 inside) + 10 pt + text column 262 wide (title 12/600 uppercase-typed, 5 pt, body 12/500 #212529, 2 lines = 30 tall).

| Card | Height | Tile fill | Icon | Title (Inter 12/600 **#7f5fc0** violet-600) | Body (Inter 12/500 #212529) | Extra |
|---|---|---|---|---|---|---|
| A | 104 | **#e3d8f9** | `vuesax/bold/unlock` 20×20 **#4d3974** (violet-800) | `MEDICATION × FOCUS` | `On Medication Days, Sharp Focus Appeared 75% Of The Time.` | progress row 9 pt below body: track **285×6** r 9.5 fill #fafafa stroke #000 @ 10 % 0.25; fill **165×6** linear gradient 90° **#8061bf → #8c68d3**; trailing `70%` Inter 12/500 **#193024** |
| B | 80 | **#f4f0fb** (violet-50) | `vuesax/bold/lock` 20×20 **#7f5fc0** | `SLEEP × MOOD` | `Note 1 More Good Sleep Day & 3More Poor-Sleep Days To Unlock This Connection` | — |
| C | 80 | **#f4f0fb** | `vuesax/bold/lock` 20×20 **#7f5fc0** | `ENERGY × MOOD` | `Log High Energy 2 More Days To Unlock This Connection` | — |

  - Progress fill is 165/285 = **58 %** of the track, the trailing label says **70 %**, the sentence says **75 %** — three different numbers.
  - PNG: last card ends ≈2033, tab bar starts 2041 (8 pt clearance). JSON (wrapped chips): last card ends 2065 and is overlapped by the tab bar by 24 pt.

### 2.9 Tab bar + FAB (`Main_navbar` instance) — (28,2041) 346×60
- Row, gap **22**, right-aligned: `Navigation` pill + `Add Button`.
- **`Navigation`**: 274×60, fill #ffffff, radius 75, shadow **#183c28 @ 16 %** offset (0,8) blur 24 (HTML: `0 8px 21px #183c2829`); items `space-between`.
  - Selected item (`navigation/menu - home`): outer 94×60 (padding 8 × 15), inner pill **64×44**, fill **#2a9134**, radius 44, padding 10 × 20, icon `vuesax/bold/calendar` 24×24 **#ffffff**. **No label** (DS variant has the label).
  - Unselected items 65×57 each, icon 24×24 **#999b9d** (grey-200): `vuesax/linear/task-square` (1.5 stroke), `vuesax/outline/chart`, `vuesax/twotone/setting-2` (1.5 stroke).
- **`Add Button`** (DS Frame 15 component): 50×50 at (324,2046), fill **#8c68d3** (violet-500), radius 75 (circle), shadow **#000000 @ 17 %** offset (0,7) blur 17 (HTML `0 7px 14.875px #0000002b`); icon `vuesax/twotone/add` 41×41, two 20.5 pt strokes **#e9e9ea** 1.71 pt.
- **Home indicator**: 143×5, radius 10, **#212529** at (129,2131).

---

## 3. Component instances and states

| Component (DS name) | Instances on this screen | State(s) shown |
|---|---|---|
| Status Bar (light) | 1 | default |
| Segmented month selector (no DS component; local `Background` + `Container`/`Background+Shadow`) | 1 × 3 segments | `July 2026` **selected** (white, shadow, 12/500 green-700); `June 2026`, `Aug 2026` **unselected** (12/400 grey-300) |
| Stat card (local `Background`, r 24) | 4 | default; card 1 is 342 wide, others 344 |
| Bubble (`bubble/Low…Great`) | 5 | sized by %; Great uses white text, others #1c1b1f |
| **Bill-shape · `BG=With Dot`** (Frame 15) | 5 | all outlined white with coloured dot; 4th clipped at card edge, 5th hidden (PNG) — implies horizontal scroll or overflow bug. No `BG=solid` (selected) chip on this screen |
| Signal row header (icon + label + trailing tag) | 3 (card 2) + 3 (card 3) | tag coloured per signal: green #2a9134 / amber #e38400 / blue #4278a8 (card 2); grey caption 12/400 (card 3) |
| Weekday glyph cell | 21 | 18 **filled level glyphs** (levels 1–5), 3 **empty** (18 pt hairline circle #8e8e93 @ 30 %) |
| Range bar (5 pills + bracket) | 3 | bracket over segments 3–4 / 2–3 / 4–5 |
| Rhythm cell (44 pt circle) | 12 | 9 **filled** (tinted circle + glyph + 11/500 label), 3 **empty** (hairline #dbddde circle + `—` @ 60 %) |
| Connection card (r 18) | 3 | A **unlocked** (tile #e3d8f9, `vuesax/bold/unlock` #4d3974, progress bar); B, C **locked** (tile #f4f0fb, `vuesax/bold/lock` #7f5fc0, no bar) |
| Progress bar | 1 | 58 % fill, violet gradient |
| **Main_navbar › Navigation** (Frame 4) | 1 | **Calendar selected, icon-only** (no label). Expected `Status=Insights` |
| **Add Button** (Frame 15) | 1 | default (violet, +) |
| Home Indicator | 1 | default |

Rows clipped at an edge: only the legend chip row (card edge, not frame edge). Nothing else overflows horizontally.

---

## 4. Copy inventory (verbatim) and copy issues

### 4.1 Every string, in reading order
Status: `9:41`
Title block: `Insights` · `Your Month At Glance`
Month selector: `June 2026` · `July 2026` · `Aug 2026`
Card 1: `Mood Check-In Breackdoen` · `24 check-ins` · `8%` `Low` · `17%` `Flat` · `33%` `Okay` · `29%` `Good` · `13%` `Great` · `Low (2)` · `Flat (4)` · `Okey (8)` · `Good (7)` · `Great (3)`
Card 2: `Your month in three signals` · `Average Across Weekdays In July` · `Mood` · `Mostly Okay` · `Mo` `Tu` `We` `Th` `Fr` `Sa` `Su` · `Energy Level` · `Mostly Steady` · `Mo` `Tu` `We` `Fr` `Fr` `Sa` `Su` · `Focus` · `Mostly Sharp` · `Mo` `Tu` `We` `Th` `Fr` `Sa` `Su`
Card 3: `Where you averaged` · `Mood` · `Between Okay & Good` · `Low` `Flat` `Okay` `Good` `Great` · `Energy Level` · `Between Tired & Steady` · `Steady` `Alert` `Tired` `Good` `Great` · `Focus` · `Between Present & Sharp` · `Low` `Flat` `Okay` `Good` `Great`
Card 4: `Your Daily Rhythm` · `Dominant level per signal by time of day` · `MORNING` `AFTERNOON` `EVENING` `LATE` · `Mood` · `Okay` `Good` `Great` `—` · `Energy` · `Steady` `Alert` `Tired` `—` · `Focus` · `Sharp` `Sharp` `Present` `—`
Connections: `Connections` · `Patterns across signals — 3 or more days to unlock` · `MEDICATION × FOCUS` · `On Medication Days, Sharp Focus Appeared 75% Of The Time.` · `70%` · `SLEEP × MOOD` · `Note 1 More Good Sleep Day & 3More Poor-Sleep Days To Unlock This Connection` · `ENERGY × MOOD` · `Log High Energy 2 More Days To Unlock This Connection`
Tab bar: no text (icon-only).

### 4.2 Typos and inconsistencies
1. `Mood Check-In Breackdoen` → "Mood Check-In Breakdown".
2. `Okey (8)` (legend chip) → "Okay (8)"; the bubble already says `Okay`.
3. `Your Month At Glance` → "Your Month at a Glance" (missing article; also Title Case vs sentence case elsewhere).
4. Month labels mix full and abbreviated names: `June 2026`, `July 2026` vs `Aug 2026`.
5. Energy weekday labels `Mo Tu We Fr Fr Sa Su` — `Th` missing, `Fr` duplicated.
6. `AFTERNOON` wraps to `AFTERNOO` / `N` (layout defect, 66.5 pt column).
7. Energy scale under "Where you averaged" reads `Steady · Alert · Tired · Good · Great` — mixes energy and mood vocabulary and is not ordered low→high.
8. Focus scale under "Where you averaged" reads `Low · Flat · Okay · Good · Great` — mood vocabulary under Focus.
9. Caption `Between Tired & Steady` vs bracket drawn over `Alert`–`Tired`.
10. Caption `Between Present & Sharp` vs bracket drawn over `Good`–`Great` (mood labels).
11. `3More` → "3 More"; `Poor-Sleep` hyphenated while `Good Sleep` is not.
12. Connection A: sentence says `75%`, label says `70%`, bar is 58 % full.
13. Connection bodies are Title Case (`On Medication Days, Sharp Focus Appeared…`) while subtitles elsewhere are sentence case; card A ends with a period, B and C do not.
14. Section-title casing is inconsistent: `Mood Check-In Breackdoen` / `Your Daily Rhythm` (Title) vs `Your month in three signals` / `Where you averaged` (sentence). Subtitles likewise: `Average Across Weekdays In July` (Title) vs `Dominant level per signal by time of day` (sentence).
15. Signal label `Energy Level` (cards 2–3) vs `Energy` (card 4).
16. Subtitle says `Average Across Weekdays In July` but the row shows `Sa` and `Su` (weekend columns; Su empty).
17. `Mostly Steady` / `Mostly Sharp` do not map to a stated level on the scales shown beneath them.
18. Hairline "Su" empty circle (18 pt, #8e8e93) and rhythm empty circle (44 pt, #dbddde) use different empty-state styling.

---

## 5. Glyph and icon usage

### 5.1 Signal level glyphs (DS Frame 12 names `<signal>-<level> 1`, level ∈ low/flat/okay/good/great = 1…5)
- **Mood sprout** — two leaves + stem, filled, colour ramp per level:
  - low: leaves **#d97773** / **#bc4749**, stem stroke #bc4749 1.57, veins #bc4749 / #eeb4aa
  - flat: **#e8b964** / **#c58b37**, veins #c58b37 / #f6dca6
  - okay: **#b1c194** / **#82936b**, veins #82936b / #d9e2c6
  - good: **#75ba4f** / **#2a9134**, veins #2a9134 / #b7dc88
  - great: **#428d52** / **#175723**, veins #175723 / #9ccaa0
  - Used: card 2 Mood row (low, flat, okay, good, great, okay), card 4 Mood row (okay, good, great). Rendered at 33.55 pt.
- **Energy bolt** — amber bolt (**#eda94a** face, **#d98232** shade) over a pale bolt shadow (**#f8e4c7**; **#f0cf9e** inside rhythm cells) and a **solid #000000 block** whose height encodes the level (8.8 / 13.95 / 19.08 / 23.82 / 29.36 pt of 33.55). Layers are named `Clip path group` / `asset-energy-*-fill`, which suggests the black block may be an exported clip mask rather than intended art — but both the screen PNG and the DS Glyphs PNG render it black. Used: card 2 Energy row (low, flat, okay, great, good, okay), card 4 Energy row (flat, good, okay).
- **Focus target** — pale ring **#d6e5f0**, blue arc **#4278a8** whose sweep encodes level (¼ … full), inner disc **#8ab8d6**, amber arrow **#eda94a**. Used: card 2 Focus row (low, flat, okay, good, great, great), card 4 Focus row (great, great, flat).
- **Sleep moon** (DS Frame 12) — **not used** on this screen.

### 5.2 Signal header icons (not the level glyphs)
- Mood: `svgexport-20 (1) 1` sprout, 14×14 (card 2/3) and 20×20 (card 4), fills **#4caf50** / **#388e3c** (Material greens — off the DS green ramp).
- Energy: single bolt vector, 9×14 (cards 2/3) and 13×19 (card 4), fill **#eda94a**, filled style.
- Focus: `Layer 9` target 14×14 (cards 2/3) / 17×17 (card 4), fills #ffffff, **#4278a8**, **#447097**, arrow **#eda94a**, filled style.

### 5.3 UI icons (vuesax set)
| Icon | Variant | Size | Colour | Where |
|---|---|---|---|---|
| calendar | `vuesax/bold` (filled) | 24 | #ffffff on #2a9134 | tab bar, selected |
| task-square (list-check) | `vuesax/linear` (outline 1.5) | 24 | #999b9d | tab bar |
| chart (bars) | `vuesax/outline` (filled bars) | 24 | #999b9d | tab bar |
| setting-2 (gear) | `vuesax/twotone` (outline 1.5) | 24 | #999b9d | tab bar |
| add (plus) | `vuesax/twotone` (2 strokes 1.71) | 41 in 50 circle | #e9e9ea on #8c68d3 | FAB |
| unlock | `vuesax/bold` (filled) | 20 in 42 tile | #4d3974 on #e3d8f9 | Connection A |
| lock | `vuesax/bold` (filled) | 20 in 42 tile | #7f5fc0 on #f4f0fb | Connections B, C |
Not present: chevron, ellipsis, mic, capsule, pencil, play, sparkles.

### 5.4 Palette mapping (DS Frame 5) and off-palette colours
- On-palette: #17501d green-800 · #1e6725 green-700 · #2a9134 green-500 · #55a75d green-400 · #9dcca2 green-200 · #212529 grey-500 · #4d5154 grey-400 · #6a6d70 grey-300 · #999b9d grey-200 · #e9e9ea grey-50 · #8c68d3 violet-500 · #7f5fc0 violet-600 · #4d3974 violet-800 · #f4f0fb violet-50.
- Off-palette (used here, absent from Frame 5): page #fbfffc; text #292d32, #1c1b1f, #193024, #8a8a8e; amber/orange ramp #da7a2a, #eda94a, #e38400, #d98232, #c79043, #f8e4c7, #f0cf9e, #fdf6eb; blue ramp #4278a8, #447097, #8ab8d6, #d6e5f0, #72a3ff; violet tint #e3d8f9, gradient stop #8061bf; hairlines #e4ece4, #dbddde; mood glyph ramp colours (§5.1); Material greens #4caf50/#388e3c.

---

## 6. Data implied

- **Month context**: selected month (`July 2026`), previous (`June 2026`) and next (`Aug 2026`) — a month cursor with neighbours; presumably bounded by data availability.
- **Check-in count** for the month: `24 check-ins`.
- **Mood distribution** (per month): count per level → Low 2, Flat 4, Okay 8, Good 7, Great 3 (sum 24 ✔); percentages 8/17/33/29/13 are integer-rounded shares (2/24 = 8.3, 3/24 = 12.5 → 13; they sum to 100).
- **Mood enum**: Low · Flat · Okay · Good · Great (5 levels, consistent with Edit Check-In and Calendar screens).
- **Energy enum**: this screen uses Steady, Alert, Tired (+ mood leftovers Good/Great). Other pen screens use Charged (Day-mode details, Edit Check-In), Alert/Tired (Calendar). Task brief lists Alert/Tired/Steady/Charged. Order and glyph-level mapping are undefined here (rhythm cells map Steady→level 2, Alert→level 4, Tired→level 3).
- **Focus enum**: Sharp, Present here; Distracted, Locked In elsewhere (Calendar). Rhythm cells map Sharp→level 5, Present→level 2.
- **Weekday average per signal** (Mon…Sun): a level 1–5 or null (Sunday null in all rows) + a modal summary (`Mostly Okay/Steady/Sharp`). Subtitle wording implies weekdays only, layout shows 7 days.
- **Average range per signal**: an adjacent pair of levels (lo, hi) → caption `Between <lo> & <hi>` and a bracket over those two segments.
- **Daily rhythm**: dominant level per signal × daypart (Morning, Afternoon, Evening, Late), nullable (`—`). Daypart boundaries undefined.
- **Connections** (cross-signal insights): identity (`MEDICATION × FOCUS`, `SLEEP × MOOD`, `ENERGY × MOOD`), state (unlocked / locked), unlock threshold ("3 or more days"), for locked: remaining-day requirements per condition (1 more good-sleep day & 3 more poor-sleep days; 2 more high-energy days), for unlocked: a statistic sentence (75 %) and a progress value (70 % label / 58 % bar). Requires medication-day, sleep-quality and energy-level data joined to focus/mood per day.
- Not on this screen (but in the brief's list): medication name/dose, hours of sleep, timestamps, Active/Kicking In — none appear here.

---

## 7. Interactions implied

- **Vertical scroll** of the whole page; tab bar + FAB float over content (need bottom content inset).
- **Month selector**: tap a segment to switch month (3 visible; likely also horizontal paging/swipe to reach earlier months — not shown).
- **Legend chips**: the clipped row implies **horizontal scroll** of the legend; possibly tap-to-highlight a bubble (not indicated — all chips are in the outlined, unselected variant).
- **Bubbles, weekday glyphs, range bars, rhythm cells**: no affordance shown (static read-outs). Possible drill-in (e.g. tap a weekday → Calendar) is not indicated.
- **Connection cards**: unlocked card A may be tappable for detail (no chevron shown); locked cards B/C read as informational.
- **Tab bar**: 4 tabs (Calendar, Check-In, Insights, Settings); tap to switch. **FAB `+`**: new entry (DS "Add Button"; on the Check-In screen family this starts a check-in).
- No back, no save, no toggles, no expand/collapse on this screen.

---

## 8. Open questions / ambiguities for the owner

1. **Tab bar state** — the pen shows Calendar selected (icon-only pill) on the Insights screen. Should this instance be the DS `Status=Insights` variant (chart icon + `Insights` label, 116×44)? And is the selected pill always labelled (DS) or icon-only (this screen)?
2. **Legend chips** — one clipped row (PNG) or two wrapped rows (Figma export)? If one row, is it horizontally scrollable, and should the card fade/mask the clipped edge?
3. **Bubble sizing rule** — diameters follow ≈ 60 + 1.3·pct, not an area-proportional scale. Confirm the formula, min/max diameter, and how 0 % levels are shown (hidden? minimum bubble?).
4. **Energy and Focus scales** — confirm the canonical enums and their order (Energy: Tired → Steady → Alert → Charged? Focus: Distracted → Present → Sharp → Locked In?) so "Where you averaged", "Mostly …" tags and rhythm cells can be labelled correctly. The pen currently reuses mood labels and the mood colour ramp for both.
5. **Energy glyph black block** — intended art (solid #000000 level indicator) or a broken clip-mask export? It is the only pure-black fill in the system.
6. **Rhythm cell tints** — nine different fill/opacity combos (#ddf4de@20, #9dcca2@20/30, #fdf6eb, #eda94a@30, #c79043@20, #4278a8@10, #72a3ff@8). Should this be one rule (signal colour @ fixed alpha, or per-level alpha)?
7. **Connection A numbers** — 75 % (copy) vs 70 % (label) vs 58 % (bar). Which is the progress bar measuring (confidence? days logged toward the threshold?), and is it distinct from the stat in the sentence?
8. **Unlock thresholds** — "3 or more days" header vs per-card requirements (1 & 3 days, 2 days). Is the rule per signal-pair, per condition, or global?
9. **Sunday column** — subtitle says weekdays; the row shows Sa and an empty Su. Weekend included or not? What does the empty circle mean (no check-ins vs. excluded)?
10. **Daypart boundaries** for Morning / Afternoon / Evening / Late, and what "dominant" means (mode? mean rounded?).
11. **Card 1 width 342 vs 344** — intentional or drift?
12. **Card 3 row spacing** — 15 pt after the Mood header vs 10 pt after Energy/Focus headers; which is right?
13. **Colour tokens** — the amber/orange and blue ramps used for Energy and Focus, and the mood glyph ramp, are not in the Color palettes frame. Should they be added as tokens (the app's `Palette` needs names for them)?
14. **Header sprout icon** uses Material greens #4caf50/#388e3c rather than the DS ramp — replace with a DS-green sprout or the `mood-good` glyph?
15. **Typeface** — the pen file is set in Inter; the shipping app is native SF (DESIGN.md typography reversal, spec 023). Confirm SF with the same sizes/weights, or a deliberate switch to Inter.
16. **Month selector behaviour** — fixed three segments, or a scrolling strip of months? What happens at the first month with data?
17. **Empty/low-data states** — what does this screen show for a month with 0–2 check-ins, and does the 32-pt-shorter card layout change when the legend has fewer levels?
18. **Copy fixes** — approve the corrections in §4.2 (Breakdown, Okay, "at a Glance", Th/Fr, "3 More", casing rules) before the DESIGN.md copy table is written.
