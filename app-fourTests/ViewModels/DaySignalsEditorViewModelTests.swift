import Testing
import SwiftData
import Foundation
@testable import app_four

@MainActor
struct DaySignalsEditorViewModelTests {
    // Returns the VM + store, plus the container that must be retained for the test.
    private func makeVM(day: Date) throws -> (DaySignalsEditorViewModel, SignalsStore, ModelContainer) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailySignals.self, configurations: config)
        let store = SignalsStore(context: container.mainContext)
        let vm = DaySignalsEditorViewModel(dayStart: day, store: store)
        return (vm, store, container)
    }

    private let day = SignalDayKey.dayStart(for: Date(timeIntervalSince1970: 4_000_000))

    @Test func editingSleepFlipsSourceToManual() throws {
        let (vm, store, container) = try makeVM(day: day)
        _ = container
        vm.sleepHours = 6.5
        vm.sleepLevel = .okay
        try vm.save()

        let row = try #require(store.fetch(dayStart: day))
        #expect(row.sleepHours == 6.5)
        #expect(row.sleepLevel == .okay)
        #expect(row.sleepSource == .manual)
    }

    @Test func clearingManualFieldResetsToNone() throws {
        let (vm, store, container) = try makeVM(day: day)
        _ = container
        // Seed a manual value, then re-load it into the VM.
        let seeded = store.upsert(dayStart: day)
        seeded.sleepHours = 7
        seeded.sleepSource = .manual
        try store.save()

        vm.load()
        vm.sleepHours = nil      // user clears it
        vm.sleepLevel = nil
        try vm.save()

        let updated = try #require(store.fetch(dayStart: day))
        #expect(updated.sleepHours == nil)
        #expect(updated.sleepSource == .none)   // eligible for HealthKit again (A5/FR-012)
    }

    @Test func untouchedGroupsKeepTheirSource() throws {
        let (vm, store, container) = try makeVM(day: day)
        _ = container
        let seeded = store.upsert(dayStart: day)
        seeded.steps = 8000
        seeded.activitySource = .healthKit
        try store.save()

        vm.load()
        vm.sleepHours = 8        // only sleep edited
        try vm.save()

        let updated = try #require(store.fetch(dayStart: day))
        #expect(updated.activitySource == .healthKit)   // untouched group keeps its source (FR-009)
        #expect(updated.sleepSource == .manual)
    }

    // MARK: Non-sleep group branches (save() per-group change-detection)

    @Test func editingThenClearingActivityResetsSource() throws {
        let (vm, store, container) = try makeVM(day: day); _ = container
        vm.steps = 8000
        vm.activeEnergyKcal = 420
        try vm.save()
        #expect(try #require(store.fetch(dayStart: day)).activitySource == .manual)

        vm.load()
        vm.steps = nil
        vm.activeEnergyKcal = nil
        vm.exerciseMinutes = nil
        try vm.save()
        #expect(try #require(store.fetch(dayStart: day)).activitySource == .none)
    }

    @Test func editingHeartFlipsSourceToManual() throws {
        let (vm, store, container) = try makeVM(day: day); _ = container
        vm.restingHeartRate = 60
        try vm.save()
        let row = try #require(store.fetch(dayStart: day))
        #expect(row.restingHeartRate == 60)
        #expect(row.heartSource == .manual)
    }

    @Test func editingThenClearingCycleResetsSource() throws {
        let (vm, store, container) = try makeVM(day: day); _ = container
        vm.menstrualFlow = .medium
        vm.cycleSymptoms = ["cramps"]
        try vm.save()
        let saved = try #require(store.fetch(dayStart: day))
        #expect(saved.menstrualFlow == .medium)
        #expect(saved.cycleSymptoms == ["cramps"])
        #expect(saved.cycleSource == .manual)

        vm.load()
        vm.menstrualFlow = nil
        vm.cycleSymptoms = []
        try vm.save()
        #expect(try #require(store.fetch(dayStart: day)).cycleSource == .none)
    }
}
