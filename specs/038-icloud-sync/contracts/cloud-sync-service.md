<!-- Created: 2026-07-18 15:34 (WEST) · Updated: 2026-07-18 15:34 (WEST) -->
# Contract: CloudSyncService + Settings sync surface (feature 038)

Per Constitution VIII, the sync capability sits behind a `Services/` protocol injected via `AppDependencies`, mockable at the seam. UI is a `@MainActor @Observable` view-model consuming it. This contract defines the seam and the observable states — not the implementation.

## Service protocol (Services/)

```
protocol CloudSyncService: Sendable {
    // Account availability (A4). Off-main. Maps CKContainer.accountStatus().
    func accountStatus() async -> SyncAccountStatus            // .available/.noAccount/.restricted/.temporarilyUnavailable/.couldNotDetermine

    // Enable/disable (Pattern A: persists the flag; effect applies on next container build).
    func setSyncEnabled(_ enabled: Bool) async throws
    var isSyncEnabled: Bool { get }

    // Remove the user's data from iCloud (FR-011): disable, then purge the private-DB zone.
    // Does NOT touch local stores on this or any other device.
    func removeFromICloud() async throws

    // Live status for Settings (FR-009). Never reports a false "synced".
    var state: AsyncStream<SyncState> { get }                  // phase + lastSyncedAt + accountStatus
}
```

- **Errors surfaced (A5)** — the service maps `CKError.Code` to a typed `SyncFailure`: `.quotaExceeded`, `.network`, `.notAuthenticated`, `.rateLimited(retryAfter:)`, `.other`. The VM renders each as a distinct, honest message; never a perpetual spinner (FR-013).
- **Threading**: all CloudKit/account calls run off the main actor; the VM is `@MainActor @Observable` and holds no persistence logic (VIII).
- **Mock**: `MockCloudSyncService` (in `Services/Mock/`) returns scripted account states + failures for VM/unit tests (test-first, X).

## Container-build contract (Pattern A)

The container factory reads the sync-enabled flag + account availability at build time and selects the Synced configuration's `cloudKitDatabase`:

```
enabled && accountAvailable  → ModelConfiguration("Synced", schema: syncedSchema, cloudKitDatabase: .private("iCloud.<container>"))
otherwise                    → ModelConfiguration("Synced", schema: syncedSchema, cloudKitDatabase: .none)
Local config                 → always ModelConfiguration("Local", schema: localSchema, cloudKitDatabase: .none)
```

- The synced schema is **permanently V2-shaped** (unique-free, CloudKit-valid) regardless of the flag, so toggling the flag never triggers a migration (research §B5).
- Store directory keeps `isExcludedFromBackupKey` in both states (A3).
- **Migration runs before CloudKit validation** — the V1→V2 lightweight stage brings the on-disk store to a valid shape before `.private` attaches.

## Settings UI contract (SwiftUI)

New "iCloud Sync" section in Settings ▸ Your data (HTML mockup required first, Constitution I). Observable states → UI:

| `SyncState.phase` / condition | UI |
|---|---|
| flag off (default) | Toggle **off**; subtitle "Off — your journal stays on this device." |
| enabling / initial export | Toggle on; "Setting up…" with progress; app remains usable |
| syncing / idle, `.available` | Toggle on; "On · Last synced <relative time> · <account>" |
| `.stalled(.quotaExceeded)` | "iCloud storage full — sync paused" (not an error alarm) |
| `.stalled(.network)` | "Waiting for network" |
| `.unavailable(.noAccount)` | Toggle disabled; "Sign in to iCloud to turn on Sync" |
| pre-enable consent | Sheet: what syncs, "your own iCloud account", "Squirl can't read it", E2E-under-ADP note (FR-003, FR-012) |
| destructive | "Remove my data from iCloud" row → confirm → `removeFromICloud()` (FR-011) |

- **Privacy copy (FR-012)**: claim end-to-end encryption **only** conditionally ("End-to-end encrypted when Advanced Data Protection is on"); otherwise "Private to your iCloud account — not readable by Squirl." Never unconditional E2E.
- **Onboarding line** [WelcomeView.swift:48](app-four/Views/Onboarding/WelcomeView.swift#L48) ("Everything stays on this device") must be revised to survive an opt-in sync toggle without lying (align with this section's copy).

## Acceptance mapping

| Spec | Contract element |
|---|---|
| FR-001 off by default | flag defaults false; `.none` config until enabled |
| FR-003 consent gate | pre-enable sheet before first `.private` build |
| FR-008 developer-inaccessible | private DB only; no public/shared zone, no server |
| FR-009 honest status | `state` stream → Settings rows |
| FR-011 remove | `removeFromICloud()` = disable + purge cloud, local retained |
| FR-012 E2E-only-under-ADP | conditional privacy copy |
| FR-013 no false success | typed `SyncFailure` → distinct messages |
| FR-016 field encryption | `.allowsCloudEncryption` on sensitive fields (data-model.md) |
