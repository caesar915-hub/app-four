# Phase 1 — Data Model

This is a visual feature. The **only** model touch is one optional field on an existing DTO, to back the Edit-sheet duration box (spec FR-009, Key Entities).

## MedEvent (existing Codable DTO — `Services/NoteExtraction/NoteExtraction.swift`)

Add one field:

| Field | Type | Default | Purpose |
|---|---|---|---|
| `durationHours` | `Double?` | `nil` | Per-dose duration set in the Edit-sheet inline-expand box. |

- **Backward compatibility**: optional → synthesized `Codable` uses `decodeIfPresent`, so JSON persisted before the field decodes as `nil`. No migration.
- **No behavior change to the voice path**: the shared resolver is **catalog-free** (`med.durationHours ?? durationHours ?? 10.0`), exactly the pre-feature order plus the new per-med override. The catalog default is **not** in the shared resolver — it is seeded into `med.durationHours` only inside the Edit-sheet view-model (`addMedication`, and carried on re-edit), so `ProcessingViewModel`'s transcript output is byte-identical to before.

## Flow to the SwiftData model (unchanged schema)

`Recording.setMedicationEvents(from:durationHours:context:)` materializes each `MedEvent` into a `MedicationEvent` (which **already** has `durationHours`). The per-dose value resolves as:

```
event.durationHours = med.durationHours    // per-med (Edit sheet; catalog-seeded by the VM)
                    ?? durationHours        // call-site default (voice path arg)
                    ?? 10.0
```

The Edit-sheet VM seeds the catalog default into `med.durationHours` (so the box default matches what saves); the shared resolver never reads the catalog, keeping the non-Edit-sheet path unchanged. No SwiftData `@Model`, schema, or relationship changes. No `@Attribute(.unique)` added.

## Validation rules

- Duration box accepts a positive decimal; an empty/invalid string leaves `durationHours` nil (falls back to the catalog/default). Non-numeric input is ignored (no crash, no write).
- Dose pills are constrained to the med's `MedicationCatalog` `doseOptions`.
