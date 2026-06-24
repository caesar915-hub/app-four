# Phase 1 Data Model: Multilingual On-Device Check-in Extraction (Demo)

No SwiftData schema change. The persisted model already carries `emotions` and every field the
ported engine writes. The "data" here is the in-memory config/vocabulary and the bundled JSON.

## LanguageConfig (NEW Swift type — ported from spike)

`public nonisolated struct LanguageConfig: Codable, Sendable` — per-language tables, synthesized
Codable (no explicit `CodingKeys`). All fields required (non-optional). 17 stored properties:

| Field | Type | Role |
|---|---|---|
| `numberWords` | `[String: Double]` | spelled-out cardinals → value (sleep-hours reading) |
| `sleepWords` | `[String]` | curated sleep vocabulary (whole-token) |
| `sleepMultiwordPatterns` | `[String]` | extra sleep regexes ("a wink", "lay awake") |
| `sleepHoursPattern` | `String` | regex for "<n> hours" |
| `sleepBarePattern` | `String` | regex for terse "slept 7" |
| `weakEnergyTriggers` | `[String]` | gate substrings for the energy fallback |
| `weakEnergyTable` | `[WeakEnergyEntry]` | descriptor → `EnergyLevel` (ordered) |
| `weakEnergyDefaultLevel` / `…Phrase` | `EnergyLevel` / `String` | fallback when energy named, no descriptor |
| `weakMoodTriggerPattern` | `String` | regex gate for the mood fallback |
| `weakMoodTable` | `[WeakMoodEntry]` | descriptor → mood label (ordered) |
| `weakMoodDefaultLabel` / `…Phrase` | `String` / `String` | fallback when mood named, no descriptor |
| `presentMarkers` / `pastMarkers` | `[String]` | tense markers (TenseClassifier) |
| `pastVerbSuffixes` | `[String]` | past-tense suffixes (English `["ed"]`) |
| `irregularPastVerbs` | `[String]` | irregular past verbs |

- Nested: `WeakEnergyEntry {word: String, level: EnergyLevel}`, `WeakMoodEntry {word, label: String}`.
- `static let english` carries the canonical English values (the prior in-code literals).
- **Decoding rule**: extra JSON keys are ignored; a missing required key throws → loader falls back
  to `.english`. Packs MUST be complete (see contracts/language-pack.md).

## Pack key (selection model)

`packKey ∈ { "en", "pt-PT", "es-ES", "es-MX" }`. Derivation:
- language = `NLLanguageRecognizer` (constrained en/pt/es) over the check-in text.
- `portuguese → "pt-PT"`; `spanish → "es-MX"` iff `locale.region?.identifier == "MX"` else `"es-ES"`;
  otherwise `"en"`.
- `"en"` ⇒ in-code `LanguageConfig.english` (no `config.en.json`); the other three ⇒ load
  `config.<key>.json`.

## Lexicon / LexiconData (REUSED — unchanged shape)

`Lexicon` (typed vocab, 23 categories incl. `feelings`, `medications`, energy/focus tiers, sleep
quality, side-effect/appetite/rebound cues, activity keywords) and its JSON mirror `LexiconData`
(`Codable`, `toLexicon(personalOverlay:) -> Lexicon`) are reused as-is. `Lexicon.defaultEmotions`
keeps spec-020's curated 20 words as the code fallback. The vocab **input** key is `feelings`; it
feeds the **output** field `emotions`.

## PersonalLexicon overlay (REUSED — must be threaded)

`PersonalLexicon { medications, moodSpecific, feelings }`, built from `userCorrected`
`RecordingTag`s by `PersonalLexiconBuilder`. Merged on top of the selected pack's vocabulary inside
`toLexicon(personalOverlay:)`. The loader passes the same overlay the prod path uses today.

## NoteExtraction (REUSED — the output, no change)

The 6 demo signals map onto existing fields:

| Demo signal | NoteExtraction field(s) |
|---|---|
| mood | `mood: String?` |
| energy | `energy: EnergyLevel?` |
| focus | `focus: FocusLevel?` |
| sleep | `sleep: SleepNote?`, `sleepHours: Double?` |
| medications | `medications: [MedEvent]`, `extractedDose`, `onsetMinutes`, `durationHours`, `crashTime`, `intakeContext` |
| side-effects | `sideEffects`, `physicalSideEffects`, `reboundTerms`, **`appetiteLoss`**, `appetiteReturn` |

(`emotions: [String]` and the other expanded-triage fields are written too, unchanged.)
