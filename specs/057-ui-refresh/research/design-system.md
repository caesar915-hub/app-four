<!-- Created: 2026-09-27 22:06 (WEST) · Updated: 2026-09-27 22:06 (WEST) -->
# Design-system specification — pen file "untitled.pen", section "Design System & Components"

| | |
|---|---|
| Source of truth | `untitled.pen` (Pencil). Read through its exports only: PNG renders at 2x (`pen/named/`), HTML-lite with layer names + inline styles (`pen/ds-html-lite/`), Figma JSON of the same design (`figma/*.json`, `*.raw.json`). |
| Frames covered | Frame 2 Typography · Frame 3 Buttons · Frame 4 Navs · Frame 5 Color palettes · Frame 12 Glyphs · Frame 15 Design Components (bill-shape chips + Add Button). Semantic roles and screen-only components are derived from the 8 screen frames (iPhone 17 - 1/4/5/6/7/16/18/19). |
| Units | All numbers are **pt at 1x** from the JSON/HTML (screen frames are 402 pt wide). PNGs are 2x. Hex is lowercase as exported; alpha written `@0.10`. |
| Status | **Planning document. No Swift changes, no implementation.** Where the pen is ambiguous this file says so instead of guessing. Open questions are collected in §7. |
| Variables | The pen file defines **no variables**; every value below is a literal. The Figma copy carries four small collections ("Button Tokens", "Tiimo Colors", "Variable collection", "Squirl Tokens") which are reproduced in §1.6 for reference. |

Conventions used in this document: `filled`/`outlined`/`underline` are the pen's own button family names; "Bill-shape" is the pen's name for the chip; "Navigation" is the pen's name for the tab bar; signal level names follow the pen's asset names `low / flat / okay / good / great` (1→5).

---

## 1. Color

### 1.1 Palettes (Frame 5 "Color palettes")

Three ramps, 50→900, each drawn as a 160 × 56 swatch (r 12, stroke `#e9ebf8` 1) with two contrast pills: **black-text ratio** (large-text grade · small-text grade) and **white-text ratio**. The numbers below are exactly the ones printed on the swatches. Contrast is against `#000000` / `#ffffff` text, WCAG 2.x. "—" means no grade printed (fails).

#### Violet

| Token | Hex | RGB | Black text (large · small) | White text (large · small) |
|---|---|---|---|---|
| violet-50 | `#f4f0fb` | 244, 240, 251 | 18.70 AAA · AAA | 1.12 — |
| violet-100 | `#dbd0f1` | 219, 208, 241 | 14.30 AAA · AAA | 1.47 — |
| violet-200 | `#cabaeb` | 202, 186, 235 | 11.73 AAA · AAA | 1.79 — |
| violet-300 | `#b29ae2` | 178, 154, 226 | 8.61 AAA · AAA | 2.44 — |
| violet-400 | `#a386dc` | 163, 134, 220 | 7.00 AAA · AA | 3.00 — |
| violet-500 | `#8c68d3` | 140, 104, 211 | 5.04 AAA · AA | 4.17 AA · — |
| violet-600 | `#7f5fc0` | 127, 95, 192 | 4.30 AA · — | 4.88 AAA · AA |
| violet-700 | `#634a96` | 99, 74, 150 | 2.95 — | 7.12 AAA · AAA |
| violet-800 | `#4d3974` | 77, 57, 116 | 2.15 — | 9.75 AAA · AAA |
| violet-900 | `#3b2c59` | 59, 44, 89 | 1.69 — | 12.42 AAA · AAA |

#### Green

| Token | Hex | RGB | Black text (large · small) | White text (large · small) |
|---|---|---|---|---|
| green-50 | `#eaf4eb` | 234, 244, 235 | 18.64 AAA · AAA | 1.13 — |
| green-100 | `#bdddc0` | 189, 221, 192 | 14.27 AAA · AAA | 1.47 — |
| green-200 | `#9dcca2` | 157, 204, 162 | 11.59 AAA · AAA | 1.81 — |
| green-300 | `#70b577` | 112, 181, 119 | 8.56 AAA · AAA | 2.45 — |
| green-400 | `#55a75d` | 85, 167, 93 | 7.07 AAA · AA | 2.97 — |
| green-500 | `#2a9134` | 42, 145, 52 | 5.20 AAA · AA | 4.04 AA · — |
| green-600 | `#26842f` | 38, 132, 47 | 4.42 AA · — | 4.75 AAA · AA |
| green-700 | `#1e6725` | 30, 103, 37 | 3.02 — | 6.95 AAA · AA |
| green-800 | `#17501d` | 23, 80, 29 | 2.20 — | 9.54 AAA · AAA |
| green-900 | `#123d16` | 18, 61, 22 | 1.70 — | 12.32 AAA · AAA |

#### Neutral (pen names the column "Neutral", the tokens "grey-*")

| Token | Hex | RGB | Black text (large · small) | White text (large · small) |
|---|---|---|---|---|
| grey-50 | `#e9e9ea` | 233, 233, 234 | 17.31 AAA · AAA | 1.21 — |
| grey-100 | `#babbbd` | 186, 187, 189 | 10.93 AAA · AAA | 1.92 — |
| grey-200 | `#999b9d` | 153, 155, 157 | 7.53 AAA · AAA | 2.79 — |
| grey-300 | `#6a6d70` | 106, 109, 112 | 4.03 AA · — | 5.21 AAA · AA |
| grey-400 | `#4d5154` | 77, 81, 84 | 2.62 — | 8.01 AAA · AAA |
| grey-500 | `#212529` | 33, 37, 41 | 1.36 — | 15.43 AAA · AAA |
| grey-600 | `#1e2225` | 30, 34, 37 | 1.31 — | 16.02 AAA · AAA |
| grey-700 | `#171a1d` | 23, 26, 29 | 1.20 — | 17.47 AAA · AAA |
| grey-800 | `#121417` | 18, 20, 23 | 1.14 — | 18.45 AAA · AAA |
| grey-900 | `#0e1011` | 14, 16, 17 | 1.10 — | 19.08 AAA · AAA |

Contrast consequences worth stating now, before tokens are written:
- `green-500 #2a9134` with white text is **4.04 — AA for large text only** (≥18 pt regular / 14 pt bold). Every filled button, active tab pill and selected chip in the screens puts **12–16 pt / 500** white text on it. That is below AA for normal text. Same for `violet-500 #8c68d3` (4.17).
- `grey-300 #6a6d70` is the caption grey (4.03 on white — AA large only) and it is used at 11–12 pt throughout Insights and Settings.
- These are design decisions for the owner, not errors in this document (see §7).

### 1.2 Semantic roles (derived from the 8 screens)

