---
description: "Task list for Settings — recovery, privacy & clarity (017)"
---

# Tasks: Settings — recovery, privacy & clarity

**Input**: Design documents from `/specs/017-settings-recovery-privacy/`

**Prerequisites**: [plan.md](plan.md) (required), [spec.md](spec.md) (required for user stories). research.md + data-model.md are folded into plan.md.

**Tests**: Test-first is MANDATORY for logic (SwiftData `@Model` types, `Services/` implementations, `@MainActor @Observable` view-models) per Constitution **Principle X** — write the test, run it, confirm it **FAILS (RED)**, then implement just enough to make it **GREEN**, then refactor. SwiftUI **views are EXEMPT** (verified by build + on-simulator run via `ios-debugger-agent`). Tests use **Swift Testing** (`@Test`/`#expect`). `MockAIModelService` + `MockAppServices` already exist ([app-fourTests/Mocks/](../../app-fourTests/Mocks/)).

**Organization**: Grouped by user story so each slice is independently implementable, testable, and revertable. US1 and US4 are delete/clarity slices; US2 carries the engine-coordination seam; US3 is additive copy + the optional export.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies).
- **[Story]**: US1–US4 (maps to spec user stories) or SETUP/POLISH.
- Exact file paths are absolute-from-repo-root in each description.

## Path Conventions

- App: `app-four/…` · Tests: `app-fourTests/…` · Design doc: `DESIGN.md` (repo root).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Branch + confirm the test seam is usable before any slice.

- [ ] T001 [SETUP] Create branch `feat/017-settings-recovery-privacy` off `main`; confirm a clean build + green full suite as the baseline (`ios-debugger-agent`).
- [ ] T002 [SETUP] Restore the disabled `SettingsViewModelTests` ([app-fourTests/ViewModels/SettingsViewModelTests.swift](../../app-fourTests/ViewModels/SettingsViewModelTests.swift)) against the current `SettingsViewModel(store:services:)` init using `MockAppServices` ([app-fourTests/Mocks/MockAppServices.swift](../../app-fourTests/Mocks/MockAppServices.swift)): un-comment, fix the init to `SettingsViewModel(store: store, services: MockAppServices().services)`, and get the four existing tests (storage, checkModels installed/not-installed, recordingCount) GREEN. This is the regression net every later VM task builds on. *(Logic — but a restore of existing tests; run them and confirm GREEN before proceeding.)*

**Checkpoint**: Baseline green; `SettingsViewModelTests` runs against real mocks.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: None of the four user stories share a blocking dependency — they touch different concerns and can proceed in priority order after Setup. No global schema/infra change is required before US1 (the `AppSettings` edit is scoped to US1 itself).

**⚠️ No foundational phase.** Proceed to user stories. (US2 defines the engine seam *within* its own phase, coordinated with 015 — see T010.)

---

## Phase 3: User Story 1 - Honor system Reduce Motion / kill the dead control (Priority: P1) 🎯 MVP

**Goal**: Remove the in-app Reduce-Motion toggle and both orphaned stores; honor iOS only; add one static footer line. No runtime motion change.

**Independent Test**: No interactive motion control in Settings; iOS system Reduce Motion still stills the crescent/onset (unchanged); source search finds zero `reduceMotion`/`reduceMotionEnabled` app state; footer line renders.

### Tests for User Story 1 (test-first · RED — MANDATORY for logic) ⚠️

> **RED: write + run these FIRST; they MUST FAIL before implementation.**

- [ ] T003 [US1] In [app-fourTests/ViewModels/SettingsViewModelTests.swift](../../app-fourTests/ViewModels/SettingsViewModelTests.swift), add a test asserting `SettingsViewModel` exposes **no** `reduceMotion` property (compile-level: remove/replace the prior expectation) and that constructing the VM does not touch a `reduceMotion` UserDefaults key. Confirm RED against the current VM that still has `reduceMotion`.
- [ ] T004 [P] [US1] In [app-fourTests/Models/](../../app-fourTests/Models/) add `AppSettingsTests` (Swift Testing) asserting a freshly-initialized `AppSettings` has the expected defaults and **no `reduceMotionEnabled` member** (the test references the remaining attributes only; it fails to compile while the attribute/its init param still exist). Confirm RED.

### Implementation for User Story 1

