<!-- Created: 2026-07-03 17:50 (WEST) · Updated: 2026-07-03 17:50 (WEST) -->
# Implementation Plan: Calendar Day Context — "The Day, Remembered" (Phase 1)

**Branch**: `feat/029-calendar-day-context` | **Date**: 2026-07-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/029-calendar-day-context/spec.md` (clarified 2026-07-03, checklist 16/16). Design authority: [2026-07-03-calendar-integration-design.md](../../docs/superpowers/specs/2026-07-03-calendar-integration-design.md).

## Summary

Give every check-in day a durable, on-device snapshot of what the user's calendar held — captured at check-in save (plus a self-healing backfill sweep), stored as a day-keyed SwiftData model, rendered as a classified one-line summary on day cards ("3 meetings · Dentist · Mum's birthday"). EventKit is read behind a new actor service; nothing is written to the calendar, nothing leaves the device, and the whole pipeline is disabled in mock mode. Full research in [research.md](research.md) (decisions D1–D13); entities in [data-model.md](data-model.md); seams in [contracts/](contracts/calendar-context-service.md); validation in [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 5 language mode, MainActor-default isolation + Approachable Concurrency (Xcode 16 / Swift 6.2 toolchain)

**Primary Dependencies**: EventKit (new — first use in the app), SwiftUI, SwiftData, Swift Concurrency. No third-party additions.

**Storage**: SwiftData — new `DayCalendarContext` @Model (day-keyed, JSON payload column, no unique constraints), registered in both `AppModelContainer` schemas; UserDefaults/@AppStorage for preferences (5 keys, data-model.md)

**Testing**: Swift Testing (`@Test`/`#expect`), test-first per Constitution X; new actor mock `MockCalendarContextService` extends the existing 7-mock pattern; suite runs serial (parallel is known-flaky)

**Target Platform**: iOS 17.0+ (iPhone primary, iPad secondary) — matches the deployment target; `requestFullAccessToEvents` is iOS 17+ so no availability gates needed

