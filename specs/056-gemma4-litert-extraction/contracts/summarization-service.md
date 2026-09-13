# Contract — SummarizationService (reused, unchanged)

The integration boundary. `GemmaJournalService` conforms; downstream consumers are unaware of the backend.

```swift
protocol SummarizationService: Sendable {
    func summarize(rawTranscription: String) async throws -> SummaryResult
}
```

## Invariants the Gemma conformer MUST uphold

1. **Never lose the transcript.** Every non-crash outcome returns a `SummaryResult` whose bullets contain at least the raw transcript, OR throws a typed `SummarizationError` the caller already handles (`ProcessingViewModel` branches on `.insufficientMemory` / `.modelNotInstalled`). No path silently drops input.
2. **Empty/whitespace input** ⇒ return the empty result (title "Empty Note", nil/empty signals) without loading the model (matches `MLXJournalService.emptyResult()`).
3. **Signals are validated** through `ExtractionValidator.validate(_:lexicon:rawTranscript:)`; values outside `Levels.swift` rawValues are clamped to `nil`. The service does not invent its own validation.
4. **Off-main:** generation runs off the main actor (nested actor + detached task).
5. **Idempotent load:** concurrent `summarize` calls share one model load (in-flight `Task` dedup).
6. **Sequential residency:** headroom is checked (`os_proc_available_memory()`) before constructing the engine; per D2 there is no fallback model on gate-fail.
7. **Return type parity:** the returned `SummaryResult` is assembled by `ExtractionValidator.assembleSummaryResult(from:lexicon:rawTranscript:)` — same shape as the MLX path, so no consumer changes.

## Two-pass behaviour (internal, contractually observable via eval)

- **Pass 1** narrative summary → `SummaryResult.bullets`/`noteExtraction.summary` (pass-1 owns `summary`).
- **Pass 2** signals → all structured fields (pass-2 owns signals). Tool Use first, free-form + 3-stage recovery + one correction retry as fallthrough.
- Merge: `merged = pass2 ?? UnifiedExtraction(); merged.summary = pass1 ?? pass2.summary`.

## DEBUG test hooks (parity with MLXJournalService — keeps the fast suite hermetic)

```swift
#if DEBUG
extension GemmaJournalService {
  var isModelLoaded: Bool { get async }
  func markLoadedForTesting() async
  func armIdleTimerForTesting() async
  func startLifecycleObservingForTesting() async
}
#endif
```
Tests inject a `FakeLiteRTGenerator` and a fresh `NotificationCenter()`; they NEVER load a real `.litertlm` or link the live runtime.
