# ADR 003: WhisperKit for On-Device Transcription

## Status

Accepted

## Context

The app must transcribe voice check-ins accurately and privately. The transcription engine needs to:

- Run entirely on device.
- Handle conversational, sometimes ADHD-specific vocabulary.
- Work within iPhone memory and thermal constraints.
- Be downloadable on demand to keep the initial app size reasonable.

## Decision

Use **OpenAI Whisper Small via WhisperKit** for transcription:

- Downloaded in the background after first launch.
- Filesystem presence is the source of truth for readiness.
- `WhisperKitTranscriptionService` is an actor to serialize access and isolate mutable model state.
- `unloadModel()` is called immediately after each transcription to free Metal/CoreML memory.
- `DecodingOptions` include ADHD-biased prompt tokens and medication names.

## Consequences

### Positive

- High transcription accuracy for conversational audio.
- Fully offline and private.
- Whisper Small balances quality and resource use.
- Background download keeps initial install small.

### Negative

- First transcription requires a model download; pending queue adds complexity.
- Whisper Small uses significant RAM; must be unloaded aggressively.
- Download failures require graceful UI and retry logic.

## Alternatives Considered

- **Apple Speech framework:** Free and fast but less accurate for domain vocabulary and longer utterances. Implemented as `SpeechTranscriptionService` as a selectable fallback.
- **Whisper Base/Large:** Higher accuracy but heavier memory use. Rejected for v1 due to device constraints.
- **Server-side transcription:** Violates privacy principle; rejected.
