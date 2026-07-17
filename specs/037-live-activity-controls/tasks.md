<!-- Created: 2026-07-16 19:58 (WEST) · Updated: 2026-07-17 20:40 (WEST) -->
# Tasks: Live Activity Recording Controls for Check-In (037)

**Input**: Design documents from `specs/037-live-activity-controls/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/recording-lifecycle.md](contracts/recording-lifecycle.md), [quickstart.md](quickstart.md)

**Branch/worktree**: `feat/037-live-activity-controls` in `.claude/worktrees/030-us3-us4` (stacks on `feat/030-us3-us4` = App Intents US1–US4).

**Tests**: Test-first is MANDATORY for logic (Constitution X) — `RecordingSessionController`, the `RecordingState → ContentState` mapping, and the intent→controller routing. Write the test, RUN it, confirm it **FAILS (RED)**, then implement to **GREEN**, then refactor. SwiftUI/WidgetKit views (`CheckInLiveActivity`, Dynamic Island) are **EXEMPT** — verified by build + device QA (quickstart) behind an HTML-mockup gate (Constitution I). Tests use **Swift Testing** (`@Test`/`#expect`).

**Architecture**: MVVM + service-oriented (Constitution VIII) — matches the codebase. Two new `Services/` protocols injected via `AppDependencies`; `@MainActor @Observable` owner; heavy work stays off-main.

> **Implementation status (2026-07-17)**: the **full feature is authored, reviewed twice (adversarial multi-agent), and now BUILDS + passes its tests** (owner-confirmed ⌘B/⌘U 2026-07-17 — `LiveActivityContentStateTests`, `RecordingSessionControllerTests`, and the repaired `CheckInViewModelTests` all green; the only build fix was arranging an active capture in 2 stop-pipeline tests for the new idempotency guard). All phases are in: shared package + 3 intents, ActivityKit `LiveActivityController`, `RecordingSessionController` + finalize delegation, the `CheckInViewModel` surgery, DI wiring, the Lock Screen + Dynamic Island views, the mapper + controller tests. Committed as `14efba9c` + `1eebed4c` on `feat/037-live-activity-controls`. **Remaining:** (1) **device QA** — the Lock-Screen "Stop without unlock" gate (FR-005), pause/resume, Dynamic Island, a real call interruption; (2) two build-in-the-loop refinements FLAGGED (not blockers): make `AudioRecordingServiceImpl` `@MainActor` (pre-existing interruption race) + rewrite the VM elapsed timer to a wall-clock anchor (drift vs the Lock-Screen clock); (3) `/code-review` + PR + merge. See DEVLOG 2026-07-17.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: parallelizable (different files, no dependency on an incomplete task)
- **[Story]**: US1 / US2 / US3 (setup/foundational/polish carry no story label)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the extension target, the shared attributes package, and the platform declarations the whole feature needs.

- [ ] T001 Add a WidgetKit extension target **`SquirlWidgets`** ("Include Live Activity") to `app-four.xcodeproj`: `SquirlWidgets/SquirlWidgetsBundle.swift` (`@main WidgetBundle`) + its template Info.plist. Structural pbxproj edit — after adding, **Clean Build Folder + delete DerivedData** before the next build (see memory: pbxproj-structural-edit-clean-build).
- [ ] T002 Create a local Swift package **`SquirlLiveActivity`** (`SquirlLiveActivity/Package.swift`, iOS 26) to hold the shared `ActivityAttributes` type; add it as a dependency of BOTH the `app-four` app target and the `SquirlWidgets` extension target (research D2 — do not use per-file target membership under synchronized folders).
- [ ] T003 [P] Add `NSSupportsLiveActivities` = Boolean **YES** to the app target Info.plist in `app-four/Info.plist` (research D1; `UIBackgroundModes: audio` already present).
- [ ] T004 [P] Data-protection audit (research D13): confirm the app has **no** `com.apple.developer.default-data-protection = NSFileProtectionComplete` entitlement (Signing & Capabilities / entitlements). Record the finding; no code if absent (default is the lock-tolerant class).

**Checkpoint**: Extension target builds empty; shared package importable by both targets; app declares Live Activity support.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The shared attributes type, the process-level recording owner, and the ActivityKit controller — every user story needs these. **⚠️ No user story can begin until this phase is complete.**

