import Testing
import AVFoundation
@testable import app_four

/// The interruption decision policy is a pure function, so it can be tested
/// without a microphone or a live AVAudioSession. The AVFoundation side effects
/// (pause/resume the recorder) are device-only and verified by hand.
struct AudioInterruptionPolicyTests {

    @Test func beganWhileRecordingPauses() {
        #expect(AudioRecordingServiceImpl.interruptionResponse(
            type: .began, options: [], isRecording: true, wasInterrupted: false) == .pause)
    }

    @Test func beganWhileNotRecordingIsIgnored() {
        #expect(AudioRecordingServiceImpl.interruptionResponse(
            type: .began, options: [], isRecording: false, wasInterrupted: false) == .ignore)
    }

    @Test func endedWithShouldResumeResumes() {
        #expect(AudioRecordingServiceImpl.interruptionResponse(
            type: .ended, options: .shouldResume, isRecording: false, wasInterrupted: true) == .resume)
    }

    @Test func endedWithoutShouldResumeStaysPaused() {
        // Recording is preserved (not discarded) even when the system says don't resume.
        #expect(AudioRecordingServiceImpl.interruptionResponse(
            type: .ended, options: [], isRecording: false, wasInterrupted: true) == .stayPaused)
    }

    @Test func endedWithoutPriorPauseIsIgnored() {
        // An .ended for an interruption that began before we started recording.
        #expect(AudioRecordingServiceImpl.interruptionResponse(
            type: .ended, options: .shouldResume, isRecording: false, wasInterrupted: false) == .ignore)
    }
}
