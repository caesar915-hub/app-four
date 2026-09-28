<!-- Created: 2026-09-27 21:55 (WEST) · Updated: 2026-09-27 21:55 (WEST) -->
# Screen spec — Check-In Recording · A · Idle hub

| | |
|---|---|
| Pen node | `iIaeI` — frame **"iPhone 17 - 4"** (Figma id `72:16335`) |
| Label in file | Check-In Recording — A · idle hub (How Do You Feel? ring with Speak Check-In / Log Medications / Write Notes) |
| Siblings | B · listening = "iPhone 17 - 5" (`72:16377`) · C · saved = "iPhone 17 - 6" (`72:16419`) |
| Sources used | PNG `pen/named/iphone17-4-checkin-recording-a.png` (ground truth) · HTML `pen/html-lite/iPhone-17-4.html` · JSON `figma/iphone17-4.json` + `.raw.json` · DS frames 2/3/4/5/12/15 |
| Status | Planning only. No Swift changes. Numbers are pt at 1x from the JSON; PNG is 2x. |

---

## 1. Purpose and placement

**Purpose.** The resting state of the daily check-in. One question ("How Do You Feel?"), one primary action (speak), two quiet alternatives (log medications, write a note). It is the entry point of the three-screen capture flow A → B → C:

- **A · idle hub (this screen)** → tap *Speak Check-In* →
- **B · listening** ("iPhone 17 - 5": rotating prompt card "How's Your Mode?" with 5 dots, `0:07` timer inside the same ring, *Stop & Save* / *Cancel*, caption "Take Your Time, Speak Freely.") → *Stop & Save* →
- **C · saved** ("iPhone 17 - 6": check tile in a fully closed ring, "Check-In Saved", *Go Back Home*).

This maps 1:1 onto the previous DESIGN.md "Check-in — three states: idle hub / listening / saved" and onto the existing `app-four/Views/CheckIn/CheckInView.swift` + `CrescentRing.swift`. The partial green arc on the ring is the new form of the crescent.

**Where it sits — inferred from chrome.**

| Chrome | Present? | Reading |
|---|---|---|
| Back pill (`Container › Frame 1 › Background+Border` with `vuesax/outline/arrow-left`) at top-left | **Yes** | Screen is **pushed or presented full-screen**; it has a parent to return to. |
| `Main_navbar` tab bar (DS Frame 4 "Navigation", variants Calendar / Check In / Insights / Settings) | **No** | Not a tab root as drawn. |
| Add Button FAB (DS Frame 15, violet `#8c68d3` 50×50 "+") | **No** | Not a browsing surface. |
| Nav title slot (`Container › Frame 1 › Frame 2 › Container`, 128×22, empty) | Present but empty | Same header component as "Today's Mood" (iPhone 17 - 1) with the title removed. |
| Trailing "…" action (as on iPhone 17 - 1) | No | Header has only the leading pill. |

**Conclusion:** as drawn, this is a **full-screen pushed/covered flow**, most plausibly launched from the violet **Add Button FAB** on the Calendar screens (iPhone 17 - 1 / 19) and/or from the **Check In** tab. The DS Navigation component still contains a `Status=Check In` variant, which conflicts with this screen having no tab bar — see Open question 1.

---

## 2. Layout top → bottom

**Canvas.** Frame 402 × 874 pt, fill `#fbfffc`, corner radius 32 (device mock, not a UI radius). `clipsContent` on. Everything fits inside 874 pt: **no scroll, nothing below the fold.** Content column is 342 pt wide at x = 30 (30 pt gutters); the nav header is 340 pt at x = 31 (31 pt gutters) — a 1 pt inconsistency between the two containers.

Vertical rhythm (y in pt from the top of the frame):

