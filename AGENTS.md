# Agent Guide — Squirl (app-four)

This file contains project-specific instructions for coding agents working on the Squirl iOS app.

---

## Project at a Glance

- **Product:** Squirl — an on-device, privacy-first iOS journal for ADHD adults.
- **Language:** Swift 5, SwiftUI, iOS 17.0+.
- **Persistence:** SwiftData.
- **Concurrency:** Swift Concurrency (`async/await`, `@MainActor`, actors, `AsyncStream`).
- **Observation:** `@Observable` ViewModels and `AppServices`.
- **Local packages:** `SquirlSignals` (level enums), `SquirlDesignSystem` (tokens, glyphs, components).
- **External dependency:** `WhisperKit` for on-device transcription.
- **Tests:** XCTest in `app-fourTests/`; run serially (suite is not parallel-safe).

---

## Architecture Rules

1. **Views do not touch singletons directly.** Dependencies are injected through the SwiftUI environment (`AppServices`, `RecordingStore`, `MedicationBarViewModel`, `ScreenTracker`, `DiagnosticsStore`).
2. **Services are protocol-driven.** Every service capability lives behind a protocol defined in `app-four/Services/Protocols.swift`; provide mocks for tests and previews.
3. **RecordingStore is the SSOT for recordings.** It is `@Observable @MainActor`. Heavy work happens off the main actor via `Task.detached` or actor-isolated services.
4. **SwiftData models are the source of truth.** Do not duplicate model state in ViewModels unless it is genuinely transient (e.g., a draft).
5. **Use `applySummary(_:fillOnly:)` as the single writer** for NLP extraction results on `Recording`.
6. **Custom signal glyphs, not SF Symbols or emoji.** Signals are rendered by `SignalGlyph` in `SquirlDesignSystem` using shape+fill+hue encoding.
7. **No streaks, no gamification, no medication alarms.** These are deliberate product constraints.

---

## Code Style

- Prefer `@Observable @MainActor` for ViewModels.
- Prefer `some View` and small dedicated subviews; avoid massive `body` blocks.
- Use `Task.detached` for CPU-heavy work; keep UI updates on `@MainActor`.
- Use `AsyncStream` for progress-like events.
- Keep service implementations actor-isolated when they own mutable state.
- Use SwiftData's `@Relationship` and inverse relationships consistently.
- Prefer explicit dependency injection over `static` globals.

---

## Spec Kit Workflow

Features are specced under `specs/NNN-feature-name/`:

- `spec.md` — requirements and acceptance criteria
- `plan.md` — implementation plan and trade-offs
- `tasks.md` — dependency-ordered tasks

Follow the Spec Kit skills in `.claude/skills/speckit-*/` when creating or updating feature specs. Do not bypass the constitution gates documented in `CLAUDE.md`.

---

## Git & Session Workflow

- Work on feature branches when possible.
- Keep commits focused and atomic.
- Do not run `git commit`, `git push`, `git reset`, `git rebase`, or other destructive git operations unless explicitly asked.
- When starting a session, review `CLAUDE.md` and `docs/TODO.md` for current priorities and known gaps.
- Update `docs/TODO.md` or relevant spec artifacts if your work closes a documented gap.

---

## Common Files to Know

| File | Purpose |
|------|---------|
| `app-four/App/SquirlApp.swift` | App launch, onboarding, background model download |
| `app-four/App/AppModelContainer.swift` | SwiftData container, privacy backup exclusion |
| `app-four/Store/RecordingStore.swift` | Central data access + mutation |
| `app-four/Store/AppDependencies.swift` | Service singleton wiring |
| `app-four/Store/AppServices.swift` | Environment-injected service bundle |
| `app-four/Models/Recording.swift` | Core SwiftData entity |
| `app-four/Services/Protocols.swift` | Service contracts + DTOs |
| `app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift` | Transcription backend |
| `app-four/Services/NLSummarizationService.swift` | NLP summarization adapter |
| `app-four/Services/NoteExtraction/NLNoteExtractor.swift` | Structured extraction engine |
| `app-four/ViewModels/CheckInViewModel.swift` | Capture flow state machine |
| `DESIGN.md` | Visual/UI source of truth |
| `CLAUDE.md` | Agent behavior and process |
| `docs/BACKLOG.md` | Milestones |
| `docs/TODO.md` | Known gaps |

---

## Skills to Use

When working on relevant areas, consult these skills:

- `swiftui-pro`
- `swiftui-patterns`
- `swiftui-view-refactor`
- `swiftui-design-principles`
- `swift-accessibility-skill`
- `swift-concurrency-expert`
- `swiftdata-pro`
- `swift-testing-pro`
- `impeccable` (for UI/UX polish)

---

## Things to Avoid

- Adding cloud sync, analytics, or remote APIs without explicit approval.
- Introducing medication alarms, streaks, or gamification.
- Using SF Symbols or emoji for signal visualization.
- Running tests in parallel.
- Making large architectural changes without a spec/plan review.
