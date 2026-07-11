# Feature Specification: UI Audit — Critical & Ship-Blocker Fixes

**Feature Branch**: `fix/026-audit-critical-fixes`

**Created**: 2026-06-27

**Status**: Draft (revised after adversarial spec review — see Revision Note)

**Source**: `docs/AUDIT-UI-2026-06-27.md` — 10-skill parallel audit (127 raw → 90 deduplicated findings).

**Scope of this spec**: The audit's ship-blocker findings + the accessibility and concurrency warnings that live in the same files. Design-token / spacing / typography consistency and the `.tabItem`→`Tab` migration are deferred (see **Deferred (Named)**).

**Carve-out**: User Story 6 (MedicationBar sheet re-routing) is **excluded from this spec's plan and tasks** and moved to sibling branch `fix/027-medbar-sheet-routing` for independent review — it rewires sheet presentation app-wide through `RootTabView` and carries the highest regression risk. Documented here for traceability. In-scope for 026: User Stories 1–5, 7, 8.

---

## Revision Note (post-review)

A 5-reviewer adversarial pass (constitution / traceability / SwiftUI-soundness / testability / completeness), each grounded in the **actual source**, corrected the following before planning:

1. **US5 was rebuilt.** The "silent data-loss critical" (audit #7) is not reproducible: `RecordingStore.addRecording()` calls `loadRecordings()` synchronously after `insert()+save()` (RecordingStore.swift:52-56), so `store.recordings` is refreshed before extraction runs. FR-006 is now a **robustness refactor** (decouple the lookup from array-mutation timing via `store.context`), not a data-loss fix. FR-007 now targets the **real** gap the audit pointed at: a genuinely-failed *summary* is invisible and unrecoverable in the UI.
2. **No model/schema change.** `RecordingStatus.failed` (AppEnums.swift:13) and `SummaryStatus.failed` (AppEnums.swift:96) already exist; the pipeline already writes `summaryStatus = SummaryStatus.failed.rawValue` on the summarization-throw path (ProcessingViewModel.swift:65). Nothing is "added." Zero Principle-IX impact.
3. **Line numbers and fix mechanics corrected** throughout (tap targets, Reduce Motion sites, `loadPromptInterval`, preload-cancel target).
4. **Testability reclassified**: compile-time vs device-only vs unit-testable, per Principle X.
5. **Dropped warnings named** in a Deferred section; audit #19 (fire-and-forget regenerate Task, an in-scope-file concurrency warning) pulled into US8 as FR-019.

---

## Constitution Check

| Principle | Status |
|---|---|
| I. SwiftUI-First | ✅ Modern SwiftUI only, no UIKit. US5/FR-007 reuses/extends the **existing** failed-state affordance in `RecordingDetailView` (the `recording.status == .failed` "Retry transcription" branch, RecordingDetailView.swift:159-164) rather than introducing a new view surface — no HTML mockup required (in-place conditional branch, no new navigation surface). |
| II. Test-Build-Ship | ✅ Build + full suite required on branch before PR. Owner runs the device build. |
| III. Correctness Over Speed | ✅ Every fix resolves a verified issue. US5 was downgraded from an unproven critical to an honest robustness refactor + a real UX gap rather than shipping a fabricated bug fix. |
| IV. Minimal Surface | ✅ No new abstraction. The only new abstraction in the audit (MedicationBarEnvironmentAction) is the **deferred** US6. FR-006 stays inside the VM using the already-exposed `store.context` (RecordingStore.swift:9). |
| V. Solo Git Discipline | ✅ `fix/026-audit-critical-fixes` off `main`. PR + `/code-review` before merge. |
| VI. On-Device Privacy | ✅ No storage/transmission changes. |
| VII. Deterministic Extraction | ✅ `NLNoteExtractor` untouched. FR-006 only changes how the already-extracted recording is located. |
| VIII. Service-Oriented Architecture | ✅ Fixes stay inside their existing VM / view layers. |
| IX. Pre-Release Data Posture | ✅ **No schema change.** Both `.failed` enum cases pre-exist as `String` raw values; persisted type unchanged; CloudKit-compat untouched. |
| X. Test-First Development | ✅ See **Test-First Mapping**. Logic fixes that have a seam (FR-006, plus FR-017/FR-018 with the small seams named) are RED-first. Pure-annotation (FR-014) and view-only fixes (FR-001, 002, 003, 005, 009–013, 016) are build/device-verified — exempt under Principle X. |

---

## User Scenarios & Testing

### User Story 1 — Check-In Ring Animates on Every Session (Priority: P1)

A user who has completed one recording session returns to the Check-in tab. The CrescentRing breathes in idle and spins while recording — as on the first session.

**Why this priority**: Triggered on the **second check-in** — affects every returning user. After idle→recording→idle, `spinning`/`breathing` are already `true` (CrescentRing.swift:39, 46); SwiftUI's value-binding animation only fires on a change, so `true→true` never re-triggers. The ring goes permanently static.

**Independent Test** *(device-only)*: Record a check-in → save → return to Check-in tab. Ring must breathe. Tap Speak → ring must spin.

**Acceptance Scenarios**:

1. **Given** a user has completed ≥1 check-in, **When** they open the Check-in tab, **Then** the CrescentRing breathes (idle).
2. **Given** a user taps Speak on a subsequent session, **When** recording begins, **Then** the CrescentRing spins.
3. **Given** `accessibilityReduceMotion` is ON, **Then** the ring is static (existing `reduceMotion` guard preserved).

**Fix**: In [CrescentRing.swift](../../app-four/Views/CheckIn/CrescentRing.swift), extract an `AnimatedArc(isActive:)` child view that **owns** the animation `@State` (`animating`) and runs `.onAppear { animating = true }`; render it as `AnimatedArc(isActive: isActive).id(isActive)`. `spinning`/`breathing` are `@State` on `CrescentRing` itself, so `.id()` on the stateless `arc` would NOT reset them — the state must live on a child whose identity flips with `isActive`. Each entry then gets a fresh `animating == false`, so the `false→true` `.onAppear` transition fires every time. Preferred over dual `.onDisappear` resets (racy, per the original Edge Cases).

---

### User Story 2 — Every Tappable Element Meets the 44pt HIG Minimum (Priority: P1)

Users can reliably hit every interactive control on the first attempt.

**Why this priority**: Two controls are below 44pt: the play/pause button in `AudioPlayerView` (36pt) and the xmark dismiss in `TextCheckInComposer` (30pt). The dismiss is the **only escape** from the text check-in flow. Both are accessibility blockers.

**Independent Test** *(device-only — Accessibility Inspector)*: Both controls report a ≥ 44×44pt hit region with a centred activation point.

**Acceptance Scenarios**:

1. **Given** AudioPlayerView is visible, **When** a user taps within 44×44pt centred on the play/pause icon, **Then** playback toggles.
2. **Given** TextCheckInComposer is open, **When** a user taps within 44×44pt centred on the xmark, **Then** the composer dismisses.
3. **Given** Dynamic Type is at maximum, **Then** the tap target does not shrink below 44pt.

**Fix** *(use the existing `Metrics.minTapTarget = 44` token, not a literal)*:
- [AudioPlayerView.swift:15](../../app-four/Views/Components/AudioPlayerView.swift#L15): the play/pause `.frame(width: 36, height: 36)` sizes the **visible** gradient disc. To preserve the 36pt disc while meeting the hit-area minimum, wrap with `.contentShape(.rect)` + `.frame(minWidth: Metrics.minTapTarget, minHeight: Metrics.minTapTarget)` rather than enlarging the disc to 44.
- [TextCheckInComposer.swift:39](../../app-four/Views/CheckIn/TextCheckInComposer.swift#L39): the xmark `.frame(width: 30, height: 30)` sizes the visible Circle+border. Wrap the labelled content with `.contentShape(.circle)` + `.frame(minWidth: Metrics.minTapTarget, minHeight: Metrics.minTapTarget)`. **Also** update the balancing `Color.clear.frame(width: 30, height: 30)` spacer at [TextCheckInComposer.swift:51](../../app-four/Views/CheckIn/TextCheckInComposer.swift#L51) to the same final width, or the centred title de-centers.

---

### User Story 3 — Check-In Deletion Requires Explicit Confirmation (Priority: P1)

A user who opens the delete menu does not lose a check-in to a single tap.

**Why this priority**: "Delete check-in" sets `pendingDelete = true` and dismisses immediately (RecordingDetailView.swift:51-54); the SwiftData delete fires in `.onDisappear` (RecordingDetailView.swift:72). No confirmation, no undo.

**Independent Test** *(device-only)*: Menu → "Delete check-in" → a confirmation dialog appears; Cancel leaves the check-in intact; Delete removes it.

**Acceptance Scenarios**:

1. **Given** a user taps "Delete check-in", **When** the menu action fires, **Then** a `confirmationDialog` titled "Delete this check-in?" appears — the check-in is NOT yet deleted.
2. **Given** the dialog is showing, **When** the user taps "Delete", **Then** `pendingDelete = true`, the view dismisses, and the `.onDisappear` teardown-delete (L72) removes it.
3. **Given** the dialog is showing, **When** the user taps "Cancel", **Then** nothing is deleted.
4. **Given** VoiceOver is on, **When** the dialog appears, **Then** focus moves to it and labels read correctly.

**Fix**: [RecordingDetailView.swift:51](../../app-four/Views/RecordingDetailView.swift#L51) — add `@State private var showDeleteConfirm = false`; the menu button sets `showDeleteConfirm = true` only. Attach `.confirmationDialog(isPresented: $showDeleteConfirm)` **at body level** (near the existing `.sheet`/`.onDisappear`, ~L65–72), with a `role: .destructive` "Delete" action doing `pendingDelete = true; dismiss()`. The existing `.onDisappear` delete pattern (L72) is preserved unchanged.

*Unit-testable seam*: `RecordingDetailViewModel.delete()` removing the recording from the store is RED-testable (insert → `delete()` → assert empty). The confirmation **gate** itself is view `@State` — device-verified.

---

### User Story 4 — Motion-Sensitive Users Get No Animation (Priority: P1)

With "Reduce Motion" ON, three views produce no animation — matching the existing pattern in `CrescentRing`/`CalendarLibraryView`.

**Why this priority**: Three views ignore `@Environment(\.accessibilityReduceMotion)`. RecordingDetailView's transcript animation is a vestibular blocker.

**Acceptance Scenarios** *(device-only)*:

1. **Given** Reduce Motion ON, **When** the user toggles the transcript in `RecordingDetailView`, **Then** the content **and the chevron** change instantly (both sites gated).
2. **Given** Reduce Motion ON, **When** the user taps "Copy key" in `RecoveryKeySheet`, **Then** `copied` changes instantly.
3. **Given** Reduce Motion ON, **When** a save failure occurs in `TextCheckInComposer`, **Then** the error appears instantly.
4. **Given** Reduce Motion OFF, **Then** the original animation plays.

**Fix** — add `@Environment(\.accessibilityReduceMotion) private var reduceMotion` to each type and gate `reduceMotion ? nil : …`:
- [RecordingDetailView.swift:142](../../app-four/Views/RecordingDetailView.swift#L142) (`withAnimation` in the toggle action) **and** [RecordingDetailView.swift:154](../../app-four/Views/RecordingDetailView.swift#L154) (`.animation(…, value: isTranscriptExpanded)` on the chevron) — **both**.
- [JournalExportSection.swift:66](../../app-four/Views/Settings/JournalExportSection.swift#L66) — the `withAnimation(Motion.smooth) { copied = true }` inside the **`RecoveryKeySheet`** type (add the env property to `RecoveryKeySheet`, not the outer section).
- [TextCheckInComposer.swift:118](../../app-four/Views/CheckIn/TextCheckInComposer.swift#L118) — `.animation(Motion.smooth, value: showSaveFailed)`.

*Optional unit seam*: lift each ternary to a pure `animation(reduceMotion:)` helper returning `nil` when true — cheap RED test, removes eyeballing.

---

### User Story 5 — Recording Lookup Is Robust, and Failed Summaries Are Recoverable (Priority: P2)

**Revised after review.** Two distinct, real concerns — neither is the unproven "stale-array data loss" of audit #7.

**5a — Robust lookup (FR-006).** `ProcessingViewModel.run()` locates the recording via a fresh `FetchDescriptor` query rather than the cached in-memory array, decoupling extraction from array-mutation timing.

**5b — Recoverable failed summary (FR-007).** When summarization genuinely fails for a found recording, the user sees that it failed and can retry. Today `ProcessingViewModel` sets `summaryStatus = SummaryStatus.failed.rawValue` (L65), but **no view reads `summaryStatus`** (grep: 0 hits in `Views/`) and the Regenerate button (ADHDSummarySection) is gated behind `hasSummaryContent`, so a failed-summary recording shows neither an error nor a retry.

**Why P2 (down from P1)**: 5a is a latent robustness improvement, not a reproduced bug. 5b is a real but bounded UX gap.

**Independent Test**:
- *5a (unit)*: persist a Recording, leave `store.recordings` stale (don't reload), call `run()`, assert it still finds the row and populates mood/signals — deterministic, no time bound.
- *5b (device)*: force a summary failure (mock), open the recording, see a failed indicator + working retry.

**Acceptance Scenarios**:

1. **Given** a saved voice check-in, **When** `run()` executes, **Then** the Recording is located via `store.context.fetch(FetchDescriptor<Recording>(predicate: #Predicate { $0.audioFileName == audioFileName }))` — not `store.recordings.first { }`.
2. **Given** the fetch returns nil (genuine not-found), **When** `run()` detects it, **Then** it logs and returns safely (there is no recording object to mutate — it MUST NOT attempt `recording.status = .failed`).
3. **Given** summarization fails for a found recording (`summaryStatus == .failed`), **When** the user opens it in `RecordingDetailView`, **Then** a failed-summary state is visible with a retry action, reconciled with the existing `recording.status == .failed` "Retry transcription" branch (L159-164) and the gated Regenerate button — one coherent failed surface, not three.

**Dependencies / build order**: FR-006 (lookup) and the `summaryStatus` write are the **producer**; the `RecordingDetailView` surface (FR-007) is the **consumer** and MUST be built after the producer writes a readable marker. Sequence: (1) FR-006 lookup, (2) confirm/keep `summaryStatus=.failed` write, (3) add/ungate the view surface.

**Fix**:
- [ProcessingViewModel.swift:52](../../app-four/ViewModels/ProcessingViewModel.swift#L52) — replace the in-memory lookup with `store.context.fetch(FetchDescriptor…)`; nil branch logs + returns.
- [RecordingDetailView.swift:159](../../app-four/Views/RecordingDetailView.swift#L159) + [ADHDSummarySection.swift:13](../../app-four/Views/Components/ADHDSummarySection.swift#L13) — surface `summaryStatus == .failed` (ungate the Regenerate button for the failed case, or add a compact failed row), reconciled with the existing transcription-failed branch. Align button copy ("Regenerate summary" vs the existing "Retry transcription").

---

### User Story 6 — Medication Log Sheet Presents Reliably (Priority: P2) — DEFERRED

> **Status: carved out to sibling branch `fix/027-medbar-sheet-routing`.** Documented for traceability; NOT part of this spec's plan or tasks.

A user tapping "Log new dose" from the MedicationBarView while any sheet is open sees the `MedicationLogSheet` appear — the sheet is not silently dropped (iOS swallows a `.sheet()` presented from inside an active sheet).

---

### User Story 7 — VoiceOver Users Can Fully Operate the App (Priority: P2)

Users navigating with VoiceOver/Voice Control encounter no unlabelled buttons, color-only state, or decorative images read as content.

**Acceptance Scenarios** *(device-only)*:

1. **Given** VoiceOver in `MedicationLogSheet`, **When** a med chip is selected, **Then** it announces "[name], selected" via `.accessibilityAddTraits(.isSelected)` on the chip `Button` (MedicationLogSheet.swift:75-85) — not via the label string.
2. **Given** VoiceOver in `RecordingDetailView`, **When** focus lands on the transcript toggle, **Then** it announces "Transcript, expanded/collapsed" + hint "Double tap to toggle"; the `transcriptionStatusPill` inside the label (RecordingDetailView.swift:149) is `.accessibilityHidden(true)`.
3. **Given** VoiceOver in `CalendarHeaderView` with `forceWeek == true`, **Then** the expand/collapse button supplies **no** `.accessibilityHint` (the `.accessibilityHint("")` empty-string smell at L69 is removed — omit the modifier when `forceWeek`).
4. **Given** VoiceOver and `TagFlowView`, **Then** the `Image(systemName: tag.icon)` at TagFlowView.swift:12 is `.accessibilityHidden(true)` (the `SignalGlyph` path is already decorative); prefer `.accessibilityElement(children: .combine)` per chip.
5. **Given** Voice Control / Full Keyboard Access in Settings, **Then** `ModelDownloadRow` is recognised as actionable.

**Fix note (FR-013)**: `ModelDownloadRow` (ModelDownloadRow.swift:25-50) is a `VStack + .onTapGesture` that already does `.accessibilityElement(children: .combine)` + `.accessibilityActions` (L59-61) and contains its **own** inner `Cancel`/ghost-pill Buttons (L82, L123). Wrapping the whole VStack in a `Button` would swallow those inner controls' hits. Add `.accessibilityAddTraits(.isButton)` to the existing combined element instead.

---

### User Story 8 — Concurrency Is Sound Under Swift 6 Strict Checking (Priority: P2)

No Swift 6 isolation violations, no Tasks that outlive their view, no phantom timer ticks.

**Acceptance Scenarios**:

1. *(compile-time — SC-008)* `CheckInViewModel.loadPromptInterval()` is `@MainActor`; verified by the strict-concurrency build, not a unit test.
2. *(unit, with seam)* The model-preload Task handle is stored and cancelled **on the discard path** (`cancelRecording()`), not on `stopRecording()`.
3. *(device-only)* The cap-approach work in `CheckInView.onChange` no longer outlives the view.
4. *(unit, with seam)* After cancellation, the recording timer fires no phantom tick.
5. *(unit/inspection)* `RecordingDetailViewModel` cancels `retryTask` on dealloc.
6. *(device/inspection)* The regenerate Task on the RecordingDetailView button no longer leaks (audit #19).

---

### Edge Cases

- **CrescentRing** (US1): the `.id(isActive)` approach removes the reset-ordering race entirely (fresh `@State` on every entry), so no ordering guarantee is needed.
- **ProcessingViewModel** (US5a): two rapid saves each resolve their own `FetchDescriptor` independently; the fetch is keyed by `audioFileName`, which is unique per save.
- **Failed summary** (US5b): on repeated failure the retry remains available; an empty transcript (nothing to summarize) shows the failed state, not a spinner.
- **Delete confirmation** (US3): backed by FR-004a — `showDeleteConfirm` resets to `false` on view reappear so a backgrounded mid-dialog state does not delete.
- **Reduce Motion** (US4): toggling mid-flight is handled by SwiftUI's environment propagation; no extra requirement.
- *(Removed)* The sheet-over-sheet edge case — it belonged to the deferred FR-008.

---

## Requirements

### Functional Requirements

- **FR-001**: CrescentRing MUST move the spin/breathe animation `@State` into an `AnimatedArc(isActive:)` child view and apply `.id(isActive)` to that child, so the state re-initialises to `false` on each branch entry and re-triggers the `false→true` animation. (`.id()` on the stateless `arc` would not reset the parent's `@State`.) (View; device-verified.)
- **FR-002**: AudioPlayerView play/pause MUST present a ≥ `Metrics.minTapTarget` (44pt) hit area via `.contentShape` + min-frame, preserving the 36pt visual disc. (View.)
- **FR-003**: TextCheckInComposer dismiss (xmark) MUST present a ≥ `Metrics.minTapTarget` hit area via `.contentShape` + min-frame; the balancing spacer (L51) MUST match the final width. (View.)
- **FR-004**: RecordingDetailView MUST present a `confirmationDialog` (attached at body level) before any deletion; `pendingDelete` MUST be set only in the dialog's destructive action; the existing `.onDisappear` delete (L72) is preserved. (View gate.)
- **FR-004a**: `showDeleteConfirm` MUST reset to `false` on view reappear. (View.)
- **FR-005**: `RecordingDetailView` (both L142 and L154), `RecoveryKeySheet` (in JournalExportSection.swift, L66), and `TextCheckInComposer` (L118) MUST read `@Environment(\.accessibilityReduceMotion)` and suppress their animation when ON. (View.)
- **FR-006**: `ProcessingViewModel.run()` MUST locate the target `Recording` via `store.context.fetch(FetchDescriptor<Recording>(predicate: #Predicate { $0.audioFileName == audioFileName }))`, replacing the in-memory `store.recordings.first { }`. (Logic; **RED-first**.)
- **FR-006a**: If the fetch returns nil, `run()` MUST log and return without crashing; it MUST NOT attempt to mutate a non-existent recording. (Logic; RED-first.)
- **FR-007**: A genuinely-failed summary (`summaryStatus == SummaryStatus.failed.rawValue`) MUST be visible and recoverable in `RecordingDetailView`, reconciled into a single failed surface with the existing `recording.status == .failed` retry branch (L159-164) and the (currently gated) Regenerate button. No new model case or migration is involved. (View + wiring; device-verified, depends on FR-006.)
- **FR-009**: `MedicationLogSheet` med chips MUST convey selected state via `.accessibilityAddTraits(selected ? [.isSelected] : [])` on the chip `Button`. (View.)
- **FR-010**: The `RecordingDetailView` transcript toggle MUST have an explicit `.accessibilityLabel` ("Transcript, expanded/collapsed") + hint; the inner `transcriptionStatusPill` MUST be `.accessibilityHidden(true)`. (View.)
- **FR-011**: The `CalendarHeaderView` expand/collapse button MUST omit `.accessibilityHint` entirely when `forceWeek` (no empty-string hint). (View.)
- **FR-012**: The `Image(systemName: tag.icon)` in `TagFlowView` (L13) MUST be `.accessibilityHidden(true)`; prefer `.accessibilityElement(children: .combine)` per chip. (View.)
- **FR-013**: `ModelDownloadRow` MUST be discoverable as actionable via `.accessibilityAddTraits(.isButton)` on its existing combined element — NOT by wrapping the VStack in a `Button` (which would swallow its inner Cancel/ghost-pill buttons). (View.)
- **FR-014**: `CheckInViewModel.loadPromptInterval()` MUST be annotated `@MainActor`. (Compile-time; folds into SC-008 — no unit test.)
- **FR-015**: The `CheckInViewModel` model-preload Task MUST stay `Task.detached` (off-main warm-up — a plain `Task` would inherit `@MainActor` and move the model load onto the main thread), be stored as a `private(set)` handle, and cancelled on the **discard path (`cancelRecording()`)**, NOT on `stopRecording()` (cancelling on stop would defeat the post-stop warm-up). (Logic; RED-first — the RED test sets a `loadModelHangs` flag on the mock so the task is still in-flight at cancel.)
- **FR-016**: The `CheckInView` cap-approach work currently in a bare `Task {}` inside `.onChange` SHOULD be expressed as `.task(id: viewModel.isApproachingCap)` (auto-cancels on disappear/id-change). (View; device-verified.)
- **FR-017**: The `CheckInViewModel` timer loop MUST place `guard !Task.isCancelled else { break }` **between** `Task.sleep` and `elapsedTime += 0.1`. To make it RED-first, extract the tick body to an internal `advanceTick()` so a test can assert it is a no-op after cancellation. (Logic; RED-first via the seam.)
- **FR-018**: `RecordingDetailViewModel` MUST implement `deinit { retryTask?.cancel() }`. (Inspection/compile-only — NOT RED-testable: `retryTask` captures `self` strongly, so the VM cannot dealloc while the retry is in-flight; the deinit-cancels-in-flight scenario a test would need is unreachable without a `weak self` rewrite, which is out of scope. Verified by inspection + the strict-concurrency build.)
- **FR-019** *(pulled from audit #19)*: The regenerate Task on the RecordingDetailView button (RecordingDetailView.swift:30, fire-and-forget) MUST be replaced by a `private(set) var summaryTask` handle + a `startRegenerate()` method that cancels a prior in-flight regenerate before re-running. The view calls `startRegenerate()`. It MUST **NOT** cancel `summaryTask` on `.onDisappear`/`deinit`: `regenerateSummary()` commits-first (wipes the summary + saves, then awaits), so cancelling mid-flight would strand the recording with a wiped summary; an in-flight regenerate retains `self` and completes/persists after dismiss. The handle exists to make **re-entry** safe (non-destructive — the second run re-commits). Full cancellation-on-dismiss is deferred pending a commit-last refactor. (Logic/view; RED-first on re-entry via a `hangs` mock flag.)

### Key Entities

- **Recording** (`@Model`): unchanged. `RecordingStatus.failed` and `SummaryStatus.failed` already exist (AppEnums.swift:13, 96); `summaryStatus` is a `String?` holding `SummaryStatus.rawValue`. FR-007 reads this existing state — no field, case, or migration is added.
- **MedicationBarEnvironmentAction** *(DEFERRED → `fix/027`)*: new `@Environment` key to host the log sheet at the non-sheet root.

---

## Test-First Mapping (Principle X)

| FR | Class | Verification |
|---|---|---|
| FR-006 | Logic (VM) | **RED-first**: insert via `store.context` without `loadRecordings` (stale array) → assert `run()` still populates `summaryStatus`/mood |
| FR-006a | Logic (VM) | **GREEN characterization** (nil-safe return already exists — passes on old + new) |
| FR-015 | Logic (VM) | **RED-first** via `private(set)` handle + `loadModelHangs` mock flag: assert `isCancelled` after `cancelRecording()` |
| FR-017 | Logic (VM) | **RED-first** via `advanceTick()` with internal `guard !Task.isCancelled`: run inside a cancelled `Task`, assert `elapsedTime` unchanged |
| FR-019 | Logic (VM) | **RED-first** re-entry via `summaryTask`/`startRegenerate()` + `hangs` mock flag: second `startRegenerate()` cancels the first |
| FR-018 | Inspection/compile | `deinit { retryTask?.cancel() }` — not RED-testable (retry retains `self`); verified by inspection + SC-008 |
| FR-003 delete VM | Logic (VM) | **GREEN characterization**: `delete()` empties the store |
| FR-014 | Compile-time | Strict-concurrency build (SC-008) — no unit test |
| FR-001, 002, 003, 004, 004a, 005, 007, 009–013, 016 | View | Build + on-device run (exempt under Principle X) |

---

## Success Criteria

- **SC-001** *(device)*: On the 2nd consecutive check-in, the ring is non-static in idle within ~1s and rotates within ~1s of tapping Speak (binary pass/fail, not "looks right").
- **SC-002** *(device)*: Accessibility Inspector reports ≥ 44×44pt for the two regressed controls (AudioPlayerView play/pause, TextCheckInComposer xmark), and no other control regressed.
- **SC-003**: *(unit)* `ProcessingViewModel` populates mood/signals/`summaryStatus` when `store.recordings` is stale but the row is persisted (deterministic). *(device)* 0 empty-extraction cards across 5 consecutive real saves.
- **SC-004**: *(unit)* `RecordingDetailViewModel.delete()` empties the store. *(device)* deletion requires menu-tap + confirm — 0 single-tap deletions.
- **SC-005** *(device)*: With Reduce Motion ON, 0 animations fire across the three affected views (both RecordingDetailView sites included).
- **SC-007** *(device)*: VoiceOver/Voice Control can identify and activate every element named in FR-009–FR-013 (five specific fixes, not the whole app).
- **SC-008** *(build gate)*: With `SWIFT_STRICT_CONCURRENCY=complete` (Swift 6 mode) on the `app-four` target, 0 concurrency warnings on the branch.
- **SC-009**: Full Swift Testing suite stays green on the branch (no regressions).

---

## Deferred (Named)

Not addressed in 026 — listed so nothing is silently dropped:

- **Own branch**: US6 / FR-008 sheet re-routing → `fix/027-medbar-sheet-routing`.
- **Data warnings (future spec)**: #11 double-insert save-ordering, #15 noteExtractionJSON not round-tripped on edit, #16 manual doses invisible in ADHDSummarySection, #29 midnight rollover (CalendarLibraryView), #30 duplicate-`createdAt` drops a timeline recording.
- **New gap surfaced by this review**: `summaryStatus` is read by **zero** views today — FR-007 addresses the failed case; the broader "summaryStatus is the documented UI source of truth but unobserved" cleanup is deferred.
- **Commit-last regenerate refactor**: `regenerateSummary()` wipes the summary + saves before awaiting, so cancellation strands data. FR-019 sidesteps this (no cancel-on-dismiss). Making regenerate cancellation-safe (commit-last, or restore-on-cancel) — which would let `summaryTask` be cancelled on dismiss — is deferred.
- **Design system (cleanup spec)**: off-grid spacing (#41–46, 55, 76, 90), Typography token gaps (#47–49), `.primary` vs `Theme.textPrimary` (#39–40, 62), `.card()` modifier on DayCard (#48), deprecated `ScrollView(showsIndicators:)` (#49), `.tabItem`→`Tab` migration (#31), stale font credit (#60).
- **Info tier**: #61–90 except those pulled in above.

---

## Assumptions

- **No schema migration** (Principle IX): both `.failed` enum cases pre-exist as `String` raw values; the persisted type is unchanged regardless of which field FR-007 reads. There is provably zero migration/CloudKit-compat impact.
- **No HTML mockup** (Principle I): FR-007 reuses/extends the existing failed-state affordance in `RecordingDetailView` (an in-place conditional branch, no new navigation surface), so it is not a "new view."
- The `Metrics.minTapTarget` token (Packages/SquirlDesignSystem/.../Metrics.swift:10) is the single source for the 44pt minimum.
- The owner runs the device build + on-device QA (no simulator use by Claude); Claude delivers code + Swift Testing tests + self-review.
- Test seams (FR-015 `private(set)` handle, FR-017 `advanceTick()`, FR-018 cancellation flag) are minimal and justified by Principle X's RED-first mandate — they are the smallest change that makes the logic deterministically testable.
