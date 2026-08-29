<!-- Created: 2026-08-11 22:44 (WEST) · Updated: 2026-08-11 22:44 (WEST) -->
# 04b-2 — Validation & Persistence (`parseExtraction`, `UnifiedExtraction`, `Recording`)

The JSON parsing, validation, and persistence pipeline that sits between raw LLM output and persisted structured signals. Covers multi-stage JSON recovery, value clamping against `Levels.swift` enums, the `UnifiedExtraction` schema, `SummaryResult` assembly, and persistence via `Recording.applySummary()` / `setMedicationEvents()`.

> **This is Part 2 of 3.** It consumes the raw JSON string produced by [Part 1 — MLXJournalService Core](04b-1-mlx-journal-service.md), validates and persists the structured signals, which are then displayed and editable via [Part 3 — Extraction Review UI](04b-3-extraction-review-ui.md).

## Purpose

Describe how the raw JSON output from Llama inference is parsed, validated, clamped, and persisted into `Recording` model columns. Covers: `UnifiedExtraction` schema, the multi-stage JSON recovery pipeline (`parseExtraction`), value clamping rules, `SleepLevel` derivation, topic derivation, `SummaryResult` assembly, `Recording.applySummary()`, `Recording.setMedicationEvents()`, fallback and error handling, and haptic feedback.

## Scope

- **In scope**: `UnifiedExtraction` / `MedicationExtraction` schema, `parseExtraction` (JSON recovery + validation), `SummaryResult` assembly, `Recording.applySummary()`, `Recording.setMedicationEvents()`, fallback & error handling (FR-EXT-16, FR-EXT-17), haptic feedback (FR-EXT-15).
- **Out of scope**: LLM inference and prompt construction ([Part 1](04b-1-mlx-journal-service.md)), `ExtractionReviewView` / `ExtractionReviewViewModel` ([Part 3](04b-3-extraction-review-ui.md)), Whisper transcription ([04a](04a-whisperkit-transcription.md)), audio capture ([03](../fsd/03-check-in-capture.md)), library rendering ([05](../fsd/05-library-and-history.md)), insights ([06](../fsd/06-insights.md)), medication bar / Dose Guard ([07](../fsd/07-medications.md)).

---

## Integration contract

| Boundary | Direction | Data | Source |
|---|---|---|---|
| Part 1 → **Part 2** | Input | Raw JSON string from Llama inference | [04b-1](04b-1-mlx-journal-service.md) |
| **Part 2** → Part 3 | Output | Persisted `Recording` with populated signal columns | [04b-3](04b-3-extraction-review-ui.md) |
| **Part 2** → `ProcessingViewModel` | Output | `SummaryResult` returned from `summarize()` | Unchanged caller |

---

## Signal schema (source of truth: `Levels.swift`)

The validation layer must reject any value not in these sets.

