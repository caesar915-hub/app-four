import Foundation
import Testing
import SwiftData
@testable import app_four

@Suite(.serialized)
@MainActor
struct RecordingDetailViewModelTests {
    private static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: Recording.self, configurations: config)
    }()

    var viewModel: RecordingDetailViewModel
    var mocks: MockAppServices
    var store: RecordingStore
    var recording: Recording

    init() throws {
        TestSupport.useRealData()
        let context = Self.container.mainContext
        try context.delete(model: Recording.self)
        store = RecordingStore(context: context)
        mocks = MockAppServices()
        recording = Recording(audioFileName: "test-026.m4a")
        store.context.insert(recording)
        try store.context.save()
        viewModel = RecordingDetailViewModel(recording: recording, store: store, services: mocks.services)
    }

    // MARK: Spec 057 / UI-38 — relative title + dated subtitle (D18: one check-in per page)

    @Test func relativeTitleByDay() throws {
        let cal = Calendar.current
        recording.createdAt = Date()
        #expect(viewModel.relativeTitle == "Today")
        recording.createdAt = try #require(cal.date(byAdding: .day, value: -1, to: Date()))
        #expect(viewModel.relativeTitle == "Yesterday")
        let older = try #require(cal.date(byAdding: .day, value: -3, to: Date()))
        recording.createdAt = older
        #expect(viewModel.relativeTitle == older.formatted(.dateTime.weekday(.wide)))
        let expectedSubtitle = older.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
            + " · " + older.formatted(date: .omitted, time: .shortened)
        #expect(viewModel.subtitle == expectedSubtitle)
    }

    // MARK: US3 Delete characterization

    @Test func retryTranscriptionSavesOncePerCompletion() async throws {
        recording.status = .failed
        store.resetSaveCallCount()

        viewModel.retryTranscription()

        // Wait for the whole chain (transcribe → completion save → summary save)
        // deterministically: `applySummary` sets summaryStatus synchronously
        // before the summary save on the same actor turn, so observing a settled
        // status guarantees every save has landed. A fixed sleep flakes under
        // full-suite parallel load.
        for _ in 0..<500 {
            let status = recording.summaryStatus
            if status == SummaryStatus.completed.rawValue || status == SummaryStatus.failed.rawValue { break }
            try? await Task.sleep(for: .milliseconds(10))
        }

        #expect(recording.status == .completed)
        #expect(recording.fullTranscriptText == "This is a mock transcript.")
        // Start (.transcribing) save, completion save, and summary save = 3 total.
        // If a per-segment save remained, this would be 4 (with one segment) or more.
        #expect(store.saveCallCount == 3, "Transcription completion must produce exactly one save, with no per-segment writes")
    }

    @Test func deleteRemovesRecordingFromStore() {
        store.addRecording(recording)
        viewModel.delete()
        #expect(store.recordings.isEmpty)
    }
}
