# Implementation Plan: UI Audit — Critical & Ship-Blocker Fixes

**Branch**: `fix/026-audit-critical-fixes` | **Date**: 2026-06-27 | **Spec**: [spec.md](spec.md)

**Input**: `specs/026-audit-critical-fixes/spec.md` (revised post-review)

**Status**: revised after adversarial plan review (constitution / fidelity / swift-correctness / test-design / phasing-risk). Corrections baked in: FR-001 child-view fix, FR-006 real-RED seam, FR-015 keep-detached, FR-017 internal guard, FR-018 inspection-only, FR-019 non-destructive re-entry handle, FR-007 two-clause predicate.

## Summary

Resolve the audit's ship-blocker findings (CrescentRing dead animation, two sub-44pt tap targets, unconfirmed delete, unguarded Reduce Motion, a `@MainActor` isolation gap, task leaks, phantom timer tick) plus the in-file accessibility and concurrency warnings, and harden the post-transcription recording lookup. All changes are localized edits to existing views and view-models — **no new architecture, no schema change, no new service**. Logic changes are RED-first via three minimal production seams (plus two test-only mock hang-flags); view changes are build + on-device verified per Principle X.

## Technical Context

**Language/Version**: Swift 6.2, strict concurrency (`SWIFT_STRICT_CONCURRENCY=complete`)
**UI**: SwiftUI, iOS 26+
**Persistence**: SwiftData (`@Model Recording`, `RecordingStore` wrapping a `ModelContext`)
**Async**: Swift Concurrency (`@MainActor @Observable` VMs, `Task`, `AsyncStream`)
**Testing**: Swift Testing (`@Test`/`#expect`), test-first for logic (Principle X), in-memory `ModelContainer`
**Target Platform**: iOS 26 (primary), iPadOS (secondary)
**Project Type**: Mobile app (single target `app-four`, module `app-four`, local SPM package `SquirlDesignSystem`)
**Constraints**: On-device only; owner runs device build/QA (no simulator use by Claude); `main` stays releasable
**Scale/Scope**: 12 source files + 3 test files, ~18 functional requirements, one revertable PR

## Constitution Check

- [x] **I. SwiftUI-First** — all edits modern SwiftUI; FR-007 reuses the existing `recording.status == .failed` affordance pattern and the existing `ADHDSummarySection` Regenerate button — not a new view. The one new *visible* element (a one-line "Couldn't summarize this check-in" failed row) has its copy + layout specified below (matching the existing "Retry transcription" treatment), so no improvised design; no HTML mockup required (in-place conditional branch, no navigation surface).
- [x] **II. Test-Build-Ship** — logic is test-first; owner builds + runs the full suite + device QA before PR.
- [x] **III. Correctness Over Speed** — US5 reframed honestly; FR-019 is non-destructive (does not cancel an in-flight commit-first regenerate); no dead code.
- [x] **IV. Minimal Surface** — three production seams (listed in Complexity Tracking), each the minimum for a RED test. FR-018 adds only a 2-line `deinit` (no seam). Two mock hang-flags are test-only.
- [x] **V. Solo Git Discipline** — one PR off `main`; `/code-review` before merge.
- [x] **VI. On-Device Privacy** — no storage/transmission/logging changes touching content.
- [x] **VII. Deterministic Extraction** — `NLNoteExtractor` untouched; FR-006 only changes how an already-extracted `Recording` is located. No eval impact.
- [x] **VIII. Service-Oriented Architecture** — fixes stay inside existing VMs/views; no new `Services/` protocol.
- [x] **IX. Pre-Release Data Posture** — **no schema change**; `RecordingStatus.failed` (AppEnums.swift:13) and `SummaryStatus.failed` (AppEnums.swift:96) already exist as `String` raw values.
- [x] **X. Test-First Development** — RED-first logic: **FR-006** (the one genuinely-RED case), **FR-015**, **FR-017**, **FR-019** (re-entry). GREEN characterization: **FR-006a**, `delete()`. Inspection/compile-only: **FR-018** (deinit; not RED-testable — see below), **FR-014** (annotation → SC-008). View FRs: build + device.

