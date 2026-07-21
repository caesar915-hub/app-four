<!-- Created: 2026-07-18 15:34 (WEST) · Updated: 2026-07-18 15:34 (WEST) -->
# Tasks: Opt-in iCloud Sync

**Input**: Design documents from `specs/038-icloud-sync/` — [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/cloud-sync-service.md](contracts/cloud-sync-service.md), [quickstart.md](quickstart.md)

**Tests**: Test-first is MANDATORY for logic (Constitution X, Swift Testing `@Test`/`#expect`): RED → GREEN → refactor. SwiftUI views EXEMPT (build + device run).

**Baseline note (owner directive)**: implementing on a fresh `feat/038-icloud-sync` off `main`, **ignoring unmerged branches**. `fix/app-store-readiness` is NOT assumed — 038 **bootstraps the VersionedSchema itself** (`SquirlSchemaV1` from the current shape + `SquirlSchemaV2`). ⚠️ When readiness merges later, `App/SquirlSchema.swift` + `App/AppModelContainer.swift` will need manual reconciliation (both introduce a versioned schema / crash-safe container). Keep 038's schema file at `App/SquirlSchema.swift` to match readiness's location and minimize conflict surface.

**Phase-1 scope**: syncs the **4 existing journal models** only (`Recording`, `TranscriptionSegment`, `RecordingTag`, `MedicationEvent`). `DayCalendarContext` (spec 029) is unbuilt and joins later.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: parallelizable (different files, no incomplete deps)
- **[Story]**: US1–US4; Setup/Foundational/Polish carry no story label

---

## Phase 1: Setup (Shared Infrastructure)

- [ ] T001 Create branch `feat/038-icloud-sync` off `main`; confirm working tree clean.
- [ ] T002 Create `app-four/app-four.entitlements` with `com.apple.developer.icloud-services = [CloudKit]`, `com.apple.developer.icloud-container-identifiers = [iCloud.Rythm-App.app-four]`, and `aps-environment` (added by CloudKit). Wire the file into the target's Code Signing Entitlements build setting. (research §D3)
- [ ] T003 [P] Add `remote-notification` to `UIBackgroundModes` in `app-four/Info.plist`; confirm `ITSAppUsesNonExemptEncryption` stays `false` (research §D6).
- [ ] T004 [P] Owner action (documented in [quickstart.md](quickstart.md)): register the CloudKit container `iCloud.Rythm-App.app-four` on the developer portal for BOTH bundle ids (main + Stable TestFlight); do not deploy schema to Production yet (T045).

**Checkpoint**: target builds with the new entitlements; no functional change yet.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: CloudKit-compatible schema + versioned migration + two-config container + service seam. Blocks ALL user stories.

### Schema bootstrap + CloudKit-compat migration (test-first)

- [ ] T005 Write RED test `app-fourTests/SchemaMigrationV1toV2Tests.swift`: seed a store at `SquirlSchemaV1` shape (with `.unique` ids + bare non-optional scalars) with sample rows, migrate V1→V2, assert (a) all rows preserved, (b) `.unique` dropped on `Recording`/`TranscriptionSegment`, (c) no wipe. Confirm it FAILS (no V2 yet). (research §B1)
- [ ] T006 Create `app-four/App/SquirlSchema.swift`: `SquirlSchemaV1` (VersionedSchema capturing the CURRENT shape of all 6 models incl. existing `.unique`) and `SquirlMigrationPlan` skeleton. (data-model.md §Schema versions)
- [ ] T007 [P] Modify `app-four/Models/Recording.swift`: drop `@Attribute(.unique)` on `id`; add inline defaults to all bare non-optional scalars (`createdAt`, `updatedAt`, `audioFileName`, `duration`, `fileSize`, `status`, `fullTranscriptText`, `title`, `isFavorite`); keep relationships optional/defaulted with explicit inverses. (data-model.md §Recording)
- [ ] T008 [P] Modify `app-four/Models/TranscriptionSegment.swift`: drop `@Attribute(.unique)` on `id`; add defaults (`text`, `startTime`, `endTime`, `isFinal`, `language`); declare explicit inverse to `Recording.segments`. (data-model.md §TranscriptionSegment)
- [ ] T009 [P] Modify `app-four/Models/RecordingTag.swift`: add defaults (`name`, `category`, `source`, `createdAt`); explicit inverse to `Recording.correctionTags`; deterministic merge key (id derived from `recording.id`+`category`+`name`). (data-model.md §RecordingTag)
- [ ] T010 [P] Modify `app-four/Models/MedicationEvent.swift`: confirm explicit inverse to `Recording.medicationEvents` (already CloudKit-shaped otherwise). (data-model.md §MedicationEvent)
- [ ] T011 Add `SquirlSchemaV2` to `app-four/App/SquirlSchema.swift` reflecting T007–T010 shapes; register `MigrationStage.lightweight(fromVersion: SquirlSchemaV1, toVersion: SquirlSchemaV2)` in `SquirlMigrationPlan.stages`; `schemas = [V1, V2]`.
- [ ] T012 Run T005 → GREEN; refactor. Then verify against a **copy of a real V1 store** the lightweight assumption holds (owner device step, quickstart S11). (research §B1 flag)

