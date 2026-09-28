<!-- Created: 2026-09-27 21:58 WEST · Updated: 2026-09-27 22:01 WEST -->
# Check-In Recording — B · Listening

**Pen node:** `iPhone 17 - 5` (pen id `XXA5N`, Figma id `72:16377`) · **Frame:** 402 × 874 pt, corner radius 32, fill `#fbfffc`
**Sources:** `pen/named/iphone17-5-checkin-recording-b.png` (ground truth) · `pen/html-lite/iPhone-17-5.html` · `figma/iphone17-5.json` / `.raw.json`
**Status:** planning spec only — no Swift changes. All numbers are 1× points from the Figma JSON; the PNG is 2×.

Sections: 1 Purpose & placement · 2 Layout top→bottom · 3 Component instances & states · 4 Copy inventory & copy issues · 5 Glyph & icon usage · 6 Data implied · 7 Interactions implied · 8 Open questions

---

## 1. Purpose & placement

**Purpose.** The live "listening" state of the voice check-in: the mic is open, a count-up timer shows elapsed recording time, a rotating prompt card nudges what to talk about, and the user ends with **Stop & Save** or **Cancel**.

**Where it sits.** It is step 2 of a three-screen linear flow, not a tab:

| Step | Pen screen | Heading | Ring fill |
|---|---|---|---|
| A · idle | `iPhone 17 - 4` | "How Do You Feel?" — Speak Check-In / Log Medications / Write Notes | 118.8° = 33 % |
| **B · listening (this)** | **`iPhone 17 - 5`** | prompt card + `0:07` timer + Stop & Save / Cancel | **237.6° = 66 %** |
| C · saved | `iPhone 17 - 6` | "Check-In Saved" — Go Back Home | 360° = 100 % |

Evidence from nav chrome:
- **Back pill present** (top-left, 42.6 pt circle with `vuesax/outline/arrow-left`) — same ad-hoc pill as screens A and C → this is a **pushed / full-screen** view inside the check-in flow.
- **No `Navigation` tab bar** (DS Frame 4 `Status=…, Mode=Light` is absent), **no `Add Button` FAB** (DS Frame 15 absent). The tab bar is hidden for the whole A→B→C flow.
- The nav-title slot (`Frame 2 › Container`, 128 × 22 at x 80.6) is **empty** — there is no screen title; the prompt card is the only heading.
- Nothing scrolls: content ends at y 716.25, home indicator starts at 840.

**Ring = flow-step indicator, not a timer.** The same 347 pt ring appears on A and B with a gradient arc anchored at 3 o'clock and swept clockwise; the arc grows 33 % → 66 % → 100 % across A → B → C (computed from the `Ellipse 8` clip paths in the three HTML exports). It does **not** represent elapsed time (66 % at 0:07 would imply a ~10.6 s cap). See Q2.

**What it replaces in code (read-only reference).** `app-four/Views/CheckIn/CheckInView.swift` already renders idle / recording / paused / processing / done in one layout with a prompt card (`heroPrompt` + `promptDots`), a time-based prompt progress bar, a "Recording, elapsed" live region and a cancel action; `CheckInViewModel.nudgePrompts` holds exactly **5** prompts, matching the 5 dots. The pen file shows only the `recording` state and drops the paused / processing / cap-approaching states that the code has today (Q3–Q5).

---

## 2. Layout top → bottom

Coordinates are absolute within the 402 × 874 frame (x, y, w × h). Horizontal centre of the frame is x = 201.

### 2.0 Frame
- 402 × 874, corner radius 32, fill `#fbfffc` (page background; **off-palette** — nearest Neutral is none; it is a green-tinted near-white).
- Content column: `Frame 1707479478` at (30, 130) 342 × 586.25 — vertical auto-layout, **gap 65**, items centred, horizontal constraint CENTER. Side gutters are therefore **30 pt** (31 pt for the nav row).

### 2.1 Status bar (system, Light)
- `Status Bar` instance (0, 0) 402 × 52.
- Time "9:41" vector 28.43 × 11.09 at (38, 23), fill `#212529` (grey-500).
- Status icons row at (301, 20) 69 × 14, gap 4: cellular 20 × 14 (empty bar opacity 0.18), Wi-Fi 16 × 14, battery 25 × 14 (outline + cap opacity 0.6, fill 19 × 8 r 1). All `#212529`.
- Treat as system chrome; not part of the SwiftUI spec.

