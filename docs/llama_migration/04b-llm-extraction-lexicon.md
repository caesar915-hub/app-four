<!-- Created: 2026-08-11 21:20 (WEST) · Updated: 2026-08-11 21:20 (WEST) -->
# 04b — LLM Extraction & Lexicon (`MLXJournalService`)

Documents the extraction layer that replaces the legacy `NLNoteExtractor` + `CueMatcher`. All signal scales, lexicon vocabulary, and validation rules are sourced from the existing codebase (`Levels.swift`, `lexicon.json`), which is the **single source of truth**.

Companion to [04a — WhisperKit Transcription](04a-whisperkit-transcription.md), which covers everything up to the moment a clean transcript string is produced. This document covers what happens next.

## Purpose

Describe how a clean transcript string is transformed into structured ADHD journal signals: the `MLXJournalService` (Llama 3.2 1B via MLX-Swift), how the existing curated lexicon seeds the LLM prompt and validates its output, the JSON parsing and validation pipeline, persistence via `Recording.applySummary()` / `setMedicationEvents()`, the extraction review sheet, and provenance tagging.

## Scope

- **In scope**: `MLXJournalService` (new — replaces `NLSummarizationService` / `NLNoteExtractor` / `CueMatcher`), `lexicon.json` (retained, repurposed), `LexiconLoader`, `Levels.swift` signal enums, `UnifiedExtraction` schema, `SummaryResult`, `Recording.applySummary` / `setMedicationEvents`, `ExtractionReviewView` / `ExtractionReviewViewModel`, `RecordingTag`.
- **Out of scope**: Whisper transcription ([04a](04a-whisperkit-transcription.md)), audio capture ([03](../fsd/03-check-in-capture.md)), library rendering ([05](../fsd/05-library-and-history.md)), insights ([06](../fsd/06-insights.md)), medication bar / Dose Guard ([07](../fsd/07-medications.md)).

---

## Architecture: what changes, what stays

| Component | Legacy (NL) | Llama Migration | Status |
|---|---|---|---|
| `SummarizationService` protocol | Implemented by `NLSummarizationService` | Implemented by `MLXJournalService` | **Swap** |
| `NLNoteExtractor` + `CueMatcher` | Deterministic regex/tokenizer pipeline | Replaced by LLM inference | **Removed** |
| `lexicon.json` (718 entries, 27 categories) | Loaded by `LexiconLoader`, consumed by `CueMatcher` for substring matching | Loaded by `LexiconLoader`, consumed by `MLXJournalService` for prompt injection + validation | **Retained & repurposed** |
| `Levels.swift` signal enums | Source of truth for signal labels | Source of truth for signal labels | **Unchanged** |
| `SummaryResult` | Returned by `NLSummarizationService` | Returned by `MLXJournalService` | **Unchanged** |
| `Recording.applySummary()` | Consumes `SummaryResult` | Consumes `SummaryResult` | **Unchanged** |
| `Recording.setMedicationEvents()` | Consumes `SummaryResult.medications` | Consumes `SummaryResult.medications` | **Unchanged** |
| `ProcessingViewModel` | Calls `summarizationService.summarize()` | Calls `summarizationService.summarize()` | **Unchanged** |
| `PendingTranscriptionServiceImpl` | Calls `summarizationService.summarize()` | Calls `summarizationService.summarize()` | **Unchanged** |
| `ExtractionReviewView` / `ViewModel` | Displays/edits extracted signals | Displays/edits extracted signals | **Unchanged** |
| `RecordingTag` | Records provenance `.nlp` / `.userCorrected` | Records provenance `.llm` / `.userCorrected` | **Label change** |

> **Key principle:** The `SummarizationService` protocol is the only integration boundary. Downstream consumers (`ProcessingViewModel`, `PendingTranscriptionServiceImpl`, `Recording`, the review sheet) are unaware of the extraction backend. The migration swaps one `SummarizationService` implementation for another.

---

## The lexicon: retained and repurposed

> **The curated `lexicon.json` (718 entries across 27 categories) is the source of truth for the app's ADHD-specific vocabulary.** The file and its loader (`LexiconLoader.loadBundled()`) are **not deleted**. What changes is the consumer:
>
> | Before (NL) | After (Llama) |
> |---|---|
> | `CueMatcher` loads the lexicon and performs exact-substring matching with Damerau–Levenshtein fuzzy tolerance | `MLXJournalService` loads the lexicon and uses it for two purposes: **(1)** injecting domain vocabulary into the system prompt so the 1B model recognises ADHD slang, and **(2)** providing the canonical allowlists for Swift-side validation |
>
> Categories that relied on token-level mechanics (`negationTokens`, `medNotTakenVerbs`, `timeOfDayKeywords`) are **not injected into the prompt** — the LLM handles negation, tense, and time resolution semantically.