### Tests (test-first · RED — MANDATORY) ⚠️

> Write these FIRST and RUN them — they MUST FAIL before implementation.

- [X] T005 [P] RED: `app-fourTests/Services/LiveActivityContentStateTests.swift` — the pure `RecordingState → RecordingActivityPhase` mapping table (data-model §2), the `ContentState` derivation, `phase == .paused ⇒ pausedAt != nil`, and the **privacy invariant**: an encoded `ContentState` contains no transcript / mood / medication substring (FR-016). Confirm FAIL.
- [ ] T006 [P] RED: `app-fourTests/Services/RecordingSessionControllerTests.swift` — lifecycle transitions (idle→recording→paused→resume→stop), **idempotent finalize by `captureID`** (finalize twice → exactly one saved `Recording`), stop-while-paused finalizes, and model-absent → pending path. Against mock `AudioRecordingService` / `RecordingStore` / `TranscriptionService` (existing `app-fourTests/Mocks` patterns). Confirm FAIL.

### Implementation

- [X] T007 Implement `CheckInActivityAttributes` (+ nested `ContentState: Codable & Hashable`) and `RecordingActivityPhase` in `SquirlLiveActivity/Sources/SquirlLiveActivity/CheckInActivityAttributes.swift`, plus the pure `RecordingState → ContentState` mapping. GREEN for T005. (data-model §1–§2)
- [X] T008 Define the `RecordingSessionController` and `LiveActivityController` protocols in `app-four/Services/Protocols.swift` (contracts §1–§2).
- [ ] T009 Implement `RecordingSessionControllerImpl` in `app-four/Services/Recording/RecordingSessionControllerImpl.swift` — process-level lifecycle owner extracted from `CheckInViewModel`: `start`/`pause`/`resume`/`stopAndSave`/`recoverIfNeeded`; **one idempotent capture-id-keyed finalize** wrapping the existing save pipeline (`pendingSave` buffer + transcription chaining, not a copy); start recorder via `record(forDuration: cap)` (research D17); wrap the awaited finalize in `UIApplication.beginBackgroundTask` (research D9). GREEN for T006.
- [ ] T010 Implement `LiveActivityControllerImpl` in `app-four/Services/LiveActivity/LiveActivityControllerImpl.swift` — `begin`/`update`/`end` via ActivityKit (`Activity.request/.update/.end(.immediate)`), maps phase→`ContentState`, **no-ops when Live Activities are unavailable/disabled** (FR-014); sets `staleDate` (research D3/D15).
- [ ] T011 Pin data protection to `.completeUntilFirstUserAuthentication` on the SwiftData store files (`.sqlite`/`-wal`/`-shm`) and the finalized audio file, in `app-four/App/AppModelContainer.swift` + `app-four/Services/Audio/AudioFileStorageServiceImpl.swift` (research D13; SwiftData `ModelConfiguration` has no protection knob → use `FileManager`/`URLResourceValues`).
- [ ] T012 Register both services in `app-four/Store/AppDependencies.swift` + `AppDependencyManager.shared.add(dependency:)` in `app-four/App/SquirlApp.swift`; wire `CheckInViewModel` (`app-four/ViewModels/CheckInViewModel.swift`) to delegate its recording lifecycle to `RecordingSessionController` while keeping view-only concerns (prompts, VoiceOver gate, cap cue). Build + **full suite green**.

**Checkpoint**: The recording lifecycle is owned by a background-safe process-level controller; the activity surface is drivable and privacy-safe. User stories can begin.

---

## Phase 3: User Story 1 — Stop-and-save from the Lock Screen without unlocking (Priority: P1) 🎯 MVP

**Goal**: Start a check-in, lock the phone, and end + save it from the Lock Screen in one tap, no unlock — saved entry identical to an in-app stop.

**Independent Test**: quickstart L1–L3, L6 + P1–P4 — lock, tap Stop on the Lock Screen indicator, confirm a saved journal entry equivalent to in-app, no unlock.

### Tests (test-first · RED — MANDATORY) ⚠️

