<!-- Created: 2026-08-11 19:42 (WEST) · Updated: 2026-08-11 19:44 (WEST) -->
# 04 — Processing & Extraction (Llama Migration)

Documents branch `main` @ `43eb6515a63a0eca957a79aad257da380c73edd4` with LLM Extraction overlay. Unchanged system citations are against `main`. New AI rules reference hardware and Llama documentation.

## Purpose

Describe how a captured check-in becomes structured data: on-device Whisper transcription, the pending-transcription queue for recordings captured before models are ready, the LLM-based extraction pipeline (`MLXJournalService` using Llama 3.2 1B), JSON parsing and Swift-side validation, summarization and persistence, the "Edit check-in" extraction review sheet, provenance tagging, and on-device AI model (Whisper & Llama) download/delete management.

## Scope

- **In scope**: `WhisperKitTranscriptionService`, `PendingTranscriptionServiceImpl`, `ProcessingViewModel`, `MLXJournalService` (replaces `NLNoteExtractor`), `AIModelServiceImpl`, `ExtractionReviewView`/`ExtractionReviewViewModel`, `RecordingTag`, `Recording.applySummary`/`setMedicationEvents`, the signal enums in `Packages/SquirlSignals`.
- **Out of scope**: Audio capture itself (check-in capture), rendering of extracted data in the library ([Library & History](05-library-and-history.md)), aggregation into insights ([Insights](06-insights.md)), and the medication bar / Dose Guard ([Medications](07-medications.md)).

## Actors & triggers

- **User** — records a voice check-in (up to 15 minutes); taps "Stop & save"; opens the Edit sheet from a recording's detail view; downloads/deletes AI models in settings; taps "Tap to retry" / "Retry transcription/extraction" after a failure.
- **System triggers** — app launch (`.task`), every foreground (`scenePhase == .active`), and background model-download completion all trigger a pending-queue drain (`SquirlApp.swift:125-130, 161`). Recording stop triggers transcription when the Whisper model is installed, which immediately hands off to LLM extraction if the Llama model is installed; otherwise the recording enters the pending queue. Transcription and extraction run automatically — there is **no** automatic review prompt.

## Functional requirements

### Transcription provider (`WhisperKitTranscriptionService`)

- **FR-PRC-01 — Single on-device transcription provider.** Transcription is performed by `WhisperKitTranscriptionService`, an `actor` wrapping WhisperKit with the `openai_whisper-small` (or Tiny) model. There is no runtime provider switch.
- **FR-PRC-02 — Hard-coded English.** `DecodingOptions(language: "en")` — the language is always English (`WhisperKitTranscriptionService.swift:133`).
- **FR-PRC-03 — ADHD medical prompt, opt-out defaulting ON.** When enabled, transcription is seeded with a fixed medical/ADHD prompt to bias the decoder toward relevant vocabulary (Concerta, Vyvanse, executive dysfunction, etc.). The opt-out key `UserDefaults.medicalPromptEnabled` **defaults to `true`** (`WhisperKitTranscriptionService.swift:18-24, 130-141`; `Constants.swift:23-38`).
- **FR-PRC-04 — Voice Activity Detection (VAD).** Transcription relies on WhisperKit's built-in VAD to gate transcription to speech segments only, saving battery and avoiding hallucinations [[13]](https://docs.argmaxinc.com/whisperkit/).
- **FR-PRC-05 — Non-speech marker stripping.** Before passing to the LLM, a regex removes literal Whisper non-speech markers (`BLANK AUDIO`, `SILENCE`, `MUSIC`, `INAUDIBLE`, `NOISE`, etc.) and collapses whitespace (`WhisperKitTranscriptionService.swift:33-46`).
- **FR-PRC-06 — Streaming lifecycle & Peak Shaving.** `transcribe(audioURL:)` holds a background task. Crucially, **the Whisper model is explicitly unloaded from memory** before finishing the stream so Metal/CoreML buffers are freed *before* initializing the Llama LLM, honoring Jetsam limits (`WhisperKitTranscriptionService.swift:83-214`).
- **FR-PRC-07 — 90-second transcription timeout.** Stream consumption races against a 90s timeout; on timeout, the recording is marked `.failed` with a retry prompt (`CheckInViewModel.swift:246-330`).
- **FR-PRC-08 — Serialization across recordings.** A new recording's transcription chains after any prior in-flight transcription to prevent overlapping memory pressure spikes (`CheckInViewModel.swift:157-167, 209-214`).

