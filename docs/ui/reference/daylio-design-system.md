<!-- Created: 2026-06-30 16:27 (WEST) · Updated: 2026-07-02 15:05 (WEST) -->
# Daylio — Reverse-Engineered Design System (reference)

> **Scope.** This is a *reference teardown* of the third-party app **Daylio**, extracted from 8 screenshots for inspiration/comparison. It is **not** app-four's design system — see root `DESIGN.md` for that. Do not copy values into app-four without a deliberate design decision.

## Provenance & method
Derived from 8 iPhone screenshots (1170×2532 px, @3x → **pt = px ÷ 3**). Values were obtained by **PIL pixel-sampling** (median RGB over near-uniform swatches, circle-fit for radii, cap-height for type), cross-checked by independent agents and adjudicated by re-measurement. Confidence is labelled per value.
- **Batch 1** (`IMG_5142–5146`, 3 dark + 2 light: entries/stats/calendar) — **Theme A** (teal accent). Re-verified 2026-07-02; corrections marked ✎.
- **Batch 2** (`IMG_4580–4582`, 3 light: entry composer, activity picker, FAB context menu; `IMG_4586`, 1 light: Entries tab with multi-entry day card) — earlier capture on a **different palette (Theme B**, green accent); added 2026-07-02. Proves palette theming (see §2). `IMG_4586` provided the first **sharp** Theme-B mood colors.

- **[M]** measured from pixels (high confidence)
- **[I]** inferred (glyph/structure reasoning; needs source/live-app to confirm)
- **⚠** saturated color: value is the **stored P3-encoded** pixel; convert to sRGB with macOS Digital Color Meter on the live app before using as a token.

## 1. Identity
**Daylio** (Journal/Mood Tracker). Confirmed from the signature default mood lexicon **rad/good/meh/bad/awful** + feature set (Days in a Row/Longest Chain, Mood Chart, Mood Count gauge, activity chips, quote card). No wordmark on screen — identity is sourced inference. Sources: trackinghappiness.com/daylio-review, daylio.net/how-to-track-moods.

## 2. Color

### ⚠ Palette theming (cross-batch finding, 2026-07-02)
The **accent AND the mood ramp are user-configurable as a set** — the two batches show two different palettes on the same install. All "one shared token" / "mode-independent" claims below hold **within a theme**, not across themes.
| | Accent | rad | good | meh | bad | awful |
|---|---|---|---|---|---|---|
| **Theme A** (batch 1) | `#66B3B5` teal | `#F0A180` | `#8DBE41` | `#94CF95` | `#82B3DB` | `#9F7CB3` |
| **Theme B** (batch 2) | `#54B492` green **[M]** | face `#6BC2A7` / text `#54B492` **[M]** | face `#AED568` / text `#9ACB4A` **[M]** | `≈#8DBDE0`* | face `#EDA75C` / text `#E8913D` **[M]** | `≈#E9737E`* |

\* meh/awful still only sampled through the blurred Mood-Count legend (blur mixes toward white; true values more saturated). rad/good/bad measured **sharp** from `IMG_4586` (Entries tab). Theme B is plausibly the app default (green/lime/blue/orange/red matches Daylio marketing) — **[I]**. Theme-B dark mode: not captured.

**Face-fill vs text-tint pairs (Theme B) [M]:** each mood has TWO tones — a lighter **avatar/face fill** and a darker **text tint** used for the mood word, timestamp-adjacent chips and tag icons/labels (`rad` text tint == the accent `#54B492`). Theme A showed a single tone per mood; whether the pairing is theme-specific or was simply unresolvable in batch 1 is open — **[I]**. Tag chips in Theme B light are **mood-tinted (icons + labels)** per entry; Theme A dark showed grey labels (`#B7B7BF`) with tinted icons — mode- or theme-dependent, unresolved **[I]**.

