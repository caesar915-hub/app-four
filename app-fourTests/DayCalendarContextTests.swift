import Testing
@testable import app_four

struct DayCalendarContextTests {

    // MARK: - CapturedEvent Codable round-trip

    @Test func capturedEventRoundTrip() throws {
        let event = CapturedEvent(
            title: "Team Sync",
            start: Date(timeIntervalSince1970: 1_000_000),
            end: Date(timeIntervalSince1970: 1_003_600),
            isAllDay: false,
            attendeeCount: 4,
            availability: "busy"
        )
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(CapturedEvent.self, from: data)
        #expect(decoded == event)
    }

    @Test func capturedEventNilTitle() throws {
        let event = CapturedEvent(
            title: nil,
            start: Date(timeIntervalSince1970: 1_000_000),
            end: Date(timeIntervalSince1970: 1_003_600),
            isAllDay: false,
            attendeeCount: 0,
            availability: "free"
        )
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(CapturedEvent.self, from: data)
        #expect(decoded.title == nil)
        #expect(decoded == event)
    }

    @Test func capturedEventAvailabilityStrings() throws {
        let availabilities = ["busy", "free", "tentative", "unavailable", "notSupported"]
        for avail in availabilities {
            let event = CapturedEvent(
                title: nil,
                start: Date(timeIntervalSince1970: 0),
                end: Date(timeIntervalSince1970: 3600),
                isAllDay: false,
                attendeeCount: 0,
                availability: avail
            )
            let data = try JSONEncoder().encode(event)
            let decoded = try JSONDecoder().decode(CapturedEvent.self, from: data)
            #expect(decoded.availability == avail)
        }
    }

    // MARK: - CapturedDayEvents Codable round-trip

    @Test func capturedDayEventsSchemaVersionDefault() {
        let payload = CapturedDayEvents(events: [])
        #expect(payload.schemaVersion == 1)
    }

    @Test func capturedDayEventsRoundTrip() throws {
        let payload = CapturedDayEvents(events: [
            CapturedEvent(
                title: "Doctor",
                start: Date(timeIntervalSince1970: 2_000_000),
                end: Date(timeIntervalSince1970: 2_003_600),
                isAllDay: false,
                attendeeCount: 1,
                availability: "tentative"
            ),
            CapturedEvent(
                title: nil,
                start: Date(timeIntervalSince1970: 2_100_000),
                end: Date(timeIntervalSince1970: 2_103_600),
                isAllDay: true,
                attendeeCount: 0,
                availability: "notSupported"
            )
        ])
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(CapturedDayEvents.self, from: data)
        #expect(decoded == payload)
        #expect(decoded.schemaVersion == 1)
    }

    // MARK: - DayCalendarContext defaulted attributes

    @Test func defaultedAttributeConstruction() {
        let ctx = DayCalendarContext()
        #expect(ctx.dayKey == .distantPast)
        #expect(ctx.eventsJSON == nil)
        #expect(ctx.capturedAt == .distantPast)
        #expect(ctx.titlesIncluded == true)
        #expect(ctx.isMockData == false)
    }

    // MARK: - DayKey

    @Test func dayKeyReturnsStartOfDay() {
        let now = Date()
        let result = DayKey.make(for: now)
        #expect(result == Calendar.current.startOfDay(for: now))
    }

    @Test func dayKeyIsIdempotent() {
        let start = Calendar.current.startOfDay(for: Date())
        #expect(DayKey.make(for: start) == start)
    }

    // MARK: - JSON convenience (encodeEvents / decodedEvents)

    @Test func jsonConvenienceRoundTrip() {
        let ctx = DayCalendarContext()
        let payload = CapturedDayEvents(events: [
            CapturedEvent(
                title: "Standup",
                start: Date(timeIntervalSince1970: 500_000),
                end: Date(timeIntervalSince1970: 501_800),
                isAllDay: false,
                attendeeCount: 5,
                availability: "busy"
            )
        ])
        ctx.encodeEvents(payload)
        #expect(ctx.eventsJSON != nil)
        #expect(ctx.decodedEvents == payload)
    }

    @Test func decodedEventsNilWhenJSONIsNil() {
        let ctx = DayCalendarContext()
        #expect(ctx.eventsJSON == nil)
        #expect(ctx.decodedEvents == nil)
    }
}
