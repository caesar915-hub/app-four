import Testing
import Foundation
import SwiftData
@testable import app_four

// MARK: - Helpers

@MainActor
private func makeStore(container: ModelContainer) -> DayContextStore {
    DayContextStore(context: container.mainContext)
}

private func makeContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: DayCalendarContext.self, configurations: config)
}

private func dayKey(offsetDays: Int = 0) -> Date {
    let base = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_750_000_000))
    return Calendar.current.date(byAdding: .day, value: offsetDays, to: base)!
}

private func makePayload(title: String) -> CapturedDayEvents {
    CapturedDayEvents(events: [
        CapturedEvent(
            title: title,
            start: Date(timeIntervalSince1970: 1_000_000),
            end: Date(timeIntervalSince1970: 1_003_600),
            isAllDay: false,
            attendeeCount: 1,
            availability: "busy"
        )
    ])
}

private func makeCoordinator(
    service: MockCalendarContextService,
    store: DayContextStore,
    settings: CalendarCaptureSettings = CalendarCaptureSettings(
        titlesIncluded: true,
        excludedIDs: [],
        includedOverrideIDs: []
    ),
    checkInDays: Set<Date> = [],
    isMockMode: Bool = false
) -> CalendarContextCoordinatorImpl {
    CalendarContextCoordinatorImpl(
        service: service,
        store: store,
        settingsProvider: { settings },
        checkInDaysProvider: { checkInDays },
        isMockMode: { isMockMode }
    )
}

// MARK: - Suite

@MainActor
struct CalendarContextCoordinatorTests {

    // MARK: checkInSaved — captures and stores

    @Test func checkInSavedCapturesAndStores() async throws {
        TestSupport.useRealData()
        let container = try makeContainer()
        let store = makeStore(container: container)
        let service = MockCalendarContextService()
        let day = dayKey()
        let payload = makePayload(title: "Standup")

        await service.setStubAccessState(.fullAccess)
        await service.setStubCaptureResult(payload, for: day)

        let coordinator = makeCoordinator(service: service, store: store, checkInDays: [day])
        await coordinator.checkInSaved(dayKey: day)

        #expect(store.context(for: day) == payload)
        let calls = await service.recordedCaptureCalls()
        #expect(calls.count == 1)
        #expect(calls[0].dayKey == day)
    }

    // MARK: checkInSaved — latest-wins (FR-006)

    @Test func checkInSavedLatestWinsOnSecondSave() async throws {
        TestSupport.useRealData()
        let container = try makeContainer()
        let store = makeStore(container: container)
        let service = MockCalendarContextService()
        let day = dayKey()
        let payloadV1 = makePayload(title: "First")
        let payloadV2 = makePayload(title: "Second")

        await service.setStubAccessState(.fullAccess)
        await service.setStubCaptureResult(payloadV1, for: day)

        let coordinator = makeCoordinator(service: service, store: store, checkInDays: [day])
        await coordinator.checkInSaved(dayKey: day)
        #expect(store.context(for: day) == payloadV1)

        // Replace stub with new payload and save again.
        await service.setStubCaptureResult(payloadV2, for: day)
        await coordinator.checkInSaved(dayKey: day)

        #expect(store.context(for: day) == payloadV2)
        let calls = await service.recordedCaptureCalls()
        #expect(calls.count == 2)
    }

    // MARK: sweep — only captures days lacking a row

    @Test func sweepCapturesOnlyMissingDays() async throws {
        TestSupport.useRealData()
        let container = try makeContainer()
        let store = makeStore(container: container)
        let service = MockCalendarContextService()

        let coveredDay = dayKey(offsetDays: 0)
        let missingDay = dayKey(offsetDays: 1)
        let coveredPayload = makePayload(title: "Covered")
        let missingPayload = makePayload(title: "Missing")

        // Pre-seed coveredDay so the store already has a row for it.
        store.upsert(dayKey: coveredDay, payload: coveredPayload, titlesIncluded: true)

        await service.setStubAccessState(.fullAccess)
        await service.setStubCaptureResult(missingPayload, for: missingDay)
        // coveredDay has no stub; returning nil would be a bug if called.

        let coordinator = makeCoordinator(
            service: service,
            store: store,
            checkInDays: [coveredDay, missingDay]
        )
        await coordinator.sweep()

        let calls = await service.recordedCaptureCalls()
        // Only missingDay should have been passed to captureDay.
        #expect(calls.count == 1)
        #expect(calls[0].dayKey == missingDay)
        // Covered day's context must be unchanged.
        #expect(store.context(for: coveredDay) == coveredPayload)
        // Missing day's context must now be populated.
        #expect(store.context(for: missingDay) == missingPayload)
    }

