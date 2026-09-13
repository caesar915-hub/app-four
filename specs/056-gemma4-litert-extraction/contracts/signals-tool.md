# Contract — Pass-2 Signals (Tool Use + free-form fallthrough)

Pass-2 produces structured signals. Two paths converge on **one** `UnifiedExtraction` mapping so behaviour is identical whichever the model uses.

## Path A — Tool Use / function calling (D1, preferred)

The signals schema is declared as a tool the model calls with typed arguments. Registered via `ConversationConfig(tools:)`; the LiteRT `Tool` conformance is compile-guarded (`#if canImport(LiteRTLM)`), the argument type and mapping are not.

```swift
struct SignalsToolArguments: Codable, Sendable {
  var mood: String?          // one of MoodLevel rawValues or nil
  var energy: String?        // EnergyLevel rawValues
  var focus: String?         // FocusLevel rawValues
  var sleepHours: Double?
  var sleepQuality: String?  // SleepLevel rawValues
  var medications: [MedicationExtraction]   // { name, dose?, taken=true }
  var emotions: [String]
  var activities: [String]
  var topics: [String]
  var lexicon: [String]
  var sideEffects: [String]
  var summary: String?
}
```

- Tool name: `record_signals`. One call expected per pass-2.
- `@ToolParam` descriptions carry the same enum-allowlist guidance the system prompt injects (mood/energy/focus/sleep labels, medication list).
- The model MAY still emit values outside the allowlist; that is fine — `ExtractionValidator.validate` clamps them. The tool schema is a *hint*, not a hard constraint (LiteRT has no constrained decoding).

## Path B — free-form JSON (fallthrough, proven Qwen-equivalent)

If no tool call is produced, or its arguments fail to decode, read the model's free-form text and run the **existing** recovery:
1. `ExtractionValidator.parseExtraction(from:)` — 3-stage: direct decode → strip ```json fences → first-`{`-to-last-`}`.
2. On nil, **one** correction retry with `PromptLoader.loadSignalCorrectionPrompt(transcript:)`, re-generate, parse again.
3. Still nil ⇒ pass-2 yields nil; merge leaves signals empty; `SummaryResult` still returns with the transcript.

## Convergence invariant (tested)

`SignalsTool.unifiedExtraction(from: args)` and `ExtractionValidator.parseExtraction(from: equivalentJSON)` MUST produce an identical `UnifiedExtraction` for the same logical content. This is the load-bearing unit test — it lets the free-form path be the safety net without behavioural drift.

## Thinking / determinism

Pass-2 generation sets the thinking-token budget ≈ 0 and temperature 0 (greedy), so output is the payload (tool call or JSON) without reasoning preamble — matching the MLX path's `temperature: 0.0`.

## Acceptance (maps to SC-2/SC-2a/SC-3)

- SC-2: post-validator JSON/tool validity ≥ Qwen baseline on the shared fixtures.
- SC-2a: measured tool-call schema-conformance rate on-device (reliability metric; no guarantee).
- SC-3: micro-averaged signal P/R ≥ Qwen baseline (expected higher; Gemma IFEval 94.6 vs 42.5).
