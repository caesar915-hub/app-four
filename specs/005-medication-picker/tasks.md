# Tasks: Medication Picker for Dose Logging (005)

**Branch**: `feat/med-picker-mvp` · spec/plan/research/data-model/quickstart in this dir.
**Conventions**: `[P]` parallelizable. Per constitution v1.2.0 **Principle X**, logic tasks are
test-first (RED → GREEN); SwiftUI views are exempt (verified by build + simulator run).

## Phase 1 — Mockup gate (Principle I)
- **T001** HTML mockup of the revised Log-Dose sheet → `docs/superpowers/plans/2026-06-16-medication-logdose-picker.html` (Paper & Pollen + shipped chip style). Blocks the SwiftUI rewrite.

## Phase 2 — Catalog (logic · test-first)
- **T002 [RED]** `app-fourTests/Models/MedicationCatalogTests.swift` — 3 entries {Concerta,Ritalin,Elvanse}; well-formed (≥1 dose, onset>0, duration>0); unique; `entry(matching:)` base-name/case-insensitive + nil for unknown.
- **T003 [GREEN]** `app-four/Models/MedicationCatalog.swift` — `MedicationCatalogEntry` + `enum MedicationCatalog { all; entry(matching:) }`, 3 seed entries. → T002 green.

## Phase 3 — Picker view-model (logic · test-first)
- **T004 [RED]** `app-fourTests/ViewModels/MedicationPickerViewModelTests.swift` — `merge(catalog:history:)` (catalog first, fold history matching a catalog base name, dedup within history); `baseName()`.
- **T005 [GREEN]** `app-four/ViewModels/MedicationPickerViewModel.swift` — `@MainActor @Observable`; static `merge`/`baseName`; `pickableNames`; distinct-history fetch via existing `ModelContext`; `catalogEntry(for:)`. → T004 green.

## Phase 4 — Duration plumbing (logic · test-first)
- **T006 [RED]** extend `app-fourTests/ViewModels/MedicationBarViewModelTests.swift` — `logManualDose(durationHours: 8)` → persisted event `durationHours == 8` (SC-002).
- **T007 [GREEN]** `app-four/ViewModels/MedicationBarViewModel.swift` — `logManualDose(... durationHours: Double = 10.0)`, use it instead of the hard-coded `10.0`. → T006 green.

## Phase 5 — UI (views · build+run verified)
- **T008** Rewrite `app-four/Views/Components/MedicationLogSheet.swift` — catalog picker (chips) + free-text add-new; dose-options picker; read-only onset; editable duration prefilled; taken-time capped at now; `onLog: (String, String?, Date, Double) -> Void`. [depends T003, T005]
- **T009** `app-four/Views/Components/MedicationBarView.swift` — onLog call site passes `durationHours`; update `#Preview`. [depends T007, T008]
- **T010** FR-012: `app-four/Views/ExtractionReviewView.swift` — `medicationGroups` items ← `MedicationCatalog.all.map(\.name)` (replaces the hard-coded list). [depends T003]

## Phase 6 — Verify
- **T011** Build + full suite green on iPhone 17 sim (`-parallel-testing-enabled NO`). Manual (quickstart): log a Concerta dose, change duration to 8h, confirm the bar's end-time = takenAt + 8h.

**Order**: T001 → (T002→T003) → (T004→T005) → (T006→T007) → T008 → T009 → T010 → T011.
