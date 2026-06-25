---

description: "Task list for Onboarding & First-Run (015)"
---

# Tasks: Onboarding & First-Run

**Input**: Design documents from `specs/015-onboarding-first-run/`

**Prerequisites**: [plan.md](plan.md) (required), [spec.md](spec.md) (user stories). research.md + data-model.md content is inline in plan.md.

**Tests**: Test-first is MANDATORY for logic (SwiftData `@Model` semantics, `Services/`, `@Observable` view-models) per Constitution **Principle X** — write the test, run it, confirm it **FAILS (RED)**, implement to **GREEN**, refactor. SwiftUI **views are EXEMPT** (verified by build + on-simulator run via `ios-debugger-agent`). Tests use **Swift Testing** (`@Test`/`#expect`).

**Organization**: Grouped by user story (US1–US5 from spec.md) so each ships as an independent increment. Each task is one concern and a clean revertable checkpoint.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency)
- **[Story]**: US1–US5 (or SETUP/FOUND/POLISH)
- Paths are absolute-from-repo-root.

## Path Conventions

Single Xcode target `app-four` (module `app_four`). App code under `app-four/`, tests under `app-fourTests/`.

---

## Phase 1: Setup

**Purpose**: Branch + the HTML mockup that must precede the SwiftUI welcome (Principle I).

- [ ] T001 Create branch `feat/015-onboarding-first-run` off `main`; confirm the existing suite is green on it (baseline) via `ios-debugger-agent`.
- [ ] T002 [P] Author the welcome HTML mockup under `docs/superpowers/plans/` (warm paper, Fraunces headline, breathing-crescent placeholder, one privacy sentence, one primary action) — the Principle I mockup-before-SwiftUI gate for `WelcomeView`. Reference DESIGN.md tokens; no code.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The `Recording` status value + the two new service protocols that US2/US3 depend on. No user-story work begins until this is done.

**⚠️ CRITICAL**: T003–T005 block US2 and US3.

### Tests (RED — MANDATORY) ⚠️

- [ ] T003 [P] [FOUND] In `app-fourTests/Models/RecordingStatusTests.swift`, write failing tests asserting `RecordingStatus.pendingTranscription` exists, is `Codable` round-trippable, and is distinct from `.transcribing`/`.failed`/`.recorded`. Run → RED.

### Implementation

- [ ] T004 [FOUND] Add `case pendingTranscription` to `RecordingStatus` in `app-four/Models/AppEnums.swift` (defaulted, non-unique — Principle IX). Run T003 → GREEN.
- [ ] T005 [P] [FOUND] Add the `Connectivity` and `PendingTranscriptionService` protocol declarations (+ `NetworkInterface` enum) to `app-four/Services/Protocols.swift` per the data-model contracts. No implementations yet (these are seams; impls land in their stories). Build only.

**Checkpoint**: Status value + service seams exist; app still builds.

---

## Phase 3: User Story 1 - One warm welcome that lands on capture (Priority: P1) 🎯 MVP

**Goal**: Replace the three-step onboarding with a single Paper & Pollen welcome that persists completion and lands on the Check-in hub.

**Independent Test**: Fresh launch → one paper welcome with breathing crescent + single primary action → tap → hub; relaunch → no welcome.

### Tests for User Story 1 (test-first · RED — MANDATORY for logic) ⚠️

> Write FIRST, run, confirm FAIL before implementing.

- [ ] T006 [P] [US1] In `app-fourTests/ViewModels/WelcomeViewModelTests.swift`, write failing tests: `complete(modelContext:)` persists `hasCompletedOnboarding == true`; calling it twice does not create a duplicate `AppSettings` row (idempotent); after a forced save failure it still reports completion so the cover can dismiss (FR-005). Use an in-memory `ModelContainer` + `MockAppServices`. Run → RED.

### Implementation for User Story 1