    // MARK: checkInDateChanged — captures newDay, deletes oldDay when vacated

    @Test func checkInDateChangedCapturesNewAndDeletesVacatedOld() async throws {
        TestSupport.useRealData()
        let container = try makeContainer()
        let store = makeStore(container: container)
        let service = MockCalendarContextService()

        let oldDay = dayKey(offsetDays: 0)
        let newDay = dayKey(offsetDays: 1)
        let oldPayload = makePayload(title: "OldDay")
        let newPayload = makePayload(title: "NewDay")

        // Pre-seed context for old day.
        store.upsert(dayKey: oldDay, payload: oldPayload, titlesIncluded: true)

        await service.setStubAccessState(.fullAccess)
        await service.setStubCaptureResult(newPayload, for: newDay)

        // checkInDays no longer includes oldDay (it was the last check-in for that day).
        let coordinator = makeCoordinator(
            service: service,
            store: store,
            checkInDays: [newDay]   // oldDay absent → should be deleted
        )
        await coordinator.checkInDateChanged(from: oldDay, to: newDay)

        // New day captured.
        #expect(store.context(for: newDay) == newPayload)
        // Old day context deleted.
        #expect(store.context(for: oldDay) == nil)
        let calls = await service.recordedCaptureCalls()
        #expect(calls.count == 1)
        #expect(calls[0].dayKey == newDay)
    }

    // MARK: checkInDateChanged — keeps oldDay context when still has check-ins

    @Test func checkInDateChangedKeepsOldDayContextWhenStillHasCheckIns() async throws {
        TestSupport.useRealData()
        let container = try makeContainer()
        let store = makeStore(container: container)
        let service = MockCalendarContextService()

        let oldDay = dayKey(offsetDays: 0)
        let newDay = dayKey(offsetDays: 1)
        let oldPayload = makePayload(title: "OldDay")
        let newPayload = makePayload(title: "NewDay")

        store.upsert(dayKey: oldDay, payload: oldPayload, titlesIncluded: true)

        await service.setStubAccessState(.fullAccess)
        await service.setStubCaptureResult(newPayload, for: newDay)

        // oldDay still has check-ins — present in checkInDaysProvider.
        let coordinator = makeCoordinator(
            service: service,
            store: store,
            checkInDays: [oldDay, newDay]
        )
        await coordinator.checkInDateChanged(from: oldDay, to: newDay)

        // Old context must still be present.
        #expect(store.context(for: oldDay) == oldPayload)
        #expect(store.context(for: newDay) == newPayload)
    }

    // MARK: checkInDeleted — deletes when last check-in removed

    @Test func checkInDeletedDeletesContextWhenLastCheckIn() async throws {
        TestSupport.useRealData()
        let container = try makeContainer()
        let store = makeStore(container: container)
        let service = MockCalendarContextService()

        let day = dayKey()
        store.upsert(dayKey: day, payload: makePayload(title: "Event"), titlesIncluded: true)

        await service.setStubAccessState(.fullAccess)

        // Day has no remaining check-in (default checkInDays: []) → context deleted.
        let coordinator = makeCoordinator(service: service, store: store)
        await coordinator.checkInDeleted(dayKey: day)

        #expect(store.context(for: day) == nil)
    }

    // MARK: checkInDeleted — no-op when day still has check-ins

    @Test func checkInDeletedIsNoOpWhenDayStillHasCheckIns() async throws {
        TestSupport.useRealData()
        let container = try makeContainer()
        let store = makeStore(container: container)
        let service = MockCalendarContextService()

        let day = dayKey()
        let payload = makePayload(title: "Event")
        store.upsert(dayKey: day, payload: payload, titlesIncluded: true)

        await service.setStubAccessState(.fullAccess)

        // Day still has a check-in (present in checkInDaysProvider) → context kept.
        let coordinator = makeCoordinator(service: service, store: store, checkInDays: [day])
        await coordinator.checkInDeleted(dayKey: day)

        #expect(store.context(for: day) == payload)
        let calls = await service.recordedCaptureCalls()
        #expect(calls.isEmpty)
    }

