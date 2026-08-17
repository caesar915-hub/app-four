import Testing
import Foundation
import SquirlSignals
@testable import app_four

/// Regression floors for the MLX (LLM) extraction eval, recalibrated on the
/// 2026-08-17-c on-device run (iPhone 12 Pro). Same convention as `EvalFloors`:
/// observed − 0.02, raise never lower. Two deliberate resets vs the -b run:
/// activities and sideEffectFlag precision were ~1.0 only because the pipeline
/// never fired — the -c tuning made them fire (recall 0→0.857), so their
/// precision floors were recalibrated to observed − 0.02 (owner-approved).
enum MLXEvalFloors {
    static let mood           = (precision: 0.56, recall: 0.83)
    static let energy         = (precision: 0.31, recall: 0.44)
    static let focus          = (precision: 0.29, recall: 0.73)
    static let emotions       = (precision: 0.27, recall: 0.98)
    static let activities     = (precision: 0.31, recall: 0.83)
    static let meds           = (precision: 0.98, recall: 0.98)
    static let sleepHours     = (precision: 0.75, recall: 0.98)
    static let topics         = (precision: 0.45, recall: 0.98)
    static let sideEffectFlag = (precision: 0.73, recall: 0.83)
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
///
/// The T036 memory gate (`modelLoadAndEvictionReclaimsMemory`) lives here too —
/// merged from the former `MLXMemoryGateTests` suite so both gated tests share
/// one `.serialized` suite instead of two parallel suites each loading the
/// ~1 GB model in-process.
@Suite("MLX extraction eval (gated)", .enabled(if: MLXEvalGate.isEnabled), .serialized)
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

    /// T036 (spec 044) device gate: prove with the **real** model on a **real**
    /// device that (a) loading the LLM consumes roughly its expected footprint and
    /// (b) eviction actually reclaims it. The notification-driven paths (background
    /// / memory-warning / 180 s idle / re-arm cancellation) are covered with
    /// lifecycle hooks by `MLXJournalServiceTests`; this test adds the numbers.
    @Test func modelLoadAndEvictionReclaimsMemory() async throws {
        let service = MLXJournalService()

        let baselineMB = Double(os_proc_available_memory()) / (1024 * 1024)

        // Real two-pass inference → real model load.
        _ = try await service.summarize(
            rawTranscription: "Feeling good today, took my Concerta this morning."
        )
        #expect(await service.isModelLoaded)
        let loadedMB = Double(os_proc_available_memory()) / (1024 * 1024)

        let reclaimed = await service.modelHolder.evict()
        #expect(reclaimed)
        #expect(await service.isModelLoaded == false)
        let evictedMB = Double(os_proc_available_memory()) / (1024 * 1024)

        // Metal buffer teardown is asynchronous on the GPU driver — poll up to
        // 10 s for the reclamation to settle before judging it.
        var settledMB = evictedMB
        for _ in 0..<20 {
            if settledMB - loadedMB >= 400 { break }
            try? await Task.sleep(for: .milliseconds(500))
            let sample = Double(os_proc_available_memory()) / (1024 * 1024)
            settledMB = max(settledMB, sample)
        }

        let loadDropMB = baselineMB - loadedMB
        let reclaimedMB = settledMB - loadedMB
        print(String(format: "T036|baseline=%.0fMB|loaded=%.0fMB|afterEvict=%.0fMB|settled=%.0fMB|loadDrop=%.0fMB|reclaimed=%.0fMB",
                     baselineMB, loadedMB, evictedMB, settledMB, loadDropMB, reclaimedMB))

        // The 4-bit 1.5B model + KV cache should cost on the order of 1 GB;
        // assert conservatively (≥400 MB) to stay robust against jetsam-headroom noise.
        #expect(loadDropMB >= 400,
                "model load should drop available memory by ≥400 MB (got \(Int(loadDropMB)) MB)")
        #expect(reclaimedMB >= 400,
                "eviction should reclaim ≥400 MB within 10 s (got \(Int(reclaimedMB)) MB)")
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