- [ ] T007 [US1] Create `app-four/Views/Onboarding/WelcomeViewModel.swift` (`@MainActor @Observable`) with `complete(modelContext:)` (upsert `AppSettings`, idempotent, completion-signaled-even-on-save-failure). Run T006 → GREEN; refactor.
- [ ] T008 [US1] Create `app-four/Views/Onboarding/WelcomeView.swift` — single screen: `Theme.background` paper, breathing `CrescentRing()` hero, Fraunces `Typography.largeTitle`/`title` headline, one `Typography.body` privacy sentence, one `.primary` Meadow-gradient action, clamped to `Metrics.maxContentWidth`, `Motion.smooth` transitions, Reduce-Motion via `CrescentRing`. Tokens-only (no literals). View — verify by build.
- [ ] T009 [US1] Rewire `RootContainerView` in `app-four/App/SquirlApp.swift` to present `WelcomeView` from the existing `hasCompletedOnboarding`-driven `.fullScreenCover`; on completion the cover dismisses to the Check-in hub. Keep the `-skipOnboarding` debug arg.
- [ ] T010 [US1] Delete `app-four/Views/Onboarding/OnboardingView.swift` and `app-four/Views/Onboarding/OnboardingViewModel.swift` (three-step flow, `DownloadPhase`, dead `modelsReady`) and the disabled `app-fourTests/ViewModels/OnboardingViewModelTests.swift`. No dead code (Principle III). Build.
- [ ] T011 [US1] Build + run on simulator (`ios-debugger-agent`): fresh launch shows the paper welcome (light + dark), one tap lands on the hub, relaunch shows no welcome. Token-grep the first-run path clean. Full suite green.

**Checkpoint**: MVP — a calm, on-brand welcome that reliably reaches the hub. Permission + model still handled by existing point-of-use paths.

---

## Phase 4: User Story 2 - Transcription model downloads in the background (Priority: P1)

**Goal**: After the welcome, the model downloads in the background with no exit gate, honoring `downloadOverCellular` (defer to Wi-Fi when off + cellular).

**Independent Test**: Fresh launch with no model → hub reached without blocking → background download begins; cellular + preference OFF → download deferred until Wi-Fi; model already on disk → no re-download.

### Tests for User Story 2 (test-first · RED — MANDATORY for logic) ⚠️

- [ ] T012 [P] [US2] In `app-fourTests/Mocks/MockConnectivity.swift`, add a scriptable `Connectivity` mock (set current interface; emit changes). (Test infra — no production logic.)
- [ ] T013 [P] [US2] In `app-fourTests/Services/NetworkConnectivityTests.swift`, write failing tests for the download-decision helper: `downloadOverCellular == false` + cellular → defer; + wifi → proceed; + unsatisfied → defer; `downloadOverCellular == true` + cellular → proceed. Drive via injected interface/`MockConnectivity`. Run → RED.

### Implementation for User Story 2

- [ ] T014 [US2] Create `app-four/Services/Connectivity/NetworkConnectivity.swift` — `NWPathMonitor`-backed `Connectivity` (`currentInterface` + change signal), `Sendable`, off-main. Plus the pure `shouldStartDownload(overCellular:interface:)` decision used by T013. Run T013 → GREEN; refactor.
- [ ] T015 [US2] Compose `NetworkConnectivity` into `app-four/Store/AppServices.swift` + `app-four/Store/AppDependencies.swift`; add the mock to `app-fourTests/Mocks/MockAppServices.swift`. Build.
- [ ] T016 [US2] Add the launch background-download trigger (in `RootContainerView.task` / `SquirlApp`): if model not installed and the decision allows, start `AIModelService.download(.whisper)`; if deferred, begin automatically when the interface becomes Wi-Fi. No blocking UI on the first-run path (FR-007). Reuse the existing short-circuit when already installed (FR-008). View/wiring — verify by build + run.
- [ ] T017 [US2] Build + run (`ios-debugger-agent`): fresh launch reaches hub with no blocking download UI; toggle simulator network to confirm deferral/resume against the preference. Full suite green.

**Checkpoint**: The download gate is gone; cellular data is protected. (Draining of anything recorded meanwhile lands in US3.)

---

## Phase 5: User Story 3 - Record before model ready; transcribe when it lands (Priority: P1)

**Goal**: A recording captured before the model is ready is persisted as `.pendingTranscription`, survives relaunch, and drains automatically (serialized) through the existing transcribe→extract path once the model lands — with a calm "ready shortly" affordance and no `.failed`.

**Independent Test**: No model on disk → record → "Captured." + recording shows "ready shortly"; make model ready → recording auto-transcribes; title + signals populate; kill/relaunch mid-pending → still drains.

### Tests for User Story 3 (test-first · RED — MANDATORY for logic) ⚠️

- [ ] T018 [P] [US3] In `app-fourTests/ViewModels/CheckInViewModelTests.swift`, write a failing test: when the model is NOT ready (`MockAIModelService` localPath nil), finishing a recording persists it with `status == .pendingTranscription` (not `.transcribing`, not `.failed`) and still reaches the `.done`/"Captured." UI state; when the model IS ready, behavior is unchanged (transcribes as today). Run → RED.
- [ ] T019 [P] [US3] In `app-fourTests/Services/PendingTranscriptionServiceTests.swift`, write failing tests: `drainIfModelReady()` with model not ready leaves pending recordings untouched; with model ready it transcribes all `.pendingTranscription` recordings in capture (oldest-first) order, sets them `.completed`, and applies extraction (assert title/signals via the mock summarization path); a deleted-meanwhile recording is skipped; draining serializes (no overlapping inferences — assert via a mock that records concurrent entry). Run → RED.
- [ ] T020 [P] [US3] In `app-fourTests/Store/RecordingStoreTests.swift`, add a failing test: launch-time orphan recovery sweeps `.transcribing` → `.failed` but MUST leave `.pendingTranscription` untouched (FR-016). Run → RED.

