<!-- Created: 2026-08-11 19:42 (WEST) · Updated: 2026-08-11 19:50 (WEST) -->
# 04 — Processing & Extraction (Llama Migration)

Documents branch `main` @ `43eb6515a63a0eca957a79aad257da380c73edd4` with LLM Extraction overlay. Unchanged system citations are against `main`. New AI rules reference hardware and Llama documentation. Lexicon inventory sourced from `lexicon.json` (1 092 lines, 718 entries) and `Levels.swift` (the authoritative signal scales).

## Purpose

Describe how a captured check-in becomes structured data: on-device Whisper transcription, the pending-transcription queue for recordings captured before models are ready, the LLM-based extraction pipeline (`MLXJournalService` using Llama 3.2 1B), the role of the curated lexicon in prompt construction and Swift-side validation, JSON parsing, summarization and persistence, the "Edit check-in" extraction review sheet, provenance tagging, and on-device AI model (Whisper & Llama) download/delete management.

## Scope

- **In scope**: `WhisperKitTranscriptionService`, `PendingTranscriptionServiceImpl`, `ProcessingViewModel`, `MLXJournalService` (replaces `NLNoteExtractor`), `lexicon.json` (retained, repurposed), `AIModelServiceImpl`, `ExtractionReviewView`/`ExtractionReviewViewModel`, `RecordingTag`, `Recording.applySummary`/`setMedicationEvents`, the signal enums in `Packages/SquirlSignals`.
- **Out of scope**: Audio capture itself (check-in capture), rendering of extracted data in the library ([Library & History](05-library-and-history.md)), aggregation into insights ([Insights](06-insights.md)), and the medication bar / Dose Guard ([Medications](07-medications.md)).

## Actors & triggers

- **User** — records a voice check-in (up to 15 minutes); taps "Stop & save"; opens the Edit sheet from a recording's detail view; downloads/deletes AI models in settings; taps "Tap to retry" / "Retry transcription/extraction" after a failure.
- **System triggers** — app launch (`.task`), every foreground (`scenePhase == .active`), and background model-download completion all trigger a pending-queue drain (`SquirlApp.swift:125-130, 161`). Recording stop triggers transcription when the Whisper model is installed, which immediately hands off to LLM extraction if the Llama model is installed; otherwise the recording enters the pending queue. Transcription and extraction run automatically — there is **no** automatic review prompt.

---

## Functional requirements

### Transcription provider (`WhisperKitTranscriptionService`)

- **FR-PRC-01 — Single on-device transcription provider.** Transcription is performed by `WhisperKitTranscriptionService`, an `actor` wrapping WhisperKit with the `openai_whisper-small` (or Tiny) model. There is no runtime provider switch (`WhisperKitTranscriptionService.swift:7-11`; `AppDependencies.swift`).
- **FR-PRC-02 — Hard-coded English.** `DecodingOptions(language: "en")` — the language is always English (`WhisperKitTranscriptionService.swift:133`).
- **FR-PRC-03 — ADHD medical prompt, opt-out defaulting ON.** When enabled, transcription is seeded with a fixed medical/ADHD prompt to bias the decoder toward relevant vocabulary (Concerta, Vyvanse, executive dysfunction, etc.). The opt-out key `UserDefaults.medicalPromptEnabled` **defaults to `true`**; when off, `promptTokens = nil` so non-medical audio isn't dragged toward medication vocabulary (`WhisperKitTranscriptionService.swift:18-24, 130-141`; `Constants.swift:23-38`).
- **FR-PRC-04 — Voice Activity Detection (VAD).** Transcription relies on WhisperKit's built-in VAD to gate transcription to speech segments only, saving battery and avoiding hallucinations [[13]](https://docs.argmaxinc.com/whisperkit/).
- **FR-PRC-05 — Non-speech marker stripping.** Before passing to the LLM, a regex removes literal Whisper non-speech markers — `BLANK AUDIO`, `SILENCE`, `NO SPEECH`, `MUSIC`, `INAUDIBLE`, `NOISE`, `SOUND`, `PAUSE`, `APPLAUSE`, `LAUGH(S)`, `LAUGHTER`, `BEEP`, `STATIC`, `CLICKING` (case-insensitive, bracket or paren, `_`/space variants) — then collapses 2+ whitespace and trims (`WhisperKitTranscriptionService.swift:33-46`).
- **FR-PRC-06 — Streaming lifecycle & Peak Shaving.** `transcribe(audioURL:)` cancels any prior in-flight transcription (single-inference discipline), yields progress segments, holds a `beginBackgroundTask(name: "WhisperTranscription")` for the whole inference, joins all result text, and **unloads the model before finishing the stream** so Metal/CoreML buffers are freed *before* initializing the Llama LLM, honoring Jetsam limits. An empty result throws; errors yield a final `isError: true` segment (`WhisperKitTranscriptionService.swift:83-214`).
- **FR-PRC-07 — 90-second transcription timeout.** Stream consumption races against a 90s timeout (`consumeStreamWithTimeout(..., timeoutSeconds: 90)`); on timeout, the recording is marked `.failed` with text **"Transcription timed out. Tap to retry in the recording detail view."** (`CheckInViewModel.swift:246-330`).
- **FR-PRC-08 — Serialization across recordings.** A new recording's transcription chains after any prior in-flight transcription — the single WhisperKit engine never runs two inferences at once, and a back-to-back recording never cancels the previous transcription (`CheckInViewModel.swift:157-167, 209-214`).

