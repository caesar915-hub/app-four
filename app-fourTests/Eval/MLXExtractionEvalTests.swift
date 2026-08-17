import Testing
import Foundation
import SquirlSignals
@testable import app_four

/// Regression floors for the MLX (LLM) extraction eval, initialized from the
/// first green on-device run (2026-08-17, iPhone 12 Pro, current tuning).
/// Same convention as `EvalFloors`: observed − 0.02, raise never lower.
enum MLXEvalFloors {
    static let mood           = (precision: 0.56, recall: 0.83)
    static let energy         = (precision: 0.12, recall: 0.44)
    static let focus          = (precision: 0.29, recall: 0.73)
    static let emotions       = (precision: 0.24, recall: 0.98)
    static let activities     = (precision: 0.98, recall: 0.00)
    static let meds           = (precision: 0.92, recall: 0.92)
    static let sleepHours     = (precision: 0.36, recall: 0.98)
    static let topics         = (precision: 0.11, recall: 0.64)
    static let sideEffectFlag = (precision: 0.98, recall: 0.12)
}

/// Eval gate: gated suites only run when explicitly requested (MLX_EVAL=1) AND
/// the LLM model is installed — otherwise the default test run would burn
/// ~15–20 min of on-device inference.
enum MLXEvalGate {
    static let isEnabled: Bool = {
        guard ProcessInfo.processInfo.environment["MLX_EVAL"] == "1" else { return false }
        return AIModelServiceImpl.findLLMModelDirectory(in: ModelConstants.llmDownloadBase) != nil
    }()
}

/// Runs `MLXEvalSet` through the real two-pass `MLXJournalService` (real model,
/// real prompts, real validator) and reports per-category precision/recall
/// reusing `EvalCounts`. Hard-gate cases (`tuned-*`) are asserted exactly;
/// the rest feed the metrics report.
///
/// Run on device with:
///   xcodebuild test -scheme app-four -testPlan app-four-mlx-eval \
///     -destination 'platform=iOS,id=<udid>' \
///     -only-testing:app-fourTests/MLXExtractionEvalTests
/// Optional subset filter: MLX_EVAL_FILTER=tuned (case-id prefix).
@Suite("MLX extraction eval (gated)", .enabled(if: MLXEvalGate.isEnabled))
struct MLXExtractionEvalTests {

    private struct Outcome {
        let evalCase: MLXEvalCase
        let result: SummaryResult
        let seconds: Double
    }

