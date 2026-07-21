# New Team Member Onboarding

_Last updated: 2026-06-28_

Welcome to Squirl. This guide will get you from zero to a productive first contribution.

---

## Day 1: Setup

1. **Clone the repository** to `/Users/caesargrey/Projects/app-four` (or your preferred location).
2. **Install prerequisites:**
   - macOS 15+
   - Xcode 16+
   - (Optional) XcodeGen for the sandbox app
3. **Open the project:**

   ```bash
   open app-four.xcodeproj
   ```

4. **Resolve packages:** Xcode will fetch `WhisperKit` automatically.
5. **Build and run** on an iOS 17+ simulator.

You should land on a populated timeline because debug builds seed mock data automatically.

---

## Read This First

Spend 30 minutes with these docs before touching code:

1. [`README.md`](../README.md) — project overview and build instructions.
2. [`docs/engineering/ARCHITECTURE.md`](engineering/ARCHITECTURE.md) — how the app is structured.
3. [`docs/engineering/SERVICES.md`](engineering/SERVICES.md) — service layer contracts.
4. [`docs/engineering/DATA_MODEL.md`](engineering/DATA_MODEL.md) — SwiftData schema.
5. [`docs/product/README.md`](product/README.md) — product principles and anti-features.
6. [`DESIGN.md`](../DESIGN.md) — design system.
7. [`CLAUDE.md`](../CLAUDE.md) — only if you are an agent contributor.

---

## Codebase Tour

### Entry Points

- `app-four/App/SquirlApp.swift` — app launch, environment injection, background model download.
- `app-four/App/AppModelContainer.swift` — SwiftData container setup.
- `app-four/Store/AppDependencies.swift` — service singleton wiring.

### Core Flows

| Flow | Start Here |
|------|------------|
| Voice check-in | `app-four/ViewModels/CheckInViewModel.swift` → `app-four/Views/CheckIn/CheckInView.swift` |
| Text check-in | `app-four/Store/RecordingStore.swift` → `TextCheckInComposer` |
| Transcription | `app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift` |
| NLP extraction | `app-four/Services/NLSummarizationService.swift` → `app-four/Services/NoteExtraction/NLNoteExtractor.swift` |
| Calendar/timeline | `app-four/Views/Library/CalendarLibraryView.swift` |
| Insights | `app-four/Views/InsightsView.swift` |
| Settings | `app-four/Views/SettingsView.swift` |

### Local Packages

- `Packages/SquirlSignals/` — level enums shared across the app and design system.
- `Packages/SquirlDesignSystem/` — tokens, typography, palette, signal glyphs, reusable components.

### Supporting Tools

- `SandboxApp/` — design-system iteration.
- `WhisperCLI/` — WhisperKit command-line experimentation.

---

## Your First Tasks

Pick one of these to get familiar with the codebase:

1. **Add a unit test** for `Recording.applySummary(_:fillOnly:)` in `app-fourTests/Models/`.
2. **Trace a voice check-in** from tap to saved recording, following the data flow in `ARCHITECTURE.md`.
3. **Iterate on a design-system component** in `SandboxApp/`.
4. **Fix a TODO** from `docs/TODO.md` that is marked P1 or P2.

---

## Development Workflow

1. Create a feature branch from `main`:

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make focused, atomic commits.
3. Write or update tests for behavior changes.
4. Update docs if you change architecture, services, or data models.
5. Run the full test suite serially before opening a PR.
6. Open a PR and request review from at least one teammate.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for detailed conventions.

---

## Getting Help

- Check the docs in `docs/` first.
- Look at existing specs in `specs/NNN-feature-name/` for context on recent features.
- Ask in the team channel if something is unclear — docs only improve when gaps are reported.
