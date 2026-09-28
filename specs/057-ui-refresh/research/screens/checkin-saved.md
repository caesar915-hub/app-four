<!-- Created: 2026-09-27 21:55 WEST · Updated: 2026-09-27 21:55 WEST -->
# Check-In Saved — screen spec

**Pen node:** `iPhone 17 - 6` (pen id `fmQEp`, Figma id `72:16419`)
**Pen label:** "Check-In Recording — C · saved (Check-In Saved, ring with check, Go Back Home)"
**Sources used:** PNG render `pen/named/iphone17-6-checkin-recording-c.png` (804×1748 @2x = 402×874), HTML-lite `pen/html-lite/iPhone-17-6.html`, Figma JSON `figma/iphone17-6.json` + `.raw.json`, DS frames 2/3/4/5/12/15, sibling screens `iPhone 17 - 4` (A) and `iPhone 17 - 5` (B).
**Scope:** planning only. No Swift. Numbers come from the JSON; visibility comes from the PNG. Anything the file does not settle is listed in §8 rather than guessed.

---

## 1. Purpose and placement

**Purpose.** Terminal confirmation of the voice Check-In flow. It tells the person the recording has been persisted ("Check-In Saved") and offers one exit ("Go Back Home"). It shows no data about what was saved.

**Where it sits.** Step C of a three-screen flow, all named "Check-In Recording" in the pen file:

| Step | Pen frame | Content | Nav chrome |
|---|---|---|---|
| A | `iPhone 17 - 4` | "How Do You Feel?" — Speak Check-In / Log Medications / Write Notes inside a partial progress ring | back pill only |
| B | `iPhone 17 - 5` | "How's Your Mode?" prompt card, `0:07` timer, Stop & Save / Cancel inside the ring | back pill only |
| **C** | **`iPhone 17 - 6`** | **ring at 100 % with a check, "Check-In Saved", Go Back Home** | **back pill only** |

**Presentation inferred from chrome:**
- No `Main_navbar` tab bar (Frame 4 component) and no `Add Button` FAB (Frame 15 component) → the flow runs full-screen with the tab bar hidden. Screens that *do* carry `Main_navbar` + `Add Button` are the tab roots (`iPhone 17 - 1` Day Mode Details, `- 7` Statistics, `- 19` Mood Journal).
- A circular **back pill** (`Background+Border` + `vuesax/outline/arrow-left`) is present top-left, the same instance used on A, B and `- 18` Edit Check-In → the flow is a **pushed** stack (or a full-screen cover with its own back affordance), not a sheet: there is no grabber, the frame fills 402×874, and the device status bar is drawn.
- "Go Back Home" is the primary exit and implies popping the whole flow to a tab root. Which root is "Home" is not defined by the pen file (see §8).

**Fold.** Frame is exactly 402×874; nothing extends below 874. The screen does not scroll.

---

## 2. Layout, top → bottom

Coordinates are absolute in the 402×874 frame unless marked *rel*. Frame background `#fbfffc` (off-palette near-white with a green cast; not in Frame 5), device corner radius 32.

### 2.1 Status bar — `Status Bar` instance, y 0–52
- `Time / Light`: x 32, y 18, 40×21, radius 20; glyph "9:41" vector 28.43×11.09, fill `#212529` (grey-500).
- `Status Icons`: x 301, y 20, 69×14, hstack gap 4:
  - `Network Signal / Light` 20×14 — three bars `#212529`, `Empty Bar` at 18 % opacity.
  - `WiFi Signal / Light` 16×14 — `#212529`.
  - `Battery / Light` 25×14 — outline and cap at 60 % opacity, fill `Rectangle 20` 19×8 radius 1, `#212529`.
- System chrome; in SwiftUI this is the real status bar, not drawn.

