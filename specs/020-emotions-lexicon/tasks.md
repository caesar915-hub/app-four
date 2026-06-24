---
description: "Task list for Emotions Lexicon (replace Feelings)"
---

# Tasks: Emotions Lexicon (replace "Feelings")

**Input**: Design documents from `/specs/020-emotions-lexicon/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/emotions-lexicon.md](contracts/emotions-lexicon.md)

**Tests**: Test-first is MANDATORY for logic (SwiftData `@Model`, `Services/`, `@Observable` view-models, NLP extraction) per Constitution **Principle X** — RED → GREEN → refactor with **Swift Testing** (`@Test`/`#expect`). SwiftUI **views are EXEMPT** (build + on-simulator run). The 20 emotions are fixed in [contracts/emotions-lexicon.md](contracts/emotions-lexicon.md).

**Note on atomicity**: A symbol rename must compile as a unit, so Phase 2 (the rename spine + vocabulary swap) lands as one connected change. US1/US2/US3 then layer UI, detection/eval, and robustness on top.

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: Setup

- [X] T001 Record the current `feelings` precision/recall floors from [app-fourTests/Eval/ExtractionEvalTests.swift](../../app-fourTests/Eval/ExtractionEvalTests.swift) (`EvalFloors`) as the baseline to compare against post-change (capture in the implementation commit message; no code change).

---

## Phase 2: Foundational — rename spine + vocabulary swap (BLOCKS US1–US3)

**⚠️ CRITICAL**: Everything depends on the renamed symbols + new vocabulary existing and compiling.

### Tests (test-first · RED — MANDATORY) ⚠️

- [X] T002 [P] In [app-fourTests/Services/LexiconDataTests.swift](../../app-fourTests/Services/LexiconDataTests.swift), write/adjust a test asserting `Lexicon.defaultEmotions` equals the 20 curated words (per contract) and contains **none** of the dropped energy/mood words (`exhausted`, `restless`, `indifferent`, `curious`, `motivated`). Run → confirm FAILS (symbol `defaultEmotions` does not exist yet).
- [X] T003 [P] In [app-fourTests/Models/RecordingApplySummaryTests.swift](../../app-fourTests/Models/RecordingApplySummaryTests.swift), adjust the test to assert `applySummary` writes `emotionsJSON` and `decodedEmotions` round-trips `result.emotions`. Run → confirm FAILS.
- [X] T004 [P] In [app-fourTests/ViewModels/ProcessingViewModelTests.swift](../../app-fourTests/ViewModels/ProcessingViewModelTests.swift), assert a `NoteExtraction` round-trips through Codable using the `emotions` key. Run → confirm FAILS.

### Implementation (lands together to compile · GREEN)

- [X] T005 [NoteExtraction.swift](../../app-four/Services/NoteExtraction/NoteExtraction.swift): rename `feelings`→`emotions` (property, init param, assignment, `CodingKeys`, the `c.decode(...forKey: .emotions)` line); delete the now-redundant `// specific emotions` comment.
- [X] T006 [Recording.swift](../../app-four/Models/Recording.swift): `feelingsJSON`→`emotionsJSON` (stored, keep `String?`), init param + assignment, `decodedFeelings`→`decodedEmotions`, and the `applySummary` writes/clears (`extraction.emotions = []`, `result.emotions`, write `emotionsJSON`).
- [X] T007 [RecordingTag.swift](../../app-four/Models/RecordingTag.swift): `TagCategory.feelings`→`.emotions`.
- [X] T008 [Lexicon.swift](../../app-four/Services/NoteExtraction/Lexicon.swift): `feelings`/`defaultFeelings`→`emotions`/`defaultEmotions`; **replace** `defaultEmotions` body with the 20 (contract order); update the `// MARK: - Emotions` and curated-subset comment. Do **not** touch the mood/energy/focus cue-phrase tuples that contain "feeling".
- [X] T009 [LexiconData.swift](../../app-four/Services/NoteExtraction/LexiconData.swift): `feelings`/`extraFeelings`→`emotions`/`extraEmotions` (properties, init param, merge).
- [X] T010 [Resources/lexicon.json](../../app-four/Resources/lexicon.json): rename top-level `"feelings"` key → `"emotions"` and **replace its array with the 20** (wipe the old ~60). Leave every `"feeling …"` cue phrase inside the mood/energy/focus arrays untouched (FR-005).
- [X] T011 [P] [Protocols.swift](../../app-four/Services/Protocols.swift): `SummaryResult.feelings`→`.emotions`.
- [X] T012 [NLSummarizationService.swift](../../app-four/Services/NLSummarizationService.swift): map `emotions: extraction.emotions`.
- [X] T013 [NLNoteExtractor.swift](../../app-four/Services/NoteExtraction/NLNoteExtractor.swift): `detectedFeelings`→`detectedEmotions`, `cues.feelings`→`.emotions`, `makeList(lexicon.emotions)`, `extraction.emotions = detectedEmotions`, and the scoring `hasAny(cues.emotions)`.
- [X] T014 [PersonalLexiconBuilder.swift](../../app-four/Services/NoteExtraction/PersonalLexiconBuilder.swift): `feelings`/`seenFeelings`/`feelingsCategory`→`emotions`/`seenEmotions`/`emotionsCategory`; `PersonalLexicon(emotions:)`; uses `TagCategory.emotions.rawValue`.
- [X] T015 [P] [ExportService.swift](../../app-four/Services/ExportService.swift): export DTO `feelingsJSON`→`emotionsJSON` (field + mapping).
- [X] T016 [P] [MockDataGenerator.swift](../../app-four/Utils/MockDataGenerator.swift): `feelingPool`→`emotionPool` seeded with the 20 (capitalized for display); `recording.emotionsJSON`.
- [X] T017 [P] [CueMatcher.swift](../../app-four/Services/NoteExtraction/CueMatcher.swift): update the category-naming comments ("feeling/state cues"→"emotion/state cues"). Comment-only, no behavior.

