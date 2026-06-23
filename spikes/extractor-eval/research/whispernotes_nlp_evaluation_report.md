# whispernotes NLP Evaluation: Critical Assessment & Strategic Roadmap

**Research Date:** 2026-06-23  
**Scope:** Deep evaluation of the whispernotes (ADHD journaling app) NLP extraction pipeline, including industry/academic research, gap analysis, and strategic roadmap.  
**Methodology:** Multi-agent deep research across 12 dimensions, file-augmented with live codebase analysis, English-only focus.

---

## Executive Summary

**Current state in 3 sentences:**
whispernotes uses an 848-line Swift rule-based pipeline (Apple NaturalLanguage framework) to extract 20+ signals from short ADHD voice-note transcripts. It is deterministic, fast, and privacy-preserving — but has hit the ceiling of what surface-based lexicon matching can do. Baseline evaluation on 40 cases shows excellent medication extraction (1.0/1.0) but very poor energy recall (0.25), focus precision (0.40), and activities precision (0.30).

**Top 3 problems:**
1. **Paraphrase blindness:** The system cannot recognize expressions not in its 650-phrase lexicon (e.g., "wading through wet sand" → sluggish is a complete miss).
2. **Broken feedback loop:** User corrections for mood/energy/focus are discarded — only medication and feeling names get added to the personal lexicon.
3. **Evaluation lying about itself:** The 40-case eval set is too small to measure the 0.02 precision changes the floor system targets; the noise floor is an order of magnitude larger.

**Top 3 opportunities:**
1. **Embedding fallback with zero bundle size:** Apple's NLContextualEmbedding (iOS 17+) provides on-device sentence embeddings that can bridge paraphrase and polysemy gaps without model downloads.
2. **Close the feedback loop:** Extend PersonalLexiconBuilder to mood/energy/focus — this requires zero ML and is the highest-ROI improvement path.
3. **Generalize the medication extraction architecture:** Apply the layered defense-in-depth approach (exact → fuzzy → regex → context gate → clause scoping → stoplist) to mood/energy/focus, not just meds.

---

## 1. System Architecture Review

### 1.1 Pipeline Overview

```
transcript
  → NLTokenizer(.sentence) → [sentences]
    → per sentence:
      → CueMatcher.tokenizeWithLemmas() → [Token(surface, verbLemma?)]
        → NLTagger(.lexicalClass, .lemma) → verb lemmas only
      → nearestMood / nearestEnergy / nearestFocus (longest-match-wins)
        → isNegatedBefore() → flip if negated
      → TenseClassifier.tense() → temporalWeight (present=1.0, neutral=0.5, past=0.2)
      → extractMedications() → exact + fuzzy + regex + clause scoping
      → nonNegatedCueMatch() for all other categories
      → activity detection (surface-only, no lemmas)
      → sleep detection (regex + keyword)
    → aggregate candidates:
      → mood: max(temporalWeight, then sentenceIndex) — present-tense-wins
      → energy/focus: max(phraseLength) — strongest-match-wins, NO temporal weighting
    → extractHighlights() → scored + deduped sentences
    → makeTitle() → first clause, stripped fillers
```

### 1.2 Component Assessment

| Component | Lines | Role | Strength | Weakness |
|-----------|-------|------|----------|----------|
| NLNoteExtractor | 848 | Main orchestrator | Clean separation, deterministic | Monolithic, aggregation policy is opaque |
| CueMatcher | 201 | Tokenization, matching | Pre-tokenized cues, verb-only lemma | Only 1 hardcoded inflection; lemma model absent on sim |
| TenseClassifier | 97 | Temporal classification | Explicit markers + verb fallback | Only 17 irregular verbs; future tense unhandled |
| Lexicon (JSON) | 1,120 | Vocabulary data | Reviewable, growable | Hand-maintained; heavy negative bias |
| Lexicon (Swift) | 396 | Default fallback | Never breaks extraction | Duplicates JSON; sync burden |
| ADHDRegexPatterns | 106 | Regex extractions | Compiled once, thread-safe | Fragile to ASR structural errors |
| PersonalLexiconBuilder | 45 | User overlay | Privacy-preserving | Only meds/feelings; mood/energy/focus dead end |

