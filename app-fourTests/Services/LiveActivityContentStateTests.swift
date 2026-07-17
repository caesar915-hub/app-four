import Testing
import Foundation
@testable import app_four
import SquirlLiveActivity

/// 037 / Foundational (T005) — RED-first for the pure `RecordingState → ContentState`
/// mapping (data-model §2) and the FR-016 privacy invariant. Per Constitution X:
/// confirm these FAIL without `RecordingActivityContentStateMapper` before trusting green.
@Suite struct LiveActivityContentStateTests {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func idleProducesNoActivity() {
        #expect(RecordingActivityContentStateMapper.contentState(for: .idle, startedAt: t0, pausedAt: nil) == nil)
    }

    @Test func recordingCarriesTheAnchorAndNoPause() {
        let cs = RecordingActivityContentStateMapper.contentState(for: .recording, startedAt: t0, pausedAt: nil)
        #expect(cs?.phase == .recording)
        #expect(cs?.startedAt == t0)
        #expect(cs?.pausedAt == nil)
    }

    @Test func pausedCarriesTheFreezeTimestamp() {
        let pausedAt = t0.addingTimeInterval(120)
        let cs = RecordingActivityContentStateMapper.contentState(for: .paused, startedAt: t0, pausedAt: pausedAt)
        #expect(cs?.phase == .paused)
        #expect(cs?.startedAt == t0)
        #expect(cs?.pausedAt == pausedAt)
    }

    // Invariant (data-model §1): pausedAt is non-nil iff phase == .paused.
    @Test func recordingAndEndedNeverCarryAPauseTimestamp() {
        let now = Date()
        #expect(RecordingActivityContentStateMapper.contentState(for: .recording, startedAt: t0, pausedAt: now)?.pausedAt == nil)
        #expect(RecordingActivityContentStateMapper.contentState(for: .done, startedAt: t0, pausedAt: now)?.pausedAt == nil)
    }

    @Test func processingAndDoneMapToEnded() {
        #expect(RecordingActivityContentStateMapper.contentState(for: .processing, startedAt: t0, pausedAt: nil)?.phase == .ended)
        #expect(RecordingActivityContentStateMapper.contentState(for: .done, startedAt: t0, pausedAt: nil)?.phase == .ended)
    }

    // FR-016 / SC-006 / Constitution VI — the Lock Screen surface must never encode
    // transcript, mood, or medication content. Structurally guaranteed by the type;
    // pinned here so any future field that leaks content fails this test.
    @Test func contentStateEncodesNoSensitiveContent() throws {
        let cs = CheckInActivityAttributes.ContentState(startedAt: t0, phase: .recording, pausedAt: nil)
        let json = try #require(String(data: JSONEncoder().encode(cs), encoding: .utf8))
        #expect(!json.localizedCaseInsensitiveContains("transcript"))
        #expect(!json.localizedCaseInsensitiveContains("mood"))
        #expect(!json.localizedCaseInsensitiveContains("medication"))
        #expect(!json.localizedCaseInsensitiveContains("dose"))
    }
}