### Pending-transcription & extraction lifecycle

- **FR-PRC-09 — Pending status.** When a recording is saved but models are missing, the recording is persisted with `status = .pendingTranscription`. The UI shows **"Ready shortly…"** — never error language (`CheckInViewModel.swift:200-207`; `RecordingStore.swift:14-36`).
- **FR-PRC-10 — Drain triggers.** `PendingTranscriptionServiceImpl` drains the queue on app launch, foreground transition, and background-download completion (`PendingTranscriptionServiceImpl.swift:4-16`).
- **FR-PRC-11 — Serialized drain.** `drainIfModelReady()` coalesces concurrent triggers. Recordings are processed oldest-first, verifying models exist between recordings (`PendingTranscriptionServiceImpl.swift:37-63`).
- **FR-PRC-12 — Identical pipeline.** Drain runs the identical pipeline: stream transcription → `Task.checkCancellation()` → memory handoff (unload Whisper) → `MLXJournalService.extract(transcript:)` → `applySummary` + `status = .completed` (`PendingTranscriptionServiceImpl.swift:68-144`).

### LLM extraction pipeline (`MLXJournalService`)

- **FR-PRC-13 — 100% On-device LLM.** Extraction utilizes Llama 3.2 (1B) 4-bit Quantized running via MLX-Swift. There are **no network calls**. Inference runs strictly on a background actor/queue to keep the main UI thread responsive at 60fps [[16]](https://github.com/ml-explore/mlx-swift).
- **FR-PRC-14 — Pure Unified Schema.** The entire raw transcript (duration agnostic, up to 15 mins / ~3,000 tokens) is passed to a single, unified System Prompt. The model natively handles up to 128k context length, eliminating word-count routing [[17]](https://ai.meta.com/blog/llama-3-2-connect-2024-vision-edge-mobile-devices/).
- **FR-PRC-15 — Rigid System Prompt & Few-Shot Examples.** The system prompt enforces outputting ONLY a single JSON object conforming exactly to the `UnifiedExtraction` schema, with no markdown backticks. It relies on 3 few-shot examples (Short Check-in, Journal Entry, Hybrid) to route behavior (e.g., setting `summary: null` for brief check-ins vs generating an empathetic second-person summary for journals).
- **FR-PRC-16 — Layer 4 Swift-Side Validation.** Because 1B models can hallucinate, `parseExtraction` is resilient:
  1. Tries direct JSON decode.
  2. Strips markdown backticks (e.g., ` ```json `) and retries.
  3. Uses regex/substring matching to extract JSON slices from surrounding text.
  4. Discards hallucinated values by validating against strict enums (e.g., clamping `topics` to 4 max, `lexicon` to 5 max, `sleepHours` to 0-24, and matching exact mood strings).
- **FR-PRC-17 — Fallback Grace.** If JSON parsing entirely fails, the UI falls back to showing only the raw transcript, notifying the user that synthesis failed. The app never crashes.

### Extracted signals inventory

- **FR-PRC-18 — UnifiedExtraction Schema.** `mood` (String), `energy` (String), `focus` (String), `sleep_hours` (Double), `medications` (Array of Name/Dose/Taken), `topics` (Array of Strings), `lexicon` (Array of Strings), `summary` (String).
- **FR-PRC-19 — Signal scales.** Validations map string values directly to the 5-step ordinals (`numericValue` 1–5) in `Packages/SquirlSignals`: `MoodLevel` (low/flat/okay/good/great), `EnergyLevel` (sluggish/tired/steady/alert/charged), `FocusLevel` (foggy/distracted/present/sharp/lockedIn). (Note: The prompt expects the LLM to output specific strings which are mapped onto these levels.)

### Summarization & persistence

- **FR-PRC-20 — Summarization mapping.** The validated extracted JSON maps to the SwiftData `Recording`/`JournalEntry` models. `topics` and `lexicon` are saved directly. `summary` provides the main bullet list or paragraph content (`Recording.swift:202-306`).
- **FR-PRC-21 — Pipeline status & UX.** `ProcessingViewModel` sets `summaryStatus = generating`, displaying *"Synthesizing your journal..."* to mask 5-15s latency. Upon parsing success, it triggers a `UINotificationFeedbackGenerator.success` haptic, and sets `summaryStatus = completed` (`ProcessingViewModel.swift:27-92`).
- **FR-PRC-22 — Transcript medication events.** `setMedicationEvents` creates `MedicationEvent` records based on the LLM's `medications` array output, deleting prior transcript-sourced meds but preserving `source == .manual` entries (`Recording.swift:301-355`).

### Extraction review ("Edit check-in")

- **FR-PRC-23 — Manual-only review entry.** The review sheet is reached only from `RecordingDetailView` via the trailing pencil button (accessibility "Edit check-in"). User retains ultimate agency; all AI-generated fields must be editable inline (`RecordingDetailView.swift:54-74`).
- **FR-PRC-24 — Editable cards.** Displays AI-synthesized fields: When (date/time capped at now), Signals (Mood/Energy/Focus `GlyphRampPicker`), Sleep (level chips + duration presets 2/4/6/8/10h + custom), Medications (Taken/Missed toggle, dose chips, editable duration), Topics, and Summary text (`ExtractionReviewView.swift:118-440`).
- **FR-PRC-25 — Confirm semantics.** On Save: scalars and text are rewritten, and the JSON cache is rebuilt so persisted JSON can't disagree with the database columns (`ExtractionReviewViewModel.swift:183-263`).
- **FR-PRC-26 — Provenance tags.** Updates `RecordingTag`: sets `source: .userCorrected` if that category was touched, else remains `.nlp` / `.llm`. Tags are persisted via `store.addCorrectionTags` (`ExtractionReviewViewModel.swift:35, 231-253`).

### AI Model Management & Constraints

- **FR-PRC-27 — Model download & lifecycle.** WhisperKit and Llama models are managed via `AIModelServiceImpl`. Models download to local storage (e.g. `~/Library/whisperkit`), reporting clamped progress up to 0.99 until fully finalized. The filesystem is the source of truth (`AIModelServiceImpl.swift:22-153`).
- **FR-PRC-28 — Memory Limits & Entitlements (Jetsam).** The iPhone 12 Pro 6GB baseline strictly enforces Jetsam limits (~2.5-3GB). The app explicitly requests the `com.apple.developer.kernel.increased-memory-limit` entitlement to access required headroom for the ~0.74GB Llama model and ~150MB Whisper model [[4]](https://developer.apple.com/documentation/os/os_proc_available_memory()).
- **FR-PRC-29 — Runtime Monitoring.** `MLXJournalService` queries `os_proc_available_memory()` dynamically. If headroom falls below critical thresholds (e.g., 200MB), generation aborts gracefully to prevent a Jetsam crash.
- **FR-PRC-30 — Cold Start Lazy Loading.** Llama 3.2 model weights are explicitly lazy-loaded *only* when the user taps "Stop & Save", ensuring instant app launch.
- **FR-PRC-31 — Privacy (Zero-Cloud).** The app declares `NSMicrophoneUsageDescription` detailing that audio processing happens completely offline.

## User flows

### Happy path — voice check-in to structured data
1. User records a voice note (up to 15 mins) and taps "Stop & save".
2. UI updates to "How are you feeling?" / "Journaling..." dynamically.
3. Whisper model performs background transcription.
4. Whisper model is evicted from memory (Peak Shaving).
5. UI shows *"Synthesizing your journal..."* while `MLXJournalService` loads Llama 3.2 and generates JSON output based on the transcript.
6. JSON is parsed, validated, and persisted. Haptic success triggers.
7. Check-in appears in library with AI-generated summary, topics, lexicon, and structured signals.

### Alternate flows
- **Models not installed at save time:** Persisted as `.pendingTranscription` ("Ready shortly…"); drained automatically once models are downloaded.
- **Transcription timeout/cancel/error:** Status `.failed` with retry copy. User retries from the detail view.
- **LLM Hallucination/Parse Failure:** Gracefully fails to parse JSON. User sees raw transcript and can manually enter details in Edit sheet.
- **Memory Pressure Abort:** If `os_proc_available_memory()` hits critical levels, extraction cancels safely to prevent Jetsam crash.
- **User corrects extraction:** Opens detail → pencil → Edit check-in → adjusts fields → Save. Scalars rewritten, provenance tags re-emitted with `.userCorrected` for touched categories.

## UI states

- **Empty transcript** → Extraction titled "Empty Note".
- **Transcribing** → Status `.transcribing`; detail transcript card shows spinner + "Transcribing…".
- **Pending transcription** → Status `.pendingTranscription`, display title "Ready shortly…", no error language.
- **Extraction failure** → `summaryStatus = failed`, UI offers "Tap to retry" or shows raw transcript.
- **Synthesizing** → Loading state overlay with shimmer effect.
- **Model states** → `ModelStatus` notInstalled/downloading/installing/ready/corrupted; download progress clamped to 0.99 until final 1.0.

## Validation rules & constants

| Rule / constant | Value | Source |
|---|---|---|
| Target Hardware | iPhone 12 Pro (A14 Bionic, 6GB RAM) | `llama_extraction_fsd.md` |
| Whisper model | `openai_whisper-small` or Tiny, ~150MB | `WhisperKitTranscriptionService.swift:11` / `llama_extraction_fsd.md` |
| Llama model footprint | Llama 3.2 1B (4-bit), ~0.74 GB in unified memory | `llama_extraction_fsd.md` |
| Language | hard-coded `"en"` | `WhisperKitTranscriptionService.swift:133` |
| Medical prompt default | ON (`medicalPromptEnabled` defaults true) | `Constants.swift:23-38` |
| Transcription timeout | 90 s | `CheckInViewModel.swift:250` |
| Max recording length | 15 mins (~3,000 tokens) | `llama_extraction_fsd.md` |
| Output Latency | 5-15 seconds (15-30 tok/s) | `llama_extraction_fsd.md` |
| Max Topics / Lexicon | 4 topics / 5 lexicon terms | `UnifiedExtraction` validation |
| Valid Moods | ["Great", "Good", "Okay", "Bad", "Awful"] | `UnifiedExtraction` validation |
| Download progress clamp | 0.99 until final 1.0 | `AIModelServiceImpl.swift:43, 125-131` |
| Highlight/Extract threshold | Fallback layer validations discard invalid JSON silently | `MLXJournalService` validation logic |
| Edit sheet constraints | Date/time capped at now; sleep presets 2/4/6/8/10 h | `ExtractionReviewView.swift` |

## Edge cases

- Cancellation mid-extraction returns partial results or aborts gracefully; cancelled model downloads finish quietly without touching possibly torn-down SwiftData state.
- Recording deleted mid-transcription/mid-drain: the pipeline re-verifies existence and never touches a freed `@Model`.
- Review-sheet cancel on an incomplete recording marks the summary `failed`.

## Acceptance criteria

1. A completed voice check-in yields persisted mood/energy/focus/sleep scalars, topics, lexicon, and transcript-sourced medication events without any network call.
2. A recording saved with the model absent shows "Ready shortly…" and is transcribed+summarized automatically after the model download completes or on next foreground.
3. Memory headroom is checked via `os_proc_available_memory()` before loading Llama weights, ensuring zero Jetsam crashes.
4. If the LLM output is badly malformed, validation catches it, ignores the bad data, and gracefully displays only the raw text.
5. Saving corrections in the Edit sheet rewrites scalars and emits `.userCorrected` tags for exactly the touched categories; untouched categories keep `.llm` / `.nlp`.
6. Model download reports monotonic progress ending at exactly 1.0; deleting the model resets both flags and makes `localPath(for:)` return nil.

## Source references

- `app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift:7-225`
- `app-four/Services/PendingTranscriptionServiceImpl.swift:4-144`
- `app-four/ViewModels/CheckInViewModel.swift:157-330` · `app-four/ViewModels/ProcessingViewModel.swift:27-92`
- `app-four/Services/MLXJournalService.swift` (replaces legacy NL extraction)
- `app-four/Services/AIModelServiceImpl.swift:14-153`
- `app-four/Models/Recording.swift:202-355` · `app-four/Models/RecordingTag.swift:4-43` · `app-four/Models/AppEnums.swift:4-108`
- `app-four/Views/ExtractionReviewView.swift` · `app-four/ViewModels/ExtractionReviewViewModel.swift` · `app-four/Views/RecordingDetailView.swift:54-74`
- Hardware & memory limits: [Apple Developer: `os_proc_available_memory()`](https://developer.apple.com/documentation/os/os_proc_available_memory())
- WhisperKit integration: [Argmax: WhisperKit Docs](https://docs.argmaxinc.com/whisperkit/)
- MLX integration: [GitHub: mlx-swift](https://github.com/ml-explore/mlx-swift)
- Sibling FSD: [Library & History](05-library-and-history.md) · [Insights](06-insights.md) · [Medications](07-medications.md)