    @Test func tunedPipelineMatchesExpectations() async throws {
        let filter = ProcessInfo.processInfo.environment["MLX_EVAL_FILTER"]
        let cases = MLXEvalSet.cases.filter { filter == nil || $0.id.hasPrefix(filter!) }
        try #require(!cases.isEmpty, "MLX_EVAL_FILTER=\(filter ?? "nil") matched no cases")

        let service = MLXJournalService()
        var outcomes: [Outcome] = []

        for c in cases {
            let start = ContinuousClock.now
            let result = try await service.summarize(rawTranscription: c.transcript)
            let elapsed = ContinuousClock.now - start
            let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            outcomes.append(Outcome(evalCase: c, result: result, seconds: seconds))
            print(Self.caseLine(c, result, seconds))
        }

        // MARK: Metrics (micro-averaged P/R per category, overall + per language)
        var overall = CategoryCounts()
        var perLanguage: [String: CategoryCounts] = [:]
        for o in outcomes {
            overall.add(o.evalCase, o.result)
            perLanguage[o.evalCase.language, default: CategoryCounts()].add(o.evalCase, o.result)
        }

        print(overall.report(header: "EVAL-SUMMARY"))
        for lang in perLanguage.keys.sorted() {
            print(perLanguage[lang]!.report(header: "EVAL-LANG|\(lang)"))
        }

        let latencies = outcomes.map(\.seconds).sorted()
        let avg = latencies.reduce(0, +) / Double(latencies.count)
        let p95 = latencies[min(latencies.count - 1, Int(ceil(Double(latencies.count) * 0.95)) - 1)]
        print(String(format: "EVAL-LATENCY|cases=%d|avg=%.1fs|p95=%.1fs|max=%.1fs",
                     latencies.count, avg, p95, latencies.last ?? 0))

        // MARK: Regression floors (full run only — filtered subsets skew P/R)
        if filter == nil {
            let checks: [(String, EvalCounts, (precision: Double, recall: Double))] = [
                ("mood", overall.mood, MLXEvalFloors.mood),
                ("energy", overall.energy, MLXEvalFloors.energy),
                ("focus", overall.focus, MLXEvalFloors.focus),
                ("emotions", overall.emotions, MLXEvalFloors.emotions),
                ("activities", overall.activities, MLXEvalFloors.activities),
                ("meds", overall.meds, MLXEvalFloors.meds),
                ("sleepHours", overall.sleepHours, MLXEvalFloors.sleepHours),
                ("topics", overall.topics, MLXEvalFloors.topics),
                ("sideEffectFlag", overall.sideEffectFlag, MLXEvalFloors.sideEffectFlag),
            ]
            for (name, counts, floor) in checks {
                #expect(counts.precision >= floor.precision,
                        "\(name) precision \(counts.precision) below MLX floor \(floor.precision)")
                #expect(counts.recall >= floor.recall,
                        "\(name) recall \(counts.recall) below MLX floor \(floor.recall)")
            }
        }

        // MARK: Hard gate — the deterministic tuning behaviors
        for o in outcomes where o.evalCase.hardGate {
            Self.assertHardGate(o.evalCase, o.result)
        }
    }

    // MARK: - Per-case log line

    /// Activities live on the assembled `NoteExtraction`, not on `SummaryResult`.
    private static func activities(of r: SummaryResult) -> Set<String> {
        Set(r.noteExtraction?.activities ?? [])
    }

    private static func caseLine(_ c: MLXEvalCase, _ r: SummaryResult, _ seconds: Double) -> String {
        var diffs: [String] = []
        if r.mood != c.mood { diffs.append("mood exp=\(c.mood ?? "nil") got=\(r.mood ?? "nil")") }
        if r.energyLevel != c.energy?.rawValue { diffs.append("energy exp=\(c.energy?.rawValue ?? "nil") got=\(r.energyLevel ?? "nil")") }
        if r.focusLevel != c.focus?.rawValue { diffs.append("focus exp=\(c.focus?.rawValue ?? "nil") got=\(r.focusLevel ?? "nil")") }
        if Set(r.emotions) != c.emotions { diffs.append("emotions exp=\(c.emotions.sorted()) got=\(r.emotions)") }
        if Self.activities(of: r) != c.activities { diffs.append("activities exp=\(c.activities.sorted()) got=\(Self.activities(of: r).sorted())") }
        if Set(r.medications.map(\.name)) != c.medNames { diffs.append("meds exp=\(c.medNames.sorted()) got=\(r.medications.map(\.name))") }
        if r.sleepHours != c.sleepHours { diffs.append("sleepHours exp=\(c.sleepHours.map { String($0) } ?? "nil") got=\(r.sleepHours.map { String($0) } ?? "nil")") }
        if Set(r.topics) != c.topics { diffs.append("topics exp=\(c.topics.sorted()) got=\(r.topics)") }
        if !r.sideEffects.isEmpty != c.anySideEffect { diffs.append("sideFx exp=\(c.anySideEffect) got=\(!r.sideEffects.isEmpty)") }
        let status = diffs.isEmpty ? "OK" : "DIFF " + diffs.joined(separator: "; ")
        return String(format: "EVAL-CASE|%@|%@|%.1fs|%@", c.id, c.language, seconds, status)
    }

    // MARK: - Hard-gate assertions

    private static func assertHardGate(_ c: MLXEvalCase, _ r: SummaryResult) {
        if let mood = c.mood, !c.softFields.contains("mood") {
            #expect(r.mood == mood, "\(c.id): mood expected \(mood), got \(r.mood ?? "nil")")
        }
        if let energy = c.energy, !c.softFields.contains("energy") {
            if let alternatives = c.energyAlternatives {
                let accepted = alternatives.map(\.rawValue)
                #expect(accepted.contains(r.energyLevel ?? ""),
                        "\(c.id): energy expected one of \(accepted), got \(r.energyLevel ?? "nil")")
            } else {
                #expect(r.energyLevel == energy.rawValue,
                        "\(c.id): energy expected \(energy.rawValue), got \(r.energyLevel ?? "nil")")
            }
        }
        if let focus = c.focus, !c.softFields.contains("focus") {
            #expect(r.focusLevel == focus.rawValue,
                    "\(c.id): focus expected \(focus.rawValue), got \(r.focusLevel ?? "nil")")
        }
        if !c.medNames.isEmpty {
            #expect(Set(r.medications.map(\.name)) == c.medNames,
                    "\(c.id): meds expected \(c.medNames.sorted()), got \(r.medications.map(\.name))")
        }
        for (name, taken) in c.medTaken {
            let actual = r.medications.first(where: { $0.name == name })?.taken
            #expect(actual == taken, "\(c.id): \(name) taken expected \(taken), got \(actual.map { String($0) } ?? "nil")")
        }
        for field in c.assertNil {
            switch field {
            case "mood":        #expect(r.mood == nil, "\(c.id): mood expected nil, got \(r.mood ?? "nil")")
            case "energy":      #expect(r.energyLevel == nil, "\(c.id): energy expected nil, got \(r.energyLevel ?? "nil")")
            case "focus":       #expect(r.focusLevel == nil, "\(c.id): focus expected nil, got \(r.focusLevel ?? "nil")")
            case "emotions":    #expect(r.emotions.isEmpty, "\(c.id): emotions expected empty, got \(r.emotions)")
            case "activities":  #expect(Self.activities(of: r).isEmpty, "\(c.id): activities expected empty, got \(Self.activities(of: r).sorted())")
            case "medications": #expect(r.medications.isEmpty, "\(c.id): medications expected empty, got \(r.medications.map(\.name))")
            case "sleepHours":  #expect(r.sleepHours == nil, "\(c.id): sleepHours expected nil")
            case "topics":      #expect(r.topics.isEmpty, "\(c.id): topics expected empty, got \(r.topics)")
            case "sideEffects": #expect(r.sideEffects.isEmpty, "\(c.id): sideEffects expected empty, got \(r.sideEffects)")
            default: break
            }
        }
    }

    // MARK: - Category accumulation

    private struct CategoryCounts {
        var mood = EvalCounts(tp: 0, fp: 0, fn: 0)
        var energy = EvalCounts(tp: 0, fp: 0, fn: 0)
        var focus = EvalCounts(tp: 0, fp: 0, fn: 0)
        var emotions = EvalCounts(tp: 0, fp: 0, fn: 0)
        var activities = EvalCounts(tp: 0, fp: 0, fn: 0)
        var meds = EvalCounts(tp: 0, fp: 0, fn: 0)
        var sleepHours = EvalCounts(tp: 0, fp: 0, fn: 0)
        var topics = EvalCounts(tp: 0, fp: 0, fn: 0)
        var sideEffectFlag = EvalCounts(tp: 0, fp: 0, fn: 0)

        mutating func add(_ c: MLXEvalCase, _ r: SummaryResult) {
            mood.add(.init(expectedScalar: c.mood, actualScalar: r.mood))
            energy.add(.init(expectedScalar: c.energy?.rawValue, actualScalar: r.energyLevel))
            focus.add(.init(expectedScalar: c.focus?.rawValue, actualScalar: r.focusLevel))
            emotions.add(.init(expected: c.emotions, actual: Set(r.emotions)))
            activities.add(.init(expected: c.activities, actual: MLXExtractionEvalTests.activities(of: r)))
            meds.add(.init(expected: c.medNames, actual: Set(r.medications.map(\.name))))
            sleepHours.add(.init(expectedScalar: c.sleepHours.map { String($0) },
                                 actualScalar: r.sleepHours.map { String($0) }))
            topics.add(.init(expected: c.topics, actual: Set(r.topics)))
            sideEffectFlag.add(.init(expectedScalar: c.anySideEffect ? "yes" : nil,
                                     actualScalar: r.sideEffects.isEmpty ? nil : "yes"))
        }

        func report(header: String) -> String {
            func line(_ name: String, _ c: EvalCounts) -> String {
                String(format: "%@|%@|P=%.3f|R=%.3f|tp=%d fp=%d fn=%d",
                       header, name, c.precision, c.recall, c.tp, c.fp, c.fn)
            }
            return [
                line("mood", mood), line("energy", energy), line("focus", focus),
                line("emotions", emotions), line("activities", activities), line("meds", meds),
                line("sleepHours", sleepHours), line("topics", topics), line("sideEffectFlag", sideEffectFlag),
            ].joined(separator: "\n")
        }
    }
}
