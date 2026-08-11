<!-- Created: 2026-07-27 15:10 (WEST) · Updated: 2026-07-27 15:10 (WEST) -->
# 09 · Data Model & Persistence

Documents branch `main` @ `43eb6515a63a0eca957a79aad257da380c73edd4`. Sibling documents: [Settings & Data Management](08-settings-and-data.md) · [Architecture & Services](10-architecture-and-services.md) · [Non-Functional Requirements](11-nonfunctional.md).

## Purpose

Define the SwiftData persistence layer: the versioned schema and its six entities with full attribute tables, relationships and cascade rules, the enums stored as raw values, the migration plan, backup exclusion, the quarantine/self-heal recovery ladder with its in-memory (`isEphemeral`) fallback, and DEBUG mock seeding.

## Scope

- `app-four/App/SquirlSchema.swift`, `app-four/App/AppModelContainer.swift`
- `app-four/Models/`: `Recording.swift`, `TranscriptionSegment.swift`, `RecordingTag.swift`, `MedicationEvent.swift`, `ModelMetadata.swift`, `AppSettings.swift`, `AppEnums.swift`, `PromptPace.swift`, `DoseGuardMode.swift`, `CheckInDraft.swift`
- Storage layout and migration utilities: `app-four/Utils/AppPaths.swift`, `app-four/Utils/StorageMigration.swift`, `app-four/Utils/MockDataGenerator.swift`

Non-persisted types (`CheckInDraft`, signal level enums) are listed for completeness because they shape what gets persisted.

## Schema & container

- `SquirlSchemaV1: VersionedSchema`, `versionIdentifier = Schema.Version(1, 0, 0)`. Entities: `Recording`, `TranscriptionSegment`, `ModelMetadata`, `AppSettings`, `RecordingTag`, `MedicationEvent`. (`SquirlSchema.swift:10-22`)
- `SquirlMigrationPlan: SchemaMigrationPlan` — `schemas: [SquirlSchemaV1]`, `stages: []`. No migrations exist yet; the plan is forward-looking so future model changes migrate deterministically instead of forcing a destructive wipe. (`SquirlSchema.swift:25-32`)
- `AppModelContainer` (`@MainActor enum`) owns the shared `ModelContainer` and `isEphemeral` (`AppModelContainer.swift:6-13`).

## Entities

### `Recording` — `app-four/Models/Recording.swift:4`

The central journal entry (voice or text check-in).

| Attribute | Type | Default | Optional | Notes |
|---|---|---|---|---|
| `id` | `UUID` | — | no | `@Attribute(.unique)` (`:6`) |
| `createdAt` | `Date` | — | no | (`:7`) |
| `updatedAt` | `Date` | — | no | (`:8`) |
| `audioFileName` | `String` | — | no | filename only, never an absolute path; text check-ins use `"text-<UUID>"` with no real file (`:9`) |
| `duration` | `TimeInterval` | — | no | 0 for text check-ins (`:10`) |
| `fileSize` | `Int64` | — | no | (`:11`) |
| `status` | `RecordingStatus` | — | no | enum stored by SwiftData (`:12`) |
| `fullTranscriptText` | `String` | — | no | whole-transcript text; doubles as the note body for text check-ins (`:13`) |
| `title` | `String` | `"Untitled"` | no | (`:14`, `:70`) |
| `isFavorite` | `Bool` | — | no | (`:15`) |
| `cloudSyncStatus` | `String?` | nil | yes | present but **no sync code reads it** on main (`:16`) |
| `summary` | `String?` | nil | yes | bullets joined as `"- \(bullet)"` lines (`:18`) |
| `summaryStatus` | `String?` | nil | yes | raw value of `SummaryStatus` (`:19`) |
| `topicTagsJSON` | `String?` | nil | yes | JSON `[String]` of `TopicCategory` raw values (`:20`) |
| `summaryGeneratedAt` | `Date?` | nil | yes | (`:21`) |
| `hasMedication` | `Bool` | `false` | no | ADHD-journal block start (`:24`) |
| `medicationInfo` | `String?` | nil | yes | (`:25`) |
| `energyLevel` | `String?` | nil | yes | raw level name (`:26`) |
| `focusLevel` | `String?` | nil | yes | (`:27`) |
| `mood` | `String?` | nil | yes | (`:28`) |
| `sleepHours` | `Double?` | nil | yes | (`:29`) |
| `sleepQuality` | `String?` | nil | yes | (`:30`) |
| `summaryBulletsJSON` | `String?` | nil | yes | JSON `[String]` (`:31`) |
| `noteExtractionJSON` | `String?` | nil | yes | serialized `NoteExtraction`, mood/energy/focus/emotions/sideEffects/sleepHours stripped (scalar columns are source of truth) (`:32`) |
| `sideEffectsJSON` | `String?` | nil | yes | (`:33`) |
| `sleepEventJSON` | `String?` | nil | yes | (`:34`) |
| `emotionsJSON` | `String?` | nil | yes | (`:35`) |
| `sleepLevelValue` | `String?` | nil | yes | raw of `SleepLevel` (`:36`) |
| `isMockData` | `Bool` | `false` | no | mock/real partition flag (`:38`) |

