# Quickstart: validate the Emotions Lexicon

Prerequisites: Xcode (XcodeBuildMCP), iOS 26 simulator, the `feat/rename-feelings-to-emotions` branch.

## 1. Build + full test suite (Constitution II)

Build the `app-four` scheme for an iOS 26 simulator and run all tests. Expected: build succeeds, all Swift Testing suites pass.

## 2. Extraction eval — floors not regressed (Constitution VII, SC-004)

Run the extraction eval suite (`app-fourTests/Eval/ExtractionEvalTests.swift`). Expected:
- The `emotions` category (renamed from `feelings`) reports precision/recall **≥** its tracked floor.
- Samples that asserted dropped words (`indifferent`, `curious`, `restless`, `exhausted`, `recharged`, `motivated`, `overwhelmed`) are re-pointed per [contracts/emotions-lexicon.md](contracts/emotions-lexicon.md#eval-re-pointing-map) so no expectation references a non-lexicon word.

## 3. Detection spot-checks (US2)

Via unit tests on `NLNoteExtractor`:
- "I felt **grateful** and **proud**" → emotions `{grateful, proud}`.
- "I was **exhausted**" → emotions **empty** (energy axis owns it).
- "I'm **feeling down**" → mood detection fires on the `feeling down` cue; emotions unaffected (FR-005).
- A custom user emotion tag still matches via the personal overlay (FR-007).

## 4. UI check on simulator (US1, SC-001, SC-006)

Open a check-in's extraction-review screen:
- Section header reads **"Emotions"** (formerly "07 Feelings").
- The selectable chips are exactly the **20** curated emotions.
- The composer nudge asks **"Any strong emotions?"**.
- No screen shows "Feelings" as a category label.

## 5. Clean update / wipe-and-rebuild (US3, SC-005)

Launch over a store created by the prior `feelings` schema (e.g. a simulator with old data, or delete-derived). Expected: app starts without crashing, presents the Emotions category; prior feelings data is gone (accepted, Constitution IX).

## 6. Codebase sweep (SC-006)

`rg -n 'feeling' app-four/` returns **only** the intentional mood cue-phrases (`feeling down`, `feeling empty`, `feeling seen`, tense markers in `TenseClassifier.swift`) — zero category *identifiers* named `feeling(s)`.
