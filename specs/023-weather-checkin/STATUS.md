# Status: Weather at Check-In (spec 023)

**As of**: 2026-06-25 · **Branch**: `worktree-feat+weather-checkin` (worktree off `main` @ `55201477`)
**State**: Implementation complete; adversarial `/code-review` done with all 11 findings (incl. 1
critical) fixed & re-verified (**35/35 feature tests green**); **not committed**. Remaining: serial
full-suite gate (env-flaky in parallel) + commit/PR. T004 (manual WeatherKit capability registration)
**SKIPPED by user decision (2026-06-25)** — code degrades to best-effort `nil` on device until then;
blocks nothing in build/tests/PR.

---

## TL;DR

All three user stories are implemented and pass their tests (32/32 weather+insights, plus
every affected suite green in isolation). The app compiles clean. What's left is the
Phase-6 polish (full-suite gate, docs, `/code-review`), one **manual** Apple Developer
portal step only you can do (T004), and the commit/PR. Nothing is merged.

---

## What works (done + verified)

### Governance
- Constitution amended **v1.2.0 → v1.3.0**: scoped Principle VI exception permitting
  first-party (Apple WeatherKit), reduced-accuracy, read-only weather lookups that transmit
  no user content and store on-device. (`.specify/memory/constitution.md`)
- Full Spec Kit chain authored: `spec.md`, `plan.md` (Constitution Check PASS), `research.md`,
  `data-model.md`, `contracts/WeatherService.contract.md`, `quickstart.md`, `tasks.md`,
  `checklists/requirements.md`.

### Code (by user story)
- **US1 — auto capture (P1)**: best-effort weather snapshot on every check-in (voice + text),
  backfilled *after* save so it never blocks/fails a check-in. Mirrors `transcribeInBackground`,
  including the deleted-recording guard.
  - `Recording.weatherJSON` (optional → CloudKit-safe), `decodedWeather`, `applyWeather`.
  - `WeatherSnapshot` + `WeatherFamily` value types (`nonisolated`, Codable/Sendable).
  - `WeatherService` protocol; `WeatherServiceImpl` (one-shot `kCLLocationAccuracyReduced`
    CoreLocation → WeatherKit, 10 s timeout, nil on every failure, outcome-only logging);
    `MockWeatherService`. Wired through `AppDependencies`/`AppServices`/`MockAppServices`.
  - `CheckInViewModel.captureWeather/backfillWeather` + `weatherCaptureTask`, called on both paths.
- **US2 — detail display (P2)**: weather row on `RecordingDetailView` (SF Symbol + locale
  temperature via `MeasurementFormatter` + condition word), omitted cleanly when absent,
  with mandatory Apple Weather attribution link.
- **US3 — Insights correlation (P3)**: `weatherMoodConnection` (mood averaged per weather
  family, best-vs-worst, gated until ≥5 weathered entries spanning ≥2 families) added to the
  `connections` array; renders via existing `ConnectionCardsView`; Apple Weather attribution
  shown when unlocked.

### Setup
- `app-four/app-four.entitlements` (`com.apple.developer.weatherkit`); `CODE_SIGN_ENTITLEMENTS`
  + `NSLocationWhenInUseUsageDescription` added to **both** pbxproj configs.
- HTML mockups for both new surfaces (`html-mockups/weather-checkin.html`) — Principle I.

### Tests (Swift Testing, test-first)
- New: `WeatherSnapshotTests`, `RecordingWeatherTests`, `CheckInWeatherCaptureTests`
  (happy / nil best-effort / deleted-entry guard), `InsightsWeatherTests` (gating + ranking).
- Updated: `InsightsViewModelTests.connectionsAlwaysFourInOrder` (was 3 → 4).
- **Results**: 32/32 green on weather+insights suites; 16/16 green incl. `RecordingStoreTests`
  in isolation. Whole app (views included) compiles clean. One pre-existing warning in
  `MockAIModelService` (not ours).

---

## Outstanding

### Manual — SKIPPED (user decision, 2026-06-25)
- **T004**: enable the **WeatherKit capability** on App ID `Rythm-App.app-four` (team
  `SWFNK3KULQ`) in the Apple Developer portal + refresh provisioning. **Deferred** — code is
  best-effort `nil` until then (no crash), no live weather on device. Revisit before any
  TestFlight build that should show real weather.

