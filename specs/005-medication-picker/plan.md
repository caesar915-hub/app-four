# Implementation Plan: Medication Picker for Dose Logging

**Branch**: `feat/med-picker-mvp` (Spec Kit feature `005-medication-picker`) | **Date**: 2026-06-16 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/005-medication-picker/spec.md` (reconciled 2026-06-16 to the 3-med beta scope).

## Summary

Replace the free-text Log-Dose sheet with a selection-first medication picker backed by a small **static catalog** (3 curated EU stimulants — Concerta, Ritalin, Elvanse) merged with the user's own logged-medication **history**. Selecting a medication surfaces its dose options, shows onset (read-only), and prefills an **editable** effect duration; taken-time defaults to now (capped at now); free-text entry of a new medication is preserved and persists via history. **No schema change** — reuse the existing `MedicationEvent` model (its `durationHours` already exists) and the existing manual-log path; the catalog is static reference data.

**FR-012 consistency:** the catalog is the *single source of truth* for the med list, so the medication chips already shipped in the Edit sheet (`ExtractionReviewView`, via `fix/med-crash-mvp` on `main`) are repointed at `MedicationCatalog` rather than their current hard-coded `["Concerta","Ritalin","Elvanse"]`. We do **not** force one monolithic control across both surfaces — the Edit sheet is *multi-select chips* and the Log-Dose sheet logs *one* dose (different interaction shapes); sharing the data + chip style is the right level of reuse.

## Technical Context

**Language/Version**: Swift 6 (strict concurrency)

**Primary Dependencies**: SwiftUI (iOS 26+), SwiftData, Swift Concurrency; existing `AppDependencies`/`AppServices` DI

**Storage**: SwiftData for logged doses (existing `MedicationEvent` `@Model`, unchanged). Catalog is static in-binary data — no store.

**Testing**: Swift Testing (`@Test`/`#expect`) in `app-fourTests`, **test-first per Principle X** for all logic (catalog, picker view-model, duration plumbing). The SwiftUI sheet is view-layer → verified by build + simulator run.

**Target Platform**: iOS 26+

**Project Type**: mobile-app (single SwiftUI app, module `app-four`)

**Performance Goals**: instant — 3 catalog entries + a bounded distinct-name history fetch; picker render within the 60fps frame budget

**Constraints**: on-device only; no network; no new persisted schema; legible/selectable at large Dynamic Type

**Scale/Scope**: 1 rewritten sheet, 1 new picker view-model, 1 static catalog, a 1-line med-list repoint in the Edit sheet, ~3 test files.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design — still PASS (no schema change). Gated against `.specify/memory/constitution.md` **v1.2.0** (Principles I–X).*

- [x] **I. SwiftUI-First** — PASS *(with precondition)*: the revised sheet is SwiftUI on iOS 26+, no UIKit. New/changed UI requires an **HTML mockup first** → the blocking precursor (Task 1), following DESIGN.md (Paper & Pollen) + the shipped chip style.
- [x] **II. Test-Build-Ship** — PASS: build + full suite green on the iPhone 17 sim before done (verified directly via `xcodebuild ... -parallel-testing-enabled NO`).
- [x] **III. Correctness Over Speed** — PASS: the free-text fields are fully replaced (no parallel dead path); the hard-coded 10 h default on the manual-log path is removed in favour of catalog/override duration.
- [x] **IV. Minimal Surface** — PASS: static catalog (no SwiftData catalog model, no migration); reuse `MedicationEvent.durationHours` and the existing `logManualDose` path; **no monolithic shared control** (rejected — different interaction shapes). One new view-model, justified below.
- [x] **V. Solo Git Discipline** — PASS: one revertable feature on `feat/med-picker-mvp`; build+tests green before PR; `main` stays releasable.
- [x] **VI. On-Device Privacy** — PASS: catalog is local static data; no medication content logged; nothing leaves the device.
- [x] **VII. Deterministic, Measured Extraction** — N/A: no change to `NLNoteExtractor` or the transcript pipeline. The manual picker and transcript-extracted events share `MedicationEvent`; the existing manual/transcript dedupe contract (`setMedicationEvents`) is **preserved, not altered**.
- [x] **VIII. Service-Oriented Architecture** — PASS: the new picker VM is `@MainActor @Observable`, holds **no persistence logic** (reads distinct history names via the existing `ModelContext` seam, logs via the existing `logManualDose`). The catalog is static data; if a swappable source is ever needed it goes behind a `Services/` protocol.
- [x] **IX. Pre-Release Data Posture** — PASS *(key gate)*: no new attributes, no `@Attribute(.unique)`, no required non-defaulted fields. `MedicationEvent` is already CloudKit-compatible (`durationHours` defaulted). The static catalog avoids a migratable store entirely.
- [x] **X. Test-First Development** — PASS: the **logic** — `MedicationCatalog` (+`entry(matching:)`), `MedicationPickerViewModel` (catalog ∪ deduped history, metadata resolution), and `logManualDose(durationHours:)` — is built **RED→GREEN** (failing Swift Testing tests committed before implementation). The SwiftUI `MedicationLogSheet` and the Edit-sheet chip-list repoint are view-layer → exempt, verified by build + simulator run.

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

No `contracts/` — on-device UI feature, no external API. The behavioural contract is the spec's acceptance scenarios, verified by the tests in `quickstart.md`.

### Source Code (repository root)

```text
app-four/
├── Models/
│   ├── MedicationEvent.swift            # REUSE unchanged (name, dose, takenAt, durationHours, source)
│   └── MedicationCatalog.swift          # NEW (test-first) — static: name, doseOptions, onsetMinutes, durationHours + entry(matching:)
├── ViewModels/
│   ├── MedicationBarViewModel.swift     # MODIFY (test-first) — logManualDose gains durationHours (drop hard-coded 10.0)
│   └── MedicationPickerViewModel.swift  # NEW (test-first) — @MainActor @Observable: catalog ∪ deduped history, metadata resolution
└── Views/
    ├── Components/
    │   ├── MedicationLogSheet.swift       # REWRITE (view) — picker + dose options + read-only onset + editable duration; free-text add-new
    │   └── MedicationBarView.swift        # MODIFY (view) — onLog call site gains the chosen durationHours
    └── ExtractionReviewView.swift         # MODIFY (view, FR-012) — chip list ← MedicationCatalog.all (replaces hard-coded names)

app-fourTests/
├── Models/MedicationCatalogTests.swift             # NEW — 3 entries, dose options non-empty, onset/duration sane, names unique, entry(matching:)
├── ViewModels/MedicationPickerViewModelTests.swift # NEW — catalog∪history dedup/fold, metadata resolution, add-new persists
└── ViewModels/MedicationBarViewModelTests.swift    # MODIFY — logged dose's effect window uses the chosen duration (SC-002)

docs/superpowers/plans/
└── 2026-06-16-medication-logdose-picker.html        # NEW — HTML mockup (Principle I), Task 1, blocking
```

**Structure Decision**: Single SwiftUI app (`app-four`); reuse Models/ViewModels/Views layering. The only new persisted-adjacent artifact is a **static** catalog (no store). Catalog is typed Swift, not `Resources/*.json` — 3 fixed, type-checked clinical entries; revisit JSON only if it grows large or needs localization. The picker's history/dedup logic lives in a dedicated `@MainActor @Observable` view-model (Principle VIII) so it is unit-testable (Principle X) rather than buried in the view.

## Complexity Tracking

None — Constitution Check passes with no violations, so no complexity to justify. (The one new view-model is required to give the history/dedup logic a testable home under Principles VIII + X — not speculative surface.)