```
   0 ── Status Bar (52 tall)
  52
  77 ── Back pill 42.6 × 42.6                        (25 pt below status bar)
 119.6
 143 ── "Saturday, Sept 11"        12/500 #6f7f75      h 15
 158      gap 10
 168 ── "How Do You Feel?"         34/600 #17501d      h 41
 209      gap 6
 215 ── "Take A Moment To Check In With Yourself" 16/500 #1e2225  h 19
 234      gap 65
 299 ── Ring 347 × 347  (x 27.5 … 374.5, centre 201 × 472.5)
 396.5    ├─ Button stack 342 × 152 (clipped), vertically centred in ring
 396.5    │   Speak Check-In   182 × 44
 448.5    │   Log Medications  191 × 46   (gap 8)
 502.5    │   Write Notes      155 × 46   (gap 8)
 548.5    └─
 646      gap 67 (space-between remainder; auto-layout minimum gap is 35)
 713 ── "A few Words Is Enough"    14/500 #6f7f75      h 17
 730
 730–840  empty (110 pt)
 840 ── Home Indicator (34 tall) — bar 143 × 5 at (129, 861)
 874
```

### 2.1 Status Bar — `Status Bar` (instance) 0,0 · 402×52
- iOS light status bar mock. Time "9:41" vector at (32,18) 40×21; icons (signal 20×14, Wi-Fi 16×14, battery 25×14, gap 4) at (301,20).
- All glyphs `#212529` (= **grey-500**); empty signal bar at 18 % opacity; battery outline at 60 %.
- Implementation note: system-provided; nothing to build.

### 2.2 Nav header — `Container` 31,77 · 340×42.6
- Horizontal auto-layout, `SPACE_BETWEEN`, gap 95.7, counter-axis centre. Only one child (`Frame 1`), so the trailing slot is empty.
- **Back pill** — `Frame 1 › Background+Border` 42.6×42.6 at (31,77): fill `#ffffff`, stroke **1.065 pt `#e4ece4`** (inside), corner radius 21.3 (full circle). No shadow.
  - Icon `vuesax/outline/arrow-left` 20×20 at (42.3, 88.3) — centred (11.3 inset). Vector fill **`#1e6725` (green-700)**. Despite the library name it renders as a **chevron "<"**, not an arrow with a shaft (see PNG crop).
- **Title slot** — `Frame 1 › Frame 2 › Container` 128×22 at (80.6, 87.3), vertical auto-layout, **empty**. Gap between pill and slot: 7.
- Nothing on the right.

### 2.3 Content block — `Frame 1707479473` 30,143 · 342×587
- Vertical auto-layout, **`SPACE_BETWEEN`**, gap ≥ 35, counter-axis centre, fixed size. Constraints CENTER/CENTER (block is meant to float in the middle of the safe area).
- Two children: the header+ring group (503 tall) and the caption (17 tall). 587 − 520 = 67 → caption sits 67 pt under the ring.

#### 2.3.1 Header + ring group — `Frame 1707479515` (27.5,143) · 347×503
Vertical auto-layout, gap **65**, centre-aligned. Its x is −2.5 relative to the content column because the ring (347) is 5 pt wider than the column (342).

**Header** — `Frame 2` (41,143) · 320×91, vertical, gap **10**, centred:

| Layer | Text | Font | Colour | Box | Notes |
|---|---|---|---|---|---|
| `Saturday, Sept 11` | "Saturday, Sept 11" | Inter **12 / Medium (500)**, line-height auto, tracking 0 | `#6f7f75` | 115×15 at (143.5,143) | centred on x = 201 |
| `Frame 1707479471` | — | — | — | 320×66 at (41,168), vertical gap **6** | |
| `How Do You Feel?` | "How Do You Feel?" | Inter **34 / Semi Bold (600)**, auto lh | `#17501d` (green-800) | 293×41 at (54.5,168) | single line, `white-space: nowrap` |
| `Take A Moment To Check In With Yourself` | same | Inter **16 / Medium (500)**, auto lh | `#1e2225` (grey-600) | 320×19 at (41,215) | single line, nowrap, fills the 320 header width exactly |

All three are `textAlignHorizontal: LEFT` but hug their content and are centred by the parent auto-layout, so they read as centred text.

**Ring** — `Group 735` (27.5,299) · 347×347
- Group effect: **drop shadow** `#000000` @ 8 %, offset (0, 2), blur radius 18, spread 0.
- **Track + disc** — `Frame 1707479517` 347×347, corner radius 173.5 (perfect circle):
  - fill **`#ebf8ee`** (inner disc)
  - stroke **21.33 pt `#bdddc0` (green-100)**, align INSIDE → track outer Ø 347, inner Ø 304.34.
  - vertical auto-layout, centre/centre, gap 9.2 (irrelevant with one child).
