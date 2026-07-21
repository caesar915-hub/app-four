# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) for Squirl. Each ADR captures a significant technical decision, the context in which it was made, the options considered, and the consequences.

## Format

ADRs follow this structure:

1. **Title** — `ADR NNN: Short Title`
2. **Status** — Proposed / Accepted / Deprecated / Superseded
3. **Context** — What problem were we solving?
4. **Decision** — What did we decide?
5. **Consequences** — Positive and negative outcomes
6. **Alternatives Considered** — Options rejected and why

## Active ADRs

| ADR | Title | Status |
|-----|-------|--------|
| [001](001-mvvm-store-dependency-injection.md) | MVVM + Centralized Store + Environment-Based DI | Accepted |
| [002](002-swiftdata-local-privacy-first-storage.md) | SwiftData with Local-Only, Privacy-First Storage | Accepted |
| [003](003-whisperkit-on-device-transcription.md) | WhisperKit for On-Device Transcription | Accepted |
| [004](004-protocol-oriented-services.md) | Protocol-Oriented Services | Accepted |
| [005](005-deterministic-nlp-extraction.md) | Deterministic NLP Extraction with NaturalLanguage + Lexicon | Accepted |

## Adding an ADR

1. Copy the structure from an existing ADR.
2. Use the next available number.
3. Keep it focused on one decision.
4. Update this index.