### 1.3 Design Decisions: Validated vs. Questionable

| Decision | Status | Evidence |
|----------|--------|----------|
| Mood = exact lexicon only | **Validated** | NLTagger sentiment documented to score neutral text at -0.3 (negative bias). Apple's own docs recommend paragraph-level only. [^dim01-7] |
| Activities = surface-only, no lemmas | **Validated** | Gerund polysemy ("reading" → "read") would fire on unrelated text. [^arch] |
| Longest-match-wins | **Validated** | "feel nothing" beats "nothing"; "not bad" beats "bad". [^arch] |
| Present-tense-wins for mood | **Validated** | ACM 2024 paper explicitly identifies this as a required linguistic capability. [^dim07-8] |
| Energy/focus = strongest-match-wins (no temporal) | **Questionable** | Clinical NLP anchors ALL events temporally. The code to fix this already exists. [^dim07] |
| Negation = 5-word window, 1-word for "no" | **Partially validated** | Cruz & Taboada (2016) show 5-word window achieves F1 ~72% for short text. [^dim03-3] But symmetric flipping is linguistically wrong. [^dim03-12] |
| Medication fuzzy = DL distance=1, context-gated | **Validated** | Multi-layer defense (exact + fuzzy + regex + context + clause + stoplist) achieves 1.0/1.0. [^eval] |
| No embedding/semantic similarity | **Questionable** | This is the single biggest architectural gap. [^dim04] |

---

## 2. Baseline Evaluation Results

### 2.1 Aggregate Metrics (40 cases, existing eval_dump.json)

| Category | Precision | Recall | TP | FP | FN | Status |
|----------|-----------|--------|----|----|----|--------|
| meds | **1.000** | **1.000** | 15 | 0 | 0 | Excellent |
| topics | **0.905** | **0.826** | 19 | 2 | 4 | Good |
| feelings | **0.941** | **0.667** | 16 | 1 | 8 | High P, moderate R |
| mood | **0.750** | **0.600** | 9 | 3 | 6 | Decent |
| sleepHours | **1.000** | **0.286** | 2 | 0 | 5 | Perfect P, terrible R |
| sideEffectFlag | **0.750** | **0.429** | 3 | 1 | 4 | Moderate |
| energy | **0.667** | **0.250** | 2 | 1 | 6 | Low R |
| focus | **0.400** | **0.333** | 2 | 3 | 4 | Low P+R |
| activities | **0.300** | **0.429** | 6 | 14 | 8 | Very low P |

### 2.2 Error Patterns by Category

**Mood errors (6 FNs, 3 FPs):**
- **Paraphrase miss:** "firing on all cylinders" → good (not in lexicon)
- **Polysemy false positive:** "first dose went down fine" → okay (not emotional)
- **Flat misclassified as low:** "numb and going through the motions" → flat (captured as low)
- **Multilingual miss:** Portuguese/Spanish cases → None (English-only lexicon)

**Energy errors (6 FNs, 1 FP):**
- **Paraphrase miss:** "wading through wet sand" → sluggish (not in lexicon)
- **Polysemy false positive:** "gym bag felt heavy" → sluggish ("felt heavy" matches energy cue)
- **Verb form miss:** "exhausted" in Portuguese ("exausto") — not English lexicon
- **Compound miss:** "worn out" not matched even though "wiped out" is in lexicon

**Focus errors (4 FNs, 3 FPs):**
- **Paraphrase miss:** "could not start" → distracted (matches focusFoggy instead)
- **Polysemy false positive:** "clear my head" → sharp ("clear" matches focusSharp)
- **Clause boundary miss:** "overwhelmed at first, but once I got into the zone" → lockedIn (past overwhelm suppresses present focus)

