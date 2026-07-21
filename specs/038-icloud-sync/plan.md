<!-- Created: 2026-07-18 15:34 (WEST) · Updated: 2026-07-18 15:34 (WEST) -->
# Implementation Plan: Opt-in iCloud Sync

**Branch**: `feat/038-icloud-sync` (to be created) | **Date**: 2026-07-18 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/038-icloud-sync/spec.md`

## Summary

Add opt-in, off-by-default iCloud sync of the journal (recordings/transcripts, mood/energy/focus/sleep/side-effects, medication log, and — when built — calendar day-context) across a user's own Apple devices, via **SwiftData native CloudKit mirroring** to the user's **private** database. Sensitive fields are marked `@Attribute(.allowsCloudEncryption)` so they are end-to-end encrypted under Advanced Data Protection (FR-016) with **no on-device search penalty** (the local replica stays plaintext). The developer can never read the data, so the App Store label stays "Data Not Collected." Technical approach (grounded in [research.md](research.md)): a **two-configuration `ModelContainer`** (Synced `.private`/`.none` + Local `.none` for settings/metadata), a **`SquirlSchemaV2` lightweight migration** that drops `@Attribute(.unique)` from `Recording`+`TranscriptionSegment` and adds CloudKit-required defaults, and **Pattern A opt-in** (the toggle picks `cloudKitDatabase` at container-build time) behind a `CloudSyncService` seam.

## Technical Context

**Language/Version**: Swift 6+ (strict concurrency)
**Primary Dependencies**: SwiftData (native CloudKit mirroring via `ModelConfiguration(cloudKitDatabase:)`), CloudKit (`CKContainer.accountStatus`, `CKError`), Foundation
**Storage**: SwiftData / SQLite; synced models mirror to the user's **private** CloudKit database; store dir stays `isExcludedFromBackupKey`
**Testing**: Swift Testing (`@Test`/`#expect`), test-first per Principle X; migration + service + VM + merge logic unit-tested; UI + sync verified on device (quickstart.md)
**Target Platform**: iOS 26+ (iPhone primary, iPad secondary)
**Project Type**: Mobile (single iOS app target)
**Performance Goals**: cross-device propagation ≤ 60 s under normal connectivity (SC-001); no UI block during initial export
**Constraints**: off-by-default (nothing transmitted pre-opt-in, SC-002); no store wipe (v1.2 shipped — migration must be lightweight/non-destructive); developer-inaccessible (private DB); local search unaffected by encryption
**Scale/Scope**: 6 existing `@Model` types (4 synced, 2 local) + 1 future (`DayCalendarContext`); ~single-user, low-thousands of entries

**Hard dependencies (sequencing)**:
1. `fix/app-store-readiness` merged to `main` — provides `SquirlSchemaV1` + crash-safe container = the V1 baseline this migration hops from.
2. `DayCalendarContext` (spec 029) is **not built** — 038 phase-1 syncs the 4 existing journal models; DCC joins the Synced schema when 029 ships (authored CloudKit-native).

## Constitution Check

*GATE: passed before Phase 0; re-checked after design below.* See `.specify/memory/constitution.md` (v1.2.0).

- [x] **I. SwiftUI-First** — PASS. New "iCloud Sync" Settings section is SwiftUI; **requires an HTML mockup first** (task). Account/CloudKit is non-UI.
- [x] **II. Test-Build-Ship** — PASS. Buildable, fully-tested; device QA per quickstart.md before "done".
- [x] **III. Correctness Over Speed** — PASS. The container-holder work is real refactor, not a shim; no dead code. The **latent Constitution IX violation** (Recording/TranscriptionSegment not actually CloudKit-shaped) is surfaced and fixed, not papered over.
- [x] **IV. Minimal Surface** — PASS (with justification). Two configurations + `CloudSyncService` + V2 migration are the minimum for opt-in selective sync. **Pattern A (apply-on-next-launch)** is chosen precisely to avoid the larger live-swap refactor; app-level CryptoKit is **not** adopted (native encryption suffices). See Complexity Tracking.
- [x] **V. Solo Git Discipline** — PASS. One revertable feature on `feat/038-icloud-sync`; `/code-review` + device QA before merge; `main` stays releasable.
- [x] **VI. On-Device Privacy** — PASS. Sync is **opt-in and OFF by default** (the exact carve-out VI permits); store stays `isExcludedFromBackupKey` while mirroring; sensitive fields field-encrypted; sync-enabled flag is local-only (never synced); logs stay counts/durations. No data leaves the device until the user opts in, and even then only to their own developer-inaccessible iCloud.
- [x] **VII. Deterministic, Measured Extraction** — N/A. Extraction pipeline untouched.
- [x] **VIII. Service-Oriented Architecture** — PASS. `CloudSyncService` protocol in `Services/`, injected via `AppDependencies`, `MockCloudSyncService` at the seam; `@MainActor @Observable` VM holds no persistence logic; CloudKit/account work off-main.
- [x] **IX. Pre-Release Data Posture** — PASS (and **restores** compliance). Synced schema becomes genuinely CloudKit-compatible (drop `.unique` on 2 models, add defaults, optional relationships + inverses). Local-only models keep `.unique` legitimately (exempt). The unique-drop is a **lightweight, non-destructive** migration — no wipe.
- [x] **X. Test-First Development** — PASS. V1→V2 migration, `CloudSyncService`, account-gating, upsert/merge, and the VM are built RED→GREEN with Swift Testing; SwiftUI views exempt (build + device run).

