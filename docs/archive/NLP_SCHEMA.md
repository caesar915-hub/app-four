> **⚠️ HISTORICAL SNAPSHOT — superseded.** Frozen 2026-06-15. Pre-app-four (WhisperNotes/app-two era); does not reflect current project state. Current architecture lives in the Notion `app-two` DB, [docs/BACKLOG.md](../BACKLOG.md), and [docs/DEVLOG.md](../DEVLOG.md). Any "Gemma" mention is historical — Gemma was removed before the app-four fork.

# NLP Data Schema

> The complete data model for NLP extraction, persistence, and planned evolution in app-two.

---

## Current State

### `NoteExtraction` — raw NLP output

Produced by `NLNoteExtractor.extract(from:)`. Never persisted directly — fields are mapped to `Recording` via `NLSummarizationService` + `Recording.applySummary(_:)`.

```swift
struct NoteExtraction {
    // Core state
    var mood: String?               // free-text: "anxious", "calm", "flat" …
    var moodValence: Double?        // -1.0 (negative) → +1.0 (positive)
    var energy: EnergyLevel?        // .high | .steady | .low | .crashed
    var focus: FocusLevel?          // .hyperfocused | .focused | .scattered | .distracted | .foggy

    // Medication
    var medications: [MedEvent]

    // Symptoms & behaviour
    var sideEffects: [String]
    var executiveDysfunction: [String]
    var physicalStim: [String]
    var physicalSideEffects: [String]
    var reboundTerms: [String]
    var appetiteLoss: [String]
    var appetiteReturn: [String]

    // Tasks & wins
    var tasksCompleted: [String]
    var tasksAvoided: [String]
    var wins: [String]
    var overwhelm: [String]

    // Sleep
    var sleep: SleepNote?

    // Structured regex extractions
    var extractedDose: String?
    var sleepHours: Double?
    var onsetMinutes: Int?
    var durationHours: Double?
    var crashTime: String?
    var intakeContext: String?

    // Highlights → journal bullets
    var highlights: [String]
    var title: String
}
```

---

### `MedEvent` — single medication instance

```swift
struct MedEvent: Codable {
    var name: String        // "Concerta", "Elvanse" (brand name from lexicon)
    var dose: String?       // "36mg", "30mg XL"
    var time: String?       // HH:mm 24h e.g. "08:00"; nil when not derivable
    var timeLabel: String?  // raw phrasing: "around 10 am", "morning", "with breakfast"
    var taken: Bool         // false when negation detected ("forgot", "missed", "skipped")
}
```

---

### `EnergyLevel` / `FocusLevel` — enums

```swift
enum EnergyLevel: String, Codable {
    case high, steady, low, crashed
}

enum FocusLevel: String, Codable {
    case hyperfocused, focused, scattered, distracted, foggy
}
```

---

### `SleepNote`

```swift
struct SleepNote: Codable {
    var mentioned: Bool
    var hours: Double?      // "slept about 6.5 hours" → 6.5
    var quality: String?    // "poor", "good", "restless"
}
```

---

### `Recording` — persisted fields (SwiftData)

Only a subset of `NoteExtraction` is persisted. Fields marked **⚠ not persisted** are extracted but currently dropped after processing.