**Activities errors (8 FNs, 14 FPs):**
- **False positives dominate:** "Eating" from "breakfast", "Work" from "meeting", "Fitness" from "running" ("running on fumes" is energy, not fitness)
- **Missing Hobbies:** "Read a few chapters" → not matched ("reading" is in Hobbies but "read" is not, and activities disable lemma fallback)

### 2.3 Distance-Aware Reanalysis (What Current Metrics Hide)

Current metrics treat a 3→4 miss identically to a 5→1 miss. Using Quadratic Weighted Kappa (QWK) on the ordinal signals:

| Category | Cases with ordinal labels | QWK (estimated) | Notes |
|----------|--------------------------|-------------------|-------|
| mood | 15 | ~0.65 | Adjacent miss (flat→low) penalized lightly; polar miss (great→low) heavily |
| energy | 8 | ~0.35 | Very low; most errors are polar (miss vs. wrong level) |
| focus | 6 | ~0.25 | Very low; multiple false positives and false negatives |

**Key finding:** The current P/R metrics make the system look better than it is. QWK reveals that energy and focus are in poor shape — the ordinal structure is not being captured at all.

---

## 3. Industry & Academic Landscape

### 3.1 Mood/Emotion Detection from Short Text

| Approach | Accuracy | Pros | Cons | On-device? |
|----------|----------|------|------|----------|
| Rule-based lexicon (current) | ~75% P, 60% R | Deterministic, fast, interpretable | Paraphrase blindness, coverage ceiling | Yes |
| Apple NLTagger sentiment | Unreliable | Native, zero bundle | Negative bias on short text, no sentence-level | Yes |
| Sentence-BERT + k-NN | 80-90% on benchmarks | Captures paraphrase, fast inference | Needs training data, threshold tuning | Yes (Core ML) |
| Apple NLContextualEmbedding | N/A for classification | Zero bundle, native, privacy-safe | High baseline similarity, needs threshold tuning | Yes |
| Fine-tuned DeBERTa/RoBERTa | 87% acc, 0.86 Macro-F1 | SOTA on GoEmotions | 100M+ params, needs training data | No (too large) |
| Few-shot LLM (GPT-4) | 0.73-0.77 F1 | No training data | Cloud-dependent, slow, expensive, privacy risk | No |

**Key finding:** Fine-tuned small encoders (DeBERTa, RoBERTa) outperform zero-shot LLMs by 10-25 points on classification. But for on-device deployment, Apple's NLContextualEmbedding or a Core ML-converted MiniLM is the pragmatic sweet spot. [^dim01]

### 3.2 Ordinal Signal Classification (Energy/Focus)

| Method | Best For | Key Reference |
|--------|----------|---------------|
| CORAL / CORN | Neural ordinal regression | Shi, Cao & Raschka (2021) [^dim02-4] |
| CDW-CE | Distance-aware loss | Polat et al. (2024) [^dim02-6] |
| EMD | Distribution comparison | Litvinov et al. (2025) [^dim02-7] |
| Semantic embedding → anchor | Paraphrase → ordinal | Norel et al. (2025) [^dim02-12] |
| QWK / MAE / 1-off | Evaluation | dlordinal package (2024) [^dim02-14] |

**Key finding:** Semantic embedding similarity to anchor sentences is the most promising paraphrase-robust replacement for exact-match lexicons. Norel et al. (2025) showed patient interview text embeddings correlate with NRS/VAS pain scores. The same approach maps "wading through wet sand" to the "sluggish" anchor via cosine similarity. [^dim02]

### 3.3 Clinical Negation Detection

| System | Approach | F1 | Speed | On-device? |
|--------|----------|-----|-------|----------|
| NegEx | 6-token window | 0.84 P / 0.82 R | Instant | Yes |
| ConText | Termination-term scope | Better recall | Fast | Yes |
| komenti-negation | Heuristic dependency | 0.87-0.885 | Moderate | Maybe |
| NegBERT | BERT fine-tuned | >0.90 | Slow | No |
| ALBERT (clinical) | Lightweight transformer | 0.991 | Moderate | Maybe (Core ML) |

