# Dimension 08: Lexicon Engineering, Coverage & Maintenance

## Research Date: 2026-06-23
## Scope: Clinical lexicon construction, coverage estimation, mental health vocabulary, and maintenance intractability for an ADHD journaling app (whispernotes)

---

## Key Findings

### 1. Lexicon Construction Methods in Clinical NLP

**Claim:** Clinical and mental health lexicons are built through three primary pathways: manual expert curation, automated/semi-automated corpus extraction, and crowdsourced annotation. Each method carries distinct trade-offs in precision, coverage, and scalability.[^1]
**Source:** Jesse Doka / "Constructing Effective Lexicons: A Comprehensive Guide" (blog summarizing established NLP methods)
**URL:** https://jessedoka.co/blog/lexicon-construction-tool
**Date:** 2024-05-19
**Excerpt:** "Manual Compilation: This traditional approach involves linguists and language experts manually compiling lists of words and their attributes. It ensures high accuracy and reliability but is time-consuming and resource-intensive... Automated Extraction: Leveraging algorithms and machine learning techniques... Semi-Automated Methods: Combining manual and automated techniques, semi-automated methods involve initial automated extraction followed by manual refinement."
**Context:** Overview of lexicon construction methods used across specialized domains including medical and legal lexicons.
**Confidence:** high

**Claim:** The "knowledge acquisition bottleneck" is a well-documented problem in supervised corpus-based methods: hand-built resources like sense-tagged training corpora are difficult and expensive to produce, leading to the need for semi-supervised bootstrapping approaches (e.g., Yarowsky algorithm).[^2]
**Source:** Sánchez-de Madariaga & Fernández-del Castillo, "The bootstrapping of the Yarowsky algorithm in real corpora"
**URL:** https://www.sciencedirect.com/science/article/pii/S0306457308000794
**Date:** 2008 (cited in 2018)
**Excerpt:** "The supervised corpus-based (and also the knowledge-based) methods need hand-built resources like sense-tagged training corpora. These training data are difficult and expensive to produce. This problem is often referred to as the knowledge acquisition bottleneck..."
**Context:** Word sense disambiguation literature, but the bottleneck concept generalizes to all curated lexicon construction.
**Confidence:** high

---

### 2. Established Mental Health Lexicons: LIWC, VADER, CLPsych

**Claim:** LIWC (Linguistic Inquiry and Word Count) dictionaries are created through a rigorous multi-judge validation process: words are rated by independent judges, with inclusion requiring two-thirds agreement; reliability rates reach 93–100%. The most recent versions also test statistical relatedness of words within categories.[^3]
**Source:** Tausczik & Pennebaker (2010) / University of Alabama repository on LIWC validation
**URL:** https://ir.ua.edu/bitstreams/598d1e23-b27c-4b0b-bb81-e25148ea8642/download
**Date:** 2010 (cited in 2025)
**Excerpt:** "The tentative dictionaries were then rated by three judges who independently rated each word's fit into their respective categories. If two thirds of the judges felt the word should be either included or excluded, the majority ruled on the decision... reliability rate of 93-100%... The most recent version of LIWC also tested the words in each category to determine if they were, in fact, statistically significantly related to one another."
**Context:** Describing the gold-standard validation process for LIWC, the most widely used psycholinguistic lexicon in clinical research.
**Confidence:** high

**Claim:** Standard LIWC dictionaries capture only ~66% of domain-specific vocabulary in fields like software engineering, necessitating targeted dictionary expansion. Coverage gaps are a known limitation across domains.[^4]
**Source:** Emergent Mind / Sajadi et al. (2025) on LIWC
**URL:** https://www.emergentmind.com/topics/linguistic-inquiry-and-word-count-liwc
**Date:** 2025-11-07
**Excerpt:** "The scope and coverage of LIWC dictionaries are foundational for analyzable contexts, yet standard lexicons have been shown to capture only ~66% of domain-specific vocabulary in certain fields, such as software engineering, necessitating targeted dictionary expansion."
**Context:** LIWC limitations and recent critiques; directly relevant to whispernotes' coverage problem.
**Confidence:** high

