# Implementation Plan: Emotions Lexicon (replace "Feelings")

**Branch**: `feat/rename-feelings-to-emotions` | **Date**: 2026-06-24 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/020-emotions-lexicon/spec.md`

## Summary

Replace the check-in **Feelings** category with an **Emotions** category in two coordinated moves: (1) a pure terminology rename of every `feelings` *identifier* — the persisted `Recording` column, `TagCategory` case, `NoteExtraction` property + Codable key, the `lexicon.json` top-level key, extractor/view-model/view identifiers, the UI section header, the nudge copy, and all tests; and (2) a **content swap** of the vocabulary — wipe the ~60-word feelings list and install a curated set of **exactly 20 emotions** (5 per Mood-Meter valence×energy quadrant) sourced from the How We Feel model, deliberately excluding states the app already owns on its mood/energy/focus axes. Mood cue-phrases that literally contain "feeling" (`feeling down`, `feeling seen`) are **not** touched. Schema change is recovered by the existing wipe-and-rebuild path (Constitution IX); no migration. The extraction eval set is re-pointed to the new vocabulary and must not regress its floors (Constitution VII).

## Technical Context

**Language/Version**: Swift 6 (strict concurrency enabled)

**Primary Dependencies**: SwiftUI (iOS 26+), SwiftData, Apple `NaturalLanguage` (`NLNoteExtractor`); WhisperKit/transcription unaffected

**Storage**: SwiftData (`Recording` `@Model`); bundled `Resources/lexicon.json` is the extraction vocabulary (data, not code, per Constitution VII)

**Testing**: Swift Testing (`@Test`/`#expect`) for unit/integration; the extraction eval harness (`app-fourTests/Eval/*`) with tracked precision/recall floors

**Target Platform**: iOS 26+ (primary), iPadOS (secondary)

**Project Type**: mobile-app (single iOS target `app-four`, display name *Squirl*)

**Performance Goals**: no change — extraction stays deterministic and off the main actor; renaming/word-swap is allocation-neutral

**Constraints**: on-device + offline only (Constitution VI); exactly 20 emotions, quadrant-balanced (SC-002); emotions must not duplicate mood/energy/focus states (SC-003); emotions eval floors must hold or improve (SC-004); the only surviving "feeling" tokens are intentional mood cue-phrases (SC-006)

**Scale/Scope**: ~26 app-source identifier sites + ~13 test files + the `lexicon.json` key & word-list + `Lexicon.swift` `defaultEmotions`; one revertable feature on one branch

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.* (v1.2.0)

- [x] **I. SwiftUI-First** — UI change is a label ("07 Emotions") and the existing chip list; **no new view**, so the HTML-mockup-first rule does not apply. Existing SwiftUI/modern APIs untouched. **PASS**
- [x] **II. Test-Build-Ship** — plan ends in a full build + `swift test` (incl. eval) on the branch before done. **PASS**
- [x] **III. Correctness Over Speed** — no compat shim is added precisely *because* the wipe is accepted (IX); old vocabulary is deleted, not left as dead data. **PASS**
- [x] **IV. Minimal Surface** — no new abstraction, flag, or service; a rename + a data-list swap. **PASS**
- [x] **V. Solo Git Discipline** — one feature on `feat/rename-feelings-to-emotions`, `/code-review` before merge, `main` stays releasable. **PASS**
- [x] **VI. On-Device Privacy** — no data-flow change; extraction stays on-device; no logging of content added. **PASS**
- [x] **VII. Deterministic, Measured Extraction** — matching stays whole-token/contiguous, off-main, lexicon-as-data; **no** sentiment/embedding rescue introduced. The eval harness is re-pointed and **run**; emotions precision/recall floors must not regress. This is the live gate — enforced by a dedicated eval task ordered last. **PASS (gated)**
- [x] **VIII. Service-Oriented Architecture** — reuses `NLNoteExtractor` + `LexiconData` + the `AppDependencies` seam; VMs stay `@MainActor @Observable`; no persistence logic moved into views. **PASS**
- [x] **IX. Pre-Release Data Posture** — `emotionsJSON` stays **optional** (CloudKit-compatible, no unique/required attribute added); schema conflict recovered by the existing wipe path in `AppModelContainer`. No migration plan. **PASS**
- [x] **X. Test-First Development** — the `NoteExtraction` model rename, `LexiconData`/`Lexicon` word-list, `NLNoteExtractor` detection, and `ExtractionReviewViewModel` changes are covered test-first: failing tests updated/added (RED) before the rename lands (GREEN). SwiftUI label change is build+run verified (exempt). **PASS**

