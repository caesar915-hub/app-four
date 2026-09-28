import Testing
@testable import app_four

struct RangeSpanTests {
    @Test func wholeAverageBracketsOneSegment() {
        #expect(RangeSpan.segments(level: 3, isWhole: true) == 3...3)
    }

    @Test func fractionalAverageBracketsThePair() {
        #expect(RangeSpan.segments(level: 3, isWhole: false) == 3...4)
    }

    @Test func topLevelNeverOverflows() {
        #expect(RangeSpan.segments(level: 5, isWhole: false) == 5...5)
    }

    @Test func emptyAverageHasNoBracket() {
        #expect(RangeSpan.segments(level: 0, isWhole: true) == nil)
        #expect(RangeSpan.segments(level: 6, isWhole: false) == nil)
    }

    @Test func sentenceCaseTouchesOnlyTheFirstLetter() {
        #expect("mostly Okay".sentenceCased == "Mostly Okay")
        #expect("between Okay & Good".sentenceCased == "Between Okay & Good")
        #expect("".sentenceCased == "")
    }
}
