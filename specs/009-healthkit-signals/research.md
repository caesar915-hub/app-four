# Phase 0 Research: HealthKit Signals

**Feature**: 009-healthkit-signals | **Date**: 2026-06-20

This consolidates the decisions that resolve every unknown in the Technical Context. Each correction below supersedes the corresponding detail in the design-feeder doc `docs/superpowers/specs/2026-06-13-healthkit-signals-design.md`; cited sources were verified (and externally re-verified for the HealthKit API claims) in a parallel research pass.

## D1 — CloudKit / `@Attribute(.unique)` conflict (Constitution IX)

**Decision**: Drop `@Attribute(.unique)` from `DailySignals`. `dayStart` is a plain, defaulted, non-unique `Date` used only as a *logical* key. One-row-per-day is enforced in `SignalsStore.upsert(for:)` (normalize to `startOfDay`, fetch with `fetchLimit = 1`, update-in-place or insert, then save). Every attribute is optional or defaulted.

**Rationale**: SwiftData's CloudKit mirroring runs on `NSPersistentCloudKitContainer`, which **never supported unique constraints** and now fails container load up front if one is present; it also requires every attribute to be optional or have a default. The design doc's `@Attribute(.unique) var dayStart` would forfeit the opt-in sync path that Constitution IX exists to protect. Dropping it *removes* the violation — **no Complexity Tracking entry is needed**. The app uses a single shared main context (`AppModelContainer.container.mainContext`), and `@MainActor` serializes all access, so there is no in-process insert race; the only duplicate vector is cross-device CloudKit convergence, which is out of scope until sync is enabled and is then handled by Apple's de-dup-on-import pattern.

**Alternatives rejected**: Keeping `@Attribute(.unique)` (breaks CloudKit — Apple forums 656380); a separate cloud configuration (over-engineering for a feature that ships local-only).

**Sources**: developer.apple.com/forums/thread/656380, /735349, /766973; fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/; constitution.md §IX.

**Latent issue surfaced (out of scope, file a backlog item)**: `Recording`, `AppSettings`, `ModelMetadata`, `TranscriptionSegment` already declare `@Attribute(.unique) var id: UUID` (e.g. `app-four/Models/Recording.swift:6`) — a pre-existing IX violation that would block CloudKit today. `DailySignals` MUST NOT copy this pattern. Stripping the existing four is a separate cleanup, not this feature's job.

## D2 — Menstrual flow enum is deprecated; raw mapping in the design doc is wrong

**Decision**: Map menstrual flow using the non-deprecated `HKCategoryValueVaginalBleeding` (iOS 18.0+, cases `unspecified/light/medium/heavy/none`). Correct the integer mapping to: **1 = unspecified, 2 = light, 3 = medium, 4 = heavy, 5 = none** (raw 0 = "not applicable" is an Obj-C-only value with no Swift case). Our `MenstrualFlow` domain enum maps `light→.light, medium→.medium, heavy→.heavy`; `unspecified`/`none`/unrecognized → no flow recorded (`nil`).

**Rationale**: `HKCategoryValueMenstrualFlow` is **deprecated as of iOS 18.0** and renamed to `HKCategoryValueVaginalBleeding`. The design doc's `HealthKitSampleMapping.flow(fromHKValue:)` mapped raw `1 → none`, which is wrong (1 is *unspecified*; *none* is 5). This is a correctness bug that the unit test in the impl plan (Task 6) also encodes incorrectly — both the mapping and its test must use the corrected integers.

**Sources**: developer.apple.com/.../hkcategoryvaluemenstrualflow.json (deprecated iOS 18.0, "Renamed to HKCategoryValueVaginalBleeding"); raw integers verified via the Microsoft .NET HealthKit binding auto-generated from Apple's Obj-C `NS_ENUM`.

## D3 — HealthKit read API surface (verified current for iOS 26)

**Decision**: Use the modern async query descriptors:
- Samples: `HKSampleQueryDescriptor(...).result(for: store)` (sleep, menstrual flow, symptoms).
- Daily statistics: `HKStatisticsQueryDescriptor(...).result(for: store)` — `.cumulativeSum` for steps/active-energy/exercise-minutes, `.discreteAverage` for resting HR / HRV SDNN.
- Sleep "asleep" = sum of `asleepCore + asleepDeep + asleepREM + asleepUnspecified` (the combined legacy `.asleep` is deprecated; `allAsleepValues` is available as a convenience); `inBed` summed separately for the efficiency heuristic.
- Quantity identifiers confirmed non-deprecated: `stepCount`, `activeEnergyBurned`, `appleExerciseTime`, `restingHeartRate`, `heartRateVariabilitySDNN`.
- Symptom category identifiers confirmed: `abdominalCramps`, `headache`, `fatigue`, `lowerBackPain` (severity-valued) and `moodChanges` (presence-valued). We only detect *presence of any sample that day* → a symptom tag, so the value enum difference does not affect logic.

**Authorization**: `HKHealthStore.isHealthDataAvailable()` gate; `requestAuthorization(toShare: [], read:)` async. **Read authorization status cannot be queried** — denial is indistinguishable from "no data" (Apple-documented). Therefore the service reports `.authorized` once available and reads simply return empty; the UI treats denied/unavailable/no-data identically (FR-014).

**Entitlement / Info.plist**: `com.apple.developer.healthkit` (Boolean entitlement) + `NSHealthShareUsageDescription` (read). **No** `NSHealthUpdateUsageDescription` (read-only; FR-017).

