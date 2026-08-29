<!-- Created: 2026-08-17 19:21 (WEST) · Updated: 2026-08-17 19:45 (WEST) -->

# MLX On-Device Journal Pipeline: Tuning & Sync Runbook

This document defines the ownership rules, versioning conventions, porting runbook, and audit registry for the MLX on-device LLM journal extraction pipeline (`Qwen2.5-1.5B-Instruct-4bit`).

---

## 1. Ownership & Synchronization Rules

The on-device journal extraction pipeline is developed and tuned in the macOS harness (`/Users/caesargrey/Projects/app-four-macos`) and synchronized to the iOS app (`/Users/caesargrey/Projects/app-four-llama`).

* **Source of Truth (Owner):** The macOS repository owns all 10 tuning files. **iOS destination files must NEVER be edited directly.**
* **Sync Mechanism:** All transfers from macOS to iOS must be performed mechanically via `scripts/sync-tuning.sh`.
* **CI Parity Verification:** Run `scripts/sync-tuning.sh --check` to detect any unauthorized drift between macOS source and iOS destination files.

### The 10-File Payload Mapping

| macOS Source (`Sources/SquirlJournal/`) | iOS Destination (`app-four/`) |
| :--- | :--- |
| `Resources/Prompts.yaml` | `Resources/Prompts.yaml` |
| `Resources/lexicon.json` | `Resources/lexicon.json` |
| `PromptLoader.swift` | `Services/PromptLoader.swift` |
| `SummaryPromptBuilder.swift` | `Services/SummaryPromptBuilder.swift` |
| `SignalPromptBuilder.swift` | `Services/SignalPromptBuilder.swift` |
| `NoteExtraction/ExtractionValidator.swift` | `Services/NoteExtraction/ExtractionValidator.swift` |
| `NoteExtraction/UnifiedExtraction.swift` | `Services/NoteExtraction/UnifiedExtraction.swift` |
| `NoteExtraction/Lexicon.swift` | `Services/NoteExtraction/Lexicon.swift` |
| `NoteExtraction/LexiconData.swift` | `Services/NoteExtraction/LexiconData.swift` |
| `NoteExtraction/NoteExtraction.swift` | `Services/NoteExtraction/NoteExtraction.swift` |

### The 3 Allowed iOS Platform Adaptations

The sync script automatically applies and verifies these three adaptations (and no others):

1. **Bundle Resolution:** `Bundle.module.url(...)` $\rightarrow$ `Bundle.main.url(...)` in `PromptLoader.swift` and `LexiconData.swift`.
2. **Logging Subsystem:**
   * `print("ExtractionValidator:` $\rightarrow$ `AppLogger.log("ExtractionValidator:` in `ExtractionValidator.swift`
   * `print("PromptLoader warning:` $\rightarrow$ `AppLogger.log("PromptLoader warning:` in `PromptLoader.swift`
   * `prints warning` / `prints a warning` $\rightarrow$ `logs a warning` in `PromptLoader.swift` doc-comments.
3. **Module Imports:** In `NoteExtraction.swift`, the line `import SquirlSignals` is removed (iOS imports symbols globally via `@_exported import SquirlSignals` in `app-four/App/SignalsReexport.swift`).

---

## 2. Version Stamp Convention

Every tuning iteration must be stamped on the very first line of `Sources/SquirlJournal/Resources/Prompts.yaml`:

```yaml
# tuning-version: YYYY-MM-DD-suffix
```

* **Format:** ISO 8601 calendar date (`YYYY-MM-DD`) followed by a single-letter lowercase suffix (`-a`, `-b`, `-c`, etc.) indicating same-day iterations.
* **Integrity:** The stamp is preserved during sync and verified by `scripts/sync-tuning.sh --check`.

---

## 3. Port & Verification Runbook

Follow these steps sequentially for any tuning iteration:

1. **Tune & Validate on macOS:**
   * Edit prompts in `Prompts.yaml` and logic in `ExtractionValidator.swift`.
   * Run `swift test` in `app-four-macos`. **All 44 unit tests must be GREEN.**
   * Run `.build/debug/JournalCLI eval` (or targeted filter) to confirm benchmark progression.
