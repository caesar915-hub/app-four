<!-- Created: 2026-08-11 22:44 (WEST) · Updated: 2026-08-11 22:44 (WEST) -->
# 04b-3 — Extraction Review UI (`ExtractionReviewView`)

The user-facing edit sheet for reviewing and correcting LLM-extracted ADHD journal signals. Covers the review sheet layout, editable signal cards, confirm/cancel semantics, and provenance tagging.

> **This is Part 3 of 3.** It displays and edits the persisted signals produced by [Part 2 — Validation & Persistence](04b-2-validation-persistence.md), which in turn consumes the raw JSON from [Part 1 — MLXJournalService Core](04b-1-mlx-journal-service.md).

## Purpose

Describe the `ExtractionReviewView` and `ExtractionReviewViewModel`: how the user reviews extracted signals, edits them via structured UI controls (pickers, chips, toggles), saves corrections, and how provenance tags distinguish LLM-extracted values from user-corrected values.

## Scope

- **In scope**: `ExtractionReviewView`, `ExtractionReviewViewModel`, `RecordingDetailView` (entry point only), `RecordingTag` provenance, signal picker UI, emotion/side-effect chips, medication cards, confirm/cancel semantics.
- **Out of scope**: LLM inference and prompt construction ([Part 1](04b-1-mlx-journal-service.md)), JSON parsing and validation ([Part 2](04b-2-validation-persistence.md)), Whisper transcription ([04a](04a-whisperkit-transcription.md)), audio capture ([03](../fsd/03-check-in-capture.md)), library rendering ([05](../fsd/05-library-and-history.md)), insights ([06](../fsd/06-insights.md)), medication bar / Dose Guard ([07](../fsd/07-medications.md)).

---

## Integration contract

| Boundary | Direction | Data | Source |
|---|---|---|---|
| Part 2 → **Part 3** | Input | Persisted `Recording` with populated signal columns | [04b-2](04b-2-validation-persistence.md) |
| **Part 3** → Part 2 | Output | Calls `applySummary()` + `setMedicationEvents()` on save | [04b-2](04b-2-validation-persistence.md) |
| **Part 3** → `RecordingTag` | Output | Provenance tags (`.llm` / `.userCorrected`) | Persisted via `store.addCorrectionTags` |

> **Key principle:** The review sheet reads persisted `Recording` columns and the `noteExtraction` JSON. It does not interact with the LLM, the lexicon, or the inference pipeline. It calls the same `applySummary()` and `setMedicationEvents()` methods documented in [Part 2](04b-2-validation-persistence.md) to re-persist edited values.

---

## Functional requirements

### Extraction review ("Edit check-in")

Source: `ExtractionReviewView.swift`, `ExtractionReviewViewModel.swift`, `RecordingDetailView.swift`

- **FR-REV-01 — Manual-only entry.** The review sheet is reachable only from `RecordingDetailView`'s trailing pencil toolbar button (accessibility label **"Edit check-in"**). Presented as `.sheet(item:)` with `.presentationDetents([.large])` and a visible drag indicator. There is no automatic review prompt.

