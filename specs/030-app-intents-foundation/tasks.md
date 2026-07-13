<!-- Created: 2026-07-03 19:08 (WEST) · Updated: 2026-07-11 03:38 (WEST) -->
# Tasks: App Intents Foundation + NFC Sticker Actions

**Input**: Design documents from `/specs/030-app-intents-foundation/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md) (23 FRs, clarified 2026-07-03), [research.md](research.md) (D1–D15; **D15 raises the deployment target to iOS 26.0** — D2/D9 revised to the `supportedModes` API), [data-model.md](data-model.md), [contracts/app-intents.md](contracts/app-intents.md), [quickstart.md](quickstart.md) (S1–S26)

**Tests**: Test-first is MANDATORY for logic per Constitution X — every RED task is run and confirmed FAILING before its implementation task. SwiftUI views are exempt (build + device QA; no simulator per project workflow — owner runs device QA at story checkpoints). Swift Testing (`@Test`/`#expect`) throughout; suites touching mock-mode-predicated fetches call `TestSupport.useRealData()` first.

**Organization**: Grouped by user story (spec priorities P1–P4). Guard *evaluation* logic ships inside US1's service (guard defaults to `off`; FR-008's UI arrives in US3) — the split keeps every story independently testable without violating RED-first (see notes on T012/T030).

**Revision 2026-07-03 19:15**: reviewed under the full skill set (swiftui-pro, swiftdata-pro, concurrency, architecture, design-principles) after the owner raised the target to iOS 26 — added T002 (deployment-target raise), flipped T019/T027 to `supportedModes`/`continueInForeground`, pinned the service's MainActor isolation in T017, renumbered T001–T040.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [X] T001 Create branch `feat/030-app-intents` off `main`; verify baseline build + full serial suite green before any change (Constitution II baseline)
- [X] T002 **Verify** the iOS 26 baseline is already on `main` (the raise was executed 2026-07-03 on branch `feat/ios26-target` ahead of this feature — pbxproj all four configs + both SPM packages at 26.0, `ScrollPosition` restored in ScreenContainer, dead iOS-16 guard removed): `grep -c "IPHONEOS_DEPLOYMENT_TARGET = 26.0" app-four.xcodeproj/project.pbxproj` == 8. If that branch has NOT merged yet, rebase this feature onto it or land it first — do not re-apply the raise here (D15)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: settings fields, guard math, and the router — every story depends on at least one of these. The RED wave (T003–T005) is written and run BEFORE any implementation.

**⚠️ CRITICAL**: No user story work until T010 passes.

### RED wave (write, run, confirm FAIL)