**Relationships (all `.cascade` delete):**

| Relationship | Target | Inverse | Notes |
|---|---|---|---|
| `segments` | `[TranscriptionSegment]?` | `\TranscriptionSegment.recording` | (`:52-53`) |
| `correctionTags` | `[RecordingTag]?` | `\RecordingTag.recording` | (`:55-56`) |
| `medicationEvents` | `[MedicationEvent]` (default `[]`) | `\MedicationEvent.recording` | (`:58-59`) |

**Key derived behavior** (all fail-soft: malformed/missing JSON → empty/nil):
- `displayTitle` (`:44-50`): `.transcribing` → `"Transcribing…"`; `.pendingTranscription` → `"Ready shortly…"` (calm, "never error language"); otherwise `title`.
- `formattedDuration` `"M:SS"` (`:122-126`); `formattedDate` via `RelativeDateTimeFormatter` `.full` style (`:129-133`); `audioURL` = `AppPaths.recordings/appendingPathComponent(audioFileName)` (`:136-138`).
- JSON decoders: `summaryBullets`, `decodedSleepEvent` (`@MainActor`), `decodedSideEffects`, `decodedSleepLevel`, `decodedEmotions`, `decodedNoteExtraction` (`@MainActor`), `decodedActivities`, `topicCategories` (`:145-193`).
- `applySummary(_:fillOnly:)` (`@MainActor`, `:202-284`) — single source of truth for writing NLP extraction: `fillOnly == true` (text check-in path) fills only nil scalars, never overwriting user-set values; `fillOnly == false` composes the title as `"Mood · Energy · Focus"` (falling back to `result.generatedTitle` when all three are nil) then overwrites all scalars. Both modes write the JSON blobs, `summary`, `summaryStatus = .completed`, `summaryGeneratedAt = .now`, `updatedAt = .now`.
- `setMedicationEvents(from:durationHours:context:)` (`@MainActor`, `:301-344`) — replaces transcript-sourced `MedicationEvent` rows; manual events (`source == .manual`) are never touched and win same-name matches (case-insensitive); per-med `durationHours = med.durationHours ?? callSiteDefault ?? 10.0`; sets `hasMedication` from inputs, not the relationship array (SwiftData keeps just-deleted rows until next save).

### `TranscriptionSegment` — `app-four/Models/TranscriptionSegment.swift:4`

| Attribute | Type | Default | Optional | Notes |
|---|---|---|---|---|
| `id` | `UUID` | — | no | `@Attribute(.unique)` (`:6`) |
| `text` | `String` | — | no | (`:7`) |
| `startTime` | `TimeInterval` | — | no | (`:8`) |
| `endTime` | `TimeInterval` | — | no | (`:9`) |
| `isFinal` | `Bool` | `true` | no | (`:10`) |
| `confidence` | `Double?` | nil | yes | (`:11`) |
| `language` | `String` | `"en"` | no | (`:12`) |
| `recording` | `Recording?` | nil | yes | inverse side of the cascade from `Recording.segments` (`:14`) |

**Note:** on main, the active WhisperKit path writes whole-transcript text to `Recording.fullTranscriptText`; no code in the capture area persists `TranscriptionSegment` rows (mock seeding creates one per recording).

### `RecordingTag` — `app-four/Models/RecordingTag.swift:18`

| Attribute | Type | Default | Optional | Notes |
|---|---|---|---|---|
| `id` | `UUID` | — | no | **not** marked unique (`:19`) |
| `name` | `String` | — | no | (`:20`) |
| `category` | `String` | — | no | raw of `TagCategory` (`:21`) |
| `source` | `String` | — | no | raw of `TagSource` (`:22`) |
| `confidence` | `Double?` | nil | yes | (`:23`) |
| `createdAt` | `Date` | — | no | (`:24`) |
| `recording` | `Recording?` | nil | yes | (`:26`) |

