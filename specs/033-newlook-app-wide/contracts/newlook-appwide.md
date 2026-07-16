# Contract: App-Wide New Look Surface + Med-Bar Behaviour (Spec 033)

**Date**: 2026-07-11. The interface contract for this app-feature is the **UI surface every screen must produce** plus the **one behavioural guarantee** of the med-bar fix. This is the reviewer's checklist against the a-screen language and the acceptance scenarios. Extends spec-032's [newlook-tokens.md](../../032-newlook-screens/contracts/newlook-tokens.md); reuses that token API unchanged except the two additions below.

## Token API delta (added to `SquirlDesignSystem`)

```
enum NewLook { static let tintNeutral: Color }          // #ECEAE6 light + derived dark — grooves/tracks
extension View { func newLookCard(...) }                 // shadow → 2-layer Tiimo/Shadow/Card
// Deleted in the final PR once unreferenced: Theme.{background,cardBackground,surface2,
//   elevatedBackground,textPrimary,textSecondary,separator,cardStroke} and .card()
```

## Surface contract — every screen (verify against the a-screen language)

| # | Element | Contract |
|---|---|---|
| S1 | Screen ground | `NewLook.screen` on every tab + sheet; nav/tool bar shares it; **no `Theme.background`/`cardBackground` surface remains** |
| S2 | Card | `.newLookCard()` — white, radius 20, **no border**, 2-layer soft shadow; no `.card()` and no manual `Theme.cardBackground` fills remain |
| S3 | Groove/track | `NewLook.tintNeutral` (never `card` white, never a border colour) — visible on white cards |
| S4 | Primary text | `NewLook.inkPrimary` |
| S5 | Secondary/caption text | `NewLook.inkSecondary` |
| S6 | Divider/hairline | `NewLook.hairline` (row dividers/field borders); card borders **dropped** |
| S7 | Selection | non-medication selected chips → `NewLook.selection` (green); medication chips → `Palette.medication` |
| S8 | Tab bar | explicit sage/white appearance — reads as part of the ground, not system chrome |
| S9 | Semantic colours | `accent`, `meadow*`, `status*`, `danger` (warm clay), `Palette.medication`, signal ramps, mood/category/tag tints **unchanged** |
| S10 | Glyphs | shapes unchanged; only container/colour context restyled |

## Med-bar contract

| # | Element | Contract |
|---|---|---|
| M1 | Container | `.newLookCard()` (borderless r20), replacing `.card()` |
| M2 | Dose track | groove `NewLook.tintNeutral`; fill `Palette.medication` (unchanged) |
| M3 | Text | name `inkPrimary`, subline `inkSecondary`; state word `Palette.medication` (unchanged) |
| M4 | **Behaviour (FR-009)** | a dose logged in the app's current mode **appears** in the bar within its active window; a dose past its window disappears; empty-state reserves zero space; the visibility setting still hides it |
| M5 | Partition | `isMockData` mock/real split preserved (Constitution IX); no schema change |

## Cross-cutting

| # | Constraint | Verify |
|---|---|---|
| X1 | No literals | style-literal audit of migrated files → zero hardcoded colour/radius/shadow (FR-011, SC-003) |
| X2 | Both appearances | every token + `tintNeutral` + hairline-on-sage legible in light AND dark (FR-012, SC-006) |
| X3 | No behaviour change (except M4) | existing VM suites green; manual flow parity (FR-010, SC-005) |
| X4 | Test-first | FR-009 has a RED `MedicationBarViewModelTests` case before the fix (Constitution X) |
| X5 | Verify-only | `RecordingDetailView`, `ExtractionReviewView`, `ADHDSummarySection` confirmed unregressed on the D3 shadow + D2 groove; never re-Themed (FR-013) |
| X6 | No dead code | after PR-3, full-repo grep of the 8 deleted tokens + `.card(` → zero; clean rebuild (FR-017, SC-002) |

## Out of contract (excluded)

- Calendar day timeline / a01 (gated on spec-029, FR-018).
- Any schema change, new attribute, or new service.
- Figma `ink/destructive #e0443a` (warm-clay `Theme.danger` retained, FR-015).