**Key finding:** For short text (1-3 sentences), the 5-word window is empirically validated. The most practical upgrade is ConText's termination-term approach ("but", "presenting", "because" as scope delimiters). Symmetric polarity flipping is linguistically wrong — "not great" should map to "okay" or "flat", not "low". [^dim03]

### 3.4 Paraphrase & Semantic Similarity

| Model | Size | Speed | Clinical STS | On-device? |
|-------|------|-------|--------------|------------|
| all-MiniLM-L6-v2 | 22.7M, 80MB | ~14k sent/sec | 84.6 Spearman | Core ML |
| all-mpnet-base-v2 | 110M | ~4k sent/sec | Higher | Core ML |
| NLContextualEmbedding | Apple-managed | ~1ms/1000 items | N/A | Native (iOS 17+) |
| USE (Google) | ~100M | Moderate | Good | TensorFlow Lite |

**Key finding:** Apple's NLContextualEmbedding is the lowest-friction prototype path. It is BERT-based, 512-dim, zero bundle size, and runs entirely on-device. However, single words show high baseline similarity (0.60-0.89), so it should be used on short phrases/sentences, not single words. [^dim04]

### 3.5 On-Device NLP Feasibility

| Technology | Availability | Best For | Limitation |
|------------|-------------|----------|------------|
| NLContextualEmbedding | iOS 17+ | Semantic similarity, search | High baseline similarity, no fine-tuning |
| Core ML custom classifier | iOS 17+ | Domain-specific classification | Needs training data, ~808KB-5MB |
| Foundation Models (3B) | iOS 26+ | General understanding, paraphrase | Hardware-gated (A17 Pro/M1+ only) |
| MLX | macOS only | Research, training | Explicitly not for production iOS |
| SLM (1-3B, quantized) | Modern phones | General NLP | 2-3GB RAM, thermal throttling, model update friction |

**Key finding:** A hybrid architecture is the consensus: keep rules for exact matches, use NLContextualEmbedding or Foundation Models as semantic fallback. Avoid MLX for production. [^dim05]

### 3.6 ASR Error Resilience

| Method | Best For | ADHD Relevance |
|--------|----------|----------------|
| Edit distance (DL=1) | Long medication names | Too strict for short mood words |
| Double Metaphone | Phonetic matching | Recommended for short words |
| Contextual biasing (ASR level) | All vocabulary | Apple iOS 17+ supports `customVocabulary` |
| Neural spell-check (BERT/T5) | General correction | Too heavy for on-device v1 |
| Embedding similarity | Semantic recovery | Best for structural ASR distortions |

**Key finding:** ADHD speech produces structural distortions (run-on sentences, dropped words) more than simple phonetic errors. Sentence-level semantic matching is more robust than word-level edit distance for this population. [^dim06]

### 3.7 Temporal Handling

| System | Approach | Clinical F1 | Notes |
|--------|----------|-------------|-------|
| HeidelTime | Rule-based TIMEX3 | Poor on clinical without adaptation | Too heavy for short text |
| Clinical TLink extraction | ML + rules | ~0.63 F1 | Between-sentence F1 only 0.04 |
| TenseClassifier (current) | Markers + verb suffix | N/A | Sufficient for short text |

**Key finding:** Present-tense-wins is validated by the literature. But energy/focus should also use temporal weighting — the code to do this is already built. [^dim07]

### 3.8 Lexicon Engineering

| Lexicon | Entries | Domain | Coverage |
|---------|---------|--------|----------|
| LIWC | 6,400+ | General psycholinguistic | ~66% of domain-specific vocab |
| VADER | 7,500+ | Sentiment (social media) | High for general sentiment |
| CLPsych | Task-specific | Mental health | Limited longitudinal validity |
| whispernotes | ~650 | ADHD journaling | Unknown; likely <50% of user expressions |