Enums (`RecordingTag.swift:4-16`): `TagSource { nlp, user, userCorrected }`; `TagCategory { mood, energy, focus, medication, emotions }`.

### `MedicationEvent` — `app-four/Models/MedicationEvent.swift:9`

"Single persisted medication record — whether typed by the user or extracted from a transcript."

| Attribute | Type | Default | Optional | Notes |
|---|---|---|---|---|
| `id` | `UUID` | `UUID()` | no | (`:11`) |
| `name` | `String` | `""` | no | (`:12`) |
| `dose` | `String?` | nil | yes | (`:13`) |
| `takenAt` | `Date` | `Date()` | no | "Resolved absolute time. Set once at save time so there is no re-parsing on every read" (`:14`) |
| `taken` | `Bool` | `true` | no | (`:15`) |
| `quantity` | `Double?` | nil | yes | nil = full dose; 0.5 = half pill (`:16`) |
| `durationHours` | `Double` | `10.0` | no | per-medication effect window, "stored so the bar doesn't hard-code it" (`:17`) |
| `change` | `MedEventChange?` | nil | yes | (`:18`) |
| `timeLabel` | `String?` | nil | yes | raw transcript phrase kept for provenance (`:19`) |
| `source` | `Source` | `.manual` | no | nested enum (`:20`) |
| `createdAt` | `Date` | `Date()` | no | (`:21`) |
| `isMockData` | `Bool` | `false` | no | (`:25`) |
| `recording` | `Recording?` | nil | yes | nil for standalone manual logs; set for transcript-extracted events and manual doses logged inside a check-in (`:29`) |

Nested `enum Source: String, Codable, Sendable { manual, transcript }` (`:33-36`).

Derived: `effectProgress(at:)` = `min(1, max(0, elapsed / (durationHours*3600)))`, returns 1 when duration ≤ 0 (`:68-72`); `isActive(at:)` = `taken && effectProgress < 1` (`:75-77`). `resolvedTakenAt(time:timeLabel:recordingDate:)` (static, `:83-114`): parses explicit `HH:mm` (if the parsed time is after the recording date, assumes previous day); else fuzzy label mapping — morning/am/breakfast → 8:00, afternoon/lunch/noon → 13:00, evening/dinner/pm → 19:00, night/bedtime/sleep → 22:00; else recording creation time.

### `ModelMetadata` — `app-four/Models/ModelMetadata.swift:4`

| Attribute | Type | Default | Optional |
|---|---|---|---|
| `id` | `UUID` (unique) | — | no |
| `modelName` | `String` | `"base"` | no |
| `modelType` | `String` | `AIModelType.whisper.rawValue` | no |
| `modelSize` | `Int64` | `74_000_000` (~74 MB) | no |
| `isDownloaded` | `Bool` | `false` | no |
| `isCorrupted` | `Bool` | `false` | no |
| `version` | `String` | `"openai-whisper-base-v1"` | no |
| `checksum` | `String?` | nil | yes |

(`:6-13`). **Known drift:** the defaults describe "base"/74 MB while the runtime model is `openai_whisper-small` — the entity's defaults predate the model switch. Install truth is the filesystem, not `isDownloaded` (see [Settings](08-settings-and-data.md), FR-SET-04).

### `AppSettings` — `app-four/Models/AppSettings.swift:4`

Singleton-style row (the view model fetches the first or inserts a new one).

| Attribute | Type | Default | Optional | Notes |
|---|---|---|---|---|
| `id` | `UUID` | — | no | `@Attribute(.unique)` (`:6`) |
| `hasCompletedOnboarding` | `Bool` | `false` | no | (`:7`) |
| `defaultLanguage` | `String` | `"en"` | no | (`:8`) |
| `downloadOverCellular` | `Bool` | `false` | no | (`:9`) |
| `transcriptionCount` | `Int` | `0` | no | (`:10`) |
| `promptPaceSeconds` | `Int` | `PromptPace.relaxed.rawValue` (= 10) | no | (`:11`) |
| `defaultMedicationName` | `String?` | nil | yes | App Intents block (`:13`) |
| `defaultMedicationDose` | `String?` | nil | yes | (`:14`) |
| `doseGuardModeRaw` | `String` | `"off"` | no | (`:15`) |
| `doseGuardWindowHours` | `Int` | `2` | no | (`:16`) |
| `nameMedicationInConfirmations` | `Bool` | `false` | no | (`:19`) |

