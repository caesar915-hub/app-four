# Interface Contract — ViewModel & Interaction Surface

Spec: `specs/014-daily-card/spec.md`. This contract covers the **interaction + data** surface for the daily-card redesign: the `<= selectedDate` list filter, selection-collapses-others, the folded-summary / most-recent-med derivation ownership, and the auto-expand setting. The view layer is in `daycard-view.md`.

Ground truth files inspected: [CalendarLibraryView.swift](app-four/Views/Library/CalendarLibraryView.swift), [MoodLibraryViewModel.swift](app-four/ViewModels/MoodLibraryViewModel.swift), [AppSettings.swift](app-four/Models/AppSettings.swift), [SettingsViewModel.swift](app-four/ViewModels/SettingsViewModel.swift), [DayTimeline.swift](app-four/ViewModels/DayTimeline.swift), [Motion.swift](app-four/DesignSystem/Motion.swift).

Ownership split (Constitution Principle VIII — ViewModels are `@MainActor @Observable`, no persistence logic; views hold ephemeral state; `AppSettings` owns persisted data):
- **`CalendarLibraryView`** owns ephemeral UI state: `selectedDay` ([already @State, L10](app-four/Views/Library/CalendarLibraryView.swift#L10)) and the open-card set.
- **`MoodLibraryViewModel`** owns the pure data transform (filter).
- **`@AppStorage("autoExpandOnSelection")`** owns the auto-expand preference — read in `CalendarLibraryView`, written by a `DayCardSettingsSection` toggle (no model/view-model dependency; matches the `MedicationBar*` toggles).

---

## 1. `MoodLibraryViewModel` — `<= selected date` filter

Today: `timelineDays` is a computed property that builds the whole month newest-first and never shows future days ([MoodLibraryViewModel.swift#L69-L100](app-four/ViewModels/MoodLibraryViewModel.swift#L69)). The filter is added as a **pure method**, not a stored `@Observable` property (keeps the selected date out of the model — Principle VIII).

### New method
```swift
/// Returns `timelineDays` with every day strictly more recent than `selectedDate` removed.
/// Preserves the existing month scope and newest-first order; selectedDate is the top entry
/// when it has data within the current month.
func timelineDaysFilteredToSelectedDate(_ selectedDate: Date) -> [TimelineDay]
```

**Guarantees**
- Applies the **existing** month filter ([L72-L77](app-four/ViewModels/MoodLibraryViewModel.swift#L72)) **plus** `startOfDay(of: day.date) <= startOfDay(of: selectedDate)`. No duplicated month logic.
- Output is a subsequence of `timelineDays` (same elements, same newest-first sort) with the tail of more-recent days dropped.
- Idempotent w.r.t. `selectedDate`: same input ⇒ same output (pure; reads only `store`/`medicationEvents`/`currentMonth`).
- Days **older** than `selectedDate` remain present and scrollable (FR-010).

| FR | Guarantee | Test-first logic unit? |
|----|-----------|------------------------|
| FR-010 | Days more recent than `selectedDate` are absent from the **list**. | **Yes** — `MoodLibraryViewModelTests`: returns only days `<= selected`; `selected` is first; days `> selected` excluded; days `< selected` retained. |
| FR-009 | The list re-renders with `selectedDate` at top (it is the newest remaining day). | Covered by the above + the interaction test in §2. |
| FR-016 | Order within the result is unchanged (newest-first); no reshuffle of surviving days. | Implied by sort stability — assert order in test. |

**Caller change:** `CalendarLibraryView.timelineList`'s `ForEach(viewModel.timelineDays)` ([L99](app-four/Views/Library/CalendarLibraryView.swift#L99)) becomes `ForEach(viewModel.timelineDaysFilteredToSelectedDate(selectedDay))`, keeping `.id(day.date)`.

> Note: the calendar *week row* does **not** use this filter — more-recent days stay visible there but de-emphasized (FR-011, see `daycard-view.md` §4b). Filter-out is list-only; grey-out is calendar-only.

---

## 2. `CalendarLibraryView` — selection collapses others + open-card state

### New state
```swift
@State private var expandedCardDates: Set<Date> = []   // start-of-day keys; O(1) membership
```
`Set<Date>` over `selectedDay: Date?`: FR-005 requires **multiple** cards open via header taps, which a single optional cannot represent. `Set` over `Dictionary<Date,Bool>`: no unused value.

### Header tap → `DayCard.onToggleExpand` (FR-005)
```swift
withAnimation(reduceMotion ? nil : Motion.smooth) {
    if expandedCardDates.contains(day.date) { expandedCardDates.remove(day.date) }
    else { expandedCardDates.insert(day.date) }
}
```
**Guarantee:** toggling one card never mutates another's membership — cards are independent (FR-005). `reduceMotion` already in scope ([L18](app-four/Views/Library/CalendarLibraryView.swift#L18)).

### Date selection → extend `selectDay(_:)` (FR-009, FR-010)
`selectDay(_:)` ([L130-L137](app-four/Views/Library/CalendarLibraryView.swift#L130)) and `scrollList(to:)` ([L139-L149](app-four/Views/Library/CalendarLibraryView.swift#L139)) already set `selectedDay`, scroll-to-top, and animate. Add the collapse-then-open command inside the same `withAnimation(reduceMotion ? nil : Motion.smooth)`:
```swift
expandedCardDates.removeAll()                          // collapse ALL open cards (FR-009)
if autoExpandOnSelection { expandedCardDates.insert(target) }   // open ONLY the selected day (FR-019)
```

**Guarantees**
- After selecting date *D*: `expandedCardDates == (autoExpandOnSelection ? [D] : [])` — every previously open card is closed; at most *D* is open.
- **Idempotent re-selection (FR-009, spec line 19):** selecting the already-selected, already-top day does not re-collapse/re-animate into a different state — it remains top and (if auto-expand) open. The collapse-all → re-insert is a no-op set when *D* is already the sole member.
- `selectedDay` continues to drive both the list filter (§1) and the calendar highlight; the existing scroll-sync at [L115-L118](app-four/Views/Library/CalendarLibraryView.swift#L115) is unchanged.

| FR | Guarantee | Test-first? |
|----|-----------|-------------|
| FR-005 | Header tap toggles one card; multiple may be open. | **Yes** — `DayCardExpandStateTests`: toggle adds/removes only that date; two toggles ⇒ two members. |
| FR-009 | Selecting a date clears the set then inserts the selected (if auto-expand on); idempotent on re-select. | **Yes** — `DayCardExpandStateTests`: after select, set == `[selected]` (auto on) or `[]` (auto off). |
| Reduce Motion | Collapse/open + scroll honor `accessibilityReduceMotion` (nil animation) — mirrors [L143](app-four/Views/Library/CalendarLibraryView.swift#L143). | View. |

---

## 3. Folded-summary / most-recent-medication derivation — ownership

**Decision:** this is **presentation logic and lives in the view** (`FoldedDayCardHeader`, see `daycard-view.md` §2), **not** in `MoodLibraryViewModel`. The model exposes only what already exists: `TimelineDay.nodes`, newest-first ([MoodLibraryViewModel.swift#L99](app-four/ViewModels/MoodLibraryViewModel.swift#L99); nodes sorted `$0.time > $1.time` at [DayTimeline.swift#L66](app-four/ViewModels/DayTimeline.swift#L66)).

- **No** new computed property / field on `TimelineDay` or `DayTimeline.Node` (would couple the data model to view concerns — Principle VIII / IV).
- Derivation: `day.nodes.first { !$0.intakeDoses.isEmpty }?.intakeDoses.first?.name` → most-recent med name (FR-003).

| FR | Guarantee | Test-first? |
|----|-----------|-------------|
| FR-001/002 | Summary built from logged signals only; omits unlogged. | Yes — view-logic unit `FoldedDayCardHeaderTests`. |
| FR-003 | Exactly the most-recent check-in's med name on a multi-med day. | **Yes.** |
| FR-004 | Empty day ⇒ `"No check-ins this day. That's alright."` | **Yes (exact copy).** |

---

## 4. Auto-expand setting — `@AppStorage` (FR-019)

Default **ON**. Stored as **`@AppStorage("autoExpandOnSelection")`** — the codebase's pattern for view-consumed behavior toggles ([MedicationBarSettingsSection.swift](app-four/Views/Settings/MedicationBarSettingsSection.swift) writes, [MedicationBarView.swift](app-four/Views/Components/MedicationBarView.swift) reads, both `@AppStorage("medicationBarVisible")`). **No `AppSettings` attribute, no `SettingsViewModel` change, no schema change.**

### Read (consumer)
```swift
// CalendarLibraryView
@AppStorage("autoExpandOnSelection") private var autoExpandOnSelection = true
```
Used in `selectDay` exactly as §2: `expandedCardDates = expandedCardDates.selecting(target, autoExpand: autoExpandOnSelection)`.

### Write (user control)
```swift
// DayCardSettingsSection (new — mirrors MedicationBarSettingsSection)
@AppStorage("autoExpandOnSelection") private var autoExpandOnSelection = true
// Toggle("Auto-expand selected day", isOn: $autoExpandOnSelection)
```

**Why not `AppSettings`/`SettingsViewModel`:** a `@Model` attribute would force plumbing the value into `CalendarLibraryView` (whose environment holds only `AppServices`) and would depend on `SettingsViewModelTests`, which is **currently disabled** pending a mock `AppServices`. `@AppStorage` is read directly anywhere, needs no plumbing, and is test-exempt (view state). Both reader and writer bind the same key, so the toggle is reflected immediately. *(Supersedes an earlier draft that placed this on `AppSettings` — see plan.md / data-model.md §4.)*

| FR | Guarantee | Test-first? |
|----|-----------|-------------|
| FR-019 | Auto-expand is user-controllable (`DayCardSettingsSection` toggle), default ON; OFF ⇒ selection does not auto-open. | View — the §2 `ExpandedDayCards.selecting(_:autoExpand:)` test parameterizes on the `autoExpand` bool. |
| Principle IX | No schema attribute added ⇒ no migration surface. | N/A. |

---

## 5. Test-first logic units (Constitution Principle X — RED first)

Swift Testing (`@Test`, `#expect`), `@MainActor` suites following the existing `MoodLibraryViewModelTests` pattern.

1. **`timelineDaysFilteredToSelectedDate(_:)`** — returns only days `<= selected`; `selected` is first; `> selected` excluded; `< selected` retained; order newest-first. *(FR-010, FR-009, FR-016)*
2. **Selection state machine** (`expandedCardDates`) — header toggle adds/removes only that date; selecting a date clears then inserts `[selected]` when auto-expand on, `[]` when off; re-select is idempotent. *(FR-005, FR-009, FR-019)*
3. **Most-recent medication** — multi-med day yields the newest check-in's name only; no-med day yields `nil`. *(FR-003)*
4. **Empty-day copy** — empty day's summary equals `"No check-ins this day. That's alright."`; no unlogged signals rendered. *(FR-004, FR-002)*

SwiftUI views themselves (`DayCard`, `FoldedDayCardHeader`, `CalendarDayCell`, `CalendarLibraryView`) are exempt from unit tests (Principle X) — verified by build + simulator.

