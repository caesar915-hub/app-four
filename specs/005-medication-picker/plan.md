# Implementation Plan: Medication Picker for Dose Logging

**Branch**: `feat/medication-picker` (Spec Kit feature `005-medication-picker`) | **Date**: 2026-06-15 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/005-medication-picker/spec.md`

## Summary

Replace the free-text Log Dose sheet with a selection-first medication picker backed by a small **static catalog** (the seven curated EU stimulants) merged with the user's own logged-medication **history**. Selecting a medication surfaces its dose options, shows onset (read-only), and prefills an **editable** effect duration; taken-time defaults to now (capped at now); free-text entry of a new medication is preserved and persists via history. **No schema change** — reuse the existing `MedicationEvent` model (its `durationHours` already exists) and the existing manual-log path; the catalog is static reference data. One shared picker control serves both the medication bar's sheet and the check-in composer (FR-012).

## Technical Context

**Language/Version**: Swift 6 (strict concurrency)

**Primary Dependencies**: SwiftUI (iOS 26+), SwiftData, Swift Concurrency; existing `AppDependencies`/`AppServices` DI container

**Storage**: SwiftData for logged doses (existing `MedicationEvent` `@Model`, unchanged). Catalog is static in-binary data — no store.

**Testing**: Swift Testing (`@Test`/`#expect`) in the existing `app-fourTests` target

**Target Platform**: iOS 26+

**Project Type**: mobile-app (single SwiftUI app, module `app-four`)

**Performance Goals**: instant — 7 catalog entries + a bounded distinct-name history fetch; picker render within the 60fps frame budget

**Constraints**: on-device only; no network; no new persisted schema; legible/selectable at large Dynamic Type

**Scale/Scope**: 1 rewritten sheet, 1 new view-model, 1 static catalog, 1 shared picker control, ~3 test files. Touches the manual-log path used by both the medication bar and check-in.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design — still PASS (no schema change introduced).*

- [x] **I. SwiftUI-First** — PASS *(with precondition)*: the revised sheet is SwiftUI on iOS 26+, no UIKit. New/changed UI requires an HTML mockup first → a **blocking precursor task** (design phase, superpowers) before SwiftUI work.
- [x] **II. Test-Build-Ship** — PASS: tests accompany implementation (catalog integrity, dedup/merge, duration→effect-window); build + full suite green via `ios-debugger-agent` before done.
- [x] **III. Correctness Over Speed** — PASS: the free-text fields are fully replaced (no parallel dead path); the hard-coded 10 h default on the manual-log path is removed in favor of catalog/override duration.
- [x] **IV. Minimal Surface** — PASS: static catalog (no SwiftData catalog model, no migration), reuse `MedicationEvent.durationHours` and the existing `logManualDose` path, reuse the check-in chip pattern. One new VM, one shared control — nothing speculative.
- [x] **V. Solo Git Discipline** — PASS: one revertable feature on `feat/medication-picker`; `/code-review` before merge; `main` stays releasable.
- [x] **VI. On-Device Privacy** — PASS: catalog is local static data; no medication content logged; nothing leaves the device.
- [x] **VII. Deterministic, Measured Extraction** — N/A: no change to `NLNoteExtractor` or the transcript pipeline. The manual picker and transcript-extracted events share `MedicationEvent`; the existing manual/transcript dedupe contract (`setMedicationEvents`) is **preserved, not altered**. Eval harness not implicated.
- [x] **VIII. Service-Oriented Architecture** — PASS: the picker VM is `@MainActor @Observable`, holds no persistence (reads via the existing `ModelContext` seam, logs via the existing manual-log method). The catalog is static data — acceptable under Minimal Surface; if a swappable source is later needed it goes behind a `Services/` protocol.
- [x] **IX. Pre-Release Data Posture** — PASS *(key gate)*: no new attributes, no `@Attribute(.unique)`, no required non-defaulted fields. `MedicationEvent` is already CloudKit-compatible (`durationHours` defaulted). The static catalog avoids a migratable store entirely.

→ **No violations.** Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/005-medication-picker/
├── plan.md         # This file
├── research.md     # Phase 0 — decisions & rationale
├── data-model.md   # Phase 1 — entities (no schema change)
├── quickstart.md   # Phase 1 — manual validation + test plan
└── tasks.md        # Phase 2 — created by /speckit-tasks (NOT here)
```

No `contracts/` — this is an on-device UI feature with no external API. The behavioral contract is the spec's acceptance scenarios, verified by the tests in `quickstart.md`.

### Source Code (repository root)

```text
app-four/
├── Models/
│   ├── MedicationEvent.swift            # REUSE unchanged (name, dose, takenAt, durationHours, source)
│   └── MedicationCatalog.swift          # NEW — static catalog: name, aliases, doseOptions, onsetMinutes, durationHours
├── ViewModels/
│   ├── MedicationBarViewModel.swift     # MODIFY — logManualDose gains a durationHours param (drop hard-coded 10.0)
│   └── MedicationPickerViewModel.swift  # NEW — @MainActor @Observable: catalog ∪ deduped history, metadata resolution
└── Views/
    ├── Components/
    │   ├── MedicationLogSheet.swift       # REWRITE — picker + dose options + read-only onset + editable duration; free-text = add-new
    │   └── MedicationPickerField.swift    # NEW — shared selection control used by the sheet AND the check-in composer (FR-012)
    └── CheckIn/
        └── TextCheckInComposer.swift      # MODIFY — adopt the shared picker field for consistency

app-fourTests/
├── Models/MedicationCatalogTests.swift             # NEW — catalog integrity (dose options non-empty, onset/duration sane, names unique)
├── ViewModels/MedicationPickerViewModelTests.swift # NEW — dedup, history merge, metadata resolution, add-new
└── ViewModels/MedicationBarViewModelTests.swift    # MODIFY — logged dose's effect window uses the chosen duration (SC-002)
```

**Structure Decision**: Single SwiftUI app (module `app-four`); reuse the existing Models/ViewModels/Views layering. The only new persisted-adjacent artifact is a **static** catalog (no store). Catalog is kept as typed Swift rather than `Resources/*.json` because it is seven fixed, type-checked clinical entries; revisit JSON only if it grows or needs localization (matching the lexicon-as-data precedent in Principle VII).

## Complexity Tracking

None — Constitution Check passes with no violations, so no complexity to justify.
