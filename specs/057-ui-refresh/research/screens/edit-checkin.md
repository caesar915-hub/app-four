<!-- Created: 2026-09-27 22:03 WEST · Updated: 2026-09-27 22:03 WEST -->
# Edit Check-In — screen spec (pen node `hSrrZ`, frame "iPhone 17 - 18")

**Sources used:** PNG render `pen/named/iphone17-18-edit-checkin.png` (804×3548 @2x → 402×1774 pt; ground truth for what is visible) · Pencil HTML export `pen/html-lite/iPhone-17-18.html` (layer names + auto-layout gaps/paddings) · Figma JSON `figma/iphone17-18{.raw}.json` (hex, fonts, radii, bounds) · design-system frames 2 (Typography), 3 (Buttons), 4 (Navs), 5 (Color palettes), 12 (Glyphs), 15 (Bill-shape + Add Button).

**Read this first — the three sources disagree in one way.** The PNG and the HTML export lay every chip group out as a **single row that clips** (`541_frame`, `563_frame`, `592_frame` are `flex-direction: row; overflow: hidden; gap: 6px`). The Figma JSON re-flowed the same chips into **wrapped rows** (y = 0, 33, 66, 99, 132) and so reports taller cards (e.g. Emotions 342.17 vs ≈210 in the render). Where they differ, this spec follows the PNG and gives the JSON figure in brackets. All coordinates below are in pt, origin top-left of the 402-wide frame.

---

## 1. Purpose and placement

- **What it is:** the edit form for an existing check-in. The pen file labels the node "Check-In Details · Edit Check-In", i.e. the edit mode reached from the Check-In Details screen. It replaces the current app's "Edit sheet" (old DESIGN.md §11).
- **Nav chrome present:** iOS status bar (9:41), a **circular back pill** (`vuesax/outline/arrow-left`) + page title, home indicator.
- **Nav chrome absent:** no `Navigation` tab bar (Frame 4), no `Add Button` FAB (Frame 15), no Cancel/Done pair, no trailing action in the title row (the title `Container` is `justify-content: space-between` with only one child, so the right slot is empty).
- **Inference:** a **pushed detail screen** on the navigation stack with the tab bar hidden, not a modal sheet — a back chevron is a pop affordance; a sheet would show a grabber or Cancel/Done. See open question 1.
- **Scroll:** the frame is 1774 tall but content ends at y≈1389 (bottom of "Save Changes"); the remainder is empty canvas. On a 402×874 device the screen scrolls vertically ≈515 pt + bottom safe area.

---

## 2. Layout top → bottom (exact metrics)

### 2.0 Frame
| Property | Value |
|---|---|
| Size | 402 × 1774 (device canvas; content height ≈1389) |
| Fill | `#fbfffc` (canvas — not a Frame 5 palette token) |
| Corner radius / clip | 32 / clips content |
| Status bar | `Status Bar` instance 402×52; time "9:41" at (36,21); signal/wifi/battery at x 301–370, y 20–34; glyph fill `#303030` |
| Home indicator | `Home Indicator` instance 402×34 at y 1740; bar 143×5, `#303030`, r 10, at (129.5, 1761) |
| Left gutter | 29 (content column) / 31 (title row) |
| Content column | `Frame 11` at (29,150), width 344, vertical auto-layout, **gap 24** |

**Fold (402×874 device):** above the fold = status bar, title row, Date & Time, the entire "How Did You Feel?" card (ends ≈753), the Medication card header and its medication chips (≈836–863). The "Concerta Dose" label (≈876–893) straddles the fold; the dose chips, Emotions, Side Effects and Save Changes are below it.

### 2.1 Title row — `Container` at (31,74), 340 × 42.6
| Element | Spec |
|---|---|
| Back pill `Background+Border` | 42.6 × 42.6 at (31,74); fill `#ffffff`; stroke 1.065 `#e4ece4` inside; r 21.3 (full circle) |
| Back icon | `vuesax/outline/arrow-left` 20×20 centered (inset 11.3); fill `#1e6725` (green-700) |
| Gap pill → title | 7 |
| Title "Edit Check-In" | Inter **18 / 600** (Semi Bold), `#17501d` (green-800), 118×22, at x 80.6, vertically centred on the pill (y ≈96–118) |

