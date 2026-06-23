# whispernotes NLP Architecture Audit

## System Overview

NLNoteExtractor is an 848-line Swift NLP pipeline for extracting structured ADHD journal data from short voice-note transcripts. It runs entirely on-device using Apple's `NaturalLanguage` framework. No model download required. iOS 26+ / macOS 15+.

**Key design principle:** Pure rule-based lexicon matching with deterministic output. No ML, no embeddings, no cloud dependency. The entire pipeline is `nonisolated`/`Sendable` for off-main-actor execution.

---

## Pipeline Flow

```
transcript
  → NLTokenizer(.sentence) → [sentences]
    → per sentence:
      → CueMatcher.tokenizeWithLemmas() → [Token(surface, verbLemma?)]
        → NLTagger(.lexicalClass, .lemma) → verb lemmas only
      → nearestMood / nearestEnergy / nearestFocus (longest-match-wins)
        → isNegatedBefore() → flip if negated
      → TenseClassifier.tense() → temporalWeight (present=1.0, neutral=0.5, past=0.2)
      → extractMedications() → fuzzy matching + clause-scoped attributes
      → nonNegatedCueMatch() for all other categories
      → activity detection (surface-only, no lemmas)
      → sleep detection (regex + keyword)
    → aggregate candidates:
      → mood: max(temporalWeight, then sentenceIndex)
      → energy/focus: max(phraseLength)
    → extractHighlights() → scored + deduped sentences
    → makeTitle() → first clause, stripped fillers
```

---

## Component Inventory

| Component | File | Lines | Role |
|-----------|------|-------|------|
| NLNoteExtractor | NLNoteExtractor.swift | 848 | Main pipeline orchestrator |
| CueMatcher | CueMatcher.swift | 201 | Tokenization, lemmatization, matching, fuzzy distance |
| TenseClassifier | TenseClassifier.swift | 97 | Present/past/neutral classification |
| Lexicon | Lexicon.swift | 396 | Hard-coded default vocabulary + injectable init |
| LexiconData | LexiconData.swift | 130 | Codable JSON representation + overlay system |
| NoteExtraction | NoteExtraction.swift | 294 | Output schema (20+ fields) |
| PersonalLexiconBuilder | PersonalLexiconBuilder.swift | 45 | User correction → overlay |
| ADHDRegexPatterns | NLNoteExtractor.swift:743-848 | 106 | Compiled regex for dose, sleep, onset, duration, crash, context |

---

## Extraction Targets

| Target | Type | Cardinality | Aggregation Rule | Key Mechanism |
|--------|------|-------------|------------------|---------------|
| mood | scalar (5 levels) | 1 | present-tense-wins | longest lexicon match, temporal weight |
| energy | scalar (5 levels) | 1 | strongest-match-wins | longest phrase, negation flip |
| focus | scalar (5 levels) | 1 | strongest-match-wins | longest phrase, negation flip |
| feelings | set | N | collect all non-negated | per-cue iteration, deduped |
| activities | set | N | collect all matches | surface-only, no lemma |
| medications | set | N | collect all, per-clause attributes | exact + fuzzy + regex |
| sleepHours | scalar | 0-1 | first match | regex + sentence keyword |
| sideEffectFlag | boolean | 1 | any non-negated cue | longest-match cue list |
| topics | set | N | derived from meds/symptoms/appointments | post-hoc derivation |
| tasksCompleted | set | N | collect non-negated | longest-match cue list |
| tasksAvoided | set | N | collect non-negated | longest-match cue list |
| wins | set | N | collect non-negated | longest-match cue list |
| overwhelm | set | N | collect non-negated | longest-match cue list |
| executiveDysfunction | set | N | collect non-negated | longest-match cue list |
| physicalStim | set | N | collect non-negated | longest-match cue list |
| physicalSideEffects | set | N | collect non-negated | longest-match cue list |
| reboundTerms | set | N | collect non-negated | longest-match cue list |
| appetiteLoss | set | N | collect non-negated | longest-match cue list |
| appetiteReturn | set | N | collect non-negated | longest-match cue list |
| appointments | set | N | collect non-negated | longest-match cue list |
| extractedDose | string | 0-1 | first match | regex |
| onsetMinutes | int | 0-1 | first match | regex |
| durationHours | double | 0-1 | first match | regex |
| crashTime | string | 0-1 | first match | regex |
| intakeContext | string | 0-1 | first match | regex |
| highlights | array | 1-5 | scored + deduped | cue-density scoring + Jaccard dedup |
| title | string | 1 | first highlight clause | filler stripping + truncation |

---

## Lexicon Structure

The lexicon is a curated, hand-maintained vocabulary list organized by extraction target. It lives in `lexicon.json` (1,120 lines) and has a Swift default fallback.

### Scale per category

