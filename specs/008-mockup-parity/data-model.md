# Phase 1 — Data Model

This is a visual feature. The **only** model touch is one optional field on an existing DTO, to back the Edit-sheet duration box (spec FR-009, Key Entities).

## MedEvent (existing Codable DTO — `Services/NoteExtraction/NoteExtraction.swift`)

Add one field:

| Field | Type | Default | Purpose |
|---|---|---|---|
| `durationHours` | `Double?` | `nil` | Per-dose duration set in the Edit-sheet inline-expand box. |

- **Backward compatibility**: optional → synthesized `Codable` uses `decodeIfPresent`, so JSON persisted before the field decodes as `nil`. No migration.
- **No behavior change**: when `nil`, the existing resolution order applies (`durationHours` argument → catalog → 10h default).

## Flow to the SwiftData model (unchanged schema)

`Recording.setMedicationEvents(from:durationHours:context:)` materializes each `MedEvent` into a `MedicationEvent` (which **already** has `durationHours`). The per-dose value resolves as:

```
event.durationHours = med.durationHours
                    ?? durationHours                                  // call-site default
                    ?? MedicationCatalog.entry(matching: med.name)?.durationHours
                    ?? 10.0
```

No SwiftData `@Model`, schema, or relationship changes. No `@Attribute(.unique)` added.

## Validation rules

- Duration box accepts a positive decimal; an empty/invalid string leaves `durationHours` nil (falls back to the catalog/default). Non-numeric input is ignored (no crash, no write).
- Dose pills are constrained to the med's `MedicationCatalog` `doseOptions`.
