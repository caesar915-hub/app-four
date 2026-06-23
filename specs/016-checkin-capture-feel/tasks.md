---
description: "Task list for Check-in — Capture That Lands"
---

# Tasks: Check-in — Capture That Lands

**Input**: Design documents from `/specs/016-checkin-capture-feel/`

**Prerequisites**: [plan.md](plan.md) (required), [spec.md](spec.md) (user stories). Research + data-model are inline in plan.md.

**Tests**: Test-first is MANDATORY for logic (`CheckInViewModel` behavior) per Constitution **Principle X** — write the test, run it, confirm it **FAILS (RED)**, then implement just enough to make it pass (**GREEN**), then refactor. SwiftUI **views are EXEMPT** (the Settle morph, the inline retry line, the first-launch hint, the paused visual, the a11y wiring on the view) — verified by **build + on-simulator run** via `ios-debugger-agent`. Tests use **Swift Testing** (`@Test`/`#expect`) and live in [app-fourTests/ViewModels/CheckInViewModelTests.swift](../../app-fourTests/ViewModels/CheckInViewModelTests.swift), using `MockAppServices`. Force save failure with `MockAudioRecordingService.shouldThrowError` ([MockAudioRecordingService.swift#L10](../../app-fourTests/Mocks/MockAudioRecordingService.swift#L10)) and/or a throwing storage mock.

**Organization**: Tasks are grouped by user story. Each task is ONE concern and a clean revertable checkpoint. Anything touching model+view+test is split.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files / independent, no ordering dependency)
- **[Story]**: US1–US5, or FND (foundational) / POL (polish)
- Paths are absolute-from-repo-root.

## Path Conventions

- View-model: `app-four/ViewModels/CheckInViewModel.swift`
- Views: `app-four/Views/CheckIn/{CheckInView,CrescentRing,TextCheckInComposer}.swift`
- Tests: `app-fourTests/ViewModels/CheckInViewModelTests.swift`

---

## Phase 1: Setup

**Purpose**: Branch + baseline green before touching anything.

- [ ] T001 [FND] Create/confirm branch `016-checkin-capture-feel` off `main`; run `ios-debugger-agent` to build the app and run the full test suite + the extraction eval — confirm baseline GREEN before any change (Principle II/VII/X). No code change in this task.

---

## Phase 2: Foundational (Blocking Prerequisite — the P1 correctness fix)

**Purpose**: The re-entry guard is a prerequisite for the Settle and the retry buffer (both reason about a single clean capture lifecycle). It is the P1 logic bug and must land first.

**⚠️ CRITICAL**: No user story work begins until Phase 2 is complete.

### Tests for Foundational (test-first · RED — MANDATORY) ⚠️

> **RED: Write these FIRST and RUN them — they MUST FAIL before T004.**

- [ ] T002 [FND] RED test: re-entry guard. In `CheckInViewModelTests.swift`, add a test that starting a recording while already `.recording` does NOT zero a live `elapsedTime` and does NOT call `startRecording` through to a second audio-session start (assert `state` stays `.recording`, `elapsedTime` preserved, and via the mock that `startRecording()` was not re-invoked / no duplicate start). Confirm it FAILS against current `CheckInViewModel.startRecording()` ([L46-85](../../app-four/ViewModels/CheckInViewModel.swift#L46)).

### Implementation for Foundational

- [ ] T003 [FND] GREEN: add the re-entry guard at the top of `startRecording()` in `app-four/ViewModels/CheckInViewModel.swift` — start only from a resettable state (`.idle`, or `.done` after `reset()`), early-return otherwise BEFORE `elapsedTime = 0` or the audio-session request; also clear stale `permissionDenied`/`lowDiskSpace` on a clean start (FR-016, [critique §4 P3](../../docs/ux-critique-checkin.md)). Run T002 → GREEN; refactor.
- [ ] T004 [FND] Harden the auto-start entry point: in `consumeAutoStart()` in `app-four/Views/CheckIn/CheckInView.swift` ([L54-59](../../app-four/Views/CheckIn/CheckInView.swift#L54)), early-return when state is `.recording`/`.paused`/`.processing` instead of calling `startRecording()` (FR-016). View change — verify by build + run (start a capture, switch tabs to retrigger auto-start, confirm no double-start). Full suite stays green.

**Checkpoint**: Re-entry bug eliminated (SC-005). Lifecycle is clean for US1/US2.

---

## Phase 3: User Story 1 — The Settle (Priority: P1) 🎯 MVP

**Goal**: Crescent→check morph + one success haptic at completion + single-"Done" Saved state, both save paths, Reduce-Motion safe.

**Independent Test**: Record → Stop & save → ring morphs into the check in place, one haptic at completion, single "Done" returns to hub; Reduce Motion shows the final check instantly with the same single haptic.

### Tests for User Story 1 (test-first · RED — MANDATORY for logic) ⚠️

> **RED: Write FIRST and RUN — MUST FAIL before implementation.**

- [ ] T005 [P] [US1] RED test: a completed save (mocked) lands the VM in `.done` exactly once and exposes a single "capture completed" signal the view can key the haptic+morph off (e.g. a monotonic `lastSavedRecording` set + `.done`), with no duplicate transition on re-entrant calls. In `CheckInViewModelTests.swift`. Confirm FAIL for any new VM signal added for the one-shot; if the existing `.done`/`lastSavedRecording` suffices, assert their single-set contract. (Logic only — the morph itself is view work, T007.)

### Implementation for User Story 1

- [ ] T006 [US1] GREEN (VM, if needed): ensure the VM exposes a clean once-per-capture completion signal for both paths (`stopRecording` [L99-119](../../app-four/ViewModels/CheckInViewModel.swift#L99) and `saveTextCheckIn` [L261-275](../../app-four/ViewModels/CheckInViewModel.swift#L261)) without double-firing. Run T005 → GREEN; refactor. (If `.done` + `lastSavedRecording` already satisfy it, this task only adds the assertion-backed guarantee, no behavior change.)
- [ ] T007 [US1] View: build the Settle morph in `app-four/Views/CheckIn/CrescentRing.swift` (a morphable variant / sibling `SettleRing` sharing one animatable canvas) — recording arc decelerates, contracts, and the stroke redraws into a checkmark in place rather than cross-dissolving, driven by a `progress` value; `progress = 1` instantly under `accessibilityReduceMotion` (FR-001, FR-003, R1). Use a `Motion` token, not a raw literal ([Motion.swift](../../app-four/DesignSystem/Motion.swift)). Build + run (visual check both normal + Reduce Motion).
- [ ] T008 [US1] View: host the Settle in `app-four/Views/CheckIn/CheckInView.swift` — replace the cross-dissolve to `CheckInSavedView`'s fresh checkmark ([L75](../../app-four/Views/CheckIn/CheckInView.swift#L75), [L286-294](../../app-four/Views/CheckIn/CheckInView.swift#L286)) so the ring settles in place into the Saved state; fire `Haptics.success()` ONCE at morph completion (or immediately under Reduce Motion), guarded one-shot per `.done` entry (FR-002, FR-003, R2). Build + run.
- [ ] T009 [US1] View: collapse the Saved actions to a single "Done" in `CheckInView.swift` — remove "Check in again" ([L308-311](../../app-four/Views/CheckIn/CheckInView.swift#L308)); "Done" calls `reset()` → idle hub (FR-004). Build + run.
- [ ] T010 [US1] View: route the text-save path through the same Settle + single haptic so a composer save lands identically (FR-002 AC4). Build + run (type a check-in, confirm same Settle + one haptic + single "Done").

**Checkpoint**: US1 fully functional + independently demoable (SC-001). The product's signature motion is delivered.

---

## Phase 4: User Story 2 — Never lose a capture (Priority: P1)

**Goal**: Retry buffer + calm inline "try again" replacing the silent reset; explicit discard; text-save failure surface.

**Independent Test**: Force a save failure → inline "try again" shows (no idle reset), buffer survives, retry (failure cleared) reaches Saved; discard clears + returns to hub.

### Tests for User Story 2 (test-first · RED — MANDATORY for logic) ⚠️

> **RED: Write FIRST and RUN — MUST FAIL before implementation.**

- [ ] T011 [P] [US2] RED test: on a stop/save failure (mock throws at save), the VM does NOT set `state = .idle`, sets a `saveFailed` flag, and retains the retry buffer (`pendingSave` non-nil). In `CheckInViewModelTests.swift`. Confirm FAIL against the current silent `state = .idle` ([L115-118](../../app-four/ViewModels/CheckInViewModel.swift#L115)).
- [ ] T012 [P] [US2] RED test: retry from the buffer succeeds → `saveFailed` cleared, `pendingSave` cleared, `state == .done`, recording added to the store. (Mock clears `shouldThrowError` before retry.) Confirm FAIL.
- [ ] T013 [P] [US2] RED test: retry that fails again keeps `saveFailed == true` and `pendingSave` non-nil (no discard, no idle). Confirm FAIL.
- [ ] T014 [P] [US2] RED test: explicit discard clears `pendingSave`, clears `saveFailed`, sets `state == .idle`. Confirm FAIL.
- [ ] T015 [P] [US2] RED test: a text-save failure sets `textSaveFailed` (not a silent drop) and does not lose the draft path. Confirm FAIL against current `saveTextCheckIn` returning `Void` ([L261-275](../../app-four/ViewModels/CheckInViewModel.swift#L261)).

### Implementation for User Story 2

- [ ] T016 [US2] GREEN (VM state machine): in `app-four/ViewModels/CheckInViewModel.swift`, add `pendingSave`/`saveFailed`; in `stopRecording()`'s catch, retain the `(fileURL, duration)` buffer and set `saveFailed` instead of `state = .idle` (FR-005, R3). Run T011 → GREEN; refactor.
- [ ] T017 [US2] GREEN (VM retry): add `retrySave()` that re-runs `storageService.saveRecording` from the buffer, on success clears buffer+flag and transitions to `.done` (FR-007). Run T012 + T013 → GREEN; refactor.
- [ ] T018 [US2] GREEN (VM discard): add `discardFailedCapture()` clearing the buffer (releasing the audio file) + flag and resetting to `.idle` (FR-008). Run T014 → GREEN; refactor.
- [ ] T019 [US2] GREEN (VM text failure): give `saveTextCheckIn` a non-alarming failure path setting `textSaveFailed` (FR-009). Run T015 → GREEN; refactor.
- [ ] T020 [US2] View: render the inline retry surface in `app-four/Views/CheckIn/CheckInView.swift` when `saveFailed` — a calm line "Couldn't save that one — tap to try again" (tap → `retrySave()`) plus a discard affordance (→ `discardFailedCapture()`); fire `Haptics.error()` once when the failure appears; recovery-framed copy, no red/alarm styling, ≥44pt targets (FR-006, FR-013). Build + run with a forced failure. Surface `textSaveFailed` comparably (FR-009).

**Checkpoint**: A capture can never silently vanish (SC-002). US1 + US2 both independently testable.

---

## Phase 5: User Story 3 — The recording experience is heard (Priority: P2)

**Goal**: Per-prompt VoiceOver announcements (gated on active voice), "Recording, elapsed" live region, "Saving…"/"Captured." transitions, 44pt controls.

**Independent Test**: VoiceOver on → hear prompt advances, hear elapsed, hear "Captured."; no announcement while actively speaking.

### Tests for User Story 3 (test-first · RED — MANDATORY for logic) ⚠️

> **RED: Write FIRST and RUN — MUST FAIL before implementation. (View-side `accessibility*` modifiers and `UIAccessibility.post` are exempt view work, verified by run; the VM-side `isSpeaking` gate is logic and IS tested.)**

- [ ] T021 [P] [US3] RED test: the VM derives an `isSpeaking` signal from the audio level — above a threshold ⇒ `true`, below ⇒ `false`. In `CheckInViewModelTests.swift`, drive a level value (or the mock stream) and assert the gate. Confirm FAIL (current `startLevelMonitoring` discards the level, [L290-297](../../app-four/ViewModels/CheckInViewModel.swift#L290)).
- [ ] T022 [P] [US3] RED test: a pending prompt-advance announcement is deferred while `isSpeaking == true` and becomes eligible once it drops to `false` (assert whatever VM-exposed "announce now / hold" state drives the view gate). Confirm FAIL.

### Implementation for User Story 3

- [ ] T023 [US3] GREEN (VM): wire `startLevelMonitoring()` to set `isSpeaking` from `audioLevelStream` ([Protocols.swift#L49-50](../../app-four/Services/Protocols.swift#L49)) with a named threshold (R4) — giving the previously-discarded stream its minimal job (the announcement gate, NOT a glow). Add the deferred-announcement gating state. Run T021 + T022 → GREEN; refactor.
- [ ] T024 [US3] View: announce prompt advances in `app-four/Views/CheckIn/CheckInView.swift` on `currentPromptIndex` change, suppressed while `isSpeaking` and flushed on the next quiet (FR-010, R4). Prefer SwiftUI `AccessibilityNotification.Announcement` (iOS 26), fall back to `UIAccessibility.post` if needed. Build + run with VoiceOver.
- [ ] T025 [US3] View: group the crescent + timer ([L169-182](../../app-four/Views/CheckIn/CheckInView.swift#L169)) into one accessibility element labeled "Recording, [elapsed] elapsed" as an `.updatesFrequently` live region, throttled to a coarse cadence so it doesn't chatter every 0.1s (FR-011, R4). Build + run with VoiceOver.
- [ ] T026 [US3] View: announce `.processing` → "Saving…" and `.done` → "Captured." transitions (FR-012). Build + run with VoiceOver.
- [ ] T027 [US3] View: bring the hand-rolled controls to ≥44pt — recording "Cancel" text button ([L177-180](../../app-four/Views/CheckIn/CheckInView.swift#L177)) and the new retry/discard affordances — and confirm Stop & save and the retry surface are VoiceOver-operable (FR-013, SC-006). Build + run.

**Checkpoint**: A VoiceOver user can complete a full check-in by audio alone (SC-003).

---

## Phase 6: User Story 4 — The 8-minute soft landing (Priority: P2)

**Goal**: One-time approach cue + graceful save-into-Settle at the cap (failure routes to US2 buffer).

**Independent Test**: Advance elapsed toward the cap → single approach cue once (no ticking); at the cap, saves through the Settle to the Saved screen.

### Tests for User Story 4 (test-first · RED — MANDATORY for logic) ⚠️

> **RED: Write FIRST and RUN — MUST FAIL before implementation.**

- [ ] T028 [P] [US4] RED test: `isApproachingCap` is `false` before `maxDuration − approachWindow` and `true` after; `hasShownCapApproach` flips once and the cue is one-shot (advancing further does not re-arm it). In `CheckInViewModelTests.swift`, driving `elapsedTime`. Confirm FAIL (no such state today).
- [ ] T029 [P] [US4] RED test: reaching the cap triggers the same stop/save path as a manual stop (assert it goes `.processing → .done` on success via the mock) — i.e. the capped save lands on the Settle path, not a hard drop (FR-015). Confirm FAIL/assert against `startTimer()`'s auto-stop ([L282-285](../../app-four/ViewModels/CheckInViewModel.swift#L282)). (Failure-at-cap routing to the US2 buffer is already covered by T011's path since both call `stopRecording()`.)

### Implementation for User Story 4

- [ ] T030 [US4] GREEN (VM): add `approachWindow` (named ~30s constant, documented), derived `isApproachingCap`, and one-shot `hasShownCapApproach` in `app-four/ViewModels/CheckInViewModel.swift` (FR-014, R5). Run T028 → GREEN; refactor. Confirm T029 passes — the cap routes through `stopRecording()` which now Settles via US1 (FR-015).
- [ ] T031 [US4] View: render a single faint "wrapping up soon" cue in `app-four/Views/CheckIn/CheckInView.swift` on the `isApproachingCap` transition, fading after a beat — NOT a ticking bar, no red, no alarm (FR-014, R5). Build + run (drive the timer near the cap).

**Checkpoint**: The cliff is a soft landing (SC-004); a capped save feels captured, not cut.

---

## Phase 7: User Story 5 — First-launch whisper hint (Priority: P3)

**Goal**: One-time headline hint + idle-ring caption, dismissed on first capture, never returns; ring stays purely ambient.

**Independent Test**: Fresh flag → both hints show; start a capture → they fade; later visits → never show.

> **Logic note**: this story is a single `@AppStorage` bool gating two `Text`s — pure view work, EXEMPT from unit-test-first (verified by build + run with the flag toggled). No VM logic, so no RED test task.

### Implementation for User Story 5

- [ ] T032 [US5] View: add `@AppStorage("checkInHintSeen")` to `app-four/Views/CheckIn/CheckInView.swift`; when unset, show the low-contrast headline hint under "Ready when you are." and a faint caption under the idle `CrescentRing` ([L99-100](../../app-four/Views/CheckIn/CheckInView.swift#L99)); set the flag `true` when any capture starts (voice or text) so both fade and never return (FR-018, R7). Keep the ring purely ambient — no fill/count/recency (FR-019). Build + run with the flag cleared and set.

**Checkpoint**: First-run orientation closed (SC-007); zero clutter for returning users.

---

## Phase 8: Polish & Cross-Cutting

**Purpose**: Token/metric cleanup, the minimal paused visual, motion-token alignment, and the final verification gate.

- [ ] T033 [P] [POL] View: give `.paused` a minimal honest visual distinct from `.recording` in `app-four/Views/CheckIn/CheckInView.swift` ([L72](../../app-four/Views/CheckIn/CheckInView.swift#L72)) — e.g. the crescent dims / stops revolving and a quiet "paused" label — with NO audio-append/resume engineering (FR-017, scope boundary). Build + run.
- [ ] T034 [P] [POL] View: replace remaining raw layout/animation literals touched by this feature with `Spacing`/`Metrics`/`Motion` tokens (the state crossfade `0.25` → `Motion.smooth`, [CheckInView.swift#L24](../../app-four/Views/CheckIn/CheckInView.swift#L24); dot/stop-square sizes per [critique §4](../../docs/ux-critique-checkin.md)); document any genuine content dimension (like `noteMinHeight`). Build + run.
- [ ] T035 [POL] Confirm no new data leaves the device and any added logging is counts/durations/state-names only (FR-020); confirm the Saved state still shows no transcribing UI / no daily card / no echo and the background extraction path is byte-for-byte unchanged (FR-021). Code audit + build.
- [ ] T036 [POL] Final gate: `ios-debugger-agent` build + FULL test suite GREEN + extraction eval floors not regressed (SC-008, Principle II/VII/X); run the device QA pass for the Settle, the retry surface, VoiceOver, and the cap cue (SC-001–SC-007). Then `/code-review` the diff before opening the PR.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (P1)**: none — start immediately.
- **Foundational (P2)**: depends on Setup; BLOCKS all user stories (the lifecycle guard underpins US1/US2).
- **US1 (P3)**: after Foundational. The signature motion + the single completion signal.
- **US2 (P4)**: after Foundational. Independent of US1's *visuals*, but a successful retry should land on the Settle — so US2's retry-success path is best demoed after US1 (functionally it only needs `.done`).
- **US3 (P5)**: after Foundational. The retry-surface a11y (T027) references US2's affordances, so run US3 after US2.
- **US4 (P6)**: after US1 (the cap's graceful save IS the Settle path).
- **US5 (P7)**: after Foundational; independent of US1–US4.
- **Polish (P8)**: after all desired stories.

### Within Each User Story

- RED test written, RUN, confirmed FAILING before implementation (Principle X).
- VM logic before its view wiring.
- Story complete + checkpoint before the next priority.

### Parallel Opportunities

- All `[P]` RED tests within a story author different test functions in the same file — write them together, but note they share `CheckInViewModelTests.swift` (serialize the actual edits or use distinct functions to avoid churn).
- US5 (T032) is fully independent and can be built any time after Foundational, in parallel with US1–US4.
- Polish T033/T034 are independent view edits and can run in parallel.

---

## Implementation Strategy

### MVP First (Foundational + US1)

1. Phase 1 Setup → baseline green.
2. Phase 2 Foundational → re-entry bug dead.
3. Phase 3 US1 → the Settle ships. **STOP & VALIDATE**: record → felt, single-Done capture. Demoable MVP.

### Incremental Delivery

1. + US2 → no capture can vanish (trust floor).
2. + US3 → the recording is heard (a11y).
3. + US4 → the cliff is a soft landing.
4. + US5 → first-run orientation.
5. + Polish → paused visual, tokens, final gate, `/code-review`.

Each story is an independently revertable checkpoint; `main` stays releasable throughout (Principle V).

---

## Notes

- `[P]` = different files / independent; same-file test tasks are marked `[P]` for planning but edit one file — keep functions distinct.
- Verify tests FAIL (RED) before implementing; never write implementation ahead of its test for VM logic (Principle X).
- Views (Settle morph, inline retry line, hint, paused visual, a11y wiring) are exempt — build + on-simulator run is the verification (Principle I/II).
- No schema change, no `Services/` protocol change, no new `@Model` (Principles VIII/IX).
- Commit after each task or logical group; one PR = this one revertable feature (Principle V).