**Caveat (verify at implement)**: the exact `iOS 15.0+` availability of `HKQuantityType.init(_:)`/`HKCategoryType.init(_:)` was not independently confirmed; the identifier-based init is standard usage and the compiler will pinpoint any mismatch on the iOS 26 SDK.

**Sources**: developer.apple.com/.../hksamplequerydescriptor, /hkstatisticsquerydescriptor, /hkcategoryvaluesleepanalysis, /hkhealthstore/ishealthdataavailable, /setting-up-healthkit.

## D4 — Timezone-safe day key

**Decision**: `SignalDayKey.dayStart(for: Date, calendar: Calendar = .current) -> Date` returns `calendar.startOfDay(for:)` — the Date itself, never a derived string/int. Store that Date; always recompute keys through one `Calendar` (`.current`).

**Rationale**: Matches the established codebase convention (`InsightsViewModel+Signals.swift:112`, `CalendarMonthModel`, etc.). `startOfDay(for:)` correctly resolves DST edges. The only hazard is that a key depends on the calendar's timezone, so a persisted derived key would diverge after a timezone change — avoided by storing the Date and recomputing.

**Sources**: sosumi.ai/documentation/foundation/calendar/startofday(for:); developer.apple.com/forums/thread/676573; codebase `InsightsViewModel+Signals.swift:112`.

## D5 — Sleep quality uses the existing 5-step `SleepLevel`, not a 3-value string (honors A6)

**Decision**: `DailySignals` stores sleep as `sleepHours: Double?` + `sleepLevelValue: String?` (raw of the existing `SleepLevel` enum), mirroring `Recording.sleepLevelValue`. Manual entry offers the 5 `SleepLevel` cases. The HealthKit importer always sets `sleepHours`; it maps sleep efficiency (`asleep/inBed`) to a `SleepLevel` via a documented coarse heuristic, leaving the level `nil` when `inBed` is unknown (A3 fallback).

**Rendering (reconciled with DESIGN.md, 2026-06-20)**: sleep renders with the **bed icon + sleep indigo (`#5566A6`) + the named `SleepLevel` scale** (Restless→Deep) as text/hours — **not** colored beads. DESIGN.md (L49, L106) explicitly **defers the sleep colour ramp**, and the 5-step `SignalLevel` colour grammar stays mood/energy/focus only. Therefore **`SleepLevel: SignalLevel` conformance is NOT added** (tasks.md T009 cut). This was an explicit owner decision overriding the original A6 "beads" reading.

**Rationale**: The design doc assumed a `poor/okay/good` (3-value) sleep-quality string. The codebase's *actual* sleep grammar is the 5-step `SleepLevel` (`restless/light/okay/good/deep`, `NoteExtraction.swift:233-252`), and the 5-step visual grammar is `SignalLevel` (`DesignSystem/SignalLevel.swift:25-34`). A 3-value string cannot render 5 beads, so satisfying A6 *requires* `SleepLevel`. Reusing it (rather than inventing a parallel vocabulary) also honors Constitution IV (Minimal Surface). `SleepLevel` is not yet `SignalLevel`-conforming — that conformance is the one small addition.

**Efficiency→SleepLevel heuristic (coarse, documented; cutoffs finalized in tasks/implement)**: based on sleep-efficiency norms (≥~85–90% healthy, ≥80% normal floor, <75% disturbed — Wikipedia "Sleep efficiency"). A defensible starting mapping: `<0.70 restless, 0.70–<0.80 light, 0.80–<0.88 okay, 0.88–<0.94 good, ≥0.94 deep`; return `nil` when `inBed ≤ 0` or efficiency is non-finite/>1. This is a heuristic, not a diagnosis; the unit test locks whatever cutoffs are committed.

**Sources**: codebase `NoteExtraction.swift:233-252`, `DesignSystem/SignalLevel.swift:25-34`, `Recording.swift:30-37`; en.wikipedia.org/wiki/Sleep_efficiency.

## D6 — Existing patterns to mirror (no new architecture)

- **Service seam**: new `HealthDataReading: Sendable` protocol in `Services/HealthKit/`, implemented by an `actor HealthKitServiceImpl` (the only `import HealthKit`), injected by adding `healthService` to `AppServices` (after `summarizationService`, `AppServices.swift:10-27`) and constructing it in `AppDependencies`. Mock added to `MockAppServices` (`@MainActor struct`, vends `var services: AppServices`). (Constitution VIII.)
- **Store**: `@MainActor @Observable final class SignalsStore` taking an injected `ModelContext`, mirroring `RecordingStore` (`RecordingStore.swift:8-11`).
- **Schema registration**: add `DailySignals.self` to **both** `Schema([...])` arrays — `AppModelContainer.swift:9-16` (container) and `:63-70` (previewContainer). The `#if DEBUG` wipe-on-conflict path (`:31`) covers dev; no migration needed (Constitution IX, pre-release).
- **View model**: `@Observable @MainActor` per `CheckInViewModel` (`CheckInViewModel.swift:6-8`).
- **Tests**: Swift Testing (`@Test`/`#expect`), `@testable import app_four`, in-memory `ModelConfiguration(isStoredInMemoryOnly: true)`. **The design/impl-plan snippets say `@testable import app_two` — that is wrong; the module is `app_four`.**

## D7 — Scope locked by clarification (2026-06-20)

- **A8** — all four signal groups ship end-to-end.
- **A2** — check-in→sleep bridge **excluded** (impl-plan Task 13 is dropped).
- **A6** — sleep-only bead grammar (see D5); activity/heart/cycle render as plain values.
