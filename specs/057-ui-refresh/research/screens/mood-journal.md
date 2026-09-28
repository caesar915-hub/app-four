<!-- Created: 2026-09-27 21:56 WEST · Updated: 2026-09-27 21:56 WEST -->
# Screen spec — "iPhone 17 - 19" · Mood Journal (Calendar tab)

Pen node `nDRZv` · Figma id `78:11944` · frame **402 × 1131** (2× PNG 804 × 2262).
Sources: PNG render (ground truth for what was approved), HTML-lite export (layer names + inline styles), Figma JSON (exact fills/fonts/radii/bounds). All coordinates below are **frame-relative** (frame origin = 0,0), in points. Colors are quoted as exported; palette names in brackets refer to Frame 5 (violet/green/grey 50–900). Anything not in the palette is marked **off-palette**.

Planning document only — no Swift changes are implied or authorised by this file.

---

## 1. Purpose and placement

- **What it is:** the Calendar tab of the app — today's medication bars, a month header with a week strip, the selected day expanded into its check-in rows, and a "Previous Days" list of collapsed day cards.
- **Where it sits:** a **root tab**, not a pushed or modal screen. Evidence: no back pill and no title bar; the floating `Main_navbar` (Frame 4 "Navs" component, `Status=Calendar, Mode=Light` variant) is present with the first item (calendar icon) in the filled green pill; the purple `Add Button` FAB sits to the right of the pill. Status bar and home indicator are the standard iOS light instances.
- **Canvas vs device:** the pen frame is 1131 tall, i.e. **257 pt taller than an iPhone 17 viewport (874)**. The content column is 924 tall (y 76 → 1000) and the tab bar is drawn at the canvas bottom (y 1037), so the artboard is a scrolled view with the chrome placed at the end. Treat the tab bar as floating and fixed (as in Frame 4); see §2.9 for what falls above/below the fold.
- **Layer naming:** the tab items carry template names `navigation/menu - home / wallet / analysis / profile`; they map to Calendar / Check In / Insights / Settings per Frame 4.

---

## 2. Layout, top → bottom

### 2.0 Frame

| Property | Value |
|---|---|
| Size | 402 × 1131 |
| Fill | `#fbfffc` (**off-palette**; near-white with a green cast — not grey-50 `#e9e9ea`, not green-50 `#eaf4eb`) |
| Corner radius | 32 (device mask), clips content |
| Content column | x 30 → 372 (**342 wide, 30 pt gutters**), starts y 76, vertical auto-layout, **gap 24** |
| Tab bar | x 28 → 374 (346 wide, 28 pt gutters), y 1037 |

### 2.1 Status bar (0, 0) 402 × 52 — `Status Bar` instance
- Time `9:41` vector at (38, 23) inside a 40 × 21 `Time / Light` frame at (32, 18), fill `#212529` [grey-500].
- Icons group at (301, 20) 69 × 14, gap 4: signal 20 × 14 (bars `#212529`, empty bar @18%), Wi-Fi 16 × 14, battery 25 × 14 (`#212529` @60% outline, 19 × 8 fill r 1).

### 2.2 Medication bar card — `Frame 8` (30, 76) 342 × 140

| Property | Value |
|---|---|
| Fill | `#ffffff` |
| Stroke | `#000000` @ 10%, 0.5 pt, inside |
| Radius | 12 |
| Shadow | `#183c28` @ 8%, offset (0, 3), blur 8, spread 0 (**off-palette** shadow tint) |
| Padding | 11 all sides; vertical layout, gap 14, children centred |

Two identical **medication rows** (320 × 45, vertical gap 7) separated by a divider:

**Row A — Concerta** (inner origin 41, 87)
- Header line 320 × 26, horizontal, space-between, centred:
  - Capsule badge (41, 87) **26 × 26**, fill `#f4f0fb` [violet-50], stroke `#000000` @ 10% 0.418 pt inside, r 13. Inner SVG 13.93 × 13.93, single vector fill `#4d3974` [violet-800] — a flat, filled **capsule** glyph.
  - Text group at x 75, gap 4, centred: `09:54` Inter **14 / Semi Bold 600** `#171a1d` [grey-700] · dot ellipse 3 × 3 `#212529` · `Concerta 36 mg` Inter **12 / Medium 500** `#4d5154` [grey-400].
  - Right-aligned status `Active` Inter **12 / Semi Bold 600** `#2a9134` [green-500], right edge at x 361.
- Progress bar container (41, 120) 320 × 12:
  - Track (41, 121) **320 × 10**, fill `#fafafa` (**off-palette**), stroke `#000000` @ 10% 0.25 pt inside, r 9.5.
  - Fill (41, 121) **165 × 10** (= 51.6 %), r 9.5, **linear gradient 90°** `#8061bf` (0 %) → `#8c68d3` (100 %) [violet-500 at the right end; `#8061bf` is **off-palette**].

