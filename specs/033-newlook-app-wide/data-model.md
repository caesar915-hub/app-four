# Phase 1 Data Model — App-Wide New Look Migration

This feature is a re-skin plus one behavioural fix. It adds **no persisted entity**, **no attribute**, and **no schema migration**. Two kinds of "model" matter: the design-token additions (the contract every screen binds to) and the single existing data field the med-bar fix touches.

## 1. Design-token additions (`SquirlDesignSystem`)

| Token | Light | Dark (derived) | Scope | Figma source | Requirement |
|---|---|---|---|---|---|
| `NewLook.tintNeutral` | `#ECEAE6` | `#272A22` | fills (tracks/grooves/segmented) | `tint/neutral` | FR-001 |

Card treatment change (no new token — modifier body only):

| Modifier | Change | Figma source | Requirement |
|---|---|---|---|
| `.newLookCard()` shadow | single-layer `0.06 r8 y2` → two-layer `#0000000D r8 y2` + `#00000008 r2 y1` | `Tiimo/Shadow/Card` | FR-002 |

Already present (spec-032, unchanged): `NewLook.screen #EFF2EB`, `NewLook.card #FFFFFF`, `NewLook.inkPrimary #1C1B1F`, `NewLook.inkSecondary #8A8A8E`, `NewLook.hairline #DBDDDE`, `NewLook.selection #54B492`, `Radius.newLookCard = 20`, `Palette.medication #7E5CA8`.

Tokens **deleted** at the end (FR-017, PR-3) once zero consumers remain — `Theme`: `background`, `cardBackground`, `surface2`, `elevatedBackground`, `textPrimary`, `textSecondary`, `separator`, `cardStroke`; `Card`: `.card()` + its stroke path. **Retained** on `Theme`: `accent`, `meadowGreen`, `meadowAmber`, `meadowGradient`, `statusDone`, `statusInProgress`, `danger`.

## 2. Touched persisted field — `MedicationEvent.isMockData`

- **Entity**: `MedicationEvent` (`@Model`). **No change to its shape.**
- **Field**: `isMockData: Bool = false` — the existing mock/real partition flag (Constitution IX).
- **Change (FR-009 only)**: `MedicationBarViewModel.logManualDose(...)` sets `isMockData` on the new event to the active mode (`UserDefaults.standard.bool(forKey: "debugMockMode")`) instead of leaving the `false` default. This makes a dose logged in the current mode satisfy the `refresh()` filter `isMockData == mockMode`.
- **Invariants preserved**: the partition still cleanly separates mock and real data (IX); no `@Attribute(.unique)`; field stays optional/defaulted (CloudKit-compatible); no migration.
- **State/visibility rule** (unchanged except the tag): a dose is shown iff `taken == true` AND `takenAt > now − 24h` AND `takenAt + durationHours·3600 > now` AND `isMockData == debugMockMode`, then the 3 most-recent within-window doses, oldest-first.

## 3. Not modelled here

No new services, view-models, or DI wiring. All other files are SwiftUI views whose only change is token/modifier references — no state, no data.
