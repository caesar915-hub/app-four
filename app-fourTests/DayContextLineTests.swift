import Testing
@testable import app_four

struct DayContextLineTests {

    // MARK: - Helpers

    private func event(
        title: String? = nil,
        attendeeCount: Int = 0,
        offsetSeconds: TimeInterval = 0
    ) -> CapturedEvent {
        CapturedEvent(
            title: title,
            start: Date(timeIntervalSince1970: 1_000_000 + offsetSeconds),
            end: Date(timeIntervalSince1970: 1_000_000 + offsetSeconds + 3600),
            isAllDay: false,
            attendeeCount: attendeeCount,
            availability: "busy"
        )
    }

    private func payload(_ events: [CapturedEvent]) -> CapturedDayEvents {
        CapturedDayEvents(events: events)
    }

    // MARK: - FR-005 empty → nil

    @Test func emptyEventsReturnsNil() {
        #expect(DayContextLine.text(for: payload([])) == nil)
    }

    // MARK: - Meetings-only

    @Test func singularMeetingLabel() {
        let result = DayContextLine.text(for: payload([event(title: "Standup", attendeeCount: 1)]))
        #expect(result == "1 meeting")
    }

    @Test func pluralMeetingsOnly() {
        let events = [
            event(title: "Standup", attendeeCount: 3),
            event(title: "Review", attendeeCount: 2, offsetSeconds: 3600),
        ]
        let result = DayContextLine.text(for: payload(events))
        #expect(result == "2 meetings")
    }

    @Test func sixMeetingsHeavyOfficeDay() {
        let events = (0..<6).map { i in
            event(title: "Meeting \(i)", attendeeCount: 5, offsetSeconds: TimeInterval(i * 3600))
        }
        let result = DayContextLine.text(for: payload(events))
        #expect(result == "6 meetings")
    }

    // MARK: - Named non-meetings only (no meetings)

    @Test func singleNamedEventNoMeetings() {
        let result = DayContextLine.text(for: payload([event(title: "Therapy", attendeeCount: 0)]))
        #expect(result == "Therapy")
    }

    @Test func multipleNamedEventsInDayOrder() {
        // Events arrive sorted by start; assert titles are emitted in that order
        let events = [
            event(title: "Dentist", attendeeCount: 0, offsetSeconds: 0),
            event(title: "Mum's birthday", attendeeCount: 0, offsetSeconds: 7200),
        ]
        let result = DayContextLine.text(for: payload(events))
        #expect(result == "Dentist · Mum's birthday")
    }

    // MARK: - Mixed: meetings + named events

    @Test func meetingsPlusNamedEvents() {
        // Variant B primary example: "3 meetings · Dentist · Mum's birthday"
        let events = [
            event(title: "Standup", attendeeCount: 4, offsetSeconds: 0),
            event(title: "Review", attendeeCount: 2, offsetSeconds: 3600),
            event(title: "Sync", attendeeCount: 1, offsetSeconds: 7200),
            event(title: "Dentist", attendeeCount: 0, offsetSeconds: 10_800),
            event(title: "Mum's birthday", attendeeCount: 0, offsetSeconds: 14_400),
        ]
        let result = DayContextLine.text(for: payload(events))
        #expect(result == "3 meetings · Dentist · Mum's birthday")
    }

    @Test func twoMeetingsPlusOneNamed() {
        // Variant B side-table: "2 meetings · Dentist · Lisbon trip"
        let events = [
            event(title: "Standup", attendeeCount: 3, offsetSeconds: 0),
            event(title: "Sync", attendeeCount: 2, offsetSeconds: 3600),
            event(title: "Dentist", attendeeCount: 0, offsetSeconds: 7200),
            event(title: "Lisbon trip", attendeeCount: 0, offsetSeconds: 10_800),
        ]
        let result = DayContextLine.text(for: payload(events))
        #expect(result == "2 meetings · Dentist · Lisbon trip")
    }

    // MARK: - FR-007 titles-off (all titles nil)

    @Test func titlesOffMeetingsAndEvents() {
        // "3 meetings · 2 events"
        let events = [
            event(title: nil, attendeeCount: 2, offsetSeconds: 0),
            event(title: nil, attendeeCount: 3, offsetSeconds: 3600),
            event(title: nil, attendeeCount: 1, offsetSeconds: 7200),
            event(title: nil, attendeeCount: 0, offsetSeconds: 10_800),
            event(title: nil, attendeeCount: 0, offsetSeconds: 14_400),
        ]
        let result = DayContextLine.text(for: payload(events))
        #expect(result == "3 meetings · 2 events")
    }

    @Test func titlesOffMeetingsOnlyNoNonMeetings() {
        let events = [
            event(title: nil, attendeeCount: 5, offsetSeconds: 0),
            event(title: nil, attendeeCount: 2, offsetSeconds: 3600),
        ]
        let result = DayContextLine.text(for: payload(events))
        #expect(result == "2 meetings")
    }

    @Test func titlesOffNonMeetingsOnlyEventsCount() {
        let events = [
            event(title: nil, attendeeCount: 0, offsetSeconds: 0),
            event(title: nil, attendeeCount: 0, offsetSeconds: 3600),
            event(title: nil, attendeeCount: 0, offsetSeconds: 7200),
        ]
        let result = DayContextLine.text(for: payload(events))
        #expect(result == "3 events")
    }

    @Test func titlesOffSingularEventLabel() {
        let result = DayContextLine.text(for: payload([event(title: nil, attendeeCount: 0)]))
        #expect(result == "1 event")
    }

    // MARK: - Variant B truncation: compose the full string, view clips it
    // No "+N more" in variant B — the string is always the full set of titles;
    // SwiftUI's .lineLimit(1) + .truncationMode(.tail) handles visual overflow.

    @Test func manyNamedEventsProducesFullString() {
        let titles = ["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta"]
        let events = titles.enumerated().map { i, t in
            event(title: t, attendeeCount: 0, offsetSeconds: TimeInterval(i * 3600))
        }
        let result = DayContextLine.text(for: payload(events))
        let expected = titles.joined(separator: " · ")
        #expect(result == expected)
    }

    // MARK: - Non-meetings with nil titles are excluded from named-event list

    @Test func nonMeetingWithNilTitleExcludedWhenOtherTitlesPresent() {
        // One named event + one untitled non-meeting: only the named one appears
        let events = [
            event(title: "Dentist", attendeeCount: 0, offsetSeconds: 0),
            event(title: nil, attendeeCount: 0, offsetSeconds: 3600),
        ]
        let result = DayContextLine.text(for: payload(events))
        // titlesOff = false (Dentist has a title), so we list named non-meetings
        #expect(result == "Dentist")
    }
}
