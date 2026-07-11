import EventKit
import Foundation

// MARK: - RawCalendarEvent

/// Intermediate value type the EventKit layer (T016) maps EKEvents into.
/// No EventKit types cross this boundary — pure value semantics.
nonisolated struct RawCalendarEvent: Sendable, Equatable {
    var title: String?
    var start: Date
    var end: Date
    var isAllDay: Bool
    var attendeeCount: Int
    var availability: String
    var eventIdentifier: String
    var occurrenceDate: Date?   // recurring dedupe; nil for non-recurring
    var currentUserDeclined: Bool
}

// MARK: - CalendarCaptureLogic

/// Pure capture pipeline — called from the EventKit service actor; must not inherit
/// the module's default `@MainActor` isolation.
nonisolated enum CalendarCaptureLogic {

    // MARK: Declined filter (FR-008)

    static func filterDeclined(_ events: [RawCalendarEvent]) -> [RawCalendarEvent] {
        events.filter { !$0.currentUserDeclined }
    }

    // MARK: Occurrence dedupe

    /// Unique by (eventIdentifier, occurrenceDate ?? start). Keeps the first occurrence
    /// encountered for each key, matching EventKit's predicate-order stability.
    static func deduplicateOccurrences(_ events: [RawCalendarEvent]) -> [RawCalendarEvent] {
        var seen = Set<OccurrenceKey>()
        return events.filter { event in
            let key = OccurrenceKey(id: event.eventIdentifier, occurrence: event.occurrenceDate ?? event.start)
            return seen.insert(key).inserted
        }
    }

    private struct OccurrenceKey: Hashable {
        let id: String
        let occurrence: Date
    }

    // MARK: Day attribution

    /// Returns true if `event` belongs to `dayKey` (a startOfDay Date).
    ///
    /// Timed event (not all-day AND duration < 24h): attributed to its start day only.
    /// All-day OR ≥24h event: attributed to every day whose window intersects [start, end).
    ///
    /// Half-open [start, end): EventKit multi-day all-day events set `end` to midnight of
    /// the first *excluded* day (e.g. a 3-day event Mon–Wed has end = Thu 00:00), so
    /// `end` is excluded to avoid attributing the event to a day it doesn't cover.
    static func isAttributed(_ event: RawCalendarEvent, to dayKey: Date) -> Bool {
        let duration = event.end.timeIntervalSince(event.start)
        let isTimed = !event.isAllDay && duration < 86_400
        if isTimed {
            return DayKey.make(for: event.start) == dayKey
        }
        let cal = Calendar.current
        let dayStart = dayKey
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return false }
        return event.start < dayEnd && event.end > dayStart
    }

    // MARK: Map to CapturedEvent

    static func mapEvent(_ raw: RawCalendarEvent, includeTitles: Bool) -> CapturedEvent {
        CapturedEvent(
            title: includeTitles ? raw.title : nil,
            start: raw.start,
            end: raw.end,
            isAllDay: raw.isAllDay,
            attendeeCount: raw.attendeeCount,
            availability: raw.availability
        )
    }

    // MARK: Top-level compose

    /// filter declined → dedupe occurrences → keep events attributed to dayKey
    /// → sort by start ascending → map to CapturedEvent → CapturedDayEvents
    static func capturedDay(
        for dayKey: Date,
        from raw: [RawCalendarEvent],
        includeTitles: Bool
    ) -> CapturedDayEvents {
        let events = deduplicateOccurrences(filterDeclined(raw))
            .filter { isAttributed($0, to: dayKey) }
            .sorted { $0.start < $1.start }
            .map { mapEvent($0, includeTitles: includeTitles) }
        return CapturedDayEvents(events: events)
    }
}

// MARK: - CalendarContextServiceImpl

/// The app's only EventKit touchpoint.
///
/// `EKEventStore` is not Sendable and Apple documents it as a long-lived, off-main-thread
/// singleton. Confining it to this actor satisfies both constraints: one instance lives for
/// the actor's lifetime and all access is serialized on the actor's executor (off-main).
/// No `EKEvent` or `EKCalendar` ever escapes — only value types cross the actor boundary.
actor CalendarContextServiceImpl: CalendarContextService {

    // Long-lived, actor-confined. Never let a reference escape the actor.
    private let store = EKEventStore()

    init() {}

    // MARK: CalendarContextService

    func accessState() async -> CalendarAccessState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:   return .notDetermined
        case .restricted:      return .restricted
        case .denied:          return .denied
        case .fullAccess:      return .fullAccess
        case .writeOnly:       return .writeOnly
        @unknown default:      return .denied
        }
    }

    func requestFullAccess() async -> CalendarAccessState {
        _ = try? await store.requestFullAccessToEvents()
        return await accessState()
    }

    func availableCalendars() async -> [CalendarDescriptor] {
        store.calendars(for: .event).map { cal in
            CalendarDescriptor(
                id: cal.calendarIdentifier,
                title: cal.title,
                isBirthdayClass: cal.type == .birthday || cal.source.sourceType == .birthdays,
                isSubscribedClass: cal.type == .subscription || cal.isSubscribed
            )
        }
    }

    func captureDay(
        _ dayKey: Date,
        includeTitles: Bool,
        includedCalendarIDs: [String]
    ) async -> CapturedDayEvents? {
        guard await accessState() == .fullAccess else { return nil }

        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: dayKey)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return nil }

        let includedCalendars = store.calendars(for: .event)
            .filter { includedCalendarIDs.contains($0.calendarIdentifier) }

        // 0 included calendars means the user has excluded everything — return empty, not nil.
        // nil is reserved for "access unavailable"; the coordinator distinguishes the two cases.
        guard !includedCalendars.isEmpty else { return CapturedDayEvents(events: []) }

        let predicate = store.predicateForEvents(
            withStart: dayStart,
            end: dayEnd,
            calendars: includedCalendars
        )
        let ekEvents = store.events(matching: predicate)

        let rawEvents: [RawCalendarEvent] = ekEvents.map { event in
            let availabilityString: String
            switch event.availability {
            case .busy:         availabilityString = "busy"
            case .free:         availabilityString = "free"
            case .tentative:    availabilityString = "tentative"
            case .unavailable:  availabilityString = "unavailable"
            case .notSupported: availabilityString = "notSupported"
            @unknown default:   availabilityString = "notSupported"
            }

            // occurrenceDate is the date this occurrence was originally scheduled — the
            // only thing distinguishing two occurrences of the same recurring event
            // (which share one eventIdentifier). The dedupe key falls back to `start`
            // when it is nil (non-recurring events, where identifier alone suffices).
            return RawCalendarEvent(
                title: event.title,
                start: event.startDate,
                end: event.endDate,
                isAllDay: event.isAllDay,
                attendeeCount: event.attendees?.count ?? 0,
                availability: availabilityString,
                eventIdentifier: event.eventIdentifier ?? "",
                occurrenceDate: event.occurrenceDate,
                currentUserDeclined: event.attendees?
                    .first(where: { $0.isCurrentUser })?
                    .participantStatus == .declined
            )
        }

        return CalendarCaptureLogic.capturedDay(
            for: dayStart,
            from: rawEvents,
            includeTitles: includeTitles
        )
    }
}
