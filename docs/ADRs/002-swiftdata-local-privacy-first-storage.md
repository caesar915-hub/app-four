# ADR 002: SwiftData with Local-Only, Privacy-First Storage

## Status

Accepted

## Context

Squirl handles sensitive health-adjacent data: voice memos, transcripts, medication names, mood, energy, sleep, and side effects. Privacy is a core product principle. We needed a persistence solution that:

- Stores data locally without cloud dependency.
- Integrates cleanly with SwiftUI.
- Supports the iOS 17 deployment target.
- Can be excluded from iCloud backup.

## Decision

Use **SwiftData** as the local persistence layer with:

- All entities stored on device.
- Store directory marked `isExcludedFromBackupKey`.
- No cloud sync or remote storage.
- Schema conflict wipe as a pre-release fallback; lightweight migration to be implemented before v1.0.

## Consequences

### Positive

- Native Apple framework with first-class SwiftUI integration.
- No third-party database dependency.
- Clear privacy story for users and App Store review.

### Negative

- Schema migrations require explicit versioning; currently handled by wipe fallback.
- JSON-encoded fields are needed for arrays and nested types.
- Cross-device sync is not supported and would require a separate effort.

## Alternatives Considered

- **Core Data:** Mature but more verbose; SwiftData is the modern replacement.
- **Realm / GRDB:** Additional dependency; rejected to keep the stack minimal and Apple-native.
- **CloudKit sync:** Contradicts the privacy-first principle; rejected.
