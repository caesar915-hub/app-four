# Calendar Mood + Medication Check-in Timeline — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Also required during the SwiftUI tasks (3–5):** invoke `swiftui-pro`, `swift-accessibility-skill`, and `swiftui-design-principles` before writing/reviewing view code.

**Goal:** Replace the flat per-day `RecordingRow` list in the Calendar tab with a merged vertical timeline where each node is a single moment in time carrying a mood check-in and/or one or more medication doses, with concentric effect rings for every dose active at that moment.

**Architecture:** A pure, fully-unit-tested builder (`DayTimelineBuilder`) merges a day's `Recording`s (placed at `createdAt`) and `MedicationEvent`s (placed at `takenAt`) into time-ordered `DayTimeline.Node`s. Events sharing the exact same timestamp collapse into one node (the "live check-in" case); a dose mentioned with an earlier spoken time stays a separate node anchored to that intake time. Every node carries the effect rings of all doses whose window covers the node's instant. `MoodLibraryViewModel` fetches medication events alongside recordings and exposes `timelineDays`. New SwiftUI components (`TimelineBead`, `TimelineRow`) render the beads, concentric rings, and connector line.

**Tech Stack:** SwiftUI, SwiftData (`@Model`), Observation (`@Observable`), Swift Testing (`import Testing`), in-memory `ModelContainer` for tests. Reuses existing `MedicationEvent.effectProgress(at:)`, `MedicationBarViewModel.effectColor(for:)`, and `Recording.moodColor`.

**Design decisions locked with the user:**
1. Percentages in the mock are illustrative; real progress = `effectProgress(at:)` over `durationHours` (default 10h).
2. A med mentioned in a recording → if its `takenAt` equals the recording time, it's **one combined node**; if back-dated to an earlier spoken time, it's a **separate hollow med node** at that intake time, and the recording's node shows that dose as an active ring.
3. Manually-logged doses (med-bar taps, no recording) **do** appear as hollow med-only nodes.
4. Voice notes that mention neither mood nor medication still appear as **neutral (gray-centre) nodes** — nothing is hidden.
5. A node draws rings for **active (unfinished) doses only**, capped at the **3 most-recent**, ordered oldest→newest (outermost = oldest), matching the medication bar.
6. Rings (and their % labels) use **flat purple** (`Palette.medication`), not the medication-bar color ramp. A ring fills to a full circle at 99% and disappears at 100% (`activeRings` already excludes `instant >= end`); the % label is **truncated** (`Int(progress*100)`) so a visible ring never reads "100%".
7. **The `AppTwoUIPlayground` target is deleted** (Task 0) — its only consumers of `DayGroup`/`MoodDaySection` go away, so those are removed as dead code in Task 5.

**Out of scope (do not touch):** `MoodLibraryViewModel.DayGroup` / `groupedDays` and `MoodDaySection.swift` stay as-is — they are still referenced by `AppTwoUIPlayground/ComponentGalleryView.swift`. We add `timelineDays` alongside the existing API rather than replacing it.

---

## File Structure

| File | Responsibility | Action |
|------|----------------|--------|
| `app-two/ViewModels/DayTimeline.swift` | `DayTimeline.Node`, `DayTimeline.Ring`, and the pure `DayTimelineBuilder.build(...)`. No SwiftUI, no store. | Create |
| `app-twoTests/ViewModels/DayTimelineBuilderTests.swift` | Unit tests for the builder (merge, back-date, rings ordering, cap, expiry, overlay). | Create |
| `app-two/ViewModels/MoodLibraryViewModel.swift` | Add medication-event fetching + `timelineDays` computed property + `TimelineDay`. | Modify |
| `app-twoTests/ViewModels/MoodLibraryViewModelTests.swift` | Tests for `timelineDays` (merge, manual-dose-only day, month filtering). | Create |
| `app-two/Views/Components/TimelineBead.swift` | The circular bead: mood/hollow centre, concentric effect rings, in-bead time + percentages, accessibility label. | Create |
| `app-two/Views/Components/TimelineRow.swift` | One timeline row: bead column + connector line + content (title, intake meta, tap target). | Create |
| `app-two/Views/Library/CalendarLibraryView.swift` | Swap the day section to render `timelineDays` via `TimelineRow`; empty-state check uses `timelineDays`. | Modify |

---

## Task 0: Delete the `AppTwoUIPlayground` target (+ orphaned `MoodDaySection`)

