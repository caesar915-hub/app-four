import Testing
import Foundation
import SquirlSignals
@testable import app_four

/// Eval gate: runs ONLY when explicitly requested (`GEMMA_EVAL=1`) AND the Gemma
/// `.litertlm` model is installed. Otherwise skipped — the default plan (and the
/// simulator) never load the runtime. Requires the LiteRTLM package on device.
enum GemmaEvalGate {
    static let isEnabled: Bool = {
        guard ProcessInfo.processInfo.environment["GEMMA_EVAL"] == "1" else { return false }
        return AIModelServiceImpl.gemmaLiteRTModelInstalled(in: ModelConstants.llmDownloadBase)
    }()
}

/// Device-only smoke + quality + memory gate for the Gemma 4 / LiteRT backend.
/// Reuses the shared `MLXEvalSet.cases` and runs the real two-pass
/// `GemmaJournalService` on device. Metrics are computed inline (the MLX suite's
/// `CategoryCounts` is private); the STRICT per-category floors vs the Qwen
/// baseline are the owner's device-day recalibration (see device-qa-checklist.md).
/// The asserts here are conservative smoke gates a working integration passes and
/// a broken one fails.
///
/// Run on a physical iPhone 12 Pro:
///   xcodebuild test -scheme app-four -testPlan app-four-gemma-eval \
///     -destination 'platform=iOS,id=<udid>' \
///     -only-testing:app-fourTests/GemmaExtractionEvalTests
@Suite("Gemma extraction eval (gated)", .enabled(if: GemmaEvalGate.isEnabled), .serialized)
struct GemmaExtractionEvalTests {

    @Test func gemmaExtractsSignalsAcrossTheEvalSet() async throws {
        let cases = MLXEvalSet.cases
        try #require(!cases.isEmpty)

        let service = GemmaJournalService()

        var moodLabeled = 0, moodPresent = 0, moodExact = 0
        var medTP = 0, medFP = 0, medFN = 0
        var latencies: [Double] = []

        for c in cases {
            let start = ContinuousClock.now
            let result = try await service.summarize(rawTranscription: c.transcript)
            let elapsed = ContinuousClock.now - start
            latencies.append(Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18)

            if let expectedMood = c.mood {
                moodLabeled += 1
                if result.mood != nil { moodPresent += 1 }
                if result.mood == expectedMood { moodExact += 1 }
            }
            let expectedMeds = c.medNames
            let gotMeds = Set(result.medications.map(\.name))
            medTP += expectedMeds.intersection(gotMeds).count
            medFP += gotMeds.subtracting(expectedMeds).count
            medFN += expectedMeds.subtracting(gotMeds).count

            let moodStr = result.mood ?? "nil"
            print("GEMMA-CASE|\(c.id)|\(c.language)|mood exp=\(c.mood ?? "nil") got=\(moodStr)|meds exp=\(c.medNames.sorted()) got=\(result.medications.map(\.name))")
        }

        let medRecall = medTP + medFN == 0 ? 1.0 : Double(medTP) / Double(medTP + medFN)
        let medPrecision = medTP + medFP == 0 ? 1.0 : Double(medTP) / Double(medTP + medFP)
        let moodPresenceRate = moodLabeled == 0 ? 1.0 : Double(moodPresent) / Double(moodLabeled)
        let moodExactRate = moodLabeled == 0 ? 1.0 : Double(moodExact) / Double(moodLabeled)
        let avgLatency = latencies.reduce(0, +) / Double(latencies.count)
        print(String(format: "GEMMA-EVAL|cases=%d|medP=%.2f|medR=%.2f|moodPresence=%.2f|moodExact=%.2f|avgLatency=%.1fs",
                     cases.count, medPrecision, medRecall, moodPresenceRate, moodExactRate, avgLatency))

        // Conservative smoke gates (a working Gemma easily clears these; recalibrate
        // to the Qwen floors — MLXEvalFloors — once measured on device).
        #expect(medRecall >= 0.5, "medication recall \(medRecall) below smoke floor 0.5")
        #expect(moodPresenceRate >= 0.6, "mood presence \(moodPresenceRate) below smoke floor 0.6")
    }

    /// SC-1: prove on a real A14 that loading the LiteRT engine consumes roughly its
    /// expected footprint and eviction reclaims it. Thresholds are conservative
    /// placeholders — recalibrate to the measured `phys_footprint` (device-qa-checklist).
    @Test func modelLoadAndEvictionReclaimsMemory() async throws {
        let service = GemmaJournalService()
        let baselineMB = Double(os_proc_available_memory()) / (1024 * 1024)

        _ = try await service.summarize(rawTranscription: "Feeling steady today, took my Concerta this morning.")
        #expect(await service.isModelLoaded)
        let loadedMB = Double(os_proc_available_memory()) / (1024 * 1024)

        let reclaimed = await service.modelHolder.evict()
        #expect(reclaimed)
        #expect(await service.isModelLoaded == false)

        var settledMB = Double(os_proc_available_memory()) / (1024 * 1024)
        for _ in 0..<20 {
            if settledMB - loadedMB >= 300 { break }
            try? await Task.sleep(for: .milliseconds(500))
            settledMB = max(settledMB, Double(os_proc_available_memory()) / (1024 * 1024))
        }
        let loadDropMB = baselineMB - loadedMB
        let reclaimedMB = settledMB - loadedMB
        print(String(format: "SC-1|baseline=%.0fMB|loaded=%.0fMB|settled=%.0fMB|loadDrop=%.0fMB|reclaimed=%.0fMB",
                     baselineMB, loadedMB, settledMB, loadDropMB, reclaimedMB))

        // Gemma CPU/XNNPACK target ~607 MB resident — assert conservatively; recalibrate on device.
        #expect(loadDropMB >= 300, "load should drop available memory ≥300 MB (got \(Int(loadDropMB)) MB)")
        #expect(reclaimedMB >= 300, "eviction should reclaim ≥300 MB (got \(Int(reclaimedMB)) MB)")
    }
}
