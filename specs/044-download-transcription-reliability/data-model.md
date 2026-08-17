# Phase 1 Data Model: Model Download & Transcription Pipeline Reliability

**Spec**: [`spec.md`](file:///Users/caesargrey/Projects/app-four-llama/specs/044-download-transcription-reliability/spec.md) | **Date**: 2026-08-14

**This feature adds NO new SwiftData `@Model` types and NO schema changes.** The SwiftData schema (`Recording`, `ModelMetadata`, etc.) is untouched; Constitution Principle IX is trivially satisfied. All new state is transient task state, actor-held lifecycle state, or disposable JSON in `Library/Caches`. The entities below are the complete set.

---

## 1. `ResumeState` (persisted, disposable — JSON file in Caches)

Enables byte-range continuation of an interrupted LLM snapshot download (FR-006…008). One record per download, stored as `llm-resume-state.json` under `Library/Caches` via `ResumeStateStore` with atomic (write-temp-then-rename) writes.

| Field | Type | Purpose |
|---|---|---|
| `repoID` | `String` | HF repo (`ModelConstants.llmHubRepoID`); mismatched repo → state ignored |
| `fileURL` | `URL` | Remote file this record resumes |
| `tempFileID` | `String` | Name of the partial file in the download staging directory |
| `byteOffset` | `Int64` | Bytes already on disk; resume sends `Range: bytes=<offset>-` |
| `etag` | `String?` | Validator from the original response (`ETag`, else `Last-Modified`); mismatch → discard + clean download |

**Lifecycle**: created/updated on explicit cancellation and on failure (FR-007); loaded on retry and on app relaunch; deleted on successful completion and on any staleness signal (purged temp file, unreadable JSON, ETag mismatch, HTTP 412/416). Deletion is silent — the user never sees a resume error (FR-008). The OS may purge Caches at any time; absence simply means file-level retry granularity (today's behavior floor).

**Validation rules** (all enforced in `ResumeStateStore.load`, unit-tested): JSON must decode; `byteOffset > 0`; referenced temp file must exist on disk; `repoID` must match the current request. Any failure → return nil and delete the file.

---

## 2. Model Download Task state (transient, per attempt)

Owned by `AIModelServiceImpl` (existing `@MainActor` class) and, if the fallback ships, by `BackgroundLLMDownloadService`'s URLSession delegate. Not persisted beyond `ResumeState`.

| State | Type / location | Notes |
|---|---|---|
| Source repo ID | `String` (`ModelConstants.llmHubRepoID`) | Constant today; carried into `ResumeState` for mismatch detection |
| Destination directory | `URL` (`ModelConstants.llmDownloadBase` + staging subdir) | Staged, then atomically renamed into the final layout; `findLLMModelDirectory` never sees a partial directory (FR-002) |
| Progress fraction | `Double`, throttled to 1% steps | Last-emitted value kept in the progress bridge so the AsyncThrowingStream yields ≤ 1 event per 1% (FR-004) |
| Background session identifier | `String` constant | Stable across launches so `AppDelegate.handleEventsForBackgroundURLSession` reconnects the right session (FR-003) |
| Delegate-callback bookkeeping | guarded by `OSAllocatedUnfairLock` (fallback path only) | Task→record map mutated on the delegate queue; lock never held across `await` |

---

## 3. Transcription Result (existing shape, single persistence)

No type changes. The existing flow is preserved:

- `AsyncStream<TranscriptionSegmentDTO>` from `TranscriptionService.transcribe(audioURL:)` — progress yields plus exactly one final `isFinal` segment carrying the cleaned transcript (cleaning happens in `WhisperKitTranscriptionService.cleanTranscript`, unchanged).
- Persistence: the final text lands on `Recording.fullTranscriptText` with `status = .completed` in **exactly one** `store.save()` per transcription (FR-014). Failure persists `status = .failed` + an error-message string in one save; **partial transcript text is never persisted** (US4 AC3).
- Timeout input: `Recording.duration` + `ProcessInfo.thermalState` → `TranscriptionTimeoutCalculator.budget(...)` (new pure struct; not an entity, no state).

---

## 4. Model Holder State (actor-isolated, in-memory only)

Inside `MLXJournalService.private actor ModelHolder` ([`MLXJournalService.swift:95-133`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/MLXJournalService.swift#L95)):

| State | Type | Change in this feature |
|---|---|---|
| `isLoaded` | `Bool` | Unchanged storage; now read via `var isModelLoaded: Bool { get async }` (semaphore bridge deleted, FR-016) |
| `modelContainer` | `ModelContainer?` | Released by new `evict()` — set to nil, `isLoaded = false`, `MLX.Memory.clearCache()` |
| Idle-eviction timer | cancellable `Task` handle | NEW — owned by the `@MainActor` lifecycle coordinator (not the actor); cancelled + re-armed after every inference; fires `await modelHolder.evict()` at 3 min |
| Lifecycle observers | NotificationCenter tokens for `didReceiveMemoryWarningNotification` + `didEnterBackgroundNotification` | NEW — owned by the coordinator; each triggers `await modelHolder.evict()` (FR-011) |
| Buffer cache cap | `MLX.Memory.cacheLimit = 20 MB` | NEW — set once in `MLXJournalService.init` (FR-009); `MLX.Memory.clearCache()` after every inference (FR-010) |

**Eviction semantics**: any trigger → container released + cache cleared. A new inference arriving while the timer is armed cancels the timer and reuses the loaded container (zero reload latency, US5 AC3). Eviction during in-flight inference is deferred (coordinator skips a busy holder and re-arms) so generation is never torn down mid-token. Next inference after eviction cold-loads through the existing 200 MB `checkMemoryHeadroom()` gate (US5 AC4).

---

## Entity relationship summary

```text
ResumeState (JSON, Caches)  ←―― ResumeStateStore (atomic IO)
      ↑ captured on cancel/fail          ↑ loaded on retry/relaunch
Model Download Task (transient) ――→ staging dir ――atomic rename――→ llmDownloadBase
      ↑ driven by swift-huggingface background session (fallback: BackgroundLLMDownloadService)

Transcription Result (existing DTO stream) ――final segment only――→ Recording (1 save)

Model Holder State (actor) ←― evict() ―― LifecycleCoordinator (@MainActor: timer + 2 observers)
```

None of these relationships cross into SwiftData; nothing here affects CloudKit compatibility (Principle IX) or privacy posture (no transcript content in any new persisted artifact — Principle VI).