### Implementation for User Story 3

- [ ] T021 [US3] Create `app-four/Services/PendingTranscriptionServiceImpl.swift` (actor): fetch `.pendingTranscription` recordings oldest-first; if model ready, drain each through `TranscriptionService` → `applySummary`/`setMedicationEvents` → `.completed`, serialized on the single engine; skip deleted; on real error → `.failed` with existing retry copy. Run T019 → GREEN; refactor.
- [ ] T022 [US3] Branch `CheckInViewModel.stopRecording` in `app-four/ViewModels/CheckInViewModel.swift`: when the model is not ready, save the recording as `.pendingTranscription` and skip starting transcription (keep the `.done`/"Captured." flow); when ready, the existing path is unchanged. Run T018 → GREEN; refactor.
- [ ] T023 [US3] Update `RecordingStore.recoverOrphanedTranscriptions` in `app-four/Store/RecordingStore.swift` to scope its sweep to `.transcribing` only, explicitly excluding `.pendingTranscription`. Run T020 → GREEN.
- [ ] T024 [US3] Compose `PendingTranscriptionServiceImpl` into `app-four/Store/AppServices.swift` + `app-four/Store/AppDependencies.swift`; add a mock to `app-fourTests/Mocks/MockAppServices.swift`. Drive `drainIfModelReady()` from (a) the background-download completion (US2 trigger) and (b) app launch + `scenePhase → active` in `SquirlApp`. Build + run.
- [ ] T025 [US3] Extend `Recording.displayTitle` in `app-four/Models/Recording.swift` so `.pendingTranscription` reads as the calm "ready shortly" affordance (FR-017, warm clay never raw red), preserving `.transcribing` → "Transcribing…". Add/adjust a small `@Test` for the computed value. Run → GREEN.
- [ ] T026 [US3] Build + run (`ios-debugger-agent`): airplane-mode capture → "Captured." + pending affordance; restore Wi-Fi → auto-transcribe + signals populate; kill/relaunch while pending → still drains; back-to-back captures while model arrives → both transcribe (serialized). Full suite green.

**Checkpoint**: No lost audio; the record-before-ready dead end is gone. US1+US2+US3 = the safe redesign.

---

## Phase 6: User Story 4 - Just-in-time microphone permission (Priority: P2)

**Goal**: No permission in first-run; reuse the existing Check-in grant/deny/Settings recovery; already-granted users never re-prompted.

**Independent Test**: Complete onboarding with no permission screen → first record triggers the OS prompt → deny → "Open Settings" recovery; granted-already → record starts with no prompt.

### Tests for User Story 4 (test-first · RED — MANDATORY for logic) ⚠️

- [ ] T027 [P] [US4] In `app-fourTests/ViewModels/CheckInViewModelTests.swift`, confirm (add if missing) failing/own tests that `startRecording` sets `permissionDenied` when the mock denies and does not when granted — guarding that deleting the onboarding permission step preserves the recovery contract. Run → RED (or assert existing coverage and extend).

### Implementation for User Story 4