| Field | Type | Source | Notes |
|---|---|---|---|
| `mood` | `String?` | `NoteExtraction.mood` | Free-text mood label |
| `energyLevel` | `String?` | `NoteExtraction.energy.rawValue` | Enum → raw string |
| `focusLevel` | `String?` | `NoteExtraction.focus.rawValue` | Enum → raw string |
| `medicationsJSON` | `String?` | `[MedEvent]` encoded | Full medication array |
| `medicationInfo` | `String?` | Formatted string | Human-readable summary |
| `summaryBulletsJSON` | `String?` | `NoteExtraction.highlights` | Bullet points for Journal card |
| `topicTagsJSON` | `String?` | `[TopicCategory]` encoded | Topic tags array |
| `hasMedication` | `Bool` | Derived | True when medications non-empty |
| `summary` | `String?` | Bullets joined | Legacy field |
| `sleepHours` | `Double?` | `SummaryResult.sleepHours` | From regex extraction via `SleepNote.hours` |
| `sleepQuality` | `String?` | `SummaryResult.sleepQuality` | From `SleepNote.quality` (e.g. "poor", "restless") |
| `moodValence` | — | ⚠ not persisted | In NoteExtraction; not promoted to SummaryResult |
| `sideEffects` | — | ⚠ not persisted | In NoteExtraction; not promoted to SummaryResult |
| `executiveDysfunction` | — | ⚠ not persisted | In NoteExtraction; not promoted to SummaryResult |
| `physicalStim` | — | ⚠ not persisted | In NoteExtraction; not promoted to SummaryResult |
| `reboundTerms` | — | ⚠ not persisted | In NoteExtraction; not promoted to SummaryResult |
| `appetiteLoss` | — | ⚠ not persisted | In NoteExtraction; not promoted to SummaryResult |
| `onsetMinutes` | — | ⚠ not persisted | In NoteExtraction; not promoted to SummaryResult |
| `durationHours` | — | ⚠ not persisted | In NoteExtraction; not promoted to SummaryResult |
| `crashTime` | — | ⚠ not persisted | In NoteExtraction; not promoted to SummaryResult |

---

### `DisplayTag` — display only (not persisted)

Computed by `Recording.displayTags` in [Recording+MoodDisplay.swift](app-four/Models/Recording+MoodDisplay.swift). Derived at render time from persisted fields. Has no source or confidence metadata.

```swift
struct DisplayTag: Identifiable {
    let id: String      // "cat-medication", "energy", "med-Concerta"
    let label: String
    let icon: String    // SF Symbol name
}
```

---

## Planned Evolution

### 1. Persist missing `NoteExtraction` fields

Several extracted fields (`moodValence`, `sideEffects`, `reboundTerms`, `sleepHours`, etc.) are currently dropped after processing. These are high-value for weekly/monthly insights and should be persisted — either as new `Recording` columns or as a single `noteExtractionJSON: String?` blob.

### 2. Tag provenance model

When users can select tags during recording, every tag needs a source. Replace `DisplayTag` (display-only) with a persistent `RecordingTag` stored on `Recording`:

```swift
enum TagSource: String, Codable {
    case user           // selected during recording — ground truth
    case nlp            // extracted automatically — inferred
    case userCorrected  // user edited an NLP tag after the fact
}

struct RecordingTag: Codable {
    let name: String
    let category: TagCategory   // .mood, .medication, .energy, .focus, .topic
    let source: TagSource
    let confidence: Float?      // nil for user, 0–1 for NLP
}
```

Full design: `idea-tag-provenance.md` in project memory.

### 3. User lexicon entries (correction learning)

When users correct a tag, the source term is stored and injected into future extractions:

```swift
@Model class UserLexiconEntry {
    var term: String        // "wiped out"
    var category: String    // "energy"
    var mappedValue: String // "low"
    var addedAt: Date
}
```

`NLNoteExtractor` loads these at init alongside the base `Lexicon`. Full design: `idea-user-correction-learning.md` in project memory.

---

## Files

| File | Role |
|---|---|
| [NoteExtraction.swift](app-four/Services/NoteExtraction/NoteExtraction.swift) | `NoteExtraction`, `MedEvent`, `SleepNote`, enums |
| [NLNoteExtractor.swift](app-four/Services/NoteExtraction/NLNoteExtractor.swift) | Extraction engine |
| [Lexicon.swift](app-four/Services/NoteExtraction/Lexicon.swift) | Injectable vocabulary |
| [NLSummarizationService.swift](app-four/Services/NLSummarizationService.swift) | Maps `NoteExtraction` → `SummaryResult` → `Recording` |
| [Recording.swift](app-four/Models/Recording.swift) | SwiftData model, `applySummary(_:)` |
| [Recording+MoodDisplay.swift](app-four/Models/Recording+MoodDisplay.swift) | `DisplayTag`, `moodColor`, `moodIcon` |

---

## Related

- [NL_ARCHITECTURE.md](NL_ARCHITECTURE.md) — how the extraction pipeline works step by step