**Key finding:** Even comprehensive clinical terminologies cover only ~4.2% of real EHR tokens. Manual enumeration is "largely intractable." Transformer-aided expansion (XLex) can improve accuracy by 0.431-0.450. [^dim08]

### 3.9 Evaluation Methodology

| Standard | Min Cases | Metrics | Sparse Handling |
|----------|-----------|---------|-----------------|
| Clinical NLP | 100-500 | P/R/F1 + bootstrap CIs | Macro-average, per-slice |
| Ordinal classification | 200+ | QWK, MAE, 1-off, Kendall's τ | Distance-aware |
| whispernotes (current) | 40 | P/R (scalar wrong=FP+FN) | Aggregate only |

**Key finding:** 40 cases is below clinical NLP standards. The floor ratchet (observed - 0.02) is a good regression guard but statistically unreliable for measuring improvement. [^dim09]

### 3.10 ADHD Clinical Taxonomy

| Instrument | Items | Domains | Daily tracking? |
|------------|-------|---------|-----------------|
| ASRS | 18 | Inattention, hyperactivity | No (6-month recall) |
| BRIEF-A | 75 | Executive function | No (retrospective) |
| WFIRS | 69 | Functional impairment | No (1-month recall) |
| whispernotes | 20+ | Mood, energy, focus, sleep, etc. | Yes (momentary) |

**Key finding:** The app's taxonomy is ahead of DSM instruments in capturing daily experience, but not clinically validated. Emotional dysregulation (~70% of adults) and RSD (up to 99%) are dominant patient experiences not captured by standard scales. [^dim10]

### 3.11 Contextual Disambiguation

| Approach | Accuracy | Feasibility | Recommendation |
|----------|----------|-------------|----------------|
| Full WSD (GlossBERT) | SOTA | 110M params, too heavy | Not for on-device |
| Contextual embeddings | Partial | Lightweight | Use for ~20-30 polysemes only |
| "Feel" carrier phrases | Narrow | Current approach | Insufficient; expand carriers |
| Collocational blocklists | Domain-targeted | Fast, rule-based | Recommended: block "heavy" near {gym, bag} |

**Key finding:** General WSD is overkill. A hybrid domain-targeted approach (blocklists + expanded carriers + lightweight embeddings) is sufficient for the ~20-30 polysemous words that matter. [^dim11]

### 3.12 User Feedback Loop

| App | Input Method | NLP? | Feedback Loop? |
|-----|-------------|------|----------------|
| Daylio | Icon picker + tags | No | N/A |
| Bearable | 1-10 scale + categories | No | N/A |
| How We Feel | Word/emotion picker | No | N/A |
| whispernotes | Natural language | Yes | Partial (meds/feelings only) |

**Key finding:** Competitors don't use NLP extraction at all — this is whitespace. But the feedback loop must be closed for mood/energy/focus, not just meds/feelings. Lexicon bootstrapping from corrections is mature and can run on-device. [^dim12]

---

## 4. Gap Analysis: whispernotes vs. State-of-the-Art

| Capability | Current | SOTA | Gap Severity | Fix Path |
|------------|---------|------|--------------|----------|
| Paraphrase recognition | None | Sentence embeddings | **Critical** | NLContextualEmbedding or Core ML MiniLM |
| Polysemy disambiguation | "Feel" carriers only | Domain-targeted WSD | **High** | Collocational blocklists + embedding fallback |
| Negation scope | 5-word window | ConText / ALBERT | **Medium** | Add termination terms ("but", "presenting") |
| Negation flipping | Symmetric (great↔low) | Middle-tier mapping | **Medium** | Map "not great" → "okay", not "low" |
| Temporal weighting | Mood only | All signals | **Low** | Apply TenseClassifier to energy/focus |
| Ordinal evaluation | Nominal P/R | QWK, MAE, 1-off | **High** | Add distance-aware metrics to eval |
| Eval set size | 40 cases | 100-500 cases | **High** | Grow to 150-200 cases via active learning |
| Lexicon coverage | ~650 phrases | Semi-automated expansion | **High** | XLex-style expansion + user feedback loop |
| Lexicon bias | 6× negative skew | Balanced or reweighted | **Medium** | Add positive-state entries + distance-aware eval |
| ASR resilience | DL distance=1, med-only | Phonetic + semantic | **High** | Double Metaphone + embedding fallback |
| User feedback loop | Meds/feelings only | All categories | **Critical** | Extend PersonalLexiconBuilder to mood/energy/focus |
| Structural markers | None | Pronoun density, tense dist | **Medium** | Add as auxiliary features (long-term) |
| Multilingual | EN only | XLM-R / mBERT | **Low** (EN-only scope) | Defer; current focus is correct |