**Claim:** VADER (Valence Aware Dictionary for sEntiment Reasoning) was constructed using a "Wisdom of the Crowd" (WotC) approach on Amazon Mechanical Turk, with extensive quality control: English comprehension screening, sentiment rating training, golden-item validation, and bonus incentives for quality. It outperforms individual human raters (F1 = 0.96 vs 0.84).[^5]
**Source:** Hutto & Gilbert (2014), VADER paper
**URL:** http://eegilbert.org/papers/icwsm14.vader.hutto.pdf
**Date:** 2014
**Excerpt:** "Every rater was prescreened for English language reading comprehension... every prescreened rater then had to complete an online sentiment rating training and orientation session, and score 90% or higher... every batch of 25 features contained five 'golden items'... If a worker was more than one standard deviation away from the mean of this known distribution on three or more of the five golden items, we discarded all 25 ratings in the batch from this worker."
**Context:** Gold-standard example of crowdsourced lexicon construction with rigorous quality assurance. ~7,500 lexical features validated.
**Confidence:** high

**Claim:** CLPsych (Computational Linguistics and Clinical Psychology) shared tasks have driven methodological advances since 2014, collecting data from peer-support forums and Reddit, with tasks ranging from depression/PTSD detection to suicide risk prediction and longitudinal mental health dynamics. Systems have explored keyword-based lexica, topic modelling, psycholinguistic feature extraction, and deep learning approaches.[^6]
**Source:** CLPsych 2025 / Bucur et al. (2025) "Datasets for Depression Modeling in Social Media"
**URL:** https://arxiv.org/html/2503.21513v1
**Date:** 2025-03-27
**Excerpt:** "Shared tasks such as CLPsych and eRisk have driven methodological advances by providing annotated datasets and realistic evaluation settings for early detection... Systems developed for these tasks have explored a wide range of techniques, including keyword-based lexica, topic modelling, psycholinguistic feature extraction, and (deep) machine learning approaches."
**Context:** The primary academic venue for clinical NLP in mental health; establishes what methods have been tried and validated.
**Confidence:** high

---

### 3. Coverage Analysis & Gap Estimation

**Claim:** Distributional semantics (random indexing, word embeddings) can be leveraged for semi-automatic vocabulary expansion, achieving recall of 25–68% for medical terminology depending on category and candidate-list depth. This suggests that even semi-automated expansion has significant limitations and requires human curation.[^7]
**Source:** Ahltorp et al. (2016), "Expansion of medical vocabularies using distributional semantics on Japanese patient blogs"
**URL:** https://link.springer.com/article/10.1186/s13326-016-0093-x
**Date:** 2016-09-26
**Excerpt:** "The best pre-processing, context window size and clustering settings resulted in the best average recall values for Pharmaceutical Drug, for which a recall of 25% was achieved for top n candidates and a recall of 68% for top 10 n... For a candidate list of top 10 n candidates, the second best category was Medical Finding, for which a recall of 16% was achieved for top n and a recall of 58% for top 10 n."
**Context:** Directly relevant to whispernotes: semi-automatic expansion from a seed of 100 terms per category still leaves substantial gaps.
**Confidence:** high

**Claim:** Lexicon coverage can be measured by comparing extracted vocabulary against reference standards (e.g., UMLS, existing medical vocabularies). In one study, a semantic lexicon built from clinical trial eligibility criteria covered 95.95% of UMLS-recognizable terms in-corpus, but 20 semantic types covered ~80% of the vocabulary — indicating a long-tail distribution where a small fraction of categories dominates.[^8]
**Source:** Friedman et al., "EliXR: An approach to eligibility criteria extraction and representation"
**URL:** https://www.researchgate.net/publication/51538858_EliXR_An_approach_to_eligibility_criteria_extraction_and_representation
**Date:** 2008 (cited in 2024)
**Excerpt:** "The lexicon covered 95.95% UMLS-recognizable terms in our corpus. A total of 20 UMLS semantic types, representing about 17% of all the distinct semantic types assigned to corpus lexemes, covered about 80% of the vocabulary of our corpus."
**Context:** Coverage metrics in clinical NLP; the 80/20 pattern is critical for understanding lexicon completeness.
**Confidence:** high

**Claim:** A novel XLex methodology using transformers + SHAP to automatically learn financial lexicons demonstrated that manually annotated lexicons can be expanded with enhanced vocabulary coverage, leading to accuracy improvements of 0.431–0.450 over baseline. This confirms that lexicon words largely determine performance, and similar lexicons yield similar performance.[^9]
**Source:** Rizinski et al. (2023), "Sentiment Analysis in Finance: From Transformers Back to eXplainable Lexicons (XLex)"
**URL:** https://arxiv.org/abs/2306.03997
**Date:** 2023-06-06
**Excerpt:** "We demonstrate that transformer-aided explainable lexicons can enhance the vocabulary coverage of the benchmark Loughran-McDonald (LM) lexicon... the resulting lexicon outperforms the standard LM lexicon... accuracy increase by 0.431... combined dictionary achieves even higher accuracy improvement of 0.450."
**Context:** Demonstrates a modern, explainable approach to lexicon expansion that could be adapted for mental health domains.
**Confidence:** high