- [ ] T005 [US1] Remove `reduceMotionEnabled` from [app-four/Models/AppSettings.swift](../../app-four/Models/AppSettings.swift) (stored property + `init` parameter + assignment). Run T004 → GREEN.
- [ ] T006 [US1] Remove the `_reduceMotion` backing store and the `reduceMotion` get/set (incl. the `UserDefaults["reduceMotion"]` read/write) from [app-four/ViewModels/SettingsViewModel.swift](../../app-four/ViewModels/SettingsViewModel.swift#L22). Run T003 → GREEN; run T002's restored suite → still GREEN.
- [ ] T007 [US1] In [app-four/Views/SettingsView.swift](../../app-four/Views/SettingsView.swift), delete the "Reduce Motion" `Toggle` ([#L117-L119](../../app-four/Views/SettingsView.swift#L117)) and add a single non-interactive muted-ink footer line to the Accessibility section (or its successor) stating Squirl follows the iOS motion setting (`Theme.textSecondary`, `Typography.caption`). *(View — build + run.)*
- [ ] T008 [US1] **Verify no regression**: with iOS system Reduce Motion ON in the simulator, confirm the Check-in crescent is still (no breathe/revolve), the medication-bar onset pulse is off, and Settings still builds. Source-grep confirms zero `reduceMotion`/`reduceMotionEnabled` references remain outside `@Environment(\.accessibilityReduceMotion)`. *(Build + run + grep.)*

**Checkpoint**: US1 shippable and revertable. The P0 dead control is gone; no motion behaviour changed.

---

## Phase 4: User Story 4 - Clarity S-pass: title, rename/relocate, scroll-gate, documented exemption (Priority: P2)

> Ordered before US2 because it is low-risk, fully independent, and clears the Accessibility section (already emptied of RM in US1) so the medical row relocates cleanly. Pure clarity; no engine dependency.

**Goal**: Visible "Settings" title (+ VoiceOver landmark); "Medical Context Prompt" → "Recognize medication names" relocated under Check-in/Transcription with an effect footer; scroll-to-top animation gated on Reduce Motion via a `Motion` token; native-chrome typography exemption documented.

**Independent Test**: Title shows + VoiceOver announces "Settings"; renamed control under Check-in/Transcription with footer, same transcription behaviour; scroll anim honors Reduce Motion; DESIGN.md records the exemption.

### Tests for User Story 4 (test-first · RED — MANDATORY for logic) ⚠️

- [ ] T009 [US4] In [app-fourTests/ViewModels/SettingsViewModelTests.swift](../../app-fourTests/ViewModels/SettingsViewModelTests.swift), add a test that the medical-vocabulary setting is still backed by `UserDefaults.medicalPromptEnabled` (default `true`) and that toggling the VM's `medicalPromptEnabled` flips that exact key — proving the rename/relocate is label-only (FR-022). Confirm it passes pre-change (it should, asserting current behaviour) then stays GREEN after the UI move. *(Behaviour-lock test for the relocation.)*

### Implementation for User Story 4

- [ ] T010 [US4] In [app-four/Views/SettingsView.swift](../../app-four/Views/SettingsView.swift#L18), pass `title: "Settings"` to `ScreenContainer` and mark the title as a VoiceOver heading/landmark. *(View — build + run; VoiceOver check.)*
- [ ] T011 [US4] In [app-four/Views/SettingsView.swift](../../app-four/Views/SettingsView.swift), rename the toggle label "Medical Context Prompt" → "Recognize medication names" and **move the row out of `accessibilitySection` into `checkInSection`** (or a "Transcription" subsection), with a footer "Helps transcription spell medication and side-effect terms correctly." Keep it bound to `viewModel.medicalPromptEnabled` (no value migration). Run T009 → GREEN. *(View — build + run.)*
- [ ] T012 [US4] In [app-four/Views/SettingsView.swift](../../app-four/Views/SettingsView.swift#L34), gate the tab-reselect scroll-to-top on Reduce Motion and replace the raw `.easeOut(duration: 0.25)` with a `Motion` token: read `@Environment(\.accessibilityReduceMotion)` and use `withAnimation(reduceMotion ? nil : Motion.smooth)`. *(View — build + run; matches the app-wide convention.)*
- [ ] T013 [P] [US4] In [DESIGN.md](../../DESIGN.md) Decisions Log, add a dated entry recording the **typography exemption**: Settings deliberately uses native iOS grouped-`List` system-font chrome (HIG-aligned, more learnable), exempt from "do not use SF/system as display or body." *(Docs — trivial; may go straight in.)*
- [ ] T014 [US4] **Verify**: simulator shows "Settings" title; VoiceOver reads a "Settings" heading; the renamed row sits under Check-in with its footer; scroll anim is stilled under Reduce Motion. *(Build + run.)*

**Checkpoint**: US4 shippable and revertable. Screen is readable; no behaviour changed.

---

## Phase 5: User Story 2 - Recover from a failed model download (Priority: P1)

**Goal**: Pre-download size/conditions line; inline cause-specific error (`noNetwork` / `insufficientSpace` / `cellularDisabled` / `other`) with a single "Try again"; cellular shortcut; Cancel during download; clean filesystem-truth after cancel/fail. **Consumes feature 015's download engine** — defines the minimal cause + cancel + reachability seam if 015 hasn't shipped it; never forks the download/queue.

**Independent Test**: Each simulated cause yields its distinct inline message + Retry; size/conditions line present pre-tap; in-progress download cancels to a clean "not installed"; retry-after-failure settles to "Installed" and clears the error.

### Coordination gate (do FIRST in this phase)

- [ ] T015 [US2] **015 seam decision.** Check whether feature 015 has landed (a) a typed `ModelDownloadFailure` surfaced from the download path, (b) a VM-callable cancel that leaves no installed/partial model, and (c) a reachability capability. If yes → consume them (skip the matching sub-tasks below). If no → implement the seam here, in `Services/`, where 015 will own it (T016–T018). Record the decision in the task notes. *(Decision/coordination — no code beyond notes.)*

### Tests for User Story 2 (test-first · RED — MANDATORY for logic) ⚠️

> **RED: write + run these FIRST; they MUST FAIL before implementation.**

- [ ] T016 [P] [US2] In [app-fourTests/Services/](../../app-fourTests/Services/) add `NetworkConditionServiceTests` (only if T015 = "add"): a `MockNetworkConditionService` returns constrained/cellular/wifi states; assert the protocol reports `isCellular`/`isConstrained` correctly. Confirm RED (type doesn't exist yet).
- [ ] T017 [US2] Extend [app-fourTests/Mocks/MockAIModelService.swift](../../app-fourTests/Mocks/MockAIModelService.swift) to inject a **specific** `ModelDownloadFailure` (not just a boolean throw) and to simulate cancel. Add a `SettingsViewModelTests` case asserting that when the engine reports `.noNetwork`, the VM's `downloadError` becomes `.noNetwork` and its user-facing message is the no-connection copy. Confirm RED.
- [ ] T018 [P] [US2] In `SettingsViewModelTests`, add cases asserting the **cause→copy mapping** is exhaustive and distinct: `.insufficientSpace` → space message (no "tap to retry" as the sole remedy), `.cellularDisabled` → cellular message + a `canAllowCellular` affordance flag true, `.other` → generic non-alarming message. Confirm RED.
- [ ] T019 [US2] In `SettingsViewModelTests`, add cases for the **state machine**: `cancelDownload()` sets `isDownloadingWhisper == false`, leaves `whisperModelInstalled == false` (filesystem truth), and clears progress; a successful retry after a failure sets `whisperModelInstalled == true` and `downloadError == nil`. Confirm RED.

### Implementation for User Story 2

- [ ] T020 [US2] (if T015 = "add") Define `ModelDownloadFailure` (enum, `Sendable`: `noNetwork`, `insufficientSpace`, `cellularDisabled`, `other(String)`) in [app-four/Services/Protocols.swift](../../app-four/Services/Protocols.swift) and surface it from the download path so the VM receives the cause (terminating stream value or rethrow — engine choice, 015-owned). Carry no transcript/med content. Run T017 → GREEN.
- [ ] T021 [P] [US2] (if T015 = "add") Add `NetworkConditionService` protocol + `Network`-framework impl (`NWPathMonitor`) in `Services/`, injected via [app-four/Store/AppServices.swift](../../app-four/Store/AppServices.swift) + [AppDependencies.swift](../../app-four/Store/AppDependencies.swift); register a mock in [MockAppServices.swift](../../app-fourTests/Mocks/MockAppServices.swift). Run T016 → GREEN.
- [ ] T022 [US2] Add `cancelDownload()` to [app-four/ViewModels/SettingsViewModel.swift](../../app-four/ViewModels/SettingsViewModel.swift): tear down the download stream/task and re-run `checkModels()` so the row reflects filesystem truth. Run the cancel half of T019 → GREEN.
- [ ] T023 [US2] In [app-four/ViewModels/SettingsViewModel.swift](../../app-four/ViewModels/SettingsViewModel.swift), add `downloadError: ModelDownloadFailure?` (observable), a `message(for:) -> String` mapping (plain-language, token copy), and a `canAllowCellular` flag; set `downloadError` from the engine's reported cause in `downloadModel`, and clear it on a new attempt/success. Run T018 + the retry half of T019 → GREEN; refactor.
- [ ] T024 [US2] In [app-four/Views/Components/ModelDownloadRow.swift](../../app-four/Views/Components/ModelDownloadRow.swift), add the **pre-download size/conditions line** ("~150 MB · Wi-Fi recommended") shown when not installed and not downloading, reusing the size already named in onboarding. *(View — build + run.)*
- [ ] T025 [US2] In [app-four/Views/Components/ModelDownloadRow.swift](../../app-four/Views/Components/ModelDownloadRow.swift), add the **inline error state** (cause message in `Theme.danger`, never raw red) with a single ghost-pill "Try again", and — for `.cellularDisabled` — a one-tap "Allow on cellular" (toggle `downloadOverCellular`) or open-iOS-settings shortcut (`UIApplication.openSettingsURLString`, per [CheckInView.swift#L41](../../app-four/Views/CheckIn/CheckInView.swift#L41)). Wire to the VM's `downloadError`/`message(for:)`/retry. *(View — build + run.)*
- [ ] T026 [US2] In [app-four/Views/Components/ModelDownloadRow.swift](../../app-four/Views/Components/ModelDownloadRow.swift), add a **Cancel** affordance while `isDownloading` (replacing the current hard tap-block at [#L46](../../app-four/Views/Components/ModelDownloadRow.swift#L46)) calling the VM's `cancelDownload()`. *(View — build + run.)*
- [ ] T027 [US2] **Accessibility pass on the row** (FR-013): `accessibilityElement(children: .combine)` with a label conveying state + action (download / downloading N% / error-cause + "Try again" / cancel), and `.accessibilityHidden(true)` on the decorative status dot ([#L36-L38](../../app-four/Views/Components/ModelDownloadRow.swift#L36)). Verify VoiceOver announces cause + available action; check Dynamic Type at AX sizes for the new lines. *(View — build + run + VoiceOver.)*
- [ ] T028 [US2] **Verify end-to-end**: simulate each cause (via the mock in dev/preview or by toggling conditions) → distinct message + Retry; cancel mid-download → clean "not installed"; retry success → "Installed", error cleared. Full suite GREEN. *(Build + run.)*

**Checkpoint**: US2 shippable and revertable. The one active task is recoverable; no silent failure remains; no engine fork.

---

## Phase 6: User Story 3 - "Your data": privacy statement + acknowledgements (Priority: P2)

**Goal**: A "Your data" section with an on-device privacy statement (onboarding voice) and an open-source/font acknowledgements list (WhisperKit; Fraunces / DM Sans / IBM Plex Mono under OFL). Greenlight + the optional encrypted-export build last.

**Independent Test**: "Your data" renders the on-device statement + acknowledgements naming WhisperKit and the three OFL fonts; copy matches onboarding voice with no marketing tone.

### Tests for User Story 3 (test-first · RED — MANDATORY only for built logic) ⚠️

> The privacy section is **static SwiftUI** (view — exempt). Tests apply **only if** the optional export phase (T032–T034) is taken.

### Implementation for User Story 3 — privacy footer (ships now)

- [ ] T029 [US3] Create [app-four/Views/Settings/YourDataSection.swift](../../app-four/Views/Settings/YourDataSection.swift): a `Section("Your data")` with one or two muted-ink lines restating the on-device promise (reuse [OnboardingView.swift#L175](../../app-four/Views/Onboarding/OnboardingView.swift#L175) voice) — recordings, check-ins, and signals stay on this device, not uploaded. Tokens only (`Theme.textSecondary`, `Typography`). *(View — build + run.)*
- [ ] T030 [US3] Add an **Acknowledgements** affordance within `YourDataSection` (inline rows or a pushed plain-text screen) crediting WhisperKit and Fraunces / DM Sans / IBM Plex Mono under the SIL Open Font License (FR-016). *(View — build + run.)*
- [ ] T031 [US3] Mount `YourDataSection` in [app-four/Views/SettingsView.swift](../../app-four/Views/SettingsView.swift), placed sensibly above the danger (`Clear All Data`) section so it reads as the trust home; build + run. *(View — build + run.)*

### Implementation for User Story 3 — encrypted export (OPTIONAL final phase; greenlit)

> Take this block only if the export build is in scope for 017 (else it ships in its own sibling spec — privacy footer above is independent and ships regardless). **Import/migrate is OUT of scope.**

- [ ] T032 [US3] **(RED)** Add `ExportServiceTests` in [app-fourTests/Services/](../../app-fourTests/Services/): assert an `ExportService` produces a single encrypted archive from a known set of recordings + check-ins + signals, that the output is encrypted (not plaintext-readable), and that an empty journal exports a valid (empty) archive. Confirm RED.
- [ ] T033 [US3] Implement `ExportService` protocol + impl behind [app-four/Store/AppServices.swift](../../app-four/Store/AppServices.swift): serialize the SwiftData graph + bundle audio + encrypt (CryptoKit), off the main actor. Run T032 → GREEN; refactor.
- [ ] T034 [US3] Add "Save a copy of my journal — yours to keep" via `fileExporter`/`ShareLink` in [app-four/Views/SettingsView.swift](../../app-four/Views/SettingsView.swift), placed **directly above** "Clear All Data" so the destructive path always offers "save a copy first." *(View — build + run.)*

**Checkpoint**: US3 privacy footer shippable independently; export (if taken) is the only piece with new logic and is fully tested.

---

## Phase 7: Polish & Cross-Cutting

- [ ] T035 [POLISH] Update [docs/BACKLOG.md](../../docs/BACKLOG.md) (Settings item → 🔨 In code with branch/PR) and add a [docs/DEVLOG.md](../../docs/DEVLOG.md) entry: the dead-control removal, the 015 download-seam coordination, the privacy footer, and the export greenlight/deferral. *(Docs.)*
- [ ] T036 [POLISH] Final full-suite + build pass on the branch (`ios-debugger-agent`); run `/code-review` on the diff and address findings before opening the PR. Confirm `main` stays releasable (each US slice independently revertable).

---

## Dependencies & Execution Order

### Phase / story order

- **Setup (Phase 1)** → no deps; do first. T002 restores the VM test net.
- **No Foundational phase** — stories are independent.
- **US1 (P1)** → smallest, delete-only; do first as MVP. Touches `AppSettings` + VM + view.
- **US4 (P2)** → independent clarity; ordered after US1 so the Accessibility section is already RM-free when the medical row relocates. No engine dep.
- **US2 (P1)** → the substantive slice; gated on the T015 015-seam decision. Independent of US1/US4 at the file level (different concerns in the same VM/view — sequence to avoid edit collisions).
- **US3 (P2)** → additive; privacy footer independent of all; export is the optional last block.
- **Polish (Phase 7)** → after the chosen slices land.

### Within each story

- Tests written + RUN + confirmed FAILING (RED) before implementation (GREEN); refactor after (Principle X).
- Model edits before VM edits before view edits.
- `ModelDownloadFailure` + reachability + cancel (logic) before the row's error/cancel UI.
- A story is complete and verified before moving to the next priority.

### Parallel opportunities

- [P] T004 (model test) ∥ T003 (VM test) — different files.
- [P] T013 (DESIGN.md) ∥ any US4 view task — docs vs code.
- [P] T016 (reachability test) ∥ T018 (cause-mapping test) — different test files.
- [P] T021 (reachability impl) ∥ T020 (failure enum) — different `Services/` units.
- Within a single file (e.g. `SettingsView.swift`, `ModelDownloadRow.swift`, `SettingsViewModel.swift`) tasks are **sequential** — no [P].

---

## Implementation Strategy

### MVP first

1. Phase 1 Setup (baseline green + restored VM tests).
2. **US1** (kill the dead control) → STOP and validate → shippable MVP (closes the only P0).
3. **US4** (clarity) → validate → ship.
4. **US2** (download recovery) → resolve T015 seam → validate → ship.
5. **US3** privacy footer → ship; export optionally last (or its own spec).

### Notes

- [P] = different files, no deps. [Story] maps each task to its spec user story.
- Verify tests FAIL (RED) before implementing; never write implementation ahead of its test (Principle X).
- Each task is a clean revertable checkpoint; commit per task or logical group.
- **Do not fork the download engine** — US2 consumes 015's cause + cancel, or defines the seam in `Services/` for 015 to own.
- Stop at any checkpoint to validate the story independently; each US slice is one revertable feature on the branch.
