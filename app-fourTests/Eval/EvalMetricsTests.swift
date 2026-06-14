import Testing
@testable import app_four

struct EvalMetricsTests {

    @Test func setCountsBasic() {
        let c = EvalCounts(expected: ["a", "b"], actual: ["b", "c"])
        #expect(c.tp == 1)   // b
        #expect(c.fp == 1)   // c
        #expect(c.fn == 1)   // a
    }

    @Test func scalarCounts() {
        #expect(EvalCounts(expectedScalar: "low", actualScalar: "low") == EvalCounts(tp: 1, fp: 0, fn: 0))
        #expect(EvalCounts(expectedScalar: "low", actualScalar: "flat") == EvalCounts(tp: 0, fp: 1, fn: 1))
        #expect(EvalCounts(expectedScalar: nil, actualScalar: "low") == EvalCounts(tp: 0, fp: 1, fn: 0))
        #expect(EvalCounts(expectedScalar: "low", actualScalar: nil) == EvalCounts(tp: 0, fp: 0, fn: 1))
        #expect(EvalCounts(expectedScalar: nil, actualScalar: nil) == EvalCounts(tp: 0, fp: 0, fn: 0))
    }

    @Test func precisionRecallAggregation() {
        var agg = EvalCounts(tp: 0, fp: 0, fn: 0)
        agg.add(EvalCounts(tp: 3, fp: 1, fn: 0))
        agg.add(EvalCounts(tp: 1, fp: 0, fn: 2))
        #expect(agg.precision == 0.8)          // 4 / (4+1)
        #expect(agg.recall == (4.0 / 6.0))     // 4 / (4+2)
    }

    @Test func emptyDenominatorsAreOne() {
        let c = EvalCounts(tp: 0, fp: 0, fn: 0)
        #expect(c.precision == 1.0)
        #expect(c.recall == 1.0)
    }
}