- **Progress arc** — `Ellipse 8` 347×347, drawn over the track (z above):
  - fill = **linear gradient, vertical (transform is a 90° rotation; HTML export `180deg`)**: `#26842f` at 0 % (top) → `#3fbb4b` at 50 % (mid-height) → `#25832e` at 100 % (bottom). No stroke (a stray `strokeWeight 0.92` is set but `strokes: []`).
  - Arc geometry from the export clip-path: outer r **173.5**, inner r **152.68** → thickness **20.82** (0.5 pt thinner than the track), **butt (flat) ends**.
  - Sweep: starts at **0° (3 o'clock)** and runs **clockwise to 118.8° (≈ 7 o'clock)** → **≈ 33 % of the circumference**. Visually: bright `#3fbb4b` at the right edge fading to `#25832e` at the bottom.
  - On screen B the same layer is swept ≈ ⅔ from ≈ 11 o'clock clockwise to 3 o'clock; on C it is a full closed ring. The idle value has no data meaning as drawn — see Open question 2.
- **Button stack** — `665_frame` (30,396.5) · 342×152, vertical auto-layout gap **8**, centred, **`clipsContent: true`**. Width 342 is wider than the disc's inner Ø (304.34); on screen B this frame is 304.34 wide. Nothing visible is clipped at this size.

| # | Layer | Box (screen) | Fill / stroke | Radius | Padding · gap | Icon | Label |
|---|---|---|---|---|---|---|---|
| 1 | `Button / Filled` | (110,396.5) 182×44, **fixed width 182** | fill `#2a9134` (green-500), no stroke | 999 | 10 top/bottom · 18 sides · **gap 3** | `vuesax/bold/microphone-2` **21×21** `#ffffff` at inset (18,11.5) | "Speak Check-In" Inter 16/500, **line-height 24 px**, `#ffffff`, 122×24 |
| 2 | `Button / Outlined` | (105.5,448.5) 191×46, hug | fill `#ffffff`, stroke **1 pt `#cbd5e1`** | 999 | 10 · 18 · gap 8 | `svgexport-20 (6) 1` **18×18** `#8c68d3` (violet-500) at inset (19,14) | "Log Medications" Inter 16/500 lh 24, **`#634a96` (violet-700)**, 127×24 |
| 3 | `Button / Outlined` | (123.5,502.5) 155×46, hug | fill `#ffffff`, stroke 1 pt `#cbd5e1` | 999 | 10 · 18 · gap 8 | `vuesax/bold/edit-2` **18×18** `#2a9134` at inset (19,14) | "Write Notes" Inter 16/500 lh 24, `#26842f` (green-600), 91×24 |

Measured heights: 44 (filled) vs **46 (outlined)** — 10 + 24 + 10 = 44 in both; the outlined pair's extra 2 pt is the 1 pt stroke being counted outside the box by the export. Treat all three as **44 pt** in code.

#### 2.3.2 Caption — `A few Words Is Enough` (124,713) · 154×17
Inter **14 / Medium (500)**, auto line-height, `#6f7f75`, centred on x = 201, 67 pt below the ring.

### 2.4 Home Indicator — instance 0,840 · 402×34
Bar 143×5, radius 10, `#212529`, at (129,861). System-provided.

### 2.5 Colour → token map (DS Frame 5 "Color palettes")

| Hex | Where | Token | Status |
|---|---|---|---|
| `#fbfffc` | screen background | — | **not in palette** (green-tinted near-white; every screen uses it) |
| `#ebf8ee` | ring inner disc | — | **not in palette** (green-50 is `#eaf4eb`) |
| `#bdddc0` | ring track | green-100 | ✓ |
| `#2a9134` | primary button fill; pencil icon | green-500 | ✓ (DS primary) |
| `#26842f` | arc start; "Write Notes" label | green-600 | ✓ |
| `#3fbb4b` | arc mid-stop | — | **not in palette** |
| `#25832e` | arc end-stop | — | not in palette (1 unit off green-600) |
| `#1e6725` | back chevron | green-700 | ✓ |
| `#17501d` | title | green-800 | ✓ |
| `#1e2225` | subtitle | grey-600 | ✓ |
| `#212529` | status bar, home bar | grey-500 | ✓ |
| `#6f7f75` | date line, caption | — | **not in palette** (sage grey, reused on B) |
| `#cbd5e1` | outlined button stroke | — | not in palette; Buttons component default (Tailwind slate-300) |
| `#e4ece4` | back pill stroke | — | not in palette; shared with Bill-shape chips (Frame 15) |
| `#8c68d3` | capsule icon | violet-500 | ✓ (also the Add Button FAB) |
| `#634a96` | "Log Medications" label | violet-700 | ✓ |
| `#ffffff` | button fills, pill fill, primary label | — | white |

