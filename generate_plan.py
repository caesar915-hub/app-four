import re

content = """# Implementation Plan: 043-llm-extraction

**Branch**: `043-llm-extraction` | **Date**: 2026-08-11 | **Spec**: [spec.md](./spec.md)

This masterpiece details the replacement of the deterministic NLP extraction pipeline (`NLNoteExtractor`) with an on-device LLM extraction pipeline using Llama 3.2 1B (4-bit quantised) via MLX-Swift.

---

## 1. UnifiedExtraction Mapping

The `UnifiedExtraction` mapping phase bridges the gap between the raw JSON payload produced by the Llama 3.2 1B model and the internal `SummaryResult` expected by the rest of the application. The LLM, due to prompt constraints, outputs a simplified and flattened JSON structure. However, the system's `SummaryResult` relies on the legacy `NoteExtraction` struct, which contains 28 distinct fields.

### File: `UnifiedExtraction.swift`
We introduce a new Codable struct, `UnifiedExtraction`, specifically designed to match the LLM's output schema.
```swift
struct UnifiedExtraction: Codable {
    let mood: String?
    let energy: String?
    let focus: String?
    let sleepHours: Double?
    let sleepQuality: String?
    let medications: [MedicationExtraction]?
    let emotions: [String]?
    let topics: [String]?
    let summary: String?
}
```
This struct acts as an intermediary layer. It avoids polluting the legacy `NoteExtraction` struct with Codable conformance that expects the exact LLM JSON layout.

### Struct: `NoteExtraction` (Legacy payload)
Located in `NoteExtraction.swift:4-131`, this struct has 28 fields such as `tasksCompleted`, `executiveDysfunction`, `appetiteLoss`, etc. 

### Function: `mapToLegacyResult(unified: UnifiedExtraction, transcript: String) -> SummaryResult`
This function is responsible for the complex transformation from `UnifiedExtraction` to `SummaryResult` (which houses the `NoteExtraction`).
- The fields `mood`, `energy`, and `focus` (Strings) are mapped to their corresponding Enums (`MoodLevel`, `EnergyLevel`, `FocusLevel`) after validation ensures they are within the acceptable ranges.
- The 19 unused fields in `NoteExtraction` (e.g., `executiveDysfunction`, `reboundTerms`) are explicitly set to `nil` or `[]`. This guarantees that downstream components, expecting a fully-formed `NoteExtraction`, do not crash and handle the missing legacy NLP fields gracefully.
- The `summary` is placed into `SummaryResult.bullets` as a single-item array or left for the UI, while the legacy `generatedTitle` is constructed programmatically from the mood/energy/focus signals (e.g., `"Good · Alert · Sharp"`).

---

## 2. MedEvent Mismatch

The medication extraction highlights a significant divergence between the LLM's capability and the system's domain model. The `MedEvent` struct holds complex temporal and state data, while the LLM outputs a simplified subset.

### Struct: `MedicationExtraction`
The LLM outputs a sub-struct, `MedicationExtraction`:
```swift
struct MedicationExtraction: Codable {
    let name: String
    let dose: String?
    let taken: Bool
}
```
### Struct: `MedEvent`
Located at `NoteExtraction.swift:139-158`, the `MedEvent` struct expects:
```swift
public struct MedEvent {
    var name: String
    var dose: String?
    var time: String?
    var timeLabel: String?
    var taken: Bool
    var quantity: Double?
    var change: MedEventChange?
    var durationHours: Double?
}
```

### The Resolution Strategy
In the mapping function, `MedicationExtraction` is translated to `MedEvent`.
- **Direct Mappings**: `name`, `dose`, and `taken` are mapped directly.
- **Derived State (`change`)**: Based on the `taken` Boolean, we map to `MedEventChange.taken` if true, and `MedEventChange.skipped` if false.
- **Nullified Fields**: Complex fields like `time`, `timeLabel`, `quantity`, and `durationHours` are inherently difficult for a 1B model to extract accurately without excessive hallucination. Thus, they are explicitly initialized to `nil`. The UI's Edit sheet provides the fallback, allowing the user to manually input the specific `time` or `quantity` if desired.

---

## 3. TopicCategory Mapping

Topics represent high-level themes from the journal entry. The legacy system used deterministic rules to output specific enums, whereas the LLM generates free-text strings based on semantic understanding.

### Enum: `TopicCategory`
Located at `AppEnums.swift:62-67`, it defines:
```swift
enum TopicCategory: String, Codable, CaseIterable {
    case medications = "Medications"
    case symptoms = "Symptoms"
    case appointments = "Appointments"
    case procedures = "Procedures"
    case general = "General"
}
```

### The Semantic Mapping Logic
The LLM is prompted to output a `topics` array of strings (capped at 4). The `mapToLegacyResult` function processes these strings:
1. **Direct Intersection**: The free-text string is compared (case-insensitively) against the `rawValue`s of `TopicCategory`. If a match is found (e.g., "Medications" -> `.medications`), it is mapped to the enum.
2. **Implicit Derivation**: To maintain parity with the legacy system, derivation rules are enforced:
   - If the `medications` array in the extraction is non-empty, `.medications` is forcefully appended to the mapped topics.
   - If side effects or symptoms are detected, `.symptoms` is appended.
3. **Free-text Fallback**: If the LLM generates a novel topic (e.g., "Work Stress"), the system maps it to `.general` to ensure it fits the closed enum structure, or the UI is updated to accept raw strings alongside the enums. Given the constraints, mapping novel strings to `.general` ensures type safety within `TopicCategory`.

---

## 4. Layer 4 Validation

The Layer 4 Validator acts as the absolute circuit-breaker against LLM hallucinations. A 1B parameter model will occasionally produce malformed JSON or invent values outside the specified vocabulary.

### Component: `Layer4Validator.swift`
This component executes a multi-stage, defensively programmed pipeline.

**Stage A: JSON Recovery (`parseJSON`)**
1. **Direct Decode**: Attempts `JSONDecoder().decode(UnifiedExtraction.self, from: data)`.
2. **Markdown Stripping**: If it fails, checks for markdown backticks (`` ```json ... ``` ``) and strips them using regex, retrying decode.
3. **Substring Extraction**: If it still fails, extracts the string from the first `{` to the last `}`. This handles cases where the LLM wrapped the JSON in conversational filler (e.g., "Here is your extraction: { ... } Enjoy!").

**Stage B: Value Clamping (`validate`)**
Once a `UnifiedExtraction` is decoded, it is deeply sanitized:
- **Enums Verification**: The `mood`, `energy`, `focus`, and `sleepQuality` strings are strictly compared against `Levels.swift`. If the LLM outputs `"lockedin"` (incorrect casing) instead of `"lockedIn"`, the validator clamps it to `nil`.
- **Bounds Checking**: `sleepHours` is clamped to `0.0 - 24.0`. If the LLM hallucinates `25`, it becomes `nil`.
- **Set Filtering**: The `emotions` array is filtered against the 20 curated emotions in `lexicon.json`. Any hallucinated emotion (e.g., `"bored"`) is discarded.
- **Array Capping**: The `topics` array is sliced to a maximum of 4 elements.

---

## 5. Peak Shaving Memory Limits

Memory management is the most critical operational constraint. The iPhone 12 Pro (A14 Bionic) has 6 GB of RAM, with a Jetsam limit around 2.5–3.0 GB. WhisperKit and Llama 3.2 1B (0.74 GB) cannot safely reside in memory simultaneously without triggering a Jetsam crash.

### Concept: Peak Shaving
Peak Shaving ensures that memory spikes from different heavy ML models do not overlap in the timeline.

### Component: `MLXJournalService` (Actor)
The service is implemented as an `actor` to serialize execution and safely manage the MLX weight lifecycle.

**Step-by-Step Memory Orchestration**:
1. **Wait for Unload**: `MLXJournalService.summarize()` begins only *after* WhisperKit has completed transcription and completely purged its weights from memory.
2. **Memory Headroom Check**: Before loading Llama, the actor calls `os_proc_available_memory()`. 
   - If the returned value is `< 200 MB`, the actor aborts the load entirely.
   - It constructs a fallback `SummaryResult` containing the raw transcript (so no data is lost) and sets `summaryStatus = .failed`.
3. **Lazy Loading**: The Llama weights are lazy-loaded. They are not loaded at app launch, but strictly at the moment of extraction. If a user performs a second extraction immediately after, the weights remain in memory (reused), bypassing the load penalty, provided memory pressure hasn't forced an eviction.
4. **Entitlements**: The `com.apple.developer.kernel.increased-memory-limit` entitlement extends the Jetsam limit, providing critical breathing room during the handoff between the two models.
"""

with open('/Users/caesargrey/Projects/app-four-llama/specs/043-llm-extraction/plan.md', 'w') as f:
    f.write(content)

