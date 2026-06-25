# Quickstart / Validation: Weather at Check-In

How to prove the feature works end-to-end. References [data-model.md](./data-model.md),
[contracts/WeatherService.contract.md](./contracts/WeatherService.contract.md), and the
[spec](./spec.md) acceptance scenarios.

## Prerequisites

- **Manual (user-only)**: WeatherKit capability enabled on App ID `Rythm-App.app-four` (team
  `SWFNK3KULQ`) in the Apple Developer portal. Without it, live WeatherKit returns nothing on device.
- `app-four.entitlements` present with `com.apple.developer.weatherkit`; `CODE_SIGN_ENTITLEMENTS`
  set in both pbxproj configs; `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` set in both configs.
- HTML mockups for the weather row + Insights card exist under `html-mockups/` (Principle I).

## 1. Unit / logic tests (no device) — run first, expect RED then GREEN

```bash
# via XcodeBuildMCP test_sim (session defaults configured)
#   targets: WeatherSnapshotTests, RecordingWeatherTests,
#            CheckInWeatherCaptureTests, InsightsWeatherTests
```

Expected: snapshot Codable round-trip; `applyWeather`/`decodedWeather` equality + `updatedAt`
bump; best-effort (nil snapshot still lands the check-in); deleted-entry guard; Insights gating.

## 2. Build

```bash
# XcodeBuildMCP build_sim — must compile clean (Swift 6 strict concurrency)
```

## 3. Simulator smoke (best-effort live path)

1. `set_sim_location` to a known coordinate (e.g. San Francisco 37.7749, -122.4194).
2. Launch app, grant location when prompted.
3. Make a **voice** check-in → confirm it completes instantly; within a moment the entry shows a
   weather row (icon + temp + condition) on detail. *(SC-001, AS-1)*
4. Make a **text** check-in → same. *(AS-2)*
5. Open the entry detail → weather row + **Apple Weather attribution** visible. *(FR-007, FR-009)*

> Simulator WeatherKit can be flaky — if no data returns, verify on device (step 5b).

## 4. Best-effort / privacy validation

- Deny location (Settings → reset) → make a check-in → it completes with no delay and **no**
  weather, no error. *(AS-3, SC-003)*
- Enable Airplane Mode → make a check-in → completes, weather-less, silent. *(AS-4, SC-003)*
- Confirm older/pre-feature entries render with no weather area. *(FR-011)*

## 5. Insights correlation

- Seed ≥5 weathered entries spanning ≥2 condition families (mock data or repeated check-ins with
  `set_sim_location` varied) → open Insights → a plain-language mood↔weather summary appears.
  *(US3, SC-005)*
- With fewer than the threshold → summary absent (not empty/misleading). *(AS-2 of US3)*

## 5b. Device acceptance (the honest gate)

On a real device with the capability registered: a real check-in shows correct **local** weather;
attribution present; no audio/transcript/mood data leaves the device (spot-check with a network
proxy if desired — only a coarse-location WeatherKit request should appear). *(SC-006, FR-006)*

## Definition of done

- All Swift Testing logic tests green; `build_sim` + `test_sim` clean (Principle II/X).
- Acceptance scenarios AS-1…AS-5 (US1), US2, US3 verified.
- Attribution visible wherever weather shows; no coordinates/condition in logs.
- `/code-review` run on the diff before merge (Principle V).
