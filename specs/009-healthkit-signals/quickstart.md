# Quickstart / Validation: HealthKit Signals

**Feature**: 009-healthkit-signals | **Date**: 2026-06-20

How to prove the feature works end-to-end. Logic is verified by Swift Testing suites (run on simulator); the HealthKit read path is verified manually on a device (the simulator has no Health data).

## Prerequisites

- Xcode with the iOS 26 SDK; an iPhone 16 Pro simulator (or substitute via `xcrun simctl list devices available`).
- Build/test env (per project memory): prefix with `env -u GIT_CONFIG_COUNT -u GIT_CONFIG_KEY_0 -u GIT_CONFIG_VALUE_0`.
- HealthKit capability + entitlement added to the `app-four` target; `NSHealthShareUsageDescription` in Info.plist.

## Automated validation (simulator, no Health data)

Run per-suite during TDD, full target before "done":

```bash
env -u GIT_CONFIG_COUNT -u GIT_CONFIG_KEY_0 -u GIT_CONFIG_VALUE_0 \
  xcodebuild test -scheme app-four \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:app-fourTests/<SuiteName> 2>&1 | tail -40
```

| Scenario (maps to spec) | Suite | Expected |
|---|---|---|
| Day model defaults, no `@Attribute(.unique)` | `DailySignalsTests` | sources default `.none`; two inserts for the same day converge to one row via the store |
| Timezone-safe day key (FR-015) | `SignalDayKeyTests` | same local day → same key across times; DST-safe |
| Upsert idempotency (FR-003) | `SignalsStoreTests` | repeat `upsert` returns the same row; count stays 1 |
| Merge rule (FR-009/010/011) | `SignalSyncCoordinatorTests` | `.none`→fill, `.healthKit`→refresh, `.manual`→untouched |
| Sync orchestration (FR-006) | `SignalSyncCoordinatorTests` | mock reader fills rows; manual edits survive sync |
| Flow enum mapping (D2 fix) | `HealthKitSampleMappingTests` | 2→light, 3→medium, 4→heavy; 1/5/unknown→nil |
| Sleep efficiency → `SleepLevel` (D5) | `HealthKitSampleMappingTests` | documented cutoffs; `nil` when inBed unknown |
| Editor VM provenance (FR-008/012, A5) | `DaySignalsEditorViewModelTests` | edit → `.manual`; clear → `.none`; untouched groups keep source |

**P1 manual-only path (core requirement, SC-001/SC-005)**: with the simulator having no Health data, `DaySignalsSummaryView` shows "—" and the editor accepts manual values that persist across relaunch — proving the feature works with HealthKit absent.

## Manual device validation (the only thing tests can't cover)

On a physical device with Health data:
1. Launch → reach Signals → primer appears (FR-005) → **Connect** → grant access.
2. Recent days populate from Apple Health with the Apple-Health source indicator (SC-002); first grant backfills ~30 days (SC-003).
3. A day with no Health data shows empty, editable fields — no error (FR-014/SC-005).
4. Edit one imported value → it flips to "Added by you" (SC-006) and **survives pull-to-refresh** (SC-004).
5. Confirm no network egress of health values (SC-007 / Constitution VI).

Record the device-pass result in the PR description.

## Done

- All `app-fourTests` suites green; app target builds with no new warnings.
- Manual device pass recorded.
- Backlog row moved 📐 Plan → 🔨 In code with branch + plan link.
