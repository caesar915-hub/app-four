# Contract: New Look UI Token & Component Surface (Spec 032)

**Date**: 2026-07-10

The "interface contract" for this app-feature is the **UI surface**: the public token/modifier
API the two screens consume, and the visual states they must produce to match the binding Figma
mockups. This is the checklist a reviewer verifies against the mockup and the acceptance
scenarios. Figma file: Squil-Design (`M0Meys9X89X1NLyT14qrX5`) → page "Screens (v2)".

## Public API added to `SquirlDesignSystem` (contract surface)

```
enum NewLook {                       // colors (light+dark adaptive)
  static let screen, card, inkPrimary, inkSecondary, hairline, selection: Color
}
extension Radius { static let newLookCard: CGFloat = 20 }
extension View  { func newLookCard(padding:) -> some View }          // borderless, r20, soft shadow
                  func newLookChip(selected:, role:) -> some View     // white+hairline / solid+white
// nav-row helper: back pill · centered title · Save pill
```
- `Theme`, `Palette`, `Typography`, and the `.card()` **definition** are **unchanged** — the
  contract adds, never mutates. US2 migrates 2 of the 4 `.card()`-consuming files
  (`RecordingDetailView`, `ADHDSummarySection`) to `.newLookCard()`; the **2 that stay Paper &
  Pollen are `RecordingRow` and `MedicationBarView`** (plus every `Theme.*` screen) — FR-011.

## US1 — a03 Edit check-in (node `308:1654`) — required visual states

| # | Element | Contract (must match a03) |
|---|---|---|
| C1 | Screen | `NewLook.screen` background, 16px content gutter |
| C2 | Nav row | back pill + Save pill at edges; title **centered on screen axis** (equal L/R) |
| C3 | Card | `.newLookCard()` — white, radius 20, soft shadow, **no border** |
| C4 | Card header | bold sentence-case: Signals · Sleep · Medications · Emotions · **Side effects** (not SYMPTOMS) |
| C5 | Group eyebrow | uppercase tracked micro-label (MOOD/ENERGY/FOCUS, PLEASANT/UNPLEASANT) |
| C6 | Chip unselected | `NewLook.card` fill + `NewLook.hairline` 1px border + `inkPrimary` label |
| C7 | Chip selected (standard) | solid `NewLook.selection` + white label |
| C8 | Chip selected (medication) | solid `Palette.medication` + white label (Concerta, dose, Taken) |
| C9 | Behavior | select/deselect/save/cancel identical to current (FR-005) |

## US2 — a02 Recording detail (node `308:1594`) — required visual states

| # | Element | Contract (must match a02) |
|---|---|---|
| C10 | Screen | `NewLook.screen` background, 16px gutter |
| C11 | Hero strip | 3 equal columns (glyph · level word · uppercase micro-label · level bar) |
| C12 | Info cards | `.newLookCard()`; bold sentence-case header + leading icon: Medications · Sleep · Emotions · Side effects · Transcript |
| C13 | Card body | `inkPrimary`, `NewLook.card` surface, one body size across cards |
| C14 | Audio card | play control (medication purple), progress track, mono duration label — **card internals restyled (T017), not just the container** |
| C15 | Delete row | destructive treatment (`Theme.danger` reused — warm clay, never raw red) |
| C16 | Transcript | full text wraps, no clip/overlap at any Dynamic Type size |
| C17 | Behavior | playback / edit entry / delete identical to current (FR-005) |

## Cross-cutting contract

| # | Constraint | Verify |
|---|---|---|
| X1 | No literals | style-literal audit of both view files returns zero hardcoded color/radius/shadow (SC-003, FR-006) |
| X2 | Both appearances | every token legible in light AND dark; contrast holds (FR-009, SC-004) |
| X3 | No behavior change | existing VM suites green; manual flow parity (SC-002) |
| X4 | Isolation | non-target screens + the 2 remaining P&P `.card()` consumers (`RecordingRow`, `MedicationBarView`) + mascot tab bar / `RootTabView` / status chrome visually unchanged (FR-011) |
| X5 | Glyphs | sprout/bolt/aperture/bed/capsule shapes unchanged; only container/color restyled (FR-008) |

## Out of contract (explicitly excluded)

- Mascot tab bar, status-bar chrome, `RootTabView` (FR-011).
- Calendar timeline a01 / US3 — gated on spec-029 (FR-012), separate PR.
- Demo content values from the mockups (names/times) — not binding (assumption).
