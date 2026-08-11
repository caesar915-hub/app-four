# Feature Specification: Extraction Review UI — `ExtractionReviewView`

**Feature Branch**: `043-mlx-journal-service`

**Created**: 2026-08-12

**Status**: Draft

**Input**: User description: "The user-facing edit sheet for reviewing and correcting LLM-extracted ADHD journal signals. Covers the review sheet layout, editable signal cards (mood, energy, focus, sleep, medications, emotions, side effects), confirm/cancel semantics, provenance tagging (`.llm` vs `.userCorrected`), and `noteExtraction` JSON rebuild on save."

**Source**: [`04b-3-extraction-review-ui.md`](file:///Users/caesargrey/Projects/app-four-llama/docs/llama_migration/04b-3-extraction-review-ui.md) (Part 3 of 3 — Extraction Review UI)

> **This is Part 3 of 3.** It displays and edits the persisted signals produced by [Part 2 — Validation & Persistence](file:///Users/caesargrey/Projects/app-four-llama/specs/043-mlx-journal-service/spec-part2.md), which in turn consumes the raw JSON from [Part 1 — MLXJournalService Core](file:///Users/caesargrey/Projects/app-four-llama/specs/043-mlx-journal-service/spec.md).

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Review and confirm LLM-extracted signals (Priority: P1)

After an LLM extraction completes and signals are persisted (Part 2), the user taps the pencil button on `RecordingDetailView` to open the Extraction Review sheet. The sheet displays six editable signal cards (When, Signals, Sleep, Medications, Emotions, Side Effects) pre-filled with the LLM-extracted values. The user reviews, optionally edits any card, and taps Save to persist corrections.

**Why this priority**: This is the core purpose of the review UI — without it, users cannot verify or correct LLM-extracted signals, making the extraction pipeline effectively unauditable.

**Independent Test**: Open a `RecordingDetailView` for a recording with completed extraction, tap the pencil button, verify the sheet opens with pre-filled signal values, edit one signal, tap Save, and verify the edited value persists.

**Acceptance Scenarios**:

1. **Given** a `Recording` with `summaryStatus = .completed` and mood = `okay`, **When** the user taps the pencil toolbar button on `RecordingDetailView`, **Then** the review sheet slides up with `.presentationDetents([.large])` and a visible drag indicator, showing mood pre-filled as `okay`.
2. **Given** the review sheet is open with mood = `okay`, **When** the user adjusts mood to `good` via `GlyphRampPicker` and taps Save, **Then** `noteExtraction` JSON is rebuilt, `applySummary()` and `setMedicationEvents()` are called, and `Recording.mood` = `"good"`.
3. **Given** the review sheet is open, **When** the user taps Save without modifying anything, **Then** `applySummary()` and `setMedicationEvents()` still run (idempotent), and no data is lost.

---

### User Story 2 — Provenance tagging for LLM vs user-corrected signals (Priority: P1)

On confirm, the system writes one `RecordingTag` per signal category (mood, energy, focus, medication, emotions). Tags distinguish between LLM-extracted values (`.llm`) and user-corrected values (`.userCorrected`), enabling downstream analytics and trust indicators.

**Why this priority**: Provenance is critical for data integrity — without it, there's no way to distinguish machine-generated signals from user-verified ones, undermining trust in trend analysis and insights.

**Independent Test**: Open the review sheet, modify mood only, tap Save, and verify that mood's tag is `.userCorrected` while energy and focus tags are `.llm`.

**Acceptance Scenarios**:

1. **Given** the review sheet is open with LLM-extracted mood = `okay`, energy = `alert`, focus = `sharp`, **When** the user changes mood to `good` and taps Save, **Then** provenance tags are: mood → `.userCorrected`, energy → `.llm`, focus → `.llm`.
2. **Given** the review sheet is open with LLM-extracted emotion `excited`, **When** the user adds emotion `grateful` and taps Save, **Then** emotion `grateful` → `.userCorrected`, emotion `excited` → `.llm`.
3. **Given** the review sheet is open and the user does not touch any category, **When** Save is tapped, **Then** all emitted tags have `source: .llm`.
4. **Given** provenance tags are written, **When** tags are persisted, **Then** they are saved via `store.addCorrectionTags` + `store.save()`.

---

### User Story 3 — Six editable signal cards with structured controls (Priority: P1)

The review sheet presents six structured signal cards: When (date/time pickers), Signals (mood/energy/focus ramp pickers), Sleep (quality chips + duration presets), Medications (taken/missed toggle + dose chips), Emotions (20 curated chips), and Side Effects (15 hard-coded chips). Each card uses appropriate UI controls with defined constraints.

**Why this priority**: The structured card layout is the entire user interaction surface. Without it, the review sheet has no content.

**Independent Test**: Open the review sheet and verify all six cards render with correct controls, constraints, and initial values from the extraction.

**Acceptance Scenarios**:

1. **Given** the review sheet is open, **When** the user views the **When** card, **Then** Date and Time `DatePicker`s are shown, bounded by `in: ...Date()` — future dates/times cannot be set.
2. **Given** the review sheet is open, **When** the user views the **Signals** card, **Then** three `GlyphRampPicker` rows (Mood, Energy, Focus) are shown, each with 5 levels and a current-value line.
3. **Given** the review sheet is open, **When** the user views the **Sleep** card, **Then** 5 `SleepLevel` chips (toggle) and duration presets (2, 4, 6, 8, 10 h) plus a custom field are shown. Entering `"7,5"` in the custom field normalises to `7.5`.
4. **Given** the review sheet is open with a detected medication "Vyvanse", **When** the user views the **Medications** card, **Then** a section for "Vyvanse" appears with Taken/Missed toggle, catalog dose chips, read-only time, and editable duration.
5. **Given** the review sheet is open, **When** the user views the **Emotions** card, **Then** exactly 20 chips appear in "Pleasant" and "Unpleasant" groups (5 per quadrant × 4 quadrants).
6. **Given** the review sheet is open, **When** the user views the **Side effects** card, **Then** exactly 15 chips appear: dry mouth, headache, nausea, appetite gone, insomnia, jittery, heart racing, stomach ache, dizzy, irritable, rebound, crash, sweating, grinding teeth, flat affect.

---

### User Story 4 — Cancel semantics and incomplete extraction handling (Priority: P2)

When the user cancels the review sheet, the system checks `summaryStatus`. If extraction was incomplete (`summaryStatus != .completed`), the status is set to `.failed` and saved. This prevents the UI from showing a perpetual "Processing…" state for failed extractions.

**Why this priority**: Important for state consistency but is a fallback path — most users will confirm rather than cancel.

**Independent Test**: Open the review sheet for a recording with incomplete extraction, tap Cancel, and verify `summaryStatus` is set to `.failed`.

**Acceptance Scenarios**:

1. **Given** the review sheet is open and `summaryStatus == .completed`, **When** the user taps Cancel, **Then** the sheet dismisses and no state change occurs.
2. **Given** the review sheet is open and `summaryStatus != .completed` (e.g., `.processing`), **When** the user taps Cancel, **Then** `summaryStatus` is set to `.failed`, saved, and the sheet dismisses.

---

### User Story 5 — User correction after total parse failure (Priority: P2)

When LLM extraction fails entirely (Part 2 FR-EXT-16), the review sheet opens with all signals nil. The user can manually enter all values from scratch. All emitted provenance tags are `.userCorrected`.

**Why this priority**: Ensures the user always has a manual fallback even when the LLM pipeline completely fails — important for robustness but secondary to the happy path.

**Independent Test**: Create a recording where extraction failed (all signals nil), open the review sheet, manually enter mood/energy/focus values, tap Save, and verify all tags are `.userCorrected`.

**Acceptance Scenarios**:

1. **Given** a `Recording` where extraction failed (all signal columns nil), **When** the user opens the review sheet, **Then** all signal pickers show empty/default state with no pre-filled values.
2. **Given** the review sheet is open with all nil signals, **When** the user sets mood = `good`, energy = `alert`, and taps Save, **Then** all emitted tags have `source: .userCorrected`.

---

### User Story 6 — noteExtraction JSON rebuild on save (Priority: P1)

On Save, the `noteExtraction` JSON is rebuilt from the edited scalar values. This ensures the JSON column never disagrees with the scalar columns on `Recording` — maintaining a single source of truth for downstream consumers.

**Why this priority**: Data consistency between JSON and scalar columns is critical — if they disagree, different parts of the app would show conflicting signals.

**Independent Test**: Open the review sheet, edit mood from `okay` to `great`, tap Save, and verify that `noteExtraction` JSON contains `"mood": "great"` matching `Recording.mood`.

**Acceptance Scenarios**:

1. **Given** the review sheet is open with mood = `okay`, **When** the user changes mood to `great` and taps Save, **Then** the rebuilt `noteExtraction` JSON contains `"mood": "great"` and `Recording.mood` = `"great"`.
2. **Given** the user sets a non-empty trimmed title in the review sheet, **When** Save is tapped, **Then** the user-set title wins over the generated title.
3. **Given** the user clears the title field (empty trimmed string), **When** Save is tapped, **Then** the generated title is used instead.
4. **Given** the user edits `recording.createdAt` via the When card, **When** Save is tapped, **Then** `createdAt` is set **before** materialising med events so `takenAt` resolves against the corrected day.

---

### Edge Cases & Error Handling

#### 1. Network & Connectivity Failures
- **Scenario:** Not applicable — the review sheet reads and writes persisted local data only. Zero network calls.
- **System Behavior:** No network dependency exists.
- **User Experience (UX):** No change; works in airplane mode.

#### 2. Data Validation & Bad Input
- **Scenario:** User enters `"7,5"` in the custom sleep duration field (comma decimal separator).
- **System Behavior:** Comma→dot normalisation converts the input to `7.5`.
- **User Experience (UX):** The normalised value is displayed and persisted correctly.

#### 3. State Restoration & Interruptions
- **Scenario:** App is backgrounded or terminated while the review sheet is open.
- **System Behavior:** Unsaved edits are lost. The `Recording` retains its pre-edit state. The user can re-open the review sheet on next launch.
- **User Experience (UX):** User sees the recording with original LLM-extracted values; edits must be re-applied.

#### 4. User Clears All Signals
- **Scenario:** User removes all signal values (mood, energy, focus all deselected).
- **System Behavior:** All nil values are persisted. Title reverts to the generated title (empty signal title).
- **User Experience (UX):** The recording appears with no signal values; it can be re-edited at any time.

#### 5. Future Date Prevention
- **Scenario:** User attempts to set the date/time to a future value.
- **System Behavior:** `DatePicker` is bounded by `in: ...Date()` — future dates/times cannot be set.
- **User Experience (UX):** The picker visually prevents selection of future dates.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-REV-01**: The review sheet MUST be reachable only from `RecordingDetailView`'s trailing pencil toolbar button (accessibility label **"Edit check-in"**). Presented as `.sheet(item:)` with `.presentationDetents([.large])` and a visible drag indicator. There MUST be no automatic review prompt.

- **FR-REV-02**: The review sheet MUST display six editable cards:

  | Card | Controls | Constraints |
  |---|---|---|
  | **When** | Date + Time `DatePicker`s | Bounded `in: ...Date()` — future dates/times cannot be set |
  | **Signals** | Three `GlyphRampPicker` rows: Mood, Energy, Focus | Each shows 5 levels with current-value line |
  | **Sleep** | 5 `SleepLevel` chips (toggle) + duration presets 2/4/6/8/10 h + custom field | Custom field: comma→dot normalisation |
  | **Medications** | Taken/Missed toggle, catalog dose chips, read-only time, editable duration | One section per detected medication |
  | **Emotions** | 20 chips in "Pleasant" / "Unpleasant" groups | Exactly the 20 curated emotions |
  | **Side effects** | 15 hard-coded chips | dry mouth, headache, nausea, appetite gone, insomnia, jittery, heart racing, stomach ache, dizzy, irritable, rebound, crash, sweating, grinding teeth, flat affect |

- **FR-REV-03**: On Save, the system MUST:
  1. Rebuild `noteExtraction` from the edited scalars (JSON can't disagree with columns).
  2. Set `recording.createdAt = date` **before** materialising med events so `takenAt` resolves against the corrected day.
  3. Call `applySummary` + `setMedicationEvents` (see [Part 2](file:///Users/caesargrey/Projects/app-four-llama/specs/043-mlx-journal-service/spec-part2.md) FR-EXT-13, FR-EXT-14).
  4. A user-set non-empty trimmed title MUST always win over the generated title.

- **FR-REV-04**: On confirm, the system MUST write one `RecordingTag` per mood, energy, focus, each medication, and each emotion:
  - `source: .userCorrected` if that category was touched.
  - `source: .llm` if that category was extracted by the LLM and not modified.
  - `TagCategory` covers mood/energy/focus/medication/emotions — sleep and side-effect edits produce no tags.
  - Tags MUST be persisted via `store.addCorrectionTags` + `store.save()`.

- **FR-REV-05**: On Cancel, if `summaryStatus != .completed`, the system MUST set `summaryStatus = .failed` and save.

### Key Entities

- **`ExtractionReviewView`**: SwiftUI sheet presenting the six editable signal cards. Reads persisted `Recording` columns and `noteExtraction` JSON. Source: [`ExtractionReviewView.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Views/ExtractionReviewView.swift).

- **`ExtractionReviewViewModel`**: ViewModel managing edit state, dirty tracking per category, and save/cancel logic. Source: [`ExtractionReviewViewModel.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/ExtractionReviewViewModel.swift).

- **`RecordingDetailView`**: Entry point — the pencil toolbar button presents the review sheet. Source: [`RecordingDetailView.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Views/RecordingDetailView.swift).

- **`RecordingTag`**: Provenance label entity. `source` is `.llm` (extracted, unmodified) or `.userCorrected` (user edited). `TagCategory` covers mood, energy, focus, medication, emotions. Source: [`RecordingTag.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Models/RecordingTag.swift).

- **`GlyphRampPicker`**: Existing 5-level signal picker UI component used for Mood, Energy, and Focus.

- **`SleepLevel`**: Enum for sleep quality chips: `restless`, `light`, `okay`, `good`, `deep`. Source: [`Levels.swift:80-99`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift#L80-L99).

### Integration Contract

| Boundary | Direction | Data | Source |
|---|---|---|---|
| Part 2 → **Part 3** | Input | Persisted `Recording` with populated signal columns | [spec-part2.md (Part 2)](file:///Users/caesargrey/Projects/app-four-llama/specs/043-mlx-journal-service/spec-part2.md) |
| **Part 3** → Part 2 | Output | Calls `applySummary()` + `setMedicationEvents()` on save | [spec-part2.md (Part 2)](file:///Users/caesargrey/Projects/app-four-llama/specs/043-mlx-journal-service/spec-part2.md) |
| **Part 3** → `RecordingTag` | Output | Provenance tags (`.llm` / `.userCorrected`) | Persisted via `store.addCorrectionTags` |

> **Key principle:** The review sheet reads persisted `Recording` columns and the `noteExtraction` JSON. It does not interact with the LLM, the lexicon, or the inference pipeline. It calls the same `applySummary()` and `setMedicationEvents()` methods documented in [Part 2](file:///Users/caesargrey/Projects/app-four-llama/specs/043-mlx-journal-service/spec-part2.md) to re-persist edited values.

### Signal Schema (source of truth: `Levels.swift`)

| Signal | Enum | Valid labels (1 → 5) | Source |
|---|---|---|---|
| Mood | `MoodLevel` | `low`, `flat`, `okay`, `good`, `great` | [`Levels.swift:8-27`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift#L8-L27) |
| Energy | `EnergyLevel` | `sluggish`, `tired`, `steady`, `alert`, `charged` | [`Levels.swift:29-48`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift#L29-L48) |
| Focus | `FocusLevel` | `foggy`, `distracted`, `present`, `sharp`, `lockedIn` | [`Levels.swift:50-78`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift#L50-L78) |
| Sleep quality | `SleepLevel` | `restless`, `light`, `okay`, `good`, `deep` | [`Levels.swift:80-99`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift#L80-L99) |

### 20 Curated Emotions (source of truth: `lexicon.json`)

| Quadrant | Entries |
|---|---|
| High energy + Pleasant | excited, joyful, proud, thrilled, inspired |
| High energy + Unpleasant | angry, anxious, frustrated, irritated, jealous |
| Low energy + Pleasant | content, grateful, peaceful, secure, serene |
| Low energy + Unpleasant | sad, lonely, disappointed, hopeless, discouraged |

### Validation Rules & Constants

| Rule / constant | Value | Source |
|---|---|---|
| Side-effect chips | 15 (dry mouth, headache, nausea, appetite gone, insomnia, jittery, heart racing, stomach ache, dizzy, irritable, rebound, crash, sweating, grinding teeth, flat affect) | `ExtractionReviewView.swift` |
| Emotions | exactly 20 curated (5 per quadrant) | `lexicon.json:emotions` |
| Signal pickers | 5 levels each (Mood, Energy, Focus) | `Levels.swift` |
| Sleep chips | 5 levels (restless, light, okay, good, deep) | `Levels.swift:80-85` |
| Sleep duration presets | 2, 4, 6, 8, 10 hours | `ExtractionReviewView.swift` |
| Tag categories | mood, energy, focus, medication, emotions | `RecordingTag` |
| Tag sources | `.llm`, `.userCorrected` | `RecordingTag` |
| Date picker bound | `in: ...Date()` (no future dates) | `ExtractionReviewView.swift` |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The Edit sheet displays the same 5-step signal pickers, 20 emotions, 15 side-effect chips as defined in the FSD — verified by UI inspection and count assertions.
- **SC-002**: Provenance tags correctly emit `.llm` for untouched categories and `.userCorrected` for touched categories — verified by unit tests on `ExtractionReviewViewModel` dirty tracking.
- **SC-003**: `applySummary()` and `setMedicationEvents()` are called on Save (identical to [Part 2](file:///Users/caesargrey/Projects/app-four-llama/specs/043-mlx-journal-service/spec-part2.md) persistence contract) — verified by observing `Recording` column updates after Save.
- **SC-004**: Cancel with incomplete extraction sets `summaryStatus = .failed` — verified by unit test asserting status change on cancel.
- **SC-005**: The sheet is reachable only from the pencil button on `RecordingDetailView` — there is no automatic review prompt — verified by UI audit confirming no other entry points.
- **SC-006**: `noteExtraction` JSON is rebuilt from edited scalars on save — JSON never disagrees with scalar columns — verified by comparing JSON and column values post-save.
- **SC-007**: Comma→dot normalisation works for custom sleep duration input — verified by entering `"7,5"` and asserting persistence of `7.5`.
- **SC-008**: User-set non-empty trimmed title always wins over the generated title — verified by unit test.

## Assumptions

- The review sheet reads persisted `Recording` columns and does NOT interact with the LLM, the lexicon, or the inference pipeline directly.
- `applySummary()` and `setMedicationEvents()` are unchanged from the legacy pipeline (documented in [Part 2](file:///Users/caesargrey/Projects/app-four-llama/specs/043-mlx-journal-service/spec-part2.md)) and are not modified as part of this feature.
- The `SummarizationService` protocol and `SummaryResult` type are stable and will not change shape during this migration.
- The 20 curated emotions and 15 side-effect chips are stable and will not change during this feature.
- `GlyphRampPicker` and `SleepLevel` chip components already exist and function correctly — no new UI components need to be created.
- `RecordingTag` entity and `store.addCorrectionTags` already exist — no new persistence infrastructure is needed.
- `ExtractionReviewView`, `ExtractionReviewViewModel`, and `RecordingDetailView` already exist — this spec documents their current behaviour under the Llama migration (provenance label change from `.nlp` to `.llm`).

## Source References

- [`04b-3-extraction-review-ui.md`](file:///Users/caesargrey/Projects/app-four-llama/docs/llama_migration/04b-3-extraction-review-ui.md) — Source FSD (Part 3 of 3)
- [`ExtractionReviewView.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Views/ExtractionReviewView.swift) — Review sheet UI
- [`ExtractionReviewViewModel.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/ExtractionReviewViewModel.swift) — Review sheet ViewModel
- [`RecordingDetailView.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Views/RecordingDetailView.swift) — Entry point (pencil button)
- [`RecordingTag.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Models/RecordingTag.swift) — Provenance tag entity
- [`Levels.swift`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift) — Authoritative signal enums
- [`lexicon.json`](file:///Users/caesargrey/Projects/app-four-llama/docs/llama_migration/lexicon.json) — Emotions allowlist
- [`Recording.swift:202-355`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Models/Recording.swift#L202-L355) — `applySummary`, `setMedicationEvents` (see [Part 2](file:///Users/caesargrey/Projects/app-four-llama/specs/043-mlx-journal-service/spec-part2.md))
- [spec.md (Part 1)](file:///Users/caesargrey/Projects/app-four-llama/specs/043-mlx-journal-service/spec.md) — MLXJournalService Core specification
- [spec-part2.md (Part 2)](file:///Users/caesargrey/Projects/app-four-llama/specs/043-mlx-journal-service/spec-part2.md) — Validation & Persistence specification