### 2.2 Nav row — `Container`, x 31, y 77, 340×42.6
- Auto-layout: horizontal, `SPACE_BETWEEN`, gap 95.7, counter-axis centre. Only one child (`Frame 1`), so it renders left-aligned.
- `Frame 1` 177.6×42.6, hstack gap 7:
  - **Back pill** `Background+Border`: 42.6×42.6, fill `#ffffff`, stroke `#e4ece4` 1.065 inside (off-palette), radius 21.3 (full circle). Absolute box x 31–73.6, y 77–119.6; centre (52.3, 98.3).
    - Icon `vuesax/outline/arrow-left` 20×20 at rel (11.3, 11.3), centred in the pill. Visible glyph `Vector` 7.16×14.45 at rel (5.96, 2.78), fill `#1e6725` (green-700). A second 20×20 `Vector` at opacity 0 is the icon's bounding box.
    - The fractional sizes (42.6 / 21.3 / 1.065) are exactly 40 / 20 / 1 × 1.065 — a scaled component. See §8.
  - `Frame 2` → `Container` 128×22 at rel (49.6, 10.3): **empty**. It is a title slot with no text on this screen. Nothing renders.
- Vertical gap from pill bottom (119.6) to the hero block top (267): 147.4.

### 2.3 Hero block — `Frame 1707479478`, x 30, y 267, 342×340
- Auto-layout: vertical, gap 48, both axes centred, width fixed 342, height hugs.
- Constraints `CENTER / CENTER`: y 267 = (874 − 340) / 2 → the block is **vertically centred on the frame**, not pinned to the nav.
- Side gutters 30 (402 − 342). Note the nav row uses 31 — a 1 pt mismatch.

#### 2.3.1 Completion ring — `Group 735`, 211×211, abs x 95.5–306.5, y 267–478, centre (201, 372.5)
- Group effect: drop shadow `#000000` @ 8 %, offset (0, 1.22), blur 10.95, spread 0. (HTML-lite converts this to `drop-shadow(0 1.216px 4.789px #00000014)`.)
- Layer 1 `Frame 1707479517` (the disc + track): 211×211, radius 105.5, fill `#ebf8ee` (off-palette; nearest is green-50 `#eaf4eb`), stroke `#bdddc0` (green-100) **12.97 inside** — this is the ring *track*. Auto-layout vertical, centred, gap 5.6.
  - Child `Frame 1000002966` (the check tile): **96.95×96.95 square, corner radius none (sharp corners), fill `#2a9134` (green-500)**, at rel (57.03, 57.03) → abs x 152.5–249.5, y 324–421. `strokeWeight` 1.61 OUTSIDE is recorded but `strokes` is empty, so no border renders.
    - Child `Vector` (check mark): 49.72×37.29 at rel (23.62, 29.83), fill `#ffffff`. Custom vector, not a library instance.
- Layer 2 `Ellipse 8` (the progress arc at 100 %): 211×211 on top of layer 1. Rendered as a full donut — outer r 105.5, inner r 92.84, so the visible ring is **12.66 thick** (HTML-lite `clip-path` confirms the donut). Fill linear gradient, transform = 90° rotation, i.e. **top → bottom**: `#26842f` (green-600) 0 % → `#3fbb4b` (off-palette) 50 % → `#25832e` (off-palette, green-600 − 1) 100 %. Effect: darker at top and bottom, lighter at the horizontal midline — visible in the PNG.
  - Because the arc (12.66) is slightly thinner than the track (12.97), up to ~0.3 pt of `#bdddc0` may peek along the inner edge. Not visible at 2x.
- Relationship to A/B: same `Group 735` construction (disc `#ebf8ee`, track `#bdddc0`, gradient arc). A/B use 347×347 with stroke 21.33; C is that ring × 0.608. On A/B the arc is partial (progress); on C it is complete. **C = ring at 100 %.**

