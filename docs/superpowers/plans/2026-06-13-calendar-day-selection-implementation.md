# Calendar Day-Selection & Navigation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Calendar tab's month-only header with a collapsible (tap-chevron) week↔month calendar whose selected day is two-way bound to the day-grouped mood/med timeline; show every day of the visible month (empties included) with a mood-colour marker dot.

**Architecture:** Month-paged — the calendar grid and the list are both scoped to `MoodLibraryViewModel.currentMonth` (reuse the existing `currentMonth`/`availableMonths`/`prevMonth`/`nextMonth`). A new pure value type `CalendarMonthModel` builds the Monday-first grid and per-day `DayMarker` from `timelineDays`. `timelineDays` is changed to emit **every** in-month day (bounded at today), empties as `nodes: []`. `CalendarLibraryView` owns its own `ScrollView` with `.scrollPosition(id:)` for two-way sync (the shared `ScreenContainer` only does edge-scroll).

**Tech Stack:** SwiftUI, SwiftData, Swift Concurrency, Swift Testing (`@Test`/`#expect`). Deployment target iOS 26.4+ (`.scrollPosition(id:)` available).

**Skills to apply during implementation:** view tasks (4–7) follow **swiftui-design-principles** (grid spacing, ≤5 font sizes, semantic colours) and **swift-accessibility-skill** (Dynamic Type, VoiceOver labels/traits, Voice Control input labels, Reduce Motion); the scroll-sync task follows **swift-concurrency-pro** (cancellable guard `Task`). Run a **swiftui-pro** + **swift-concurrency-pro** review pass over the new files before the PR. Conform to the app's existing architecture (`@Observable` VM + `ScreenContainer`) — do not introduce a new pattern.

**Worktree:** built in isolation at `../app-two-calendar` on `feat/calendar-day-selection` (a separate session holds the main checkout for the checkin/PromptPace feature).

**Design spec:** [2026-06-13-calendar-day-selection-design.md](../specs/2026-06-13-calendar-day-selection-design.md)

---

## File structure

| File | Responsibility | New/Modify |
|---|---|---|
| `app-two/ViewModels/CalendarMonthModel.swift` | Pure value type: `DayMarker` enum + Monday-first grid (`DayCell`s) for a month, each tagged in-month/today/future + marker | **New** |
| `app-two/ViewModels/MoodLibraryViewModel.swift` | `timelineDays` emits all in-month days incl. empties; `TimelineDay` gains `date`; add `hasAnyEntries` + `calendarMonth` | Modify |
| `app-two/Views/Components/DayCard.swift` | Render "No check-ins" when a day has zero nodes | Modify |
| `app-two/Views/Components/CalendarDayCell.swift` | One day cell: number + marker dot + selection/today/future + a11y | **New** |
| `app-two/Views/Components/CalendarHeaderView.swift` | Collapsible week/month grid + month label + chevron + jump-to-today + month-swipe | **New** |
| `app-two/Views/Library/CalendarLibraryView.swift` | Wire header + own `ScrollView` with two-way `.scrollPosition(id:)` sync + tab reset | Modify |
| `app-twoTests/ViewModels/CalendarMonthModelTests.swift` | Grid shape, flags, marker rules, DST | **New** |
| `app-twoTests/ViewModels/MoodLibraryViewModelTests.swift` | Full-month emission, empties, ordering, future exclusion, `hasAnyEntries` | Modify |

`MonthSelectorScrollView` is **not** touched — it stays in use by Insights; we only stop using it in the Calendar tab.

---

## Task 1: `DayMarker` + `CalendarMonthModel` grid generation

**Files:**
- Create: `app-two/ViewModels/CalendarMonthModel.swift`
- Test: `app-twoTests/ViewModels/CalendarMonthModelTests.swift`

- [ ] **Step 1: Write the failing test**

Create `app-twoTests/ViewModels/CalendarMonthModelTests.swift`:

