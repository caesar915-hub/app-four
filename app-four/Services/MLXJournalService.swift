import Foundation
import os
import MLX
import MLXNN
import MLXRandom
import MLXLLM
import MLXLMCommon

// LLMExtractionResponse and LLMMedicationEntry removed in Part 2.
// JSON decoding now uses UnifiedExtraction via ExtractionValidator.parseExtraction().

nonisolated struct MLXJournalService: SummarizationService {
    private let lexicon: Lexicon
    private let systemPrompt: String
    
    init() {
        // loadBundled() is non-throwing: it falls back to code defaults if the
        // bundled lexicon.json is missing or malformed.
        let lex = LexiconLoader.loadBundled()
        self.lexicon = lex
        self.systemPrompt = MLXPromptBuilder.buildSystemPrompt(lexicon: lex)
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
        let currentSystemPrompt = self.systemPrompt
        let currentModelHolder = self.modelHolder
        let rawJSON = try await Task.detached(priority: .userInitiated) {
            try await currentModelHolder.generateText(systemPrompt: currentSystemPrompt, userMessage: userMessage)
        }.value
        
        // 5. Parse with 3-stage recovery (direct → backtick strip → substring)
        guard let extraction = ExtractionValidator.parseExtraction(from: rawJSON) else {
            return ExtractionValidator.fallbackResult(rawTranscript: trimmed)
        }
        
        // 6. Validate and clamp all fields against Levels.swift enums + lexicon allowlists
        let validated = ExtractionValidator.validate(extraction, lexicon: lexicon)
        
        // 7. Assemble SummaryResult from validated extraction
        return ExtractionValidator.assembleSummaryResult(
            from: validated, lexicon: lexicon, rawTranscript: trimmed
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
        var modelContainer: ModelContainer?
        
        func loadIfNeeded() async throws {
            guard !isLoaded else { return }
            
            // The model's lifecycle is managed by AIModelService (onboarding /
            // Settings / background download). Never trigger an implicit ~740 MB
            // hub download mid-check-in — if it isn't installed, say so.
            guard let directory = AIModelServiceImpl.findLlamaModelDirectory(
                in: ModelConstants.llamaDownloadBase
            ) else {
                os_log(.error, "Llama model not installed")
                throw SummarizationError.modelNotInstalled
            }
            
            guard MLXJournalService.checkMemoryHeadroom() else {
                os_log(.error, "Insufficient memory to load MLX model")
                throw SummarizationError.insufficientMemory
            }
            
            let config = ModelConfiguration(directory: directory)
            modelContainer = try await LLMModelFactory.shared.loadContainer(configuration: config)
            
            isLoaded = true
        }

        func generateText(systemPrompt: String, userMessage: String) async throws -> String {
            guard let modelContainer = modelContainer else {
                throw SummarizationError.modelNotInstalled
            }
            
            let session = ChatSession(modelContainer, instructions: systemPrompt, generateParameters: GenerateParameters(temperature: 0.1))
            return try await session.respond(to: userMessage)
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
