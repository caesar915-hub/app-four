import Testing
import Foundation
@testable import app_four

/// 037 / T006 — the process-level coordinator's control flow, against mocks for the
/// session (the finalize pipeline) and the ActivityKit surface. Verifies delegation,
/// idempotency, the terminal release, and that a Lock-Screen tap with no live session
/// is a safe no-op (the data-loss guard the review surfaced). Timing of the resume
/// re-anchor is a device-QA concern (elapsed == recorded); here we assert the call flow.
@Suite @MainActor
struct RecordingSessionControllerTests {

    // MARK: Mocks

    final class MockCheckInSession: CheckInSession {
        var state: RecordingState
        var stopCalled = 0
        var pauseCalled = 0
        var resumeCalled = 0
        init(state: RecordingState = .recording) { self.state = state }
        @discardableResult func stopRecording() -> Task<Void, Never> {
            stopCalled += 1; state = .processing; return Task {}
        }
        func pauseCapture() async { pauseCalled += 1; state = .paused }
        func resumeCapture() async throws { resumeCalled += 1; state = .recording }
    }

    final class MockLiveActivityController: LiveActivityController {
        var beginCalled = 0
        var updates: [(state: RecordingState, pausedAt: Date?)] = []
        var endCalled = 0
        var endAllStaleCalled = 0
        func begin(startedAt: Date, cap: TimeInterval) async { beginCalled += 1 }
        func update(for state: RecordingState, startedAt: Date, pausedAt: Date?) async {
            updates.append((state, pausedAt))
        }
        func end() async { endCalled += 1 }
        func endAllStale() async { endAllStaleCalled += 1 }
    }

    private func makeSUT() -> (RecordingSessionControllerImpl, MockCheckInSession, MockLiveActivityController) {
        let la = MockLiveActivityController()
        let session = MockCheckInSession()
        let sut = RecordingSessionControllerImpl(liveActivity: la)
        return (sut, session, la)
    }

    // MARK: Lifecycle

    @Test func recordingDidStartBeginsTheSurface() async {
        let (sut, session, la) = makeSUT()
        await sut.recordingDidStart(session, startedAt: .now, cap: 480)
        #expect(la.beginCalled == 1)
    }

    @Test func recordingDidFinishEndsAndReleasesTheSession() async {
        let (sut, session, la) = makeSUT()
        await sut.recordingDidStart(session, startedAt: .now, cap: 480)
        await sut.recordingDidFinish()
        #expect(la.endCalled == 1)
        // Session released → a later Lock-Screen stop no-ops (no double finalize).
        await sut.stopAndSave()
        #expect(session.stopCalled == 0)
    }

    // MARK: Stop (idempotency + the no-session guard)

    @Test func stopAndSaveDelegatesToTheSessionExactlyOnce() async {
        let (sut, session, _) = makeSUT()
        await sut.recordingDidStart(session, startedAt: .now, cap: 480)
        await sut.stopAndSave()
        #expect(session.stopCalled == 1)
        // A racing / repeated stop is a no-op once finalizing.
        await sut.stopAndSave()
        #expect(session.stopCalled == 1)
    }

    @Test func stopAndSaveWithoutASessionIsASafeNoOp() async {
        let (sut, _, _) = makeSUT()
        await sut.stopAndSave()   // must not crash (no session attached)
    }

    @Test func stopAndSaveIsANoOpOnceProcessing() async {
        let (sut, session, _) = makeSUT()
        session.state = .processing
        await sut.recordingDidStart(session, startedAt: .now, cap: 480)
        await sut.stopAndSave()
        #expect(session.stopCalled == 0)  // guard rejects a non-recording/paused state
    }

    // MARK: Pause / resume

    @Test func pauseFreezesTheSurfaceWithAFreezeStamp() async {
        let (sut, session, la) = makeSUT()
        await sut.recordingDidStart(session, startedAt: .now, cap: 480)
        await sut.pause()
        #expect(session.pauseCalled == 1)
        #expect(la.updates.last?.state == .paused)
        #expect(la.updates.last?.pausedAt != nil)
    }

    @Test func resumeClearsTheFreezeAndReturnsToRecording() async throws {
        let (sut, session, la) = makeSUT()
        await sut.recordingDidStart(session, startedAt: .now, cap: 480)
        await sut.pause()
        try await sut.resume()
        #expect(session.resumeCalled == 1)
        #expect(la.updates.last?.state == .recording)
        #expect(la.updates.last?.pausedAt == nil)
    }

    @Test func pauseIsARejectedWhenNotRecording() async {
        let (sut, session, _) = makeSUT()
        session.state = .paused
        await sut.recordingDidStart(session, startedAt: .now, cap: 480)
        await sut.pause()
        #expect(session.pauseCalled == 0)  // guard requires .recording
    }

    // MARK: Recovery

    @Test func recoverIfNeededEndsStaleSurfaces() async {
        let (sut, _, la) = makeSUT()
        await sut.recoverIfNeeded()
        #expect(la.endAllStaleCalled == 1)
    }
}