**Divider** `Line 2`: y 146, x 41 → 361 (320 × 0), stroke `#000000` @ 10%, 1 pt.

**Row B — Vyvans** (inner origin 41, 160)
- Same construction. `18:23` 14/600 `#171a1d` · dot · `Vyvans` 12/500 `#4d5154` · status `Kicking In` 12/600 `#2a9134`.
- Track (41, 194) 320 × 10; fill **20 × 10** (= 6.25 %), same gradient.
- No dose shown for this row.

Card bottom edge y 216.

### 2.3 Month header — `Frame 1707479454` (30, 240) 133 × 17
- `September 2026` Inter **14 / Semi Bold 600** `#212529` [grey-500].
- Chevron 16 × 16 at (163, 240.5): `vuesax/twotone/arrow-up` instance **rotated 90°** so it points **right**; stroke `#212529`, weight 1.71, linear/outline style. Gap 2 between text and chevron.

### 2.4 Week strip — `Frame 1707479453` (30, 263) 342 × 83
- Horizontal auto-layout, space-between, top-aligned; seven `_Calendar column header` instances (Untitled-UI-style component: padding 8 top/bottom, 12 left/right; vertical gap 6; centred).
- Column widths 46 / 50 / 50 / 51 / 56 / 44 / 47 = **344**, i.e. 2 pt wider than the 342 container (last column ends at x 374). Cosmetic, but the row does not fit the grid exactly.
- Each column, top → bottom:
  - Weekday label: font family exported as **"mixed"** (not confirmed Inter), **12 / weight 500**, line-height 18 px, fill `#717680` (**off-palette** — Untitled UI gray-500).
  - `Date wrapper`: r 9999; unselected = 24 tall, hugs the text (8–14 wide, no fill).
  - Date: **12 / weight 600**, line-height 18, fill `#414651` (**off-palette** — Untitled UI gray-700).
- **Selected column (Fri 10)** 56 × 83: `Date wrapper` **32 × 32** filled `#17501d` [green-800]; date text `#ffffff`, centred. Below it, 6 pt gap, `Ellipse 1` **5 × 5** fill `#55a75d` [green-400] — an indicator dot present **only** under the selected day.
- Nothing is clipped at the frame edge; all seven columns are visible. A horizontal week-to-week swipe is not depicted.

Columns as drawn, left → right: `Tue 7` · `Mon 6` · `Wed 8` · `Thur 9` · `Fri 10` (selected) · `Sat 11` · `Sun 12`.

### 2.5 Expanded day card — `Frame 1707479456` (30, 370) 342 × 266

| Property | Value |
|---|---|
| Fill | `#ffffff` |
| Stroke | `#000000` @ 10%, 0.5 pt, **centre** aligned (other cards use inside) |
| Radius | **24** (larger than the 12 used elsewhere) |
| Shadow | `#183c28` @ 8%, offset (0, **4**), blur 8 |
| Layout | vertical, gap 15, padding bottom 15, children centred |

**Header band** (30, 370) 342 × 52
- Fill `#e6f5ee` (**off-palette** mint; not green-50 `#eaf4eb`), radii **24 / 24 / 0 / 0**, padding 14 top/bottom, 15 left/right.
- Inner row 312 × 24, space-between:
  - Left group, gap 6: `Okay ` (trailing space in the source) Inter **14 / Semi Bold 600** `#17501d` [green-800] · dot 3 × 3 `#4d5154` · `Fri 08` 14/600 `#17501d`.
  - Right: **collapse button** (333, 384) 24 × 24, fill `#ffffff`, stroke `#e4ece4` (**off-palette**) 0.6 pt inside, r 12; inside `vuesax/twotone/arrow-up` 13 × 13, stroke `#26842f` [green-600] 1.41 pt — **chevron-up** (expanded state).

**Rows container** `Frame 1707479451` (30, 437) 342 × 184 — padding 15 left/right, vertical gap 13. Three **check-in rows**, each 312 × 44, separated by 1 pt dividers (`#000000` @ 10%, x 45 → 357) at y 494 and y 564.

Row anatomy (`Container`, horizontal, space-between, top-aligned):
- **Mood avatar** 44 × 44, r 35, fill = stroke (1 pt inside) tinted per mood; inside a 33.56 × 33.56 sprout glyph (`mood-<level> 1`).
- **Text column** at x 96, vertical gap 4:
  - Title line, gap 6, bottom-aligned: mood label Inter **14 / Semi Bold 600** (colour per mood) · time `18:30` Inter **14 / Medium 500** `#212529`.
  - Signals line, gap 6, centred: [energy glyph 18 × 18 + label] · dot 3 × 3 `#4d5154` · [focus glyph 18 × 18 + label]; glyph-to-label gap 3; labels Inter **12 / Medium 500** `#212529` [grey-500].