### 2.2 Nav row — back pill
- `Container` (31, 77) 340 × 42.6 — horizontal auto-layout, `SPACE_BETWEEN`, gap 95.7, items centred.
- `Frame 1` (horizontal, gap 7) holds:
  - **Back pill** `Background+Border` (31, 77) **42.6 × 42.6**, corner radius 21.3 (circle), fill `#ffffff`, stroke **1.065 pt `#e4ece4`** inside (off-palette light green-grey). No shadow.
    - Icon `vuesax/outline/arrow-left` 20 × 20 at (42.3, 88.3); the visible chevron path is 7.16 × 14.45 at (48.26, 91.08), fill `#1e6725` (green-700).
  - `Frame 2 › Container` (80.6, 87.3) 128 × 22 — **empty title slot**, no text.
- Gap from pill bottom (119.6) to prompt card top (130): **10.4 pt**.

### 2.3 Prompt card ("How’s Your Mode?")
- `Background` (30, 130) **342 × 98.25**, corner radius **18**, fill `#ffffff`, stroke **0.5 pt `#000000` @ 10 %** inside, drop shadow **(0, 4) blur 8, `#183c28` @ 8 %** (HTML-lite renders it as `0 4px 7px #183c2814`).
- Padding **15** on all sides; vertical auto-layout, gap 15, centred.
- Inner stack `Frame 1707479471` (87, 145) 228 × 68.25 — vertical, **gap 11**, centred:
  - Text block `Frame 1707479476` 228 × 50 — vertical, **gap 6**, centred:
    - **Title** "How’s Your Mode?" — 212 × 29 at (95, 145); Inter **24 / Medium (500)**, auto line-height, letter-spacing 0, `#17501d` (green-800). Single line, no wrap.
    - **Subtitle** "Heavy, Light, Flat, Bright- Whatever Fits" — 228 × 15 at (87, 180); Inter **12 / Medium (500)**, `#6a6d70` (grey-300).
  - **Page dots** `Frame 1707479475` 52.25 × 7.25 at (174.875, 206), horizontal, **gap 4**: five circles **7.25 pt**; dot 1 `#2a9134` (green-500, active), dots 2–5 `#bdddc0` (green-100, inactive). Row is centred on x = 201.
- Card bottom y = 228.25.

### 2.4 Recording ring (gap 59 below the card)
- `Group 735` **(27.5, 287.25) 347 × 347**, centred at (201, 460.75). Group drop shadow **(0, 2) blur 18, `#000000` @ 8 %** (HTML-lite: `0 2px 7.875px #00000014`). Overhangs the 342 column by 2.5 pt each side.
- **Track / disc** `Frame 1707479517` 347 × 347, corner radius 173.5, fill **`#ebf8ee`** (off-palette; green-50 is `#eaf4eb`), stroke **21.33 pt `#bdddc0`** (green-100) inside. Vertical auto-layout, **gap 9.204**, both axes centred.
  - **Timer** "0:07" — 154 × 87 at (124, 363.65); Inter **72 / Medium (500)**, auto line-height, `#17501d` (green-800), vertical align centre. (JSON lists strokeWeight 2.55 OUTSIDE but no stroke paint — ignore.) 72 pt is **outside the DS type scale** (12–40 pt).
  - **Button stack** `665_frame` (48.83, 459.85) 304.34 × 98 — vertical, **gap 8**, centred, clipsContent true:
    - **Stop & Save** (125, 459.85) **152 × 44** — see §3.
    - **Cancel** (155.5, 511.85) **91 × 46** — see §3.
- **Progress arc** `Ellipse 8` 347 × 347 over the same bounds, z-above the disc: fill = linear gradient, **vertical** (gradientTransform is a 90° rotation; HTML `180deg`): `#26842f` @ 0 % (top) → `#3fbb4b` @ 50 % → `#25832e` @ 100 % (bottom). Clipped to an annulus **20.82 pt** wide (outer R 173.5, inner R 152.68) that starts at **3 o'clock (0°)** and sweeps **clockwise on screen to the 11 o'clock position (122.4° in math coordinates) = 237.6° = 66.0 %**. End caps are **flat radial cuts (butt)**, not rounded. Remaining 34 % shows the `#bdddc0` track.
- Ring bottom y = 634.25.

