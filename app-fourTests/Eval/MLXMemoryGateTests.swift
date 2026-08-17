import Testing
import Foundation
@testable import app_four

/// T036 (spec 044) device gate: prove with the **real** model on a **real**
/// device that (a) loading the LLM consumes roughly its expected footprint and
/// (b) eviction actually reclaims it. The notification-driven paths (background
/// / memory-warning / 180 s idle / re-arm cancellation) are covered with
/// lifecycle hooks by `MLXJournalServiceTests`; this suite adds the numbers.
///
/// Runs only under the MLX eval test plan (MLX_EVAL=1 + model installed).
@Suite("MLX memory gate (gated)", .enabled(if: MLXEvalGate.isEnabled))
struct MLXMemoryGateTests {

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
}
