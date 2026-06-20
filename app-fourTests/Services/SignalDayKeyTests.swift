import Testing
import Foundation
@testable import app_four

struct SignalDayKeyTests {
    @Test func dayStartZeroesTimeComponents() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let instant = cal.date(from: DateComponents(year: 2026, month: 6, day: 13, hour: 15, minute: 30))!

        let start = SignalDayKey.dayStart(for: instant, calendar: cal)
        let back = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: start)

        #expect(back.year == 2026)
        #expect(back.month == 6)
        #expect(back.day == 13)
        #expect(back.hour == 0)
        #expect(back.minute == 0)
        #expect(back.second == 0)
    }

    @Test func sameDayDifferentTimesProduceSameKey() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let morning = cal.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 1))!
        let night = cal.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 23))!

        #expect(SignalDayKey.dayStart(for: morning, calendar: cal)
                == SignalDayKey.dayStart(for: night, calendar: cal))
    }

    @Test func differentDaysProduceDifferentKeys() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let day1 = cal.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 12))!
        let day2 = cal.date(from: DateComponents(year: 2026, month: 1, day: 3, hour: 12))!

        #expect(SignalDayKey.dayStart(for: day1, calendar: cal)
                != SignalDayKey.dayStart(for: day2, calendar: cal))
    }
}