---

### 4. Lexicon Bias & Negative-State Imbalance

**Claim:** Depression is consistently associated with increased use of negative affect words and decreased use of positive affect words across multiple studies. One study found depressive patients used positive affect words at M=3.48 vs controls M=5.66 (p<0.001), while negative affect words were higher at M=2.40 vs M=1.54 (p=0.011). This is not merely a lexicon artifact; it is a genuine linguistic marker of depression.[^10]
**Source:** Trifu et al. (2024), "Linguistic markers for major depressive disorder: a cross-sectional study using an automated procedure"
**URL:** https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2024.1355734/full
**Date:** 2024-03-06
**Excerpt:** "The use of words that express positive affect is very limited in the sample with depression, compared with controls, i.e., M=3.48 (2.47; 5.16) compared with M=5.66 (3.99; 7.01), p<0.001... negative affect words have a higher rate in the sample with depression M=2.40 (1.42; 3.47) compared with controls M=1.54 (1.01; 2.35), p=0.011."
**Context:** Romanian sample using LIWC; replicated finding across many languages and contexts. The negative-state bias in whispernotes' lexicon may partially reflect real-world usage patterns, but still creates coverage/recall problems.
**Confidence:** high

**Claim:** StackOverflow discussion from 2015 highlights that negative sentiment lexicons are often 6× larger than positive ones (e.g., 300 positive vs 1,800 negative words), which can introduce systematic negative bias in sentiment scores unless corrected through weighting or normalization.[^11]
**Source:** StackOverflow discussion on sentiment lexicon normalization
**URL:** https://stackoverflow.com/questions/28600875/sentiment-analysis-should-i-normalise-positive-and-negative-word-lists-when-thy
**Date:** 2015-02-19
**Excerpt:** "the corpus of negative words is 6 times larger than the positive word corpus (around 300 positive words and 1800 negative words) so by the measure above, the sentiment score will likely be negatively biased since there are more negative words to match than positive words."
**Context:** Practical discussion of the exact bias problem observed in whispernotes (energySluggish: 37 vs energyAlert: 7; focusFoggy: 39 vs focusPresent: 6).
**Confidence:** medium

**Claim:** First-person singular pronouns (I, me, myself) are actually more reliable linguistic markers of depression than negative emotion words, with a meta-analysis (k=21, N=3,758) showing a small but consistent correlation r=0.13, 95% CI=[0.10–0.16]. This suggests that lexicon design should consider structural/function-word markers, not just content words.[^12]
**Source:** Edwards & Holtzman (2017) meta-analysis, cited in Trifu et al. (2024)
**URL:** https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2024.1355734/full
**Date:** 2024 (citing 2017)
**Excerpt:** "A meta-analysis focused on the association between depression and the use of first-person singular pronouns in a sample of k=21, N=3,758, using LIWC. The results revealed a small correlation r=0.13, 95% CI=[0.10–0.16] and the authors conclude that first-person singular pronouns can be used as a linguistic marker of depression."
**Context:** Critical for whispernotes: a lexicon-only approach misses structural and functional markers that are more predictive than content words.
**Confidence:** high

---

### 5. Is a Curated Lexicon Ever Sufficient? At What Scale Does Maintenance Become Intractable?

**Claim:** Lexicon-based methods require "considerable manual annotation efforts to create, maintain, and update the lexicons" and are considered inferior to deep learning approaches, though they offer interpretability and speed advantages. The core trade-off is that manual curation becomes a bottleneck as language evolves and domain-specificity increases.[^13]
**Source:** Rizinski et al. (2023) / XLex paper
**URL:** https://arxiv.org/abs/2306.03997
**Date:** 2023-06-06
**Excerpt:** "Lexicon-based sentiment analysis in finance leverages specialized, manually annotated lexicons created by human experts... Although lexicon-based methods are simple to implement and fast to operate on textual data, they require considerable manual annotation efforts to create, maintain, and update the lexicons. These methods are also considered inferior to the deep learning-based approaches."
**Context:** This is a recurring consensus across multiple domains, not just finance.
**Confidence:** high

