# Contract — Transcription boundary (post-migration)

The `TranscriptionService` protocol (`app-four/Services/Protocols.swift`) stays the seam; view-models and the pending queue depend only on it. The migration keeps the file-based method (for deferred/pending transcription) and adds a live-streaming entry point.

## Protocol surface

```swift
protocol TranscriptionService: Sendable {
    // Deferred / pending path (assets became ready after capture). Unchanged signature.
    func transcribe(audioURL url: URL) async throws -> AsyncStream<TranscriptionSegmentDTO>

    // Live path (assets ready at capture time). Consumes converted mic buffers,
    // emits volatile (isFinal=false) then final (isFinal=true) segments.
    // Exact buffer type finalized in implementation; the contract is:
    //   input: an async sequence of mic PCM buffers (already at the analyzer format
    //          OR converted internally); output: a segment stream ending when the
    //          session is finalized.
    func transcribeLive(_ buffers: AsyncStream<AVAudioPCMBuffer>) -> AsyncStream<TranscriptionSegmentDTO>

    func cancelTranscription() async
    func loadModel() async throws   // = AssetInventory install for the selected module
}
```

## Behavioural contracts (engine impl `SpeechAnalyzerTranscriptionService`)

- **Engine selection:** resolves the ladder via `SpeechAnalyzerCapability` before creating a session; `.unavailable` → the stream yields a single `isError` segment (audio already persisted by the caller) and finishes. Never crashes.
- **Assets:** `loadModel()` runs `AssetInventory.assetInstallationRequest(supporting:)` + `downloadAndInstall()`; safe to call repeatedly; no-op if installed. Failure throws (mapped to `ModelDownloadFailure` where a cause is shown).
- **Volatile vs final:** live path emits `isFinal=false` segments that the UI must treat as replace-in-place for their range; a later `isFinal=true` commits. `transcribe(audioURL:)` (file) emits only final segments.
- **Finalization:** the impl always finishes the `SpeechAnalyzer` session (`finalizeAndFinish(through:)` / `finalizeAndFinishThroughEndOfInput()` / `cancelAndFinishNow()`); ending the input stream alone does not finish it. `cancelTranscription()` maps to `cancelAndFinishNow()` + teardown, idempotent.
- **Errors:** `SFSpeechError.insufficientResources` (concurrency cap) is retried/serialized, not forced. Other errors terminate the stream after yielding an `isError` segment; audio is never lost.
- **Privacy:** logs counts/durations/status only (Principle VI); never transcript text.
- **Threading:** `actor`; heavy work off the main actor; results delivered via `AsyncStream` for `@MainActor` consumers.

## Consumer expectations (unchanged)
- `CheckInViewModel` / `RecordingDetailViewModel` / `PendingTranscriptionServiceImpl` consume `AsyncStream<TranscriptionSegmentDTO>` and hand the final text to `SummarizationService.summarize(rawTranscription:)`. No consumer references a concrete engine (the only binding is `AppDependencies`).
