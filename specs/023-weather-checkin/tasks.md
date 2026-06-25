# Tasks: Weather at Check-In

**Feature**: 023-weather-checkin | **Branch**: `feat/weather-checkin`
**Spec**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md) · **Contract**: [contracts/WeatherService.contract.md](./contracts/WeatherService.contract.md)

**Constitution**: v1.3.0. Test-first is MANDATORY (Principle X) — every logic task has a RED test
before it. New UI requires an HTML mockup first (Principle I). `build_sim` + `test_sim` must be
green before done (Principle II).

**Conventions**: `[P]` = parallelizable (different files, no incomplete deps). Test target assumed
`app-fourTests` (Swift Testing `@Test`/`#expect`).

---

## Implementation status (2026-06-25)

- **Done & feature-tested green**: T001–T003 (setup), T005–T011 (foundational), T012–T019 (US1
  capture + WeatherServiceImpl), T020–T022 (US2 detail), T023–T027 (US3 Insights), T029 (logging
  audit — outcome-only, by inspection).
- **Skipped (owner)**: **T004** WeatherKit capability registration — best-effort `nil` on device until done.
- **Partial / reasoned**: T028 schema-wipe — optional add reasoned-safe + in-memory containers pass,
  not exercised on a pre-populated on-disk store.
- **Outstanding**: T030 full-suite gate (parallel run env-flaky → needs serial/CI), T031 docs
  (DEVLOG/BACKLOG ✅ done), T032 `/code-review` (adversarial multi-agent review running).

See [STATUS.md](./STATUS.md) for the authoritative current state.

---

## Phase 1: Setup (shared infrastructure)

- [ ] T001 [P] Create `app-four/Services/Weather/` directory and an empty `app-four/app-four.entitlements` containing the `com.apple.developer.weatherkit` boolean key.
- [ ] T002 Set `CODE_SIGN_ENTITLEMENTS = app-four/app-four.entitlements` in BOTH Debug and Release build configs in `app-four.xcodeproj/project.pbxproj`.
- [ ] T003 Add `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "Squirl uses your location to note the weather alongside each check-in, so you can spot mood patterns."` to BOTH Debug and Release configs in `app-four.xcodeproj/project.pbxproj`.
- [ ] T004 **[MANUAL — user only]** Enable the WeatherKit capability on App ID `Rythm-App.app-four` (team `SWFNK3KULQ`) in the Apple Developer portal and refresh the provisioning profile. Document in the PR description that live WeatherKit returns nothing on device until this is done (best-effort `nil` until then). *(No code; blocks device acceptance, not the build.)*

**Checkpoint**: Project builds with the new entitlement + plist keys wired (no behavior yet).

---

## Phase 2: Foundational (BLOCKS all user stories)

> Value type, model field, service seam, mock, and DI — every story depends on these. Test-first.

### Tests first (RED)