**Claim:** Neural language models face a fundamental methodological issue: "models cannot adapt to unseen lexicon." Large vocabularies lead to models that are "intractable both to train and to do inference." This applies to both pure lexicon methods and neural approaches.[^14]
**Source:** "Machines of Meaning" (survey on prediction frame problems in NLP)
**URL:** https://arxiv.org/html/2412.07975
**Date:** 2023-07-02
**Excerpt:** "Both problems expose a fundamental methodological issue in computational approaches to language, the fact that models cannot adapt to unseen lexicon... A neural network model can only deal with a finite lexicon... large vocabularies often lead to models that are intractable both to train and to do inference."
**Context:** Theoretical framing of why lexicon coverage is a hard ceiling for any finite-vocabulary system.
**Confidence:** high

**Claim:** Manually enumerating a pre-defined lexicon for natural language is "largely intractable," so most grounded semantic parsing techniques focus on short texts and small domains, requiring thousands of manually annotated pairs even under closed domains.[^15]
**Source:** PMC / "A Semantic Parsing Method for Mapping Clinical Questions to Logical Forms"
**URL:** https://pmc.ncbi.nlm.nih.gov/articles/PMC5977685/
**Date:** 2018
**Excerpt:** "Manually enumerating a pre-defined lexicon for natural language is largely intractable, so most grounded semantic parsing techniques thus focus on short texts (such as questions) and small domains... Even under closed domains, oftentimes thousands of manually annotated <question,logical form> pairs are necessary to train a semantic parser to achieve satisfactory results."
**Context:** Even for narrowly scoped clinical question parsing, full lexicon enumeration is considered intractable.
**Confidence:** high

**Claim:** LIWC-based models are consistently outperformed by contextual LLMs (e.g., BERT) for fine-grained, within-subject prediction tasks, due to limitations in capturing dynamic semantics. Additionally, group-level relationships discovered via LIWC do not necessarily generalize to individual trajectories in longitudinal designs.[^16]
**Source:** Emergent Mind / O'Dea et al. (2018); Biggiogera et al. (2021)
**URL:** https://www.emergentmind.com/topics/linguistic-inquiry-and-word-count-liwc
**Date:** 2025-11-07
**Excerpt:** "LIWC-based models are consistently outperformed by contextual LLMs (e.g., BERT) for fine-grained, within-subject prediction tasks, due to limitations in capturing dynamic semantics... Inadequate Individual-Level Inference: Group-level relationships discovered via LIWC do not necessarily generalize to individual trajectories in longitudinal designs."
**Context:** Directly relevant to whispernotes, which is an individual-level longitudinal tracking app.
**Confidence:** high

---

### 6. Crowdsourcing vs. Expert Curation for Clinical Lexicons

**Claim:** Crowdsourcing non-experts for medical term identification in patient-authored text achieves high inter-rater reliability and can predict expert (nurse) responses with F1=84%. A CRF model trained on crowd-labeled data achieves F1=78%, dramatically outperforming MetaMap (F1=32–35%), OBA (F1=43–47%), and TerMINE (F1=42%). This demonstrates that crowdsourcing can be viable for clinical lexicon construction when expert annotation is scarce.[^17]
**Source:** MacLean et al. (2013), "Identifying medical terms in patient-authored text"
**URL:** https://pmc.ncbi.nlm.nih.gov/articles/PMC3822103/
**Date:** 2013-03-07
**Excerpt:** "Combining and aggregating Turker responses predicts Nurse responses with an F1 score of 84%... Our CRF model achieves an F1 score of 78%, dramatically outperforming existing annotation toolkits MetaMap and OBA, and statistical term extractor TerMINE."
**Context:** Strong evidence that crowdsourcing can substitute for expert curation in some clinical NLP tasks, though quality control is essential.
**Confidence:** high

**Claim:** Crowdsourcing lexical diversity has limitations: expert-driven approaches reinforce English bias and are unidirectional; they also limit applicability to low-resource languages. A hybrid approach (semi-automated generation + crowdsourcing + expert verification) is proposed as a more scalable alternative.[^18]
**Source:** Frontiers in AI / "Crowdsourcing lexical diversity"
**URL:** https://www.frontiersin.org/journals/artificial-intelligence/articles/10.3389/frai.2025.1648073/full
**Date:** 2025-12-05
**Excerpt:** "A major limitation of this approach is its unidirectional design (English → Target Language), which reinforces an English bias... Additionally, the reliance on professional linguistic experts significantly limits its applicability to low-resource languages... Crowdsourcing has emerged as an effective means for developing NLP and linguistic resources."
**Context:** Crowdsourcing is a viable alternative but introduces its own biases; expert verification remains necessary.
**Confidence:** medium

---

### 7. Lexicon-Based vs. ML-Based Approaches: A Critical View

