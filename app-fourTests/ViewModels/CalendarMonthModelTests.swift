import Foundation
import Testing
import SwiftUI
@testable import app_four

@MainActor
struct CalendarMonthModelTests {

    /// Fixed UTC Gregorian calendar so grid math is run-date-independent.
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
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
        #expect(c8?.marker == DayMarker.none)   // explicit: bare `.none` would bind to Optional.none
    }
}