Two different hairline greys are in play on one screen: `#cbd5e1` (buttons) and `#e4ece4` (pill / chips).

### 2.6 Typography → DS Frame 2
Everything is **Inter** in the pen file (Regular/Medium/Semi Bold/Bold ramp 12–40). The shipping app is native SF (spec 023). Roles used here: 34/600 (display title) · 16/500 (subtitle, button labels @ lh 24) · 14/500 (caption) · 12/500 (eyebrow date). Button label line-heights 20/24/28 for Small/Medium/Large come from the Buttons component.

---

## 3. Component instances and states

| Instance | DS component | Variant / state on this screen | Notes |
|---|---|---|---|
| Back pill | Nav header "Container" (shared with iPhone 17 - 1/19) | leading pill only; title slot empty; no trailing action | 42.6 pt square — under the 44 pt minimum. |
| `Button / Filled` "Speak Check-In" | Buttons (Frame 3) — Filled column | **Size = Medium, Icon = With Icon, State = Default** | **Detached FRAME**, not an instance (on screen B they are INSTANCEs). Drift from the component: gap **3** instead of 8, icon **21** instead of 18, **fixed width 182** instead of hug. |
| `Button / Outlined` "Log Medications" | Buttons — Outlined column | Medium · With Icon · Default | Detached. **Off-system colour**: label violet-700 + icon violet-500; the component only defines green labels. |
| `Button / Outlined` "Write Notes" | Buttons — Outlined column | Medium · With Icon · Default | Detached; matches the component (green-600 label, `#cbd5e1` stroke). |
| Ring + arc | none (bespoke `Group 735`, reused on B and C) | idle: arc ≈ 33 %, no timer, no check | Candidate for a new DS component "Check-In Ring" with states idle / listening(progress) / saved. |

Buttons component reference (from Frame 3 HTML, for the state matrix the code will need):

| State | Filled | Outlined |
|---|---|---|
| Default | bg `#2a9134`, label `#fff` | bg `#fff`, stroke `#cbd5e1`, label `#26842f` |
| Hovered/pressed | bg `#1e6725` | bg `#f8fafc`, stroke `#2a9134` |
| Focused | bg `#17501d`, ring `#93c5fd` 0 px | bg `#fff`, stroke `#26842f` |
| Disabled | bg `#e5e7eb`, label `#9ca3af` | bg `#f8fafc`, stroke `#e2e8f0`, label `#94a3b8` |
| Sizes | Small pad 8/14 lh 20 · **Medium pad 10/18 lh 24** · Large lh 28 | same |

Nothing on this screen is selected/unselected, on/off, expanded/collapsed, or clipped at a frame edge. **No horizontal scroll.**

---

## 4. Copy inventory (verbatim)

| # | Layer id | String | Role |
|---|---|---|---|
| 1 | `72:16346` | `Saturday, Sept 11` | eyebrow date |
| 2 | `72:16348` | `How Do You Feel?` | title |
| 3 | `72:16349` | `Take A Moment To Check In With Yourself` | subtitle |
| 4 | `72:16355` | `Speak Check-In` | primary button |
| 5 | `72:16360` | `Log Medications` | secondary button |
| 6 | `72:16363` | `Write Notes` | secondary button |
| 7 | `72:16365` | `A few Words Is Enough` | caption |
| — | status bar | `9:41` | system mock |

