import Foundation

/// Micro-averaged precision/recall counts for one tag category.
struct EvalCounts: Equatable {
    var tp: Int
    var fp: Int
    var fn: Int

    init(tp: Int, fp: Int, fn: Int) {
        self.tp = tp; self.fp = fp; self.fn = fn
    }

    /// Set-valued categories (feelings, activities, meds, topics).
    init(expected: Set<String>, actual: Set<String>) {
        tp = expected.intersection(actual).count
        fp = actual.subtracting(expected).count
        fn = expected.subtracting(actual).count
    }

    /// Scalar categories (mood, energy, focus, sleepHours-as-string).
    /// Wrong non-nil value counts as both a false positive and a false negative.
    init(expectedScalar: String?, actualScalar: String?) {
        switch (expectedScalar, actualScalar) {
        case (nil, nil):                  self.init(tp: 0, fp: 0, fn: 0)
        case (nil, .some):                self.init(tp: 0, fp: 1, fn: 0)
        case (.some, nil):                self.init(tp: 0, fp: 0, fn: 1)
        case let (.some(e), .some(a)):
            self.init(tp: e == a ? 1 : 0, fp: e == a ? 0 : 1, fn: e == a ? 0 : 1)
        }
    }

    mutating func add(_ other: EvalCounts) {
        tp += other.tp; fp += other.fp; fn += other.fn
    }

    var precision: Double { tp + fp == 0 ? 1.0 : Double(tp) / Double(tp + fp) }
    var recall: Double    { tp + fn == 0 ? 1.0 : Double(tp) / Double(tp + fn) }
}
