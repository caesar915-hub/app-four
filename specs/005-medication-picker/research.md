# Phase 0 Research: Medication Picker

All unknowns from the spec are resolved (the three `[NEEDS CLARIFICATION]` items were
closed in the spec's Clarifications session). This records the design decisions and
why the alternatives were rejected.

## D1 — Catalog storage: static Swift, not a SwiftData model or JSON

**Decision**: A typed Swift value `MedicationCatalog` (array of 7 entries) compiled into the binary.

**Rationale**: The catalog is read-only reference data of fixed, known size. A static
constant is type-checked, needs no loader, and — critically — introduces no persisted
schema, keeping **Principle IX** trivially green and honoring **Minimal Surface (IV)**.

**Alternatives rejected**:
- *SwiftData `Medication` model* — would add a store + migration pressure and tempt a
  unique-name constraint, fighting Principle IX (CloudKit-compatible, no `.unique`). Not
  needed when the data is fixed.
- *`Resources/medications.json` + loader* — adds a parse/error path for seven rows.
  Defer to JSON only if the catalog grows large, becomes user-editable, or needs
  localization (the lexicon-as-data precedent in Principle VII applies *there*, not here).

## D2 — History source and de-duplication

**Decision**: List previously-used medications by fetching distinct `MedicationEvent.name`
through the existing `ModelContext`, normalized by **lowercased base name** (first token,
trailing dose text stripped). History entries matching a catalog medication fold into the
catalog entry rather than appearing twice (FR-014).

**Rationale**: Reuses the base-name normalization already present in
`MedicationBarViewModel` (used for per-day ordinal counting), so "Concerta", "Concerta XL",
and "concerta 36mg" collapse consistently with existing behavior.

## D3 — Duration override storage

**Decision**: Persist the chosen/overridden duration on the **existing**
`MedicationEvent.durationHours` (already present, defaulted `10.0`). The manual-log path
(`MedicationBarViewModel.logManualDose`) gains a `durationHours` argument; free-text meds
default to the existing 10 h fallback, editable.

**Rationale**: No schema change. The medication bar already computes `endsAt` from
`takenAt + durationHours`, so honoring the chosen duration makes **SC-002** (end time
matches chosen duration) fall out for free — the current bug is only that the manual path
hard-codes `10.0`.

## D4 — Onset handling

**Decision**: Onset is **catalog-only** and **read-only display**; it is *not* persisted on
the logged event. Free-text medications show no onset (FR-013).

**Rationale**: Nothing downstream consumes onset beyond informational display, so adding a
persisted field would violate Minimal Surface (IV) and touch the schema (IX) for no
behavioral gain.

## D5 — Taken-time cap

**Decision**: The taken-time control uses a date range with a closed upper bound at "now"
(`in: ...Date()`), so future times are unselectable; earlier times allowed (FR-006).

## D6 — Shared picker control (consistency, FR-012)

**Decision**: Extract one selection control (`MedicationPickerField`) from the existing
check-in chip pattern and use it in **both** the medication bar's `MedicationLogSheet` and
the check-in composer.

**Rationale**: FR-012 requires identical dose-logging behavior wherever a dose is logged.
A shared control is the single source of that behavior and prevents the two surfaces from
drifting (the original divergence that caused this feedback).

## D7 — New-view mockup precondition (Principle I)

**Decision**: Produce an HTML mockup of the revised Log Dose sheet (superpowers design
phase) before any SwiftUI implementation.

**Rationale**: Constitution Principle I and CLAUDE.md require an HTML mockup before new
SwiftUI UI. This is a blocking precursor, sequenced first in `/speckit-tasks`.

## Open questions

None. The three spec clarifications are resolved; no further research required before
`/speckit-tasks`.