| Category | Entries (JSON) | Notes |
|----------|----------------|-------|
| moodSpecific | 68 | 5 labels: low, flat, okay, good, great |
| energyCharged | 21 | |
| energyAlert | 7 | |
| energySteady | 7 | |
| energyTired | 18 | |
| energySluggish | 37 | |
| focusLockedIn | 22 | |
| focusSharp | 9 | |
| focusPresent | 6 | |
| focusDistracted | 25 | |
| focusFoggy | 39 | |
| feelings | 62 | |
| taskCompletion | 12 | |
| taskAvoidance | 20 | |
| winCues | 12 | |
| overwhelmCues | 20 | |
| executiveDysfunction | 33 | |
| appointmentCues | 15 | |
| sideEffectCues | 29 | |
| physicalStim | 26 | |
| physicalSideEffects | 20 | |
| sleepQualityGood | 18 | |
| sleepQualityBad | 22 | |
| sleepInsomnia | 17 | |
| reboundTerms | 22 | |
| appetiteLoss | 19 | |
| appetiteReturn | 16 | |
| medications | 92 | Includes generics, brand names, street names, typos |
| activityKeywords | 11 categories × ~7 each | |
| negationTokens | 5 | not, never, no, n't, without |
| medNotTakenVerbs | 5 | forgot, missed, skipped, skip, forget |
| timeOfDayKeywords | 8 | |

**Total vocabulary:** ~650+ distinct surface phrases across all categories.

---

## NLP Techniques Used

| Technique | Implementation | Where | Limitations |
|-----------|------------------|-------|-------------|
| Sentence splitting | NLTokenizer(.sentence) | splitSentences:298 | Apple-only; no clause-level discourse parsing |
| Word tokenization | NLTokenizer(.word) | tokenize:38, tokenizeWithLemmas:58 | Preserves possessives/contractions deliberately |
| Lemmatization | NLTagger(.lemma) | tokenizeWithLemmas:62-74 | Only for verbs; absent on iOS simulator; one entry ("panicking"→"panicked") hardcoded in `canonicalInflections` |
| POS tagging | NLTagger(.lexicalClass) | tokenizeWithLemmas:68 | Used only to gate lemma lookup (verb-only) |
| Tense detection | Lexical markers + verb suffix | TenseClassifier:40-58 | Limited to explicit markers; irregular past list is finite (17 verbs) |
| Negation detection | Window scan (5 words, 1 for "no") | isNegatedBefore:318 | No scope resolution; no syntactic parsing; "not only happy" → false flip risk |
| Fuzzy matching | Damerau-Levenshtein distance=1 | editDistanceIsOne:142 | Medications only; single-character edits only |
| Clause splitting | String split at "and/but/then/so/, " | clauseRanges:484 | Syntactically naive; no dependency parsing |
| Regex extraction | NSRegularExpression (compiled once) | ADHDRegexPatterns:743 | Dose, sleep, onset, duration, crash, intake context |
| Highlight scoring | Cue-density heuristic | extractHighlights:627 | Fixed weights (med=3, win=2.5, etc.); no learning |
| Personal overlay | User-corrected tags → lexicon append | PersonalLexiconBuilder:12 | Only meds and feelings; no mood/energy/focus overlays |

---

## Critical Design Decisions

1. **Mood = exact lexicon only, no sentiment fallback.** NLTagger paragraph sentiment was too negatively biased on short factual text (-0.6 to -0.8), fabricating "low" moods on neutral entries. (Line 242-244)

2. **Activities = surface-only, no lemmas.** Gerund polysemy: "reading"→"read" would fire on unrelated text. (Line 14-15)

3. **Longest-match-wins for mood/energy/focus.** "feel nothing" beats "nothing"; "not bad" beats "bad". (nearestMood:379, nearestEnergy:392)

4. **Present-tense-wins for mood headline.** Past moods are context. "I was feeling anxious on Monday. Today I'm calm." → mood=good. (Line 245-249)

5. **Strongest-match-wins for energy/focus.** Longest phrase across all sentences, not temporal. (Line 254-258)

6. **Negation = simple window, no scope.** "not bad" → okay; but "not only happy" is a known risk. "no" uses 1-word window to avoid "no special energy focus" false flip. (Line 315-335)

7. **Medication fuzzy matching = context-gated.** Only fires when dose context ("mg", "took") or med-context tokens are present. Stoplist prevents "concert"→"Concerta". (Line 430-444)

8. **Clause-scoped medication attributes.** "I skipped my Strattera but took my Concerta" → Strattera not-taken, Concerta taken. (Line 461-479)

---

## Known Weaknesses (from code comments)

1. **Paraphrase gap:** "wading through wet sand" → sluggish is not in lexicon. Energy recall on paraphrases is expected to be zero. (EvalSet case `en-paraphrase-energy`)

2. **Past-progressive filtering:** "was feeling really anxious on Monday" → past tense should suppress, but "I was feeling" is in pastMarkers. Works, but "Today I'm actually calm" is the present-tense win. (EvalSet case `en-past-progressive`)