Render check: pill occupies y 74–117 at x 52 (matches JSON).

### 2.2 Date & Time — `Frame 4` at (29,150), 344 × 92, column gap 12
| Element | Spec |
|---|---|
| Header "Date & Time" | Inter **16 / 600**, `#193024`, full width, h 19 (y 150–169). Sits directly on the canvas — the only section without a card. |
| Field row `Frame 1707479439` | y 181, two columns **166** wide, **gap 12** |
| Column (`Frame 1707479440` / `…441`) | vertical, **gap 7**: label then field |
| Labels "Date" / "Time" | Inter **12 / 500**, `#1c1b1f`, h 15 (y 181–196) |
| Field `Background` | 166 × 39 at y 203 (render: ≈205–243); fill `#ffffff`; stroke 1 `#1c1b1f` @ 10 % inside; **r 12**; shadow 0 / 2 / blur 8 (HTML says 7) / `#183c28` @ 8 %; padding **12 top/bottom × 10 left/right**; row gap 7 |
| Field icon | 15 × 15 at (10,12) inside the field; single vector, fill `#6f7f75`, stroke ≈1.07. Date = outline **calendar**, Time = outline **clock**. Layers are unnamed ("SVG"/"Vector"); the file's icon library has `vuesax/outline/calendar` and `vuesax/outline/clock`. |
| Field value "Jun 29" / "9:15 AM" | Inter **12 / 600**, `#193024`, at x 32 inside the field (icon 15 + gap 7 + padding 10) |

Section ends y 242; gap 24 → next card at 266.

### 2.3 Card "How Did You Feel?" — `Background+Border` at (29,266), 344 × ≈487 [JSON 520.17 because the sleep row wrapped]
| Property | Value |
|---|---|
| Fill / stroke / radius | `#ffffff` / **1** `#e4ece4` inside / **24** |
| Shadow | 0 / 4 / blur 8 (HTML 7) / `#183c28` @ 8 % |
| Padding | 15 + 1 border → content inset **16**, content width **312** (x 45–357) |
| Column gap | **15** between header row, divider, body |
| Render extents | top 266, bottom ≈748–753 (shadow to ≈760) |

**Header row** `Frame 1707479449` 312 × 29.167, space-between:
- "How Did You Feel?" Inter **16 / 600** `#193024`, 143×19, vertically centred.
- Collapse button `Background+Border` **29.167 × 29.167** circle, fill `#ffffff`, stroke **0.729** `#e4ece4` inside, r 14.583; icon `vuesax/twotone/arrow-up` **18.763** square, stroke `#26842f` (green-600) weight ≈1.71. State shown: **expanded (chevron up)**.

**Divider** `Line 2`: 312 × 1, `#000000` @ 10 %.

**Body** `Frame 1707479447` 312 × ≈396 [JSON 429], column **gap 13**, four blocks:

Blocks 1–3 (mood / Energy Level / focus level) share one anatomy, 312 × 102, internal gap 7:
| Row | Spec |
|---|---|
| `Paragraph` (h 17, space-between) | left label Inter **14 / 500** `#292d32`; right caption Inter **12 / 600** `#2a9134` (green-500) |
| Tile row (h 56, **gap 8**) | five `Background+Border` tiles **56 × 56**, r **20**, **no fill** (card white shows through), stroke **1** inside. Tile x (abs): 45, 109, 173, 237, 301. Glyph frame 33.555 × 33.555 centred (inset 11.22). |
| Caption row (h 15, space-between) | "Low" left / "High" right, Inter **12 / 400** `#6f7f75` |

| Block | Label (verbatim) | Caption | Tile strokes L→R | Glyph names |
|---|---|---|---|---|
| 1 | `mood ` (trailing space) | Good | `#e5f7e5` ×4, 5th **`#70b577`** (green-300, selected) | mood-low / flat / okay / good / great |
| 2 | `Energy Level` | Charged | 1st **`#f3b09a`** (selected), `#e5f7e5` ×4 | energy-low … great |
| 3 | `focus level` | Present | `#e5f7e5`, 2nd **`#f6cc8a`** (selected), `#e5f7e5` ×3 | focus-low … great |

