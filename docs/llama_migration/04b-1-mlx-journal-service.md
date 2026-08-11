<!-- Created: 2026-08-11 22:44 (WEST) · Updated: 2026-08-11 22:44 (WEST) -->
# 04b-1 — MLXJournalService Core (`MLXJournalService`)

The on-device LLM extraction engine that replaces the legacy `NLNoteExtractor` + `CueMatcher`. Covers model loading, lexicon-informed prompt construction, MLX-Swift inference, and memory lifecycle.

> **This is Part 1 of 3.** It produces a raw JSON string from a transcript. The JSON is consumed by [Part 2 — Validation & Persistence](04b-2-validation-persistence.md), which parses, validates, and persists the structured signals. [Part 3 — Extraction Review UI](04b-3-extraction-review-ui.md) covers the user-facing edit sheet.

Companion to [04a — WhisperKit Transcription](04a-whisperkit-transcription.md), which covers everything up to the moment a clean transcript string is produced. This document covers the first stage of what happens next.

## Purpose

Describe how a clean transcript string is fed into the `MLXJournalService` (Llama 3.2 1B via MLX-Swift) for structured ADHD journal signal extraction. Covers: the service's conformance to `SummarizationService`, how the existing curated lexicon seeds the LLM prompt, the model's memory lifecycle, and inference execution.

## Scope

- **In scope**: `MLXJournalService` (new — replaces `NLSummarizationService` / `NLNoteExtractor` / `CueMatcher`), `lexicon.json` (retained, repurposed), `LexiconLoader`, `Levels.swift` signal enums (for prompt label enumeration), system prompt construction, MLX-Swift model loading and inference, memory lifecycle.
- **Out of scope**: JSON parsing and validation ([Part 2](04b-2-validation-persistence.md)), persistence via `Recording.applySummary` / `setMedicationEvents` ([Part 2](04b-2-validation-persistence.md)), `ExtractionReviewView` / `ExtractionReviewViewModel` ([Part 3](04b-3-extraction-review-ui.md)), Whisper transcription ([04a](04a-whisperkit-transcription.md)), audio capture ([03](../fsd/03-check-in-capture.md)), library rendering ([05](../fsd/05-library-and-history.md)), insights ([06](../fsd/06-insights.md)), medication bar / Dose Guard ([07](../fsd/07-medications.md)).

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
> | `CueMatcher` loads the lexicon and performs exact-substring matching with Damerau–Levenshtein fuzzy tolerance | `MLXJournalService` loads the lexicon and uses it for two purposes: **(1)** injecting domain vocabulary into the system prompt so the 1B model recognises ADHD slang, and **(2)** providing the canonical allowlists for Swift-side validation (see [Part 2](04b-2-validation-persistence.md)) |
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

- **FR-EXT-03 — Lexicon loading.** The service loads `lexicon.json` via `LexiconLoader.loadBundled()` at initialisation — the identical loader used by the legacy `NLSummarizationService`. The lexicon object is used for (a) building the system prompt and (b) populating validation allowlists (consumed by [Part 2](04b-2-validation-persistence.md)).

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

The LLM prompt must instruct the model to output these **exact strings**. The validation layer ([Part 2](04b-2-validation-persistence.md)) must reject any value not in these sets.

