<!-- Created: 2026-07-03 18:24 (WEST) · Updated: 2026-07-03 18:24 (WEST) -->
# Tasks: Calendar Day Context — "The Day, Remembered" (Phase 1)

**Input**: Design documents from `/specs/029-calendar-day-context/` — [plan.md](plan.md) · [spec.md](spec.md) · [research.md](research.md) (D1–D13) · [data-model.md](data-model.md) · [contracts/](contracts/calendar-context-service.md) · [quickstart.md](quickstart.md)

**Tests**: MANDATORY test-first per Constitution X — every logic task is preceded by its RED task (write test → run → confirm FAIL → implement → GREEN → refactor). Swift Testing (`@Test`/`#expect`); suite runs **serial** (parallel is known-flaky). SwiftUI views are exempt (build + owner device QA + HTML mockup first per Constitution I).

**Organization**: by user story (spec priorities P1–P3), after a blocking Foundational phase. One branch, one PR; stories are independently *testable* increments on that branch.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [ ] T001 Create branch `feat/029-calendar-day-context` off `main`
- [ ] T002 Add `NSCalendarsFullAccessUsageDescription` to `app-four/Info.plist` with the verbatim string from [contracts §5](contracts/calendar-context-service.md)

---

## Phase 2: Foundational (blocking — no story work before this completes)

**Purpose**: model, store, service seam, coordinator, DI. All pure-logic; all RED-first.

