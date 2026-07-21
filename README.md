# Squirl

Squirl is an on-device, privacy-first iOS journal for ADHD adults.

Open the app, voice-log (or type) a daily check-in in under a minute, and Squirl transcribes the audio with OpenAI Whisper (via [WhisperKit](https://github.com/argmaxinc/WhisperKit)) and extracts structured signals — mood, energy, focus, sleep, medications, emotions, side effects — using a deterministic on-device NLP pipeline. A searchable day-by-day timeline in Calendar and pattern surfaces in Insights help users notice what affects them without gamification, streaks, or medication nagging.

> **Product principle:** *effortless* — in and out in under a minute, always slightly calmer than before.

---

## Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
- [Development](#development)
- [Testing](#testing)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [Privacy](#privacy)
- [License](#license)

---

## Features

- **Voice check-in** — one-tap recording with rotating prompt nudges, an 8-minute soft cap, live timer, pause/resume, and a calm "wrapping up soon" cue.
- **Text check-in** — signal-first composer with mood/energy/focus pickers, free-form note, and medication selection.
- **On-device transcription** — Whisper Small runs locally; downloaded in the background with a pending queue for recordings captured before the model is ready.
- **NLP extraction** — derives mood, energy, focus, sleep, medications, emotions, side effects, appointments, highlights, and topics from transcripts.
- **Calendar / Library** — collapsible week/month calendar bound to a day-grouped timeline; fold/expand day cards; tap any entry for detail.
- **Insights** — mood bubble chart, weekday signal strips, averages, daily rhythm matrix, and connections; scoped to a selected month.
- **Medication tracking** — standalone dose logs plus transcript-extracted doses; a medication bar overlay shows the active effect window with no alarms.
- **Extraction review / edit** — correct signals, meds, emotions, and side effects; corrections write `RecordingTag(source: .userCorrected)` to train a personal lexicon.
- **Settings** — model download/management, storage, cellular download toggle, prompt pace, day-card + med-bar toggles, encrypted journal export, clear data, and a debug console.
- **Accessibility** — VoiceOver live regions, active-voice announcement gate, Reduce Motion support, and Dynamic Type via `UIFontMetrics`.

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| UI | SwiftUI, iOS 17.0+ |
| Persistence | SwiftData |
| Concurrency | Swift Concurrency (`async/await`, `@MainActor`, `actor`s, `AsyncStream`) |
| Observation | `@Observable` ViewModels and `AppServices` |
| Audio | `AVFoundation` recording, custom `AudioConverter` |
| Transcription | WhisperKit (`openai_whisper-small`) |
| NLP extraction | Apple `NaturalLanguage` + custom lexicon-driven `NLNoteExtractor` |
| Local packages | `SquirlSignals` (level enums), `SquirlDesignSystem` (tokens, glyphs, components) |
| Tests | XCTest |

---

## Project Structure

```text
app-four/
├── App/                    # App entry, model container, package re-exports
├── Models/                 # SwiftData models + enums
├── Services/               # Protocols + implementations
│   ├── Audio/
│   ├── WhisperKit/
│   ├── Speech/
│   ├── NoteExtraction/
│   ├── Connectivity/
│   └── Mock/
├── Store/                  # RecordingStore, DI wiring, previews
├── ViewModels/             # @Observable coordinators
├── Views/                  # SwiftUI screens + components
│   ├── CheckIn/
│   ├── Library/
│   ├── Insights/
│   ├── Settings/
│   ├── Components/
│   ├── Feedback/
│   └── Onboarding/
├── DesignSystem/           # App-specific container chrome
├── Utils/                  # Helpers
├── wireframes/             # Placeholder views for later screens
├── Resources/              # Assets, Info.plist
└── Assets.xcassets/

Packages/
├── SquirlSignals/          # Level enums (Mood/Energy/Focus/Sleep)
└── SquirlDesignSystem/     # Tokens, typography, palette, glyphs, buttons, cards

WhisperCLI/                 # Separate macOS SPM executable for WhisperKit CLI
SandboxApp/                 # XcodeGen-driven sandbox app for design-system iteration

specs/                      # Per-feature specs/plans/tasks
docs/                       # Engineering, product, and design documentation
html-mockups/ + mockups/    # Design prototypes
```

---

## Architecture

Squirl follows **MVVM + centralized Store + environment-based dependency injection**.

- **Views** are pure SwiftUI and contain no business logic.
- **ViewModels** own screen-level `@Observable` state and coordinate between Views, the Store, and Services.
- **Store** (`RecordingStore`) is the single source of truth for recordings and mutations.
- **Services** implement low-level capabilities behind protocols so they can be mocked or swapped.
- **Models** are SwiftData `@Model` objects persisted to a local store.

Dependencies are constructed in `AppDependencies.swift` and injected into the SwiftUI environment via `AppServices`. Views read the bundle through `@Environment(AppServices.self)`. Heavy services are actor-isolated; UI updates and SwiftData mutations stay on `@MainActor`.

For the full architecture overview, see [`docs/engineering/ARCHITECTURE.md`](docs/engineering/ARCHITECTURE.md).

---

## Getting Started

1. Open `app-four.xcodeproj` in Xcode 16 or later.
2. Select the `app-four` target and an iOS 17+ simulator or device.
3. Build and run (`⌘R`).

The app downloads the Whisper Small model on first launch. Recordings made before the model is ready are queued in `PendingTranscriptionService` and transcribed once the download completes.

See [`docs/ONBOARDING.md`](docs/ONBOARDING.md) for a day-one guide for new team members.

---

## Development

Detailed development instructions are in [`docs/engineering/DEVELOPMENT.md`](docs/engineering/DEVELOPMENT.md), including:

- Working with the Sandbox App
- Working with WhisperCLI
- Debug workflows and launch arguments
- Release build configuration

Quick commands:

```bash
# Generate sandbox project
cd SandboxApp && xcodegen generate && open SquirlSandbox.xcodeproj

# Build WhisperCLI
cd WhisperCLI && swift build

# Run tests serially from command line
xcodebuild test \
  -project app-four.xcodeproj \
  -scheme app-four \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -disableParallelTesting
```

---

## Testing

Tests live in `app-fourTests/` and use XCTest. The suite is currently **not parallel-safe** and must be run serially.

In Xcode: select the `app-four` scheme and press `⌘U`.

From the command line:

```bash
xcodebuild test \
  -project app-four.xcodeproj \
  -scheme app-four \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -disableParallelTesting
```

See [`docs/engineering/TESTING.md`](docs/engineering/TESTING.md) for the full testing strategy.

---

## Documentation

| Document | Purpose |
|----------|---------|
| [`docs/ONBOARDING.md`](docs/ONBOARDING.md) | New team member guide |
| [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) | Branching, PRs, code review, style conventions |
| [`docs/engineering/ARCHITECTURE.md`](docs/engineering/ARCHITECTURE.md) | System architecture and data flow |
| [`docs/ui/ARCHITECTURE.md`](docs/ui/ARCHITECTURE.md) | UI patterns, navigation, state flow, accessibility |
| [`docs/ui/VIEW_MODELS.md`](docs/ui/VIEW_MODELS.md) | ViewModel catalog and responsibilities |
| [`docs/ui/COMPONENTS.md`](docs/ui/COMPONENTS.md) | Reusable component catalog |
| [`docs/engineering/SERVICES.md`](docs/engineering/SERVICES.md) | Service protocols and implementations |
| [`docs/engineering/DATA_MODEL.md`](docs/engineering/DATA_MODEL.md) | SwiftData schema and relationships |
| [`docs/engineering/DEVELOPMENT.md`](docs/engineering/DEVELOPMENT.md) | Build, run, test, debug |
| [`docs/engineering/TESTING.md`](docs/engineering/TESTING.md) | Testing strategy |
| [`docs/engineering/OPERATIONS.md`](docs/engineering/OPERATIONS.md) | Release process and runbook |
| [`docs/ADRs/`](docs/ADRs/) | Architecture Decision Records |
| [`docs/product/README.md`](docs/product/README.md) | Product definition |
| [`DESIGN.md`](DESIGN.md) | Design system "Paper & Pollen" |
| [`docs/BACKLOG.md`](docs/BACKLOG.md) | Milestones and feature stages |
| [`docs/TODO.md`](docs/TODO.md) | Load-bearing pre-launch gaps |

---

## Contributing

See [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) for branching, commit message, PR, and code review conventions.

Quick rules:

- Work on feature branches.
- Keep commits focused and atomic.
- Run the full test suite serially before opening a PR.
- Update docs when you change architecture, services, or data models.

---

## Privacy

- All audio, transcripts, and extracted signals stay on device.
- Whisper transcription and NLP extraction run locally.
- The SwiftData store directory is excluded from iCloud backup.
- Encrypted export is available before any data leaves the device.
- No analytics or crash-reporting SDK is currently wired.

---

## License

Proprietary — © Squirl. All rights reserved.