### Neutrals (mode-specific; NOT a simple inversion)
| Role | Dark | Light |
|---|---|---|
| Background | `#000000` **[M]** | `#ECECF1`–`#F2F2F6` **[M]≈** (flat `#EEEEF2`; card gaps read darker, `#EBEBEF`, from card shadows) |
| Surface / card | `#1C1C1D` **[M]** | `#FFFFFF` **[M]** |
| Text primary (incl. dark date header + nav title) | `#FFFFFF` **[M]** | `#000000` **[M]** |
| Text secondary (tags, timestamps) | `~#B7B7BF` **[M]** (timestamp `#B7B7BE`) | `#6C6C6C` **[M]** |
| Text tertiary ("N Days Missing") | `~#808080` **[M]** | ✎ `~#78787B` **[M]** (was `~#8E8E93` [I]) |
| Destructive / badge | `#EA3323` **[M]** | `#EA3323` **[M]** (byte-identical both modes) |

Dark uses pure-black bg with near-black **elevated** cards; light uses light-grey bg with white cards — mirrored iOS grouped-inset elevation. Greys are close to Apple semantic label colors (`label`/`secondaryLabel`) — **[I]**.
**Elevation ✎:** light-mode cards cast a **diffuse drop shadow** (bg sampled `#D0D0D4` just below a card edge vs `#ECECF1` flat) — dark-mode cards are **flat** (color-only elevation, no shadow). **[M]**

### Accent (theme-scoped — see Palette theming above)
- **Theme B green `#54B492` ⚠ [M]** — measured byte-identical across: Today CTA, selected activity chips, composer Save FAB, top Save circle, category dots, "+"/collapse glyphs, "Open Full Note" link, Edit-Activities pencil, context-menu icons. Same single-token discipline as Theme A.
- Teal `#66B3B5` ⚠ **[M]** (Theme A) — FAB, active-tab tint, nav chevrons, streak check nodes. **One shared token**, pixel-identical in light & dark. Re-verified byte-identical `#66B3B5` on: chevron discs, streak nodes, active-tab label, calendar "add +" text, average-mood chip smiley. FAB fill samples `#64B2B4`–`#65B2B4` (≈ same token; slight gradient/AA).
- **Disabled accent ✎:** dimmed forward-chevron = teal at **~25 % opacity over the background** in *both* modes (`#192F2F` on black, `#D6E5E9` on white). **[M]**
- **FAB plus glyph inverts with mode**: black in dark, white in light. **[M]**

### Mood ramp — the core 5-level scale (Theme A values)
**Mode-independent within the theme** (byte-identical dark==light, proven by sampling both). All ⚠ **[M]**:

| Level | Word | Hex | Note |
|---|---|---|---|
| 5 best | rad | `#F0A180` | soft salmon/coral |
| 4 | good | `#8DBE41` | lime green |
| 3 | meh | `#94CF95` | desaturated mint |
| 2 | bad | `#82B3DB` | sky blue |
| 1 worst | awful | `#9F7CB3` | muted purple |

Re-verified: all 5 hexes byte-identical dark==light on avatars, chart y-axis faces, calendar fills, and Mood-Count gauge segments. **Mood-word text strokes use the exact ramp hexes** (no darkening for text). **[M]**