- **FR-REV-02 — Editable cards.** Six cards:

  | Card | Controls | Constraints |
  |---|---|---|
  | **When** | Date + Time `DatePicker`s | Bounded `in: ...Date()` — future dates/times cannot be set |
  | **Signals** | Three `GlyphRampPicker` rows: Mood, Energy, Focus | Each shows 5 levels with current-value line |
  | **Sleep** | 5 `SleepLevel` chips (toggle) + duration presets 2/4/6/8/10 h + custom field | Custom field: comma→dot normalisation |
  | **Medications** | Taken/Missed toggle, catalog dose chips, read-only time, editable duration | One section per detected medication |
  | **Emotions** | 20 chips in "Pleasant" / "Unpleasant" groups | Exactly the 20 curated emotions |
  | **Side effects** | 15 hard-coded chips | dry mouth, headache, nausea, appetite gone, insomnia, jittery, heart racing, stomach ache, dizzy, irritable, rebound, crash, sweating, grinding teeth, flat affect |

  The **Signal schema** for the pickers (source of truth: `Levels.swift`):

  | Signal | Enum | Valid labels (1 → 5) | Source |
  |---|---|---|---|
  | Mood | `MoodLevel` | `low`, `flat`, `okay`, `good`, `great` | [`Levels.swift:8-27`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift#L8-L27) |
  | Energy | `EnergyLevel` | `sluggish`, `tired`, `steady`, `alert`, `charged` | [`Levels.swift:29-48`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift#L29-L48) |
  | Focus | `FocusLevel` | `foggy`, `distracted`, `present`, `sharp`, `lockedIn` | [`Levels.swift:50-78`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift#L50-L78) |
  | Sleep quality | `SleepLevel` | `restless`, `light`, `okay`, `good`, `deep` | [`Levels.swift:80-99`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift#L80-L99) |

  The **20 curated emotions** (from `lexicon.json`, Mood Meter / Brackett):

  | Quadrant | Entries |
  |---|---|
  | High energy + Pleasant | excited, joyful, proud, thrilled, inspired |
  | High energy + Unpleasant | angry, anxious, frustrated, irritated, jealous |
  | Low energy + Pleasant | content, grateful, peaceful, secure, serene |
  | Low energy + Unpleasant | sad, lonely, disappointed, hopeless, discouraged |

- **FR-REV-03 — Confirm semantics.** On Save:
  1. `noteExtraction` is rebuilt from the edited scalars (JSON can't disagree with columns).
  2. `recording.createdAt = date` is set **before** materialising med events so `takenAt` resolves against the corrected day.
  3. `applySummary` + `setMedicationEvents` run (see [Part 2](04b-2-validation-persistence.md) FR-EXT-13, FR-EXT-14).
  4. A user-set non-empty trimmed title always wins over the generated title.
  
  On Cancel: if `summaryStatus != completed`, sets it to `failed` and saves.

- **FR-REV-04 — Provenance tags.** On confirm, one `RecordingTag` is written per mood, energy, focus, each medication, and each emotion:
  - `source: .userCorrected` if that category was touched.
  - `source: .llm` if that category was extracted by the LLM and not modified.
  - `TagCategory` covers mood/energy/focus/medication/emotions — sleep and side-effect edits produce no tags.
  
  Tags are persisted via `store.addCorrectionTags` + `store.save()`.

---

## User flows (Part 3 scope)

### Happy path — review and confirm
1. User taps pencil button on `RecordingDetailView`.
2. Review sheet slides up with pre-filled signal values from LLM extraction.
3. User adjusts mood from `okay` to `good` via `GlyphRampPicker`.
4. User adds emotion chip `grateful`.
5. User taps Save.
6. `noteExtraction` JSON rebuilt. `applySummary()` + `setMedicationEvents()` run.
7. Provenance tags written: mood → `.userCorrected`, energy → `.llm`, focus → `.llm`, emotion `grateful` → `.userCorrected`.
8. Sheet dismisses.

### Fallback flows (Part 3 scope)
- **User correction after parse failure**: If extraction failed ([Part 2](04b-2-validation-persistence.md) FR-EXT-16), the sheet opens with all signals nil. User manually enters values. All tags emitted as `.userCorrected`.
- **Cancel with incomplete extraction**: `summaryStatus` set to `.failed`, saved.

---

## Edge cases (Part 3 scope)

- **User sets date to today, time to now** → bounded by `in: ...Date()`, no future dates allowed.
- **Custom sleep duration with comma** → comma→dot normalisation (e.g. "7,5" → 7.5).
- **User clears all signals** → all nil values persisted. Title reverts to generated (empty signal title).
- **User edits title then clears it** → empty trimmed title loses to generated title on next save.

---

## Validation rules & constants (Part 3 scope)

| Rule / constant | Value | Source |
|---|---|---|
| Side-effect chips | 15 (dry mouth, headache, nausea, appetite gone, insomnia, jittery, heart racing, stomach ache, dizzy, irritable, rebound, crash, sweating, grinding teeth, flat affect) | `ExtractionReviewView.swift` |
| Emotions | exactly 20 curated (5 per quadrant) | `lexicon.json:emotions` |
| Signal pickers | 5 levels each (Mood, Energy, Focus) | `Levels.swift` |
| Sleep chips | 5 levels (restless, light, okay, good, deep) | `Levels.swift:80-85` |
| Sleep duration presets | 2, 4, 6, 8, 10 hours | `ExtractionReviewView.swift` |
| Tag categories | mood, energy, focus, medication, emotions | `RecordingTag` |
| Tag sources | `.llm`, `.userCorrected` | `RecordingTag` |

---

## Acceptance criteria (Part 3 scope)

1. The Edit sheet displays the same 5-step signal pickers, 20 emotions, 15 side-effect chips as before.
2. Provenance tags correctly emit `.llm` for untouched and `.userCorrected` for touched categories.
3. `applySummary()` and `setMedicationEvents()` are called on Save (identical to [Part 2](04b-2-validation-persistence.md) persistence contract).
4. Cancel with incomplete extraction sets `summaryStatus = .failed`.
5. The sheet is reachable only from the pencil button on `RecordingDetailView` — there is no automatic review prompt.
6. `noteExtraction` JSON is rebuilt from edited scalars on save — JSON never disagrees with scalar columns.

---

## Source references

- [`ExtractionReviewView.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Views/ExtractionReviewView.swift)
- [`ExtractionReviewViewModel.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/ExtractionReviewViewModel.swift)
- [`RecordingDetailView.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Views/RecordingDetailView.swift)
- [`RecordingTag.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Models/RecordingTag.swift)
- [`Levels.swift`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift) (authoritative signal enums)
- [`lexicon.json`](file:///Users/caesargrey/Projects/app-four-llama/docs/llama_migration/lexicon.json) (emotions allowlist)
- [`Recording.swift:202-355`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Models/Recording.swift#L202-L355) (`applySummary`, `setMedicationEvents` — see [Part 2](04b-2-validation-persistence.md))
- Part 1: [04b-1 — MLXJournalService Core](04b-1-mlx-journal-service.md)
- Part 2: [04b-2 — Validation & Persistence](04b-2-validation-persistence.md)
