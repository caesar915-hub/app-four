# Phase 1 Data Model: Medication Picker

**No SwiftData schema change.** One new static value type; the existing persisted model is
reused unchanged. This keeps Principle IX (CloudKit-compatible, no `.unique`, optional/
defaulted attributes) green by construction.

## New — `MedicationCatalogEntry` (static value type, NOT persisted)

Compiled into the binary as a fixed array (`MedicationCatalog`). Read-only in v1.

| Field | Type | Notes |
|---|---|---|
| `name` | `String` | Display name: "Concerta" \| "Ritalin" \| "Elvanse" (matches the shipped Edit-sheet chips) |
| `doseOptions` | `[String]` | display strings, e.g. ["18 mg","27 mg","36 mg","54 mg"]; ≥1 |
| `onsetMinutes` | `Int` | Read-only info; > 0 |
| `durationHours` | `Double` | Prefilled, editable effect window; > 0 |

**Seed values** (spec FR-002 — 3-med beta subset):

| name | doseOptions (mg) | onsetMinutes | durationHours |
|---|---|---|---|
| Concerta | 18, 27, 36, 54 | 60 | 12 |
| Ritalin | 5, 10, 20 | 20 | 3 |
| Elvanse | 20, 30, 40, 50, 60, 70 | 90 | 10 |

**Validation invariants** (covered by `MedicationCatalogTests`, **written test-first per Principle X**):
exactly 3 entries {Concerta, Ritalin, Elvanse}; names unique; `doseOptions` non-empty;
`onsetMinutes > 0`; `durationHours > 0`; `entry(matching:)` resolves base names
case-insensitively ("concerta", "Concerta 36 mg" → Concerta) and returns nil for unknown.

## Reused unchanged — `MedicationEvent` (`@Model`)

Only the fields this feature reads/writes are listed; the schema is **not** modified.

| Field | Type | Role in this feature |
|---|---|---|
| `name` | `String = ""` | Set from selected catalog name or typed free-text |
| `dose` | `String? = nil` | Set from selected dose option or custom entry |
| `takenAt` | `Date = Date()` | Defaults to now; user-editable, capped at now (FR-006) |
| `durationHours` | `Double = 10.0` | **Now set from catalog/override** instead of always 10 (FR-005, FR-010) |
| `source` | `Source = .manual` | Manual log (unchanged) |

All attributes remain optional or defaulted; no `@Attribute(.unique)`; mock/real
partitioning via `isMockData` unchanged. **No migration.**

## Derived data (not persisted)

- **Picker list** = catalog entries ∪ distinct history names, de-duplicated by normalized
  base name; a history name matching a catalog entry (by normalized base name) folds into
  that catalog entry (FR-014).
- **Effect window** (`endsAt`, `effectProgress`) already derives from
  `takenAt + durationHours` in `MedicationEvent`/`MedicationBarViewModel` — no new
  derivation needed; honoring the chosen `durationHours` is what fixes SC-002.

## Constitution re-check (post-design)

- **IX** PASS — no attribute added, no constraint introduced, no store created.
- **X** PASS — the catalog and `entry(matching:)` are pure logic, built test-first (`MedicationCatalogTests`, RED→GREEN). ✅