- **More button** (334.4, row y) **22.6 × 22.6**, fill `#ffffff`, stroke `#e4ece4` 0.565 pt inside, r 11.3; `vuesax/outline/more` 13.26 × 13.26 — three filled dots `#1e6725` [green-700], horizontal.

| Row | y | Avatar fill | Sprout | Label (colour) | Time | Energy | Focus |
|---|---|---|---|---|---|---|---|
| 1 | 437 | `#ddf4de` | `mood-great` (stroke `#175723`, leaves `#428d52` / `#175723`, highlight `#9ccaa0`) | `Great` `#17501d` | `18:30` | `energy-low 1` · `Alert` | `focus-good 1` · `Distracted` |
| 2 | 507 | `#f4dddd` | `mood-low` (stroke `#bc4749`, leaves `#d97773` / `#bc4749`, highlight `#eeb4aa`) | `Low` `#842626` | `18:30` | `energy-okay 1` · `Alert` | `focus-flat 1` · `Distracted` |
| 3 | 577 | `#e5f7e5` | `mood-okay` (stroke `#82936b`, leaves `#b1c194` / `#82936b`, highlight `#d9e2c6`) | `Okey` `#1e6725` | `18:30` | **bare bolt vector** 10 × 14.8 fill `#eda94a` (not a component) · `Tired` | `focus-great 1` · `Locked In` |

Avatar tints `#ddf4de`, `#f4dddd`, `#e5f7e5` and label colours `#842626`, `#1e6725`/`#17501d` are **off-palette** except the greens. Card bottom edge y 636.

### 2.6 "Previous Days" — `Frame 1707479457` (30, 660) 342 × 340
- Heading `Previous Days` Inter **16 / Semi Bold 600** `#212529`, full width (342 × 19), y 660.
- Then three **day cards**, gap 8, at y **687**, **794**, **901**, each 342 × 99.

**Day card anatomy** (collapsed state)

| Property | Value |
|---|---|
| Stroke | tinted per mood, @ 50%, 0.5 pt, inside |
| Radius | 12 |
| Shadow | `#183c28` @ 8%, (0, 3), blur 8 |
| Padding | 11 all sides; horizontal layout gap 8, centred |

Inside: `Container` (41, 698) 320 × 77, gap 7 → **mood avatar** 44 × 44 (same spec as §2.5) + **text column** (92, 698) 269 × 77, vertical gap 7:
1. Title row 269 × 24, space-between: [mood label Inter **16 / Semi Bold 600** (colour per mood) · gap 6 · `Aug 30` Inter **16 / Semi Bold 600** `#212529`] … **expand button** (337, 698) 24 × 24, fill `#ffffff`, stroke `#e4ece4` 0.6 inside, r 12, holding `vuesax/twotone/arrow-up` 13 × 13 stroke `#26842f` **flipped vertically** (HTML: `rotate(-180deg) scaleX(-1)`) → reads as **chevron-down**.
2. Signals row (92, 729) 245 × 24, gap 6: [`energy-good 1` **23 × 23** + `Alert`] · dot · [`focus-okay 2` **24 × 24** + `Distracted`] · dot · [`sleep-great 1` **20 × 20** + `8h Sleep`]. Labels Inter **12 / Medium 500** `#4d5154` [grey-400] (note: grey-400 here vs grey-500 in the expanded card).
3. Medication row (92, 760) 105 × 15, gap 3: **multicolour pill illustration** 12.19 × 12.19 (fills `#ffd039`, `#ffae47`, `#ff9522`, `#dd7917`, `#e93234`, `#f9f1ef`, `#bf161c`, `#cccccc` — an emoji-style capsule, not the flat violet capsule of §2.2) + `Concerta 36mg` Inter 12/500 `#4d5154`.

| Card | y | Card fill | Card stroke @50% | Avatar fill | Sprout | Label (colour) |
|---|---|---|---|---|---|---|
| 1 | 687 | `#f8fffc` | `#abbba3` | `#ddf4de` | `mood-great` | `Great` `#17501d` |
| 2 | 794 | `#fffdfd` | `#f3b09a` | `#f4dddd` | `mood-low` | `Low` `#842626` |
| 3 | 901 | `#fefdfa` | `#f6cc8a` | `#fee8d1` | `mood-flat` (stroke `#c58b37`, leaves `#e8b964` / `#c58b37`, highlight `#f6dca6`) | `Flat` `#da7a2a` |

