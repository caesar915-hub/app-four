# Data Model — Spec 026

## No schema change

This feature introduces **no new `@Model`, no new attribute, no new relationship, and no migration**. Principle IX (pre-release, CloudKit-compatible) is untouched.

## Existing types FR-007 reads (no edit)

| Type / field | Definition | Role in 026 |
|---|---|---|
| `Recording.summaryStatus` | `String?` holding a `SummaryStatus` raw value | FR-007 reads it to surface a failed summary; already **written** by `ProcessingViewModel.run()` (ProcessingViewModel.swift:65) and `RecordingDetailViewModel.performSummarization()` (RecordingDetailViewModel.swift:136). |
| `SummaryStatus` | `enum SummaryStatus: String { notGenerated, generating, completed, failed }` (AppEnums.swift:92-97) | `.failed` already exists. FR-007 matches `summaryStatus == SummaryStatus.failed.rawValue`. |
| `RecordingStatus` | `enum RecordingStatus: String { recorded, transcribing, pendingTranscription, completed, failed, placeholder }` (AppEnums.swift:5-15) | `.failed` already exists and already drives the **transcription**-failed branch (RecordingDetailView.swift:159-164). FR-007 is the distinct **summary**-failed concern — they stay separate. |
| `Recording.audioFileName` | `String` | FR-006 keys the `FetchDescriptor<Recording>` predicate on it. |

## Lookup change (FR-006) — behavior, not schema

`ProcessingViewModel.run()` changes from an in-memory `store.recordings.first { $0.audioFileName == … }` to a fresh `store.context.fetch(FetchDescriptor<Recording>(predicate: #Predicate { $0.audioFileName == audioFileName }))`. Same `ModelContext` the store already owns (RecordingStore.swift:9); same persisted data; only the access path changes.

## Invariants preserved

- `summaryStatus` remains the documented single source of truth the summary UI observes (ProcessingViewModel header comment, lines 4-6) — FR-007 finally makes a view honor that contract.
- Transcription status (`recording.status`) and summary status (`recording.summaryStatus`) remain independent; FR-006a explicitly does **not** write `recording.status` on the not-found path.
