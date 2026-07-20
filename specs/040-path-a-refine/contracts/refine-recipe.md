<!-- Created: 2026-07-20 19:12 (WEST) · Updated: 2026-07-20 19:12 (WEST) -->
# Contract — The Refine Recipe (measurable values, from the accepted a02-a)

Every `a0N-a` frame is checked against this literally. Source of truth: accepted pilot `a02-a` (`638:1465`). Where a value came from the pilot it is fixed; where marked *per-screen* the builder chooses within the stated bound and records it.

## 1 · Spacing tiers
- Card rhythm (root auto-layout `itemSpacing`): **20** · major-section break: **32** (20 + 12 spacer, the pilot mechanism) · tiers must differ ≥1.5×.
- In-card: padding 16; row gaps 12–14; kicker-to-fact gap 3.

## 2 · Cards
- Radius **20** (Tiimo `radius/card`), white card fill (existing bound token), **exactly one** soft shadow: `0 2 8 @5%` (the pilot's kept layer).
- Merged-card row: `icon 22×22 slot · 12 gap · [kicker 10pt +0.6 tracking caption-gray · 3 gap · fact 15pt Semi Bold ink]`; kicker gray must be ≥4.5:1 (`#6C6C70` reference).
- Destructive content isolated in its own card; never merged.

## 3 · Data marks
- Bars: fill **≥6pt**, radius 3, on a visible track (`#3C3C43 @12%`, radius 3); fill = the signal's ramp, darkened steps allowed for legibility (same hue family).
- Glyphs: sprout/bolt/aperture shapes unchanged; stroke-built glyphs carry enough weight to match filled glyphs' presence at rendered size (pilot: aperture ×1.8 → ~1.1–2.0 depending on scale). After any `rescale`, stroke weights are re-set explicitly.
- Ramp colors on data marks only — never on controls or chrome.

## 4 · Chrome
- Status bar on all 8 frames (clone of the canonical one), 44pt, y0.
- Med bar (a01/a02/a07/a08): **inset 358×44, radius 14, `accent/medication` tint via node-opacity 10% rect** (paint-level opacity is unreliable — standing gotcha), capsule glyph + `medicationText` 13 Semi Bold + trailing status 10pt, **no shadow**. Identical anatomy on all four frames.
- The capture trio (a04–a06) has no med bar (by design).

## 5 · Controls & selection
- One interactive green per context: capture flow `checkInGreen` (#5FB36E), all other surfaces `selection` (#54B492). That green marks action/on/selected — nothing else on the screen uses it, and it never encodes data.
- Chips: **h36, r18 pill, 13pt label, ≥8pt gaps** (≥44pt effective slot); selected = interactive-green fill + AA label; unselected = white + hairline stroke. One family per screen.
- Toggles: existing 51×31 switch, ON = the context green.
- Mutually-exclusive modes (Dose Guard): radio-rows in one card, selected row = green ring/check.
- Destructive = the existing red (`ink/destructive` #D54037), text/row treatment, isolated card.

## 6 · Type roles
- Card title 17 Semi Bold · row fact 15 Semi Bold · kicker 10 caps +0.6 · footnote/caption 13 · body 13–15. No new faces, no role mixing (a title style is never a row style).

## 7 · Color & AA
- Text ≥4.5:1 on resolved surface, computed not eyeballed (composite tinted grounds first).
- Purple only on medication identity; audio/player and any non-med control = neutral ink.
- Signal words may keep ramp/word colors **as data readings** (pilot precedent: GREAT/CHARGED/SHARP stay) — but must pass AA where over tinted grounds.

## 8 · Parity & structure
- 100% of the screen's inventory strings survive (case/joiner transforms documented per screen).
- Frame stays an auto-layout; deltas work with it (no absolute-position rebuilds).
- Each `a0N-a` sits at its original's x, y≈1150 (the pilot's side-by-side column convention).

## Acceptance
A screen passes when: every applicable line above holds by measurement · parity 100% vs its 039 inventory · its mapped audit findings are gone · the owner judges it side-by-side ("still Squirl, now ranked").
