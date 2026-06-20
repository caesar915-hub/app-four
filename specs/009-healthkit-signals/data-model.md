# Phase 1 Data Model: HealthKit Signals

**Feature**: 009-healthkit-signals | **Date**: 2026-06-20

Source of truth is SwiftData. HealthKit is a read-only source that mirrors into these types via Sendable DTOs. All persisted attributes are optional or defaulted and none use `@Attribute(.unique)` (Constitution IX / research D1).

## Entity: `DailySignals` (`@Model`)

One row per local calendar day. Identity is the logical key `dayStart`; uniqueness is enforced by `SignalsStore.upsert`, **not** the schema.

| Field | Type | Default | Notes |
|---|---|---|---|
| `dayStart` | `Date` | `.distantPast` | start-of-day key (D4). Plain, **non-unique**, defaulted. |
| `updatedAt` | `Date` | `.now` | last write. |
| `sleepHours` | `Double?` | `nil` | hours asleep. |
| `sleepLevelValue` | `String?` | `nil` | raw of `SleepLevel` (D5); rendered as 5-step beads. |
| `sleepSource` | `SignalSource` | `.none` | provenance for the sleep group. |
| `steps` | `Int?` | `nil` | |
| `activeEnergyKcal` | `Double?` | `nil` | |
| `exerciseMinutes` | `Int?` | `nil` | |
| `activitySource` | `SignalSource` | `.none` | provenance for the activity group. |
| `restingHeartRate` | `Double?` | `nil` | bpm. |
| `hrvSDNN` | `Double?` | `nil` | ms. |
| `heartSource` | `SignalSource` | `.none` | provenance for the heart group. |
| `menstrualFlow` | `MenstrualFlow?` | `nil` | |
| `cycleSymptomsJSON` | `String?` | `nil` | `[String]` encoded (matches existing `*JSON` convention; avoids a CloudKit relationship). |
| `cycleSource` | `SignalSource` | `.none` | provenance for the cycle group. |
| `isMockData` | `Bool` | `false` | mock/real partition per codebase convention. |

- Provenance is **per signal group** (4 sources), not per scalar field (A1).
- `cycleSymptoms: [String]` is a computed accessor over `cycleSymptomsJSON` (encode/decode; empty array → `nil`).
- **No relationships.** If one is ever added it must be optional with an inverse (CloudKit rule).

## Value types

```
enum SignalSource: String, Codable, Sendable { case none, healthKit, manual }

enum MenstrualFlow: String, Codable, Sendable, CaseIterable { case light, medium, heavy, spotting }
```

- `SignalSource` drives the merge rule (below). Stored as a defaulted raw value.
- `MenstrualFlow` maps to/from `HKCategoryValueVaginalBleeding` **inside the HealthKit actor only** (D2): HK `light=2→.light`, `medium=3→.medium`, `heavy=4→.heavy`; `unspecified=1`/`none=5`/unknown → no flow. (`spotting` is a manual-entry-only value; HK has no distinct spotting case in this enum.)

## Sleep rendering (reconciled with DESIGN.md, 2026-06-20)

Sleep renders with the **bed icon + sleep indigo (`#5566A6`) + the named `SleepLevel` scale** (Restless→Deep) as text/hours. The colour bead ramp is **deferred** per DESIGN.md (L49, L106), so **no `SleepLevel: SignalLevel` conformance is added** — the 5-step `SignalLevel` colour grammar stays mood/energy/focus only. `DailySignals.sleepLevel` (computed accessor over `sleepLevelValue`) supplies the named level for display and the manual picker.

## Sendable DTOs (cross the actor boundary)

```
struct SleepDTO    { var hours: Double; var level: SleepLevel? }
struct ActivityDTO { var steps: Int?; var activeEnergyKcal: Double?; var exerciseMinutes: Int? }
struct HeartDTO    { var restingHeartRate: Double?; var hrvSDNN: Double? }
struct CycleDTO    { var flow: MenstrualFlow?; var symptoms: [String] }
struct DaySignalsDTO { var dayStart: Date; var sleep: SleepDTO?; var activity: ActivityDTO?; var heart: HeartDTO?; var cycle: CycleDTO? }
```

All are structs of value types → automatically `Sendable` (no `@unchecked`). No `HKObject` ever escapes the actor.

## Provenance merge rule (the core invariant — FR-009/010/011)

Applied per group when a HealthKit DTO arrives:

| existing source | action | resulting source |
|---|---|---|
| `.none` | write HK values | `.healthKit` |
| `.healthKit` | overwrite with fresh HK values | `.healthKit` |
| `.manual` | **do nothing** (sticky) | `.manual` |

Manual entry always sets `.manual`. Clearing a `.manual` group to empty resets it to `.none`, re-enabling HK fill next sync (FR-012, A5).

## State transitions (per group)

```
none ──HK import──▶ healthKit ──HK re-import──▶ healthKit
 │                      │
 └──manual edit──▶ manual ◀──manual edit── (any)
        │
        └──cleared to empty──▶ none
```

## Store contract: `SignalsStore` (`@MainActor @Observable`)

- `init(context: ModelContext)`
- `fetch(dayStart: Date) -> DailySignals?` — exact match, `fetchLimit = 1`.
- `upsert(dayStart: Date) -> DailySignals` — normalize via `SignalDayKey.dayStart`, fetch-or-insert (idempotent; FR-003).
- `fetchRange(from:to:) -> [DailySignals]` — inclusive, newest first.
- `save() throws`.

## Identity & uniqueness

- Logical key: normalized `dayStart` (`startOfDay`).
- Uniqueness: enforced in `upsert` (fetch-then-insert). Safe in-process because of the single `@MainActor` main context (research D1).
- Volume: one row/day → ~365 rows/year; trivial.
