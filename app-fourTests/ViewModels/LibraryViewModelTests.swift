import Testing
import SwiftData
@testable import app_four

@MainActor
struct LibraryViewModelTests {
    var viewModel: LibraryViewModel
    var store: RecordingStore
    var container: ModelContainer

    init() throws {
        TestSupport.useRealData()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Recording.self, configurations: config)
        store = RecordingStore(context: container.mainContext)
        viewModel = LibraryViewModel(store: store)
    }

    @Test func filteringByTitle() throws {
        store.addRecording(Recording(audioFileName: "a.m4a", title: "Morning Meeting"))
        store.addRecording(Recording(audioFileName: "b.m4a", title: "Lecture Notes"))

        #expect(viewModel.recordings.count == 2)

        viewModel.searchText = "Morning"
        #expect(viewModel.filteredRecordings.count == 1)
        #expect(viewModel.filteredRecordings.first?.title == "Morning Meeting")
    }

    @Test func emptySearchReturnsAll() throws {
        store.addRecording(Recording(audioFileName: "a.m4a", title: "A"))
        store.addRecording(Recording(audioFileName: "b.m4a", title: "B"))

        viewModel.searchText = ""
        #expect(viewModel.filteredRecordings.count == 2)
    }

    @Test func deletingRecording() throws {
        let recording = Recording(audioFileName: "del.m4a", title: "To Delete")
        store.addRecording(recording)
        #expect(viewModel.recordings.count == 1)

        viewModel.deleteRecording(recording)
        #expect(viewModel.recordings.count == 0)
    }
}