App Intents block comment: "All defaulted/optional, no `.unique` (Constitution IX, CloudKit-compatible)."

## Enums used as stored values

| Enum | Cases | Stored as | Source |
|---|---|---|---|
| `RecordingStatus` | `recorded`, `transcribing`, `pendingTranscription`, `completed`, `failed`, `placeholder` | SwiftData enum attribute on `Recording.status` | `AppEnums.swift:5-15` |
| `SummaryStatus` | `notGenerated`, `generating`, `completed`, `failed` | raw `String` in `Recording.summaryStatus` | `AppEnums.swift:92-97` |
| `TopicCategory` | `medications`, `symptoms`, `appointments`, `procedures`, `general` | raw `String` inside `topicTagsJSON` | `AppEnums.swift:62-90` |
| `TagSource` / `TagCategory` | see `RecordingTag` above | raw `String` columns | `RecordingTag.swift:4-16` |
| `MedicationEvent.Source` | `manual`, `transcript` | SwiftData enum attribute | `MedicationEvent.swift:33-36` |
| `PromptPace` | `relaxed = 10`, `brisk = 6` | raw `Int` in `AppSettings.promptPaceSeconds` | `PromptPace.swift:3-14` |
| `DoseGuardMode` | `off`, `total`, `window` | raw `String` in `AppSettings.doseGuardModeRaw`; `init(raw:)` degrades unknown values to `.off` | `DoseGuardMode.swift:6-14` |
| Signal levels (`MoodLevel`, `EnergyLevel`, `FocusLevel`, `SleepLevel`) | five cases each, `numericValue` 1–5 | raw name `String` columns on `Recording` | `Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift:8-90` |
| `AIModelType` | `whisper` (only case) | raw `String` in `ModelMetadata.modelType` | `AppEnums.swift:99-101` |

`RecordingStatus.pendingTranscription` exists deliberately: captured before the transcription model was ready — orphan recovery must not sweep it to `.failed`, and it is distinct from `.failed` since a late model is not a failure (`AppEnums.swift:8-10`).

## Persistence-behavior requirements (FR-DAT)

### Container creation & backup exclusion

- FR-DAT-01 — The primary container is disk-backed (`isStoredInMemoryOnly: false`) under Application Support; the store directory is pre-created before opening to avoid first-launch CoreData diagnostic noise. (`AppModelContainer.swift:16-19`)
- FR-DAT-02 — Before opening, `recoverInterruptedQuarantine(storeURL:)` self-heals a crash/jetsam that interrupted a quarantine cycle. (`AppModelContainer.swift:24`)
- FR-DAT-03 — After a successful open, `NSURL.isExcludedFromBackupKey = true` is set on the store directory: transcript and medication data is sensitive health information and is excluded from iCloud backup. Separately, `AppPaths.privateRoot` (`Application Support/SquirlData/`) is created on first access and flagged `isExcludedFromBackup`; recordings, exports, and diagnostics live there — never in `Documents` — so they are invisible to the Files app and Finder/iTunes file sharing. (`AppModelContainer.swift:28-30`; `AppPaths.swift:3-20`)

### Failure ladder (release builds)

- FR-DAT-04 — On primary-open failure, release builds distinguish "locked/transiently unreadable" (data protection during a pre-unlock background launch) from genuinely unopenable via `isStoreContentReadable` (open-success is the whole test; a missing file counts as readable). A locked store is left untouched and degrades to in-memory. (`AppModelContainer.swift:56-63`, `:140-145`)
- FR-DAT-05 — If content is readable but open failed: `quarantine(storeURL:)` moves the store trio (`default.store`, `-wal`, `-shm`) into `Quarantine/<ISO8601 stamp (":"→"-")>/` — **rename, never delete** — with a `pending` marker written FIRST (crash-atomic ordering), then retries a fresh open. On retry success the marker is cleared (snapshot kept for forensics); on retry failure `undoQuarantine` restores the original files. (`AppModelContainer.swift:157-227`)
- FR-DAT-06 — Quarantine protocol ordering: the pending marker is committed before any file move; sidecars (`-wal`/`-shm`) move before the database so a snapshot containing `default.store` is provably complete; undo logic decides per-side which copy is real and renames dead retry files aside under `dead-<stamp>/` (never deletes live files unless a same-named aside already exists — then deletes to prevent a foreign `-wal` replaying into the restored store); `recoverInterruptedQuarantine` reads the marker on next launch and hands the marked snapshot to `undoQuarantine`. (`AppModelContainer.swift:105-249`)
- FR-DAT-07 — Last resort: an in-memory `ModelConfiguration` with `isEphemeral = true`; `try!` is justified as impossible to fail on a valid schema. "Launch never crashes. On-disk data is untouched or quarantined — never deleted in release." (`AppModelContainer.swift:80-89`)