All card fills, strokes and avatar tints here are **off-palette**. In card 3 the bolt's pale base vector is `#f8e4c7` whereas cards 1–2 use `#f0cf9e` (two different "empty" tints for the same `energy-good 1` glyph). Content column ends at y 1000.

### 2.7 Tab bar — `Main_navbar` (28, 1037) 346 × 60
- Horizontal layout, gap **22**, right-aligned, centred vertically. Two children:
- **Navigation pill** (28, 1037) **274 × 60**, fill `#ffffff`, r 75, shadow `#183c28` @ **16%**, offset (0, 8), blur 24; items space-between.
  - Item 1 — active (`navigation/menu - home`) 94 × 60, padding 8 / 15; inner pill (43, 1045) **64 × 44**, fill `#2a9134` [green-500], r 44, padding 10 / 20; `vuesax/bold/calendar` 24 × 24 **filled white**. **No text label** (the Frame 4 `Status=Calendar` variant carries a `Calendar` 12/500 white label and is 122 wide; this instance is icon-only).
  - Item 2 (`navigation/menu - wallet`) 65 × 57, padding 16.5 / 20.5; `vuesax/linear/task-square` 24 × 24, stroke `#999b9d` [grey-200] 1.5 — outline, inactive.
  - Item 3 (`navigation/menu - analysis`) 65 × 57; `vuesax/outline/chart` 24 × 24, `#999b9d` — outline bars, inactive.
  - Item 4 (`navigation/menu - profile`) 65 × 57; `vuesax/twotone/setting-2` 24 × 24, stroke `#999b9d` 1.5 — outline gear, inactive.
- **Add Button** (324, 1042) **50 × 50**, fill `#8c68d3` [violet-500], r 75, shadow `#000000` @ 17%, offset (0, 7), blur 17; `vuesax/twotone/add` 41 × 41 — plus strokes 20.5 long, `#e9e9ea` [grey-50], weight 1.71. Matches the Frame 15 `Add Button` component exactly.

### 2.8 Home indicator (0, 1097) 402 × 34
- Bar (129, 1118) 143 × 5, fill `#212529`, r 10.

### 2.9 Above / below the fold (inferred for a 402 × 874 viewport)
If the tab bar floats at the bottom as Frame 4 implies (navbar ≈ y 780–840, home indicator 840–874):
- **Visible unobstructed:** medication card (76–216), month header (240–257), week strip (263–346), expanded day card (370–636), `Previous Days` heading (660–679).
- **Partly behind the floating bar:** previous-day card 1 (687–786).
- **Below the fold:** cards 2 (794–893) and 3 (901–1000).
The pen file does not show a scrolled state, a bottom content inset, or a scroll-edge fade; those need to be decided (see §8).

---

## 3. Component instances and states

| Component (source frame) | Instances on this screen | State shown |
|---|---|---|
| `Main_navbar` / `Navigation` (Frame 4 Navs) | 1 | `Status=Calendar` — item 1 active (green pill, bold/filled icon, **label omitted**); items 2–4 inactive (outline icons, `#999b9d`) |
| `Add Button` (Frame 15) | 1 | default, violet-500, plus icon |
| Medication row (local, `Frame 1707479461/62`) | 2 | Concerta: `Active`, bar 51.6 %; Vyvans: `Kicking In`, bar 6.25 % |
| Capsule badge (local `Background` 26 × 26) | 2 | violet-50 disc, violet-800 filled capsule |
| Progress bar (`15_rectangle` pair) | 2 | track + gradient fill, left-anchored |
| Month header + chevron | 1 | chevron **right** (arrow-up rotated 90°) |
| `_Calendar column header` (Untitled-UI style) | 7 | 6 unselected (no fill, `#414651` date) · 1 **selected** (`#17501d` 32 pt disc, white date, green-400 dot beneath) |
| Expanded day card | 1 | **expanded** (mint header band, chevron-up, 3 rows visible) |
| Check-in row | 3 | default; `more` (ellipsis) button on every row; rows differ by mood tint |
| Mood avatar 44 × 44 (`Background+Border` + `mood-<level> 1`) | 6 | great ×2, low ×2, okay ×1, flat ×1 |
| Circular icon button 24 × 24 (`Background+Border` + `arrow-up`) | 4 | 1 × chevron-up (collapse) in the expanded card; 3 × chevron-down (expand, vertically flipped instance) in Previous Days |
| Circular icon button 22.6 × 22.6 (`vuesax/outline/more`) | 3 | default; green-700 dots |
| Previous-day card | 3 | **collapsed**; tinted fill/stroke per mood (green / red / amber) |
| Energy glyph (Frame 12) | 6 | `energy-low 1` (row 1), `energy-okay 1` (row 2), bare bolt vector (row 3), `energy-good 1` ×3 (cards) — sizes 18 / 18 / ~10×15 / 23 |
| Focus glyph (Frame 12) | 6 | `focus-good 1`, `focus-flat 1`, `focus-great 1` at 18 pt; `focus-okay 2` ×3 at 24 pt |
| Sleep glyph (Frame 12) | 3 | `sleep-great 1` at 20 pt, cards only |
| Medication pill illustration (local group) | 3 | multicolour emoji-style capsule, cards only |
| Divider `Line` | 3 | `#000000` @ 10%, 1 pt |
| Status bar / Home indicator (iOS light) | 1 each | default |