### 2.5 Hint line (gap 65 below the ring)
- `Frame 1707479477` (30, 699.25) 342 × 17.
- "Take Your Time, Speak Freely." — full width 342 × 17; Inter **14 / Medium (500)**, `#6f7f75` (**off-palette** greenish grey; grey-300 is `#6a6d70`), **centre-aligned**.

### 2.6 Below the fold — nothing
- Empty from y 716.25 to 840 (**123.75 pt** of unused space above the home indicator). No tab bar, no FAB.
- `Home Indicator` instance (0, 840) 402 × 34; bar 143 × 5, r 10, `#212529` at (129, 861).

### 2.7 Vertical rhythm summary
`status 52` → `25` → `back pill 42.6` → `10.4` → `card 98.25` → `59` → `ring 347` → `65` → `hint 17` → `123.75 free` → `home 34`.

### 2.8 Palette cross-reference (DS Frame 5)
| Hex | Token | Used for |
|---|---|---|
| `#17501d` | green-800 | title, timer |
| `#1e6725` | green-700 | back chevron |
| `#26842f` | green-600 | Cancel label; arc gradient top |
| `#2a9134` | green-500 | Stop & Save fill; active dot |
| `#bdddc0` | green-100 | ring track; inactive dots |
| `#6a6d70` | grey-300 | card subtitle |
| `#212529` | grey-500 | status bar, home indicator |
| `#fbfffc` | — off-palette | page background |
| `#ebf8ee` | — off-palette (≈ green-50 `#eaf4eb`) | ring disc |
| `#3fbb4b` | — off-palette | arc gradient mid |
| `#25832e` | — off-palette (≈ green-600, off by 1) | arc gradient bottom |
| `#6f7f75` | — off-palette (≈ grey-300) | hint text |
| `#e4ece4` | — off-palette | back pill stroke |
| `#cbd5e1` | — off-palette (Tailwind slate-300) | Outlined button stroke (inherited from DS Button) |
| `#183c28` @ 8 % | — | card shadow tint |

---

## 3. Component instances & visible states

| # | Instance (pen layer) | DS component / variant | Visible state on this screen | Notes |
|---|---|---|---|---|
| 1 | `Status Bar` | DS instance, Light | 9:41, full signal, Wi-Fi, full battery | system |
| 2 | `Home Indicator` | DS instance | default | system |
| 3 | `Background+Border` + `vuesax/outline/arrow-left` | **not a DS component** (ad-hoc, repeated on A and C) | Default | "Back pill": 42.6 circle, white, 1.065 `#e4ece4` stroke, chevron `#1e6725`. Recommend promoting to a component. |
| 4 | `Background` (prompt card) | **not a DS component** | prompt **1 of 5** | white card r 18, 0.5 pt 10 % black stroke, tinted shadow |
| 5 | `Ellipse 2…6` | **not a DS component** | dot 1 **active** `#2a9134`, dots 2–5 **inactive** `#bdddc0` | 7.25 pt, gap 4 |
| 6 | `Group 735` (disc + track + arc) | **not a DS component** (shared with A: 347 pt; C: 211 pt) | arc at **66 %** (step 2 of 3) | track 21.33 `#bdddc0`, arc 20.82 gradient, butt caps |
| 7 | `Button / Filled` "Stop & Save" | **Button / Filled · Size=Medium · Icon=With Icon · State=Default** | Default (enabled) | fill `#2a9134`, r 999, padding 10 / 18, gap 8, label 16 / Medium / lh 24 `#ffffff`; icon slot 16 × 16 at (18, 14) |
| 8 | `Button / Outlined` "Cancel" | **Button / Outlined · Size=Medium · Icon=Without Icon · State=Default** | Default (enabled) | fill `#ffffff`, stroke 1 `#cbd5e1`, r 999, padding 10 / 18, label 16 / Medium / lh 24 `#26842f` |
| 9 | Hint text | plain text | — | 14 / Medium `#6f7f75` |

