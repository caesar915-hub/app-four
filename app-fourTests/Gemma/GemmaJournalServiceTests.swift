import Testing
import UIKit
@testable import app_four

@Suite struct GemmaJournalServiceTests {
    // MARK: - Empty / conformance

    @Test func emptyTranscriptReturnsEmptyNote() async throws {
        let service = GemmaJournalService()
        let result = try await service.summarize(rawTranscription: "")
        #expect(result.generatedTitle == "Empty Note")
        #expect(result.mood == nil)
    }

    @Test func whitespaceOnlyTranscriptReturnsEmptyNote() async throws {
        let service = GemmaJournalService()
        let result = try await service.summarize(rawTranscription: "   \n \t ")
        #expect(result.generatedTitle == "Empty Note")
    }

    @Test func conformsToSummarizationService() async throws {
        let service: SummarizationService = GemmaJournalService()
        _ = try await service.summarize(rawTranscription: "")
    }

    @Test func serviceIsSendable() {
        let _: any Sendable = GemmaJournalService()
    }

    // MARK: - Memory gate / load state

    @Test func memoryCheckReturnsValue() {
        #expect(GemmaJournalService.checkMemoryHeadroom(minimumBytes: 0) == true)
        #expect(GemmaJournalService.checkMemoryHeadroom(minimumBytes: .max) == false)
    }

    @Test func modelNotLoadedAtInit() async {
        let service = GemmaJournalService()
        #expect(await service.isModelLoaded == false)
    }

    @Test func summarizeThrowsWhenModelNotInstalled() async {
        // No preloaded generator + installedCheck false ⇒ the load path throws.
        let service = GemmaJournalService(installedCheck: { false })
        await #expect(throws: SummarizationError.self) {
            _ = try await service.summarize(rawTranscription: "Real transcript with content.")
        }
    }

    // MARK: - Two-pass pipeline (hermetic: preloaded FakeLiteRTGenerator, no runtime)

    @Test func toolCallPassProducesValidatedResult() async throws {
        let fake = FakeLiteRTGenerator(
            generate: { _, _, maxTokens in maxTokens <= 120 ? "You had a steady, focused day." : "" },
            callTool: { _, _ in
                SignalsToolArguments(
                    mood: "good", energy: "steady", focus: "sharp",
                    medications: [MedicationExtraction(name: "Vyvanse", dose: nil, taken: true)],
                    emotions: ["calm"], topics: ["Focus"], summary: nil
                )
            }
        )
        let service = GemmaJournalService(preloadedGenerator: fake)
        let result = try await service.summarize(
            rawTranscription: "Took my Vyvanse this morning. Energy is steady, focus is sharp."
        )
        #expect(result.generatedTitle != "Empty Note")
        #expect(result.mood != nil)
        #expect(!result.bullets.isEmpty)
        #expect(result.medications.contains { $0.name.localizedCaseInsensitiveContains("vyvanse") })
    }

    @Test func freeFormFallthroughWhenNoToolCall() async throws {
        let json = #"{"mood":"good","energy":"steady","focus":"sharp","medications":[{"name":"Vyvanse","taken":true}],"summary":"steady day"}"#
        let fake = FakeLiteRTGenerator(
            generate: { _, _, maxTokens in maxTokens <= 120 ? "You had a steady day." : json },
            callTool: { _, _ in nil } // no tool call → free-form path
        )
        let service = GemmaJournalService(preloadedGenerator: fake)
        let result = try await service.summarize(
            rawTranscription: "Took my Vyvanse this morning. Energy steady, focus sharp."
        )
        #expect(result.mood != nil)
        #expect(result.medications.contains { $0.name.localizedCaseInsensitiveContains("vyvanse") })
    }

    @Test func unparseablePass2StillPreservesTranscript() async throws {
        let fake = FakeLiteRTGenerator(
            generate: { _, _, maxTokens in maxTokens <= 120 ? "A brief note." : "this is not json at all" },
            callTool: { _, _ in nil }
        )
        let service = GemmaJournalService(preloadedGenerator: fake)
        let result = try await service.summarize(rawTranscription: "Just rambling with no clear signals here.")
        #expect(!result.bullets.isEmpty)          // transcript/summary retained
        #expect(result.mood == nil)               // no signals parsed
        #expect(result.generatedTitle != "Empty Note")
    }

    // MARK: - Lifecycle (mirrors MLXJournalService lifecycle tests)

    @Test func idleTimerEvictsModel() async {
        let center = NotificationCenter()
        let service = GemmaJournalService(idleEvictionInterval: .milliseconds(50), notificationCenter: center)
        await service.startLifecycleObservingForTesting()
        await service.modelHolder.markLoadedForTesting()
        #expect(await service.isModelLoaded == true)
        await service.armIdleTimerForTesting()
        #expect(await waitForEviction(of: service))
    }

    @Test func inferenceBeforeExpiryCancelsEviction() async {
        let center = NotificationCenter()
        let service = GemmaJournalService(idleEvictionInterval: .seconds(60), notificationCenter: center)
        await service.startLifecycleObservingForTesting()
        await service.modelHolder.markLoadedForTesting()
        await service.armIdleTimerForTesting()
        let firstTimer = await service.currentIdleTimerTaskForTesting()
        await service.armIdleTimerForTesting()
        #expect(firstTimer != nil)
        #expect(firstTimer?.isCancelled == true)
        #expect(await service.isModelLoaded == true)
    }

    @Test func memoryWarningEvictsImmediately() async {
        let center = NotificationCenter()
        let service = GemmaJournalService(idleEvictionInterval: .seconds(60), notificationCenter: center)
        await service.startLifecycleObservingForTesting()
        await service.modelHolder.markLoadedForTesting()
        #expect(await service.isModelLoaded == true)
        center.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        #expect(await waitForEviction(of: service))
    }

    @Test func backgroundEntryEvictsImmediately() async {
        let center = NotificationCenter()
        let service = GemmaJournalService(idleEvictionInterval: .seconds(60), notificationCenter: center)
        await service.startLifecycleObservingForTesting()
        await service.modelHolder.markLoadedForTesting()
        #expect(await service.isModelLoaded == true)
        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        #expect(await waitForEviction(of: service))
    }

    private func waitForEviction(of service: GemmaJournalService) async -> Bool {
        for _ in 0..<100 {
            if await service.isModelLoaded == false { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return false
    }
}
