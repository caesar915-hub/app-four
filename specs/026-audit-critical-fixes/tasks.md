---
description: "Task list — spec 026 audit critical/ship-blocker fixes"
---

# Tasks: UI Audit — Critical & Ship-Blocker Fixes

**Input**: `specs/026-audit-critical-fixes/` (spec.md, plan.md, research.md, data-model.md)

**Tests**: Test-first is MANDATORY for logic (Principle X) — write the test, RUN it, confirm **RED**, implement to **GREEN**, refactor. SwiftUI views are EXEMPT (build + device). Swift Testing (`@Test`/`#expect`).

**Scope**: User Stories 1–5, 7, 8. US6 is deferred to `fix/027`.

**Same-file sequencing (NOT parallel)**:
- `RecordingDetailView.swift` — T021, T024, T030, T033 (sequence in this order).
- `CheckInViewModel.swift` — T011, T014, T026 (sequence).
- `RecordingDetailViewModel.swift` — T017, T019, T020 (sequence).
- `ProcessingViewModelTests.swift` — T008, T010 (sequence).

---

## Phase 1: Setup

- [ ] T001 Create branch `fix/026-audit-critical-fixes` off `main`.
- [ ] T002 [P] Add a `var loadModelHangs = false` gate to `loadModel()` in `app-fourTests/Mocks/MockTestTranscriptionService.swift` — `if loadModelHangs { while !Task.isCancelled { await Task.yield() } }`. Default false (no behavior change to existing tests). *(enables T008 RED determinism)*
- [ ] T003 [P] Add a `var hangs = false` gate to `summarize(...)` in `app-fourTests/Mocks/MockSummarizationService.swift` (suspend until cancelled when true). Default false. *(enables T018 RED determinism)*
- [ ] T004 [P] Scaffold NEW `app-fourTests/ViewModels/RecordingDetailViewModelTests.swift` — `@MainActor struct`, in-memory `ModelConfiguration(isStoredInMemoryOnly: true)` → `RecordingStore(context:)` → `MockAppServices().services`, building `RecordingDetailViewModel(recording:store:services:)` (mirror `CheckInViewModelTests` scaffold).

**Checkpoint**: mocks + test scaffold ready; all existing tests still green.

---

## Phase 2: Logic (test-first · RED → GREEN) — US5, US8, US3 ⚠️

> Write each test FIRST, RUN it, confirm it FAILS, then implement to GREEN.

### US5 — Robust recording lookup (FR-006/006a)

- [ ] T005 [US5] **RED**: in `app-fourTests/ViewModels/ProcessingViewModelTests.swift`, add a stale-array test — insert a `Recording` via `store.context.insert(r); try store.context.save()` **without** `addRecording`/`loadRecordings` (so `store.recordings` is stale), run `processRawTranscription(...).value` with a deterministic `MockSummarizationService`, `#expect(r.summaryStatus == SummaryStatus.completed.rawValue)`. RUN — confirm RED (old `store.recordings.first` returns nil).
- [ ] T006 [US5] **GREEN**: in `app-four/ViewModels/ProcessingViewModel.swift:52`, replace `store.recordings.first { … }` with `store.context.fetch(FetchDescriptor<Recording>(predicate: #Predicate { $0.audioFileName == audioFileName }))` (`fetchLimit = 1`); nil branch logs + returns (FR-006a, MUST NOT mutate). RUN — confirm GREEN. Keep the documented mock-mode non-filter decision (audioFileName is unique).
- [ ] T007 [US5] **GREEN characterization** (FR-006a): add a not-found test (no matching row) asserting no crash + no mutation. Passes on old + new (regression guard).

### US8 — Concurrency (FR-015, FR-017, FR-018, FR-019)