Block y (abs, computed from auto-layout): mood 341–443 · energy 456–558 · focus 571–673 (render within ±5).

Block 4 "Your Sleep" `Container` 312 × ≈51 [JSON 84, two rows]:
- "Your Sleep" Inter **14 / 500** `#292d32` h 17; gap 7.
- Chip row, **gap 6**, `Bill-shape` chips: Low (56) · Flat (54) · Good (63) · **Okay (62, solid)** · Great (64). Sum incl. gaps = **323 > 312**: with Figma's Inter metrics the JSON wraps "Great" onto a second row; in the pen render all five fit on one line (Great ends ≈x 355, flush with the content edge). Treat as a row that must wrap or scroll on device.

### 2.4 Card "Medication" — `Background` at (29,≈777), **342** × ≈183 [JSON 216.17]
| Property | Value |
|---|---|
| Fill / stroke / radius | `#ffffff` / **0.5** `#000000` @ 10 % inside / **24** |
| Shadow | 0 / 4 / 8 / `#183c28` @ 8 % |
| Padding | 15 → content inset 15, content width 312 (x 44–356) |
| Gaps | 15 (header → divider → body); body `Frame 1707479452` gap **13**; sub-groups gap **10** |
| Render extents | top ≈771–777, bottom ≈951–957 |

- Header row: "Medication" 16 / 600 `#193024`; collapse button identical to 2.3 (expanded).
- Divider 312 × 1 `#000` @ 10 %.
- **Medication chips** (row, gap 6, no clipping needed): Concerta (86) · Ritalin (68) · **Elvense (77, solid)**. Total 243 — fits.
- **"Concerta Dose"** Inter 14 / 500 `#292d32`, h 17; gap 10.
- **Dose chips** `Container` (row, gap 6, **no `overflow:hidden`**): **60mg (66, solid)** · 18mg (64) · 27mg (65) · 36mg (66) · Missed (74) · **Taken (67, solid)**. Total **432 > 312**. In the render the row **spills past the card's right edge** ("Missed" is fully drawn, ending ≈x 389, beyond the card edge at 371) and "Taken" is cut by the **frame edge at 402**. [JSON wraps Missed/Taken to a second row.]

### 2.5 Card "Emotions" — `Background` at (29,≈984), 342 × ≈210 [JSON 342.17]
Same card style as 2.4 (0.5 `#000`@10 %, r 24, shadow, padding 15, gaps 15/13/10). Render extents: top ≈974–977, bottom ≈1182–1187.
- Header "Emotions" 16 / 600 `#193024` + collapse button (expanded). Divider.
- **Pleasant** group: label Inter 14 / 500 `#292d32`; chip row `541_frame` gap 6, **`overflow: hidden` → clips at the content edge x 356**: **Excited (75, solid)** · Joyful (67) · Proud (66) · Serene (73) · Thrilled (76) · Inspired (79) · Content (79) · Grateful (79) · Peaceful (82) · Secure (73). Visible in render: Excited, Joyful, Proud, Serene and a ~10 pt sliver of Thrilled.
- **Unpleasant** group: label 14 / 500; chip row `563_frame` (same clipping): Angry (67) · Anxious (78) · **Frustrated (92, solid)** · Irritated (78) · Jealous (77) · Sad (55) · Lonely (71) · Disappointed (109) · Hopeless (86) · Discouraged (105). Visible: Angry, Anxious, Frustrated, Irritated (cut mid-chip at 356).

### 2.6 Card "Side Effects" — `Background` at (29,≈1218), 342 × ≈116 [JSON 248.17]
Same card style **except r 23** (JSON/HTML both say 23 — the other cards are 24). Render extents: top ≈1204–1207, bottom ≈1320–1325.
- Header "Side Effects" 16 / 600 + collapse button (expanded). Divider. No sub-label.
- Chip row `592_frame` gap 6, `overflow: hidden`: Dry Mouth (93) · **Headache (91, solid)** · Nausea (76) · Appetite Gone (115) · Insomnia (84) · Jittery (70) · Heart Racing (107) · Stomach Ache (116) · Dizzy (64) · Irritable (77) · **Rebound (84, solid)** · Crash (66) · Sweating (86) · Grinding Teeth (117) · **Flat Affect (92, solid)**. Visible: Dry Mouth, Headache, Nausea, "Appe" (cut at 356).

