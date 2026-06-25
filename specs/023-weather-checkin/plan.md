# Implementation Plan: Weather at Check-In

**Branch**: `feat/weather-checkin` | **Date**: 2026-06-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/023-weather-checkin/spec.md`

## Summary

Capture current weather automatically on every check-in (voice + text) and freeze a
`WeatherSnapshot` (condition, temperature, SF-symbol, capture time) onto the `Recording`.
Capture is best-effort and runs **after** the entry is saved — mirroring the existing
`transcribeInBackground` pattern — so a denied permission, offline state, or service error
never blocks or fails a check-in. Weather shows on the entry detail and powers a
mood↔weather correlation in Insights. Allowed under Constitution **v1.3.0** (scoped
Principle VI weather exception): only coarse location is sent to first-party Apple WeatherKit;
no user content leaves the device; the snapshot is stored on-device.

## Technical Context

**Language/Version**: Swift 6 (strict concurrency)

**Primary Dependencies**: SwiftUI, SwiftData, WeatherKit, CoreLocation (one-shot, reduced
accuracy), Swift Concurrency

**Storage**: SwiftData — new optional `weatherJSON: String?` attribute on the existing
`Recording` `@Model`; weather encoded as JSON (mirrors `sleepEventJSON`/`emotionsJSON`)

**Testing**: Swift Testing (`@Test`/`#expect`), test-first per Principle X; `MockWeatherService`
in `Services/Mock/`

**Target Platform**: iOS 26+ (device floor iPhone 12 / A14; WeatherKit needs iOS 16+ — no blocker)

**Project Type**: Single-target iOS app (`app-four`, display name Squirl, bundle `Rythm-App.app-four`)

**Performance Goals**: Check-in confirmation must be instant — weather adds zero perceptible
latency (SC-002); capture happens off the confirmation path.

**Constraints**: Best-effort capture (never blocks check-in); offline-capable check-ins;
coarse location only; no continuous/background location; mandatory Apple Weather attribution.

**Scale/Scope**: New service + value type; 1 model field; 2 capture call-sites; 1 detail row;
1 Insights correlation; entitlement + Info.plist keys; HTML mockups for the 2 new UI surfaces.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Per `.specify/memory/constitution.md` (**v1.3.0**).

- [x] **I. SwiftUI-First** — Weather row + Insights card are SwiftUI on iOS 26 APIs. **New UI ⇒
      HTML mockups required first** (tasks include `html-mockups/` for both surfaces before SwiftUI).
- [x] **II. Test-Build-Ship** — change is buildable + fully tested; `build_sim` + `test_sim` green
      before done.
- [x] **III. Correctness Over Speed** — no shims/stubs; best-effort failure is explicit, not silent
      corner-cutting; the privacy tradeoff is surfaced (spec + amendment).
- [x] **IV. Minimal Surface** — one protocol, one impl, one mock, one model field, one snapshot
      type. No flags, no speculative dimensions (humidity/wind deferred). Snapshot stored as JSON
      blob, reusing the existing pattern rather than a new relationship.
- [x] **V. Solo Git Discipline** — one revertable feature on `feat/weather-checkin`; `/code-review`
      before merge; bundles the constitution amendment it depends on for reviewer context.
- [x] **VI. On-Device Privacy** — **PASS under the v1.3.0 scoped exception.** Only coarse location
      → first-party Apple WeatherKit; NO audio/transcript/mood/health/medication transmitted;
      weather stored on-device; logs stay counts/durations (no coordinates, no condition text in logs).
- [x] **VII. Deterministic, Measured Extraction** — N/A: weather does not touch `NLNoteExtractor`
      or the lexicon; no eval impact.
- [x] **VIII. Service-Oriented Architecture** — `WeatherService` protocol in `Services/Weather/`,
      injected via `AppDependencies`/`AppServices`, mockable; capture runs off the main actor;
      `CheckInViewModel` stays `@MainActor @Observable` and holds no persistence logic.
- [x] **IX. Pre-Release Data Posture** — `weatherJSON: String?` is optional/defaulted, no
      `@Attribute(.unique)`; schema stays CloudKit-compatible. No migration plan needed; verify the
      optional add does not trip the wipe-on-mismatch recovery.
- [x] **X. Test-First Development** — `WeatherSnapshot` mapping/Codable, `Recording.decodedWeather`/
      `applyWeather`, the capture-backfill best-effort behavior, and the Insights correlation are
      all built RED→GREEN with Swift Testing + `MockWeatherService`. SwiftUI views exempt (build+run).

**Result: PASS** (no violations → Complexity Tracking left empty).

## Project Structure

### Documentation (this feature)

```text
specs/023-weather-checkin/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (WeatherService.contract.md)
├── checklists/
│   └── requirements.md  # spec quality checklist
└── tasks.md             # Phase 2 (/speckit-tasks — not created here)
```

### Source Code (repository root)

```text
app-four/
├── Models/
│   └── Recording.swift                 # + weatherJSON, init param, decodedWeather, applyWeather
├── Services/
│   ├── Protocols.swift                 # + WeatherService protocol
│   ├── Weather/                         # NEW
│   │   ├── WeatherSnapshot.swift        # Codable/Sendable value type
│   │   └── WeatherServiceImpl.swift     # CoreLocation one-shot + WeatherKit
│   └── Mock/
│       └── MockWeatherService.swift     # NEW — fixed snapshot / configurable nil
├── Store/
│   ├── AppDependencies.swift            # wire WeatherService
│   ├── AppServices.swift                # expose in bundle
│   └── RecordingStore.swift             # text path already returns inserted Recording
├── ViewModels/
│   ├── CheckInViewModel.swift           # backfillWeather(for:) on both save paths
│   └── InsightsViewModel+Signals.swift  # mood↔weather correlation
├── Views/
│   ├── <EntryDetail>.swift              # weather row (symbolName + temp + condition + attribution)
│   └── Insights/InsightsView.swift      # gated correlation section + attribution
├── DesignSystem/Glyphs/                 # (optional, later) Canvas weather glyphs for Insights hero
├── Info.plist                           # (keys live in pbxproj — see below)
└── app-four.entitlements                # NEW — com.apple.developer.weatherkit

app-fourTests/ (or existing test target)
└── WeatherSnapshotTests / RecordingWeatherTests / CheckInWeatherCaptureTests / InsightsWeatherTests

html-mockups/                            # NEW mockups for weather row + Insights card (Principle I)

app-four.xcodeproj/project.pbxproj       # INFOPLIST_KEY_NSLocationWhenInUseUsageDescription +
                                         # CODE_SIGN_ENTITLEMENTS (both Debug & Release)
```

**Structure Decision**: Single-target iOS app. The feature follows the established
service-behind-protocol + DI seam (Principle VIII) and the JSON-blob metadata pattern on
`Recording` (Principle IX), adding exactly one new service area (`Services/Weather/`).

## Complexity Tracking

> No Constitution violations — table intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| — | — | — |