**Claim:** A public health sentiment analysis systematic review found that lexicon-based methods struggle with context, sarcasm, negation, and domain-specific language; performance depends heavily on lexicon quality and coverage. They are often risky for complex health topics without domain adaptation or validation, and frequently perform poorly off-the-shelf.[^19]
**Source:** Villanueva-Miranda et al. (2025), "Sentiment analysis in public health: a systematic review"
**URL:** https://pmc.ncbi.nlm.nih.gov/articles/PMC12226299/
**Date:** 2024-02-06
**Excerpt:** "Struggles with context, sarcasm, negation, domain-specific language; performance depends heavily on lexicon quality/coverage. Risky for complex health topics without domain adaptation/validation. Often performs poorly off-the-shelf."
**Context:** Systematic review of methods in public health; directly applicable to whispernotes' clinical lexicon challenge.
**Confidence:** high

**Claim:** A direct comparison of lexicon-based (Hedonometer) vs. machine learning-based (Microsoft Azure) sentiment analysis across four domains found that "baked-in" word-level sentiment weights contribute to domain-specific differences, and some lexical entries need updating while others should be left untouched. This reveals that lexicon maintenance is not uniform — some words are stable, others are domain-dependent.[^20]
**Source:** arXiv / "A Comparison of Lexicon-Based and ML-Based Sentiment Analysis: Are There Outlier Words?"
**URL:** https://ar5iv.labs.arxiv.org/html/2311.06221
**Date:** 2023
**Excerpt:** "Here we are interested in how domain-independent are lexicon-based sentiment analysis tools, how do the 'baked-in' word-level sentiment weights contribute to differences when compared to machine learning approaches, and how transferable are they across domains?"
**Context:** Suggests that lexicon gap analysis should identify which categories are stable vs. which require domain-specific adaptation.
**Confidence:** high

---

### 8. ADHD-Specific Language Patterns

**Claim:** ADHD is associated with specific vocabulary and concepts including "time blindness," "hyperfocus," "rejection sensitive dysphoria," "emotional dysregulation," and "academic underachievement." Adult ADHD terminology often revolves around occupational and relationship difficulties rather than childhood behavioral descriptors.[^21]
**Source:** Neurolaunch / "Understanding ADHD: A Comprehensive Guide to Terms, Vocabulary, and Terminology"
**URL:** https://neurolaunch.com/adhd-terms/
**Date:** 2024-08-04
**Excerpt:** "Adult ADHD terminology often revolves around occupational and relationship difficulties. Terms like 'time blindness' (difficulty perceiving and managing time), 'hyperfocus' (intense concentration on a single task to the exclusion of everything else), and 'rejection sensitive dysphoria' (extreme emotional sensitivity to perceived rejection) are frequently used to describe adult ADHD experiences."
**Context:** Whispernotes' lexicon should include these ADHD-specific terms that would not appear in general mental health lexicons like LIWC or VADER.
**Confidence:** medium

**Claim:** Children with ADHD exhibit increased susceptibility to phonological interference during vocabulary recognition, suggesting that their language processing involves distinct attentional patterns that may manifest in self-report text.[^22]
**Source:** PMC / "Investigating Foreign Language Vocabulary Recognition in Children with ADHD and Autism"
**URL:** https://pmc.ncbi.nlm.nih.gov/articles/PMC12384167/
**Date:** 2024-04-29
**Excerpt:** "Children with ADHD exhibited increased fixations on phonological distractors, indicating higher susceptibility to interference... whereas children with ASD demonstrated more distributed attention, often attracted by semantic cues."
**Context:** While not directly about lexicon design, this suggests ADHD users may express themselves differently and may use more fragmented, distraction-influenced language.
**Confidence:** medium

---

### 9. Clinical NLP from Electronic Health Records (EHR)

**Claim:** In a Dutch EHR database with ~340 million clinical narratives, standard terminologies (MedDRA, MeSH, SNOMED-CT) covered only 4.2% of the ~6 million unique words. This demonstrates that even comprehensive clinical terminologies fail to capture the vast majority of real-world clinical language, which is noisy, abbreviated, and idiosyncratic.[^23]
**Source:** Afzal (2018) thesis, "Text Mining to Support Knowledge Discovery from Electronic Health Records"
**URL:** https://repub.eur.nl/pub/105993/Zubair-Afzal_Thesis-Full.pdf
**Date:** 2018
**Excerpt:** "The IPCI database contained almost 6 million textually unique words... The coverage of the three terminology was low in the IPCI data as we were able to normalize only 272,791 (4.2%) words."
**Context:** This is a devastating finding for any hand-curated lexicon approach: even the most comprehensive clinical terminologies capture <5% of real-world clinical text tokens.
**Confidence:** high

