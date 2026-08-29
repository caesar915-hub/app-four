---
description: "Expanded Task list for 043-mlx-journal-service (Part 3: Extraction Review UI)"
---

# Tasks: 043-mlx-journal-service (Part 3)

**Input**: Design documents from `/specs/043-mlx-journal-service/spec-part3.md` and `/specs/043-mlx-journal-service/plan-part3.md`

**Prerequisites**: plan-part3.md, spec-part3.md

## Phase 1: User Story 2 & 6 - Provenance Tagging & JSON Rebuild (Priority: P1)

**Goal**: Update provenance tags to use `.llm` instead of legacy `.nlp`, verify `store.addCorrectionTags` assertions, and ensure `noteExtraction` JSON is accurately rebuilt upon save using `JSONEncoder`.

### Tests

- [x] T001 [P] [US2/US6] Unit tests for `ExtractionReviewViewModel` tag generation and JSON rebuild
  - **File:** `app-four/Tests/ViewModels/ExtractionReviewViewModelTests.swift`
  - **Action:** Write `#expect` tests verifying that unmodified categories yield `.llm` tags, modified yield `.userCorrected`. Explicitly assert that `store.addCorrectionTags` is called. Ensure saving correctly rebuilds the JSON string matching the new values.
  - **Validation:** Tests fail (RED).

### Implementation

- [x] T002 [US2] Update Provenance Tags to `.llm` and Explicitly Persist
  - **File:** `app-four/ViewModels/ExtractionReviewViewModel.swift`
  - **Action:** Find tag generation logic. Replace `.nlp` references with `.llm`. Ensure dirty tracking accurately assigns `.userCorrected` when a field is touched. Verify that `store.addCorrectionTags` is explicitly called with the generated tags.
  - **Dependencies:** T001
  - **Validation:** Tests from T001 turn GREEN for tags.

- [x] T003 [US6] Rebuild `noteExtraction` JSON on Save
  - **File:** `app-four/ViewModels/ExtractionReviewViewModel.swift`
  - **Action:** In the `save()` method, construct an `LLMOutput` object from the current view model state (mood, energy, focus, sleep, medications, emotions, topics, summary). Use `JSONEncoder` to serialize it to a string, and set this as `noteExtraction` on the recording *before* calling `applySummary()`.
  - **Dependencies:** T001
  - **Validation:** Tests from T001 turn GREEN for JSON rebuild.

---

## Phase 2: User Story 1, 3, & 6 - Normalisation & Precedence (Priority: P1)

**Goal**: Implement sleep duration comma-to-dot normalisation, title precedence, and date creation adjustments.

### Tests

- [x] T004 [P] [US1/US3/US6] Unit tests for sleep normalisation, title precedence, and date ordering
  - **File:** `app-four/Tests/ViewModels/ExtractionReviewViewModelTests.swift`
  - **Action:** Write tests verifying `"7,5"` becomes `7.5`, user title overrides generated title, and `createdAt` is updated before `setMedicationEvents()`.
  - **Validation:** Tests fail (RED).

### Implementation

- [x] T005 [US3] Implement Comma-to-Dot Sleep Normalisation
  - **File:** `app-four/ViewModels/ExtractionReviewViewModel.swift`
  - **Action:** In the `save()` method, intercept the `customSleepDuration` string. Replace `,` with `.` before attempting to cast to Double.
  - **Dependencies:** T004
  - **Validation:** Sleep normalisation tests pass.

- [x] T006 [US6] Implement Title Precedence & Date Ordering
  - **File:** `app-four/ViewModels/ExtractionReviewViewModel.swift`
  - **Action:** In `save()`, ensure `recording.title` uses the user-edited title if non-empty, otherwise fallback to the generated title. Ensure `recording.createdAt = self.date` is executed *before* `recording.setMedicationEvents()`.
  - **Dependencies:** T004
  - **Validation:** Title and Date tests pass.

---

## Phase 3: User Story 4 - Cancel Semantics (Priority: P2)

**Goal**: Handle incomplete extractions by setting `summaryStatus` to `.failed` if the user cancels.

### Tests

- [x] T007 [P] [US4] Unit tests for Cancel semantics
  - **File:** `app-four/Tests/ViewModels/ExtractionReviewViewModelTests.swift`
  - **Action:** Write tests verifying that calling `cancel()` when `summaryStatus != .completed` mutates it to `.failed` and saves the context.
  - **Validation:** Tests fail (RED).

### Implementation

- [x] T008 [US4] Update Cancel Logic in ViewModel
  - **File:** `app-four/ViewModels/ExtractionReviewViewModel.swift`
  - **Action:** In the `cancel()` method, check the current `Recording.summaryStatus`. If it is not `.completed`, set it to `.failed` and call `try? context.save()`.
  - **Dependencies:** T007
  - **Validation:** Tests from T007 pass.

---

## Phase 4: User Story 5 - Total Parse Failure Fallback (Priority: P2)

**Goal**: Ensure the review sheet safely handles a completely nil extraction result without crashing, allowing full manual correction.

### Tests & Implementation

- [x] T009 [US5] Verify Nil Extraction Safety via Unit Tests
  - **File:** `app-four/Tests/ViewModels/ExtractionReviewViewModelTests.swift` & `app-four/ViewModels/ExtractionReviewViewModel.swift`
  - **Action:** Write specific unit tests verifying the nil extraction safety. Inject a completely nil `SummaryResult` (from a failed parse) into the ViewModel and assert that all fields default to nil/empty safely. Ensure subsequent saves emit `.userCorrected`.
  - **Validation:** Tests must pass, guaranteeing no force-unwrap crashes.

---

## Phase 5: Strict Structural UI Compliance (Priority: P1)

**Goal**: Ensure the SwiftUI views perfectly adhere to the FSD presentation rules, specifically for accessibility, presentation detents, and dataset limits.

### Tests & Implementation

- [x] T010 [US1] Enforce Sheet Presentation Rules & Accessibility
  - **File:** `app-four/Views/RecordingDetailView.swift` & `app-four/Views/ExtractionReviewView.swift`
  - **Action:** Ensure the edit sheet is presented solely from the pencil toolbar button. The button must have the exact accessibility label `"Edit check-in"`. Ensure the sheet uses `.presentationDetents([.large])` and `.presentationDragIndicator(.visible)`.
  - **Validation:** Manual SwiftUI preview inspection and accessibility label audit.

- [x] T011 [US3] Enforce Dataset Dimensions for Chips
  - **File:** `app-four/Views/ExtractionReviewView.swift`
  - **Action:** Audit and enforce that exactly 15 hard-coded side effect chips are presented. Audit that exactly 20 curated emotions (5 per quadrant) are presented as per `lexicon.json`.
  - **Validation:** Code review and UI test confirming the hardcoded counts are perfectly respected.