- [ ] T003 [P] RED: write `app-fourTests/DayCalendarContextTests.swift` — `CapturedDayEvents`/`CapturedEvent` Codable round-trip (incl. nil titles, availability strings, schemaVersion), `DayCalendarContext` defaulted-attribute construction; confirm FAIL (types don't exist)
- [ ] T004 [P] RED: write `app-fourTests/CalendarInclusionTests.swift` — class defaults (birthday class excluded, subscribed class excluded, plain calDAV/local included), `calendarExcludedIDs`/`calendarIncludedOverrideIDs` resolution per [data-model.md §Preferences](data-model.md), newly-appearing-calendar behavior; confirm FAIL
- [ ] T005 [P] RED: write `app-fourTests/CapturedDayEventsClassificationTests.swift` — day-attribution rule (timed <24 h → start day only; all-day/≥24 h → each covered day), declined-attendee filter, occurrence dedupe key (`eventIdentifier + occurrenceDate`), titles-off payload (nil titles, counts intact); confirm FAIL
- [ ] T006 Implement `app-four/Models/DayCalendarContext.swift` — @Model per [data-model.md](data-model.md) (all attributes defaulted, **no `@Attribute(.unique)`** — Constitution IX) + `CapturedDayEvents`/`CapturedEvent` structs + `DayKey.make(for:)` helper (`Calendar.current.startOfDay`); T003 GREEN
- [ ] T007 Register `DayCalendarContext.self` in **both** `Schema` arrays in `app-four/App/AppModelContainer.swift` (production + preview)
- [ ] T008 Implement `app-four/Services/CalendarContext/CalendarInclusion.swift` — pure classification + two-set resolution logic (takes `CalendarDescriptor`s; no EventKit import); T004 GREEN
- [ ] T009 Implement capture pure-logic in `app-four/Services/CalendarContext/CalendarContextServiceImpl.swift` as testable free functions/extensions (attribution, declined filter, dedupe, payload mapping — separated from EKEventStore I/O); T005 GREEN
- [ ] T010 [P] RED: write `app-fourTests/DayContextStoreTests.swift` — upsert one-per-day invariant (insert → update, whole-payload replace), newest-`capturedAt` dedupe guard on duplicate rows, `daysLackingContext(checkInDays:)` set-difference, `purgeAll`, `deleteContext(for:)`, `isMockData` partition filtering on every fetch (in-memory ModelContainer); confirm FAIL
- [ ] T011 Implement `app-four/Store/DayContextStore.swift` — `@MainActor @Observable`, observable `contextsByDay` cache, API per [contracts §2](contracts/calendar-context-service.md); T010 GREEN
- [ ] T012 Declare `CalendarContextService`, `CalendarContextCoordinator` protocols + `CalendarAccessState`, `CalendarDescriptor` in `app-four/Services/Protocols.swift` per [contracts §1/§3](contracts/calendar-context-service.md)
- [ ] T013 [P] Implement `app-fourTests/Mocks/MockCalendarContextService.swift` — 8th actor mock (scripted access states, calendars, per-day captured payloads, call recording), pattern of the existing 7 mocks
- [ ] T014 [P] RED: write `app-fourTests/CalendarContextCoordinatorTests.swift` — `checkInSaved` captures (latest-wins), `sweep` fills only missing days + coalesces re-entrant calls, `checkInDateChanged` re-captures new day + cleans vacated day, `checkInDeleted` deletes only when day empty, `recaptureAll` replaces everything under current settings, **all triggers no-op when access ≠ fullAccess or `debugMockMode` is on**; confirm FAIL
- [ ] T015 Implement `app-four/Services/CalendarContext/CalendarContextCoordinatorImpl.swift` — actor, drain-pattern re-entrancy guard, dayKey work items (no `@Model` across hops), gating per contract; T014 GREEN
- [ ] T016 Complete `CalendarContextServiceImpl` EventKit I/O — single long-lived `EKEventStore` actor-confined, `accessState`/`requestFullAccess`/`availableCalendars`/`captureDay` per [contracts §1](contracts/calendar-context-service.md) (research D2/D3/D4/D5); logic already covered by T005/T009 — I/O layer verified on device (T040)
- [ ] T017 Compose in `app-four/Store/AppDependencies.swift` + `app-four/Store/AppServices.swift` — service, coordinator, `DayContextStore` (coordinator receives service + store + settings reader); build must stay green

**Checkpoint**: foundation GREEN (serial suite) — story phases can begin.

---

## Phase 3: User Story 1 — Remember what a day held (P1) 🎯 MVP

**Goal**: with access granted, every check-in day carries its captured context; past days backfill; day cards show the classified line.

**Independent test** (quickstart QA 3–5, 10–12, 16): grant via the minimal Settings row → backfill lights up history → new/backdated/multi check-ins behave per FR-002/006; deletion per FR-014.

- [ ] T018 [US1] Wire post-save capture trigger (voice): `app-four/ViewModels/CheckInViewModel.swift` `attemptSave` — fire-and-forget `coordinator.checkInSaved(dayKey:)` after `store.addRecording` (off critical path, FR-012)
- [ ] T019 [US1] Wire post-save capture trigger (text): `app-four/Store/RecordingStore.swift` `persistCheckInNote` path — same trigger
- [ ] T020 [P] [US1] Wire date-change triggers: `app-four/ViewModels/ExtractionReviewViewModel.swift` `confirm()` and `app-four/ViewModels/RecordingDetailViewModel.swift` `updateDate(_:)` — `coordinator.checkInDateChanged(from:to:)` when the day changes (US1-AS7 + vacated-day cleanup)
- [ ] T021 [US1] RED: extend `app-fourTests/DayContextStoreTests.swift` (or RecordingStore tests) — deleting a day's **last** recording removes the day's context; multi-check-in day keeps it; confirm FAIL. Then implement the FR-014 hook in `app-four/Store/RecordingStore.swift` `deleteRecording` (count remaining same-day/same-partition recordings); GREEN
- [ ] T022 [US1] Wire sweep at lifecycle hooks: `app-four/App/SquirlApp.swift` `RootContainerView` — `coordinator.sweep()` in the existing launch `.task` + `scenePhase == .active` handler (beside `drainIfModelReady`)
- [ ] T023 [US1] RED: extend `app-fourTests/` MoodLibraryViewModel coverage — `TimelineDay` gains `context: CapturedDayEvents?` populated from `DayContextStore` for the day; days without context get nil; confirm FAIL. Then implement in `app-four/ViewModels/MoodLibraryViewModel.swift` `timelineDays`; GREEN
- [ ] T024 [US1] Implement the classified context line in `app-four/Views/Components/FoldedDayCardHeader.swift` — "N meetings" (`attendeeCount > 0`) + named events in day order, titles-off → "N meetings · M events", truncation per approved mockup ([mockups/context-line-variants.html](mockups/context-line-variants.html) **variant B** — mockup gate already satisfied); extend the composed VoiceOver label; nothing renders when context is absent (FR-005)
- [ ] T025 [US1] Add the minimal Settings entry: new `app-four/Views/Settings/CalendarContextSection.swift` with the live access-state row + "Connect calendar" action calling `requestFullAccess()` then `coordinator.sweep()` — the skeleton US2/US3 extend (not throwaway); register in `SettingsView.body`
- [ ] T026 [US1] Build + full serial suite green; owner device QA quickstart scenarios 3–5, 10–12, 16

**Checkpoint**: MVP — the memory prosthesis works end-to-end for a granting user.

---

## Phase 4: User Story 2 — Grant or decline on my own terms (P2)

**Goal**: the trustworthy flow — invitation card, explainer with the titles choice before any prompt, decline as a first-class state, silent degradation, self-healing on re-grant.

**Independent test** (quickstart QA 1–2, 13–14, 20): fresh install shows the one-time invitation; explainer precedes the prompt; decline/deny/revoke are silent; re-grant heals gaps.

- [ ] T027 [P] [US2] HTML mockup: invitation card + explainer sheet in `specs/029-calendar-day-context/mockups/grant-flow.html` (Paper & Pollen; explainer = what-is-read · on-device promise · benefit · titles toggle default-on; copy per spec FR-001) — owner approves before SwiftUI
- [ ] T028 [US2] RED: write access-presentation tests (new `app-fourTests/CalendarAccessPresentationTests.swift`) — invitation shows only while `notDetermined && !invitationDismissed && !explainerDeclined`; explainer-declined ⇒ no prompt ever, Settings path stays; denied/revoked ⇒ no affordances outside Settings (FR-010 gating logic as a small pure helper); confirm FAIL → implement helper in `app-four/Services/CalendarContext/CalendarInclusion.swift` or sibling; GREEN
- [ ] T029 [US2] Implement `app-four/Views/CalendarExplainerSheet.swift` per approved mockup — titles choice writes `calendarTitlesIncluded`; proceed → `requestFullAccess()` → on grant `coordinator.sweep()`; decline → `calendarExplainerDeclined = true`, no prompt
- [ ] T030 [US2] Implement the one-time invitation card in `app-four/Views/Library/CalendarLibraryView.swift` — first child of the timeline `LazyVStack` **and** the empty-state branch; dismissal sets `calendarInvitationDismissed` (permanent); opens the explainer
- [ ] T031 [US2] Route the Settings row (T025) through the explainer sheet instead of direct request; verify revoked/denied states render the Settings guidance (FR-010)
- [ ] T032 [US2] Build + serial suite green; owner device QA quickstart scenarios 1–2, 13–14, 20

**Checkpoint**: the permission story is complete and calm in all states.

---

## Phase 5: User Story 3 — Control what Squirl sees (P3)

**Goal**: the full Settings surface — per-calendar picker, titles toggle, re-capture history, remove all captured context.

**Independent test** (quickstart QA 6–9, 15): exclusions apply to future captures; titles-off works; re-capture and purge do what they say; declined invites never appear.

- [ ] T033 [P] [US3] HTML mockup: full Settings Calendar section in `specs/029-calendar-day-context/mockups/settings-calendar.html` (access row · picker with class-default badges · titles toggle · re-capture/remove actions with confirms) — owner approves before SwiftUI
- [ ] T034 [US3] Retitle the existing day-card section "Calendar" → "Day cards" in `app-four/Views/Settings/DayCardSettingsSection.swift` (frees the name; one line)
- [ ] T035 [US3] Extend `app-four/Views/Settings/CalendarContextSection.swift` per approved mockup — per-calendar picker (from `availableCalendars()` + T008 resolution, writing the two ID sets), titles toggle, "Re-capture history with current settings" (`coordinator.recaptureAll()`) and "Remove captured calendar context" (`DayContextStore.purgeAll()`) with confirmation dialogs (FR-013)
- [ ] T036 [US3] RED: extend `app-fourTests/` SettingsViewModel coverage — `clearAllData()` also deletes all `DayCalendarContext` rows (no cascade exists); confirm FAIL → implement in `app-four/ViewModels/SettingsViewModel.swift`; GREEN
- [ ] T037 [US3] Build + serial suite green; owner device QA quickstart scenarios 6–9, 15

**Checkpoint**: all spec user stories delivered.

---

## Phase 6: Polish & Cross-Cutting

- [ ] T038 [P] RED: extend `app-fourTests/ExportServiceTests.swift` — archive contains `dayContexts` (same partition), `formatVersion == 2`, DTO round-trip; confirm FAIL → implement `DayContextDTO` + snapshot fetch + version bump in `app-four/Services/ExportService.swift`; GREEN (FR-011)
- [ ] T039 [P] Disclosure copy: export/privacy UI states captured day context (incl. titles when enabled) rides the encrypted export — `app-four/Views/Settings/YourDataSection.swift` (or export sheet copy) per FR-011
- [ ] T040 [P] Mock fixtures: seed fixture `DayCalendarContext` rows (`isMockData = true`) in `app-four/Utils/MockDataGenerator.swift` for seeded days; verify (existing coordinator tests, T014) the pipeline never touches EventKit in mock mode; owner QA scenario 17
- [ ] T041 Device-verify checklist from [research.md §Device-verification](research.md) on owner hardware: (1) multi-day overlap semantics, (2) recurring `eventIdentifier` dedupe, (3) real declined-invite detection, (4) permission-toggle-mid-run relaunch — quickstart scenarios 15, 16, 20; adjust capture logic + tests if any assumption fails
- [ ] T042 Spec-wording amendment (owner sign-off): FR-008 "holiday calendars" → "the system birthday calendar and subscribed calendars" per research D5; update `spec.md` + checklist note
- [ ] T043 Full serial suite + build green; VoiceOver pass on a context-bearing day card (quickstart 19); export round-trip QA (quickstart 18)
- [ ] T044 Open PR → `/code-review` on the diff → address findings → owner device QA sign-off (quickstart full script) → merge per repo rules (never on review alone)
- [ ] T045 Trackers: BACKLOG stage 📐→🔨→✅ as it moves, DEVLOG checkpoint entries, WORKLOG regeneration after commits

---

## Dependencies

```
Setup (T001–T002)
  └─▶ Foundational (T003–T017; RED tasks [P] first, impls follow their REDs)
        └─▶ US1 (T018–T026) 🎯 MVP  ── minimal grant row T025 is US1's only UI dependency
              ├─▶ US2 (T027–T032)   ── wraps T025's request in the explainer; adds invitation
              └─▶ US3 (T033–T037)   ── extends T025's section; independent of US2
                    └─▶ Polish (T038–T045; T038/T039/T040 [P] any time after Foundational)
```

- Story order US1 → US2 → US3 is priority order; US2 and US3 are mutually independent (both extend T025's skeleton — file-level coordination only).
- Every impl task depends on its RED task (T003→T006, T004→T008, T005→T009, T010→T011, T014→T015, plus inline RED-then-GREEN tasks T021/T023/T028/T036/T038).

## Parallel execution examples

- **Foundational**: T003 + T004 + T005 + T010 + T013 + T014 (six test/mock files, no shared files) in one wave; then T006–T009, T011–T012, T015–T017 in dependency order.
- **US1**: T020 alongside T018/T019 (different files); T023's RED alongside T021's RED.
- **US2/US3**: T027 and T033 (mockups) can be authored back-to-back and approved in one owner pass; after US1, US2 and US3 implementation can interleave.
- **Polish**: T038 + T039 + T040 concurrently.

## Implementation strategy

**MVP = Foundational + US1** (T001–T026): a granting user gets the full memory prosthesis. US2 hardens trust, US3 hardens control, Polish closes export/mock/verification. Stop-and-ship points exist at each checkpoint; the PR ships all phases together per the one-revertable-feature rule, but device QA runs per checkpoint so regressions localize.
