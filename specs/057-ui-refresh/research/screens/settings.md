<!-- Created: 2026-09-27 22:08 (WEST) · Updated: 2026-09-27 22:08 (WEST) -->
# Screen spec — Settings ("iPhone 17 - 16", pen node `IoBoz`, Figma id `72:10008`)

| | |
|---|---|
| Label in file | Settings · the Settings tab (Check-In Calendar, Voice & Storage, Confirmations, Dose Guard, Medication Bar, Accessibility, Your Data, tab bar + FAB) |
| Sources used | PNG `pen/named/iphone17-16-settings.png` (804×3798 = 402×1899 @2x — ground truth) → Figma JSON `figma/iphone17-16.json` + `.raw.json` (every number) → HTML `pen/html-lite/iPhone-17-16.html` (layer names, padding/gap) → DS frames 2 / 3 / 4 / 5 / 12 / 15 (component and token names). The `.pen` file was not opened. |
| Existing code read for mapping only (no changes) | `app-four/Views/SettingsView.swift`, `Views/Settings/*`, `Models/AppSettings.swift`, `Models/DoseGuardMode.swift`, `Models/PromptPace.swift` |
| Status | Planning only. No Swift changes. Coordinates are pt inside the 402-wide frame, origin top-left, `(x, y) w×h`. Hex quoted exactly as exported; a palette name in brackets means the value matches a Frame 5 swatch; "off-palette" means it does not. |

---

## 1. Purpose and placement

**What it is.** The app's preferences screen: seven titled card groups — voice-prompt pace and calendar-card behaviour, on-device model status and storage, medication-name privacy in confirmations, Dose Guard (double-log protection for hands-free logs), the medication bar's visibility rows, a Reduce-Motion note, and the on-device data promise. It replaces today's native `insetGrouped` `List` in `SettingsView.swift` with custom white cards, custom toggles, bill-shape chips and radio rows.

**Where it sits — inferred from chrome.**

| Evidence | Reading |
|---|---|
| Large display title "Settings" (34/600 green-800) with a subtitle, **no back pill**, no "…" | A **root screen**, not pushed and not a sheet. |
| `Main_navbar` (DS Frame 4 `Navigation`, variant **`Status=Settings, Mode=Light`**) at the bottom with the gear in the filled green pill | It **is the Settings tab** — the 4th tab (Calendar · Check In · Insights · Settings), matching `RootTabView`'s `.settings` case. |
| Violet `Add Button` FAB (DS Frame 15) above the right end of the nav | The FAB is global chrome; a new check-in can be started from Settings. |
| Status bar + home indicator are the standard iOS light instances | Nothing custom. |

**Canvas vs device.** The frame is **402 × 1899**, i.e. **1025 pt taller than an iPhone 17 viewport (874)**. The content column runs y 159 → 1780 and the nav/FAB group is drawn at the canvas bottom (nav y 1809, FAB y 1745), so the artboard is a *fully unrolled* scroll view with the floating chrome parked at the end. Treat the nav bar and FAB as **pinned overlays** (as on every other frame) and the seven groups as one vertical `ScrollView`. See §2.10 for what falls above/below the fold and the FAB collision at rest.

---

## 2. Layout, top → bottom

**Frame** `iPhone 17 - 16` (0,0) 402×1899 — fill `#fbfffc` (off-palette green-tinted near-white; green-50 is `#eaf4eb`), corner radius 32 (device mask), `clipsContent`.

**Three different left edges are in play:** title block x = **32**, content column x = **29** (width 344 → right gutter 29), nav/FAB group x = **28** (width 346). See Open question 15.

Vertical rhythm (y in pt, JSON geometry):

```
    0 ── Status Bar 402×52
   74 ── "Settings"                       34/600 #17501d   138×41   (x 32)
  115      gap 3
  118 ── "Make The App Works For You"      16/500 #6a6d70   225×19
  137      gap 22
  159 ── Content column (29,159) 344×1621.08, vertical auto-layout, gap 24
  159 ──   §2.2 Check-In Claendar   heading 19 · gap 12 · card 223.62  → 413.62
  437.62 ── §2.3 Voice & Storage    heading 19 · gap 12 · card 184     → 652.62
  676.62 ── §2.4 Confirmations      heading 19 · gap 12 · card 167     → 874.62
  898.62 ── §2.5 Dose Guard         heading 19 · gap 12 · card 312     → 1241.62
 1265.62 ── §2.6 Medication Bar     heading 19 · gap 12 · card 210.46  → 1507.08
 1531.08 ── §2.7 Accessibility      heading 19 · gap 12 · card 81      → 1643.08
 1667.08 ── §2.8 Your Data          heading 19 · gap 12 · card 82      → 1780.08
 1745 ── Add Button (309,1745) 50×50           ← overlaps the Your Data card's bottom-right (JSON)
 1809 ── Navigation (28,1809) 346×60
 1865 ── Home Indicator 402×34 (bar 143×5 at (129,1886))
 1899
```

**Where the PNG departs from the JSON (measured on the render):** cards 1–3 match within 3 pt. From Dose Guard down the render is shorter: the Dose Guard card renders ≈ **284 tall (y 928.5 → 1212.5)** instead of 312, and the Accessibility card renders ≈ **45 tall (y ≈ 1535 → 1580)** instead of 81 — in both, a row that holds an icon plus a *fixed-height* text box (`textAutoResize: NONE`, `height: 100%` in the HTML) collapsed to the icon's height, and in the Accessibility card the three text lines visibly **overflow the card's top and bottom edges** in the PNG. Everything below shifts up accordingly (Medication Bar card 1269.5 → 1478, Your Data card ≈ 1637 → 1717). Nav (1809–1869) and FAB (1745–1795) are absolutely placed and match the JSON exactly. This spec uses the JSON (auto-layout intent: 15 padding, hugging rows) and flags the render in Open question 1.

### 2.1 Status bar — `Status Bar` (0,0) 402×52
Standard iOS light mock: "9:41" vector (32,18) 40×21; signal 20×14 · Wi-Fi 16×14 · battery 25×14, gap 4, at (301,20). All `#212529` [grey-500]; empty signal bar at 18 %, battery outline at 60 %. System-provided.