### DEBUG-only behaviors

- FR-DAT-08 — DEBUG only: on primary-open failure the store file trio is wiped and the open retried once (dev convenience for schema churn). (`AppModelContainer.swift:50-55`)
- FR-DAT-09 — DEBUG only: if the store is empty (`Recording` fetch count == 0), `MockDataGenerator.generate(context:)` seeds mock data — never in release. (`AppModelContainer.swift:33-40`)
- FR-DAT-10 — `previewContainer` is an in-memory container pre-populated with mock data for SwiftUI previews; `fatalError` on failure. (`AppModelContainer.swift:92-103`)

### Mock seeding contents

- FR-DAT-11 — `MockDataGenerator` (`@MainActor`) seeds 10 days × 2–4 recordings/day (8 AM–10 PM spread) with random mood/energy/focus; the morning entry is always medicated (~70 % otherwise); med names Concerta/Elvanse/Ritalin/Vyvanse, doses 18/36/54/30/50/70 mg; durations 30–300 s; sleep hours 5–9 on the morning entry; 0–3 emotions from a 12-word pool; ~⅓ of entries get 1–2 side effects (Headache/Nausea/Dry mouth/Jitters/Appetite loss); `isMockData = true` on recordings AND medication events; one `TranscriptionSegment` per recording; summary bullets + topic tags + `summaryStatus = completed`. (`app-four/Utils/MockDataGenerator.swift`)

### Store partitioning & lifecycle

- FR-DAT-12 — `RecordingStore.loadRecordings()` fetches with predicate `$0.isMockData == mockMode` where `mockMode = UserDefaults.standard.bool(forKey: "debugMockMode")`, sorted `createdAt` descending. Mock and real data are strictly partitioned by this flag. In release the `debugMockMode` key is unconditionally removed at launch so a container that ever ran a Debug build doesn't hide real recordings. (`RecordingStore.swift:38-50`; `SquirlApp.swift:23-30`)
- FR-DAT-13 — Orphan recovery at store init: any recording stuck in `.transcribing` at launch is set to `.failed`; if its transcript is empty it is set to `"Transcription was interrupted. Tap to retry in the recording detail view."` `.pendingTranscription` recordings are explicitly **not** touched — they drain via `PendingTranscriptionService` once the model lands. (`RecordingStore.swift:25-36`)
- FR-DAT-14 — `RecordingStore.save()` posts `Notification.Name.medicationEventsDidChange` so the shared medication bar refreshes across screens. Store-level `deleteRecording` removes only the SwiftData row; the audio FILE is removed solely by `AudioFileStorageService.deleteRecording`. (`RecordingStore.swift:58-70`; `AudioFileStorageServiceImpl.swift:46-58`)
- FR-DAT-15 — Text check-ins are persisted as `Recording` rows with `audioFileName = "text-<UUID>"` (no real audio file), `duration = 0`, `status = .completed`, user-picked mood/energy/focus/sleepQuality written as authoritative scalars, and one `MedicationEvent(source: .manual)` per draft med. The throwing variant `persistCheckInNote` exists so the capture flow can surface a retry instead of silently dropping the draft. (`RecordingStore.swift:94-155`)

### Pre-1.0 storage migration

- FR-DAT-16 — `StorageMigration.run()` (app init, before any store/service reads disk) performs a one-time, idempotent, file-by-file relocation of pre-1.0 data from `Documents/{Recordings,Exports,Diagnostics}` into `AppPaths.privateRoot`. Because `Recording` stores only the filename, no DB rows change. Collision rules: dir-vs-dir → recurse; file-vs-file → newer mtime wins; dir-vs-file mixed → legacy item moved aside as `<name>.legacy`; a legacy directory is removed only when empty — "a failed move never deletes an un-migrated file." (`StorageMigration.swift:34-72`; `SquirlApp.swift:14`)

## Non-persisted model types (context)

