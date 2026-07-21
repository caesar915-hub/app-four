# ADR 004: Protocol-Oriented Services

## Status

Accepted

## Context

The app depends on several capabilities that are complex to test or replace: audio recording, file storage, transcription, summarization, model management, and network connectivity. We needed a pattern that:

- Makes unit testing straightforward.
- Allows swapping implementations without view changes.
- Encourages small, focused contracts.

## Decision

Define every service capability behind a **protocol** in `app-four/Services/Protocols.swift`. Concrete implementations are wired in `AppDependencies.swift`. Mock implementations are provided in `app-four/Services/Mock/`.

All service protocols conform to `Sendable`. Stateful services are implemented as actors.

## Consequences

### Positive

- Tests can inject deterministic mocks.
- SwiftUI previews can run without real hardware or model downloads.
- Multiple transcription backends (WhisperKit, Apple Speech) coexist behind the same protocol.
- Contracts are explicit and stable.

### Negative

- More boilerplate than direct class usage.
- The `AppServices` bundle must be updated when adding a new service.
- Protocols with associated types or generic requirements can complicate environment injection.

## Alternatives Considered

- **Direct concrete service usage:** Simpler initially but harder to test and mock.
- **EnvironmentObject singletons:** Works but hides dependencies and makes unit testing fragile.
