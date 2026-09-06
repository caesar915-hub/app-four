# Phase 1 Data Model — SpeechAnalyzer migration

**No SwiftData schema change.** `Recording`, transcript persistence, and the `SummaryResult` seam are unchanged (Principle IX preserved: no new unique/required attributes). This document lists the value types and state the feature introduces or changes.

## Unchanged (reused as-is)
- `TranscriptionSegmentDTO` (`Services/Protocols.swift:48`) — `id, text, startTime, endTime, isFinal, confidence, isError`. Volatile results are carried as `isFinal == false`; the UI replaces the volatile range until a `isFinal == true` segment commits it. No new field needed.
- `ModelDownloadFailure` (`Services/Protocols.swift:142`) — reused for asset-install failure causes surfaced to UI.
- `SummaryResult` / `SummarizationService` — untouched (String-in seam).

## New value types
- `TranscriptionEngineChoice` (enum, `Sendable`): `.speechTranscriber(Locale)` · `.dictation(Locale)` · `.unavailable`. The resolved ladder outcome for a recording.
- `SpeechAnalyzerCapability` (struct, no stored state): pure resolver.
  - `static func resolve(isAvailable: Bool, resolvedSpeechLocale: Locale?, resolvedDictationLocale: Locale?) -> TranscriptionEngineChoice`
  - The service supplies the async-resolved locales (`supportedLocale(equivalentTo:)` for each module); the struct holds the branch logic so it is unit-testable without the SDK.

## Changed types
- `AIModelType` (`Models/AppEnums.swift:99`): **remove `.whisper`** case; retain the LLM case. All exhaustive switches over `AIModelType` (download, delete, status, UI) updated accordingly.
- `TranscriptionService` (protocol, `Services/Protocols.swift:69`): gains a live-streaming entry point (see `contracts/transcription-service.md`); the file-based `transcribe(audioURL:)` and `cancelTranscription()`/`loadModel()` remain.
- `ModelConstants` (`Utils/Constants.swift`): remove `whisperDownloadBase` and the ~600 MB whisper free-space constant; LLM constants unchanged.

## State transitions (recording → transcript)
1. **Capture (assets installed):** live stream → volatile segments (`isFinal=false`) → final segments (`isFinal=true`) → transcript persisted.
2. **Capture (assets NOT installed):** audio persisted, recording marked `.pendingTranscription`; on `AssetInventory` install, `PendingTranscriptionService.drainIfModelReady()` transcribes **file-based** and updates the transcript.
3. **Unavailable (no engine for device/locale):** audio persisted; recording surfaces "transcription unavailable"; no crash, no data loss (FR-011/edge cases).
