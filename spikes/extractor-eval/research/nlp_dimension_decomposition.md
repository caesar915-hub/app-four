# Dimension Decomposition: whispernotes NLP Deep Research

## Route: File-Augmented (Route D) — English-only focus

## 12 Research Dimensions

Each dimension approaches the ADHD text extraction problem from a distinct angle. Every dimension must investigate: current state, key evidence, tensions/counter-arguments.

---

### Dimension 01: Mood Detection from Short Text
**Angle:** Technical — How do rule-based lexicon, embedding similarity, and transformer classifiers compare for 1-3 sentence mood extraction?
**Scope:** Compare the current exact-match approach (68 mood phrases) against industry alternatives: sentiment analysis APIs, clinical depression detection (PHQ-9 text models), transformer-based emotion classification (GoEmotions, Ekman), and embedding similarity (Sentence-BERT). Focus on short-text accuracy (1-3 sentences), not document-level sentiment.
**Expected sources:** Academic papers on short-text emotion classification, clinical NLP surveys, GoEmotions dataset papers, sentiment analysis benchmarking.
**File context:** The current system rejects NLTagger sentiment due to negative bias on factual text. Need to verify if modern alternatives solve this.

---

### Dimension 02: Ordinal Signal Classification (Energy/Focus)
**Angle:** Technical — Mapping free text to ordinal scales (1-5): regression vs. classification, calibration, and distance-aware evaluation.
**Scope:** Current system treats energy/focus as exact-match scalar extraction. Research: ordinal regression techniques, how to handle "adjacent miss" vs. "polar miss", calibration of confidence, and whether learned models can map paraphrases to ordinal levels. Look at star-rating prediction, pain-scale text extraction, and clinical PROM (Patient-Reported Outcome Measure) text mapping.
**Expected sources:** Ordinal regression papers, clinical NLP for PROMs, star-rating prediction, VAS/NRS scale text extraction.
**File context:** Current eval treats 3→4 and 5→1 identically. Need research on distance-aware metrics for ordinal classification.

---

### Dimension 03: Clinical Negation Detection
**Angle:** Technical — Scope detection, syntactic parsing, and the gap between simple word lists and clinical negation systems.
**Scope:** Current system uses a 5-word window scan with a 5-token negation list. Research: NegEx, ConText, OpenNeg, and modern transformer-based negation detection (NegBERT, NegBio). How do these handle: "not only happy" (false flip), "no special energy focus" (false flip), "wasn't tired but exhausted" (intensification vs. negation). Also: scope resolution — how far does negation extend syntactically?
**Expected sources:** NegEx paper (Chapman 2001), ConText (Harkema 2009), NegBERT, BioNLP shared tasks on negation.
**File context:** The "no" token uses 1-word window to avoid "no special energy focus" false flip. This is a hack, not a principled solution.

---

### Dimension 04: Paraphrase & Semantic Similarity Beyond Lexicon
**Angle:** Technical — How to catch "weight lifted" → relieved, "wading through wet sand" → sluggish without explicit lexicon entries.
**Scope:** Current system is purely surface-based. Research: sentence embeddings (Sentence-BERT, USE), paraphrase detection (MRPC, Quora), semantic similarity for mental health (Depression detection via paraphrase), few-shot learning for new expressions, and on-device embedding feasibility (Core ML conversion, MLX). Also: word sense disambiguation for polysemous words ("heavy", "clear", "spent").
**Expected sources:** Sentence-BERT paper, USE paper, mental health paraphrase datasets, few-shot text classification, Core ML embedding deployment.
**File context:** EvalSet has 2 explicit paraphrase cases: "wading through wet sand" and "weight lifted off my shoulders" — both expected to fail. This is the single biggest recall gap.

---

### Dimension 05: On-Device NLP Constraints & Alternatives
**Angle:** Technical/Engineering — What can realistically run on an iPhone with privacy constraints?
**Scope:** Current system uses Apple NaturalLanguage. Research alternatives: spaCy (on-device?), ONNX Runtime (Core ML backend), Apple's MLX framework, quantized small LLMs (Phi-3, Llama-3.2-1B), Core ML conversion of PyTorch models. Trade-offs: latency, memory, accuracy, model size, thermal impact. Also: Apple's Neural Engine capabilities, what models Apple itself runs on-device (Live Text, Visual Look Up, etc.).
**Expected sources:** MLX documentation, Core ML tools guides, ONNX Runtime iOS, small LLM benchmarking (Phi-3, Gemma-2B), Apple silicon ML performance.
**File context:** The pipeline is explicitly designed for "no model download, instant, on-device." Any ML alternative must meet this bar.

