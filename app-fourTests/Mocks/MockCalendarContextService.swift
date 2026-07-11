import Foundation
@testable import app_four

actor MockCalendarContextService: CalendarContextService {
    var stubAccessState: CalendarAccessState = .notDetermined
    var stubRequestFullAccessResult: CalendarAccessState = .fullAccess
    var updateAccessStateOnRequest = true
    var stubCalendars: [CalendarDescriptor] = []
    var stubCaptureResults: [Date: CapturedDayEvents] = [:]

    var requestFullAccessCalled = false
    var requestFullAccessCallCount = 0

    /// Hook fired inside `captureDay` before it returns — lets a test interleave a
    /// delete during an in-flight capture to exercise actor-reentrancy safety.
    private var onCaptureDay: (@Sendable (Date) async -> Void)?

    private var captureCalls: [(dayKey: Date, includeTitles: Bool, includedCalendarIDs: [String])] = []

    func setStubAccessState(_ state: CalendarAccessState) { stubAccessState = state }
    func setStubRequestFullAccessResult(_ state: CalendarAccessState) { stubRequestFullAccessResult = state }
    func setStubCalendars(_ calendars: [CalendarDescriptor]) { stubCalendars = calendars }
    func setStubCaptureResult(_ result: CapturedDayEvents?, for dayKey: Date) { stubCaptureResults[dayKey] = result }
    func setOnCaptureDay(_ hook: (@Sendable (Date) async -> Void)?) { onCaptureDay = hook }

    func recordedCaptureCalls() -> [(dayKey: Date, includeTitles: Bool, includedCalendarIDs: [String])] {
        captureCalls
    }

    func accessState() async -> CalendarAccessState {
        stubAccessState
    }

    func requestFullAccess() async -> CalendarAccessState {
        requestFullAccessCalled = true
        requestFullAccessCallCount += 1
        if updateAccessStateOnRequest { stubAccessState = stubRequestFullAccessResult }
        return stubRequestFullAccessResult
    }

    func availableCalendars() async -> [CalendarDescriptor] {
        stubCalendars
    }

    func captureDay(_ dayKey: Date, includeTitles: Bool, includedCalendarIDs: [String]) async -> CapturedDayEvents? {
        captureCalls.append((dayKey: dayKey, includeTitles: includeTitles, includedCalendarIDs: includedCalendarIDs))
        await onCaptureDay?(dayKey)
        return stubCaptureResults[dayKey]
    }
}