- [ ] T013 [P] [US1] RED: `app-fourTests/Intents/RecordingControlIntentsTests.swift` — `StopRecordingIntent.perform()` calls `controller.stopAndSave()` exactly once; asserts it declares no `.requiresAuthentication` and a background-capable `supportedModes` (FR-005). Confirm FAIL.
- [ ] T014 [P] [US1] RED: extend `RecordingSessionControllerTests.swift` — `stopAndSave()` produces a saved `Recording` equivalent to the in-app stop (SC-003), and the `record(forDuration:)` finish path finalizes through the same idempotent call (research D17). Confirm FAIL.

### Implementation

- [X] T015 [US1] HTML mockup of the **Lock Screen** recording presentation (recording indicator + elapsed + Stop) → `specs/037-live-activity-controls/mockups/lock-screen.html` (Constitution I gate before SwiftUI).
- [ ] T016 [US1] Implement `StopRecordingIntent` (`LiveActivityIntent`, background `supportedModes`, default `.alwaysAllowed`) in `app-four/Intents/StopRecordingIntent.swift` → `controller.stopAndSave()`. GREEN for T013.
- [ ] T017 [US1] Implement the Lock Screen presentation in `SquirlWidgets/CheckInLiveActivity.swift` — recording indicator + `Text(timerInterval:)` elapsed (research D4) + Stop `Button(intent: StopRecordingIntent())`. SwiftUI, view-exempt (build + device QA).
- [ ] T018 [US1] Wire activity lifecycle: `RecordingSessionController.start()` calls `LiveActivityController.begin(...)`; `stopAndSave()` ends it (`.immediate`), so the surface appears < 1 s on start (SC-002) and clears within seconds on stop (SC-005). Enforce one-activity-at-a-time (FR-010).
- [ ] T019 [US1] Cap auto-stop while locked (FR-011): finalize from `audioRecorderDidFinishRecording(_:successfully:)` via the shared idempotent path; activity shows ended before removal (research D17).
- [ ] T020 [US1] Model-absent parity (FR-012): stop-from-activity while Whisper is absent → capture queued as pending through the existing `PendingTranscriptionService` path.

**Checkpoint**: MVP — build + full suite green; owner device-QA quickstart L1–L3, L6, P1–P4. **Stop here to validate/demo.**

---

## Phase 4: User Story 2 — Pause & resume from the Lock Screen (Priority: P2)

**Goal**: Pause and resume an in-progress check-in from the Lock Screen; the recording is one continuous capture minus the paused gap.

**Independent Test**: quickstart L4–L5, SC-008 — pause freezes the timer/indicator, resume continues, saved audio excludes the paused interval.

### Tests (test-first · RED — MANDATORY) ⚠️

- [ ] T021 [P] [US2] RED: extend `RecordingSessionControllerTests.swift` (pause→resume transitions, saved capture continuity) + `LiveActivityContentStateTests.swift` (paused `ContentState` sets `pausedAt`) + `RecordingControlIntentsTests.swift` (Pause/Resume intents route to `controller.pause()/resume()`). Confirm FAIL.

### Implementation

- [ ] T022 [US2] Implement `controller.pause()` / `resume()` in `RecordingSessionControllerImpl` — the **first real callers** of `audioService.pauseRecording()/resumeRecording()` (research D19 — currently dead); update the activity to `.paused`/`.recording`. GREEN.
- [ ] T023 [P] [US2] Implement `PauseRecordingIntent` + `ResumeRecordingIntent` (`LiveActivityIntent`) in `app-four/Intents/` → `controller.pause()/resume()`. GREEN for T021 routing.
- [ ] T024 [US2] Add Pause/Resume `Button(intent:)` to `SquirlWidgets/CheckInLiveActivity.swift`; the paused state freezes the timer via `Text(timerInterval:pauseTime:)` (research D4). View-exempt.

**Checkpoint**: US1 + US2 work independently — device-QA L4–L5.

---

## Phase 5: User Story 3 — Dynamic Island presence & controls (Priority: P3)

**Goal**: While in another app, the Dynamic Island shows the live recording and, when expanded, offers the same pause/resume/stop controls.

**Independent Test**: quickstart D1–D3 — compact shows status, expanded exposes the controls, behaving as the Lock Screen ones.

### Implementation (SwiftUI — view-exempt; controls reuse existing intents, no new logic)