**Result**: No violations → Complexity Tracking empty.

## Project Structure

### Documentation (this feature)

```text
specs/020-emotions-lexicon/
├── plan.md              # This file
├── research.md          # Phase 0 — curation methodology + final 20 (from How We Feel research pass)
├── data-model.md        # Phase 1 — Recording column, TagCategory, NoteExtraction, lexicon shape
├── quickstart.md        # Phase 1 — how to validate (UI, eval, clean-launch)
├── contracts/
│   └── emotions-lexicon.md   # the data contract: lexicon.json `emotions` key + the 20 words + quadrants
└── checklists/
    └── requirements.md  # spec quality checklist (done)
```

### Source Code (repository root) — files touched

```text
app-four/
├── Models/
│   ├── Recording.swift                       # feelingsJSON → emotionsJSON; decodedFeelings → decodedEmotions; applySummary writes
│   ├── Recording+MoodDisplay.swift           # decodedEmotions; DisplayTag id "emotion-…"
│   └── RecordingTag.swift                     # TagCategory.feelings → .emotions
├── Services/
│   ├── Protocols.swift                        # SummaryResult.feelings → .emotions
│   ├── NLSummarizationService.swift           # pass-through field rename
│   ├── ExportService.swift                    # export DTO feelingsJSON → emotionsJSON
│   └── NoteExtraction/
│       ├── NoteExtraction.swift               # .feelings property + CodingKeys + decode/encode
│       ├── Lexicon.swift                       # feelings/defaultFeelings → emotions/defaultEmotions; NEW 20-word default
│       ├── LexiconData.swift                   # feelings/extraFeelings → emotions/extraEmotions
│       ├── NLNoteExtractor.swift               # detectedFeelings, cues.feelings → emotions
│       ├── PersonalLexiconBuilder.swift        # feelings/seenFeelings/feelingsCategory → emotions
│       └── CueMatcher.swift                    # comments only (category naming)
├── Resources/
│   └── lexicon.json                            # "feelings" key → "emotions"; REPLACE word array with the 20
├── ViewModels/
│   ├── ExtractionReviewViewModel.swift         # feelings set, toggleFeeling, editedFields.feelings
│   └── CheckInViewModel.swift                  # nudge "Any strong feelings?" → "Any strong emotions?"
├── Views/
│   ├── ExtractionReviewView.swift              # feelingGroups, feelingsField, "07 Emotions" header, a11y label
│   └── Components/ADHDSummarySection.swift      # decodedEmotions, chip loop
└── Utils/MockDataGenerator.swift               # emotionPool (use the new 20), emotionsJSON

app-fourTests/
├── Eval/{EvalSet,ExtractionEvalTests,EvalMetrics}.swift   # category field + floors var + re-pointed samples
├── Services/{LexiconDataTests,PersonalLexiconTests,NLNoteExtractor*Tests}.swift
├── ViewModels/{ExtractionReviewViewModelTests,CheckInViewModelTests}.swift
└── Models/RecordingApplySummaryTests.swift  ·  Mocks/MockSummarizationService.swift
```

**Structure Decision**: Single iOS target. No new modules or directories — this is an in-place rename + a data-file word-list replacement. The only *new* artifact is the curated 20-word emotions list, which lives as **data** in `lexicon.json` (superset) with a curated default subset in `Lexicon.defaultEmotions` (code), mirroring the existing feelings split exactly.

## Complexity Tracking

> No Constitution violations — table intentionally empty.
