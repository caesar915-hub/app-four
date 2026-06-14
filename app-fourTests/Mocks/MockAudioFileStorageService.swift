import Foundation
import SwiftData
@testable import app_four

final class MockAudioFileStorageService: AudioFileStorageService, @unchecked Sendable {
    var shouldThrowError = false
    var savedRecordings: [Recording] = []
    var stubAvailableStorage: Int64 = 100_000_000

    func saveRecording(from temporaryURL: URL, duration: TimeInterval) throws -> Recording {
        if shouldThrowError {
            throw RecordingError.unknown
        }
        let recording = Recording(
            id: UUID(),
            createdAt: Date(),
            updatedAt: Date(),
            audioFileName: "mock.m4a",
            duration: duration,
            fileSize: 1024,
            status: .recorded,
            title: "Mock Recording"
        )
        savedRecordings.append(recording)
        return recording
    }

    func deleteRecording(_ recording: Recording) throws {
        savedRecordings.removeAll { $0.id == recording.id }
    }

    func getAudioURL(for recording: Recording) -> URL? {
        URL(fileURLWithPath: "/tmp/\(recording.audioFileName)")
    }

    func exportTranscript(_ recording: Recording, format: ExportFormat) async throws -> URL {
        URL(fileURLWithPath: "/tmp/export.json")
    }

    func calculateTotalStorageUsed() async -> Int64 {
        1024
    }

    func availableStorage() async -> Int64 {
        stubAvailableStorage
    }
}