### Pending-transcription & extraction lifecycle

- **FR-PRC-09 — Pending status.** When a recording is saved but models are missing, the recording is persisted with `status = .pendingTranscription`. This status is distinct from `.transcribing` and `.failed`. The UI shows **"Ready shortly…"** — never error language (`CheckInViewModel.swift:200-207`; `AppEnums.swift:4-14`; `Recording.swift:44-51`; `RecordingStore.swift:14-36`).
- **FR-PRC-10 — Drain triggers.** `PendingTranscriptionServiceImpl` (an `actor`) drains the queue on three triggers wired in `SquirlApp`: app launch (`.task`), every foreground transition (`scenePhase == .active`), and background-download completion (`SquirlApp.swift:125-130, 161`; `PendingTranscriptionServiceImpl.swift:4-16`).
- **FR-PRC-11 — Serialized drain.** `drainIfModelReady()` no-ops when models are absent; an `isDraining` latch coalesces concurrent/re-entrant triggers into a single pass. Pending recording **UUIDs** (not models) are fetched oldest-first (`createdAt` ascending); each recording is re-resolved at drain time, so a recording deleted meanwhile is simply not found. Between recordings the drain re-checks models still exist and stops if not (`PendingTranscriptionServiceImpl.swift:37-63`).
- **FR-PRC-12 — Identical pipeline.** Each drained recording runs through the **exact** post-recording path: stream transcription → `Task.checkCancellation()` → memory handoff (unload Whisper) → `MLXJournalService.extract(transcript:)` → `applySummary` + `setMedicationEvents` + `status = .completed`. Cancellation is logged and swallowed; any other error marks `.failed` (`PendingTranscriptionServiceImpl.swift:68-144`).

---

### The lexicon: retained, repurposed

> **The curated `lexicon.json` (718 entries across 27 categories) is the source of truth for the app's ADHD-specific vocabulary.** It was originally consumed by `CueMatcher` for deterministic substring matching. Under the Llama migration it is **not deleted** — it is repurposed to serve two new roles:
>
> 1. **Prompt vocabulary injection** — selected lexicon categories are serialised into the system prompt so the 1B model recognises domain-specific slang and maps it to the correct signal labels (e.g. "bouncing off the walls" → energy: charged).
> 2. **Swift-side validation allowlists** — the valid signal labels, medication names, and emotion tokens from the lexicon are used as the canonical allowlists in Layer 4 validation to clamp or discard hallucinated LLM output.
>
> The lexicon is loaded at startup via `LexiconLoader.loadBundled()` exactly as before; what changes is the *consumer* — `MLXJournalService` instead of `NLNoteExtractor`.

#### Lexicon inventory (source: `lexicon.json`)