### 4.1 Typos and inconsistencies
1. **"A few Words Is Enough"** — subject–verb disagreement ("words … is"); should be "A Few Words Are Enough" (or sentence case "A few words are enough"). Also the only string with a lower-case "few" in an otherwise Title-Case file.
2. **Title Case on full sentences** — "Take A Moment To Check In With Yourself" capitalises "A", "To", "With". Consistent with sibling screens ("A Moment For Yourself, Captured.") but not with iOS sentence-style copy. Needs a file-wide decision, not a per-screen fix.
3. **"Sept 11"** — non-standard abbreviation for en-US (`Sep`); "Sept" is en-GB/en-AU. Use a system `Date.FormatStyle`, not literal copy.
4. **Saturday ≠ 11 Sep 2026** — 11 Sep 2026 is a Friday. Placeholder data; the calendar strip on iPhone 17 - 19 has the same invented week (and lists "Tue 7" before "Mon 6").
5. **"Check-In" spelling varies across the file** — "Speak Check-In" / "Check-In Saved" / "Daily Check-In" (hyphen + capital I) vs. the tab label **"Check In"** (Frame 4) vs. code "Check in". Pick one; the tab bar is the odd one out.
6. **"Write Notes" / "Log Medications"** are plural; one check-in produces one note. Not a typo — flagging for the owner ("Write a Note"?).
7. No spelling errors on this screen (the "Okey / Breackdoen / Vyvans / Claendar / Dtails / How Does It Feels" set lives on other frames).

---

## 5. Glyph and icon usage

**Signal glyphs (DS Frame 12): none.** No sprout / bolt / target / moon at any level on this screen.

UI icons:

| Icon | Library name | Style | Size | Colour | Where |
|---|---|---|---|---|---|
| Chevron back | `vuesax/outline/arrow-left` | outline (renders as a bare chevron) | 20 | `#1e6725` green-700 | back pill |
| Microphone | `vuesax/bold/microphone-2` | **bold / filled** | 21 | `#ffffff` | Speak Check-In |
| Capsule | `svgexport-20 (6) 1` — **imported SVG, not from the vuesax library** (no capsule/pill exists in `icon-library-names.json`) | filled, diagonal (~45°), one half solid + one half hollow with a highlight (two-tone via path, single fill colour) | 18 | `#8c68d3` violet-500 | Log Medications |
| Pencil | `vuesax/bold/edit-2` | bold / filled, with base line | 18 | `#2a9134` green-500 | Write Notes |

Not present here but part of the family: tab-bar icons (`vuesax/outline/calendar`, `vuesax/linear/task-square`, `vuesax/outline/chart`, `vuesax/twotone/setting-2`, bold variants when active), Add Button `vuesax/twotone/add`, "…" ellipsis pill, play, sparkles, lock.

Style rule visible in the file: **actions inside buttons use the bold (filled) vuesax set; navigation chrome uses outline/linear.** The capsule is the same asset used inside the violet circular badge on iPhone 17 - 1 / 19 medication rows; it needs a proper named asset (e.g. `glyph-medication-capsule`).

---

## 6. Data the screen implies

| Field | Type | Shown as | Notes |
|---|---|---|---|
| Today's date | `Date` | "Saturday, Sept 11" — weekday, abbreviated month, day | Format via `Date.FormatStyle` (`.weekday(.wide) .month(.abbreviated) .day()`), never a literal. |
| Ring progress | `Double` 0…1 | ≈ 0.33 arc | Meaning on idle undefined (Open question 2). On B it advances with recording time; on C it is 1.0. |
| Recording state | enum `idle · listening · saved` | this screen = `idle` | Drives A/B/C. |
| Medication on board | — | **not shown** | The previous `MedicationBarOverlay` ("rides above when a dose is on board") has no counterpart in this frame. |

No enums (Great/Good/Okay…, Alert/Tired…, Sharp/Present…), no medication name/dose, no hours of sleep, no month selector, no counts or percentages appear on this screen.

---

## 7. Interactions implied

| Target | Hit area as drawn | Action | Destination |
|---|---|---|---|
| Back pill | 42.6×42.6 at (31,77) | pop / dismiss | parent (Calendar day or tab root) |
| Speak Check-In | 182×44 | start recording; request mic permission on first use | **B · listening** (iPhone 17 - 5) |
| Log Medications | 191×46 | open medication logging | **no pen screen in this export** (nearest: the medication section of "iPhone 17 - 18 · edit check-in") |
| Write Notes | 155×46 | open text composer | **no pen screen in this export** (existing `TextCheckInComposer.swift`) |
| Ring | — | none as drawn | previous spec: breathes ~5 s when idle (scale 1→1.035), static glow under Reduce Motion |
| Title slot / trailing slot | — | none | empty on this screen |