| Signal | Enum | Valid labels (1 → 5) | Source |
|---|---|---|---|
| Mood | `MoodLevel` | `low`, `flat`, `okay`, `good`, `great` | [`Levels.swift:8-27`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift#L8-L27) |
| Energy | `EnergyLevel` | `sluggish`, `tired`, `steady`, `alert`, `charged` | [`Levels.swift:29-48`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift#L29-L48) |
| Focus | `FocusLevel` | `foggy`, `distracted`, `present`, `sharp`, `lockedIn` | [`Levels.swift:50-78`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift#L50-L78) |
| Sleep quality | `SleepLevel` | `restless`, `light`, `okay`, `good`, `deep` | [`Levels.swift:80-99`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift#L80-L99) |

> **Critical:** The original Llama FSD specified `["Great", "Good", "Okay", "Bad", "Awful"]` for mood and 3-step energy/focus scales. These **do not match** the codebase. The prompt and validation must use the 5-step labels above.

---

## User flows (Part 1 scope)

### Happy path — transcript to raw JSON
1. Clean transcript arrives from WhisperKit (see [04a](04a-whisperkit-transcription.md)).
2. `ProcessingViewModel` calls `mlxJournalService.summarize(rawTranscription:)`.
3. UI shows *"Synthesizing your journal…"* + shimmer.
4. `MLXJournalService` checks `os_proc_available_memory()`, loads Llama if not loaded.
5. Builds system prompt with lexicon vocabulary and signal label enumerations.
6. Injects transcript into user message. Calls MLX-Swift inference.
7. **Hands raw JSON string to the validation layer** → [Part 2](04b-2-validation-persistence.md).

### Fallback flows (Part 1 scope)
- **Memory pressure**: extraction aborts before loading weights. Raw transcript preserved. Equivalent to a parse failure from the UI's perspective.
- **Empty transcript**: extraction returns title "Empty Note", all signals nil.

---

## Edge cases (Part 1 scope)

- **"Energy drink" in transcript** → the LLM handles this semantically (it understands "energy drink" ≠ energy level), unlike the legacy regex guard.
- **Negation ("I'm not feeling great")** → the LLM handles negation natively. No negation window or clause-break logic is needed.
- **Empty transcript** → extraction returns title "Empty Note", all signals nil.

---

## Validation rules & constants (Part 1 scope)

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
| Lexicon total entries | 718 across 27 categories | `lexicon.json` |

---

## Acceptance criteria (Part 1 scope)

1. `MLXJournalService` conforms to `SummarizationService` and returns the same `SummaryResult` type — downstream consumers are unaffected.
2. The system prompt includes representative vocabulary from each lexicon tier so the model recognises ADHD slang.
3. The curated lexicon (718 entries) is preserved and actively used — the app's domain recognition is not degraded by the migration.
4. Memory headroom is checked before loading Llama weights.
5. Signal values in the prompt enumerate **exactly** the `Levels.swift` enum rawValues — `low`/`flat`/`okay`/`good`/`great` for mood, `sluggish`/`tired`/`steady`/`alert`/`charged` for energy, `foggy`/`distracted`/`present`/`sharp`/`lockedIn` for focus.

---

## Source references

- `MLXJournalService` (new — replaces `NLSummarizationService` / `NLNoteExtractor` / `CueMatcher`)
- [`lexicon.json`](file:///Users/caesargrey/Projects/app-four-llama/docs/llama_migration/lexicon.json) (718 entries, 27 categories)
- [`Levels.swift`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift) (authoritative signal enums)
- [`NLSummarizationService.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/NLSummarizationService.swift) (legacy — logic preserved in validation)
- [`ProcessingViewModel.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/ProcessingViewModel.swift)
- MLX-Swift: [GitHub](https://github.com/ml-explore/mlx-swift)
- Llama 3.2 1B: [HuggingFace](https://huggingface.co/meta-llama/Llama-3.2-1B-Instruct) · [Meta AI Blog](https://ai.meta.com/blog/llama-3-2-connect-2024-vision-edge-mobile-devices/)
- Memory management: [Apple: `os_proc_available_memory()`](https://developer.apple.com/documentation/os/os_proc_available_memory())
- Companion: [04a — WhisperKit Transcription](04a-whisperkit-transcription.md)
- Llama FSD: [`llama_extraction_fsd.md`](llama_extraction_fsd.md)
- Legacy NLP Reference: [`nlp_extractor_reference.md`](nlp_extractor_reference.md)
- Part 2: [04b-2 — Validation & Persistence](04b-2-validation-persistence.md)
- Part 3: [04b-3 — Extraction Review UI](04b-3-extraction-review-ui.md)