| Role | Hex | Palette token | Where it is used |
|---|---|---|---|
| Screen background | `#fbfffc` | — (off-palette; Figma "Variable collection / BG_Color") | Every screen frame fill. Very faintly green white. |
| Card surface | `#ffffff` | — (Figma "Tiimo Colors / surface/card") | All cards, tab bar, chips (outline), pills. |
| Card hairline | `#000000@0.10` at 0.5 pt | — | Card borders on day-details, insights, settings, mood-journal, listening card. |
| Card hairline (alt) | `#e4ece4` at 1 pt | — | Edit-check-in "How Did You Feel?" card, nav back/ellipsis pills, outline chips, expand chevron pills. |
| Row separator | `#000000@0.10` at 1 pt | — | `Line` nodes inside cards (settings rows, medication bar, transcript card, insights cards). |
| Ink — page title / brand green | `#17501d` | green-800 | Page titles 34/600, nav titles 18/600, "How's Your Mode?" 24/500, timer 72/500, mood word "Great", "Concerta · 36 mg", selected calendar day disc. |
| Ink — primary | `#212529` | grey-500 | Section titles 16/600, settings row titles 14/500, times "18:30", dates "Aug 30", body chips text on insights. |
| Ink — primary (variants) | `#1e2225` · `#292d32` · `#1c1b1f` · `#193024` | grey-600 · — · — · — | `#1e2225` day-details labels and transcript body; `#292d32` row labels on edit/insights/settings (14/500, 14/600); `#1c1b1f` bubble-chart labels and date-field labels; `#193024` chip text (all outline chips) and "70%". Four near-identical inks — see §7. |
| Ink — secondary | `#4d5154` | grey-400 | Captions 12/500 (medication name, "24 check-ins", weekday letters, previous-day signal words, toggle row labels 14/500), "03:24" 9/600. |
| Ink — tertiary | `#6a6d70` | grey-300 | Subtitles 16/500 and 14/400, captions 12/400–12/500, rhythm captions 11/500, unselected segment labels. |
| Ink — tertiary (green-grey) | `#6f7f75` | — | Nav subtitles "Monday, Jun 29", "Saturday, Sept 11", helper lines "A few Words Is Enough", "Low / High" 12/400, date-field icons. |
| Ink — placeholder | `#8a8a8e` | — | "Written by on-device AI…" 12/400, rhythm "—" 11/400. |
| Calendar strip greys | `#717680` (day names) · `#414651` (numbers) | — | Week strip only. |
| Primary action green | `#2a9134` | green-500 | Filled buttons, active tab pill, selected chips, toggles ON, radio ON, status "Active / Kicking In / Installed", signal status 12/600, mood row bar, "Good / Charged / Present" values. |
| Primary action pressed / hovered | `#1e6725` | green-700 | Button "Hovered" state; back-chevron and ellipsis glyphs; selected segment label; mood word "Okey". |
| Primary action focused / deepest | `#17501d` | green-800 | Button "Focused" state fill. |
| Outlined button ink | `#26842f` | green-600 | Outlined/underline label + focused stroke; "Write Notes", "Cancel"; expand chevron stroke. |
| Title green (headings) | `#17501d` | green-800 | see Ink — page title. |
| Selected chip | fill + stroke `#2a9134`, text `#ffffff` | green-500 | Emotion / dose / side-effect / sleep / prompt-length / blocked-for chips. |
| FAB violet | `#8c68d3` | violet-500 | Add Button 50 × 50, waveform played bars, play button, medication bar gradient end. |
| Medication violet (glyph) | `#4d3974` | violet-800 | Capsule icon inside its tile, unlock icon. |
| Medication violet (tint) | `#f4f0fb` | violet-50 | Capsule tile 26/28 px, locked-connection tile, medication preview row in Settings. |
| Medication violet (unlocked tile) | `#e3d8f9` | — | Unlocked connection tile. |
| Connection title violet | `#7f5fc0` | violet-600 | "MEDICATION × FOCUS" 12/600 uppercase, lock icon, AI sparkle. |
| Medication bar gradient | `#8061bf → #8c68d3` (0° → horizontal) | — → violet-500 | Progress fill of medication bars and connection bar. |
| Success / installed | `#2a9134` dot 8 × 8 + text 12/500 `#2a9134` | green-500 | Settings "Installed". |
| Destructive | **none drawn.** No red button, no delete state anywhere in the 8 screens. | — | The only reds are mood-level colours (`#842626`, `#bc4749`, `#f4dddd`). |
| Tab bar active fill | `#2a9134` pill on `#ffffff` bar | green-500 | Navigation. |
| Tab bar inactive icon | `#999b9d` | grey-200 | Navigation. |
| Disabled (buttons) | fill `#e5e7eb`, text `#9ca3af` (filled); fill `#f8fafc`, stroke `#e2e8f0`, text `#94a3b8` (outlined/underline) | — (Tailwind slate/gray) | Frame 3 only; no disabled control appears on a screen. |
| Toggle OFF | `#babbbd` | grey-100 | Settings. |
| Empty-state stroke | `#dbddde` 1 pt · `#8e8e93@0.30` 1.33 pt | — | Rhythm empty tile / weekday empty circle. |
| Shadow colour | `#183c28` (green-black) at 0.06–0.16; `#000000` at 0.07–0.17 | — | see §3.3. |
| Focus ring (design only) | `#93c5fd` | — | Figma "Button Tokens / focus/ring". Drawn as a 0-blur 0-spread shadow, so it renders invisible. |

### 1.3 Signal ramps (Frame 12 "Glyphs" + screens)

Each glyph is a 64 × 64 frame in Frame 12, drawn as **filled multi-colour vector paths** (not tintable, not an icon component). Five levels, left → right = `low, flat, okay, good, great`. On screens the same assets are placed at 33.55 (level pickers, weekday rows), 23–24 (inline signal words), ≈24 in 44 tiles (rhythm matrix), 14–16 (section headers).

#### Mood — sprout (colour changes per level, shape constant)

| Level | Leaf A (left) | Leaf B (right) + stem stroke 3 pt | Vein stroke 2.3 pt |
|---|---|---|---|
| 1 low | `#d97773` | `#bc4749` | `#eeb4aa` |
| 2 flat | `#e8b964` | `#c58b37` | `#f6dca6` |
| 3 okay | `#b1c194` | `#82936b` | `#d9e2c6` |
| 4 good | `#75ba4f` | `#2a9134` | `#b7dc88` |
| 5 great | `#428d52` | `#175723` | `#9ccaa0` |

Geometry (64-box): stem = open path 23.7 × 28.2 at (21.4, 26.8), stroke 3 round; leaf A 21.64 × 22.51 at (9, 13); leaf B 21.55 × 22.46 at (33.58, 17.5); veins 9 × 9.1 and 9.5 × 9.6.

**Inconsistency:** on screens the "Great" sprout in avatars and section headers is drawn with `#4caf50` / `#388e3c` (Material greens), not the Frame 12 `#428d52` / `#175723`. Two different "great" sprouts exist.

#### Energy — bolt (colour constant, fill height changes)

| Level | Filled portion (mask height of a 55–56 pt clip) | % |
|---|---|---|
| 1 low | 16.8 | 30 % |
| 2 flat | 26.6 | 48 % |
| 3 okay | 36.4 | 65 % |
| 4 good | 46.2 | 83 % |
| 5 great | 56.0 | 100 % |

Colours: base bolt `#f8e4c7` (pale), filled bolt `#d98232` (dark amber) with highlight `#eda94a` (28.86 × 27 top-left facet). Bolt path 35.78 × 47.52 at (14.34, 9). The fill rises from the bottom.

**Export artefact / open question:** the rising fill is a "Clip path group" whose mask is exported as a **solid black rectangle** (`asset-energy-*-fill`, fill `#000000`, 64 wide). The PNG render shows a literal black block behind the bolt, and the same black block appears on the *screens* (mood journal "Alert", Insights weekday row, level pickers). Either the pen intends a black tile behind the bolt, or the mask failed to export. **Owner must confirm before assets are cut.** The `black block` counts for 35 of the `#000000` fills in the histogram.

#### Focus — target ring + arrow (blue ring progression, amber arrow constant)

| Level | Blue arc `#4278a8` on base ring `#d6e5f0` (43.5 ⌀) |
|---|---|
| 1 low | short arc, top-right quadrant (20.69 × 16.73) + 2 round caps 5.5 |
| 2 flat | right half (21.75 × 39.35) + caps |
| 3 okay | ≈ three quarters (34.53 × 43.5) + caps |
| 4 good | full ring + caps still drawn |
| 5 great | full ring, no caps |

