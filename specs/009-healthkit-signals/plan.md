# Implementation Plan: HealthKit Signals

**Branch**: `feat/healthkit-signals` | **Date**: 2026-06-20 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/009-healthkit-signals/spec.md`

## Summary

Add four passive health signals — sleep, activity, heart, menstrual cycle — read read-only from Apple Health, mirrored into a day-keyed SwiftData model (`DailySignals`) that the user can also edit by hand, including when Apple Health has no data. HealthKit access is quarantined behind a `HealthDataReading` protocol implemented by one `actor` that returns Sendable DTOs; a `@MainActor SignalSyncCoordinator` applies a "HealthKit-wins-unless-edited" per-group provenance merge and upserts rows via a `SignalsStore`. SwiftData is the source of truth; the UI never reads HealthKit directly. All four groups ship end-to-end (A8); the check-in→sleep bridge is excluded (A2); sleep renders with the bed icon + indigo + named `SleepLevel` scale, with the colour bead ramp deferred per DESIGN.md (A6). See [research.md](research.md), [data-model.md](data-model.md), [contracts/interfaces.md](contracts/interfaces.md), [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6.2 (strict concurrency)
**Primary Dependencies**: SwiftUI, SwiftData, HealthKit (read-only), Swift Concurrency
**Storage**: SwiftData (`DailySignals`), single shared `@MainActor` main context (`AppModelContainer.container.mainContext`); CloudKit not configured but schema kept CloudKit-compatible
**Testing**: Swift Testing (`@Test`/`#expect`), in-memory `ModelContainer`; `@testable import app_four`
**Target Platform**: iOS 26+ (iPhone primary)
**Project Type**: Mobile app (single Xcode target `app-four` + `app-fourTests`)
**Performance Goals**: read-on-open sync of ~30 days is non-blocking (off-main actor reads); UI renders immediately from SwiftData
**Constraints**: on-device only (no egress of health data); no `@Attribute(.unique)`, all attributes optional/defaulted (Constitution IX); read-only (no HealthKit write-back)
**Scale/Scope**: one row/day (~365/yr); 4 signal groups; ~6 new logic types + 3 new SwiftUI views

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.* (v1.2.0)

| Principle | Verdict | Justification |
|---|---|---|
| **I. SwiftUI-First** | PASS | All UI is SwiftUI on iOS 26 APIs. 3 new views; each is gated by an HTML mockup before SwiftUI (Task: mockup gate). |
| **II. Test-Build-Ship** | PASS | Every task ends green; full suite + app build before done (quickstart). |
| **III. Correctness Over Speed** | PASS | No shims/stubs/dead code. Research corrected two real bugs (flow enum, `@Attribute(.unique)`) rather than carrying them. |
| **IV. Minimal Surface** | PASS | Reuses existing seams (Services/AppDependencies, RecordingStore pattern, `SleepLevel`/`SignalLevel`). No flags, no speculative abstraction. A2 bridge excluded. |
| **V. Solo Git Discipline** | PASS | One revertable feature on `feat/healthkit-signals`; `/code-review` before merge; `main` stays releasable. |
| **VI. On-Device Privacy** | PASS | HealthKit read-only, on-device; no egress (FR-016); store excluded from iCloud backup; logs counts/durations only (C4). |
| **VII. Deterministic, Measured Extraction** | N/A | No NLP/extraction change. Excluding the A2 bridge keeps the extraction path untouched. |
| **VIII. Service-Oriented Architecture** | PASS | `HealthDataReading` protocol in `Services/`, injected via `AppServices`/`AppDependencies`, mocked at the seam; `@MainActor @Observable` VM; HealthKit reads off-main in an `actor`. |
| **IX. Pre-Release Data Posture** | PASS | `DailySignals` has **no** `@Attribute(.unique)`; all attributes optional/defaulted; `isMockData` partition; `#if DEBUG` wipe covers schema change. No Complexity Tracking deviation needed (research D1). |
| **X. Test-First Development** | PASS | All logic (model, store, coordinator, mapping, VM) is RED→GREEN→refactor with Swift Testing; views exempt (build + run + mockup). `/speckit-tasks` orders each test before its implementation. |

**Result: PASS (pre-Phase 0).** Post-design re-check below — still PASS, no new violations.

**Note (not a violation of this feature)**: research surfaced a pre-existing IX breach — `Recording`/`AppSettings`/`ModelMetadata`/`TranscriptionSegment` use `@Attribute(.unique) var id: UUID`. Out of scope here; recommend a separate backlog cleanup. `DailySignals` does not copy the pattern.

## Project Structure

### Documentation (this feature)

```text
specs/009-healthkit-signals/
├── plan.md              # this file
├── spec.md              # /speckit-specify + /speckit-clarify output
├── research.md          # Phase 0 (D1–D7, cited)
├── data-model.md        # Phase 1
├── contracts/
│   └── interfaces.md    # Phase 1 (service/coordinator/store/UI/platform seams)
├── quickstart.md        # Phase 1 (validation guide)
└── tasks.md             # /speckit-tasks output (next)
```

### Source Code (repository root)

```text
app-four/Models/
  DailySignals.swift            # @Model, source of truth (no @Attribute(.unique))
  SignalSource.swift            # enum
  MenstrualFlow.swift           # enum
  # (SleepLevel+SignalLevel.swift CUT — sleep colour ramp deferred per DESIGN.md; A6/D5)

app-four/Services/HealthKit/
  HealthSignalsDTO.swift        # Sendable DTOs + SignalDayKey
  HealthDataReading.swift       # protocol + HealthAuthorizationState
  HealthKitSampleMapping.swift  # pure mapping funcs (flow, sleep efficiency→SleepLevel)
  HealthKitServiceImpl.swift    # actor — the ONLY import HealthKit

app-four/Store/
  SignalsStore.swift            # @MainActor @Observable upsert/fetch by day
  SignalSyncCoordinator.swift   # merge rule + sync orchestration

app-four/ViewModels/
  DaySignalsEditorViewModel.swift

app-four/Views/Signals/
  DaySignalsEditorSheet.swift   # after mockup gate
  DaySignalsSummaryView.swift   # after mockup gate
  HealthAccessPrimerView.swift

app-fourTests/
  Mocks/MockHealthDataReading.swift
  DailySignalsTests.swift
  SignalDayKeyTests.swift
  SignalsStoreTests.swift
  SignalSyncCoordinatorTests.swift
  HealthKitSampleMappingTests.swift
  DaySignalsEditorViewModelTests.swift
```

Modified: `app-four/App/AppModelContainer.swift` (register `DailySignals.self` in both Schema arrays, :9-16 & :63-70); `app-four/Store/AppServices.swift` (+`healthService`, after `summarizationService` :10-27); `app-four/Store/AppDependencies.swift` (construct service + coordinator + store); `app-fourTests/Mocks/MockAppServices.swift` (+mock); `app-four/Info.plist` (+`NSHealthShareUsageDescription`); `app-four.xcodeproj` (HealthKit capability → `app-four.entitlements`, manual Xcode step).

**Structure Decision**: Single mobile target. New code is grouped by layer matching the existing convention (`Models/`, `Services/<Feature>/`, `Store/`, `ViewModels/`, `Views/<Feature>/`), with HealthKit isolated under `Services/HealthKit/` so exactly one file imports the framework.

## Complexity Tracking

> No entries. The one potential deviation (`@Attribute(.unique)` on `dayStart`) is **removed**, not justified — uniqueness moves to `SignalsStore.upsert` (research D1), which keeps Constitution IX satisfied with no added complexity.