### 2.7 Save Changes — `Button / Filled` at (29,≈1359), 344 × 44 (render y 1345–1389)
| Property | Value |
|---|---|
| Component | `Button / Filled`, **Size=Medium, Icon=Without Icon, State=Default** (Frame 3) |
| Fill / radius | `#2a9134` (green-500) / **999** (pill) |
| Padding / gap | 10 top-bottom × 18 left-right; gap 8 (icon slot, unused) |
| Label "Save Changes" | Inter **16 / 500**, `#ffffff`, line-height **24**, centred (110×24) |
| Other states (Frame 3) | Hovered/pressed fill `#1e6725`; Focused `#17501d`; Disabled fill `#e5e7eb`, label `#9ca3af` |

Below the button: empty `#fbfffc` canvas from ≈1389 to 1774; home indicator bar at 1761.

### 2.8 Colour tokens used on this screen vs Frame 5
| Token (Frame 5) | Hex | Used for |
|---|---|---|
| green-500 | `#2a9134` | solid chips, level captions, Save button, divider-less accents |
| green-600 | `#26842f` | collapse chevron stroke |
| green-700 | `#1e6725` | back-arrow glyph |
| green-800 | `#17501d` | page title |
| green-300 | `#70b577` | selected mood tile border |
| **Not in Frame 5** | `#193024` ink · `#292d32` label ink · `#6f7f75` muted/icons · `#1c1b1f` field label + field stroke · `#e4ece4` hairline · `#e5f7e5` tile hairline · `#fbfffc` canvas · `#ffffff` card · `#183c28` shadow tint · `#f3b09a` energy-selected · `#f6cc8a` focus-selected · `#000000`@10 % divider/card stroke | need naming in the new DESIGN.md |

Typography (Frame 2 = Inter, weights Regular/Medium/Semi Bold/Bold): 18/600 title · 16/600 section headers · 14/500 sub-labels · 12/600 field values + level captions · 12/500 chip text + field labels · 12/400 Low/High · 16/500 button label. Everything is single-line (`white-space: nowrap`), auto line-height except the button (24).

---

## 3. Component instances and states

| Component (DS frame) | Instances here | State(s) shown | Notes |
|---|---|---|---|
| Back pill (no DS component; ad-hoc `Background+Border` + `vuesax/outline/arrow-left`) | 1 | default | 42.6 circle — not in Frame 3/4 |
| Text field (ad-hoc `Background`) | 2 (Date, Time) | filled, default | leading outline icon + 12/600 value; no focused/error state designed |
| Section card (ad-hoc) | 4 | **all expanded** | two visual variants: card 1 = 344 w, 1 px `#e4ece4`; cards 2–4 = 342 w, 0.5 px `#000`@10 % |
| Collapse button (ad-hoc 29.167 circle + `vuesax/twotone/arrow-up`) | 4 | expanded (chevron up) | collapsed state not designed |
| Level tile (ad-hoc 56×56 r20) | 15 (3 signals × 5) | **unselected** `#e5f7e5` / **selected** per signal: mood `#70b577`, energy `#f3b09a`, focus `#f6cc8a` | selected has no fill change — border only |
| `Bill-shape` **BG=outline** (Frame 15) | 5 sleep + 2 meds + 4 dose + 18 emotions + 12 side effects = 41 | unselected | fill `#fff`, stroke 1 `#e4ece4`, r 15, h 27, padding 6 × 16 (5×15 + 1 border), text 12/500 `#193024` |
| `Bill-shape` **BG=solid** (Frame 15) | Okay · Elvense · 60mg · Taken · Excited · Frustrated · Headache · Rebound · Flat Affect = 9 | selected | fill + stroke `#2a9134`, text `#ffffff` |
| `Bill-shape` BG=With Dot | 0 | — | exists in Frame 15, unused here |
| `Button / Filled` Medium (Frame 3) | 1 | Default | full-width 344 |
| `Navigation` tab bar (Frame 4) · `Add Button` (Frame 15) | 0 | — | absent — confirms pushed/detail context |
| Status Bar · Home Indicator | 1 each | light | |