Constant parts: inner disc 22.5 ⌀ `#8ab8d6` at (16.75, 24.75); arrow `#eda94a` 24.68 × 24.68 diagonal from centre to top-right, arrowhead 12.38 × 11.14, two 4.5 dots. Text colour used for focus values on screens: `#447097` ("Sharp") and `#4278a8` ("Mostly Sharp").

#### Sleep — crescent moon + star (violet moon fill rises, amber star fill rises)

| Level | Moon mask height (of 56) | Star mask height (of ≈54.5) |
|---|---|---|
| 1 low | 16.8 | 40.74 |
| 2 flat | 26.6 | 44.18 |
| 3 okay | 36.4 | 47.62 |
| 4 good | 46.2 | 51.06 |
| 5 great | 56.0 | 54.5 |

Colours: moon base `#e3d7f3`, moon fill `#8c68d3` with highlight `#bca5e8` (42.8 × 40.39); star base `#f8e4c7`, star fill `#eda94a` (17 × 17.2 at (38.5, 9.5)). Moon path 44.9 × 46.84 at (9, 8.6). Same black-block mask artefact as Energy (the whole row renders as black tiles with a violet crescent peeking out). On screens the sleep glyph appears once, as "8h Sleep" in previous-day cards, and there it *is* a black square with a star.

#### Level words used on screens (not in the pen as a table — collected from copy)

| Signal | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Mood (bubble legend / range bar) | Low | Flat | Okay (also "Okey") | Good | Great |
| Energy (range bar labels, as drawn) | Steady | Alert | Tired | Good | Great — **the pen mixes energy words with mood words** |
| Energy (words used elsewhere) | Tired · Steady · Alert · Charged | | | | |
| Focus (range bar labels, as drawn) | Low | Flat | Okay | Good | Great — **mood words reused** |
| Focus (words used elsewhere) | Distracted · Present · Sharp · Locked In | | | | |

### 1.4 Level colours as used in charts, cards and text

| Level | Bubble / range-bar / legend colour | Mood word colour | Avatar tint (44 ⌀) | Day-card fill · stroke@0.50 (0.5 pt) | Level-picker selected ring |
|---|---|---|---|---|---|
| 1 low | `#da7a2a` | `#842626` ("Low") | `#f4dddd` | `#fffdfd` · `#f3b09a` | `#f3b09a` (energy tile 1) |
| 2 flat | `#eda94a` | `#da7a2a` ("Flat") | `#fee8d1` | `#fefdfa` · `#f6cc8a` | `#f6cc8a` (focus tile 2) |
| 3 okay | `#9dcca2` (green-200) | `#1e6725` ("Okey") | `#e5f7e5` | — not drawn | — |
| 4 good | `#55a75d` (green-400) | — not drawn as a word colour | — | — | — |
| 5 great | `#2a9134` (green-500) | `#17501d` ("Great") | `#ddf4de` | `#f8fffc` · `#abbba3` | `#70b577` (mood tile 5, green-300) |

Other tints: expanded day-card header `#e6f5ee` (radii 24/24/0/0); check-in ring interior `#ebf8ee` with ring `#bdddc0`; rhythm tiles — mood Okay `#ddf4de@0.20`, Good `#9dcca2@0.20`, Great `#9dcca2@0.30`; energy Steady `#fdf6eb`, Alert `#eda94a@0.30`, Tired `#c79043@0.20`; focus Sharp `#4278a8@0.10`, Present `#72a3ff@0.08`. Day-details signal values: mood `#0e7718` text + bar `#2e8b57` (Figma "Squirl Tokens / color/mood/base-5"); focus `#447097`; energy `#e38400` text + bar.

**Ambiguity (level-picker ring):** the three selected tiles on the edit screen are level 5 (mood, green), level 1 (energy, coral) and level 2 (focus, amber). The ring colours match the *level* tints in the table above exactly, not the *signal* colours (amber for energy, blue for focus). The pen is consistent with "ring colour = level colour". The brief's assumption "selection ring per signal colour" is not what is drawn. Owner decision.

### 1.5 Colours used on screens that are NOT in the three palettes

Every hex from the 8-screen fill histogram that is absent from Frame 5, grouped. Counts in parentheses are histogram counts.