## Project Structure

```text
specs/026-audit-critical-fixes/   # spec.md, plan.md, research.md, data-model.md, tasks.md

app-four/
├── Views/
│   ├── CheckIn/
│   │   ├── CrescentRing.swift            # FR-001  extract AnimatedArc child + .id(isActive)
│   │   ├── CheckInView.swift             # FR-016  .task(id:) carrying the full guarded cue body
│   │   └── TextCheckInComposer.swift     # FR-003 tap target (inner disc + 44 hit area) + spacer, FR-005
│   ├── Components/
│   │   ├── AudioPlayerView.swift         # FR-002  44pt hit area via contentShape (disc stays 36)
│   │   ├── ADHDSummarySection.swift      # FR-007  failed-summary row (summaryStatus==.failed && !hasSummaryContent)
│   │   ├── MedicationLogSheet.swift      # FR-009  .isSelected trait on chips
│   │   ├── CalendarHeaderView.swift      # FR-011  omit empty hint on forceWeek
│   │   ├── TagFlowView.swift             # FR-012  hide decorative Image (L13)
│   │   └── ModelDownloadRow.swift        # FR-013  .isButton trait (no Button wrap)
│   ├── Settings/
│   │   └── JournalExportSection.swift    # FR-005  reduce-motion in RecoveryKeySheet (L66)
│   └── RecordingDetailView.swift         # FR-004/004a delete confirm, FR-005 (L142+L154), FR-007 wiring,
│                                         #   FR-010 transcript a11y, FR-019 startRegenerate (L30)
├── ViewModels/
│   ├── ProcessingViewModel.swift         # FR-006/006a FetchDescriptor lookup
│   ├── CheckInViewModel.swift            # FR-014 @MainActor, FR-015 preload handle, FR-017 advanceTick
│   └── RecordingDetailViewModel.swift    # FR-018 deinit, FR-019 summaryTask + startRegenerate()
└── Store/RecordingStore.swift            # read-only reference (store.context, deleteRecording)

app-fourTests/
├── ViewModels/
│   ├── ProcessingViewModelTests.swift    # EXTEND — FR-006 RED (stale-array), FR-006a GREEN char.
│   ├── CheckInViewModelTests.swift       # EXTEND — FR-015 RED, FR-017 RED
│   └── RecordingDetailViewModelTests.swift   # NEW — delete() char., FR-019 RED (re-entry)
└── Mocks/
    ├── MockTestTranscriptionService.swift    # add `loadModelHangs` flag (FR-015 RED determinism)
    └── MockSummarizationService.swift        # add `hangs` flag (FR-019 RED determinism)
```

**Structure Decision**: existing feature-folder layout preserved. New file: `RecordingDetailViewModelTests.swift` (scaffolded like `CheckInViewModelTests`: `ModelConfiguration(isStoredInMemoryOnly: true)` → `RecordingStore(context:)` → `MockAppServices().services`). Two mocks gain a hang-flag for deterministic cancellation tests. `SquirlDesignSystem` referenced only for `Metrics.minTapTarget` (no package edit).

## Architecture & Approach (per requirement)

### FR-001 — CrescentRing animation (View)
**Root cause**: `spinning`/`breathing` are `@State` **on `CrescentRing`** (CrescentRing.swift:10-11) and never reset; after one idle→record→idle cycle they're already `true`, so the `.animation(value:)` has no `false→true` change to fire. `arc` is a stateless computed view, so `.id()` on `arc` would NOT reset the parent's state.
**Fix**: extract a child view `AnimatedArc(isActive: Bool, lineWidth:)` that **owns** `@State private var animating = false`, runs `.onAppear { animating = true }`, and renders the spin (active) or breathe (idle) variant gated by `reduceMotion`. In `CrescentRing.body`, render `AnimatedArc(isActive: isActive, …).id(isActive)`. Flipping `isActive` gives the child a fresh identity → `animating == false` → `.onAppear` drives `false→true` every entry. The `.accessibilityHidden(true)` stays on the parent.

