import Testing
import SwiftData
@testable import app_four

@MainActor
struct SettingsViewModelTests {
    var viewModel: SettingsViewModel
    var mocks: MockAppServices
    var store: RecordingStore
    var container: ModelContainer

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Recording.self, AppSettings.self, configurations: config)
        store = RecordingStore(context: container.mainContext)
        mocks = MockAppServices()

        viewModel = SettingsViewModel(store: store, services: mocks.services)
    }

    @Test func storageCalculationReflectsMockBytes() async {
        await viewModel.updateStorage()
        let expectedMB = 1024.0 / 1_048_576.0
        #expect(abs(viewModel.storageUsedMB - expectedMB) < 0.0001, "Storage MB should match mock bytes")
    }

    @Test func checkModelsReflectsMockState() async {
        await viewModel.checkModels()
        #expect(viewModel.whisperModelInstalled == true)
    }

    @Test func checkModelsWhenNotInstalled() async {
        await mocks.aiModel.setStubIsDownloaded(false)
        await viewModel.checkModels()
        #expect(viewModel.whisperModelInstalled == false)
    }

    @Test func recordingCountMatchesStore() throws {
        #expect(viewModel.recordingCount == 0)
        store.addRecording(Recording(audioFileName: "a.m4a", title: "Test"))
        #expect(viewModel.recordingCount == 1)
    }
}
