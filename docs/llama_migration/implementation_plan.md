# Replace NLP Extractor with LLAMA (MLX-Swift)

This plan outlines the steps to replace the current deterministic, Natural Language (NL) pipeline with a dynamic, LLM-driven journaling platform using Llama 3.2 (1B) and MLX-Swift, as specified in the FSD.

## User Review Required

> [!WARNING]
> This is a major architectural change. We will be deleting a large chunk of the existing, deterministic extraction pipeline (regex patterns, cue matching) in favor of the LLAMA model. As requested, the lexicon will be kept as a text/note file for reference.
>
> Please confirm if you want to proceed with deleting the other legacy code or if you'd like to keep it around in a disabled state for fallback purposes.

## Open Questions

> [!IMPORTANT]
> 1. Do we already have `MLX-Swift` integrated into the project (e.g., via Swift Package Manager), or should I add it to `app-four.xcodeproj` / `Packages`?
> 2. The FSD mentions WhisperKit. Should the integration of WhisperKit be part of this plan, or are we strictly focusing on the extraction step (`Raw Transcript -> LLM -> UnifiedExtraction`) for now?

## Proposed Changes

### 1. New AI Service Layer

We will introduce the `MLXJournalService` responsible for LLM orchestration, taking the raw transcript, handling prompt construction, model execution on a background actor, and parsing.

#### [NEW] `app-four/Services/MLXJournalService.swift`
- Manages LLM loading and inference lifecycle on a background actor.
- Injects the system prompt and few-shot examples defined in the FSD.
- Implements the strict JSON response format (`UnifiedExtraction`).

#### [NEW] `app-four/Models/UnifiedExtraction.swift`
- Defines the `UnifiedExtraction` and `MedicationEvent` structs with robust `Codable` implementations.
- Implements the `parseExtraction(_:)` layer with fallback logic (regex cleanup, markdown backtick stripping, clamping values to valid ranges).

### 2. Updating Data Models & Summary Service

We need to update the app's internal representation of the journal summary to use the new LLM output schema instead of the old `NoteExtraction` signals.

#### [MODIFY] `app-four/Models/Recording.swift` (or related SwiftData models)
- Update to accommodate the new fields: `summary: String?`, `topics: [String]`, `mood: String?`, `energy: String?`, `focus: String?`, `sleepHours: Double?`, `medications: [MedicationEvent]`.

#### [MODIFY] `app-four/Services/NLSummarizationService.swift` -> `app-four/Services/LLMSummarizationService.swift`
- Redirect the summarization process from the old `NLNoteExtractor` to the new `MLXJournalService`.
- Map the parsed `UnifiedExtraction` to the UI-friendly `SummaryResult`.
- Ensure this orchestrator properly handles memory deallocation handoffs (e.g., ensuring WhisperKit context is released before LLM loading).

### 3. Deleting the Legacy NLP Pipeline

Once the LLM service is in place, we can safely remove the legacy extraction files, as their functionality will be fully superseded by the LLM.

#### [DELETE] `app-four/Services/NoteExtraction/NLNoteExtractor.swift`
#### [DELETE] `app-four/Services/NoteExtraction/CueMatcher.swift`
#### [DELETE] `app-four/Services/NoteExtraction/Lexicon.swift`
#### [DELETE] `app-four/Services/NoteExtraction/LexiconData.swift`
#### [DELETE] `app-four/Services/NoteExtraction/NoteExtraction.swift`
#### [DELETE] `app-four/Services/NoteExtraction/TenseClassifier.swift`
#### [DELETE] `app-four/Services/NoteExtraction/PersonalLexiconBuilder.swift`
#### [MODIFY] `app-four/Resources/lexicon.json` (Keep and convert to a text/note file for reference)

## Verification Plan

### Automated Tests
- Create unit tests for `parseExtraction` to ensure it gracefully handles valid JSON, markdown-wrapped JSON, hallucinatory fields, and invalid JSON structures.

### Manual Verification
- Run a short Mood Check-in transcript and verify the TTFT (Time-To-First-Token) and overall memory footprint in Xcode Instruments.
- Run a long (15 minute equivalent) Journal Entry and verify the JSON extraction adheres strictly to the unified schema and handles topics/summary generation properly.
- Verify `os_proc_available_memory()` behavior when loading the 1B model to prevent Jetsam crashes.