#### 2.3.2 Text stack — `Frame 1707479471`, rel (40.5, 259) → abs x 70.5–331.5, y 526–607, 261×81
- Auto-layout vertical, gap 6, items centred, hugs both axes. Width 261 is the title's intrinsic width; the subtitle is stretched to it (`width: 100%` in HTML-lite).
- **Title** `Check-In Saved`: 261×41, abs y 526–567. Inter **34 / Semi Bold (600)**, colour `#17501d` (green-800), line-height auto (≈41), letter-spacing 0, horizontal align LEFT (irrelevant — auto-width), vertical CENTER. Matches DS Typography row "34 pt · Semi Bold".
- **Subtitle** `A Moment For Yourself, Captured.⏎See You At Next Check-In`: 261×34, rel y 47 → abs y 573–607. Inter **14 / Medium (500)**, colour `#1e2225` (grey-600), line-height auto (≈17 ×2 lines), align CENTER. The break is a hard **U+2028 LINE SEPARATOR** after "Captured." — a designed two-line break, not wrapping. Matches DS "14 pt · Medium".
- Gap from ring bottom (478) to title top (526): 48 (the stack gap).

### 2.4 Primary CTA — `Frame 1707479477`, x 30, y 717, 342×44
- Wrapper auto-layout vertical, gap 25, centred; constraints `MIN / MIN` (pinned top-left at y 717, **not** bottom-anchored in the file).
- `665_frame` 342×44: horizontal, gap 8, centred, `WRAP`, clips content — a generic button-row container with one child.
- **`Button / Filled`** instance, 342×44 (flex-fills the row): fill `#2a9134` (green-500), radius 999 (pill), padding **10 top/bottom · 18 left/right**, gap 8, no stroke. Absolute y 717–761.
  - `label` "Go Back Home": 113×24 at rel x 114.5 (centred). Inter **16 / Medium (500)**, line-height **24 px**, letter-spacing 0, colour `#ffffff`.
  - Matches DS Frame 3 variant **`Button / Filled` · Size=Medium · Icon=Without Icon · State=Default** exactly (44 h, 10/18 padding, 16/500/24, `#2a9134`).
- Gap subtitle bottom (607) → button top (717): 110. Gap button bottom (761) → home-indicator bar (861): 100; → frame bottom: 113.

### 2.5 Home indicator — `Home Indicator` instance, y 840–874
- `Bar › Base` 143×5, x 129, rel y 21 → abs y 861–866, radius 10, fill `#212529`. System chrome.

### 2.6 Colour inventory (this screen)

| Hex | DS token (Frame 5) | Used for |
|---|---|---|
| `#fbfffc` | — off-palette | screen background |
| `#ffffff` | white | back pill fill, check glyph, button label |
| `#e4ece4` | — off-palette | back pill stroke |
| `#1e6725` | green-700 | back chevron |
| `#ebf8ee` | — off-palette (green-50 is `#eaf4eb`) | ring disc |
| `#bdddc0` | green-100 | ring track |
| `#26842f` | green-600 | gradient start |
| `#3fbb4b` | — off-palette | gradient mid |
| `#25832e` | — off-palette (green-600 − 1) | gradient end |
| `#2a9134` | green-500 | check tile, CTA fill |
| `#17501d` | green-800 | title |
| `#1e2225` | grey-600 | subtitle |
| `#212529` | grey-500 | status bar, home indicator |

Contrast (from Frame 5 cards): green-800 on white 9.54 AAA (title ✓); grey-600 on white 16.02 AAA (subtitle ✓); green-700 on white 6.95 AAA (chevron ✓); **white on green-500 = 4.04 — passes AA only for large text; the 16 pt Medium button label is not "large", so it fails WCAG AA 4.5:1.** Same finding applies to every Medium filled button in the file.

---

## 3. Component instances and states

| Component (DS name) | Instance on this screen | Visible state | Notes |
|---|---|---|---|
| Back pill (`Background+Border` + `vuesax/outline/arrow-left`) — shared with A, B, `- 18` | 42.6 pt circle, white, `#e4ece4` stroke, green-700 chevron | default / enabled | Not a Frame 3 button variant; a bespoke nav control. Same instance on A/B/18 → should be one reusable view. |
| Nav title slot (`Frame 2 › Container` 128×22) | empty | empty | Slot exists, no text. |
| Completion ring (`Group 735`: disc + track + gradient arc) — shared with A, B | 211 pt, arc at 100 % | **complete** | A/B show partial progress; C is the terminal state. Scaled 0.608× from A/B. |
| Check tile (`Frame 1000002966` + `Vector`) | 96.95 pt sharp square, green-500, white check | static | Only appears on C. Not a library icon. |
| `Button / Filled` (Frame 3) | Size=Medium · Icon=Without Icon | **State=Default** | DS defines Hovered `#1e6725`, Focused `#17501d`, Disabled `#e5e7eb` fill (label colour for Disabled not read from this screen). |
| `Status Bar`, `Home Indicator` | — | light | Device chrome. |

