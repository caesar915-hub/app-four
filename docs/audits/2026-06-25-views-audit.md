# View-Layer Static Audit — app-four

**Date:** 2026-06-25 · **Branch:** feat/nlp-multilang-demo
**Scope:** all view-layer code under `app-four/` (Views + ViewModels + DesignSystem; 148 Swift files, ~15.8k lines)
**Lenses:** A = `swiftui-ui-patterns` (architecture) · B = `swiftui-pro` (code quality).
**Method:** 67-agent verified workflow — 13 cluster finders → adversarial per-finding verification (each finding re-read against the real file, prompted to refute) → completeness critic (directory-complete enumeration). **54 raw → 50 confirmed + 5 critic additions; 3 rejected as false positives.** Read-only — no code changed.
**Next:** Lens C (`ios-design-review`, on-device visual) runs separately on a booted simulator.

---

## Calibration (verified facts)

- **Deployment target: iOS 26.5 / 26.4** ([project.pbxproj:301,323,390,448](../../app-four.xcodeproj/project.pbxproj#L301)). iOS 26-only modern APIs (e.g. the `Tab` builder) are in-scope and valid.
- **`SWIFT_VERSION = 5.0`** ([project.pbxproj:309](../../app-four.xcodeproj/project.pbxproj#L309)) — Swift 5 language mode; Swift 6 strict-concurrency is **not** compiler-enforced.
- Already modern: **0 `AnyView`**, **0 `ObservableObject`**, 20 `@Observable`. SwiftData `@Model` types observe directly.

## Headline

**No data races; the modern-API surface is clean.** The dominant problem is **dead code**: ~7 fully-orphaned files and ~12 dead members/properties — almost certainly accumulated from the day-card / Chip-unification / `SummaryCard`→`ADHDSummarySection` migrations that landed without removing the superseded code. Two items rise above hygiene:

1. **🔴 Real bug — `RecordingDetailView` loses its toolbar (Delete + date title) when opened from the Calendar tab.** It relies on an enclosing `NavigationStack` that the Insights push-path supplies but the Calendar `.sheet` path does not.
2. **🔴 Debug scaffolding ships in Release.** `TestServicesView`'s trigger is `#if DEBUG`-gated but its presenting `.sheet` is not, so the debug surface compiles into the shipping binary; `TestSchemaView` is fully orphaned. → candidate for the **`ios-clean`** skill.

---

## 🔴 High — fix first

### Dead code (delete)

| File:line | What | Fix |
|---|---|---|
| `ViewModels/LibraryViewModel.swift:1-94` (A) | Entire VM unreferenced; Calendar tab uses `MoodLibraryViewModel`. Only consumer is its own test (false coverage). | Delete the VM **and** `LibraryViewModelTests.swift`. Backlog the week-grouped list if still wanted. |
| `Views/Components/TopicChip.swift:1-49` (B) | `TopicChip` + `FilterChip` superseded by unified `Chip` (`Chip.filter` at [ExtractionReviewView.swift:431,449](../../app-four/Views/ExtractionReviewView.swift#L431)). Zero prod refs. | Delete the file. |
| `Views/Components/SummaryCard.swift:1-72` (B) | Superseded by `ADHDSummarySection` ([RecordingDetailView.swift:31](../../app-four/Views/RecordingDetailView.swift#L31)). Orphaned (only its own `#Preview`). Also the sole external user of `RecordingDetailViewModel.SummaryState`. | Delete the file (unblocks the `SummaryState` removal below). |
| `DesignSystem/Elevation.swift:5-9` (B) | `.elevated()`'s only caller is `Card.swift`'s dead `elevated` branch. | Delete the file (see Card finding under 🟡). |
| `ViewModels/RecordingDetailViewModel.swift:46-54` (B) | `exportJSON()` never called; keeps a `storageService` dependency alive for nothing. | Delete the method + drop the `storageService` property and its `init` wiring. |
| `ViewModels/ProcessingViewModel.swift:58-66` (B) | `retry(...)` — zero callers, not even in tests; a pass-through that silently drops `fillOnly`. | Delete the method. |
| `ViewModels/AudioPlaybackViewModel.swift:86-92` (B) | `stop()` — no callers; teardown is via `cleanup()` on `.onDisappear`. | Delete the method. |
| `ViewModels/RecordingDetailViewModel.swift:15-23` (B) | `summaryState` + nested `SummaryState` enum + `topicTags` written but never read; UI renders off `viewModel.recording`. **Fix is order-dependent:** delete `SummaryCard.swift` *first* (it references the enum), then remove these + their assignments. `performSummarization()` then only sets `summaryStatus` + `applySummary` + save. | Delete `SummaryCard.swift`, then remove `summaryState`/`SummaryState`/`topicTags`. |

### Correctness

**`Views/RecordingDetailView.swift` toolbar (body 26-77, toolbar 49-67) (A) — missing `NavigationStack` on the Calendar sheet path.**
The body is a bare `ScrollView` whose `.toolbar` puts the date in `.principal` and Delete in `.topBarTrailing` — these only render inside a navigation bar. Insights pushes it through `ScreenContainer`'s `NavigationStack`; **`CalendarLibraryView` presents the same view as a plain `.sheet`, so Delete + the date title silently vanish.**
→ Wrap the sheet content: `.sheet(item: $detailRef) { NavigationStack { RecordingDetailView(...) } }`. Verify Delete + title appear when opening a check-in from the Calendar tab.

---

## 🟡 Medium

**Dead / unreachable surface**
- `ViewModels/ProcessingViewModel.swift:12-20` (A) — the `@Observable state: ProcessingState` machine (`.summarizing/.saving/.completed/.failed`) is read by **no view**; the pipeline runs fire-and-forget and the UI renders off `Recording.summaryStatus`. → Drop the observable `state` (make the pipeline a plain async fn) and let `summaryStatus` be the single source of truth; retarget `ProcessingViewModelTests` to the persisted status.
- `ViewModels/ExtractionReviewViewModel.swift:10-19` (B) — title-editing machinery (`name`/`userDidSetTitle`/`originalTitle` + dead `confirm()` branch) is unreachable; no title field binds `viewModel.name`. → Surface a title field or remove the half-feature.
- `ViewModels/AudioPlaybackViewModel.swift:77-84` (B) — `beginScrubbing()`/`endScrubbing(at:)` have no callers; they're the only writers of `isScrubbing`, so its guard in `startProgressPolling` is inert. → Delete both + the flag + guard, or wire into `PlaybackWaveformBars`' drag.
- `Views/Components/TimelineDaySection.swift:5-27` (B) — never instantiated (Calendar renders via `DayCard`). → Delete.
- `Views/Insights/InsightsPreviewSupport.swift:1-50` (B) — `InsightsViewModel.preview()` has zero call sites. → Delete or wire into the `InsightsView` `#Preview`.
- `Views/Feedback/ScreenshotCapture.swift:8-17` (B) — `isCapturing` is written but never read; the "hide button during capture" contract is unimplemented. → Remove the flag + 50ms sleep (and fix the misleading doc), or actually wire the hide.
- `Views/Components/Chip.swift:9,18-30` (A) — the `.topic` case/factory of the unified `Chip` is never used (only `.filter` is). → Delete the topic half until a consumer exists.
- `DesignSystem/Card.swift:18-34` (B) — `card(elevated:)` is never called with `true`; the branch (and thus `Elevation.swift`) is dead. → Drop the `elevated` param, return the base treatment directly.

**Debug-in-Release (critic — systemic)**
- `Views/TestSchemaView.swift:1-37` (B) — "temporary view to verify the SwiftData schema," no `#if DEBUG`, zero refs → compiles into Release. → Delete.
- `Views/SettingsView.swift:71-73` (A) — the `.sheet(isPresented: $showingDebug){ TestServicesView() }` is **not** `#if`-gated, though its trigger (247-249) is. → Wrap the sheet + `@State` in the same `#if DEBUG || TESTFLIGHT`.
- `Views/TestServicesView.swift:153-157` (B) — the sheet's "Done" button body is an empty placeholder — the only dismiss affordance is a no-op. → Wire `@Environment(\.dismiss)` (or gate the whole file behind `#if DEBUG`).

**Code quality**
- `ViewModels/InsightsViewModel+Signals.swift:97-295` (B) — every analytics getter re-filters `store.recordings` into uncached `monthRecordings`; all five paged sections live in one `VStack` and re-render on every `activeSectionID` change, recomputing from scratch (`rhythmMatrix` filters the month 12×). → Cache the per-month derivation once per `currentMonth` change (snapshot via `.onChange`/`.task`); hoist the kind-independent filter out of `rhythmMatrix`'s inner loop.
- `Views/Components/FoldedDayCardHeader.swift:56,58,59` (B) — deprecated `Text.foregroundColor` → `foregroundStyle` (the `+` concat is load-bearing for wrapping; keep it).
- `Views/Components/TimelineChip.swift:25` (B) — `.font(.system(size: 12))` freezes user-facing text (renders "Happy", "5h sleep", "Taken Concerta 36mg"); DESIGN.md mandates Dynamic Type. → `.font(Typography.label)`.
- `Views/RootTabView.swift:19-35` (B) — legacy `.tabItem`+`.tag` → modern `Tab(value:)` builder (valid at iOS 26.5).

---

## 🟢 Low (grouped)

- **`Task.sleep(nanoseconds:)` → `Task.sleep(for:)`** (not deprecated, readability only): `CheckInViewModel:321,442` · `RecordingDetailViewModel:147` · `AudioPlaybackViewModel:110` · `ScreenshotCapture:15`.
- **Per-render `DateFormatter`**: `SettingsView:26-30` · `DayDetailSheet:9-16`. **Repeated store fetch in a computed prop**: `SettingsViewModel:47-56`.
- **DRY / placement**: month-cursor logic duplicated across `MoodLibraryViewModel` + `InsightsViewModel`; the shared `Calendar.startOfMonth` extension hidden at `InsightsViewModel.swift:90-95` (→ `Extensions/Calendar+Month.swift`); `MedicationBarViewModel` `DoseDisplay` carries `dose` + always-equal `effectiveDose`.
- **One type per file**: `RootContainerView` inside `SquirlApp.swift:44-131`; `FlowLayout` inside `TagFlowView.swift`; `JournalExportSection` filename mismatch.
- **Encapsulation / state**: `AudioPlaybackViewModel.currentTime` should be `private(set)` (:18); unreachable `.loading` enum case (:9); `generateSummary()` over-broad access (:60-67); vestigial state in `CalendarLibraryView:8`.
- **Sheets / a11y polish**: `IssueReportView` parallel-boolean sheets (:25-27) + `TextEditor`→`TextField(axis:.vertical)` (:76); `TextCheckInComposer` same `TextEditor` idiom (:71-90); `MonthSelectorScrollView` selection state not exposed to assistive tech (:20-36); `RecordingDetailView` sheet self-dismiss (:234-239); `JournalExportSection` forwards dismiss closure (:30-85); `ExtractionReviewView` `Binding(get:set:)` where `$vm` works (:170-174); dead design tokens in `Metrics`/`Typography`; `TestServicesView` raw system font (:56); dead `MoodLibraryViewModel` helper (:147-149); dead params on `processRawTranscription` (:39-40).

---

## False positives filtered (recorded for auditability)

Adversarial verification rejected 3 finder claims — each re-read and refuted:
- **`ExtractionReviewView.swift:94-100`** — `Text` `+` concatenation flagged as deprecated. **Not deprecated**, and the `+` is load-bearing (single wrapping run). Kept as-is.
- **`Views/Insights/SignalAverageGauges.swift:29-31`** — glyph flagged as missing a11y. The `SignalGlyph` already owns its accessibility element/label by default. No issue.
- **`Views/Library/CalendarLibraryView.swift:37-44`** — `.sheet(item:)` on a UUID wrapper flagged as should-be-model. The re-lookup is a **deliberate deletion-safe guard** that self-dismisses. Acceptable.

## Confirmed clean (verified, not re-litigated)

`MedicationPickerViewModel`, `WelcomeView`/`WelcomeViewModel`, `MedicationLogSheet` (owns `dismiss()`; the callback is a data handoff, not dismiss-forwarding — correcting the earlier recon's false flag), `MedicationBarView` (cached formatter, standard dialog binding, full a11y), `RecordingRow`, `MoodBubbleChart`. Modern APIs throughout; consistent accessibility on icon buttons and charts; `LazyVStack` + explicit `ForEach` ids.

---

## Recommended order

1. **Delete dead code** (🔴 dead-code table + 🟡 dead surface) — high value, near-zero risk. Mind the one ordering dependency: `SummaryCard.swift` before the `SummaryState` removal.
2. **Fix the `RecordingDetailView` toolbar bug** (🔴 correctness) — user-visible, small.
3. **Fence/delete debug scaffolding** (🟡 critic) — run the **`ios-clean`** skill to fence all `Test*` surfaces behind one `#if DEBUG`.
4. **Modern-API + a11y** (🟡 `FoldedDayCardHeader`, `TimelineChip`, `RootTabView`).
5. **Insights perf caching** (🟡) when it next changes.
6. Low items opportunistically.

## Next: Lens C

`ios-design-review` on a booted simulator (HIG + DESIGN.md, 10 dimensions). The `TimelineChip` frozen-Dynamic-Type finding and any spacing/contrast issues cross-check there. Report lands at `~/.gstack/projects/<slug>/ios-design-review-<date>.md`.
