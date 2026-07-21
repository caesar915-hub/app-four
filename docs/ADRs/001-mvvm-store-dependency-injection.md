# ADR 001: MVVM + Centralized Store + Environment-Based DI

## Status

Accepted

## Context

Squirl is a SwiftUI app with significant local state: recordings, transcripts, extracted signals, medication events, settings, and model download status. We needed an architecture that:

- Keeps views testable and free of business logic.
- Provides a single source of truth for persisted data.
- Allows services to be mocked for tests and previews.
- Works cleanly with SwiftData and Swift Concurrency.

## Decision

Adopt **MVVM + centralized Store + environment-based dependency injection**:

- **Views** are pure SwiftUI.
- **ViewModels** own screen-level `@Observable` state and coordinate use cases.
- **Store** (`RecordingStore`) is the single access point for `Recording` CRUD.
- **Services** are protocol-driven and injected via `AppServices` in the SwiftUI environment.

## Consequences

### Positive

- Views and ViewModels are decoupled from concrete service implementations.
- Unit tests can inject mocks without refactoring views.
- SwiftData mutations are centralized in the Store and model extensions.
- The architecture is familiar to iOS engineers and well-supported by SwiftUI.

### Negative

- The `AppServices` bundle grows as more capabilities are added.
- ViewModels can become large if not decomposed carefully.
- Environment injection requires discipline; no singleton access from views.

## Alternatives Considered

- **TCA (The Composable Architecture):** Powerful but adds significant complexity and learning curve for a small team. Rejected for v1.
- **Direct `@Environment` injection of individual services:** More granular but creates a large number of environment keys. Rejected in favor of a single observable bundle.
