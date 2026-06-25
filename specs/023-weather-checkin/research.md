# Phase 0 Research: Weather at Check-In

All Technical Context unknowns resolved. Each item: Decision · Rationale · Alternatives.

## R1 — Capture timing: backfill after save (not before)

**Decision**: Save the entry immediately; fetch weather in a detached `Task` afterward, then
`recording.applyWeather(snapshot)` + `store.save()`. Guard against the recording having been
deleted before the result returns.

**Rationale**: WeatherKit is a network round-trip; awaiting it before insert would put latency
on every check-in's critical path and break offline capture (SC-002, SC-003). The codebase
already does exactly this with `transcribeInBackground` ([CheckInViewModel.swift:208](../../app-four/ViewModels/CheckInViewModel.swift#L208)) — insert, flip state to `.done`, then mutate + re-save in a background task.

**Alternatives**: *Await before insert* — rejected (latency + offline failure). *Capture in the
View* — rejected (violates Principle VIII; VM owns orchestration).

## R2 — One-shot location under Swift 6 concurrency

**Decision**: A `@MainActor` `CLLocationManager` wrapper. Call `requestWhenInUseAuthorization()`
lazily on first capture; set `desiredAccuracy = kCLLocationAccuracyReduced`; call
`requestLocation()` (single fix, not `startUpdatingLocation`). Bridge the delegate's
`didUpdateLocations`/`didFailWithError` to async via `withCheckedContinuation`, with a
single-resume guard (a stored optional continuation set to `nil` after first resume).

**Rationale**: `requestLocation()` delivers one fix and stops — no continuous tracking (FR-005).
Reduced accuracy is sufficient for weather and is the privacy-correct choice mandated by the
v1.3.0 exception. `CLLocationManager` is delegate-based and main-actor-affine, so a `@MainActor`
wrapper + continuation is the clean Swift 6 bridge. The whole service returns `WeatherSnapshot?`
and **never throws** — every failure path maps to `nil`.

**Alternatives**: `CLLocationUpdate.liveUpdates` async sequence — heavier, continuous-oriented,
overkill for one fix. Full accuracy — rejected (privacy; exception forbids finer precision).

## R3 — WeatherKit fetch + name collision

**Decision**: `try await WeatherKit.WeatherService.shared.weather(for: location)`, read
`currentWeather` → map `.condition.rawValue`, `.temperature` (convert to °C for storage),
`.symbolName`. Fully-qualify `WeatherKit.WeatherService` because our own protocol is named
`WeatherService`.

**Rationale**: `weather(for:)` returns the full set; we read only `currentWeather`. Storing a
canonical unit (°C) decouples persistence from display locale (display converts via
`MeasurementFormatter`, FR-010). `symbolName` is WeatherKit's condition-accurate SF Symbol,
covering all conditions for free (FR-003, FR-007).

**Alternatives**: Renaming our protocol to avoid the clash — unnecessary; qualification is
clearer about the boundary. Storing °F — rejected (locale coupling in storage).

## R4 — WeatherKit entitlement + attribution (deployment)

**Decision**: (1) Add `app-four.entitlements` with `com.apple.developer.weatherkit` and set
`CODE_SIGN_ENTITLEMENTS` in **both** pbxproj configs. (2) **Manual, user-only**: enable the
WeatherKit capability on App ID `Rythm-App.app-four` (team `SWFNK3KULQ`) in the developer portal.
(3) Show the mandatory **Apple Weather attribution** (the "Weather" mark + a link to
`weatherkit-legal-attribution` / Apple's data-source page) wherever weather appears — entry
detail row and the Insights card.

**Rationale**: Without the portal capability, WeatherKit fails at runtime on device (the #1 risk);
best-effort `nil` keeps the app from crashing, but no data returns until it's registered.
Attribution is an App Review gate per WeatherKit terms — must ship from day one.

**Alternatives**: Skipping attribution — rejected (rejection risk). Hiding attribution behind a
settings page only — insufficient; it must be near the data.

## R5 — Schema migration safety

**Decision**: Add `weatherJSON: String?` as an optional attribute. Verify on a seeded store that
the optional add performs a lightweight automatic migration and does **not** trigger the
wipe-on-mismatch recovery in [AppModelContainer.swift:45-57](../../app-four/App/AppModelContainer.swift#L45).

**Rationale**: Principle IX keeps the schema CloudKit-compatible (optional/defaulted, no unique);
an optional column is the lightest possible change. The wipe path is a pre-release safety net,
not an expected trigger for an additive optional field — but it must be confirmed, since a wipe
would nuke existing entries.

**Alternatives**: A separate `WeatherSnapshot` `@Model` with a relationship — heavier, adds a
schema entity and a relationship migration; rejected per Principle IV (the JSON-blob pattern is
already the house style for rich per-entry metadata).

## R6 — Insights correlation: statistic + threshold

**Decision**: Bucket `monthRecordings` by `decodedWeather?.conditionCode` (coarsened to a small
family set — e.g. clear / cloudy / rain / snow — not every raw WeatherKit case), average the
numeric `MoodLevel` per bucket (reuse existing mood-averaging in `InsightsViewModel+Signals`), and
surface the highest-vs-lowest bucket as one plain-language Connection. Gate on **≥5 weathered
entries spanning ≥2 condition families**.

**Rationale**: Reuses the existing `connections`/`signalAverages` machinery and the established
"plain-language insight" pattern; coarsening conditions avoids thin, noisy buckets. The threshold
prevents a misleading correlation from 1–2 data points (FR-008, SC-005). Exact families/threshold
are tunable; defined here so tasks are concrete.

**Alternatives**: Mood-vs-temperature scatter/regression — richer but more UI and easy to
over-read with sparse data; deferred. Per-raw-condition buckets — too sparse early on.

## R7 — Glyph: SF Symbol vs Canvas (design system)

**Decision**: Use WeatherKit's `symbolName` SF Symbol inline on the detail row and lists.
Optionally hand-draw a few BedIcon-style Canvas glyphs (clear/cloud/rain/snow) for the **Insights
hero card only**, later. Do **not** add weather to the `GlyphSignal` 1–5 ramp enum.

**Rationale**: Weather is ambient context, not a 1–5 self-state signal, so it doesn't belong in
the sprout/bolt/aperture ramp. SF Symbols match how the app still renders signals today and cover
every condition with zero hand-work. The Paper-&-Pollen Canvas treatment is a separable polish
step that can ship after capture+correlation (Principle IV: don't build it until needed).

**Alternatives**: Hand-draw the full WeatherKit condition set — large, low ROI. Force weather into
`GlyphSignal` — semantically wrong (it's not a level).

## R8 — Simulator vs device verification

**Decision**: Treat `MockWeatherService` as the source of truth for logic tests. For live checks,
use XcodeBuildMCP `set_sim_location` then run a check-in; but gate acceptance on a **real device**
(weather capability + attribution) because the simulator's WeatherKit can be flaky/unavailable.

**Rationale**: Mocks make the best-effort behavior deterministic and CI-safe; the device is the
only honest acceptance surface for live WeatherKit + the portal entitlement.

**Alternatives**: Simulator-only acceptance — rejected (flaky, can't validate the entitlement).
