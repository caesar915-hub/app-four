# Phase 1 Data Model: Weather at Check-In

## New value type — `WeatherSnapshot`

A point-in-time, immutable record of outdoor conditions captured for a check-in. Pure value
type (`Codable, Sendable`), persisted as JSON on the entry — **not** a SwiftData `@Model`.

| Field | Type | Notes |
|-------|------|-------|
| `conditionCode` | `String` | WeatherKit `WeatherCondition.rawValue` (e.g. `clear`, `rain`). Categorical. |
| `temperatureC` | `Double` | Canonical storage in °C; display converts to locale unit (FR-010). |
| `symbolName` | `String` | WeatherKit `currentWeather.symbolName` (SF Symbol) for display (FR-003, FR-007). |
| `capturedAt` | `Date` | When weather was fetched (≈ check-in time). Records the moment, not a live value. |

**Validation / invariants**:
- All fields required *within* a snapshot; the snapshot as a whole is optional on the entry.
- Immutable once written — never refreshed (it is historical context).
- `conditionCode` is coarsened into a small **family** (clear / cloudy / rain / snow / other) at
  the Insights layer only; raw code is preserved in storage.

**Display derivations** (no new stored fields):
- `conditionFamily` — computed mapping of `conditionCode` → family (used by Insights buckets, R6).
- temperature string — `MeasurementFormatter` over `Measurement(value: temperatureC, unit: .celsius)`.

## Modified entity — `Recording` (`@Model`)

Existing entry record ([Models/Recording.swift](../../app-four/Models/Recording.swift)). One new
optional attribute + helpers; **no** relationship, **no** required field — preserves CloudKit
compatibility (Principle IX).

| Change | Detail |
|--------|--------|
| New attribute | `var weatherJSON: String?` — placed beside `sleepEventJSON` (~L36). Optional ⇒ lightweight migration. |
| Init param | `weatherJSON: String? = nil` — default keeps every existing call site compiling. |
| Read helper | `var decodedWeather: WeatherSnapshot?` — decode JSON; **not** `@MainActor` (snapshot is `Sendable`), unlike `decodedSleepEvent` which is main-actor for its main-context type. |
| Write helper | `func applyWeather(_ snapshot: WeatherSnapshot)` — JSON-encode into `weatherJSON`, bump `updatedAt`. Single source of truth for writing weather (parallels `applySummaryResult`). |

**Relationship**: at most one `WeatherSnapshot` per `Recording` (embedded JSON, 0..1). No inverse,
no cascade — it's a value, not an entity.

**State**: a `Recording` is *weather-less* (`weatherJSON == nil`) until backfill succeeds; it may
remain weather-less permanently (permission denied / offline / pre-feature entry) and MUST render
cleanly in that state (FR-011).

## Schema registration

No change to the `Schema([...])` array in
[AppModelContainer.swift](../../app-four/App/AppModelContainer.swift) — `WeatherSnapshot` is not a
`@Model`. Only `Recording` gains a column. **Verify** the optional add does not trip the
wipe-on-mismatch recovery (research R5).

## Logging posture (Principle VI)

Weather capture MUST log counts/durations/outcome only (`captured` / `skipped: denied` /
`skipped: offline` / `error`). It MUST NOT log coordinates, `conditionCode`, or temperature.
