# Research — Spec 026 (decisions & rationale)

Every decision is grounded in the actual source (verified during the adversarial spec review).

## D1 — CrescentRing re-animation (FR-001)
**Options**: (a) dual `.onDisappear { spinning/breathing = false }`; (b) `.id(isActive)` to force fresh `@State`; (c) drive animation from a derived value instead of an `.onAppear`-set `@State`.
**Decision**: (b) `.id(isActive)`.
**Why**: (a) is racy — a fast `isActive` flip can fire the next `.onAppear` before the reset (the original spec admitted this in its own Edge Cases). `.id(isActive)` re-initialises both `@State` vars to `false` on every branch entry, so the `false→true` `.onAppear` transition always fires. (c) is a larger rewrite for no extra benefit. Source: CrescentRing.swift:10-11, 39, 46.

## D2 — Tap-target expansion (FR-002, FR-003)
**Options**: (a) enlarge the existing `.frame` to 44; (b) `.contentShape` + `.frame(minWidth/minHeight: 44)` around the labelled content, preserving the visual disc.
**Decision**: (b), using the `Metrics.minTapTarget` token.
**Why**: in both files the frame sizes the **visible** gradient/circle (AudioPlayerView.swift:15 disc; TextCheckInComposer.swift:39-41 circle+border), so (a) changes the design. (b) meets HIG hit-area while keeping the 36/30pt visuals. TextCheckInComposer also has a balancing `Color.clear` spacer (L51) that must match the final width or the centred title shifts. The token already exists (Metrics.swift:10) and is used across the app.

## D3 — ProcessingViewModel recording lookup (FR-006/006a)
**Options**: (a) keep `store.recordings.first { }`; (b) `store.context.fetch(FetchDescriptor)`.
**Decision**: (b).
**Why**: the audit's "stale array → silent abandonment" premise is **not reproducible** — `RecordingStore.addRecording()` calls `loadRecordings()` synchronously after `insert()+save()` (RecordingStore.swift:52-56), and the voice path runs extraction only after that. (b) is still the better design: it decouples the lookup from array-mutation timing and mirrors the existing `FetchDescriptor` in `loadRecordings()` (RecordingStore.swift:41-45). `store.context` is already exposed (RecordingStore.swift:9). The nil branch logs + returns (there is no object to mutate). This is honest robustness hardening, not a fabricated bug fix (Principle III).

## D4 — Failed-summary surface (FR-007)
**Options**: (a) new error card in RecordingDetailView; (b) extend `ADHDSummarySection` to render a failed state; (c) reuse the transcription-failed branch.
**Decision**: (b).
**Why**: the producer already exists — `run()` writes `summaryStatus = .failed` (ProcessingViewModel.swift:65) and `regenerateSummary()` exists (RecordingDetailViewModel.swift:37). The only gap is that **no view reads `summaryStatus`** and `ADHDSummarySection` hides its card (+ Regenerate button) when `hasSummaryContent` is false (ADHDSummarySection.swift:13, 100-102) — exactly the failure case. Extending `ADHDSummarySection` keeps one summary owner and avoids a third overlapping mechanism. (c) is wrong: transcription-failure (`recording.status == .failed`, "Retry transcription", RecordingDetailView.swift:159-164) is a distinct concern from summary-failure.

## D5 — Preload-task cancellation target (FR-015)
**Options**: (a) cancel on `stopRecording()`; (b) cancel on `cancelRecording()`/discard only.
**Decision**: (b).
**Why**: the detached preload exists so post-stop transcription doesn't reload the model (CheckInViewModel.swift:141-142 comment). Cancelling on stop would defeat its purpose and is actively harmful. Store the handle (`private(set)`) regardless, so cancellation on discard is assertable.

## D6 — Phantom-tick test seam (FR-017)
**Options**: (a) real-time 100 ms race test; (b) extract `advanceTick()` and unit-test it as a no-op after cancellation.
**Decision**: (b).
**Why**: (a) is flaky, not deterministic RED-first. The loop currently increments after a `try?`-swallowed `Task.sleep` (CheckInViewModel.swift:439-450); extracting the tick body gives a deterministic seam and the `guard !Task.isCancelled` sits between sleep and increment.

## D7 — ModelDownloadRow actionability (FR-013)
**Options**: (a) wrap the VStack in a `Button`; (b) `.accessibilityAddTraits(.isButton)` on the existing combined element.
**Decision**: (b).
**Why**: the row contains its own `Cancel` and ghost-pill Buttons (ModelDownloadRow.swift:82, 123) and a confirmationDialog; wrapping the whole VStack in a Button would swallow those inner hits. It already has `.accessibilityElement(children: .combine)` + actions (L59-61); adding the `.isButton` trait makes it discoverable to Voice Control / Full Keyboard Access without breaking the inner controls.

## D8 — Delete confirmation control (FR-004)
**Decision**: `confirmationDialog` (not `.alert`), attached at body level near the `.onDisappear` teardown.
**Why**: HIG prefers an action sheet / confirmation dialog for a single destructive action; the dialog must live at body level because the Menu dismisses when its button fires. The existing `pendingDelete + .onDisappear` teardown (RecordingDetailView.swift:72) — required because deleting a mounted `@Model` traps SwiftData — is preserved unchanged.