Derived / calendar-specific:
- **Today marker ✎:** a **mood-filled disc + concentric ring** in the *same* mood color (`#F0A180` measured on both ring and fill), structure ≈ fill · ~2pt gap · ~2pt ring, same ~41pt footprint as a plain day. NOT a hollow ring over bg, and not `#DF9678` (that value came from a blended day, see next). **[M]** (Today had an entry; no-entry today state unverified.)
- **Blended average fills ✎ (new):** in "average mood" calendar mode, some days show **interpolated colors between ramp stops** — measured `#E29778` (day 3) and `#D58F72` (day 10) vs pure rad `#F0A180` (day 5). Consistent with multi-entry days averaging (24 entries over ~16 logged days per Mood Count). Interpolation function unknown — **[M]** colors, **[I]** mechanism.
- Out-of-month day = `#3E4C24` **[M]** (≈ that day's mood color at ~45 % brightness — **[I]**).

## 3. Typography
**Two families.**
- **Chrome** (nav, card titles, dates, tags, timestamps): **SF Pro** — double-story `a`, flat terminals. **[M]**
- **Mood words** (rad/good/meh): a **custom rounded geometric Bold** with a **single-story `g`** (one bowl + open hook), near-circular bowls, blunt terminals — distinct from the chrome. **[M]** for the *class*; exact name **not publicly documented**. Closest renders: **Quicksand Bold / Nunito Bold / Baloo 2** (all single-story). Pin via Daylio's asset bundle or a WhatTheFont upload. (Original "Nunito" guess was right on family; "not SF Pro" is proven; Nunito is **not** excluded — current Google Fonts Nunito is single-story.)

Size hierarchy (cap-height ÷ 0.714; re-measured 2026-07-02, ±1pt):
| Token | ≈ pt | Conf | Weight |
|---|---|---|---|
| Card title ("Days in a Row") | ~22 | [I] | Bold |
| Nav title ("June 2026") | **22.4** (capH 48px) | [M] | Bold/Semibold |
| Mood word (display) | ~21–22 ('d'-ascender 49px; rounded-font metrics → est.) | [M]≈ | Bold, mood-tinted |
| Date label ("TODAY, 29 JUN") | **13.5** (capH 29px on "JUN") | [M] | Semibold, UPPERCASE, tracked; **white in dark mode** (`#FFFFFF` measured) |
| Body / activity tag | ~14 | [M]≈ | Regular |
| Timestamp / weekday / axis | **~13** ("22:00" capH 27px) | [M] | Regular |

## 4. Layout (pt @3x)
| Metric | Value | Conf |
|---|---|---|
| Horizontal margin (hard edge) | **12pt** (36px, both sides) | [M] |
| Card corner radius | ✎ **26pt** (circle-fit R≈78px; stable across thresholds 25/42/60 *and* on the light-mode shot, R=78–80px; was 24pt) | [M] |
| Inter-card gap | **20pt** (60px); ✎ gap below quote card is **18pt** | [M] |
| Card internal padding | ~17pt (avatar left inset 17.3pt) | [M] |
| Row height | content-driven — ✎ **78pt tagless** (was "~70pt min"), **129pt** w/ tags | [M] |
| Mood emoji avatar | ~43pt (129px, slightly non-circular) | [M]≈ |
| Calendar day circle | ~41.5pt (124–125px; grid pitch ✎ **49.5pt**/148px) | [M] |
| FAB | **62pt** (185px) diameter; right margin **16pt**, bottom inset **21pt** from screen edge | [M] |
| Tab bar | **custom floating pill**, ✎ **62pt tall** (185px — same height & 21pt bottom inset as FAB, one aligned row); left inset ~27pt; not standard UITabBar | [M] |
| Nav bar | **custom** circular icon buttons + centered title, ~44pt band; chevron disc **25pt** (75px) | [M]/[I] |
| Streak node (Days in a Row) | **34pt** (102px) | [M] |
| Quote card | height **117pt** (351px) | [M] |

## 5. Components
Quote/affirmation card (image bg + teal overlay + italic quote; 117pt tall) · Entry row (mood avatar + tinted date + mood word + time + wrapping activity-tag chips + "⋯" overflow) · Section divider ("14 Days Missing") · Days-in-a-Row streak (node rail + count chip + "🏆 Longest Chain") · Mood Chart (gradient line + emoji y-axis + line/bar toggle + "Select Activity" pill) · Calendar month grid (mood circles + weekday header) · Average-mood metric selector chip (teal smiley + "14×" count + ▾ + "add +") · Mood Count semicircle gauge (segments = exact mood-ramp hexes + center total + legend count pills) · Achievements card · FAB (plus glyph inverts with mode) · Custom floating tab bar (62pt pill, FAB-aligned) · Circular icon buttons (25pt discs: chevrons, search, share).

**Entry flow & menu (batch 2, light, Theme B) [M]:**
- **Activity picker** — "Search activity…" pill field · white category cards ("Emotions/Sleep/Health" title + accent dot + circled "+" and collapse-chevron buttons) · **activity chips 50pt**, icon + label below, wrapping 5-per-row grid.
- **Entry composer** — Quick Note ("Add Note…" field `#F2F2F2`, "Open Full Note" accent link) · Photo ("Tap to Select Photo…" field) · Voice Memo (full-width "Tap to Record" field + trailing accent mic disc) · **54pt circular Save button** + "Edit Activities" (accent pencil) footer · nav pill: back chevron + current mood face + "✓ Save" pill.
- **FAB context menu** — iOS-material grouped menu: rows with leading `#F6F6F6` rounded-square icon chips (icons accent-tinted), "Create Entry" section label, destructive-free; **full-width 50pt accent "Today" CTA** at the bottom.
- **Entries tab, Theme B light (`IMG_4586`) [M]:** integrated **quote nav-header** (photo + green gradient overlay, italic white quote behind a centered title row of translucent-white 40pt circle buttons: calendar-star · chevrons · search) · **multi-entry day card** (accent-tinted `#D6EFE9` header band with ring glyph + accent "TODAY, 2 JUN", stacked entry rows, `#DBDDDE` **timeline connector** between avatars) · single-entry cards carry the black date label inline · **month divider pill** ("May 2026", white pill, black semibold) · grey footer hint ("This has been your first entry.") · tab bar/FAB as measured in batch 1 geometry with Theme-B colors.

## 6. Component states (NOT default-only)
- Tab bar ✎: **active** = **grey chip** behind the item (`#3E3E3F` dark / `#E8EAE9` light) with **teal icon+label** (`#66B3B5`); **inactive** = near-white label/icon in dark (`#E9E9EA`), dark in light. Pill bg: `#1C1C1D` dark (same token as card) / `#FCFCFF` light. (Was "teal-tinted pill" — the tint is in the glyphs, not the chip.) **[M]**
- Streak nodes: **completed** (teal + white check) vs **empty/future** (grey +).
- Calendar day: **logged** (mood fill) / ✎ **today** (mood fill + concentric mood ring, see §2) / ✎ **multi-entry** (blended average fill, see §2) / **future** (plain number) / **out-of-month** (dimmed).
- Nav chevron: forward **disabled/dimmed** on current month — ✎ present in **both** modes (teal @ ~25 % opacity), not just light shots. **[M]**
- Trophy avatar: **red notification badge**.
- Chart: line-view **selected** vs bar-view unselected.
- **Activity chip (batch 2)**: **selected** = accent fill + white glyph · **unselected** = white fill + `#DBDDDE` hairline ring + accent-tinted glyph. **[M]**
- **Category card (batch 2)**: expanded (chevron ˄) vs collapsed; accent dot = "has selections". **[M]/[I]**
- Not captured: pressed, hover, empty-data, loading, error.

## 7. Motion
**Not extractable from stills** — transitions, chart draw, streak fill, month paging, FAB→editor, spring curves all require the live app or source.

## 8. Still needs live-app / source verification
1. sRGB values for all ⚠ saturated tokens (mood ramp, teal) — Digital Color Meter on device.
2. Exact mood-word font name — asset bundle or WhatTheFont (`actual_good_clean.png`).
3. Weights + Dynamic Type behavior — source. (Sizes now measured, see §3.)
4. Whether the greys are Apple semantic colors (values now measured in both modes).
5. All motion specs.
6. Pressed/empty/error/loading states.
7. ✎ Calendar average-mood **blend function** for multi-entry days (`#E29778`, `#D58F72` observed).
8. ✎ Today marker when today has **no entry** (hollow-ring-only hypothesis untested).
9. ~~Theme-B ramp unblurred~~ **partially resolved 2026-07-02** (`IMG_4586`): rad/good/bad measured sharp incl. face/text pairs; **meh + awful still blur-only**; Theme-B **dark mode** still missing.
10. **Theme catalog** — how many palettes Daylio ships, and whether accent/ramp are always paired.