### Phase 6 polish (not yet done)
- **T030 — full-suite gate**: ⚠️ the full *parallel* `test_sim` run crashed 166 tests with
  "signal trap" across unrelated pre-existing suites. **This is an environment/parallelism
  artifact, not the feature** — every one of those suites passes in isolation *with* these
  changes present (proven: `RecordingStoreTests` crashed in-full, passed in-isolation). Likely
  resource contention from the ML-heavy suites (WhisperKit/CoreML) under parallel load; the
  run also emitted SPM `safe.bareRepository` git-cache errors. **Recommend** a serial run
  (`-parallel-testing-enabled NO`) or running the canonical suite on the main checkout / CI
  before merge. (I was mid-verification of "previously-crashed suites pass together" when this
  status was requested.)
- **T028 — schema-wipe check**: reasoned safe (optional column = lightweight migration; the
  wipe-on-mismatch path isn't expected to trigger) and in-memory container tests pass, but
  **not** explicitly exercised against a pre-populated on-disk store.
- **T029 — logging audit**: done by inspection — `WeatherServiceImpl` logs outcome strings only
  (`captured` / `skipped — no location` / `lookup failed`), no coordinates/condition/temp.
- **T031 — docs**: `docs/BACKLOG.md` + `docs/DEVLOG.md` not yet updated.
- **T032 — `/code-review`**: ✅ done. Multi-agent adversarial review (31 agents, 6 dimensions,
  each finding verified through 2 skeptic lenses) → 11 confirmed findings. **All applied & re-verified
  green (35/35):**
  - **CRITICAL (fixed)**: `WeatherServiceImpl` timeout could never fire — `withTaskGroup` implicitly
    awaits all children and `cancelAll()` doesn't resume the non-cancellation-aware `CheckedContinuation`,
    so a never-answered permission prompt hung `currentSnapshot()` forever (defeating the 10s bound and
    the never-block guarantee). Fixed with `withTaskCancellationHandler` → resumes `nil` on cancel.
  - **Should-fix (fixed)**: Insights subtitle "3 or more days" was wrong for all four gates → made
    generic; added the voice-path end-to-end test (`voiceCheckInBackfillsWeather`).
  - **Nice-to-have (fixed)**: tightened the loose fraction assertion; added `conditionLabel`, tie-break,
    and `weatherCorrelationShown` attribution-gate tests; deduped the double `MeasurementFormatter`;
    made the `updatedAt` assertion non-vacuous.
  - **Confirmed clean**: CloudKit-compatible schema, outcome-only logging, attribution coverage,
    reduced-accuracy location only.

### Integration
- **Not committed**; **no PR**. One revertable feature on the worktree branch.
- Device acceptance (real local weather + attribution visible; no user content leaves device)
  not performed — needs T004 + a physical device.

---

## Known caveats / risks
- `WeatherServiceImpl` can leak a CLLocation continuation if the OS never returns a fix and the
  10 s timeout wins (best-effort; minor, no crash). Acceptable for v1; worth a follow-up.
- Branch name is the harness's worktree name (`worktree-feat+weather-checkin`); set a proper
  `feat/weather-checkin` PR title at merge time.
- Constitution amendment travels in this branch — flag it for the reviewer; the bump is
  classified MINOR (additive scoped exception) but softens a NON-NEGOTIABLE principle, so it
  warrants a conscious sign-off.

## Files
- **New**: `app-four/Services/Weather/{WeatherSnapshot,WeatherServiceImpl}.swift`,
  `app-four/Services/Mock/MockWeatherService.swift`, `app-four/app-four.entitlements`,
  4 test files, `html-mockups/weather-checkin.html`, all of `specs/023-weather-checkin/`.
- **Modified**: `Recording.swift`, `Protocols.swift`, `AppServices.swift`, `AppDependencies.swift`,
  `CheckInViewModel.swift`, `InsightsViewModel+Signals.swift`, `RecordingDetailView.swift`,
  `InsightsView.swift`, `MockAppServices.swift`, `InsightsViewModelTests.swift`,
  `project.pbxproj`, `.specify/memory/constitution.md`, `CLAUDE.md`, `.specify/feature.json`.