**Checkpoint**: project compiles; T002–T004 GREEN.

---

## Phase 3: User Story 1 — "Emotions" surfaces in the UI (Priority: P1) 🎯 MVP

**Goal**: Everywhere a user reads "Feelings" they now read "Emotions", choosing from the curated 20.

**Independent Test**: Open extraction-review → section "Emotions", 20 chips, nudge "Any strong emotions?".

### Tests (test-first · RED) ⚠️

- [X] T018 [P] [US1] In [app-fourTests/ViewModels/CheckInViewModelTests.swift](../../app-fourTests/ViewModels/CheckInViewModelTests.swift), assert the emotion nudge `question == "Any strong emotions?"`. Run → FAILS.
- [X] T019 [P] [US1] In [app-fourTests/ViewModels/ExtractionReviewViewModelTests.swift](../../app-fourTests/ViewModels/ExtractionReviewViewModelTests.swift), assert `toggleEmotion(_:)` mutates the `emotions` set and emitted tags carry `category: .emotions`. Run → FAILS.

### Implementation

- [X] T020 [US1] [ExtractionReviewViewModel.swift](../../app-four/ViewModels/ExtractionReviewViewModel.swift): `feelings: Set<String>`→`emotions`, `toggleFeeling`→`toggleEmotion`, `EditedField.feelings`→`.emotions`, tag `category: .emotions`, `decodedEmotions`.
- [X] T021 [US1] [ExtractionReviewView.swift](../../app-four/Views/ExtractionReviewView.swift): `feelingGroups`→`emotionGroups`, `feelingsField`→`emotionsField`, header `numberedHeader("07", "Emotions")`, the loop var + accessibility label; chips bind to the 20.
- [X] T022 [P] [US1] [CheckInViewModel.swift](../../app-four/ViewModels/CheckInViewModel.swift): nudge copy `"Any strong feelings?"`→`"Any strong emotions?"`.
- [X] T023 [P] [US1] [ADHDSummarySection.swift](../../app-four/Views/Components/ADHDSummarySection.swift) + [Recording+MoodDisplay.swift](../../app-four/Models/Recording+MoodDisplay.swift): `decodedEmotions`, DisplayTag id `"emotion-\(i)"`, header/loop comments.

**Checkpoint**: build + simulator — header "Emotions", 20 chips, nudge copy (views exempt; verified on sim).

---

## Phase 4: User Story 2 — detection + eval floors hold (Priority: P2)

**Goal**: New emotions detected; dropped words no longer emitted; mood cues intact; eval floors not regressed.

**Independent Test**: Run the eval; `emotions` precision/recall ≥ baseline; spot-check transcripts.

### Tests (test-first · RED) ⚠️

- [X] T024 [P] [US2] In [app-fourTests/Services/NLNoteExtractorMatchingTests.swift](../../app-fourTests/Services/NLNoteExtractorMatchingTests.swift), assert "grateful"/"proud" → emotions, a new word (e.g. "irritated") matches, and "exhausted" is **not** emitted as an emotion. Run → FAILS.
- [X] T025 [P] [US2] In [app-fourTests/Services/NLNoteExtractorMoodTests.swift](../../app-fourTests/Services/NLNoteExtractorMoodTests.swift), assert "I'm feeling down" still drives **mood** detection and leaves `emotions` empty (guards FR-005). Run → FAILS (or adjust existing symbol names).

### Implementation