---

### Dimension 06: Fuzzy Matching & ASR Error Resilience
**Angle:** Technical — Damerau-Levenshtein vs. phonetic similarity vs. neural spell-check for voice-note ASR errors.
**Scope:** Current system uses DL distance=1 for medications only. Research: ASR error patterns for mental health voice notes (disfluencies, self-corrections, ADHD-specific speech patterns), phonetic matching (Soundex, Metaphone, Double Metaphone), contextual spell-checking (neural: BERT-based, T5-based), and on-device speech recognition quality (Apple's ASR error rates). Also: how do ADHD voice notes differ from general dictation? (faster, more tangential, emotional dysregulation in speech patterns).
**Expected sources:** ASR error analysis papers, phonetic matching algorithms, neural spell-check (BertSpell, T5 spelling), ADHD speech characteristics research.
**File context:** "Conserta" → "Concerta" is the only tested ASR case. Fuzzy matching is medication-only and distance=1. Real ASR errors may be multi-edit and affect mood/energy/focus words too.

---

### Dimension 07: Tense & Temporal Expression Handling
**Angle:** Technical — Past-progressive filtering, temporal anchoring, and narrative time structure.
**Scope:** Current system classifies each sentence as present/past/neutral and uses present-tense-wins for mood. Research: temporal expression extraction (TimeML, TIMEX3), narrative timeline parsing, how clinical NLP handles temporal references ("yesterday I felt X but today I feel Y"), and whether energy/focus should also use temporal weighting. Also: handling of "I was feeling anxious on Monday. Today I'm calm." — current system works, but is it robust?
**Expected sources:** TimeML specification, TIMEX3 parsers, clinical temporal NLP, narrative medicine text analysis.
**File context:** Current system handles this with explicit markers and verb suffix. Only 17 irregular past verbs. "was feeling" is in pastMarkers. Tense is only used for mood aggregation.

---

### Dimension 08: Lexicon Engineering, Coverage & Maintenance
**Angle:** Engineering/Operational — Curated lexicon maintenance, bootstrapping, bias analysis, and coverage gaps.
**Scope:** Current system has ~650 phrases hand-maintained. Research: how to systematically grow a clinical lexicon (bootstrapping from corpora, user feedback loops, crowdsourcing), coverage analysis methods (what % of real user expressions are captured?), bias in vocabulary (overrepresentation of negative states), and maintenance burden (how many entries needed per 1% recall gain?). Also: synonym expansion strategies, WordNet/MedLex for clinical terms, and whether the current size is on par with clinical NLP systems.
**Expected sources:** Clinical lexicon construction papers, sentiment lexicon surveys (VADER, LIWC, SentiWordNet), coverage estimation methods, mental health vocabulary studies.
**File context:** Energy/focus lexicons are heavily skewed: energySluggish (37) vs energyAlert (7); focusFoggy (39) vs focusPresent (6). This suggests negative-state bias.

---

### Dimension 09: Evaluation Methodology for Sparse Extraction
**Angle:** Methodological — How to properly evaluate a system where most labels are empty most of the time.
**Scope:** Current eval: 40 cases, aggregate P/R, scalar wrong=FP+FN. Research: how many cases needed for statistical confidence (power analysis), distance-aware metrics for ordinal signals (Kendall's tau, Spearman, Earth Mover's Distance), subset analysis (negation cases, paraphrase cases, multi-clause cases), inter-annotator agreement for clinical text labels, and the challenge of "empty-allowed" evaluation (precision deflates when system is conservative, recall deflates when system is aggressive). Also: active learning for test set expansion.
**Expected sources:** Clinical NLP evaluation papers, IAA studies for mental health text, ordinal metric papers, power analysis for NLP evaluation, test set construction best practices.
**File context:** 40 cases is the eval set. Floors are ratcheted at observed-0.02. No confidence intervals. No per-case error analysis in the Swift test. No subset analysis.

---

### Dimension 10: ADHD-Specific Signal Taxonomy & Clinical Validity
**Angle:** Clinical/Domain — Does the extraction taxonomy map to clinically relevant ADHD measures?
**Scope:** Current taxonomy: mood, energy, focus, feelings, activities, sleep, meds, side effects, executive dysfunction, etc. Research: how does this map to validated clinical instruments (ADHD-RS, ASRS, BRIEF-A, PHQ-9, GAD-7, PSQI)? What signals do clinicians actually track? What is the evidence base for mood/energy/focus as useful ADHD self-monitoring dimensions? Also: comorbidity expression (anxiety, depression, sleep disorders) in ADHD text, and whether the current taxonomy captures the full clinical picture.
**Expected sources:** ADHD self-monitoring literature, patient-reported outcome measures (PROMs), mood/energy tracking in chronic illness, ADHD journaling studies, digital phenotyping for ADHD.
**File context:** The app is designed for ADHD patients. Clinical validity is implied but not explicitly validated against any instrument.

---

### Dimension 11: Contextual Disambiguation & Word Sense Resolution
**Angle:** Technical — General solutions for polysemous words that appear in both emotional and non-emotional contexts.
**Scope:** Current system handles "heavy" (emotional vs physical) via "feel" carrier phrases. But this is not general: "spent" (time vs money), "clear" (weather vs focus), "light" (mood vs weight vs rain), "lost" (emotional vs literal), "empty" (emotional vs fridge). Research: word sense disambiguation (WSD) techniques, context-aware matching, and whether modern embeddings implicitly solve this. Also: the "feel" carrier strategy is English-specific; how does it generalize?
**Expected sources:** WSD papers (WordNet Lesk, supervised WSD, BERT-based WSD), context-aware sentiment analysis, polysemy in emotion lexicons.
**File context:** EvalSet has trap cases: "gym bag felt heavy" (should NOT match), "fridge was empty" (should NOT match), "light rain" (should NOT match). The current solution is carrier-phrase hardcoding, not general disambiguation.

---

### Dimension 12: User Feedback Loop & Continuous Improvement
**Angle:** Product/Engineering — How can the system learn from user corrections without ML training?
**Scope:** Current system: PersonalLexiconBuilder only captures medication and feeling names from user corrections. Research: human-in-the-loop NLP, active learning for clinical text, user correction aggregation, error pattern mining from review data, and A/B testing frameworks for NLP improvements. Also: how do other apps (pillr, Bearable, Daylio) handle user feedback on extraction? What are the UX patterns for extraction review that maximize correction rate?
**Expected sources:** Human-in-the-loop NLP papers, active learning for clinical text, error mining from user feedback, competitor analysis of mood tracking apps.
**File context:** The review UI exists (ExtractionReviewView, ExtractionReviewViewModel) but the feedback loop only extends meds and feelings. Mood/energy/focus corrections are value changes, not lexicon additions.

---

## Dimension Map

| Dim | Angle | Primary Question | Key File Context |
|-----|-------|-------------------|------------------|
| 01 | Technical | What mood detection methods work for short text? | NLTagger sentiment rejected; exact lexicon only |
| 02 | Technical | How to map text to ordinal scales properly? | Adjacent miss = polar miss in current metrics |
| 03 | Technical | How do clinical negation systems work? | 5-word window, 5 negation tokens |
| 04 | Technical | How to catch paraphrases without lexicon entries? | 2 explicit paraphrase failures in eval |
| 05 | Engineering | What ML can run on-device with privacy? | No model download, instant, Apple-only |
| 06 | Technical | How to handle ASR errors in voice notes? | DL-distance=1, med-only |
| 07 | Technical | How to handle temporal references properly? | Only mood uses tense; 17 irregular verbs |
| 08 | Engineering | How to maintain and grow a clinical lexicon? | 650 phrases, hand-maintained, negative bias |
| 09 | Methodological | How to evaluate sparse extraction rigorously? | 40 cases, no CIs, no subsets |
| 10 | Clinical | Does the taxonomy map to clinical measures? | ADHD app, no validated instrument mapping |
| 11 | Technical | How to disambiguate polysemous words generally? | "feel" carrier phrases only |
| 12 | Product | How to build a learning feedback loop? | Only meds/feelings from user corrections |
