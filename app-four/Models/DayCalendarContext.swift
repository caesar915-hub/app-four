import Foundation
import SwiftData

@Model
final class DayCalendarContext {
    var id: UUID = UUID()
    var dayKey: Date = Date.distantPast
    var eventsJSON: String? = nil
    var capturedAt: Date = Date.distantPast
    var titlesIncluded: Bool = true
    var isMockData: Bool = false

    init(
        id: UUID = UUID(),
        dayKey: Date = .distantPast,
        eventsJSON: String? = nil,
        capturedAt: Date = .distantPast,
        titlesIncluded: Bool = true,
        isMockData: Bool = false
    ) {
        self.id = id
        self.dayKey = dayKey
        self.eventsJSON = eventsJSON
        self.capturedAt = capturedAt
        self.titlesIncluded = titlesIncluded
        self.isMockData = isMockData
    }
}

nonisolated struct CapturedDayEvents: Codable, Sendable, Equatable {
    var schemaVersion: Int = 1
    var events: [CapturedEvent]
}

nonisolated struct CapturedEvent: Codable, Sendable, Equatable {
    var title: String?
    var start: Date
    var end: Date
    var isAllDay: Bool
    var attendeeCount: Int
    var availability: String
}

/// Pure, stateless day-normalization — consumed from MainActor views AND two plain
/// actors (the coordinator, the EventKit service), so it must not inherit the
/// module's default `@MainActor` isolation.
nonisolated enum DayKey {
    static func make(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
}

extension DayCalendarContext {
    var decodedEvents: CapturedDayEvents? {
        guard let json = eventsJSON,
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(CapturedDayEvents.self, from: data)
    }

    func encodeEvents(_ payload: CapturedDayEvents) {
        guard let data = try? JSONEncoder().encode(payload),
              let json = String(data: data, encoding: .utf8) else { return }
        eventsJSON = json
    }
}
