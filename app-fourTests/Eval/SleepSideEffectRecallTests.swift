import Testing
import Foundation
@testable import app_four

/// Recall regression tests for the sleep-hours parser + side-effect phrasing fix
/// (fix/extractor-recall). Grounded in real journal phrasings the lexicon/regex
/// previously missed. Precision-guard included: a non-sleep duration must NOT
/// become sleep hours.
struct SleepHoursRecallTests {
    let ex = NLNoteExtractor(lexicon: LexiconLoader.loadBundled(overlay: nil))

    @Test func parsesAbbreviatedHours() {
        #expect(ex.extract(from: "sleep was good 8 hrs").sleepHours == 8)
        #expect(ex.extract(from: "elvanse 40 today. sleep 6hrs woke up groggy.").sleepHours == 6)
    }

    @Test func parsesSpelledOutHours() {
        #expect(ex.extract(from: "Sleep was solid, around eight hours.").sleepHours == 8)
        #expect(ex.extract(from: "I slept five and a half hours, neighbour's dog again.").sleepHours == 5.5)
    }

    @Test func parsesBareSleepNumber() {
        #expect(ex.extract(from: "concerta 36mg. sleep 7. focus good.").sleepHours == 7)
    }

    /// Precision guard: "three-hour lab session" lives in a non-sleep sentence and
    /// must never be read as a sleep duration.
    @Test func ignoresNonSleepDurations() {
        #expect(ex.extract(from: "Energy held steady through a three-hour lab session.").sleepHours == nil)
        #expect(ex.extract(from: "Sat through a two hour planning meeting.").sleepHours == nil)
    }
}

struct SideEffectPhrasingTests {
    let ex = NLNoteExtractor(lexicon: LexiconLoader.loadBundled(overlay: nil))

    private func hasSideEffect(_ s: String) -> Bool {
        let r = ex.extract(from: s)
        return !(r.sideEffects.isEmpty && r.physicalSideEffects.isEmpty)
    }

    @Test func detectsJawClench() {
        #expect(hasSideEffect("small jaw clench when i was stressed about a bug"))
        #expect(hasSideEffect("some mild jaw tension toward the evening"))
    }

    @Test func detectsRacingHeart() {
        #expect(hasSideEffect("heart sped up a bit running for the train"))
        #expect(hasSideEffect("a slightly racing heart mid-morning"))
    }

    @Test func detectsAppetiteReduction() {
        #expect(hasSideEffect("a slightly reduced appetite at lunch"))
        #expect(hasSideEffect("mild appetite reduction and a touch of jaw tension"))
    }
}