Not present: `Main_navbar` (tab bar), `Add Button` (FAB), bill-shape chips, signal glyphs. No row is clipped at the frame edge → no horizontal scroll.

---

## 4. Copy inventory

Verbatim, in reading order (`⏎` = U+2028 line separator):

1. `9:41` — status bar (vector, not editable text)
2. `Check-In Saved`
3. `A Moment For Yourself, Captured.⏎See You At Next Check-In`
4. `Go Back Home`

### Typos / inconsistencies
- **Title Case in running copy.** "A Moment For Yourself, Captured. See You At Next Check-In" capitalises every word including "For", "At". Sentence case would be the native-iOS norm. The same pattern is on A ("Take A Moment To Check In With Yourself", "A few Words Is Enough") and B, so it is a file-wide convention rather than a one-off; decide once.
- **Missing terminal punctuation** on line 2 ("See You At Next Check-In" has no full stop; line 1 has one).
- **"At Next Check-In"** reads as a missing article — "at your next check-in" / "at the next check-in".
- **Hyphenation drift across the file:** this screen and A use "Check-In"; the Frame 4 tab bar uses "Check In" (no hyphen). Pick one.
- **"Home" is not a destination in the tab bar** (Calendar · Check In · Insights · Settings). "Go Back Home" names a place the nav does not define.
- No typo of the "Okey / Breackdoen / Vyvans" class on this screen.

---

## 5. Glyph and icon usage

**Signal glyphs (Frame 12 — sprout / bolt / target / moon):** none on this screen.

**UI icons:**

| Icon | Source | Style | Size | Colour |
|---|---|---|---|---|
| Back chevron | `vuesax/outline/arrow-left` instance (library also has `vuesax/linear/arrow-left`, `vuesax/bold/arrow-left`) | outline/linear stroke, **rendered as a bare chevron "‹" — no shaft**, despite the "arrow-left" name | 20×20 box; glyph 7.16×14.45 | `#1e6725` green-700 |
| Check mark | custom `Vector` (not from the vuesax library, which offers `vuesax/linear/check`, `vuesax/bold/check`, `tick-square`, `tick-circle`) | **filled** solid white shape | 49.72×37.29 inside a 96.95 solid square | `#ffffff` on `#2a9134` |
| Status bar signal / wifi / battery, home indicator | system | filled | — | `#212529` |

Style note: the DS elsewhere is outline/linear (tab bar icons, back chevron, mic/capsule/pencil on A). The filled white check on a **sharp-cornered** solid square is the only hard-edged rectangle in a pill-and-circle system.

---

## 6. Data implied

This screen displays no record data. It implies:

