<!-- Created: 2026-07-18 15:34 (WEST) · Updated: 2026-07-18 15:34 (WEST) -->
# Quickstart / Validation: Opt-in iCloud Sync (feature 038)

Device-only validation (no simulator, per project rules — owner runs on hardware). Requires **two devices** signed into the **same test Apple Account** and a TestFlight build with the CloudKit schema **deployed to Production** (research §D3). Prerequisites: `fix/app-store-readiness` merged (V1 baseline); iCloud+CloudKit + Background Modes (remote-notification) entitlements provisioned for the build's bundle id.

## Setup

1. Build to Device A and Device B, both signed into the same iCloud test account.
2. Confirm CloudKit container exists and schema is **Production**-deployed (CloudKit Dashboard).

## Validation scenarios (map to spec Success Criteria)

### S1 — Off by default (SC-002, FR-001)
- Fresh install on Device A. Record several check-ins. **Do not** open the sync toggle.
- **Expected**: no CloudKit traffic; nothing appears in the CloudKit Dashboard private zone; the toggle reads Off.

### S2 — Enable + populate second device (SC-001, SC-003, US1)
- Device A: Settings ▸ Your data ▸ turn on iCloud Sync, accept the consent sheet. (Pattern A: reopen the app if required to apply.)
- Device B: install, sign in, enable sync.
- **Expected**: Device A's existing entries appear on Device B; **no duplicates**, **no lost entries** (S8 covers merge).

### S3 — Continuous propagation (SC-001, US2)
- Device A records a new check-in.
- **Expected**: appears on Device B within **one minute** under normal connectivity. Edit mood/transcript on B → reflected on A. Delete on A → removed on B, does not reappear.

### S4 — Local search over encrypted fields (FR-016, C3 — must validate)
- With sync on, run an in-app search/filter that matches transcript text.
- **Expected**: `#Predicate contains` still returns matches on-device (local replica plaintext), confirming `.allowsCloudEncryption` did not break local search.

### S5 — E2E honesty (FR-012)
- Read the sync consent copy with ADP **off** vs **on** (Settings ▸ Apple Account ▸ iCloud ▸ Advanced Data Protection).
- **Expected**: with ADP off, copy does **not** claim E2E ("Private to your iCloud account — not readable by Squirl"); with ADP on, it may state E2E.

### S6 — Disable keeps local (FR-010)
- Device A: turn sync off.
- **Expected**: transmission stops; every entry remains on Device A.

### S7 — Remove from iCloud, no fan-out (FR-011, edge case)
- Device A: "Remove my data from iCloud" → confirm.
- **Expected**: cloud copy deleted within a bounded time; Device A's local journal intact; **Device B's local journal intact** (removal did not delete B's entries).

### S8 — Merge with pre-existing local data (FR-006, FR-007, US1-4)
- Device B has its own local entries created before enabling; enable sync.
- **Expected**: A's and B's entries **union** with no duplicates and no loss.

### S9 — Account / quota / network honesty (FR-013, A4/A5)
- Sign out of iCloud on Device A while sync is on → "Sign in to iCloud to keep syncing."
- Simulate no network → "Waiting for network," resumes on reconnect.
- (If feasible) fill iCloud storage → "iCloud storage full — sync paused," never a false "synced."

### S10 — New-device recovery (SC-003, US4)
- Wipe/replace Device A with a clean install, same account, enable sync.
- **Expected**: journal restored (transcripts/signals/med-log); an entry whose audio was device-local shows the "audio stays on its original device" state, not an error.

### S11 — Migration preserves data (B1 — must validate)
- Upgrade a build carrying a **real V1 store** (with data) to the V2 build.
- **Expected**: all rows preserved, `.unique` dropped, app launches without wipe (crash-safe container path holds).

## Pass criteria

All of S1–S11 pass on hardware, plus:
- App Store privacy label unchanged ("Data Not Collected", research §D1).
- No new required-reason API declarations needed (research §D2).
- Constitution Check (plan.md) green post-implementation; full Swift Testing suite green (Principle II/X).
