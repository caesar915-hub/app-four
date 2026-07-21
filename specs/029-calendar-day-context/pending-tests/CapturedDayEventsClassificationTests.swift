import Testing
@testable import app_four

// Reference date: 2026-01-05 (Monday) — chosen for unambiguity; all times UTC/device-local.
// dayKey for Jan 5 = Calendar.current.startOfDay(for: jan5_noon)
private let jan5_noon  = Date(timeIntervalSince1970: 1_767_585_600) // 2026-01-05 12:00:00 UTC
private let jan6_noon  = Date(timeIntervalSince1970: 1_767_672_000) // 2026-01-06 12:00:00 UTC
private let jan5_day   = DayKey.make(for: jan5_noon)
private let jan6_day   = DayKey.make(for: jan6_noon)

// MARK: - Helpers

private func makeRaw(
    title: String? = "Event",
    start: Date,
    end: Date,
    isAllDay: Bool = false,
    attendeeCount: Int = 0,
    availability: String = "busy",
    eventIdentifier: String = "id-\(UUID())",
    occurrenceDate: Date? = nil,
    currentUserDeclined: Bool = false
) -> RawCalendarEvent {
    RawCalendarEvent(
        title: title,
        start: start,
        end: end,
        isAllDay: isAllDay,
        attendeeCount: attendeeCount,
        availability: availability,
        eventIdentifier: eventIdentifier,
        occurrenceDate: occurrenceDate,
        currentUserDeclined: currentUserDeclined
    )
}

// Jan 5 start-of-day and end-of-day (next midnight) for building events
private var jan5Start: Date { jan5_day }
private var jan5End: Date   { Calendar.current.date(byAdding: .day, value: 1, to: jan5_day)! }
private var jan6Start: Date { jan6_day }
private var jan6End: Date   { Calendar.current.date(byAdding: .day, value: 1, to: jan6_day)! }
private var jan7Start: Date { Calendar.current.date(byAdding: .day, value: 2, to: jan6_day)! }
private var jan7End: Date   { Calendar.current.date(byAdding: .day, value: 3, to: jan6_day)! }

// MARK: - Tests

struct CapturedDayEventsClassificationTests {

    // MARK: Timed <24h event — start-day only

    @Test func timedEventOnStartDayNotNextDay() {
        // 1-hour meeting starting Jan 5 at noon
        let event = makeRaw(
            start: jan5_noon,
            end: jan5_noon.addingTimeInterval(3_600)
        )
        let jan5Result = CalendarCaptureLogic.capturedDay(for: jan5_day, from: [event], includeTitles: true)
        let jan6Result = CalendarCaptureLogic.capturedDay(for: jan6_day, from: [event], includeTitles: true)
        #expect(jan5Result.events.count == 1)
        #expect(jan6Result.events.count == 0)
    }

    // MARK: All-day event on its day

    @Test func allDayEventOnItsDay() {
        // All-day event on Jan 5: EventKit sets end = Jan 6 midnight (half-open)
        let event = makeRaw(
            start: jan5Start,
            end: jan5End,
            isAllDay: true
        )
        let jan5Result = CalendarCaptureLogic.capturedDay(for: jan5_day, from: [event], includeTitles: true)
        #expect(jan5Result.events.count == 1)
        #expect(jan5Result.events[0].isAllDay == true)
    }

    // MARK: ≥24h multi-day event spans all covered days

    @Test func multiDayEventAppearsOnFirstMiddleAndLastDay() {
        // Event spans Jan 5 (start) through Jan 7 (end = Jan 8 midnight, 3 days)
        let jan8Start = Calendar.current.date(byAdding: .day, value: 3, to: jan6_day)!
        let event = makeRaw(
            start: jan5Start,
            end: jan8Start,    // half-open: Jan 5, 6, 7 covered
            isAllDay: false
        )
        let jan7_day = DayKey.make(for: jan7Start)
        let jan5Result = CalendarCaptureLogic.capturedDay(for: jan5_day, from: [event], includeTitles: true)
        let jan6Result = CalendarCaptureLogic.capturedDay(for: jan6_day, from: [event], includeTitles: true)
        let jan7Result = CalendarCaptureLogic.capturedDay(for: jan7_day, from: [event], includeTitles: true)
        #expect(jan5Result.events.count == 1)
        #expect(jan6Result.events.count == 1)
        #expect(jan7Result.events.count == 1)
    }

