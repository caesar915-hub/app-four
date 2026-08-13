# Implementation Plan: 043-mlx-journal-service (Part 3: Extraction Review UI)

**Branch**: `043-feat` | **Date**: 2026-08-12 | **Spec**: [spec-part3.md](file:///Users/caesargrey/Projects/app-four-llama/specs/043-mlx-journal-service/spec-part3.md)

**Input**: Feature specification from `/specs/043-mlx-journal-service/spec-part3.md`

## Feature Definition & Scope

This plan covers **Part 3** of the 043-mlx-journal-service feature: the user-facing edit sheet (`ExtractionReviewView`) for reviewing and correcting LLM-extracted ADHD journal signals. 

The scope includes:
1. **Review Sheet Layout**: A `.sheet` presenting six structured, editable signal cards (When, Signals, Sleep, Medications, Emotions, Side effects) pre-filled with LLM-extracted data from Part 2.
2. **Provenance Tagging**: Emitting `RecordingTag` items on confirmation, strictly tracking which values were untouched (`.llm`) versus user-edited (`.userCorrected`).
3. **Data Consistency**: Rebuilding the raw `noteExtraction` JSON directly from scalar values prior to save, ensuring strict parity between database columns and JSON cache.
4. **Input Normalization**: Ensuring comma-to-dot normalization for custom sleep duration entry (e.g. "7,5" to `7.5`).
5. **Cancel & Error Semantics**: Overriding `summaryStatus` to `.failed` if the user cancels an incomplete extraction, and safely supporting manual fallbacks on complete LLM parsing failures.

## Technical Context

### 1. Language & Runtime Environment
- **Swift 6 & iOS 17.0+**: SwiftUI-first environment.
- **Strict Concurrency**: ViewModels operate on `@MainActor` to safely mutate observable state before handing off to the SwiftData persistence layer.

### 2. Core Dependencies & Frameworks
- **SwiftUI**: Exclusively utilizing native iOS components (e.g., `DatePicker`, `.presentationDetents`).
- **SquirlSignals**: Leveraging existing components (`GlyphRampPicker`, `Levels.swift`) for standardized signal levels.
- **Foundation**: `JSONEncoder` for serialization of the rebuilt `noteExtraction` property.

### 3. State Management & Data Flow
- **Data Flow**: `RecordingDetailView` -> triggers presentation of `ExtractionReviewView`.
- **State Ownership**: `ExtractionReviewViewModel` holds a localized copy of the `Recording` values to track dirty states.
- **Save Operation**: Upon saving, the ViewModel determines delta (dirty) properties to generate `.userCorrected` tags vs `.llm` tags. It then calls `recording.applySummary()` and `recording.setMedicationEvents()`.
- **Cancel Operation**: If the user dismisses the sheet while `summaryStatus` is incomplete (e.g. `.processing`), the state defaults to `.failed`.

### 4. Storage & Persistence Strategy
- **RecordingTag**: Emitted and persisted alongside the `Recording` object for later analytics tracking. Handled via existing `store.addCorrectionTags` function.
- **JSON Integrity**: A local `LLMOutput` struct is populated and re-encoded using `JSONEncoder` and persisted back to `noteExtraction` column, avoiding sync issues between scalar DB columns and stored JSON string.

### 5. Performance & Constraints
- **Latency**: UI updates must remain instant (under 16ms frame bounds). All heavy data formatting/serialization operations on save must execute efficiently without main thread hitching.
- **Memory**: Extremely lightweight compared to Part 1 (MLX execution); standard SwiftUI lifecycle memory bounds apply.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. SwiftUI-First**
- [x] **II. Test-Build-Ship**
- [x] **III. Correctness Over Speed**
- [x] **IV. Minimal Surface**
- [x] **V. Solo Git Discipline**
- [x] **VI. On-Device Privacy**
- [x] **VII. Deterministic, Measured Extraction**
- [x] **VIII. Service-Oriented Architecture**
- [x] **IX. Pre-Release Data Posture**
- [x] **X. Test-First Development**
- [x] **XI. Architectural Exhaustiveness**

## Project Structure

### Documentation (this feature)

```text
specs/043-mlx-journal-service/
├── plan-part3.md        # This file
├── tasks-part3.md       # Expanded via 5-stage pipeline
└── spec-part3.md        
```

### Source Code (repository root)

```text
app-four/
├── Views/
│   ├── RecordingDetailView.swift
│   └── ExtractionReviewView.swift
├── ViewModels/
│   └── ExtractionReviewViewModel.swift
└── Tests/
    └── ViewModels/
        └── ExtractionReviewViewModelTests.swift
```

**Structure Decision**: Part 3 operates entirely within the existing UI and ViewModel directories. No new modules or architectures are introduced. Modification is constrained to updating existing structures to reflect the new Llama provenance and data validation rules.

### File Manifest & Responsibilities

| File Path | Responsibility | Key Structs / Functions / Protocols |
|-----------|----------------|-------------------------------------|
| `app-four/Views/ExtractionReviewView.swift` | The `.sheet` UI layer displaying the 6 constraint-driven cards. | `struct ExtractionReviewView` |
| `app-four/ViewModels/ExtractionReviewViewModel.swift` | Holds editable state, manages dirty-tracking for `.userCorrected` tags, handles cancel fallbacks, and rebuilding JSON on save. | `class ExtractionReviewViewModel`, `func save()`, `func cancel()` |
| `app-four/Tests/ViewModels/ExtractionReviewViewModelTests.swift` | **MANDATORY**: Test-first assertions for provenance tagging logic, cancel semantic overrides, and comma-to-dot normalization. | `struct ExtractionReviewViewModelTests` |
