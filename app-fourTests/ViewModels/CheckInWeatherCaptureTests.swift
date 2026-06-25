import Foundation
import Testing
import SwiftData
@testable import app_four

/// T012–T014 — best-effort weather backfill on check-in. Voice and text paths share
/// `captureWeather(for:)`/`backfillWeather(for:)`, so the shared capture is tested directly
/// plus the text path end-to-end.
@MainActor
struct CheckInWeatherCaptureTests {
    let container: ModelContainer
    let store: RecordingStore
    let mocks: MockAppServices
    let viewModel: CheckInViewModel

    init() throws {
        TestSupport.useRealData()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Recording.self, configurations: config)
        store = RecordingStore(context: container.mainContext)
        mocks = MockAppServices()
        viewModel = CheckInViewModel(store: store, services: mocks.services)
    }

    private func moodDraft() -> CheckInDraft {
        var d = CheckInDraft(); d.mood = .good; return d
    }

    // T013 — text path backfills weather onto the persisted recording.
    @Test func textCheckInBackfillsWeather() async {
        viewModel.saveTextCheckIn(moodDraft())
        await viewModel.weatherCaptureTask?.value
        #expect(viewModel.lastSavedRecording?.decodedWeather?.conditionCode == "clear")
    }

    // T012 — VOICE path end-to-end: record → stop → attemptSave → backfill wiring.
    // Drives the real call site (CheckInViewModel.attemptSave) so deleting that one line
    // would fail here, not just the shared-helper test below.
    @Test func voiceCheckInBackfillsWeather() async {
        await viewModel.startRecording().value
        await viewModel.stopRecording().value
        await viewModel.weatherCaptureTask?.value
        #expect(viewModel.lastSavedRecording?.decodedWeather?.conditionCode == "clear")
    }

    // T012 — the shared capture writes weather for a recording present in the store
    // (the single call both voice `attemptSave` and text `saveTextCheckIn` make).
    @Test func captureWritesWeatherForPresentRecording() async {
        let r = Recording(audioFileName: "text-y", status: .completed)
        store.addRecording(r)
        await viewModel.captureWeather(for: r)
        #expect(r.decodedWeather?.conditionCode == "clear")
    }

    // T014a — a nil snapshot still lands the check-in, weather-less, with no error.
    @Test func nilSnapshotLeavesCheckInWeatherless() async {
        mocks.weather.snapshot = nil
        viewModel.saveTextCheckIn(moodDraft())
        await viewModel.weatherCaptureTask?.value
        #expect(viewModel.lastSavedRecording != nil)
        #expect(viewModel.lastSavedRecording?.weatherJSON == nil)
    }

    // T014b — a recording deleted before weather returns is never touched (guard holds).
    @Test func deletedRecordingIsNotTouched() async {
        let r = Recording(audioFileName: "text-x", status: .completed) // never added to store
        await viewModel.captureWeather(for: r)
        #expect(r.weatherJSON == nil)
    }
}