- [ ] T025 [US3] HTML mockup of the **Dynamic Island** compact + expanded states → `specs/037-live-activity-controls/mockups/dynamic-island.html` (Constitution I gate).
- [ ] T026 [US3] Implement the Dynamic Island in `SquirlWidgets/CheckInLiveActivity.swift` — `DynamicIsland { }`: compact/minimal = recording glyph + elapsed (**display-only**), expanded region = elapsed + Pause/Resume/Stop `Button(intent:)` (research D5).
- [ ] T027 [US3] Verify control parity: expanded Dynamic Island buttons reuse the US1/US2 intents unchanged (no duplicated control logic).

**Checkpoint**: All three stories independently functional — device-QA D1–D3.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T028 [P] Terminated-app recovery (research D15, FR-007): write an in-progress capture marker at record-start (cleared atomically in the finalize transaction); on launch, end stale activities and recover/validate any orphaned capture via `pendingSave` / `PendingTranscriptionService`. RED test the reconcile logic first (`RecordingSessionControllerTests.swift`), then implement.
- [ ] T029 Interruption interplay (research D16, FR-008): finalize tolerates an already-stopped recorder (skip `stop()`, persist the closed file); activity reflects interrupted/paused on `AVAudioSession.interruptionNotification`. RED test the finalize-tolerance first.
- [ ] T030 [P] Reduce Motion static indicator + accessible labels on Pause/Resume/Stop (FR-015) in `SquirlWidgets/CheckInLiveActivity.swift`.
- [ ] T031 Tap-activity-body opens the app into the live check-in (FR-009) via the existing `AppIntentRouter` deep-entry path.
- [ ] T032 [P] Owner device QA — run the full [quickstart.md](quickstart.md) (A/B/C/D/E/F). **Gate**: P1 (locked SwiftData save succeeds) and P2 (`audioRecorderDidFinishRecording` fires while locked) must pass before FR-003/FR-011 are treated as closed; if either fails, fix (protection class / cap fallback) and correct research.md in the same PR.
- [ ] T033 Full suite + build green on the branch (Constitution II) — PR gate.
- [ ] T034 Update `docs/BACKLOG.md` (📐 → 🔨 In code, with branch) + `docs/DEVLOG.md`; open the PR; run `/code-review`; regenerate `docs/WORKLOG.md`.

---

## Dependencies & Execution Order

### Phase dependencies
- **Setup (P1)** → no deps.
- **Foundational (P2)** → depends on Setup; **blocks all user stories**.
- **US1 (P3)** → after Foundational. **US2 (P4)** → after Foundational (extends the controller + activity view from US1, but independently testable). **US3 (P5)** → after Foundational; reuses US1/US2 intents.
- **Polish (P6)** → after the desired stories.

### Within each story
- Tests written, RUN, confirmed FAILING (RED) before implementation (GREEN); refactor after (Principle X).
- Shared attributes → controller → intents → widget view.
- New SwiftUI surface gated by its HTML mockup (Constitution I).

### Parallel opportunities
- Setup: T003, T004 in parallel (after T001/T002).
- Foundational tests: T005, T006 in parallel (RED).
- US1 tests: T013, T014 in parallel. US2 test: T021.
- US3 is largely independent view work once US1/US2 intents exist.
- Polish: T028, T030, T032 in parallel.

## Parallel Example: Foundational RED tests
```
Task: "RED LiveActivityContentStateTests — mapping + privacy invariant (T005)"
Task: "RED RecordingSessionControllerTests — lifecycle + idempotent finalize (T006)"
```

---

## Implementation Strategy

### MVP (US1 only)
1. Phase 1 Setup → 2. Phase 2 Foundational (CRITICAL) → 3. Phase 3 US1 → 4. **STOP & VALIDATE** on device (locked stop-and-save) → demo.

### Incremental delivery
Setup + Foundational → US1 (MVP, locked stop) → US2 (pause/resume) → US3 (Dynamic Island) → Polish. Each story adds value without breaking the previous.

### Notes
- The two hardware-only checks (P1 locked save, P2 locked cap-finish) are the gate for calling FR-003/FR-011 closed — they can only pass on a physical locked device with the debugger detached.
- Constitution IX preserved (no new `@Model`, no `.unique`); Constitution VI reinforced (privacy invariant tested in T005).
- Commit after each task or logical group; keep `feat/037` stacked cleanly on `feat/030-us3-us4`.
