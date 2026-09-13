import Testing
import Foundation
import SwiftData
@testable import app_four

@Suite(.serialized)
@MainActor
struct AudioFileStorageServiceTests {
    private static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: Recording.self, configurations: config)
    }()

    /// saveRecording must COPY the temp capture to the durable recordings dir, persist
    /// the row, and only then remove the temp — so a save failure can never orphan the
    /// file or consume the retry buffer.
    @Test func saveRecordingCopiesToRecordingsAndClearsTemp() throws {
        let service = AudioFileStorageServiceImpl(context: Self.container.mainContext)
        let fm = FileManager.default

        let temp = fm.temporaryDirectory.appendingPathComponent("cap_\(UUID().uuidString).m4a")
        let bytes = Data("captured-audio".utf8)
        try bytes.write(to: temp)

        let recording = try service.saveRecording(from: temp, duration: 12.5)
        let dest = AppPaths.recordings.appendingPathComponent(recording.audioFileName)

        #expect(fm.fileExists(atPath: dest.path))          // durable copy exists
        #expect(!fm.fileExists(atPath: temp.path))         // temp cleared after durable save
        #expect((try? Data(contentsOf: dest)) == bytes)    // content preserved
        #expect(recording.duration == 12.5)
        #expect(recording.status == .recorded)

        try? fm.removeItem(at: dest)
    }
}
