import Testing
import Foundation
@testable import app_four

/// The side-effect display surface must count the appetite-loss bucket as a side
/// effect, not only the generic/physical side-effect buckets (spec 021, FR-011).
struct SideEffectDisplayTests {
    @Test func appetiteLossSurfacesAsSideEffect() async throws {
        // Deterministic lexicon: an appetite-loss cue, with the generic/physical
        // side-effect buckets emptied so the keyword can ONLY come from appetiteLoss.
        let service = NLSummarizationService(lexicon: Lexicon(
            sideEffectCues: [], physicalSideEffects: [], appetiteLoss: ["appetite gone"]))
        let result = try await service.summarize(rawTranscription: "Appetite gone all day.")
        #expect(result.sideEffects.contains("appetite gone"))
    }
}
