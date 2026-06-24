# Implementation Plan: Multilingual On-Device Check-in Extraction (Demo)

**Branch**: `feat/nlp-multilang-demo` | **Date**: 2026-06-25 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/021-nlp-multilang-demo/spec.md`

## Summary

Swap the app's `NLNoteExtractor` engine for the newer `nl-classifier` lineage from the
nlp-spike — same lineage the app's NoteExtraction files were originally forked from — which adds a
**data-driven `LanguageConfig`** (numbers, sleep regex, weak mood/energy tables, tense markers)
alongside the existing data-driven `Lexicon`. On top of that, add **per-check-in pack selection**:
a `LanguageDetector` picks the language from the check-in text (NLLanguageRecognizer, constrained
to en/pt/es) and the device region disambiguates the two Spanish variants; a `LanguagePackLoader`
loads the matching `lexicon.<key>.json` (+ `config.<key>.json` for non-English) and builds the
extractor, threading the existing `PersonalLexicon` overlay through unchanged.

The port is **narrower than a from-scratch rewrite**: the app already writes 26 of the spike's 27
output fields and already has all expanded-triage fields. The only output-field rename is the
spike's `feelings` → the app's `emotions` (spec-020). The English pack preserves spec-020's
curated 20-emotion vocabulary (the spike's stale ~60-word list is **not** copied). Four packs
ship: `en` (in-code default config), `pt-PT`, `es-ES`, `es-MX` (data). Non-English negation,
medication-clause parsing, ADHD-pattern detection, title generation, and morphology remain English
— an accepted, documented demo limitation. The extraction eval harness is run and its
precision/recall floors must not regress (Constitution VII).

## Technical Context

**Language/Version**: Swift 6 (strict concurrency enabled)

**Primary Dependencies**: SwiftUI (iOS 26+), SwiftData, Apple `NaturalLanguage` — `NLNoteExtractor`
(lexicon matching), `NLTagger`/`NLTokenizer` (tokenize/lemma), `NLLanguageRecognizer` (language ID
for pack selection). No new third-party dependency. WhisperKit/transcription unaffected.

**Storage**: Bundled JSON resources in `app-four/Resources/` — the per-language extraction
vocabulary (`lexicon.<key>.json`) and language config (`config.<key>.json`), data not code
(Constitution VII). No SwiftData schema change (the model already has `emotions` and every field
the engine writes).

**Testing**: Swift Testing (`@Test`/`#expect`) — new unit tests for `LanguageDetector` and
`LanguagePackLoader`; the extraction eval harness (`app-fourTests/Eval/*`) with tracked
precision/recall floors as the English regression guard.

**Target Platform**: iOS 26+ (primary), iPadOS (secondary); demo on iPhone 15 simulator (and the
A14/iPhone-12 minimum at runtime — no on-device-model dependency added here).

**Project Type**: mobile-app (single iOS target `app-four`, display name *Squirl*).

**Performance Goals**: no regression — extraction stays deterministic and off the main actor;
pack JSON is decoded once per extractor construction (per check-in), mirroring today's single
`LexiconLoader.loadBundled` decode.

**Constraints**: on-device + offline only (VI); no `NLEmbedding`/sentiment rescue reintroduced
(VII — verified absent in the spike engine); eval floors must hold (VII, SC-002); pack selection
correct for the 4 reference check-ins (SC-001/003/004); personalization preserved (FR-007/SC-005).

**Scale/Scope**: +1 engine file (`LanguageConfig.swift`), 2 new selection files
(`LanguageDetector`, `LanguagePackLoader`), 7 JSON resources (1 EN + 6 packs), a `feelings→emotions`
rename in the ported extractor, 1 call-site rewire (`NLSummarizationService`), 1 small display
edit (appetite-loss into the side-effect surface). Resources auto-bundle via
`PBXFileSystemSynchronizedRootGroup` — **no `project.pbxproj` edit**.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.* (v1.2.0)

- [x] **I. SwiftUI-First** — no new view; the only UI-adjacent change is folding the appetite-loss
      bucket into the existing side-effect display surface. No UIKit, no mockup required. **PASS**
- [x] **II. Test-Build-Ship** — plan ends in a full `xcodebuild build` + `xcodebuild test` (incl.
      eval) on the branch before done; nothing reported done unverified. **PASS**
- [x] **III. Correctness Over Speed** — the partial-localization limitation is surfaced explicitly
      (FR-012, PR notes), not silently shipped; old `lexicon.json` is deleted after rewire, not
      left as dead data; no compat shim added. **PASS**
- [x] **IV. Minimal Surface** — `LanguageConfig` is required by the ported engine; `LanguageDetector`
      + `LanguagePackLoader` are the minimum to select a pack per check-in; both are plain
      static helpers, **not** new injected DI services (justified vs. VIII below). No feature flag,
      no abstraction for hypothetical future languages. **PASS**
- [x] **V. Solo Git Discipline** — one revertable feature on `feat/nlp-multilang-demo`,
      `/code-review` before merge, `main` stays releasable. **PASS**
