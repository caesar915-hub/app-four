# Feature Specification: Validation & Persistence — `parseExtraction`, `UnifiedExtraction`, `Recording`

**Feature Branch**: `043-mlx-journal-service`

**Created**: 2026-08-12

**Status**: Draft

**Input**: User description: "The JSON parsing, validation, and persistence pipeline that sits between raw LLM output and persisted structured signals. Covers multi-stage JSON recovery, value clamping against `Levels.swift` enums, the `UnifiedExtraction` schema, `SummaryResult` assembly, and persistence via `Recording.applySummary()` / `setMedicationEvents()`."

**Source**: [`04b-2-validation-persistence.md`](file:///Users/caesargrey/Projects/app-four-llama/docs/llama_migration/04b-2-validation-persistence.md) (Part 2 of 3 — validation & persistence)

> **This is Part 2 of 3.** It consumes the raw JSON string produced by [Part 1 — MLXJournalService Core](file:///Users/caesargrey/Projects/app-four-llama/specs/043-mlx-journal-service/spec.md), validates and persists the structured signals, which are then displayed and editable via Part 3 — Extraction Review UI.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Multi-stage JSON recovery from malformed LLM output (Priority: P1)

After Llama inference produces a raw JSON string, the `parseExtraction` function attempts to decode it into a `UnifiedExtraction` struct. Because a 1B model frequently produces malformed output (markdown wrappers, trailing text, missing brackets), parsing uses a 3-stage recovery chain: direct decode → strip backticks → substring extraction. If all fail, the system falls back gracefully to raw transcript only.

**Why this priority**: Without JSON recovery, even valid inference output wrapped in markdown backticks would fail to parse, making the entire LLM pipeline useless. This is the gatekeeper between raw inference and structured signals.

**Independent Test**: Pass known-malformed JSON strings (backtick-wrapped, trailing prose, nested markdown) to `parseExtraction()` and verify each recovery stage produces a valid `UnifiedExtraction`.

**Acceptance Scenarios**:

1. **Given** a well-formed JSON string from Llama, **When** `parseExtraction()` is called, **Then** it decodes directly via `JSONDecoder` on the first attempt and returns a valid `UnifiedExtraction`.
2. **Given** JSON wrapped in `` ```json ... ``` `` backtick fences, **When** direct decode fails, **Then** the backtick stripping stage removes the fences and successfully decodes.
3. **Given** JSON preceded by conversational text (e.g. "Here is the extraction:\n{...}"), **When** both direct decode and backtick strip fail, **Then** the substring extraction stage finds the first `{` to last `}` and successfully decodes that slice.
4. **Given** completely unparseable output (no JSON structure at all), **When** all 3 stages fail, **Then** `parseExtraction()` returns `nil` and the caller falls back to raw transcript.

---

### User Story 2 — Value clamping against `Levels.swift` enums (Priority: P1)

After successful JSON decode, every extracted signal field is validated against the canonical enum values from `Levels.swift`. Invalid values (hallucinated labels, wrong casing, legacy 3-step labels) are clamped to `nil` rather than propagated — ensuring only valid signals reach persistence.

**Why this priority**: The 1B model regularly hallucinates signal values not in the canonical set. Without clamping, invalid values would persist and corrupt downstream views (DayCard, Insights, Charts).

**Independent Test**: Pass a `UnifiedExtraction` with a mix of valid and invalid signal values to the clamping logic and verify each field is correctly validated or nulled.

**Acceptance Scenarios**:

1. **Given** mood = `"good"` (valid), energy = `"fantastic"` (invalid), focus = `"sharp"` (valid), **When** clamping runs, **Then** mood = `"good"`, energy = `nil`, focus = `"sharp"`.
2. **Given** mood = `"Bad"` (legacy label, not in valid set), **When** clamping runs, **Then** mood = `nil`.
3. **Given** focus = `"lockedin"` (missing camelCase), **When** clamping runs, **Then** focus = `nil` (exact match required: `"lockedIn"`).
4. **Given** `sleepHours` = `25.0` (out of range 0–24), **When** clamping runs, **Then** `sleepHours` = `nil`.
5. **Given** `sleepHours` = `7.5` (valid), **When** clamping runs, **Then** `sleepHours` = `7.5` (unchanged).
6. **Given** emotions = `["excited", "blissful", "grateful"]`, **When** clamping runs, **Then** emotions = `["excited", "grateful"]` (`"blissful"` dropped, not in the 20 curated emotions).
7. **Given** activities = `["Work", "Napping", "Fitness"]`, **When** clamping runs, **Then** activities = `["Work", "Fitness"]` (`"Napping"` dropped, not one of the 11 categories).
8. **Given** topics = `["Medications", "Work", "Sleep", "Exercise", "School"]` (5 items), **When** clamping runs, **Then** topics is truncated to the first 4: `["Medications", "Work", "Sleep", "Exercise"]`.
9. **Given** summary = `""` (empty string), **When** clamping runs, **Then** summary = `nil`.

---

### User Story 3 — SleepLevel derivation from hours (Priority: P2)

When the LLM provides `sleepHours` but not `sleepQuality`, the system derives a `SleepLevel` using the existing legacy mapping. When the LLM provides `sleepQuality` directly, that value is used as-is (after clamping).

**Why this priority**: Important for preserving behaviour parity with the legacy NLP pipeline, but the LLM usually outputs `sleepQuality` directly so this is a fallback path.

**Independent Test**: Pass `UnifiedExtraction` instances with various `sleepHours` / `sleepQuality` combinations and verify the correct `SleepLevel` is derived.

**Acceptance Scenarios**:

1. **Given** `sleepQuality` = `"good"` (valid) and `sleepHours` = `4.0`, **When** derivation runs, **Then** `sleepQuality` = `"good"` (explicit value takes precedence over hours-based derivation).
2. **Given** `sleepQuality` = `nil` and `sleepHours` = `4.0`, **When** derivation runs, **Then** `sleepQuality` = `"restless"` (< 5 hours).
3. **Given** `sleepQuality` = `nil` and `sleepHours` = `5.5`, **When** derivation runs, **Then** `sleepQuality` = `"light"` (5 ..< 6).
4. **Given** `sleepQuality` = `nil` and `sleepHours` = `6.5`, **When** derivation runs, **Then** `sleepQuality` = `"okay"` (6 ..< 7).
5. **Given** `sleepQuality` = `nil` and `sleepHours` = `8.0`, **When** derivation runs, **Then** `sleepQuality` = `"good"` (7 ..< 9).
6. **Given** `sleepQuality` = `nil` and `sleepHours` = `10.0`, **When** derivation runs, **Then** `sleepQuality` = `"deep"` (≥ 9).
7. **Given** both `sleepQuality` = `nil` and `sleepHours` = `nil`, **When** derivation runs, **Then** `sleepQuality` = `nil`.

---

### User Story 4 — Topic derivation rules (Priority: P2)

After the LLM generates topics semantically, validation enforces mandatory topic presence based on extracted content: `"Medications"` is injected if any medication events were extracted, `"Symptoms"` if side effects or rebound terms are present, `"Appointments"` if appointment-related language was detected.

**Why this priority**: Ensures topic integrity for downstream displays (DayCard topics, search) regardless of whether the LLM remembered to include them.

**Independent Test**: Pass `UnifiedExtraction` instances with medications/sideEffects present and verify the correct topics are injected.

**Acceptance Scenarios**:

1. **Given** `medications` = `[{name: "Vyvanse", taken: true}]` and topics = `["Work"]`, **When** topic derivation runs, **Then** topics includes `"Medications"` (injected) alongside `"Work"`.
2. **Given** `sideEffects` = `["appetite loss"]` and topics = `["Sleep"]`, **When** topic derivation runs, **Then** topics includes `"Symptoms"` (injected) alongside `"Sleep"`.
3. **Given** `medications` = `[]` and `sideEffects` = `[]` and topics = `["Work", "Sleep"]`, **When** topic derivation runs, **Then** topics = `["Work", "Sleep"]` (no injection needed).
4. **Given** topics already contains `"Medications"` and medications is non-empty, **When** topic derivation runs, **Then** no duplicate `"Medications"` is added.

---

### User Story 5 — SummaryResult assembly and persistence (Priority: P1)

After validation and derivation, the pipeline assembles a `SummaryResult` and returns it to `ProcessingViewModel`, which calls `Recording.applySummary()` and `Recording.setMedicationEvents()` to persist all structured signals. These persistence methods are **unchanged** from the legacy pipeline — the new validation layer produces the same `SummaryResult` type.

**Why this priority**: Persistence is the final step — if `SummaryResult` assembly is wrong or `applySummary()` receives unexpected data, signals are lost or corrupted.

**Independent Test**: Construct a `SummaryResult` from a fully validated `UnifiedExtraction` and verify that `Recording.applySummary()` correctly populates all scalar columns, JSON columns, and generates the expected title.

**Acceptance Scenarios**:

1. **Given** a fully validated `UnifiedExtraction` with mood=`"good"`, energy=`"alert"`, focus=`"sharp"`, **When** `SummaryResult` is assembled and `applySummary(fillOnly: false)` is called, **Then** `Recording.mood` = `"good"`, `Recording.energyLevel` = `"alert"`, `Recording.focusLevel` = `"sharp"`, and title = `"Good · Alert · Sharp"`.
2. **Given** `applySummary(fillOnly: true)` is called and `Recording.mood` already has a user-entered value, **When** the `SummaryResult` contains a different mood, **Then** the existing user value is **not overwritten**.
3. **Given** a `UnifiedExtraction` with medications = `[{name: "Vyvanse", dose: "30mg", taken: true}]`, **When** `setMedicationEvents()` is called, **Then** a new `MedicationEvent` with `source = .transcript` is created for "Vyvanse", duration defaults to 10.0h, and `hasMedication` is set to `true`.
4. **Given** a manual `MedicationEvent` for "Vyvanse" already exists (`source = .manual`), **When** `setMedicationEvents()` is called with an extracted "Vyvanse", **Then** the manual event is preserved (not overwritten) — manual dose beats extractor.
5. **Given** `summaryStatus` transitions to `.completed`, **When** `ProcessingViewModel` observes this, **Then** `UINotificationFeedbackGenerator.success` is triggered (haptic feedback).

---

### User Story 6 — Graceful fallback on total parse failure (Priority: P1)

When JSON parsing fails entirely (all 3 recovery stages exhausted), the pipeline returns a `SummaryResult` with only the raw transcript as a single bullet and all signal fields nil. The app never crashes.

**Why this priority**: Crash prevention is non-negotiable. The user must always see their transcript even if extraction fails.

**Independent Test**: Pass completely unparseable output to `summarize()` and verify the returned `SummaryResult` contains the raw transcript with all structured fields nil.

**Acceptance Scenarios**:

1. **Given** Llama output is completely unparseable garbage, **When** `summarize()` completes, **Then** `SummaryResult` contains `rawTranscript` as a single bullet, all signal fields nil, and `summaryStatus = .completed`.
2. **Given** `os_proc_available_memory()` reports < 200 MB, **When** `summarize()` is called, **Then** extraction aborts before loading weights, raw transcript is preserved, and the app does not crash.

---

### Edge Cases & Error Handling

#### 1. Network & Connectivity Failures
- **Scenario:** Not applicable — the entire validation and persistence pipeline is on-device with zero network calls.
- **System Behavior:** No network dependency exists.
- **User Experience (UX):** No change; works in airplane mode.

#### 2. Data Validation & Bad Input
- **Scenario:** LLM outputs `"Bad"` for mood (legacy 3-step label), `"lockedin"` for focus (wrong casing), `"fantastic"` for energy (hallucinated).
- **System Behavior:** Each invalid value is clamped to `nil`. Other valid signals in the same extraction survive. The `UnifiedExtraction` struct is partially populated with only valid fields.
- **User Experience (UX):** The user sees the valid signals pre-filled; nil signals appear empty and can be manually entered via the Edit sheet (Part 3).

#### 3. State Restoration & Interruptions
- **Scenario:** App is backgrounded or crashes between JSON parse and `applySummary()`.
- **System Behavior:** `PendingTranscriptionServiceImpl` retries extraction on next launch. The raw transcript is always preserved in `Recording.rawTranscription`.
- **User Experience (UX):** User sees "Processing…" on the recording; extraction completes on next app launch.

#### 4. LLM Hallucinated Medication Name
- **Scenario:** LLM outputs a medication name not in the ~90 lexicon names (e.g. "Tylenol" — valid medicine but not ADHD-specific).
- **System Behavior:** The medication is **kept** (not rejected). The user may mention non-ADHD medications. The Edit sheet (Part 3) allows correction.
- **User Experience (UX):** The extracted medication appears in the check-in; the user can remove or edit it.

#### 5. Legacy `noteExtractionJSON` decode failure
- **Scenario:** Pre-migration `Recording` objects have JSON in `noteExtractionJSON` that doesn't match the new schema.
- **System Behavior:** `Recording` decodes with `try?`, so any pre-migration JSON that fails to decode is silently nulled, not crashed.
- **User Experience (UX):** Old recordings display normally; nil fields simply show as empty.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-EXT-09**: System MUST implement multi-stage JSON recovery in `parseExtraction()`:
  1. Direct decode via `JSONDecoder().decode(UnifiedExtraction.self, from: data)`.
  2. Strip `` ```json `` / `` ``` `` backtick wrappers and retry.
  3. Find first `{` to last `}` (substring extraction) and decode that slice.
  4. If all fail → return `nil`.

- **FR-EXT-10**: System MUST clamp every extracted field against canonical allowlists after JSON decode:

  | Field | Validation | On failure |
  |---|---|---|
  | `mood` | Must be one of `["low", "flat", "okay", "good", "great"]` | Set `nil` |
  | `energy` | Must be one of `["sluggish", "tired", "steady", "alert", "charged"]` | Set `nil` |
  | `focus` | Must be one of `["foggy", "distracted", "present", "sharp", "lockedIn"]` | Set `nil` |
  | `sleepHours` | Must be `0.0 ... 24.0` | Set `nil` |
  | `sleepQuality` | Must be one of `["restless", "light", "okay", "good", "deep"]` | Set `nil` |
  | `emotions` | Each must be in the 20 curated emotions | Drop unrecognised |
  | `medications[].name` | Validated against ~90 lexicon names (case-insensitive) | **Keep** (user may mention non-ADHD meds) |
  | `medications[].taken` | Must be `Bool` | Default `true` |
  | `topics` | Max 4 entries | Truncate |
  | `lexicon` | Max 5 entries | Truncate |
  | `activities` | Each must be in the 11 category names | Drop unrecognised |
  | `sideEffects` | Each must be in `sideEffectCues` ∪ `physicalSideEffects` | Drop unrecognised |
  | `summary` | If empty string → set `nil` | — |

- **FR-EXT-11**: System MUST derive `SleepLevel` from `sleepHours` when `sleepQuality` is nil, using the legacy mapping:

  | Sleep hours | Derived `SleepLevel` |
  |---|---|
  | < 5 | `.restless` |
  | 5 ..< 6 | `.light` |
  | 6 ..< 7 | `.okay` |
  | 7 ..< 9 | `.good` |
  | ≥ 9 | `.deep` |

- **FR-EXT-12**: System MUST enforce topic derivation rules:
  - `"Medications"` injected if any medication events were extracted.
  - `"Symptoms"` injected if `sideEffects` or `reboundTerms` are non-empty.
  - `"Appointments"` injected if appointment-related language was detected.
  - No duplicate topics.

- **FR-EXT-13**: `Recording.applySummary()` MUST persist `SummaryResult` onto `Recording` columns:
  - **Normal mode** (`fillOnly: false`): writes all scalar columns (mood, energyLevel, focusLevel, sleepHours, sleepQuality, sleepLevelValue, medicationInfo). Generates title from signal parts (`"Good · Alert · Sharp"`). Writes JSON columns for bullets, emotions, side effects, sleep event, topics. Strips mood/energy/focus/emotions/sideEffects/sleepHours from `noteExtractionJSON` (single source of truth). Sets `summaryStatus = .completed`.
  - **fillOnly mode** (`fillOnly: true`): only writes nil columns — user-entered values from the text check-in composer are never overwritten.

- **FR-EXT-14**: `Recording.setMedicationEvents()` MUST replace transcript-sourced `MedicationEvent` rows:
  1. Collect names of `source == .manual` events (manual dose beats extractor).
  2. Delete all `source == .transcript` events.
  3. Create new `MedicationEvent` for each extracted med not in the manual set.
  4. Duration: per-med `durationHours` ?? call-site default ?? **10.0 h**.
  5. `takenAt` resolved from `med.time` / `med.timeLabel` / `recording.createdAt`.
  6. Set `hasMedication` from inputs (not from the relationship, which has stale deletes pre-save).

- **FR-EXT-15**: On successful extraction completion (`summaryStatus = .completed`), `ProcessingViewModel` MUST trigger `UINotificationFeedbackGenerator.success` (haptic feedback).

- **FR-EXT-16**: If JSON parsing entirely fails, `summarize()` MUST return a `SummaryResult` with only the raw transcript as a single bullet, all signals nil. **The app MUST never crash.**

- **FR-EXT-17**: If `os_proc_available_memory()` reports < 200 MB before or during inference, generation MUST abort. Raw transcript is preserved. Equivalent to parse failure from the UI's perspective.

### Key Entities

- **`UnifiedExtraction`**: New `Codable` struct capturing the full extraction output schema:
  ```swift
  struct UnifiedExtraction: Codable {
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
  ```

- **`MedicationExtraction`**: New `Codable` struct for medication entries:
  ```swift
  struct MedicationExtraction: Codable {
      var name: String
      var dose: String?
      var taken: Bool
  }
  ```

- **`parseExtraction()`**: New function implementing the multi-stage JSON recovery pipeline. Input: raw String from LLM. Output: `UnifiedExtraction?` (nil on total failure).

- **`SummaryResult`**: Existing return type from `SummarizationService`. **Unchanged** — the new validation layer assembles this from a validated `UnifiedExtraction`.

- **`Recording.applySummary()`**: Existing persistence method. Maps `SummaryResult` onto `Recording` model columns. **Unchanged** — source: [`Recording.swift:202-355`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Models/Recording.swift#L202-L355).

- **`Recording.setMedicationEvents()`**: Existing medication persistence method. Replaces transcript-sourced events while preserving manual entries. **Unchanged** — source: [`Recording.swift:202-355`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Models/Recording.swift#L202-L355).

- **`ProcessingViewModel`**: Existing ViewModel. Calls `summarize()` → `applySummary()` → `setMedicationEvents()` → haptic. **Unchanged**.

### Integration Contract

| Boundary | Direction | Data | Source |
|---|---|---|---|
| Part 1 → **Part 2** | Input | Raw JSON string from Llama inference | [spec.md (Part 1)](file:///Users/caesargrey/Projects/app-four-llama/specs/043-mlx-journal-service/spec.md) |
| **Part 2** → Part 3 | Output | Persisted `Recording` with populated signal columns | Part 3 — Extraction Review UI |
| **Part 2** → `ProcessingViewModel` | Output | `SummaryResult` returned from `summarize()` | Unchanged caller |

### Signal Schema (source of truth: `Levels.swift`)

| Signal | Enum | Valid labels (1 → 5) |
|---|---|---|
| Mood | `MoodLevel` | `low`, `flat`, `okay`, `good`, `great` |
| Energy | `EnergyLevel` | `sluggish`, `tired`, `steady`, `alert`, `charged` |
| Focus | `FocusLevel` | `foggy`, `distracted`, `present`, `sharp`, `lockedIn` |
| Sleep | `SleepLevel` | `restless`, `light`, `okay`, `good`, `deep` |

### Validation Allowlists (source of truth: `lexicon.json`)

| Category | Count | Source |
|---|---|---|
| Emotions | 20 (5 per quadrant: `excited`, `joyful`, `proud`, `thrilled`, `inspired`, `angry`, `anxious`, `frustrated`, `irritated`, `jealous`, `content`, `grateful`, `peaceful`, `secure`, `serene`, `sad`, `lonely`, `disappointed`, `hopeless`, `discouraged`) | `lexicon.json:emotions` |
| Activity categories | 11 (`Resting`, `Hobbies`, `Hanging Out`, `Fitness`, `Eating`, `Driving`, `Work`, `Chores`, `Errands`, `Outdoors`, `Screen Time`) | `lexicon.json:activityKeywords` |
| Medications | ~90 names (brand, generic, slang, misspellings) | `lexicon.json:medications` |
| Side effects | `sideEffectCues` (29) ∪ `physicalSideEffects` (29) | `lexicon.json` |

### Validation Rules & Constants

| Rule / Constant | Value | Source |
|---|---|---|
| Valid Moods | `["low", "flat", "okay", "good", "great"]` | `Levels.swift:8-13` |
| Valid Energy | `["sluggish", "tired", "steady", "alert", "charged"]` | `Levels.swift:29-34` |
| Valid Focus | `["foggy", "distracted", "present", "sharp", "lockedIn"]` | `Levels.swift:50-55` |
| Valid Sleep | `["restless", "light", "okay", "good", "deep"]` | `Levels.swift:80-85` |
| SleepLevel from hours | <5→restless, 5–6→light, 6–7→okay, 7–9→good, ≥9→deep | `NLSummarizationService.swift:61-72` |
| Emotions | exactly 20 curated (5 per quadrant) | `lexicon.json:emotions` |
| Activities | exactly 11 categories | `lexicon.json:activityKeywords` |
| Medications | ~90 names | `lexicon.json:medications` |
| Max Topics | 4 | Validation rule |
| Max Lexicon phrases | 5 | Validation rule |
| Med duration fallback | 10.0 h | `Recording.swift:342` |
| Memory abort threshold | < 200 MB available | `os_proc_available_memory()` |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Signal values persisted in `Recording` use **exactly** the `Levels.swift` enum rawValues — verified by unit tests asserting every valid label passes clamping and every invalid label is nulled.
- **SC-002**: Layer 4 validation rejects 100% of mood/energy/focus/sleep values not in the canonical enum sets — verified by parameterised tests covering all valid labels plus representative invalid values (`"Bad"`, `"fantastic"`, `"lockedin"`, `"Awful"`).
- **SC-003**: Emotions are validated against the exact 20 from `lexicon.json` — verified by unit test with all 20 valid + at least 5 invalid.
- **SC-004**: If JSON parsing fails entirely (all 3 recovery stages), the user sees raw transcript with no crash — verified by unit test passing garbage input and asserting non-nil `SummaryResult` with nil signals.
- **SC-005**: `SummaryResult` returned from `summarize()` is identical in type to the legacy implementation — verified by type assertion at compile time (no `SummaryResult` schema changes).
- **SC-006**: `applySummary()` and `setMedicationEvents()` continue to function identically — verified by existing unit tests passing without modification.
- **SC-007**: Multi-stage JSON recovery successfully parses: (a) clean JSON, (b) backtick-wrapped JSON, (c) JSON with surrounding prose — verified by 3 distinct test cases.
- **SC-008**: SleepLevel derivation from hours matches the legacy mapping exactly for all 5 ranges — verified by parameterised test with boundary values.

## Assumptions

- The raw JSON string arrives from Part 1 (`MLXJournalService`) via the `summarize()` return path — not via any async callback or notification.
- `Recording.applySummary()` and `Recording.setMedicationEvents()` are unchanged from the legacy pipeline and will not be modified as part of this feature. They are tested via their existing test coverage.
- The `SummarizationService` protocol and `SummaryResult` type are stable and will not change shape during this migration.
- `LexiconLoader.loadBundled()` continues to work as-is — no changes to the loader are required.
- The 20 curated emotions, 11 activity categories, and ~90 medication names in `lexicon.json` are stable and will not change during this feature.
- `ProcessingViewModel` and `PendingTranscriptionServiceImpl` consume `SummaryResult` identically to the legacy path — zero code changes required.
- Haptic feedback is wired through the existing `summaryStatus` observation in `ProcessingViewModel` — no new wiring is required.

## Source References

- [`04b-2-validation-persistence.md`](file:///Users/caesargrey/Projects/app-four-llama/docs/llama_migration/04b-2-validation-persistence.md) — Source FSD (Part 2 of 3)
- [`Levels.swift`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift) — Authoritative signal enums
- [`lexicon.json`](file:///Users/caesargrey/Projects/app-four-llama/docs/llama_migration/lexicon.json) — Curated ADHD vocabulary (718 entries, 27 categories)
- [`NLSummarizationService.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/NLSummarizationService.swift) — Legacy SleepLevel derivation logic (preserved)
- [`Recording.swift:202-355`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Models/Recording.swift#L202-L355) — `applySummary`, `setMedicationEvents`
- [`ProcessingViewModel.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/ProcessingViewModel.swift) — Downstream caller (unchanged)
- [spec.md (Part 1)](file:///Users/caesargrey/Projects/app-four-llama/specs/043-mlx-journal-service/spec.md) — MLXJournalService Core specification
- Llama FSD: [`llama_extraction_fsd.md`](file:///Users/caesargrey/Projects/app-four-llama/docs/llama_migration/llama_extraction_fsd.md)
- Legacy NLP Reference: [`nlp_extractor_reference.md`](file:///Users/caesargrey/Projects/app-four-llama/docs/llama_migration/nlp_extractor_reference.md)