- [ ] T008 [US8] **RED**: in `app-fourTests/ViewModels/CheckInViewModelTests.swift`, FR-015 preload-cancel test — set `loadModelHangs = true`, `await startRecording().value`, `await cancelRecording().value`, `#expect(viewModel.modelPreloadTask?.isCancelled == true)`. RUN — confirm RED (no handle today).
- [ ] T009 [US8] **GREEN**: in `app-four/ViewModels/CheckInViewModel.swift:143-149`, keep `Task.detached`, assign to `private(set) var modelPreloadTask`; cancel it in `cancelRecording()` (CheckInViewModel.swift:332), NOT `stopRecording()`. RUN — confirm GREEN.
- [ ] T010 [US8] **RED**: in `CheckInViewModelTests.swift`, FR-017 phantom-tick test — `viewModel.state = .recording; let t = Task { viewModel.advanceTick() }; t.cancel(); await t.value; #expect(viewModel.elapsedTime == 0)`. RUN — confirm RED.
- [ ] T011 [US8] **GREEN**: in `CheckInViewModel.swift:439-450`, extract `func advanceTick()` with `guard !Task.isCancelled else { return }` then `elapsedTime += 0.1`; the loop keeps the `>= maxDuration → stopRecording(); break` after the call. RUN — confirm GREEN.
- [ ] T012 [US8] **RED**: in `RecordingDetailViewModelTests.swift`, FR-019 re-entry test — set `MockSummarizationService.hangs = true`, `viewModel.startRegenerate()`, capture `let first = viewModel.summaryTask`, `viewModel.startRegenerate()` again, `#expect(first?.isCancelled == true)` and `#expect(viewModel.summaryTask != nil)`. RUN — confirm RED.
- [ ] T013 [US8] **GREEN**: in `app-four/ViewModels/RecordingDetailViewModel.swift`, add `private(set) var summaryTask` + `func startRegenerate() { summaryTask?.cancel(); summaryTask = Task { await regenerateSummary() } }`. RUN — confirm GREEN. *(Do NOT cancel on disappear/deinit — destructive; see plan FR-019.)*
- [ ] T014 [US8] FR-018: add `deinit { retryTask?.cancel() }` to `RecordingDetailViewModel`. *(Inspection/compile — no test; verified by SC-008 build.)*

### US3 — Delete VM characterization

- [ ] T015 [US3] **GREEN characterization**: in `RecordingDetailViewModelTests.swift`, `store.addRecording(r); viewModel.delete(); #expect(store.recordings.isEmpty)`.

**Checkpoint**: full suite green; logic hardened.

---

## Phase 3: Compile-time — US8 (FR-014)

- [ ] T016 [US8] Annotate `@MainActor private static func loadPromptInterval()` in `app-four/ViewModels/CheckInViewModel.swift:351`. Verify by building under `SWIFT_STRICT_CONCURRENCY=complete` (SC-008).

---

## Phase 4: View mechanical (build + device QA — no unit tests) — US1, US2, US3, US4, US7, US8

- [ ] T017 [US1] FR-001: in `app-four/Views/CheckIn/CrescentRing.swift`, extract `AnimatedArc(isActive:)` child owning `@State private var animating` + `.onAppear { animating = true }` (reduceMotion-gated); render `AnimatedArc(isActive: isActive).id(isActive)`; keep `.accessibilityHidden(true)` on the parent.
- [ ] T018 [P] [US2] FR-002: in `app-four/Views/Components/AudioPlayerView.swift:15`, keep the 36pt disc on inner content; wrap with `.contentShape(.rect)` + `.frame(minWidth: Metrics.minTapTarget, minHeight: Metrics.minTapTarget)`.
- [ ] T019 [P] [US2] FR-003: in `app-four/Views/CheckIn/TextCheckInComposer.swift:39`, keep the 30pt disc on inner content; wrap with `.contentShape(.circle)` + `.frame(minWidth: Metrics.minTapTarget, minHeight: Metrics.minTapTarget)`; set the balancing spacer at L51 to `Color.clear.frame(width: Metrics.minTapTarget, height: Metrics.minTapTarget)`.
- [ ] T020 [P] [US7] FR-009: in `app-four/Views/Components/MedicationLogSheet.swift:75-85`, add `.accessibilityAddTraits(selected ? [.isSelected] : [])` to the chip `Button`.
- [ ] T021 [US3] FR-004/004a: in `app-four/Views/RecordingDetailView.swift`, add `@State private var showDeleteConfirm = false`; Menu button sets it true only; `.confirmationDialog("Delete this check-in?", isPresented: $showDeleteConfirm, titleVisibility: .visible)` at body level (near L72) with `role: .destructive` → `pendingDelete = true; dismiss()`; `.onAppear { showDeleteConfirm = false }`. Preserve the `.onDisappear` delete (L72).
- [ ] T022 [P] [US4] FR-005 (a): in `app-four/Views/Settings/JournalExportSection.swift:66`, add `@Environment(\.accessibilityReduceMotion)` to `RecoveryKeySheet`; gate `withAnimation(reduceMotion ? nil : Motion.smooth)`.
- [ ] T023 [P] [US4] FR-005 (b): in `app-four/Views/CheckIn/TextCheckInComposer.swift:118`, add `reduceMotion` env; `.animation(reduceMotion ? nil : Motion.smooth, value: showSaveFailed)`.
- [ ] T024 [US4] FR-005 (c): in `app-four/Views/RecordingDetailView.swift`, add `reduceMotion` env; gate **both** L142 (`withAnimation`) and L154 (`.animation(value:)`).
- [ ] T025 [P] [US7] FR-011: in `app-four/Views/Components/CalendarHeaderView.swift:69`, omit `.accessibilityHint` entirely when `forceWeek` (no empty string).
- [ ] T026 [P] [US7] FR-012: in `app-four/Views/Components/TagFlowView.swift:13`, add `.accessibilityHidden(true)` to `Image(systemName: tag.icon)`; optionally `.accessibilityElement(children: .combine)` per chip.
- [ ] T027 [P] [US7] FR-013: in `app-four/Views/Components/ModelDownloadRow.swift`, add `.accessibilityAddTraits(.isButton)` to the existing combined element (do NOT wrap in a Button — would swallow inner Cancel/ghost buttons).
- [ ] T028 [US8] FR-016: in `app-four/Views/CheckIn/CheckInView.swift:138-146`, replace the `.onChange` + bare `Task {}` with `.task(id: viewModel.isApproachingCap)` carrying the full guarded body (`guard viewModel.isApproachingCap, !viewModel.hasShownCapApproach else { return }` → `markCapApproachShown()` → show → `sleep(4s)` → hide).
- [ ] T029 [US7] FR-010: in `app-four/Views/RecordingDetailView.swift`, add `.accessibilityLabel(isTranscriptExpanded ? "Transcript, expanded" : "Transcript, collapsed")` + hint on the transcript toggle Button; `transcriptionStatusPill.accessibilityHidden(true)`.

