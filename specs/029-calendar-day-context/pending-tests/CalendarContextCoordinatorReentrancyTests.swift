import Testing
import Foundation
import SwiftData
@testable import app_four

/// Actor-reentrancy + FR-014 access-gate coverage for the coordinator (spec 029).
/// Added with the 2026-07-11 review fixes: the existing CalendarContextCoordinatorTests
/// exercise only sequential invocation, so neither the capture-vs-delete interleaving
/// (critical) nor the "delete needs no calendar access" rule (FR-014) was covered.
@MainActor
struct CalendarContextCoordinatorReentrancyTests {

    /// Mutable, Sendable check-in set the provider reads and a mid-capture hook mutates —
    /// models a check-in deleted while a capture is in flight.
    private actor DaySet {
        private(set) var days: Set<Date>
        init(_ d: Set<Date>) { days = Set(d.map { DayKey.make(for: $0) }) }
        func snapshot() -> Set<Date> { days }
        func remove(_ d: Date) { days.remove(DayKey.make(for: d)) }
    }

    private let day = DayKey.make(for: Date(timeIntervalSince1970: 1_750_000_000))
    private func payload() -> CapturedDayEvents { CapturedDayEvents(events: []) }

    private func makeStore() throws -> DayContextStore {
        TestSupport.useRealData()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DayCalendarContext.self, configurations: config)
        return DayContextStore(context: container.mainContext)
    }

    private func makeCoordinator(store: DayContextStore, service: MockCalendarContextService, daySet: DaySet) -> CalendarContextCoordinatorImpl {
        CalendarContextCoordinatorImpl(
            service: service,
            store: store,
            settingsProvider: { CalendarCaptureSettings(titlesIncluded: true, excludedIDs: [], includedOverrideIDs: []) },
            checkInDaysProvider: { await daySet.snapshot() },
            isMockMode: { false }
        )
    }

    // MARK: - Reentrancy (critical): capture must not resurrect a deleted day

    @Test func captureSkipsUpsertWhenDayNoLongerHasACheckIn() async throws {
        let store = try makeStore()
        let service = MockCalendarContextService()
        await service.setStubAccessState(.fullAccess)
        await service.setStubCaptureResult(payload(), for: day)
        // Day is not a check-in day at re-validation time (its check-in was removed).
        let coord = makeCoordinator(store: store, service: service, daySet: DaySet([]))

        await coord.checkInSaved(dayKey: day)
        #expect(store.context(for: day) == nil, "capture re-checks check-in membership before upsert")
    }

    @Test func deleteInterleavedDuringCaptureIsNotResurrected() async throws {
        let store = try makeStore()
        let service = MockCalendarContextService()
        let daySet = DaySet([day])
        await service.setStubAccessState(.fullAccess)
        await service.setStubCaptureResult(payload(), for: day)
        // The check-in is deleted mid-capture (inside the EventKit fetch) — the exact
        // actor-reentrancy interleaving that previously resurrected a deleted context.
        await service.setOnCaptureDay { d in await daySet.remove(d) }
        let coord = makeCoordinator(store: store, service: service, daySet: daySet)

        await coord.checkInSaved(dayKey: day)
        #expect(store.context(for: day) == nil, "a delete landing mid-capture must not be resurrected")
    }

    // MARK: - FR-014: local delete is unconditional on calendar access

    @Test func checkInDeletedRemovesContextEvenWithoutFullAccess() async throws {
        let store = try makeStore()
        store.upsert(dayKey: day, payload: payload(), titlesIncluded: true)
        #expect(store.context(for: day) != nil)

        let service = MockCalendarContextService()
        await service.setStubAccessState(.denied)   // access lost or never granted
        let coord = makeCoordinator(store: store, service: service, daySet: DaySet([]))

        await coord.checkInDeleted(dayKey: day)
        #expect(store.context(for: day) == nil, "FR-014 is unconditional — a local row delete needs no calendar access")
    }

    // MARK: - Orphan reconciliation (durable self-heal for any residual race)

    @Test func sweepRemovesAContextWhoseDayHasNoCheckIn() async throws {
        let store = try makeStore()
        store.upsert(dayKey: day, payload: payload(), titlesIncluded: true)
        let service = MockCalendarContextService()
        await service.setStubAccessState(.fullAccess)
        let coord = makeCoordinator(store: store, service: service, daySet: DaySet([]))

        await coord.sweep()
        #expect(store.context(for: day) == nil, "sweep drops a context whose day has no check-in")
    }
}
