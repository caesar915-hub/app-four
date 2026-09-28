import Foundation
import Testing
import SwiftData
@testable import app_four

@Suite(.serialized)
@MainActor
struct MedicationBarViewModelTests {
    private static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(
            for: Recording.self, MedicationEvent.self, AppSettings.self,
            configurations: config
        )
    }()

    var context: ModelContext
    var viewModel: MedicationBarViewModel

    init() throws {
        context = Self.container.mainContext
        try context.delete(model: Recording.self)
        try context.delete(model: MedicationEvent.self)
        try context.delete(model: AppSettings.self)
        viewModel = MedicationBarViewModel(context: context)
    }

    // Spec 057 / D10 — status by fill fraction; worn-off stays quiet (never red).
    @Test func doseStatusFollowsFillThresholds() {
        typealias S = MedicationBarViewModel.DoseStatus
        #expect(S(progress: 0) == .kickingIn)
        #expect(S(progress: 0.19) == .kickingIn)
        #expect(S(progress: 0.2) == .active)
        #expect(S(progress: 0.79) == .active)
        #expect(S(progress: 0.8) == .wearingOff)
        #expect(S(progress: 0.99) == .wearingOff)
        #expect(S(progress: 1) == .wornOff)
        #expect(S.kickingIn.displayLabel == "Kicking in")
        #expect(S.wornOff.displayLabel == "Worn off")
    }

    @Test func logManualDoseUsesGivenDuration() throws {
        viewModel.logManualDose(name: "Concerta", dose: "36 mg", takenAt: Date(), durationHours: 8)
        let events = try context.fetch(FetchDescriptor<MedicationEvent>())
        #expect(events.count == 1)
        let event = try #require(events.first)
        #expect(event.durationHours == 8)   // the chosen duration, not the old hard-coded 10h (SC-002)
        #expect(event.source == .manual)
    }

    @Test func logManualDoseDefaultsToTenHours() throws {
        viewModel.logManualDose(name: "Ritalin", dose: nil, takenAt: Date())
        let event = try #require(try context.fetch(FetchDescriptor<MedicationEvent>()).first)
        #expect(event.durationHours == 10)
    }

    @Test func refreshReturnsEmptyWhenNoEvents() {
        viewModel.refresh()
        #expect(viewModel.activeDoses.isEmpty)
    }

    @Test func refreshShowsActiveTranscriptEvent() throws {
        let recording = Recording(audioFileName: "test.m4a", duration: 60, title: "Morning", hasMedication: true)
        context.insert(recording)
        let event = MedicationEvent(name: "Concerta", dose: "36mg", takenAt: Date(), taken: true, source: .transcript)
        context.insert(event)
        event.recording = recording
        try context.save()

        viewModel.refresh()

        #expect(viewModel.activeDoses.count == 1)
        #expect(viewModel.activeDoses.first?.name == "Concerta")
        #expect(viewModel.activeDoses.first?.dose == "36mg")
    }

    // P0.4 — a dose with no recorded amount must NOT show a phantom default ("36mg").
    @Test func noDoseShowsNoEffectiveDose() throws {
        let event = MedicationEvent(name: "Vyvanse", dose: nil, takenAt: Date(), taken: true, source: .manual)
        context.insert(event)
        try context.save()

        viewModel.refresh()

        #expect(viewModel.activeDoses.first?.name == "Vyvanse")
        #expect(viewModel.activeDoses.first?.effectiveDose == nil)
    }

    @Test func showsUpToThreeActiveDoses() throws {
        for i in 0..<4 {
            let event = MedicationEvent(
                name: "Concerta",
                dose: "36mg",
                takenAt: Date().addingTimeInterval(Double(i) * 3600),
                taken: true,
                durationHours: 10.0,
                source: .manual
            )
            context.insert(event)
        }
        try context.save()

        viewModel.refresh()

        #expect(viewModel.activeDoses.count == 3)
    }

    @Test func ordinalIsCorrectForMultipleDoses() throws {
        // Anchor to midday so the two doses never straddle a calendar-day boundary
        // regardless of when the suite runs (the ordinal groups doses by `startOfDay`).
        let now = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600)
        let first  = MedicationEvent(name: "Concerta", dose: "36mg", takenAt: now.addingTimeInterval(-3600), taken: true, source: .manual)
        let second = MedicationEvent(name: "Concerta", dose: "36mg", takenAt: now, taken: true, source: .manual)
        context.insert(first)
        context.insert(second)
        try context.save()

        viewModel.refresh(now: now)

        #expect(viewModel.activeDoses.count == 2)
        #expect(viewModel.activeDoses.first?.doseNumber == 1)
        #expect(viewModel.activeDoses.last?.doseNumber == 2)
        #expect(viewModel.activeDoses.first?.totalDosesToday == 2)
    }

    @Test func progressIsNearZeroForFreshDose() throws {
        let event = MedicationEvent(name: "Concerta", dose: "36mg", takenAt: Date(), taken: true, source: .manual)
        context.insert(event)
        try context.save()

        viewModel.refresh()

        #expect((viewModel.activeDoses.first?.progress ?? 1) < 0.01)
    }

    @Test func expiredEventIsNotShown() throws {
        let event = MedicationEvent(
            name: "Old Dose", dose: "10mg",
            takenAt: Date().addingTimeInterval(-11 * 3600),
            taken: true, durationHours: 10.0, source: .manual
        )
        context.insert(event)
        try context.save()

        viewModel.refresh()

        #expect(viewModel.activeDoses.isEmpty)
    }

    @Test func missedDoseIsNotShown() throws {
        let event = MedicationEvent(name: "Concerta", dose: "36mg", takenAt: Date(), taken: false, source: .transcript)
        context.insert(event)
        try context.save()

        viewModel.refresh()

        #expect(viewModel.activeDoses.isEmpty)
    }

    @Test func logManualDoseAppearsInActiveDoses() {
        #expect(viewModel.activeDoses.isEmpty)
        viewModel.logManualDose(name: "Ritalin", dose: "10mg", takenAt: Date())
        #expect(viewModel.activeDoses.first?.name == "Ritalin")
    }

    @Test func logManualDoseTaggedWithCurrentMockModeAppearsInActiveDoses() {
        UserDefaults.standard.set(true, forKey: "debugMockMode")
        defer { UserDefaults.standard.removeObject(forKey: "debugMockMode") }

        viewModel.logManualDose(name: "Concerta", dose: "36mg", takenAt: Date())

        #expect(viewModel.activeDoses.first?.name == "Concerta")
    }

    @Test func deleteEventRemovesFromActiveDoses() throws {
        let event = MedicationEvent(name: "Concerta", dose: "36mg", takenAt: Date(), taken: true, source: .manual)
        context.insert(event)
        try context.save()
        viewModel.refresh()
        #expect(viewModel.activeDoses.count == 1)

        let id = event.id
        viewModel.deleteEvent(id: id)

        #expect(viewModel.activeDoses.isEmpty)
    }

    @Test func deletingRecordingCascadesMedicationEvents() throws {
        let recording = Recording(audioFileName: "cascade.m4a", duration: 60, title: "Cascade test", hasMedication: true)
        context.insert(recording)
        let event = MedicationEvent(name: "Concerta", dose: "36mg", takenAt: Date(), taken: true, source: .transcript)
        context.insert(event)
        event.recording = recording
        try context.save()

        context.delete(recording)
        try context.save()

        #expect((try? context.fetchCount(FetchDescriptor<MedicationEvent>())) == 0)
    }
}