### FR-002 / FR-003 — Tap targets (View)
Both frames currently size the **visible** disc, so naive enlargement is a design regression. Keep the disc, expand only the hit area:
- AudioPlayerView (AudioPlayerView.swift:15): keep the 36pt disc on the inner content; wrap with `.contentShape(.rect)` + `.frame(minWidth: Metrics.minTapTarget, minHeight: Metrics.minTapTarget)`.
- TextCheckInComposer (TextCheckInComposer.swift:39): apply the visible 30pt `.frame` + `Circle()` background to the **inner label content**, then wrap with `.contentShape(.circle)` + `.frame(minWidth: Metrics.minTapTarget, minHeight: Metrics.minTapTarget)` so only the hit area is 44. **Also** set the balancing spacer at TextCheckInComposer.swift:51 to `Color.clear.frame(width: Metrics.minTapTarget, height: Metrics.minTapTarget)` to match the button's new laid-out width and keep the title centred.

### FR-004 / FR-004a — Delete confirmation (View gate)
Add `@State private var showDeleteConfirm = false`. The Menu's destructive button sets only `showDeleteConfirm = true`. Attach `.confirmationDialog("Delete this check-in?", isPresented: $showDeleteConfirm, titleVisibility: .visible)` at body level (near `.onDisappear`, RecordingDetailView.swift:72); its `role: .destructive` "Delete" action does `pendingDelete = true; dismiss()`. The existing teardown-delete (`.onDisappear { if pendingDelete { viewModel.delete() } }`, L72) is preserved verbatim — the documented [[feedback-delete-model-pattern]]. FR-004a: `.onAppear { showDeleteConfirm = false }`.

### FR-005 — Reduce Motion (View; three types / four sites)
Add `@Environment(\.accessibilityReduceMotion) private var reduceMotion` and gate `reduceMotion ? nil : …`:
- RecordingDetailView **L142** (`withAnimation`) **and L154** (`.animation(…, value:)`) — both.
- `RecoveryKeySheet` (JournalExportSection.swift:66) — env property on `RecoveryKeySheet`, not the outer section.
- TextCheckInComposer **L118** (`.animation(Motion.smooth, value: showSaveFailed)`).

### FR-006 / FR-006a — Robust recording lookup (Logic)
Replace `store.recordings.first { … }` (ProcessingViewModel.swift:52) with:
```swift
var d = FetchDescriptor<Recording>(predicate: #Predicate { $0.audioFileName == audioFileName })
d.fetchLimit = 1
guard let recording = try? store.context.fetch(d).first else {
    AppLogger.log("ProcessingViewModel: no Recording for \(audioFileName)")
    return
}
```
`audioFileName` is a non-optional `String` function parameter → clean `#Predicate` capture; mirrors `RecordingStore.loadRecordings()` (RecordingStore.swift:41-45). **Documented decision**: the new predicate is keyed on `audioFileName` only and is NOT mock-mode-filtered (unlike the in-memory array, RecordingStore.swift:40-45). `audioFileName` is UUID-derived and unique per recording (voice filename / `text-\(UUID())`), so a real/mock collision is impossible — the mock filter is unnecessary here. This is an accepted, stated divergence.
- **FR-006 (RED)**: the only genuinely-RED case. See Test Design.
- **FR-006a (GREEN characterization)**: the nil branch already logs + returns today, so a "nil → safe return, no mutation" test passes on both old and new code — it is a regression guard, not RED. It MUST NOT mutate a non-existent recording.

