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

    // MARK: FR-019 Re-entry protection (026 RED\u2192GREEN)

    /// RED: `viewModel.summaryTask` and `viewModel.startRegenerate()` do not exist \u2014
    /// compile failure confirms RED.
    /// GREEN: T013 adds both; second call cancels the first task and stores the new one.
    @Test func startRegenerateOnSecondCallCancelsPreviousTask() async {
        await mocks.summarization.setHangs(true)

        viewModel.startRegenerate()
        let first = viewModel.summaryTask
        viewModel.startRegenerate()

        #expect(first?.isCancelled == true)
        #expect(viewModel.summaryTask != nil)
    }

    // MARK: US3 Delete characterization

    @Test func deleteRemovesRecordingFromStore() {
        store.addRecording(recording)
        viewModel.delete()
        #expect(store.recordings.isEmpty)
    }
}
