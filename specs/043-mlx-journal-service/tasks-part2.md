# Tasks: Validation & Persistence — `parseExtraction`, `UnifiedExtraction`, `Recording`

**Input**: Design documents from `/specs/043-mlx-journal-service/`

**Prerequisites**: [plan-part2.md](file:///Users/caesargrey/Projects/app-four-llama/specs/043-mlx-journal-service/plan-part2.md) (required), [spec-part2.md](file:///Users/caesargrey/Projects/app-four-llama/specs/043-mlx-journal-service/spec-part2.md) (required for user stories)

**Tests**: Test-first is MANDATORY for logic (extraction schema, validator, parser, assembly) per Constitution **Principle X** — write the test, run it, confirm it **FAILS (RED)**, then implement just enough to make it pass (**GREEN**), then refactor. SwiftUI **views are EXEMPT** (no views in this feature). Tests use **Swift Testing** (`@Test`/`#expect`/`#require`). Each user story's Tests block below is REQUIRED, not optional.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

**Skills applied**: swift-testing (parameterized `@Test(arguments:)`, `#expect`/`#require`), swift-language (`enum` as namespace, `CaseIterable` for label enumeration, guard-else, switch expressions), swift-codable (`Codable` structs with `CodingKeys`, `JSONDecoder`), swift-api-design-guidelines (noun-based types, verb-based functions).

**Continuation**: This is Part 2. Part 1 tasks are in [tasks.md](file:///Users/caesargrey/Projects/app-four-llama/specs/043-mlx-journal-service/tasks.md). Task IDs here start at T100 to avoid collision.

---

## Phase 1: Foundational — `UnifiedExtraction` Schema (Blocking Prerequisites)

**Purpose**: Define the extraction output schema that all subsequent validation, derivation, and assembly logic depends on.

**⚠️ CRITICAL**: No validation or assembly work can begin until this phase is complete.

### Tests for `UnifiedExtraction` (test-first · RED — MANDATORY) ⚠️

> **RED**: Write these tests FIRST and RUN them — they MUST FAIL before any implementation.

- [ ] `T100` `[P]` `[Foundation]` **RED — Test: `UnifiedExtraction` decodes complete JSON**
  - **File:** [`app-fourTests/UnifiedExtractionTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/UnifiedExtractionTests.swift) [NEW]
  - **Action:** Create `@Suite struct UnifiedExtractionTests`. Add `@Test func decodesCompleteJSON() throws` — construct a JSON string with all 12 fields populated (mood: `"good"`, energy: `"steady"`, focus: `"sharp"`, sleepHours: `7.5`, sleepQuality: `"good"`, medications: `[{name: "Vyvanse", dose: "30mg", taken: true}]`, emotions: `["excited"]`, activities: `["Work"]`, topics: `["Medications"]`, lexicon: `["took my addy"]`, summary: `"You had a good day"`, sideEffects: `["appetite loss"]`). Decode via `JSONDecoder`. `#expect(extraction.mood == "good")`, `#expect(extraction.sleepHours == 7.5)`, `#expect(extraction.medications.count == 1)`, `#expect(extraction.medications[0].name == "Vyvanse")`, etc.
  - **Dependencies:** None
  - **Validation:** Test compiles but **FAILS** because `UnifiedExtraction` does not exist yet.

- [ ] `T101` `[P]` `[Foundation]` **RED — Test: `UnifiedExtraction` decodes partial JSON with missing optional fields**
  - **File:** [`app-fourTests/UnifiedExtractionTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/UnifiedExtractionTests.swift)
  - **Action:** Add `@Test func decodesPartialJSON() throws` — decode JSON with only `mood` and `energy` present. All other fields should default: `sleepHours == nil`, `sleepQuality == nil`, `medications` empty array, `emotions` empty array, `activities` empty array, `topics` empty array, `lexicon` empty array, `summary == nil`, `sideEffects` empty array.
  - **Dependencies:** T100 (same file)
  - **Validation:** Test compiles but **FAILS**.

- [ ] `T102` `[P]` `[Foundation]` **RED — Test: `MedicationExtraction` decodes correctly**
  - **File:** [`app-fourTests/UnifiedExtractionTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/UnifiedExtractionTests.swift)
  - **Action:** Add `@Test func medicationExtractionDecodes() throws` — decode `MedicationExtraction` from `{name: "Concerta", dose: "36mg", taken: true}`. `#expect(med.name == "Concerta")`, `#expect(med.dose == "36mg")`, `#expect(med.taken == true)`. Also test missing `dose` defaults to `nil`, missing `taken` defaults to `true`.
  - **Dependencies:** T100 (same file)
  - **Validation:** Test compiles but **FAILS**.

### Implementation for `UnifiedExtraction`

- [ ] `T103` `[Foundation]` **GREEN — Implement `UnifiedExtraction` and `MedicationExtraction`**
  - **File:** [`app-four/Services/NoteExtraction/UnifiedExtraction.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/NoteExtraction/UnifiedExtraction.swift) [NEW]
  - **Action:** Create the file with two public structs:
    ```swift
    public struct UnifiedExtraction: Codable, Sendable, Equatable {
        var mood: String?
        var energy: String?
        var focus: String?
        var sleepHours: Double?
        var sleepQuality: String?
        var medications: [MedicationExtraction]
        var emotions: [String]
        var activities: [String]
        var topics: [String]
        var lexicon: [String]
        var summary: String?
        var sideEffects: [String]
    }
    
    public struct MedicationExtraction: Codable, Sendable, Equatable {
        var name: String
        var dose: String?
        var taken: Bool
    }
    ```
    Use `init(from decoder:)` with `decodeIfPresent` for optionals and `decodeIfPresent(...) ?? []` for arrays so partial JSON works. Default `taken` to `true` if missing via `decodeIfPresent(Bool.self, forKey: .taken) ?? true`.
  - **Dependencies:** T100–T102 (tests must exist and FAIL first)
  - **Validation:** T100, T101, T102 turn **GREEN**.

**Checkpoint**: `UnifiedExtraction` schema is defined and tested. All subsequent phases can begin.

---

## Phase 2: User Story 1 — Multi-Stage JSON Recovery (Priority: P1) 🎯 MVP

**Goal**: Implement `parseExtraction(from:)` with 3-stage recovery: direct decode → backtick strip → substring extraction.

**Independent Test**: Pass known-malformed JSON strings and verify each recovery stage works.

### Tests for User Story 1 (test-first · RED — MANDATORY) ⚠️

> **RED**: Write these tests FIRST and RUN them — they MUST FAIL before any implementation.

- [ ] `T104` `[P]` `[US1]` **RED — Test: direct JSON decode succeeds**
  - **File:** [`app-fourTests/ParseExtractionTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/ParseExtractionTests.swift) [NEW]
  - **Action:** Create `@Suite struct ParseExtractionTests`. Add `@Test func directDecodeSucceeds()` — pass clean JSON `{"mood":"good","energy":"steady","medications":[],"emotions":[],"activities":[],"topics":[],"lexicon":[],"sideEffects":[]}` to `ExtractionValidator.parseExtraction(from:)`. `#expect(result != nil)`, `#expect(result?.mood == "good")`.
  - **Dependencies:** T103 (`UnifiedExtraction` must exist)
  - **Validation:** Test compiles but **FAILS** because `ExtractionValidator.parseExtraction` does not exist yet.

- [ ] `T105` `[P]` `[US1]` **RED — Test: backtick-wrapped JSON is recovered**
  - **File:** [`app-fourTests/ParseExtractionTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/ParseExtractionTests.swift)
  - **Action:** Add `@Test func backtickWrappedJsonRecovered()` — pass `` ```json\n{"mood":"good","medications":[],"emotions":[],"activities":[],"topics":[],"lexicon":[],"sideEffects":[]}\n``` `` to `parseExtraction(from:)`. `#expect(result != nil)`, `#expect(result?.mood == "good")`.
  - **Dependencies:** T104 (same file)
  - **Validation:** Test compiles but **FAILS**.

- [ ] `T106` `[P]` `[US1]` **RED — Test: JSON surrounded by prose is recovered**
  - **File:** [`app-fourTests/ParseExtractionTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/ParseExtractionTests.swift)
  - **Action:** Add `@Test func proseWrappedJsonRecovered()` — pass `"Here is the extraction:\n{\"mood\":\"good\",\"medications\":[],\"emotions\":[],\"activities\":[],\"topics\":[],\"lexicon\":[],\"sideEffects\":[]}\nI hope this helps!"` to `parseExtraction(from:)`. `#expect(result != nil)`, `#expect(result?.mood == "good")`.
  - **Dependencies:** T104 (same file)
  - **Validation:** Test compiles but **FAILS**.

- [ ] `T107` `[P]` `[US1]` **RED — Test: totally unparseable returns nil**
  - **File:** [`app-fourTests/ParseExtractionTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/ParseExtractionTests.swift)
  - **Action:** Add `@Test func totallyUnparseableReturnsNil()` — pass `"This is just a random string with no JSON at all"` to `parseExtraction(from:)`. `#expect(result == nil)`.
  - **Dependencies:** T104 (same file)
  - **Validation:** Test compiles but **FAILS**.

- [ ] `T108` `[P]` `[US1]` **RED — Test: empty string returns nil**
  - **File:** [`app-fourTests/ParseExtractionTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/ParseExtractionTests.swift)
  - **Action:** Add `@Test func emptyStringReturnsNil()` — pass `""` to `parseExtraction(from:)`. `#expect(result == nil)`.
  - **Dependencies:** T104 (same file)
  - **Validation:** Test compiles but **FAILS**.

### Implementation for User Story 1

- [ ] `T109` `[US1]` **GREEN — Implement `parseExtraction(from:)`**
  - **File:** [`app-four/Services/NoteExtraction/ExtractionValidator.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/NoteExtraction/ExtractionValidator.swift) [NEW — start of file]
  - **Action:** Create `enum ExtractionValidator` (caseless enum — no instances). Implement `static func parseExtraction(from rawJSON: String) -> UnifiedExtraction?`:
    1. **Stage 1 — Direct decode:** Convert `rawJSON` to `Data` (UTF-8). `try JSONDecoder().decode(UnifiedExtraction.self, from: data)`. If success → return.
    2. **Stage 2 — Strip backticks:** Use regex or `replacingOccurrences` to remove `` ```json `` and `` ``` `` wrappers (also handle `` ```JSON `` case-insensitive). Trim whitespace. Retry decode. If success → return.
    3. **Stage 3 — Substring extraction:** Find the index of first `{` and last `}`. Guard both exist and start < end. Extract the substring. Retry decode. If success → return.
    4. **Fallback:** Return `nil`.
  - **Dependencies:** T103 (`UnifiedExtraction`), T104–T108 (tests must FAIL first)
  - **Validation:** T104, T105, T106, T107, T108 turn **GREEN**.

**Checkpoint**: JSON recovery pipeline handles all known LLM output formats. Malformed output is recovered; truly broken output returns nil.

---

## Phase 3: User Story 2 — Value Clamping Against `Levels.swift` (Priority: P1)

**Goal**: Clamp every extracted signal field against canonical allowlists. Invalid values → nil. Invalid list entries → dropped.

**Independent Test**: Pass a `UnifiedExtraction` with mixed valid/invalid values and verify correct clamping.

### Tests for User Story 2 (test-first · RED — MANDATORY) ⚠️

> **RED**: Write these tests FIRST and RUN them — they MUST FAIL before any implementation.

- [ ] `T110` `[P]` `[US2]` **RED — Test: valid mood values pass clamping**
  - **File:** [`app-fourTests/ExtractionValidatorTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/ExtractionValidatorTests.swift) [NEW]
  - **Action:** Create `@Suite struct ExtractionValidatorTests`. Add `@Test(arguments: ["low", "flat", "okay", "good", "great"]) func validMoodPassesClamping(_ mood: String)` — construct a `UnifiedExtraction` with `mood = mood`, call `ExtractionValidator.validate(extraction, lexicon: lexicon)`, `#expect(result.mood == mood)`.
  - **Dependencies:** T103, T109 (`ExtractionValidator` file must exist)
  - **Validation:** Test compiles but **FAILS** because `validate()` does not exist yet.

- [ ] `T111` `[P]` `[US2]` **RED — Test: invalid mood values are clamped to nil**
  - **File:** [`app-fourTests/ExtractionValidatorTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/ExtractionValidatorTests.swift)
  - **Action:** Add `@Test(arguments: ["Bad", "fantastic", "Awful", "happy", "GOOD", ""]) func invalidMoodClampedToNil(_ mood: String)` — construct extraction with `mood = mood`, validate, `#expect(result.mood == nil)`.
  - **Dependencies:** T110 (same file)
  - **Validation:** Test compiles but **FAILS**.

- [ ] `T112` `[P]` `[US2]` **RED — Test: valid energy values pass, invalid clamped**
  - **File:** [`app-fourTests/ExtractionValidatorTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/ExtractionValidatorTests.swift)
  - **Action:** Add two tests:
    - `@Test(arguments: ["sluggish", "tired", "steady", "alert", "charged"]) func validEnergyPasses(_ energy: String)` — `#expect(result.energy == energy)`.
    - `@Test(arguments: ["fantastic", "Low", "energized", "CHARGED"]) func invalidEnergyClamped(_ energy: String)` — `#expect(result.energy == nil)`.
  - **Dependencies:** T110 (same file)
  - **Validation:** Test compiles but **FAILS**.

- [ ] `T113` `[P]` `[US2]` **RED — Test: valid focus values pass, invalid clamped**
  - **File:** [`app-fourTests/ExtractionValidatorTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/ExtractionValidatorTests.swift)
  - **Action:** Add two tests:
    - `@Test(arguments: ["foggy", "distracted", "present", "sharp", "lockedIn"]) func validFocusPasses(_ focus: String)` — `#expect(result.focus == focus)`.
    - `@Test(arguments: ["lockedin", "locked_in", "LockedIn", "focused"]) func invalidFocusClamped(_ focus: String)` — `#expect(result.focus == nil)`. Critical: `"lockedin"` (no camelCase) must be rejected.
  - **Dependencies:** T110 (same file)
  - **Validation:** Test compiles but **FAILS**.

- [ ] `T114` `[P]` `[US2]` **RED — Test: sleepHours clamped to 0–24 range**
  - **File:** [`app-fourTests/ExtractionValidatorTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/ExtractionValidatorTests.swift)
  - **Action:** Add `@Test func sleepHoursRangeClamping()`:
    - `sleepHours = 7.5` → `#expect(result.sleepHours == 7.5)` (valid, pass through)
    - `sleepHours = 0.0` → `#expect(result.sleepHours == 0.0)` (boundary, valid)
    - `sleepHours = 24.0` → `#expect(result.sleepHours == 24.0)` (boundary, valid)
    - `sleepHours = -1.0` → `#expect(result.sleepHours == nil)` (out of range)
    - `sleepHours = 25.0` → `#expect(result.sleepHours == nil)` (out of range)
    - `sleepHours = nil` → `#expect(result.sleepHours == nil)` (nil passthrough)
  - **Dependencies:** T110 (same file)
  - **Validation:** Test compiles but **FAILS**.

- [ ] `T115` `[P]` `[US2]` **RED — Test: valid sleepQuality passes, invalid clamped**
  - **File:** [`app-fourTests/ExtractionValidatorTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/ExtractionValidatorTests.swift)
  - **Action:** Add `@Test(arguments: ["restless", "light", "okay", "good", "deep"]) func validSleepQualityPasses(_ quality: String)` and `@Test(arguments: ["poor", "insomnia", "bad", "excellent"]) func invalidSleepQualityClamped(_ quality: String)`.
  - **Dependencies:** T110 (same file)
  - **Validation:** Test compiles but **FAILS**.

- [ ] `T116` `[P]` `[US2]` **RED — Test: emotions filtered against 20 curated**
  - **File:** [`app-fourTests/ExtractionValidatorTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/ExtractionValidatorTests.swift)
  - **Action:** Add `@Test func emotionFiltering()` — input emotions `["excited", "blissful", "grateful", "happy", "anxious"]`, validate, `#expect(result.emotions == ["excited", "grateful", "anxious"])` (blissful and happy dropped — not in the 20).
  - **Dependencies:** T110 (same file)
  - **Validation:** Test compiles but **FAILS**.

- [ ] `T117` `[P]` `[US2]` **RED — Test: activities filtered against 11 categories**
  - **File:** [`app-fourTests/ExtractionValidatorTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/ExtractionValidatorTests.swift)
  - **Action:** Add `@Test func activityFiltering()` — input activities `["Work", "Napping", "Fitness", "Meditating"]`, validate, `#expect(result.activities == ["Work", "Fitness"])` (Napping and Meditating not in 11 categories).
  - **Dependencies:** T110 (same file)
  - **Validation:** Test compiles but **FAILS**.

- [ ] `T118` `[P]` `[US2]` **RED — Test: sideEffects filtered against lexicon allowlists**
  - **File:** [`app-fourTests/ExtractionValidatorTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/ExtractionValidatorTests.swift)
  - **Action:** Add `@Test func sideEffectFiltering()` — input sideEffects with one valid entry from `lexicon.sideEffectCues` and one invalid. Verify only valid entries survive.
  - **Dependencies:** T110 (same file)
  - **Validation:** Test compiles but **FAILS**.

- [ ] `T119` `[P]` `[US2]` **RED — Test: topics truncated to max 4**
  - **File:** [`app-fourTests/ExtractionValidatorTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/ExtractionValidatorTests.swift)
  - **Action:** Add `@Test func topicsTruncated()` — input topics `["A", "B", "C", "D", "E"]` (5 items), validate, `#expect(result.topics.count == 4)`, `#expect(result.topics == ["A", "B", "C", "D"])`.
  - **Dependencies:** T110 (same file)
  - **Validation:** Test compiles but **FAILS**.

- [ ] `T120` `[P]` `[US2]` **RED — Test: lexicon phrases truncated to max 5**
  - **File:** [`app-fourTests/ExtractionValidatorTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/ExtractionValidatorTests.swift)
  - **Action:** Add `@Test func lexiconTruncated()` — input lexicon `["a", "b", "c", "d", "e", "f"]` (6 items), validate, `#expect(result.lexicon.count == 5)`.
  - **Dependencies:** T110 (same file)
  - **Validation:** Test compiles but **FAILS**.

- [ ] `T121` `[P]` `[US2]` **RED — Test: empty summary string set to nil**
  - **File:** [`app-fourTests/ExtractionValidatorTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/ExtractionValidatorTests.swift)
  - **Action:** Add `@Test func emptySummarySetToNil()` — input summary `""`, validate, `#expect(result.summary == nil)`. Also test `"  "` (whitespace only) → nil.
  - **Dependencies:** T110 (same file)
  - **Validation:** Test compiles but **FAILS**.

- [ ] `T122` `[P]` `[US2]` **RED — Test: medication names are kept even if not in lexicon**
  - **File:** [`app-fourTests/ExtractionValidatorTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/ExtractionValidatorTests.swift)
  - **Action:** Add `@Test func nonLexiconMedicationsKept()` — input medications `[{name: "Tylenol", taken: true}]` (not in ADHD lexicon), validate, `#expect(result.medications.count == 1)`, `#expect(result.medications[0].name == "Tylenol")`.
  - **Dependencies:** T110 (same file)
  - **Validation:** Test compiles but **FAILS**.

### Implementation for User Story 2

- [ ] `T123` `[US2]` **GREEN — Implement `ExtractionValidator.validate()`**
  - **File:** [`app-four/Services/NoteExtraction/ExtractionValidator.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/NoteExtraction/ExtractionValidator.swift)
  - **Action:** Add `static func validate(_ extraction: UnifiedExtraction, lexicon: Lexicon) -> UnifiedExtraction` to the `ExtractionValidator` enum. Implementation:
    1. **Mood clamping:** `let validMoods = Set(MoodLevel.allCases.map(\.rawValue))` → if `extraction.mood` not in set → nil.
    2. **Energy clamping:** Same pattern with `EnergyLevel.allCases`.
    3. **Focus clamping:** Same pattern with `FocusLevel.allCases`.
    4. **SleepQuality clamping:** Same pattern with `SleepLevel.allCases`.
    5. **SleepHours clamping:** If not in `0.0...24.0` → nil.
    6. **Emotions filtering:** `extraction.emotions.filter { lexicon.emotions.contains($0) }`.
    7. **Activities filtering:** `extraction.activities.filter { name in lexicon.activityKeywords.contains { $0.category == name } }`.
    8. **SideEffects filtering:** Filter against `Set(lexicon.sideEffectCues + lexicon.physicalSideEffects)`.
    9. **Topics truncation:** `Array(extraction.topics.prefix(4))`.
    10. **Lexicon truncation:** `Array(extraction.lexicon.prefix(5))`.
    11. **Summary nil-on-empty:** If `summary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true` → nil.
    12. **Medications:** Keep all (FR-EXT-10 — user may mention non-ADHD meds). Default `taken` to `true` if somehow missing.
    Return a new `UnifiedExtraction` with all clamped values.
  - **Dependencies:** T103 (`UnifiedExtraction`), T109 (`ExtractionValidator` file exists), T110–T122 (tests must FAIL first)
  - **Validation:** T110–T122 turn **GREEN**.

**Checkpoint**: All field clamping works. Invalid LLM outputs are rejected. Valid signals pass through. The validation layer is the primary defence against hallucinated values reaching persistence.

---

## Phase 4: User Story 3 — SleepLevel Derivation (Priority: P2)

**Goal**: Derive `SleepLevel` from `sleepHours` when `sleepQuality` is nil. Replicate the legacy mapping from `NLSummarizationService.swift:61-72`.

**Independent Test**: Pass various `sleepHours` values and verify correct `SleepLevel` derivation.

### Tests for User Story 3 (test-first · RED — MANDATORY) ⚠️

- [ ] `T124` `[P]` `[US3]` **RED — Test: SleepLevel derivation from hours**
  - **File:** [`app-fourTests/ExtractionValidatorTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/ExtractionValidatorTests.swift)
  - **Action:** Add parameterised test:
    ```swift
    @Test(arguments: [
        (4.0,  "restless"),  // < 5
        (4.9,  "restless"),  // boundary
        (5.0,  "light"),     // 5 ..< 6
        (5.5,  "light"),
        (6.0,  "okay"),      // 6 ..< 7
        (6.9,  "okay"),
        (7.0,  "good"),      // 7 ..< 9
        (8.0,  "good"),
        (8.9,  "good"),      // boundary
        (9.0,  "deep"),      // ≥ 9
        (10.0, "deep"),
    ])
    func sleepLevelDerivation(hours: Double, expected: String)
    ```
    Call `ExtractionValidator.deriveSleepLevel(hours:)` and `#expect(result == expected)`.
  - **Dependencies:** T109 (`ExtractionValidator` file exists)
  - **Validation:** Test compiles but **FAILS** because `deriveSleepLevel` does not exist yet.

- [ ] `T125` `[P]` `[US3]` **RED — Test: nil sleepHours returns nil SleepLevel**
  - **File:** [`app-fourTests/ExtractionValidatorTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/ExtractionValidatorTests.swift)
  - **Action:** Add `@Test func nilSleepHoursReturnsNilLevel()` — `#expect(ExtractionValidator.deriveSleepLevel(hours: nil) == nil)`.
  - **Dependencies:** T124 (same file)
  - **Validation:** Test compiles but **FAILS**.

- [ ] `T126` `[P]` `[US3]` **RED — Test: explicit sleepQuality takes precedence over hours**
  - **File:** [`app-fourTests/ExtractionValidatorTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/ExtractionValidatorTests.swift)
  - **Action:** Add `@Test func explicitQualityTakesPrecedence()` — construct extraction with `sleepQuality = "good"` and `sleepHours = 4.0`. After full validation, `#expect(result.sleepQuality == "good")` (explicit value wins over hours-derived "restless").
  - **Dependencies:** T124 (same file)
  - **Validation:** Test compiles but **FAILS**.

### Implementation for User Story 3

- [ ] `T127` `[US3]` **GREEN — Implement `deriveSleepLevel(hours:)`**
  - **File:** [`app-four/Services/NoteExtraction/ExtractionValidator.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/NoteExtraction/ExtractionValidator.swift)
  - **Action:** Add `static func deriveSleepLevel(hours: Double?) -> String?` to `ExtractionValidator`:
    ```swift
    static func deriveSleepLevel(hours: Double?) -> String? {
        guard let hours else { return nil }
        return switch hours {
        case ..<5:    SleepLevel.restless.rawValue
        case 5..<6:   SleepLevel.light.rawValue
        case 6..<7:   SleepLevel.okay.rawValue
        case 7..<9:   SleepLevel.good.rawValue
        default:      SleepLevel.deep.rawValue
        }
    }
    ```
    Also wire into `validate()`: if `sleepQuality` is nil after clamping but `sleepHours` is present, set `sleepQuality = deriveSleepLevel(hours: sleepHours)`.
  - **Dependencies:** T123 (`validate()` exists), T124–T126 (tests must FAIL first)
  - **Validation:** T124, T125, T126 turn **GREEN**.

**Checkpoint**: SleepLevel derivation matches legacy behaviour. Explicit quality takes precedence over hours-derived.

---

## Phase 5: User Story 4 — Topic Derivation Rules (Priority: P2)

**Goal**: Inject mandatory topics (`Medications`, `Symptoms`, `Appointments`) based on extracted content.

**Independent Test**: Verify correct topics are injected based on medications/sideEffects presence.

### Tests for User Story 4 (test-first · RED — MANDATORY) ⚠️

- [ ] `T128` `[P]` `[US4]` **RED — Test: Medications topic injected when meds present**
  - **File:** [`app-fourTests/ExtractionValidatorTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/ExtractionValidatorTests.swift)
  - **Action:** Add `@Test func medicationsTopicInjected()` — construct extraction with medications `[{name: "Vyvanse", taken: true}]` and topics `["Work"]`. After validation, `#expect(result.topics.contains("Medications"))`.
  - **Dependencies:** T123 (`validate()` exists)
  - **Validation:** Test compiles but **FAILS** because topic injection not yet implemented.

- [ ] `T129` `[P]` `[US4]` **RED — Test: Symptoms topic injected when sideEffects present**
  - **File:** [`app-fourTests/ExtractionValidatorTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/ExtractionValidatorTests.swift)
  - **Action:** Add `@Test func symptomsTopicInjected()` — construct extraction with sideEffects `["appetite loss"]` (valid, assumed to survive filtering), topics `["Sleep"]`. After validation, `#expect(result.topics.contains("Symptoms"))`.
  - **Dependencies:** T128 (same file)
  - **Validation:** Test compiles but **FAILS**.

- [ ] `T130` `[P]` `[US4]` **RED — Test: no duplicate topics injected**
  - **File:** [`app-fourTests/ExtractionValidatorTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/ExtractionValidatorTests.swift)
  - **Action:** Add `@Test func noDuplicateTopics()` — construct extraction with medications present and topics already containing `"Medications"`. After validation, verify `"Medications"` appears exactly once.
  - **Dependencies:** T128 (same file)
  - **Validation:** Test compiles but **FAILS**.

- [ ] `T131` `[P]` `[US4]` **RED — Test: no injection when content absent**
  - **File:** [`app-fourTests/ExtractionValidatorTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/ExtractionValidatorTests.swift)
  - **Action:** Add `@Test func noInjectionWhenContentAbsent()` — construct extraction with empty medications, empty sideEffects, topics `["Work"]`. After validation, `#expect(!result.topics.contains("Medications"))`, `#expect(!result.topics.contains("Symptoms"))`.
  - **Dependencies:** T128 (same file)
  - **Validation:** Test compiles but **FAILS**.

### Implementation for User Story 4

- [ ] `T132` `[US4]` **GREEN — Implement topic derivation in `validate()`**
  - **File:** [`app-four/Services/NoteExtraction/ExtractionValidator.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/NoteExtraction/ExtractionValidator.swift)
  - **Action:** Add `static func deriveTopics(_ topics: [String], extraction: UnifiedExtraction, lexicon: Lexicon) -> [String]` to `ExtractionValidator`:
    1. Start with the existing topics (already truncated to 4).
    2. If `!extraction.medications.isEmpty` and `"Medications"` not already in topics → insert.
    3. If `!extraction.sideEffects.isEmpty` and `"Symptoms"` not already in topics → insert.
    4. (Appointments detection: if any side effect or topic contains appointment language from `lexicon.appointmentCues` and `"Appointments"` not present → insert.)
    5. Re-truncate to max 4 after injection.
    Wire into `validate()` after field clamping.
  - **Dependencies:** T123, T127 (`validate()` with sleep derivation), T128–T131 (tests must FAIL first)
  - **Validation:** T128, T129, T130, T131 turn **GREEN**.

**Checkpoint**: Topic derivation replicates legacy `deriveTopics()` logic. Mandatory topics are injected without duplicates.

---

## Phase 6: User Story 5 — SummaryResult Assembly & Integration (Priority: P1)

**Goal**: Assemble a correctly-shaped `SummaryResult` from a validated `UnifiedExtraction`, map `MedicationExtraction` → `MedEvent`, and wire the full pipeline into `MLXJournalService.summarize()`.

**Independent Test**: Construct a validated extraction, assemble `SummaryResult`, verify all fields map correctly. Then run `MLXJournalService.summarize()` end-to-end and verify a valid `SummaryResult` is returned.

### Tests for User Story 5 (test-first · RED — MANDATORY) ⚠️

- [ ] `T133` `[P]` `[US5]` **RED — Test: `assembleSummaryResult` maps all fields correctly**
  - **File:** [`app-fourTests/SummaryResultAssemblyTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/SummaryResultAssemblyTests.swift) [NEW]
  - **Action:** Create `@Suite struct SummaryResultAssemblyTests`. Add `@Test func mapsAllFieldsCorrectly()` — construct a validated `UnifiedExtraction` with mood=`"good"`, energy=`"alert"`, focus=`"sharp"`, sleepHours=`8.0`, sleepQuality=`"good"`, summary=`"You had a productive day"`, emotions=`["excited"]`, topics=`["Work"]`, sideEffects=`["appetite loss"]`. Call `ExtractionValidator.assembleSummaryResult(from:lexicon:rawTranscript:)`. Verify:
    - `#expect(result.mood == "good")`
    - `#expect(result.energyLevel == "alert")`
    - `#expect(result.focusLevel == "sharp")`
    - `#expect(result.sleepHours == 8.0)`
    - `#expect(result.sleepQuality == "good")`
    - `#expect(result.sleepLevel == "good")`
    - `#expect(result.emotions == ["excited"])`
    - `#expect(result.topics == ["Work"])`
    - `#expect(result.sideEffects == ["appetite loss"])`
    - `#expect(!result.bullets.isEmpty)`
  - **Dependencies:** T109, T123 (`ExtractionValidator` with validate)
  - **Validation:** Test compiles but **FAILS** because `assembleSummaryResult` does not exist yet.

- [ ] `T134` `[P]` `[US5]` **RED — Test: `MedicationExtraction` maps to `MedEvent`**
  - **File:** [`app-fourTests/SummaryResultAssemblyTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/SummaryResultAssemblyTests.swift)
  - **Action:** Add `@Test func mapsMedicationToMedEvent()` — construct extraction with medications `[{name: "Vyvanse", dose: "30mg", taken: true}]`. Assemble `SummaryResult`. Verify `result.medications.count == 1`, `result.medications[0].name == "Vyvanse"`, `result.medications[0].dose == "30mg"`, `result.medications[0].taken == true`.
  - **Dependencies:** T133 (same file)
  - **Validation:** Test compiles but **FAILS**.

- [ ] `T135` `[P]` `[US5]` **RED — Test: title generated from signal parts**
  - **File:** [`app-fourTests/SummaryResultAssemblyTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/SummaryResultAssemblyTests.swift)
  - **Action:** Add `@Test func titleFromSignalParts()` — construct extraction with mood=`"good"`, energy=`"alert"`, focus=`"sharp"`. Assemble `SummaryResult`. `#expect(result.generatedTitle == "Good · Alert · Sharp")`. Also test with only mood present → title is `"Good"`. Test with no signals → title is `"Journal Entry"`.
  - **Dependencies:** T133 (same file)
  - **Validation:** Test compiles but **FAILS**.

- [ ] `T136` `[P]` `[US5]` **RED — Test: fallback SummaryResult on nil extraction**
  - **File:** [`app-fourTests/SummaryResultAssemblyTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/SummaryResultAssemblyTests.swift)
  - **Action:** Add `@Test func fallbackOnNilExtraction()` — call a fallback path with `rawTranscript = "I had a rough day"` and no parsed extraction. Verify `SummaryResult` has `bullets == ["I had a rough day"]`, all signal fields nil, `generatedTitle` is a sensible default.
  - **Dependencies:** T133 (same file)
  - **Validation:** Test compiles but **FAILS**.

### Implementation for User Story 5

- [ ] `T137` `[US5]` **GREEN — Implement `assembleSummaryResult(from:lexicon:rawTranscript:)`**
  - **File:** [`app-four/Services/NoteExtraction/ExtractionValidator.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/NoteExtraction/ExtractionValidator.swift)
  - **Action:** Add `static func assembleSummaryResult(from extraction: UnifiedExtraction, lexicon: Lexicon, rawTranscript: String) -> SummaryResult` to `ExtractionValidator`:
    1. **Title generation:** Build from signal parts: capitalize mood/energy/focus display labels, join with ` · `. Fall back to `"Journal Entry"` if all nil.
    2. **Bullets:** If `extraction.summary` is non-nil, split into sentences or use as single bullet. If nil, use raw transcript as single bullet.
    3. **Medications mapping:** `extraction.medications.map { med -> MedEvent in MedEvent(name: med.name, dose: med.dose, taken: med.taken) }`.
    4. **SleepEvent construction:** If `sleepHours` or `sleepQuality` present, construct `SleepEvent(mentioned: true, hours: extraction.sleepHours, quality: extraction.sleepQuality)`. Else nil.
    5. **SleepLevel:** Use validated `sleepQuality` or `deriveSleepLevel(hours:)` result.
    6. **NoteExtraction:** Construct a `NoteExtraction` preserving activities, lexicon phrases, and other fields for `noteExtractionJSON` (which `applySummary` strips scalar duplicates from).
    7. Return `SummaryResult(bullets:, medications:, generatedTitle:, energyLevel:, focusLevel:, mood:, sleepHours:, sleepQuality:, sleepEvent:, sleepLevel:, sideEffects:, emotions:, topics:, noteExtraction:)`.
    
    Also add `static func fallbackResult(rawTranscript: String) -> SummaryResult` — returns transcript-only result with all signals nil.
  - **Dependencies:** T123, T127, T132 (validator complete), T133–T136 (tests must FAIL first)
  - **Validation:** T133, T134, T135, T136 turn **GREEN**.

- [ ] `T138` `[US5]` **Refactor `MLXJournalService.summarize()` to use validation pipeline**
  - **File:** [`app-four/Services/MLXJournalService.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/MLXJournalService.swift)
  - **Action:** Refactor `summarize()` (lines 52-116):
    1. **Remove** the private `LLMExtractionResponse` struct (lines 20-36) and `LLMMedicationEntry` struct (lines 8-18).
    2. **Replace** lines 84-115 (direct decode + mapping) with:
       ```swift
       // Parse with 3-stage recovery
       guard let extraction = ExtractionValidator.parseExtraction(from: rawJSON) else {
           return ExtractionValidator.fallbackResult(rawTranscript: trimmed)
       }
       // Validate and clamp all fields
       let validated = ExtractionValidator.validate(extraction, lexicon: lexicon)
       // Assemble SummaryResult
       return ExtractionValidator.assembleSummaryResult(
           from: validated, lexicon: lexicon, rawTranscript: trimmed
       )
       ```
    3. The empty-transcript guard, model loading, prompt building, and inference call remain unchanged.
  - **Dependencies:** T137 (`assembleSummaryResult` exists), T109, T123, T127, T132
  - **Validation:** Existing `MLXJournalServiceTests` (T012–T015 from Part 1) still pass. Project builds. `summarize()` returns correctly-validated `SummaryResult`.

**Checkpoint**: Full pipeline wired: inference → parseExtraction → validate → assembleSummaryResult → SummaryResult. All downstream consumers (`ProcessingViewModel`, `Recording.applySummary()`, `Recording.setMedicationEvents()`) continue to work unchanged.

---

## Phase 7: User Story 6 — Graceful Fallback (Priority: P1)

**Goal**: Verify that total parse failure returns a transcript-only `SummaryResult` and the app never crashes.

**Independent Test**: Pass garbage to `summarize()` and verify the returned `SummaryResult` has raw transcript and nil signals.

> **Note**: Most of this is already covered by T107/T108 (parse returns nil) and T136/T137 (fallback result). This phase adds end-to-end verification.

- [ ] `T139` `[US6]` **Integration test: garbage input returns transcript-only result**
  - **File:** [`app-fourTests/SummaryResultAssemblyTests.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-fourTests/SummaryResultAssemblyTests.swift)
  - **Action:** Add `@Test func endToEndFallback()` — construct a raw JSON string that fails all 3 parse stages. Call the full `ExtractionValidator.parseExtraction()` → nil → `fallbackResult(rawTranscript:)` path. Verify `result.mood == nil`, `result.energyLevel == nil`, `result.focusLevel == nil`, `result.bullets == [rawTranscript]`, `result.medications.isEmpty`.
  - **Dependencies:** T137, T138
  - **Validation:** Test passes. No crash.

**Checkpoint**: Graceful fallback verified. The app never crashes on unparseable LLM output.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Full test suite, build verification, and cleanup.

- [ ] `T140` `[P]` `[Polish]` **Run full test suite and verify all GREEN**
  - **File:** N/A (test runner)
  - **Action:** Run `xcodebuild test` for the `app-four` scheme. Verify all existing tests pass (no regressions from Part 1) and all new Part 2 tests (T100–T139) pass.
  - **Dependencies:** All previous tasks
  - **Validation:** Full suite green. Zero test failures.

- [ ] `T141` `[P]` `[Polish]` **Verify build succeeds for release configuration**
  - **File:** N/A (build system)
  - **Action:** Run `xcodebuild build -scheme app-four -configuration Release`. Verify no release-only build issues.
  - **Dependencies:** T138
  - **Validation:** Release build succeeds with no errors or warnings.

- [ ] `T142` `[Polish]` **Commit Part 2 changes**
  - **File:** N/A (git)
  - **Action:** Stage all new and modified files. Commit with message `feat(043): Part 2 — validation & persistence pipeline (parseExtraction, ExtractionValidator, UnifiedExtraction)`. Push `feat/043-mlx-journal-service` branch.
  - **Dependencies:** T140, T141
  - **Validation:** Branch pushed. Ready for `/code-review`.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Foundation)**: No dependencies — start immediately. T100–T102 run in parallel.
- **Phase 2 (US1 — Parse)**: Depends on T103 (`UnifiedExtraction`). Tests T104–T108 can run in parallel.
- **Phase 3 (US2 — Clamp)**: Depends on T109 (`ExtractionValidator` file exists). Tests T110–T122 can run in parallel.
- **Phase 4 (US3 — Sleep)**: Depends on T123 (`validate()` exists).
- **Phase 5 (US4 — Topics)**: Depends on T123. Can run in parallel with Phase 4.
- **Phase 6 (US5 — Assembly)**: Depends on T123, T127, T132 (all validation complete).
- **Phase 7 (US6 — Fallback)**: Depends on T137, T138 (assembly and refactor complete).
- **Phase 8 (Polish)**: Depends on all previous phases.

### Critical Path

```
T103 (UnifiedExtraction) → T109 (parseExtraction) → T123 (validate) → T127 (sleepLevel) + T132 (topics) → T137 (assembly) → T138 (refactor MLXJournalService) → T140 (full test suite)
```

### Within Each Phase

- Tests MUST be written, RUN, and confirmed FAILING (RED) before implementation (GREEN); refactor after green (Principle X)
- Schema before parser (Phase 1 before Phase 2)
- Parser before validator (Phase 2 before Phase 3)
- Validator before assembly (Phase 3–5 before Phase 6)
- Assembly before service refactor (T137 before T138)

### Parallel Opportunities

- T100–T102 can all be written in parallel (Phase 1 tests)
- T104–T108 can all be written in parallel (Phase 2 tests)
- T110–T122 can all be written in parallel (Phase 3 tests — same file, different functions)
- T124–T126 can run in parallel (Phase 4 tests)
- T128–T131 can run in parallel (Phase 5 tests)
- T133–T136 can run in parallel (Phase 6 tests)
- Phase 4 and Phase 5 can run in parallel (different functions in same file — no conflict if careful)

---

## Implementation Strategy

### MVP First (Schema + Parse + Clamp + Assembly)

1. Complete Phase 1: `UnifiedExtraction` schema (tested)
2. Complete Phase 2: `parseExtraction()` (3-stage recovery tested)
3. Complete Phase 3: `validate()` field clamping (all allowlists tested)
4. Complete Phase 6: `assembleSummaryResult()` + refactor `MLXJournalService`
5. **STOP and VALIDATE**: Run all tests. Verify extraction → validation → SummaryResult works end-to-end.
6. Deploy/demo if ready.

### Full Delivery

1. MVP (above) + Phase 4 (SleepLevel derivation) + Phase 5 (topic injection)
2. Phase 7 (fallback verification)
3. Phase 8 (polish, full suite, commit)
4. Each phase adds value without breaking previous phases.

---

## Notes

- `[P]` tasks = different files or independent test functions, no dependencies
- `[Story]` label maps task to specific user story for traceability
- Task IDs start at T100 to avoid collision with Part 1 tasks (T001–T028)
- `enum ExtractionValidator` (caseless) to prevent accidental instantiation
- Use `CaseIterable` for all label enumerations — never hardcode signal strings
- `UnifiedExtraction` is `Codable, Sendable, Equatable` — value type, no reference semantics
- `validate()` is a pure function: input → output, no side effects, no state mutation
- All validation uses `Set` for O(1) lookups (mood/energy/focus/sleep/emotions sets)
- `MedicationExtraction` → `MedEvent` mapping uses only the fields present in both types; `time`, `timeLabel`, `quantity`, `change`, `durationHours` default to nil (resolved later by `Recording.setMedicationEvents()`)

---

## Phase 9: User Story 7 — Memory Headroom Alert (Priority: P0)

**Goal**: Handle insufficient memory (< 200 MB) by aborting generation, preserving the transcript (fallback result), and alerting the UI.

### Tests for User Story 7 (test-first · RED — MANDATORY) ⚠️

- [x] `T143` `[P]` `[US7]` **RED — Test: ProcessingViewModel handles insufficientMemory**
  - **File:** `app-fourTests/ViewModels/ProcessingViewModelTests.swift` (create or update)
  - **Action:** Add a test verifying that when `SummarizationService` throws `SummarizationError.insufficientMemory`, the `ProcessingViewModel` catches it, sets `showMemoryError = true`, and successfully applies a fallback summary (transcript only) so `recording.summaryStatus == .completed`.
  - **Validation:** Test compiles but **FAILS**.

### Implementation for User Story 7

- [x] `T144` `[US7]` **GREEN — Implement insufficientMemory error and UI state**
  - **File:** `app-four/Services/Protocols.swift`, `app-four/ViewModels/ProcessingViewModel.swift`, `app-four/Services/MLXJournalService.swift`
  - **Action:** 
    1. Add `case insufficientMemory` to `SummarizationError`.
    2. In `MLXJournalService`, throw `.insufficientMemory` instead of `.modelNotInstalled` when `checkMemoryHeadroom` fails.
    3. In `ProcessingViewModel`, add `var showMemoryError: Bool = false`. Catch `SummarizationError.insufficientMemory`, set `showMemoryError = true`, generate a fallback `SummaryResult` using the raw transcript, and apply it to the recording (setting `summaryStatus = .completed`).
  - **Validation:** T143 turns **GREEN**.