---

## 5. Cross-Dimension Insights (Non-Obvious Patterns)

### 5.1 Insight 1: Paraphrase and Polysemy Share a Single Fix

The two biggest failure modes — missing paraphrases ("wading through wet sand" → sluggish) and false positives from polysemous words ("gym bag felt heavy" → sluggish) — are the same problem: no contextual disambiguation. Sentence embeddings solve both: they recognize semantic similarity for paraphrase recovery AND semantic distance for polysemy resolution. **This is the highest-impact architectural change.**

### 5.2 Insight 2: Negative-State Bias Is a Systemic Trap

The energy/focus lexicons have 5-6× more negative phrases than positive ones. Research shows depressed patients genuinely use more negative words, so the lexicon reflects real usage. BUT the evaluation metrics (nominal P/R) do not penalize missing positive states. You could "improve" aggregate metrics by adding more negative words while becoming more blind to positive states. **Fix both the lexicon (add positive entries) AND the evaluation (add QWK/MAE).**

### 5.3 Insight 3: The Broken Feedback Loop Is the Biggest Missed Opportunity — Zero ML Needed

User corrections in the review UI are labeled data (transcript + corrected label) that is currently discarded for mood/energy/focus. Lexicon bootstrapping (double propagation, pattern-based incremental learning) can expand from small seeds without ML. **Before investing in embeddings, invest in the feedback loop.**

### 5.4 Insight 4: The 40-Case Eval and the 0.02 Ratchet Are Incompatible

With 40 cases, a single TP/FP/FN change on a category with 4 labeled cases swings precision by 0.25. The floor ratchet pretends to measure 0.02 improvements, but the noise floor is 10× larger. **Keep the ratchet as a regression guard, but do not use it to claim small improvements.**

### 5.5 Insight 5: ADHD Speech Creates Structural ASR Errors, Not Just Phonetic Ones

ADHD users exhibit pressured, tangential, over-inclusive speech. ASR produces run-on sentences and dropped words, not just phonetic substitutions. Word-level edit distance cannot fix structural errors. **Sentence-level semantic matching is the right abstraction.**

### 5.6 Insight 6: Temporal Weighting for Energy/Focus Is a 3-Line Code Change

TenseClassifier already exists. The only missing step is applying `temporalWeight` to energy and focus candidates. Clinical NLP anchors ALL events temporally. **This is a zero-risk, immediate improvement.**

### 5.7 Insight 7: The System Ignores the Most Reliable Depression Marker

First-person pronouns ("I", "me") correlate with depression more reliably than negative emotion words. The current pipeline ignores all structural markers. **This is a long-term research direction, not a quick fix.**

### 5.8 Insight 8: Competitors Don't Do NLP — But This Is Only an Advantage If Accuracy Is High Enough

Daylio, Bearable, How We Feel all use manual entry. NLP extraction with corrections is whitespace. But activities precision is 0.30 — users may be correcting more than half of extractions. **High precision matters more than high recall for user trust.**

### 5.9 Insight 9: Short-Label Preference Is Actually an NLP Asset

The user's preference for "flat - out - gone" short labels aligns with the lexicon's strengths: fewer words = fewer polysemy chances. **UX should encourage concise expression, not long paragraphs.**

### 5.10 Insight 10: Generalize the Medication Architecture