**Project Type**: Mobile app, single Xcode target (`app-four`), Xcode 16 synchronized folders (file adds don't touch pbxproj)

**Performance Goals**: capture adds no visible wait to check-in save (SC-002 — hook runs after persistence, alongside existing background transcription); backfill of ~300 days completes < 5 min (SC-007 — local queries, batched newest-first)

**Constraints**: on-device only (Constitution VI); no attendee identities/locations/notes captured (FR-002); no `@Attribute(.unique)` (Constitution IX); real calendar never read in mock mode; iOS may terminate the app on a mid-run permission toggle (research D2 — handled by foreground re-check)

**Scale/Scope**: 1 new @Model + payload structs · 1 service protocol + actor impl + mock · 1 store · 1 coordinator · 3 new UI surfaces (invitation card, explainer sheet, Settings section) + day-card line extension · export DTO + version bump · ~6 new test suites · 3 HTML mockups

## Constitution Check

*GATE: evaluated pre-Phase-0 and re-checked post-design — both PASS.*

- [x] **I. SwiftUI-First** — all new UI is SwiftUI; EventKit is a framework, not UI. Mockup gate honored: context line already mocked ([mockups/context-line-variants.html](mockups/context-line-variants.html), approved variant B); invitation card, explainer sheet, and Settings section get HTML mockups before SwiftUI (explicit tasks).
- [x] **II. Test-Build-Ship** — quickstart defines build + serial-suite gates; PR only after green.
- [x] **III. Correctness Over Speed** — the one deliberate scope cut (no full-event-list UI) is spec'd (Clarifications Q2), not silent; captured payload retains the full set so no dead-end.
- [x] **IV. Minimal Surface** — no per-event exclusion, no EKEventStoreChanged live-refresh (point-in-time capture is the spec's model), no background tasks; the coordinator exists because three trigger paths + sweep share orchestration (justified below in Complexity Tracking — no violation, documented anyway).
- [x] **V. Solo Git Discipline** — one branch `feat/029-calendar-day-context`, one revertable PR, `/code-review` before merge.
- [x] **VI. On-Device Privacy** — EventKit is local; capture stores 5 facts/event, never identities; export-only egress inside the user-encrypted archive (FR-011 + disclosure copy task); logging counts/durations only (no titles in logs — explicit review point).
- [x] **VII. Deterministic, Measured Extraction** — **N/A with note**: `NLNoteExtractor`, the lexicon, and the eval harness are untouched; event classification is deterministic attendee-count logic, not NLP. No eval run required.
- [x] **VIII. Service-Oriented Architecture** — `CalendarContextService` protocol in `Services/Protocols.swift`, actor impl, composed in `AppDependencies`, injected via `AppServices`; `DayContextStore` is `@MainActor @Observable`; capture/sweep run off-main in the actor; value types cross boundaries.
- [x] **IX. Pre-Release Data Posture** — `DayCalendarContext` is CloudKit-compatible: every attribute defaulted, **no unique constraint**; one-per-day is a documented store invariant with a newest-wins dedupe guard (research D1). Schema add relies on the pre-release wipe-and-rebuild posture.
- [x] **X. Test-First Development** — model, payload, store, coordinator, inclusion logic, classification, and export extension are all RED→GREEN test-first (suites named in quickstart); SwiftUI surfaces exempt (build + device QA + mockups).

## Project Structure

### Documentation (this feature)

```text
specs/029-calendar-day-context/
├── spec.md              # clarified 2026-07-03
├── plan.md              # this file
├── research.md          # Phase 0 — decisions D1–D13
├── data-model.md        # Phase 1 — DayCalendarContext + payload + prefs
├── quickstart.md        # Phase 1 — build/test gates + 20-scenario device QA
├── contracts/
│   └── calendar-context-service.md
├── mockups/
│   └── context-line-variants.html   # approved (variant B); invitation/explainer/settings mockups to be added here
└── tasks.md             # /speckit-tasks output (next step)
```

### Source Code (repository root)

```text
app-four/
├── Models/
│   └── DayCalendarContext.swift          # NEW — @Model + CapturedDayEvents payload structs
├── Services/
│   ├── Protocols.swift                   # + CalendarContextService, CalendarContextCoordinator, CalendarAccessState, CalendarDescriptor
│   └── CalendarContext/
│       ├── CalendarContextServiceImpl.swift   # NEW actor — owns the EKEventStore
│       ├── CalendarContextCoordinatorImpl.swift # NEW actor — triggers + sweep (drain pattern)
│       └── CalendarInclusion.swift            # NEW — class defaults + override-set resolution (pure, testable)
├── Store/
│   ├── AppDependencies.swift             # + service/coordinator/store composition
│   ├── AppServices.swift                 # + properties
│   ├── DayContextStore.swift             # NEW — @MainActor @Observable, upsert invariant
│   └── RecordingStore.swift              # deleteRecording: FR-014 hook
├── ViewModels/
│   ├── CheckInViewModel.swift            # attemptSave/saveTextCheckIn: post-save capture trigger
│   ├── ExtractionReviewViewModel.swift   # confirm(): date-change trigger
│   ├── RecordingDetailViewModel.swift    # updateDate(): date-change trigger
│   ├── MoodLibraryViewModel.swift        # TimelineDay + context population
│   └── SettingsViewModel.swift           # clearAllData(): purge contexts; re-capture/remove actions
├── Views/
│   ├── Library/CalendarLibraryView.swift # invitation card slot
│   ├── Components/FoldedDayCardHeader.swift # classified context line + VoiceOver label
│   ├── Settings/CalendarContextSection.swift # NEW section (existing day-card section retitled "Day cards")
│   └── CalendarExplainerSheet.swift      # NEW — explainer + titles choice → system prompt
├── Services/ExportService.swift          # JournalArchive + DayContextDTO, formatVersion 2
├── Utils/MockDataGenerator.swift         # fixture contexts
├── App/AppModelContainer.swift           # schema registration ×2
├── App/SquirlApp.swift                   # RootContainerView: sweep on launch/foreground/grant
└── Info.plist                            # NSCalendarsFullAccessUsageDescription

app-fourTests/
├── DayCalendarContextTests.swift          # NEW
├── DayContextStoreTests.swift             # NEW
├── CalendarContextCoordinatorTests.swift  # NEW (uses MockCalendarContextService)
├── CalendarInclusionTests.swift           # NEW
├── CapturedDayEventsClassificationTests.swift # NEW
├── Mocks/MockCalendarContextService.swift # NEW — 8th actor mock
└── ExportServiceTests.swift               # extended — formatVersion 2 round-trip
```

**Structure Decision**: single-target additions following the existing layer map (Models / Services / Store / ViewModels / Views / Tests). New service files grouped under `Services/CalendarContext/` (peer of `Services/WhisperKit/`). Synchronized folders mean no pbxproj churn.

## Implementation notes (feed for /speckit-tasks)

1. **Order**: model+payload → store → inclusion logic → service actor → coordinator → DI wiring → save/date/delete hooks → sweep wiring → export → mock fixtures → **mockups (invitation/explainer/settings)** → UI surfaces → Info.plist + copy → device-verify checklist (research §Device-verification) → QA script.
2. **Sequencing rule**: every logic task is preceded by its RED test task (Constitution X); UI tasks are preceded by their mockup task (Constitution I).
3. **Known small collisions**: existing Settings section titled "Calendar" must be retitled "Day cards" (one line); `.specify/feature.json` currently points at 029 — leave until 030 planning resumes.
4. **Spec-wording flag for the owner** (research D5): FR-008's "holiday calendars" is implemented as the subscribed-calendar class (no first-class holiday marker exists in EventKit). One-line spec amendment recommended at implement time.
5. **Deferred by design** (do not build): full-event-list UI (Clarifications Q2 — payload retains everything), per-event exclusions, EKEventStoreChanged-driven refresh, background-task capture, med-only-day capture (Q3).

## Complexity Tracking

> No Constitution violations. One borderline documented for transparency:

| Addition | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| `CalendarContextCoordinator` (2nd new actor beside the service) | Save-hook, two date-change hooks, delete hook, sweep, and re-capture share trigger gating (mock-mode/access checks), re-entrancy coalescing, and store hops | Folding orchestration into the EventKit service actor couples query mechanics to app lifecycle; folding into `DayContextStore` puts async sweep work on the MainActor. The drain-service precedent (`PendingTranscriptionServiceImpl`) already establishes this exact shape. |
