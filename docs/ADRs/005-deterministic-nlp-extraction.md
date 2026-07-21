# ADR 005: Deterministic NLP Extraction with NaturalLanguage + Lexicon

## Status

Accepted

## Context

After transcription, the app must extract structured signals (mood, energy, focus, sleep, medications, emotions, side effects, topics) without sending data to a server. The extraction must:

- Run instantly on device.
- Be explainable and debuggable.
- Work offline.
- Improve over time with user corrections.

## Decision

Use **Apple's `NaturalLanguage` framework combined with a custom lexicon-driven `NLNoteExtractor`**:

- Deterministic rule and pattern matching.
- No CoreML model download.
- Runs off the main actor via `Task.detached`.
- Personal lexicon can be trained from `RecordingTag(source: .userCorrected)` corrections.

## Consequences

### Positive

- Instant, offline, and private.
- Fully explainable outputs.
- Easy to extend with new lexicon entries or patterns.
- No additional binary size from ML models.

### Negative

- Less flexible than a large language model for unusual phrasing.
- Requires ongoing lexicon maintenance.
- Complex multi-sentence or ambiguous references may be missed.

## Alternatives Considered

- **On-device LLM (e.g., small transformer):** More capable but slower, larger, and less predictable. Documented as a future path in `docs/engineering/next-ml.md`.
- **Cloud NLP API:** Violates privacy principle; rejected.
