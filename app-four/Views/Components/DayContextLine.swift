import Foundation

/// Pure string formatter for the classified calendar-context line on a DayCard (spec 029 / FR-005–007).
///
/// Variant B composition rules (approved mockup):
///   • meetings (attendeeCount > 0) collapse to a count: "1 meeting" / "N meetings"
///   • named non-meetings (attendeeCount == 0 AND title != nil) list titles in day order
///   • parts joined by " · " (MIDDLE DOT with spaces)
///   • titles-off (all titles nil): "N meetings · M events" counts-only (FR-007)
///   • zero events → nil (FR-005 — nothing renders)
///   • truncation is a view concern: compose the full string; the view clips with .lineLimit(1)
enum DayContextLine {

    private static let separator = " · "

    static func text(for events: CapturedDayEvents) -> String? {
        let all = events.events
        guard !all.isEmpty else { return nil }

        let meetings = all.filter { $0.attendeeCount > 0 }
        let nonMeetings = all.filter { $0.attendeeCount == 0 }

        let titlesOff = all.allSatisfy { $0.title == nil }

        if titlesOff {
            return titleOffText(meetingCount: meetings.count, nonMeetingCount: nonMeetings.count)
        }

        return titlesOnText(meetings: meetings, nonMeetings: nonMeetings)
    }

    // MARK: - Private helpers

    private static func titleOffText(meetingCount: Int, nonMeetingCount: Int) -> String? {
        var parts: [String] = []
        if meetingCount > 0 {
            parts.append(meetingLabel(meetingCount))
        }
        if nonMeetingCount > 0 {
            parts.append(eventLabel(nonMeetingCount))
        }
        return parts.isEmpty ? nil : parts.joined(separator: separator)
    }

    private static func titlesOnText(meetings: [CapturedEvent], nonMeetings: [CapturedEvent]) -> String? {
        var parts: [String] = []
        if !meetings.isEmpty {
            parts.append(meetingLabel(meetings.count))
        }
        let namedTitles = nonMeetings.compactMap { $0.title }
        parts.append(contentsOf: namedTitles)
        return parts.isEmpty ? nil : parts.joined(separator: separator)
    }

    private static func meetingLabel(_ n: Int) -> String {
        n == 1 ? "1 meeting" : "\(n) meetings"
    }

    private static func eventLabel(_ n: Int) -> String {
        n == 1 ? "1 event" : "\(n) events"
    }
}