    // MARK: Recurring occurrence dedupe

    @Test func recurringOccurrencesWithDifferentOccurrenceDatesToSurvive() {
        // Same eventIdentifier, different occurrenceDates → both survive
        let occ1 = makeRaw(
            start: jan5_noon,
            end: jan5_noon.addingTimeInterval(3_600),
            eventIdentifier: "recurring-id",
            occurrenceDate: jan5_noon
        )
        let occ2 = makeRaw(
            start: jan6_noon,
            end: jan6_noon.addingTimeInterval(3_600),
            eventIdentifier: "recurring-id",
            occurrenceDate: jan6_noon
        )
        // Test on a week view (both days combined in input)
        let jan5Result = CalendarCaptureLogic.capturedDay(for: jan5_day, from: [occ1, occ2], includeTitles: true)
        let jan6Result = CalendarCaptureLogic.capturedDay(for: jan6_day, from: [occ1, occ2], includeTitles: true)
        #expect(jan5Result.events.count == 1)
        #expect(jan6Result.events.count == 1)
    }

    @Test func trueDuplicateCollapsesToOne() {
        // Same eventIdentifier + same occurrenceDate → duplicate; keep first
        let dup1 = makeRaw(
            start: jan5_noon,
            end: jan5_noon.addingTimeInterval(3_600),
            eventIdentifier: "dup-id",
            occurrenceDate: jan5_noon
        )
        let dup2 = makeRaw(
            title: "OTHER TITLE",  // different title to verify first is kept
            start: jan5_noon,
            end: jan5_noon.addingTimeInterval(3_600),
            eventIdentifier: "dup-id",
            occurrenceDate: jan5_noon
        )
        let result = CalendarCaptureLogic.capturedDay(for: jan5_day, from: [dup1, dup2], includeTitles: true)
        #expect(result.events.count == 1)
        #expect(result.events[0].title == "Event")  // first one kept
    }

    // MARK: Declined event removed (FR-008)

    @Test func declinedEventRemoved() {
        let declined = makeRaw(
            start: jan5_noon,
            end: jan5_noon.addingTimeInterval(3_600),
            currentUserDeclined: true
        )
        let accepted = makeRaw(
            title: "Accepted",
            start: jan5_noon.addingTimeInterval(7_200),
            end: jan5_noon.addingTimeInterval(10_800)
        )
        let result = CalendarCaptureLogic.capturedDay(for: jan5_day, from: [declined, accepted], includeTitles: true)
        #expect(result.events.count == 1)
        #expect(result.events[0].title == "Accepted")
    }

    // MARK: includeTitles: false → all titles nil, attendeeCount/availability intact

    @Test func titlesOffProducesNilTitlesButPreservesOtherFields() {
        let e1 = makeRaw(
            title: "Secret Meeting",
            start: jan5_noon,
            end: jan5_noon.addingTimeInterval(3_600),
            attendeeCount: 3,
            availability: "busy"
        )
        let e2 = makeRaw(
            title: "Another Event",
            start: jan5_noon.addingTimeInterval(7_200),
            end: jan5_noon.addingTimeInterval(10_800),
            attendeeCount: 0,
            availability: "free"
        )
        let result = CalendarCaptureLogic.capturedDay(for: jan5_day, from: [e1, e2], includeTitles: false)
        #expect(result.events.count == 2)
        #expect(result.events.allSatisfy { $0.title == nil })
        #expect(result.events[0].attendeeCount == 3)
        #expect(result.events[0].availability == "busy")
        #expect(result.events[1].attendeeCount == 0)
        #expect(result.events[1].availability == "free")
    }

    // MARK: Output sorted by start ascending

    @Test func outputSortedByStartAscending() {
        let e1 = makeRaw(
            title: "Late",
            start: jan5_noon.addingTimeInterval(7_200),
            end: jan5_noon.addingTimeInterval(10_800)
        )
        let e2 = makeRaw(
            title: "Early",
            start: jan5_noon,
            end: jan5_noon.addingTimeInterval(3_600)
        )
        let result = CalendarCaptureLogic.capturedDay(for: jan5_day, from: [e1, e2], includeTitles: true)
        #expect(result.events.count == 2)
        #expect(result.events[0].title == "Early")
        #expect(result.events[1].title == "Late")
        #expect(result.events[0].start < result.events[1].start)
    }
}