| Category | Count | Role in Llama pipeline |
|---|---|---|
| `medications` | ~90 names (brand, generic, slang, common misspellings) | Injected into prompt context so the LLM recognises ADHD meds; used as allowlist for medication name validation |
| `moodSpecific` | ~60 word→label mappings across 5 levels (low/flat/okay/good/great) | Defines the vocabulary the LLM should map onto `MoodLevel` labels |
| `energyCharged` | 22 phrases | Prompt context for `EnergyLevel.charged` |
| `energyAlert` | 7 phrases | Prompt context for `EnergyLevel.alert` |
| `energySteady` | 8 phrases | Prompt context for `EnergyLevel.steady` |
| `energyTired` | 17 phrases | Prompt context for `EnergyLevel.tired` |
| `energySluggish` | 37 phrases | Prompt context for `EnergyLevel.sluggish` |
| `focusLockedIn` | 21 phrases | Prompt context for `FocusLevel.lockedIn` |
| `focusSharp` | 9 phrases | Prompt context for `FocusLevel.sharp` |
| `focusPresent` | 6 phrases | Prompt context for `FocusLevel.present` |
| `focusDistracted` | 25 phrases | Prompt context for `FocusLevel.distracted` |
| `focusFoggy` | 35 phrases | Prompt context for `FocusLevel.foggy` |
| `emotions` | exactly 20 (5 per valence×energy quadrant) | Validation allowlist for the `emotions` field; injected into prompt |
| `taskCompletionCues` | 11 phrases | Prompt context for topic extraction ("Productivity") |
| `taskAvoidanceCues` | 27 phrases | Prompt context for topic extraction ("Executive Dysfunction") |
| `winCues` | 10 phrases | Prompt context for topic extraction ("Wins") |
| `overwhelmCues` | 19 phrases | Prompt context for topic extraction ("Overwhelm") |
| `executiveDysfunction` | 34 phrases | Prompt context for topic extraction |
| `appointmentCues` | 18 phrases | Prompt context for topic extraction ("Appointments") |
| `sideEffectCues` | 29 phrases | Prompt context; validation allowlist for side-effect extraction |
| `physicalStim` | 24 phrases | Prompt context for behavioural cues |
| `physicalSideEffects` | 30 phrases | Prompt context; validation allowlist |
| `sleepQualityGood` | 16 phrases | Prompt context for sleep quality mapping |
| `sleepQualityBad` | 18 phrases | Prompt context for sleep quality mapping |
| `sleepInsomnia` | 17 phrases | Prompt context for sleep quality mapping |
| `reboundTerms` | 21 phrases | Prompt context for medication rebound detection |
| `appetiteLoss` | 17 phrases | Prompt context for appetite change detection |
| `appetiteReturn` | 14 phrases | Prompt context for appetite change detection |
| `negationTokens` | 5 tokens: `not`, `never`, `no`, `n't`, `without` | *Not injected into prompt* — negation is handled semantically by the LLM |
| `medNotTakenVerbs` | 5 verbs: `forgot`, `missed`, `skipped`, `skip`, `forget` | *Not injected into prompt* — the LLM understands missed-med semantics natively |
| `timeOfDayKeywords` | 8 keyword→normalized mappings | *Not injected into prompt* — the LLM extracts time context natively |
| `activityKeywords` | 11 categories (Resting, Hobbies, Hanging Out, Fitness, Eating, Driving, Work, Chores, Errands, Outdoors, Screen Time) | Validation allowlist for activity extraction |

---

### LLM extraction pipeline (`MLXJournalService`)

