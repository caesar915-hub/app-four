# Phase 0 Research: Medication Picker

All unknowns from the spec are resolved (the three `[NEEDS CLARIFICATION]` items were
closed in the spec's Clarifications session). This records the design decisions and
why the alternatives were rejected.

## D1 — Catalog storage: static Swift, not a SwiftData model or JSON

**Decision**: A typed Swift value `MedicationCatalog` (array of 3 entries — Concerta, Ritalin, Elvanse, the beta subset) compiled into the binary; extensible to the fuller EU list without redesign.

**Rationale**: The catalog is read-only reference data of fixed, known size. A static
constant is type-checked, needs no loader, and — critically — introduces no persisted
schema, keeping **Principle IX** trivially green and honoring **Minimal Surface (IV)**.

**Alternatives rejected**:
- *SwiftData `Medication` model* — would add a store + migration pressure and tempt a
  unique-name constraint, fighting Principle IX (CloudKit-compatible, no `.unique`). Not
  needed when the data is fixed.
- *`Resources/medications.json` + loader* — adds a parse/error path for three rows.
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

## D6 — FR-012 consistency: share the catalog data, not a monolithic control

**Decision**: Make `MedicationCatalog` the single source of truth for the med list and
**repoint the shipped Edit-sheet chips** (`ExtractionReviewView`, currently hard-coded
`["Concerta","Ritalin","Elvanse"]` from `fix/med-crash-mvp` on `main`) at the catalog's
names. Build the rich single-dose picker (dose options, onset, editable duration) inside
`MedicationLogSheet`. Do **not** extract one shared control across both surfaces.

**Rationale**: The two surfaces have different interaction shapes — the Edit sheet is
*multi-select chips* (each med its own event), the Log-Dose sheet logs *one* dose with a
duration. A monolithic shared control would force one shape onto both (violates Minimal
Surface, IV) and risks regressing the just-shipped Edit-sheet crash fix. What FR-012 actually
needs is that the two never disagree on *which* meds exist — sharing the **catalog data**
delivers exactly that (add a med once, both update). The richer affordances can come to the
Edit sheet later as a separate, separately-tested change.

**Alternatives rejected**:
- *One `MedicationPickerField` reused in both* — over-couples two different interaction models.
- *Leave the Edit-sheet list hard-coded* — the two med lists would silently drift (the
  original class of bug behind this feedback).

## D7 — New-view mockup precondition (Principle I)

**Decision**: Produce an HTML mockup of the revised Log Dose sheet (superpowers design
phase) before any SwiftUI implementation.

**Rationale**: Constitution Principle I and CLAUDE.md require an HTML mockup before new
SwiftUI UI. This is a blocking precursor, sequenced first in `/speckit-tasks`.

## D8 — Test-first ordering (Principle X, constitution v1.2.0)

**Decision**: `MedicationCatalog` (+`entry(matching:)`), `MedicationPickerViewModel`
(catalog ∪ deduped history, metadata resolution), and `logManualDose(durationHours:)` are
**logic** → their Swift Testing tests are written and committed **failing (RED)** before the
implementation, then made GREEN. The SwiftUI `MedicationLogSheet` and the Edit-sheet list
repoint are view-layer → exempt from X, verified by build + simulator run.

## Open questions

None. The spec clarifications (incl. the 2026-06-16 3-med scope) are resolved; no further
research required before `/speckit-tasks`.
