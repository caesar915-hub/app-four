import Testing
@testable import app_four

struct NLSummarizationServiceTopicTests {

    @Test func medAndSideEffectTranscriptYieldsTopics() async throws {
        let service = NLSummarizationService(lexicon: LexiconLoader.loadBundled(overlay: nil))
        let result = try await service.summarize(rawTranscription:
            "Took my Concerta 36mg this morning. Dry mouth all afternoon.")
        #expect(result.topics.contains("Medications"))
        #expect(result.topics.contains("Symptoms"))
        #expect(!result.topics.contains("Appointments"))
    }

    @Test func appointmentTranscriptYieldsAppointments() async throws {
        let service = NLSummarizationService(lexicon: LexiconLoader.loadBundled(overlay: nil))
        let result = try await service.summarize(rawTranscription:
            "Saw my psychiatrist today, we have a follow-up appointment next month.")
        #expect(result.topics.contains("Appointments"))
    }

    @Test func neutralTranscriptYieldsNoTopics() async throws {
        let service = NLSummarizationService(lexicon: LexiconLoader.loadBundled(overlay: nil))
        let result = try await service.summarize(rawTranscription:
            "I went to the store and bought milk.")
        #expect(result.topics.isEmpty)
    }
}