| Signal | Enum | Valid labels (1 → 5) | Source |
|---|---|---|---|
| Mood | `MoodLevel` | `low`, `flat`, `okay`, `good`, `great` | [`Levels.swift:8-27`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift#L8-L27) |
| Energy | `EnergyLevel` | `sluggish`, `tired`, `steady`, `alert`, `charged` | [`Levels.swift:29-48`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift#L29-L48) |
| Focus | `FocusLevel` | `foggy`, `distracted`, `present`, `sharp`, `lockedIn` | [`Levels.swift:50-78`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift#L50-L78) |
| Sleep quality | `SleepLevel` | `restless`, `light`, `okay`, `good`, `deep` | [`Levels.swift:80-99`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift#L80-L99) |

> **Critical:** The original Llama FSD specified `["Great", "Good", "Okay", "Bad", "Awful"]` for mood and 3-step energy/focus scales. These **do not match** the codebase. The prompt ([Part 1](04b-1-mlx-journal-service.md)) and validation must use the 5-step labels above.

---

## Functional requirements

### Extraction output schema (`UnifiedExtraction`)

```swift
struct UnifiedExtraction: Codable {
    var mood: String?           // MoodLevel rawValue or null
    var energy: String?         // EnergyLevel rawValue or null
    var focus: String?          // FocusLevel rawValue or null
    var sleepHours: Double?     // 0-24 or null
    var sleepQuality: String?   // SleepLevel rawValue or null
    var medications: [MedicationExtraction]
    var emotions: [String]      // subset of the 20 curated emotions
    var activities: [String]    // subset of the 11 activity categories
    var topics: [String]        // 1-4 high-level themes
    var lexicon: [String]       // 3-5 user phrases/slang verbatim
    var summary: String?        // null for brief check-ins; empathetic 2nd person for journals
    var sideEffects: [String]   // from sideEffectCues/physicalSideEffects
}

struct MedicationExtraction: Codable {
    var name: String            // medication name
    var dose: String?           // e.g. "36mg", "morning dose"
    var taken: Bool             // true = taken, false = missed/skipped
}
```

---

### Layer 4 Swift-side validation (`parseExtraction`)

- **FR-EXT-09 — Multi-stage JSON recovery.** Because a 1B model can produce malformed output, parsing uses a fallback chain:
  1. **Direct decode**: `try JSONDecoder().decode(UnifiedExtraction.self, from: data)`.
  2. **Strip backticks**: remove `` ```json `` / `` ``` `` wrappers and retry.
  3. **Substring extraction**: find first `{` to last `}` and decode that slice.
  4. If all fail → return `nil`.

- **FR-EXT-10 — Value clamping.** After successful JSON decode, each field is validated:

  | Field | Validation | On failure |
  |---|---|---|
  | `mood` | Must be one of `["low", "flat", "okay", "good", "great"]` | Set `nil` |
  | `energy` | Must be one of `["sluggish", "tired", "steady", "alert", "charged"]` | Set `nil` |
  | `focus` | Must be one of `["foggy", "distracted", "present", "sharp", "lockedIn"]` | Set `nil` |
  | `sleepHours` | Must be `0.0 ... 24.0` | Set `nil` |
  | `sleepQuality` | Must be one of `["restless", "light", "okay", "good", "deep"]` | Set `nil` |
  | `emotions` | Each must be in the 20 curated emotions from lexicon | Drop unrecognised |
  | `medications[].name` | Validated against ~90 lexicon names (case-insensitive) | **Keep** (user may mention non-ADHD meds) |
  | `medications[].taken` | Must be `Bool` | Default `true` |
  | `topics` | Max 4 entries | Truncate |
  | `lexicon` | Max 5 entries | Truncate |
  | `activities` | Each must be in the 11 category names | Drop unrecognised |
  | `sideEffects` | Each must be in `sideEffectCues` ∪ `physicalSideEffects` | Drop unrecognised |
  | `summary` | If empty string → set `nil` | — |

- **FR-EXT-11 — SleepLevel derivation.** If the LLM outputs `sleepQuality` directly, use it. Otherwise, derive from `sleepHours` using the existing legacy logic:

  | Sleep hours | Derived `SleepLevel` |
  |---|---|
  | < 5 | `.restless` |
  | 5 ..< 6 | `.light` |
  | 6 ..< 7 | `.okay` |
  | 7 ..< 9 | `.good` |
  | ≥ 9 | `.deep` |

  Source: `NLSummarizationService.swift:61-72` (preserved logic).

- **FR-EXT-12 — Topic derivation rules.** The LLM generates topics semantically, but validation enforces:
  - `"Medications"` must be present if any medication events were extracted.
  - `"Symptoms"` must be present if `sideEffects` or `reboundTerms` are non-empty.
  - `"Appointments"` must be present if appointment-related language was detected.
  
  Source: `NLSummarizationService.deriveTopics(from:)` (preserved logic).

---

### Persistence (`Recording.applySummary` + `setMedicationEvents`)

These methods are **unchanged** from the legacy pipeline. Source: [`Recording.swift:202-355`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Models/Recording.swift#L202-L355).

- **FR-EXT-13 — applySummary.** Maps the `SummaryResult` onto `Recording` columns:
  - **Normal mode** (`fillOnly: false`): writes all scalar columns (`mood`, `energyLevel`, `focusLevel`, `sleepHours`, `sleepQuality`, `sleepLevelValue`, `medicationInfo`). Generates a title from signal parts (`"Good · Alert · Sharp"`). Writes JSON columns for bullets, emotions, side effects, sleep event, topics. Strips mood/energy/focus/emotions/sideEffects/sleepHours from the persisted `noteExtractionJSON` (they live in scalar columns — single source of truth). Sets `summaryStatus = .completed`.
  - **fillOnly mode** (`fillOnly: true`): only writes nil columns — user-entered values from the text check-in composer are never overwritten.

- **FR-EXT-14 — setMedicationEvents.** Replaces transcript-sourced `MedicationEvent` rows:
  1. Collects names of `source == .manual` events (manual dose beats extractor).
  2. Deletes all `source == .transcript` events.
  3. Creates new `MedicationEvent` for each extracted med not in the manual set.
  4. Duration resolution: per-med `durationHours` ?? call-site default ?? **10.0 h**.
  5. `takenAt` resolved from `med.time` / `med.timeLabel` / `recording.createdAt`.
  6. Sets `hasMedication` from inputs (not from the relationship, which has stale deletes pre-save).

- **FR-EXT-15 — Haptic feedback.** On successful extraction, `ProcessingViewModel` triggers `UINotificationFeedbackGenerator.success` (wired through the `summaryStatus = .completed` observation).

---

### Fallback & error handling

- **FR-EXT-16 — Graceful fallback.** If JSON parsing entirely fails (all 3 recovery stages exhaust), `summarize()` returns a `SummaryResult` with only the raw transcript as a single bullet, all signals nil. The UI shows the transcript; the user can manually enter details via the Edit sheet ([Part 3](04b-3-extraction-review-ui.md)). **The app never crashes.**

- **FR-EXT-17 — Memory pressure abort.** If `os_proc_available_memory()` reports < 200 MB before or during Llama inference, generation aborts. The raw transcript is preserved. Equivalent to a parse failure from the UI's perspective.

---

## User flows (Part 2 scope)

### Happy path — raw JSON to persisted signals
1. Raw JSON string arrives from Llama inference ([Part 1](04b-1-mlx-journal-service.md)).
2. `parseExtraction` attempts direct JSON decode.
3. On failure: strips backticks, retries. On failure: extracts `{…}` substring, retries.
4. On success: clamps each field against `Levels.swift` allowlists.
5. Derives `SleepLevel` from hours if `sleepQuality` is nil.
6. Enforces topic derivation rules (Medications, Symptoms, Appointments).
7. Assembles `SummaryResult`.
8. Returns to `ProcessingViewModel`.
9. `ProcessingViewModel` calls `recording.applySummary()` + `setMedicationEvents()`.
10. Haptic success. Check-in appears with structured signals.

### Fallback flows (Part 2 scope)
- **Hallucinated value**: "fantastic" for energy → not in `["sluggish", "tired", "steady", "alert", "charged"]` → set `nil`. Other valid signals survive.
- **Malformed JSON**: backtick stripping or substring extraction recovers it. If all fail → raw transcript only.
- **User correction**: Edit sheet ([Part 3](04b-3-extraction-review-ui.md)) → Save → provenance tags emitted with `.userCorrected`.

---

## Edge cases (Part 2 scope)

- **LLM outputs `"Bad"` for mood** → not in valid set → clamped to `nil`. Other signals survive.
- **LLM outputs `"lockedin"` (no camel case) for focus** → not in valid set → clamped to `nil`. The prompt ([Part 1](04b-1-mlx-journal-service.md)) must emphasise exact casing.
- **LLM wraps output in markdown** → backtick stripping catches `` ```json ... ``` ``.
- **LLM outputs extra text** → first-`{`-to-last-`}` extraction recovers the JSON.
- **LLM hallucinates a medication name** → kept (the user may mention a non-ADHD med not in the lexicon). The Edit sheet ([Part 3](04b-3-extraction-review-ui.md)) lets the user correct it.
- **Legacy `noteExtractionJSON` decode** → `Recording` decodes with `try?`, so any pre-migration JSON that fails to decode is silently nulled, not crashed.

---

## Validation rules & constants (Part 2 scope)

| Rule / constant | Value | Source |
|---|---|---|
| Valid Moods | `["low", "flat", "okay", "good", "great"]` | `Levels.swift:8-13` |
| Valid Energy | `["sluggish", "tired", "steady", "alert", "charged"]` | `Levels.swift:29-34` |
| Valid Focus | `["foggy", "distracted", "present", "sharp", "lockedIn"]` | `Levels.swift:50-55` |
| Valid Sleep | `["restless", "light", "okay", "good", "deep"]` | `Levels.swift:80-85` |
| SleepLevel from hours | <5→restless, 5–6→light, 6–7→okay, 7–9→good, ≥9→deep | `NLSummarizationService.swift:61-72` |
| Emotions | exactly 20 curated (5 per quadrant) | `lexicon.json:emotions` |
| Activities | exactly 11 categories | `lexicon.json:activityKeywords` |
| Medications | ~90 names (brand, generic, slang, misspellings) | `lexicon.json:medications` |
| Max Topics | 4 | Validation rule |
| Max Lexicon phrases | 5 | Validation rule |
| Med duration fallback | 10.0 h | `Recording.swift:342` |
| Memory abort threshold | < 200 MB available | `os_proc_available_memory()` |

---

## Acceptance criteria (Part 2 scope)

1. Signal values use **exactly** the `Levels.swift` enum rawValues — `low`/`flat`/`okay`/`good`/`great` for mood, `sluggish`/`tired`/`steady`/`alert`/`charged` for energy, `foggy`/`distracted`/`present`/`sharp`/`lockedIn` for focus.
2. Layer 4 validation rejects any mood/energy/focus value not in the canonical enum sets.
3. Emotions are validated against the exact 20 from `lexicon.json`.
4. If JSON parsing fails entirely, the user sees raw transcript with no crash.
5. `SummaryResult` returned from `summarize()` is identical in type to the legacy implementation — downstream consumers are unaffected.
6. `applySummary()` and `setMedicationEvents()` continue to function identically — no changes to persistence logic.

---

## Source references

- [`Levels.swift`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift) (authoritative signal enums)
- [`lexicon.json`](file:///Users/caesargrey/Projects/app-four-llama/docs/llama_migration/lexicon.json) (718 entries, 27 categories — validation allowlists)
- [`NLSummarizationService.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/NLSummarizationService.swift) (legacy — logic preserved in validation)
- [`Recording.swift:202-355`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Models/Recording.swift#L202-L355) (`applySummary`, `setMedicationEvents`)
- [`ProcessingViewModel.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/ProcessingViewModel.swift)
- Llama FSD: [`llama_extraction_fsd.md`](llama_extraction_fsd.md)
- Legacy NLP Reference: [`nlp_extractor_reference.md`](nlp_extractor_reference.md)
- Part 1: [04b-1 — MLXJournalService Core](04b-1-mlx-journal-service.md)
- Part 3: [04b-3 — Extraction Review UI](04b-3-extraction-review-ui.md)