### FR-007 — Surface failed summaries (View; producer already exists)
`run()` already writes `summaryStatus = .failed` (ProcessingViewModel.swift:65) and `regenerateSummary()` exists (RecordingDetailViewModel.swift:37). Gap: no view reads `summaryStatus`, and `ADHDSummarySection` hides its card (+ Regenerate) when `hasSummaryContent` is false — the failed case. In `ADHDSummarySection`, add a failed row gated by the **two-clause** predicate `recording.summaryStatus == SummaryStatus.failed.rawValue && !hasSummaryContent`:
- **Copy/layout**: a single eyebrow `Text("Summary").cardEyebrow()` + body `Text("Couldn't summarize this check-in.").font(Typography.body).foregroundStyle(Theme.textSecondary)` + the existing Regenerate button (label "Regenerate summary"), inside a `.card()` matching the existing "Retry transcription" branch's visual treatment (RecordingDetailView.swift:159-164).
- **Regression guard**: legacy notes have `summaryStatus == nil` (Recording default) — they do NOT match, so the card stays hidden (Principle: no legacy regression). `.generating`/`.notGenerated` also don't match, so an in-flight regenerate never flashes the failed card. `Recording` is `@Model`/`@Observable`, so the view re-renders on `summaryStatus` change.
- The failed row's Regenerate MUST route through `viewModel.startRegenerate()` (FR-019), not a fresh inline Task.

### FR-009 – FR-013 — Accessibility (View)
- FR-009: `.accessibilityAddTraits(selected ? [.isSelected] : [])` on the `MedicationLogSheet` chip `Button`.
- FR-010: `.accessibilityLabel(isTranscriptExpanded ? "Transcript, expanded" : "Transcript, collapsed")` + hint on the transcript toggle; `transcriptionStatusPill.accessibilityHidden(true)`.
- FR-011: omit `.accessibilityHint` entirely when `forceWeek` (no empty string).
- FR-012: `.accessibilityHidden(true)` on `Image(systemName: tag.icon)` at **TagFlowView.swift:13**; optionally `.accessibilityElement(children: .combine)` per chip.
- FR-013: `.accessibilityAddTraits(.isButton)` on `ModelDownloadRow`'s existing combined element — **not** a Button wrap (would swallow its inner Cancel/ghost-pill buttons, ModelDownloadRow.swift:82, 123).

### FR-014 — @MainActor annotation (Compile-time)
`@MainActor private static func loadPromptInterval()` (CheckInViewModel.swift:351). A `static` member isn't covered by the type's `@MainActor`; the annotation makes its `mainContext` access statically checkable. Verified by SC-008, not a unit test.

### FR-015 — Preload task handle (Logic, RED)
The preload is `Task.detached(priority: .utility) { [transcriptionService] in … }` (CheckInViewModel.swift:143-149), unstored. **Keep `Task.detached`** — converting to a plain `Task` would inherit `@MainActor` and move the model load onto the main thread, defeating the off-main warm-up (comment L141-142). Assign it to `private(set) var modelPreloadTask: Task<Void, Never>?` and cancel it **only on the discard path `cancelRecording()`** (CheckInViewModel.swift:332), NOT `stopRecording()`. RED test: see Test Design.

### FR-016 — Cap-approach cue task (View)
The `.onChange(of: viewModel.isApproachingCap)` (CheckInView.swift:138-146) does more than the leaked Task: it guards the rising edge (`guard approaching, !hasShownCapApproach`), calls `markCapApproachShown()`, sets `showCapApproachCue = true`, then a bare `Task { sleep(4s); showCapApproachCue = false }`. Replace the whole thing with `.task(id: viewModel.isApproachingCap)` carrying the **entire guarded body**:
```swift
.task(id: viewModel.isApproachingCap) {
    guard viewModel.isApproachingCap, !viewModel.hasShownCapApproach else { return }
    viewModel.markCapApproachShown()
    withAnimation { showCapApproachCue = true }
    try? await Task.sleep(for: .seconds(4))
    withAnimation { showCapApproachCue = false }
}
```
The leading guard reads live `viewModel.isApproachingCap`, so the falling-edge rerun early-returns. `.task(id:)` auto-cancels on disappear/id-change. Device-verified.

