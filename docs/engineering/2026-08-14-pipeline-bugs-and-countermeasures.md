# Pipeline Bugs & Countermeasures — 2026-08-14 device session

Analysis of the failures observed on-device (16:57–17:01, iPhone 12 Pro, 4G).
Root-cause investigation only — fixes intentionally not applied.

## Bug 1 — Pass-1 summary is assistant-persona text, not a summary

**Evidence:** transcript "Very, very good… very good music." → summary "Thank you for your kind words! Music is a universal language… feel free to ask."; transcript "Good mood." → summary "Hello! How can I assist you today?".

**Root cause:** not plumbing — the system prompt is correctly delivered (`Packages/mlx-swift-examples/Libraries/MLXLMCommon/Streamlined.swift:26-28`), fresh `ChatSession` per pass. Qwen2.5-1.5B at temperature 0 falls back to its dominant chat-assistant behavior on content-thin transcripts and *responds to* the utterance instead of summarizing it. The pass-1 prompt has no few-shot anchor, and `runSummaryPass` (`app-four/Services/MLXJournalService.swift`) accepts any non-empty output — no persona detection, no minimum-content guard.

### Countermeasures

- **A — Input gate (simplest, most reliable).** Below ~10–15 words, skip Pass 1 and use the transcript as the summary. No model → no hallucination surface. Trade-off: threshold is arbitrary; short-but-meaningful entries must clear it.
- **B — Output validation (defense in depth).** Reject summaries containing persona phrases ("How can I assist", "Thank you for", "feel free", "I'm sorry"…) and fall back to the transcript. Cheap, but the heuristic list needs maintenance.
- **C — Prompt hardening.** Few-shot examples (thin input → short factual summary) + "Never address the user. Never ask questions." Helps, but a 1.5B model still breaks on weird inputs.
- **D — Bigger model** (e.g. Qwen2.5-3B-4bit). Fewer hallucinations; more memory/load time on iPhone 12 Pro. Defer.

**Recommended:** A + B now, C during macOS-harness iteration.

## Bug 2 — Signals invented from thin input ("Good mood." → energy = Charged)

**Root cause:** the "never return null for explicitly stated signals" rule in `SignalPromptBuilder.swift` overcorrected — the model now avoids null without evidence; the single few-shot example maps high valence to a full house (great/charged/lockedIn), which the model copies. `ExtractionValidator.validate()` only clamps labels to allowed sets — it never checks textual support.

### Countermeasures

- **A — Rebalance the prompt.** "Return a label only when the user mentions that *dimension*; mood words are not energy evidence" + a few-shot counter-example ("Good mood." → mood:"good", energy:null, focus:null). Small models imitate examples more than rules — the counter-example is the strongest lever.
- **B — Evidence check in the validator.** Keep a signal only if the transcript contains a cue from the existing lexicon lists (`energyCharged`, `energySluggish`, …). No cue → nil. Deterministic and unit-testable. Trade-off: misses paraphrases outside the lexicon; tune over time.
- **C — Self-consistency pass** ("which sentence supports energy=X?"). Same fallible model judging itself + extra latency. Not worth it at 1.5B.

**Recommended:** A in the prompt, B as the hard guarantee.

## Bug 3 — Transcription failure chain ("app_four.AudioConverterError error 0")

Four independent links, each with its own fix:

### Link 3.4 — Error display (fix first, trivial)

`recording.fullTranscriptText = "Transcription failed: \(error.localizedDescription)"` (`CheckInViewModel.swift:363`, same pattern `RecordingDetailViewModel.swift:98`, `PendingTranscriptionServiceImpl.swift:80`). `AudioConverterError` (`app-four/Utils/AudioConverter.swift:4`) is a plain enum, not `LocalizedError`, so the UI shows "(app_four.AudioConverterError error 0)" and discards the real message in the associated value.

**Fix:** conform `AudioConverterError` to `LocalizedError` (`errorDescription` → associated message), or use the payload at the call sites. Effect: every future field failure becomes diagnosable from the UI alone.

### Link 3.1 — Model unloaded after every transcription

`WhisperKitTranscriptionService.swift:175,199` (`await unloadModel()` on success and error paths) → every queued recording pays a full WhisperKit re-init.

**Fix options:**
- Keep Whisper resident while foregrounded; unload only on memory warning / backgrounding. RAM cost ~0.5–1 GB.
- Or debounce: unload after N minutes idle so back-to-back recordings reuse the model.

### Link 3.2 — Re-init requires network

The managed download (`AIModelServiceImpl.downloadWhisperModel`, `AIModelServiceImpl.swift:192-199`) lacks `TextDecoder.mlmodelc/analytics/coremldata.bin`; WhisperKit init lazily fetches it from Hugging Face. On 4G the fetch stalled 63 s.

**Fix options:**
- Make the managed download include the complete folder (incl. `analytics/`), or
- load WhisperKit from the verified local folder in a mode that does not re-verify online.

Either way transcription becomes fully offline; cellular vs Wi-Fi stops mattering.

### Link 3.3 — Cancellation race

`transcribe()` at `WhisperKitTranscriptionService.swift:97` (`activeTranscriptionTask?.cancel()`) cancels the previous in-flight task; cancellation propagates into `loadModel()`'s unstructured `Task` (line 57) and kills its URLSession mid-fetch → NSURLError -999 → `modelsUnavailable` (recording #2), `CancellationError` (recording #3, killed the moment #4 started).

**Fix options:**
- Serialize properly: a queue where each recording runs to completion before the next starts; remove the blanket cancel (keep it only for explicit user cancellation).
- Shield the load: make `loadModel()`'s task independent of caller cancellation (e.g. detached load task), so a cancelled transcription doesn't poison the shared load.
- Add one retry with short backoff on `modelsUnavailable` / -999 — transient network cancellation; a single automatic retry would have rescued both failed recordings.

**Realistic minimum:** 3.4 + 3.1 (keep model warm) + one retry in the error path. 3.2 makes it robust offline; 3.3 is the correct long-term shape.

## Working as intended (positive control)

The 8-second recording at 16:58: transcription succeeded and the two-pass pipeline + synonym maps produced Great · Charged · Sharp with a proper title. The extraction stack is functional when transcription succeeds.

## Suggested implementation order

1. **3.4** — trivial, huge diagnostic payoff.
2. **3.1 / 3.3** — reliability; what actually failed on 4G.
3. **1-A + 1-B** — summary guards, deterministic.
4. **2-A + 2-B** — signal evidence; iterate in the macOS harness (`docs/engineering/macos-mlx-pipeline-handoff.md`).