### 2.1a Title block — `Frame 2` (32,74) 225×63, vertical, gap 3
| Layer | Text | Font | Colour | Box |
|---|---|---|---|---|
| `Settings` | "Settings" | Inter **34 / Semi Bold (600)**, auto lh, tracking 0 | `#17501d` [green-800] | 138×41 |
| `Make The App Works For You` | "Make The App Works For You" | Inter **16 / Medium (500)** | `#6a6d70` [grey-300] | 225×19 |

No nav bar, no trailing action, no large-title collapse behaviour is drawn.

### 2.1b Shared section anatomy (all seven groups)
- **Section wrapper** (`Frame 4/12/14/13/15/16/17`): vertical, gap **12**, width 344.
- **Heading**: Inter **16 / Semi Bold (600)**, `#212529` [grey-500], 19 tall, left-aligned at the column edge (x 29).
- **Card** (`Background`): fill `#ffffff`, stroke **0.5 pt `#000000` @ 10 %** inside, corner radius **24** (Check-In Calendar, Voice & Storage, Dose Guard, Medication Bar) or **18** (Confirmations, Accessibility, Your Data) — see Open question 9; drop shadow `#183c28` @ 8 %, offset (0, 3), blur 8 (HTML export: `0px 3px 7px #183c2814`); padding **15** on all sides; vertical auto-layout, gap **15**; inner content width **314** (x 44 → 358).
- **Hairline divider** (`Line 2/3/4`): 1 pt stroke `#000000` @ 10 %, centre-aligned, spans the full inner width 314. Because the card gap is 15 on both sides, rows separated by a divider sit **30 pt apart** with the line in the middle. Dividers appear between *independent* rows (Voice & Storage ×2, Medication Bar ×3, between the Voice Prompts and Calendar Cards groups, between the radio group and Blocked For) but **not** between the three Dose Guard radio rows nor between the Confirmations toggle row and its preview chip.
- **Row** (`Frame 17074795xx`): horizontal, `SPACE_BETWEEN`, gap 10, width 314; counter-axis **centre** except where noted. Left cluster = optional 21×21 icon + gap 10 + text stack (vertical, gap 4 or 5). Right cluster = toggle / status / value / chevron.
- Typography roles inside cards: **row title** 14/600 `#292d32` (off-palette — 8 units off grey-500) *or* 14/500 `#212529` [grey-500] *or* 14/500 `#4d5154` [grey-400] (three different treatments — see §4.1 #17); **secondary** 12/500 `#6a6d70` [grey-300]; **value** 12/500 `#4d5154`.

### 2.2 Check-In Claendar — `Frame 4` (29,159) 344×254.62 · card (29,190) 344×223.62, r 24
**Group A — Voice Prompts** (`Frame 1707479442 › 1707479503`, (44,205) 314×88, vertical gap 10):
- `Frame 1707479502` (vertical gap 4): "Voice Prompts" 14/600 `#292d32` 99×17 · "How long each prompt stays on screen during a voice check-in." 12/500 `#6a6d70` 314×30 (wraps to 2 lines).
- Chip row `Container` (44,266) 314×27, horizontal gap **6**, left-aligned, no wrap:

| Chip (`Bill-shape` INSTANCE) | Box | Fill | Stroke | Radius | Padding | Label |
|---|---|---|---|---|---|---|
| "Brisk · 6 s" — unselected | (44,266) 88×27 | `#ffffff` | 1 pt `#e4ece4` inside (off-palette hairline, same as the back pill on other frames) | 15 | 5 top/bottom · 15 sides | 12/500 `#193024` (off-palette dark green) |
| "Relaxed · 10 s" — **selected** | (138,266) 111×27 | `#2a9134` [green-500] | 1 pt `#2a9134` | 15 | 5 · 15 | 12/500 `#ffffff` |

Row width used: 88 + 6 + 111 = 205 of 314 — nothing clipped.

**Divider** at y 308.

**Group B — Calendar Cards** (`Frame 1707479503`, (44,323) 314×75.62, vertical gap **9**):
- "Calendar Cards" 14/600 `#292d32` 105×17.
- `Container` (44,349) vertical gap **13**, two toggle rows, each 314×18.31, `SPACE_BETWEEN`, centre:

| Row | Label (12/500 `#4d5154` [grey-400]) | Toggle state |
|---|---|---|
| `Frame 1707479506` (44,349) | "Auto-expand selected day" 152×15 | **ON** |
| `Frame 1707479507` (44,380.31) | "Always expand cards" 122×15 | **OFF** |

**Toggle, small** (`1230_frame` + `1231_ellipse`, no DS source component): track **34 × 18.31**, corner radius 379.27 (pill), `clipsContent`; ON fill `#2a9134` [green-500], OFF fill `#babbbd` [grey-100]; knob 13.73 Ø `#ffffff`, top 1.96, x **17** when ON / **3.92** when OFF, shadow `#000000` @ 15 %, offset (0, 0.76), blur 1.52. Note the 12 pt label here vs 14 pt for the same control in Medication Bar.

Card bottom 413.62.

### 2.3 Voice & Storage — `Frame 12` (29,437.62) 344×215 · card (29,468.62) 344×184, r 24
| Row | Box | Icon (21×21, at x 44) | Title | Right cluster |
|---|---|---|---|---|
| 1 `Frame 1707479503` | (44,483.62) 314×21 | `vuesax/outline/voice-cricle` — circle outline + 5 vertical bars, vectors `#212529` (two bars carry a 1.71 stroke) | "Voice Transcription" 14/500 `#212529` at x 75 | `Frame 1707479509` (297,486.62) 61×15, gap 4: `Ellipse 7` **8 Ø `#2a9134`** status dot + "Installed" 12/500 **`#2a9134`** |
| — divider y 519.62 | | | | |
| 2 `Frame 1707479504` | (44,534.62) 314×21 | `vuesax/bold/record-circle` — filled disc with ring, `#212529` | "Recording" 14/500 `#212529` | "34MB" 12/500 `#4d5154` (323,537.62) 35×15 |
| — divider y 570.62 | | | | |
| 3 `Frame 1707479505` | (44,585.62) 314×52 | `vuesax/bold/chart` — three filled bars `#292d32` (frame + baseline vectors at 0 opacity), vertically centred at y 601.12 | text stack `Frame 1707479510` 249 wide, gap 5: "Download Over Cellular" 14/500 `#212529` 157×17 · "Allow voice-model downloads using mobile Data" 12/500 `#6a6d70` 249×30 (2 lines) | small toggle **ON** (324,602.46) 34×18.31, vertically centred |

Card bottom 652.62. No download / progress / error / delete states are drawn (Open question 3).

### 2.4 Confirmations — `Frame 14` (29,676.62) 344×198 · card (29,707.62) 344×167, **r 18**
- **Row** `Frame 1707479505` (44,722.62) 314×82, `SPACE_BETWEEN`, counter-axis **MIN (top-aligned)**:
  - `Frame 1707479510` 280×82, vertical gap 5: "Name medication in confirmations" 14/500 `#212529` 229×17 · "Off — discreet everywhere; the medication name stays inside the app. On — confirmations name the medication and dose (banner, spoken, and on the lock screen)." 12/500 `#6a6d70` 280×60 (4 lines).
  - Small toggle **ON** at (324,722.62) — aligned with the title line, not the row centre.
  - Geometry drift: 280 + gap 10 + 34 = 324 > 314; the text frame overlaps the toggle by 10 pt (invisible because line 1 is only 229 wide). Text column should be 270.
- gap 15 → **Preview chip** `1262_frame` (44,819.62) **314×40**, fill `#f4f0fb` [violet-50], radius **12**, padding 7 top/bottom · 10 sides, horizontal gap 10, centre, `clipsContent`:
  - **Capsule badge** `Background` (54,826.62) **26×26**, fill `#ffffff`, stroke 0.418 pt `#000000` @ 10 % inside, r 13; inner `SVG` 13.93×13.93 with one vector 12.74×12.73 fill **`#4d3974`** [violet-800] — a capsule/pill **outline drawn diagonally with a midline** (line-style; identical to the badge on Day Details, mood-journal med rows).
  - `Frame 1707479463` (90,831.12) 146×17, gap 4: "09:54" **14/600 `#171a1d`** [grey-700] 41×17 · `Ellipse 2` **3 Ø `#212529`** dot separator (rendered "•", not a character) · "Concerta 36 mg" 12/500 `#4d5154` 94×15.

Card bottom 874.62.

### 2.5 Dose Guard — `Frame 13` (29,898.62) 344×343 · card (29,929.62) 344×312, r 24
**Radio group** — three rows 314×36, gap 15, **no dividers**, `SPACE_BETWEEN`, centre. Text stack 294 wide, gap 4: title 14/600 `#292d32`, subtitle 12/500 `#6a6d70` 294×15. Radio = `Ellipse 7` **20×20** at x 338, y +8:

| Row | Title | Subtitle | Radio |
|---|---|---|---|
| `Frame 1707479506` (44,944.62) | "Off" | "Every Trigger Logs" | unselected — no fill, stroke **1 pt `#000000` @ 10 %** inside |
| `Frame 1707479508` (44,995.62) | "Total" | "Blocked While A Does Is Still Active" | unselected |
| `Frame 1707479509` (44,1046.62) | "Time Window" | "Blocked for a set time after a dose" | **selected** — no fill, stroke **6 pt `#2a9134`** inside → green ring with an 8 pt white centre |

**Divider** at y 1097.62.

**Blocked For** `Frame 1707479507` (44,1112.62) 314×54, vertical gap 10:
- "Blocked For" 14/600 `#292d32` 80×17.
- Chip row `Container` (44,1139.62) 314×27, gap 6:

| Chip | Box | State | Content |
|---|---|---|---|
| "1h" | (44,1139.62) 45×27 | unselected (white, `#e4ece4` stroke) | 12/500 `#193024` |
| "2h" | (95,1139.62) **67×27** | **selected + check** — fill/stroke `#2a9134` | leading badge `Frame 1707479511` **15×15** `#ffffff` r 99999 with a 10×7 check vector `#2a9134`, gap **5**, then "2h" 12/500 `#ffffff` |
| "3h" | (168,1139.62) 47×27 | unselected | |
| "4h" | (221,1139.62) 48×27 | unselected | |

Row width used 225 of 314. These four chips are detached FRAMEs (the two in §2.2 are INSTANCEs of `Bill-shape`). The check-badge variant does **not** exist in DS Frame 15 (which has plain / filled / grey-dot variants) — Open question 14.

- gap 15 → **Footnote row** `Frame 1707479505` (44,1181.62) 314×45, left cluster counter-axis MIN: `vuesax/bold/info-circle` 21×21 `#212529` (filled disc with "!") at x 44 · text "A second log is blocked for 2 h after your last dose. The in-app Log Dose sheet is never blocked." 12/500 `#6a6d70`, **fixed 283×45** (`textAutoResize: NONE`, vertically centred), 3 lines, at x 75.

Card bottom 1241.62 (JSON) — renders ≈ 1212.5 in the PNG (footnote row collapsed to the icon height; gap to the chips ≈ 4 pt, bottom padding ≈ 3 pt).

### 2.6 Medication Bar — `Frame 15` (29,1265.62) 344×241.46 · card (29,1296.62) 344×210.46, r 24
Four identical rows 314×22.62, `SPACE_BETWEEN`, centre, separated by dividers (rows 52.62 apart):

| Row | Label (14/500 `#4d5154` [grey-400]) | Toggle |
|---|---|---|
| `Frame 1707479506` (44,1311.62) | "Show Medication Bar" 142×17 | ON |
| — divider y 1349.23 | | |
| `Frame 1707479507` (44,1364.23) | "Show Medication Name" 159×17 | ON |
| — divider y 1401.85 | | |
| `Frame 1707479508` (44,1416.85) | "Show Taken Time" 118×17 | ON |
| — divider y 1454.46 | | |
| `Frame 1707479509` (44,1469.46) | "Show End Time" 104×17 | ON |

**Toggle, large** (same `1230_frame`/`1231_ellipse` structure, scaled): track **42 × 22.62**, r 468.51, fill `#2a9134`; knob 16.96 Ø `#ffffff` at x 21, top 2.42, shadow `#000000` @ 15 %, offset (0, 0.94), blur 1.88. **Two toggle sizes on one screen** (34×18.31 in §2.2–2.4 vs 42×22.62 here) — Open question 8. All four are ON; no OFF state and no dependency between row 1 and rows 2–4 is drawn.

Card bottom 1507.08.

### 2.7 Accessibility — `Frame 16` (29,1531.08) 344×112 · card (29,1562.08) 344×81, r 18
Single row `Frame 1707479505` (44,1577.08) 314×51, left cluster counter-axis MIN, gap 10:
- Icon `Group` **13.81×17** at (44,1577.08): two vectors (head 3.72 Ø + body) fill **`#000000`** (pure black — the only pure-black ink on the screen; not a vuesax layer name) — a filled standing-figure "accessibility" glyph.
- Text at x 67.81: "Squirl follows the iOS motion setting. Turn on Reduce Motion in Settings › Accessibility to still animations." Inter **14 / Regular (400)** — the only Regular-weight text on the screen — `#6a6d70`, **fixed 283×51** (`NONE`), 3 lines, vertically centred.

No control; informational only. Card bottom 1643.08 (JSON). **PNG renders the card ≈ 45 pt tall with the text spilling over both edges** — Open question 1.

### 2.8 Your Data — `Frame 17` (29,1667.08) 344×113 · card (29,1698.08) 344×82, r 18
Single row `Frame 1707479506` (44,1713.08) 314×52, `SPACE_BETWEEN`, centre:
- `Frame 1707479510` 293×52, vertical gap 5: "Acknowledgement" 14/500 `#212529` 126×17 · "Your recordings, check-ins, and signals stay on this device. Nothing is uploaded." 12/500 `#6a6d70` 293×30 (2 lines).
- `vuesax/twotone/arrow-right` 21×21 at (337,1728.58): one 6.21×13.86 vector, **stroke `#212529` 1.71 pt centre, no fill** — renders as a **">" disclosure chevron**, not an arrow with a shaft.

Card bottom 1780.08 = end of the content column.

### 2.9 Bottom chrome — `Group 729` (28,1745) 346×124
- **Add Button** (FAB) `INSTANCE` (309,1745) **50×50**: fill `#8c68d3` [violet-500], r 75 (circle), shadow `#000000` @ 17 %, offset (0, 7), blur 17 (HTML `14.875px`); icon `vuesax/twotone/add` 41×41 at (+4.5,+4.5): two 20.5 pt strokes `#e9e9ea` [grey-50], weight 1.71. Identical to DS Frame 15 `Add Button`. Its right edge (359) is inset 15 from the nav's right edge (374); gap to the nav top = 14.
- **Navigation** `INSTANCE` (28,1809) **346×60**: fill `#ffffff`, r 75, shadow `#183c28` @ 16 %, offset (0, 8), blur 24 (HTML `21px`); horizontal, centred, gap 0 (children total 343 → 1.5 pt slack each side). Variant = DS Frame 4 **`Status=Settings, Mode=Light`**, unchanged:

| Item (template layer name) | Tab | Box | Icon | Style / colour |
|---|---|---|---|---|
| `navigation/menu - wallet` | Calendar | (29.5,1810.5) 65×57, pad 16.5/20.5 | `vuesax/outline/calendar` 24 at (50,1827) | outline, `#999b9d` [grey-200] |
| `navigation/menu - analysis` | Check In | (94.5,1810.5) 65×57 | `vuesax/linear/task-square` 24 at (115,1827) | linear, stroke `#999b9d` 1.5 |
| `navigation/menu - profile` | Insights | (159.5,1810.5) 65×57 | `vuesax/outline/chart` 24 at (180,1827) | outline, `#999b9d` |
| `navigation/menu - home` | **Settings (active)** | (224.5,1809) 148×60, pad 8/15 → inner pill (239.5,1817) **118×44**, fill `#2a9134`, r 44, pad 10/20, gap 6 | `vuesax/bold/setting-2` 24 `#ffffff` at (259.5,1827) | bold/filled + label "Settings" 12/500 `#ffffff` 48×15 |

- **Home Indicator** (0,1865) 402×34; bar (129,1886) 143×5 `#212529` r 10. The nav's bottom edge (1869) intrudes 4 pt into the home-indicator zone; the bar itself has 17 pt clearance.

### 2.10 Above / below the fold (402×874 viewport, chrome pinned as on the 874-pt frames: nav ≈ y 784–844, FAB ≈ y 720–770)
- **Visible, unobstructed:** title block, Check-In Calendar (190–413.6), Voice & Storage (437.6–652.6), "Confirmations" heading (676.6) and the top of its card (707.6 →).
- **Behind the FAB at rest:** the FAB's rest box (309–359 × 720–770) sits **exactly over the "Name medication in confirmations" toggle** (324–358 × 722.6–740.9). The tall canvas hides this collision.
- **Behind the nav bar at rest:** the Confirmations description lines 3–4 and the preview chip (819.6–859.6).
- **Below the fold:** Dose Guard, Medication Bar, Accessibility, Your Data.
- **Scroll end:** content bottom 1780; with the nav top 90 pt above the frame bottom and the FAB top 154 pt above it, the JSON geometry has the FAB overlapping the Your Data card's bottom-right corner by 35 pt (the shorter PNG render leaves a 28 pt gap by accident). A bottom content inset of **≥ 170 pt** (154 + 16) keeps the last row clear of both; 106 pt (90 + 16) clears only the nav.

### 2.11 Colour → token map (DS Frame 5)
| Hex | Where | Token |
|---|---|---|
| `#fbfffc` | screen background | off-palette (shared by every screen) |
| `#ffffff` | cards, chip fills, knobs, nav, check badge, capsule badge | white |
| `#17501d` | "Settings" title | green-800 ✓ |
| `#2a9134` | selected chips, ON toggles, radio ring, status dot + "Installed", check glyph, nav pill | green-500 ✓ |
| `#193024` | unselected chip labels | **off-palette** (darkest green in file; green-900 is `#123d16`) |
| `#e4ece4` | unselected chip stroke | off-palette hairline (Frame 15 `Bill-shape` default) |
| `#212529` | section headings, 14/500 row titles, icons, "•", nav bar/home bar | grey-500 ✓ |
| `#292d32` | 14/600 row titles, chart bars | **off-palette** (8 units lighter than grey-500) |
| `#171a1d` | "09:54" | grey-700 ✓ |
| `#4d5154` | 12/14 pt toggle labels, "34MB", "Concerta 36 mg" | grey-400 ✓ |
| `#6a6d70` | subtitle, all descriptions, footnotes | grey-300 ✓ |
| `#999b9d` | inactive tab icons | grey-200 ✓ |
| `#babbbd` | OFF toggle track | grey-100 ✓ |
| `#e9e9ea` | FAB "+" strokes | grey-50 ✓ |
| `#000000` @ 10 % | card strokes, dividers, radio-off stroke, capsule-badge stroke | black alpha (no token) |
| `#000000` | accessibility figure | pure black (only use) |
| `#f4f0fb` | confirmation preview chip | violet-50 ✓ |
| `#4d3974` | capsule glyph | violet-800 ✓ |
| `#8c68d3` | FAB | violet-500 ✓ |
| `#183c28` @ 8 % / 16 % | card / nav shadows | shadow ink (no token) |

### 2.12 Typography → DS Frame 2
All Inter in the file (shipping app is native SF — spec 023). Roles: 34/600 display title · 16/500 subtitle · 16/600 section heading · 14/600 group/row title · 14/500 row title/label · 14/400 accessibility note · 14/600 time · 12/500 secondary, chip labels, values, status, nav label. Every text layer is `lineHeight: AUTO`, tracking 0. Two fixed-size (`NONE`) text boxes exist (Dose Guard footnote 283×45, Accessibility 283×51); all others hug.

---

## 3. Component instances and states

| Component (source) | Count | Instance(s) | State shown | Notes |
|---|---|---|---|---|
| `Main_navbar` / `Navigation` (Frame 4) | 1 | bottom | `Status=Settings` — item 4 active (green pill, **bold** gear, label shown); items 1–3 inactive (outline/linear, `#999b9d`, no labels) | Exact DS variant. |
| `Add Button` (Frame 15) | 1 | (309,1745) | default | Exact DS component. No pressed state. |
| `Bill-shape` chip (Frame 15) — INSTANCE | 2 | "Brisk · 6 s", "Relaxed · 10 s" | 1 unselected (outlined) · 1 **selected** (filled green) | Single-select segmented pair. |
| Bill-shape chip — detached FRAME | 4 | "1h" "2h" "3h" "4h" | 3 unselected · 1 **selected with check badge** | Check-badge variant is not in Frame 15. |
| Toggle, small (`1230_frame`, no DS source) | 6 | Auto-expand · Always expand · Download Over Cellular · Name medication in confirmations | **5 ON, 1 OFF** ("Always expand cards") | 34×18.31. |
| Toggle, large (same structure) | 4 | Medication Bar rows | **4 ON** | 42×22.62. No OFF drawn. |
| Radio (`Ellipse 7` 20 Ø, no DS source) | 3 | Off · Total · Time Window | 2 unselected (10 % black ring) · 1 **selected** (6 pt green ring) | Whole row must be the target (radio is 20 pt). |
| Status dot + label | 1 | "● Installed" | installed | Other model states (not installed / downloading / error) not drawn. |
| Value label | 1 | "34MB" | — | |
| Preview chip (`1262_frame`, local; same anatomy as the mood-journal / day-details med rows) | 1 | "09:54 • Concerta 36 mg" | ON-state preview | OFF-state preview not drawn. |
| Capsule badge 26×26 | 1 | inside the preview chip | — | violet-50 disc is the chip here; badge is white. |
| Card (`Background`) | 7 | — | r 24 ×4, r 18 ×3 | |
| Hairline divider | 7 | — | — | |
| Disclosure row (chevron) | 1 | "Acknowledgement" | default | |
| Informational row (icon + note) | 2 | Dose Guard footnote · Accessibility | — | Fixed-height text; collapses in the PNG. |
| Status Bar · Home Indicator (iOS instances) | 1 + 1 | — | light | System. |

**Clipping / horizontal scroll:** none. Both chip rows fit (205 and 225 of 314); every card is 344 wide inside a 402 frame. **Expanded/collapsed:** nothing is collapsible as drawn (the hours chips are visible while "Time Window" is selected; whether they hide for Off/Total is not shown — Open question 4).

---

## 4. Copy inventory (verbatim)

| # | Figma id | String | Role |
|---|---|---|---|
| 1 | `72:10012` | `Settings` | display title |
| 2 | `72:10013` | `Make The App Works For You` | subtitle |
| 3 | `72:10016` | `Check-In Claendar` | section heading |
| 4 | `72:10021` | `Voice Prompts` | group title |
| 5 | `72:10022` | `How long each prompt stays on screen during a voice check-in.` | description |
| 6 | `I72:10024;33:15683` | `Brisk · 6 s` | chip (instance text) |
| 7 | `I72:10025;33:15689` | `Relaxed · 10 s` | chip (selected; instance text) |
| 8 | `72:10029` | `Calendar Cards` | group title |
| 9 | `72:10033` | `Auto-expand selected day` | toggle label |
| 10 | `72:10037` | `Always expand cards` | toggle label |
| 11 | `72:10041` | `Voice & Storage` | section heading |
| 12 | `72:10046` | `Voice Transcription` | row title |
| 13 | `72:10049` | `Installed` | status |
| 14 | `72:10054` | `Recording` | row title |
| 15 | `72:10056` | `34MB` | value |
| 16 | `72:10062` | `Download Over Cellular` | row title |
| 17 | `72:10063` | `Allow voice-model downloads using mobile Data` | description |
| 18 | `72:10068` | `Confirmations` | section heading |
| 19 | `72:10072` | `Name medication in confirmations` | row title |
| 20 | `72:10073` | `Off — discreet everywhere; the medication name stays inside the app. On — confirmations name the medication and dose (banner, spoken, and on the lock screen).` | description |
| 21 | `72:10082` | `09:54` | preview time |
| 22 | `72:10084` | `Concerta 36 mg` | preview medication + dose |
| 23 | `72:10086` | `Dose Guard` | section heading |
| 24 | `72:10090` | `Off` | radio title |
| 25 | `72:10091` | `Every Trigger Logs` | radio subtitle |
| 26 | `72:10095` | `Total` | radio title |
| 27 | `72:10096` | `Blocked While A Does Is Still Active` | radio subtitle |
| 28 | `72:10100` | `Time Window` | radio title (selected) |
| 29 | `72:10101` | `Blocked for a set time after a dose` | radio subtitle |
| 30 | `72:10106` | `Blocked For` | group title |
| 31–34 | `72:10111` · `72:10116` · `72:10119` · `72:10122` | `1h` · `2h` · `3h` · `4h` | chips (2h selected) |
| 35 | `72:10126` | `A second log is blocked for 2 h after your last dose. The in-app Log Dose sheet is never blocked.` | footnote |
| 36 | `72:10128` | `Medication Bar` | section heading |
| 37 | `72:10131` | `Show Medication Bar` | toggle label |
| 38 | `72:10136` | `Show Medication Name` | toggle label |
| 39 | `72:10141` | `Show Taken Time` | toggle label |
| 40 | `72:10146` | `Show End Time` | toggle label |
| 41 | `72:10150` | `Accessibility` | section heading |
| 42 | `72:10157` | `Squirl follows the iOS motion setting. Turn on Reduce Motion in Settings › Accessibility to still animations.` | note |
| 43 | `72:10159` | `Your Data` | section heading |
| 44 | `72:10164` | `Acknowledgement` | row title |
| 45 | `72:10165` | `Your recordings, check-ins, and signals stay on this device. Nothing is uploaded.` | description |
| 46 | `I72:10168;29:12094` | `Settings` | active tab label (Navigation instance text) |
| — | status bar | `9:41` | system mock |

### 4.1 Typos and inconsistencies
1. **"Check-In Claendar"** → "Check-In Calendar" (typo; one of the known file-wide set).
2. **"Blocked While A Does Is Still Active"** → "Does" should be **"Dose"**. Code string: "Blocked while a dose is still active".
3. **"Make The App Works For You"** → subject–verb error ("make … work"); also Title Case on a sentence.
4. **Casing is mixed inside the same card:** "Every Trigger Logs" / "Blocked While A Does Is Still Active" (Title Case) vs "Blocked for a set time after a dose" (sentence case) in the Dose Guard radios; "Name medication in confirmations" (sentence case) vs "Show Medication Bar" / "Download Over Cellular" (Title Case) for row titles. Code uses sentence case throughout ("Every trigger logs", "Time window", "Blocked for", "Download over Cellular").
5. **"34MB"** → "34 MB" (space before the unit; `Measurement` formatting). Code shows "N recordings · 34.0 MB".
6. **"2h" chips vs "2 h" in the footnote** — same value, two spellings in one card. Code uses "1 h … 4 h".
7. **"mobile Data"** — stray capital; and "mobile" (description) vs "Cellular" (title) name the same thing two ways. Code: "Download over Cellular".
8. **"Acknowledgement"** — singular, and it titles the *on-device privacy promise* with a disclosure chevron. In code "Acknowledgements" (plural) is a separate `NavigationLink` to open-source credits, and the promise is a plain text row. The pen merges two different rows under a misleading title (Open question 7).
9. **"Voice Prompts"** vs code "Prompt Pace" (picker) under a "Check-in" header; "Calendar Cards" vs code "Calendar"; row order in Calendar Cards is reversed vs code ("Always expand cards" first in code).
10. **"Recording"** as a row title for a storage figure is ambiguous (reads like a model name next to "Voice Transcription"). Code: "Storage — N recordings · X MB".
11. **"09:54 • Concerta 36 mg"** — the preview puts the time first with a drawn dot; code prints "Concerta · 36 mg · 17:42" (name · dose · time, middle-dot characters). Pick one order and one separator. "Concerta 36 mg" also drops the "·" between name and dose that the rest of the file uses.
12. **"Check-In"** spelling: heading "Check-In Claendar" and description "voice check-in" (lower-case) on the same card; tab label is "Check In". File-wide decision needed (same note as the check-in screens).
13. **"Settings › Accessibility"** uses U+203A "›" — matches code exactly; keep.
14. No spelling errors beyond #1–2 on this screen ("Okey / Breackdoen / Vyvans / Dtails / How Does It Feels" live on other frames).
15. Section heading "Voice & Storage" vs App-Store-facing naming in code ("AI Models" + "System") — a naming change, not a typo; note that the LLM model row is absent (Open question 2).
16. Subtitle line "Make The App Works For You" is 16/500 grey-300 — the same role as descriptions inside cards; fine, but it is Title Case while every description is sentence case.
17. Three ink treatments for row titles at the same hierarchy level (14/600 `#292d32` · 14/500 `#212529` · 14/500 `#4d5154`) and two label sizes for toggles (12 vs 14) — visual, not textual, but it will read as inconsistent copy weight.

---

## 5. Glyph and icon usage

**Signal glyphs (DS Frame 12 — sprout / bolt / target / moon): none.** No level glyphs appear on Settings.

**UI icons:**

| Icon | Layer / library name | Style | Size | Colour | Where |
|---|---|---|---|---|---|
| Waveform in circle | `vuesax/outline/voice-cricle` (sic) | **outline** | 21 | `#212529` | Voice Transcription row |
| Record disc | `vuesax/bold/record-circle` | **bold / filled** | 21 | `#212529` | Recording row |
| Bar chart | `vuesax/bold/chart` | bold / filled bars | 21 | `#292d32` | Download Over Cellular row |
| Capsule (medication) | unnamed `SVG › Vector` (imported; no capsule exists in the vuesax set) | line-style outline, diagonal, midline | 12.74 in a 26 Ø white badge | `#4d3974` violet-800 | Confirmation preview chip |
| Check | `Frame 1707479511 › Vector` | filled check inside a white 15 Ø disc | 10×7 | `#2a9134` | selected "2h" chip |
| Info | `vuesax/bold/info-circle` | bold / filled disc with "!" | 21 | `#212529` | Dose Guard footnote |
| Accessibility figure | unnamed `Group` (2 vectors) | filled | 13.81×17 | `#000000` | Accessibility note |
| Disclosure chevron | `vuesax/twotone/arrow-right` | stroke only 1.71 pt — renders as ">" | 21 | `#212529` | Your Data row |
| Calendar | `vuesax/outline/calendar` | outline | 24 | `#999b9d` | tab 1 (inactive) |
| Task list | `vuesax/linear/task-square` | linear (1.5 stroke) | 24 | `#999b9d` | tab 2 (inactive) |
| Chart | `vuesax/outline/chart` | outline | 24 | `#999b9d` | tab 3 (inactive) |
| Gear | `vuesax/bold/setting-2` | **bold / filled** | 24 | `#ffffff` | tab 4 (active) |
| Plus | `vuesax/twotone/add` | 1.71 strokes | 41 box / 20.5 arms | `#e9e9ea` | FAB |
| Status dot | `Ellipse 7` | filled circle | 8 | `#2a9134` | "Installed" |
| Separator dot | `Ellipse 2` | filled circle | 3 | `#212529` | preview chip |

Style rule visible: **chrome uses outline/linear (inactive) and bold (active)**; in-card leading icons mix outline (voice-circle) and bold (record-circle, chart, info-circle) at 21 pt in grey-500 — the mix looks deliberate (bold for "state" icons, outline for the model) but is not documented. Not used here: mic, pencil, play, sparkles, lock, ellipsis, bed/moon, capsule-in-violet-disc (the badge here is white-on-violet-50, the inverse of the day-details rows' violet-50 disc inside a white row).

---

## 6. Data the screen implies

| Field | Type / enum | Shown as | Existing code (read-only) | Notes |
|---|---|---|---|---|
| Prompt pace | `PromptPace` enum `brisk = 6` · `relaxed = 10` (seconds) | chips "Brisk · 6 s" / "Relaxed · 10 s", **relaxed selected** | `AppSettings.promptPaceSeconds`, `PromptPace.displayLabel` (labels match verbatim) | Single-select. |
| Auto-expand selected day | `Bool` | ON | `@AppStorage("autoExpandOnSelection")` default true | |
| Always expand cards | `Bool` | OFF | `@AppStorage("alwaysExpandCards")` default false | |
| Whisper model installed | `Bool` (+ downloading `Double` progress, error) | "● Installed" | `SettingsViewModel.whisperModelInstalled` etc. | Only the installed state is drawn. |
| Storage used | `Double` MB (+ recording `Int` count in code) | "34MB" | `storageUsedMB`, `recordingCount` | Count not shown. |
| Download over cellular | `Bool` | ON | `AppSettings.downloadOverCellular` default false | |
| Name medication in confirmations | `Bool` | ON | `AppSettings.nameMedicationInConfirmations` default false | Preview chip depends on it. |
| Default medication + dose | `String?` + `String?` | "Concerta 36 mg" | `defaultMedicationName` / `defaultMedicationDose` | **The picker that sets these ("My Medication") is not on the screen.** |
| Preview time | `Date` → "HH:mm" | "09:54" | code uses a fixed sample "17:42" | Sample, last dose, or now? (Open question 6) |
| Dose Guard mode | enum `off` · `total` · `window` | radios, **window selected** | `DoseGuardMode`, `AppSettings.doseGuardModeRaw` | |
| Blocked-for hours | `Int` 1…4 | chips, **2 selected** | `AppSettings.doseGuardWindowHours` default 2 | Footnote interpolates the value ("2 h"). |
| Show Medication Bar | `Bool` | ON | `@AppStorage("medicationBarVisible")` | |
| Show Medication Name | `Bool` | ON | `@AppStorage("medicationBarShowName")` | Code hides this row when the bar is off. |
| Show Taken Time | `Bool` | ON | **no counterpart** | New setting — semantics undefined. |
| Show End Time | `Bool` | ON | **no counterpart** | New setting — semantics undefined. |
| Reduce Motion | system `Bool` (read-only) | note only | `@Environment(\.accessibilityReduceMotion)` | No in-app control, by design. |
| Acknowledgement destination | navigation | chevron | `AcknowledgementsView` (credits) or privacy page | Ambiguous. |

No level enums (Great/Good/Okay/Flat/Low, Alert/Tired/Steady/Charged, Sharp/Present/Distracted/Locked In, Active/Kicking In), no hours of sleep, no month selector, no percentages or counts appear on this screen. The only medication string is the confirmation preview.

---

## 7. Interactions implied

| Target | Hit area as drawn | Action | Notes |
|---|---|---|---|
| "Brisk" / "Relaxed" chips | 88×27 · 111×27 | single-select; fill animates to green | 27 pt tall → needs a ≥ 44 pt hit area / row-level tap. |
| Six small toggles | 34×18.31 | flip Bool; persist immediately (no Save button anywhere) | Make the whole row (314×≥18) the target; native `Toggle` semantics for VoiceOver. |
| Four large toggles | 42×22.62 | same | |
| Dose Guard radio rows | row 314×36 (radio 20 Ø) | select one of three; `.isSelected` trait; selection animates | Whether "Blocked For" hides/disables for Off/Total is not drawn. |
| "1h…4h" chips | 45–67×27 | single-select; footnote re-renders "… for N h …" | The check badge appears only on the selected chip (67 wide vs 45–48). |
| "Voice Transcription" row | 314×21 | none drawn (installed) | Code has download / cancel / retry / allow-cellular / delete actions — undrawn states. |
| "Recording · 34MB" | — | none drawn | |
| "Acknowledgement" row | 314×52 + chevron | push a screen | Destination ambiguous. |
| Preview chip | — | none (read-only preview) | Should reflect the toggle live. |
| Tab bar items | 65×57 each; active 148×60 | switch tab | |
| FAB | 50×50 | start a new check-in (global) | Covers the Confirmations toggle at rest (§2.10). |
| Scroll | vertical only | — | Content 1621 pt; no horizontal axis anywhere. |
| Back / Save | — | none | Root tab; all changes commit on toggle. |

**Accessibility notes to carry into the plan**
- Contrast (Frame 5 figures): `#6a6d70` on white **5.21 : 1** ✓; `#4d5154` **8.01** ✓; `#193024` ✓; white on `#2a9134` **4.04 : 1** — fails AA for the 12 pt chip labels and the 12 pt "Settings" nav label (same exception as every other screen); `#2a9134` on white **4.04 : 1** — "Installed" (12 pt) fails AA; `#999b9d` inactive tab icons **2.79 : 1** — below the 3 : 1 non-text minimum; `#babbbd` OFF track on white 1.92 : 1 (conventional for switches, but the knob's 15 % shadow is the only edge).
- Fixed-height text boxes (283×45, 283×51) will clip under Dynamic Type; they must hug. All other text is `nowrap` single-line at 14/16/34 pt — "Name medication in confirmations" (229 wide) and "Show Medication Name" (159) are the first to collide with their toggles at larger sizes.
- Custom controls replace `Toggle`, `Picker` (segmented) and a radio group: VoiceOver must still hear "switch, on/off", "selected", and the group's heading; the 20 pt radio and 18 pt toggles are far below 44 pt targets.
- Motion: none specified. Reduce Motion note is copy only.

---

## 8. Open questions for the owner

1. **Render vs intent.** In the PNG the Accessibility card is ≈ 45 pt tall with its note overflowing both edges, and the Dose Guard footnote is jammed under the chips (card ≈ 284 vs 312). The JSON has 15 pt padding and 81 / 312 pt cards. Confirm the JSON is the intent (icon + hugging multi-line text, 15 padding) and the PNG is a Pencil layout artefact.
2. **Missing rows vs the shipping Settings.** Not drawn: **Journal Insights (LLM) model row** (the app has two models), **My Medication** (default name/dose picker that feeds the preview chip), **Medication info** disclaimer, **"Save a copy of my journal"** (export — *never gated*, CLAUDE.md), **Clear All Data**, **Privacy Policy** link, **version label**, and the RevenueCat **Restore Purchases / Manage subscription** row that the paywall spec puts in Settings. Deliberate cuts, or frames still to come? Export, Privacy Policy and Restore are hard requirements.
3. **Model row states.** Only "● Installed" is drawn. Need: not installed (Download button + "~150 MB · Wi-Fi recommended"), downloading (progress + %, Cancel), error (Retry / Allow cellular), and Delete. Also: is "Recording · 34MB" the storage row (code: "N recordings · X MB")?
4. **Hours chips when mode ≠ Time Window** — hidden (as in code), disabled, or always shown? And does the footnote switch per mode (code has three variants incl. "Guards expedited logs only — Siri or Shortcuts")?
5. **"Show Taken Time" / "Show End Time"** — new. What do they control on the medication bar (the bar on Calendar shows a status word and a bar)? Are rows 2–4 disabled/hidden when "Show Medication Bar" is off (code hides "Show Medication Name")?
6. **Preview chip.** Which time — a fixed sample (code 17:42), the last dose, or now? What does it show when the toggle is **Off** (e.g. "09:54 • Medication logged")? Which order: "09:54 • Concerta 36 mg" (pen) or "Concerta · 36 mg · 17:42" (code)?
7. **"Acknowledgement" row.** The chevron opens what — the open-source Acknowledgements screen, the privacy policy, or a "Your data" explainer? Rename to match; add a Privacy Policy row (privacy sequencing is a hard gate).
8. **Two toggle sizes** (34×18.31 vs 42×22.62) and a custom switch smaller than iOS's 51×31. Unify — and consider the native `Toggle` tinted green-500 for HIG/VoiceOver parity.
9. **Card radius 24 vs 18** — one value? Sibling screens' cards should decide.
10. **Off-palette inks:** `#292d32` row titles (vs grey-500 `#212529`), `#193024` chip labels, `#e4ece4` hairline, `#fbfffc` background. Add as tokens or snap to the ramp?
11. **Native List reversal.** DESIGN.md decision 2026-06-24 kept Settings on the native grouped `List` on purpose. This frame replaces it with custom cards, toggles, radios and chips. Confirm the reversal (and log it), and whether `insetGrouped` styling of native controls would be acceptable inside these cards.
12. **Copy policy.** Fix "Claendar", "Does"; decide Title Case vs sentence case for row titles/subtitles; "2h" vs "2 h"; "34MB" vs "34 MB"; "mobile Data" vs "Cellular".
13. **Pinned chrome and insets.** Confirm nav + FAB float over the scroll view; bottom content inset ≥ 170 pt (clears the FAB) or ≥ 106 (clears only the nav); accept that the FAB covers the Confirmations toggle at rest, or move the FAB/insert a spacer.
14. **DS gaps.** Toggle, radio and the checked chip variant have no source component in Frames 3/4/15; add them (Toggle S/L · Radio · `Bill-shape` `State=Selected+Check`) so the code has one reference.
15. **Left-edge alignment.** Title at x 32, column at 29, nav at 28 — settle on one gutter.
16. **Contrast exceptions.** Accept 4.04 : 1 for white-on-green-500 (chip/nav labels) and green-500 "Installed" on white, and 2.79 : 1 inactive tab icons — or darken to green-600 / grey-300.