**Clipping / horizontal scroll:** no row is clipped at the frame edge. The week strip fits (overflows by 2 pt, not a scroll), the signal rows fit inside their 269-pt column, the tab bar fits with 28-pt gutters. No horizontal scrolling is depicted anywhere on this screen.

Not used on this screen: Frame 3 Buttons, Frame 15 bill-shape chips (outline / solid / with-dot). Medication status (`Active`, `Kicking In`) is plain text, not a chip.

---

## 4. Copy inventory (verbatim) and issues

### 4.1 Every text string, in layer order
| # | String | Style |
|---|---|---|
| 1 | `9:41` | status bar (vector) |
| 2 | `09:54` | Inter 14/600 `#171a1d` |
| 3 | `Concerta 36 mg` | Inter 12/500 `#4d5154` |
| 4 | `Active` | Inter 12/600 `#2a9134` |
| 5 | `18:23` | Inter 14/600 `#171a1d` |
| 6 | `Vyvans` | Inter 12/500 `#4d5154` |
| 7 | `Kicking In` | Inter 12/600 `#2a9134` |
| 8 | `September 2026` | Inter 14/600 `#212529` |
| 9–22 | `Tue` `7` · `Mon` `6` · `Wed` `8` · `Thur` `9` · `Fri` `10` · `Sat` `11` · `Sun` `12` | labels 12/500 `#717680`; dates 12/600 `#414651` (10 is `#ffffff`) |
| 23 | `Okay ` (trailing space) | Inter 14/600 `#17501d` |
| 24 | `Fri 08` | Inter 14/600 `#17501d` |
| 25 | `Great` | Inter 14/600 `#17501d` |
| 26 | `18:30` | Inter 14/500 `#212529` |
| 27 | `Alert` | Inter 12/500 `#212529` |
| 28 | `Distracted` | Inter 12/500 `#212529` |
| 29 | `Low` | Inter 14/600 `#842626` |
| 30 | `18:30` | Inter 14/500 `#212529` |
| 31 | `Alert` | Inter 12/500 `#212529` |
| 32 | `Distracted` | Inter 12/500 `#212529` |
| 33 | `Okey` | Inter 14/600 `#1e6725` |
| 34 | `18:30` | Inter 14/500 `#212529` |
| 35 | `Tired` | Inter 12/500 `#212529` |
| 36 | `Locked In` | Inter 12/500 `#212529` |
| 37 | `Previous Days` | Inter 16/600 `#212529` |
| 38 | `Great` | Inter 16/600 `#17501d` |
| 39 | `Aug 30` | Inter 16/600 `#212529` |
| 40 | `Alert` | Inter 12/500 `#4d5154` |
| 41 | `Distracted` | Inter 12/500 `#4d5154` |
| 42 | `8h Sleep` | Inter 12/500 `#4d5154` |
| 43 | `Concerta 36mg` | Inter 12/500 `#4d5154` |
| 44 | `Low` | Inter 16/600 `#842626` |
| 45 | `Aug 30` | Inter 16/600 `#212529` |
| 46–49 | `Alert` · `Distracted` · `8h Sleep` · `Concerta 36mg` | as card 1 |
| 50 | `Flat` | Inter 16/600 `#da7a2a` |
| 51 | `Aug 30` | Inter 16/600 `#212529` |
| 52–55 | `Alert` · `Distracted` · `8h Sleep` · `Concerta 36mg` | as card 1 |