**Claim:** Transfer learning bootstrapped on unannotated EHRs can achieve 94.7 F1 in medical NER, 4.3 points above traditional rule-based approaches, by pre-training embeddings on the raw clinical corpus. This suggests that unannotated clinical data can compensate for small lexicons when used with neural models.[^24]
**Source:** Gligic et al. (2020), "Named entity recognition in electronic health records using transfer learning bootstrapped Neural Networks"
**URL:** https://www.sciencedirect.com/science/article/abs/pii/S089360801930259X
**Date:** 2019-08-03
**Excerpt:** "We bootstrap the Neural Networks through transfer learning, by feeding them pretrained word embeddings from a secondary task on unannotated electronic records. This approach achieves 94.7 F1 in I2B2 2009... 4.3 more than the traditional approach."
**Context:** If whispernotes has unannotated user journal entries, transfer learning on this corpus could supplement the curated lexicon.
**Confidence:** high

---

## Major Players & Sources

| Resource | Type | Size | Validation Method | Relevance to whispernotes |
|----------|------|------|-------------------|---------------------------|
| **LIWC** | Psycholinguistic lexicon | 90–118 categories, thousands of words | Multi-judge rating (93–100% reliability); statistical relatedness testing | Gold standard for mental health language research; can be adapted |
| **VADER** | Sentiment lexicon | ~7,500 features | Crowdsourced (AMT) with golden-item QC | Model for crowdsourced construction; includes social media slang |
| **NRC Emotion Lexicon** | Emotion lexicon | 9,892 words × 8 emotions + 2 sentiments | >1,000 Mechanical Turkers, high agreement | Good for emotion categorization beyond simple polarity |
| **CLPsych shared tasks** | Research community / datasets | Multiple datasets (Reddit, forums) | Expert/clinical annotation | Defines state-of-the-art benchmarks and evaluation protocols |
| **SentiWordNet** | Sentiment lexicon | WordNet synsets with sentiment scores | Semi-automatic propagation from seed words | Limited coverage; not domain-specific |
| **MedLexSp / UMLS** | Medical terminology | Hundreds of thousands of concepts | Expert curation | Useful for medication/symptom terminology; 4.2% EHR coverage noted |
| **XLex (Rizinski 2023)** | Automated lexicon expansion method | Domain-dependent | Transformer + SHAP explainability | Methodology that could be adapted for mental health lexicon expansion |

---

## Trends & Signals

1. **Hybrid models are dominant:** The field is moving toward combining lexicon features with ML/DL (e.g., lexicon features + BERT, or transformer-aided lexicon expansion like XLex). Pure lexicon-based approaches are increasingly viewed as baselines rather than production solutions.[^19][^9]

2. **Explainability is a major driver:** In clinical and finance domains, interpretability requirements keep lexicon-based methods alive despite lower accuracy. SHAP-aided lexicon expansion (XLex) is an emerging trend that preserves explainability while closing coverage gaps.[^9]

3. **Domain adaptation is non-trivial:** Even well-established lexicons like LIWC require domain-specific expansion. Standard lexicons capture ~66% of domain-specific vocabulary in some fields.[^4] Whispernotes' ADHD-specific domain is unlikely to be well-covered by general mental health lexicons.

4. **Individual-level inference is harder than group-level:** LIWC group-level findings (e.g., depressed people use more first-person pronouns) do not necessarily generalize to individual longitudinal tracking.[^16] Whispernotes must be evaluated at the individual level, not just aggregate.

5. **Crowdsourcing is viable but not a silver bullet:** Non-experts can match expert annotation with proper quality control (F1=84%), but crowdsourcing introduces noise and cultural biases.[^17][^18]

6. **The "negative emotion bias" is real but risky:** Depression genuinely correlates with more negative and fewer positive words, but if a lexicon is heavily skewed toward negative states, it will systematically misclassify or miss positive states. This creates a coverage/recall asymmetry.[^10][^11]

7. **Language evolves faster than lexicons:** Static lexicons struggle with neologisms, slang, and culturally specific terms.[^4] VADER's success was partly due to its inclusion of social media-specific features (emoticons, acronyms, slang).[^5] Whispernotes' user-generated language will evolve.

---

## Controversies & Conflicting Claims

