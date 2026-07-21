# Testing Strategy

_Last updated: 2026-06-28_

This document describes how Squirl is tested, the conventions we follow, and how to write new tests.

---

## Table of Contents

- [Test Philosophy](#test-philosophy)
- [Test Targets](#test-targets)
- [Running Tests](#running-tests)
- [Test Conventions](#test-conventions)
- [What to Test](#what-to-test)
- [Mocking](#mocking)
- [Known Limitations](#known-limitations)
- [Adding Tests](#adding-tests)

---

## Test Philosophy

- Tests should be fast, deterministic, and isolated where possible.
- Prefer testing behavior through protocols and ViewModel state over implementation details.
- Use mocks for services; use the in-memory `previewContainer` for SwiftData-backed tests.
- The suite is currently run serially because of shared state.

---

## Test Targets

| Target | Path | Purpose |
|--------|------|---------|
| `app-fourTests` | `app-fourTests/` | Unit and integration tests for the main app. |

There is no separate UI test target currently.

---

## Running Tests

### Xcode

1. Select the `app-four` scheme.
2. Press `⌘U` or choose **Product → Test**.

### Command Line

```bash
cd /Users/caesargrey/Projects/app-four
xcodebuild test \
  -project app-four.xcodeproj \
  -scheme app-four \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -disableParallelTesting
```

> Always use `-disableParallelTesting`. The suite is not parallel-safe.

---

## Test Conventions

- **File naming:** `*Tests.swift`.
- **Class naming:** `<Feature>Tests` inheriting from `XCTestCase`.
- **Test naming:** `test<Behavior>_<Condition>_<ExpectedResult>`.
- **Use `@MainActor` for tests that touch ViewModels or SwiftData contexts.**
- **Inject mocks via initializers**, not via global state.

Example:

```swift
@MainActor
final class RecordingStoreTests: XCTestCase {
    func test_createCheckInNote_persistsRecordingWithUserValues() {
        let container = AppModelContainer.previewContainer
        let store = RecordingStore(context: container.mainContext)

        let draft = CheckInDraft(
            mood: .calm,
            energy: .moderate,
            focus: .focused,
            note: "Feeling okay today.",
            meds: []
        )

        let recording = store.createCheckInNote(draft)

        XCTAssertEqual(recording.mood, "calm")
        XCTAssertEqual(recording.status, .completed)
        XCTAssertTrue(recording.fullTranscriptText.contains("okay"))
    }
}
```

---

## What to Test

### High Priority

- `Recording.applySummary(_:fillOnly:)` — correctness of extraction result application.
- `Recording.setMedicationEvents(...)` — manual events are preserved; transcript events are reconciled.
- `RecordingStore` CRUD operations — insert, delete, update, mock-mode filtering.
- Service protocol implementations — happy path and error paths.
- ViewModel state machines — especially `CheckInViewModel` recording lifecycle.

### Medium Priority

- NLP extraction outputs for representative transcripts.
- Date/time resolution in `MedicationEvent`.
- Audio storage URL resolution.

### Low Priority / Out of Scope

- Pure SwiftUI view layout (test via snapshot tests if added later).
- WhisperKit transcription accuracy (validated manually or via WhisperCLI).

---

## Mocking

Mock services live in `app-four/Services/Mock/`. Common patterns:

- Conform to the service protocol.
- Provide deterministic outputs.
- Expose hooks to simulate errors or delays.
- Keep mocks simple; do not reimplement business logic.

Use the in-memory `AppModelContainer.previewContainer` for tests that need a real `ModelContext` without touching the file system.

---

## Known Limitations

- **Serial execution required.** Parallel tests share the in-memory container and file system and will flake.
- **No UI tests.** The project currently relies on unit/integration tests only.
- **No performance baselines.** CPU-heavy paths (Whisper, NLP) are not under automated performance testing.
- **Schema conflict wipe.** Pre-release builds wipe the store on schema mismatch, which affects tests that rely on persistence across launches.

---

## Adding Tests

1. Add a new file under `app-fourTests/` in the appropriate subdirectory.
2. Inherit from `XCTestCase` and annotate with `@MainActor` if needed.
3. Inject dependencies via initializers or environment.
4. Use mocks or `previewContainer` for SwiftData.
5. Run the full suite serially before opening a PR.
