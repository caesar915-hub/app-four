# Data Model: New Look Screens (Spec 032)

**Date**: 2026-07-10

This feature persists **no data** — no `@Model`, no schema, no migration (Constitution IX
trivially satisfied). The "data model" here is the **design-token schema**: the named values the
two screens bind to. This is the single source of truth for the token names, their light/dark
values, and their Figma origin. All values are adaptive `Color(lightHex:darkHex:)` unless noted.

## Entity: `NewLook` color namespace (new file `NewLook.swift`)

| Token | Type | Light | Dark (derived, D3) | Figma origin |
|---|---|---|---|---|
| `NewLook.screen` | `Color` | `#EFF2EB` | `#12140F` | `surface/screen` |
| `NewLook.card` | `Color` | `#FFFFFF` | `#1C1E19` | `surface/card` |
| `NewLook.inkPrimary` | `Color` | `#1C1B1F` | `#F2F3EE` | `ink/primary` |
| `NewLook.inkSecondary` | `Color` | `#8A8A8E` | `#9BA09A` | `ink/secondary` |
| `NewLook.hairline` | `Color` | `#DBDDDE` | `#33362F` | `border/hairline` |
| `NewLook.selection` | `Color` | `#54B492` | `#5FC49F` | `accent/selection` |
| medication | `Color` | — | — | reuse `Palette.medication` (`#7E5CA8`/`#9277BE`) — NOT redefined |

**Rules / invariants**
- All seven roles are **light+dark adaptive**; no screen may render dark-on-dark or
  white-on-white (spec edge case; verified at QA).
- Medication is **never** re-expressed — chips/pills with `role == .medication` bind
  `Palette.medication`; all other selected chips bind `NewLook.selection` (FR-002, FR-003).
- Dark hexes are the plan's derivation; owner device QA may nudge them without a spec change.

## Entity: `Radius` extension

| Token | Value | Status |
|---|---|---|
| `Radius.newLookCard` | `20` | NEW |
| `Radius.card` | `16` | UNCHANGED (Paper & Pollen; other screens) |
| `Radius.control`, `chip`, `button` | 10 / 15 / 16 | UNCHANGED |

## Entity: component grammar (modifiers/styles in `NewLook.swift`)

| Symbol | Shape | Contract |
|---|---|---|
| `.newLookCard(padding:)` | View modifier | fill `NewLook.card`, corner `Radius.newLookCard` (20), soft shadow, **no border** |
| `newLookChip(selected:role:)` | chip/pill style | unselected: `NewLook.card` fill + `NewLook.hairline` 1px border + `inkPrimary` label; selected: solid fill (`selection`, or `Palette.medication` if `role == .medication`) + white label |
| nav-row helper | layout | edge back pill + edge Save pill + **centered title** (overlay/ZStack so title centering is independent of pill widths) |

**Enum: chip role** — `enum NewLookChipRole { case standard, medication }` (or reuse the existing
signal-kind type if it already carries "is medication"; decided at implementation, minimal).

## Typography (no new entity — mapping only, D2)

No new `Typography` roles. Screens bind existing roles; the 24pt nav title uses the existing
`Typography.text(24, weight: .bold, relativeTo: .title)` helper. Full mapping table in
[research.md](research.md) §D2.

## State transitions

None. Static tokens; no lifecycle, no persistence, no derived state.