- **Inks:** `#193024` (59) chip text · `#292d32` (26) row labels · `#1c1b1f` (10) · `#6f7f75` (12) · `#717680` (7) · `#414651` (6) · `#8a8a8e` (4) · `#303030` (15, status bar + home indicator on the edit screen only — the other screens use `#212529`).
- **Backgrounds / tints:** `#fbfffc` (8) screen bg · `#fafafa` (20) segment track, bar tracks · `#e5f7e5` (16) tile stroke + Okey avatar · `#ddf4de`, `#e6f5ee`, `#ebf8ee`, `#f8fffc`, `#fffdfd`, `#fefdfa`, `#fee8d1`, `#f4dddd`, `#fdf6eb`, `#e3d8f9`, `#e4ece4` (hairline), `#abbba3`, `#f3b09a`, `#f6cc8a`, `#c79043`, `#72a3ff`, `#dbddde`, `#d9d9d9` (chip dot), `#8e8e93`.
- **Energy / amber family:** `#eda94a` (116 — the single most used chromatic colour after green) · `#d98232` (19) · `#f8e4c7` (13) · `#e38400` (3) · `#da7a2a` (6) · `#f0cf9e` (9), `#ff9522` (6), `#dd7917` (6) — the last three are the medication "pill" icon on previous-day cards.
- **Focus / blue family:** `#4278a8` (57) · `#8ab8d6` (20) · `#d6e5f0` (20) · `#447097` (10).
- **Mood sprout family:** `#d97773`, `#bc4749`, `#e8b964`, `#c58b37`, `#b1c194`, `#82936b`, `#75ba4f`, `#428d52`, `#175723`, plus `#4caf50`, `#388e3c` (screens' "great" sprout) and `#0e7718`, `#2e8b57`, `#842626`.
- **Violet extras:** `#8061bf` (gradient start) · `#bca5e8`, `#e3d7f3` (moon).
- **Button-token greys (Tailwind):** `#e5e7eb`, `#9ca3af`, `#cbd5e1`, `#e2e8f0`, `#f8fafc`, `#94a3b8`, `#93c5fd`, `#e2e5ec`, `#f0f1f6`, `#fbfbfd` (Frame 2/3 furniture and outlined-button strokes on screens).
- **Shadow:** `#183c28`.
- **Present in the histogram but NOT found in any export JSON:** `#34c759`, `#ffd60a`, `#83f00d`, `#ebebf5@30%`. These are iOS system colours (system green, system yellow, separator); they most likely belong to the status-bar/toggle library components in the pen. They are not part of the design language. Note the toggles on Settings are drawn in brand green `#2a9134`, **not** system green `#34c759`.

### 1.6 Figma variables that came with the design (for reference only — the pen has none)

- **Button Tokens:** radius/pill 999 · small: padding-x 14, padding-y 8, gap 8, font 14/line 20 · medium: 18/10/8, 16/24 · large: 24/12/10, 18/28 · stroke 1 · filled/background/disabled `#E5E7EB` · filled/content default|hovered|focused `#FFFFFF`, disabled `#9CA3AF` · outlined/background default `#FFFFFF`, hovered `#F8FAFC`, focused `#FFFFFF`, disabled `#F8FAFC` · outlined/border default `#CBD5E1`, disabled `#E2E8F0` · outlined/content default `#111827`, disabled `#94A3B8` · underline/content/disabled `#94A3B8` · focus/ring `#93C5FD`.
  Note: the variable says outlined content `#111827`, but every outlined button in Frame 3 and on screens uses `#26842f`. The literal wins.
- **Tiimo Colors:** surface/card `#FFFFFF` (dark `#1C1E19`) · radius/card 20. Note: cards in the screens use r 24 / 18 / 12, never 20 (20 is only the level-picker tile).
- **Variable collection:** BG_Color `#FBFFFC`.
- **Squirl Tokens:** color/mood/base-5 `#2E8B57` (light + dark).
- **No dark-mode values exist** anywhere except `#1C1E19` above.

---

## 2. Typography

### 2.1 Family — an owner decision, not made here

The pen sets **Inter** on every text node (HTML: `font-family: Inter, system-ui, sans-serif`, loaded from Google Fonts at weights 100–900). The app's standing rule (DESIGN.md §typography, spec 023, 2026-06-26) is **native SF app-wide, no bundled faces, no `UIAppFonts`**. Adopting the pen literally means bundling Inter and re-adding `UIAppFonts`. Options: (a) bundle Inter; (b) keep SF and map the ramp 1:1 (SF Pro Text/Display at the same sizes and weights — Inter and SF have very close metrics, so layouts hold); (c) SF with `.rounded`? — not what is drawn. **Record as a decision to make; this document does not decide it.** Everything below is written as size/weight so it survives either choice.

One node family reads `mixed` in the export (the calendar week strip: "Tue / 7" etc.). It is probably an SF or system-font instance pasted from a UI kit. Flag.

### 2.2 The size × weight matrix (Frame 2 "Typography")

Sizes **12 · 14 · 16 · 18 · 20 · 22 · 24 · 26 · 28 · 30 · 32 · 34 · 36 · 38 · 40 pt**, each in **Regular 400 · Medium 500 · Semi Bold 600 · Bold 700**. Sample string "Ag · Interface", colour `#12151d`, line-height auto, letter-spacing 0. Frame furniture: header row `#f0f1f6` with labels 20 pt (Size 700, Regular 400, Medium 500, Semi Bold 600, Bold 700; colour `#4b5060`, letter-spacing 0.6); size labels 13/600 `#626877`; rows alternate `#ffffff` / `#fbfbfd`; hairlines `#e2e5ec` 0.889; section r 20.

Slip in the pen: the cell labelled "36 pt Bold" is actually set at **38/700**.

Line-heights are auto everywhere in screens except buttons (20/24/28 from Button Tokens) and the calendar strip (18).

### 2.3 Role ramp actually used on screens

Counts are text nodes across the 8 screens (from the text-style histogram: Inter|12|500 ×155, 14|500 ×40, 16|600 ×30, 12|400 ×28, 12|600 ×27, 14|600 ×15, 16|500 ×11, 11|500 ×9, 40|500 ×6, 18|600 ×5, 34|600 ×5, 14|400 ×4, 11|400 ×3, 20|600 ×1, 24|500 ×1, 13|400 ×1, 9|600 ×1, 72|500 ×1, 69.7|500 ×1). The 40/500 ×6 and 69.7/500 ×1 are the DS frame banners, not app text.

| Role | Size / weight | Colour | Examples (verbatim) |
|---|---|---|---|
| Page title | 34 / 600 | `#17501d` | "Insights", "Settings", "How Do You Feel?", "Check-In Saved" |
| Page subtitle | 16 / 500 | `#6a6d70` (`#1e2225` under "How Do You Feel?") | "Your Month At Glance", "Make The App Works For You", "Take A Moment To Check In With Yourself" |
| Nav-bar title | 18 / 600 | `#17501d` | "Today's Mood", "Edit Check-In" |
| Nav-bar subtitle | 12 / 500 | `#6f7f75` | "Monday, Jun 29 ", "Saturday, Sept 11" |
| Prompt title (card) | 24 / 500 | `#17501d` | "How's Your Mode?" |
| Prompt subtitle | 12 / 500 | `#6a6d70` | "Heavy, Light, Flat, Bright- Whatever Fits" |
| Screen question | 20 / 600 | `#212529` | "How Does It Feels Today?" |
| Section title | 16 / 600 | `#212529` (edit screen: `#193024`) | "Your Medications", "Previous Days", "Connections", "Date & Time", "Medication" |
| Card title (previous day) | 16 / 600 | mood colour + `#212529` | "Great" + "Aug 30" |
| Card subtitle | 14 / 400 | `#6a6d70` | "Average Across Weekdays In July", "Squirl follows the iOS motion setting…" |
| Row label | 14 / 500 | `#292d32` (edit, insights) · `#212529` (settings) · `#1e2225` (day-details) | "mood ", "Energy Level", "Voice Transcription", "Mood" |
| Row title strong | 14 / 600 | `#292d32` · `#171a1d` (times) | "Voice Prompts", "Dose Guard" options, "09:54" |
| Entry title (journal) | 14 / 600 | mood colour | "Great", "Low", "Okey", "Okay • Fri 08" |
| Body / transcript | 12 / 400 | `#1e2225` | "Took my Concerta around nine…" |
| Body emphasised | 12 / 500 | `#212529` | connection body, journal signal words |
| Caption | 12 / 500 | `#4d5154` · `#6a6d70` | "Concerta 36 mg", "24 check-ins", helper text under toggles |
| Caption quiet | 12 / 400 | `#6a6d70` · `#6f7f75` · `#8a8a8e` | range labels, "Low"/"High", "Written by on-device AI…" |
| Label (chip) | 12 / 500 | `#193024` / `#ffffff` selected | all Bill-shape chips |
| Status / value | 12 / 600 | `#2a9134` · signal colour (`#e38400`, `#4278a8`, `#447097`, `#0e7718`) · `#7f5fc0` (uppercase connection titles) | "Active", "Charged", "Mostly Sharp", "MEDICATION × FOCUS" |
| Micro | 11 / 500 `#6a6d70` · 11 / 400 `#8a8a8e` · 9 / 600 `#4d5154` | | rhythm captions, "—", "03:24" |
| Button label | 16 / 500 (medium) · 14 / 500 (small) · 18 / 500 (large) | `#ffffff` filled · `#26842f` outlined · `#634a96` on "Log Medications" | "Speak Check-In", "Save Changes" |
| Tab label | 12 / 500 | `#ffffff` | "Calendar", "Check In", "Insights", "Settings" |
| Timer | 72 / 500 | `#17501d` | "0:07" |
| Bubble value / word | 14 / 500 + 12 / 500 | `#1c1b1f` (`#ffffff` on Great) | "33%" "Okay" |
| Calendar strip | 12 / 500 lh 18 `#717680` · 12 / 600 lh 18 `#414651` (`#ffffff` selected) | family "mixed" | "Tue" "7" |
| Segment label | 12 / 500 `#1e6725` selected · 12 / 400 `#6a6d70` | | "July 2026" |

Observations: hierarchy is carried by weight and colour, not size — there are only four sizes above 16 in the whole app (18, 20, 24, 34) plus the 72 timer. 12/500 is 155 of ~400 text nodes: the app is set very small. Text case is Title Case in almost every sentence ("Take A Moment To Check In With Yourself", "A Moment For Yourself, Captured.") — a copy decision to make.

---

## 3. Spacing, radii, elevation

### 3.1 Grid and gutters

- Screen frame **402 × 874** (iPhone 17 artboard), corner r 32 on the frame (device mask, not UI).
- Content left edge **x = 28–31**; content width **340–344**; right gutter 28–31. There is no single gutter: nav-bar container 340 @ x 31; cards 342 @ x 30 (mood journal, check-in), 344 @ x 28/29 (day-details, insights, settings, edit); tab bar 346 @ x 28. Treat as **gutter 28 (outer) / 30 (cards)** and flag the 1–3 pt drift as pen noise.
- Nav-bar/back-pill row at **y = 74–77**, height 43. Page-title block at y 74, height 63 (title 34 + subtitle 16 + gap ≈ 4).
- First content card at y 143–159 (i.e. ≈ 26 below the nav row / 22 below the page-title block).
- Section title → card: 12–13 (e.g. "Previous Days" 1185→card 1214 at 2x = 14 pt at 1x). Card → next section title: ≈ 24. Card → card in a stack: 24 (insights), 20 (edit), 16 (settings groups), 8 (previous-day cards).
- Card inner padding: **15** (insights, edit, settings, medication bar, expanded header) but **11** on day-details and journal rows. Two values coexist.
- Chip row: gap **6** horizontal, **6** vertical (27-high chips on a 33 pitch).
- Level-picker tiles: 56 on a **64 pitch** (gap 8).
- Tab bar bottom edge at y 839 (5 above the home-indicator zone), FAB vertically centred on the bar.

### 3.2 Radii

| Element | Radius |
|---|---|
| Buttons (all families), chips on Frame 3 | 999 (pill) |
| Bill-shape chip | 15 (pill for a 27-high chip) |
| Tab bar container | 75 (pill for 60 high) |
| Tab bar active pill | 44 (pill for 44 high) |
| Add Button | 75 (circle, 50 ⌀) |
| Nav back / ellipsis pill | 21.3 (circle, 43 ⌀); 11.3–12 for the 23–24 ⌀ row versions |
| Card L | 24 |
| Card M | 18 |
| Card S / row card / day card | 12 |
| Expanded day-card header | 24 / 24 / 0 / 0 |
| Level-picker tile | 20 |
| Date/time field | 12 |
| Medication tile (capsule) | 13–14 (circle, 26–28 ⌀); connection icon tile 11 (42 sq) |
| Segmented track / thumb | 19 / 15 |
| Progress bars | 9.5 (10 high), 2 (4 high), 52 on one 4-high fill (pen noise) |
| Rhythm tile, avatar | 22 (44 ⌀) / 35 (44 ⌀ — over-specified) |
| Check-in ring | 173.5 (347 ⌀) / 105.5 (211 ⌀) |
| Toggle track | pill (379 / 468 as exported) |
| Selected calendar day | 9999 (32 ⌀) |

### 3.3 Elevation (shadows, from the HTML `box-shadow` and JSON effects)

| Level | Value | Used on |
|---|---|---|
| Card / low | `0 3 8 #183c28@0.08` | Insights cards, settings cards, medication bar, day cards, connection cards |
| Card / raised | `0 4 8 #183c28@0.08` | Day-details cards, edit-screen cards, listening prompt card |
| Field | `0 2 8 #183c28@0.08` | Date / time fields |
| Chip (emotion, day-details only) | `0 7 6 #183c28@0.06` | "Proud", "Excited" chips |
| Tab bar | `0 8 24 #183c28@0.16` (HTML: `0 8 21 #183c2829`) | Navigation |
| FAB | `0 7 17 #000000@0.17` (HTML: `0 7 14.875 #0000002b`) | Add Button |
| Check-in ring | `0 2 18 #000000@0.08` (saved: `0 1.22 10.95`) | Ring group |
| Segment thumb | `0 1 3 #193024@0.07` | Insights month selector |
| Toggle knob | `0 0.94 1.88 #000000@0.15` (small: `0 0.76 1.52`) | iOS-style toggles |
| Focus ring (invisible) | `0 0 0 #93c5fd` | Frame 3 "Focused" state |

The whole system uses one shadow tint, `#183c28` (dark green-black), at 0.06–0.16 — except the FAB and ring which use pure black. Recommend one token.

### 3.4 Hairlines / strokes

| Stroke | Weight | Used on |
|---|---|---|
| `#000000@0.10` | 0.5 (cards) · 1 (separators, radio off, diagonal separators) · 0.25–0.75 (icon tiles, bar tracks) | most cards and all in-card dividers |
| `#e4ece4` | 1 (chips, edit card) · 0.6–1.065 (nav pills) | chips, pills |
| `#cbd5e1` | 1 | outlined buttons (default) |
| `#e5f7e5` | 1 | level-picker tile (unselected) |
| `#bdddc0` | 21.33 inside (347 ring) · 12.97 (211 ring) | check-in ring track |
| `#dbddde` / `#8e8e93@0.30` | 1 / 1.33 | empty tiles |
| `#1c1b1f@0.10` | 1 | date/time fields |
| `#000000@0.04` | 1 | segmented track |

---

## 4. Components

Each entry: anatomy · variants · states · metrics. Metrics are from the JSON; where a screen instance differs from the Frame 3/4/15 master, the screen value is listed as a variant.

### 4.1 Buttons (Frame 3 "Buttons")

Three families × three sizes × with/without leading icon × four states = 72 masters. Pill radius 999, label 500 weight, icon `vuesax/linear/user` as placeholder (16 pt on small/medium, 18 on large), stroke 1.5.

| Size | Height (filled / outlined) | Padding x / y | Gap | Font / line | Icon |
|---|---|---|---|---|---|
| Small | 36 / 38 | 14 / 8 | 8 | 14 / 20 | 16 |
| Medium | 44 / 46 | 18 / 10 | 8 | 16 / 24 | 16 |
| Large | 52 / 54 | 24 / 12 | 10 | 18 / 28 | 18 |

Outlined is 2 pt taller/wider because the 1 pt stroke is outside the padding box.

| Family / state | Fill | Stroke | Label + icon |
|---|---|---|---|
| Filled · Default | `#2a9134` | — | `#ffffff` |
| Filled · Hovered | `#1e6725` | — | `#ffffff` |
| Filled · Focused | `#17501d` + ring `#93c5fd` 0/0 | — | `#ffffff` |
| Filled · Disabled | `#e5e7eb` | — | `#9ca3af` |
| Outlined · Default | `#ffffff` | `#cbd5e1` 1 | `#26842f` / icon `#2a9134` |
| Outlined · Hovered | `#f8fafc` | `#2a9134` 1 | `#26842f` |
| Outlined · Focused | `#ffffff` | `#26842f` 1 + ring | `#26842f` |
| Outlined · Disabled | `#f8fafc` | `#e2e8f0` 1 | `#94a3b8` |
| Underline (text) · Default | — | — | `#26842f` |
| Underline · Hovered | — | — | `#1e6725` |
| Underline · Focused | — | — | `#17501d` + ring |
| Underline · Disabled | — | — | `#94a3b8` |

State mapping for iOS (proposal, not in pen): Hovered → pressed highlight, Focused → not applicable (no keyboard focus ring on iPhone), the darkest `#17501d` fill can double as "pressed" if a stronger press is wanted. The pen calls the third column "Focused", not "pressed-dark".

Screen instances:
- "Speak Check-In" — Filled Medium with icon (`vuesax/bold/microphone-2`), 182 × 44.
- "Log Medications" — Outlined Medium with icon, 191 × 46, **label `#634a96` (violet-700)** and capsule icon — a colour variant not in Frame 3.
- "Write Notes" — Outlined Medium with icon (`vuesax/bold/edit-2`), 155 × 46, label `#26842f`.
- "Stop & Save" — Filled Medium with icon (`vuesax/outline/stop` 16, white, r 4), 152 × 44.
- "Cancel" — Outlined Medium, 91 × 46.
- "Go Back Home" / "Save Changes" — Filled Medium, **full width** 342/344 × 44, label centred.
- No Large or Small instance appears on any screen.

### 4.2 Bill-shape chips (Frame 15)

Anatomy: pill 27 high, padding **5 / 15**, r 15, label 12/500. Three masters:

| Variant | Fill | Stroke | Label | Extra |
|---|---|---|---|---|
| `BG=outline` | `#ffffff` | `#e4ece4` 1 | `#193024` | — |
| `BG=solid` (selected) | `#2a9134` | `#2a9134` 1 | `#ffffff` | — |
| `BG=With Dot` | `#ffffff` | `#e4ece4` 1 | `#193024` | leading 8 × 8 circle `#d9d9d9`, gap 4 |

States drawn: only unselected/selected. No pressed, no disabled.

Screen variants:
- Insights legend: With-Dot at **25 high**, dot in level colour (`#da7a2a`, `#eda94a`, `#9dcca2`, `#55a75d`, `#2a9134`), label colour not set in export (renders dark).
- Day-details emotion chips: solid, **29 high, label 14/500**, shadow `0 7 6 #183c28@0.06` — the only elevated chips.
- Settings "Blocked For": selected chip carries a leading 15 × 15 white circle with a check (`Frame 1707479511`).
- Chip rows: horizontal gap 6, vertical gap 6. On the edit screen several rows are **clipped at the card edge** ("Missed | T…", "Serene | …", "App…"), i.e. the pen draws a horizontally scrolling row, while the Sleep row wraps. Wrap vs scroll is not decided in the pen.

### 4.3 Add Button (Frame 15)

50 × 50 circle, fill `#8c68d3`, shadow `0 7 17 #000000@0.17`. Glyph `vuesax/twotone/add` at 41 × 41: two 20.5-long strokes, `#e9e9ea`, weight 1.71 (HTML 1.826), round caps. No states drawn. On screens: x 324 (right gap 28), vertically centred on the tab bar (nav y 779 h 60 → FAB y 784 h 50); on Settings it floats **above** the bar at (337, 1745 − offset) because the bar there is full width.

### 4.4 Navs — tab bar (Frame 4 "Navs", component set "Navigation")

Container **346 × 60**, fill `#ffffff`, r 75, shadow `0 8 24 #183c28@0.16`. Four items in order **Calendar · Check In · Insights · Settings**.

- Active item: wrapper padding 8 / 15; inner pill fill `#2a9134`, r 44, padding **10 / 20**, gap 6, icon 24 (bold style, white) + label 12/500 white. Pill widths 122 / 121 / 116 / 118 × 44.
- Inactive item: padding 16.5 / 20.5, icon 24 `#999b9d`, no label.
- Icons: active `vuesax/bold/calendar`, `bold/task-square`, `bold/chart`, `bold/setting-2`; inactive `vuesax/outline/calendar`, `linear/task-square`, `outline/chart`, `twotone/setting-2` — three different inactive styles for four tabs (see §5).
- Four masters: `Status=Calendar|Check In|Insights|Settings, Mode=Light`. No dark mode drawn.

Screen variants:
- **Compact** (Day-details, Mood journal, Insights): bar **274 × 60** sharing the row with the Add Button; active pill is **icon-only 64 × 44** (padding 10/20, no label).
- **Full** (Settings): bar 346 × 60 with icon + label pill (118 × 44 "Settings"), Add Button floated above.
- Check-in flow screens (4/5/6) have **no tab bar** — they are pushed full-screen with a back pill.

### 4.5 Nav bar (screen header)

Container 340 × 43 at (31, 74–77). Left: **back pill** 43 × 43, fill `#ffffff`, stroke `#e4ece4` 1.065, r 21.3, icon `vuesax/outline/arrow-left` 20 fill `#1e6725`. Title 18/600 `#17501d` + subtitle 12/500 `#6f7f75`, 8 from the pill. Right: **ellipsis pill** 43 × 43 same style, icon `vuesax/outline/more` 25 with three 5.73 dots `#1e6725`. Variant without title (check-in flow): pill only. Variant page-title (Insights/Settings): no pills; 34/600 title + 16/500 subtitle at x 30–32.

### 4.6 Cards

| Variant | Size (typ.) | Fill | Stroke | Radius | Shadow | Where |
|---|---|---|---|---|---|---|
| L | 342–344 wide | `#ffffff` | `#000000@0.10` 0.5 (edit: `#e4ece4` 1) | 24 | 0 4 8 / 0 3 8 | insights, settings groups, edit sections, transcript |
| M | 344 × 80–167 | `#ffffff` | `#000000@0.10` 0.5 | 18 | 0 3 8 | connection cards, Voice & Storage, accessibility note, listening prompt (0 4 8) |
| S | 342–344 × 50–140 | `#ffffff` | `#000000@0.10` 0.5 | 12 | 0 3 8 | medication bar, "Your Medications" row, signal summary |
| Day (tinted) | 342 × 99 | `#f8fffc` / `#fffdfd` / `#fefdfa` | level tint @0.50, 0.5 | 12 | 0 3 8 | previous days |
| Expanded day | 342 × 266 | `#ffffff` | `#000000@0.10` 0.5 | 24 | 0 4 8 | header strip `#e6f5ee` 52 high, radii 24/24/0/0, padding 14/15 |

Inside a card: title 16/600 at the top-left, optional right-aligned caption 12/500 `#4d5154`; a 1 pt `#000000@0.10` line under the title when the card has rows (edit screen, settings).

### 4.7 Toggles (iOS-style, brand green)

| Size | Track | Knob | ON | OFF |
|---|---|---|---|---|
| Regular | 42 × 22.62, pill | 16.96 ⌀ `#ffffff`, shadow 0 0.94 1.88 `#000000@0.15` | `#2a9134` | `#babbbd` |
| Small | 34 × 18.31, pill | 13.73 ⌀ | `#2a9134` | `#babbbd` |

Not system `#34c759`. Two sizes coexist on one screen (Calendar Cards rows use small, Medication Bar rows use regular).

### 4.8 Radio (Dose Guard)

20 ⌀. Off: stroke `#000000@0.10` 1, no fill. On: stroke `#2a9134` **6**, white centre 8 ⌀. Row: title 14/600 `#292d32` + subtitle 12/500 `#6a6d70`, radio right-aligned at x 338.

### 4.9 Segmented pills (Insights month selector)

Track 344 × 38, fill `#fafafa`, stroke `#000000@0.04` 1, r 19. Three equal segments 109 × 30. Selected thumb `#ffffff`, r 15, shadow `0 1 3 #193024@0.07`, label 12/500 `#1e6725`; unselected 12/400 `#6a6d70`. Copy: "June 2026 · July 2026 · Aug 2026".

### 4.10 Progress / medication bars

| Bar | Track | Fill | Radius |
|---|---|---|---|
| Medication (bar card) | 320 × 10, `#fafafa`, stroke `#000000@0.10` 0.25 | gradient `#8061bf → #8c68d3` horizontal, 165 / 20 wide | 9.5 |
| Connection | 285 × 6, same | same gradient, 165 wide, caption "70%" 12/500 `#193024` (165/285 = 58 %, not 70 %) | 9.5 |
| Signal mini (day-details) | 86 × 4, `#e9e9ea` | mood `#2e8b57` 78, focus `#447097` 48, energy `#e38400` 21 | 2 |

Medication row: capsule tile 26 ⌀ `#f4f0fb` stroke `#000000@0.10` 0.42 with capsule vector 12.7 `#4d3974`; "09:54" 14/600 `#171a1d` · "•" · "Concerta 36 mg" 12/500 `#4d5154`; status right 12/600 `#2a9134` ("Active", "Kicking In"); rows separated by a 1 pt `#000000@0.10` line.

### 4.11 Check-in ring (Frames iPhone 17 - 4 / 5 / 6)

- **Idle / Listening:** group 347 ⌀, shadow `0 2 18 #000000@0.08`. Base disc fill `#ebf8ee` with inside stroke `#bdddc0` **21.33** (r 173.5). Arc: an `Ellipse 8` with linear gradient at 90° — `#26842f` 0 % → `#3fbb4b` 50 % → `#25832e` 100 % — masked to a sweep. **No `arcData` is exported**; visually the idle sweep runs from ≈ 3 o'clock clockwise to ≈ 7 o'clock (~⅓), the listening sweep from ≈ 10 o'clock clockwise through 6 to ≈ 3 o'clock (~⅝). Whether the arc is progress, a level meter or decoration is not specified.
- Inside idle: three stacked buttons (§4.1), gap 8. Inside listening: timer 72/500 `#17501d` + "Stop & Save" + "Cancel". Under the ring: helper 14/500 `#6f7f75` ("A few Words Is Enough", "Take Your Time, Speak Freely.").
- Listening prompt card: 342 × 98, r 18, title 24/500 `#17501d`, subtitle 12/500 `#6a6d70`, **pager dots** 5 × 7 ⌀ — active `#2a9134`, inactive `#bdddc0`.
- **Saved:** ring 211 ⌀, stroke 12.97, full gradient ring; centre **square** 96.95 × 96.95 fill `#2a9134` (no radius) with white check 49.7 × 37.3; below: 34/600 title + 14/500 `#1e2225` two-line body; "Go Back Home" full-width filled button.

### 4.12 Bubble chart ("Mood Check-In Breackdoen")

Five overlapping circles on one baseline band, left → right:

| Level | ⌀ | Fill | Label |
|---|---|---|---|
| Low | 70.76 | `#da7a2a` | "8%" / "Low" `#1c1b1f` |
| Flat | 84.15 | `#eda94a` | "17%" / "Flat" |
| Okay | 103.3 | `#9dcca2` | "33%" / "Okay" |
| Good | 98.49 | `#55a75d` | "29%" / "Good" |
| Great | 78.41 | `#2a9134` | "13%" / "Great" `#ffffff` |

Labels 14/500 + 12/500 centred. Diameters are ordered by share but **not area-proportional** (33 % → 103, 13 % → 78). Legend row of With-Dot chips (§4.2). Card title 16/600 + "24 check-ins" 12/500 `#4d5154`. Card 342 × 317, r 24.

### 4.13 Weekday glyph row ("Your month in three signals")

Row header: 14–16 signal icon + label 14/500 `#292d32`, right status 12/600 in signal colour ("Mostly Okay" `#2a9134`, "Mostly Steady" `#e38400`, "Mostly Sharp" `#4278a8`). Seven columns **44.57 × 52.55**: glyph 33.55 at top, weekday 12/500 `#4d5154` ("Mo Tu We Th Fr Sa Su") below. Empty day: 18 ⌀ circle stroke `#8e8e93@0.30` 1.33. Rows separated by 1 pt `#000000@0.10` lines. Copy bugs: energy row reads "Mo Tu We Fr Fr Sa Su".

### 4.14 Range bars ("Where you averaged")

Five segments **61 × 7**, r pill, gap ≈ 1.75, colours low→great `#da7a2a · #eda94a · #9dcca2 · #55a75d · #2a9134`; labels 12/400 `#6a6d70` under each; bracket = 1 pt `#000000@0.10` ⊓ over the averaged span; caption right 12/400 `#6a6d70` ("Between Okay & Good"). Same colours for every signal (no blue/amber ramp here).

### 4.15 Rhythm matrix ("Your Daily Rhythm")

Columns "MORNING · AFTERNOON · EVENING · LATE" 12/500 `#4d5154` (uppercase in copy, not via text-case). Row heads: glyph + 12/500 `#292d32`. Tiles **44 ⌀ r 22** with tinted fill (§1.4) and ≈24 glyph; caption 11/500 `#6a6d70` ("Okay", "Sharp"); empty tile stroke `#dbddde` 1 + "—" 11/400 `#8a8a8e`. Column "AFTERNOON" wraps to "AFTERNOO / N" at this width.

### 4.16 Connection cards (lock state)

Card M 344 × 104 (unlocked, with bar) / 80 (locked). Icon tile 42 × 42 r 11 stroke `#000000@0.10` 0.45: **unlocked** fill `#e3d8f9` + `vuesax/bold/unlock` 20 `#4d3974`; **locked** fill `#f4f0fb` + `vuesax/bold/lock` 20 `#7f5fc0`. Title 12/600 `#7f5fc0` uppercase ("MEDICATION × FOCUS"); body 12/500 `#212529`; unlocked card adds the 285 × 6 bar + "70%". Section header "Connections" 16/600 + "Patterns across signals — 3 or more days to unlock" 14/400 `#6a6d70`.

### 4.17 Settings rows

Group card L/M; rows 40–60 high; title 14/500 `#212529` (or 14/600 `#292d32` when a description follows), description 12/500 `#6a6d70`; 1 pt `#000000@0.10` separators inset 15. Trailing controls: toggle (§4.7), value 12/500 `#4d5154` ("34MB"), status dot 8 ⌀ `#2a9134` + 12/500 `#2a9134` ("Installed"), chevron `vuesax/twotone/arrow-right`. Leading icons 24: `vuesax/outline/voice-cricle`, `bold/record-circle`, cellular bars (custom vector), `bold/info-circle` (accessibility note). Sub-components: prompt-length chips (Bill-shape), medication preview row 314 × 40 `#f4f0fb` r 12 with capsule tile, radio group (§4.8), "Blocked For" chip group with check. Section headers 16/600 `#212529` sit ≈12 above their card.

### 4.18 Date / time fields

Label 12/500 `#1c1b1f` above (22 offset). Field **166 × 39**, fill `#ffffff`, stroke `#1c1b1f@0.10` 1, r 12, shadow `0 2 8 #183c28@0.08`. Leading icon 15 × 15 `#6f7f75` at (10, 12) — calendar / clock drawn as custom vectors, not vuesax instances. Value 12/600 `#193024` at x 32. Two fields side by side, gap 12.

### 4.19 Level pickers (edit check-in)

Row: label 14/500 `#292d32` left ("mood ", "Energy Level", "focus level" — inconsistent case), current value 12/600 `#2a9134` right ("Good", "Charged", "Present"). Five tiles **56 × 56 r 20**, stroke 1 `#e5f7e5`, glyph 33.55 inset 11.22, pitch 64. Selected: stroke 1 in the level tint (§1.4: `#70b577`, `#f3b09a`, `#f6cc8a`) — no fill change, no weight change. Under the row: "Low" left / "High" right 12/400 `#6f7f75`. Sleep uses a chip row instead of tiles ("Low Flat Good Okay Great" — order differs from every other ramp).

### 4.20 Chip groups

Titled group (14/500 `#292d32`, e.g. "Pleasant", "Concerta Dose") + rows of Bill-shape chips, gap 6/6, multi-select shown by several solid chips ("Excited" + "Frustrated"; "Headache" + "Rebound" + "Flat Affect"). Overflow behaviour undecided (§4.2).

### 4.21 Calendar week strip (mood journal)

Month title 14/600 `#212529` + chevron; seven columns; day names 12/500 lh 18 `#717680`; numbers 12/600 lh 18 `#414651`; selected day 32 ⌀ `#17501d` with white number; event dot 5 ⌀ `#55a75d` centred 6 below. Copy bug: "Tue Mon Wed Thur Fri Sat Sun" with "7 6 8 9 10 11 12".

### 4.22 Journal entry row and previous-day card

Avatar 44 ⌀ tinted (§1.4) with sprout 33.55; mood word 14/600 in mood colour + time 14/500 `#212529`; second line: energy glyph 23 + word, "•", focus glyph 24 + word, 12/500 `#212529`; trailing ellipsis pill 23 ⌀ (stroke `#e4ece4` 0.565, `more` 13) or chevron pill 24 ⌀ (`twotone/arrow-up` 13 stroke `#26842f` 1.41). Previous-day card: word 16/600 mood colour + date 16/600 `#212529`; signals 12/500 `#4d5154` incl. "8h Sleep" (black tile glyph); meds line: pill icon (`#ff9522` / `#dd7917` / `#f0cf9e`) + "Concerta 36mg".

### 4.23 Signal summary card (day-details) and transcript card

Summary: 344 × 113 r 12; three columns split by **diagonal** 81-long hairlines `#000000@0.10`; glyph ≈32, label 14/500 `#1e2225`, value 12/600 in signal colour, 86 × 4 bar (§4.10). Transcript: card L r 24; AI line = sparkle 13.6 × 16.4 `#7f5fc0` + 12/400 `#8a8a8e`; body 12/400 `#1e2225`; player: play 28 ⌀ `#8c68d3` (stroke `#000000@0.10` 0.75) with white triangle, waveform of 2-wide pill bars (played `#8c68d3`, unplayed `#eaf4eb`), duration 9/600 `#4d5154`.

---

## 5. Iconography

### 5.1 UI-chrome icon set and style

The library is **vuesax (Iconsax)**, ≈1,030 names in each of four styles: **Linear, Bold, Outline, Two line (twotone)** (`figma/icon-library-names.json`; note the "Outline" list also contains a "Bulk"/crypto/brand sub-list). Instances actually placed on screens:

| Icon | Style | Where |
|---|---|---|
| `arrow-left` | outline | back pill (5 screens) |
| `more` | outline | ellipsis pills |
| `arrow-up` | twotone | expand/collapse chevrons (9) |
| `arrow-right` | twotone | Settings disclosure |
| `add` | twotone | Add Button |
| `calendar` | bold (active tab) · outline (inactive) | tab bar |
| `task-square` | bold (active) · linear (inactive) | tab bar |
| `chart` | bold (active) · outline (inactive) | tab bar |
| `setting-2` | bold (active) · twotone (inactive) | tab bar |
| `microphone-2`, `edit-2` | bold | check-in buttons |
| `stop` | outline | Stop & Save |
| `lock`, `unlock` | bold | connection cards |
| `record-circle`, `info-circle` | bold | Settings |
| `voice-cricle` | outline | Settings |
| capsule, calendar/clock (fields), cellular bars, sparkle, play, check | custom vectors | various |

Summary: **active = Bold; everything else is a mix of Outline, Linear and Twotone with no rule**; the "user" placeholder in Frame 3 is Linear. A single inactive style must be chosen (Outline is the majority: arrow-left, more, calendar, chart, stop, voice-cricle). Stroke weights seen: 1.5 (linear/twotone), 1 (outline fills), 1.41 (chevrons). Sizes: 24 tab, 20 back/lock, 25 more, 16 button icon, 13 row chevrons.

### 5.2 Signal glyph set (Frame 12) — asset export notes

- Twenty assets, 4 signals × 5 levels, named `{energy|focus|mood|sleep}-{low|flat|okay|good|great}`, each a 64 × 64 frame of **plain vector paths** (`VECTOR` nodes) — **no icon components, no instances, not tintable**. Export as PDF/SVG at 64 and place at 33.55 / 24 / 23 / 16 / 14.
- Geometry per signal is in §1.3. Energy and Sleep depend on **clip masks** ("Clip path group" with an `asset-*-fill` rectangle). The masks exported as black rectangles; confirm intended appearance with the owner before cutting assets.
- Mood sprout is stroke + fill (stem 3 pt, veins 2.3 pt) — scaling to 14–16 pt will thin the strokes below 1 pt; a simplified small-size variant may be needed.
- Screens also use a fifth "sleep" representation (black square with star) and a medication pill icon (`#ff9522` family) that are not in Frame 12.

---

## 6. iOS chrome present in the pen that is NOT to be implemented

- **Status bar** `Status Bar` instance, 402 × 52: "9:41" 40 × 21 at (32, 18), signal/Wi-Fi/battery icons 69 × 14 at (301, 20), tint `#212529` (`#303030` on the edit screen). System-drawn; do not replicate.
- **Home indicator** `Home Indicator` instance, 402 × 34 at the bottom, bar 143 × 5 r 10 `#212529`/`#303030` at (129, 861). System-drawn; only its 34-pt safe-area inset matters (the tab bar sits 5 above it).
- **Device corner** radius 32 on every screen frame — the artboard mask, not UI.
- The four iOS system colours in the histogram (`#34c759`, `#ffd60a`, `#83f00d`, `#ebebf5@30%`) belong to these library components; ignore.

---

## 7. Inconsistencies, ambiguities and decisions for the owner

1. **Font family:** Inter (pen) vs native SF (app rule). Decision required; ramp is family-agnostic.
2. **Contrast:** white 12–16/500 text on `#2a9134` (4.04) and `#8c68d3` (4.17) fails AA for normal text; `#6a6d70` captions at 11–12 pt (4.03) likewise. Either accept (large-text-only AA) or shift primary to `#26842f`/`#1e6725` and captions to `#4d5154`.
3. **Energy/Sleep black block:** mask export artefact or intended black tile? It appears on the DS frame *and* on the screens. Blocks asset export.
4. **Two "great" sprouts:** Frame 12 `#428d52/#175723` vs screens `#4caf50/#388e3c`.
5. **Level-picker selection ring:** drawn per *level* tint, not per *signal* colour.
6. **Four primary inks** (`#212529`, `#1e2225`, `#292d32`, `#1c1b1f`) plus chip ink `#193024`; three hairline greys (`#000000@0.10`, `#e4ece4`, `#cbd5e1`); two card paddings (11 vs 15); three card radii (24/18/12) with the Figma variable saying 20. Token pass should collapse these.
7. **Tab bar:** two layouts (compact icon-only + FAB vs full with label + floating FAB); inactive icons in three styles.
8. **Range-bar labels** reuse mood words for energy and focus; "Sleep" chips ordered "Low Flat Good Okay Great"; "Okay"/"Okey" spelled both ways; "Breackdoen", "Claendar", "Vyvans", "Does" typos; weekday strip "Tue Mon Wed"; energy row "Fr Fr".
9. **Check-in ring arc:** meaning and sweep not parameterised (no `arcData`).
10. **Chip overflow:** scroll (clipped rows) vs wrap — both drawn.
11. **Connection bar** shows 58 % fill labelled "70%".
12. **Bubble sizes** not area-proportional.
13. **No dark mode, no disabled control, no destructive action, no error/empty states** are drawn anywhere. The app already ships dark mode; the pen gives no guidance.
14. **Figma variable** outlined content `#111827` contradicts every drawn outlined label (`#26842f`); "Log Medications" label uses violet `#634a96`.
15. **Toggles** use brand green `#2a9134`, not system green — intentional? (Owner rule: native feel.)