**DS button states available (Frame 3) for the two instances — for the implementer's state map:**
- Filled: Default `#2a9134` · Hovered `#1e6725` · Focused `#17501d` · Disabled fill `#e5e7eb`, label `#9ca3af`.
- Outlined: Default white / stroke `#cbd5e1` / label `#26842f` · Hovered fill `#f8fafc`, stroke `#2a9134` · Focused stroke `#26842f` · Disabled fill `#f8fafc`, stroke `#e2e8f0`, label `#94a3b8`.
- The DS has no "Pressed" or "Loading" state; see Q11.

**Size note.** Filled renders **44** pt tall (10 + 24 + 10) while Outlined renders **46** pt (label at y 11) — the 1 pt stroke is being drawn outside on the Outlined instance in Pencil. Both should be 44 in code (Q15).

**Not on this screen:** `Navigation` tab bar (any `Status=` variant), `Add Button`, `Bill-shape` chips (solid / outline / with-dot), any Glyph (`energy-*`, `focus-*`, `mood-*`, `sleep-*`).

**Clipping / horizontal scroll:** none. No row is cut at the frame edge.

---

## 4. Copy inventory (verbatim) & copy issues

### 4.1 Copy inventory
| # | Node | String (verbatim) | Style |
|---|---|---|---|
| 1 | status bar | `9:41` | system placeholder |
| 2 | `72:16402` | `How’s Your Mode?` (apostrophe is U+2019) | 24 / 500 `#17501d` |
| 3 | `72:16403` | `Heavy, Light, Flat, Bright- Whatever Fits` | 12 / 500 `#6a6d70` |
| 4 | `72:16412` | `0:07` | 72 / 500 `#17501d` |
| 5 | `I72:16414;27:1087` | `Stop & Save` | 16 / 500 `#ffffff` |
| 6 | `I72:16415;27:1139` | `Cancel` | 16 / 500 `#26842f` |
| 7 | `72:16418` | `Take Your Time, Speak Freely.` | 14 / 500 `#6f7f75` |

### 4.2 Typos & inconsistencies
1. **"Mode" → "Mood".** The hint lists mood adjectives and the shipping copy is `"How's your mood?"` (`CheckInViewModel.nudgePrompts[0]`). Almost certainly a typo.
2. **"Bright- Whatever Fits"** — hyphen glued to "Bright" with a space after. The shipping hint is `"Heavy, light, flat, bright — whatever fits."` (spaced em dash, sentence case, full stop). Pen drops all three.
3. **Title Case on sentences** — "Take Your Time, Speak Freely.", "Heavy, Light, Flat, Bright- Whatever Fits". Apple HIG and the current app use sentence case for body/hint copy. Same pattern on screen A ("Take A Moment To Check In With Yourself", "A few Words Is Enough" — which also has a lowercase "few" and a grammar slip). Needs a one-time casing decision (Q14).
4. **Trailing punctuation inconsistent** — hint has a full stop; the card subtitle has none; screen A's hint has none.
5. **Layer hygiene** — the stop icon's slot is still named `vuesax/linear/user` (component placeholder) in the HTML export; the instance is `vuesax/outline/stop` but renders as a solid square (see §5). Cosmetic, but it will confuse anyone reading the pen file.
6. **"Stop & Save"** — ampersand in a button label; acceptable, but the rest of the flow spells words out ("Speak Check-In", "Log Medications"). Flagging for consistency, not as an error.
7. **Apostrophe** — `How’s` uses the typographic U+2019; keep that consistently (the code uses a straight `'`).

---

## 5. Glyph & icon usage

**Signal glyphs (DS Frame 12: energy bolt / focus target / mood sprout / sleep moon):** **none** on this screen.

**UI icons:**
| Icon | Pen layer | Style as named | Style as rendered | Size / colour | SF Symbol equivalent |
|---|---|---|---|---|---|
| Back chevron | `vuesax/outline/arrow-left` | Iconsax **outline** | outline (single chevron path, no shaft) | 20 × 20 box, path 7.16 × 14.45, fill `#1e6725` | `chevron.left` |
| Stop | `vuesax/outline/stop` inside the Button icon slot | Iconsax **outline** | **solid white rounded square** — the 16 × 16 instance container has fill `#ffffff`, corner radius **4**; the inner white vector is invisible on it | 16 × 16, `#ffffff` | `stop.fill` |