- [ ] T028 [US4] Verify no permission request remains on the first-run path (the onboarding permission step was deleted in T010); confirm `WelcomeView`/`WelcomeViewModel` never call `requestPermission`. Code audit + build.
- [ ] T029 [US4] Build + run (`ios-debugger-agent`): reset privacy → first record shows OS prompt; deny → existing "Open Settings" alert ([CheckInView.swift#L39-L46](../../app-four/Views/CheckIn/CheckInView.swift#L39)); typed check-in still works; re-grant → no second prompt. Full suite green.

**Checkpoint**: Permission is point-of-use only, with a verified escape.

---

## Phase 7: User Story 5 - Plain-language wording & Settings model home (Priority: P2)

**Goal**: No "Whisper"/"~150 MB" in user-facing strings on these paths; model management stays in the Settings row (de-jargoned, coordinated with 017); optional non-naggy hub hint; no replay.

**Independent Test**: String-audit shows no "Whisper"/"150 MB" on first-run + queue strings; Settings shows one transcription row with state + download/retry/delete; no replay entry.

### Implementation for User Story 5

- [ ] T030 [P] [US5] De-jargon user-facing copy: the Settings transcription row label/copy in `app-four/Views/SettingsView.swift` ("Whisper Transcription" → plain language), coordinated with Feature 017 (do not build a parallel row). View — verify by build.
- [ ] T031 [P] [US5] Audit transcription-path placeholder strings (e.g. `WhisperKitTranscriptionService` segment text "Downloading AI Model (~150MB)…" [WhisperKitTranscriptionService.swift#L105](../../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L105)) — ensure none surface to the user on the pending/queue path (the calm `.pendingTranscription` affordance is shown instead); replace any that can. Build.
- [ ] T032 [US5] (Optional, non-naggy) In the Check-in hub, surface at most one gentle hint linking to the Settings transcription row when the model is not set up/failed (FR-024). Warm, an offer not a chore. View — verify by build + run. Skip if it cannot be made non-naggy within the design bar.
- [ ] T033 [US5] Confirm no "replay onboarding" entry exists anywhere (FR-025). String/grep audit: no "Whisper"/"150 MB" on first-run + queue strings (SC-004). Build + run; full suite green.

**Checkpoint**: Trust-and-polish layer complete; jargon gone; model has one discoverable home.

---

## Phase 8: Polish & Cross-Cutting

- [ ] T034 [P] Accessibility pass on `WelcomeView`: VoiceOver labels/order, Dynamic Type at AX5 (ScrollView fallback if content overflows with the fixed-size crescent), decorative crescent `.accessibilityHidden`. Verify on simulator.
- [ ] T035 [P] Add a calm success haptic (`Haptics.success`) when onboarding completes / first capture is confirmed if not already present, matching the "reward = captured" posture (DESIGN.md). Verify on device/sim.
- [ ] T036 Run the full quickstart (plan.md Phase 1) end-to-end on simulator in light + dark; confirm SC-001…SC-007. Token-grep clean on the first-run path. Full Swift Testing suite green (serial).
- [ ] T037 Update `docs/BACKLOG.md` (onboarding gate → 🔨 In code with branch/PR) and `docs/DEVLOG.md` (the decision: single welcome + background queue, why). Then `/code-review` the diff → open PR.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (P1)**: no deps.
- **Foundational (P2)**: needs Setup; `.pendingTranscription` (T004) + protocol seams (T005) BLOCK US2/US3.
- **US1 (P3)**: needs Foundational only for build cleanliness; otherwise self-contained — ship as MVP first.
- **US2 (P4)**: needs Foundational (Connectivity protocol). Independent of US3 logic but the launch trigger it adds is where US3's drive attaches.
- **US3 (P5)**: needs Foundational (`.pendingTranscription`, queue protocol) + US2's launch trigger to drive draining on download completion.
- **US4 (P6)**: needs US1 (the permission step is deleted there); otherwise independent.
- **US5 (P7)**: independent; coordinate with Feature 017 on the Settings row.
- **Polish (P8)**: after the desired stories.

### Within Each User Story

- Tests written, RUN, confirmed FAILING (RED) before implementation (GREEN); refactor after (Principle X).
- Model/enum changes → services → VM/view wiring → build+run.
- Story complete and independently verified before the next priority.

### Parallel Opportunities

- T002 (mockup) ∥ T001 baseline.
- T003 ∥ T005; T006; T012 ∥ T013; T018 ∥ T019 ∥ T020 (different files).
- T030 ∥ T031 ∥ T034 ∥ T035.
- US4 and US5 can proceed in parallel once US1 lands.

---

## Implementation Strategy

### MVP First (US1)

1. Setup (P1) → Foundational (P2) → US1 (P3).
2. **STOP and VALIDATE**: paper welcome reliably reaches the hub; relaunch clean; tokens clean. This alone kills the P0 brand regression and the download dead-end (existing point-of-use paths cover the rest).

### Incremental Delivery

1. + US2 → background download, cellular-safe → demo.
2. + US3 → record-before-ready queue (the real engineering) → demo. **This is the point the redesign is fully safe.**
3. + US4 → permission gate deleted, recovery verified → demo.
4. + US5 → de-jargon + Settings home → demo.
5. Polish → a11y, haptic, quickstart, backlog/devlog, PR.

---

## Notes

- [P] = different files, no dependency.
- Verify tests FAIL (RED) before implementing; never write implementation ahead of its test (Principle X).
- Commit after each task or logical group; each task is a clean revertable checkpoint.
- Keep extraction untouched — queued recordings drain through the EXACT existing transcribe→`applySummary` path (Principle VII; no eval-floor impact).
- Tokens-only on the first-run path; no raw color/font literals (SC-005).
- Coordinate the Settings transcription row with Feature 017 — do not build a parallel model-management surface.
