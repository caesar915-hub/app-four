import Testing
import Foundation
@testable import app_four
import SquirlLiveActivity

/// 037 / Foundational (T005) — RED-first for the pure `RecordingState → ContentState`
/// mapping (data-model §2) and the FR-016 privacy invariant. Per Constitution X:
/// confirm these FAIL without `RecordingActivityContentStateMapper` before trusting green.
@Suite struct LiveActivityContentStateTests {

    @Test func idleProducesNoActivity() {
        #expect(RecordingActivityContentStateMapper.contentState(for: .idle, pausedAt: nil) == nil)
    }

    @Test func recordingMapsToRecordingPhaseWithNoPause() {
        let cs = RecordingActivityContentStateMapper.contentState(for: .recording, pausedAt: nil)
        #expect(cs?.phase == .recording)
        #expect(cs?.pausedAt == nil)
    }

    @Test func pausedCarriesTheFreezeTimestamp() {
        let t = Date(timeIntervalSince1970: 1_700_000_000)
        let cs = RecordingActivityContentStateMapper.contentState(for: .paused, pausedAt: t)
        #expect(cs?.phase == .paused)
        #expect(cs?.pausedAt == t)
    }

    // Invariant (data-model §1): pausedAt is non-nil iff phase == .paused.
    @Test func recordingAndEndedNeverCarryAPauseTimestamp() {
        #expect(RecordingActivityContentStateMapper.contentState(for: .recording, pausedAt: Date())?.pausedAt == nil)
        #expect(RecordingActivityContentStateMapper.contentState(for: .done, pausedAt: Date())?.pausedAt == nil)
    }

    @Test func processingAndDoneMapToEnded() {
        #expect(RecordingActivityContentStateMapper.contentState(for: .processing, pausedAt: nil)?.phase == .ended)
        #expect(RecordingActivityContentStateMapper.contentState(for: .done, pausedAt: nil)?.phase == .ended)
    }

    // FR-016 / SC-006 / Constitution VI — the Lock Screen surface must never encode
    // transcript, mood, or medication content. Structurally guaranteed by the type;
    // pinned here so any future field that leaks content fails this test.
    @Test func contentStateEncodesNoSensitiveContent() throws {
        let cs = CheckInActivityAttributes.ContentState(phase: .recording, pausedAt: nil)
        let json = try #require(String(data: JSONEncoder().encode(cs), encoding: .utf8))
        #expect(!json.localizedCaseInsensitiveContains("transcript"))
        #expect(!json.localizedCaseInsensitiveContains("mood"))
        #expect(!json.localizedCaseInsensitiveContains("medication"))
        #expect(!json.localizedCaseInsensitiveContains("dose"))
    }
}
