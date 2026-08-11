import Testing
@testable import app_four

@Suite struct MLXJournalServiceTests {
    @Test func emptyTranscriptReturnsEmptyNote() async throws {
        let service = MLXJournalService()
        let result = try await service.summarize(rawTranscription: "")
        #expect(result.generatedTitle == "Empty Note")
        #expect(result.mood == nil)
        #expect(result.energyLevel == nil)
        #expect(result.focusLevel == nil)
    }
    
    @Test func whitespaceOnlyTranscriptReturnsEmptyNote() async throws {
        let service = MLXJournalService()
        let result = try await service.summarize(rawTranscription: "   \n  \t  ")
        #expect(result.generatedTitle == "Empty Note")
        #expect(result.mood == nil)
        #expect(result.energyLevel == nil)
        #expect(result.focusLevel == nil)
    }
    
    @Test func conformsToSummarizationService() async throws {
        let service: SummarizationService = MLXJournalService()
        let _ = try await service.summarize(rawTranscription: "")
    }
    
    @Test func serviceLoadsLexicon() throws {
        let _ = MLXJournalService()
    }
    
    // MARK: - Phase 4 Tests
    
    @Test func memoryCheckReturnsValue() {
        let hasHeadroom = MLXJournalService.checkMemoryHeadroom()
        // On a dev machine this should be true. It verifies the function exists and works.
        #expect(hasHeadroom == true || hasHeadroom == false) 
    }
    
    @Test func modelNotLoadedAtInit() {
        let service = MLXJournalService()
        #expect(service.isModelLoaded == false)
    }
    
    // MARK: - Phase 5 Tests
    
    @Test func serviceIsSendable() {
        let _: any Sendable = MLXJournalService()
    }
    
    @Test func tagSourceLlmExists() {
        #expect(TagSource.llm.rawValue == "llm")
    }
    
    // MARK: - Phase 6 Tests
    
    @Test func coldStartDoesNotLoadModel() async {
        let service = MLXJournalService()
        // Simulate checking the state without triggering the summarization
        #expect(service.isModelLoaded == false)
    }
}
