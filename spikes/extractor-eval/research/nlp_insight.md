# Insight Extraction: Cross-Dimension Synthesis

## Methodology

Insights are higher-level inferences that emerge from comparing findings across multiple dimensions. Each insight is supported by evidence from at least two dimensions and reveals a pattern not visible in any single dimension's findings.

---

## Insight 1: The Paraphrase Gap and Polysemy Gap Share a Single Root Cause — And a Single Fix

**Insight:** Your system's two biggest failure modes — missing paraphrases ("wading through wet sand" → sluggish) and false positives from polysemous words ("gym bag felt heavy" → sluggish) — are actually the same problem: the pipeline has no contextual disambiguation mechanism. Both failures arise because the system treats every word as a single sense. The same embedding-based fix solves both: contextual sentence embeddings can recognize that "wading through wet sand" is semantically close to "sluggish" (paraphrase recovery) AND that "gym bag felt heavy" is semantically distant from "feel heavy" (polysemy resolution).

**Derived From:**
- Dim 04 (Paraphrase): Semantic similarity to anchor sentences is the recommended paraphrase fix.
- Dim 11 (WSD): Contextual embeddings partially capture polysemy, and targeted embeddings on ~20-30 polysemous words would solve the false-positive problem.
- Dim 05 (On-device): Apple's NLContextualEmbedding (iOS 17+) provides exactly this capability with zero bundle size.

**Rationale:** The lexicon treats "heavy" as a single cue. But "heavy" has two senses: physical (gym bag) and emotional (feel heavy). A sentence embedding of "gym bag felt heavy" would not align with the embedding of "feel heavy" because the surrounding context words diverge. Similarly, "wading through wet sand" has no single-word overlap with "sluggish," but sentence-level embeddings could capture the shared semantic field. This means one architectural change (embedding fallback) fixes the two most visible error categories simultaneously.

**Implications:** This is the highest-impact architectural change. It is not "add ML to fix paraphrase" — it is "add semantic disambiguation to fix both paraphrase and polysemy at once."

**Confidence:** high

---

## Insight 2: The Negative-State Bias Is a Systemic Trap That Makes Both the Lexicon AND the Evaluation Lie to You

**Insight:** Your energy/focus lexicons have 5-6× more negative phrases than positive ones (energySluggish: 37 vs energyAlert: 7; focusFoggy: 39 vs focusPresent: 6). This is not just a coverage bug. Research shows depressed patients genuinely use more negative words, so the lexicon reflects real usage patterns. BUT the evaluation metrics treat a miss of "alert" identically to a miss of "sluggish" — there is no penalty for the system being blind to positive states. The combination of a negative-skewed lexicon AND nominal evaluation metrics creates a systemic trap: you could improve aggregate precision/recall by adding more negative words, while silently becoming even more blind to positive states.

**Derived From:**
- Dim 02 (Ordinal): Negative-state bias is a class-imbalance problem with known solutions (balanced data, focal loss, synthetic augmentation).
- Dim 08 (Lexicon): Depressed patients use more negative words (M=2.40 vs M=1.54), but LIWC-based models are outperformed by contextual LLMs for within-subject prediction.
- Dim 09 (Eval): Current metrics ignore ordinal ordering and class imbalance.

**Rationale:** If the eval only reports aggregate P/R, a system that predicts "sluggish" on every energy case would have high recall for the dominant class but zero recall for "alert" — and the metric would not flag this clearly. Distance-aware metrics (QWK, MAE) would penalize this behavior. Similarly, the lexicon's negative skew means the system is structurally biased toward detecting negative states. Even with perfect matching, a user describing a good day has fewer lexicon entries that could fire.

**Implications:** You need to fix BOTH the lexicon (add positive-state entries) AND the evaluation (add QWK/MAE/1-off metrics) to escape the trap. Fixing only one leaves the other masking the problem.

**Confidence:** high

---

## Insight 3: The Broken Feedback Loop Is the Biggest Missed Opportunity — And It Requires Zero ML

**Insight:** Your current eval shows mood/energy/focus have the most errors (mood P=0.75/R=0.60, energy R=0.25, focus P=0.40/R=0.333). But the PersonalLexiconBuilder only captures medication and feeling corrections. Every time a user corrects a mood/energy/focus label in the review UI, the system learns nothing for future extractions. Research on lexicon bootstrapping (double propagation, distributional semantics) shows that even small seed sets can be expanded automatically. This means you could close the feedback loop entirely with rule-based techniques — no ML, no embeddings, no model training.

