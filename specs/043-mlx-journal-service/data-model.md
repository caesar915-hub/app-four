# Phase 1: Data Model & Contracts (043-mlx-journal-service)

This document defines the structural contracts between the `SquirlLLM` package, the `MLXJournalService`, and the `UnifiedExtraction` layer.

## 1. SquirlLLM Package Contract

The `SquirlLLM` package abstracts away MLX and HuggingFace.

```swift
public enum SquirlLLMError: Error {
    case insufficientMemory(available: Int, required: Int)
    case downloadFailed(Error)
    case cancelled
}

public protocol LLMGenerator: Sendable {
    /// Checks `os_proc_available_memory` and loads the model into memory. 
    /// Downloads from HuggingFace if missing.
    func loadModel() async throws
    
    /// Executes the prompt and yields the generation.
    /// Can be cancelled via the Swift concurrency `Task` system.
    func generate(prompt: String) async throws -> String
}
```

## 2. MLXJournalService Contract

```swift
/// Retained existing protocol
public protocol SummarizationService: Sendable {
    func summarize(rawTranscription: String) async throws -> SummaryResult
}

/// New implementation
public actor MLXJournalService: SummarizationService {
    private let llm: any LLMGenerator
    private let lexicon: Lexicon // loaded from lexicon.json
    
    public func summarize(rawTranscription: String) async throws -> SummaryResult {
        // 1. Check memory via LLM manager
        // 2. Load model (downloads if needed)
        // 3. Assemble prompt with lexicon and rawTranscription
        // 4. Generate JSON string
        // 5. Pass to UnifiedExtraction
    }
}
```

## 3. UnifiedExtraction Contract

The extraction parser validates the raw JSON. It is resilient to partial parsing failures.

```swift
public struct UnifiedExtraction {
    
    /// The intermediate codable representation that maps exactly to the LLM's expected JSON format.
    private struct LLMOutput: Codable {
        let sleep: SleepOutput?
        let mood: String?
        let energy: String?
        let focus: String?
        let emotions: [String]?
        let topics: [String]?
        let medications: [MedicationOutput]?
        let summary: String?
    }
    
    /// Parses the raw string and outputs the domain SummaryResult.
    public func parse(json: String, rawTranscription: String, lexicon: Lexicon) throws -> SummaryResult {
        // - Extracts JSON substring
        // - Decodes LLMOutput (using tolerant decoding)
        // - Maps properties to SummaryResult (e.g. standardizing sleep comma to dot)
        // - Clamps arrays (max 3 topics)
        // - Filters against lexicon allowlists
    }
}
```

## 4. UI Layer Contracts

The existing UI layers expect `SummaryResult`. If `os_proc_available_memory()` fails (e.g. throws `SquirlLLMError.insufficientMemory`), the UI layer must catch this error.

```swift
// In the view model that calls `summarize()`:
do {
    let result = try await summarizationService.summarize(rawTranscription: text)
    // present review sheet
} catch SquirlLLMError.insufficientMemory {
    // Show "Not enough memory" alert
    // Fallback to storing raw transcript only
} catch {
    // Generic fallback
}
```