- The icon set for the whole pen file is **Iconsax ("vuesax/…")**; the app's rule is native SF Symbols. Map, don't embed (Q9/Q13).
- System glyphs only otherwise (cellular, Wi-Fi, battery, home indicator).

---

## 6. Data the screen implies

| Field | Type / values | Shown as |
|---|---|---|
| `elapsed` | `TimeInterval`, count-up from 0 | `"0:07"` → `m:ss`, minutes without leading zero, seconds zero-padded (`0:07`, `1:23`, `12:05`). No hours. |
| `promptIndex` | `0…4` (5 prompts) | active dot; card title + subtitle |
| `prompt` | `{ question, hint }` | title 24 pt, subtitle 12 pt |
| `flowStep` | `1…3` (idle / listening / saved) | ring arc 33 % / **66 %** / 100 % |
| `recordingState` | `.recording` (this screen). Code also has `.paused`, `.processing`, `.done`, `.idle` — no pen variants | timer + buttons |
| `maxDuration` | exists in code (`LayoutConstants.maxRecordingDuration`) | **not represented** in the pen |
| audio level | — | **not represented** (no waveform / pulse) |
| date | shown on A ("Saturday, Sept 11"), **not** on B | — |

No medication, sleep hours, month selector, percentages or counts on this screen.

---

## 7. Interactions implied

| Target | Size | Action | Confidence |
|---|---|---|---|
| Back pill | 42.6 × 42.6 (**< 44 pt** minimum) | pop / dismiss the flow. Unclear whether it equals Cancel, prompts a confirm, or is disabled while recording | low → Q6 |
| **Stop & Save** (primary) | 152 × 44 | stop the recorder, persist the check-in, run transcription + extraction, push **C · Check-In Saved** | high |
| **Cancel** (secondary) | 91 × 46 | discard the recording and return to **A** | medium — no confirm shown → Q6 |
| Prompt card | 342 × 98.25 | dots imply paging through 5 prompts. Code today **auto-advances on a timer** (`promptInterval`, `PromptPace`); no swipe. Pen doesn't show a progress bar or affordance | low → Q7 |
| Timer | — | ticks each second; VoiceOver live region ("Recording, 0:07 elapsed" as today) | high |
| Ring | — | static at 66 % on this step; whether it animates on step change or "breathes" while listening is unspecified | low → Q2 |
| Scroll | — | none; fixed layout | high |
| System | — | interactive-pop swipe from the left edge would end the recording silently unless blocked | → Q6 |

Accessibility notes to carry into the plan (WCAG ratios measured from the hex values, not the DS chart):

| Pair | Ratio | Verdict |
|---|---|---|
| title `#17501d` on card `#ffffff` | 9.54:1 | pass |
| subtitle `#6a6d70` on card `#ffffff` (12 pt) | 5.21:1 | pass AA (size still below the 13 pt floor — Q12) |
| timer `#17501d` on disc `#ebf8ee` | 8.72:1 | pass |
| **Stop & Save label `#ffffff` on `#2a9134` (16 pt Medium)** | **4.04:1** | **fails AA for normal text** (needs 4.5; passes only as large/bold) — the DS chart marks green-500 "AA" for white text, which is the large-text threshold — Q19 |
| Cancel label `#26842f` on `#ffffff` | 4.75:1 | pass |
| **hint `#6f7f75` on page `#fbfffc` (14 pt)** | **4.19:1** | **fails AA** — Q19 |
| back chevron `#1e6725` on `#ffffff` | 6.95:1 | pass |
| active dot `#2a9134` vs inactive `#bdddc0` (non-text) | 2.74:1 | below the 3:1 UI-component guideline |
| arc mid `#3fbb4b` vs track `#bdddc0` (non-text) | 1.69:1 | the step indicator's filled/unfilled distinction is weakest exactly at the brightest point of the gradient |
| arc ends `#26842f` vs track `#bdddc0` | 3.23:1 | pass (UI) |
| track `#bdddc0` vs disc `#ebf8ee` · Cancel stroke `#cbd5e1` vs disc · back-pill stroke `#e4ece4` vs page | 1.35 / 1.36 / 1.19 | decorative only; fine if nothing depends on them |

