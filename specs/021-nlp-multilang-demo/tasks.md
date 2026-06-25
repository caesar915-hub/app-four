---

description: "Task list for Multilingual On-Device Check-in Extraction (Demo)"
---

# Tasks: Multilingual On-Device Check-in Extraction (Demo)

**Input**: Design documents from `/specs/021-nlp-multilang-demo/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Test-first is MANDATORY for logic (Constitution X). The ported engine is a same-lineage
port whose contract is the existing **eval precision/recall floors** (`app-fourTests/Eval/*`) — those
floors are the regression gate (Principle VII): run them, they must hold; a broken floor is an
unexpected RED → **STOP and investigate, never weaken**. The genuinely new logic — `LanguageDetector`
and `LanguagePackLoader` — gets fresh RED tests before implementation. Swift Testing (`@Test`/`#expect`).

**Paths**: app source `app-four/…`; tests `app-fourTests/…`. Spike source =
`~/Projects/app-four-spikes-local/nlp-spike/extractor`.

## Phase 1: Setup

- [X] T001 Confirm branch `feat/nlp-multilang-demo` is checked out and the spike source dir
      `~/Projects/app-four-spikes-local/nlp-spike/extractor` exists with `LanguageConfig.swift`,
      `NLNoteExtractor.swift`, `TenseClassifier.swift`, `lexicon.json`, and `packs/`.
- [X] T002 Establish the GREEN baseline: run `xcodebuild test -scheme app-four -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:app-fourTests/Eval` on the unmodified branch and record that all floors currently pass (so any later break is attributable to the swap).

---

## Phase 2: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: the engine will not compile (and no story can proceed) until `LanguageConfig`
exists and the sibling files are reconciled.

- [X] T003 Diff the four sibling files between spike and app and reconcile (spike is newer): `~/Projects/app-four-spikes-local/nlp-spike/extractor/{CueMatcher,Lexicon,LexiconData}.swift` vs `app-four/Services/NoteExtraction/{CueMatcher,Lexicon,LexiconData}.swift`. Overwrite a file only where the spike is behaviorally newer; **preserve `Lexicon.defaultEmotions` (spec-020 curated 20) — do NOT take the spike's pre-curation `feelings` default**; keep `LexiconData.toLexicon(personalOverlay:)`. If any divergence is non-obvious, **STOP and report the exact symbol** — do not invent a shim.
- [X] T004 Add `app-four/Services/NoteExtraction/LanguageConfig.swift` (copy spike verbatim — Codable per-language tables + `static let english`). Needed by both the ported extractor (US1) and the config packs (US2/US3).

**Checkpoint**: `LanguageConfig` present; siblings reconciled. Engine port can begin.

---

## Phase 3: User Story 1 — English check-in keeps working after the engine upgrade (Priority: P1) 🎯 MVP

**Goal**: Swap in the richer same-lineage engine; English extracts the 6 signals at ≥ today's
quality; spec-020's curated emotions and personalization are preserved.

**Independent Test**: eval floors hold; the English reference check-in surfaces all 6 signals; a
curated emotion extracts and a spec-020-removed emotion does not.

### Tests for User Story 1 (test-first · RED — MANDATORY) ⚠️

- [X] T005 [US1] RED: add `app-fourTests/Services/EnglishPackExtractionTests.swift` — build an extractor from `lexicon.en.json` (English) and assert the en reference check-in (quickstart §4) populates `mood`, `energy`, `focus`, `sleep`, `medications`, `sideEffects`, AND `emotions`; assert a curated-20 emotion is detectable while a known spec-020-removed word is not. Run it; confirm it FAILS (no `lexicon.en.json` yet).

### Implementation for User Story 1

- [~] T006 [US1] **SUPERSEDED** — no `lexicon.en.json` is created. The app's current `Resources/lexicon.json` already has the `"emotions"` key with spec-020's curated 20 and is the exact vocab the eval floors were tuned on; English keeps using it. (Minimal-delta: only the engine changes, not the English vocabulary.)
- [X] T007 [US1] Replace `app-four/Services/NoteExtraction/NLNoteExtractor.swift` with the spike version, then rename the single output write `extraction.feelings = …` → `extraction.emotions = …`. Verify (grep) no other `extraction.feelings`/`.feelings =` write remains.
- [X] T008 [P] [US1] Replace `app-four/Services/NoteExtraction/TenseClassifier.swift` with the spike version (markers now sourced from `LanguageConfig.english`).
- [~] T009 [US1] **SUPERSEDED** — `loadBundled` is left reading `lexicon.json`. In US2, `LanguagePackLoader.lexicon("en")` routes the English key through `LexiconLoader.loadBundled` instead of a separate `lexicon.en.json`, so no repoint and no duplicate file (eval + `LexiconDataTests` untouched). Constructor `NLNoteExtractor(lexicon:config:.english)` keeps existing call sites compiling.
- [X] T010 [US1] Build: `xcodebuild build -scheme app-four -destination 'platform=iOS Simulator,name=iPhone 15'`. Fix compile errors (the `feelings`→`emotions` write, the new `config:` param, any sibling-merge fallout). 
- [X] T011 [US1] GREEN gate: run T005 + `-only-testing:app-fourTests/Eval`. T005 passes; every eval floor holds. **If any floor regressed, STOP and investigate the swap — do not weaken a floor.** Note any exact-match expectation the richer engine legitimately improved.

**Checkpoint**: English MVP — richer engine in, floors green, curation + personalization intact. Shippable.

---

## Phase 4: User Story 2 — Portuguese and Spanish understood in-language (Priority: P2)

**Goal**: Detect the check-in language and extract the 6 signals with the matching pack
(`pt-PT`, `es-ES`); English still routes correctly.

**Independent Test**: the pt and es-ES reference check-ins are detected, select their pack, and
surface all 6 signals; detector/loader unit tests pass.

### Tests for User Story 2 (test-first · RED — MANDATORY) ⚠️

- [X] T012 [P] [US2] RED: `app-fourTests/Services/LanguageDetectorTests.swift` — en reference → `"en"`; pt reference → `"pt-PT"`; es reference (any non-MX region) → `"es-ES"`. Run; confirm FAILS (no `LanguageDetector` yet).
- [X] T013 [P] [US2] RED: `app-fourTests/Services/LanguagePackLoaderTests.swift` — `config("pt-PT")` and `config("es-ES")` each decode to a NON-`.english` config (proves pack completeness — guards the synthesized-Codable silent-fallback trap, research D5); `config("en") == .english`; `config("zz")` (missing) → `.english`; `lexicon("en", overlay:)` applies a sentinel overlay term (overlay threaded). Run; confirm FAILS.

### Implementation for User Story 2

- [X] T014 [P] [US2] Add `app-four/Services/NoteExtraction/LanguageDetector.swift` — `packKey(for:locale:)` via `NLLanguageRecognizer` constrained to en/pt/es with equal hints; portuguese→`"pt-PT"`, spanish→`"es-ES"` (region branch deferred to US3), default→`"en"`.
- [X] T015 [US2] Add `app-four/Services/NoteExtraction/LanguagePackLoader.swift` — `lexicon(_:overlay:)` (loads `lexicon.<key>.json` → `LexiconData.toLexicon(personalOverlay:)`, `Lexicon()` fallback), `config(_:)` (`"en"`→`.english`, else decode `config.<key>.json`, `.english` fallback), `extractor(for:locale:overlay:)`. Overlay always threaded (FR-007).
- [X] T016 [P] [US2] Add packs to `app-four/Resources/`: `lexicon.pt-PT.json`, `config.pt-PT.json`, `lexicon.es-ES.json`, `config.es-ES.json` (copy from spike `extractor/packs/`).
- [X] T017 [US2] Rewire the production path in `app-four/Services/NLSummarizationService.swift`: select+build the extractor **per check-in** from the transcript text — store the `personalOverlay` at init and call `LanguagePackLoader.extractor(for: text, overlay: personalOverlay)` inside the extract/summarize method, replacing the single pre-built `LexiconLoader.loadBundled` extractor. Leave the `init(lexicon:)` test seam intact.
- [X] T018 [US2] Build + run T012/T013 (GREEN) + the Eval floors (still green — English unaffected). Then manual: pt and es-ES reference check-ins each surface the 6 signals (quickstart §4).

**Checkpoint**: en + pt-PT + es-ES all work via per-check-in selection.

---

## Phase 5: User Story 3 — Mexican vs. European Spanish by region (Priority: P3)

**Goal**: Disambiguate the two Spanish packs by device region (MX → `es-MX`, else `es-ES`).

**Independent Test**: same Spanish check-in selects `es-MX` under region Mexico and `es-ES`
otherwise; the mx reference check-in (incl. "Ando agüitado") surfaces low mood + the 6 signals.

### Tests for User Story 3 (test-first · RED — MANDATORY) ⚠️

- [X] T019 [P] [US3] RED: extend `app-fourTests/Services/LanguageDetectorTests.swift` — the same Spanish reference text with `locale.region == "MX"` → `"es-MX"`, with region `"ES"` → `"es-ES"`. Extend `LanguagePackLoaderTests` — `config("es-MX")` decodes to a non-`.english` config. Run; confirm the MX cases FAIL.

### Implementation for User Story 3

- [X] T020 [US3] Add the region branch to `LanguageDetector.packKey`: spanish → `(locale.region?.identifier == "MX") ? "es-MX" : "es-ES"`.
- [X] T021 [P] [US3] Add packs to `app-four/Resources/`: `lexicon.es-MX.json`, `config.es-MX.json` (from spike `extractor/packs/`).
- [X] T022 [US3] Build + run T019 (GREEN) + Eval floors. Manual: set simulator region to Mexico, enter the mx reference check-in, confirm `es-MX` selection and the 6 signals (incl. low mood from "Ando agüitado"); switch to Spain → `es-ES`.

**Checkpoint**: all four packs select and extract correctly.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T023 [P] RED: in `app-fourTests/Services/` add/extend a test asserting `NLSummarizationService` surfaces an `appetiteLoss` phrase within its side-effect display output (`sideEffectKeywords`). Run; confirm FAILS.
- [X] T024 Fold the `appetiteLoss` bucket into the side-effect surface in `app-four/Services/NLSummarizationService.swift:78-85` (`sideEffectKeywords`), alongside `sideEffects`/`physicalSideEffects` (FR-011). Make T023 GREEN.
- [~] T025 **SUPERSEDED** — `lexicon.json` is kept (not removed): the English key routes through `LexiconLoader.loadBundled` which reads it, and the eval + `LexiconDataTests` depend on it. No duplicate `lexicon.en.json` was ever created, so there is nothing to remove.
- [X] T026 Full verification: `xcodebuild build` + `xcodebuild test -scheme app-four` (entire suite, incl. Eval) green; run the quickstart §4 four-language manual demo end-to-end (verify §1-5).
- [X] T027 [P] Log a `docs/DEVLOG.md` checkpoint (the why: engine upgraded to the multilingual lineage + 4 demo packs; documented limitations) and move `docs/BACKLOG.md` item to 🔨/✅.

---

## Dependencies & Execution Order

- **Setup (P1)** → **Foundational (P2: T003-T004)** blocks everything.
- **US1 (P3 phase)** depends on Foundational. It is the MVP and the prerequisite engine for US2/US3.
- **US2** depends on US1 (engine in place + `lexicon.en.json` + per-check-in wiring point).
- **US3** depends on US2 (`LanguageDetector` + `LanguagePackLoader` exist; adds the region branch + es-MX pack).
- **Polish (P6)** depends on US1 (T024 touches the side-effect surface) and US3 (T025 removes legacy lexicon after the loader fully replaces it).

### Within each story

- Write the RED test, run it, confirm it FAILS, then implement to GREEN, then refactor (Principle X).
- Resources before the loader that reads them; loader before the call-site rewire.
- Eval floors re-run at every story checkpoint (Principle VII).

### Parallel opportunities

- T008 (TenseClassifier) ∥ T006 (lexicon.en.json) within US1.
- T012 ∥ T013 (detector vs loader tests); T014 ∥ T016 (detector file vs pack resources) within US2.
- T021 (es-MX packs) ∥ T019 (tests) within US3.

---

## Implementation Strategy

**MVP = US1**: Foundational + the engine swap with English correct (floors green) is a complete,
shippable increment — the richer extraction lineage, no behavioral regression.

**Incremental**: US1 (English) → US2 (pt-PT + es-ES) → US3 (es-MX). Each adds a language slice
without breaking the previous, gated by the eval floors and the per-story manual check-in.

## Notes

- The port is gated by the existing eval floors, not new exact-match tests — never weaken a floor (VII).
- Resources auto-bundle (synchronized file group) — no `project.pbxproj` edit; a clean build is the
  first proof `Bundle.main.url` resolves each pack.
- Documented demo limitation (FR-012): for pt/es, negation/med-clause/ADHD-regex/title/morphology
  stay English — the config packs' extra keys are inert (not decoded by `LanguageConfig`).
- Commit after each story checkpoint.
