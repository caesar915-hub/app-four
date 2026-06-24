# Phase 0 Research: Multilingual On-Device Check-in Extraction (Demo)

All "NEEDS CLARIFICATION" were resolved during planning (the spec carries no markers). This file
records the decisions that shape the plan, each grounded in the two repos.

## D1 — Port scope: engine swap, not rewrite

**Decision**: Replace the engine logic files in `app-four/Services/NoteExtraction/` with the spike
versions and ADD `LanguageConfig.swift`; keep the app's `NoteExtraction.swift` model.

**Rationale**: The app's extractor files were forked from the same `nl-classifier` lineage as the
spike (per the dir's own README). Verified sizes are near-identical: CueMatcher 200↔201,
TenseClassifier 97↔98, Lexicon 396↔396, LexiconData 130↔130, NoteExtraction 294↔294; only
`NLNoteExtractor` is materially newer (848→931, +83 lines). The app already writes 26 of the
spike's 27 output fields and already has all expanded-triage fields. So the delta is: add
`LanguageConfig`, take the newer extractor + tense classifier (which now source markers from
`LanguageConfig.english`), and rename one output write.

**Alternatives rejected**: (a) hand-merge each recall improvement into the app's 848-line
extractor — far more error-prone than swapping a same-lineage file; (b) keep the app engine and
bolt on language selection — the localized tables (`LanguageConfig`) don't exist in the app engine,
so non-English would have nothing to switch to.

## D2 — The one model reconciliation: `feelings` → `emotions`

**Decision**: In the ported `NLNoteExtractor`, rename the single output write
`extraction.feelings = …` → `extraction.emotions = …`. No other output rename.

**Rationale**: Diff of the two models shows the **only** field-name difference is spike `feelings`
vs app `emotions` (the spec-020 rename, merged to `main` as commit 55201477). All other 26 fields
(mood, energy, focus, sleep, medications, sideEffects, physicalSideEffects, reboundTerms,
appetiteLoss, appetiteReturn, executiveDysfunction, physicalStim, appointments, the 6 structured
regex fields, highlights, title, etc.) match by name and type. The internal lexicon vocabulary key
stays `feelings` (input vocab); only the model output field is `emotions`.

## D3 — English lexicon reconciliation (preserve spec-020 curation)

**Decision**: `lexicon.en.json` = the spike's English engine vocabulary, but with the `feelings`
word-list replaced by the app's curated **20-word Mood-Meter** vocabulary (spec-020). Do NOT copy
the spike's stale ~60-word list. Keep `Lexicon.swift`'s `defaultEmotions` (curated 20) as the code
fallback.

**Rationale**: spec-020 deliberately curated the emotion vocabulary one day before this work.
Copying the spike's pre-curation list would silently revert that feature (Constitution III) and
would shift the `emotions` eval floor (Constitution VII, SC-002). User-confirmed during planning.

**Alternatives rejected**: use spike list verbatim (reverts 020); union both lists (dilutes the
deliberate Mood-Meter curation, risks lowering `emotions` precision).

## D4 — Pack selection mechanism

**Decision**: `LanguageDetector.packKey(for:locale:)` uses `NLLanguageRecognizer` constrained to
{english, portuguese, spanish} with equal hints; maps portuguese→`pt-PT`, spanish→(`es-MX` if
`locale.region == "MX"` else `es-ES`), default→`en`. `LanguagePackLoader.extractor(for:locale:overlay:)`
loads `lexicon.<key>.json` (+ `config.<key>.json` for non-en) and constructs
`NLNoteExtractor(lexicon:config:)`.

**Rationale**: `NLLanguageRecognizer` returns only `es` for both Spanish variants, so the variant
must come from device region (the prompt's documented approach). Constraints + hints handle the
short-check-in case. On-device, no dependency (Constitution VI).

## D5 — `LanguageConfig` is synthesized-Codable → packs must be complete

**Decision**: Treat each `config.<key>.json` as requiring **all 17** `LanguageConfig` fields; pin
this with a loader test that asserts a non-English pack decodes to a *non-English* config (not the
`.english` fallback).

**Rationale**: `LanguageConfig` has no explicit `CodingKeys` and all fields are non-optional `let`s
([LanguageConfig.swift:7-92](../../app-four-spikes-local/nlp-spike/extractor/LanguageConfig.swift)).
`JSONDecoder` therefore (a) ignores extra keys — which is why the packs' extra keys
(clauseBreakConjunctions, medContextTokens, medStoplist, titleClauseSplitters, canonicalInflections,
…) are **inert**, the precise mechanism behind the documented English-only limitation for
negation/med-clause/titles/morphology; and (b) **throws if any of the 17 required keys is missing**,
which the loader's `try?` swallows into a silent `.english` fallback. A missing key would quietly
defeat a language in the demo, so it must be test-caught.

## D6 — Personalization overlay must survive the rewire

**Decision**: Extend the loader beyond the prompt's skeleton:
`LanguagePackLoader.lexicon(_ key:, overlay: PersonalLexicon?)` threads the overlay into
`LexiconData.toLexicon(personalOverlay:)`; `extractor(for:locale:overlay:)` passes it through. The
production call site supplies the same `personalOverlay` it does today.

**Rationale**: today's prod path is `LexiconLoader.loadBundled(overlay: personalOverlay)`
([NLSummarizationService.swift:17](../../app-four/Services/NLSummarizationService.swift)). The naive
skeleton drops the overlay → silent loss of P2.3 personalization (FR-007/SC-005). Threading it is
cheap and prevents a regression.

## D7 — Resource bundling needs no `project.pbxproj` edit

**Decision**: Drop the 7 JSON files into `app-four/Resources/`; no pbxproj change.

**Rationale**: the project uses `PBXFileSystemSynchronizedRootGroup`
([project.pbxproj](../../app-four.xcodeproj/project.pbxproj) §40-54) — the `Resources/` folder is
auto-synchronized into the build. Verified the existing `lexicon.json` is bundled this way (empty
`PBXResourcesBuildPhase` files array). Confirm by a build that `Bundle.main.url` resolves each.

## D8 — Eval-floor risk (the live gate)

**Decision**: Keep the eval as the English regression guard. Re-run after the swap; **if a floor
breaks, STOP and investigate — never weaken a floor.** Only update an expectation if the richer
engine *improves* an exact-match assertion (and note it).

**Rationale**: floors (`EvalFloors`, e.g. mood .730/.580, emotions .920/.647, meds .980/.980) were
tuned to the app's 848-line engine; the spike engine was tuned independently. Recall should rise,
but a precision dip below a floor is possible. The eval constructs the extractor with English
defaults, so it stays a valid EN guard after the constructor gains a defaulted `config:` param. The
draft pt/es packs are **not** scored by the harness (Assumption); non-EN is verified by the 4
manual reference check-ins (SC-001).

## D9 — Constitution VII: no embedding/sentiment rescue reintroduced

**Decision**: Proceed; the port preserves the deterministic, lexicon-only posture.

**Rationale**: `grep` of the spike extractor for `NLEmbedding|sentiment|valence` found only a
comment confirming "No sentiment-valence fallback"; the engine uses `NLTagger`/`NLTokenizer` only.
No prohibited word-vector rescue is introduced.
