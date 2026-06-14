import Foundation
@testable import app_four

actor MockAudioRecordingService: AudioRecordingService {
    nonisolated var audioLevelStream: AsyncStream<Float> {
        AsyncStream { continuation in continuation.finish() }
    }

    var permissionGranted = true
    var shouldThrowError = false

    var startRecordingCalled = false
    var stopRecordingCalled = false
    var cancelRecordingCalled = false

    func setPermissionGranted(_ value: Bool) {
        permissionGranted = value
    }

    func requestPermission() async -> Bool {
        permissionGranted
    }

    func startRecording() async throws -> URL {
        if shouldThrowError { throw RecordingError.unknown }
        startRecordingCalled = true
        return URL(fileURLWithPath: "/tmp/mock.m4a")
    }

    func pauseRecording() async {}

    func resumeRecording() async throws {
        if shouldThrowError { throw RecordingError.unknown }
    }

    func stopRecording() async throws -> (fileURL: URL, duration: TimeInterval) {
        if shouldThrowError { throw RecordingError.unknown }
        stopRecordingCalled = true
        return (URL(fileURLWithPath: "/tmp/mock.m4a"), 10.0)
    }

    func cancelRecording() async {
        cancelRecordingCalled = true
    }
}