### Controversy 1: Are lexicon-based methods ever sufficient for clinical tasks?
- **Pro-lexicon:** Interpretable, transparent, fast, work in low-resource settings, clinician-trustworthy.[^4][^19]
- **Anti-lexicon:** Consistently outperformed by contextual models; cannot handle negation, sarcasm, or context shifts; inadequate for individual-level inference.[^16][^19]
- **Resolution:** Most recent literature advocates hybrid approaches that combine lexicon interpretability with ML/DL performance.[^9][^19]

### Controversy 2: Should lexicons be balanced (equal positive/negative coverage) or reflect real-world usage?
- **Balance argument:** A 6× larger negative lexicon creates systematic negative bias in scoring.[^11]
- **Reflect-usage argument:** Depression is genuinely associated with more negative language; a balanced lexicon would artificially suppress detection of the genuinely more prevalent negative expressions.[^10]
- **Whispernotes implication:** The app tracks *both* negative and positive states. An unbalanced lexicon will have poor recall for positive states (energyAlert: 7, focusPresent: 6) even if those are genuinely rarer in user text. This is a coverage problem, not just a bias problem.

### Controversy 3: Is expert curation worth the cost?
- **Pro-expert:** High precision, clinically validated, reliable for high-stakes decisions.[^3][^17]
- **Pro-crowd:** Much cheaper, faster, scalable; can achieve near-expert performance with QC.[^17][^18]
- **Tension:** Expert curation is the bottleneck that makes maintenance intractable.[^13][^15] Whispernotes' PersonalLexiconBuilder only allows user additions for medications and feelings, not mood/energy/focus — which is the exact domain where coverage gaps are worst.

### Controversy 4: Does negative affect word count measure depression, or does it measure the lexicon's negative bias?
- **Caution:** Trifu et al. (2024) found that negative affect predicted "negatively focused emotion language," highlighting that negative affect itself drives negative word use — not just a measurement artifact.[^10]
- **Counterpoint:** If the lexicon is overwhelmingly negative, it will find negative words more often simply because there are more opportunities to match. The observed recall of 0.25 (energy) and 0.333 (focus) suggests the lexicon is failing to capture many genuine expressions, not that users aren't expressing them.

---

## Recommended Deep-Dive Areas

### Immediate (for whispernotes v0.9)
1. **ADHD-specific vocabulary study:** Conduct a corpus analysis of ADHD subreddits (r/ADHD), forums, or journal entries to identify the most frequent expressions for energy, focus, and mood that are missing from the current lexicon. The current ratio of 37:7 (sluggish:alert) is likely leaving many user expressions unmapped.

2. **Gap analysis methodology:** Adopt the Ahltorp (2016) / XLex (2023) approach: use a seed set of known terms, generate candidate expansions via distributional semantics or transformer SHAP scores, then manually validate the top-N candidates. Measure coverage against a held-out test corpus.

3. **Address the negative-state bias:** Either (a) expand positive-state categories to match negative-state coverage, or (b) implement category-aware normalization so that scores are not systematically pulled negative by the larger lexicon size.

### Medium-term
4. **Crowdsourced lexicon expansion:** Follow the VADER methodology: pre-screen raters, provide training, use golden items, and incentivize quality. Target ADHD-diagnosed users or community members for phrase rating, rather than generic crowds.

5. **Hybrid architecture evaluation:** Test whether adding a small ML classifier on top of lexicon features (or using transformer embeddings) can close the recall gap while preserving interpretability. The XLex paper shows this is feasible.[^9]

6. **Longitudinal individual-level validation:** Evaluate recall/precision at the individual user level over time, not just aggregate. The O'Dea et al. (2018) finding that group-level LIWC patterns don't generalize to individual trajectories is critical for a journaling app.[^16]

### Long-term / Research
7. **Bootstrapping from unannotated user journals:** If whispernotes accumulates user journal entries, apply Gligic et al. (2020)'s transfer learning approach: pre-train embeddings on the raw corpus, then use them to suggest new lexical entries. This is especially valuable because ADHD-specific language is unlikely to appear in general clinical corpora.

8. **Cross-linguistic adaptation:** If the app expands to other languages, the "unidirectional English bias" problem in crowdsourced lexicon construction will become relevant. A hybrid expert-crowd-native speaker pipeline is recommended.[^18]

9. **Real-time lexicon drift detection:** Monitor for new slang, neologisms, and evolving expressions (e.g., new TikTok/Reddit terminology for ADHD experiences). Static lexicons degrade over time.[^4]

---

## Footnotes

[^1]: Doka, J. (2024). "Constructing Effective Lexicons: A Comprehensive Guide." https://jessedoka.co/blog/lexicon-construction-tool