- [x] **VI. On-Device Privacy** — all selection + extraction on-device; `NLLanguageRecognizer`
      runs locally; no network; no transcript/med content logged. **PASS**
- [x] **VII. Deterministic, Measured Extraction** — matching stays whole-token/contiguous,
      off-main, lexicon+config as DATA; **no** sentiment/`NLEmbedding` rescue (verified absent in
      the spike engine — `grep` found only a comment confirming "no sentiment-valence fallback").
      The eval harness is **run**; English floors must not regress. This is the live gate, enforced
      by a dedicated eval task ordered last. **PASS (gated)**
- [x] **VIII. Service-Oriented Architecture** — reuses the existing `NLSummarizationService` seam
      (behind a protocol via `AppDependencies`); the extractor stays the off-main engine. The new
      `LanguagePackLoader`/`LanguageDetector` are pure, stateless factories that *construct* the
      engine — adding a protocol+DI registration for them would be premature abstraction (IV), so
      they are kept as static helpers. VMs unchanged, `@MainActor @Observable`. **PASS**
- [x] **IX. Pre-Release Data Posture** — **no schema change** (the model already has `emotions`
      and all written fields); no `@Attribute(.unique)`, no required attribute added. **N-A** for
      migration; **PASS**.
- [x] **X. Test-First Development** — `LanguageDetector.packKey` and `LanguagePackLoader` are built
      test-first (RED tests for en/pt/es-ES/es-MX selection incl. the MX-region branch, and the
      missing-pack→English fallback, written and failing before the impl). The ported engine is a
      port of already-test-covered logic; its behavior is pinned by the existing eval floors, which
      are re-run (RED if a floor breaks → investigate, never weaken). Display edit is build+run
      verified. **PASS**

**Result**: No violations → Complexity Tracking empty.

## Project Structure

### Documentation (this feature)

```text
specs/021-nlp-multilang-demo/
├── plan.md              # This file
├── research.md          # Phase 0 — port-scope diff, pack selection, EN-lexicon reconciliation, floor risk
├── data-model.md        # Phase 1 — LanguageConfig shape, pack-key model, NoteExtraction (unchanged), overlay
├── quickstart.md        # Phase 1 — how to validate (build, eval floors, 4-language manual demo)
├── contracts/
│   ├── language-pack.md      # JSON contract: lexicon.<key>.json + config.<key>.json keys; pack-key set
│   └── selection-api.md      # LanguageDetector.packKey + LanguagePackLoader.extractor contracts
└── checklists/
    └── requirements.md  # spec quality checklist (done)
```

### Source Code (repository root) — files touched

```text
app-four/
├── Services/
│   ├── NLSummarizationService.swift            # rewire prod path → LanguagePackLoader.extractor(for:overlay:);
│   │                                            #   fold appetiteLoss into sideEffectKeywords surface
│   └── NoteExtraction/
│       ├── LanguageConfig.swift                # NEW — Codable per-language tables + static .english (from spike)
│       ├── NLNoteExtractor.swift               # REPLACE w/ spike engine; rename one write feelings→emotions
│       ├── TenseClassifier.swift               # REPLACE — now sources markers from LanguageConfig
│       ├── CueMatcher.swift                     # diff vs spike; overwrite only if behaviorally newer
│       ├── Lexicon.swift                        # diff vs spike; KEEP curated defaultEmotions (spec-020)
│       ├── LexiconData.swift                    # diff vs spike; toLexicon(personalOverlay:) preserved
│       ├── LanguageDetector.swift              # NEW — packKey(for:locale:) en/pt-PT/es-ES/es-MX
│       └── LanguagePackLoader.swift            # NEW — lexicon(_:overlay:)/config(_:)/extractor(for:locale:overlay:)
└── Resources/
    ├── lexicon.en.json                          # NEW — spike EN engine vocab w/ curated-20 emotions grafted in
    ├── lexicon.pt-PT.json  config.pt-PT.json     # NEW — Portuguese draft pack
    ├── lexicon.es-ES.json  config.es-ES.json     # NEW — European Spanish draft pack
    ├── lexicon.es-MX.json  config.es-MX.json     # NEW — Mexican Spanish draft pack
    └── lexicon.json                              # REMOVE after rewire (now unused)

app-fourTests/
├── Services/
│   ├── LanguageDetectorTests.swift             # NEW — pack selection incl. MX vs ES region branch
│   └── LanguagePackLoaderTests.swift           # NEW — overlay threaded; missing pack → English fallback
└── Eval/{EvalSet,ExtractionEvalTests,EvalMetrics}.swift   # re-run; floors hold (update only if richer
                                                            #   engine *raises* an exact expectation)
```

**Structure Decision**: Single iOS target, in-place engine swap inside
`Services/NoteExtraction/`. No new module/DI service: pack selection is two stateless helpers that
build the existing engine, and the engine is reached through the existing `NLSummarizationService`
protocol seam. The only *new persistent artifacts* are the language packs, which live as **data**
in `Resources/` (auto-bundled by the synchronized file group).

## Complexity Tracking

> No Constitution violations — table intentionally empty.