### Field-level encryption (schema, before any production promotion)

- [ ] T013 Add `@Attribute(.allowsCloudEncryption)` to sensitive fields in V2: `Recording.fullTranscriptText`/`medicationInfo`/`summary`/`noteExtractionJSON`/`summaryBulletsJSON`/`emotionsJSON`/`sideEffectsJSON`/`sleepEventJSON`/`topicTagsJSON`, `TranscriptionSegment.text`, `RecordingTag.name`, `MedicationEvent.name`/`dose`. Finalize the exact set. ⚠️ Must be set BEFORE first Production schema promotion (T045) — irreversible after. (research §C4/§C5)

### Two-configuration container

- [ ] T014 Write RED test `app-fourTests/ContainerConfigTests.swift`: assert the container builds a Synced config (journal models) and a Local config (`AppSettings`, `ModelMetadata`) with no cross-config relationship, and that `cloudKitDatabase` is `.none` when the sync flag is off. Confirm FAILS.
- [ ] T015 Modify `app-four/App/AppModelContainer.swift`: build ONE `ModelContainer` from two `ModelConfiguration`s — `"Synced"` (journal schema, `cloudKitDatabase` chosen from the sync flag: `.private("iCloud.Rythm-App.app-four")` when enabled+available else `.none`) and `"Local"` (`AppSettings`/`ModelMetadata`, always `.none`); wire `SquirlMigrationPlan`; re-apply `isExcludedFromBackupKey` on the store dir; remove the wipe-on-conflict `fatalError` path in favor of fail-closed. (data-model.md, contracts §container-build, research §A2/§A3/§B5)
- [ ] T016 Run T014 → GREEN; refactor.

### Service seam (protocol + mock)

- [x] T017 Add `CloudSyncService` protocol + `SyncAccountStatus`/`SyncFailure`/`SyncPhase`/`SyncState` types **in new file `app-four/Services/Sync/CloudSyncService.swift`** (cleaner than editing the shared `Protocols.swift`), incl. pure `SyncAccountStatus(from: CKAccountStatus)` + `SyncFailure(from: Error)` mappings. ✅ 2026-07-18
- [x] T018 Create `app-four/Services/Mock/MockCloudSyncService.swift`: scriptable account status + `removeFromICloud` + `state` stream (@MainActor). ✅ 2026-07-18
- [ ] T019 Register `CloudSyncService` in `app-four/Store/AppDependencies.swift` (real impl added in US1).

**Checkpoint**: schema is CloudKit-valid + migrates lightweight; container partitions synced/local; service seam + mock exist. Build + full test suite green.

---

## Phase 3: User Story 1 — Enable sync, populate a 2nd device (P1) 🎯 MVP

**Goal**: opt-in toggle uploads the local journal and it appears on a second device. **Independent test**: quickstart S1 (off-by-default) + S2 (enable + populate) + S8 (merge).

### Tests (RED first)
- [x] T020 [P] [US1] `app-fourTests/CloudSyncServiceTests.swift`: pure `CKAccountStatus`→`SyncAccountStatus` + `CKError`→`SyncFailure` mappings, and mock opt-in gating (off-by-default, enable needs available account, remove disables). ✅ 2026-07-18 (owner: run suite to confirm GREEN)
- [ ] T021 [P] [US1] `app-fourTests/SyncSettingsViewModelTests.swift`: VM exposes off-by-default state; enabling requires consent; state stream → UI mapping. Confirm FAILS.

