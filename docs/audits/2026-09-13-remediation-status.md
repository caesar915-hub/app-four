<!-- Created: 2026-09-13 10:37 WEST · Updated: 2026-09-13 10:37 WEST -->
# Audit remediation — status (2026-09-13)

Follow-up to the audit (PR #43). All fixes are on branches, **nothing merged** — device QA is yours.

## Fixed & verified — PR #45 `fix/audit-high-medium`
**Debug build + 550 tests pass (6 new); Release simulator build succeeds.**

### 🔴 / data-loss
1. **Recording-cap race** — removed the duplicate service-level 480 s timer; `CheckInViewModel` owns the single cap and saves through the normal path. No more silently-lost 8-minute recording.
2. **Orphaned audio on delete** — `RecordingStore.deleteRecording` now deletes the `.m4a`, not just the row.
3. **Save-before-move** — `AudioFileStorageServiceImpl` copies then removes temp only after a durable save, with rollback on failure.

### 🟡
4. Focus level-5 (`lockedIn`) restored in Insights + day timeline (stop lowercasing; show `displayLabel`).
5. Sleep-hours guard keeps "slept for 8 hours" instead of nulling it.
6. Regenerate now refreshes medication events.
7. WhisperKit background task has an expiration handler.

## Fixed earlier — PR #44 `fix/audit-safe-cleanup`
Dead-code deletion, debug-surface gating (**RC-30**), PHI-log gating, overflow-trap fix, comment fix. Debug+Release green.

## Reported, NOT changed (need your device QA or a decision)
- **Download/transcription:** cellular-off enforcement, in-flight dedup, WhisperKit cross-driver serialization, MLX detached cancellation, pending-drain timeout. Load-bearing; needs on-device verification.
- **ExportService** main-actor encode — never-break export path; Codable isolation is main-actor-sensitive.
- **ViewModel-persistence refactor** (constitution VIII) — its own PR.
- **CloudKit-compat schema** (`@Attribute(.unique)`) — **changing it wipes tester data mid-sprint**; your call.
- **`SpeechTranscriptionService` deletion** — coordinate with PR #42.
- **Dead-NL test removal** — already on `chore/remove-dead-nlp`.
- 43 low findings — in the audit report.

## Merge order suggestion
1. #44 (safe cleanup, RC-30) → device QA → merge.
2. #45 (high+medium) → device QA (record + hit the 8-min cap, delete a check-in, regenerate a summary, log sleep) → merge.
3. #43 (report/docs) → merge anytime.
4. Then land `chore/remove-dead-nlp` and decide the deferred items.

## PRs
- #43 report: https://github.com/caesar915-hub/app-four/pull/43
- #44 safe cleanup: https://github.com/caesar915-hub/app-four/pull/44
- #45 high+medium: https://github.com/caesar915-hub/app-four/pull/45