2. **Bump Version Stamp & Commit (macOS):**
   * Update the first line of `Prompts.yaml` (e.g. `# tuning-version: 2026-08-17-c`).
   * Commit in macOS repo: `git commit -am "chore: bump tuning-version to YYYY-MM-DD-suffix"`.
3. **Sync to iOS Repo:**
   * In `app-four-llama`, run:
     ```bash
     ./scripts/sync-tuning.sh
     ```
   * Review `git diff` on iOS to ensure only the expected files and adaptations changed.
4. **Verify iOS Simulator Unit Tests:**
   * Execute the targeted 44-test suite on the iOS Simulator:
     ```bash
     xcodebuild test \
       -project app-four.xcodeproj \
       -scheme app-four \
       -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
       -only-testing:app-fourTests/ExtractionValidatorTests \
       -only-testing:app-fourTests/ParseExtractionTests \
       -only-testing:app-fourTests/SummaryPromptBuilderTests \
       -only-testing:app-fourTests/SignalPromptBuilderTests
     ```
   * All 44 tests must pass cleanly.
5. **Physical Device Benchmark & Gate (iPhone):**
   * Ensure the connected physical device (iPhone) is unlocked with model weights installed.
   * Run the physical device evaluation test plan:
     ```bash
     xcodebuild test \
       -project app-four.xcodeproj \
       -scheme app-four \
       -testPlan app-four-mlx-eval \
       -destination 'platform=iOS,id=00008101-000849EE0EB9003A' \
       -only-testing:app-fourTests/MLXExtractionEvalTests
     ```
   * **Hard Gate:** Must remain **8/8 (100.0%) PASS**.
   * **Floor Calibration (Raise-Never-Lower Rule):** The thresholds in `MLXEvalFloors` (`app-fourTests/Eval/MLXExtractionEvalTests.swift`) are strict ratchet floors:
     * If a new tuning iteration improves a metric, update the floor to $\text{observed} - 0.02$ and log it.
     * If any metric drops below the existing floor, **STOP IMMEDIATELY and report to the user — NEVER silently lower a floor.**
6. **Audit & Log:**
   * Record the new iteration entry in the [Tuning Audit Registry](#5-tuning-audit-registry) below.

---

## 4. Holdout Golden Set Discipline

* **Holdout Set Integrity:** `app-fourTests/Eval/MLXEvalSet.swift` is a strict, held-out evaluation dataset.
* **No Direct Prompt Overfitting:** Prompts, regexes, and validator rules must NEVER be tuned directly against `MLXEvalSet.swift`.
* **Case Additions:** New test cases may only be appended from real-world telemetry failures or clinical edge cases observed in practice.

---

## 5. Tuning Audit Registry

| Version Stamp | Description & Tuning Payload Summary | Benchmark & Device Gate Results |
| :--- | :--- | :--- |
| **`2026-08-17-a`** | Initial port (15-rule validator, ASR med aliases, supplement lexicon) | Device hard-gate: 7/8, meds P/R: 0.789 / 0.882 |
| **`2026-08-17-b`** | Stop-words `+medicines/none/med`; mood synonym `+positive→great` | Device hard-gate: 8/8, meds P/R: 0.941 / 0.941, mood R: 0.857 |
| **`2026-08-17-c`** | Structured field extraction rules (11 activity categories, topic allowlist, sleep duration clamping, side effect scanning, energy vitality suppression) | **Device (iPhone 12 Pro):** hard gate 8/8 (after crash-recovery label update for the new positive-now energy rule); meds P/R **1.000/1.000**, topics R **1.000**, activities R **0.857**, sideFx R **0.857**, sleepHours P **0.778**; energy P 0.333 (over-fire halved). Floors recalibrated: all raised to observed−0.02 except activities-P and sideFx-P — deliberate owner-approved resets (previously vacuous ~1.0 when nothing fired). Latency avg 13.0 s, p95 19.5 s. |