**Rows clipped at an edge (⇒ horizontal scroll implied):**
- Concerta Dose row — overflows the card, clipped by the **frame** (x 402). "Taken" partially visible.
- Pleasant row — clipped at **content edge x 356**; "Thrilled" sliver visible.
- Unpleasant row — clipped at x 356 mid-"Irritated".
- Side Effects row — clipped at x 356 mid-"Appetite Gone" ("Appe").
- Your Sleep row — fits in the render but overflows by 11 pt under Figma metrics (see 2.3).

---

## 4. Copy inventory (verbatim) and copy issues

### 4.1 Every string, in reading order
`9:41` · `Edit Check-In` · `Date & Time` · `Date` · `Jun 29` · `Time` · `9:15 AM` · `How Did You Feel?` · `mood ` (note trailing space) · `Good` · `Low` · `High` · `Energy Level` · `Charged` · `Low` · `High` · `focus level` · `Present` · `Low` · `High` · `Your Sleep` · `Low` · `Flat` · `Good` · `Okay` · `Great` · `Medication` · `Concerta` · `Ritalin` · `Elvense` · `Concerta Dose` · `60mg` · `18mg` · `27mg` · `36mg` · `Missed` · `Taken` · `Emotions` · `Pleasant` · `Excited` · `Joyful` · `Proud` · `Serene` · `Thrilled` · `Inspired` · `Content` · `Grateful` · `Peaceful` · `Secure` · `Unpleasant` · `Angry` · `Anxious` · `Frustrated` · `Irritated` · `Jealous` · `Sad` · `Lonely` · `Disappointed` · `Hopeless` · `Discouraged` · `Side Effects` · `Dry Mouth` · `Headache` · `Nausea` · `Appetite Gone` · `Insomnia` · `Jittery` · `Heart Racing` · `Stomach Ache` · `Dizzy` · `Irritable` · `Rebound` · `Crash` · `Sweating` · `Grinding Teeth` · `Flat Affect` · `Save Changes`

(76 text nodes; strings not visible in the render because of clipping: Taken, Thrilled, Inspired, Content, Grateful, Peaceful, Secure, Jealous, Sad, Lonely, Disappointed, Hopeless, Discouraged, Insomnia, Jittery, Heart Racing, Stomach Ache, Dizzy, Irritable, Rebound, Crash, Sweating, Grinding Teeth, Flat Affect.)

### 4.2 Typos / inconsistencies
1. **`Elvense`** — the lisdexamfetamine brand is spelled **Elvanse** (UK/EU). (US: Vyvanse.)
2. **`mood `** has a trailing space in the text node.
3. **Casing:** `mood` and `focus level` are lowercase; `Energy Level`, `Your Sleep`, `Concerta Dose` are Title Case.
4. **Caption ≠ selection:** mood caption `Good` but the 5th (great) tile is selected; energy caption `Charged` but the **1st (low)** tile is selected; focus caption `Present` but the 2nd tile is selected. Placeholder data, but the caption→level mapping is therefore undefined by the file.
5. **Sleep chip order** `Low · Flat · Good · Okay · Great` puts Good before Okay, contradicting the low→flat→okay→good→great ladder every glyph set uses.
6. **`Concerta Dose`** while **Elvense** is the selected medication — the label should follow the selection.
7. **`60mg`** is not a Concerta strength (18 / 27 / 36 / 54 mg); it is also listed first, out of numeric order.
8. **`Missed` / `Taken`** (a status) are mixed into the dose-strength row, giving **two solid chips in one row** (60mg + Taken) — reads as multi-select where it is presumably single-select + status.
9. **Your Sleep** is a 5-word text-chip scale here, while Frame 12 defines a **5-level sleep moon glyph** that this screen never uses; no hours-of-sleep field exists.
10. **Card geometry drift:** card 1 is 344 wide with a 1 px `#e4ece4` stroke and 16 pt inset; cards 2–4 are **342** wide with a 0.5 px `#000`@10 % stroke and 15 pt inset; Side Effects has **r 23** vs 24.
11. **Clipping drift:** three chip rows clip at the content edge, the Concerta Dose row does not clip at all and spills past the card.
12. `Date & Time` is a bare header on the canvas while every other section is a card.
13. Field icons are unnamed vectors ("SVG"/"Vector") rather than `vuesax/outline/calendar` / `…/clock` instances.
14. Energy glyph back-plate is `#f0cf9e` for levels 1–3 and `#f8e4c7` for 4–5 on this screen; Frame 12 uses `#f8e4c7` for all five.
15. Shadow blur: JSON says 8, HTML export says 7 for every shadow — pick one.

