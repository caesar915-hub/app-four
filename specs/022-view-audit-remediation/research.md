# Phase 0 — Research & Implementation Decisions

No `NEEDS CLARIFICATION` remained in the spec. These are the implementation-approach decisions resolved before tasking. Each cites the audit finding it addresses.

## R1 — RecordingDetailView toolbar (US1 / 🔴)

**Decision**: Wrap the sheet *content* in a `NavigationStack` at the **Calendar** call site only — `CalendarLibraryView`'s `.sheet(item: $detailRef) { NavigationStack { RecordingDetailView(...) } }`.
**Rationale**: The Insights path already supplies a stack via `ScreenContainer`; the bug is only the Calendar `.sheet` path lacking one, so its `.toolbar` (`.principal` date + `.topBarTrailing` Delete) has no bar to render into.
**Guard against double-stack**: Do NOT add a stack inside `RecordingDetailView` itself (would double-nest on the Insights push). Verify both entry points after the change.
**Alternatives rejected**: Embedding a stack in the view (breaks the Insights push); using `.toolbar` on the sheet without a stack (placements need a navigation bar).

## R2 — TimelineChip Dynamic Type (US2 / M11)

**Decision**: Replace `.font(.system(size: 12, weight: .medium))` with the scaling `Typography.label` token (DM Sans 12pt, `relativeTo:`).
**Rationale**: DESIGN.md mandates Dynamic Type on all three faces; the frozen system size is the only user-facing text in the audited surface that does not scale. Sibling chips already use scaling tokens.
**Layout**: Confirm the chip row adapts at AX5 (wrap / vertical growth) without clipping long strings ("Taken Concerta 36mg"). If the horizontal row clips, allow wrapping rather than a `minimumScaleFactor` hack (per swiftui-design-principles §11).
**Out of scope**: Fixed *decorative glyph* sizes in `Metrics.swift` stay frozen by intent.

## R3 — Debug-in-Release fence (US3 / critic)

**Decision**: Fence `TestServicesView`, its presenting `.sheet` + `showingDebug` `@State` in `SettingsView`, and `TestSchemaView` behind a single consistent compilation condition; delete `TestSchemaView` outright; wire `@Environment(\.dismiss)` into the diagnostics "Done" button.
**Condition**: Verify whether a `TESTFLIGHT` active-compilation-condition is defined in build settings. If yes → `#if DEBUG || TESTFLIGHT`; if not → `#if DEBUG` (do NOT invent a build setting in this remediation). Match whatever the existing 5-tap trigger uses (it already references `DEBUG || TESTFLIGHT`).
**Rationale**: The gate is currently on the trigger but not the presentation/definition, so the debug view compiles into Release.

## R4 — ProcessingViewModel state removal (US4 / FR-009, test-first)

**Decision**: Remove the `@Observable var state: ProcessingState` machine (no view reads it); the persisted `Recording.summaryStatus` is the single source of truth for the summary/processing UI. Keep the async pipeline as plain methods.
**Tests (RED first)**: Retarget `ProcessingViewModelTests` to assert on the persisted `recording.summaryStatus` transitions (generating → ready / failed) instead of the in-memory enum. Write the retargeted failing assertions before deleting the enum.
**Rationale**: Duplicate observable state nobody reads (constitution III/VIII). `RecordingDetailView`/`RecordingRow` already render off `recording`.

## R5 — Insights analytics caching (US5 / perf)

**Decision**: Compute `monthRecordings` and the `SignalKind`→levels groupings **once per `currentMonth` change** into a stored snapshot on `InsightsViewModel`; derive `moodShares`/`signalStrips`/`signalAverages`/`rhythmMatrix`/`connections` from the snapshot. Hoist the kind-independent bucket filter out of `rhythmMatrix`'s inner loop.
**Trigger**: Recompute the snapshot in `currentMonth`'s `didSet` (or an explicit refresh called from `prevMonth()`/`nextMonth()`), not in computed getters re-read every render.
**Tests (RED first)**: Add `@Test` cases asserting the derived analytics equal the current outputs for a seeded month (behavior-preserving), then refactor to the snapshot.
**Rationale**: Getters currently re-filter `store.recordings` on every paged render; cost grows with recording count.

## R6 — Dead-code removal order (US4 / FR-010)

**Decision**: Removal sequence to avoid transient build breaks:
1. `SummaryCard.swift` (references `RecordingDetailViewModel.SummaryState`) **before** removing `summaryState`/`SummaryState`/`topicTags`.
2. `Card.swift` `elevated` param removal **before/with** `Elevation.swift` deletion (Elevation's only caller is the dead `elevated` branch).
3. `LibraryViewModel.swift` + `LibraryViewModelTests.swift` together.
4. Standalone deletions (no dependents): `TopicChip.swift`, `TimelineDaySection.swift`, `InsightsPreviewSupport.swift`, `TestSchemaView.swift`, and members `exportJSON()`(+`storageService`), `retry()`, `stop()`/`beginScrubbing()`/`endScrubbing()`/`isScrubbing`, `.loading` case, ExtractionReview title machinery, `Chip.topic`, `ScreenshotCapture.isCapturing`, dead `processRawTranscription` params.
**Verify each**: grep zero production refs immediately before deleting; build after each batch.

## R7 — Modern-API migrations (US5 / M7, M8 + polish)

**Decisions**:
- `RootTabView`: `.tabItem`+`.tag` → `Tab("…", systemImage:, value:)` builder (iOS 26.5). Selection binding stays the existing `Tab` enum.
- `FoldedDayCardHeader:56/58/59`: `foregroundColor` → `foregroundStyle` (keep the load-bearing `Text` `+` concat).
- `Task.sleep(nanoseconds:)` → `Task.sleep(for:)` at the 5 sites (CheckInViewModel ×2, RecordingDetailViewModel, AudioPlaybackViewModel, ScreenshotCapture — the last folds into the dead-code removal).
- Per-render `DateFormatter` → `Date.FormatStyle` / `static let` (SettingsView, DayDetailSheet).
- `IssueReportView`/`TextCheckInComposer`: `TextEditor` → `TextField(axis:.vertical)` with placeholder; `IssueReportView` parallel-boolean sheets → one `enum` + `.sheet(item:)`.
- Relocate `Calendar.startOfMonth` → `app-four/Extensions/Calendar+Month.swift`; extract shared `MonthCursor` consumed by `InsightsViewModel` + `MoodLibraryViewModel`.
- `AudioPlaybackViewModel.currentTime` → `private(set)`. `MedicationBarViewModel.DoseDisplay`: drop redundant `effectiveDose`, point readers at `dose`.
- One-type-per-file: split `RootContainerView` out of `SquirlApp.swift`; `FlowLayout` out of `TagFlowView.swift`.

**Note**: All migrations are behavior-preserving and DESIGN.md-neutral. None alters tokens, glyphs, palette, or typeface.