Other notes: 72 pt timer inside a fixed 347 pt ring (Dynamic Type headroom is limited); back pill under 44 pt; no visual "mic is live" feedback beyond the timer.

---

## 8. Open questions / ambiguities for the owner

1. **"How’s Your Mode?"** — confirm it is a typo for **Mood** and that the shipping hint copy (spaced em dash, sentence case) wins over the pen's `Bright- Whatever Fits`.
2. **Ring semantics.** Evidence says it is a **3-step flow indicator** (33 % → 66 % → 100 % across A/B/C). Confirm; and say whether it should animate between steps, "breathe" while listening (old DESIGN.md had crescent breathing), or stay static. If it were meant to track elapsed time it would need a cap value.
3. **Recording cap.** Code has `maxRecordingDuration` and an "approaching cap" state; the pen shows nothing. Does the timer change colour, does the arc fill, does Stop & Save auto-fire?
4. **Paused / interrupted state.** Code dims the ring and shows "Paused" on an audio interruption (no user pause). The pen has no paused variant — reuse today's treatment, or design one?
5. **Processing state between B and C.** Whisper + MLX take seconds. Does Stop & Save go to the DS **Disabled** look (`#e5e7eb` / `#9ca3af`), show a spinner, or does C appear immediately with a "Saving…" state? No pen screen exists.
6. **Cancel / back / swipe-back.** Immediate discard or confirm dialog? Is the back pill the same as Cancel? Should the edge-swipe pop be blocked while recording so a stray gesture can't lose the take?
7. **Prompt carousel behaviour.** Timed auto-advance as today (`PromptPace` setting), user swipe, or both? The pen shows only prompt 1 of 5 and no progress bar; the other 4 prompts are assumed to reuse the same card.
8. **Live-mic feedback.** Nothing on screen shows audio is being captured. Intentional minimalism, or should the ring/dots respond to level?
9. **Typeface.** The pen is set in **Inter**; the app rule is native SF app-wide. Plan assumes SF with the pen's sizes/weights — confirm once for the whole design system.
10. **Off-palette colours.** `#fbfffc`, `#ebf8ee`, `#3fbb4b`, `#25832e`, `#6f7f75`, `#e4ece4`, `#cbd5e1`, `#183c28` are not in Frame 5. Add them as named tokens, or snap to nearest (green-50, green-600, grey-300)?
11. **Button state map.** DS provides Default / Hovered / Focused / Disabled. iOS needs **pressed**: use Hovered colours for pressed, or Focused?
12. **12 pt subtitle** — below the iOS 13 pt floor and borderline AA on white. Bump to 13–14 pt?
13. **Stop glyph** — keep the **solid white rounded square** as rendered (`stop.fill`), or the Iconsax outline stop the layer is named after?
14. **Casing policy.** Title Case for every word of body/hint copy, or sentence case (current app + HIG)? Affects A, B and C.
15. **Outlined button height** — 46 pt in the pen vs 44 for Filled; treat both as 44 with an inside stroke?
16. **Dark mode** — no dark variant exists in the pen (status bar is `Mode=Light` only). Derive, or defer?
17. **Back pill hit target** — 42.6 pt; bump to 44 (and promote the pill to a DS component since A, B and C all use it)?
18. **Unused bottom space** — 124 pt empty above the home indicator. Deliberate breathing room, or should the hint sit lower / the ring larger on taller phones?
19. **Contrast of the primary CTA and the hint.** "Stop & Save" (white on green-500 `#2a9134`, 16 pt Medium) measures **4.04:1** and the hint (`#6f7f75` on `#fbfffc`) **4.19:1** — both under WCAG AA 4.5:1 for normal text. Options: fill the Filled button with green-600 `#26842f` (4.75:1 — same value the DS already uses for the Outlined label), or make the label Semi Bold/18 pt so it qualifies as large text; move the hint to grey-300 `#6a6d70` (5.21:1). This affects every Filled button in the file, so it is a design-system decision, not a screen one.
