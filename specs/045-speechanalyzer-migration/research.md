# Phase 0 Research — SpeechAnalyzer migration

Sources: `docs/engineering/speechanalyzer-adoption.md` (Apple-doc-verified), `.agents/skills/speech-recognition` (+ `references/speechanalyzer-patterns.md`), the on-device probe result (`Probes/SpeechTranscriberProbe`, verified on iPhone 12 Pro / A14 / iOS 26.6.1), and the current-code map (Explore).

## Decisions

1. **Primary engine = `SpeechTranscriber`; fallback = `DictationTranscriber`.** Ladder resolved at runtime, per recording: if `SpeechTranscriber.isAvailable` AND a supported locale resolves, use it; else if `DictationTranscriber` supports the locale, use it; else unavailable (persist audio, surface state). No third tier (SFSpeechRecognizer removed). Rationale: `SpeechTranscriber` is the long-form/streaming on-device model; `DictationTranscriber` covers 8-core-NE devices/locales it doesn't. Probe confirmed `isAvailable == true` on the A14 target.

2. **Locale resolution via `SpeechTranscriber.supportedLocale(equivalentTo: .current)`, never `supportedLocales.contains(.current)`.** The probe device's `en-PT` locale is NOT in the supported set but resolves to `en-GB`; the naive contains-check would wrongly report "unsupported" (FR-004). All three locale queries (`installedLocales`/`supportedLocales`/`supportedLocale(equivalentTo:)`) are **async** — must be `await`ed.

3. **Presets:** `.progressiveTranscription` for live capture (low-latency volatile→final); `.transcription` for the deferred/pending file path. `.timeIndexedProgressiveTranscription` only if playback highlighting is later needed (out of scope now). Do NOT use a non-existent `offlineTranscription` preset.

4. **Live capture = `AVAudioEngine` dual-sink.** Replace `AVAudioRecorder` with an `AVAudioEngine` input tap that fans out to (a) an `AVAudioFile` (preserving the stored `Recording` audio for playback/export — FR-014) and (b) an `AsyncStream<AnalyzerInput>` after converting each `AVAudioPCMBuffer` to `SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith:)` via `AVAudioConverter`. **Trap:** mismatched formats silently yield zero output — conversion is mandatory. Consume `transcriber.results` in a separate task; finish with `finalizeAndFinish(through:)` (file) / `finalizeAndFinishThroughEndOfInput()` (live) / `cancelAndFinishNow()`. Ending the input stream does NOT finish the session.

5. **Assets via `AssetInventory`.** `assetInstallationRequest(supporting:)` + `downloadAndInstall()`; treat installed-state as environmental (re-check each session; OS may reclaim). The **pending queue is preserved**: recordings captured before assets are installed are saved `.pendingTranscription` and transcribed **file-based** when installed — the same `SpeechTranscriber` supports live and file input. This replaces the WhisperKit "model downloaded?" gate with an `AssetInventory` gate.

6. **Permissions:** `SpeechAnalyzer` needs **microphone only** (unlike `SFSpeechRecognizer`, which also needs speech-recognition authorization). Keep `NSMicrophoneUsageDescription`; **remove `NSSpeechRecognitionUsageDescription`** (build setting) when the SFSpeech path is deleted. No `SFSpeechRecognizer.requestAuthorization` call in the new path (the probe never needed it).

7. **Error taxonomy:** framework errors are typed — `SFSpeechError.Code` (`timeout`, `insufficientResources`, `audioReadFailed`, …). The concurrent-analysis cap throws `insufficientResources`; if transcription can overlap the MLX extraction pass, treat it as **back-pressure (serialize/retry)**, never set `ignoresResourceLimits`. Map asset/network failures onto the existing `ModelDownloadFailure` where a UI cause is needed; keep a catch-all.

8. **Removal set (destructive-last):** `WhisperKitTranscriptionService`, the `argmaxinc/WhisperKit` SPM package (pbxproj + Package.resolved), `AIModelType.whisper` + its `AIModelServiceImpl` download/integrity/space logic + `ModelConstants.whisperDownloadBase`, the `.whisper` background-download in `SquirlApp`, the Whisper download row + acknowledgement in Settings/onboarding, and the dormant `SpeechTranscriptionService` (SFSpeech). `WhisperCLI/` is a **separate SPM package/tool**, not in the app target — leave it out of scope (or delete in a follow-up); it does not affect the app build or SC-006 for the app target.

9. **Testing without the live SDK:** the Simulator returns `SpeechTranscriber.isAvailable == false` and cannot run the model, and Principle-VIII/CLAUDE.md forbid tests hitting the live SDK. So new tests cover **pure logic** — the capability/locale ladder (`SpeechAnalyzerCapability.resolve`), result→`TranscriptionSegmentDTO` mapping, volatile/final handling, error mapping — using injected synthetic results/fakes. The engine actor exposes a seam so mapping is testable without `SpeechAnalyzer`. Real end-to-end transcription is device QA (owner).

## Open questions → verify on device (owner QA)
- First-result latency with `.progressiveTranscription` on the A14 target.
- Background/lock-screen capture behaviour + whether `UIBackgroundModes: audio` is needed for long sessions.
- Exact `SFSpeechError` cases surfaced on asset-download failure (to refine `ModelDownloadFailure` mapping).
- `AVAudioEngine` interruption/route-change parity with the current `AVAudioRecorder` policy (calls, unplug).
