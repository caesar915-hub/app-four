<!-- Created: 2026-07-18 15:34 (WEST) · Updated: 2026-07-18 15:34 (WEST) -->
# Data Model: Opt-in iCloud Sync (feature 038)

Grounded in [research.md](research.md) §B/§C and the actual `@Model` source. All schema shapes obey CloudKit rules **for synced models only**: R1 no `.unique`; R2 every non-relationship attribute optional-or-defaulted; R3 all relationships optional; R4 inverse required; R5 no `.deny` delete rule.

## Store partition (one container, two configurations)

| Configuration | `cloudKitDatabase` | Models | CloudKit rules apply? |
|---|---|---|---|
| **Synced** | `.private("iCloud.<container>")` when enabled, else `.none` | `Recording`, `TranscriptionSegment`, `RecordingTag`, `MedicationEvent`, `DayCalendarContext`¹ | **Yes** |
| **Local** | `.none` (always) | `AppSettings`, `ModelMetadata` | No — exempt |

¹ `DayCalendarContext` (spec 029) is **not built yet**; it joins the Synced configuration when 029 lands, authored CloudKit-native from day one. 038 phase-1 syncs the four existing journal models.

**Invariant (build-time hazard)**: no `@Relationship` may cross the Synced↔Local boundary, or SwiftData merges the two stores. Verified safe today (`AppSettings`/`ModelMetadata` have no relationships). Any future relationship from a local model to a synced one is forbidden.

## Schema versions

- **`SquirlSchemaV1`** — baseline from `fix/app-store-readiness` (must merge first). `.unique` on `Recording.id`, `AppSettings.id`, `ModelMetadata.id`, `TranscriptionSegment.id`; bare non-optional scalars on `Recording`/`TranscriptionSegment`.
- **`SquirlSchemaV2`** — this feature. Migration: `MigrationStage.lightweight(V1 → V2)` (no custom stage, no wipe). Changes below.

## Per-model changes in V2

### Recording (synced) — largest change
- **Drop** `@Attribute(.unique)` on `id`; `id: UUID` stays as the **app-level merge key** (random at creation, never regenerated).
- **Add inline defaults** (R2) to every currently-bare non-optional scalar: `createdAt = Date()`, `updatedAt = Date()`, `audioFileName = ""`, `duration = 0`, `fileSize = 0`, `status = .pendingTranscription`, `fullTranscriptText = ""`, `title = ""`, `isFavorite = false`. (Skill guardrail: prefer non-optional-**with-default** over optional where the initializer supplies a value — don't over-optionalize.)
- **Encrypt** (`.allowsCloudEncryption`, R2-defaulted): `fullTranscriptText`, `medicationInfo`, `summary`, and derived-content JSON blobs `noteExtractionJSON`, `summaryBulletsJSON`, `emotionsJSON`, `sideEffectsJSON`, `sleepEventJSON`, `topicTagsJSON`.
- **Relationships** already compliant: `segments: [TranscriptionSegment]?` (cascade, inverse), `correctionTags: [RecordingTag]?` (cascade, inverse), `medicationEvents: [MedicationEvent] = []` (cascade, inverse) — confirm the empty-array default is accepted by CloudKit validation; if not, make optional.
- `cloudSyncStatus: String?` already exists — repurpose or leave; do not use it as the merge key.

### TranscriptionSegment (synced)
- **Drop** `@Attribute(.unique)` on `id`.
- **Add defaults** (R2): `text = ""`, `startTime = 0`, `endTime = 0`, `isFinal = true`, `language = "en"`.
- **Encrypt**: `text` (transcript content).
- `recording: Recording?` — optional ✓; **declare explicit inverse** to `Recording.segments` (R4).

### RecordingTag (synced)
- No `.unique` today ✓. **Add defaults** (R2) to `name`, `category`, `source`, `createdAt`.
- **Encrypt**: `name` (may hold a medication name).
- `recording: Recording?` — optional ✓; explicit inverse to `Recording.correctionTags` (R4).
- **Deterministic merge key**: derive `id` from the normalized (`recording.id` + `category` + `name`) OR match-by-name on merge, so two devices don't duplicate the same tag.

### MedicationEvent (synced) — already CloudKit-shaped
- Every attribute already inline-defaulted; `recording: Recording? = nil` optional ✓. **No R1/R2/R3 change.**
- **Encrypt**: `name`, `dose`.
- Confirm explicit inverse to `Recording.medicationEvents` (R4).
- Merge key: random `id` (single-origin user log) — upsert-by-id safety net.

### DayCalendarContext (synced, spec 029 — not built)
- Build CloudKit-native: no `.unique`; all scalars optional/defaulted; relationships optional + inverse.
- **Deterministic day-derived `id`** (stable UUID from the calendar-day key) so both devices compute the same key for the same date → upsert collapses duplicates.

### AppSettings, ModelMetadata (local-only)
- **No change.** Exempt (Local configuration). Keep `@Attribute(.unique) id`.

## Cross-device de-duplication (merge) rules

CloudKit does **not** merge by the `id` attribute (it uses per-store record names). De-dup is app-code **upsert** on every insert/import path:

```
fetch Recording where id == incoming.id (fetchLimit 1)
  → found: update fields
  → none: insert
```

- **Single-origin rows** (`Recording`, `MedicationEvent`): random UUID; collision impossible; upsert is a safety net.
- **Deterministic singletons** (`DayCalendarContext`, `RecordingTag`): UUID derived from a natural key so both devices agree; upsert collapses independent creations.
- Conflict on a matched row: last-writer-wins (framework default, attribute-level) — acceptable for a single person's own devices.

## New non-persisted types (not `@Model`)

- **`SyncState`** (value type / `@Observable` on the VM): `enabled: Bool`, `accountStatus: CKAccountStatus`, `phase: .idle/.syncing/.stalled(reason)/.unavailable(reason)`, `lastSyncedAt: Date?`. Drives Settings display (FR-009). Persisted bits (`enabled`) live in `AppSettings` (local) or `UserDefaults` — never synced (so a device's own toggle can't be flipped by sync).
- **Sync-enabled flag**: stored in `AppSettings` (local config) or `UserDefaults`; read at launch to choose `cloudKitDatabase` (Pattern A). Explicitly **not** a synced attribute.

## State transitions (sync lifecycle)

```
OFF (default, .none) ──user enables + iCloud available──▶ ENABLING (rebuild container .private, initial export)
   ▲                                                            │
   │ user disables (rebuild .none, local intact)                ▼
OFF ◀───────────────────────────────────────────────  ON (.private, mirroring)
                                                              │
   "remove from iCloud": disable first → purge cloud copy ────┘  (local journals on all devices retained)
```

- **Remove-from-iCloud** (FR-011): disable sync on the device, then delete the private-DB zone/records — **not** a fan-out delete (does not propagate entry-deletions to other devices' local stores).
- **Account signed out / changed**: sync pauses; local store never deleted as a side effect.
