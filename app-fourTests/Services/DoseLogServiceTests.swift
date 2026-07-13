import Testing
import Foundation
import SwiftData
@testable import app_four

/// T012 (030 / US1) — full outcome + guard-evaluation matrix for `DoseLogService`.
/// Isolated in-memory container per test (parallel-safe); real-data mode so the
/// guard's `isMockData == false` fetch behaves.
@MainActor
struct DoseLogServiceTests {

    private func makeStore(
        mode: DoseGuardMode = .off,
        windowHours: Int = 2,
        name: String? = "Elvanse",
        dose: String? = "30 mg"
    ) throws -> ModelContext {
        TestSupport.useRealData()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Recording.self, MedicationEvent.self, AppSettings.self,
            configurations: config
        )
        let context = container.mainContext
        let settings = AppSettings()
        settings.defaultMedicationName = name
        settings.defaultMedicationDose = dose
        settings.doseGuardModeRaw = mode.rawValue
        settings.doseGuardWindowHours = windowHours
        context.insert(settings)
        try context.save()
        return context
    }

    private func make(
        mode: DoseGuardMode = .off,
        windowHours: Int = 2,
        name: String? = "Elvanse",
        dose: String? = "30 mg"
    ) throws -> (DoseLogServiceImpl, ModelContext) {
        let context = try makeStore(mode: mode, windowHours: windowHours, name: name, dose: dose)
        return (DoseLogServiceImpl(context: context), context)
    }

    private func eventCount(_ context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<MedicationEvent>())
    }

    // MARK: - Not configured

    @Test func notConfiguredWhenNoDefault() async throws {
        let (service, context) = try make(name: nil, dose: nil)
        #expect(await service.logDefaultDose(now: .now) == .notConfigured)
        #expect(try eventCount(context) == 0)
    }

    @Test func notConfiguredWhenNameNotInCatalog() async throws {
        let (service, context) = try make(name: "Adderall", dose: "30 mg")
        #expect(await service.logDefaultDose(now: .now) == .notConfigured)
        #expect(try eventCount(context) == 0)
    }

    // Reachable partial state: switching medication clears the dose
    // (SettingsViewModel.medicationDidChange), leaving a valid catalog name with a
    // nil dose durably persisted. Firing the intent mid-reconfiguration must degrade
    // to not-configured — never log with a stale/empty dose (FR-007).
    @Test func notConfiguredWhenNameSetButDoseCleared() async throws {
        let (service, context) = try make(name: "Ritalin", dose: nil)
        #expect(await service.logDefaultDose(now: .now) == .notConfigured)
        #expect(try eventCount(context) == 0)
    }

    // MARK: - Logged event contract

    @Test func loggedEventMatchesContract() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let (service, context) = try make(name: "Elvanse", dose: "30 mg")

        #expect(await service.logDefaultDose(now: now) == .logged(name: "Elvanse", dose: "30 mg", at: now))

        let event = try #require(try context.fetch(FetchDescriptor<MedicationEvent>()).first)
        #expect(event.name == "Elvanse")
        #expect(event.dose == "30 mg")
        #expect(event.takenAt == now)
        #expect(event.durationHours == 10)      // Elvanse catalog default
        #expect(event.source == .manual)
        #expect(event.recording == nil)
        #expect(event.isMockData == false)
        #expect(event.taken == true)
    }

    // MARK: - Guard off

    @Test func guardOffAllowsDoubleLog() async throws {
        let (service, context) = try make(mode: .off)
        _ = await service.logDefaultDose(now: .now)
        _ = await service.logDefaultDose(now: .now)
        #expect(try eventCount(context) == 2)
    }

    // MARK: - Total guard

    @Test func totalGuardBlocksWhileActive() async throws {
        let now = Date()
        let (service, context) = try make(mode: .total)
        context.insert(MedicationEvent(name: "Elvanse", dose: "30 mg",
                                       takenAt: now.addingTimeInterval(-2 * 3600),
                                       durationHours: 10, source: .manual))
        try context.save()

        #expect(await service.logDefaultDose(now: now) == .guarded(activeSince: now.addingTimeInterval(-2 * 3600)))
        #expect(try eventCount(context) == 1)   // nothing new written
    }

    @Test func totalGuardAllowsAtExactEffectEnd() async throws {
        let now = Date()
        let (service, context) = try make(mode: .total)
        context.insert(MedicationEvent(name: "Elvanse", dose: "30 mg",
                                       takenAt: now.addingTimeInterval(-10 * 3600),
                                       durationHours: 10, source: .manual))
        try context.save()

        #expect(await service.logDefaultDose(now: now) == .logged(name: "Elvanse", dose: "30 mg", at: now))
        #expect(try eventCount(context) == 2)
    }

    @Test func totalGuardCountsAnyMedicationAndSurface() async throws {
        let now = Date()
        let (service, context) = try make(mode: .total)   // default is Elvanse
        // A Ritalin dose logged the in-app way still guards an expedited Elvanse log.
        context.insert(MedicationEvent(name: "Ritalin", dose: "10 mg",
                                       takenAt: now.addingTimeInterval(-1 * 3600),
                                       durationHours: 3, source: .manual))
        try context.save()

        #expect(await service.logDefaultDose(now: now) == .guarded(activeSince: now.addingTimeInterval(-1 * 3600)))
    }

    // MARK: - Window guard

    @Test func windowGuardBlocksInsideWindow() async throws {
        let now = Date()
        let (service, context) = try make(mode: .window, windowHours: 3)
        context.insert(MedicationEvent(name: "Elvanse", dose: "30 mg",
                                       takenAt: now.addingTimeInterval(-2 * 3600),
                                       durationHours: 10, source: .manual))
        try context.save()

        #expect(await service.logDefaultDose(now: now) == .guarded(activeSince: now.addingTimeInterval(-2 * 3600)))
    }

    @Test func windowGuardAllowsAtExactBoundary() async throws {
        let now = Date()
        let (service, context) = try make(mode: .window, windowHours: 2)
        context.insert(MedicationEvent(name: "Elvanse", dose: "30 mg",
                                       takenAt: now.addingTimeInterval(-2 * 3600),
                                       durationHours: 10, source: .manual))
        try context.save()

        #expect(await service.logDefaultDose(now: now) == .logged(name: "Elvanse", dose: "30 mg", at: now))
    }

    // MARK: - Armed guard, empty history (FR-009/010: a guard blocks only against a prior dose)

    // A user who enables Dose guard before ever logging: mode != .off but
    // mostRecentDose() == nil must fall through the `if let previous` and log. A
    // regression that returned .guarded on nil history would dead-end every guard-on
    // user's first-ever dose while every prior-dose test stayed green.
    @Test func totalGuardWithNoPriorDoseStillLogs() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let (service, context) = try make(mode: .total)
        #expect(await service.logDefaultDose(now: now) == .logged(name: "Elvanse", dose: "30 mg", at: now))
        #expect(try eventCount(context) == 1)
    }

    @Test func windowGuardWithNoPriorDoseStillLogs() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let (service, context) = try make(mode: .window, windowHours: 4)
        #expect(await service.logDefaultDose(now: now) == .logged(name: "Elvanse", dose: "30 mg", at: now))
        #expect(try eventCount(context) == 1)
    }

    // MARK: - Notification side effect

    @Test func postsMedicationEventsDidChangeOnLoggedOnly() async throws {
        let (service, _) = try make(mode: .off)
        let counter = PostCounter()
        let token = NotificationCenter.default.addObserver(
            forName: .medicationEventsDidChange, object: nil, queue: nil
        ) { _ in counter.count += 1 }
        defer { NotificationCenter.default.removeObserver(token) }

        _ = await service.logDefaultDose(now: .now)
        #expect(counter.count == 1)
    }

    @Test func doesNotPostWhenNotConfigured() async throws {
        let (service, _) = try make(name: nil, dose: nil)
        let counter = PostCounter()
        let token = NotificationCenter.default.addObserver(
            forName: .medicationEventsDidChange, object: nil, queue: nil
        ) { _ in counter.count += 1 }
        defer { NotificationCenter.default.removeObserver(token) }

        _ = await service.logDefaultDose(now: .now)
        #expect(counter.count == 0)
    }

    // MARK: - Persistence failure (SC-007: honest failure, never a false "logged")

    @Test func saveFailureReturnsFailedWritesNothingPostsNothing() async throws {
        let context = try makeStore()
        let service = FailingSaveDoseLogService(context: context)
        let counter = PostCounter()
        let token = NotificationCenter.default.addObserver(
            forName: .medicationEventsDidChange, object: nil, queue: nil
        ) { _ in counter.count += 1 }
        defer { NotificationCenter.default.removeObserver(token) }

        #expect(await service.logDefaultDose(now: .now) == .failed)
        #expect(try eventCount(context) == 0)
        #expect(counter.count == 0)
    }

    @Test func saveFailureLeavesNoPendingInsertForAutosave() async throws {
        let context = try makeStore()
        let service = FailingSaveDoseLogService(context: context)
        _ = await service.logDefaultDose(now: .now)
        #expect(context.insertedModelsArray.isEmpty,
                "A dangling insert would be persisted by a later autosave — a silent success after a reported failure means a double log on retry")
    }

    // MARK: - Guard failure semantics (SC-005: armed guard fails closed)

    @Test func armedGuardFailsClosedWhenHistoryUnreadable() async throws {
        let context = try makeStore(mode: .total)
        let service = FailingHistoryDoseLogService(context: context)
        #expect(await service.logDefaultDose(now: .now) == .failed)
        #expect(try eventCount(context) == 0)
    }

    @Test func guardOffNeverReadsHistory() async throws {
        let context = try makeStore(mode: .off)
        let service = FailingHistoryDoseLogService(context: context)
        let outcome = await service.logDefaultDose(now: .now)
        guard case .logged = outcome else {
            Issue.record("Guard .off must never consult dose history (FR-009); got \(outcome)")
            return
        }
        #expect(try eventCount(context) == 1)
    }
}

/// Overridable failure seams — the SwiftData layer can't be made to fail on demand
/// otherwise (pattern: `RecordingStore.persistCheckInNote`).
private final class FailingSaveDoseLogService: DoseLogServiceImpl {
    override func persist() throws { throw DoseLogTestError.forced }
}

private final class FailingHistoryDoseLogService: DoseLogServiceImpl {
    override func mostRecentDose() throws -> MedicationEvent? { throw DoseLogTestError.forced }
}

private enum DoseLogTestError: Error { case forced }

/// Synchronous, same-thread (`queue: nil`) observation counter — the notification is
/// posted on the MainActor and the block runs inline, so unchecked Sendable is safe.
private final class PostCounter: @unchecked Sendable {
    var count = 0
}