**Result: GATE PASS** — no unjustified violations. Complexity items justified below.

## Project Structure

### Documentation (this feature)

```text
specs/038-icloud-sync/
├── plan.md              # this file
├── research.md          # Phase 0 — 4 agents (cloudkit/swiftdata/swift-security/app-store-review) + Apple docs
├── data-model.md        # Phase 1 — V1→V2 schema, two-config split, encryption fields, merge keys
├── contracts/
│   └── cloud-sync-service.md   # CloudSyncService seam + Settings UI + container-build contract
├── quickstart.md        # Phase 1 — S1–S11 device validation
└── tasks.md             # Phase 2 — /speckit-tasks (NOT created here)
```

### Source Code (repository root)

```text
app-four/
├── App/
│   └── AppModelContainer.swift        # MODIFY: two ModelConfigurations; cloudKitDatabase chosen from sync flag (Pattern A); V2 migration plan wired
├── Models/
│   ├── SquirlSchema.swift             # MODIFY: add SquirlSchemaV2 (VersionedSchema) + SquirlMigrationPlan .lightweight(V1→V2)
│   ├── Recording.swift                # MODIFY: drop .unique; add defaults; .allowsCloudEncryption on sensitive fields
│   ├── TranscriptionSegment.swift     # MODIFY: drop .unique; add defaults + explicit inverse; encrypt text
│   ├── RecordingTag.swift             # MODIFY: defaults; encrypt name; deterministic merge key
│   └── MedicationEvent.swift          # MODIFY: encrypt name/dose; confirm inverse (already CloudKit-shaped)
├── Services/
│   ├── Protocols.swift                # MODIFY: add CloudSyncService protocol + typed SyncFailure/SyncAccountStatus
│   ├── Sync/
│   │   └── CloudSyncServiceImpl.swift # NEW: accountStatus, setSyncEnabled, removeFromICloud, state stream, CKError mapping
│   └── Mock/
│       └── MockCloudSyncService.swift # NEW: scripted account/failure states for tests
├── Store/
│   └── AppDependencies.swift          # MODIFY: register CloudSyncService
├── ViewModels/
│   └── SyncSettingsViewModel.swift    # NEW: @MainActor @Observable; consumes CloudSyncService.state
├── Views/Settings/
│   └── ICloudSyncSection.swift        # NEW: SwiftUI section (HTML mockup first) — toggle, status, consent sheet, remove
├── Views/Onboarding/
│   └── WelcomeView.swift              # MODIFY: revise "Everything stays on this device" to survive opt-in sync
├── app-four.entitlements              # NEW: icloud-services=CloudKit, icloud-container-identifiers, aps-environment
├── Info.plist                         # MODIFY: UIBackgroundModes += remote-notification (ITSAppUsesNonExemptEncryption stays false)
└── PrivacyInfo.xcprivacy              # NO CHANGE: required-reason APIs already declared; label stays "Data Not Collected"

app-fourTests/
├── SchemaMigrationV1toV2Tests.swift   # NEW: lightweight migration preserves rows, drops .unique (on a real V1 store copy)
├── CloudSyncServiceTests.swift        # NEW: account-status mapping, CKError→SyncFailure, enable/disable/remove
├── SyncMergeUpsertTests.swift         # NEW: upsert-by-id dedup; deterministic keys for tag/day-context
└── SyncSettingsViewModelTests.swift   # NEW: state→UI mapping, no-false-success, honest E2E copy gating
```

**Structure Decision**: single iOS app target (`app-four`); this feature is additive within existing `App/`, `Models/`, `Services/`, `ViewModels/`, `Views/`, plus a net-new `.entitlements`. No new module. `Services/Sync/` mirrors the existing `Services/DoseLog/` convention.

## Complexity Tracking

| Violation / added complexity | Why needed | Simpler alternative rejected because |
|---|---|---|
| **Two `ModelConfiguration`s in one container** | Selective sync — `AppSettings`/`ModelMetadata` (device config, model metadata) must stay local while journal syncs | Syncing the whole store would push device-specific config across devices and enlarge the CloudKit-compat audit for no user value |
| **`CloudSyncService` seam + Mock** | Constitution VIII requires external capabilities behind a `Services/` protocol; enables test-first (X) of account/error handling without a live iCloud account | Inline CloudKit calls in the VM would violate VIII and be untestable |
| **Container-build reads sync flag (Pattern A)** | No supported live hot-swap of `ModelContainer` local→CloudKit; Pattern A is the minimal correct opt-in (research §A2) | Pattern B (live root-swap) needs refactoring the `static let` container + statically-captured `.mainContext` — larger surface; deferred until Pattern A's relaunch-to-apply UX proves insufficient |
| **V2 attribute-default pass on Recording/TranscriptionSegment** | CloudKit requires optional-or-defaulted; these models are not CloudKit-shaped today (latent IX violation) | Cannot enable `.private` on a non-compliant schema — container init throws |

**Deferred (not in this plan, flagged)**: Pattern B live-swap; app-level CryptoKit "E2E for non-ADP users"; raw-audio sync; `DayCalendarContext` sync (until spec 029 ships).