```swift
import Foundation
import Testing
import SwiftUI
@testable import app_two

@MainActor
struct CalendarMonthModelTests {

    /// Fixed UTC Gregorian calendar so grid math is run-date-independent.
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    @Test func gridIsMondayFirstWithLeadingBlanks() {
        // Jan 2020: 1 Jan is a Wednesday → 2 leading cells (Mon, Tue), 31 days, 5 rows = 35 cells.
        let model = CalendarMonthModel(month: date(2020, 1, 15), days: [], today: date(2020, 1, 10), calendar: cal)
        #expect(model.rowCount == 5)
        #expect(model.cells.count == 35)
        #expect(model.cells[0].isInMonth == false)            // Mon 30 Dec 2019
        #expect(model.cells[2].isInMonth == true)             // Wed 1 Jan 2020
        #expect(model.cells[2].dayNumber == 1)
    }

    @Test func todayAndFutureFlags() {
        let model = CalendarMonthModel(month: date(2020, 1, 15), days: [], today: date(2020, 1, 10), calendar: cal)
        let jan10 = model.cells.first { $0.isInMonth && $0.dayNumber == 10 }
        let jan11 = model.cells.first { $0.isInMonth && $0.dayNumber == 11 }
        let jan9  = model.cells.first { $0.isInMonth && $0.dayNumber == 9 }
        #expect(jan10?.isToday == true)
        #expect(jan10?.isFuture == false)
        #expect(jan11?.isFuture == true)
        #expect(jan9?.isFuture == false)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme app-two -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:app-twoTests/CalendarMonthModelTests 2>&1 | grep -E "error:|Compiling|TEST"`
Expected: FAIL — `CalendarMonthModel` / `DayMarker` undefined (does not compile).

- [ ] **Step 3: Write minimal implementation**

Create `app-two/ViewModels/CalendarMonthModel.swift`:

```swift
import Foundation
import SwiftUI

/// What a calendar day cell shows about that day's check-ins.
enum DayMarker: Equatable {
    case none           // no entries
    case mood(Color)    // ≥1 mood → deep average-mood dot
    case neutral        // entries but no mood (e.g. medication-only)
}

/// Pure, value-type description of one month's calendar grid for the Calendar tab.
/// Monday-first weeks for `month`; each cell tagged in-month/today/future and given
/// its `DayMarker`. Selection lives in the view, so this model isn't rebuilt per tap.
struct CalendarMonthModel: Equatable {

    struct DayCell: Identifiable, Equatable {
        let date: Date          // start-of-day
        let dayNumber: Int
        let isInMonth: Bool
        let isToday: Bool
        let isFuture: Bool
        let marker: DayMarker
        var id: Date { date }
    }

    let month: Date
    let cells: [DayCell]        // row-major, 7 * rowCount, Monday-first
    let rowCount: Int

    init(month: Date, days: [MoodLibraryViewModel.TimelineDay], today: Date, calendar: Calendar = .current) {
        self.month = month

        var markerByDay: [Date: DayMarker] = [:]
        for day in days {
            markerByDay[calendar.startOfDay(for: day.date)] = CalendarMonthModel.marker(for: day)
        }

        let startOfToday = calendar.startOfDay(for: today)
        let firstOfMonth = calendar.startOfMonth(for: month)
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 0

        // Monday-first leading offset (weekday: 1=Sun…7=Sat → Mon=0…Sun=6).
        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth)
        let leading = (weekdayOfFirst + 5) % 7

        let total = leading + daysInMonth
        let rows = Int((Double(total) / 7.0).rounded(.up))
        self.rowCount = rows

        let gridStart = calendar.date(byAdding: .day, value: -leading, to: firstOfMonth)!

        var cells: [DayCell] = []
        for i in 0..<(rows * 7) {
            let cellDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: i, to: gridStart)!)
            let isInMonth = calendar.isDate(cellDate, equalTo: firstOfMonth, toGranularity: .month)
            cells.append(DayCell(
                date: cellDate,
                dayNumber: calendar.component(.day, from: cellDate),
                isInMonth: isInMonth,
                isToday: calendar.isDate(cellDate, inSameDayAs: startOfToday),
                isFuture: cellDate > startOfToday,
                marker: isInMonth ? (markerByDay[cellDate] ?? .none) : .none
            ))
        }
        self.cells = cells
    }

    /// `.mood` (deep average colour) when the day has any mood; `.neutral` when it
    /// has entries but no mood; `.none` when empty.
    static func marker(for day: MoodLibraryViewModel.TimelineDay) -> DayMarker {
        let moods = day.nodes.compactMap { $0.recording?.mood }
        if let color = MoodLevel.averageDeep(of: moods) { return .mood(color) }
        return day.nodes.isEmpty ? .none : .neutral
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme app-two -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:app-twoTests/CalendarMonthModelTests 2>&1 | grep -E "Executed|TEST (SUCCEEDED|FAILED)"`
Expected: PASS — 2 tests.

- [ ] **Step 5: Commit**