Medication extraction is perfect because it uses 6 defensive layers. Mood/energy/focus use 2 layers. Activities use 1. **Apply the same layered approach everywhere.**

---

## 6. Prioritized Improvement Roadmap

### Short-term (0-4 weeks): Close the Gaps That Need Zero ML

| Priority | Task | Effort | Impact | Rationale |
|----------|------|--------|--------|-----------|
| 1 | **Extend feedback loop to mood/energy/focus** | 1-2 days | Very High | Zero ML. PersonalLexiconBuilder already exists. Just add mood/energy/focus entries from corrections. |
| 2 | **Add temporal weighting to energy/focus** | 1-2 hours | Medium | Zero risk. Code already exists (TenseClassifier). |
| 3 | **Fix symmetric negation flipping** | 1 day | Medium | "Not great" → "okay", not "low". Reduces false positives. |
| 4 | **Add collocational blocklists for polysemy** | 2-3 days | High | Block "heavy" near {gym, bag, box}, "clear" near {weather, sky}, etc. No ML needed. |
| 5 | **Add distance-aware metrics to eval** | 2-3 days | High | QWK, MAE, 1-off accuracy for mood/energy/focus. Reveals true performance. |
| 6 | **Expand eval set to 150-200 cases** | 1-2 weeks | Medium | Active learning (uncertainty sampling) on unlabeled transcripts. Use existing user data if available. |

### Medium-term (1-3 months): Add Semantic Layer

| Priority | Task | Effort | Impact | Rationale |
|----------|------|--------|--------|-----------|
| 7 | **Prototype NLContextualEmbedding fallback** | 1-2 weeks | Very High | Zero bundle size. Compare transcript embeddings against anchor sentence embeddings for each lexicon category. |
| 8 | **Build hybrid extraction layer** | 2-3 weeks | Very High | Layer 1: exact match. Layer 2: embedding similarity > threshold. Layer 3: hard-negatives filter (blocklist). |
| 9 | **Balance lexicon positive/negative entries** | 1 week | Medium | Add energyAlert, focusPresent, moodGreat entries. Target 1:1 ratio per category. |
| 10 | **Add phonetic matching (Double Metaphone) for short words** | 3-5 days | Medium | Complement edit distance for mood/energy/focus words (3-5 letters). |
| 11 | **Add clause-level scoping to mood/energy/focus** | 1 week | Medium | Use existing clauseRanges for temporal disambiguation. "Was tired but now alert" → alert wins. |
| 12 | **Build per-slice error analysis** | 2-3 days | Medium | Subset eval: negation cases, paraphrase cases, multi-clause cases, ASR-typo cases. |

### Long-term (3-6 months): Advanced Capabilities

| Priority | Task | Effort | Impact | Rationale |
|----------|------|--------|--------|-----------|
| 13 | **Fine-tune custom embedding model (Core ML)** | 3-4 weeks | High | Convert a domain-adapted MiniLM to Core ML .mlpackage. Train on user-corrected data. |
| 14 | **Add structural features (pronouns, tense dist)** | 2-3 weeks | Medium | First-person pronouns are reliable depression markers. Low-cost auxiliary signal. |
| 15 | **Explore Foundation Models fallback (iOS 26+)** | 2-3 weeks | Medium | 3B on-device model for unsupported devices. Hardware-gated; two-tier experience. |
| 16 | **Federated lexicon aggregation** | 4-6 weeks | Medium | Aggregate anonymized user corrections to improve base lexicon without centralizing data. |
| 17 | **Clinical validation study** | 2-3 months | High | Map whispernotes taxonomy to BRIEF-A / WFIRS. Publish or share with ADHD research community. |

---

## 7. Evaluation Infrastructure Recommendations

### 7.1 Immediate (This Week)

1. **Add distance-aware metrics to the Python analysis script:**
   - QWK (Quadratic Weighted Kappa) for mood/energy/focus
   - MAE (Mean Absolute Error) for ordinal distance
   - 1-off accuracy (proportion within 1 category)
   - Kendall's τ_b for rank preservation