### Full lexicon inventory

Source: [`lexicon.json`](file:///Users/caesargrey/Projects/app-four-llama/docs/llama_migration/lexicon.json) (1 092 lines, 718 entries)

#### Medications (1 category, ~90 entries)

| Category | Count | Representative entries | LLM role |
|---|---|---|---|
| `medications` | ~90 | Concerta, Concerta XL, Ritalin, Ritalin LA, Ritalin SR, Ritalin IR, Vyvanse, Elvanse, Adderall, Adderall XR, Mydayis, Strattera, Atomoxetine, Focalin, Focalin XR, Wellbutrin, Bupropion, Modafinil, Intuniv, Guanfacine, Clonidine, Qelbree... | Prompt context for medication extraction; **also includes** community slang (`vyv`, `addy`, `addies`, `dex`, `rits`, `meth patch`) and common misspellings (`vyvance`, `vivance`, `adderal`, `stratera`, `straterra`, `buproprion`, `wellbutin`, `concerta er`) |

#### Mood (1 category, ~60 word→label mappings)

Source: `moodSpecific` in `lexicon.json`, maps to `MoodLevel` enum in [`Levels.swift:8-27`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift#L8-L27).

| Label | `MoodLevel` case | Numeric | Example lexicon words |
|---|---|---|---|
| `low` | `.low` | 1 | bleak, numb, terrible, awful, destroyed, hopeless, can't go on, muted, depressed, really sad, feeling down, rock bottom, anxious, worried, angry, furious, grumpy, snappy, irritable, irritated, frustrated, stressed, overwhelmed, miserable, sad, zoned out, subdued, ruminating, looping, grouchy, touchy, short fuse, feel heavy, feeling heavy |
| `flat` | `.flat` | 2 | flat, meh, hollow, emotionless, zombie, neutral, detached, zombified, lifeless, not myself, disconnected, robotic, dulled, feel empty, feeling empty, felt empty, feel nothing, feeling nothing, felt nothing |
| `okay` | `.okay` | 3 | okay, fine, alright, not bad, so-so, steady mood, getting by |
| `good` | `.good` | 4 | warm, lifted, better, pretty good, feeling good, feel good, positive, calm, relaxed, content, chill, at ease, peaceful, optimistic |
| `great` | `.great` | 5 | great, amazing, thriving, bright, fantastic, wonderful, on top of the world, brilliant, happy, cheerful, joyful, glad, ecstatic, nailed it, crushed it, accomplished |

#### Energy (5 categories, ~91 entries total)

Maps to `EnergyLevel` enum in [`Levels.swift:29-48`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift#L29-L48).

| Level | `EnergyLevel` case | Numeric | Category | Count | Examples |
|---|---|---|---|---|---|
| Charged | `.charged` | 5 | `energyCharged` | 22 | charged, electric, wired, buzzing, pumped, on fire, vibing, bouncing off the walls, amped up, could run a marathon, peaking |
| Alert | `.alert` | 4 | `energyAlert` | 7 | alert, awake, ready, clear headed, refreshed, perked up, switched on |
| Steady | `.steady` | 3 | `energySteady` | 8 | steady, stable, moderate, baseline, okay energy, normal energy, holding up, managing |
| Tired | `.tired` | 2 | `energyTired` | 17 | tired, fatigued, low energy, wiped out, no spoons, running on empty, need a nap, flat as a pancake, totally zonked |
| Sluggish | `.sluggish` | 1 | `energySluggish` | 37 | sluggish, dragging, lethargic, burnt out, drained, crashed, crashing, hit a wall, moving through mud, low battery, stuck in slow motion, engine won't turn over |

#### Focus (5 categories, ~96 entries total)

Maps to `FocusLevel` enum in [`Levels.swift:50-78`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift#L50-L78).

| Level | `FocusLevel` case | Numeric | Category | Count | Examples |
|---|---|---|---|---|---|
| Locked In | `.lockedIn` | 5 | `focusLockedIn` | 21 | locked in, hyperfocus, hyperfocused, deep focus, in the zone, flow state, tunnel vision, laser focused, nothing else existed, in a groove |
| Sharp | `.sharp` | 4 | `focusSharp` | 9 | sharp, focused, focus, on task, concentrating, concentration, on track, clear, keeping up |
| Present | `.present` | 3 | `focusPresent` | 6 | present, grounded, with it, tuned in, showing up, engaged |
| Distracted | `.distracted` | 2 | `focusDistracted` | 25 | distracted, distractible, can't focus, zoning out, spacing out, mind wandering, chasing squirrels, brain keeps switching tabs, ten browser tabs in my head |
| Foggy | `.foggy` | 1 | `focusFoggy` | 35 | brain fog, foggy, hazy, mental haze, fuzzy, can't think straight, drawing a blank, all over the place, head is full of static, like my brain is buffering, mind is mush |

#### Emotions (1 category, exactly 20 entries)

Curated from the Mood Meter (Brackett), 5 per valence × energy quadrant:

| Quadrant | Entries |
|---|---|
| High energy + Pleasant | excited, joyful, proud, thrilled, inspired |
| High energy + Unpleasant | angry, anxious, frustrated, irritated, jealous |
| Low energy + Pleasant | content, grateful, peaceful, secure, serene |
| Low energy + Unpleasant | sad, lonely, disappointed, hopeless, discouraged |

#### ADHD community cues (6 categories, ~129 entries total)

| Category | Count | Examples | Prompt role |
|---|---|---|---|
| `taskCompletionCues` | 11 | finished, completed, got shit done, did the thing, nailed it, smashed it | Topic extraction ("Productivity") |
| `taskAvoidanceCues` | 27 | procrastinating, task paralysis, doom pile, doom scrolling, can't make myself do it, revenge bedtime procrastination, shame spiral about not starting | Topic extraction ("Executive Dysfunction") |
| `winCues` | 10 | proud, accomplished, win, victory, crushed it, got shit done | Topic extraction ("Wins") |
| `overwhelmCues` | 19 | overwhelmed, drowning, decision fatigue, spoon deficit, rsd spiral, sensory overload, shutdown mode, popcorn brain | Topic extraction ("Overwhelm") |
| `executiveDysfunction` | 34 | executive dysfunction, can't start, time blind, body doubling, waiting mode, adhd tax, wall of awful, analysis paralysis, context switching, forgot it existed | Topic extraction |
| `appointmentCues` | 18 | appointment, psychiatrist, therapist, prescription renewal, blood test, refill appointment | Topic extraction ("Appointments") |

#### Sleep (3 categories, ~51 entries total)

| Category | Count | Examples | Maps to |
|---|---|---|---|
| `sleepQualityGood` | 16 | slept well, slept like a rock, deep sleep, crashed hard, actually slept through the night, woke up feeling human | `SleepLevel.good` / `.deep` |
| `sleepQualityBad` | 18 | slept badly, broken sleep, tossed and turned, garbage sleep, kept waking up every few hours, woke up exhausted | `SleepLevel.restless` / `.light` |
| `sleepInsomnia` | 17 | insomnia, can't sleep, wired at night, racing thoughts at bedtime, stared at the ceiling, body tired but brain awake | `SleepLevel.restless` |

Sleep quality maps to `SleepLevel` enum in [`Levels.swift:80-99`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift#L80-L99):

| `SleepLevel` case | Numeric | Subtitle |
|---|---|---|
| `.restless` | 1 | broken, tossing |
| `.light` | 2 | thin, barely resting |
| `.okay` | 3 | decent, adequate |
| `.good` | 4 | solid, rested |
| `.deep` | 5 | restorative, refreshed |

#### Physical & side effects (5 categories, ~114 entries total)

| Category | Count | Examples |
|---|---|---|
| `sideEffectCues` | 29 | dry mouth, headache, nausea, insomnia, jittery, heart racing, clenched jaw, flat affect, no personality |
| `physicalSideEffects` | 30 | headache, stomach ache, racing pulse, sweating, grinding teeth, jaw tension, appetite suppression |
| `physicalStim` | 24 | fidgeting, stimming, skin picking, chewing pen, spinning ring, can't stop moving, pacing, nail biting |
| `appetiteLoss` | 17 | no appetite, food is gross, force eating, meds killed my appetite, too focused to eat |
| `appetiteReturn` | 14 | finally hungry, ravenous, binge ate, crash eating, rebound hunger, evening munchies |

#### Medication context (2 categories, ~26 entries total)

| Category | Count | Examples |
|---|---|---|
| `reboundTerms` | 21 | rebound, wearing off, afternoon crash, comedown, the drop, meds wore off, end of dose crash, falling off a cliff |
| `medNotTakenVerbs` | 5 | forgot, missed, skipped, skip, forget |

#### Modifiers & context (3 categories)

| Category | Count | Role in Llama pipeline |
|---|---|---|
| `negationTokens` | 5 (`not`, `never`, `no`, `n't`, `without`) | **Not injected** — LLM handles negation semantically |
| `timeOfDayKeywords` | 8 keyword→normalized mappings (morning, afternoon, evening, night, bedtime + aliases) | **Not injected** — LLM resolves time context natively |
| `activityKeywords` | 11 categories × ~7 keywords each: Resting, Hobbies, Hanging Out, Fitness, Eating, Driving, Work, Chores, Errands, Outdoors, Screen Time | Validation allowlist for activity extraction |

---

## Functional requirements

### MLXJournalService

- **FR-EXT-01 — 100% On-device LLM.** Extraction uses Llama 3.2 (1B) 4-bit Quantized via MLX-Swift [[16]](https://github.com/ml-explore/mlx-swift). Zero network calls. Inference runs on a background actor/queue. The service conforms to `SummarizationService` — the **same protocol** as the legacy `NLSummarizationService`, returning the same `SummaryResult` type.

- **FR-EXT-02 — SummarizationService conformance.** The service implements:
  ```swift
  func summarize(rawTranscription: String) async throws -> SummaryResult
  ```
  Callers (`ProcessingViewModel`, `PendingTranscriptionServiceImpl`) are unaware of the extraction backend. Swapping the implementation requires only a single DI binding change in `AppServices`.

- **FR-EXT-03 — Lexicon loading.** The service loads `lexicon.json` via `LexiconLoader.loadBundled()` at initialisation — the identical loader used by the legacy `NLSummarizationService`. The lexicon object is used for (a) building the system prompt and (b) populating validation allowlists.

- **FR-EXT-04 — Pure Unified Schema.** The entire raw transcript (up to 8 mins / ~1,200 words / ~1,600 tokens) is passed to a single system prompt. There is no word-count routing or prompt switching. The model supports a 128k-token context window [[17]](https://ai.meta.com/blog/llama-3-2-connect-2024-vision-edge-mobile-devices/).

- **FR-EXT-05 — Lexicon-informed system prompt.** The system prompt must:
  1. Instruct the LLM to output **ONLY** a single JSON object with no surrounding text, no markdown backticks.
  2. Enumerate the **exact valid signal labels** from `Levels.swift` (see Signal Schema below).
  3. Include representative vocabulary from each lexicon tier so the model maps ADHD slang to the correct labels (e.g. "bouncing off the walls" → `charged`, "brain fog" → `foggy`, "zombie" → `flat`).
  4. Include the full medication list so the model recognises brand names, generics, slang, and misspellings.
  5. Include 3 few-shot examples (Short Check-in, Journal Entry, Hybrid) to behaviourally route output:
     - **Short check-in** (~1 sentence): signals only, `summary: null`.
     - **Journal entry** (~3+ sentences): signals + empathetic second-person summary + topics + lexicon phrases.
     - **Hybrid**: signals + brief summary.

- **FR-EXT-06 — Memory lifecycle.** The Llama 3.2 1B weights (~0.74 GB in unified memory) are loaded **only after Whisper has been unloaded** (Peak Shaving — documented in [04a](04a-whisperkit-transcription.md)). `os_proc_available_memory()` is checked before loading; if headroom < 200 MB, extraction aborts gracefully (returns raw transcript with no structured signals, not a crash) [[4]](https://developer.apple.com/documentation/os/os_proc_available_memory()).

- **FR-EXT-07 — Cold start lazy loading.** Llama weights are loaded on first extraction, not at app launch. Subsequent extractions reuse the loaded model. The model is not unloaded after extraction unless memory pressure requires it.

- **FR-EXT-08 — Output latency.** Expected 5–15 seconds on A14 Bionic (15–30 tokens/sec for 1B 4-bit). The UI shows *"Synthesizing your journal…"* with a shimmer overlay during this time (managed by `ProcessingViewModel`).

---

### Signal schema (source of truth: `Levels.swift`)

The LLM prompt must instruct the model to output these **exact strings**. The validation layer must reject any value not in these sets.

| Signal | Enum | Valid labels (1 → 5) | Source |
|---|---|---|---|
| Mood | `MoodLevel` | `low`, `flat`, `okay`, `good`, `great` | [`Levels.swift:8-27`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift#L8-L27) |
| Energy | `EnergyLevel` | `sluggish`, `tired`, `steady`, `alert`, `charged` | [`Levels.swift:29-48`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift#L29-L48) |
| Focus | `FocusLevel` | `foggy`, `distracted`, `present`, `sharp`, `lockedIn` | [`Levels.swift:50-78`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift#L50-L78) |
| Sleep quality | `SleepLevel` | `restless`, `light`, `okay`, `good`, `deep` | [`Levels.swift:80-99`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift#L80-L99) |

> **Critical:** The original Llama FSD specified `["Great", "Good", "Okay", "Bad", "Awful"]` for mood and 3-step energy/focus scales. These **do not match** the codebase. The prompt and validation must use the 5-step labels above.

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

- **FR-REV-03 — Confirm semantics.** On Save:
  1. `noteExtraction` is rebuilt from the edited scalars (JSON can't disagree with columns).
  2. `recording.createdAt = date` is set **before** materialising med events so `takenAt` resolves against the corrected day.
  3. `applySummary` + `setMedicationEvents` run.
  4. A user-set non-empty trimmed title always wins over the generated title.
  
  On Cancel: if `summaryStatus != completed`, sets it to `failed` and saves.

- **FR-REV-04 — Provenance tags.** On confirm, one `RecordingTag` is written per mood, energy, focus, each medication, and each emotion:
  - `source: .userCorrected` if that category was touched.
  - `source: .llm` if that category was extracted by the LLM and not modified.
  - `TagCategory` covers mood/energy/focus/medication/emotions — sleep and side-effect edits produce no tags.
  
  Tags are persisted via `store.addCorrectionTags` + `store.save()`.

---

### Fallback & error handling

- **FR-EXT-16 — Graceful fallback.** If JSON parsing entirely fails (all 3 recovery stages exhaust), `summarize()` returns a `SummaryResult` with only the raw transcript as a single bullet, all signals nil. The UI shows the transcript; the user can manually enter details via the Edit sheet. **The app never crashes.**

- **FR-EXT-17 — Memory pressure abort.** If `os_proc_available_memory()` reports < 200 MB before or during Llama inference, generation aborts. The raw transcript is preserved. Equivalent to a parse failure from the UI's perspective.

---

## User flows

### Happy path — transcript to structured signals
1. Clean transcript arrives from WhisperKit (see [04a](04a-whisperkit-transcription.md)).
2. `ProcessingViewModel` calls `mlxJournalService.summarize(rawTranscription:)`.
3. UI shows *"Synthesizing your journal…"* + shimmer.
4. `MLXJournalService` checks `os_proc_available_memory()`, loads Llama if not loaded.
5. Builds system prompt with lexicon vocabulary and signal label enumerations.
6. Injects transcript into user message. Calls MLX-Swift inference.
7. Parses JSON output through Layer 4 validation.
8. Returns `SummaryResult`.
9. `ProcessingViewModel` calls `recording.applySummary()` + `setMedicationEvents()`.
10. Haptic success. Check-in appears with structured signals.

### Fallback flows
- **Hallucinated value**: "fantastic" for energy → not in `["sluggish", "tired", "steady", "alert", "charged"]` → set `nil`. Other valid signals survive.
- **Malformed JSON**: backtick stripping or substring extraction recovers it. If all fail → raw transcript only.
- **Memory pressure**: extraction aborts before loading weights. Raw transcript preserved.
- **User correction**: Edit sheet → Save → provenance tags emitted with `.userCorrected`.

---

## Validation rules & constants

| Rule / constant | Value | Source |
|---|---|---|
| LLM model | Llama 3.2 1B (4-bit), ~0.74 GB unified memory | `llama_extraction_fsd.md` |
| Framework | MLX-Swift | [GitHub](https://github.com/ml-explore/mlx-swift) |
| Target hardware | iPhone 12 Pro (A14 Bionic, 6GB RAM) | `llama_extraction_fsd.md` |
| Memory entitlement | `com.apple.developer.kernel.increased-memory-limit` | [Apple Docs](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_developer_kernel_increased-memory-limit) |
| Memory abort threshold | < 200 MB available | `os_proc_available_memory()` |
| Output latency | 5–15 s (15–30 tok/s on A14) | `llama_extraction_fsd.md` |
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
| Side-effect chips | 15 (dry mouth, headache, nausea, appetite gone, insomnia, jittery, heart racing, stomach ache, dizzy, irritable, rebound, crash, sweating, grinding teeth, flat affect) | `ExtractionReviewView.swift` |
| Lexicon total entries | 718 across 27 categories | `lexicon.json` |

## Edge cases

- **LLM outputs `"Bad"` for mood** → not in valid set → clamped to `nil`. Other signals survive.
- **LLM outputs `"lockedin"` (no camel case) for focus** → not in valid set → clamped to `nil`. The prompt must emphasise exact casing.
- **LLM wraps output in markdown** → backtick stripping catches `` ```json ... ``` ``.
- **LLM outputs extra text** → first-`{`-to-last-`}` extraction recovers the JSON.
- **LLM hallucinates a medication name** → kept (the user may mention a non-ADHD med not in the lexicon). The Edit sheet lets the user correct it.
- **"Energy drink" in transcript** → the LLM handles this semantically (it understands "energy drink" ≠ energy level), unlike the legacy regex guard.
- **Negation ("I'm not feeling great")** → the LLM handles negation natively. No negation window or clause-break logic is needed.
- **Empty transcript** → extraction returns title "Empty Note", all signals nil.
- **Legacy `noteExtractionJSON` decode** → `Recording` decodes with `try?`, so any pre-migration JSON that fails to decode is silently nulled, not crashed.

## Acceptance criteria

1. `MLXJournalService` conforms to `SummarizationService` and returns the same `SummaryResult` type — downstream consumers are unaffected.
2. Signal values use **exactly** the `Levels.swift` enum rawValues — `low`/`flat`/`okay`/`good`/`great` for mood, `sluggish`/`tired`/`steady`/`alert`/`charged` for energy, `foggy`/`distracted`/`present`/`sharp`/`lockedIn` for focus.
3. The system prompt includes representative vocabulary from each lexicon tier so the model recognises ADHD slang.
4. Layer 4 validation rejects any mood/energy/focus value not in the canonical enum sets.
5. Emotions are validated against the exact 20 from `lexicon.json`.
6. The curated lexicon (718 entries) is preserved and actively used — the app's domain recognition is not degraded by the migration.
7. If JSON parsing fails entirely, the user sees raw transcript with no crash.
8. Memory headroom is checked before loading Llama weights.
9. Provenance tags correctly emit `.llm` for untouched and `.userCorrected` for touched categories.
10. The Edit sheet displays the same 5-step signal pickers, 20 emotions, 15 side-effect chips as before.

## Source references

- `MLXJournalService` (new — replaces `NLSummarizationService` / `NLNoteExtractor` / `CueMatcher`)
- [`lexicon.json`](file:///Users/caesargrey/Projects/app-four-llama/docs/llama_migration/lexicon.json) (718 entries, 27 categories)
- [`Levels.swift`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift) (authoritative signal enums)
- [`NLSummarizationService.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/NLSummarizationService.swift) (legacy — logic preserved in validation)
- [`Recording.swift:202-355`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Models/Recording.swift#L202-L355) (`applySummary`, `setMedicationEvents`)
- [`ProcessingViewModel.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/ProcessingViewModel.swift)
- [`ExtractionReviewView.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Views/ExtractionReviewView.swift) · [`ExtractionReviewViewModel.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/ExtractionReviewViewModel.swift)
- [`RecordingTag.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Models/RecordingTag.swift)
- MLX-Swift: [GitHub](https://github.com/ml-explore/mlx-swift)
- Llama 3.2 1B: [HuggingFace](https://huggingface.co/meta-llama/Llama-3.2-1B-Instruct) · [Meta AI Blog](https://ai.meta.com/blog/llama-3-2-connect-2024-vision-edge-mobile-devices/)
- Memory management: [Apple: `os_proc_available_memory()`](https://developer.apple.com/documentation/os/os_proc_available_memory())
- Companion: [04a — WhisperKit Transcription](04a-whisperkit-transcription.md)
- Llama FSD: [`llama_extraction_fsd.md`](llama_extraction_fsd.md)
- Legacy NLP Reference: [`nlp_extractor_reference.md`](nlp_extractor_reference.md)
