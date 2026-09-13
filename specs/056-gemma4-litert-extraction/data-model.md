# Phase 1 Data Model — Gemma 4 E2B via LiteRT-LM

**No SwiftData schema change.** All persisted types (`Recording`, `NoteExtraction`, `MedEvent`, …) are unchanged. This feature adds only in-memory value/state types.

## Reused verbatim (no change)

- **`SummaryResult`** (`Services/Protocols.swift`) — the service output. Fields: `bullets`, `medications: [MedEvent]`, `generatedTitle`, `energyLevel/focusLevel/mood/sleepQuality/sleepLevel: String?`, `sleepHours: Double?`, `sleepEvent: SleepEvent?`, `sideEffects/emotions/topics: [String]`, `noteExtraction: NoteExtraction?`.
- **`UnifiedExtraction`** (`Services/NoteExtraction/UnifiedExtraction.swift`) — the pass-2 JSON schema. Fields: `mood/energy/focus: String?`, `sleepHours: Double?`, `sleepQuality: String?`, `medications: [MedicationExtraction]`, `emotions/activities/topics/lexicon/sideEffects: [String]`, `summary: String?`.
- **`SummarizationError`** — `.modelNotInstalled`, `.contextTooLong`, `.timeout`, `.parsingFailed`, `.insufficientMemory`, `.inferenceFailed(String)`.

## New value types

### `GemmaTurn` / `GemmaChatTemplate`
```
struct GemmaTurn { enum Role { case user, model }; let role: Role; let text: String }
enum GemmaChatTemplate {
  static let startOfTurn = "<start_of_turn>"
  static let endOfTurn   = "<end_of_turn>"
  static func singleTurn(system: String, user: String) -> String
  static func render(_ turns: [GemmaTurn]) -> String
}
```
- **Invariant:** Gemma has no system role. `singleTurn` folds system text into the first user turn:
  `"<start_of_turn>user\n\(system)\n\n\(user)<end_of_turn>\n<start_of_turn>model\n"`.
- `render` concatenates turns, each `"<start_of_turn>\(role)\n\(text)<end_of_turn>\n"`, then appends the trailing `"<start_of_turn>model\n"` opener.

### `SignalsToolArguments` (pass-2 tool-call payload)
Codable mirror of the fields `UnifiedExtraction` carries, matching the existing signals JSON keys exactly so the free-form path and the tool-call path converge on one mapping:
```
struct SignalsToolArguments: Codable, Sendable {
  var mood: String?; var energy: String?; var focus: String?
  var sleepHours: Double?; var sleepQuality: String?
  var medications: [MedicationExtraction]   // {name, dose?, taken=true}
  var emotions: [String]; var activities: [String]; var topics: [String]
  var lexicon: [String]; var sideEffects: [String]; var summary: String?
}
static func unifiedExtraction(from args: SignalsToolArguments) -> UnifiedExtraction
```
- **Mapping rule:** field-for-field into `UnifiedExtraction`; collections default to `[]`; no clamping here (that is `ExtractionValidator.validate`'s job). The tool-call path and the free-form-JSON path MUST produce byte-identical `UnifiedExtraction` for the same logical content (tested).

## State machine — `GemmaJournalService.ModelHolder` (actor)

```
states: unloaded → loading → loaded → (evicted → unloaded)
```
- `unloaded`: no engine. `loadIfNeeded()` dedups concurrent loads via an in-flight `Task`.
- guard on load: `checkMemoryHeadroom(minimumBytes:)` (`os_proc_available_memory()`); fail ⇒ `throw .insufficientMemory` (no fallback per D2).
- installed guard: `.litertlm` present + expected size; absent ⇒ `throw .modelNotInstalled`.
- `loaded`: holds a `LiteRTTextGenerator`. `generate`/`callTool` route through it.
- eviction: on background/memory-warning/idle (`LifecycleCoordinator`, mirror of MLX's) → release generator → `unloaded`. `evict()` refuses while generating; caller re-arms.

## Error taxonomy mapping

| Condition | Thrown | Downstream UX |
|-----------|--------|---------------|
| `.litertlm` absent/truncated | `.modelNotInstalled` | Model-management prompt; transcript preserved |
| headroom < min | `.insufficientMemory` | "Not enough memory"; transcript-only (no fallback, D2) |
| both pass-2 paths + retry fail to parse | (non-fatal) empty-but-valid `SummaryResult` | Entry saved with raw transcript as the bullet |
| LiteRT generate throws | `.inferenceFailed(String)` | Transcript preserved; retry later |
| runtime absent at build (`#if !canImport`) | engine path reports `.modelNotInstalled` | Inert; MLX/Qwen remains live until switchover |

## Constants (additive — `Utils/Constants.swift`)
```
gemmaLiteRTRepoID     = "litert-community/gemma-4-E2B-it-litert-lm"
gemmaLiteRTFileName   = "gemma-4-E2B-it.litertlm"          // CPU/XNNPACK build
gemmaLiteRTExpectedBytes: Int64 = 2_588_147_712            // 2.41 GiB
```
`llmHubRepoID` (Qwen) is **unchanged** this feature; repointing is the switchover step.
