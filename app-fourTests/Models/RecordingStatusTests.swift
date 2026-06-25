import Testing
import Foundation
@testable import app_four

/// FOUND (Feature 015) — the `.pendingTranscription` status value that the
/// record-before-model-ready queue persists. A recording captured before the
/// model is ready must be representable as a distinct, Codable-round-trippable
/// state — never confused with `.transcribing`, `.failed`, or `.recorded`.
struct RecordingStatusTests {

    @Test func pendingTranscriptionRawValueIsStable() {
        #expect(RecordingStatus.pendingTranscription.rawValue == "pendingTranscription")
    }

    @Test func pendingTranscriptionRoundTripsThroughCodable() throws {
        let data = try JSONEncoder().encode(RecordingStatus.pendingTranscription)
        let decoded = try JSONDecoder().decode(RecordingStatus.self, from: data)
        #expect(decoded == .pendingTranscription)
    }

    @Test func pendingTranscriptionIsDistinctFromOtherStatuses() {
        #expect(RecordingStatus.pendingTranscription != .transcribing)
        #expect(RecordingStatus.pendingTranscription != .failed)
        #expect(RecordingStatus.pendingTranscription != .recorded)
        #expect(RecordingStatus.pendingTranscription != .completed)
        #expect(RecordingStatus.pendingTranscription != .placeholder)
    }
}
