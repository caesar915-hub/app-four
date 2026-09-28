<!-- Created: 2026-06-18 12:13 (WEST) · Updated: 2026-09-28 14:24 (WEST) -->
# Design System — Squirl

> **Status: planning draft, 2026-09-27.** This document replaces the Paper & Pollen / New Look `DESIGN.md`. It is derived from the Pencil file `untitled.pen` and its exports; nothing in it has been implemented. **No Swift changes are authorised by this document.** Every value is quoted from the pen (hex lowercase as exported, pt at 1x). Where the pen is ambiguous or silent the entry says so and names the owner decision; nothing is invented to fill a gap. Blocks marked **OWNER DECISION** are undecided.
>
> Conventions: `filled / outlined / underline` are the pen's button families; "Bill-shape" is the pen's chip; "Navigation" is the pen's tab bar; level names follow the pen's asset names `low / flat / okay / good / great` (1→5); `@0.10` = alpha; "Frame 5" etc. = design-system frames in the pen. Proposed Swift symbols are **proposals** for the token pass and are **identical to `UI_REFRESH_PLAN.md` §3.1 / §3.2**: the semantic namespaces `Surface` / `Ink` / `Accent` / `Stroke` / `Elevation` (new files beside the primitive `Palette.violet50 … grey900` ramps, so the existing `Palette` enum is not overloaded), plus `Typography`, `Spacing`, `Radius`, `Metrics`, `Motion`, `Icons` and the component names of §8. A name changed in one document must change in the other on the same day. They are not code.

---

## 1. Source of truth

| | |
|---|---|
| Design file | `untitled.pen` (Pencil, pen.dev). **Location not in the repo** — it lives in the owner's Pencil workspace; the repo holds only the 8 screen SVGs under `outsource_design/` (`iPhone 17 - 1/4/5/6/7/16/18/19.svg`, untracked at the time of writing). Owner to confirm whether the `.pen` or the exports get committed (proposal: `docs/design/pen/`). |
| Section in the pen | "Design System & Components" (frames 1–15) + the 8 screen frames named `iPhone 17 - N`. |
| Reading it | `.pen` files are encrypted — **never `Read`/`grep` the file**. Use the `pencil` MCP: `get_app_state` to confirm the open document, `read_skill` for the schema, `execute` to read a node subtree by id (the ids below), `get_style` for a node's resolved style. Load the MCP only for planning (SPECKIT "MCP hygiene"); drop it after `/speckit-plan`. |
| Evidence used for this document | The Pencil exports of **2026-09-27** (2× PNG renders of the 15 design-system frames and the 8 screens, the HTML-lite layer dumps) and the **Figma copy** of the same design (exact fills, fonts, radii, bounds; the ids in §1.1 are Figma ids). **Committed location (UI-01, Q80):** the SVG/PNG/JSON exports go to `docs/design/pen/`; the per-screen specs and the code cross-checks that this document quotes go to `specs/057-ui-refresh/research/` with UI-05. Until those commits exist the evidence files are **not in the repo** and every value below is quoted from the 2026-09-27 exports and the Figma node ids in §1.1 — no session-temporary path is a reference. |
| Variables | The pen defines **no variables**; every value is a literal. The Figma copy carries four small collections (`Button Tokens`, `Tiimo Colors`, `Variable collection / BG_Color`, `Squirl Tokens / color/mood/base-5`) — reference only; where a variable contradicts what is drawn, **the drawn literal wins** (e.g. outlined label `#111827` in the variable vs `#26842f` drawn). |
| Header stamp | This file keeps the path's original `Created` (2026-06-18, `git log --diff-filter=A -- DESIGN.md`) and bumps `Updated`: git records a same-path rewrite as a modification, the CLAUDE.md recovery command returns 2026-06-18 whatever the commit shape, and the path's 79 inbound references persist. The rewrite is an **edit**, not a new file (**D-P1** — recommendation; if the owner rules "new file", the override is written into this header comment itself so the recovery command is knowingly overridden). |

### 1.1 Node ids

| Frame | Pen node id | Figma id | Content |
|---|---|---|---|
| Frame 2 · Typography | `p83Lsy` | `19:9346` | Inter size × weight matrix 12–40 pt |
| Frame 3 · Buttons | `rID8G` | `19:9526` | Filled / Outlined / Underline × Small / Medium / Large × with/without icon × 4 states |
| Frame 4 · Navs | `y0xDU` | `19:9713` | `Navigation` tab bar, variants `Status=Calendar \| Check In \| Insights \| Settings, Mode=Light` |
| Frame 5 · Color palettes | `b4r29B` | `19:9821` | violet / green / neutral 50–900 with printed contrast |
| Frame 12 · Glyphs | `aGI5B` | `77:10423` | energy bolt · focus target · mood sprout · sleep moon, 5 levels each |
| Frame 15 · Design Components | `zIcKO` | `53:10311` | Bill-shape chip ×3 + Add Button |
| Frame 1 · Icon Set (not in the brief) | `UiyeH` | — | vuesax/Iconsax library strip (≈1,030 names × 4 styles), see §7.1 |
| iPhone 17 - 4 · Check-In A idle hub | `iIaeI` | `72:16335` | §15.1 |
| iPhone 17 - 5 · Check-In B listening | `XXA5N` | `72:16377` | §15.2 |
| iPhone 17 - 6 · Check-In C saved | `fmQEp` | `72:16419` | §15.3 |
| iPhone 17 - 19 · Mood Journal (Calendar tab) | `nDRZv` | `78:11944` | §15.4 |
| iPhone 17 - 1 · Day Mode Details | `v7jzk` | `78:11720` | §15.5 |
| iPhone 17 - 18 · Edit Check-In | `hSrrZ` | `78:11274` | §15.6 |
| iPhone 17 - 7 · Statistics (Insights tab) | `xjEsl` | `78:10620` | §15.7 |
| iPhone 17 - 16 · Settings | `IoBoz` | `72:10008` | §15.8 |

Artboards are 402 × 874 (iPhone 17 class); Mood Journal (1131), Edit (1774), Insights (2144) and Settings (1899) are unrolled scroll canvases with the floating chrome parked at the bottom. Frame corner radius 32 is the device mask, not UI.

---

## 2. Product Context

- **What:** on-device, privacy-first iOS journal. The user voice-logs (or types) a daily check-in in under a minute; the app transcribes it (**WhisperKit**, `openai_whisper-small`) and extracts structured signals (mood, energy, focus, sleep, medications, side-effects, emotions) with an **on-device LLM** (`mlx-community/Qwen2.5-1.5B-Instruct-4bit` via MLX, two-pass: narrative summary → strict-JSON signals), then surfaces personal patterns. Extraction is probabilistic, so every inferred value must render as *reviewable and correctable*, never as settled fact. The pen keeps this visible: the day-detail summary carries an on-device-AI attribution line and a "tap to correct" affordance; every signal is one screen from its edit picker.
- **Who:** ADHD adults. The audience is a *functional* constraint, not flavor — low cognitive load, minimal friction, no overwhelm, fast/clear reward.
- **Platform:** SwiftUI, iOS 26. Tokens live in `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/` (`Palette`, `Typography`, `Spacing`, `Radius`, `Metrics`, `Motion`, `Haptics`, `Icons`). Note: custom chrome (tab bar, FAB, nav pills, cards) is **opaque** per the pen. System-presented surfaces — sheets, menus, alerts, pickers, native toggles, RevenueCatUI paywall / Customer Center — keep their iOS 26 Liquid Glass appearance, tinted `Accent.primary`; they are not restyled and are not deviations (§9.5).
- **North star (the one thing to remember):** **effortless** — in and out in under a minute, the app always slightly calmer than you.

---

## 3. Aesthetic direction (as the pen draws it)

- **Light, airy, green.** Ground is a faintly green white (`#fbfffc`), every surface is a pure-white card (`#ffffff`) with a 0.5 pt `#000000@0.10` hairline and a soft green-black shadow (`#183c28@0.08`). Radii are large (cards 24 / 18 / 12; every control a pill). Nothing is textured; nothing is translucent.
- **One brand green, deep for text, mid for action.** Titles are green-800 `#17501d`; primary buttons, selected chips, toggles, active tab pill and status words are green-500 `#2a9134`; outlined labels and chevrons are green-600/700. Hierarchy is carried by weight and colour, almost never by size — only four text sizes above 16 pt exist in the whole app (18, 20, 24, 34) plus the 72 pt timer.
- **Violet is the second accent.** The `+` Add Button, the medication capsule tile, the medication-bar fill, the AI sparkle, the Connections lock tiles and the sleep moon are all violet (`#8c68d3` / `#4d3974` / `#f4f0fb`). Violet is no longer medication-only (§13.1 checklist).
- **Illustrated signal glyphs, not icons.** Four multi-colour vector glyphs (sprout, bolt, target-with-arrow, moon-with-star), five levels each; amber `#eda94a` and blue `#4278a8` appear only inside these glyphs and their value labels — there is no amber or blue palette ramp.
- **Two chrome pieces float:** a white pill tab bar (60 pt, r 75) on a green-black shadow (`#183c28@0.16`) and a violet 50 pt FAB on a **black** shadow (`#000000@0.17`; D-S4 proposes one tint); pushed screens use a circular white "back pill" instead of a system bar.
- **Copy is Title Case everywhere**, including full sentences ("Take A Moment To Check In With Yourself") — a file-wide convention that conflicts with HIG sentence case (OWNER DECISION §15.0).
- **Chips are everywhere**: emotions, side effects, doses, sleep, settings options and the Insights legend all use one 27 pt "Bill-shape" pill.
- **What the pen does not draw:** dark mode, disabled controls, destructive actions, error/empty/loading states, motion, pressed states, a paywall, onboarding, the type-note composer, the medication log sheet.

---

## 4. Color

### 4.1 Palettes (Frame 5)

Three ramps, 50→900. Contrast figures are exactly the ones printed on the swatches (WCAG 2.x against `#000000` / `#ffffff` text; "—" = no grade printed). **Threshold note:** WCAG's "large text" is 18 pt regular / 14 pt bold in *typographic* points (≈ 24 px / 18.7 px at 96 dpi); an iOS point ≈ 1 CSS px, so on iOS large text starts at **≈ 24 pt regular / ≈ 19 pt semibold-or-bolder**. Every role in §5.2 below that line — 16/500 button labels, 18/600 nav titles, 14/500 bubble labels, all 12-pt captions — is **small text** with a 4.5:1 floor; the "large" grades printed on the swatches apply only to the 34 pt page title, the 24 pt prompt title and the 72 pt timer. Proposed primitive symbols: `Palette.violet50 … violet900`, `Palette.green50 … green900`, `Palette.grey50 … grey900` (package-internal; views use the semantic roles in §4.2).

**Violet**

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

**Green**

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

**Neutral** (the pen names the column "Neutral" and the tokens `grey-*`)

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

Reading the table correctly: the *white-text* column is the ratio of white on the swatch **and, symmetrically, of the swatch as text on white**. So grey-300 `#6a6d70` as caption text on white is **5.21 (AA)** — the "4.03" is black-on-grey-300 and does not apply to grey text. Green-500 `#2a9134` as 12 pt text on white, and white text on a green-500 fill, are both **4.04 — AA for large text only**.

### 4.2 Semantic roles (derived from the 8 screens)

Light values only (the pen has no dark values — §11). "Today" = the shipping token the role replaces. The **symbol column is PLAN §3.1 verbatim** (`Surface` · `Ink` · `Accent` · `Stroke` · `Elevation`); it is the cross-reference that keeps the two documents from drifting.

| Role | Proposed symbol | Hex (light) | Palette | Used for | Today |
|---|---|---|---|---|---|
| Screen ground | `Surface.screen` | `#fbfffc` | off-palette (Figma `BG_Color`) | every screen | `NewLook.screen` `#EFF2EB` |
| Card surface | `Surface.card` | `#ffffff` | — | all cards, tab bar, pills, outline chips | `NewLook.card` `#FFFFFF` |
| Card hairline | `Stroke.card` | `#000000@0.10` @ 0.5 pt | — | card borders (day-details, insights, settings, journal, prompt card) | none (New Look forbade card borders) |
| Card hairline (alt) | `Stroke.chip` | `#e4ece4` @ 1 pt | off-palette | outline chips, nav pills, expand pills, edit "How Did You Feel?" card | `NewLook.hairline` `#DBDDDE` |
| Row divider | `Stroke.separator` | `#000000@0.10` @ 1 pt | — | in-card separators | `Divider` + hairline |
| Ink · brand / page title | `Ink.title` | `#17501d` | green-800 | page titles 34/600, nav titles 18/600, prompt title 24/500, timer 72/500, "Great", "Concerta · 36 mg", selected calendar disc | `NewLook.inkPrimary` `#1C1B1F` |
| Ink · primary | `Ink.primary` | `#212529` | grey-500 | section titles 16/600, row titles, times, dates, chip labels on Insights | `NewLook.inkPrimary` |
| Ink · primary variants (collapse) | `Ink.chip` (`#193024`, collapsed into `Ink.primary` unless the owner objects) | `#1e2225` · `#292d32` · `#1c1b1f` · `#193024` | grey-600 · — · — · — | day-details labels/transcript; row labels (edit/insights/settings); bubble labels + field labels; chip text + "70%" | **OWNER DECISION D-C6:** collapse the five near-identical inks (`#212529 #1e2225 #292d32 #1c1b1f #193024`) to one `Ink.primary` (proposal: grey-500 `#212529`; chip text keeps `#193024` only if the owner wants the green-black tint) |
| Ink · secondary | `Ink.secondary` | `#4d5154` | grey-400 | captions 12/500 (medication name, "24 check-ins", weekday letters, previous-day signals, toggle labels), "03:24" | `NewLook.inkSecondary` `#8A8A8E` (owner-accepted AA failure 2026-07-12 — **retired by this palette**) |
| Ink · tertiary | `Ink.tertiary` | `#6a6d70` | grey-300 | subtitles 16/500, 14/400 descriptions, 12/400–500 captions, rhythm captions 11/500, unselected segment labels | — |
| Ink · tertiary (green-grey) | `Ink.nav` | `#6f7f75` | off-palette | nav subtitles ("Monday, Jun 29", "Saturday, Sept 11"), "A few Words Is Enough", "Low / High", date-field icons | **D-C7:** 4.19:1 on `#fbfffc` — fails AA at 12–14 pt; proposal: `Ink.nav` = grey-300 `#6a6d70` (5.16:1 on ground), i.e. the token exists but is retuned (PLAN D14) |
| Ink · placeholder | `Ink.placeholder` | `#8a8a8e` | off-palette | "Written by on-device AI…" 12/400, rhythm "—" | **D-C6b:** this is the exact `NewLook.inkSecondary` value whose AA failure was accepted 2026-07-12 (3.44:1); proposal: retire the value, `Ink.placeholder` = grey-300 |
| Calendar strip greys | — | `#717680` (day names) · `#414651` (numbers) | off-palette (Untitled-UI greys) | week strip only | **D-C8:** snap to grey-300 / grey-400 |
| Accent · primary | `Accent.primary` (non-text uses: ring arc, dots, icons, bars) · `Accent.primaryFill` (text-carrying fills — green-600 `#26842f` if D-C3 = (b), PLAN D14) | `#2a9134` | green-500 | filled buttons, active tab pill, selected chips, toggles ON, radio ON, status words ("Active / Kicking In / Installed"), level captions, mood-row bar | `Theme.meadowGreen` `#5F8A4C`, `NewLook.selection` `#54B492`, `NewLook.checkInGreen` `#5FB36E` — **all three retired** |
| Accent · pressed | `Accent.pressed` | `#1e6725` | green-700 | Frame 3 "Hovered" (→ iOS pressed), back chevron, ellipsis dots, selected segment label, mood word "Okey" | — |
| Accent · deep | `Accent.deep` | `#17501d` | green-800 | Frame 3 "Focused" fill (no iOS equivalent) | — |
| Accent · text (outlined) | `Accent.primaryText` | `#26842f` | green-600 | outlined / underline labels ("Write Notes", "Cancel"), expand chevrons, arc gradient start | — |
| Selected chip | `Accent.primaryFill` fill + stroke, `Ink.onAccent` `#ffffff` text | | green-500 drawn (green-600 under D-C3 (b)) | emotion / dose / side-effect / sleep / prompt-length / blocked-for chips | `NewLookChipRole.*` |
| Violet · action (FAB) | `Accent.violet` | `#8c68d3` | violet-500 | Add Button, play button, played waveform bars, medication-bar gradient end, capsule icon in "Log Medications", moon fill | `Palette.medication` `#7E5CA8` → **aliased to `Accent.violet` (violet-500) in UI-06**, never to violet-800 — 17 sites (chips, tags, sticker, the `MedicationBarView:150` gradient start, `NewLookChipRole.medication`) must not go dark on day one (PLAN §3.1, identical mapping) |
| Violet · medication glyph | `Accent.violetDeep` | `#4d3974` | violet-800 | capsule inside its tile, unlock icon — used **only** inside `MedicationBadge` / `CapsuleGlyph` | — |
| Violet · medication tint | `Surface.medicationTint` | `#f4f0fb` | violet-50 | capsule tile 26–28 ⌀, locked-connection tile, confirmation preview row | — |
| Violet · unlocked tile | `Surface.connectionUnlocked` | `#e3d8f9` | off-palette | unlocked connection tile | — |
| Violet · eyebrow | `Accent.connection` | `#7f5fc0` | violet-600 | "MEDICATION × FOCUS" 12/600, lock icon, AI sparkle | — |
| Violet · label on white (button) | — | `#634a96` | violet-700 | "Log Medications" label | a colour variant Frame 3 does not define (**D-B1**) |
| Medication bar gradient | `Accent.medicationBarGradient` | `#8061bf → #8c68d3` (horizontal) | off-palette → violet-500 | dose progress fill, connection bar — drawn by `ProgressTrack`; `Palette.medicationFillEnd` aliases the `#8c68d3` end-stop | `Palette.medication → medicationFillEnd` |
| Success / installed | — | `#2a9134` 8 ⌀ dot + 12/500 text | green-500 | Settings "Installed" | `Theme.statusDone` |
| Destructive | — | **none drawn** | — | no delete, no red control anywhere (only reds are mood-1 colours) | `Theme.danger` `#B5503A` — **D-C10:** a destructive style must be defined (Clear All Data, delete check-in) |
| Tab bar inactive icon | `Ink.tabInactive` | `#999b9d` | grey-200 | Navigation — 2.79:1, raised to grey-300 `#6a6d70` under D-C3/PLAN D14 | system tint |
| Toggle OFF / ON | — (native `Toggle`, D-K5/PLAN D22: ON = `.tint(Accent.primaryFill)` **green-600**, OFF = system track) | `#babbbd` OFF · `#2a9134` ON drawn | grey-100 · green-500 | Settings | system |
| Track / well | `Surface.track` | `#fafafa` | off-palette | segment track, bar tracks | `NewLook.tintNeutral` `#ECEAE6` |
| Mini-bar track | — | `#e9e9ea` | grey-50 | signal 86 × 4 bars | — |
| Empty-state stroke | — | `#dbddde` 1 pt · `#8e8e93@0.30` 1.33 pt | off-palette | rhythm empty tile / weekday empty circle | `#dbddde` = today's `NewLook.hairline` |
| Shadow tint | `Elevation.*` (§6.3) | `#183c28` @ 0.06–0.16 (cards, bar) · `#000000` @ 0.07–0.17 (FAB, ring) | — | §6.3 | `.black@0.05/0.03` |
| Disabled (buttons) | — | fill `#e5e7eb` / text `#9ca3af` (filled); fill `#f8fafc`, stroke `#e2e8f0`, text `#94a3b8` (outlined) | Tailwind greys | Frame 3 only; no disabled control on any screen | — |
| Outlined button stroke | `Stroke.outlinedButton` | `#cbd5e1` @ 1 pt | Tailwind slate-300 | Frame 3 + screens | **D-C9:** three hairline greys carry chrome (`#000000@0.10` cards/dividers · `#e4ece4` chips/pills/edit card · `#cbd5e1` outlined buttons) plus four one-offs (`#e5f7e5` tiles, `#1c1b1f@0.10` fields, `#dbddde` empty tiles, `#000000@0.04` segment track) — §6.4. Options: keep `Stroke.card` + one `Stroke.chip` hairline and snap `#cbd5e1`, `#e5f7e5`, `#dbddde`, `#1c1b1f@0.10` to it, or tokenise all seven (PLAN §3.1 lists seven). |
| Focus ring (design only) | — | `#93c5fd` | — | Frame 3 "Focused", drawn 0-blur/0-spread → invisible; no iOS equivalent | ignore |

