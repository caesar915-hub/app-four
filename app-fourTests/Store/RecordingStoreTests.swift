import Testing
import Foundation
import SwiftData
@testable import app_four

@MainActor
struct RecordingStoreTests {
    var store: RecordingStore
    var container: ModelContainer

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Recording.self, configurations: config)
        store = RecordingStore(context: container.mainContext)
    }

    @Test func addRecording() throws {
        let initial = store.recordings.count

        let recording = Recording(audioFileName: "test.m4a", title: "Test Recording")
        store.addRecording(recording)

        #expect(store.recordings.count == initial + 1)
        #expect(store.recordings.last?.title == "Test Recording")
    }

    @Test func deleteRecording() throws {
        let recording = Recording(audioFileName: "delete.m4a", title: "To Delete")
        store.addRecording(recording)
        let countAfterAdd = store.recordings.count

        store.deleteRecording(recording)

        #expect(store.recordings.count == countAfterAdd - 1)
    }

    @Test func toggleFavorite() throws {
        let recording = Recording(audioFileName: "fav.m4a", title: "Favorite Test")
        store.addRecording(recording)

        #expect(recording.isFavorite == false)

        store.toggleFavorite(recording)
        #expect(recording.isFavorite == true)

        store.toggleFavorite(recording)
        #expect(recording.isFavorite == false)
    }

    @Test func adhdFieldsPersistThroughSave() throws {
        let recording = Recording(
            audioFileName: "adhd.m4a",
            title: "ADHD Entry",
            hasMedication: true,
            medicationInfo: "Concerta 36mg at 8am",
            energyLevel: "high",
            focusLevel: "high",
            mood: "positive"
        )
        store.addRecording(recording)
        store.save()

        let fetched = try #require(store.recordings.first(where: { $0.audioFileName == "adhd.m4a" }))
        #expect(fetched.hasMedication == true)
        #expect(fetched.medicationInfo == "Concerta 36mg at 8am")
        #expect(fetched.energyLevel == "high")
        #expect(fetched.focusLevel == "high")
        #expect(fetched.mood == "positive")
    }

    @Test func summaryBulletsRoundTrip() throws {
        let bullets = ["Took medication", "Feeling focused", "Mild anxiety"]
        let json = try JSONEncoder().encode(bullets)
        let jsonString = try #require(String(data: json, encoding: .utf8))

        let recording = Recording(audioFileName: "bullets.m4a", summaryBulletsJSON: jsonString)
        store.addRecording(recording)

        let fetched = try #require(store.recordings.first(where: { $0.audioFileName == "bullets.m4a" }))
        #expect(fetched.summaryBullets == bullets)
    }

    @Test func updateTitle() throws {
        let recording = Recording(audioFileName: "title.m4a", title: "Old Title")
        store.addRecording(recording)

        store.updateTitle(recording, newTitle: "New Title")

        let fetched = try #require(store.recordings.first(where: { $0.audioFileName == "title.m4a" }))
        #expect(fetched.title == "New Title")
    }
}
