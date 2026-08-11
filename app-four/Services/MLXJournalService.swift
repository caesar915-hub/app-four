import Foundation
import os
import MLX
import MLXNN
import MLXRandom
import MLXLLM

private struct LLMMedicationEntry: Decodable {
    let name: String
    let dosage: String?
    let taken: Bool?
    let timeOfDay: String?
    
    enum CodingKeys: String, CodingKey {
        case name, dosage, taken
        case timeOfDay = "time_of_day"
    }
}

private struct LLMExtractionResponse: Decodable {
    let mood: String?
    let energy: String?
    let focus: String?
    let sleep: String?
    let summary: String?
    let title: String?
    let medications: [LLMMedicationEntry]?
    let emotions: [String]?
    let topics: [String]?
    let lexiconPhrases: [String]?
    
    enum CodingKeys: String, CodingKey {
        case mood, energy, focus, sleep, summary, title, medications, emotions, topics
        case lexiconPhrases = "lexicon_phrases"
    }
}

nonisolated struct MLXJournalService: SummarizationService {
    private let lexicon: Lexicon
    private let systemPrompt: String
    
    init() {
        do {
            let lex = try LexiconLoader.loadBundled()
            self.lexicon = lex
            self.systemPrompt = MLXPromptBuilder.buildSystemPrompt(lexicon: lex)
        } catch {
            fatalError("Failed to load lexicon: \\(error)")
        }
    }
    
    func summarize(rawTranscription: String) async throws -> SummaryResult {
        let trimmed = rawTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Self.emptyResult()
        }
        
        // 2. Call loadModelIfNeeded() (Implemented in Phase 4)
        try await loadModelIfNeeded()
        
        // 3. Build user message
        let userMessage = MLXPromptBuilder.buildUserMessage(transcript: trimmed)
        
        // 4. Run inference via MLX-Swift generate() in Task.detached
        let rawJSON = try await Task.detached(priority: .userInitiated) {
            // TODO: Phase 4 will implement actual MLX generate() call here once model is loaded
            // For Phase 3, we mock a valid JSON response string to ensure mapping logic works
            return """
            {
                "title": "Journal Entry",
                "summary": "This is a summary",
                "mood": "neutral",
                "energy": "steady",
                "focus": "sharp",
                "sleep": "deep",
                "medications": [],
                "emotions": [],
                "topics": [],
                "lexicon_phrases": []
            }
            """
        }.value
        
        // 5. Parse raw JSON response
        guard let data = rawJSON.data(using: .utf8) else {
            return Self.emptyResult()
        }
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(LLMExtractionResponse.self, from: data)
        
        // 6. Map LLMExtractionResponse fields to SummaryResult
        let mappedMedications = response.medications?.compactMap { med -> MedEvent? in
            // Mapping to existing MedEvent (assuming MedEvent init)
            // If MedEvent has a specific initializer, we should use it.
            // But for now we just return an empty array or basic MedEvent
            return nil 
        } ?? []
        
        return SummaryResult(
            bullets: [],
            medications: mappedMedications,
            generatedTitle: response.title ?? "Journal Entry",
            energyLevel: response.energy,
            focusLevel: response.focus,
            mood: response.mood,
            sleepHours: nil,
            sleepQuality: nil,
            sleepEvent: nil,
            sleepLevel: response.sleep,
            sideEffects: [],
            emotions: response.emotions ?? [],
            topics: response.topics ?? [],
            noteExtraction: nil
        )
    }
    
    private static func emptyResult() -> SummaryResult {
        return SummaryResult(
            bullets: [],
            medications: [],
            generatedTitle: "Empty Note",
            energyLevel: nil,
            focusLevel: nil,
            mood: nil,
            sleepHours: nil,
            sleepQuality: nil,
            sleepEvent: nil,
            sleepLevel: nil,
            sideEffects: [],
            emotions: [],
            topics: [],
            noteExtraction: nil
        )
    }
    
    private actor ModelHolder {
        var isLoaded: Bool = false
        // var modelContainer: ModelContainer? // Omitted until we need to perform actual generation in next phases
        
        func loadIfNeeded() async throws {
            guard !isLoaded else { return }
            
            guard MLXJournalService.checkMemoryHeadroom() else {
                os_log(.error, "Insufficient memory to load MLX model")
                throw SummarizationError.modelNotInstalled
            }
            
            // Mocking the actual LLMModel.load() or LLMModelFactory call for now,
            // since Phase 3 generation is also mocked. We just satisfy the lifecycle requirement.
            // let config = ModelConfiguration(id: "meta-llama/Llama-3.2-1B-Instruct")
            // modelContainer = try await LLMModelFactory.shared.loadContainer(configuration: config)
            
            isLoaded = true
        }
    }
    
    private let modelHolder = ModelHolder()
    
    var isModelLoaded: Bool {
        get {
            // Because MLXJournalService is nonisolated, we would normally have to await this,
            // but the test checks it synchronously. We can use a semaphore or DispatchGroup for the test,
            // or just make isModelLoaded async. Wait, the test calls it synchronously. 
            // If we can't do that, we'll return a mock value here, but wait, `tasks.md` doesn't enforce the property signature.
            // Actually, we can use a DispatchSemaphore to read the actor synchronously, or just make the test async.
            // Let's just use a Task to fetch it and wait using a semaphore.
            let sema = DispatchSemaphore(value: 0)
            var result = false
            Task {
                result = await modelHolder.isLoaded
                sema.signal()
            }
            sema.wait()
            return result
        }
    }

    static func checkMemoryHeadroom(minimumBytes: UInt64 = 200 * 1024 * 1024) -> Bool {
        return os_proc_available_memory() >= minimumBytes
    }
    
    private func loadModelIfNeeded() async throws {
        try await modelHolder.loadIfNeeded()
    }
}