3. **Common-word traps:** "heavy" (gym bag), "empty" (fridge), "raw" (vegetables) require "feel" carrier phrases. (EvalSet case `en-traps`, Task 5)

4. **ASR typos:** "Conserta" → Concerta via Damerau-Levenshtein. But only for medications, and only single-edit distance. (EvalSet case `en-med-asr-typo`, Task 11)

5. **Inflection recall:** "panicking" → "panicked" is the ONLY hardcoded inflection. All other verb inflections rely on NLTagger lemma bridge, which is absent on iOS simulator. (CueMatcher:123-125)

6. **Lexicon-dependent paraphrase:** "weight lifted off my shoulders" → relieved/good is not in lexicon. (EvalSet case `en-mood-paraphrase-lifted`)

7. **Simulator vs device divergence:** NLTagger lemma model absent on iOS simulator. Only affects verb-lemma fallback (one hardcoded entry + any verb inflections). (CueMatcher:117-119)

8. **Activities beyond original six:** Added 5 new categories (Work, Chores, Errands, Outdoors, Screen Time) in Task 10. Surface-only matching. (Lexicon:383-395)

---

## Evaluation Infrastructure

| Component | Purpose | Status |
|-----------|---------|--------|
| EvalSet | 40 hand-curated cases | EN (34), PT (3), ES (3) |
| EvalMetrics | Precision/recall counts per category | Scalar (wrong=FP+FN), Set (intersection/difference) |
| EvalFloors | Regression ratchets | 9 categories with P/R floors; never lowered |
| ExtractionEvalTests | Swift test target | Runs extractor over EvalSet, asserts floors |
| EvalHarness | Standalone macOS CLI | Dumps per-case expected/actual to JSON |
| analyze_eval.py | Basic Python analysis | Error listing + confusion matrices for mood/energy/focus |

### Current floors (ratcheted, never lowered)

| Category | Precision | Recall | Notes |
|----------|-----------|--------|-------|
| mood | 0.730 | 0.580 | |
| energy | 0.647 | 0.230 | Very low recall |
| focus | 0.380 | 0.313 | Lowest precision |
| feelings | 0.920 | 0.647 | High precision, moderate recall |
| activities | 0.280 | 0.409 | Lowest precision; many false positives |
| meds | 0.980 | 0.980 | Nearly perfect |
| sleepHours | 0.980 | 0.266 | Very low recall |
| topics | 0.880 | 0.763 | |
| sideEffectFlag | 0.730 | 0.409 | Low recall |

### Test coverage (unit tests)

| Test File | Cases |
|-----------|-------|
| NLNoteExtractorTenseTests | Tense classification |
| NLNoteExtractorMoodTests | Mood extraction |
| NLNoteExtractorRegexTests | Regex patterns |
| NLNoteExtractorSmokeTests | Basic smoke |
| NLNoteExtractorNegationTests | Negation handling |
| NLNoteExtractorMatchingTests | Matching logic |
| NLNoteExtractorMedicationTests | Med extraction |
| EvalMetricsTests | Metric computation |
| ExtractionReviewViewModelTests | UI review flow |

---

## Architecture Assessment Summary

**Strengths:**
- Deterministic, reproducible, no model drift
- Extremely fast (on-device, no network)
- Privacy-preserving (no cloud)
- Well-structured for incremental lexicon growth
- Personal overlay system for user-specific vocabulary
- Good medication extraction (regex + fuzzy + clause scoping)
- Temporal disambiguation (present vs past) is a genuine feature

**Weaknesses:**
- **Paraphrase blindness:** Cannot recognize semantic equivalents not in lexicon
- **Coverage-limited recall:** Every new expression requires manual lexicon entry
- **Negation is crude:** No scope, no syntactic structure, no modality
- **No contextual disambiguation:** "I feel light" vs "light rain" handled by "feel" carrier, but "spent" (time vs money) has no general solution
- **Ordinal signals treated as scalar:** A "miss" of 3→4 (adjacent) vs 5→1 (polar) is identical in current metrics
- **40 cases is too small** for statistical confidence on any category
- **Multilingual (PT/ES) is undeveloped:** Only EN lexicon is substantive; PT/ES cases get near-zero recall
- **No embedding/semantic similarity:** "wading through wet sand" and "sluggish" have zero connection in the current system
- **iOS simulator divergence:** Lemma-dependent matching behaves differently on sim vs device
- **Activities precision is very poor** (0.28) — many false positives from surface matching
- **Energy and focus recall are very poor** (0.23, 0.31) — most energy/focus expressions are not in the lexicon or are paraphrased
- **SleepHours recall is very poor** (0.27) — only catches explicit "slept X hours" patterns
- **Evaluation is aggregate-only** — no per-case error analysis, no confusion matrices, no subset slicing

**Systemic pattern:** The pipeline is a well-engineered rule-based system that has hit the ceiling of what rule-based matching can do. Every improvement path (paraphrase, context, negation scope, multilingual) points toward either a massive lexicon expansion or a shift toward learned representations.