- **Scroll axes: none.** Content is 587 pt in an ~788 pt safe area.
- No toggles, no expand/collapse, no save on this screen (save happens on B).
- Swipe-back should work if pushed; if presented as a full-screen cover, the pill is the only way out.

Accessibility notes to carry into the plan:
- Back pill is **42.6 pt < 44 pt** minimum target.
- Eyebrow + caption `#6f7f75` on `#fbfffc` ≈ **4.19 : 1** — fails WCAG AA for 12/14 pt text (needs 4.5). Use grey-300 `#6a6d70` (5.2 : 1 on white per Frame 5 — and already used for the B-screen subtitle) or darker.
- White on green-500 `#2a9134` = **4.04 : 1** (Frame 5's own number) — AA only for *large* text; a 16 pt Medium label is not large. Either accept as a documented exception or fill primary buttons with green-600 `#26842f` (4.75 : 1).
- Every text layer is `nowrap`; the subtitle already spans the full 320 pt at 16 pt. At Dynamic Type ≥ xxL the title, subtitle and the 191-pt "Log Medications" (inside a **clipping** 342-pt frame in a 304-pt disc) will overflow. The ring is a fixed 347 pt with 27.5 pt margins and cannot grow; the plan needs a rule (wrap text above the ring, allow the button stack to break out of the disc, or shrink the ring).

---

## 8. Open questions for the owner

1. **Tab or pushed?** The frame has a back pill and no tab bar, but the DS Navigation component has a `Status=Check In` tab and the current app has a Check-in tab. Which is it: (a) Check In tab shows this hub *with* the tab bar and no back pill, (b) the tab and the FAB both push this hub full-screen, or (c) the Check In tab is dropped and the violet FAB is the only entry?
2. **What does the idle arc mean?** ≈ 33 % on idle, ≈ 66 % on B, 100 % on C. Is it (a) a purely ambient "crescent" (any value, animates/breathes), (b) recording-time budget (then idle should be 0 %), or (c) something else (e.g. today's progress: speak / meds / note = 3 steps)?
3. **Off-palette colours** — `#fbfffc` (background), `#ebf8ee` (disc), `#3fbb4b` / `#25832e` (arc), `#6f7f75` (secondary text), `#cbd5e1` and `#e4ece4` (two hairlines). Should these be added to the palette as tokens (`screen`, `disc`, `arc-hi`, `ink-secondary`, `hairline`) or snapped to the nearest ramp value?
4. **Violet outlined button** — is "Log Medications" (violet-700 label, violet-500 icon) a sanctioned Outlined variant (`Tint = Medication`) or a one-off? The Buttons component has no violet column.
5. **Detached buttons** — the three buttons on A are detached frames; "Speak Check-In" has gap 3 / icon 21 / fixed width 182 while B's instances use gap 8 / hug. Treat A as drift and follow the component (gap 8, icon 18, hug)?
6. **Medication-on-board state** — the previous design showed a `MedicationBarOverlay` above the hub when a dose is active. Deliberately removed, or not yet drawn?
7. **Missing destinations** — no pen frames for the Log Medications sheet or the Write Notes composer. Reuse the existing `TextCheckInComposer` and the meds section of iPhone 17 - 18 as-is, or are frames coming?
8. **Copy rules** — Title Case sentences file-wide? Fix "A few Words Is Enough"? Standardise "Check-In" vs "Check In"?
9. **Contrast** — accept 4.19 : 1 secondary text and 4.04 : 1 white-on-green-500, or adopt the fixes in §7?
10. **Empty header slots** — should the title slot carry anything (e.g. "Check-In") and should a trailing "…" exist here as on iPhone 17 - 1? As drawn both are empty.
11. **Motion** — carry over the old idle breathing (~5 s, 1→1.035) and listening rotation, or is the ring static? Nothing in the pen file specifies motion.