### FR-017 — Timer phantom tick (Logic, RED)
In the timer loop (CheckInViewModel.swift:439-450), extract the increment into `func advanceTick()` with the guard **inside** it:
```swift
func advanceTick() {
    guard !Task.isCancelled else { return }
    elapsedTime += 0.1
}
```
The loop keeps the cap-check + `stopRecording(); break` (a `break` can't live in an extracted function) after calling `advanceTick()`. RED test: run `advanceTick()` inside a cancelled `Task` and assert `elapsedTime` unchanged (see Test Design).

### FR-018 — retryTask deinit (Inspection/compile)
Add `deinit { retryTask?.cancel() }` to `RecordingDetailViewModel` (`Task.cancel()` is nonisolated/Sendable — compiles on a `@MainActor` type). **Not RED-testable**: `retryTask = Task { @MainActor in … }` (RecordingDetailViewModel.swift:74) captures `self` strongly, so the VM cannot dealloc while the retry is in-flight — the deinit-cancels-in-flight-task scenario a test would need is unreachable without rewriting the capture to `weak self` (out of scope). Verified by inspection + the strict-concurrency build. No test seam added.

### FR-019 — Regenerate task handle (Logic, RED for re-entry; audit #19)
`onRegenerate: { Task { await viewModel.regenerateSummary() } }` (RecordingDetailView.swift:30) is fire-and-forget. Add `private(set) var summaryTask: Task<Void, Never>?` and:
```swift
func startRegenerate() {
    summaryTask?.cancel()              // cancel a prior in-flight regenerate before re-running
    summaryTask = Task { await regenerateSummary() }
}
```
The view calls `viewModel.startRegenerate()`. **Do NOT cancel `summaryTask` on `.onDisappear` or in `deinit`**: `regenerateSummary()` commits-first (nulls `summary`, sets `.notGenerated`, saves — RecordingDetailViewModel.swift:38-41) then awaits; cancelling mid-flight would strand the recording with a wiped summary. Because the `Task` retains `self`, an in-flight regenerate completes and persists even after the view is dismissed, then the VM deallocs — no leak, no strand. The handle exists to make **re-entry** safe (a second tap cancels the first, which is non-destructive because the second run re-commits). This resolves audit #19's "untracked handle" without the destructive cancel. Full cancellation-on-dismiss is deferred pending a commit-last refactor of `regenerateSummary` (noted in Deferred).
**Co-location**: FR-019's view edit (RecordingDetailView.swift:30 `onRegenerate: { viewModel.startRegenerate() }`) and FR-007's `ADHDSummarySection` edit touch the same L28-31 expression — land them together.

## Test Design (RED-first specifics)

- **FR-006 (RED)** — `ProcessingViewModelTests`: build `RecordingStore(context: container.mainContext)`; insert a `Recording` via `store.context.insert(r); try store.context.save()` **without** `addRecording`/`loadRecordings`, so `store.recordings` stays empty (stale). Run `processRawTranscription(...).value` with a deterministic `MockSummarizationService`. `#expect(r.summaryStatus == SummaryStatus.completed.rawValue)` and mood populated. **RED** against `store.recordings.first` (returns nil → no mutation); **GREEN** with `store.context.fetch`.
- **FR-006a (GREEN char.)** — insert nothing; run with an `audioFileName` that matches no row; `#expect` no crash and no mutation. Passes on both implementations (regression guard).
- **FR-015 (RED)** — add `var loadModelHangs = false` to `MockTestTranscriptionService` (mirror `MockAIModelService` hang pattern): `func loadModel() async throws { if loadModelHangs { while !Task.isCancelled { await Task.yield() } } }`. Set it true; `await startRecording().value` to spawn the in-flight preload; `await cancelRecording().value`; `#expect(viewModel.modelPreloadTask?.isCancelled == true)`. RED because no handle/cancel exists today.
- **FR-017 (RED)** — `viewModel.state = .recording; let t = Task { viewModel.advanceTick() }; t.cancel(); await t.value; #expect(viewModel.elapsedTime == 0)`. Deterministic (a freshly-cancelled Task body reads `Task.isCancelled == true`); RED without the internal guard, GREEN with it.
- **FR-019 (RED)** — add a `hangs` flag to `MockSummarizationService.summarize`. First `startRegenerate()`; capture `let first = viewModel.summaryTask`; second `startRegenerate()`; `#expect(first?.isCancelled == true)` and `#expect(viewModel.summaryTask != nil)`. RED because no handle/`startRegenerate` exists today.
- **`delete()` (GREEN char.)** — `RecordingDetailViewModelTests` (NEW): `store.addRecording(r); vm.delete(); #expect(store.recordings.isEmpty)` (matches `RecordingStoreTests.deleteRecording`).
- **FR-018** — no test (inspection + build, per above).

## Phasing (build order)

1. **Phase 1 — Logic** (RED-first where seam exists): FR-006 (RED) + FR-006a (GREEN char.); FR-015 (RED, with mock flag); FR-017 (RED); FR-019 VM side (RED re-entry, with mock flag); FR-018 deinit (inspection); `delete()` char. test. Add the two mock hang-flags here.
2. **Phase 2 — Compile-time**: FR-014. Folds into SC-008.
3. **Phase 3 — View mechanical**: FR-001, 002, 003, 004/004a, 005, 009, 010, 011, 012, 013, 016. Build + device QA.
4. **Phase 4 — View consumer**: FR-007 (+ FR-019 view-side wiring at RecordingDetailView.swift:28-31, landed in the same edit). Depends only on the already-present `summaryStatus=.failed` write (Phase 1 FR-006 does not gate it; different file). Build + device QA.

## Complexity Tracking

| Added surface | Why needed | Simpler alternative rejected because |
|---|---|---|
| `CheckInViewModel.modelPreloadTask` (`private(set)`) | FR-015 RED must assert cancellation | Fully `private` is unobservable from a test |
| `CheckInViewModel.advanceTick()` (guard inside) | FR-017 deterministic RED | Inline loop has no seam; a real-time 100 ms test is flaky |
| `RecordingDetailViewModel.summaryTask` + `startRegenerate()` | FR-019 cancellable, testable re-entry handle | Inline `Task {}` in the view body has no handle to assert/cancel |
| *(test-only)* `loadModelHangs` on `MockTestTranscriptionService`; `hangs` on `MockSummarizationService` | Make FR-015/FR-019 cancellation deterministic, not timing-bound | No-op mocks finish instantly → cancel races; flags are test-only, not shipped |

FR-018 adds only a 2-line `deinit` (no new observable surface). No new types/protocols/production files (besides the new test file).

## Verification

- **Logic (CI/owner)**: new RED→GREEN tests for FR-006 (stale-array fetch), FR-015 (preload cancel on discard), FR-017 (no phantom tick), FR-019 (re-entry cancels prior); GREEN characterization for FR-006a and `delete()`. Full suite green.
- **Build gate (SC-008)**: `SWIFT_STRICT_CONCURRENCY=complete` on `app-four` — 0 concurrency warnings (covers FR-014, FR-018 deinit).
- **Device QA (owner)**:
  - SC-001: **2nd consecutive** check-in — ring breathes in idle <1s, spins <1s after Speak (the bug only manifests on the second cycle).
  - SC-002: Accessibility Inspector — AudioPlayerView play/pause & TextCheckInComposer xmark ≥ 44×44pt; visible discs unchanged; title stays centred.
  - SC-004: delete needs menu-tap + confirm.
  - SC-005: Reduce Motion ON — no animation across the three views (both transcript sites).
  - SC-007: VoiceOver/Voice Control over the five FR-009–013 fixes.
  - FR-007: force a summary failure → "Couldn't summarize" + working Regenerate. **Negative**: a legacy note (`summaryStatus == nil`) and an in-flight `.generating` render **no** failed card.
- **Constitution re-check**: pass. Complexity Tracking lists every added surface.
