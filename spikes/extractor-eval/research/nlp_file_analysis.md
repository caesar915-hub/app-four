# NLP File Intake & Deep Analysis

## File Inventory

| File | Lines | Type | Summary |
|------|-------|------|---------|
| NLNoteExtractor.swift | 848 | Core pipeline | Main orchestrator: sentence split → per-sentence tokenization → lexicon matching → aggregation |
| CueMatcher.swift | 201 | Tokenization + matching | NLTokenizer word tokenization, NLTagger verb lemmatization, longest-match, fuzzy distance |
| TenseClassifier.swift | 97 | Temporal classification | Present/past/neutral via lexical markers + verb suffix heuristics |
| Lexicon.swift | 396 | Default vocabulary | Hard-coded 650+ phrases across 30+ categories |
| LexiconData.swift | 130 | JSON loader | Codable JSON representation + PersonalLexicon overlay |
| NoteExtraction.swift | 294 | Output schema | 20+ field extraction result struct |
| PersonalLexiconBuilder.swift | 45 | User overlay | Builds personal lexicon from user-corrected tags |
| lexicon.json | 1120 | Data file | JSON mirror of Lexicon.swift defaults + extensions |
| EvalSetCopy.swift | 301 | Test data | 40 hand-curated eval cases (EN/PT/ES) |
| EvalHarness.swift | 97 | Test harness | Standalone CLI that dumps per-case expected/actual JSON |
| EvalMetrics.swift | 38 | Metrics | Precision/recall computation (scalar + set variants) |
| ExtractionEvalTests.swift | 79 | Swift tests | Floor-based regression test |
| analyze_eval.py | 54 | Python analysis | Basic error listing + confusion matrices |

---

## Per-File Extraction

### NLNoteExtractor.swift (Core Pipeline)

**Core themes:**
1. Pure rule-based extraction — no ML, no embeddings, deterministic
2. Per-sentence processing with cross-sentence aggregation rules
3. Explicit policy documentation (P1.2, P2.3, etc.) — decisions are logged in comments
4. Negation handling is simple window-based, not syntactic
5. Clause-level scoping for medications only; all other categories are sentence-level
6. Temporal weighting: present-tense moods win over past-tense moods
7. Longest-match-wins for mood/energy/focus to prioritize specificity

**Key claims:**
- "Mood is exact lexicon match only" — no sentiment fallback due to NLTagger negative bias
- "Activities never use verb-lemma fallback" — gerund polysemy protection
- "NLTagger paragraph sentiment is too negatively biased on short factual text"
- "The pipeline is pure over value types — safe on any executor"

**Limitations noted by author:**
- Paraphrase gap: "wading through wet sand" not recognized
- Lexicon-dependent: every new expression needs manual entry
- iOS simulator divergence: lemma model absent
- 40 cases is evaluation set size

**Methodology:** Rule-based pattern matching with hand-crafted heuristics

---

### CueMatcher.swift (Tokenization + Matching)

