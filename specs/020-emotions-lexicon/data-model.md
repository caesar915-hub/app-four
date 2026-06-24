# Phase 1 Data Model: Emotions Lexicon

No new entities — this renames one field/category and swaps the vocabulary data. All changes preserve types and optionality.

## 1. `Recording` (`@Model`) — [Recording.swift](../../app-four/Models/Recording.swift)

| Before | After | Notes |
|---|---|---|
| `var feelingsJSON: String?` | `var emotionsJSON: String?` | Stays **optional** → CloudKit-compatible (Constitution IX). No `originalName`, no migration (wipe accepted). |
| `var decodedFeelings: [String]` | `var decodedEmotions: [String]` | Computed; decodes `emotionsJSON`. |
| `applySummary(...)`: `extraction.feelings = []`, `result.feelings`, writes `feelingsJSON` | `…emotions…`, writes `emotionsJSON` | Field is still excluded from the persisted `noteExtractionJSON` (dedicated column is source of truth). |

The init parameter `feelingsJSON:` → `emotionsJSON:` (and the corresponding assignment).

## 2. `TagCategory` — [RecordingTag.swift](../../app-four/Models/RecordingTag.swift)

```swift
enum TagCategory: String, Codable {
    case mood, energy, focus, medication
    case emotions   // was: feelings   (rawValue "emotions"; persisted in RecordingTag.category)
}
```

`RecordingTag.category` stores the **rawValue string**; old rows holding `"feelings"` are discarded by the store wipe.

## 3. `NoteExtraction` — [NoteExtraction.swift](../../app-four/Services/NoteExtraction/NoteExtraction.swift)

| Before | After |
|---|---|
| `public var feelings: [String]  // specific emotions` | `public var emotions: [String]` (comment now redundant → drop) |
| init param `feelings: [String] = []`, `self.feelings = feelings` | `emotions …` |
| `CodingKeys.feelings` | `CodingKeys.emotions` |
| `feelings = try c.decode([String].self, forKey: .feelings)` | `emotions = try c.decode([String].self, forKey: .emotions)` |

Decode stays a **required** key (consistent with the file's existing pattern). Old `noteExtractionJSON` blobs are gone with the wipe, so no legacy-key fallback is needed.

## 4. Extraction vocabulary — [Lexicon.swift](../../app-four/Services/NoteExtraction/Lexicon.swift), [LexiconData.swift](../../app-four/Services/NoteExtraction/LexiconData.swift), [lexicon.json](../../app-four/Resources/lexicon.json)

| Before | After |
|---|---|
| `Lexicon.feelings: [String]` / init `feelings:` / `self.feelings = feelings ?? Lexicon.defaultFeelings` | `emotions` / `defaultEmotions` |
| `Lexicon.defaultFeelings = [ ~32 words incl. "feeling seen" ]` | `Lexicon.defaultEmotions = [ the 20 ]` — see [contract](contracts/emotions-lexicon.md) |
| `LexiconData.feelings`, `extraFeelings`, init `feelings:` | `emotions`, `extraEmotions` |
| `lexicon.json` key `"feelings": [ ~60 words ]` | `"emotions": [ the 20 ]` |

**Untouched**: every `lexicon.json` mood/energy/focus cue-phrase that contains "feeling" (`"feeling down"`, `"feeling empty"`, `"feeling seen"`, etc.) — they belong to other categories.

## 5. Extractor + view-model + view

| Site | Before → After |
|---|---|
| [NLNoteExtractor.swift](../../app-four/Services/NoteExtraction/NLNoteExtractor.swift) | `detectedFeelings`→`detectedEmotions`; `cues.feelings`→`cues.emotions`; `lexicon.feelings`→`.emotions`; `extraction.feelings`→`.emotions` |
| [PersonalLexiconBuilder.swift](../../app-four/Services/NoteExtraction/PersonalLexiconBuilder.swift) | `feelings`/`seenFeelings`/`feelingsCategory`→`emotions`/`seenEmotions`/`emotionsCategory`; `PersonalLexicon(feelings:)`→`(emotions:)` |
| [Protocols.swift](../../app-four/Services/Protocols.swift) | `SummaryResult.feelings`→`.emotions` |
| [NLSummarizationService.swift](../../app-four/Services/NLSummarizationService.swift) | `feelings: extraction.feelings`→`emotions: extraction.emotions` |
| [ExportService.swift](../../app-four/Services/ExportService.swift) | export DTO `feelingsJSON`→`emotionsJSON` |
| [ExtractionReviewViewModel.swift](../../app-four/ViewModels/ExtractionReviewViewModel.swift) | `feelings: Set<String>`, `toggleFeeling`, `EditedField.feelings`, `category: .emotions` |
| [ExtractionReviewView.swift](../../app-four/Views/ExtractionReviewView.swift) | `feelingGroups`→`emotionGroups`; `feelingsField`→`emotionsField`; header `"07","Feelings"`→`"Emotions"`; a11y label |
| [CheckInViewModel.swift](../../app-four/ViewModels/CheckInViewModel.swift) | nudge `"Any strong feelings?"`→`"Any strong emotions?"` |
| [ADHDSummarySection.swift](../../app-four/Views/Components/ADHDSummarySection.swift), [Recording+MoodDisplay.swift](../../app-four/Models/Recording+MoodDisplay.swift) | `decodedEmotions`; DisplayTag id `"emotion-…"` |
| [MockDataGenerator.swift](../../app-four/Utils/MockDataGenerator.swift) | `feelingPool`→`emotionPool` seeded with the 20; `emotionsJSON` |

## Validation rules

- Emotions list length is exactly **20** (SC-002); 5 per quadrant.
- No emotion equals a value used by the mood/energy/focus axes (SC-003).
- `emotionsJSON` is the persisted source of truth for the chips; `NoteExtraction.emotions` is cleared before persisting `noteExtractionJSON` (no drift).