- [X] T026 [US2] [EvalSet.swift](../../app-fourTests/Eval/EvalSet.swift): rename the `feelings:` expected field → `emotions:`; re-point samples per [contract map](contracts/emotions-lexicon.md#eval-re-pointing-map-old-expected-word--action) (`overwhelmed`→`anxious`; drop `indifferent`/`curious`/`restless`/`recharged`/`exhausted`/`motivated` expectations); ensure every remaining emotion expectation ⊆ the 20.
- [X] T027 [US2] [ExtractionEvalTests.swift](../../app-fourTests/Eval/ExtractionEvalTests.swift): rename the `feelings` category + `EvalFloors.feelings`→`.emotions` (keep the numeric floor unless re-pointing legitimately raises it).
- [X] T028 [P] [US2] [EvalMetrics.swift](../../app-fourTests/Eval/EvalMetrics.swift): update the set-valued-category comment/reference `feelings`→`emotions`.
- [X] T029 [P] [US2] [PersonalLexiconTests.swift](../../app-fourTests/Services/PersonalLexiconTests.swift) + [LexiconDataTests.swift](../../app-fourTests/Services/LexiconDataTests.swift) + [Mocks/MockSummarizationService.swift](../../app-fourTests/Mocks/MockSummarizationService.swift) + [ExtractionReviewViewModelTests.swift](../../app-fourTests/ViewModels/ExtractionReviewViewModelTests.swift): update remaining `feelings` identifiers/assertions → `emotions`.
- [X] T030 [US2] Run the extraction eval (`ExtractionEvalTests`); confirm `emotions` precision/recall ≥ the T001 baseline (Constitution VII). If regressed, fix by adding **whole-token** surface forms in `lexicon.json` — never by lowering floors or substring matching.

**Checkpoint**: eval green; floors held or improved.

---

## Phase 5: User Story 3 — clean wipe-and-rebuild on update (Priority: P3)

**Goal**: Launch over a prior `feelings`-schema store recovers without crashing.

- [X] T031 [US3] Build + launch on a simulator carrying an old-schema store (seed with the prior build, or trigger the conflict path in [AppModelContainer.swift](../../app-four/App/AppModelContainer.swift)); confirm wipe-and-rebuild, no crash, Emotions category present (AppModelContainer code is unchanged — this verifies the accepted IX path).

---

## Phase 6: Polish & Cross-Cutting

- [X] T032 [P] Update [DESIGN.md](../../DESIGN.md): change the "Feelings" references (chip/category language) to "Emotions"; note the Mood-Meter quadrant basis.
- [X] T033 [P] Add a [docs/DEVLOG.md](../../docs/DEVLOG.md) entry (WHY: How We Feel / Mood-Meter scholarly basis, 20-word curation, energy/mood exclusions, wipe accepted) and move the item in [docs/BACKLOG.md](../../docs/BACKLOG.md) to 🔨 In code (branch/PR).
- [X] T034 Codebase sweep `rg -n 'feeling' app-four/`: confirm **only** intentional mood cue-phrases + tense markers remain — zero category identifiers named `feeling(s)` (SC-006).
- [X] T035 Full build + complete Swift Testing suite green (Constitution II); run the [quickstart.md](quickstart.md) scenarios.

---

## Dependencies & Execution Order

- **Phase 1 (Setup)**: immediate.
- **Phase 2 (Foundational)**: the atomic rename + vocabulary; **blocks** US1–US3. T002–T004 (RED) precede T005–T017 (GREEN). T005–T010, T013, T014 are tightly coupled (same compile unit); T011, T015, T016, T017 are `[P]` (independent files).
- **Phase 3 (US1)**: after Phase 2. Tests T018–T019 before impl T020–T023.
- **Phase 4 (US2)**: after Phase 2 (independent of US1). Tests T024–T025 before impl T026–T030.
- **Phase 5 (US3)**: after Phase 2; validation only.
- **Phase 6 (Polish)**: after US1+US2 (US3 optional for MVP).

### Parallel Opportunities

- T002, T003, T004 (different test files) in parallel.
- Within Phase 2 impl: T011/T015/T016/T017 in parallel after the core T005–T010 land.
- US1 and US2 phases can proceed in parallel once Phase 2 compiles.

## Implementation Strategy

**MVP = Phase 1 + Phase 2 + Phase 3 (US1)** — the category is renamed and shows the curated 20. **US2 is required before merge** (Constitution VII gate: eval must run and not regress). US3 is a launch-robustness check. Polish closes docs + the SC-006 sweep.

## Notes

- Verify each RED test fails before implementing (Principle X).
- Commit after each logical group (e.g. "T005–T010 rename spine", "T026–T030 eval re-point").
- The only surviving "feeling" tokens after T034 are the mood cue-phrases — that is by design (FR-005), not an oversight.