### 4.3 Signal ramps (Frame 12 + screens)

Each glyph is a 64 × 64 frame of filled multi-colour vector paths — **not tintable**. Level is encoded differently per signal:

**Mood — sprout: shape constant, colour changes per level**

| Level | Leaf A (left) | Leaf B (right) + stem stroke 3 pt | Vein stroke 2.3 pt |
|---|---|---|---|
| 1 low | `#d97773` | `#bc4749` | `#eeb4aa` |
| 2 flat | `#e8b964` | `#c58b37` | `#f6dca6` |
| 3 okay | `#b1c194` | `#82936b` | `#d9e2c6` |
| 4 good | `#75ba4f` | `#2a9134` | `#b7dc88` |
| 5 great | `#428d52` | `#175723` | `#9ccaa0` |

Inconsistency: the "great" sprout used as a *level-less identity icon* on Day-details and the Insights headers is drawn with Material greens `#4caf50` / `#388e3c`, not the Frame 12 `#428d52` / `#175723` (the journal's mood avatars use the Frame 12 colours — `#4caf50`/`#388e3c` occur 0 times in `iPhone 17 - 19`). Two "great" sprouts exist (**D-G2**). Product-rule risk: colour is the sprout's **only** level cue (**§13.1**).

**Energy — bolt: colour constant, fill height changes**

| Level | Filled portion (mask height of a 56 pt clip) | % |
|---|---|---|
| 1 low | 16.8 | 30 % |
| 2 flat | 26.6 | 48 % |
| 3 okay | 36.4 | 65 % |
| 4 good | 46.2 | 83 % |
| 5 great | 56.0 | 100 % |

Colours: pale bolt `#f8e4c7` (screens also use `#f0cf9e` — two pale variants), filled bolt `#d98232`, highlight facet `#eda94a`. **Export artefact / D-G1:** the rising fill is a clip-path group whose mask exported as a **solid black rectangle** (`#000000`); the black block renders on Frame 12 *and* on every screen (Mood Journal rows, Insights weekday rows, Edit tiles, "8h Sleep"). Either the design intends a black tile or the mask failed to export. **Blocks asset export; owner must confirm.**

**Focus — target ring + arrow: blue arc sweep grows, arrow constant**

| Level | Blue arc `#4278a8` on base ring `#d6e5f0` (43.5 ⌀) |
|---|---|
| 1 low | short arc, top-right quadrant + 2 round caps 5.5 |
| 2 flat | right half + caps |
| 3 okay | ≈ three quarters + caps |
| 4 good | full ring, caps still drawn |
| 5 great | full ring, no caps |

Constant: inner disc `#8ab8d6` 22.5 ⌀; arrow `#eda94a` diagonal centre → top-right with arrowhead and two 4.5 dots. Focus value text: `#447097` ("Sharp") and `#4278a8` ("Mostly Sharp") — no blue ramp exists in Frame 5 (**D-C4**).

**Sleep — crescent moon + star: moon fill rises (violet), star fill rises (amber)**

| Level | Moon mask height (of 56) | Star mask height (of ≈54.5) |
|---|---|---|
| 1 low | 16.8 | 40.74 |
| 2 flat | 26.6 | 44.18 |
| 3 okay | 36.4 | 47.62 |
| 4 good | 46.2 | 51.06 |
| 5 great | 56.0 | 54.5 |

Colours: moon base `#e3d7f3`, fill `#8c68d3` with highlight `#bca5e8`; star base `#f8e4c7`, fill `#eda94a`. Same black-block mask artefact as energy. On screens sleep appears once ("8h Sleep" on previous-day cards) as a black square with a star. The moon is violet-500 — the same hue as medication (**§13.1**).

**Level words on screens** (not a pen table — collected from copy; canonical vocabulary is `Levels.swift`, Principle VII):

| Signal | Canonical 1→5 (`displayLabel`) | Pen shows |
|---|---|---|
| Mood | Low · Flat · Okay · Good · Great | same (+ "Okey" typo) |
| Energy | Sluggish · Tired · Steady · Alert · Charged | Tired · Steady · Alert · Charged; range-bar axis wrongly reads `Steady Alert Tired Good Great` |
| Focus | Foggy · Distracted · Present · Sharp · Locked In | Distracted · Present · Sharp · Locked In; range-bar axis wrongly reuses mood words |
| Sleep | Restless · Light · Okay · Good · Deep | chips `Low · Flat · Good · Okay · Great` (mood words, wrong order) + "8h Sleep" — **D-V1** |

Rule: the app renders `displayLabel`s; pen copy defects are never transcribed.

### 4.4 Level colours in charts, cards and text

| Level | Chart / range-bar / legend (`MoodLevel.bubble` — PLAN §3.1; the mood ramp reused for every signal) | Mood word colour | Avatar tint 44 ⌀ | Day-card fill · stroke @0.50 | Level-tile selected ring |
|---|---|---|---|---|---|
| 1 low | `#da7a2a` | `#842626` ("Low") | `#f4dddd` | `#fffdfd` · `#f3b09a` | `#f3b09a` (energy tile 1) |
| 2 flat | `#eda94a` | `#da7a2a` ("Flat") | `#fee8d1` | `#fefdfa` · `#f6cc8a` | `#f6cc8a` (focus tile 2) |
| 3 okay | `#9dcca2` (green-200) | `#1e6725` ("Okey") | `#e5f7e5` | not drawn | not drawn |
| 4 good | `#55a75d` (green-400) | not drawn | not drawn | not drawn | not drawn |
| 5 great | `#2a9134` (green-500) | `#17501d` ("Great") | `#ddf4de` | `#f8fffc` · `#abbba3` | `#70b577` (mood tile 5, green-300) |

- Level 3/4 avatar, card and ring tints are **not drawn anywhere** — they must be decided, not interpolated (**D-C11**).
- Selected-tile rings match the *level* tint for L1 and L2 (`#f3b09a`, `#f6cc8a` = the day-card strokes) but **not** for L5 (`#70b577` green-300 vs the L5 card stroke `#abbba3`); no signal-colour reading fits either. **D-E2** must pick the rule and the L3/L4/L5 values (**D-C11**).
- `#da7a2a` is level 1 in the bubble chart but the level-2 *word* colour on cards; `#1e6725` and `#17501d` both stand for green moods. Two inconsistencies to resolve in the token pass.
- Day-details signal values: mood text `#0e7718` + bar `#2e8b57` (= shipped `MoodLevel.great.color`), focus `#447097`, energy text + bar `#e38400`. `#e38400` on white is **2.78:1** — fails even large-text AA and violates "amber is decorative-only, never text" (**D-C2**).
- Other tints: expanded day-card header band `#e6f5ee`; check-in ring disc `#ebf8ee` with track `#bdddc0` (green-100); rhythm tiles mood `#ddf4de@0.20` / `#9dcca2@0.20` / `#9dcca2@0.30`, energy `#fdf6eb` / `#eda94a@0.30` / `#c79043@0.20`, focus `#4278a8@0.10` / `#72a3ff@0.08` — nine ad-hoc combos, no rule (**D-I4**).

### 4.5 Off-palette register (everything on screens that is not in Frame 5)

- **Inks:** `#193024` (59×) · `#292d32` (26×) · `#1c1b1f` (10×) · `#6f7f75` (12×) · `#717680` · `#414651` · `#8a8a8e` · `#303030` (status bar on the edit screen only).
- **Backgrounds / tints:** `#fbfffc` (ground) · `#fafafa` · `#e5f7e5` · `#ddf4de` · `#e6f5ee` · `#ebf8ee` · `#f8fffc` · `#fffdfd` · `#fefdfa` · `#fee8d1` · `#f4dddd` · `#fdf6eb` · `#e3d8f9` · `#e4ece4` · `#abbba3` · `#f3b09a` · `#f6cc8a` · `#c79043` · `#72a3ff` · `#dbddde` · `#d9d9d9` (chip dot) · `#8e8e93`.
- **Amber family:** `#eda94a` (116× — the most-used chromatic after green) · `#d98232` · `#f8e4c7` · `#f0cf9e` · `#e38400` · `#da7a2a` · `#ff9522` / `#dd7917` / `#ffd039` / `#ffae47` / `#e93234` / `#bf161c` / `#f9f1ef` / `#cccccc` (the multicolour "pill" illustration on previous-day cards).
- **Blue family:** `#4278a8` · `#8ab8d6` · `#d6e5f0` · `#447097`.
- **Mood sprout family:** §4.3 + `#4caf50` / `#388e3c` + `#0e7718` / `#2e8b57` / `#842626`.
- **Violet extras:** `#8061bf` (gradient start) · `#bca5e8` · `#e3d7f3`.
- **Ring gradient:** `#26842f` → `#3fbb4b` → `#25832e`.
- **Button-token greys (Tailwind):** `#e5e7eb` `#9ca3af` `#cbd5e1` `#e2e8f0` `#f8fafc` `#94a3b8` `#93c5fd`; Frame 2 furniture `#e2e5ec` `#f0f1f6` `#fbfbfd` `#12151d` `#4b5060` `#626877`.
- **Shadow:** `#183c28`.
- **iOS system colours in the histogram but in no export** (`#34c759`, `#ffd60a`, `#83f00d`, `#ebebf5@0.30`): status-bar/toggle library components; not part of the language. Toggles are drawn in brand green `#2a9134`, **not** system green.

**OWNER DECISION D-C1 — token sprawl.** ~40 off-palette literals. Options: (a) tokenise every one (Complexity Tracking row, constitution IV); (b) snap to the nearest Frame 5 step where the eye cannot tell (`#ebf8ee` → green-50 `#eaf4eb`, `#25832e` → green-600 `#26842f`, `#6f7f75` → grey-300, `#717680`/`#414651` → grey-300/400, five inks → grey-500) and tokenise only the deliberate ones (ground, ring disc, amber/blue glyph families, mood-1/2 colours, tints). Recommendation: (b).

### 4.6 Contrast findings the owner must rule on (light mode)

| Pair | Ratio | Verdict | Fix candidate |
|---|---|---|---|
| white 12–16/500 on green-500 `#2a9134` (every filled button, selected chip, active tab label, Great bubble) | 4.04 | **fails AA** — 12–18 pt at 500–600 is small text on iOS (§4.1 threshold note) | green-600 `#26842f` fill (4.75) — file-wide; today's `#5F8A4C` is 4.02, same failure, not a regression |
| green-500 `#2a9134` 12/600 text on white ("Good", "Charged", "Present", "Active", "Kicking In", "Installed", "Mostly Okay") | 4.04 | fails AA body | green-600 (4.75) or green-700 (6.95) |
| `#e38400` 12/600 on white ("Charged", "Mostly Steady") | 2.78 | fails outright (< 3:1 even for large text) | darker amber text token, or drop amber text (D-C2) |
| `#6f7f75` 12–14 on `#fbfffc` | 4.19 | fails AA | grey-300 (5.16 on ground) |
| `#8a8a8e` 12/400 on white (AI caption) | 3.44 | fails AA | grey-300 |
| `#da7a2a` 16/600 "Flat" on `#fefdfa` | 3.04 | fails (small text; 16/600 is below the ≈ 19 pt semibold threshold) | darker flat-word colour (today's `#8A5600` is 6.16) |
| `#999b9d` inactive tab icons on white | 2.79 | below 3:1 UI floor | grey-300 (5.21) |
| `#4278a8` "Mostly Sharp" on white | 4.68 | passes | — |
| `#7f5fc0` connection eyebrow | 4.88 | passes | — |
| `#1c1b1f` on `#55a75d` (Good bubble) | 5.77 | passes | keep explicit per-level ink, white only at level 5 |
| unplayed waveform `#eaf4eb` on white | 1.13 | near-invisible | violet-100 or a position marker |
| level-tile selected ring `#f6cc8a` / `#f3b09a` / `#70b577` on white, 1 pt | 1.5 / 1.8 / 2.45 | fails 3:1 non-text; colour is the only selected cue | fill tint and/or 2 pt green-500 stroke |
| active dot `#2a9134` vs inactive `#bdddc0` | 2.74 | below 3:1 | size/shape cue as well |
| `#6a6d70` grey-300 on white | 5.21 | passes AA | (this is why grey-300 is the recommended caption grey) |
| `#4d5154` grey-400 on white | 8.01 | passes AAA | — |

**OWNER DECISION D-C3 — primary fill.** Ship green-500 as drawn (record a new AA exception on top of the 2026-07-12 one) or fill primaries with green-600. PRODUCT.md's floor is AA 4.5:1 body / 3:1 UI. This decides every filled control in the file.

---

## 5. Typography

### 5.1 The pen matrix (Frame 2)

Family **Inter**, sizes **12 · 14 · 16 · 18 · 20 · 22 · 24 · 26 · 28 · 30 · 32 · 34 · 36 · 38 · 40 pt**, each in **Regular 400 · Medium 500 · Semi Bold 600 · Bold 700**; sample "Ag · Interface", `#12151d`, line-height auto, tracking 0. Slip: the cell labelled "36 pt Bold" is set at 38/700. On screens line-height is auto except buttons (20 / 24 / 28) and the calendar strip (18). One node family reads "mixed" (the week strip) — probably pasted from a UI kit.

### 5.2 Role ramp actually used (text-node census across the 8 screens: 12/500 ×155, 14/500 ×40, 16/600 ×30, 12/400 ×28, 12/600 ×27, 14/600 ×15, 16/500 ×11, 11/500 ×9, 18/600 ×5, 34/600 ×5, 14/400 ×4, 11/400 ×3, 20/600 ×1, 24/500 ×1, 9/600 ×1, 72/500 ×1)

| Role | Proposed `Typography.` | Size / weight | Colour | `relativeTo:` (Dynamic Type) | Verbatim examples | Today |
|---|---|---|---|---|---|---|
| Page title | `pageTitle` | 34 / 600 | `#17501d` | `.largeTitle` | "Insights", "Settings", "How Do You Feel?", "Check-In Saved" | `largeTitle` 34/**700** (4 sites) + `display` 28/600 (1) → alias of `pageTitle` |
| Page subtitle | `pageSubtitle` | 16 / 500 | `#6a6d70` (`#1e2225` under "How Do You Feel?") | `.body` | "Your Month At Glance", "Make The App Works For You", "Take A Moment To Check In With Yourself" | — (new; `subheadline` is not this role) |
| Nav-bar title | `navTitle` | 18 / 600 | `#17501d` | `.title3` | "Today's Mood", "Edit Check-In" | `text(24,.bold)` (`NewLookNavBar`) |
| Nav-bar subtitle | `navSubtitle` | 12 / 500 | `#6f7f75` → grey-300 | `.caption1` | "Monday, Jun 29 ", "Saturday, Sept 11" | `label` |
| Prompt title | `promptTitle` | 24 / 500 | `#17501d` | `.title2` | "How's Your Mode?" | `text(24,.bold)` |
| Prompt subtitle | `promptSubtitle` | 12 / 500 | `#6a6d70` | `.caption1` | "Heavy, Light, Flat, Bright- Whatever Fits" | `callout` 15 |
| Screen question | `question` | 20 / 600 | `#212529` | `.title3` | "How Does It Feels Today?" | `title` 22/600 (6 sites) → alias of `question` (−2 pt, reviewed in the B1 screenshot pack) |
| Section title | `sectionTitle` | 16 / 600 | `#212529` (edit: `#193024`) | `.headline` | "Your Medications", "Previous Days", "Connections", "Date & Time", "Medication" | `headline` 16/600 (20 sites) → alias of `sectionTitle`, same metrics |
| Card title (day card) | `cardTitle` | 16 / 600 | mood colour + `#212529` | `.headline` | "Great" + "Aug 30" | `dayCardDate` 16/600 (0 sites) → deleted in UI-07 |
| Card subtitle | `cardSubtitle` | 14 / 400 | `#6a6d70` | `.subheadline` | "Average Across Weekdays In July", Reduce Motion note | `callout` 15/400 (17 sites) → alias of `cardSubtitle` (−1 pt, reviewed in the B1 screenshot pack) |
| Row label | `rowLabel` | 14 / 500 | `#292d32` / `#212529` / `#1e2225` | `.subheadline` | "mood ", "Energy Level", "Voice Transcription", "Mood" | `subheadline` 14/500 (14 sites) → alias of `rowLabel`, same metrics |
| Row title strong | `rowTitle` | 14 / 600 | `#292d32` · `#171a1d` (times) | `.subheadline` | "Voice Prompts", "Off", "09:54" | `text(15,.semibold)` |
| Entry title (journal row) | `entryTitle` | 14 / 600 | mood colour | `.subheadline` | "Great", "Low", "Okey", "Okay • Fri 08" | `moodWord` 24/700 (2 sites) → alias of `entryTitle` |
| Body / transcript (AI summary) | `narrative` | pen **12 / 400**; ship **16 / 400** pending **D-T2** | `#1e2225` | `.body` | "Took my Concerta around nine…" | `body` 16/400 (24 sites) → alias of `narrative`, same metrics |
| Body emphasised | `bodyEmphasis` | 12 / 500 | `#212529` | `.caption1` | connection body, journal signal words | — (new) |
| Caption | `caption` | 12 / 500 | `#4d5154` · `#6a6d70` | `.caption1` | "Concerta 36 mg", "24 check-ins", toggle descriptions | `label` 12/500 (22 sites) → alias of `caption` (drop the uppercase call) — **never** today's `caption` (12/400, 63 sites), which would silently re-weight |
| Caption quiet | `captionQuiet` | 12 / 400 | `#6a6d70` / `#8a8a8e` | `.caption1` | range labels, "Low"/"High", "Written by on-device AI…" | today's `caption` 12/**400** (63 sites) → alias of `captionQuiet`, same metrics; `duration` / `mono12` (4 sites) → `captionQuiet` + `.monospacedDigit()` |
| Chip label | `chipLabel` | 12 / 500 (`#193024` / `#ffffff` selected); day-details emotion chips 14 / 500 | | `.caption1` | all Bill-shape chips | `caption.medium` |
| Status / value | `status` | 12 / 600 | `#2a9134` · signal colour · `#7f5fc0` uppercase | `.caption1` | "Active", "Charged", "Mostly Sharp", "MEDICATION × FOCUS" | `label.semibold` |
| Micro | `micro` | 11 / 500 `#6a6d70` · 11 / 400 `#8a8a8e` · 9 / 600 `#4d5154` | | `.caption2` | rhythm captions, "—", "03:24" | `text(9,.medium)` — **9 pt is below the 11 pt iOS floor; do not ship** |
| Button label | `buttonLabel` | 16 / 500 lh 24 (medium) · 14 / 500 lh 20 (small) · 18 / 500 lh 28 (large) | `#ffffff` filled · `#26842f` outlined · `#634a96` "Log Medications" | `.body` | "Speak Check-In", "Save Changes", "Go Back Home" | `headline` 16/**600** |
| Tab label | `tabLabel` | 12 / 500 | `#ffffff` | `.caption1` | "Calendar", "Check In", "Insights", "Settings" | system |
| Timer | `timerHero` | 72 / 500 `.monospacedDigit()` | `#17501d` | capped (see §12) | "0:07" | `timer` SF Mono 22 (1 site) → replaced by `timerHero` |
| Bubble value / word | `bubbleValue` / `bubbleWord` | 14 / 500 + 12 / 500 | `#1c1b1f` (`#ffffff` on Great) | `.caption1` | "33%" "Okay" | `label.semibold` |
| Calendar strip | `stripDay` / `stripNumber` | 12 / 500 lh 18 `#717680` · 12 / 600 lh 18 `#414651` (`#ffffff` selected) | | `.caption1` | "Tue" "7" | `caption` / `callout` 15 |
| Segment label | `segmentLabel` | 12 / 500 `#1e6725` selected · 12 / 400 `#6a6d70` | | `.caption1` | "July 2026" | `caption.medium` uppercase |

Observations: 12/500 is 155 of ~400 text nodes — the app is set very small; the narrative body at 12 pt (today 16) is the one size to push back on for an ADHD audience (**D-T2**). Text case is Title Case on almost every sentence (**D-COPY**, §15.0).

**Alias map (PLAN UI-07; every old role name stays as an alias until UI-49 deletes it — D15 applied to typography):** `largeTitle` / `display` → `pageTitle` · `title` → `question` · `headline` → `sectionTitle` · `subheadline` → `rowLabel` · `body` → `narrative` · `callout` → `cardSubtitle` · `caption` (12/400) → `captionQuiet` · `label` (12/500) → `caption` · `moodWord` → `entryTitle` · `timer` → `timerHero` · `duration` / `mono12` → `captionQuiet` + `.monospacedDigit()` · `dayCardDate` (0 sites) deleted. Metrics are preserved by construction except `callout` (15 → 14) and `title` (22 → 20), both reviewed in the B1 screenshot pack; the 187 `Typography.` call sites in 33 files keep compiling through the aliases and migrate screen by screen.

### 5.3 OWNER DECISION D-T1 — Inter (bundled) vs native SF

The pen sets Inter on every node. The standing rule (spec 023, 2026-06-26) is native SF app-wide, no bundled faces, no `UIAppFonts`. The ramp above is written as size/weight so it survives either choice.

| | Inter (bundle) | Native SF (map 1:1) |
|---|---|---|
| Fidelity to the pen | exact; chip widths and wrap points match the pen | ≈ same metrics; SF runs slightly wider at 12/500, so a few pen wrap points move (e.g. "Disappointed" chip, range-bar labels) |
| Dynamic Type | **equal** — `Typography.sf()` already builds `Font(UIFontMetrics(forTextStyle:).scaledFont(for:))`; swapping `UIFont.systemFont` for `UIFont(name: "Inter-…")` is the same line, and `Font.custom(_:size:relativeTo:)` scales custom faces natively. What Inter **loses**: the system **Bold Text** accessibility setting (applies to system fonts only), and AX1–AX5 must be QA'd per weight file | equal — same `UIFontMetrics` path; Bold Text works |
| Cost | 4 weight files or the variable font (≈ 500 KB), the OFL licence file, `UIAppFonts` in Info.plist, a `SquirlFonts` registration (the thing spec 023 deleted) | none — zero assets |
| Risk | a second reversal of a logged owner decision (spec 023); Bold Text not honoured; metrics differ enough that a few pen wrap points move either way | "SF looks like every other app" — the pen's identity leans on colour and glyphs, not the face. (`.monospacedDigit()` is a non-issue for both: it works on any face with `tnum`, which Inter has, with no descriptor work.) |
| Precedent | — | spec 033 mapped the Figma Inter ramp to SF; design-database R01: "Inter is the working stand-in; SF Pro is the production target" |

**Recommendation:** native SF with the pen's sizes/weights (option 2) — on the strength of spec 023 (a logged owner decision), the Bold Text accessibility setting and zero bundled assets; *not* on Dynamic Type, which is equal. Revisit only if the owner wants the face itself as brand. **Undecided.**

---

## 6. Spacing, radius, elevation

### 6.1 Grid and gutters

- Artboard 402 wide. Content left edge **x = 28–31**, content width **340–346**: nav-bar container 340 @ 31; cards 342 @ 30 (journal, check-in) or 344 @ 28/29 (day-details, insights, settings, edit); tab bar 346 @ 28. **D-S1:** one gutter token — proposal `Spacing.gutter = 28` (matches the tab bar; cards fill the column) with the 1–3 pt drift treated as pen noise. Today's gutter is 16 (`Spacing.l`).
- Nav row at **y 74–77**, 43 tall; page-title block 63 tall (34 + 16 + gap ≈ 3–4); first card ≈ 22–26 below.
- Section heading → card **12** (`Spacing.m`); card → next heading ≈ **24** (`Spacing.xxl`); card/section stacks **24** on every scroll screen (the content column `Frame 11` is a vertical auto-layout with gap 24 on edit, settings, insights and day-details = `Spacing.xxl`); 8 between previous-day cards; 5 between connection cards (no token; **D-S3**).
- Card inner padding **15** (insights, edit, settings, medication bar, expanded header) but **11** on day-details and journal rows — two values coexist (**D-S2**: proposal `Spacing.cardInset = 16` and `Spacing.rowInset = 12`, i.e. snap to the base-4 grid, or keep 15/11 as literals).
- Chip rows: gap **6** horizontal and vertical (27-high chips on a 33 pitch) — **display-only rows**; interactive rows take the ≥ 44-pt row pitch of §8.2 (**D-K6**). Level tiles 56 on a **64** pitch (gap 8). Button stacks gap 8.
- Tab bar bottom edge 5 above the home-indicator zone; FAB vertically centred on the bar (or floated above it on Settings).
- Existing `Spacing` (xs 4 · s 8 · m 12 · l 16 · xl 20 · xxl 24 · section 32 · hero 40) covers everything except gutter 28/30, inset 15/11, chip gap 6, card gap 5 and the interactive chip-row pitch (D-K6). PLAN §3.1 adds `gutter 28`, `cardInset 15`, `rowInset 11`, `chipGap 6`, `cardGap 24`, `tilePitch 64`.

### 6.2 Radii (proposed `Radius.`)

| Element | Radius | Proposed token |
|---|---|---|
| Buttons (all families), Frame 3 chips, toggles, selected calendar day, bars | 999 (pill) | `Capsule()` — no token |
| Bill-shape chip | 15 (pill on 27 high) | `Radius.chip` (**exists**, 15) |
| Tab bar container | 75 (pill on 60) | capsule |
| Tab bar active pill | 44 (pill on 44) | capsule |
| Add Button | circle 50 ⌀ | `Circle()` |
| Nav back / ellipsis pill | circle 43 ⌀ (21.3) · row versions 23–24 ⌀ (11.3–12) · collapse pill 29.17 ⌀ | `Circle()` |
| Card L | 24 | `Radius.cardL` |
| Card M | 18 | `Radius.cardM` |
| Card S / row card / day card / medication bar | 12 | `Radius.cardS` |
| Expanded day-card header band | 24 / 24 / 0 / 0 | `UnevenRoundedRectangle` |
| Level-picker tile | 20 | `Radius.tile` |
| Date / time field, preview row | 12 | `Radius.field` (= cardS) |
| Medication capsule tile | 13–14 (circle 26–28 ⌀) | `Circle()` |
| Connection icon tile | 11 (42 sq) | `Radius.iconTile` |
| Segmented track / thumb | 19 / 15 | `Radius.segmentTrack` / `segmentThumb` |
| Progress bars | 9.5 (10 high) · 2 (4 high) | capsule |
| Rhythm tile, avatar | 22 (44 ⌀) | `Circle()` |
| Check-in ring | 173.5 (347 ⌀) / 105.5 (211 ⌀) | `Circle()` |
| Saved check tile | **0** (sharp 96.95 square) | **D-K1:** the only hard rectangle in the system |

Retire: `Radius.card` 16, `Radius.button` 16, `Radius.newLookCard` 20, `Radius.control` 10 (no pen counterpart; the Figma `radius/card 20` variable is contradicted by every drawn card).

### 6.3 Elevation (proposed `Elevation.` — PLAN §3.1)

| Token | Value (offset x y · blur · colour) | Used on |
|---|---|---|
| `Elevation.card` | 0 3 · 8 · `#183c28@0.08` | insights, settings, medication bar, day cards, connection cards |
| `Elevation.raised` | 0 4 · 8 · `#183c28@0.08` | day-details cards, edit cards, listening prompt card |
| `Elevation.field` | 0 2 · 8 · `#183c28@0.08` | date / time fields |
| `Elevation.chip` | 0 7 · 6 · `#183c28@0.06` | day-details emotion chips only |
| `Elevation.tabBar` | 0 8 · 24 · `#183c28@0.16` | Navigation |
| `Elevation.fab` | 0 7 · 17 · `#000000@0.17` | Add Button |
| `Elevation.ring` | 0 2 · 18 · `#000000@0.08` (saved: 0 1.22 · 10.95) | check-in ring |
| `Elevation.thumb` | 0 1 · 3 · `#193024@0.07` | month selector |
| `Elevation.toggleKnob` | 0 0.94 · 1.88 · `#000000@0.15` | custom toggles only — moot under D-K5 / PLAN D22 (native `Toggle`) |

One tint (`#183c28`) at 0.06–0.16 carries the whole system except FAB and ring (pure black). **D-S4:** collapse to one shadow tint token; HTML export blur values differ by ≈1 pt from the JSON (7 vs 8, 21 vs 24, 14.875 vs 17) — the JSON values above are the intent.

### 6.4 Hairlines / strokes

| Stroke | Weight | Used on |
|---|---|---|
| `#000000@0.10` | 0.5 (cards) · 1 (dividers, radio off) · 0.25–0.75 (icon tiles, bar tracks) | most cards, all in-card dividers |
| `#e4ece4` | 1 (chips, edit card 1) · 0.6–1.065 (nav pills) | chips, pills |
| `#cbd5e1` | 1 | outlined buttons |
| `#e5f7e5` | 1 | level tile (unselected) |
| `#bdddc0` | 21.33 inside (347 ring) · 12.97 (211 ring) | ring track |
| `#dbddde` / `#8e8e93@0.30` | 1 / 1.33 | empty tiles |
| `#1c1b1f@0.10` | 1 | date/time fields |
| `#000000@0.04` | 1 | segmented track |

---

## 7. Iconography

### 7.1 UI-chrome icons

Library **vuesax / Iconsax** (Frame 1 "Icon Set", ≈1,030 names × Linear · Bold · Outline · Two-tone). Instances placed on screens:

| Icon | Style | Where | SF Symbol fallback |
|---|---|---|---|
| `arrow-left` | outline (renders as a bare chevron) | back pill ×5 | `chevron.left` |
| `more` | outline (three dots) | ellipsis pills | `ellipsis` |
| `arrow-up` | twotone stroke 1.41–1.71 | expand/collapse chevrons ×9 (rotated for right/down) | `chevron.up/down/right` |
| `arrow-right` | twotone | Settings disclosure | `chevron.right` |
| `add` | twotone, 1.71 strokes | Add Button | `plus` |
| `calendar` | bold (active) · outline (inactive) | tab bar | `calendar` |
| `task-square` | bold (active) · linear (inactive) | tab bar (Check In) | `checklist` / `checkmark.square` |
| `chart` | bold (active) · outline (inactive) | tab bar (Insights) | `chart.bar.fill` |
| `setting-2` | bold (active) · twotone (inactive) | tab bar (Settings) | `gearshape` |
| `microphone-2`, `edit-2` | bold | check-in buttons | `mic.fill`, `pencil` |
| `stop` | outline (renders as a solid white rounded square r 4) | Stop & Save | `stop.fill` |
| `lock`, `unlock` | bold | connection tiles | `lock.fill`, `lock.open.fill` |
| `record-circle`, `info-circle` | bold | Settings rows | `record.circle`, `info.circle.fill` |
| `voice-cricle` (sic) | outline | Settings | `waveform.circle` |
| capsule (diagonal, one half hollow) · calendar / clock (fields) · cellular bars · sparkle · play · check · accessibility figure · multicolour pill | custom pasted vectors | various | `pills`, `calendar`, `clock`, `sparkles`, `play.fill`, `checkmark`, `figure.walk` |

Rule visible in the file: **active tab = Bold; everything else mixes Outline, Linear and Two-tone with no rule** (three inactive styles in one bar). Sizes: 24 tab, 20 back/lock, 25 more, 16–21 button icons, 13 row chevrons, 21 settings rows. Stroke 1.5 (linear/twotone), 1.41 (chevrons).

**OWNER DECISION D-IC1 — icon family.** (a) bundle vuesax as template PDFs (one inactive style, proposal Outline, which is the majority; 4 bold actives; ≈20 assets); or (b) SF Symbols with the fallbacks above (zero assets, weight-matched to text, Dynamic Type-scaled). Today `Icons.swift` holds SF names only and the asset catalog holds no icons. Recommendation: (b), keeping the pen's silhouettes where SF has a near-identical glyph; (a) only if the owner wants the exact vuesax stroke look.

### 7.2 Signal glyph set (Frame 12)

Twenty assets named `{energy|focus|mood|sleep}-{low|flat|okay|good|great}`, each a 64 × 64 frame of plain `VECTOR` paths — no components, no instances, not tintable. Placed on screens at **33.55** (level pickers, weekday rows, rhythm tiles, avatars), **23–24** (inline signal words on cards), **18** (journal rows), **14–20** (section-header identity icons), **28–33** (day-details signal card, three different box sizes). Geometry: sprout stem open path 23.7 × 28.2 at (21.4, 26.8) stroke 3 round, leaves 21.6 × 22.5 at (9, 13) and (33.6, 17.5), veins ≈9 × 9; bolt path 35.78 × 47.52 at (14.34, 9); focus ring 43.5 ⌀, inner disc 22.5 ⌀ at (16.75, 24.75), arrow 24.68 sq; moon 44.9 × 46.84 at (9, 8.6), star 17 × 17.2 at (38.5, 9.5). Colours in §4.3.

Also on screens but not in Frame 12: a level-less **identity icon** per signal (sprout `#4caf50/#388e3c`, bolt `#eda94a`, target) used as row/section leaders; the black-square-with-star "sleep" tile; the multicolour medication pill.

**OWNER DECISION D-G3 — asset strategy.**

| | Export PDF/SVG from the pen | SwiftUI `Shape`/`Canvas` (today's approach) |
|---|---|---|
| Fidelity | exact art | must be redrawn by hand from the geometry above |
| Level encoding | baked per asset (20 files + 4 identity icons; ×2 if dark needs its own set) | parametric: one drawing per signal, `level` drives fill height / arc sweep / leaf colour |
| Tinting / dark mode | none — multi-colour art; dark variants need a second export | free (`Color(lightHex:darkHex:)` per part) |
| Small sizes | sprout strokes (3 / 2.3 pt at 64) thin to < 1 pt at 14–18 pt; needs a simplified small variant | stroke width can scale with a floor |
| Blocked by | D-G1 black block (mask export) | nothing — the Shape draws the intended rising fill directly |
| Accessibility | `Image` + label | `Canvas` + label, `accessibilityHidden(decorative)` as today |

Recommendation: **Shapes**, keeping the `SignalGlyph(kind, level:, size:, decorative:)` API so the 16 app call sites are untouched; the pen art is the reference drawing. Either way the sprout's colour-only level encoding must gain a shape cue or an explicit posture waiver (§13.1).

---

## 8. Components

Each entry: anatomy · variants · states · metrics · proposed SwiftUI name. **Names are PLAN §3.2 verbatim** and were checked against the app for collisions: the app's `private struct DoseTrack` (`MedicationBarView.swift:133`), `MiniBar` / `ConnectionCard` / `GatedCard` (`ConnectionCardsView.swift:19/74/110`), `ChipGroup` (`ExtractionReviewView.swift:8`), `SettingsChip` (`MyMedicationSection.swift:182`), the two private `Chip`s (`TimelineRow.swift:99`, `FoldedDayCardHeader.swift:102`) and the non-private model `struct RhythmCell` (`InsightsViewModel+Signals.swift:74`) would silently shadow a same-named package type through `@_exported` — so the package names below avoid them (`RhythmTile`, `ProgressTrack`, `SignalMiniBar`, `ChipGroupView`) and the remaining app-side duplicates are deleted as a named precondition of the screen PR that consumes the package type (PLAN UI-25 / UI-30 / UI-32). Metrics from the JSON; screen instances that differ from the DS master are listed as variants. "Today" names the shipping symbol the component supersedes (Principle III/IV: supersede, never add beside).

### 8.1 Buttons (Frame 3) — `FilledButtonStyle` / `OutlinedButtonStyle` / `UnderlineButtonStyle` (+ `.filled / .outlined / .underline` statics)

Three families × three sizes × with/without leading icon × four states. Pill radius 999, label weight 500, icon 16 (S/M) / 18 (L), stroke 1.5 on line icons.

| Size | Height (filled / outlined) | Padding x / y | Gap | Font / line | Icon |
|---|---|---|---|---|---|
| Small | 36 / 38 | 14 / 8 | 8 | 14 / 20 | 16 |
| Medium | 44 / 46 | 18 / 10 | 8 | 16 / 24 | 16 |
| Large | 52 / 54 | 24 / 12 | 10 | 18 / 28 | 18 |

Outlined is 2 pt taller because the 1 pt stroke is drawn outside; **treat all as 44 with an inside stroke**.

| Family / state | Fill | Stroke | Label + icon |
|---|---|---|---|
| Filled · Default | `#2a9134` | — | `#ffffff` |
| Filled · Hovered | `#1e6725` | — | `#ffffff` |
| Filled · Focused | `#17501d` (+ invisible ring) | — | `#ffffff` |
| Filled · Disabled | `#e5e7eb` | — | `#9ca3af` |
| Outlined · Default | `#ffffff` | `#cbd5e1` 1 | `#26842f` / icon `#2a9134` |
| Outlined · Hovered | `#f8fafc` | `#2a9134` 1 | `#26842f` |
| Outlined · Focused | `#ffffff` | `#26842f` 1 | `#26842f` |
| Outlined · Disabled | `#f8fafc` | `#e2e8f0` 1 | `#94a3b8` |
| Underline (text) · Default / Hovered / Focused / Disabled | — | — | `#26842f` / `#1e6725` / `#17501d` / `#94a3b8` |

iOS state mapping (proposal, not in pen): Hovered → **pressed**; Focused → not applicable; Disabled as drawn. **D-B2:** the pen has no pressed state; the shared style must define one (Hovered colours recommended over an opacity dip). Screen instances: "Speak Check-In" Filled M + mic (detached: gap 3, icon 21, fixed width 182 — treat as drift, build the component); "Log Medications" Outlined M + capsule, label `#634a96` violet-700 (**D-B1:** sanction a `tint: .medication` variant or keep green); "Write Notes" Outlined M + pencil; "Stop & Save" Filled M + stop; "Cancel" Outlined M; "Go Back Home" / "Save Changes" Filled M full width (342/344 × 44). No Small or Large instance appears on any screen. Supersedes `PrimaryButtonStyle`, `CheckInPrimaryButtonStyle`, `SecondaryButtonStyle`, the hand-rolled hub pills and — once `feat/055` is on `main` — `PaywallButtonStyle` (`Views/Paywall/`).

### 8.2 Bill-shape chip (Frame 15) — `BillChip`

Pill **27** high, padding **5 / 15**, r 15, label 12/500.

| Variant | Fill | Stroke | Label | Extra |
|---|---|---|---|---|
| `.outline` (`BG=outline`) | `#ffffff` | `#e4ece4` 1 | `#193024` | — |
| `.solid` (`BG=solid`, selected) | `#2a9134` | `#2a9134` 1 | `#ffffff` | — |
| `.withDot(color)` (`BG=With Dot`) | `#ffffff` | `#e4ece4` 1 | `#193024` | leading 8 ⌀ dot (`#d9d9d9` master; level colour on Insights), gap 4 |
| `.checked` (screen-only, Settings "2h") | `#2a9134` | `#2a9134` | `#ffffff` | leading 15 ⌀ white disc with a 10 × 7 green check, gap 5 — **not in Frame 15 (D-K3)** |

States drawn: unselected / selected only. Screen variants: Insights legend at 25 high; day-details emotion chips 29 high, label 14/500, `Elevation.chip` (the only elevated chips). Rows: gap 6 / 6 **for display-only rows** (Insights legend, Day-details emotions); several edit-screen rows are **clipped at the card edge** (scroll) while the sleep row wraps — **D-K2: wrap vs horizontal scroll** (recommendation: wrap, today's `FlowLayout`). **Hit area (rule, also §12):** a 44-pt hit frame on a 27-pt chip in rows on a 33-pt pitch overlaps the next row's hit frame by 11 pt — every tap in that band is ambiguous, and on Edit (emotions ×10, side effects ×15, dose chips) chips are the primary input. So **interactive chip rows use a ≥ 44-pt row pitch**: chip 27 + vertical gap 17, or chip 36 + gap 8 — **D-K6**, owner picks; both deviate from the pen. Horizontal hit extension only where neighbours are ≥ 44 apart; otherwise the drawn 27 × width is the target and the row pitch supplies the height. Supersedes `.newLookChip`, `Chip.swift` (deleted by PR #44), `TagFlowView` chip, `SettingsChip`, `FoldedDayCardHeader.Chip`, `TimelineRow.Chip`, `RecordingRow` (deleted by PR #44) / `MedicationLogSheet` capsules — seven grammars → one; the surviving private `Chip`/`SettingsChip` types are deleted before `BillChip` enters their file (PLAN UI-25 / UI-32).

### 8.3 Add Button (Frame 15) — `AddButton`

50 ⌀, fill `#8c68d3`, `Elevation.fab`; `add` glyph 41-box, two 20.5 strokes `#e9e9ea` 1.71 round caps. No states drawn. Placement: x 324 (right gap 28), vertically centred on the compact tab bar; on Settings it floats **above** the full-width bar at (309, bar − 64). **D-N2:** action undefined (new check-in? log dose? menu?) — see §9.

### 8.4 Navigation tab bar (Frame 4) — `FloatingTabBar`

Container **346 × 60**, `#ffffff`, r 75, `Elevation.tabBar`. Items Calendar · Check In · Insights · Settings.
- Active: wrapper padding 8 / 15; pill `#2a9134` r 44, padding 10 / 20, gap 6, bold icon 24 white + label 12/500 white (pill 122 / 121 / 116 / 118 × 44).
- Inactive: padding 16.5 / 20.5, icon 24 `#999b9d`, no label.
- Variants: `.full` (346, labelled pill; Settings) · `.compact` (274 × 60, **icon-only** 64 × 44 pill, shares the row with the FAB; Day-details, Journal, Insights). Check-in flow screens have **no bar**.
- Masters: `Status=Calendar|Check In|Insights|Settings, Mode=Light`. No dark variant.
- Pen defect: the Insights screen shows the *Calendar* pill active. Two layouts (labelled vs icon-only) — **D-N1** decide one; **D-N3** custom overlay bar vs native iOS 26 tab bar (see §9.2).

### 8.5 Nav header — `NavHeader`, `NavPill`

Container 340 × 43 at (31, 74–77). `NavPill(.back)`: 43 ⌀ (42.6 exported = 40 × 1.065), `#ffffff`, stroke `#e4ece4` 1.065, chevron 20 `#1e6725`; `NavPill(.more)`: same with `more` 25 (three 5.73 dots `#1e6725`). Title 18/600 `#17501d` + subtitle 12/500 `#6f7f75`, 7–8 pt after the pill. Variants: pill-only (check-in A/B/C, edit has pill + title), pill + title + subtitle + trailing more (day-details), page-title variant with no pills (Insights, Settings: 34/600 + 16/500). **Hit target 44** (pen 42.6). Supersedes `NewLookNavBar` and the `cancelPill`/`savePill` in the edit sheet.

### 8.6 Cards — `.card(_ style:)` modifier + `CardHeader`

| Style | Width | Fill | Stroke | Radius | Shadow | Padding | Where |
|---|---|---|---|---|---|---|---|
| `.large` | 342–344 | `#ffffff` | `#000000@0.10` 0.5 (edit card 1: `#e4ece4` 1) | 24 | card · raised (edit) | 15 (**11** on the day-details AI card — §8.24) | insights, settings groups (Check-In Calendar, Voice & Storage, Dose Guard, Medication Bar — all r 24 in the pen), edit sections, AI card |
| `.medium` | 344 | `#ffffff` | `#000000@0.10` 0.5 | 18 | card · raised (prompt card, 0 4 8) | 15 | connection cards, Confirmations, Accessibility, Your Data (the three r 18 Settings cards), listening prompt |
| `.small` | 342–344 | `#ffffff` | `#000000@0.10` 0.5 | 12 | card | 11 (**16 / 9** on the signal summary — §8.24) | medication bar, medication row, signal summary |
| `.day(mood)` | 342 × 99 | `#f8fffc` / `#fffdfd` / `#fefdfa` | level tint @0.50, 0.5 | 12 | card | 11 | previous days |
| `.expandedDay` | 342 × 266 | `#ffffff` | `#000000@0.10` 0.5 (centre) | 24 | raised | 14 / 15 | header band `#e6f5ee` 52 high, radii 24/24/0/0 |

`CardHeader`: title 16/600 top-left, optional right caption 12/500 `#4d5154` or a **collapse pill** (29.17 ⌀, `#ffffff`, stroke 0.729 `#e4ece4`, `arrow-up` 18.76 `#26842f`); a 1 pt divider under the header when the card has rows. Collapsed state is **not drawn** (**D-K4**). Supersedes `.newLookCard()` (r 20 borderless) and `DayCard`'s clip; the New Look "never a card border" rule is retired.

### 8.7 Toggle — recommendation: native `Toggle` with `.tint(Accent.primaryFill)` (ON = green-600, PLAN D22)

Pen draws two custom sizes: Regular track 42 × 22.62, knob 16.96 ⌀ `#ffffff` + `Elevation.toggleKnob`; Small 34 × 18.31, knob 13.73. ON `#2a9134` drawn (shipped ON = green-600 `#26842f` — one accent for every filled control, no text on the track but the same token as buttons/chips; both documents state green-600), OFF `#babbbd`. Both below the iOS 51 × 31 switch and the 44 pt floor. **D-K5:** native `Toggle` (VoiceOver "switch", Switch Control, HIG size for free) vs the drawn custom control (`SquirlToggle`, one size). Recommendation: native, one size.

### 8.8 Radio row — `RadioRow`

20 ⌀; off: stroke `#000000@0.10` 1, no fill; on: stroke `#2a9134` **6**, white 8 ⌀ centre. Row: title 14/600 `#292d32` + subtitle 12/500 `#6a6d70`, radio right-aligned at x 338; whole row is the target; `.isSelected`.

### 8.9 Segmented month picker — `SegmentedPicker`

Track 344 × 38, `#fafafa`, stroke `#000000@0.04` 1, r 19, padding 4, gap 4; three equal segments 109.33 × 30 r 15. Selected thumb `#ffffff` + `Elevation.thumb`, label 12/500 `#1e6725`; unselected 12/400 `#6a6d70`. Copy "June 2026 · July 2026 · Aug 2026" (mixed month formats — normalise to `MMMM yyyy`). Behaviour at the current month (what the "next" segment shows) undefined (**D-I1**). Hit height extend to 44. Supersedes `MonthSelectorScrollView` (the generic control lives in the package; Insights binds it to months).

### 8.10 Progress / medication bars — `ProgressTrack`, `SignalMiniBar`

| Bar | Track | Fill | Radius |
|---|---|---|---|
| Medication (bar card) | 320 × 10, `#fafafa`, stroke `#000000@0.10` 0.25 | `#8061bf → #8c68d3` horizontal; 165 (51.6 %) / 20 (6.25 %) | 9.5 |
| Connection | 285 × 6, same | same gradient, 165 wide (58 %) with caption "70%" 12/500 `#193024` (pen mismatch) | 9.5 |
| Signal mini (day-details) | 86 × 4, `#e9e9ea` | mood `#2e8b57` 78 · focus `#447097` 48 · energy `#e38400` 21 (not on a 5-step grid) | 2 |

Medication row (`DoseRow`): `MedicationBadge` 26 ⌀ `#f4f0fb` stroke `#000000@0.10` 0.42 + capsule 12.7 `#4d3974` · "09:54" 14/600 `#171a1d` · 3 ⌀ dot · "Concerta 36 mg" 12/500 `#4d5154` · status right 12/600 `#2a9134` ("Active", "Kicking In"); rows separated by 1 pt dividers, gap 14. Status vocabulary today: kicking in (< 20 %) · active (< 80 %) · wearing off · worn off — the last two are undrawn and must stay quiet (**§13.1**). Today's onset pulse (opacity 1↔0.55 / 1.3 s while < 20 %) is not drawn; keep unless told otherwise. `ProgressTrack` draws the gradient (`#8061bf → #8c68d3`) for both the 10 pt medication track and the 6 pt connection bar; `SignalMiniBar` is the 86 × 4 day-details bar. The app's `private struct DoseTrack` (`MedicationBarView.swift:133`) and `private struct MiniBar` (`ConnectionCardsView.swift:110`) are deleted in UI-25 / UI-30 when the package types arrive.

### 8.11 Check-in ring — `CheckInRing(progress:size:)` (states `.idle / .listening / .saved`)

- **Idle / listening:** group 347 ⌀ + `Elevation.ring`; disc `#ebf8ee`; inside stroke `#bdddc0` **21.33** (track); arc = annulus 20.82 wide, butt ends, vertical linear gradient `#26842f` 0 % → `#3fbb4b` 50 % → `#25832e` 100 %, anchored at 3 o'clock, swept clockwise: **≈ 33 % (118.8°) idle, ≈ 66 % (237.6°) listening, 100 % saved**. No `arcData` exported — the arc reads as a **3-step flow indicator**, not elapsed time (**D-R1** confirm; if it were time, idle must be 0 %).
- Inside idle: three stacked buttons (§8.1) gap 8. Inside listening: timer 72/500 `#17501d` + "Stop & Save" + "Cancel" (stack 304.34 wide, gap 8). Under the ring: helper 14/500 (`#6f7f75` → grey-300), 65–67 pt below.
- **Saved:** ring 211 ⌀, stroke 12.97 (arc 12.66), full gradient; centre `CheckTile` 96.95 sq sharp `#2a9134` with white check 49.7 × 37.3; title 34/600 + 14/500 `#1e2225` two lines; full-width filled button. Integers for code: ring 212 / stroke 13 / tile 96 (**D-K1** sharp vs rounded).
- Diameter must be width-relative: `min(width − 2·gutter, 347)`; the pen fits only 402-wide devices. Supersedes `CrescentRing` (also used by `WelcomeView` at 232 — migrate or the component stays alive for one consumer).

### 8.12 Prompt card + page dots — `PromptCard`, `PageDots`

342 × 98.25, `.medium` card (r 18, `Elevation.raised`), padding 15, gap 11 / 6; title 24/500 `#17501d`, subtitle 12/500 `#6a6d70`; five dots 7.25 ⌀ gap 4 — active `#2a9134`, inactive `#bdddc0` (2.74:1 — add a size cue). Today's timed 4 pt progress bar under the dots is not drawn (**D-R3**: keep as a hairline or drop, with spec 036 a05 and `promptProgress` tests going with it).

### 8.13 Bubble chart — `MoodBubbleChart`

Five overlapping flat circles on a rising baseline (≈13 pt per level), later on top (Great topmost): Low 70.76 `#da7a2a` · Flat 84.15 `#eda94a` · Okay 103.28 `#9dcca2` · Good 98.49 `#55a75d` · Great 78.41 `#2a9134`; labels 14/500 + 12/500 centred, `#1c1b1f` (`#ffffff` on Great only). Diameter ≈ `60 + 1.3·pct` — **not area-proportional**; today's formula is `44 + 74·sqrt(share/max)` (**D-I2**: pick one, test-first). Card `.large` 342 × 317, header 16/600 + "24 check-ins" 12/500 `#4d5154`, divider, legend row of `BillChip.withDot` (25 high) — single clipped row in the PNG, wrapped in the JSON (**D-K2**).

### 8.14 Weekday glyph row — `WeekdayGlyphRow`

Row header: identity icon 14–16 + label 14/500 `#292d32` + trailing status 12/600 in signal colour ("Mostly Okay" `#2a9134`, "Mostly Steady" `#e38400`, "Mostly Sharp" `#4278a8`). Seven columns 44.57 × 52.55: glyph 33.55 + gap 4 + weekday 12/500 `#4d5154` (`Mo Tu We Th Fr Sa Su`). Empty day: 18 ⌀ circle stroke `#8e8e93@0.30` 1.33. Rows separated by 1 pt dividers with 15 above/below. Pen defect: energy row reads `Mo Tu We Fr Fr Sa Su`.

### 8.15 Range bar — `RangeBar`

Five pills **60.8 × 7** r 999 gap 2 in `MoodLevel.bubble` (`#da7a2a · #eda94a · #9dcca2 · #55a75d · #2a9134` — the mood ramp reused for every signal); labels 12/400 `#6a6d70` 4 pt under each; bracket `⊓` 73 × 21, stroke `#4d5154` 1.25 round caps, over the averaged pair; caption right 12/400 `#6a6d70` ("Between Okay & Good"). Whole-number averages (one segment) are not drawn. Labels must be the canonical `displayLabel`s; "Distracted" / "Locked In" / "Sluggish" exceed 60.8 pt at 12 pt — needs a layout rule. Supersedes `SignalAverageGauges` (vertical 64 × 280 gauges).

### 8.16 Rhythm matrix — `RhythmMatrix`, `RhythmTile` (view; `RhythmCell` stays the existing model in `InsightsViewModel+Signals.swift:74`)

Columns "MORNING · AFTERNOON · EVENING · LATE" 12/500 `#4d5154` (typed in caps; "AFTERNOON" wraps at 66.5 — a defect to avoid). Row heads: identity icon + 12/500 `#292d32`. Cells 44 ⌀ tinted (§4.4) + glyph ≈24 + caption 11/500 `#6a6d70`; empty: stroke `#dbddde` 1 + "—" 11/400 `#8a8a8e@0.60`. Bucket hours are a code fact (06–11 / 12–17 / 18–21 / 22–05, tie → higher). **D-I4:** one tint rule instead of nine literals.

### 8.17 Connection card — `ConnectionCard(.locked / .unlocked)`

`.medium` card 344 × 104 (unlocked) / 80 (locked); icon tile 42 sq r 11 stroke `#000000@0.10` 0.45 — unlocked `#e3d8f9` + `unlock` 20 `#4d3974`; locked `#f4f0fb` + `lock` 20 `#7f5fc0`; title 12/600 `#7f5fc0` uppercase; body 12/500 `#212529`; unlocked adds the 285 × 6 bar + "70%". Section header "Connections" 16/600 + "Patterns across signals — 3 or more days to unlock" 14/400 `#6a6d70` (the real gates are 4 / 5 / 3+3 days — caption is wrong in pen and code). Product question on "unlock"/padlock copy: **§13.1**. Supersedes today's dashed-border `GatedCard` / `InsightGatedCard` (053) and the `private struct ConnectionCard` in `ConnectionCardsView.swift:19` — same name, so the private type is deleted in UI-30 before the package view is imported (it would shadow it otherwise).

### 8.18 Settings rows — `SettingsGroup`, `SettingsRow`, `InfoRow`

Group = heading 16/600 `#212529` ≈12 above a `.large`/`.medium` card; rows hug their content (18–82 in the pen: 18.31 / 22.62 toggle rows, 21 icon rows, 36 radio rows, 52–82 rows with a description); minimum hit height 44; title 14/500 `#212529` (14/600 `#292d32` when a description follows), description 12/500 `#6a6d70`; 1 pt dividers inset 15. Trailing: toggle, value 12/500 `#4d5154` ("34MB"), status dot 8 ⌀ + 12/500 `#2a9134` ("Installed"), chevron `arrow-right` 21 `#212529`. Leading icons 21: `voice-cricle`, `record-circle`, `chart`, `info-circle`, accessibility figure (`#000000` — the only pure-black ink; **token it**). Sub-components: `BillChip` groups (Prompt Pace, Blocked For), preview row 314 × 40 `#f4f0fb` r 12 with `MedicationBadge`, `RadioRow` group, `InfoRow` (icon + hugging multi-line text — the pen's fixed-height boxes collapse in the PNG; text must hug). Supersedes the native `insetGrouped List` (reverses the 2026-06-24 decision — §16).

### 8.19 Date / time field — `DateTimeField`

Label 12/500 `#1c1b1f` above (gap 7). Field 166 × 39, `#ffffff`, stroke `#1c1b1f@0.10` 1, r 12, `Elevation.field`, padding 12 / 10; leading icon 15 `#6f7f75` (calendar / clock); value 12/600 `#193024`; two fields, gap 12. **The picker itself is not designed (D-E3)**: compact `DatePicker` cannot be restyled to this field — present a graphical picker from the field.

### 8.20 Level tile picker — `LevelTilePicker`, `LevelTile`

Row label 14/500 `#292d32` left ("mood ", "Energy Level", "focus level" — inconsistent case) + current value 12/600 `#2a9134` right. Five tiles **56 × 56 r 20**, stroke 1 `#e5f7e5`, no fill, glyph 33.55 inset 11.22, pitch 64; selected = stroke 1 in the *level* tint (`#70b577` / `#f3b09a` / `#f6cc8a`; L3/L4 not drawn) — no fill or weight change (fails 3:1 and "colour never the only cue", **D-E2**). Captions "Low" / "High" 12/400 `#6f7f75`. The 312 pt row fits only 402-wide devices inside a 16 pt-inset card (**D-E4** narrow-device rule). Keep today's tap-again-clears; a11y = `accessibilityLabel(signalAccessibilityLabel(kind, level))` + `.isSelected` — the pinned contract (`"Mood: Good, 4 of 5"`, `SignalGlyphTests`) reads "Mood: Good, 4 of 5, selected"; one contract, already tested (PLAN UI-16 / UI-28 Verify use the same string). Supersedes `GlyphRampPicker` (also used by `TextCheckInComposer` — undesigned).

### 8.21 Chip group — `ChipGroupView` (`ChipGroup` is a private model in `ExtractionReviewView.swift:8`, deleted in UI-28)

Titled group (14/500 `#292d32`: "Pleasant", "Unpleasant", "Concerta Dose", "Your Sleep", "Blocked For") + rows of `BillChip`, gap 6 / 6, multi-select shown by several solid chips. Overflow undecided (**D-K2**).

### 8.22 Calendar week strip — `WeekStrip`, `DayCell`

Month title 14/600 `#212529` + chevron 16 (`arrow-up` rotated → **right**); seven columns; day names 12/500 lh 18 `#717680`; numbers 12/600 lh 18 `#414651`; selected day 32 ⌀ `#17501d` with white number; dot 5 ⌀ `#55a75d` 6 below **the selected day only** (**D-J1:** selected / today / has-entries semantics — today's code draws a mood-coloured dot under every day with entries). Pen defects: "Tue Mon Wed Thur…", "7 6 8 9 10 11 12", 10 Sep 2026 labelled Fri (it is a Thursday) — code calendar maths wins. Month grid / month swipe (today) are not drawn (**D-J2**).

### 8.23 Journal entry row + day cards — `CheckInRow`, `MoodAvatar`, `DayCard` (collapsed), `ExpandedDayCard`

- `MoodAvatar`: 44 ⌀ tinted (§4.4) + 1 pt stroke same tint, sprout 33.55.
- `CheckInRow` 312 × 44: avatar · mood word 14/600 mood colour + time 14/500 `#212529` (gap 6) · signals line [energy 18 + word] · 3 ⌀ dot · [focus 18 + word] 12/500 `#212529` · trailing `NavPill(.more)` 22.6 ⌀ (stroke `#e4ece4` 0.565, `more` 13). Menu contents undesigned (**D-J3**). Today's row also lists meds, sleep, emotions, side effects — removed by the pen (function loss to confirm).
- `DayCard` (collapsed): `.day(mood)` 342 × 99, padding 11: avatar + title row (word 16/600 mood colour · "Aug 30" 16/600 `#212529` · expand pill 24 ⌀ chevron-down `#26842f`) · signals row 12/500 `#4d5154` [energy 23 + word] · [focus 24 + word] · [sleep 20 + "8h Sleep"] · medication line (pill illustration 12 + "Concerta 36mg"). Three glyph sizes in one row (**D-J4** one size).
- `ExpandedDayCard`: `.expandedDay` with header band `#e6f5ee` 52 high — "Okay " 14/600 `#17501d` · 3 ⌀ dot `#4d5154` · "Fri 08" 14/600 `#17501d` · collapse pill 24 ⌀ chevron-up; rows container padding 15, gap 13, 1 pt dividers. The band is a **fixed mint** for every mood (today: mood-tinted). Header mood = day average (code fact, tested).

### 8.24 Signal summary card + AI summary card (day-details) — `SignalSummaryCard`, `SignalColumn`, `AISummaryCard`, `AudioPlayerRow`, `WaveformBars`

- Summary: `.small` card 344 × 113, padding 16 / 9; three columns 94 wide (pitch 116) split by **diagonal** 81-pt `#000000@0.10` hairlines (**D-D2** keep or vertical); column = glyph (28 / 27 / 33 — three sizes, misaligned baselines; use one 32 box) · label 14/500 `#1e2225` · value 12/600 in signal colour · 86 × 4 bar. Order Mood · **Focus** · Energy (every other screen is Mood · Energy · Focus — **D-D3**). Bars are not on a 5-step grid — use `level/5`.
- AI card: `.large` r 24, padding 11, gap 11: caption row = sparkle 13.6 × 16.4 `#7f5fc0` + "Written by on-device AI from your Voice, tap to Correct" 12/400 `#8a8a8e` (2 lines) · divider · body 12/400 `#1e2225` · divider · player row: play 27.75 ⌀ `#8c68d3` (stroke `#000000@0.10` 0.75, 44 pt hit) + 55 pill bars 2.5 wide pitch 4.6, heights quantised to 5 values (0.23 / 0.40 / 0.53 / 0.74 / 1.0 × 24.75), played `#8c68d3` / unplayed `#eaf4eb` + duration 9/600 `#4d5154`. Bar count must derive from width; amplitudes are decorative today (**D-D4** real vs seeded). States not drawn: playing, scrubbing, finished, no audio (text check-in), transcribing / pending / failed, summary edited by the user, fallback transcript under the AI byline (must never happen — carry today's guard).

### 8.25 Medication badge — `MedicationBadge`

26–28 ⌀ disc `#f4f0fb` (or `#ffffff` inside the violet preview row) + stroke `#000000@0.10` 0.42–0.45 + diagonal line-style capsule 12.7–15 `#4d3974`. Supersedes the horizontal two-tone `CapsuleGlyph` (the pen's is diagonal with a hollow half). The multicolour emoji-style pill on previous-day cards is a second, conflicting medication icon (**D-J5**: one icon).

### 8.26 Section heading — `SectionHeading`

16/600 `#212529` on the ground, 12 above its card (24 after the previous card); optional 14/400 `#6a6d70` subtitle 2 below ("Connections" pattern).

---

## 9. Layout & navigation

### 9.1 Page anatomy

- **Root tabs (Calendar, Insights, Settings):** ground `#fbfffc`, no system nav bar; Insights/Settings open with an in-content page title (34/600 + 16/500 at x 30–32, y 74); Calendar opens straight into the medication bar card at y 76. One vertical `ScrollView`, section gap 24, floating chrome pinned over the content (bottom content inset ≥ 60 + 34 + 8 ≈ 103; ≥ 170 where the FAB floats above the bar, as on Settings).
- **Pushed screens:** `NavHeader` at y 74 (back pill; title/subtitle; optional more pill). Day-details keeps the tab bar + FAB; Edit hides both (**D-N4:** one rule). Check-in A/B/C have a pill-only header and no bar/FAB.
- **Cards** fill the content column (342–344); chips and tiles never exceed the card's inner width — rows wrap (recommendation) or scroll.
- **Gutters:** 28 outer / 30 cards in the pen; one token (**D-S1**).

### 9.2 Tab bar + FAB — the load-bearing decision (D-N3)

| Route | What it gives | What it costs |
|---|---|---|
| (a) Custom `FloatingTabBar` overlay: keep `TabView(selection:)` for state, hide the system bar (`.toolbarVisibility(.hidden, for: .tabBar)`), draw the pill bar + `AddButton` in the root container | literal pen fidelity (white pill, green icon-only/labelled active pill, violet FAB beside it) | hand-rolled hit areas, `.isSelected` + "Tab, 1 of 4" VoiceOver semantics, Reduce Transparency, keyboard avoidance, iPad, loss of iOS 26 minimise-on-scroll; `ScreenContainer`'s tab-bar background modifiers become dead |
| (b) Native iOS 26 tab bar tinted green-500 (+ optional `Tab(role:)` for the trailing action) | system behaviours and a11y for free; already a floating rounded bar on iOS 26 | cannot drop labels, active item is glass not a solid green pill, a "+" search-role tab is a semantic hack |

**Recommendation: (a)** — stated identically in PLAN D4: custom `FloatingTabBar` overlay, `TabView(selection:)` kept for state, one **compact** layout (icon-only active pill + FAB) on all four roots, inactive icons raised to grey-300, fallback = native bar tinted (2 h) if the UI-18 a11y device QA fails. The a11y mechanism it must carry is in §12 (container `.accessibilityElement(children: .contain)` + `.isTabBar`, items `.isSelected`, "1 of 4" verified on device with an `accessibilityValue` fallback). **D-N2 (FAB action)** — recommendation, PLAN D5: the FAB starts a voice check-in via `router.requestCheckIn()` and is **hidden on the Check In root** (the hub already carries a 182-pt "Speak Check-In" that does the same thing; two identical primary actions on the one screen whose job is that action would violate "one primary action per screen"); it shows on Calendar, Insights, Settings and Day Details exactly as drawn. This deviates from the A frame (which draws neither bar nor FAB) and is logged as such (§16). Alternatives the owner may still pick: (ii) FAB only and the tab goes, (iii) FAB = log dose / menu.

### 9.3 Check-in flow topology (D-N5)

As drawn, A → B → C is a **full-screen flow** with a back pill and no bar, while Frame 4 still defines a `Status=Check In` tab. Readings: (a) Check In tab shows the hub *with* the bar, **without the FAB** (§9.2) and no back pill (hide bar + medication bar only while `state != .idle`, raised to `RootContainerView` through a `ChromeVisibilityKey` `PreferenceKey` — PLAN D5); (b) tab and/or FAB present the flow as a `fullScreenCover` (note: `ScreenContainer` owns its own `NavigationStack`, so a *push* onto another tab's stack cannot reuse it — a cover can); (c) tab dropped, FAB only. Affects deep links / Siri (`router.requestCheckIn()` today selects the tab and auto-starts B). "Go Back Home" names a place the bar does not have (**D-N6**: idle hub, Calendar, or the launching tab).

### 9.4 Medication bar overlay

Today a top `safeAreaInset` on every tab root. The pen draws the bar **inside** the Calendar content column and nowhere else (not on Insights, Settings, Day-details, the check-in flow). **D-N7:** pinned vs scrolling, and which screens carry it.

### 9.5 Not in the language

Custom chrome is opaque: no material on the tab bar, FAB, nav pills or cards; no system large-title collapse; no sheets *designed* (Edit is drawn as a push; today it is a `.sheet`), no grabbers. **System-owned surfaces keep iOS 26 Liquid Glass and are not restyled** — they are not deviations in design/QA review: `.sheet`s (Log Dose, the type-note composer, the D-E3 date picker, `RecoveryKeySheet`), `Menu` (`•••`), alerts (mic / download / storage / memory), native `Toggle` (D-K5), `DatePicker`, the RevenueCatUI paywall and Customer Center; all tinted `Accent.primary`. Status bar, home indicator and the 32 pt device radius are system-drawn and not implemented.

---

## 10. Motion

The pen specifies **no motion**. The old rules carry over, restated for the new ring and chrome:

- **Approach:** intentional; "effortless = inevitability." Everything decelerates gently; nothing snaps hard.
- **Check-in ring (`CheckInRing`) — OWNER DECISION D-R2.** The logged rule (2026-06-15, old §Motion) is *"the crescent revolves while listening (~7 s/rev) with a voice-level glow; settles to a check when saved"*; the pen draws a static progress arc (33 % idle · 66 % listening · 100 % saved) and no motion, and the listening spec's Q2/Q8 route the motion to the owner (constraints §3.4 Q-M1). No author may reverse it silently, so the three readings are put side by side:
  - **(a) carry the old rule** — 7 s/rev rotation of the arc + a voice-level glow (`audioLevelStream`). Gives the live-mic feedback the pen otherwise lacks; costs the "progress arc" reading (a rotating 66 % arc reads as a loader). Reduce Motion: static arc, glow → opacity step only.
  - **(b) static arc at 66 % as drawn** — zero motion beyond the entry step; simplest; the only listening cue is the timer. Reduce Motion: identical.
  - **(c) arc step 33 % → 66 % on entry + a level-driven glow (recommended)** — no rotation (the arc stays a 3-step flow indicator, D-R1), the glow (disc `#ebf8ee` → track tint, ≤ 8 % luminance swing driven by `audioLevelStream`) restores live-mic feedback; saved — arc completes to 100 % and the check tile settles (spring, gentle damping). Reduce Motion: arc changes instant, glow off, settle instant.
  - Idle **breathing** (~5 s, scale 1 → 1.035, opacity 0.94 → 1) is a separate sub-question for all three: keep or ship static as drawn. Whatever is chosen is logged in §16 as a reversal of the 2026-06-15 crescent rule.
- **Settle transitions** (spring, gentle damping) for section/tab changes, card expand/collapse (chevron rotates with `Motion.expand`), chip and toggle fills (`Motion.smooth`).
- **Medication bar onset pulse** (opacity 1 ↔ 0.55 / 1.3 s while < 20 %) — today's only "kicking in" cue; not drawn, not contradicted; keep.
- **No confetti, no streak celebration, no "you're late" alarms.**
- **Reduce Motion:** breathing collapses to the static idle ring; arc changes and settles become instant; prompt-card slide, chevron rotation and pulse are gated exactly as today (`accessibilityReduceMotion` checks in every animated view).
- **Easing:** enter ease-out · exit ease-in · move ease-in-out. **Duration:** micro 50–100 ms · short 150–250 ms · medium 250–400 ms (`Motion.snappy` 0.3, `Motion.smooth` 0.4, `Motion.expand` 0.25).

---

## 11. Dark mode — OWNER DECISION D-DM

The pen is **light-only**: the only dark value in any export is Figma `Tiimo Colors / surface/card` dark `#1C1E19`; Frame 4's variant is named `Mode=Light` and no `Mode=Dark` exists. The shipping app has always shipped dark (every token is `Color(lightHex:darkHex:)`, dark values "derived").

| Option | Consequence |
|---|---|
| (1) **Derive dark tokens now**, per token, in the same commit as the light tokens (spec-033 precedent: "Figma specs light only; dark is derived, documented and logged") | keeps parity with today; ~45 tokens need a pair; hard cases below need real design |
| (2) Ship the refresh light-only (`preferredColorScheme(.light)`) | first-ever regression for dark-mode users; simplest; contradicts the current app |
| (3) Defer: light tokens now, dark in a follow-up spec, refresh gated on it before release | same end state as (1) with a second QA pass |

Hard cases whatever the option: green-800 `#17501d` titles vanish on a dark ground (needs ≈ green-200/300 as the dark pair); `#ffffff` cards → a `#1C1E19`-class card; `#000000@0.10` hairlines/dividers → white-alpha; `#183c28` shadows → drop; violet-50 tiles → a dark violet tint (precedent `Palette.medication` dark `#957BC1`); the **energy/sleep black blocks disappear on a dark ground** — the bolt loses its only level cue; sprout reds/greens and the focus base ring `#d6e5f0` need contrast checks on a dark card; multi-colour glyph *assets* would need a second export (Shapes do not). Recommendation: (1).

---

## 12. Accessibility

- **Contrast:** WCAG 2.1/2.2 AA is the hard floor (PRODUCT.md): ≥ 4.5:1 body, ≥ 3:1 large text and UI components. The pen's own Frame 5 numbers are the reference (§4.1); the failures to rule on are in §4.6. Ratios measured on the `#fbfffc` ground are ≈0.05 lower than on white — same pass/fail.
- **Dynamic Type — policy:** every text role scales through `UIFontMetrics` with the `relativeTo:` styles in §5.2 (AX1–AX5). Glyphs and rings are imagery and stay fixed-point (`Metrics`), aligned to `.firstTextBaseline`. Rules the pen forces: (1) at `dynamicTypeSize >= .accessibility1` the check-in button stack leaves the ring (or the ring shrinks to ~120), the three signal columns stack vertically, the Date/Time columns stack, the week-strip labels fall back to single letters; (2) chip rows **wrap** (never a horizontally clipped row at AX sizes); (3) the 72 pt timer scales with a cap (`@ScaledMetric` max) so it stays inside the disc; (4) no `minimumScaleFactor` on headings; (5) nothing ships at 9 pt; 11–12 pt captions are `.caption1/.caption2` and grow; (6) fixed-height text boxes (Dose Guard footnote, Accessibility note) hug. Existing precedents to keep: `forceWeek` at AX1 in the calendar header, `@ScaledMetric` day disc capped at 40, `FlowLayout` chips, concatenated mood+time `Text` that wraps instead of truncating.
- **Touch targets ≥ 44 × 44 pt:** back/more pills (42.6), collapse pills (24–29), row ⋯ (22.6), chips (25–29), toggles (18–23), radio (20), segments (30), play (27.75) are all drawn smaller — draw small, hit 44 (`.frame(minWidth: 44, minHeight: 44).contentShape(.rect)`), or make the row/header the control. **Exception — chip rows (§8.2, D-K6):** a 44-pt hit frame on 27-pt chips at a 33-pt pitch overlaps the next row by 11 pt, so interactive chip rows use a ≥ 44-pt **row pitch** (27 + 17 or 36 + 8) instead of an oversized hit frame; display-only rows keep 6/6; horizontal hit extension only where neighbours are ≥ 44 apart.
- **VoiceOver:** glyph levels are announced as `"Energy: Alert, 4 of 5"` (today's `signalAccessibilityLabel` contract — keep); **level tiles use that same contract**: `accessibilityLabel(signalAccessibilityLabel(kind, level))` + `.isSelected` → "Mood: Good, 4 of 5, selected" (one contract, pinned by `SignalGlyphTests`; no second numeric or word-only label), and the row exposes the caption word as `accessibilityValue`; rings, check tile, diagonal separators and identity icons are `accessibilityHidden(true)`; the timer is a live region ("Recording, 0:07 elapsed"); **a custom tab bar**: container `.accessibilityElement(children: .contain)` + `.accessibilityAddTraits(.isTabBar)`, items `.isSelected` — `.isSelected` alone does not produce "Tab, 1 of 4" in SwiftUI, so the "1 of 4" readout is verified on device in PLAN UI-18 and falls back to `accessibilityValue("\(i) of 4")` if it is not spoken; the FAB needs a label ("New check-in"); custom toggles/radios/chips need `.accessibilityRepresentation` or native controls; page titles and section headings carry `.isHeader` (Settings today has **no** heading at all); combined elements for rows (title + description + state) and for range bars (bracket + five pills = one sentence).
- **Colour is never the only cue:** selected tiles and chips need fill + label (not a 1 pt tinted ring); active page dot needs size; played/unplayed waveform needs a luminance step or a position marker; the mood sprout needs a shape cue per level or an explicit waiver (§13.1); Differentiate Without Colour → stronger selected treatment.
- **Reduce Motion:** §10. **Increase Contrast:** thicken/darken the `#cbd5e1` / `#e4ece4` hairlines (1.2–1.5:1 today).
- **Device range:** the pen's fixed geometry (347 ring, 5 × 56 tiles + 4 × 8 in a 312 column) fits only 402-wide devices; every metric that depends on width needs a `min(width − …)` rule or a smaller-device variant (**D-E4**).

---

## 13. Product Posture (non-negotiable)

Carried over verbatim. The paywall (§14) and every screen in §15 obey these; if a pen element conflicts, the posture wins unless the owner rules otherwise below.

- **No streaks, no gamification.** A broken streak is a shame spiral for ADHD users and the #1 reason these apps get deleted. The reward is "I said it and it's captured."
- **Medication never nags.** No red, no "you're late." A worn-off dose just goes quiet.
- **Glyphs, not emoji faces** (see Iconography).
- **Privacy-first.** On-device; the store is excluded from iCloud backup. Nothing here invites surveillance imagery.
- **The paywall obeys every rule above.** It is a screen in this app, not an exception to it. No countdown timers, no fake scarcity, no guilt copy, no "you'll lose your progress." If a growth tactic contradicts the four rules above, the rules win.

Two rules carried verbatim from the old §Color and §Iconography, because no pen frame contains them and they bind the glyph set in §7.2:

- Rule: **color is never the only cue.** Every signal level is also encoded by glyph shape + fill (below), so it survives colorblindness and grayscale.
- Glyphs encode level by **shape + hue + fill simultaneously** (triple-redundant; verified grayscale/colorblind-safe via a single-ink silhouette test). No emoji faces anywhere — faces impose a self-judgment ("am I a frowny-face today?") that adds affective load; abstract growth glyphs are lower-stakes and faster to scan.

### 13.1 Pen vs posture — checklist to confirm

| # | Pen element | Rule touched | Question |
|---|---|---|---|
| P1 | **Red "Low" mood** — `#842626` word, red sprout `#bc4749`, red-tinted avatar `#f4dddd` / card stroke `#f3b09a` (Mood Journal, Frame 12). The old ramp deliberately started at burnt orange; red was reserved as a medication anti-reference. | no red / judgment cues | Is a red Low a judgment cue on a bad day, or acceptable data encoding? Note the pen's own bubble chart uses `#da7a2a` for Low. |
| P2 | **Black energy / sleep blocks** (`#000000` growing tiles, Frame 12 and every screen) | pure-black surfaces anti-reference; dark mode | Export artefact or intended? If intended, it is the bolt's only level cue and vanishes in dark. |
| P3 | **Connections "unlock" copy + padlock tiles** — "Patterns across signals — 3 or more days to unlock", "Note 1 More Good Sleep Day & 3More Poor-Sleep Days To Unlock This Connection", "Log High Energy 2 More Days To Unlock This Connection" | no gamification / no nags | "Unlock" + lock icon reads as progression; "log N more days" is a logging nudge; one line asks the user to have *3 more poor-sleep days*. Today's code copy ("Log medication on 2 more days to unlock this connection.") is the same idea in sentence case. |
| P4 | **Counts and percentages** — "24 check-ins", "8% Low … 13% Great", "Low (2) … Great (3)", "75% Of The Time" / "70%" | scorekeeping / streak proxy | Neutral context or a score? (And 75 vs 70 vs 58 % on one card is a data defect.) |
| P5 | **"See You At Next Check-In"** (saved screen) | return nudge | Warmth or nag? Old copy was "Captured." + Done. |
| P6 | **"Missed"** chip on Edit (exists in code today) | medication never nags | Keep, rename, or drop. |
| P7 | **Green status words "Active" / "Kicking In"** on the medication bar; no worn-off state drawn | one quiet purple, no alarm | Confirm worn-off / wearing-off stay quiet (no red, no colour change) in the green grammar. |
| P8 | **Violet everywhere** — FAB, AI sparkle, lock tiles, sleep moon, medication | "purple = medication" (2026-06-15) | Purple keeps its medication meaning, or becomes the brand accent — both cannot be true. |
| P9 | **Mood sprout encodes level by colour only** | colour never the only cue | Waiver, or add a shape cue (today's `SproutGlyph` opens the crown at ≥ 4, notches the stem at ≥ 3). |
| P10 | **Pure white cards + `#000000` blocks** | old anti-reference "pure white / pure black surfaces" | Retire that anti-reference with Paper & Pollen (the pen is white-on-near-white by design), or keep it (then cards and blocks both need a decision). |
| P11 | **Amber as text** (`#e38400` "Charged", "Mostly Steady") | "amber is decorative-only, never text" + AA | Keep amber for the bolt only, or darken a text variant. |
| P12 | **"Your recordings, check-ins, and signals stay on this device. Nothing is uploaded."** (Settings) | privacy honesty | Becomes false once the purchase receipt goes to RevenueCat — reconcile with the one honest disclosure line (§14). |

---

## 14. Paywall & Purchase (spec 055 — RevenueCat)

> **The paywall is not in the pen.** No paywall (A), trial-ended (B), fail-open (C), Settings subscription (D), Welcome/onboarding or export/recovery-key surface exists in the file; the only designed paywall is `html-mockups/055-paywall.html` in New Look tokens. Structural rules below carry over unchanged; the four visual bullets are restated in this system. **Owner reversal 2026-09-04 (feat/055):** the root/Settings paywall is **RevenueCatUI** (dashboard Paywalls v2, still a draft) + Customer Center + a Lifetime plan; the custom SwiftUI that remains is the onboarding paywall step, the screen-C fail-open card, the Settings subscription section (7 states) and the shared export/legal components. **D-PW1:** the RevenueCatUI paywall cannot be restyled in SwiftUI — its look is set in the RevenueCat dashboard (owner task) or it stays visually separate.

- **Placement:** after Welcome, **before** the ~500 MB model download — so a bounce costs the user no bandwidth and nobody waits through a long download only to be asked for money.
- **Four screens are required, not three.** Beyond the paywall (A), trial-ended (B) and Settings (D), screen **C · fail-open** is mandatory: when entitlement cannot be verified the app *unlocks*. Under a hard paywall, empty offerings or purchases-ios #4623 would otherwise lock a paying user out of their own on-device journal. Screen B also offers **export without subscribing** — the app may lock, the user's writing may not.
- **Surface (restated).** `Surface.screen` ground, one `.large` card per plan option with the standard hairline and `Elevation.card`, section headings 16/600. No full-bleed marketing hero; this app does not shout.
- **Type (restated).** The §5 ramp, hierarchy by weight/size. Price is the largest numeral on the screen (`pageTitle` 34/600 or larger); nothing competes with it.
- **Color (restated).** The recommended plan is the **selected** state of the chip/card grammar — `Accent.primaryFill` fill + `Ink.onAccent` label, never colour alone. Amber and violet never carry paywall text. Never use a destructive colour to pressure a choice.
- **⚠️ Contrast (restated).** Pricing terms, trial length and cancellation copy are legally load-bearing and are exactly what a reviewer scrutinises: render them in `Ink.primary` (grey-500, 15.43:1), never in the caption greys, and never white on green-500 (4.04:1) at body size. This is the one place no AA exception may extend. Owner decision required only if D-C3 keeps green-500 fills.
- **Required furniture** (App Review Guideline 3.1.1 — omission is an automatic rejection): exact price · billing period · trial length if any · Restore Purchases · Terms (EULA) · Privacy Policy · plain-language how-to-cancel.
- **Restore appears twice**: on the paywall and in Settings, matching the existing section pattern in `app-four/Views/Settings/`. (The pen Settings has **no** Subscription / Restore row, no Privacy Policy row and no Export row — all three are mandatory; **D-ST1** who designs them, in this language.)
- **Selection is explicit.** Plan choice uses the established chip grammar — fill + label, never colour alone (§13, colour never the only cue).
- **Accessibility is a hard gate.** The pricing screen must survive Dynamic Type AX5 without truncation or overlap — plan options stack vertically before they clip. VoiceOver reads plan → price → period → savings as one label, not four fragments. Touch targets ≥ 44×44 pt.
- **A dismissed paywall stays dismissed.** No re-presenting on every launch; that is a nag, and nags are banned above.
- **One honest disclosure line**, because the privacy policy promises the app says when anything leaves the device: *"Purchases are verified by our payments provider. Your journal never leaves this device."* (Reconcile with the Settings statement in §13.1 P12.)

---

## 15. Screen specs

### 15.0 Copy policy — OWNER DECISION D-COPY

The pen is Title Case on every string including full sentences; the shipping app and HIG use sentence case for body/hint/description copy and Title Case for titles/buttons. Decide once. Whatever the casing, **pen copy defects are normalised, never transcribed**, and level words come from `Levels.swift` `displayLabel`s. Corrections proposed (pen → fix): "Breackdoen" → "Breakdown" · "Okey" → "Okay" · "Claendar" → "Calendar" · "Vyvans" → "Vyvanse" · "Elvense" → "Elvanse" · "Blocked While A Does Is Still Active" → "Blocked while a dose is still active" · "How's Your Mode?" → "How's your mood?" · "Heavy, Light, Flat, Bright- Whatever Fits" → "Heavy, light, flat, bright — whatever fits." · "How Does It Feels Today?" → "How did today feel?" (or "Today's signals") · "A few Words Is Enough" → "A few words are enough" · "Make The App Works For You" → "Make the app work for you" · "Your Month At Glance" → "Your month at a glance" · "3More" → "3 more" · "Thur" → "Thu" · weekday row "Mo Tu We Fr Fr Sa Su" → "… Th Fr …" · "34MB" → "34 MB" · "2h" ↔ "2 h" (one form) · "mobile Data" → "cellular data" · "Concerta · 36 mg" / "Concerta 36 mg" / "Concerta 36mg" / "36mg" → one format (proposal "Concerta · 36 mg") · "Sept 11" → system `Date.FormatStyle` · "Check-In" vs tab "Check In" → one spelling · "Written by on-device AI from your Voice, tap to Correct" → "Written by on-device AI from your voice. Tap to correct." · "See You At Next Check-In" → "See you at your next check-in." (posture P5) · "Today's Mood" on a dated detail → relative date title · "Today's Emotional Condition" → "Emotions" · "Recording · 34MB" → "Storage" · time format 24 h ("18:30") vs "9:15 AM" → device locale.

### 15.1 Check-In A · idle hub — `iPhone 17 - 4` (`iIaeI`)

- **Purpose:** resting state of the daily check-in — one question, one primary action, two quiet alternatives. Entry to the A → B → C flow.
- **Chrome:** status bar; `NavPill(.back)` at (31, 77); empty title slot; **no tab bar, no FAB, no medication bar** as drawn (topology D-N5; medication-bar loss on the hub D-N7). Recommendation (§9.2 / PLAN D5): the hub is the Check In **tab root** — tab bar visible, **FAB hidden** on this root only, no back pill, medication bar shown while `state == .idle`; logged as a deviation from the A frame.
- **Layout (top → bottom, y in pt):** 143 eyebrow date "Saturday, Sept 11" 12/500 `#6f7f75` centred · 168 title "How Do You Feel?" 34/600 `#17501d` · 215 subtitle "Take A Moment To Check In With Yourself" 16/500 `#1e2225` (gap 10 / 6) · 299 `CheckInRing` 347 ⌀ idle (≈33 %) with the button stack centred (gap 8): "Speak Check-In" Filled M + mic 182 × 44 · "Log Medications" Outlined M + capsule (violet label) 191 × 46 · "Write Notes" Outlined M + pencil 155 × 46 · 713 caption "A few Words Is Enough" 14/500 `#6f7f75`, 67 below the ring. Nothing scrolls; content column 342 @ 30, 65 between header and ring.
- **Components:** §8.5, §8.11, §8.1.
- **Copy (verbatim → fix):** "Saturday, Sept 11" → formatted date · "How Do You Feel?" · "Take A Moment To Check In With Yourself" → sentence case per D-COPY · "Speak Check-In" · "Log Medications" (plural — "Log a Dose"?) · "Write Notes" ("Write a Note"?) · "A few Words Is Enough" → "A few words are enough".
- **States drawn:** idle only. **Not drawn:** first-launch hint (today's one-time whisper), mic-permission / Whisper-download / storage / memory alerts (system alerts, keep), medication on board, the Log Medications sheet and the type-note composer (no frames — reuse `MedicationLogSheet` / `TextCheckInComposer` restyled).
- **Open:** D-N5 topology · D-R1 idle arc meaning (decorative constant / time budget = 0 / today's three steps) · D-B1 violet outlined variant · D-R2 ring motion (carry / static / step + glow) + breathing · destinations for the two secondary buttons.

### 15.2 Check-In B · listening — `iPhone 17 - 5` (`XXA5N`)

- **Purpose:** mic open; count-up timer; rotating prompt card; end with Stop & Save or Cancel.
- **Chrome:** back pill only (action undefined: cancel? confirm?); no bar/FAB.
- **Layout:** 130 `PromptCard` 342 × 98.25 ("How's Your Mode?" 24/500 `#17501d`; "Heavy, Light, Flat, Bright- Whatever Fits" 12/500 `#6a6d70`; 5 dots, first active) · 287.25 `CheckInRing` 347 ⌀ at ≈66 % with timer "0:07" 72/500 `#17501d` (format `m:ss`) + "Stop & Save" Filled M + stop 152 × 44 + "Cancel" Outlined M 91 × 46 (gap 8) · 699.25 hint "Take Your Time, Speak Freely." 14/500 `#6f7f75` centred · 124 pt empty above the home indicator.
- **Copy:** "How's Your Mode?" → "How's your mood?" (typo; the five prompts are test-pinned in code) · hint → code copy with spaced em dash and full stop · "Stop & Save" (keep ampersand?) · "Cancel" · "Take Your Time, Speak Freely." → sentence case.
- **States drawn:** recording, prompt 1 of 5. **Not drawn but load-bearing (spec 016):** approaching-cap cue ("Wrapping up soon", proposal: swap the hint line for 4 s), auto-stop at the 8-minute cap, processing (spinner in the primary, disabled), save-failed recovery ("Couldn't save that one." / Try again → Filled M, Discard → Text button), interruption/paused (today unreachable — retire or wire the audio service's pause into the VM), live-mic feedback (none; `audioLevelStream` exists).
- **Open:** D-R1 ring = 3-step indicator · D-R3 prompt progress bar · back = cancel or confirm; block edge-swipe while recording · D-B2 pressed state · D-C3 contrast.

### 15.3 Check-In C · saved — `iPhone 17 - 6` (`fmQEp`)

- **Purpose:** terminal confirmation; one exit. Shows no record data (by design — carried decision).
- **Chrome:** back pill (meaningless after a save — hide, = Go Back Home, or ×; **D-N8**); no bar/FAB.
- **Layout:** hero block 342 × 340 **centred on the frame** (y 267): `CheckInRing` 211 ⌀ at 100 % with `CheckTile` 96.95 sq · gap 48 · "Check-In Saved" 34/600 `#17501d` · gap 6 · "A Moment For Yourself, Captured.⏎See You At Next Check-In" 14/500 `#1e2225` two designed lines (U+2028 → `\n`, let it reflow) · "Go Back Home" Filled M full width 342 × 44 at y 717 (79 above the home-indicator zone) — pin to the bottom safe area on other heights.
- **Copy:** "Check-In Saved" · subtitle → add final period, "at your next check-in" (posture P5) · "Go Back Home" → destination-true label ("Done" / "Back to today") once D-N6 is decided.
- **States:** C appears the moment the audio is on disk (`.done`); transcription + extraction continue in the background; alerts from that work can surface over C (undesigned, acceptable?). Text check-ins also land here today (confirm).
- **Motion:** none drawn; proposal arc 66 → 100 % + tile settle, Reduce Motion → static (§10). Keep `Haptics.success()`.
- **Open:** D-N6 "Home" · D-N8 back pill · D-K1 sharp tile · D-C3.

### 15.4 Mood Journal · Calendar tab — `iPhone 17 - 19` (`nDRZv`)

- **Purpose:** root tab — today's medication bars, month header + week strip, the selected day expanded into its check-in rows, "Previous Days" collapsed cards.
- **Chrome:** no header; `FloatingTabBar.compact` (Calendar active, icon-only) + `AddButton`; status bar; canvas 1131 (scrolls ≈257 pt).
- **Layout:** 76 medication bar `.small` card 342 × 140 (two `DoseRow`s: "09:54 • Concerta 36 mg — Active" 51.6 %; "18:23 • Vyvans — Kicking In" 6.25 %; code shows up to 3 rows) · 240 "September 2026" 14/600 + chevron-right · 263 `WeekStrip` (Tue 7 · Mon 6 · Wed 8 · Thur 9 · **Fri 10** selected · Sat 11 · Sun 12; dot under 10) · 370 `ExpandedDayCard` 342 × 266 ("Okay • Fri 08" band; rows: Great 18:30 [energy-low "Alert" · focus-good "Distracted"]; Low 18:30 [energy-okay "Alert" · focus-flat "Distracted"]; "Okey" 18:30 [bare bolt "Tired" · focus-great "Locked In"]) · 660 "Previous Days" 16/600 · 687 / 794 / 901 `DayCard`s 342 × 99 (Great Aug 30 · Low Aug 30 · Flat Aug 30; each "Alert · Distracted · 8h Sleep" + pill "Concerta 36mg") · bar at 1037.
- **Data facts from code that answer pen ambiguities:** header mood = rounded-half-up **average** of the day's moods; previous days = older than the selected day **within the current month** (an Aug 30 card under a September header is placeholder noise or a new cross-month rule — D-J6); sleep hours → level thresholds exist (`<5 restless · <6 light · <7 okay · <9 good · else deep`); energy/focus words come from `displayLabel` (today the row prints raw `alert` / `lockedIn` — fixed on PR #45).
- **Copy:** "Okey" → "Okay" · "Vyvans" → "Vyvanse" · "Thur" → "Thu" · strip order/dates are placeholder · "Fri 08" vs "Aug 30" vs "September 2026" → one day format · "Concerta 36 mg" vs "36mg" · 24 h times → locale · label/glyph level mismatches ("Alert" drawn at three different bolt levels) are lorem.
- **States drawn:** expanded selected day, collapsed previous days. **Not drawn:** empty state (first launch under a hard paywall lands here), dose-only node, transcribing/pending row, expanded previous day, worn-off dose, three-dose bar, month grid / month swipe (today), compact title band on scroll (today, spec 035 + 10 tests), scrolled state / bottom inset.
- **Open:** D-J1 dot semantics · D-J2 month chevron (grid / page / picker) · D-J3 row ⋯ menu contents and where emotions/side effects live · D-J4 one glyph size · D-J5 one medication icon · D-J6 cross-month list · D-N7 bar pinned vs scrolling · P1 red Low · P9 sprout shape cue · keep the bar's tap (log / delete dose) — the only bar-level dose management.

### 15.5 Day Mode Details — `iPhone 17 - 1` (`v7jzk`)

- **Purpose:** read-only detail of one check-in (code) — the pen's copy reads as a *day* view (**D-D1**: one check-in or the whole day; if check-in, the title needs the time).
- **Chrome:** `NavHeader` — back pill, "Today's Mood" 18/600 + "Monday, Jun 29 " 12/500, `NavPill(.more)` (menu undesigned: Edit, Delete, Transcript, Share/Export — export never gated); `FloatingTabBar.compact` + FAB stay visible (D-N4); content fits 874 by luck — must scroll with a bottom inset.
- **Layout (content x 28, width 344, section gap 24):** 150 "How Does It Feels Today?" 20/600 + `SignalSummaryCard` (Mood Great `#0e7718` 91 % · Focus Sharp `#447097` 56 % · Energy Charged `#e38400` 24 % — bar/label contradiction, use `level/5`) · 323 "Today's Emotional Condition" 16/600 + `BillChip.solid` "Proud", "Excited" 14/500 (29 high, raised) · 403 "Your Medications" 16/600 + `.small` row card 342 × 50: `MedicationBadge` 28 + "Concerta · 36 mg" 14/500 `#17501d` · 504 "Daily Check-In" 16/600 + `AISummaryCard` 342 × 183.75 (caption row · divider · body 12/400 · divider · player 42 % played, "03:24").
- **Copy:** C-01 "How Does It Feels Today?" · C-02 "Today's Mood" hard-coded · C-04 "Emotions" · C-05 medication heading (one of "Your Medications" / "Medication" / "Medications") · C-06 dose format · C-07 AI caption · C-08 "Daily Check-In" implies one per day · C-09 "03:24" vs "3:24" (both exist in code today) · signal order Mood-Focus-Energy vs Mood-Energy-Focus elsewhere.
- **States drawn:** one. **Not drawn:** sleep and side effects (both captured and editable today; the transcript even mentions "dry mouth" and "jitters"), the **transcript** and its transcribing / pending / failed / retry states (the only recovery UI today — removing it strands failed recordings), fallback-transcript-under-AI-byline guard, summary edited by the user ("tap to Correct" has no write path or provenance flag today — schema/tag decision), playing / scrubbing / finished / no-audio player states, missed doses, medication time/status, empty signal columns, unpleasant-emotion chip colour (all chips are solid green regardless of valence).
- **Open:** D-D1 · D-D2 diagonal separators · D-D3 column order · D-D4 waveform data · D-T2 body 12 vs 16 pt · where the transcript lives · what "+" does on a past day.

### 15.6 Edit Check-In — `iPhone 17 - 18` (`hSrrZ`)

- **Purpose:** the edit form for an existing check-in (today's `ExtractionReviewView` sheet). Low friction here is functional: "Save Changes" writes `RecordingTag(source: .userCorrected)` for mood/energy/focus/medication/emotions and trains the personal lexicon (sleep and side-effect edits persist but are not tagged — existing seam).
- **Chrome:** back pill + "Edit Check-In" 18/600 `#17501d` left of it; no trailing action; **no tab bar, no FAB** (drawn as a push, today a sheet — D-E1 push vs sheet; unsaved edits on back?).
- **Layout (x 29, width 344, gap 24; content ≈1389 tall):** 150 "Date & Time" 16/600 bare heading + two `DateTimeField`s ("Jun 29", "9:15 AM") · 266 `.large` card "How Did You Feel?" (stroke `#e4ece4` 1, inset 16) with collapse pill, divider, three `LevelTilePicker` blocks (mood → "Good" [tile 5 selected]; Energy Level → "Charged" [tile 1]; focus level → "Present" [tile 2] — captions contradict the selected tiles: placeholder) each with "Low / High", then "Your Sleep" chip row `Low · Flat · Good · Okay · Great` (Okay solid) · ≈777 `.large` card "Medication": chips Concerta · Ritalin · **Elvense** (solid); "Concerta Dose" 14/500; chips **60mg** (solid) · 18mg · 27mg · 36mg · Missed · **Taken** (solid) in one overflowing row · ≈984 "Emotions": Pleasant (10, "Excited" solid) / Unpleasant (10, "Frustrated" solid), rows clipped at the card edge · ≈1218 "Side Effects" (15; Headache, Rebound, Flat Affect solid; r 23 drift) clipped · ≈1359 "Save Changes" Filled M 344 × 44.
- **Copy:** "Elvense" → "Elvanse" · "mood " trailing space, "focus level" lowercase → consistent labels · "60mg" is an Elvanse strength listed under "Concerta Dose" (label must follow the selected medication) · "18mg" vs catalog "18 mg" · sleep chip order and vocabulary (D-V1: map onto `restless…deep` or show `Restless · Light · Okay · Good · Deep`).
- **States drawn:** all cards expanded; one selection per group. **Not drawn:** collapsed cards (D-K4), the date/time pickers (D-E3), disabled/dirty Save (D-E5), discard prompt, "none selected" (today's tap-again-clears), an Elvanse dose row (6 strengths + 2 = 8 chips), non-catalog medication.
- **Reversals of logged decisions the pen implies (re-decide on the record, §16):** synonyms dropped ("Great · bright, thriving"); sleep hours input dropped (hours are shown on the calendar but would become uneditable); medication **single-select** with one dose row instead of multi-select inline-expand with per-dose duration (the medication bar's fill window reads that duration); medication chips green instead of purple.
- **Open:** D-E1 · D-E2 selected-tile treatment (per level as drawn; L3/L4 tints missing) · D-E3 · D-E4 narrow devices (the 312 pt tile row fits only 402-wide) · D-E5 · D-K2 wrap vs scroll (recommend wrap) · D-V1 sleep · medication cardinality.

### 15.7 Statistics · Insights tab — `iPhone 17 - 7` (`xjEsl`)

- **Purpose:** monthly read-out — mood distribution, weekday averages, average ranges, time-of-day matrix, cross-signal connections.
- **Chrome:** page title "Insights" 34/600 + "Your Month At Glance" 16/500 `#6a6d70`; `FloatingTabBar.compact` + FAB (pen defect: Calendar pill active); canvas 2144 (scrolls ≈1270 pt; bottom inset ≥ 103).
- **Layout (x 29, width 344, gap 24):** 159 `SegmentedPicker` (June · **July** · Aug 2026) · 221 card 1 "Mood Check-In Breackdoen" + "24 check-ins" → `MoodBubbleChart` (8 % Low · 17 % Flat · 33 % Okay · 29 % Good · 13 % Great) + divider + legend chips "Low (2) · Flat (4) · Okey (8) · Good (7) · Great (3)" (clipped row) · ≈530 card 2 "Your month in three signals" / "Average Across Weekdays In July" → three `WeekdayGlyphRow`s (Mood "Mostly Okay"; Energy Level "Mostly Steady"; Focus "Mostly Sharp"; Su empty) · ≈940 card 3 "Where you averaged" → three `RangeBar`s ("Between Okay & Good" over Okay–Good ✓; "Between Tired & Steady" with axis `Steady Alert Tired Good Great` ✗; "Between Present & Sharp" with mood axis ✗) · ≈1329 card 4 "Your Daily Rhythm" / "Dominant level per signal by time of day" → `RhythmMatrix` (Mood Okay · Good · Great · —; Energy Steady · Alert · Tired · —; Focus Sharp · Sharp · Present · —) · ≈1709 "Connections" + caption → `ConnectionCard`s MEDICATION × FOCUS (unlocked: "On Medication Days, Sharp Focus Appeared 75% Of The Time." + bar 58 % labelled "70%"), SLEEP × MOOD (locked), ENERGY × MOOD (locked).
- **Data facts from code:** weekday values are rounded means (not modes); "mostly X" is the month mode; range = floor(mean) → `[lower, lower+1]` with a whole-number case the pen does not draw; bucket hours 06–11 / 12–17 / 18–21 / 22–05; connection gates 4 / 5 / 3+3 days (the "3 or more days" caption is wrong in both); the SLEEP × MOOD gate matches word lists the validator never writes — it **can never unlock on production data** (logic fix, test-first, before any restyle); "24 check-ins" counts all recordings while the chips count only those with a mood.
- **Copy:** "Breackdoen" · "Okey (8)" · "Your Month At Glance" · month label formats · "Mo Tu We Fr Fr Sa Su" · energy/focus axes → `displayLabel`s · "3More" · card A 75 / 70 / 58 % · casing mixes Title and sentence case across the four card titles · "Energy Level" (cards 2–3) vs "Energy" (card 4) · connection order (code: medFocus, energyMood, sleepMood — test-pinned) vs pen (medFocus, sleepMood, energyMood).
- **States drawn:** one. **Not drawn:** empty month / first launch (today: "Check in to see your month"), fewer than five mood levels (bubbles), whole-number averages, the current month's "next" segment, 053 shape cards (presence dots, month shape, variability bands, emotion field — decide merge-then-reskin vs archive first).
- **Open:** D-I1 month picker behaviour · D-I2 bubble formula · D-C2 amber text (`#e38400` "Mostly Steady" fails 3:1) · D-I4 rhythm tint rule · P3 unlock copy · sleep row (Frame 12 has a moon, data exists, pen draws none) · D-K2 legend wrap.

### 15.8 Settings — `iPhone 17 - 16` (`IoBoz`)

- **Purpose:** preferences in seven card groups, replacing today's native `insetGrouped List` (reverses 2026-06-24 — §16).
- **Chrome:** page title "Settings" 34/600 + "Make The App Works For You" 16/500; `FloatingTabBar.full` (`Status=Settings`, labelled pill) with the FAB floating above its right end (at rest it covers the Confirmations toggle — D-ST3); canvas 1899; bottom inset ≥ 170.
- **Layout (x 29, width 344; heading 16/600 → 12 → card; groups 24 apart):** "Check-In Claendar" `.large`: Voice Prompts 14/600 + description + chips "Brisk · 6 s" / **"Relaxed · 10 s"** · divider · Calendar Cards: "Auto-expand selected day" ON, "Always expand cards" OFF (small toggles, 12/500 labels) · "Voice & Storage" `.large`: Voice Transcription — ● Installed · Recording — 34MB · Download Over Cellular + "Allow voice-model downloads using mobile Data" — ON · "Confirmations" `.medium`: "Name medication in confirmations" ON + 4-line description + preview row "09:54 • Concerta 36 mg" on `#f4f0fb` · "Dose Guard" `.large`: `RadioRow`s Off / "Every Trigger Logs"; Total / "Blocked While A Does Is Still Active"; **Time Window** / "Blocked for a set time after a dose" · divider · "Blocked For" chips 1h · **2h ✓** · 3h · 4h · `InfoRow` "A second log is blocked for 2 h after your last dose. The in-app Log Dose sheet is never blocked." · "Medication Bar" `.large`: Show Medication Bar / Show Medication Name / Show Taken Time / Show End Time — four large toggles ON · "Accessibility" `.medium`: figure icon + "Squirl follows the iOS motion setting. Turn on Reduce Motion in Settings › Accessibility to still animations." 14/400 · "Your Data" `.medium`: "Acknowledgement" + "Your recordings, check-ins, and signals stay on this device. Nothing is uploaded." + chevron.
- **Copy:** "Claendar" · "Does" → "Dose" · subtitle grammar · mixed casing inside one card ("Every Trigger Logs" vs "Blocked for a set time…"; code is sentence case throughout) · "34MB" → "34 MB" + keep the recording count · "2h" vs "2 h" · "mobile Data" and "voice-model" (the flag gates both models) · "Recording" → "Storage" · preview order ("09:54 • Concerta 36 mg" vs the real confirmation string "Concerta 36 mg logged · 9:54 AM") · "Acknowledgement" (singular; today "Acknowledgements" is open-source credits and the privacy statement is a separate row).
- **Rows the pen omits that are mandatory or load-bearing (D-ST1):** Journal Insights (LLM) model row (only way back after "Skip for Now"), My Medication default picker (App Intent continuation target, source of the preview chip), Medication info disclaimer (App Review 1.4.1), **Journal export** (never gated — non-negotiable) + recovery-key sheet, Clear All Data (destructive style needed), **Privacy Policy** / Terms (hard gate), version label, **Subscription / Restore purchases** (055, App Review 3.1.1), ephemeral-store warning. **Not drawn:** model not-installed / downloading / error / delete states (the hardened, failure-prone path — design before implementing), preview OFF state, "Blocked For" when mode ≠ Time Window, rows 2–4 when the bar is off, the three per-mode footnotes.
- **Open:** D-ST1 · D-K5 native vs custom toggles · D-ST2 "Show Taken Time" / "Show End Time" semantics (no key, no bar slot today) · D-ST3 FAB collision / bottom inset · "Acknowledgement" destination · D-N7 medication bar on Settings · P12 privacy statement.

---

## 16. Decisions Log

New rows first. Old rows are carried verbatim as history; **⛔ superseded** marks rows this system replaces, **⚠ pending** marks reversals the pen implies that the owner has not yet confirmed, **✅ carried** marks rules that survive unchanged.

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-09-28 | ✅ **Owner accepted every recommendation** in `shipaton_plan/UI_REFRESH_PLAN.md` §1 (D1–D26) and every OWNER DECISION box in this document, as recommended: native SF (D-T1), dark tokens derived per token (D-DM), glyphs redrawn as Shapes with the black block read as a fill mask (D-G1/G3, Frame 12 sprout canonical D-G2, crown-growth cue kept D-P9), custom floating tab bar with the Add button hidden on the Check In root (D-N1/N2/N3), green-600 text fills + grey-300 captions + AA amber (D-C2/C3/C6/C7, D14), sentence case (D-COPY), ring arc step ⅓→⅔ + level glow, no rotation, no idle breathing (D-R2), header kept as an edit (D-P1). Every ⚠ pending row below is decided as recommended. | Owner, 2026-09-28: "all recommendations accepted, implement ASAP". Implementation runs on `feat/057-ui-refresh`; a decision that proves wrong on device is re-opened here, never changed silently. |
| 2026-09-27 | ✅ **Owner ask: the Pencil file `untitled.pen` is the source of truth for the visual language; `DESIGN.md` is rewritten from it** (this document), superseding Paper & Pollen (2026-06-15) and New Look (specs 032/033) as *reference*. Product Posture, Paywall & Purchase rules and the motion/accessibility rules carry over. | Owner: "pen file is the source of truth." This document is the planning artefact; implementation is post-Shipaton, sequenced after 055 lands (PLAN UI-04). Open owner decisions are indexed as D-* in this file. |
| 2026-09-27 | ⚠ pending **UI-02** — app-wide adoption specifics: light green-white ground, white hairline cards, green-500 action / green-800 titles (D-C3), violet second accent (P8), Frame 12 illustrated glyphs (D-G1/G2/G3, P9), floating pill tab bar + FAB (D-N1/N2/N3), Bill-shape chips (D-K2/K6), size/weight ramp (D-T1/T2), copy casing (D-COPY). | Nothing in this row is decided by the pen alone; each item is an open D-* until the owner answers it in UI-02. |
| 2026-09-27 | ⚠ pending **D-R2** — Check-in ring motion: the 2026-06-15 crescent rule (*revolves while listening ~7 s/rev with a voice-level glow; settles to a check when saved*) is reversed by the pen's static 33/66/100 % progress arc. Options (a) carry / (b) static / (c) arc step + level glow (recommended) with their Reduce Motion fallbacks are in §10. | Constraints §3.4 (Q-M1): carry the motion rules, route the crescent specifics to the owner. Logged here so the reversal is a decision, not an omission. |
| 2026-09-27 | Calendar tab **redesigned** per `iPhone 17 - 19` (week strip, mint-band expanded day, tinted previous-day cards). Supersedes the §Screen Specs line "Calendar. Unchanged … do not redesign without explicit ask" (2026-06-15). | Owner's explicit ask via the pen. Month grid / month swipe / compact title band (spec 035) are undrawn — D-J2 decides whether they go. |
| 2026-09-27 | Settings moves from the native grouped `List` to custom white cards, chips, radios and (recommended native) toggles per `iPhone 17 - 16`. **⚠ pending** owner confirmation — supersedes 2026-06-24. | The pen draws cards; the 2026-06-24 exemption was about a typeface rule that spec 023 already made moot. Mandatory rows the pen omits are listed in §15.8. |
| 2026-09-27 | Recording detail: back pill + `•••` menu supersede the system back + trailing pencil (spec 023), which had itself already replaced "no back button (swipe-left); pencil → Edit" (2026-06-15). | Code fact verified in `RecordingDetailView`; the pen changes the *form*, not the direction. Menu contents undesigned (D-J3). |
| 2026-09-27 | Edit screen: **⚠ pending** three reversals implied by `iPhone 17 - 18` — drop the synonym line; drop the sleep-hours input; medication single-select with one dose row (all 2026-06-15 decisions). | Each loses a function (lexicon nuance; editable hours shown on the calendar; per-dose duration that drives the medication bar). Re-decide on the record, not by omission. |
| 2026-09-27 | Signal glyphs: mood **sprout** stays; energy **bolt** stays (rising fill); focus **target ring + arrow** replaces the aperture; sleep **moon + star** 5-level ramp replaces the single bed icon; medication capsule becomes the pen's diagonal line-style capsule. **⚠ pending** D-G1 (black block), D-G2 (two "great" sprouts), D-G3 (assets vs Shapes), P9 (sprout colour-only). | Frame 12 is the drawn set. The 2026-06-15 "colour is never the only cue" rule is not waived by adoption. |
| 2026-09-27 | Typography stays **size/weight-defined**; Inter vs native SF is an open owner decision (D-T1, recommendation SF per spec 023). | The ramp is family-agnostic; Dynamic Type obligations favour SF. |
| 2026-09-27 | Dark mode: pen is light-only; option (1) derive-and-log per token is recommended (D-DM), consistent with the 2026-07-16 ruling. | The app has always shipped dark; the 2026-07-12 `#8A8A8E` exception is retired because the pen's caption grey (grey-300 `#6a6d70`, 5.21:1) is AA-compliant. |
| 2026-08-30 | ⛔ superseded (visual parts) / ✅ carried (paywall structure) — Doc corrected to match `main`: extraction is an **on-device LLM** (Qwen2.5-1.5B-Instruct-4bit via MLX, two-pass), not the old NaturalLanguage/NLP path (`NLSummarizationService` is now test-only); token path fixed `app-two/DesignSystem/` → `Packages/SquirlDesignSystem/…`. Added **Paywall & Purchase** posture + structural spec ahead of the RevenueCat build | The md files had drifted from the code; `main` is the source of truth. Paywall spec written before any SwiftUI so the HTML-mockup-first rule has something to check against, and so growth tactics can be ruled out by design rather than argued about later. *(2026-09-27: the NewLook-token bullets of §Paywall are restated in §14; RevenueCatUI reversal of 2026-09-04 noted there.)* |
| 2026-07-18 | ⛔ superseded — §Signal ramps energy/focus hexes corrected to the shipped `Palette+Signals.swift` values; design-audit remediations approved: `ink/destructive` light `#E0443A`→`#D54037` (5% darker, clears AA 4.55:1 on card), new `accent/medicationText` `#6B4E8F` for medication text on tinted surfaces (extends the R09 darker-word-color precedent), crescent gradient mid `#97C2A0`→`#96C19F` (code parity), Tiimo Colors gains a Dark mode (documented values only). Accepted-as-is: inkSecondary on tint bands/wells (extends the 2026-07-12 ruling), white-on-mood-5 bubble labels (ramp is three-way consistent; legend is redundant) | Full three-dimension design audit of the v3 catalog (`design-database/` audits №1–3, R22–R28); owner accepted the audit's judgment 2026-07-18. Code follow-ups (Theme.danger retint, medication text role) flagged, not yet implemented. *(2026-09-27: every value here is retired by §4; the "darker word colour" precedent (R09) is the right tool for the pen's amber/green-500 text failures.)* |
| 2026-07-16 | ⛔ superseded — Capture-flow surfaces (check-in · onboarding · recording-detail **edit**) adopt one green — `NewLook.checkInGreen` `#5FB36E`, the day-card "Good"-mood green — replacing the mint `selection` + meadow-gradient mix | Owner wanted these three to match the day check-in card, which has no fixed green (mood ramp), so its "Good" green was chosen. **Scoped, not app-wide** (owner call): new token + `.checkIn` chip role + `CheckInPrimaryButtonStyle` (green-only gradient); Insights chips and other primary buttons keep `selection`/meadow. `selectionSoft` → `checkInGreenSoft`. Landed straight to `main` per owner. *(2026-09-27: one green-500 for every filled control; `checkInGreen`, `selection`, `meadowGreen` all retire.)* |
| 2026-07-16 | ✅ carried as method — Contrast ruling on the spec-033 review's 8 WCAG findings: **fix derived dark-mode values, keep Figma-locked light values 1:1 and log them** | Figma specs light only; dark is derived, so fixing it isn't a deviation. Fixed: `onSelection` label token (dark ink on selection/medication fills in dark), medication dark `#9277BE`→`#957BC1`, Taken/Missed toggle re-grammar (`tintNeutral`+ink). Kept+logged: selection-green light family (chip label 2.52:1, green-on-white text, ramp ring, gradient/groove 2.14:1) — see palette note. *(2026-09-27: the specific values are retired; the "light locked, dark derived and logged" method is the D-DM recommendation. Whether green-500's 4.04:1 gets the same "locked" treatment is D-C3.)* |
| 2026-07-12 | ⛔ superseded — Keep `NewLook.inkSecondary` at Figma value `#8A8A8E` despite light-mode WCAG AA failure (3.0:1 sage / 3.4:1 white, need 4.5:1) | Owner chose Figma fidelity over the contrast fix when the spec-033 accessibility audit surfaced it app-wide. Documented as a known limitation (see palette note above); dark mode unaffected (~7:1). A compliant alternative (~`#6C6C70`) is on record if revisited. *(2026-09-27: the pen's secondary/tertiary greys are grey-400/300 and pass; `#8a8a8e` survives only on the AI caption and rhythm "—" — D-C6b proposes retiring it.)* |
| 2026-07-11 | ⛔ superseded — Adopt "New Look" as the app-wide visual language (spec 033), superseding spec 032's two-screen pilot scope | Two-screen pilot (Edit check-in, Recording detail) validated the language; owner approved app-wide rollout. `Theme` retained only for accent/meadow/status/danger semantic colours — every other screen migrates to `NewLook.screen` / `NewLook.card` / `.newLookCard()`. |
| 2026-07-10 | ⛔ superseded — Adopt "New Look" as a second visual language for Edit check-in + Recording detail (spec 032); dark tokens derived now; mixed P&P/New-Look shipped, no toggle | Owner adoption call after the Figma a-screens reached presentation grade; two lowest-risk screens prove the language before wider rollout. Calendar (a01) gated on spec-029. |
| 2026-06-26 | *(recorded from old §Typography)* ⛔ partly superseded — **Reversal (spec 023):** dropped the original **Fraunces + DM Sans + IBM Plex Mono** system — including the earlier rule "do not use SF/system as display or body, the 'gave up on typography' signal" — for native SF app-wide, an explicit owner decision. The bundled faces, `UIAppFonts`, and `SquirlFonts` registration were removed. (Settings was already SF-exempt; it now matches the rest of the app.) | *(2026-09-27: still in force unless D-T1 reverses it for Inter.)* |
| 2026-06-24 | ⚠ pending reversal — Settings is **exempt** from the "no SF/system as display or body face" rule | Settings deliberately uses the native iOS grouped-`List` chrome (system-font section headers, rows, footers). It is HIG-aligned and more learnable than a custom-typeface settings screen; the Fraunces/DM Sans rule governs Squirl's own content surfaces, not OS-standard utility chrome. *(2026-09-27: the font half is moot since spec 023; the native-`List` half is what `iPhone 17 - 16` reverses.)* |
| 2026-06-17 | ⛔ superseded (icons) / ⚠ pending (build target) — Sleep = bed, Medication = **horizontal** capsule, Mood icon **fixed** (selectable set removed) | Literal icons for the two non-self-state signals; one fixed Mood glyph. **Build target:** port all signal glyphs from SF Symbols → SwiftUI `Shape`s. *(2026-09-27: sleep → moon ramp, capsule → diagonal; "Shapes" remains the D-G3 recommendation.)* |
| 2026-06-16 | history — Glyph redesign "Bud" botanical (pod/seedhead) — explored, then **REVERTED** | Owner returned to the canonical sprout/lightning/aperture set. Net glyph change for Mood/Energy/Focus: none. Full register: `superpowers/plans/2026-06-16-design-decisions-ALL.html` *(link no longer exists in `docs/`; surviving registers are `design-database/` and `docs/superpowers/specs/*-design.md`)*. |
| 2026-06-15 | ⛔ superseded — Adopt "Paper & Pollen" design system | `/design-consultation`. Warm-paper organic identity differentiates from the blue/purple category; "refine Meadow, don't replace." |
| 2026-06-15 | ⛔ superseded — Keep shipped signal ramps; Energy stays Lemon | Owner override of the proposed Energy→Ember swap. Mood/Focus untouched. *(2026-09-27: energy is amber in the pen with a fill-height ramp, not a colour ramp.)* |
| 2026-06-15 | ⛔ partly superseded — Signal glyphs = sprout / lightning / aperture | Distinct shapes make the four signals colorblind- and grayscale-safe; chosen over sun/eye/etc. *(2026-09-27: sprout and bolt stay; aperture → target ring; the grayscale-safety rationale still binds — P9.)* |
| 2026-06-15 | ⛔ superseded — Sleep = single bed icon, ramp deferred | One icon now (like meds' capsule); add a bluer 5-step ramp later to clear med purple. *(2026-09-27: Frame 12 ships a 5-level **violet** moon — the "bluer to clear medication purple" intent is contradicted; P8.)* |
| 2026-06-15 | ⛔ partly superseded — Medication = purple `#7E5CA8`, capsule, fill-up no-alarm bar | Purple is the only unused hue; the bar fills empty→full over the dose; never alarms. *(2026-09-27: violet ramp `#8c68d3` / `#4d3974` / `#f4f0fb`, capsule and fill-up bar carried; "only unused hue" no longer holds — P8.)* |
| 2026-06-15 | ✅ carried — Check-in saved state shows no transcribing/card | Capture is the job of that moment; extraction is silent, results appear later. *(`iPhone 17 - 6` matches.)* |
| 2026-06-15 | ✅ carried (undesigned in the pen) — Type-note = Layout A (signals first) | Fewest taps for daily use; glyph pickers as input. |
| 2026-06-15 | ✅ carried — No streaks / no gamification / no med alarms | Removes the dominant reason ADHD users delete these apps. *(P3 / P4 / P5 test the pen against it.)* |
| 2026-06-15 | ⛔ superseded (see 2026-09-27 detail row) — Detail: no back button (swipe-left); pencil → "Edit check-in" button | From the owner screen-recording; the pencil was inconsistent with the interface. |
| 2026-06-15 | ⚠ pending reversal — Edit pickers keep named 1–5 scale + synonyms (Mood/Energy/Focus); Sleep drops synonyms + adds custom-hours input | Owner kept the named scale as "correct"; synonyms help mood/energy/focus, add noise on sleep. |
| 2026-06-15 | ⚠ pending reversal — Edit Medications: Stimulants only, multi-select, removable, P1 inline-expand, independent events, no limit | Non-stimulants/Off-label deferred (too complex now); inline-expand chosen over per-med sheet/table for the frictionless flow. |

### 16.1 Index of open owner decisions (D-*)

D-C1 token sprawl (snap vs tokenise) · D-C2 amber as text · D-C3 green-500 fills at 4.04:1 · D-C4 blue family · D-C6 five primary inks · D-C6b `#8a8a8e` · D-C7 `#6f7f75` · D-C8 strip greys · D-C9 two hairlines · D-C10 destructive style · D-C11 L3/L4 tints · D-T1 Inter vs SF · D-T2 12 pt body · D-COPY casing · D-S1 gutter · D-S2 card inset · D-S3 5 pt gap · D-S4 shadow tint · D-IC1 icon family · D-G1 black block · D-G2 two "great" sprouts · D-G3 assets vs Shapes · D-B1 violet outlined · D-B2 pressed state · D-K1 sharp check tile · D-K2 chip wrap vs scroll · D-K3 checked chip · D-K4 collapsed cards · D-K5 native toggles · D-K6 interactive chip-row pitch (27+17 vs 36+8) · D-N1 labelled vs icon-only pill · D-N2 FAB action · D-N3 custom vs native bar · D-N4 bar on pushed screens · D-N5 check-in topology · D-N6 "Home" · D-N7 medication bar placement · D-N8 back pill on saved · D-R1 ring meaning · D-R2 ring motion (carry / static / step + glow) + breathing · D-R3 prompt bar · D-DM dark mode · D-E1 push vs sheet · D-E2 selected tile · D-E3 pickers · D-E4 narrow devices · D-E5 dirty Save · D-V1 sleep vocabulary · D-J1 strip dot · D-J2 month chevron · D-J3 row menu · D-J4 glyph size · D-J5 medication icon · D-J6 cross-month list · D-D1 day vs check-in · D-D2 diagonals · D-D3 column order · D-D4 waveform · D-I1 month picker · D-I2 bubble formula  · D-I4 rhythm tints · D-ST1 missing Settings rows · D-ST2 taken/end time · D-ST3 FAB collision · D-PW1 RevenueCatUI styling · D-P1 header stamp (edit vs new file) · P1–P12 posture checklist (§13.1).
