import Testing
@testable import app_four

@MainActor
struct RecordingDisplayTitleTests {

    @Test func showsTranscribingPlaceholderWhileInProgress() {
        let recording = Recording(audioFileName: "a.m4a", duration: 10, title: "Real title", hasMedication: false)
        recording.status = .transcribing
        #expect(recording.displayTitle == "Transcribing…")
    }

    @Test func showsRealTitleWhenNotInProgress() {
        let recording = Recording(audioFileName: "a.m4a", duration: 10, title: "Real title", hasMedication: false)
        recording.status = .completed
        #expect(recording.displayTitle == "Real title")
        recording.status = .failed
        #expect(recording.displayTitle == "Real title")
    }
}
