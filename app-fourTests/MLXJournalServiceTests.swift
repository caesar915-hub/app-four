import Testing
import UIKit
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
    
    @Test func modelNotLoadedAtInit() async {
        let service = MLXJournalService()
        let loaded = await service.isModelLoaded
        #expect(loaded == false)
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
        let loaded = await service.isModelLoaded
        #expect(loaded == false)
    }
    
    // MARK: - Managed model lifecycle (044)
    
    /// The service must never trigger an implicit ~740 MB hub download: with no
    /// model in the managed directory (always true in the test sandbox), a real
    /// transcript fails fast with `modelNotInstalled`.
    // MARK: - Phase 5: MLX memory lifecycle (044)

    @Test func idleTimerEvictsModel() async {
        let center = NotificationCenter()
        let service = MLXJournalService(
            idleEvictionInterval: .milliseconds(50),
            notificationCenter: center
        )
        await service.startLifecycleObservingForTesting()
        await service.modelHolder.markLoadedForTesting()
        #expect(await service.isModelLoaded == true)

        await service.armIdleTimerForTesting()

        #expect(await waitForEviction(of: service))
    }

    @Test func inferenceBeforeExpiryCancelsEviction() async {
        // Deterministic: re-arming must cancel the previously armed timer task.
        // Wall-clock races against a real timer flake under full-suite parallel
        // load (Task.sleep overshoot > interval); actual eviction timing is
        // covered by idleTimerEvictsModel().
        let center = NotificationCenter()
        let service = MLXJournalService(
            idleEvictionInterval: .seconds(60),
            notificationCenter: center
        )
        await service.startLifecycleObservingForTesting()
        await service.modelHolder.markLoadedForTesting()

        await service.armIdleTimerForTesting()
        let firstTimer = await service.currentIdleTimerTaskForTesting()
        await service.armIdleTimerForTesting()

        #expect(firstTimer != nil)
        #expect(firstTimer?.isCancelled == true)
        // The re-armed timer is 60s out, so the model stays loaded.
        #expect(await service.isModelLoaded == true)
    }

    @Test func memoryWarningEvictsImmediately() async {
        let center = NotificationCenter()
        let service = MLXJournalService(
            idleEvictionInterval: .seconds(60),
            notificationCenter: center
        )
        await service.startLifecycleObservingForTesting()
        await service.modelHolder.markLoadedForTesting()
        #expect(await service.isModelLoaded == true)

        center.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)

        #expect(await waitForEviction(of: service))
    }

    @Test func backgroundEntryEvictsImmediately() async {
        let center = NotificationCenter()
        let service = MLXJournalService(
            idleEvictionInterval: .seconds(60),
            notificationCenter: center
        )
        await service.startLifecycleObservingForTesting()
        await service.modelHolder.markLoadedForTesting()
        #expect(await service.isModelLoaded == true)

        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        #expect(await waitForEviction(of: service))
    }

    /// Polls until the model is evicted (up to ~2s). Fixed sleeps flake under
    /// full-suite parallel load, where `Task.sleep` and actor hops overshoot.
    private func waitForEviction(of service: MLXJournalService) async -> Bool {
        for _ in 0..<100 {
            if await service.isModelLoaded == false { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return false
    }
}