    // MARK: recaptureAll — re-captures every check-in day

    @Test func recaptureAllCapturesAllCheckInDays() async throws {
        TestSupport.useRealData()
        let container = try makeContainer()
        let store = makeStore(container: container)
        let service = MockCalendarContextService()

        let day0 = dayKey(offsetDays: 0)
        let day1 = dayKey(offsetDays: 1)
        let day2 = dayKey(offsetDays: 2)
        let p0 = makePayload(title: "D0")
        let p1 = makePayload(title: "D1")
        let p2 = makePayload(title: "D2")

        await service.setStubAccessState(.fullAccess)
        await service.setStubCaptureResult(p0, for: day0)
        await service.setStubCaptureResult(p1, for: day1)
        await service.setStubCaptureResult(p2, for: day2)

        let coordinator = makeCoordinator(
            service: service,
            store: store,
            checkInDays: [day0, day1, day2]
        )
        await coordinator.recaptureAll()

        #expect(store.context(for: day0) == p0)
        #expect(store.context(for: day1) == p1)
        #expect(store.context(for: day2) == p2)
        let calls = await service.recordedCaptureCalls()
        #expect(calls.count == 3)
    }

    // MARK: Gating — denied access produces no captures

    @Test func gatingDeniedAccessProducesNoCaptures() async throws {
        TestSupport.useRealData()
        let container = try makeContainer()
        let store = makeStore(container: container)
        let service = MockCalendarContextService()
        let day = dayKey()

        await service.setStubAccessState(.denied)
        await service.setStubCaptureResult(makePayload(title: "Event"), for: day)

        let coordinator = makeCoordinator(
            service: service,
            store: store,
            checkInDays: [day]
        )

        await coordinator.checkInSaved(dayKey: day)
        await coordinator.sweep()
        await coordinator.recaptureAll()

        let calls = await service.recordedCaptureCalls()
        #expect(calls.isEmpty)
        #expect(store.contextsByDay.isEmpty)
    }

    // MARK: Gating — mock mode produces no captures

    @Test func gatingMockModeProducesNoCaptures() async throws {
        TestSupport.useRealData()
        let container = try makeContainer()
        let store = makeStore(container: container)
        let service = MockCalendarContextService()
        let day = dayKey()

        await service.setStubAccessState(.fullAccess)
        await service.setStubCaptureResult(makePayload(title: "Event"), for: day)

        let coordinator = makeCoordinator(
            service: service,
            store: store,
            checkInDays: [day],
            isMockMode: true    // debugMockMode ON
        )

        await coordinator.checkInSaved(dayKey: day)
        await coordinator.sweep()
        await coordinator.recaptureAll()

        let calls = await service.recordedCaptureCalls()
        #expect(calls.isEmpty)
        #expect(store.contextsByDay.isEmpty)
    }

    // MARK: Sweep coalescing — sequential path exercises the coalescing flag

    @Test func sweepSequentialPathExercisesCoalescingFlag() async throws {
        // This test verifies the functional invariant: two sequential sweep() calls
        // do not double-capture days that were already captured by the first call.
        // (True concurrency-based coalescing is not exercisable in a synchronous
        // Swift Testing suite; the structural flag is exercised by the sequential path.)
        TestSupport.useRealData()
        let container = try makeContainer()
        let store = makeStore(container: container)
        let service = MockCalendarContextService()

        let day = dayKey()
        let payload = makePayload(title: "Event")

        await service.setStubAccessState(.fullAccess)
        await service.setStubCaptureResult(payload, for: day)

        let coordinator = makeCoordinator(
            service: service,
            store: store,
            checkInDays: [day]
        )

        // First sweep: captures the missing day.
        await coordinator.sweep()
        let callsAfterFirst = await service.recordedCaptureCalls()
        #expect(callsAfterFirst.count == 1)

        // Second sweep: day is now covered — no additional captureDay calls.
        await coordinator.sweep()
        let callsAfterSecond = await service.recordedCaptureCalls()
        #expect(callsAfterSecond.count == 1)
    }
}
