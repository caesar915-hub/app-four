# Feature Specification: MLXJournalService — On-Device LLM Extraction

**Feature Branch**: `043-mlx-journal-service`

**Created**: 2026-08-11

**Status**: Draft

**Input**: User description: "Replace the legacy NLNoteExtractor + CueMatcher pipeline with an on-device Llama 3.2 1B LLM (via MLX-Swift) for structured ADHD journal signal extraction. The new MLXJournalService conforms to the existing SummarizationService protocol so downstream consumers are unaffected. The curated lexicon (718 entries, 27 categories) is retained and repurposed for prompt injection and validation."

**Source**: [`04b-1-mlx-journal-service.md`](file:///Users/caesargrey/Projects/app-four-llama/docs/llama_migration/04b-1-mlx-journal-service.md) (Part 1 of 3 — raw JSON extraction only)

## User Scenarios & Testing *(mandatory)*

### User Story 1 — LLM-based signal extraction from transcript (Priority: P1)

After completing a voice check-in, the user's transcript is fed to the on-device Llama 3.2 1B model which produces a structured JSON containing mood, energy, focus, sleep, medications, topics, summary, and emotions — replacing the legacy regex/NLP pipeline entirely.

**Why this priority**: This is the core purpose of the feature. Without LLM inference producing a valid JSON from a transcript, nothing downstream (validation, persistence, review UI) can function.

**Independent Test**: Pass a representative transcript string to `MLXJournalService.summarize(rawTranscription:)` and verify it returns a `SummaryResult` with correctly labelled signals matching the `Levels.swift` enum values.

**Acceptance Scenarios**:

1. **Given** a clean transcript from WhisperKit (e.g. "Took my Vyvanse this morning. Feeling pretty good, energy is steady. Focus is sharp but I did zone out for a bit after lunch."), **When** `MLXJournalService.summarize(rawTranscription:)` is called, **Then** the returned `SummaryResult` contains mood=`good`, energy=`steady`, focus=`sharp`, and a medication entry for "Vyvanse".
2. **Given** the model is not yet loaded (cold start), **When** `summarize()` is called for the first time, **Then** the model loads lazily, inference completes within 5–15 seconds on A14, and subsequent calls reuse the loaded model.
3. **Given** the transcript contains ADHD community slang (e.g. "brain keeps switching tabs", "doom scrolling all night", "took my addy"), **When** extraction runs, **Then** the model maps slang to correct labels (`distracted`, topic "Executive Dysfunction", medication "Adderall") because the lexicon vocabulary is embedded in the system prompt.

---

### User Story 2 — SummarizationService protocol swap (Priority: P1)

The `MLXJournalService` is a drop-in replacement for `NLSummarizationService`. Callers (`ProcessingViewModel`, `PendingTranscriptionServiceImpl`) call the same `summarize(rawTranscription:)` method and receive the same `SummaryResult` type. The swap requires only a single DI binding change in `AppServices`.

**Why this priority**: Protocol conformance is the integration boundary — if this breaks, the entire check-in flow breaks.

**Independent Test**: Swap the `SummarizationService` binding in `AppServices` from `NLSummarizationService` to `MLXJournalService`, run a check-in, and verify `ProcessingViewModel` and `PendingTranscriptionServiceImpl` continue to work without code changes.

**Acceptance Scenarios**:

1. **Given** `AppServices` binds `SummarizationService` to `MLXJournalService`, **When** `ProcessingViewModel` calls `summarizationService.summarize()`, **Then** it receives a valid `SummaryResult` and the processing flow completes.
2. **Given** `AppServices` binds `SummarizationService` to `MLXJournalService`, **When** `PendingTranscriptionServiceImpl` calls `summarizationService.summarize()` for a background transcription, **Then** it receives a valid `SummaryResult`.

---

### User Story 3 — Lexicon-informed prompt construction (Priority: P1)

The system prompt is constructed at runtime by injecting representative ADHD vocabulary from the curated `lexicon.json` (718 entries, 27 categories), the exact valid signal labels from `Levels.swift`, the full medication list (including slang and misspellings), and 3 few-shot examples.

**Why this priority**: The 1B model's accuracy depends entirely on prompt quality. Without lexicon injection, the model won't recognise ADHD-specific slang or map to the correct signal labels.

**Independent Test**: Inspect the constructed system prompt string and verify it contains (a) all 5 mood labels, 5 energy labels, 5 focus labels, 5 sleep labels, (b) representative vocabulary from each lexicon tier, (c) the full medication list, and (d) 3 few-shot examples.

**Acceptance Scenarios**:

1. **Given** `lexicon.json` is loaded via `LexiconLoader.loadBundled()`, **When** the system prompt is constructed, **Then** it includes vocabulary from all 27 lexicon categories that are relevant for prompt injection (excluding `negationTokens`, `medNotTakenVerbs`, `timeOfDayKeywords` which the LLM handles semantically).
2. **Given** `Levels.swift` defines `MoodLevel`, `EnergyLevel`, `FocusLevel`, `SleepLevel`, **When** the system prompt is constructed, **Then** it enumerates the **exact** rawValue strings: `low/flat/okay/good/great`, `sluggish/tired/steady/alert/charged`, `foggy/distracted/present/sharp/lockedIn`, `restless/light/okay/good/deep`.
3. **Given** the prompt template includes 3 few-shot examples, **When** a short check-in (~1 sentence) is processed, **Then** the model returns signals only with `summary: null`. **When** a journal entry (~3+ sentences) is processed, **Then** the model returns signals + empathetic second-person summary + topics + lexicon phrases.

---

### User Story 4 — Memory lifecycle and peak shaving (Priority: P2)

Llama 3.2 1B weights (~0.74 GB unified memory) are loaded **only after Whisper has been unloaded** (peak shaving). Memory headroom is checked via `os_proc_available_memory()` before loading. If headroom < 200 MB, extraction aborts gracefully.

**Why this priority**: Without memory management, the app will crash on lower-RAM devices (6 GB iPhone 12 Pro). This is critical for stability but sits below core extraction in priority because it's a guardrail around the main flow.

**Independent Test**: Simulate low-memory conditions and verify the service aborts without crashing, preserving the raw transcript.

**Acceptance Scenarios**:

1. **Given** Whisper has been unloaded and `os_proc_available_memory()` returns ≥ 200 MB, **When** `summarize()` is called, **Then** Llama weights are loaded and inference proceeds.
2. **Given** `os_proc_available_memory()` returns < 200 MB, **When** `summarize()` is called, **Then** extraction aborts gracefully (returns raw transcript with no structured signals), and the app does not crash.
3. **Given** the model was loaded for a previous extraction, **When** `summarize()` is called again, **Then** the model is reused (no reload), unless memory pressure has forced unloading.

---

### User Story 5 — Cold start lazy loading (Priority: P2)

Llama weights are loaded on first extraction, not at app launch. This avoids blocking launch time and unnecessary memory consumption for users who haven't started a check-in.

**Why this priority**: Important for app launch performance but not a prerequisite for extraction correctness.

**Independent Test**: Launch the app, verify Llama weights are not loaded. Trigger first check-in, verify weights load at extraction time.

**Acceptance Scenarios**:

1. **Given** the app has just launched, **When** no check-in has been triggered, **Then** Llama weights are not in memory.
2. **Given** this is the user's first check-in this session, **When** extraction begins, **Then** weights are loaded on-demand before inference.

---

### Edge Cases & Error Handling

#### 1. Network & Connectivity Failures
- **Scenario:** Not applicable — extraction is 100% on-device with zero network calls (FR-EXT-01).
- **System Behavior:** No network dependency exists.
- **User Experience (UX):** No change; works in airplane mode.

#### 2. Data Validation & Bad Input
- **Scenario:** Empty transcript is passed to the service.
- **System Behavior:** Service returns a `SummaryResult` with title "Empty Note" and all signal fields set to `nil`.
- **User Experience (UX):** The user sees a blank recording entry that can be manually edited.

#### 3. State Restoration & Interruptions
- **Scenario:** App is backgrounded or terminated mid-inference.
- **System Behavior:** The inference task is cancelled. `PendingTranscriptionServiceImpl` picks up the transcript on next launch and retries extraction.
- **User Experience (UX):** User sees "Processing…" on the recording entry; extraction completes on next app launch.

#### 4. Memory Pressure During Inference
- **Scenario:** System memory pressure rises while the model is loaded.
- **System Behavior:** If memory drops below threshold before loading, extraction aborts. If pressure rises during inference, the system relies on iOS memory management; the worst case is the OS terminating the extension, after which `PendingTranscriptionServiceImpl` retries.
- **User Experience (UX):** User sees the recording preserved with raw transcript but no structured signals.

#### 5. Semantic Ambiguity
- **Scenario:** Transcript contains "energy drink" (not an energy level signal) or negation ("I'm not feeling great").
- **System Behavior:** The LLM handles these semantically — it understands "energy drink" ≠ energy level, and negation inverts sentiment. No regex guards or negation windows are needed.
- **User Experience (UX):** Correct signal extraction without false positives.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-EXT-01**: System MUST perform 100% on-device LLM extraction using Llama 3.2 1B (4-bit quantized) via MLX-Swift. Zero network calls. Inference runs on a background actor/queue.
- **FR-EXT-02**: `MLXJournalService` MUST conform to `SummarizationService` protocol, implementing `func summarize(rawTranscription: String) async throws -> SummaryResult`. Callers are unaware of the extraction backend.
- **FR-EXT-03**: System MUST load `lexicon.json` (718 entries, 27 categories) via `LexiconLoader.loadBundled()` at initialisation for (a) building the system prompt and (b) populating validation allowlists.
- **FR-EXT-04**: System MUST use a single unified prompt schema — the entire raw transcript (up to ~1,600 tokens) is passed to one system prompt. No word-count routing or prompt switching.
- **FR-EXT-05**: The system prompt MUST (1) instruct ONLY JSON output with no surrounding text or markdown, (2) enumerate exact `Levels.swift` signal labels, (3) include representative ADHD vocabulary from each lexicon tier, (4) include the full medication list with slang and misspellings, (5) include 3 few-shot examples (Short, Journal, Hybrid).
- **FR-EXT-06**: Llama weights (~0.74 GB) MUST load **only after Whisper unload**. `os_proc_available_memory()` MUST be checked before loading; if headroom < 200 MB, extraction aborts gracefully (raw transcript preserved, no crash).
- **FR-EXT-07**: Llama weights MUST be loaded lazily on first extraction, not at app launch. Subsequent extractions reuse the loaded model.
- **FR-EXT-08**: Expected output latency is 5–15 seconds on A14 Bionic (15–30 tokens/sec). The UI MUST show "Synthesizing your journal…" with a shimmer overlay during inference (managed by `ProcessingViewModel`).

### Key Entities

- **`MLXJournalService`**: New service class replacing `NLSummarizationService` / `NLNoteExtractor` / `CueMatcher`. Conforms to `SummarizationService`. Loads the lexicon, builds the prompt, invokes MLX-Swift inference, and returns raw JSON to the validation layer (Part 2).
- **`SummarizationService`** (protocol): Existing integration boundary. Defines `summarize(rawTranscription:) async throws -> SummaryResult`. Unchanged.
- **`SummaryResult`**: Existing return type containing structured signals (mood, energy, focus, sleep, medications, topics, summary, emotions). Unchanged.
- **`lexicon.json`**: Curated ADHD vocabulary (718 entries, 27 categories). Retained and repurposed — no longer consumed by `CueMatcher` for substring matching; now consumed by `MLXJournalService` for prompt injection and validation allowlists.
- **`LexiconLoader`**: Existing utility. Loads `lexicon.json` from the app bundle. Unchanged.
- **`Levels.swift`**: Source of truth for signal enums (`MoodLevel`, `EnergyLevel`, `FocusLevel`, `SleepLevel`). Unchanged.
- **`RecordingTag`**: Provenance label changes from `.nlp` to `.llm` for LLM-extracted signals (`.userCorrected` remains).

### Signal Schema (source of truth: `Levels.swift`)

| Signal | Enum | Valid labels (1 → 5) |
|---|---|---|
| Mood | `MoodLevel` | `low`, `flat`, `okay`, `good`, `great` |
| Energy | `EnergyLevel` | `sluggish`, `tired`, `steady`, `alert`, `charged` |
| Focus | `FocusLevel` | `foggy`, `distracted`, `present`, `sharp`, `lockedIn` |
| Sleep | `SleepLevel` | `restless`, `light`, `okay`, `good`, `deep` |

### Architecture: What Changes, What Stays

| Component | Legacy (NL) | Llama Migration | Status |
|---|---|---|---|
| `SummarizationService` protocol | `NLSummarizationService` | `MLXJournalService` | **Swap** |
| `NLNoteExtractor` + `CueMatcher` | Deterministic regex/tokenizer | Replaced by LLM inference | **Removed** |
| `lexicon.json` | Loaded by `LexiconLoader`, consumed by `CueMatcher` | Loaded by `LexiconLoader`, consumed for prompt injection + validation | **Retained & repurposed** |
| `Levels.swift` signal enums | Source of truth | Source of truth | **Unchanged** |
| `SummaryResult` | Returned by `NLSummarizationService` | Returned by `MLXJournalService` | **Unchanged** |
| `ProcessingViewModel` | Calls `summarize()` | Calls `summarize()` | **Unchanged** |
| `PendingTranscriptionServiceImpl` | Calls `summarize()` | Calls `summarize()` | **Unchanged** |
| `ExtractionReviewView` / `ViewModel` | Displays/edits signals | Displays/edits signals | **Unchanged** |
| `RecordingTag` | `.nlp` / `.userCorrected` | `.llm` / `.userCorrected` | **Label change** |

### Validation Rules & Constants

| Rule / Constant | Value |
|---|---|
| LLM model | Llama 3.2 1B (4-bit), ~0.74 GB unified memory |
| Framework | MLX-Swift |
| Target hardware | iPhone 12 Pro (A14 Bionic, 6 GB RAM) |
| Memory entitlement | `com.apple.developer.kernel.increased-memory-limit` |
| Memory abort threshold | < 200 MB available (`os_proc_available_memory()`) |
| Output latency | 5–15 s (15–30 tok/s on A14) |
| Lexicon total entries | 718 across 27 categories |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `MLXJournalService.summarize()` returns a valid `SummaryResult` for 100% of non-empty transcripts — downstream consumers (`ProcessingViewModel`, `PendingTranscriptionServiceImpl`, `Recording`) require zero code changes.
- **SC-002**: The system prompt includes all valid signal labels from `Levels.swift` and representative vocabulary from each lexicon tier — verified by prompt-level assertions in unit tests.
- **SC-003**: Inference completes within 15 seconds on A14 Bionic for transcripts up to 1,600 tokens.
- **SC-004**: The curated lexicon (718 entries) is preserved and actively used in the prompt — the app's ADHD domain recognition is not degraded by the migration.
- **SC-005**: Memory headroom check prevents crashes on 6 GB devices — extraction aborts gracefully if `os_proc_available_memory()` < 200 MB.
- **SC-006**: Cold start loads model only at first extraction, not at app launch — verified by monitoring memory footprint on launch.

## Assumptions

- Whisper model is always unloaded before `MLXJournalService.summarize()` is invoked (peak shaving coordination documented in [04a](file:///Users/caesargrey/Projects/app-four-llama/docs/llama_migration/04a-whisperkit-transcription.md)).
- The `increased-memory-limit` entitlement is already present in the app's entitlements file.
- JSON parsing, validation, and persistence are handled by [Part 2 — Validation & Persistence](file:///Users/caesargrey/Projects/app-four-llama/docs/llama_migration/04b-2-validation-persistence.md) and are out of scope for this spec.
- The Extraction Review UI is handled by [Part 3](file:///Users/caesargrey/Projects/app-four-llama/docs/llama_migration/04b-3-extraction-review-ui.md) and is out of scope for this spec.
- The `SummarizationService` protocol and `SummaryResult` type are stable and will not change shape during this migration.
- `LexiconLoader.loadBundled()` continues to work as-is — no changes to the loader are required.
- The lexicon categories `negationTokens`, `medNotTakenVerbs`, and `timeOfDayKeywords` are **not** injected into the prompt — the LLM handles these semantically.

## Source References

- [`04b-1-mlx-journal-service.md`](file:///Users/caesargrey/Projects/app-four-llama/docs/llama_migration/04b-1-mlx-journal-service.md) — Source FSD (Part 1 of 3)
- [`lexicon.json`](file:///Users/caesargrey/Projects/app-four-llama/docs/llama_migration/lexicon.json) — Curated ADHD vocabulary (718 entries, 27 categories)
- [`Levels.swift`](file:///Users/caesargrey/Projects/app-four-llama/Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift) — Authoritative signal enums
- [`NLSummarizationService.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/Services/NLSummarizationService.swift) — Legacy implementation (being replaced)
- [`ProcessingViewModel.swift`](file:///Users/caesargrey/Projects/app-four-llama/app-four/ViewModels/ProcessingViewModel.swift) — Downstream caller (unchanged)
- [MLX-Swift](https://github.com/ml-explore/mlx-swift) — Inference framework
- [Llama 3.2 1B](https://huggingface.co/meta-llama/Llama-3.2-1B-Instruct) — Model weights
- [Apple `os_proc_available_memory()`](https://developer.apple.com/documentation/os/os_proc_available_memory()) — Memory check API
