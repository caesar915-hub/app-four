# Tasks: Update PR37 (Model Interception)

**Input**: Design documents from `/specs/041-update-pr37/`

**Prerequisites**: plan.md (required), spec.md (required for user stories)

**Tests**: Test-first is MANDATORY for logic (SwiftData `@Model` types, `Services/`, `@Observable` view-models, NLP extraction) per Constitution **Principle X** — write the test, run it, confirm it **FAILS (RED)**, then implement just enough to make it pass (**GREEN**), then refactor. SwiftUI **views are EXEMPT** (verified by build + on-simulator run; snapshot tests optional). Tests use **Swift Testing** (`@Test`/`#expect`). Each user story's Tests block below is REQUIRED, not optional.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1)
- Include exact file paths in descriptions

## Path Conventions

- **Mobile**: `app-four/Views/`, `app-four/ViewModels/`, `app-four/Services/`

---

## Phase 1: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented. Specifically, the background lifecycle resiliency and storage capabilities in `AIModelService`.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T001 [US1] Write test verifying `AIModelService` throws `StorageError` if storage is insufficient for download.
- [x] T002 [US1] Implement `StorageError` enum and available storage checks in `app-four/Services/AIModelService.swift`.
- [x] T003 [US1] Implement background task assertions (`UIApplication.shared.beginBackgroundTask`) and cellular bypass in `app-four/Services/AIModelService.swift`'s `downloadModel` method.

**Checkpoint**: Foundation ready - `AIModelService` can now handle robust background downloading and storage checks.

---

## Phase 2: User Story 1 - Model Download Interception Before Recording (Priority: P1) 🎯 MVP

**Goal**: Present a system-native download alert when attempting to record without the model, allowing background downloads while recording concurrently.

**Independent Test**: Delete the local Whisper model, tap the microphone button in CheckInView, and accept the download prompt. Verify the download proceeds in the background without blocking the recording state.

### Tests for User Story 1 (test-first · RED — MANDATORY for logic) ⚠️

> **NOTE (RED): Write these tests FIRST and RUN them — they MUST FAIL before any implementation. Then implement only enough to turn them GREEN, then refactor. A failing-test checkpoint precedes### Phase 2: User Story 1 (ViewModel & UI Logic)
- [x] **T004** [P] [US1] Write unit test in `app-fourTests/ViewModels/CheckInViewModelTests.swift` verifying `startRecording()` sets `showModelDownloadPrompt = true` and aborts if `aiModelService.localPath` is nil and not downloading.
- [x] **T005** [P] [US1] Write unit test in `app-fourTests/ViewModels/CheckInViewModelTests.swift` verifying `startRecordingWithDownload()` launches the download and transitions to recording state.
- [x] **T006** [P] [US1] Write unit test in `app-fourTests/ViewModels/CheckInViewModelTests.swift` verifying `startRecordingWithoutDownload()` skips download and transitions to recording state.
- [x] **T007** [P] [US1] Update `CheckInViewModel.swift`: Add `@Published var showModelDownloadPrompt` and modify `startRecording()` to implement the interception logic.
- [x] **T008** [P] [US1] Update `CheckInViewModel.swift`: Add `startRecordingWithDownload()` method that initiates the download stream and continues recording.
- [x] **T009** [P] [US1] Update `CheckInViewModel.swift`: Add `startRecordingWithoutDownload()` method that proceeds with recording and ignores the missing model.
- [x] **T010** [P] [US1] Update `CheckInView.swift`: Add an `.alert` modifier bound to `$viewModel.showModelDownloadPrompt` with "Download" and "Not Now" buttons.
- [x] **T011** [P] [US1] Update `CheckInView.swift`: Add `.alert` modifiers for `$viewModel.showStorageError` and `$viewModel.showDownloadFailedError`. states.

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Foundational (Phase 1)**: Can start immediately.
- **User Stories (Phase 2)**: Depends on Foundational phase completion (ViewModel needs the updated `AIModelService`).

### Within Each User Story

- Tests MUST be written, RUN, and confirmed FAILING (RED) before implementation (GREEN); refactor after green (Principle X).
- ViewModel logic before SwiftUI views.
- Story complete before moving to next priority.