- **FR-PRC-13 — 100% On-device LLM.** Extraction utilizes Llama 3.2 (1B) 4-bit Quantized running via MLX-Swift [[16]](https://github.com/ml-explore/mlx-swift). There are **no network calls**. Inference runs strictly on a background actor/queue to keep the main UI thread responsive at 60fps.
- **FR-PRC-14 — Pure Unified Schema.** The entire raw transcript (duration agnostic, up to 15 mins / ~3,000 tokens at ~150 wpm) is passed to a single, unified System Prompt. There is no word-count check or prompt swapping. The model natively supports a 128k-token context window [[17]](https://ai.meta.com/blog/llama-3-2-connect-2024-vision-edge-mobile-devices/).
- **FR-PRC-15 — Lexicon-informed System Prompt.** The system prompt is the primary control lever for the 1B model. It must:
  1. Instruct the LLM to output **ONLY** a single JSON object with no surrounding text or markdown.
  2. Enumerate the **exact valid signal labels** from `Levels.swift` (see Signal Schema below).
  3. Include representative vocabulary from the lexicon so the model correctly maps ADHD slang to labels (e.g. "bouncing off the walls" → `charged`, "brain fog" → `foggy`, "zombie" → `flat`).
  4. Include 3 few-shot examples (Short Check-in, Journal Entry, Hybrid) to behaviourally route output.
- **FR-PRC-16 — Layer 4 Swift-Side Validation.** Because 1B models can hallucinate, `parseExtraction` is resilient:
  1. Tries direct JSON decode.
  2. Strips markdown backticks (e.g., ` ```json `) and retries.
  3. Uses first-`{`-to-last-`}` substring extraction from surrounding text.
  4. Validates all values against the **canonical lexicon allowlists**:
     - `mood` must be one of `["low", "flat", "okay", "good", "great"]` — else `nil`.
     - `energy` must be one of `["sluggish", "tired", "steady", "alert", "charged"]` — else `nil`.
     - `focus` must be one of `["foggy", "distracted", "present", "sharp", "lockedIn"]` — else `nil`.
     - `sleep_hours` must be 0–24 — else `nil`.
     - `sleep_quality` must be one of `["restless", "light", "okay", "good", "deep"]` — else `nil`.
     - `emotions` validated against the exact 20 from `lexicon.json` — unrecognised entries dropped.
     - `medications[].name` validated against the ~90 medication names — unrecognised entries **kept** (the user may mention a non-ADHD med; the LLM can still extract it).
     - `topics` capped at 4 max.
     - `lexicon` (user phrases) capped at 5 max.
  5. Returns `nil` on total failure — UI shows raw transcript only.
- **FR-PRC-17 — Fallback Grace.** If JSON parsing entirely fails, the UI falls back to showing only the raw transcript, notifying the user that synthesis failed. The app never crashes, never shows garbage, and the user always keeps their data.

---

### Extracted signals inventory

- **FR-PRC-18 — Signal Schema (source of truth: `Levels.swift`).** The `UnifiedExtraction` struct must use the **exact same 5-step ordinal scales** as the existing codebase. The LLM prompt must instruct the model to output these exact strings:

| Signal | Enum | Labels (1→5) | Source |
|---|---|---|---|
| Mood | `MoodLevel` | `low`, `flat`, `okay`, `good`, `great` | `Levels.swift:8-27` |
| Energy | `EnergyLevel` | `sluggish`, `tired`, `steady`, `alert`, `charged` | `Levels.swift:29-48` |
| Focus | `FocusLevel` | `foggy`, `distracted`, `present`, `sharp`, `lockedIn` | `Levels.swift:50-78` |
| Sleep quality | `SleepLevel` | `restless`, `light`, `okay`, `good`, `deep` | `Levels.swift:80-99` |

> **Critical reconciliation note:** The original Llama FSD specified `["Great", "Good", "Okay", "Bad", "Awful"]` for mood and `["High", "Medium", "Low"]` for energy. These **do not match** the actual codebase enums. The system prompt **must** use the labels above. The validation layer **must** reject any value not in these exact sets.

- **FR-PRC-19 — Emotions (exactly 20, Mood-Meter derived).** 5 per valence×energy quadrant, from `lexicon.json`:
  - **High Energy + Pleasant:** excited, joyful, proud, thrilled, inspired
  - **High Energy + Unpleasant:** angry, anxious, frustrated, irritated, jealous
  - **Low Energy + Pleasant:** content, grateful, peaceful, secure, serene
  - **Low Energy + Unpleasant:** sad, lonely, disappointed, hopeless, discouraged

- **FR-PRC-20 — Activities (exactly 11 categories).** Surface-only categories from `activityKeywords`: Resting, Hobbies, Hanging Out, Fitness, Eating, Driving, Work, Chores, Errands, Outdoors, Screen Time.

- **FR-PRC-21 — Full extraction schema.** `UnifiedExtraction` carries:

```swift
struct UnifiedExtraction: Codable {
    var mood: String?          // MoodLevel rawValue or null
    var energy: String?        // EnergyLevel rawValue or null
    var focus: String?         // FocusLevel rawValue or null
    var sleepHours: Double?    // 0-24 or null
    var sleepQuality: String?  // SleepLevel rawValue or null
    var medications: [MedicationEvent]
    var emotions: [String]     // subset of the 20 curated emotions
    var activities: [String]   // subset of the 11 categories
    var topics: [String]       // 1-4 high-level themes
    var lexicon: [String]      // 3-5 user phrases/slang
    var summary: String?       // null for brief check-ins
    var sideEffects: [String]  // from sideEffectCues/physicalSideEffects
}
```

- **FR-PRC-22 — Medication events.** Each entry:

```swift
struct MedicationEvent: Codable {
    var name: String    // medication name (validated against lexicon)
    var dose: String    // e.g. "36mg", "morning"
    var taken: Bool     // true = taken, false = missed/skipped
}
```

---

### Summarization & persistence

- **FR-PRC-23 — Summarization mapping.** The validated extracted JSON maps to the SwiftData `Recording` model. Signal strings are resolved to their enum cases (`MoodLevel(rawValue:)`, etc.). `topics`, `lexicon`, `emotions`, `activities`, and `sideEffects` arrays are saved directly. `summary` provides the bullet content. `noteExtractionJSON` is persisted with mood/energy/focus/emotions/sideEffects/sleepHours **stripped** (they live in scalar columns — single-source-of-truth) (`Recording.swift:202-306`).
- **FR-PRC-24 — SleepLevel derivation.** If the LLM outputs `sleep_quality` directly, use it. Otherwise, derive from `sleep_hours`: `<5` → restless; `5..<6` → light; `6..<7` → okay; `7..<9` → good; `≥9` → deep. Nil when sleep wasn't mentioned (`NLSummarizationService.swift:55-75`).
- **FR-PRC-25 — Title generation.** Default (voice) mode: title = "Mood · Energy · Focus" parts capitalised (e.g. "Good · Alert · Sharp") when any exist, else LLM-generated title from first topic or summary sentence. `fillOnly` (text check-in) fills only nil scalars — user-entered values are never overwritten (`Recording.swift:202-260`).
- **FR-PRC-26 — Topics generation.** The LLM generates topics semantically. Validation: "Medications" must be present if any med events were extracted; "Symptoms" if sideEffects/reboundTerms non-empty; "Appointments" if appointment language detected. These rules mirror the legacy deterministic topic derivation (`NLSummarizationService.swift:83-103`).
- **FR-PRC-27 — Pipeline status & UX.** `ProcessingViewModel` sets `summaryStatus = generating`, displaying *"Synthesizing your journal..."* with shimmer overlay to mask 5–15s latency. Upon parsing success, it triggers a `UINotificationFeedbackGenerator.success` haptic and sets `summaryStatus = completed`. On throw → `summaryStatus = failed` and the UI shows **"Tap to retry"** (`ProcessingViewModel.swift:27-92`).
- **FR-PRC-28 — Transcript medication events.** `setMedicationEvents` deletes all `source == .transcript` `MedicationEvent`s and recreates them from the extraction, **skipping names that exist as `source == .manual`** (manual dose beats extractor). Duration resolution: per-med `durationHours` ?? call-site default ?? **10.0 h**. Sets `hasMedication` from inputs (`Recording.swift:301-355`).

### Extraction review ("Edit check-in")

- **FR-PRC-29 — Manual-only review entry.** The review sheet is reachable **only** from `RecordingDetailView`'s trailing pencil toolbar button (accessibility label **"Edit check-in"**), presented as a `.sheet(item:)` with `.presentationDetents([.large])` and a visible drag indicator. There is **no automatic review prompt** (`RecordingDetailView.swift:54-74`; `ExtractionReviewView.swift:53-54`).
- **FR-PRC-30 — Editable cards.** Six cards: **When** (date/time `DatePicker`s bounded `in: ...Date()` — future dates/times cannot be set); **Signals** (three `GlyphRampPicker` rows MOOD/ENERGY/FOCUS with a current-value line); **Sleep** (all five `SleepLevel` chips toggle, duration presets **2/4/6/8/10 h**, plus a custom-hours field with comma→dot normalisation); **Medications** (Taken/Missed toggle, catalog dose chips, read-only time line, editable duration field); **Emotions** (the 20 curated emotions as "Pleasant"/"Unpleasant" chip groups); **Side effects** (15 hard-coded chips: dry mouth, headache, nausea, appetite gone, insomnia, jittery, heart racing, stomach ache, dizzy, irritable, rebound, crash, sweating, grinding teeth, flat affect) (`ExtractionReviewView.swift:118-440`).
- **FR-PRC-31 — Confirm semantics.** On Save: `noteExtraction` is rebuilt from the edited scalars so persisted JSON can't disagree with columns; `recording.createdAt = date` is set **before** materialising med events so `takenAt` resolves against the corrected day; `applySummary` + `setMedicationEvents` run; a user-set non-empty trimmed title always wins. Cancel: if `summaryStatus != completed`, sets it to `failed` and saves (`ExtractionReviewViewModel.swift:183-263`).
- **FR-PRC-32 — Provenance tags.** On confirm, one `RecordingTag` is written per mood, energy, focus, each medication, and each emotion: `source: .userCorrected` if that category was touched, else `.llm`. `TagCategory` covers mood/energy/focus/medication/emotions — sleep and side-effect edits produce no tags. Tags are persisted via `store.addCorrectionTags` + `store.save()` (`ExtractionReviewViewModel.swift:35, 231-253`; `RecordingTag.swift:4-43`).

### AI Model Management & Constraints

- **FR-PRC-33 — Model download & lifecycle.** WhisperKit and Llama models are managed via `AIModelServiceImpl`. Whisper downloads to `~/Library/whisperkit`; progress is clamped to `min(fractionCompleted, 0.99)` until done, then yields exactly `1.0`. The filesystem is the source of truth — `localPath(for:)` verifies the folder contains expected artefacts (`AIModelServiceImpl.swift:22-153`).
- **FR-PRC-34 — Error classification.** `URLError.dataNotAllowed` → `.cellularDisabled`; `.notConnectedToInternet`/`.networkConnectionLost` → `.noNetwork`; file-write out-of-space → `.insufficientSpace`; anything else → `.other(String)` with only a short type tag — content-free by design (`AIModelServiceImpl.swift:65-86`).
- **FR-PRC-35 — Delete & ground truth.** `delete(_:)` removes the download directory and resets `isDownloaded`/`isCorrupted`. The filesystem is the source of truth; SwiftData `isDownloaded` mirrors it (`AIModelServiceImpl.swift:88-109, 133-153`).
- **FR-PRC-36 — Memory Limits & Entitlements (Jetsam).** The iPhone 12 Pro 6GB baseline strictly enforces Jetsam limits (~2.5–3GB). The app explicitly requests the `com.apple.developer.kernel.increased-memory-limit` entitlement. Model footprint: Llama ~0.74GB + WhisperKit ~150MB = ~0.9GB combined, leaving ~1.6–2.1GB headroom [[4]](https://developer.apple.com/documentation/os/os_proc_available_memory()) [[5]](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_developer_kernel_increased-memory-limit).
- **FR-PRC-37 — Runtime Monitoring.** `MLXJournalService` queries `os_proc_available_memory()` dynamically before and during inference. If headroom falls below 200MB, generation aborts gracefully to prevent a Jetsam crash, preserving the user's raw transcript.
- **FR-PRC-38 — Cold Start Lazy Loading.** Llama 3.2 model weights (~0.7GB) are explicitly lazy-loaded *only* when the user taps "Stop & Save", ensuring the app launches instantly without pre-loading weights into RAM.
- **FR-PRC-39 — Privacy (Zero-Cloud).** 100% of data processing occurs locally. No network requests containing user voice or text data are permitted. The app declares `NSMicrophoneUsageDescription` with a clear explanation that audio never leaves the device.

---

## User flows

### Happy path — voice check-in to structured data
1. User records a voice note (up to 15 mins) and taps "Stop & save"; the recording is persisted immediately.
2. UI updates dynamically: *"How are you feeling?"* (0–45s) → *"Journaling..."* (45s+).
3. Whisper model performs background transcription (chained after any prior transcription; 90s timeout).
4. Whisper model is explicitly evicted from memory (Peak Shaving).
5. UI shows *"Synthesizing your journal..."* with shimmer overlay while `MLXJournalService` loads Llama 3.2 and generates JSON output.
6. JSON is parsed with multi-stage fallback, validated against lexicon allowlists, and persisted. Haptic success triggers.
7. Check-in appears in library with AI-generated summary, mood/energy/focus/sleep signals, topics, emotions, medications, and lexicon phrases.

### Alternate flows
- **Models not installed at save time:** Persisted as `.pendingTranscription` ("Ready shortly…"); drained automatically once models are downloaded via the identical pipeline (FR-PRC-09–12).
- **Transcription timeout/cancel/error:** Status `.failed` with retry copy stored in `fullTranscriptText`. User retries from the recording detail "Retry transcription" button.
- **LLM Hallucination/Parse Failure:** Layer 4 validation catches invalid values. On total JSON failure, user sees raw transcript and can manually enter details in Edit sheet.
- **Memory Pressure Abort:** If `os_proc_available_memory()` hits critical levels (<200MB), extraction cancels safely, raw transcript preserved.
- **User corrects extraction:** Opens detail → pencil → Edit check-in → adjusts fields → Save. Scalars rewritten, provenance tags re-emitted with `.userCorrected` for touched categories.
- **Lexicon resource missing/malformed:** `LexiconLoader` silently falls back to code defaults — extraction never breaks.

## UI states

- **Empty transcript** → extraction titled "Empty Note".
- **Transcribing** → status `.transcribing`; detail transcript card shows spinner + "Transcribing…".
- **Pending transcription** → status `.pendingTranscription`, display title "Ready shortly…", no pill in the transcript card, no error language.
- **Synthesizing** → loading state overlay with shimmer effect, *"Synthesizing your journal..."*.
- **Extraction failure** → `summaryStatus = failed`, UI offers "Tap to retry".
- **Model states** → `ModelStatus` notInstalled/downloading/installing/ready/corrupted; download progress clamped to 0.99 until the final 1.0.
- **Edit sheet** → always populated (seeded from the recording); no empty/loading/error states exist in that view.

## Validation rules & constants

| Rule / constant | Value | Source |
|---|---|---|
| Target Hardware | iPhone 12 Pro (A14 Bionic, 6GB RAM) | `llama_extraction_fsd.md` |
| Whisper model | `openai_whisper-small`, 74 MB, base `~/Library/whisperkit` | `WhisperKitTranscriptionService.swift:11` |
| Llama model | Llama 3.2 1B (4-bit), ~0.74 GB in unified memory | `llama_extraction_fsd.md` |
| Language | hard-coded `"en"` | `WhisperKitTranscriptionService.swift:133` |
| Medical prompt default | ON (`medicalPromptEnabled` defaults true) | `Constants.swift:23-38` |
| Transcription timeout | 90 s | `CheckInViewModel.swift:250` |
| Max recording length | 15 mins (~2,250 words / ~3,000 tokens) | `llama_extraction_fsd.md` |
| Output Latency | 5–15 seconds (15–30 tok/s on A14) | `llama_extraction_fsd.md` |
| Valid Moods | `["low", "flat", "okay", "good", "great"]` | `Levels.swift:8-13` |
| Valid Energy | `["sluggish", "tired", "steady", "alert", "charged"]` | `Levels.swift:29-34` |
| Valid Focus | `["foggy", "distracted", "present", "sharp", "lockedIn"]` | `Levels.swift:50-55` |
| Valid Sleep | `["restless", "light", "okay", "good", "deep"]` | `Levels.swift:80-85` |
| SleepLevel from hours | <5 restless, 5–6 light, 6–7 okay, 7–9 good, ≥9 deep | `NLSummarizationService.swift:65-72` |
| Emotions | exactly 20 curated (5 per quadrant) | `lexicon.json:emotions` |
| Activities | exactly 11 surface-only categories | `lexicon.json:activityKeywords` |
| Medications | ~90 names (brand, generic, slang, misspellings) | `lexicon.json:medications` |
| Max Topics | 4 | `UnifiedExtraction` validation |
| Max Lexicon phrases | 5 | `UnifiedExtraction` validation |
| Download progress clamp | 0.99 until final 1.0 | `AIModelServiceImpl.swift:43, 125-131` |
| Med duration fallback | 10.0 h | `Recording.swift:342` |
| Edit sheet constraints | date/time capped at now; sleep presets 2/4/6/8/10 h; emotions exactly 20; side-effect chips exactly 15 | `ExtractionReviewView.swift` |
| Side-effect chips | dry mouth, headache, nausea, appetite gone, insomnia, jittery, heart racing, stomach ache, dizzy, irritable, rebound, crash, sweating, grinding teeth, flat affect | `ExtractionReviewView.swift` |

## Edge cases

- Cancellation mid-extraction aborts gracefully; cancelled model downloads finish quietly without touching possibly torn-down SwiftData state.
- Recording deleted mid-transcription/mid-drain: the pipeline re-verifies existence and never touches a freed `@Model`.
- Legacy `noteExtractionJSON` (pre-Llama) still decodes via `decodeIfPresent`; `Recording` decodes with `try?`, so any decode failure nulls the JSON extraction without crashing.
- "Energy drink/bar/gel/shot" should not yield an energy level — the LLM handles this semantically via context, unlike the legacy regex guard.
- The LLM natively understands negation ("I'm not feeling great"), tense, and clause scoping ("I skipped lunch and took my Concerta" should not mark Concerta missed) — eliminating the need for deterministic negation windows and clause-break logic.
- No numeric confidence is ever produced; `RecordingTag.confidence` stays nil.
- Review-sheet cancel on an incomplete recording marks the summary `failed`.

## Acceptance criteria

1. A completed voice check-in yields persisted mood/energy/focus/sleep scalars, topics, emotions, activities, lexicon phrases, side effects, and transcript-sourced medication events without any network call.
2. Signal values persisted in the database use **exactly** the `Levels.swift` enum rawValues (`low`/`flat`/`okay`/`good`/`great` for mood, etc.) — not the FSD's originally proposed simplified labels.
3. A recording saved with models absent shows "Ready shortly…" and is transcribed+summarised automatically after model download or on next foreground.
4. Memory headroom is checked via `os_proc_available_memory()` before loading Llama weights, ensuring zero Jetsam crashes.
5. If the LLM output is badly malformed, Layer 4 validation catches it, discards invalid values, and gracefully displays only the raw text.
6. Saving corrections in the Edit sheet rewrites scalars and emits `.userCorrected` tags for exactly the touched categories; untouched categories keep `.llm`.
7. Model download reports monotonic progress ending at exactly 1.0; deleting the model resets both flags and makes `localPath(for:)` return nil.
8. The curated lexicon vocabulary (medications, ADHD slang, emotions) is preserved and actively used — the app's domain-specific recognition is **not** degraded by the migration to LLM-based extraction.

## Source references

- `app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift:7-225`
- `app-four/Services/PendingTranscriptionServiceImpl.swift:4-144`
- `app-four/ViewModels/CheckInViewModel.swift:157-330` · `app-four/ViewModels/ProcessingViewModel.swift:27-92`
- `app-four/Services/MLXJournalService.swift` (replaces legacy `NLNoteExtractor` + `CueMatcher`)
- `app-four/Resources/lexicon.json` (retained — 718 entries, 27 categories)
- `app-four/Services/NoteExtraction/LexiconData.swift` · `LexiconLoader` (loading/overlay logic retained)
- `app-four/Services/AIModelServiceImpl.swift:14-153`
- `app-four/Models/Recording.swift:202-355` · `app-four/Models/RecordingTag.swift:4-43` · `app-four/Models/AppEnums.swift:4-108`
- `app-four/Views/ExtractionReviewView.swift` · `app-four/ViewModels/ExtractionReviewViewModel.swift` · `app-four/Views/RecordingDetailView.swift:54-74`
- `Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift:8-99` (authoritative signal enums)
- Hardware & memory limits: [Apple Developer: `os_proc_available_memory()`](https://developer.apple.com/documentation/os/os_proc_available_memory())
- Increased memory entitlement: [Apple Developer: Entitlements](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_developer_kernel_increased-memory-limit)
- WhisperKit integration: [GitHub: WhisperKit](https://github.com/argmaxinc/WhisperKit) · [Argmax Docs](https://docs.argmaxinc.com/whisperkit/)
- MLX-Swift framework: [GitHub: mlx-swift](https://github.com/ml-explore/mlx-swift)
- Llama 3.2 1B Instruct: [HuggingFace](https://huggingface.co/meta-llama/Llama-3.2-1B-Instruct) · [Meta AI Blog](https://ai.meta.com/blog/llama-3-2-connect-2024-vision-edge-mobile-devices/)
- Sibling FSD: [Library & History](05-library-and-history.md) · [Insights](06-insights.md) · [Medications](07-medications.md)
- Llama Extraction FSD: `llama_extraction_fsd.md` (hardware constraints, prompt specification, reliability stack)
- Legacy NLP Reference: `nlp_extractor_reference.md` (archived deterministic pipeline documentation)