No tab-bar label is rendered on this screen (the component's `Calendar` label is absent).

### 4.2 Typos and inconsistencies
1. **`Okey`** (row 3) → `Okay`. The header band of the same card spells it `Okay`.
2. **`Vyvans`** → `Vyvanse`. Also the only medication row without a dose.
3. **`Thur`** → `Thu` (the other six are three-letter).
4. **Weekday order is wrong:** strip reads `Tue 7 · Mon 6 · Wed 8 …` — Tue/Mon are swapped and 7 precedes 6.
5. **Weekdays don't match the real September 2026 calendar:** 6 Sep 2026 is a Sunday, 7 Mon, 8 Tue, 9 Wed, **10 Thu**, 11 Fri, 12 Sat. The strip labels 10 as `Fri`. (30 Aug 2026 is a Sunday, consistent with nothing on screen either way.)
6. **Selected day ≠ expanded day:** the strip selects `10` but the expanded card is titled `Fri 08`.
7. **`Okay ` has a trailing space** in the header band text node.
8. **Dose spacing:** `Concerta 36 mg` (med bar) vs `Concerta 36mg` (Previous Days). Other screens use `Concerta · 36 mg` (iphone17-1).
9. **Date formats:** `Fri 08` (weekday + zero-padded day) vs `Aug 30` (month + day) vs `September 2026` (full month). Pick one day format.
10. **Time format:** 24-hour `09:54`, `18:23`, `18:30` here vs `9:15 AM` on the Edit Check-In screen (iphone17-18).
11. **Placeholder repetition:** all three check-ins are stamped `18:30`; all three previous days are `Aug 30`; every card has identical signals (`Alert · Distracted · 8h Sleep · Concerta 36mg`).
12. **Mood label colours are not one ramp:** `Great` and the header `Okay` share `#17501d`, but row `Okey` is `#1e6725`; `Low` `#842626`, `Flat` `#da7a2a`. Two different greens for two different moods (and the same green for two different moods) is inconsistent.
13. **Label ↔ glyph level mismatch:** `Alert` is drawn with `energy-low` (row 1), `energy-okay` (row 2) and `energy-good` (cards); `Distracted` with `focus-good` (row 1), `focus-flat` (row 2) and `focus-okay` (cards). The same word should always map to the same glyph level.
14. Signal labels are `#212529` in the expanded card but `#4d5154` in the Previous Days cards.

---

## 5. Glyph and icon usage

### 5.1 Signal glyphs (Frame 12 "Glyphs")
Frame 12 defines four signals × five levels (`low · flat · okay · good · great`), all in the same filled/illustrative style (no outline variants):

| Signal | Glyph | Level encoding (from Frame 12 JSON) | Colours |
|---|---|---|---|
| Mood | sprout (two leaves + stem) | colour ramp: low red → flat amber → okay sage → good green → great dark green | low `#bc4749`/`#d97773`/`#eeb4aa`; flat `#c58b37`/`#e8b964`/`#f6dca6`; okay `#82936b`/`#b1c194`/`#d9e2c6`; good `#2a9134`/`#75ba4f`/`#b7dc88`; great `#175723`/`#428d52`/`#9ccaa0` |
| Energy | bolt | pale bolt `#f8e4c7` under a **clip-mask** (`asset-energy-<level>-fill`) whose height grows 16.8 → 26.6 → 36.4 → 46.2 → 56 of 64 (26 % → 88 %), revealing the saturated bolt `#d98232`/`#eda94a` | pale `#f8e4c7` (instances also use `#f0cf9e`), fill `#d98232`, highlight `#eda94a` |
| Focus | target + rising arrow | ring arc grows: low = small arc, flat = half, okay = ¾, good = full ring with two dots, great = full ring, no dots | ring `#4278a8` on `#d6e5f0`, centre `#8ab8d6`, arrow `#eda94a` |
| Sleep | crescent moon + star | same clip-mask scheme as energy (`asset-sleep-<level>-fill`, plus a separate star mask) | moon `#8c68d3` [violet-500] / `#bca5e8` on `#e3d7f3`; star `#eda94a` on `#f8e4c7` |

Used on this screen:

| Where | Mood | Energy | Focus | Sleep |
|---|---|---|---|---|
| Expanded row 1 | `mood-great` 33.6 pt in `#ddf4de` disc | `energy-low 1` 18 pt | `focus-good 1` 18 pt | — |
| Expanded row 2 | `mood-low` | `energy-okay 1` 18 pt | `focus-flat 1` 18 pt | — |
| Expanded row 3 | `mood-okay` | bare bolt vector (`#eda94a`, ~10 × 15) — **not a Frame 12 instance** | `focus-great 1` 18 pt | — |
| Prev card 1 | `mood-great` | `energy-good 1` 23 pt | `focus-okay 2` 24 pt | `sleep-great 1` 20 pt |
| Prev card 2 | `mood-low` | `energy-good 1` 23 pt | `focus-okay 2` 24 pt | `sleep-great 1` 20 pt |
| Prev card 3 | `mood-flat` | `energy-good 1` 23 pt (pale `#f8e4c7`) | `focus-okay 2` 24 pt | `sleep-great 1` 20 pt |

**Rendering caveat (important):** in the PNG the bolt and moon glyphs show **solid black rectangles** behind them (also visible in the Frame 12 render). In the JSON these are the `Clip path group → asset-…-fill` mask vectors (`fill #000000`) that the exporter drew instead of applying as a clip. The intended look is almost certainly a partially-filled bolt/moon; the black boxes are an export artefact, not the design. Needs owner confirmation (§8).

Glyph sizes are inconsistent across contexts: 18 pt in the expanded rows; 23 / 24 / 20 pt (energy / focus / sleep) in the previous-day cards; the mood sprout is 33.56 pt inside a 44 pt disc everywhere.

### 5.2 UI icons (vuesax set)
| Icon | Variant | Where | Style / colour |
|---|---|---|---|
| `calendar` | **bold** (filled) | tab item 1 (active) | white on green-500 pill |
| `task-square` (list-check) | **linear** (outline) | tab item 2 | stroke `#999b9d` 1.5 |
| `chart` (bars) | **outline** | tab item 3 | `#999b9d` |
| `setting-2` (gear) | **twotone** (outline) | tab item 4 | stroke `#999b9d` 1.5 |
| `add` (plus) | twotone | FAB | strokes `#e9e9ea` 1.71 on violet-500 |
| `arrow-up` (chevron) | twotone (stroke only) | month header (rotated → right), collapse button (up), expand buttons (flipped → down) | `#212529` 1.71 in header; `#26842f` 1.41 in buttons |
| `more` (ellipsis, horizontal) | outline (three filled dots) | each check-in row | `#1e6725` |
| capsule (medication) | flat filled single-colour vector | med-bar badges | `#4d3974` on `#f4f0fb` |
| pill illustration (medication) | multicolour emoji-style | previous-day med rows | `#ffd039` `#ff9522` `#e93234` `#f9f1ef` … |

Not present on this screen: mic, pencil, play, sparkles, lock, back chevron.

Convention that emerges: **active tab = bold/filled icon on a green pill; inactive = linear/outline in grey-200**, matching Frame 4.

---

## 6. Data the screen implies

**Medication bar** (per active medication, ordered by time taken)
- `name: String` (`Concerta`, `Vyvans`)
- `dose: String?` (`36 mg` — absent for Vyvans)
- `takenAt: Time` (24 h, `09:54`, `18:23`)
- `status: enum { Active, Kicking In, … }` — only two values shown; whether there are others (e.g. wearing off, ended) is not shown
- `progress: 0…1` (`0.516`, `0.0625`) — presumably elapsed fraction of the medication's effect window; the settings screen (iphone17-16) also lists `Show Taken Time` / `Show End Time`, so an **end time** exists in the model even though it is not rendered here
- Settings toggles referenced elsewhere: `Show Medication Bar`, `Show Medication Name`, `Show Taken Time`, `Show End Time` (all iphone17-16)

**Month / week strip**
- `month: YearMonth` (`September 2026`) with a forward affordance (chevron right)
- 7 `DayCell { weekday: String, day: Int, isSelected: Bool, hasIndicator: Bool }` — the green-400 dot appears only under the selected day; whether it means "selected", "today", or "has entries" is ambiguous (§8)

**Day (expanded card)**
- `daySummaryMood: Mood` (`Okay`) shown in the header alongside `dayLabel` (`Fri 08`) — a day-level aggregate distinct from the individual check-ins (Great / Low / Okay)
- `checkIns: [CheckIn]`, each: `mood: Mood`, `time: Time` (`18:30`), `energy: EnergyLevel` + label, `focus: FocusLevel` + label; a per-row overflow menu

**Previous day card** (collapsed)
- `mood: Mood`, `date` (`Aug 30`), `energy` (`Alert`), `focus` (`Distracted`), `sleep: hours` (`8h Sleep`), `medications: [name + dose]` (`Concerta 36mg`)

**Enums** (labels seen here plus sibling screens)
- Mood (5): `Low · Flat · Okay · Good · Great` — five glyph levels; only Great/Low/Okay/Flat appear here
- Energy: `Tired · Steady · Alert · Charged` seen across screens (Insights, Edit Check-In) — **4 labels vs 5 glyph levels** in Frame 12
- Focus: `Distracted · Present · Sharp · Locked In` — **4 labels vs 5 glyph levels**
- Sleep: glyph has 5 levels, but the label is a **quantity** (`8h Sleep`); Edit Check-In uses `Low/Flat/Okay/Good/Great` chips for sleep. Mapping hours → level is undefined.
- Medication status: `Active · Kicking In`

Not on this screen but listed in the brief: percentages and counts (those live on the Insights screen, iphone17-7).

---

## 7. Interactions implied

| Element | Implied interaction | Evidence |
|---|---|---|
| Vertical scroll | whole content column scrolls; tab bar floats | canvas 1131 > 874; Frame 4 shows a floating pill |
| Month header chevron (→) | advance to next month, or open a month picker | chevron points right, not down |
| Week strip day cell | tap to select a day → the expanded card switches to that day | one filled cell; settings screen has "Auto-expand selected day" |
| Week strip | horizontal swipe between weeks (not drawn) | only one week visible, no page dots |
| Expanded card chevron-up | collapse the day card | chevron-up; settings has "Always expand cards" |
| Check-in row | tap → detail / edit (Edit Check-In screen exists, iphone17-18) | row is a list item; no chevron drawn |
| Row `more` (…) button | overflow menu — edit / delete / share (contents not shown) | 22.6 pt round button, 3 per card |
| Previous-day card chevron-down | expand the day in place | flipped arrow-up = chevron-down |
| Previous-day card body | tap → expand or open the day | ambiguous with the chevron |
| Tab bar items | switch to Calendar / Check In / Insights / Settings | Frame 4 variants |
| `Add Button` (+) | start a new check-in (voice/text/medication chooser, iphone17-4) | violet FAB on every tab |
| Medication rows | no tap affordance drawn (no chevron, no button); Dose Guard / Log Dose sheet referenced on the settings screen | iphone17-16 copy |
| Progress bars | display only | — |
| Back / save | none — root tab, nothing to save | no nav bar |

Touch-target note: the `more` button (22.6 pt) and the expand/collapse buttons (24 pt) are well under the 44 pt minimum; they need an enlarged hit area even if drawn small.

---

## 8. Open questions / ambiguities for the owner

1. **Black boxes on bolt/moon glyphs.** The PNG shows solid black rectangles behind every energy bolt and sleep moon (and in the Frame 12 render). The JSON says these are clip masks (`asset-energy-<level>-fill`). Is the intended look a partially filled glyph (mask applied), and are the black boxes just an export artefact? This decides how the glyphs get implemented.
2. **Selected day vs expanded day.** The strip selects `10`, the card says `Fri 08`. Which one is the source of truth — and does selecting a day always replace the expanded card?
3. **What does the green-400 dot under the selected day mean** — "today", "selected", or "has check-ins"? Should unselected days with entries also get a dot?
4. **Day-summary mood in the header** (`Okay · Fri 08`) while rows are Great / Low / Okay: is it a mode, an average, the latest check-in, or user-chosen?
5. **Month chevron points right.** Next month? Month picker? Or should it be a down-chevron (menu) like most iOS date headers?
6. **Tab-bar label.** Frame 4's active variant has a text label (`Calendar`); this screen's instance is icon-only. Which is final?
7. **Two medication icon styles** — flat violet capsule (med bar) vs multicolour emoji-style pill (previous-day rows). Keep one?
8. **Energy / focus vocabularies.** Frame 12 has 5 levels per signal; the copy uses 4 energy labels (Tired/Steady/Alert/Charged) and 4 focus labels (Distracted/Present/Sharp/Locked In). Which label maps to which level, and is one level unused?
9. **Sleep mapping.** Sleep is shown as hours (`8h Sleep`) but the glyph has 5 discrete levels and the Edit screen uses Low…Great chips. What are the hour thresholds?
10. **Medication bar semantics.** Is progress elapsed time / effect duration? Where does `Active` end and what other statuses exist (`Wearing off`, `Ended`)? Should the end time render (settings has "Show End Time")?
11. **Vyvans row has no dose.** Placeholder or a real "dose unknown" state?
12. **Time format** — 24-hour here, `9:15 AM` on Edit Check-In. Follow the device locale?
13. **Colour tokens.** Roughly twenty colours on this screen are outside the Frame 5 ramps (`#fbfffc`, `#e6f5ee`, `#e4ece4`, `#717680`, `#414651`, `#842626`, `#da7a2a`, `#1e6725`-vs-`#17501d` for mood, the four avatar tints, the three card tints and strokes, `#8061bf`, `#fafafa`, `#183c28` shadow). Should these become named tokens (mood ramps, surface tints) or be snapped to the palette?
14. **Card radius / stroke inconsistency.** Expanded card r 24 with a centre-aligned stroke; every other card r 12 with an inside stroke. Intentional emphasis?
15. **Glyph sizes** differ between the expanded rows (18) and the previous-day cards (23 / 24 / 20). Intentional hierarchy or drift?
16. **Fold behaviour.** With a floating tab bar, previous-day card 1 sits half behind the bar at rest. Bottom content inset? Scroll-edge fade? Should the bar hide on scroll?
17. **Week strip font** is exported as "mixed" and uses Untitled-UI greys (`#717680`, `#414651`) — confirm Inter and the intended grey tokens.
18. **Overflow menu contents** for the per-row `more` button.
19. **Hit areas** for the 22.6 / 24 pt round buttons — accept enlarged invisible targets?
20. **Placeholder data.** Confirm the repeated `18:30` / `Aug 30` / identical signals are lorem, not a required demo state.
