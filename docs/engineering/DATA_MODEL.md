<!-- Created: 2026-06-28 00:00 (WEST) · Updated: 2026-07-18 17:53 (WEST) -->
# Data Model

_Last updated: 2026-07-18_

This document describes the SwiftData schema used by Squirl, the relationships between entities, and conventions for storing structured data.

---

## Table of Contents

- [Schema Overview](#schema-overview)
- [Entity Reference](#entity-reference)
- [JSON-Encoded Fields](#json-encoded-fields)
- [Relationships](#relationships)
- [Migration Strategy](#migration-strategy)
- [Adding a New Model](#adding-a-new-model)

---

## Schema Overview

The schema is declared as a `VersionedSchema` in `app-four/App/SquirlSchema.swift` and wired into the container in `app-four/App/AppModelContainer.swift`.

```swift
// SquirlSchema.swift — the V1 baseline (versionIdentifier 1.0.0)
nonisolated enum SquirlSchemaV1: VersionedSchema {
    static var models: [any PersistentModel.Type] {
        [Recording.self, TranscriptionSegment.self, RecordingTag.self,
         MedicationEvent.self, AppSettings.self, ModelMetadata.self]
    }
}
```

### Two-configuration split (spec 038, iCloud Sync — in progress)

The single container is partitioned into **two `ModelConfiguration`s** so that only the journal entities are eligible for CloudKit mirroring:

| Configuration | Store name | Models | CloudKit |
|---------------|-----------|--------|----------|
| Synced | `"Synced"` | `Recording`, `TranscriptionSegment`, `RecordingTag`, `MedicationEvent` | `.private(...)` when sync is on, else `.none` |
| Local | `"Local"` | `AppSettings`, `ModelMetadata` | always `.none` |

- Both stores use `isStoredInMemoryOnly: false`.
- `cloudKitDatabase` on the Synced store resolves to `.private("iCloud.Rythm-App.app-four")` only when `SyncFlags.iCloudSyncEnabled` is true; otherwise `.none` (`AppModelContainer.swift:35-42`). **Sync is OFF by default** — the flag lives in `UserDefaults`, not the SwiftData store, and defaults to `false` (`SyncFlags.swift:12-14`).
- The container is built with `migrationPlan: SquirlMigrationPlan.self` and both configurations (`AppModelContainer.swift:54-59`).
- The store directory is excluded from iCloud **device backup** via `.isExcludedFromBackupKey` (`AppModelContainer.swift:65`) — distinct from CloudKit sync; sensitive fields are additionally E2E-encrypted in CloudKit under Advanced Data Protection (see the `.allowsCloudEncryption` attributes below).

**Status (2026-07-18, branch `feat/038-icloud-sync`, uncommitted):** the persistence scaffolding — versioned schema, two-configuration container, `SyncFlags`, and the `CloudSyncServiceImpl` actor (`app-four/Services/Sync/`) — is in place, and the four synced `@Model`s have been made CloudKit-compatible (no `@Attribute(.unique)`, all non-optional attributes carry inline defaults, all relationships optional). The CloudKit container identifier is referenced only in code (`AppModelContainer.swift:27`, `CloudSyncServiceImpl.swift:18`) — **no `.entitlements` file is tracked and no `CODE_SIGN_ENTITLEMENTS`/`com.apple.developer.icloud-container-identifiers` key is present in the Xcode project yet** (verified 2026-07-18). Enabling sync requires that entitlement plus a user relaunch (Pattern A: `AppModelContainer` rebuilds with `.private(...)` on next launch — SwiftData has no live container hot-swap).

> **Pre-release reset:** moving from the pre-038 single `default.store` to the two named stores (`Synced`/`Local`) abandons the old rows one time — acceptable pre-release (Constitution IX). The wipe fallback in `AppModelContainer` also clears the stale `default.store`.

---

## Entity Reference

### `Recording`

The central journal entry. A `Recording` represents a single check-in, whether captured by voice or typed as text.

**Location:** `app-four/Models/Recording.swift`

> **CloudKit compatibility (spec 038):** `Recording` carries **no `@Attribute(.unique)`** — `id` is just the app-level merge key. Every non-optional attribute has an inline default in the property declaration (CloudKit reads the schema default from the initializer, not the `init` parameter). Sensitive free-text/JSON fields are marked `@Attribute(.allowsCloudEncryption)` so they are end-to-end encrypted in CloudKit under Advanced Data Protection (FR-016); the local SQLite copy stays plaintext, so on-device search/filter is unaffected.

**Key attributes:**

| Attribute | Type | Default | Purpose |
|-----------|------|---------|---------|
| `id` | `UUID` | `UUID()` | Identifier / merge key (no `.unique`) |
| `createdAt` | `Date` | `Date()` | Capture time |
| `updatedAt` | `Date` | `Date()` | Last mutation time |
| `audioFileName` | `String` | `""` | Filename in `Documents/Recordings/` |
| `duration` | `TimeInterval` | `0` | Audio length in seconds |
| `fileSize` | `Int64` | `0` | File size in bytes |
| `status` | `RecordingStatus` | `.placeholder` | `.recorded`, `.transcribing`, `.pendingTranscription`, `.completed`, `.failed`, `.placeholder` |
| `fullTranscriptText` | `String` | `""` | Full transcript · `@Attribute(.allowsCloudEncryption)` |
| `title` | `String` | `"Untitled"` | Display title |
| `isFavorite` | `Bool` | `false` | User favorite flag |
| `cloudSyncStatus` | `String?` | — | Per-record sync status (spec 038) |
| `isMockData` | `Bool` | `false` | Marks debug/preview-seeded rows |

**Summarization attributes:**

| Attribute | Type | Purpose |
|-----------|------|---------|
| `summary` | `String?` | Rendered bullet summary · `@Attribute(.allowsCloudEncryption)` |
| `summaryStatus` | `String?` | `SummaryStatus` raw value |
| `topicTagsJSON` | `String?` | JSON `[String]` → `[TopicCategory]` · `@Attribute(.allowsCloudEncryption)` |
| `summaryGeneratedAt` | `Date?` | When the summary was produced |

**ADHD/journal attributes:**

| Attribute | Type | Purpose |
|-----------|------|---------|
| `mood` | `String?` | Mood level raw value |
| `energyLevel` | `String?` | Energy level raw value |
| `focusLevel` | `String?` | Focus level raw value |
| `sleepHours` | `Double?` | Sleep duration |
| `sleepQuality` | `String?` | Sleep quality raw value |
| `sleepLevelValue` | `String?` | Sleep level enum raw value |
| `medicationInfo` | `String?` | Human-readable medication summary · `@Attribute(.allowsCloudEncryption)` |
| `hasMedication` | `Bool` | Convenience flag (default `false`) |

**JSON-encoded attributes** (all `@Attribute(.allowsCloudEncryption)`):

| Attribute | Stored Type | Decoded Type |
|-----------|-------------|--------------|
| `summaryBulletsJSON` | `String?` | `[String]` |
| `noteExtractionJSON` | `String?` | `NoteExtraction` |
| `sideEffectsJSON` | `String?` | `[String]` |
| `sleepEventJSON` | `String?` | `SleepEvent` |
| `emotionsJSON` | `String?` | `[String]` |
| `topicTagsJSON` | `String?` | `[String]` → `[TopicCategory]` |

**Computed/display helpers:**

- `displayTitle` — returns "Transcribing…", "Ready shortly…", or the real title based on `status`.
- `formattedDuration` — "4:32" style duration string.
- `formattedDate` — relative date string.
- `audioURL` — local file URL for playback.

**Key methods:**

- `applySummary(_:fillOnly:)` — single writer for `SummaryResult` extraction output.
- `setMedicationEvents(from:durationHours:context:)` — reconciles transcript-sourced medication events, preserving manual events.

### `MedicationEvent`

A single medication dose, either logged manually or extracted from a transcript.

**Location:** `app-four/Models/MedicationEvent.swift`

> CloudKit-compatible (spec 038): no `.unique`, inline defaults on every non-optional attribute. `name`/`dose` are `@Attribute(.allowsCloudEncryption)` (may hold a medication name). `MedEventChange` is defined in `app-four/Services/NoteExtraction/NoteExtraction.swift:133`.

| Attribute | Type | Default | Purpose |
|-----------|------|---------|---------|
| `id` | `UUID` | `UUID()` | Identifier |
| `name` | `String` | `""` | Medication name · `@Attribute(.allowsCloudEncryption)` |
| `dose` | `String?` | `nil` | Dose description (e.g., "20mg") · `@Attribute(.allowsCloudEncryption)` |
| `takenAt` | `Date` | `Date()` | Resolved absolute time |
| `taken` | `Bool` | `true` | Whether the dose was taken |
| `quantity` | `Double?` | `nil` | Numeric quantity |
| `durationHours` | `Double` | `10.0` | Effect-window duration |
| `change` | `MedEventChange?` | `nil` | Change type (started, stopped, skipped, etc.) |
| `timeLabel` | `String?` | `nil` | Raw transcript phrase for provenance |
| `source` | `Source` | `.manual` | `.manual` or `.transcript` |
| `createdAt` | `Date` | `Date()` | Row creation time |
| `isMockData` | `Bool` | `false` | Marks debug/preview-seeded rows |
| `recording` | `Recording?` | `nil` | Originating recording, if any |

**Key methods:**

- `effectProgress(at:)` — fraction of effect window elapsed, clamped to `[0, 1]`.
- `isActive(at:)` — whether the dose is still within its active window.
- `resolvedTakenAt(time:timeLabel:recordingDate:)` — resolves fuzzy times to absolute dates.

### `TranscriptionSegment`

A timed segment of a transcript.

**Location:** `app-four/Models/TranscriptionSegment.swift`

> CloudKit-compatible (spec 038): no `.unique`, inline defaults. `text` is `@Attribute(.allowsCloudEncryption)`.

| Attribute | Type | Default |
|-----------|------|---------|
| `id` | `UUID` | `UUID()` |
| `text` | `String` | `""` · `@Attribute(.allowsCloudEncryption)` |
| `startTime` | `TimeInterval` | `0` |
| `endTime` | `TimeInterval` | `0` |
| `isFinal` | `Bool` | `true` |
| `confidence` | `Double?` | `nil` |
| `language` | `String` | `"en"` |
| `recording` | `Recording?` | `nil` |

### `RecordingTag`

A user-applied correction or label used to train the personal lexicon.

**Location:** `app-four/Models/RecordingTag.swift`

> CloudKit-compatible (spec 038): no `.unique`, inline defaults. `name` is `@Attribute(.allowsCloudEncryption)` (may hold a medication name). `category` and `source` are persisted as **raw `String`s** — the `init` takes the `TagCategory` / `TagSource` enums and stores their `.rawValue`.

| Attribute | Type | Default | Purpose |
|-----------|------|---------|---------|
| `id` | `UUID` | `UUID()` | Identifier |
| `name` | `String` | `""` | Tag text · `@Attribute(.allowsCloudEncryption)` |
| `category` | `String` | `""` | `TagCategory` raw value (`mood`, `energy`, `focus`, `medication`, `emotions`) |
| `source` | `String` | `""` | `TagSource` raw value (`nlp`, `user`, `userCorrected`) |
| `confidence` | `Double?` | `nil` | NLP confidence, if any |
| `createdAt` | `Date` | `Date()` | Row creation time |
| `recording` | `Recording?` | `nil` | Owning recording |

### `AppSettings`

Global app settings.

**Location:** `app-four/Models/AppSettings.swift`

> Lives in the **Local** configuration (never synced), so it keeps `@Attribute(.unique)` on `id` — a single-row singleton. `promptPace` and `doseGuardMode` are stored as raw scalars, not enum-typed columns.

| Attribute | Type | Default | Purpose |
|-----------|------|---------|---------|
| `id` | `UUID` | `UUID()` | `@Attribute(.unique)` singleton key |
| `hasCompletedOnboarding` | `Bool` | `false` | Onboarding gate |
| `defaultLanguage` | `String` | `"en"` | Transcription language |
| `downloadOverCellular` | `Bool` | `false` | Cellular download preference |
| `transcriptionCount` | `Int` | `0` | Lifetime transcription count |
| `promptPaceSeconds` | `Int` | `PromptPace.relaxed.rawValue` (10) | Check-in prompt cadence, in seconds |

**030 App Intents fields** (default medication · dose guard · confirmation style — all optional/defaulted, no `.unique`):

| Attribute | Type | Default | Purpose |
|-----------|------|---------|---------|
| `defaultMedicationName` | `String?` | `nil` | Default med for expedited logs |
| `defaultMedicationDose` | `String?` | `nil` | Default dose for expedited logs |
| `doseGuardModeRaw` | `String` | `"off"` | `DoseGuardMode` raw value (`off`, `total`, `window`) |
| `doseGuardWindowHours` | `Int` | `2` | Dose-guard window when mode is `window` |
| `nameMedicationInConfirmations` | `Bool` | `false` | Whether confirmations name the medication |

### `ModelMetadata`

Mirrors the state of downloadable AI models on disk.

**Location:** `app-four/Models/ModelMetadata.swift`

> Lives in the **Local** configuration (never synced), so it keeps `@Attribute(.unique)` on `id`.

| Attribute | Type | Default |
|-----------|------|---------|
| `id` | `UUID` | `UUID()` · `@Attribute(.unique)` |
| `modelName` | `String` | `"base"` |
| `modelType` | `String` | `AIModelType.whisper.rawValue` |
| `modelSize` | `Int64` | `74_000_000` |
| `isDownloaded` | `Bool` | `false` |
| `isCorrupted` | `Bool` | `false` |
| `version` | `String` | `"openai-whisper-base-v1"` |
| `checksum` | `String?` | `nil` |

> **Note:** Filesystem presence is the source of truth for whether the model is installed; `ModelMetadata` mirrors it.

### Non-persisted supporting types

These live in `app-four/Models/` but are **not** `@Model` types, so they add nothing to the SwiftData schema (Constitution IX — keep the persisted surface minimal):

- `CheckInDraft` (`CheckInDraft.swift`) — a plain `struct` holding what the user explicitly picked in the text check-in composer; extraction may only fill what is `nil`.
- `MedicationCatalog` / `MedicationCatalogEntry` (`MedicationCatalog.swift`) — static reference data (name, dose options, onset, effect duration) for the Log-Dose picker.
- `DoseGuardMode` (`DoseGuardMode.swift`) — enum backing `AppSettings.doseGuardModeRaw`.
- `PromptPace` (`PromptPace.swift`) — `Int`-raw enum backing `AppSettings.promptPaceSeconds`.
- Enums in `AppEnums.swift` (`RecordingStatus`, `ModelStatus`, `TopicCategory`, `SummaryStatus`, `AIModelType`, …) — backing raw values for the string columns above.

---

## JSON-Encoded Fields

Several `Recording` properties store structured data as JSON strings because SwiftData does not natively support arrays or nested custom types in this schema version. All of these JSON columns are `@Attribute(.allowsCloudEncryption)`, so they are E2E-encrypted in CloudKit under Advanced Data Protection (spec 038).

**Encoding/decoding pattern:**

```swift
var summaryBullets: [String] {
    guard let json = summaryBulletsJSON,
          let data = json.data(using: .utf8),
          let bullets = try? JSONDecoder().decode([String].self, from: data) else { return [] }
    return bullets
}
```

When adding a new structured property:

1. Add a `*JSON: String?` storage property.
2. Add a typed computed property for reads.
3. Update `applySummary(_:fillOnly:)` or the relevant writer to encode the value.
4. Update this document.

---

## Relationships

```
Recording.segments        1───* TranscriptionSegment  (cascade delete)
Recording.correctionTags  1───* RecordingTag          (cascade delete)
Recording.medicationEvents 1───* MedicationEvent      (cascade delete)
```

All three are declared on `Recording` with `@Relationship(deleteRule: .cascade, inverse:)` and the child's `recording` back-reference (`Recording.swift:58-67`). **CloudKit requires all relationships to be optional** (spec 038), so the to-many arrays are optionals (`[TranscriptionSegment]?`, `[RecordingTag]?`, `[MedicationEvent]?`) and are read via `?? []`.

Manual `MedicationEvent` rows may have a nil `recording` (standalone dose logs). Transcript-sourced events always have a `recording`.

---

## Migration Strategy

**Current state (spec 038):** A `VersionedSchema` baseline and a `SchemaMigrationPlan` are now wired in `app-four/App/SquirlSchema.swift`:

- `SquirlSchemaV1` — version identifier `1.0.0`, the CloudKit-compatible shape (no `.unique` on synced models, all attributes optional-or-defaulted, all relationships optional). It is the **first** version the per-configuration stores ever see; the pre-038 single `default.store` is abandoned once (Constitution IX pre-release reset).
- `SquirlMigrationPlan` — a single-version plan with **empty `stages`** (correct: both stores are created fresh at V1, so there is no older on-disk version to migrate). The next schema change adds `SquirlSchemaV2` + a `MigrationStage`.

A schema-conflict **wipe fallback** is still retained in `AppModelContainer` (`AppModelContainer.swift:79-98`): if container creation fails, the `Synced`/`Local` store files (plus the stale `default.store`) are deleted and recreated. This is acceptable pre-release only and is slated to be replaced by the crash-safe container when `fix/app-store-readiness` merges — see the reconciliation warning in `SquirlSchema.swift:12-14`.

Until real user data ships:

- Do not rename `@Model` classes or attributes without also updating the wipe fallback logic.
- Adding a synced attribute must keep it optional-or-defaulted (CloudKit) — otherwise the four synced models fail CloudKit schema validation the first time a user enables sync.

---

## Adding a New Model

1. Define the `@Model` class in `app-four/Models/`.
2. Add it to `SquirlSchemaV1.models` in `SquirlSchema.swift`, and to the correct configuration list in `AppModelContainer.swift` (`syncedModels` if it should mirror to CloudKit, else `localModels`).
3. If it goes in `syncedModels`, keep it CloudKit-compatible: no `@Attribute(.unique)`, every non-optional attribute needs an inline default, and every relationship must be optional.
4. If it relates to `Recording`, set the inverse relationship and appropriate `deleteRule`.
5. Update `MockDataGenerator` and preview data if needed.
6. Update this document.
7. Plan the migration if the app has shipped to users.
