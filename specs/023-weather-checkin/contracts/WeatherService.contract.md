# Contract: `WeatherService` (internal service seam)

The only new interface this feature exposes. Internal protocol (Principle VIII seam), injected via
`AppDependencies`/`AppServices`, mockable at the boundary.

## Protocol

```swift
protocol WeatherService: Sendable {
    /// Best-effort current-weather snapshot for the device's location.
    /// Returns nil on EVERY failure mode (permission denied/restricted, no location,
    /// offline, WeatherKit error, timeout). NEVER throws. NEVER blocks indefinitely.
    func currentSnapshot() async -> WeatherSnapshot?
}
```

### Behavioral contract

| Condition | Required behavior |
|-----------|-------------------|
| Permission `notDetermined` | Request when-in-use authorization once; proceed with the resolved status. |
| Permission denied/restricted | Return `nil`. Do not prompt again. |
| Authorized, fix obtained, WeatherKit ok | Return a fully-populated `WeatherSnapshot`. |
| Location fix fails / times out | Return `nil`. |
| WeatherKit throws / offline | Return `nil`. |
| Any path | MUST NOT throw; MUST NOT start continuous location updates; MUST use reduced accuracy. |
| Logging | Outcome enum only (`captured`/`denied`/`offline`/`error`) — never coordinates/condition/temp. |

### Consumer contract (`CheckInViewModel.backfillWeather(for:)`)

1. Entry is already inserted + saved before this runs (best-effort, off the confirmation path).
2. `await weatherService.currentSnapshot()`.
3. If non-nil **and** the recording still exists (not deleted): `recording.applyWeather(snapshot)`
   then `store.save()`.
4. If nil: do nothing (entry stays weather-less). No user-visible error.
5. Invoked identically from the voice path (`attemptSave`) and the text path (`saveTextCheckIn`).

## Test contract (Swift Testing, test-first — Principle X)

`MockWeatherService` is configurable to return a fixed snapshot **or** `nil`.

- `currentSnapshot()` mapping: given a stub WeatherKit-like input, the produced `WeatherSnapshot`
  has the expected `conditionCode`/`temperatureC`/`symbolName`. *(mapping unit, no device)*
- `WeatherSnapshot` Codable round-trips losslessly.
- `Recording.applyWeather` then `decodedWeather` returns an equal snapshot; `updatedAt` advances.
- **Best-effort**: with `MockWeatherService` returning `nil`, a check-in still completes and the
  recording persists with `weatherJSON == nil`.
- **Deleted-entry guard**: if the recording is deleted before backfill resolves, no write/crash.
- Insights correlation: with seeded weathered entries across ≥2 families, the correlation is
  produced; below threshold it is absent.

## Out of scope (this contract)

- UI rendering (verified by build + simulator/device run per Principle I/II).
- The live WeatherKit network call (verified on device; mocked in tests).