---

## 5. Glyph and icon usage

### 5.1 Signal glyphs (Frame 12 "Glyphs"; filled, multi-colour illustrations — not SF Symbols, not tintable)
| Signal | Glyph | Levels shown | Colours per level (L1→L5) | Selected here |
|---|---|---|---|---|
| mood | **sprout** (two-tone leaves) | all 5 | L1 `#d97773`/`#bc4749` · L2 `#e8b964`/`#c58b37` · L3 `#b1c194`/`#82936b` · L4 `#75ba4f`/`#2a9134` · L5 `#428d52`/`#175723` | L5 (great) |
| energy | **bolt** over a black "charge" block | all 5 | bolt `#eda94a`/`#d98232`, plate `#f0cf9e` (L1–3) / `#f8e4c7` (L4–5), block `#000000` whose height grows 8.8 → 13.9 → 19.1 → 24.2 → 29.4 of 33.56 | L1 (low) |
| focus | **target** with arrow | all 5 | rings `#d6e5f0` (light) + `#8ab8d6`, progress arc `#4278a8` (1 segment at L5 = full ring, 3 segments otherwise), arrow `#eda94a` | L2 (flat) |
| sleep | **moon + sparkle** (`#8c68d3`/`#bca5e8`/`#e3d7f3`, sparkle `#eda94a`/`#f8e4c7`, block `#000`) | **0 — not used**; sleep is text chips here | — | — |

Glyph frames are 33.555 pt square inside 56 pt tiles (Frame 12 shows them at 64).

### 5.2 UI icons
| Icon | Where | Style | Size | Colour |
|---|---|---|---|---|
| `vuesax/outline/arrow-left` | back pill | outline (filled path) | 20 | `#1e6725` |
| `vuesax/twotone/arrow-up` | 4 collapse buttons | stroked chevron, weight ≈1.71 | 18.763 | `#26842f` |
| calendar (outline; unnamed vector ≈ `vuesax/outline/calendar`) | Date field | outline, stroke ≈1.07 | 15 | `#6f7f75` |
| clock (outline; unnamed vector ≈ `vuesax/outline/clock`) | Time field | outline | 15 | `#6f7f75` |

Not present on this screen: tab-bar icons (calendar / task-square / chart / setting-2), Add Button (+), list-check, bars, gear, chevron-down, ellipsis, mic, capsule, pencil, play, sparkles, lock. Icon style rule inferred: **outline/linear** for UI chrome; **bold** variants are reserved for the active tab pill (Frame 4).

---

## 6. Data the screen implies

| Field | Type / values (as shown) | Selection | Displayed as |
|---|---|---|---|
| Check-in date | calendar date — `Jun 29` (no year) | picker | Date field |
| Check-in time | time of day — `9:15 AM` (12-h, locale) | picker | Time field |
| mood | 5-level ordinal `low · flat · okay · good · great` (glyph names) | single | sprout tiles; caption word e.g. `Good` |
| energy | 5-level ordinal | single | bolt tiles; caption e.g. `Charged` |
| focus | 5-level ordinal | single | target tiles; caption e.g. `Present` |
| sleep | 5-word scale `Low · Flat · Good · Okay · Great` | single | chips (no hours value) |
| medication | one of the user's meds — `Concerta · Ritalin · Elvense` | single | chips |
| dose | strength — `60mg · 18mg · 27mg · 36mg` | single (presumed) | chips, label "<Med> Dose" |
| dose status | `Missed · Taken` | one of two (presumed) | chips in the same row |
| emotions (pleasant) | 10 labels (4.1) | multi | chips |
| emotions (unpleasant) | 10 labels | multi | chips |
| side effects | 15 labels | multi (3 selected) | chips |

