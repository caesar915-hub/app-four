# Implementation Plan: Update PR37 (Model Interception & Settings Integration)

**Branch**: `041-update-pr37` | **Date**: 2026-08-10 | **Spec**: [specs/041-update-pr37/spec.md](file:///Users/caesargrey/Projects/app-four/specs/041-update-pr37/spec.md)

**Input**: Feature specification from `/specs/041-update-pr37/spec.md`

## Summary

This plan outlines the architecture for two related model-management features:
1. **User Story 1**: Intercepting manual voice check-ins when the Whisper model is not downloaded. It introduces a pre-flight check in `CheckInViewModel` to present a native iOS `.alert`, allowing users to download the ~150MB model in the background while recording concurrently.
2. **User Story 2 (Phase 3)**: Exposing manual model management within the app's Settings tab, allowing the user to view status, download manually over Wi-Fi/cellular, or delete the model to free up space.

**Important Note on Phase 3**: Research indicates that **Phase 3 is already fully implemented and verified** in the `main` branch (`SettingsViewModel`, `SettingsView`, `ModelDownloadRow`, and `SettingsViewModelTests`). Therefore, no code changes are required for Phase 3 in this spec arc.

## Technical Context

**Language/Version**: Swift 6, iOS 18 (Strict Concurrency)

**Primary Dependencies**: SwiftUI, SwiftData

**Storage**: Local file system (for the downloaded model), SwiftData (for `.pendingTranscription` records)

**Testing**: Swift Testing (XCTest for UI if needed)

**Target Platform**: iOS 26+

**Project Type**: Mobile app (`app-four`)

**Performance Goals**: Model download must not hitch the UI; background tasks must be cleanly decoupled from View lifecycle.

**Constraints**: On-device transcription only; strict concurrency isolation.

**Scale/Scope**: Local iOS app.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. SwiftUI-First** — UI is SwiftUI on modern APIs (iOS 26+); no UIKit unless no SwiftUI equivalent; new views have an HTML mockup first.
- [x] **II. Test-Build-Ship** — plan produces a buildable, fully-tested change; no step ships unverified.
- [x] **III. Correctness Over Speed** — no dead code, compat shims, or stubs; any tradeoff is surfaced explicitly.
- [x] **IV. Minimal Surface** — no abstractions/flags beyond what the task needs; added complexity justified below.
- [x] **V. Solo Git Discipline** — work is one revertable feature on a `feat/…` or `fix/…` branch, `/code-review` before merge, `main` stays releasable.
- [x] **VI. On-Device Privacy** — no audio/health/mood/med data leaves the device; no cloud by default; logs are counts/durations only.
- [x] **VII. Deterministic, Measured Extraction** — extraction stays deterministic, off-main, whole-token, lexicon-as-data; eval harness run, floors not regressed.
- [x] **VIII. Service-Oriented Architecture** — new capabilities behind a `Services/` protocol via `AppDependencies`; `@MainActor @Observable` VMs; heavy work off-main.
- [x] **IX. Pre-Release Data Posture** — schema stays CloudKit-compatible (optional/defaulted, no `@Attribute(.unique)`); any unique/required attribute justified.
- [x] **X. Test-First Development** — logic (models, services, view-models, NLP extraction) is built test-first (RED→GREEN→refactor) with Swift Testing; tests are MANDATORY, ordered before implementation; SwiftUI views exempt (build + run).

## Project Structure

### Documentation (this feature)

```text
specs/041-update-pr37/
├── plan.md              # This file
├── spec.md              # Specification
└── tasks.md             # Tasks to be generated
```

### Source Code (repository root)

```text
app-four/
├── Views/
│   ├── CheckIn/
│   │   └── CheckInView.swift      # Added .alert modifier
│   └── Settings/
│       └── ModelDownloadRow.swift # (Already implemented)
├── ViewModels/
│   ├── CheckInViewModel.swift     # Added pre-flight state and download logic
│   └── SettingsViewModel.swift    # (Already implemented)
├── Services/
│   └── AIModelService.swift       # Added background task assertions & storage checks
```

## Architecture & Implementation Details

### 1. `AIModelService.swift` Modifications (Phase 2)
- Wrap `downloadModel(_:)` in a background task assertion using `UIApplication.shared.beginBackgroundTask(withName: "WhisperDownload")` to ensure iOS does not kill the 150MB download when the app is backgrounded.
- Enhance the download method to bypass cellular restrictions when triggered manually from this prompt.
- Add a pre-download check for available device storage (checking for ~150MB + buffer). Throw a specific `StorageError` if insufficient space exists.

### 2. `CheckInViewModel.swift` Modifications (Phase 2)
- Add `@MainActor` state variables for the UI:
  - `showModelDownloadPrompt: Bool = false`
  - `showStorageError: Bool = false`
  - `showDownloadFailedError: Bool = false`
- Update `startRecording()` to act as a pre-flight check:
  - Check if `!aiModelService.isDownloading` AND `aiModelService.localPath == nil`.
  - If both true, set `showModelDownloadPrompt = true` and abort immediate recording.
- Implement `startRecordingWithDownload()`:
  - Resets alert state.
  - Launches an unstructured, detached `Task` to invoke `aiModelService.downloadModel()`. This decoupling prevents cancellation if the ViewModel deallocates.
  - Immediately invokes the internal recording start mechanism.
- Implement `startRecordingWithoutDownload()`:
  - Resets alert state and proceeds with recording without initiating the download.

### 3. `CheckInView.swift` Modifications (Phase 2)
- Bind a primary `.alert("Voice Model Required", isPresented: $viewModel.showModelDownloadPrompt)` to prompt for the download.
  - Actions: "Download & Record" (triggering `startRecordingWithDownload`), "Record Only", and "Cancel".
- Bind secondary `.alert`s for the `showStorageError` and `showDownloadFailedError` states.

### 4. Settings Integration (Phase 3) - ALREADY IMPLEMENTED
- The codebase already contains full support for Settings manual model management. 
- **`ModelDownloadRow.swift`** accurately reflects the filesystem truth, presents a confirmation dialog upon deletion, and provides retry/cellular-override interfaces on error.
- **`SettingsViewModel.swift`** manages `checkModels()`, `downloadModel()`, `cancelDownload()`, and `deleteModel()` fully isolated to the `@MainActor`. 
- **`SettingsViewModelTests.swift`** has extensive test coverage covering offline errors, metered connection gates, and cancellation recovery.
- **Action**: No code changes needed for this phase.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

*No violations. The architecture remains strictly MV (Model-View), decoupling background services (AIModelService) from view lifecycles using structured/detached concurrency.*
