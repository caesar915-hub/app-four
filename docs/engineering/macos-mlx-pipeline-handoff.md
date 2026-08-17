# Handoff: macOS MLX Pipeline Development (Approach B — shared package)

**Target working directory:** `/Users/caesargrey/Projects/app-four-macos`
**Source of truth for pipeline code:** `/Users/caesargrey/Projects/app-four-llama` (branch `feat/043-mlx-journal-service`)

## What exists today (verified)

The iOS app runs a **two-pass on-device LLM pipeline** (Qwen2.5-1.5B-Instruct-4bit via MLX Swift):

- Pass 1 — holistic 1–2 sentence narrative summary (`SummaryPromptBuilder`).
- Pass 2 — strict JSON extraction of present-moment signals (`SignalPromptBuilder`): mood/energy/focus/sleepHours/sleepQuality/medications/emotions/activities/topics/lexicon/sideEffects. Temporal rule: current state wins over past states. One correction retry on JSON parse failure.
- Validation/clamping: `ExtractionValidator` — 3-stage JSON recovery, case-insensitive enum clamping, **synonym maps** (energy "high"→charged, focus "good"→sharp, etc.), topic derivation.
- Result assembly: `SummaryResult` → `Recording.applySummary` (SwiftData) — out of scope for macOS work.

### Pipeline files (all macOS-portable: Foundation / NaturalLanguage / SquirlSignals only)

```
app-four/Services/MLXJournalService.swift
app-four/Services/SummaryPromptBuilder.swift
app-four/Services/SignalPromptBuilder.swift
app-four/Services/NoteExtraction/ExtractionValidator.swift
app-four/Services/NoteExtraction/UnifiedExtraction.swift
app-four/Services/NoteExtraction/NoteExtraction.swift   (NoteExtraction, MedEvent, SleepEvent)
app-four/Services/NoteExtraction/Lexicon.swift
app-four/Services/NoteExtraction/LexiconData.swift      (LexiconLoader — reads Bundle.main/lexicon.json)
app-four/Resources/lexicon.json
app-four/Services/Protocols.swift                       (only SummaryResult, SummarizationService, SummarizationError needed)
Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift  (Mood/Energy/Focus/Sleep enums — the ONLY SquirlSignals file)
```

### App-only symbols the pipeline references (need injection or shims on macOS)

- `AIModelServiceImpl.findLLMModelDirectory(in:)` (`app-four/Services/AIModelServiceImpl.swift:217`) — model dir discovery: checks `<base>/models/<repoID>/` for config.json + tokenizer.json + *.safetensors, repo root first then subdirs.
- `ModelConstants.llmHubRepoID = "mlx-community/Qwen2.5-1.5B-Instruct-4bit"`, `ModelConstants.llmDownloadBase` (`app-four/Utils/Constants.swift:22`).
- `AppLogger.log(_:)` — replace with `print`.
- `MLXJournalService.ModelHolder` uses `os_proc_available_memory()` — fine on macOS.

### Dependencies (all local checkouts in app-four-llama/Packages/)

- `Packages/mlx-swift-examples` — SwiftPM name **`mlx-libraries`**, products `MLXLLM`, `MLXLMCommon` (pulls remote `mlx-swift` → `MLX`, `MLXNN`, `MLXRandom`).
- `Packages/swift-transformers` — products `Hub` (HubApi snapshot download), `Transformers`.
- `Packages/SquirlSignals` — product `SquirlSignals`; declares `platforms: [.iOS("26.0")]` but sources are pure Foundation → builds for macOS (SwiftPM default min version).

## Assignment: Approach B, developed in app-four-macos

Build a macOS dev harness around a **shared SwiftPM package** so pipeline iteration happens on the Mac with a terminal interface, structured as the future shared package (not throwaway scripts):

1. Create `/Users/caesargrey/Projects/app-four-macos` as a SwiftPM package (or small Xcode project) containing:
   - `Packages/SquirlJournal` — library target holding copies of the 8 pipeline files + `lexicon.json` as a package resource (`Bundle.module`). Adjust `LexiconLoader` to try `Bundle.module` first. Make `MLXJournalService` take an injected model-directory provider (`@Sendable () -> URL?`) instead of calling `AIModelServiceImpl` directly; move `SummaryResult`/`SummarizationService`/`SummarizationError` in.
   - `JournalCLI` — executable target: `journalcli "<transcript>"` | `--file <path>` | stdin; flags `--verbose` (raw pass outputs), `--model-dir`, `--skip-download`. First run downloads the model via `HubApi.snapshot` (~740 MB, same `models/<repoID>/` layout). Prints summary, validated signals, medications, per-pass latency. Exit codes 0/1/2.
2. Reference MLX dependencies by local path (`../app-four-llama/Packages/...`) so both repos build identical dependency code.
3. Port the relevant unit tests: `app-fourTests/PromptBuilderTests.swift`, `app-fourTests/ExtractionValidatorTests.swift`, `app-fourTests/ParseExtractionTests.swift` (38+ tests, all passing as of 2026-08-14).
4. Verification: `swift build` green; `journalcli "I feel great today, took my Vyvanse, slept terribly"` → mood=great, medications=[Vyvanse], sleepQuality=restless; temporal case `"I was exhausted and sad all morning, but right now I feel energized and good"` → mood=good, energy=alert/charged (NOT low/sluggish).
5. Keep the file layout mirroring `app-four/Services/…` so changes can be diffed/copied back to the iOS repo cleanly. **The iOS repo remains the shipping source of truth; improvements must be backported deliberately, not assumed in sync.**

## Explicitly out of scope

- No iOS app changes, no pbxproj edits in app-four-llama.
- No Whisper/audio in the CLI (transcript text only; WhisperKit macOS can follow the existing `WhisperCLI/` pattern later).
- No model swap without measuring against the current Qwen2.5-1.5B baseline.