- [ ] T005 [P] Write `app-fourTests/WeatherSnapshotTests.swift`: `WeatherSnapshot` Codable round-trips losslessly (conditionCode/temperatureC/symbolName/capturedAt) and `conditionFamily` maps representative `conditionCode`s to clear/cloudy/rain/snow/other. Confirm RED (type doesn't exist yet).
- [ ] T006 [P] Write `app-fourTests/RecordingWeatherTests.swift`: `Recording.applyWeather(_:)` then `decodedWeather` returns an equal snapshot and `updatedAt` advances; a fresh `Recording` has `decodedWeather == nil`. Confirm RED.

### Implementation (GREEN)

- [ ] T007 [P] Create `app-four/Services/Weather/WeatherSnapshot.swift`: `struct WeatherSnapshot: Codable, Sendable { conditionCode, temperatureC, symbolName, capturedAt }` + a `conditionFamily` computed mapping (per [data-model.md](./data-model.md)). Make T005 GREEN.
- [ ] T008 Add `var weatherJSON: String?` to `app-four/Models/Recording.swift` (beside `sleepEventJSON`), add `weatherJSON: String? = nil` to `init`, add `var decodedWeather: WeatherSnapshot?` (NOT `@MainActor`) and `func applyWeather(_:)` writer (JSON-encode + bump `updatedAt`). Make T006 GREEN. *(Depends T007.)*
- [ ] T009 [P] Add `protocol WeatherService: Sendable { func currentSnapshot() async -> WeatherSnapshot? }` to `app-four/Services/Protocols.swift` (per the contract: never throws, nil on every failure). *(Depends T007.)*
- [ ] T010 [P] Create `app-four/Services/Mock/MockWeatherService.swift`: configurable to return a fixed `WeatherSnapshot` or `nil`. *(Depends T009.)*
- [ ] T011 Wire `WeatherService` into `app-four/Store/AppDependencies.swift` (real impl placeholder until US1) and expose it through the `AppServices` bundle in `app-four/Store/AppServices.swift`; inject it into `CheckInViewModel` init. Use `MockWeatherService` in the preview/mock bundle. *(Depends T009, T010.)*

**Checkpoint**: `test_sim` green for T005–T006; schema compiles with the optional field; DI resolves. No capture wired yet.

---

## Phase 3: User Story 1 — Weather recorded automatically (P1) 🎯 MVP

**Goal**: Every voice + text check-in best-effort-captures weather AFTER save, never blocking.
**Independent test**: Mock check-ins land weather when the service returns a snapshot; still
complete with no weather (and no error/delay) when it returns nil or the entry was deleted.

### Tests first (RED)

- [ ] T012 [P] [US1] Write `app-fourTests/CheckInWeatherCaptureTests.swift` — voice path: with `MockWeatherService` returning a snapshot, `attemptSave` results in the saved `Recording` getting `decodedWeather != nil` after backfill. Confirm RED.
- [ ] T013 [P] [US1] In the same test file, text path: `saveTextCheckIn` backfills weather onto the persisted `Recording`. Confirm RED.
- [ ] T014 [P] [US1] Best-effort + guard cases: (a) `MockWeatherService` returning `nil` ⇒ check-in completes, `weatherJSON == nil`, no error; (b) recording deleted before backfill resolves ⇒ no write, no crash. Confirm RED.

### Implementation (GREEN)

- [ ] T015 [US1] Add `private func backfillWeather(for recording: Recording)` to `app-four/ViewModels/CheckInViewModel.swift`: detached task → `await weatherService.currentSnapshot()` → if non-nil AND recording still present, `recording.applyWeather(...)` + `store.save()`. Mirror the `transcribeInBackground` guard. Make T014 GREEN.
- [ ] T016 [US1] Call `backfillWeather(for:)` from the voice path after `store.addRecording(recording)` / `state = .done` in `attemptSave` (`app-four/ViewModels/CheckInViewModel.swift`). Make T012 GREEN.
- [ ] T017 [US1] Call `backfillWeather(for:)` from `saveTextCheckIn` on the `Recording` returned by `store.persistCheckInNote(...)` (`app-four/ViewModels/CheckInViewModel.swift`). Make T013 GREEN.
- [ ] T018 [US1] Implement `app-four/Services/Weather/WeatherServiceImpl.swift`: `@MainActor` `CLLocationManager` wrapper, `requestWhenInUseAuthorization` lazily, `kCLLocationAccuracyReduced`, `requestLocation()` one-shot bridged to async via `withCheckedContinuation` (single-resume guard); then `try await WeatherKit.WeatherService.shared.weather(for:)` → map `currentWeather` → `WeatherSnapshot`; return `nil` on every failure; never throws. Log outcome enum only (no coords/condition/temp).
- [ ] T019 [US1] Swap the real `WeatherServiceImpl` into `app-four/Store/AppDependencies.swift` (production), keeping the mock in previews/tests.

**Checkpoint**: US1 independently testable — `test_sim` green; a simulator check-in with `set_sim_location` attaches weather; denied/offline still completes instantly.

---

## Phase 4: User Story 2 — See weather on a past entry (P2)

**Goal**: Entry detail shows the snapshot (icon + temp + condition) with Apple Weather attribution;
absent cleanly when no snapshot.
**Independent test**: Open an entry with a snapshot → weather + attribution render; open one without
→ no placeholder, no error.

- [ ] T020 [US2] Create an HTML mockup of the entry-detail weather row (Paper & Pollen, attribution placement) under `html-mockups/` — REQUIRED before SwiftUI (Principle I).
- [ ] T021 [US2] Add a weather row to the entry detail view: render `recording.decodedWeather` via WeatherKit `symbolName` SF Symbol + locale temperature (`MeasurementFormatter` over °C) + condition word; omit entirely when `decodedWeather == nil` (FR-007, FR-010, FR-011).
- [ ] T022 [US2] Add the mandatory Apple Weather attribution (mark + legal/data-source link) to the detail weather row (FR-009). *(Depends T021.)*

**Checkpoint**: Build + simulator run shows weather on weathered entries with attribution; weather-less entries render clean.

---

## Phase 5: User Story 3 — Mood↔weather correlation in Insights (P3)

**Goal**: A gated, plain-language correlation ("mood averages higher on clear days").
**Independent test**: Seeded weathered entries across ≥2 families → summary appears; below threshold → absent.

### Test first (RED)

- [ ] T023 [P] [US3] Write `app-fourTests/InsightsWeatherTests.swift`: bucketing by `conditionFamily` + per-bucket `MoodLevel` average produces the expected highest/lowest result; gating returns nothing below ≥5 weathered entries spanning ≥2 families. Confirm RED.

### Implementation (GREEN)

- [ ] T024 [US3] Add a `weatherMoodConnection` computed property to `app-four/ViewModels/InsightsViewModel+Signals.swift`: bucket `monthRecordings` by `decodedWeather?.conditionFamily`, average mood per bucket (reuse existing averaging), gate at ≥5 entries / ≥2 families. Make T023 GREEN.
- [ ] T025 [US3] Create an HTML mockup of the Insights weather-correlation card under `html-mockups/` — REQUIRED before SwiftUI (Principle I).
- [ ] T026 [US3] Add a gated correlation section to `app-four/Views/Insights/InsightsView.swift` using the existing `InsightsSectionHeader` + bar/gauge pattern; render `weatherMoodConnection`, hidden when nil. *(Depends T024, T025.)*
- [ ] T027 [US3] Add Apple Weather attribution to the Insights weather card (FR-009). *(Depends T026.)*

**Checkpoint**: Insights shows the correlation with seeded data; hidden below threshold.

---

## Phase 6: Polish & Cross-Cutting

- [ ] T028 [P] Verify the optional `weatherJSON` add does NOT trigger the wipe-on-mismatch recovery in `app-four/App/AppModelContainer.swift` (load a pre-existing seeded store; confirm entries survive) — research R5 / Principle IX.
- [ ] T029 [P] Audit logging for Principle VI: confirm no coordinates, `conditionCode`, or temperature are logged anywhere in the capture path — outcome enum only.
- [ ] T030 Run full `build_sim` + `test_sim` green gate (Principle II); fix any Swift 6 strict-concurrency diagnostics.
- [ ] T031 [P] Update `docs/BACKLOG.md` (move Weather-at-Check-In to 🔨 In code with branch/PR) and add a `docs/DEVLOG.md` checkpoint (the WHY: HWF-inspired, Principle VI amendment, best-effort design).
- [ ] T032 Run `/code-review` on the diff and address findings before opening the PR (Principle V).

---

## Dependencies & Execution Order

- **Setup (P1: T001–T004)** → **Foundational (P2: T005–T011)** block everything.
- **US1 (P3)** depends only on Foundational → this is the **MVP**.
- **US2 (P4)** depends on Foundational (`decodedWeather`); independent of US1's capture for rendering (can be tested with seeded snapshots), but only meaningful after US1 produces data.
- **US3 (P5)** depends on Foundational (`conditionFamily`, `decodedWeather`); meaningful after US1.
- **Polish (P6)** last.

```text
Setup → Foundational → US1 (MVP) → US2 → US3 → Polish
                         └─────────┴── US2/US3 parallelizable after Foundational
```

## Parallel opportunities

- T005/T006 (tests) parallel; T007/T009/T010 parallel after; T001/T003 parallel in setup.
- T012/T013/T014 (US1 tests) parallel.
- After Foundational, US2 and US3 work streams can proceed in parallel (different files).
- T028/T029/T031 parallel in polish.

## MVP scope

**Phase 1 + Phase 2 + Phase 3 (US1)** = weather is captured and persisted best-effort on every
check-in. That alone is a shippable, revertable increment; US2 (display) and US3 (insights) layer on.

## Format validation

All tasks use `- [ ] T### [P?] [US#?] description + file path`. Setup/Foundational/Polish carry no
story label; US phases carry `[US1]`/`[US2]`/`[US3]`. Test tasks precede their implementation (Principle X).
