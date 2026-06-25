import Testing
import Foundation
@testable import app_four

/// Regression floors. Raise (never lower) as tasks land. Baseline captured in Task 2 Step 5;
/// precision ratcheted in Task 5 (common-word guards + longest-match mood) to observed − 0.02.
enum EvalFloors {
    // Ratcheted Task 10: activities moved to lexicon-as-data + 5 new categories added.
    // All floors raised to observed − 0.02; never lowered.
    static let mood            = (precision: 0.730, recall: 0.580)
    static let energy          = (precision: 0.647, recall: 0.230)
    static let focus           = (precision: 0.380, recall: 0.313)
    static let emotions        = (precision: 0.920, recall: 0.647)
    static let activities      = (precision: 0.280, recall: 0.409)
    static let meds            = (precision: 0.980, recall: 0.980)
    static let sleepHours      = (precision: 0.980, recall: 0.266)
    static let topics          = (precision: 0.880, recall: 0.763)
    static let sideEffectFlag  = (precision: 0.730, recall: 0.409)
}

struct ExtractionEvalTests {

    struct CategoryResult {
        let name: String
        var counts = EvalCounts(tp: 0, fp: 0, fn: 0)
        let floor: (precision: Double, recall: Double)
    }

    static func runEval() -> [CategoryResult] {
        let extractor = NLNoteExtractor(lexicon: LexiconLoader.loadBundled(overlay: nil))
        var mood = CategoryResult(name: "mood", floor: EvalFloors.mood)
        var energy = CategoryResult(name: "energy", floor: EvalFloors.energy)
        var focus = CategoryResult(name: "focus", floor: EvalFloors.focus)
        var emotions = CategoryResult(name: "emotions", floor: EvalFloors.emotions)
        var activities = CategoryResult(name: "activities", floor: EvalFloors.activities)
        var meds = CategoryResult(name: "meds", floor: EvalFloors.meds)
        var sleep = CategoryResult(name: "sleepHours", floor: EvalFloors.sleepHours)
        var topicsCat = CategoryResult(name: "topics", floor: EvalFloors.topics)
        var sideFx = CategoryResult(name: "sideEffectFlag", floor: EvalFloors.sideEffectFlag)

        for c in EvalSet.cases {
            let r = extractor.extract(from: c.transcript)
            mood.counts.add(.init(expectedScalar: c.mood, actualScalar: r.mood))
            energy.counts.add(.init(expectedScalar: c.energy?.rawValue, actualScalar: r.energy?.rawValue))
            focus.counts.add(.init(expectedScalar: c.focus?.rawValue, actualScalar: r.focus?.rawValue))
            emotions.counts.add(.init(expected: c.emotions, actual: Set(r.emotions)))
            activities.counts.add(.init(expected: c.activities, actual: Set(r.activities)))
            meds.counts.add(.init(expected: c.medNames, actual: Set(r.medications.map(\.name))))
            sleep.counts.add(.init(expectedScalar: c.sleepHours.map { String($0) },
                                   actualScalar: r.sleepHours.map { String($0) }))
            topicsCat.counts.add(.init(expected: c.topics,
                                       actual: Set(NLSummarizationService.deriveTopics(from: r))))
            let actualSideFx = !(r.sideEffects.isEmpty && r.physicalSideEffects.isEmpty)
            sideFx.counts.add(.init(expectedScalar: c.anySideEffect ? "yes" : nil,
                                    actualScalar: actualSideFx ? "yes" : nil))
        }
        return [mood, energy, focus, emotions, activities, meds, sleep, topicsCat, sideFx]
    }

    @Test func metricsMeetFloors() {
        for cat in Self.runEval() {
            #expect(cat.counts.precision >= cat.floor.precision,
                    "\(cat.name) precision \(cat.counts.precision) below floor \(cat.floor.precision)")
            #expect(cat.counts.recall >= cat.floor.recall,
                    "\(cat.name) recall \(cat.counts.recall) below floor \(cat.floor.recall)")
        }
    }

    /// Manual metrics dump: run with EVAL_REPORT=1 in the env.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["EVAL_REPORT"] == "1"))
    func report() {
        let lines = Self.runEval().map { c in
            let p = String(format: "%.3f", c.counts.precision)
            let r = String(format: "%.3f", c.counts.recall)
            return "\(c.name): P=\(p) R=\(r) (tp\(c.counts.tp) fp\(c.counts.fp) fn\(c.counts.fn))"
        }
        Issue.record(Comment(rawValue: "EVAL REPORT\n" + lines.joined(separator: "\n")))
    }
}
