---
description: "Task list for 043-mlx-journal-service (Part 3: Extraction Review UI)"
---

# Tasks: 043-mlx-journal-service (Part 3)

**Input**: Design documents from `/specs/043-mlx-journal-service/spec-part3.md`

**Prerequisites**: plan.md, spec-part3.md

## Phase 1: User Story 2 & 6 - Provenance Tagging & JSON Rebuild (Priority: P1)

**Goal**: Update provenance tags to use `.llm` instead of legacy `.nlp`, and ensure `noteExtraction` JSON is accurately rebuilt upon save.

### Tests

- [ ] T001 [P] [US2/US6] Unit tests for `ExtractionReviewViewModel` tag generation and JSON rebuild
  - **File:** `app-four/Tests/ViewModels/ExtractionReviewViewModelTests.swift`
  - **Action:** Write `#expect` tests verifying that unmodified categories yield `.llm` tags, modified yield `.userCorrected`, and that saving correctly rebuilds the JSON string matching the new values.
  - **Validation:** Tests fail (RED).

### Implementation

- [ ] T002 [US2] Update Provenance Tags to `.llm`
  - **File:** `app-four/ViewModels/ExtractionReviewViewModel.swift`
  - **Action:** Find tag generation logic. Replace `.nlp` references with `.llm`. Ensure dirty tracking accurately assigns `.userCorrected` when a field is touched.
  - **Dependencies:** T001
  - **Validation:** Tests from T001 turn GREEN for tags.

- [ ] T003 [US6] Rebuild `noteExtraction` JSON on Save
  - **File:** `app-four/ViewModels/ExtractionReviewViewModel.swift`
  - **Action:** In the `save()` method, before calling `applySummary()`, construct a new JSON payload from the current view model state (mood, energy, focus, sleep, medications, emotions, topics, summary). Set this as `noteExtraction`.
  - **Dependencies:** T001
  - **Validation:** Tests from T001 turn GREEN for JSON rebuild.

---

## Phase 2: User Story 1, 3, & 6 - Normalisation & Precedence (Priority: P1)

**Goal**: Implement sleep duration comma-to-dot normalisation, title precedence, and date creation adjustments.

### Tests

- [ ] T004 [P] [US1/US3/US6] Unit tests for sleep normalisation, title precedence, and date ordering
  - **File:** `app-four/Tests/ViewModels/ExtractionReviewViewModelTests.swift`
  - **Action:** Write tests verifying `"7,5"` becomes `7.5`, user title overrides generated title, and `createdAt` is updated before `setMedicationEvents()`.
  - **Validation:** Tests fail (RED).

### Implementation

- [ ] T005 [US3] Implement Comma-to-Dot Sleep Normalisation
  - **File:** `app-four/ViewModels/ExtractionReviewViewModel.swift`
  - **Action:** In the `save()` method, intercept the `customSleepDuration` string. Replace `,` with `.` before attempting to cast to Double.
  - **Dependencies:** T004
  - **Validation:** Sleep normalisation tests pass.

- [ ] T006 [US6] Implement Title Precedence & Date Ordering
  - **File:** `app-four/ViewModels/ExtractionReviewViewModel.swift`
  - **Action:** In `save()`, ensure `recording.title` uses the user-edited title if non-empty, otherwise fallback to the generated title. Ensure `recording.createdAt = self.date` is executed *before* `recording.setMedicationEvents()`.
  - **Dependencies:** T004
  - **Validation:** Title and Date tests pass.

---

## Phase 3: User Story 4 - Cancel Semantics (Priority: P2)

**Goal**: Handle incomplete extractions by setting `summaryStatus` to `.failed` if the user cancels.

### Tests

- [ ] T007 [P] [US4] Unit tests for Cancel semantics
  - **File:** `app-four/Tests/ViewModels/ExtractionReviewViewModelTests.swift`
  - **Action:** Write tests verifying that calling `cancel()` when `summaryStatus != .completed` mutates it to `.failed` and saves the context.
  - **Validation:** Tests fail (RED).

### Implementation

- [ ] T008 [US4] Update Cancel Logic in ViewModel
  - **File:** `app-four/ViewModels/ExtractionReviewViewModel.swift`
  - **Action:** In the `cancel()` method, check the current `Recording.summaryStatus`. If it is not `.completed`, set it to `.failed` and call `try? context.save()`.
  - **Dependencies:** T007
  - **Validation:** Tests from T007 pass.

---

## Phase 4: User Story 5 - Total Parse Failure Fallback (Priority: P2)

**Goal**: Ensure the review sheet safely handles a completely nil extraction result without crashing, allowing full manual correction.

### Tests & Implementation

- [ ] T009 [US5] Verify Nil Extraction Safety
  - **File:** `app-four/Views/ExtractionReviewView.swift` & `app-four/ViewModels/ExtractionReviewViewModel.swift`
  - **Action:** Audit the initialization of `ExtractionReviewViewModel` to ensure it doesn't force-unwrap any LLM signals. If `noteExtraction` is empty or unparseable, all fields should default to nil/empty, and all subsequent saves should emit `.userCorrected`.
  - **Validation:** Manual UI test (or unit test if strictly ViewModel logic) injecting a completely nil `SummaryResult` and asserting safe initialization.
