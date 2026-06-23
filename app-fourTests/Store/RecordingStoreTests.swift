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

    // A recording left `.transcribing` when the app was killed (or whose transcription
    // was cancelled and never finalized) must be recovered to `.failed` at launch, so
    // the detail view stops showing a permanent "Transcribing…" and offers retry.
    @Test func orphanedTranscribingRecoveredToFailedOnLaunch() throws {
        let orphan = Recording(audioFileName: "orphan.m4a", status: .transcribing)
        let healthy = Recording(audioFileName: "done.m4a", status: .completed)
        container.mainContext.insert(orphan)
        container.mainContext.insert(healthy)
        try container.mainContext.save()

        // A fresh store on the same container runs the launch-time sweep in init.
        let recovered = RecordingStore(context: container.mainContext)

        let sweptOrphan = try #require(recovered.recordings.first { $0.audioFileName == "orphan.m4a" })
        let untouchedDone = try #require(recovered.recordings.first { $0.audioFileName == "done.m4a" })
        #expect(sweptOrphan.status == .failed)            // orphan recovered
        #expect(!sweptOrphan.fullTranscriptText.isEmpty)  // got a retry message
        #expect(untouchedDone.status == .completed)       // healthy one left alone
    }

    // Launch-time orphan recovery sweeps `.transcribing` → `.failed`, but a recording
    // captured before the model was ready is legitimately `.pendingTranscription` and
    // MUST be left untouched so it can still drain once the model lands (FR-016 / T020).
    @Test func orphanRecoveryLeavesPendingTranscriptionUntouched() throws {
        let pending = Recording(audioFileName: "pending.m4a", status: .pendingTranscription)
        let orphan = Recording(audioFileName: "orphan.m4a", status: .transcribing)
        container.mainContext.insert(pending)
        container.mainContext.insert(orphan)
        try container.mainContext.save()

        let recovered = RecordingStore(context: container.mainContext)

        let sweptOrphan = try #require(recovered.recordings.first { $0.audioFileName == "orphan.m4a" })
        let untouchedPending = try #require(recovered.recordings.first { $0.audioFileName == "pending.m4a" })
        #expect(sweptOrphan.status == .failed)                       // orphan still swept
        #expect(untouchedPending.status == .pendingTranscription)    // pending preserved
        #expect(untouchedPending.fullTranscriptText.isEmpty)         // no error message stamped
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