### Implementation
- [ ] T022 [US1] Create `app-four/Services/Sync/CloudSyncServiceImpl.swift`: `accountStatus()` via `CKContainer.accountStatus()` (off-main); `isSyncEnabled`/`setSyncEnabled` persists flag to `AppSettings`(local)/`UserDefaults` (NEVER synced); observe `CKAccountChanged`. (research §A4)
- [ ] T023 [US1] Container-build reads the flag + account availability to pick `cloudKitDatabase` (Pattern A: apply-on-next-launch); document the relaunch-to-apply behavior. (research §A2)
- [ ] T024 [US1] Run T020 → GREEN.
- [ ] T025 [US1] Create `app-four/ViewModels/SyncSettingsViewModel.swift` (`@MainActor @Observable`): consumes `CloudSyncService.state`; exposes toggle, consent gate, status. Run T021 → GREEN.
- [ ] T026 [US1] **HTML mockup FIRST** (Constitution I): `html-mockups/settings-icloud-sync.html` — the iCloud Sync section (toggle off-default, consent sheet, status rows, remove row, conditional E2E copy). Owner design review before SwiftUI.
- [ ] T027 [US1] Create `app-four/Views/Settings/ICloudSyncSection.swift` matching the approved mockup: toggle, pre-enable consent sheet (FR-003), status display (FR-009). Wire into `SettingsView` "Your data".
- [ ] T028 [US1] Modify `app-four/Views/Onboarding/WelcomeView.swift`: revise "Everything stays on this device" ([WelcomeView.swift:48](app-four/Views/Onboarding/WelcomeView.swift#L48)) to survive an opt-in sync toggle without lying.

**Checkpoint**: US1 independently testable on device (S1, S2, S8). This is the releasable MVP.

---

## Phase 4: User Story 2 — Continuous propagation (P2)

**Goal**: new/edited/deleted entries propagate both ways; deletes don't resurrect. **Independent test**: quickstart S3.

### Tests (RED first)
- [ ] T029 [P] [US2] `app-fourTests/SyncMergeUpsertTests.swift`: upsert-by-id de-dups on import; deterministic keys for `RecordingTag`/(future)`DayCalendarContext` collapse independent creations; a deletion is not resurrected. Confirm FAILS. (research §B2, data-model.md §merge)
- [ ] T030 [P] [US2] Extend `CloudSyncServiceTests`: `CKError` cases → typed `SyncFailure` (`.quotaExceeded`/`.network`/`.notAuthenticated`/`.rateLimited`). Confirm FAILS.

### Implementation
- [ ] T031 [US2] Implement upsert/merge in the store layer (`app-four/Store/RecordingStore.swift` or a `SyncMerge` helper): fetch-by-id → update-or-insert on all import paths. Run T029 → GREEN. (research §B2)
- [ ] T032 [US2] Implement `CKError` → `SyncFailure` mapping + retry/back-off (respect `retryAfterSeconds`) in `CloudSyncServiceImpl`; emit through `state`. Run T030 → GREEN. (research §A5)
- [ ] T033 [US2] Verify background push-driven sync: remote-notification background mode delivers CloudKit change pushes (mirror sets up the subscription). Device-validate propagation ≤ 60s (S3).

**Checkpoint**: US1 + US2 = live multi-device sync.

---

## Phase 5: User Story 3 — Control: off-by-default, honest status, disable & remove (P2)

**Goal**: truthful status, disable keeps local, remove-from-iCloud is cloud-only (no fan-out), honest E2E copy. **Independent test**: quickstart S5, S6, S7.

### Tests (RED first)
- [ ] T034 [P] [US3] Extend `CloudSyncServiceTests`: `removeFromICloud()` disables sync then purges the private-DB zone; asserts local store untouched; is NOT a fan-out delete. Confirm FAILS. (spec FR-011, data-model.md state transitions)
- [ ] T035 [P] [US3] Extend `SyncSettingsViewModelTests`: status states (on/off/stalled/unavailable) render distinct copy; E2E claim shown ONLY when ADP-qualified (FR-012); no false "synced" (FR-013). Confirm FAILS.

### Implementation
- [ ] T036 [US3] Implement `removeFromICloud()` in `CloudSyncServiceImpl`: disable first, then delete the private CloudKit zone/records; leave local + other devices intact. Run T034 → GREEN. (research §A2, FR-011)
- [ ] T037 [US3] Implement disable path (rebuild container `.none`, local intact) in `CloudSyncServiceImpl` + container factory. (FR-010)
- [ ] T038 [US3] Status + conditional-E2E copy in `SyncSettingsViewModel` + `ICloudSyncSection` (per approved mockup); "remove" row + confirmation. Run T035 → GREEN.

**Checkpoint**: full control surface; trustworthy + honest.

---

## Phase 6: User Story 4 — New-device recovery (P3)

**Goal**: clean install + sign-in + enable restores the journal; audio-absent entries shown as a defined state. **Independent test**: quickstart S10.

- [ ] T039 [P] [US4] `app-fourTests/AudioAbsentStateTests.swift`: a synced `Recording` whose audio file is not present resolves to an "audio on original device" state, not an error. Confirm FAILS.
- [ ] T040 [US4] Implement the audio-absent state in `Recording`/detail view model + the detail/playback UI (defined state, never error language). Run T039 → GREEN. (spec US4 scenario 2, FR — audio device-local)
- [ ] T041 [US4] Device-validate recovery on a clean install (S10): transcripts/signals/med-log restored; audio-absent entries render calmly.

---

## Phase 7: Polish & Cross-Cutting

- [ ] T042 [P] Verify App Store privacy label stays "Data Not Collected" against `app-four/PrivacyInfo.xcprivacy` (empty collected-types) and confirm zero new required-reason API declarations (the 3 tripped are already present). (research §D1/§D2)
- [ ] T043 [P] Add App Review notes text (research §D4) to the submission checklist ([docs/app-store/SUBMISSION.md](../../docs/app-store/SUBMISSION.md)); update the in-app + hosted privacy policy to describe opt-in sync (FR — privacy policy).
- [ ] T044 [P] Confirm `ITSAppUsesNonExemptEncryption=false` remains correct with native `.allowsCloudEncryption` (OS-provided) (research §D6).
- [ ] T045 Deploy the CloudKit schema to the **Production** environment (CloudKit Dashboard) BEFORE the first TestFlight upload; verify record types + the encrypted fields (T013) are promoted. ⚠️ Additive-only after this — the V2 synced shape is now frozen. (research §B5/§C4/§D3)
- [ ] T046 Run the full quickstart device matrix S1–S11 on two devices (owner). Record results.
- [ ] T047 Run `/code-review` on the diff; address findings; open PR `feat/038-icloud-sync` → `main`. Do NOT merge without device QA (S1–S11) sign-off (CLAUDE.md).
- [ ] T048 Update BACKLOG (🔨 In code → ✅ Shipped on merge), DEVLOG, and regenerate WORKLOG (`scripts/worklog.sh`) after commits.
- [ ] T049 **Real sync-status observation (deferred from T022).** `CloudSyncServiceImpl` currently reports only on/off + iCloud-account availability (honest; never a fake "synced"). To deliver the full FR-009/FR-013 status (last-synced timestamp, `.syncing`, `.stalled(quota/network)`), observe `NSPersistentCloudKitContainer.eventChangedNotification` (posted by SwiftData's CloudKit container) and map its `.type`/`.succeeded`/`.error`/`.endDate` into `SyncState`. Device-validate that the notification fires for a SwiftData (not raw Core Data) container. Until then the mockup's "Synced · 2m ago" + stalled rows render as a plain "On".

---

## Dependencies & story order

- **Setup (P1)** → **Foundational (P2)** blocks everything.
- **US1 (P1)** depends on Foundational. **MVP = Setup + Foundational + US1.**
- **US2 (P2)** depends on US1 (needs the enabled sync path).
- **US3 (P2)** depends on US1; independent of US2.
- **US4 (P3)** depends on US1 + US2.
- **Polish** last; T045 (Production deploy) gates the first TestFlight; T013 (encryption) MUST precede T045 (irreversible).

## Parallel opportunities

- Foundational model edits **T007–T010** run in parallel (different files) after T006.
- **T020/T021**, **T029/T030**, **T034/T035**, **T039** are `[P]` RED tests (different files) within their phases.
- Polish **T042/T043/T044** run in parallel.

## Implementation strategy

1. **MVP** = Phases 1–3 (Setup + Foundational + US1) → releasable opt-in sync that populates a 2nd device.
2. Layer **US2** (continuous), then **US3** (control), then **US4** (recovery).
3. **Gates**: HTML mockup (T026) before Settings SwiftUI (T027); encryption fields (T013) before Production promotion (T045); device QA (T046) before merge (T047).