**Derived From:**
- Dim 12 (Feedback): Pattern-based incremental learning (GEN) improves by 10%+ using corrected outputs as new seeds. Lexicon bootstrapping via double propagation expands from small seeds.
- Dim 08 (Lexicon): XLex methodology using transformers + SHAP automatically learned financial lexicons with accuracy improvements of 0.431-0.450.
- Dim 09 (Eval): Active learning reduces annotation burden by 1/3 — but the user's corrections are ALREADY annotations.

**Rationale:** The user's review UI is producing labeled data (transcript + corrected label) that is currently discarded for mood/energy/focus. If a user corrects "wading through wet sand" to energy=sluggish, that phrase should become a new entry in the lexicon (or at least a candidate for review). Over time, the most frequent corrections would naturally populate the lexicon with the expressions users actually use. This is a pure data problem, not a model problem.

**Implications:** Before investing in ML, invest in the feedback loop. It is the cheapest, highest-ROI improvement path. The app already has the UI; it just needs to persist corrections to the lexicon.

**Confidence:** high

---

## Insight 4: The 40-Case Eval Set and the 0.02 Precision Ratchet Are Methodologically Incompatible

**Insight:** Your evaluation system has a methodological paradox: the floor ratchet is set to observed_precision - 0.02 (e.g., mood floor = 0.730), meaning it is designed to detect 0.02 precision improvements. But with 40 cases and sparse labels (most cases have empty values for most categories), the statistical power to detect a 0.02 precision change is essentially zero. A single case changing from FP to TP or vice versa can swing precision by 0.05-0.10 on some categories. The ratchet gives false confidence that small improvements are measurable.

**Derived From:**
- Dim 09 (Eval): Clinical NLP test sets typically use 100-500 documents. Bootstrap CIs on 40 cases are too wide. The current set is a smoke test, not a benchmark.
- Dim 02 (Ordinal): Distance-aware metrics (QWK, MAE) are standard, but the current eval uses nominal P/R which treats adjacent and polar misses identically.
- Dim 08 (Lexicon): Even if you add 50 new lexicon entries, you cannot prove a 0.02 improvement with 40 cases.

**Rationale:** With 40 cases and 9 categories, the average category has ~4.4 non-empty labels. A single TP/FP/FN change on a category with 4 labeled cases changes precision by 0.25. The floor ratchet pretends to measure 0.02 precision improvements, but the noise floor is an order of magnitude larger. This means the evaluation infrastructure is lying about its own precision.