Caption vocabulary visible: mood `Good`, energy `Charged`, focus `Present`. Not on this screen: `Great/Okay/Flat/Low` as captions, `Alert/Tired/Steady`, `Sharp/Distracted/Locked In`, `Active/Kicking In` (medication phase), hours of sleep, timestamps other than date/time, month selector, percentages, counts.

---

## 7. Interactions implied

| Target | Size | Behaviour |
|---|---|---|
| Back pill | 42.6 circle (≥44 with slop) | pop to Check-In Details. No discard-changes prompt designed. |
| Date field / Time field | 166 × 39 | open a date / time picker (compact `DatePicker` or sheet — not designed) |
| Card header chevron | 29.167 circle (below 44 — needs an expanded hit area, or make the whole header row the target) | collapse/expand the card body; chevron presumably rotates to point down. Collapsed appearance not designed. |
| Level tile | 56 × 56 | single-select within its signal; border swaps to the signal's selected colour; caption updates |
| Sleep chip | h 27 (below 44 — needs vertical slop) | single-select |
| Medication chip | h 27 | single-select; should retitle "<Med> Dose" and swap the dose list |
| Dose chip | h 27 | single-select; Missed/Taken toggles status |
| Emotion / side-effect chip | h 27 | multi-select toggle outline ↔ solid |
| Chip rows (dose, pleasant, unpleasant, side effects, possibly sleep) | — | **horizontal scroll** (clipped rows); vertical page scroll elsewhere |
| Whole screen | — | vertical scroll, ≈515 pt beyond an 874 viewport |
| Save Changes | 344 × 44 | persist edits and pop. Always enabled in the file (no disabled/dirty state shown). |

---

## 8. Open questions for the owner

1. **Push or sheet?** The back chevron says push from Check-In Details; if this is a sheet it needs Cancel/Done and a grabber. Where does an unsaved edit go on back?
2. **Are the four cards really collapsible?** Every card shows an expanded chevron and no collapsed state exists in the file. If yes: does collapse persist between visits, and can "How Did You Feel?" collapse at all?
3. **Chip rows: scroll or wrap on device?** The pen shows single clipped rows (scroll); the Figma conversion wraps; SF metrics will differ from Inter again. Horizontal scroll hides 6 of 10 emotions and 11 of 15 side effects — is that acceptable for an edit form?
4. **Sleep model:** 5-word chips, the Frame 12 moon glyph, or hours? And is the intended order Low · Flat · Okay · Good · Great?
5. **Dose model:** per-medication strength lists (Concerta 18/27/36/54; Elvanse 20–70) with a separate Taken/Missed status, or free text? Should the label follow the selected med?
6. **Caption vocabulary:** full 5-word ladders per signal (mood/energy/focus) for tiles 1–5 — the file only shows one word each, and each mismatches its selected tile.
7. **Selected-tile border colour:** per signal (green / salmon / amber as drawn) or per level?
8. **Save semantics:** enabled only when dirty? Validation for future date/time? Haptic? Return destination?
9. **Typography:** the pen file is set in **Inter**; CLAUDE.md mandates native **SF**. Confirm the mapping (18/600 → SF Semibold 18 etc.) and accept the resulting width changes.
10. **Token naming** for the 12 off-palette colours in 2.8 (`#193024`, `#292d32`, `#6f7f75`, `#1c1b1f`, `#e4ece4`, `#e5f7e5`, `#fbfffc`, `#183c28`, `#f3b09a`, `#f6cc8a`, `#000`@10 %, `#fff`).
11. **Canonical card style:** 344 w / 1 px `#e4ece4` / r 24 / inset 16 (card 1) vs 342 w / 0.5 px `#000`@10 % / r 24 (23) / inset 15 (cards 2–4)?
12. **Voice check-ins:** does Edit Check-In also cover transcript/summary edits, or only signals? Nothing here references the recording.
13. **Accessibility:** tiles carry no text (only Low/High end captions) — need per-level `accessibilityLabel`s; chips are 27 pt tall and the chevron 29 pt — hit targets below 44 pt need slop; glyphs are non-tintable colour art — Increase Contrast / dark mode not designed.
14. **Dark mode** and Dynamic Type — no variants in the file.
15. **Spelling:** confirm `Elvanse` (UK) vs `Vyvanse` (US) as the canonical brand string, and the trailing space in `mood `.