```bash
git add app-two/ViewModels/CalendarMonthModel.swift app-twoTests/ViewModels/CalendarMonthModelTests.swift
git commit -m "feat(calendar): CalendarMonthModel grid + DayMarker

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Marker rules (mood / neutral / none)

**Files:**
- Test: `app-twoTests/ViewModels/CalendarMonthModelTests.swift` (add)

- [ ] **Step 1: Write the failing test**

Add to `CalendarMonthModelTests`:

```swift
    private func day(_ d: Date, moods: [String?] = [], medOnly: Bool = false) -> MoodLibraryViewModel.TimelineDay {
        var nodes: [DayTimeline.Node] = []
        for (i, m) in moods.enumerated() {
            let rec = Recording(audioFileName: "a\(i).m4a", duration: 0, title: "t", mood: m)
            nodes.append(DayTimeline.Node(id: "rec-\(i)", time: d, recording: rec, intakeDoses: [], rings: []))
        }
        if medOnly {
            nodes.append(DayTimeline.Node(id: "med", time: d, recording: nil, intakeDoses: [], rings: []))
        }
        return MoodLibraryViewModel.TimelineDay(date: cal.startOfDay(for: d), label: "L", nodes: nodes)
    }

    @Test func markerMoodNeutralNone() {
        let d10 = date(2020, 1, 10)
        let d9  = date(2020, 1, 9)
        let model = CalendarMonthModel(
            month: date(2020, 1, 15),
            days: [day(d10, moods: ["good"]), day(d9, medOnly: true)],
            today: date(2020, 1, 31),
            calendar: cal
        )
        let c10 = model.cells.first { $0.isInMonth && $0.dayNumber == 10 }
        let c9  = model.cells.first { $0.isInMonth && $0.dayNumber == 9 }
        let c8  = model.cells.first { $0.isInMonth && $0.dayNumber == 8 }
        #expect(c10?.marker == .mood(MoodLevel.averageDeep(of: ["good"])!))
        #expect(c9?.marker == .neutral)
        #expect(c8?.marker == DayMarker.none)   // explicit: bare `.none` binds to Optional.none
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme app-two -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:app-twoTests/CalendarMonthModelTests/markerMoodNeutralNone 2>&1 | grep -E "Compiling|error:|TEST"`
Expected: FAIL — `TimelineDay` has no `date:` member yet (compile error). *(This is expected; Task 3 adds `date`. If you do Task 3 first, this passes.)*

- [ ] **Step 3: Implementation**

No new production code — the marker logic already exists from Task 1. The compile failure is the missing `TimelineDay.date`, added in Task 3. **Do Task 3 next, then re-run this test.**

- [ ] **Step 4: Run test to verify it passes** (after Task 3)

Run: `xcodebuild test -scheme app-two -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:app-twoTests/CalendarMonthModelTests/markerMoodNeutralNone 2>&1 | grep -E "Executed|TEST"`
Expected: PASS.

- [ ] **Step 5: Commit** (fold into Task 3's commit, since they're coupled by `TimelineDay.date`.)

---

## Task 3: `timelineDays` emits every in-month day + `TimelineDay.date`

**Files:**
- Modify: `app-two/ViewModels/MoodLibraryViewModel.swift:9-13` (struct), `:59-84` (`timelineDays`)
- Modify: `app-twoTests/ViewModels/MoodLibraryViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

Add a date helper and tests to `MoodLibraryViewModelTests` (top of struct):

```swift
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    @Test func pastMonthEmitsEveryDayWithEmptiesBetween() throws {
        let rec = Recording(audioFileName: "r.m4a", duration: 0, title: "Good", mood: "good")
        rec.createdAt = date(2020, 1, 10)
        context.insert(rec)
        try context.save()
        store.loadRecordings()

        let vm = MoodLibraryViewModel(store: store)
        vm.currentMonth = date(2020, 1, 15)

        #expect(vm.timelineDays.count == 31)                       // all of Jan 2020
        #expect(vm.timelineDays.first?.date == Calendar.current.startOfDay(for: date(2020, 1, 31))) // newest first
        let jan10 = vm.timelineDays.first { Calendar.current.isDate($0.date, inSameDayAs: date(2020,1,10)) }
        let jan9  = vm.timelineDays.first { Calendar.current.isDate($0.date, inSameDayAs: date(2020,1,9)) }
        #expect(jan10?.nodes.isEmpty == false)
        #expect(jan9?.nodes.isEmpty == true)                       // empty day still present
    }

    @Test func currentMonthDoesNotEmitFutureDays() throws {
        let rec = Recording(audioFileName: "r.m4a", duration: 0, title: "ok", mood: "okay")
        rec.createdAt = Date()
        context.insert(rec)
        try context.save()
        store.loadRecordings()

        let vm = MoodLibraryViewModel(store: store)   // currentMonth defaults to now
        let today = Calendar.current.startOfDay(for: Date())
        #expect(vm.timelineDays.allSatisfy { $0.date <= today })
        #expect(vm.timelineDays.first?.date == today) // newest = today
    }

    @Test func emptyStoreHasNoEntriesAndNoDays() {
        let vm = MoodLibraryViewModel(store: store)
        #expect(vm.hasAnyEntries == false)
        #expect(vm.timelineDays.isEmpty)              // first-launch: empty, view shows ContentUnavailableView
    }
```

Then **update the existing `manualDoseWithoutRecordingStillProducesADay`** to be deterministic (it previously asserted `count == 1`, which no longer holds):

```swift
    @Test func manualDoseWithoutRecordingStillProducesADay() throws {
        let when = date(2020, 1, 10)
        let dose = MedicationEvent(name: "Concerta", dose: "27mg", takenAt: when,
                                   taken: true, durationHours: 10, source: .manual)
        context.insert(dose)
        try context.save()

        let vm = MoodLibraryViewModel(store: store)
        vm.currentMonth = when

        #expect(vm.timelineDays.count == 31)
        let populated = vm.timelineDays.first { !$0.nodes.isEmpty }
        #expect(populated?.nodes.first?.recording == nil)
        #expect(populated?.nodes.first?.intakeDoses.map(\.id) == [dose.id])
    }
```

(`timelineDaysIsEmptyWithNoData`, `recordingAndLiveDoseMergeIntoOneNode`, and `untakenDosesAreExcluded` are unchanged and still pass: the first two rely on `hasAnyEntries`/`flatMap(\.nodes)`, the third has no taken entries.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme app-two -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:app-twoTests/MoodLibraryViewModelTests 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)"`
Expected: FAIL — `TimelineDay` has no `date`; `hasAnyEntries` undefined; new emission behavior absent.

- [ ] **Step 3: Implementation**

In `app-two/ViewModels/MoodLibraryViewModel.swift`, replace the `TimelineDay` struct (lines 9-13):

```swift
    struct TimelineDay: Identifiable {
        let date: Date          // start-of-day; stable id for scroll-sync
        let label: String
        let nodes: [DayTimeline.Node]
        var id: Date { date }
    }
```

Add after `isCurrentMonth` (around line 44):

```swift
    var hasAnyEntries: Bool {
        !store.recordings.isEmpty || !medicationEvents.isEmpty
    }

    /// Grid model for the currently displayed month.
    var calendarMonth: CalendarMonthModel {
        CalendarMonthModel(month: currentMonth, days: timelineDays, today: Date(), calendar: calendar)
    }
```

Replace `timelineDays` (lines 59-84) with:

```swift
    var timelineDays: [TimelineDay] {
        guard hasAnyEntries else { return [] }   // first-launch: let the view show its empty state

        let monthRecordings = store.recordings.filter {
            calendar.isDate($0.createdAt, equalTo: currentMonth, toGranularity: .month)
        }
        let monthDoses = medicationEvents.filter {
            calendar.isDate($0.takenAt, equalTo: currentMonth, toGranularity: .month)
        }
        let recordingsByDay = Dictionary(grouping: monthRecordings) { calendar.startOfDay(for: $0.createdAt) }
        let dosesByDay = Dictionary(grouping: monthDoses) { calendar.startOfDay(for: $0.takenAt) }

        let firstOfMonth = calendar.startOfMonth(for: currentMonth)
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 0
        let startOfToday = calendar.startOfDay(for: Date())

        var result: [TimelineDay] = []
        for offset in 0..<daysInMonth {
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstOfMonth) else { continue }
            let dayStart = calendar.startOfDay(for: day)
            if dayStart > startOfToday { break }     // never show future days
            result.append(TimelineDay(
                date: dayStart,
                label: dayLabel(for: dayStart),
                nodes: DayTimelineBuilder.build(
                    recordings: recordingsByDay[dayStart] ?? [],
                    doses: dosesByDay[dayStart] ?? []
                )
            ))
        }
        return result.sorted { $0.date > $1.date }   // newest first
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme app-two -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:app-twoTests/MoodLibraryViewModelTests -only-testing:app-twoTests/CalendarMonthModelTests -only-testing:app-twoTests/DayTimelineBuilderTests 2>&1 | grep -E "Executed|TEST (SUCCEEDED|FAILED)"`
Expected: PASS — all (incl. Task 2's `markerMoodNeutralNone` now compiles, and `DayTimelineBuilderTests` regression green).

- [ ] **Step 5: Commit**

```bash
git add app-two/ViewModels/MoodLibraryViewModel.swift app-two/ViewModels/CalendarMonthModel.swift app-twoTests/ViewModels/MoodLibraryViewModelTests.swift app-twoTests/ViewModels/CalendarMonthModelTests.swift
git commit -m "feat(calendar): timelineDays emits full month incl. empties; TimelineDay.date + markers

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: `DayCard` "No check-ins" empty state

**Files:**
- Modify: `app-two/Views/Components/DayCard.swift:24-30`

- [ ] **Step 1: Implementation**

In `DayCard.body`, replace the `ForEach` block (lines 24-30) with:

```swift
            if day.nodes.isEmpty {
                Text("No check-ins")
                    .font(Typography.callout)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(Array(day.nodes.enumerated()), id: \.element.id) { index, node in
                    TimelineRow(
                        node: node,
                        isLast: index == day.nodes.count - 1,
                        onTapRecording: onTapRecording
                    )
                }
            }
```

- [ ] **Step 2: Add a preview for the empty case**

Append to `DayCard.swift`:

```swift
#Preview("Empty day") {
    DayCard(
        day: .init(date: .now, label: "TUESDAY, 10 JUN", nodes: []),
        onTapRecording: { _ in }
    )
    .padding()
}
```

- [ ] **Step 3: Build & verify**

Run: `xcodebuild build -scheme app-two -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -3`
Expected: `BUILD SUCCEEDED`. Open the "Empty day" preview in Xcode canvas → header + faint "No check-ins", no tint.

- [ ] **Step 4: Commit**

```bash
git add app-two/Views/Components/DayCard.swift
git commit -m "feat(calendar): DayCard renders 'No check-ins' for empty days

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: `CalendarDayCell` view

**Files:**
- Create: `app-two/Views/Components/CalendarDayCell.swift`

- [ ] **Step 1: Implementation**

```swift
import SwiftUI

/// One day in the calendar grid: number + mood marker dot, with selection/today/
/// future styling. Selection chrome is neutral (`Color.primary` circle) so it never
/// competes with the mood-coloured marker dot.
struct CalendarDayCell: View {
    let cell: CalendarMonthModel.DayCell
    let isSelected: Bool
    let onTap: () -> Void

    @ScaledMetric(relativeTo: .body) private var diameter: CGFloat = 30

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text("\(cell.dayNumber)")
                    .font(.callout)                                   // Dynamic Type (no hardcoded size)
                    .fontWeight(isSelected || cell.isToday ? .bold : .regular)
                    .monospacedDigit()
                    .foregroundStyle(numberColor)
                    .frame(width: min(diameter, 40), height: min(diameter, 40))
                    .background {
                        if isSelected {
                            Circle().fill(Color.primary)
                        } else if cell.isToday {
                            Circle().strokeBorder(Color.primary, lineWidth: 1.6)
                        }
                    }
                marker.frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(cell.isFuture)
        .accessibilityLabel(a11yLabel)
        .accessibilityInputLabels(["\(cell.dayNumber)"])   // Voice Control: "tap 10"
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var numberColor: Color {
        if isSelected { return Color(.systemBackground) }   // on the primary circle
        if cell.isFuture { return Color(.tertiaryLabel) }
        if !cell.isInMonth { return Color(.tertiaryLabel) }
        return .primary
    }

    @ViewBuilder private var marker: some View {
        switch cell.marker {
        case .mood(let color): Circle().fill(color)
        case .neutral:         Circle().fill(Theme.textSecondary)
        case .none:            Color.clear
        }
    }

    private var a11yLabel: String {
        let day = cell.date.formatted(.dateTime.weekday(.wide).day().month(.wide))
        let state: String
        switch cell.marker {
        case .mood:    state = "has check-ins"
        case .neutral: state = "has entries"
        case .none:    state = cell.isFuture ? "future" : "no check-ins"
        }
        return cell.isToday ? "\(day), today, \(state)" : "\(day), \(state)"
    }
}

#Preview {
    let model = CalendarMonthModel(month: .now, days: [], today: .now)
    return HStack {
        ForEach(Array(model.cells.prefix(7))) { cell in
            CalendarDayCell(cell: cell, isSelected: cell.isToday, onTap: {})
        }
    }
    .padding()
}
```

- [ ] **Step 2: Build & verify**

Run: `xcodebuild build -scheme app-two -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -3`
Expected: `BUILD SUCCEEDED`. Preview shows a 7-cell row; today ringed.

- [ ] **Step 3: Commit**

```bash
git add app-two/Views/Components/CalendarDayCell.swift
git commit -m "feat(calendar): CalendarDayCell (number + mood marker + selection/today)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: `CalendarHeaderView` (collapsible week/month + chevron + jump-to-today + month swipe)

**Files:**
- Create: `app-two/Views/Components/CalendarHeaderView.swift`

- [ ] **Step 1: Implementation**

```swift
import SwiftUI

/// Collapsible week↔month calendar header for the Calendar tab.
/// Collapsed shows the selected day's week; tapping the month label/chevron expands
/// to the full month. Horizontal swipe pages months. At accessibility text sizes the
/// month grid is force-collapsed to a single week (cells get unreadable otherwise).
struct CalendarHeaderView: View {
    let model: CalendarMonthModel
    @Binding var selectedDay: Date
    @Binding var isExpanded: Bool
    let monthLabel: String
    let canJumpToToday: Bool
    let onSelect: (CalendarMonthModel.DayCell) -> Void
    let onJumpToToday: () -> Void
    let onPageMonth: (Int) -> Void   // -1 = older, +1 = newer

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let weekdaySymbols = ["M", "T", "W", "T", "F", "S", "S"]

    private var forceWeek: Bool { dynamicTypeSize >= .accessibility1 }
    private var effectiveExpanded: Bool { isExpanded && !forceWeek }

    private var weeks: [[CalendarMonthModel.DayCell]] {
        stride(from: 0, to: model.cells.count, by: 7).map {
            Array(model.cells[$0..<min($0 + 7, model.cells.count)])
        }
    }
    private var selectedWeekIndex: Int {
        weeks.firstIndex { week in
            week.contains { Calendar.current.isDate($0.date, inSameDayAs: selectedDay) }
        } ?? 0
    }
    private var visibleWeeks: [[CalendarMonthModel.DayCell]] {
        effectiveExpanded ? weeks : [weeks[safe: selectedWeekIndex] ?? []]
    }

    var body: some View {
        VStack(spacing: Spacing.s) {
            header
            weekdayCaps
            grid
        }
        .gesture(monthSwipe)
    }

    private var header: some View {
        HStack(spacing: Spacing.xs) {
            Button {
                guard !forceWeek else { return }
                withAnimation(reduceMotion ? nil : Motion.smooth) { isExpanded.toggle() }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Text(monthLabel)
                        .font(Typography.headline)
                        .foregroundStyle(.primary)
                    if !forceWeek {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .rotationEffect(.degrees(effectiveExpanded ? 90 : 0))
                            .accessibilityHidden(true)   // decorative; the month text is the label
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(forceWeek ? "" : (effectiveExpanded ? "Collapse to week" : "Expand to month"))

            Spacer()

            if canJumpToToday {
                Button(action: onJumpToToday) {
                    Text("Today")
                        .font(Typography.caption.weight(.bold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, Spacing.s)
                        .padding(.vertical, Spacing.xs)
                        .overlay(Capsule().strokeBorder(Theme.accent, lineWidth: 1.2))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var weekdayCaps: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols.indices, id: \.self) { i in
                Text(weekdaySymbols[i])
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        VStack(spacing: Spacing.xs) {
            ForEach(visibleWeeks.indices, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(visibleWeeks[row]) { cell in
                        CalendarDayCell(
                            cell: cell,
                            isSelected: Calendar.current.isDate(cell.date, inSameDayAs: selectedDay),
                            onTap: { onSelect(cell) }
                        )
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : Motion.smooth, value: effectiveExpanded)
        .animation(reduceMotion ? nil : Motion.smooth, value: model.month)
    }

    private var monthSwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                onPageMonth(value.translation.width > 0 ? -1 : 1)   // swipe right → older
            }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    @Previewable @State var selected = Calendar.current.startOfDay(for: .now)
    @Previewable @State var expanded = false
    return CalendarHeaderView(
        model: CalendarMonthModel(month: .now, days: [], today: .now),
        selectedDay: $selected,
        isExpanded: $expanded,
        monthLabel: "June 2026",
        canJumpToToday: false,
        onSelect: { selected = $0.date },
        onJumpToToday: {},
        onPageMonth: { _ in }
    )
    .padding()
}
```

- [ ] **Step 2: Build & verify**

Run: `xcodebuild build -scheme app-two -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -3`
Expected: `BUILD SUCCEEDED`. In the preview: tapping "June 2026 ›" expands/collapses with a spring; tapping a day moves the selection circle.

- [ ] **Step 3: Commit**

```bash
git add app-two/Views/Components/CalendarHeaderView.swift
git commit -m "feat(calendar): CalendarHeaderView (collapsible week/month, chevron, swipe, jump-to-today)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Wire `CalendarLibraryView` — header + two-way scroll-sync

**Files:**
- Modify: `app-two/Views/Library/CalendarLibraryView.swift`

- [ ] **Step 1: Implementation**

Replace the body of `CalendarLibraryView` (keep `init`, `store`, `viewModel`, `path`, `services`):

```swift
    @Binding var selectedTab: Tab
    @State private var viewModel: MoodLibraryViewModel
    @State private var path = NavigationPath()
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var isCalendarExpanded = false
    @State private var topDayID: Date?
    @State private var isProgrammaticScroll = false
    @State private var scrollGuardTask: Task<Void, Never>?
    @Environment(AppServices.self) private var services
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let store: RecordingStore
    private let calendar = Calendar.current

    init(store: RecordingStore, selectedTab: Binding<Tab>) {
        self.store = store
        _viewModel = State(wrappedValue: MoodLibraryViewModel(store: store))
        _selectedTab = selectedTab
    }

    var body: some View {
        ScreenContainer(title: "", showsMedicationBar: true, scrollable: false, path: $path) {
            VStack(spacing: 0) {
                CalendarHeaderView(
                    model: viewModel.calendarMonth,
                    selectedDay: $selectedDay,
                    isExpanded: $isCalendarExpanded,
                    monthLabel: viewModel.monthLabel,
                    canJumpToToday: !calendar.isDateInToday(selectedDay) || !viewModel.isCurrentMonth,
                    onSelect: { selectDay($0) },
                    onJumpToToday: { jumpToToday() },
                    onPageMonth: { pageMonth($0) }
                )
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.s)

                Divider().padding(.top, Spacing.s)

                if viewModel.hasAnyEntries {
                    timelineList
                } else {
                    emptyState.frame(maxWidth: .infinity).padding(.top, Spacing.hero)
                    Spacer()
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let recording = viewModel.recording(for: id) {
                    RecordingDetailView(recording: recording, store: store, services: services)
                }
            }
        }
        .trackScreen("CalendarLibraryView")
        .onChange(of: selectedTab) { oldValue, newValue in
            if oldValue == .calendar && newValue != .calendar {
                path.removeLast(path.count)
            }
            if newValue == .calendar { jumpToToday() }
        }
    }

    private var timelineList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.m) {
                ForEach(viewModel.timelineDays) { day in
                    DayCard(day: day, onTapRecording: { path.append($0) })
                        .id(day.date)
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.xxl)
        }
        .scrollPosition(id: $topDayID, anchor: .top)
        .edgeFadeMask(top: 0, bottom: Spacing.section)
        .onChange(of: topDayID) { _, newValue in
            guard !isProgrammaticScroll, let day = newValue else { return }
            selectedDay = day
        }
    }

    // MARK: - Selection / navigation

    private func selectDay(_ cell: CalendarMonthModel.DayCell) {
        if !cell.isInMonth {                       // out-of-month tap → page to that month, then select it
            let delta = cell.date < viewModel.currentMonth ? -1 : 1
            guard canPage(delta) else { return }
            delta < 0 ? viewModel.prevMonth() : viewModel.nextMonth()
        }
        scrollList(to: cell.date)
    }

    private func scrollList(to day: Date) {
        let target = calendar.startOfDay(for: day)
        selectedDay = target
        isProgrammaticScroll = true
        withAnimation(reduceMotion ? nil : Motion.smooth) { topDayID = target }
        scrollGuardTask?.cancel()                       // a newer tap supersedes the previous guard
        scrollGuardTask = Task {
            try? await Task.sleep(for: .seconds(0.45))  // ~ the scroll animation; clears the loop guard
            if !Task.isCancelled { isProgrammaticScroll = false }
        }
    }

    private func jumpToToday() {
        viewModel.currentMonth = Date()
        if !reduceMotion { withAnimation(Motion.smooth) { isCalendarExpanded = false } }
        else { isCalendarExpanded = false }
        scrollList(to: calendar.startOfDay(for: Date()))
    }

    /// Month paging is bounded: back to the earliest month with data, forward to the current month.
    private func canPage(_ delta: Int) -> Bool {
        if delta < 0 {
            guard let earliest = viewModel.availableMonths.first else { return false }
            return calendar.compare(viewModel.currentMonth, to: earliest, toGranularity: .month) == .orderedDescending
        } else {
            return !viewModel.isCurrentMonth
        }
    }

    private func pageMonth(_ delta: Int) {
        guard canPage(delta) else { return }
        delta < 0 ? viewModel.prevMonth() : viewModel.nextMonth()
        if let newest = viewModel.timelineDays.first?.date {   // newest in-range day of the now-current month
            scrollList(to: newest)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No entries yet",
            systemImage: "calendar.badge.exclamationmark",
            description: Text("Record a voice note to see it here.")
        )
    }
```

- [ ] **Step 2: Build**

Run: `xcodebuild build -scheme app-two -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`. (If `.scrollPosition(id:)` mismatches the `.id(day.date)` type, both must be `Date` — they are.)

- [ ] **Step 3: Run the full feature test suite**

Run: `xcodebuild test -scheme app-two -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:app-twoTests/CalendarMonthModelTests -only-testing:app-twoTests/MoodLibraryViewModelTests -only-testing:app-twoTests/DayTimelineBuilderTests 2>&1 | grep -E "Executed|TEST (SUCCEEDED|FAILED)"`
Expected: PASS — all green.

- [ ] **Step 4: Commit**

```bash
git add app-two/Views/Library/CalendarLibraryView.swift
git commit -m "feat(calendar): wire CalendarHeaderView + two-way scroll-sync into CalendarLibraryView

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Simulator verification (default + accessibility text size)

**Files:** none (verification only).

- [ ] **Step 1: Build, install, launch on the simulator**

```bash
UDID=A97FF1D1-7C91-48CD-9988-962AC80EAAF9   # iPhone 17 (or pick from: xcrun simctl list devices available)
xcodebuild build -scheme app-two -destination "id=$UDID" 2>&1 | tail -3
APP=$(find ~/Library/Developer/Xcode/DerivedData -name app-two.app -path "*Debug-iphonesimulator*" | head -1)
xcrun simctl boot "$UDID" 2>/dev/null; xcrun simctl bootstatus "$UDID" -b
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" Rythm-App.app-two
xcrun simctl io "$UDID" screenshot /tmp/calendar_default.png
```

- [ ] **Step 2: Verify the default-size render** (`/tmp/calendar_default.png`)

Confirm: month label + chevron + week strip; today ringed; mood-colour dots under days with entries; the list below shows the month's days incl. "No check-ins" rows. Tap the month label → expands to the full month grid. Tap a past day → list scrolls to it; scroll the list → the selected circle follows.

- [ ] **Step 3: Verify the accessibility-text-size render**

```bash
xcrun simctl ui "$UDID" content_size accessibility-extra-large
xcrun simctl io "$UDID" screenshot /tmp/calendar_ax.png
xcrun simctl ui "$UDID" content_size large    # restore
```

Confirm in `/tmp/calendar_ax.png`: the chevron is gone and the calendar is **week-only** (month expansion disabled); day numbers are larger but legible.

- [ ] **Step 4: Update the backlog (stage → In code)**

Move the "Calendar day-selection & navigation" row in `docs/BACKLOG.md` from **📐 Plan** to **🔨 In code** with branch `feat/calendar-day-selection`.

```bash
git add docs/BACKLOG.md
git commit -m "docs(backlog): calendar day-selection now in code

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Verification checklist (run before opening a PR)

- [ ] `xcodebuild build -scheme app-two -destination 'platform=iOS Simulator,name=iPhone 17'` → `BUILD SUCCEEDED`
- [ ] `xcodebuild test … -only-testing:app-twoTests/CalendarMonthModelTests -only-testing:app-twoTests/MoodLibraryViewModelTests -only-testing:app-twoTests/DayTimelineBuilderTests -only-testing:app-twoTests/MedicationBarViewModelTests` → all PASS
- [ ] Default-size + accessibility-size screenshots captured and correct
- [ ] Insights tab still renders (we did not touch `MonthSelectorScrollView`, but confirm no shared regressions)
- [ ] **swiftui-pro** review pass over `CalendarMonthModel`, `CalendarDayCell`, `CalendarHeaderView`, `CalendarLibraryView` (modern APIs, no redundant view rebuilds)
- [ ] **swift-concurrency-pro** review of the scroll-guard `Task` (cancellation on rapid taps; no MainActor hops)
- [ ] **Accessibility (device/Inspector):** VoiceOver reads each day cell as "weekday date, state"; the month button reads the month + "Expand to month" hint; Voice Control "tap 10" works; Dynamic Type Canvas variants legible (month grid auto-collapses to week at `.accessibility1`); Reduce Motion gives instant week↔month + scroll

## Notes / risks
- **Month paging affordance** is a horizontal swipe on the header + out-of-month-day tap + jump-to-today. There are no ‹ › month arrows by design (keeps the header clean); if swipe proves undiscoverable in testing, add arrows beside the month label.
- **Empty-day cards** use the full `DayCard` chrome. If long quiet runs look heavy in real data, a lighter empty-row treatment is a fast follow (out of scope here).
- **Weekday caps** are hardcoded Monday-first single letters (matches the mockup); revisit for locale/first-weekday if internationalising.
- **`topDayID` initial value** is `nil` until the user scrolls; selection is seeded from `selectedDay` (today) and updated by taps. This is fine — the list opens at the top (newest) and the calendar shows today selected.