**Files:**
- Delete: `AppTwoUIPlayground/` (whole directory)
- Delete: `app-two/Views/Components/MoodDaySection.swift` (only the playground's `ComponentGalleryView` used it)
- Modify: `app-two.xcodeproj/project.pbxproj` (strip the ~43 playground references + the one `MoodDaySection.swift` reference + the `AppTwoUIPlayground` target/scheme)

This is delicate Xcode-project surgery — done by the lead (not a subagent). Prefer the `xcodeproj` Ruby gem when available; fall back to careful manual pruning.

- [ ] **Step 1: Remove the target + files**

Use the `xcodeproj` gem if installed (`gem list -i xcodeproj`) to delete the `AppTwoUIPlayground` target and its file references, then delete the directory and `MoodDaySection.swift`. If the gem is unavailable, install it (`gem install xcodeproj`) or prune `project.pbxproj` by hand, removing every block that names `AppTwoUIPlayground`, the playground file UUIDs, and `MoodDaySection.swift`.

- [ ] **Step 2: Verify the project still builds**

Run: `xcodebuild build -scheme app-two -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`, and `git status` shows the playground gone with no dangling references.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: delete AppTwoUIPlayground target and its orphaned MoodDaySection

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

> After this task, `MoodLibraryViewModel.DayGroup` / `groupedDays` are only referenced by `CalendarLibraryView`'s old `daySection`, which Task 5 removes — at which point Task 5 also deletes `DayGroup`/`groupedDays`.

---

## Task 1: `DayTimeline` model + pure `DayTimelineBuilder`

**Files:**
- Create: `app-two/ViewModels/DayTimeline.swift`
- Test: `app-twoTests/ViewModels/DayTimelineBuilderTests.swift`

This is the heart of the feature — the merge/ring logic the user emphasized. Build it test-first.

- [ ] **Step 1: Write the failing tests**

Create `app-twoTests/ViewModels/DayTimelineBuilderTests.swift`:

```swift
import Foundation
import Testing
import SwiftData
@testable import app_two

@MainActor
struct DayTimelineBuilderTests {
    var container: ModelContainer
    var context: ModelContext

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Recording.self, MedicationEvent.self, AppSettings.self,
            configurations: config
        )
        context = container.mainContext
    }

    /// Build a `Date` at a fixed wall-clock time on a fixed day so progress math is deterministic.
    private func time(_ hour: Int, _ minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 9
        comps.hour = hour; comps.minute = minute
        return Calendar.current.date(from: comps)!
    }

    private func makeRecording(at date: Date, mood: String?) -> Recording {
        let r = Recording(audioFileName: "r.m4a", duration: 0, title: "Note", mood: mood)
        r.createdAt = date
        context.insert(r)
        return r
    }

    private func makeDose(at date: Date, durationHours: Double = 10) -> MedicationEvent {
        let e = MedicationEvent(name: "Concerta", dose: "27mg", takenAt: date,
                                taken: true, durationHours: durationHours, source: .manual)
        context.insert(e)
        return e
    }

    @Test func liveCheckInMergesRecordingAndDoseIntoOneNode() {
        let t = time(10, 45)
        let r = makeRecording(at: t, mood: "good")
        let dose = makeDose(at: t)

        let nodes = DayTimelineBuilder.build(recordings: [r], doses: [dose])

        #expect(nodes.count == 1)
        #expect(nodes[0].recording?.id == r.id)
        #expect(nodes[0].intakeDoses.map(\.id) == [dose.id])
        #expect(nodes[0].rings.count == 1)
        #expect(nodes[0].rings[0].progress < 0.01)        // fresh dose at its own node
    }

    @Test func backDatedDoseIsASeparateNodeAndOverlaysTheRecording() {
        let dose = makeDose(at: time(10, 45))             // intake 10:45
        let r = makeRecording(at: time(14, 0), mood: "good")  // recorded 14:00

        let nodes = DayTimelineBuilder.build(recordings: [r], doses: [dose])

        #expect(nodes.count == 2)
        // newest first
        let recordingNode = nodes[0]
        let doseNode = nodes[1]
        #expect(recordingNode.recording?.id == r.id)
        #expect(recordingNode.intakeDoses.isEmpty)
        #expect(recordingNode.rings.count == 1)
        // 3h15m into a 10h window ≈ 0.325
        #expect(abs(recordingNode.rings[0].progress - 0.325) < 0.01)
        #expect(doseNode.recording == nil)
        #expect(doseNode.intakeDoses.map(\.id) == [dose.id])
        #expect(doseNode.rings[0].progress < 0.01)
    }

    @Test func ringsAreOrderedOldestOutermost() {
        let d1 = makeDose(at: time(10, 45))               // older
        let d2 = makeDose(at: time(16, 0))                // newer
        let r = makeRecording(at: time(18, 0), mood: "great")

        let nodes = DayTimelineBuilder.build(recordings: [r], doses: [d1, d2])
        let node = nodes.first { $0.recording?.id == r.id }!

        #expect(node.rings.count == 2)
        #expect(node.rings[0].doseID == d1.id)            // outermost = oldest
        #expect(node.rings[1].doseID == d2.id)
        #expect(node.rings[0].progress > node.rings[1].progress)
    }

    @Test func moodOnlyNodeStillShowsActiveDoseRings() {
        let dose = makeDose(at: time(10, 45))             // manual, no recording
        let r = makeRecording(at: time(14, 0), mood: "okay")

        let nodes = DayTimelineBuilder.build(recordings: [r], doses: [dose])
        let moodNode = nodes.first { $0.recording?.id == r.id }!

        #expect(moodNode.intakeDoses.isEmpty)
        #expect(moodNode.rings.count == 1)                // overlay of the active dose
        #expect(abs(moodNode.rings[0].progress - 0.325) < 0.01)
    }

    @Test func expiredDoseDropsOffLaterNodes() {
        let dose = makeDose(at: time(6, 0), durationHours: 4)   // ends 10:00
        let r = makeRecording(at: time(14, 0), mood: "flat")

        let nodes = DayTimelineBuilder.build(recordings: [r], doses: [dose])
        let moodNode = nodes.first { $0.recording?.id == r.id }!

        #expect(moodNode.rings.isEmpty)
    }

    @Test func ringsCapAtThreeMostRecentActiveDoses() {
        let doses = [time(9, 0), time(10, 0), time(11, 0), time(12, 0)].map { makeDose(at: $0) }
        let r = makeRecording(at: time(13, 0), mood: "good")

        let nodes = DayTimelineBuilder.build(recordings: [r], doses: doses)
        let node = nodes.first { $0.recording?.id == r.id }!

        #expect(node.rings.count == 3)
        // 3 most-recent are 10:00,11:00,12:00 → outermost-first is 10:00
        #expect(node.rings[0].doseID == doses[1].id)
        #expect(node.rings[2].doseID == doses[3].id)
    }

    @Test func manualDoseOnlyProducesAHollowNode() {
        let dose = makeDose(at: time(8, 0))

        let nodes = DayTimelineBuilder.build(recordings: [], doses: [dose])

        #expect(nodes.count == 1)
        #expect(nodes[0].recording == nil)
        #expect(nodes[0].intakeDoses.map(\.id) == [dose.id])
    }

    @Test func nodesAreSortedNewestFirst() {
        let r1 = makeRecording(at: time(9, 0), mood: "good")
        let r2 = makeRecording(at: time(18, 0), mood: "low")

        let nodes = DayTimelineBuilder.build(recordings: [r1, r2], doses: [])

        #expect(nodes.map(\.recording?.id) == [r2.id, r1.id])
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -scheme app-two -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:app-twoTests/DayTimelineBuilderTests 2>&1 | tail -30`
Expected: FAIL — `cannot find 'DayTimelineBuilder' in scope` / `cannot find 'DayTimeline' in scope`.
(Adjust the simulator name to one that exists: `xcrun simctl list devices available | grep iPhone`.)

- [ ] **Step 3: Write the model + builder**

Create `app-two/ViewModels/DayTimeline.swift`:

```swift
import Foundation

/// A single day's merged timeline of mood/voice check-ins and medication doses,
/// collapsed into time-ordered nodes.
enum DayTimeline {

    /// One moment on the day's timeline. A node groups everything that happened
    /// at the same instant: a recording, one or more dose intakes, or both.
    struct Node: Identifiable {
        /// Stable across rebuilds for SwiftUI diffing (timestamp + event ids).
        let id: String
        let time: Date
        /// The recording logged at `time`, if any. Drives centre fill, title, and navigation.
        let recording: Recording?
        /// Doses whose `takenAt == time` — the fresh intakes "checked in" at this node.
        let intakeDoses: [MedicationEvent]
        /// Every dose still inside its effect window at `time`, oldest→newest, max 3.
        /// `rings[0]` is the outermost (oldest) ring.
        let rings: [Ring]
    }

    /// One concentric progress ring, already evaluated at its node's time.
    struct Ring: Identifiable, Equatable {
        let doseID: UUID
        let progress: Double
        var id: UUID { doseID }
    }
}

/// Pure, store-free builder. Everything it reads is a stored property or a value
/// method, so it is fully unit-testable without `now`-mocking: a past node's ring
/// progress is historical and fixed at that node's own time.
enum DayTimelineBuilder {

    /// Builds time-ordered nodes (newest first) for a single day.
    /// - Parameters:
    ///   - recordings: recordings whose `createdAt` falls on the day.
    ///   - doses: taken medication events whose `takenAt` falls on the day.
    @MainActor
    static func build(recordings: [Recording], doses: [MedicationEvent]) -> [DayTimeline.Node] {
        // 1. Every distinct instant where something happened.
        var instants = Set<Date>()
        recordings.forEach { instants.insert($0.createdAt) }
        doses.forEach { instants.insert($0.takenAt) }

        // 2. One node per instant.
        let nodes = instants.map { instant -> DayTimeline.Node in
            // At most one recording per exact instant in practice (createdAt = Date() at capture).
            let recording = recordings.first { $0.createdAt == instant }
            let intakeDoses = doses.filter { $0.takenAt == instant }
            let rings = activeRings(at: instant, doses: doses)
            return DayTimeline.Node(
                id: nodeID(instant: instant, recording: recording, intakeDoses: intakeDoses),
                time: instant,
                recording: recording,
                intakeDoses: intakeDoses,
                rings: rings
            )
        }

        // 3. Newest first (top of the day section).
        return nodes.sorted { $0.time > $1.time }
    }

    /// Doses whose effect window covers `instant`, capped at the 3 most-recent and
    /// then ordered oldest→newest so the oldest dose is the outermost ring.
    private static func activeRings(at instant: Date, doses: [MedicationEvent]) -> [DayTimeline.Ring] {
        doses
            .filter { dose in
                let start = dose.takenAt
                let end = start.addingTimeInterval(dose.durationHours * 3600)
                return start <= instant && instant < end
            }
            .sorted { $0.takenAt > $1.takenAt }   // newest first
            .prefix(3)                            // keep the 3 most-recent (matches the med bar)
            .reversed()                           // oldest first → outermost
            .map { DayTimeline.Ring(doseID: $0.id, progress: $0.effectProgress(at: instant)) }
    }

    private static func nodeID(instant: Date, recording: Recording?, intakeDoses: [MedicationEvent]) -> String {
        var parts = [String(instant.timeIntervalSince1970)]
        if let recording { parts.append(recording.id.uuidString) }
        parts.append(contentsOf: intakeDoses.map(\.id.uuidString).sorted())
        return parts.joined(separator: "-")
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodebuild test -scheme app-two -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:app-twoTests/DayTimelineBuilderTests 2>&1 | tail -30`
Expected: PASS — all 8 tests green.

- [ ] **Step 5: Commit**

```bash
git add app-two/ViewModels/DayTimeline.swift app-twoTests/ViewModels/DayTimelineBuilderTests.swift
git commit -m "feat(calendar): merge recordings + doses into a day timeline builder

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: `MoodLibraryViewModel.timelineDays`

**Files:**
- Modify: `app-two/ViewModels/MoodLibraryViewModel.swift`
- Test: `app-twoTests/ViewModels/MoodLibraryViewModelTests.swift`

The view model must also fetch medication events (manual doses are not attached to any recording), refresh them when the bar changes, and group both streams by day.

- [ ] **Step 1: Write the failing tests**

Create `app-twoTests/ViewModels/MoodLibraryViewModelTests.swift`:

```swift
import Foundation
import Testing
import SwiftData
@testable import app_two

@MainActor
struct MoodLibraryViewModelTests {
    var container: ModelContainer
    var context: ModelContext
    var store: RecordingStore

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Recording.self, MedicationEvent.self, AppSettings.self,
            configurations: config
        )
        context = container.mainContext
        store = RecordingStore(context: context)
    }

    @Test func timelineDaysIsEmptyWithNoData() {
        let vm = MoodLibraryViewModel(store: store)
        #expect(vm.timelineDays.isEmpty)
    }

    @Test func manualDoseWithoutRecordingStillProducesADay() throws {
        let dose = MedicationEvent(name: "Concerta", dose: "27mg", takenAt: Date(),
                                   taken: true, durationHours: 10, source: .manual)
        context.insert(dose)
        try context.save()

        let vm = MoodLibraryViewModel(store: store)

        #expect(vm.timelineDays.count == 1)
        let node = vm.timelineDays[0].nodes[0]
        #expect(node.recording == nil)
        #expect(node.intakeDoses.map(\.id) == [dose.id])
    }

    @Test func recordingAndLiveDoseMergeIntoOneNode() throws {
        let now = Date()
        let recording = Recording(audioFileName: "r.m4a", duration: 0, title: "Good", mood: "good")
        recording.createdAt = now
        context.insert(recording)
        let dose = MedicationEvent(name: "Concerta", dose: "27mg", takenAt: now,
                                   taken: true, durationHours: 10, source: .transcript)
        context.insert(dose)
        dose.recording = recording
        try context.save()
        store.loadRecordings()

        let vm = MoodLibraryViewModel(store: store)
        let nodes = vm.timelineDays.flatMap(\.nodes)

        #expect(nodes.count == 1)
        #expect(nodes[0].recording?.id == recording.id)
        #expect(nodes[0].intakeDoses.map(\.id) == [dose.id])
    }

    @Test func untakenDosesAreExcluded() throws {
        let dose = MedicationEvent(name: "Concerta", dose: "27mg", takenAt: Date(),
                                   taken: false, durationHours: 10, source: .manual)
        context.insert(dose)
        try context.save()

        let vm = MoodLibraryViewModel(store: store)
        #expect(vm.timelineDays.isEmpty)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -scheme app-two -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:app-twoTests/MoodLibraryViewModelTests 2>&1 | tail -30`
Expected: FAIL — `value of type 'MoodLibraryViewModel' has no member 'timelineDays'`.

- [ ] **Step 3: Add medication fetching + `timelineDays`**

In `app-two/ViewModels/MoodLibraryViewModel.swift`, add `import SwiftData` at the top (it currently imports only `Foundation` and `Observation`):

```swift
import Foundation
import Observation
import SwiftData
```

Add the `TimelineDay` type next to `DayGroup` (inside the class):

```swift
    struct TimelineDay: Identifiable {
        var id: String { label }
        let label: String
        let nodes: [DayTimeline.Node]
    }
```

Add the stored medication-event array and notification observer. Place these alongside the existing `@ObservationIgnored` properties:

```swift
    /// Taken medication events (manual + transcript). Observed so the timeline
    /// recomputes when the medication bar logs or deletes a dose.
    private var medicationEvents: [MedicationEvent] = []
    @ObservationIgnored private var medObserver: NSObjectProtocol?
```

Replace the existing `init` with one that loads doses and subscribes:

```swift
    init(store: RecordingStore) {
        self.store = store
        loadMedicationEvents()
        medObserver = NotificationCenter.default.addObserver(
            forName: .medicationEventsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.loadMedicationEvents() }
    }

    deinit {
        if let medObserver { NotificationCenter.default.removeObserver(medObserver) }
    }

    private func loadMedicationEvents() {
        let descriptor = FetchDescriptor<MedicationEvent>(
            predicate: #Predicate { $0.taken == true },
            sortBy: [SortDescriptor(\.takenAt, order: .reverse)]
        )
        medicationEvents = (try? store.context.fetch(descriptor)) ?? []
    }
```

Add the `timelineDays` computed property after `groupedDays`:

```swift
    var timelineDays: [TimelineDay] {
        let monthRecordings = store.recordings.filter {
            calendar.isDate($0.createdAt, equalTo: currentMonth, toGranularity: .month)
        }
        let monthDoses = medicationEvents.filter {
            calendar.isDate($0.takenAt, equalTo: currentMonth, toGranularity: .month)
        }
        let recordingsByDay = Dictionary(grouping: monthRecordings) {
            calendar.startOfDay(for: $0.createdAt)
        }
        let dosesByDay = Dictionary(grouping: monthDoses) {
            calendar.startOfDay(for: $0.takenAt)
        }
        let days = Set(recordingsByDay.keys).union(dosesByDay.keys)
        return days
            .sorted(by: >)
            .map { day in
                TimelineDay(
                    label: dayLabel(for: day),
                    nodes: DayTimelineBuilder.build(
                        recordings: recordingsByDay[day] ?? [],
                        doses: dosesByDay[day] ?? []
                    )
                )
            }
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodebuild test -scheme app-two -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:app-twoTests/MoodLibraryViewModelTests 2>&1 | tail -30`
Expected: PASS — all 4 tests green.

- [ ] **Step 5: Commit**

```bash
git add app-two/ViewModels/MoodLibraryViewModel.swift app-twoTests/ViewModels/MoodLibraryViewModelTests.swift
git commit -m "feat(calendar): expose timelineDays merging recordings and medication doses

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: `TimelineBead` view (centre + concentric rings)

**Files:**
- Create: `app-two/Views/Components/TimelineBead.swift`

**Invoke `swiftui-pro`, `swift-accessibility-skill`, and `swiftui-design-principles` before writing this file.**

This is preview-driven (SwiftUI views aren't unit-tested here). Verification = the `#Preview` renders correctly and the build succeeds.

- [ ] **Step 1: Write the bead view**

Create `app-two/Views/Components/TimelineBead.swift`:

```swift
import SwiftUI

/// The circular "bead" for one timeline node: a mood-coloured (recording) or
/// hollow (med-only / neutral) centre, wrapped by one concentric effect ring per
/// active medication dose, with the time and each dose's percentage inside.
struct TimelineBead: View {
    let node: DayTimeline.Node

    private let size: CGFloat = 64
    private let ringWidth: CGFloat = 4
    private let ringGap: CGFloat = 2

    var body: some View {
        ZStack {
            centre
            ForEach(Array(node.rings.enumerated()), id: \.element.id) { index, ring in
                ringArc(ring, index: index)
            }
            innerLabel
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Centre

    @ViewBuilder
    private var centre: some View {
        if let recording = node.recording {
            Circle().fill(recording.moodColor)   // gray for nil mood (moodColor handles it)
        } else {
            Circle()
                .fill(Theme.background)
                .overlay(Circle().strokeBorder(Theme.separator, lineWidth: 1))
        }
    }

    // MARK: - Rings

    private func ringArc(_ ring: DayTimeline.Ring, index: Int) -> some View {
        let inset = CGFloat(index) * (ringWidth + ringGap) + ringWidth / 2
        return Circle()
            .trim(from: 0, to: max(0.001, ring.progress))   // tiny purple dot at 0%, no gray track
            .stroke(
                Palette.medication,                          // flat purple (no ramp)
                style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))                   // start at 12 o'clock
            .padding(inset)
    }

    // MARK: - Inner label (time + percentages)

    private var innerLabel: some View {
        VStack(spacing: 0) {
            Text(node.time, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute())
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(timeColor)
            ForEach(node.rings) { ring in
                Text("\(Int(ring.progress * 100))%")        // truncates → never "100%" on a visible ring
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Palette.medication)     // % matches its purple ring
            }
        }
        .minimumScaleFactor(0.5)
        .lineLimit(1)
        .padding(ringWidth + 4)
    }

    /// Justified exception to the "no Color.white" rule: legible text on a
    /// saturated mood fill. Hollow beads use primary text.
    private var timeColor: Color {
        node.recording != nil ? .white : Theme.textPrimary
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        let time = node.time.formatted(.dateTime.hour().minute())
        var parts: [String] = ["\(time) check-in"]
        if let title = node.recording?.title { parts.append(title) }
        if node.recording == nil, let dose = node.intakeDoses.first {
            parts.append("\(dose.name) \(dose.dose ?? dose.defaultDose ?? "")")
        }
        for ring in node.rings {
            parts.append("medication \(Int(ring.progress * 100)) percent")
        }
        return parts.joined(separator: ", ")
    }
}

#Preview("Beads") {
    // Lightweight in-memory fixtures for the preview.
    struct PreviewWrapper: View {
        var body: some View {
            VStack(spacing: 24) {
                bead(rings: [])                          // mood only
                bead(rings: [0.0])                       // med just taken
                bead(rings: [0.5])                       // mood + one active dose
                bead(rings: [0.99, 0.25])                // mood + two doses (outer near full)
            }
            .padding()
        }

        private func bead(rings: [Double]) -> some View {
            let r = Recording(audioFileName: "p.m4a", duration: 0, title: "Good", mood: "good")
            let node = DayTimeline.Node(
                id: UUID().uuidString,
                time: Date(),
                recording: r,
                intakeDoses: [],
                rings: rings.enumerated().map { DayTimeline.Ring(doseID: UUID(), progress: $0.element) }
            )
            return TimelineBead(node: node)
        }
    }
    return PreviewWrapper()
}
```

- [ ] **Step 2: Build and inspect the preview**

Run: `xcodebuild build -scheme app-two -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`. Open `TimelineBead.swift` in Xcode and confirm the preview shows: a solid mood circle, a hollow circle with a 0% nub, a circle with a half ring, and a circle with two concentric rings (outer full, inner quarter).

- [ ] **Step 3: Commit**

```bash
git add app-two/Views/Components/TimelineBead.swift
git commit -m "feat(calendar): add TimelineBead with concentric medication effect rings

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: `TimelineRow` (bead column + connector line + content)

**Files:**
- Create: `app-two/Views/Components/TimelineRow.swift`

**Keep `swiftui-pro` + `swift-accessibility-skill` active.**

- [ ] **Step 1: Write the row view**

Create `app-two/Views/Components/TimelineRow.swift`:

```swift
import SwiftUI

/// One row of the day timeline: the bead (with its downward connector line) on the
/// left, and the check-in content on the right. Tapping a row that has a recording
/// navigates to its detail; med-only rows are not tappable.
struct TimelineRow: View {
    let node: DayTimeline.Node
    let isLast: Bool
    let onTapRecording: (UUID) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.l) {
            beadColumn
            content
                .padding(.bottom, isLast ? 0 : Spacing.l)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Bead + connector

    private var beadColumn: some View {
        VStack(spacing: 0) {
            TimelineBead(node: node)
            if !isLast {
                Rectangle()
                    .fill(Theme.separator)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let recording = node.recording {
            Button { onTapRecording(recording.id) } label: { contentBody }
                .buttonStyle(.plain)
        } else {
            contentBody
        }
    }

    private var contentBody: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title.uppercased())
                .font(Typography.headline)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.leading)
            if let subtitle {
                Text(subtitle)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Spacing.m)   // visually centre the first line against the bead
    }

    // MARK: - Text

    private var title: String {
        if let recording = node.recording { return recording.title }
        // Med-only node: list the distinct meds checked in here.
        let names = node.intakeDoses.map { dose -> String in
            let d = dose.dose ?? dose.defaultDose
            return d.map { "\(dose.name) \($0)" } ?? dose.name
        }
        return names.isEmpty ? "Medication" : Array(Set(names)).sorted().joined(separator: " · ")
    }

    private var subtitle: String? {
        guard node.recording != nil, !node.intakeDoses.isEmpty else { return nil }
        // Recording that also logged a fresh dose at this instant.
        let names = node.intakeDoses.map(\.name)
        return Array(Set(names)).sorted().joined(separator: " · ")
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -scheme app-two -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add app-two/Views/Components/TimelineRow.swift
git commit -m "feat(calendar): add TimelineRow with connector line and tap-to-open

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: Wire `CalendarLibraryView` to the timeline

**Files:**
- Modify: `app-two/Views/Library/CalendarLibraryView.swift`

**Keep `swiftui-pro` + `swift-accessibility-skill` active.**

- [ ] **Step 1: Swap the day rendering + empty-state check**

In `app-two/Views/Library/CalendarLibraryView.swift`, change the body's content block. Replace:

```swift
                if viewModel.groupedDays.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity)
                        .padding(.top, Spacing.hero)
                } else {
                    ForEach(viewModel.groupedDays) { group in
                        daySection(group: group)
                    }
                }
```

with:

```swift
                if viewModel.timelineDays.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity)
                        .padding(.top, Spacing.hero)
                } else {
                    ForEach(viewModel.timelineDays) { day in
                        timelineSection(day: day)
                    }
                }
```

Replace the entire `daySection(group:)` function with:

```swift
    // MARK: - Day section

    private func timelineSection(day: MoodLibraryViewModel.TimelineDay) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(day.label.uppercased())
                .font(Typography.label)
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.m)
                .accessibilityAddTraits(.isHeader)

            ForEach(Array(day.nodes.enumerated()), id: \.element.id) { index, node in
                TimelineRow(
                    node: node,
                    isLast: index == day.nodes.count - 1,
                    onTapRecording: { path.append($0) }
                )
            }
        }
    }
```

Leave `emptyState`, `init`, `body`'s outer structure, `navigationDestination`, and the `.onChange` handler unchanged.

- [ ] **Step 1b: Remove the now-dead `DayGroup` / `groupedDays`**

Nothing references them anymore (the old `daySection` is gone, and `MoodDaySection.swift` was deleted in Task 0). In `app-two/ViewModels/MoodLibraryViewModel.swift`, delete the `DayGroup` struct and the entire `groupedDays` computed property. Build to confirm no references remain:

Run: `xcodebuild build -scheme app-two -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Build and run on the simulator**

Run: `xcodebuild build -scheme app-two -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`.

Then launch the app (use the `run` or `ios-debugger-agent` skill / XcodeBuildMCP) on a booted simulator, open the **Calendar** tab, and confirm: days render as a vertical timeline; a mood-only entry shows a solid coloured bead; a logged dose shows a hollow bead with a ring; a check-in during an active dose shows the ring overlaid; the connector line links beads.

- [ ] **Step 3: Commit**

```bash
git add app-two/Views/Library/CalendarLibraryView.swift
git commit -m "feat(calendar): render the day timeline in CalendarLibraryView

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: Full verification + self-review

**Files:** none (verification only).

- [ ] **Step 1: Run the full new test suites together**

Run: `xcodebuild test -scheme app-two -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:app-twoTests/DayTimelineBuilderTests -only-testing:app-twoTests/MoodLibraryViewModelTests 2>&1 | tail -30`
Expected: all 12 tests PASS.

- [ ] **Step 2: Confirm no regression in the existing medication tests**

Run: `xcodebuild test -scheme app-two -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:app-twoTests/MedicationBarViewModelTests 2>&1 | tail -20`
Expected: PASS (these were green before; they must stay green). Note: the 11 pre-existing failing NLP mood tests and 3 disabled VM suites are unrelated and out of scope.

- [ ] **Step 3: Self-review against the locked decisions**

Re-read the "Design decisions locked with the user" list and confirm each is implemented:
1. Real progress via `effectProgress(at:)` — yes (Task 1 `activeRings`).
2. Live merge vs back-date split — yes (Task 1 instant-grouping; tests cover both).
3. Manual doses appear — yes (Task 2 fetch + `timelineDays`; test `manualDoseWithoutRecordingStillProducesADay`).
4. Neutral gray nodes for moodless notes — yes (`moodColor` returns gray for nil; recording node always filled).
5. Active doses only, max 3, oldest-outermost — yes (Task 1 `activeRings`; tests `ringsCapAtThreeMostRecentActiveDoses`, `ringsAreOrderedOldestOutermost`, `expiredDoseDropsOffLaterNodes`).
6. Flat purple rings + truncated %, vanish at 100% — yes (Task 3 `ringArc`/`innerLabel` use `Palette.medication` + `Int(progress*100)`; Task 1 `activeRings` excludes `instant >= end`).
7. Playground deleted, dead code removed — yes (Task 0 + Task 5 Step 1b).

- [ ] **Step 4: Optional polish pass**

If in-bead density looks cramped at large Dynamic Type sizes, run the `impeccable` skill on `TimelineBead` (candidate refinement: move percentages from inside the bead to small colour chips in `TimelineRow`'s content). This is a presentation refinement only — the builder/VM logic is unaffected.

---

## Self-Review (author checklist — completed at write time)

- **Spec coverage:** Each of the 5 locked decisions maps to a task (see Task 6 Step 3). The two screenshot node types (mood-filled, med-hollow) and the combined node are all produced by `DayTimelineBuilder` and rendered by `TimelineBead`/`TimelineRow`.
- **Placeholder scan:** No TBD/TODO/"handle edge cases" — every step has concrete code or an exact command.
- **Type consistency:** `DayTimeline.Node` / `DayTimeline.Ring` / `DayTimelineBuilder.build(recordings:doses:)` / `MoodLibraryViewModel.TimelineDay` / `timelineDays` / `TimelineBead(node:)` / `TimelineRow(node:isLast:onTapRecording:)` are used identically across Tasks 1–5. `Ring.doseID`/`progress`, `Node.recording`/`intakeDoses`/`rings`/`time` consistent throughout.
- **Known caveats baked in:** exact-timestamp grouping is what makes the live-merge vs back-date split work (driven by `MedicationEvent.resolvedTakenAt` returning the recording date exactly in the no-spoken-time case); `now` is intentionally not used because past-node ring progress is historical and fixed.