**Checkpoint**: device QA — SC-001 (2nd-cycle ring), SC-002 (tap targets), SC-004 (delete), SC-005 (Reduce Motion), SC-007 (VoiceOver).

---

## Phase 5: View consumer — US5 (FR-007 + FR-019 view wiring)

- [ ] T030 [US5] FR-007 + FR-019 view side (one edit at `RecordingDetailView.swift:28-31`):
  - In `app-four/Views/Components/ADHDSummarySection.swift`, add a failed row gated by `recording.summaryStatus == SummaryStatus.failed.rawValue && !hasSummaryContent`: eyebrow "Summary" + `Text("Couldn't summarize this check-in.")` (secondary) + the Regenerate button (label "Regenerate summary"), in a `.card()` matching the transcription-failed treatment.
  - In `app-four/Views/RecordingDetailView.swift:30`, change `onRegenerate: { Task { await viewModel.regenerateSummary() } }` → `onRegenerate: { viewModel.startRegenerate() }`.
  - Device QA: force a summary failure → failed row + working Regenerate. **Negative**: legacy note (`summaryStatus == nil`) and `.generating` render NO failed card.

---

## Phase 6: Polish & Handoff

- [ ] T031 Self-review the full diff with `swiftui-pro` + `swift-concurrency-pro` + `swift-accessibility-skill` + `swiftui-design-principles`. Surface any corner cut.
- [ ] T032 Update `docs/BACKLOG.md` (026 → 🔨 In code, branch/PR) and add a `docs/DEVLOG.md` note (the why: audit-driven, US5 reframed).
- [ ] T033 Hand off to owner: build + full Swift Testing suite + `SWIFT_STRICT_CONCURRENCY=complete` (SC-008) + device QA checklist (SC-001–009). Then open PR off `main` and run `/code-review` before merge.

---

## Dependencies & Execution Order

- **Phase 1** (setup) → **Phase 2** (logic RED→GREEN) → **Phase 3** (compile-time) → **Phase 4** (views) → **Phase 5** (consumer) → **Phase 6** (handoff).
- Phase 2 is fully independent of Phases 3–5 and lands first (test-first discipline).
- **RED before GREEN**: T005→T006, T008→T009, T010→T011, T012→T013 — each test RUN and confirmed failing before its implementation.
- Phase 5 (FR-007) depends only on the already-present `summaryStatus=.failed` write — not on T006.
- Same-file tasks are sequenced (see header). `[P]` tasks touch distinct files.

## Parallel Opportunities

- Phase 1: T002, T003, T004 in parallel.
- Phase 4: T018, T019, T020, T022, T023, T025, T026, T027 in parallel (distinct files). T021/T024/T029 share `RecordingDetailView.swift` — sequence. T028 is `CheckInView.swift` (independent).

## Notes

- Owner runs all builds/device QA (no simulator use by Claude).
- Commit after each task or logical RED→GREEN pair.
- US6 (sheet routing) is OUT — `fix/027`.