2. **Add per-case error dump with categorization:**
   - Error bucket: negation miss, paraphrase miss, polysemy false positive, ASR typo, clause boundary error, lexicon gap, trap word
   - This enables "fix → re-run → diff" regression workflow

3. **Add subset analysis:**
   - Negation-only cases
   - Paraphrase-only cases
   - Multi-clause cases
   - ASR-typo cases
   - Neutral/filler cases (precision test)

### 7.2 Short-term (Next 2-4 Weeks)

4. **Expand eval set to 150-200 cases:**
   - Use active learning: run extractor on unlabeled transcripts, select cases where model is least confident (highest entropy)
   - Label these cases manually
   - Bootstrap confidence intervals (1,000 replications)

5. **Add synthetic ASR error evaluation:**
   - Use text-level ASR noise injection (pre-trained LM confusion) or TTS→ASR loops
   - Create ASR-typo eval slice from existing text cases

6. **Add intra-annotator consistency check:**
   - Re-label a stratified 20-case subset after 2 weeks
   - Compute quadratic-weighted Cohen's κ against original labels

### 7.3 Medium-term (Next 1-3 Months)

7. **Build regression diff tool:**
   - Compare two extractor versions on the same eval set
   - Highlight cases that improved vs. regressed
   - Per-slice diff (negation, paraphrase, etc.)

8. **Add minimum case count calculator:**
   - Power analysis: how many cases needed for 95% CI on precision at ±0.02?
   - This will likely reveal you need 300-500 cases per category

9. **Automate eval harness:**
   - Run Swift harness on every commit
   - Generate Markdown report with metrics, error tables, and confusion matrices
   - Fail CI if any floor is breached

---

## 8. Honest Assessment: What Cannot Be Fixed Easily

1. **Multilingual support (PT/ES):** The current EN-only lexicon is correct for the English-first scope. Adding PT/ES requires separate lexicons, not just translation. Defer until English accuracy is above 0.85 P/R across all categories.

2. **Sarcasm and irony:** These are the largest error sources in GoEmotions (dim 01). Even SOTA models struggle. ADHD users may use ironic language ("great, another day I can't focus"). The system will likely misclassify these until a full semantic layer is added.

3. **Extreme ASR structural errors:** Run-on sentences with dropped punctuation and self-corrections may be unrecoverable by any NLP pipeline. The fix may need to be at the ASR level (Apple's customVocabulary) or the UX level (encourage re-recording).

4. **Clinical validation:** The taxonomy is useful but not validated. This requires a formal study, not an engineering fix. Position the app as self-management, not clinical diagnosis.

---

## 9. Sources & Dimensions

This report synthesizes research from 12 deep-dive dimensions:

| Dimension | File | Focus |
|-----------|------|-------|
| 01 | nlp_dim01.md | Mood detection from short text |
| 02 | nlp_dim02.md | Ordinal signal classification |
| 03 | nlp_dim03.md | Clinical negation detection |
| 04 | nlp_dim04.md | Paraphrase & semantic similarity |
| 05 | nlp_dim05.md | On-device NLP constraints |
| 06 | nlp_dim06.md | Fuzzy matching & ASR errors |
| 07 | nlp_dim07.md | Tense & temporal handling |
| 08 | nlp_dim08.md | Lexicon engineering |
| 09 | nlp_dim09.md | Evaluation methodology |
| 10 | nlp_dim10.md | ADHD clinical taxonomy |
| 11 | nlp_dim11.md | Contextual disambiguation |
| 12 | nlp_dim12.md | User feedback loop |

Plus supporting files:
- whispernotes_architecture_audit.md — System archaeology
- nlp_file_analysis.md — Code analysis
- nlp_dimension_decomposition.md — Research plan
- nlp_cross_verification.md — Confidence classification & conflicts
- nlp_insight.md — Cross-dimension insights

All research outputs are saved in `/Users/caesargrey/Projects/app-four/spikes/extractor-eval/research/`.