- A **check-in record has been persisted** before this screen appears (the trigger is B's "Stop & Save").
- **Ring progress = 1.0** (the same ring shows a fraction on A/B). Whether that fraction models recording duration, flow step, or processing is not defined by the pen file.
- Nothing shown: no date (A shows "Saturday, Sept 11"), no duration (B shows `0:07`), no transcript/summary, no signal values (mood/energy/focus/sleep), no medication.

Enum/labels: none on this screen. (Great/Good/Okay/Flat/Low, Alert/Tired/Steady/Charged, Sharp/Present/Distracted/Locked In, Active/Kicking In belong to `- 18` / `- 19` / `- 7`, not here.)

---

## 7. Interactions implied

| Target | Hit area (as drawn) | Action implied | Notes |
|---|---|---|---|
| Back pill | 42.6×42.6 circle at (31, 77) | pop one step | ≥44 pt recommended; 42.6 is under Apple's 44 pt minimum. What "back" means *after* a save is undefined (§8). |
| `Go Back Home` | 342×44 pill at (30, 717) | dismiss the whole flow to a tab root | Primary action; only one CTA. 44 pt tall meets the minimum. |
| Ring / check tile | — | none | Static illustration; no affordance drawn. |
| Scroll | — | none | Content height 874 = frame; no vertical or horizontal scroll. |
| Toggles / expand / chips | — | none | |

Transitions implied but **not drawn**: B → C (after Stop & Save) and C → root (after Go Back Home). No loading/processing state exists between B and C in the file. No entrance motion (ring completing, check appearing) is specified; the DS frames contain no motion spec.

DS button states available for mapping to iOS: Default → normal; Hovered (`#1e6725`) → the natural pressed/highlighted fill; Focused (`#17501d`) → keyboard/AX focus; Disabled (`#e5e7eb`).

---

## 8. Open questions for the owner

1. **Processing gap.** On this stack, "Stop & Save" is followed by WhisperKit transcription and the two-pass MLX extraction, which take seconds. Is C shown immediately after the audio is saved (processing continues in the background) or only after extraction completes? If the latter, a processing state between B and C is missing from the pen file. If the former, "Saved" is true but the person will find an entry that is still filling in.
2. **What does the back pill do on a saved screen?** Returning to B (a finished recording) makes no sense; returning to A would start a new check-in. Options: hide it on C, make it equivalent to "Go Back Home", or make it a close (×). The file keeps the same pill as A/B.
3. **Where is "Home"?** The tab bar has Calendar · Check In · Insights · Settings. Which tab does "Go Back Home" land on — the tab the flow was launched from, Check In, or Calendar (Day Mode Details)? Copy may need to change to match ("Done", "Back to today").
4. **Sharp-cornered check tile.** The 96.95 pt green square has no corner radius in an otherwise pill/circle system. Intentional accent, or should it be rounded / circular / a `tick-circle` library icon?
5. **Off-palette colours.** `#fbfffc` (background), `#ebf8ee` (disc), `#e4ece4` (pill stroke), `#3fbb4b` and `#25832e` (gradient) are not in Frame 5. Should they be added as tokens (e.g. `surface`, `green-50-alt`, `border-subtle`, `green-gradient-mid`) or snapped to the nearest existing step?
6. **Scaled, fractional metrics.** Back pill 42.6/21.3/1.065 (= 40/20/1 × 1.065), ring 211 with 12.97 track and 12.66 arc, check tile 96.95. Confirm the intent is round numbers (40 pt pill, 1 pt stroke; ~210–212 pt ring, 13 pt stroke; 96 pt tile) so the SwiftUI spec can use integers.
7. **Ring semantics.** A and B use the same ring with a partial arc. What does the fraction encode (recording length toward a cap, flow step, processing progress)? C at 100 % should be consistent with that meaning.
8. **Vertical anchoring.** The hero block is centred on the 874 pt frame while the CTA is absolutely placed at y 717 (top-left constraints). On other heights (SE-class, Pro Max, Dynamic Type growth), should the CTA pin to the bottom safe area with the hero centred in the remaining space?
9. **Typeface.** The pen file sets Inter everywhere; the shipping app is native SF (spec 023 reversal). Is Inter a stand-in for SF, or a deliberate reintroduction of a bundled face? This decides whether the 34/600, 14/500, 16/500 values map to SF Text/Display styles or to custom fonts.
10. **Button label contrast.** White on green-500 is 4.04:1 — below WCAG AA (4.5:1) for 16 pt Medium. Accept (many system green buttons are similar), darken the filled button to green-600 `#26842f` (4.75 AA), or bump the label weight/size?
11. **Subtitle copy.** Confirm Title Case is intentional app-wide; add the terminal period; consider "See you at your next check-in."
12. **Back pill hit target** is 42.6 pt (< 44). Increase the tappable area even if the drawn circle stays 40.
13. **Empty title slot** (`Frame 2 › Container` 128×22) next to the back pill — reserved for a nav title on other screens, or leftover? Nothing to render here either way.
14. **Motion.** Any entrance animation (arc completing into the check, tile scale-in) is unspecified. Product Posture forbids confetti; a settle spring on the check is the closest in-bounds option if desired.