- [X] T003 [P] Extend `app-fourTests/Models/AppSettingsTests.swift`: fresh-defaults assertions for the 5 new fields (`defaultMedicationName == nil`, `defaultMedicationDose == nil`, `doseGuardModeRaw == "off"`, `doseGuardWindowHours == 2`, `nameMedicationInConfirmations == false`) using the existing Mirror no-member pattern — RED (fields don't exist)
- [X] T004 [P] Create `app-fourTests/Models/DoseGuardModeTests.swift`: raw-value decode (`"off"`/`"total"`/`"window"`, unknown raw → `.off` forward-safe), boundary semantics helpers (window end exactly reached → guard closed; matches `effectProgress < 1` convention) — RED (type doesn't exist)
- [X] T005 [P] Create `app-fourTests/Intents/AppIntentRouterTests.swift`: trigger-state plumbing only — `requestCheckIn()` sets the check-in trigger, consumption is one-shot (second consume is a no-op), `focusMyMedication()` sets Settings tab + one-shot focus flag. (Onboarding-gate cases belong to US2 — T024.) — RED (type doesn't exist)
- [X] T006 **RED checkpoint**: run the suite; confirm T003–T005 tests FAIL for the right reason (missing members/types, not compile noise elsewhere)

### Implementation (GREEN)

- [X] T007 [P] Add the 5 defaulted fields to `app-four/Models/AppSettings.swift` per [data-model.md](data-model.md) (all defaulted/optional, no `.unique` — Constitution IX) → T003 GREEN
- [X] T008 [P] Create `app-four/Models/DoseGuardMode.swift`: non-persisted enum + raw decode + boundary rule per [data-model.md](data-model.md) → T004 GREEN
- [X] T009 Create `app-four/Intents/AppIntentRouter.swift`: `@MainActor @Observable` router — check-in trigger flag, one-shot consumption, `focusMyMedication()`; NO gate logic yet (US2) → T005 GREEN
- [X] T010 Wire the router through the app in `app-four/App/SquirlApp.swift` + `app-four/Store/AppDependencies.swift`: compose router in AppDependencies; register it with `AppDependencyManager.shared` in `SquirlApp.init` (D11); drive `selectedTab`/`shouldAutoStartRecording` from router state; **rewire the `whispernotes://checkin` `onOpenURL` handler through `router.requestCheckIn()`** (D3/D4 — gate lands in US2, plumbing now). Build + full serial suite green. **Checkpoint: foundation ready**

---

## Phase 3: User Story 1 — Log my dose without opening the app (Priority: P1) 🎯 MVP

**Goal**: default med+dose setting → background dose-log verb with discreet-by-default acknowledgment, not-configured continuation into Settings, zero-setup Siri/Spotlight/Shortcuts exposure.

**Independent Test**: quickstart **S1–S10** — configure default, run the verb from Shortcuts/Siri (unlocked + locked), verify event, banner, med-bar parity, not-configured path. No sticker, no guard UI needed.

### Tests for User Story 1 (test-first · RED — MANDATORY) ⚠️

- [X] T011 [US1] HTML mockup gate (Constitution I): create `html-mockups/030-settings-medication.html` covering the three Settings controls — "My medication" picker (catalog med + dose options, clearable), "Name medication in confirmations" toggle, and the "Dose guard" section (US3 builds it later from this same approved mockup) — DESIGN.md Paper & Pollen tokens, base-4 spacing grid; **owner approval before any SwiftUI below**
- [X] T012 [P] [US1] Create `app-fourTests/Services/DoseLogServiceTests.swift` (in-memory container + `TestSupport.useRealData()`): **full outcome + guard-evaluation matrix** — notConfigured (no default; dangling name not in catalog); logged event field contract (`source == .manual`, `recording == nil`, `isMockData == false`, catalog `durationHours`, `takenAt == now`); guard OFF double-log allowed; **total guard** blocks while `isActive` (respecting a per-event edited duration) and allows at exact effect end; **window guard** blocks `< X h`, allows at exactly `X h` (boundary closed, FR-012); **any-surface reference** — an event created the in-app way blocks a guarded expedited log (clarify Q3=A); `guarded.activeSince` carries the earlier `takenAt`; `.medicationEventsDidChange` posted on logged only — RED (service doesn't exist). *(Guard eval is tested HERE because the service owns it from day one with mode written directly to AppSettings in tests; US3 adds only the UI.)*
- [X] T013 [P] [US1] Create `app-fourTests/Views/ConfirmationCopyTests.swift` *(created at `app-fourTests/Intents/ConfirmationCopyTests.swift` — grouped next to the helper)*: pure copy-matrix helper tests per [data-model.md](data-model.md) — named/discreet × logged/guarded/notConfigured, system-short time formatting, guarded copy names time never drug — RED
- [X] T014 [P] [US1] Extend `app-fourTests/ViewModels/SettingsViewModelTests.swift`: my-medication + naming-toggle sync round-trips (VM props ↔ AppSettings persistence, clear-default path) — RED
- [X] T015 [US1] **RED checkpoint**: run suite; confirm T012–T014 FAIL for the right reasons

### Implementation for User Story 1

- [X] T016 [US1] Create `app-four/Services/DoseLog/DoseLogService.swift`: protocol + `DoseLogOutcome` (logged/guarded/notConfigured) per [contracts/app-intents.md](contracts/app-intents.md)
- [X] T017 [US1] Create `app-four/Services/DoseLog/DoseLogServiceImpl.swift`: settings resolve (fetch-first-or-create) → catalog re-validation (`entry(matching:)`) → guard evaluation (D6 semantics) → `MedicationEvent` insert + explicit save → `.medicationEventsDidChange` post → T012 GREEN. Isolation: stay MainActor-isolated (repo default) using `AppModelContainer.container.mainContext` — a fetch-limit-1 + insert is trivial work; do NOT introduce a background ModelContext or detached task for it
- [X] T018 [US1] Create the confirmation copy helper (`app-four/Intents/DoseConfirmationCopy.swift`) → T013 GREEN
- [X] T019 [US1] Create `app-four/Intents/LogDefaultDoseIntent.swift`: `static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]` (D2 rev.); thin `perform()` — `@AppDependency` service; outcome → `IntentDialog(full:supporting:)` via T018; explicit `authenticationPolicy = .alwaysAllowed` (D8); notConfigured → calm dialog + `continueInForeground()` → `router.focusMyMedication()` (D9 rev./D13); honest failure dialog via the `.failed` outcome (SC-007; review fix 2026-07-11 — the service returns `.failed` instead of throwing, keeping the 1:1 outcome→dialog mapping)
- [X] T020 [US1] Create `app-four/Intents/SquirlAppShortcuts.swift`: `AppShortcutsProvider` with the dose shortcut (iOS 17+ initializer with `shortTitle`/`systemImageName`, `.applicationName` phrases per contract; check-in entry added in US2)
- [X] T021 [US1] Register `DoseLogService` in `app-four/Store/AppDependencies.swift` + `AppDependencyManager` (extends T010 wiring)
- [X] T022 [US1] From the approved T011 mockup: create `app-four/Views/Settings/MyMedicationSection.swift` (+ naming toggle — same section or `ConfirmationStyleSection.swift` per mockup decision), add SettingsViewModel sync props → T014 GREEN, mount in `app-four/Views/SettingsView.swift`
- [X] T023 [US1] **Story checkpoint**: build + full serial suite green; owner device QA quickstart **S1–S10** (iOS 26 device, mock mode OFF). US1 is the shippable MVP

---

## Phase 4: User Story 2 — Start a check-in hands-free (Priority: P2)

**Goal**: foreground verb → app opens directly into Listening, already recording; strict onboarding gate (FR-022) covering BOTH the intent and the legacy deep link.

**Independent Test**: quickstart **S15–S20** — verb from Spotlight/Siri with app killed lands in active recording; fresh-install gate never records; re-entry, model-absent queue, mic-revoked paths intact.

### Tests for User Story 2 (test-first · RED — MANDATORY) ⚠️

- [X] T024 [US2] Extend `app-fourTests/Intents/AppIntentRouterTests.swift` with gate cases: onboarding incomplete → `requestCheckIn()` sets NO auto-start trigger and reports the gated outcome (drives the "finish setting up" dialog + app opens to onboarding); onboarding complete → trigger set; gate consults `AppSettings.hasCompletedOnboarding` via ModelContext — RED (gate not implemented)
- [X] T025 [US2] **RED checkpoint**: run suite; confirm T024 FAILS

### Implementation for User Story 2

- [X] T026 [US2] Implement the onboarding gate inside `app-four/Intents/AppIntentRouter.swift` (FR-022; single choke point — the T010-rewired URL path is now gated too, closing the shipped hole D4) → T024 GREEN
- [X] T027 [US2] Create `app-four/Intents/StartCheckInIntent.swift`: `static let supportedModes: IntentModes = .foreground` (D2 rev. — system foregrounds before `perform()`; deprecated `openAppWhenRun` banned); `@MainActor perform()` → `router.requestCheckIn()`; gated outcome → calm dialog; verify the existing `CheckInView.consumeAutoStart()` path fires through the spec-016 re-entry guard with no view changes (adjust `app-four/Views/CheckIn/CheckInView.swift` only if consumption needs the router hook)
- [X] T028 [US2] Add the check-in `AppShortcut` (phrases per contract) to `app-four/Intents/SquirlAppShortcuts.swift`
- [X] T029 [US2] **Story checkpoint**: build + full serial suite green; owner device QA quickstart **S15–S20** — S16 MUST verify both surfaces (verb AND `whispernotes://checkin` from Safari) against the gate on a fresh install, mock mode OFF

---

## Phase 5: User Story 3 — Dose guard setting (Priority: P3)

**Goal**: the user-facing guard control — off (default) / total / time-window 1–4 h. Evaluation logic already shipped + tested in US1's service; this story adds the Settings surface.

**Independent Test**: quickstart **S11–S15** — flip modes in Settings and verify block/allow/edited-duration/in-app-sheet-never-blocked behaviors end-to-end.

### Tests for User Story 3 (test-first · RED — MANDATORY) ⚠️

- [X] T030 [US3] Extend `app-fourTests/ViewModels/SettingsViewModelTests.swift`: dose-guard mode + window-hours sync round-trips (off/total/window×1–4 h ↔ `doseGuardModeRaw`/`doseGuardWindowHours`), invalid persisted raw surfaces as `.off` — RED
- [X] T031 [US3] **RED checkpoint**: run suite; confirm T030 FAILS

### Implementation for User Story 3

- [X] T032 [US3] From the approved T011 mockup: create `app-four/Views/Settings/DoseGuardSection.swift` (off/total/window control + 1·2·3·4 h picker visible only in window mode — one selected value, never independent toggles), SettingsViewModel sync props → T030 GREEN, mount in `app-four/Views/SettingsView.swift`
- [ ] T033 [US3] **Story checkpoint**: build + full serial suite green; owner device QA quickstart **S11–S15** (boundary case S14 is unit-covered; device pass validates the UX copy)

---

## Phase 6: User Story 4 — Set up my sticker in a minute (Priority: P4)

**Goal**: guided walkthrough (dose / check-in paths), `shortcuts://` hand-off, honest lock-behavior copy, Run-Immediately recommendation. Pure guidance — no journal behavior.

**Independent Test**: quickstart **S21–S24** — a first-time user turns a blank NFC tag into a working zero-tap sticker in under 2 minutes following only the guide.

### Tests for User Story 4

*View-only story — SwiftUI exempt per Constitution X (verified by build + device QA S21–S24); no logic, no RED wave.*

- [X] T034 [US4] HTML mockup gate (Constitution I): create `html-mockups/030-sticker-guide.html` — walkthrough steps per sticker type, hand-off button, lock-behavior expectation copy (no-shame framing per FR-020); **owner approval before SwiftUI**
- [X] T035 [US4] From the approved mockup: create `app-four/Views/Settings/StickerSetupView.swift` (guided walkthrough; plain `shortcuts://` hand-off — D12, never promise automation creation) + entry row in `app-four/Views/SettingsView.swift`
- [ ] T036 [US4] **Story checkpoint**: build + full serial suite green; owner device QA quickstart **S21–S24** with a real blank NFC tag

---

## Phase 7: Polish & Cross-Cutting

- [X] T037 Owner sign-off: FR-005 haptic-clause amendment in `specs/030-app-intents-foundation/spec.md` per D9 (haptic = foreground only; background ack = system banner/spoken dialog) — spec edit lands in this PR so spec and build don't drift
- [ ] T038 [P] Device-verify S23 (locked-NFC degradation — the one community-verified-only claim): reconcile `StickerSetupView` copy AND the spec assumption with observed behavior in the same PR
- [ ] T039 Full quickstart regression pass **S1–S26** on device (iOS 26, mock mode OFF), including S25 med-bar/insights parity and S26 full serial suite
- [ ] T040 Open PR `feat/030-app-intents` → run `/code-review`, address findings; after commits, regenerate `docs/WORKLOG.md` via `scripts/worklog.sh`; owner merges only after device QA (project rule: review + device QA both mandatory)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (P1: T001–T002)** → **Foundational (P2)** → user stories. T002 (target raise) MUST precede all Swift work — availability context for `IntentModes`.
- **US1 (P3)**: needs Foundational only. **US2 (P4)**: needs Foundational (router) — independent of US1. **US3 (P5)**: needs US1's service (guard eval already inside it) + T011 mockup. **US4 (P6)**: fully independent view work after Foundational.
- **Polish (P7)**: after all desired stories.

### Story independence notes

- US2 ⊥ US1 (router vs service — no shared files except the provider T020/T028, sequential by numbering).
- US3 depends on US1 (service + mockup), by design: evaluation shipped dark in US1 (guard defaults off — behavior identical until US3's UI exposes it). Same ship-dark pattern 029 used for backend-ready capture.
- US4 touches only its own view + SettingsView mount — parallelizable with US2/US3.

### Within each story

RED tests → RED checkpoint (run + confirm FAIL) → implementation (GREEN) → story checkpoint (build + full serial suite + owner device QA per quickstart scenario numbers).

### Parallel opportunities

- Foundational RED wave: T003 + T004 + T005 together; then T007 + T008 together.
- US1 RED wave: T012 + T013 + T014 together.
- After US1: US2 (T024–T029) ∥ US3 (T030–T033) ∥ US4 (T034–T036) — different files; only `SettingsView.swift` mounts and `SquirlAppShortcuts.swift` edits serialize (T022 → T028 → T032 → T035 touch order per numbering).
- Polish: T038 parallel with T037.

## Implementation Strategy

**MVP = T001–T023** (Setup + Foundational + US1): a user can configure their med and log a dose by Siri/Shortcuts with zero app-opens — shippable and demonstrable alone. Each later story is one independently QA-able increment; one PR ships the whole feature (one-revertable-feature rule), with per-story checkpoints so regressions localize to a phase.

## Notes

- Intent `perform()` bodies are thin translation layers (D14) — deliberately NOT unit-tasked; their behavior is covered by service/router tests + device QA (Constitution X views-exempt spirit).
- Deprecated App Intents surfaces (`openAppWhenRun`, `ForegroundContinuableIntent`) are BANNED on the 26 target (Constitution I); iOS 26 extras deliberately not adopted this feature: interactive snippets, `LongRunningIntent`, SwiftData `#Index` (D15 — YAGNI; the guard fetch touches tens of rows).
- Every suite touching `MedicationEvent`/mock-mode predicates: `TestSupport.useRealData()` first.
- DEBUG QA caveats (mock mode hides intent events AND bypasses the onboarding cover) are baked into checkpoint instructions — see [quickstart.md](quickstart.md) prerequisites.
- New Swift files need no pbxproj edits (synchronized folders); T002 is the only pbxproj touch. The provider surfaces on both dev + stable bundle IDs.
