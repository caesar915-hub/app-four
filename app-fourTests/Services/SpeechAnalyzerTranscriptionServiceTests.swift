import Foundation
import Testing
@testable import app_four

/// 045 / T004 — pure result→DTO mapping for the SpeechAnalyzer engine. These are the
/// engine's testable seams; the analyzer itself cannot run on the Simulator, so the
/// mapping/cleaning/error rules are verified here in isolation.
@Suite struct SpeechAnalyzerTranscriptionServiceTests {

    @Test func cleanTextTrimsAndCollapsesWhitespace() {
        #expect(SpeechAnalyzerTranscriptionService.cleanText("  hello   world  ") == "hello world")
        #expect(SpeechAnalyzerTranscriptionService.cleanText("\n a\tb \n") == "a b")
    }

    @Test func finalSegmentCarriesTextAndTimesAndIsFinal() {
        let seg = SpeechAnalyzerTranscriptionService.makeFinalSegment(text: "  the quick brown fox ", start: 0, end: 2.5)
        #expect(seg.text == "the quick brown fox")
        #expect(seg.isFinal)
        #expect(!seg.isError)
        #expect(seg.startTime == 0)
        #expect(seg.endTime == 2.5)
    }

    @Test func emptyFinalBecomesNoSpeechNotError() {
        let seg = SpeechAnalyzerTranscriptionService.makeFinalSegment(text: "   \n ", start: 0, end: 1)
        #expect(seg.text == "(no speech detected)")
        #expect(seg.isFinal)
        #expect(!seg.isError)
    }

    @Test func errorSegmentIsFlaggedAndFinal() {
        let seg = SpeechAnalyzerTranscriptionService.errorSegment("boom")
        #expect(seg.isError)
        #expect(seg.isFinal)
        #expect(seg.text.contains("boom"))
    }

    @Test func progressSegmentIsNonFinalAndNotError() {
        let seg = SpeechAnalyzerTranscriptionService.progressSegment("Transcribing…")
        #expect(!seg.isFinal)
        #expect(!seg.isError)
        #expect(seg.text == "Transcribing…")
    }
}