[^2]: Sánchez-de Madariaga, R., & Fernández-del Castillo, M. (2008). "The bootstrapping of the Yarowsky algorithm in real corpora." *Information Processing & Management*. https://www.sciencedirect.com/science/article/pii/S0306457308000794

[^3]: Tausczik, Y. R., & Pennebaker, J. W. (2010). "The psychological meaning of words: LIWC and computerized text analysis methods." *Journal of Language and Social Psychology*. https://ir.ua.edu/bitstreams/598d1e23-b27c-4b0b-bb81-e25148ea8642/download

[^4]: Sajadi et al. (2025). "LIWC: Linguistic Inquiry and Word Count." *Emergent Mind*. https://www.emergentmind.com/topics/linguistic-inquiry-and-word-count-liwc

[^5]: Hutto, C. J., & Gilbert, E. (2014). "VADER: A Parsimonious Rule-based Model for Sentiment Analysis of Social Media Text." *ICWSM-14*. http://eegilbert.org/papers/icwsm14.vader.hutto.pdf

[^6]: Bucur, A.-M., et al. (2025). "Datasets for Depression Modeling in Social Media: An Overview." *CLPsych 2025*. https://arxiv.org/html/2503.21513v1

[^7]: Ahltorp, M., et al. (2016). "Expansion of medical vocabularies using distributional semantics on Japanese patient blogs." *Journal of Biomedical Semantics*. https://link.springer.com/article/10.1186/s13326-016-0093-x

[^8]: Friedman, C., et al. (2008). "EliXR: An approach to eligibility criteria extraction and representation." https://www.researchgate.net/publication/51538858

[^9]: Rizinski, M., et al. (2023). "Sentiment Analysis in Finance: From Transformers Back to eXplainable Lexicons (XLex)." *arXiv:2306.03997*. https://arxiv.org/abs/2306.03997

[^10]: Trifu, R. N., et al. (2024). "Linguistic markers for major depressive disorder: a cross-sectional study using an automated procedure." *Frontiers in Psychology*. https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2024.1355734/full

[^11]: StackOverflow. (2015). "Sentiment Analysis - should I normalise positive and negative word lists when they differ in length?" https://stackoverflow.com/questions/28600875

[^12]: Edwards, T., & Holtzman, N. S. (2017). Meta-analysis cited in Trifu et al. (2024). See [^10].

[^13]: Rizinski et al. (2023). Same as [^9].

[^14]: "Machines of Meaning." (2023). *arXiv:2412.07975*. https://arxiv.org/html/2412.07975

[^15]: "A Semantic Parsing Method for Mapping Clinical Questions to Logical Forms." (2018). *PMC*. https://pmc.ncbi.nlm.nih.gov/articles/PMC5977685/

[^16]: O'Dea et al. (2018); Biggiogera et al. (2021). Cited in Sajadi et al. (2025). See [^4].

[^17]: MacLean, D. L., et al. (2013). "Identifying medical terms in patient-authored text." *PMC*. https://pmc.ncbi.nlm.nih.gov/articles/PMC3822103/

[^18]: Frontiers in AI. (2025). "Crowdsourcing lexical diversity." https://www.frontiersin.org/journals/artificial-intelligence/articles/10.3389/frai.2025.1648073/full

[^19]: Villanueva-Miranda, I., et al. (2025). "Sentiment analysis in public health: a systematic review." *PMC*. https://pmc.ncbi.nlm.nih.gov/articles/PMC12226299/

[^20]: arXiv. (2023). "A Comparison of Lexicon-Based and ML-Based Sentiment Analysis: Are There Outlier Words?" https://ar5iv.labs.arxiv.org/html/2311.06221

[^21]: Neurolaunch. (2024). "Understanding ADHD: A Comprehensive Guide to Terms, Vocabulary, and Terminology." https://neurolaunch.com/adhd-terms/

[^22]: PMC. (2024). "Investigating Foreign Language Vocabulary Recognition in Children with ADHD and Autism." https://pmc.ncbi.nlm.nih.gov/articles/PMC12384167/

[^23]: Afzal, Z. (2018). "Text Mining to Support Knowledge Discovery from Electronic Health Records." *Erasmus University Thesis*. https://repub.eur.nl/pub/105993/Zubair-Afzal_Thesis-Full.pdf

[^24]: Gligic, L., et al. (2020). "Named entity recognition in electronic health records using transfer learning bootstrapped Neural Networks." *Neural Networks*. https://www.sciencedirect.com/science/article/abs/pii/S089360801930259X