**Core themes:**
1. Two tokenization paths: surface-only vs. lemma-aware
2. Verb-only lemmatization to prevent noun polysemy ("wires" can't match verb cue)
3. Deliberate preservation of possessives/contractions (don't split "doctor's")
4. Single-word verb lemma fallback + hardcoded `canonicalInflections` (only "panicking"→"panicked")
5. Damerau-Levenshtein distance-1 for ASR typo resilience

**Key claims:**
- "verbLemma is non-nil ONLY when the token was tagged .verb" — prevents noun lemma matches
- "The lemma bridge rides NLTagger's lemma model, which is absent on the iOS simulator"
- "canonicalInflections is the model-independent path"

**Limitations:**
- Only ONE hardcoded inflection: "panicking"→"panicked"
- All other inflections depend on NLTagger lemma model, which is device-dependent
- Fuzzy matching only for medications, only distance=1
- Multi-word cues: exact contiguous match only; no gap tolerance

---

### TenseClassifier.swift

**Core themes:**
1. Explicit lexical markers for present/past
2. Verb suffix fallback ("-ed" + 17 irregular past verbs)
3. Last-marker-wins when both present and past markers appear

**Key claims:**
- "Explicit lexical markers take priority; otherwise we fall back to verb-tense"
- "Both present and past — the clause closest to the end ('now') usually wins"

**Limitations:**
- Finite marker lists (11 present, 15 past)
- Only 17 irregular past verbs hardcoded
- No handling of future tense, conditional, subjunctive
- No handling of reported speech ("she said she was feeling good")
- Verb suffix heuristic: "-ed" catches regular past but not participle ambiguity ("I have finished")

---

### Lexicon.swift + lexicon.json (Vocabulary)

**Core themes:**
1. Hand-curated, category-organized vocabulary
2. ~650+ surface phrases across 30+ extraction targets
3. Mood words have explicit labels (low/flat/okay/good/great)
4. Energy/focus words map to ordinal levels (1-5)
5. Medications include brand names, generics, street names, and common typos

**Key observations:**
- Energy/focus lexicons are heavily skewed toward negative states: energySluggish (37) vs energyAlert (7); focusFoggy (39) vs focusPresent (6)
- This may reflect user base (ADHD patients report negative states more) or data bias
- Feelings list is relatively small (62) vs clinical emotion inventories (100s)
- Activities: 11 categories, surface-only matching
- Side effects: 29 cues, but many overlap with physical side effects (20 cues)

**Coverage gaps visible from eval errors:**
- "relieved", "recharged", "delighted" not in feelings list (seen in eval errors)
- "wading through wet sand" not in energySluggish
- "weight lifted off my shoulders" not in mood/feelings
- "agotado" (PT), "exausto" (PT) not recognized (multilingual gap)
- "caminé" (ES), "correr" (ES) not recognized as activities

---

### NoteExtraction.swift (Output Schema)

**Core themes:**
1. 20+ field extraction result with custom decoder for backward compatibility
2. Mood/energy/focus are scalar enums with ordinal numeric values (1-5)
3. Most other fields are arrays (sets with ordering)
4. Sleep has its own sub-struct with mentioned/hours/quality

**Design implications:**
- The scalar nature of mood/energy/focus makes them suitable for ordinal regression
- Set-valued fields (feelings, activities, etc.) are naturally multi-label classification problems
- Backward-compatible decoder suggests persistence and migration concerns

---

### PersonalLexiconBuilder.swift (User Overlay)

**Core themes:**
1. User corrections become personal lexicon entries
2. Only medications and feelings can be user-extended
3. Mood/energy/focus corrections are value changes, not phrase additions

**Limitations:**
- No mechanism for users to add new paraphrases for mood/energy/focus
- No feedback loop from review UI to lexicon improvement (other than med/feeling names)
- The overlay is append-only, no deduplication with base lexicon

---

## Cross-File Mapping

### Overlapping themes
- **Lexicon-dependent matching:** All extraction paths (mood, energy, focus, feelings, activities, side effects) share the same fundamental mechanism: CueMatcher tokenization + longest-match against pre-compiled lexicon. This is a single point of failure: paraphrase blindness affects ALL categories simultaneously.
- **Negation:** isNegatedBefore is used identically for mood, energy, focus, and all set categories. The crude window approach is a systemic weakness, not a category-specific one.
- **Temporal handling:** TenseClassifier affects mood aggregation only. Energy and focus do not use temporal weighting. This creates an asymmetry: "I was tired yesterday but great today" → mood=great (correct), but energy=? (depends on phrase length, not temporal anchor).

### Contradictions
- **Lemma policy contradiction:** Activities disable lemmas to prevent gerund polysemy, but feelings ENABLE lemmas to catch inflected forms. The system has no principled way to decide which categories benefit from lemma fallback — it's a manual tuning decision per category.
- **Tense policy contradiction:** Mood uses present-tense-wins (temporal), but energy/focus use strongest-match-wins (atemporal). The rationale (P1.2) is documented but not justified — it's an arbitrary choice that could be wrong for energy/focus narratives that span the day.

### Complementary information
- **Lexicon.swift + LexiconData.swift:** The hard-coded defaults are the fallback when JSON is missing; JSON is the reviewable/growable form. The dual representation ensures extraction never breaks but creates maintenance burden (must keep JSON and code in sync).
- **CueMatcher + NLNoteExtractor:** CueMatcher provides low-level matching primitives; NLNoteExtractor provides the high-level aggregation policy. This separation is clean but means aggregation policy is opaque to the matcher.
- **EvalMetrics + ExtractionEvalTests:** The metrics are simple but sufficient for regression. The floor system is a genuine ratchet — never lowered.

### Gaps (important aspects no file covers)
1. **No embedding/semantic similarity anywhere in the pipeline.** The entire system is surface-token-based.
2. **No contextual disambiguation beyond "feel" carrier phrases.** "Spent" (time vs money), "heavy" (emotional vs physical), "clear" (weather vs focus) have no general solution.
3. **No calibration or confidence scoring.** Every extraction is a hard decision with no uncertainty.
4. **No learning from errors.** The personal lexicon only captures med/feeling names, not extraction failures.
5. **No data augmentation or synthetic case generation.** The 40 eval cases are hand-written.
6. **No inter-annotator agreement measurement.** Ground truth is single-author.
7. **No systematic error categorization.** Errors are not classified (negation miss? paraphrase? trap word?).
8. **No runtime performance metrics.** No latency measurements, no memory profiling.
9. **No adversarial or robustness testing.** No tests for typos, ASR errors, disfluencies, code-switching.
10. **No dimensionality reduction or feature analysis.** We don't know which lexicon entries are high-value vs dead weight.

---

## Consolidated Theme List (for Phase 2 Dimension Decomposition)

1. **Paraphrase & semantic gap** — the fundamental limitation of surface matching
2. **Negation scope** — crude window vs. syntactic/semantic scope
3. **Ordinal signal calibration** — adjacent vs. polar miss, no confidence
4. **Lexicon engineering** — coverage, maintenance, bias, dead weight
5. **On-device ML feasibility** — Core ML, embeddings, small LLMs
6. **Contextual disambiguation** — general solution beyond "feel" carriers
7. **Temporal handling** — tense is only used for mood; other signals ignore time
8. **Multilingual** — PT/ES are zero-recall (but user wants English-only, so this becomes "future expansion")
9. **Evaluation methodology** — 40 cases, no subset analysis, no confidence intervals
10. **ASR error resilience** — fuzzy matching is minimal and med-only
11. **User feedback loop** — personal lexicon is too narrow
12. **Clinical validity** — does the taxonomy map to ADHD clinical measures?