**Implications:** The floor system should be kept as a regression guard (don't break what works), but it should NOT be used to justify that small changes "improved" the system. You need a larger eval set (150-200 cases) and confidence intervals before making claims about precision improvements.

**Confidence:** high

---

## Insight 5: ADHD Speech Patterns Create a Unique ASR Problem That General NLP Doesn't Address

**Insight:** ASR error resilience research focuses on general dictation (phonetic drift, keyword ambiguity). But ADHD users exhibit specific speech patterns — pressured speech, tangential content, self-corrections, over-inclusive speech — that produce ASR errors of a different type: structural distortions (run-on sentences, dropped words, topic shifts) rather than simple phonetic substitutions. The current fuzzy matching (Damerau-Levenshtein distance=1) addresses phonetic errors on long medication names, but it cannot handle the structural errors that ADHD speech produces.

**Derived From:**
- Dim 06 (ASR): ADHD speech includes pressured, tangential, over-inclusive, and circumstantial speech (DSM-V, CADDRA, Li et al. 2024).
- Dim 06 (ASR): ASR errors are whole-word phonetic substitutions, but ADHD speech also produces structural distortions (run-on sentences, dropped words).
- Dim 04 (Paraphrase): Embedding-based methods are more robust to lexical overlap loss than surface matching.

**Rationale:** A user with ADHD might say: "I took my Concerta and then I was feeling like — no wait, actually I didn't take it yet, I was planning to but then I got distracted and now I feel like I'm floating but not in a good way, more like I'm just drifting." An ASR transcript might produce: "I took my concert and I was feeling like no way actually I didn't take it yet I was planning to but then I got distracted and now I feel like I'm floating but not in a good way more like I'm just drifting." The errors here are not phonetic ("Concerta" → "concert" IS phonetic, but the bigger issue is the run-on sentence and dropped punctuation). No amount of edit distance on single words can fix a run-on sentence. Only sentence-level semantic understanding (embeddings or clause parsing) can recover meaning from structurally garbled ASR output.

**Implications:** The ASR resilience strategy should shift from word-level fuzzy matching to sentence-level semantic matching. This is the same insight as #1 (paraphrase + polysemy share a fix) but applied to the ASR domain.

**Confidence:** high

---

## Insight 6: The Temporal Asymmetry (Mood Uses Tense, Energy/Focus Don't) Is a Cheap Fix With High Value

**Insight:** The pipeline uses TenseClassifier for mood aggregation (present-tense-wins) but ignores tense for energy and focus. Research validates that present-tense-wins is a correct linguistic principle. But energy and focus also vary across the day — "I was tired this morning but now I'm alert" should produce energy=alert, just as mood=good. The code to fix this already exists: TenseClassifier is built, temporal weight is computed, and the aggregation logic is identical. The only missing step is applying temporal weight to energyCandidates and focusCandidates.

**Derived From:**
- Dim 07 (Tense): Present-tense-wins is explicitly identified as a required linguistic capability (ACM 2024).
- Dim 07 (Tense): Clinical NLP anchors ALL events temporally, not just mood.
- Dim 07 (Tense): Mixed-tense sentences are a known challenge, but the current marker approach handles them adequately for short text.

**Rationale:** The asymmetry is a design choice documented in P1.2 ("mood = present-tense-wins, energy/focus = strongest-match-wins"), but the rationale is arbitrary. The literature suggests all subjective state signals should use temporal weighting. Implementing this requires ~3 lines of code change: append `temporalWeight` to energyCandidates and focusCandidates, then use `max(temporalWeight, phraseLength)` instead of `max(phraseLength)` for aggregation.

**Implications:** This is a zero-risk, low-cost improvement that aligns the system with clinical NLP standards. It should be tested immediately.

**Confidence:** high

---

## Insight 7: The System Ignores the Most Reliable Depression Marker — And It's Not a Content Word

**Insight:** Research shows first-person singular pronouns ("I", "me", "myself") are more reliable linguistic markers of depression than negative emotion words. A meta-analysis (k=21, N=3,758) found r=0.13 correlation. The current system is entirely content-word-based: it only looks at emotion words, medication names, and activity keywords. It completely ignores structural and functional markers (pronouns, tense distribution, sentence length, negation density). This means the system is missing the most predictive signals in the text.

**Derived From:**
- Dim 08 (Lexicon): First-person singular pronouns are more reliable depression markers than negative emotion words.
- Dim 10 (Clinical): ADHD patients show high first-person usage in self-narration (Reddit, blogs).
- Dim 01 (Mood): Short text is inherently limited; structural features may compensate.

**Rationale:** The user's preference for "flat - out - gone" short labels aligns with this finding: short entries have fewer content words, so the remaining signal is in structure. But the current pipeline discards all structural information. Adding pronoun density, tense distribution, or sentence complexity as auxiliary signals would require no lexicon expansion — just statistical features from the existing tokenization.

**Implications:** This is a long-term research direction, not a quick fix. But it suggests that the system's accuracy ceiling is lower than it could be because it ignores non-lexical signals.

**Confidence:** medium

---

## Insight 8: Competitors Don't Do NLP Extraction — But This Is Only an Advantage If Accuracy Is High Enough

**Insight:** Research on competitor apps (Daylio, Bearable, How We Feel) shows they all use structured manual entry (mood sliders, activity checkboxes, pre-defined taxonomies). None use NLP extraction with user-correctable feedback loops. This means whispernotes has a genuine whitespace — IF the extraction is accurate enough that users trust it and correct it rather than abandoning it. But the current eval shows focus precision is 0.40 and activities precision is 0.30. At this accuracy, users may distrust the extraction and either stop using the app or switch to manual entry.

**Derived From:**
- Dim 12 (Feedback): Competitors use manual entry; NLP extraction with corrections is whitespace.
- Dim 09 (Eval): Current precision on activities (0.30) and focus (0.40) may be below the trust threshold.
- Dim 10 (Clinical): Users prefer flexible simplicity but avoid logging negative moods.

**Rationale:** The value proposition of whispernotes is "natural language input → structured data." If the structured data is wrong 60-70% of the time on some categories, users will either correct everything (high friction) or stop using the feature. The feedback loop is only useful if the baseline accuracy is high enough that corrections are occasional, not constant. The current activities precision (0.30) suggests users are likely correcting more than half of activity extractions — this is unsustainable.

**Implications:** The priority should be improving precision on the worst categories (activities, focus) before expanding features. A system with high precision and moderate recall is more usable than one with moderate precision and low recall.

**Confidence:** high

---

## Insight 9: The User's "Extremely Short Natural Language" Preference Is Actually an Asset for NLP

**Insight:** The user prefers short labels like "flat - out - gone" over long descriptive sentences. This seems like a limitation (less signal), but it may be an asset. Short text is harder for general NLP, but for a narrow domain with a small lexicon, short text reduces ambiguity: fewer words means fewer chances for polysemy false positives. The research on short-text sentiment (SentiStrength 60.6% on 18.7-word comments) shows difficulty, but the app's domain is much narrower than general sentiment. The "flat - out - gone" style is actually closer to the app's lexicon entries ("flat", "out", "gone") than a long sentence would be.

**Derived From:**
- Dim 01 (Mood): Short informal text is inherently difficult, but the app has a narrow domain.
- Dim 11 (WSD): Microtext lacks context, but domain restriction reduces ambiguity.
- Dim 10 (Clinical): Users prefer simple entry but also nuanced capture.

**Rationale:** If users write "sluggish. heavy. can't start." — the system would actually perform well because every word is in the lexicon. The paraphrase problem ("wading through wet sand") arises from users who write longer, more descriptive entries. The solution is not to discourage long entries but to recognize that the user's own preference for short labels aligns with the system's strengths. This suggests the app should encourage concise expression rather than long narratives.

**Implications:** UX design should lean into short-form expression. The NLP pipeline should be optimized for 3-10 word entries, not 3-sentence paragraphs. This is a product insight, not just a technical one.

**Confidence:** medium

---

## Insight 10: The Medication Extraction Excellence (1.0/1.0) Masks a Design Principle That Should Be Applied Elsewhere

**Insight:** Medication extraction is nearly perfect because it uses a multi-layered approach: exact matching + fuzzy matching + regex + context gating + clause scoping + stoplist. This is exactly the kind of layered, defense-in-depth architecture that the other categories lack. Mood/energy/focus use only exact matching + negation. Activities use only exact matching. Feelings use exact matching + lemma fallback. The medication pipeline is the template; the other categories are the problem.

**Derived From:**
- Architecture audit: Medication extraction has 6 defensive layers (exact, fuzzy, regex, context, clause, stoplist).
- Architecture audit: Mood has 2 layers (exact, negation). Energy/focus have 2 layers (exact, negation). Activities have 1 layer (exact).
- Dim 06 (ASR): Context gating and stoplists are critical for precision.

**Rationale:** The medication pipeline's success is not because medication names are easier (they are, but only partly). It's because the pipeline treats medication extraction as a hard problem and throws multiple techniques at it. The other categories are treated as easy problems and get minimal defenses. Applying the same layered approach to mood/energy/focus — exact match → embedding fallback → hard-negatives filter → temporal weighting → clause scoping — would raise their accuracy to the medication level.

**Implications:** Don't invent new techniques for each category. Generalize the medication extraction architecture: exact match first, then fuzzy/semantic fallback, then context gates, then clause scoping, then stoplists/hard-negatives.

**Confidence:** high

---

## Summary: Insight Priority for Action

| Priority | Insight | Effort | Impact | Confidence |
|----------|---------|--------|--------|------------|
| 1 | Insight 3 (Fix feedback loop) | Low | Very High | High |
| 2 | Insight 1 (Embedding fallback) | Medium | Very High | High |
| 3 | Insight 6 (Temporal weighting for energy/focus) | Very Low | Medium | High |
| 4 | Insight 10 (Layered architecture) | Medium | High | High |
| 5 | Insight 2 (Fix eval metrics + lexicon bias) | Low | High | High |
| 6 | Insight 5 (ASR → sentence-level matching) | Medium | High | High |
| 7 | Insight 8 (Precision-first focus) | Low | High | High |
| 8 | Insight 4 (Expand eval set) | Medium | Medium | High |
| 9 | Insight 9 (Short-form UX) | Low | Medium | Medium |
| 10 | Insight 7 (Structural markers) | High | Medium | Medium |