- `CheckInDraft` (`CheckInDraft.swift:5-33`) — text-composer struct: `mood/energy/focus` (level enums, optional), `sleepQuality: String?`, `meds: [DraftMedication]`, `note: String = ""`. "These values are authoritative — extraction may only fill what is nil here." `DraftMedication`: `id = UUID()` (identity only, excluded from `==`), `name`, `dose: String?`, `takenAt: Date = .now`, `durationHours: Double = 10`. `trimmedNote` trims whitespace/newlines; `isEmpty` true when all signals nil, no meds, note empty.
- `DoseGuardMode.blocksLog(previousDose:windowHours:now:)` (`DoseGuardMode.swift:21-31`): `.off` → false; `.total` → `previousDose.isActive(at: now)` (honors per-event edited duration); `.window` → `now - takenAt < windowHours * 3600`. Boundary is CLOSED: at exactly window-end/effect-end the guard opens. Governs expedited (sticker/Siri/Shortcuts) logs only — the in-app Log Dose sheet never consults it.
- Signal level enums live in the `SquirlSignals` package (pure Foundation value types) and are re-exported through `SquirlDesignSystem` and `SignalsReexport.swift` (`SquirlSignals/Levels.swift`; `SignalsReexport.swift:4-5`).

## Validation rules & constants

| Item | Value | Source |
|---|---|---|
| Schema version | `Schema.Version(1, 0, 0)`, empty migration stages | `SquirlSchema.swift:10-32` |
| Store file trio | `default.store`, `default.store-wal`, `default.store-shm` | `AppModelContainer.swift:157-176` |
| Quarantine location | `Quarantine/<ISO8601 stamp>/` + `pending` marker | `AppModelContainer.swift:157-176` |
| Private root | `Application Support/SquirlData/` (+ `Recordings/`, `Exports/`, `Diagnostics/`) | `AppPaths.swift:11-20` |
| Backup exclusion | store directory + entire `SquirlData` subtree | `AppModelContainer.swift:28-30`; `AppPaths.swift:11-16` |
| Default medication effect window | 10.0 h (`MedicationEvent.durationHours`, `DraftMedication.durationHours`) | `MedicationEvent.swift:17`; `CheckInDraft.swift:18` |
| Fuzzy time mapping | 8:00 / 13:00 / 19:00 / 22:00 | `MedicationEvent.swift:116-123` |
| Mock-mode key | `"debugMockMode"` (DEBUG default true; cleared in release) | `SquirlApp.swift:20-29` |

## Edge cases

- **Pre-unlock background launch** — store locked by data protection → no quarantine, in-memory fallback; the next normal launch opens the real store (FR-DAT-04/07).
- **Crash mid-quarantine** — the pending marker makes the interrupted cycle recoverable on next launch (FR-DAT-06).
- **Deleted-mid-transcription recordings** — consumers verify the recording still exists before mutating it (never touch a freed `@Model`).
- **Same-name medication matches** — manual events beat transcript-extracted ones case-insensitively and are never deleted by re-extraction.
- **Zero/negative `durationHours`** — `effectProgress` returns 1 → dose immediately inactive; no clamping in the editor.
- **`RecordingTag.id` not unique** — tags are value rows; identity collisions are not prevented at the schema level.
- **Malformed JSON blobs** — every decoder fails soft to empty/nil; the scalar columns remain authoritative.

## Acceptance criteria

- The schema declares exactly the six entities above at version 1.0.0 with an empty migration plan.
- Deleting a `Recording` cascades to its segments, tags, and linked medication events; standalone medication events survive.
- A simulated unreadable-but-present store is quarantined (renamed, never deleted) and the app relaunches on a fresh store; a simulated lock degrades to ephemeral mode with on-disk data untouched.
- `isEphemeral == true` sessions surface the warning documented in [Settings](08-settings-and-data.md) FR-SET-19, and writes do not persist across relaunch.
- No app data directory under Application Support is included in an iCloud backup.
- In release builds, no mock data is ever seeded and the `debugMockMode` key is absent after first launch.

## Source references

| Area | Files (branch `main`) |
|---|---|
| Schema & migration plan | `app-four/App/SquirlSchema.swift:10-32` |
| Container, quarantine, ephemeral fallback | `app-four/App/AppModelContainer.swift:6-249` |
| Entities | `app-four/Models/{Recording,TranscriptionSegment,RecordingTag,MedicationEvent,ModelMetadata,AppSettings}.swift` |
| Enums | `app-four/Models/AppEnums.swift`, `app-four/Models/PromptPace.swift`, `app-four/Models/DoseGuardMode.swift`, `Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift` |
| Store | `app-four/Store/RecordingStore.swift:4-155` |
| Storage layout & migration | `app-four/Utils/AppPaths.swift`, `app-four/Utils/StorageMigration.swift:34-72` |
| Mock seeding | `app-four/Utils/MockDataGenerator.swift` |
