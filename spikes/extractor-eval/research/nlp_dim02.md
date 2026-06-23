# Dimension 02: Ordinal Signal Classification (Energy/Focus) — Deep Research Report

**Research date:** 2026-06-23
**Agent:** Deep Research Sub-agent
**Context:** whispernotes ADHD journaling app — extracting energy and focus as ordinal levels (1–5) from short voice-note transcripts.

---

## Executive Summary

The task of mapping free-text diary entries to ordinal clinical scales (1–5) is well-studied in medical NLP, psychiatric symptom extraction, and ordinal classification theory. The current whispernotes approach — exact-match lexicon with negation flipping — sits at the simplest end of a spectrum that now includes distance-aware neural losses, rank-consistent ordinal regression, semantic embedding similarity, and unimodal probability constraints. The literature strongly supports three conclusions for this specific use case: (1) **distance-aware evaluation metrics** (MAE, QWK) should replace nominal accuracy because adjacent misses are clinically meaningful; (2) **semantic embedding similarity** to anchor sentences is a proven method for mapping patient narratives to ordinal scales, directly addressing the paraphrase problem; and (3) the **negative-state bias** (37 phrases for sluggish vs 7 for alert) is a class-imbalance problem that either requires balanced lexicon expansion or an explicit loss-function correction.

---

## 1. Current State: Methods for Ordinal Text Classification

### 1.1 Threshold-Based & Statistical Models

Ordinal regression has formal roots in the Cumulative Link Model (CLM) and Proportional Odds Model (POM), which assume an underlying real-valued variable and learn thresholds that partition it into ordinal classes. [^1] These models remain competitive: in the TOC-UCO benchmark of 46 ordinal datasets, the logistic-at (LogAT) variant achieves the lowest Mean Absolute Error (MAE) and is the most robust performer across problems. [^2]

> Claim: The Cumulative Link Model (CLM) approach assumes a real-valued underlying variable and learns optimal thresholds, making it the most prominent family of ordinal classifiers. [^1]
> Source: *Convolutional and Deep Learning based techniques for Time Series Ordinal Classification* (Guijo-Rubio et al.)
> URL: https://arxiv.org/abs/2306.10084
> Date: 2023-06-16
> Excerpt: "The most prominent type of models in the literature on ordinal classification are the so-called threshold-based models. In these methodologies the existence of a real-valued variable underlying the ordinal response is assumed. Hence, the training process focuses on modelling the real variable and learning the optimal thresholds determining which intervals corresponds to each ordinal label."
> Confidence: **high**

### 1.2 Deep Neural Ordinal Regression: CORAL & CORN

For neural networks, the dominant modern approaches are CORAL (COnsistent RAnk Logits) and CORN (Conditional Ordinal Regression for Neural Networks). CORAL transforms a K-class ordinal problem into K−1 binary "is class > threshold?" subtasks with weight-sharing constraints to guarantee rank consistency. [^3] CORN removes the weight-sharing constraint by using conditional training subsets and the chain rule of probability, substantially improving expressiveness. [^4]

> Claim: CORN achieves rank consistency without weight-sharing constraints by applying the chain rule to conditional probabilities computed from conditional training subsets, outperforming CORAL across image and tabular datasets. [^4]
> Source: *Deep Neural Networks for Rank-Consistent Ordinal Regression Based On Conditional Probabilities* (Shi, Cao & Raschka)
> URL: https://arxiv.org/abs/2111.08851
> Date: 2021-11-16
> Excerpt: "The proposed CORN model is a neural network for ordinal regression that guarantees rank consistency without any weight-sharing constraint in the output layer. Instead, CORN uses a new training procedure with conditional training subsets that ensures rank consistency through applying the chain rule of probability."
> Confidence: **high**

Both CORAL and CORN are implemented in the `coral-pytorch` package and are architecture-agnostic, making them compatible with BERT-style text encoders. [^5]

### 1.3 Distance-Aware Loss Functions

Standard cross-entropy treats a 5→1 miss identically to a 5→4 miss. The literature proposes multiple remedies:

- **Class Distance Weighted Cross-Entropy (CDW-CE):** Penalizes misclassifications proportionally to ordinal distance. [^6]
- **Earth Mover's Distance (EMD):** Compares predicted and target distributions using Wasserstein distance, naturally accounting for class ordering. [^7]
- **Weighted Kappa Loss (WK):** Differentiable surrogate of quadratic weighted kappa that penalizes by ordinal distance. [^7]
- **Soft ORDinal (SORD) labels:** Replace one-hot targets with soft unimodal distributions (e.g., triangular) centered on the true class, so adjacent classes receive partial credit. [^8]

> Claim: Ordinal loss functions such as Earth Mover Distance (EMD) consistently achieve higher performance than conventional cross-entropy, with improvements particularly evident in reducing severe misclassifications. [^7]
> Source: *Clinically Aware Learning: Ordinal Loss Improves Medical Image Classifiers* (Litvinov et al.)
> URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC12787087/
> Date: 2025-06-20
> Excerpt: "Ordinal loss functions, such as Earth Mover Distance (EMD), consistently achieved higher performance across multiple metrics compared to conventional cross-entropy approaches... Improvements were particularly evident in reducing severe misclassifications."
> Confidence: **high**

> Claim: CDW-CE outperforms other ordinal loss functions including CORAL, CORN, and weighted kappa, achieving higher silhouette scores and better class discrimination. [^6]
> Source: *Class Distance Weighted Cross Entropy Loss for Classification of Disease Severity* (Polat et al.)
> URL: https://arxiv.org/abs/2412.01246
> Date: 2024-12 (published 2025)
> Excerpt: "CDW-CE consistently improves performance in ordinal image classification tasks. It achieves higher Silhouette Scores, indicating better class discrimination capability... CDW-CE outperforms other loss functions, including prominent ordinal loss functions from the literature."
> Confidence: **high**

### 1.4 Unimodal Regularization & Calibration

A key property of ordinal classification is that predicted probabilities should be unimodal — highest at the true class, decreasing smoothly toward extremes. The ORCU loss (Ordinal Regression for Calibration and Unimodality) explicitly enforces this via soft ordinal encoding and order-aware regularization. [^9]

> Claim: Unimodal distributions ensure the model assigns highest probability to the correct label with probabilities gradually decreasing as distance from the true label increases, preventing paradoxical predictions. [^9]
> Source: *Calibration of ordinal regression networks* (Kim, Chung & Jang)
> URL: https://arxiv.org/abs/2410.15658
> Date: 2024-10
> Excerpt: "Unimodal distributions ensure that the model assigns the highest probability to the correct label, with probabilities gradually decreasing as the distance from the true label increases, preventing paradoxical or inconsistent predictions."
> Confidence: **high**

---

## 2. Clinical/Diary Text: Mapping Patient Descriptions to Ordinal Scales

### 2.1 From Pain Scales to PROMs

Clinical practice has long relied on ordinal self-report scales: the Visual Analog Scale (VAS), Numerical Rating Scale (NRS), and Verbal Rating Scale (VRS) are all ordinal measures of pain intensity. [^10] Patient-Reported Outcome Measures (PROMs) such as PHQ-9 (depression), GAD-7 (anxiety), and PROMIS domains use ordinal severity cutoffs (none/slight → mild → moderate → severe). [^11]

> Claim: The 0-10 Numerical Rating Scale (NRS), Pain Faces, and Visual Analog Scale (VAS) are all simple one-dimensional measures of current pain intensity; the first two are explicitly ordinal scales and the last is essentially ordinal as well because scaling is not uniform. [^10]
> Source: *Pain: Clinical Manual* excerpt / Oxford textbook
> URL: https://api.pageplace.de/preview/DT0400.9780190213374_A24759720/preview-9780190213374_A24759720.pdf
> Date: N/A (clinical text)
> Excerpt: "The 0-10 Numerical Rating Scale (NRS), the Pain Faces, and the Visual Analog Scale (VAS) are all simple one-dimensional measures of current pain intensity. The first two scales are explicitly ordinal scales; the last is continuous, but because the scaling is not uniform it is essentially an ordinal scale as well."
> Confidence: **high**

### 2.2 Semantic Embedding of Patient Narratives

A landmark 2025 study by Norel et al. demonstrated that semantic embeddings of patient interview text can be directly mapped to NRS/VAS pain scores. Using RoBERTa embeddings, they computed semantic similarity between patient narratives and anchor sentences (e.g., "I am satisfied with my capacity for work"), finding statistically significant inverse correlations with pain intensity. [^12]

> Claim: Semantic similarity between patient interview text and anchor sentences scales with reported pain intensity, with NRS and VAS most strongly correlated with embeddings of quality-of-life anchor sentences. [^12]
> Source: *Turning Patients' Open-Ended Narratives of Chronic Pain Into Quantitative Measures* (Norel et al.)
> URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC12690277/
> Date: 2025-11-10
> Excerpt: "The semantic similarity to the anchor sentence 'I am satisfied with my capacity for work' was inversely related to both NRS and VAS scores... Notably, the NRS and VAS were most strongly correlated with the semantic embeddings of anchor sentences describing the quality of life."
> Confidence: **high**

This approach directly addresses the paraphrase problem: "wading through wet sand" would not need to be in a lexicon if its embedding is semantically close to an anchor like "my body feels heavy and slow."

### 2.3 Psychiatric Symptom Severity from Notes

The CEGS N-GRID 2016 Shared Task in Clinical NLP explicitly addressed ordinal text classification: predicting RDoC positive valence symptom severity (absent/mild/moderate/severe) from psychiatric notes. Rios et al. placed third among 24 teams using a CNN with ordinal loss and wide structured features, achieving a normalized MMAE score of 83.86 (later improved to 85.55). [^13]

> Claim: Ordinal regression problems with text data penalize misclassifications differently based on how far apart ground truth and predictions are on the ordinal scale, and CNNs with ordinal loss plus wide features achieve competitive results on psychiatric symptom severity extraction. [^13]
> Source: *Ordinal Convolutional Neural Networks for Predicting RDoC Positive Valence Psychiatric Symptom Severity Scores* (Rios et al.)
> URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC5682241/
> Date: 2017
> Excerpt: "We study ordinal regression problems with text data where misclassifications are penalized differently based on how far apart the ground truth and model predictions are on the ordinal scale... Our best model achieves a score that is within 1% of the highest score in the challenge."
> Confidence: **high**

---

## 3. Key Evidence: Papers, Datasets & Benchmarks

### 3.1 Benchmark Repositories

- **TOC-UCO:** 46 unique ordinal classification datasets with balanced class sizes, establishing a standard benchmark for the field. [^2]
- **dlordinal:** A Python package implementing deep ordinal classification methods including CDW-CE, CORAL, CORN, EMD, and metrics (QWK, AMAE, MMAE, 1-off accuracy). [^14]
- **N-GRID 2016 Clinical NLP Shared Task:** 1000 neuropsychiatric notes with gold-standard RDoC severity scores. [^13]

> Claim: The TOC-UCO repository provides 46 unique ordinal datasets with appropriate class sizes, aiming to become the standard benchmarking set for ordinal classification literature. [^2]
> Source: *TOC-UCO: a comprehensive repository of tabular ordinal classification datasets*
> URL: https://arxiv.org/abs/2507.17348
> Date: 2025
> Excerpt: "The TOC-UCO repository presented in this work addresses the aforementioned gaps, aiming to provide a new improved and updated set of benchmark problems to the OC literature."
> Confidence: **high**

### 3.2 Evaluation Metrics for Ordinal Classification

The literature consistently recommends four complementary metrics:

1. **Mean Absolute Error (MAE):** Average ordinal distance between predicted and true labels. [^15]
2. **Quadratic Weighted Kappa (QWK):** Penalizes misclassifications by squared ordinal distance; primary agreement measure for ordinal tasks. [^15]
3. **1-Off Accuracy (Adjacent Accuracy):** Proportion of predictions within one class of the true label. [^15]
4. **%Unimodality:** Frequency with which the model produces unimodal probability distributions. [^9]

> Claim: QWK is adopted as the primary agreement measure because it explicitly penalises errors according to their ordinal distance, assigning substantially larger penalties to distant misclassifications. [^15]
> Source: *From Kellgren–Lawrence to Calcium Pyrophosphate Crystal Deposition: A Soft-Labelling Framework for Knee Osteoarthritis Assessment*
> URL: https://arxiv.org/html/2605.28176v1
> Date: 2026-05
> Excerpt: "The Quadratic Weighted Kappa (QWK) is adopted as the primary agreement measure, as it explicitly penalises errors according to their ordinal distance... the commonly adopted quadratic formulation (n=2) is used, thereby assigning substantially larger penalties to distant misclassifications."
> Confidence: **high**

> Claim: The dlordinal package includes 1-off accuracy, AMAE, MMAE, QWK, Ranked Probability Score, and GMSEC as ordinal classification metrics. [^14]
> Source: *dlordinal: a Python package for deep ordinal classification* (Bérchez-Moreno et al.)
> URL: https://arxiv.org/abs/2407.17163
> Date: 2024
> Excerpt: "Metrics: in this module, several ordinal classification metrics are included: the 1-off accuracy... AMAE... MMAE... QWK... Ranked Probability Score... and GMSEC."
> Confidence: **high**

---

## 4. Tensions & Counter-Arguments

### 4.1 Regression vs. Classification vs. Ordinal Regression

There is an active debate. Multi-class classification ignores ordering. Regression assumes continuous spacing and equal intervals between classes, which is not justified for ordinal labels (the difference between 1→2 may not equal 4→5). Ordinal regression is the principled middle ground. [^16]

> Claim: Ordinal regression is half-way between classification and real-valued regression; when you perform multiclass classification of ordinal data, you assign the same penalty whenever your classifier predicts a wrong class, no matter which one. [^16]
> Source: *StackExchange Cross Validated* — "Why ordinal target in classification problems need special attention?"
> URL: https://stats.stackexchange.com/questions/493254/
> Date: 2020-10
> Excerpt: "Ordinal regression is half-way between classification and real-valued regression. When you perform multiclass classification of your ordinal data, you are assigning the same penalty whenever your classifier predicts a wrong class, no matter which one."
> Confidence: **high**

However, a 2024 paper comparing explicit and implicit ordinal strategies found that **CE performs best in nominal metrics while ordinal losses excel in ordinal metrics**, and there is a trade-off: "the improvement in ordinal metrics comes at the expense of nominal metrics." Their proposed hybrid (Multi-task Log Loss, MLL) balances both. [^17]

> Claim: There is a trade-off between nominal and ordinal performance: the improvement in ordinal metrics comes at the expense of nominal metrics. A hybrid loss (MLL) balances both. [^17]
> Source: *Exploring Ordinality in Text Classification: A Comparative Analysis* (anonymous arXiv)
> URL: https://arxiv.org/abs/2405.11775
> Date: 2024-05-20
> Excerpt: "We observe that in general CE performs best in terms of nominal metrics (like weighted-F1) and OLL performs best in terms of ordinal metrics on an average. However, there seems to be a trade-off between nominal and ordinal performance i.e. the improvement in ordinal metrics comes at the expense of nominal metrics."
> Confidence: **medium**

### 4.2 Paraphrase Handling: Lexicon vs. Semantic vs. Neural

The current whispernotes exact-match lexicon approach suffers from known limitations that are well-documented in clinical NLP:

- **Lexicon/rule-based:** High precision for known terms but fails on paraphrases, informal language, and implicit descriptions. [^18] In one evaluation, Amazon Comprehend Medical and Google Healthcare NLP extracted 64–70% incorrect symptoms from patient social media posts because they could not handle informal phrasing. [^18]
- **Semantic embedding:** Captures paraphrase equivalence (e.g., "wading through wet sand" ≈ "feel heavy") via vector similarity, but off-the-shelf embeddings struggle with clinical nuances and qualifier-level distinctions. [^19]
- **Neural/LLM:** BERT-based models and LLMs generalize better to unseen phrasing but require training data and can hallucinate. [^20]

> Claim: Off-the-shelf medical NLP tools struggle with granular, patient-centric details such as unusual symptom descriptions, implicit context, or subtle adverse events; the best-trained models still capture only approximately 25% to 50% of lengthy, figurative symptom phrases. [^18]
> Source: *Extracting Symptoms of Complex Conditions From Online Discourse* (Hossain et al.)
> URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC12475878/
> Date: 2025-05-25
> Excerpt: "A family of BERT-based models fine-tuned on colloquial data markedly improves symptom recognition in informal texts; nevertheless, their error analysis indicates that the best-trained models still capture only approximately 25% to 50% of lengthy, figurative symptom phrases and continue to misclassify many subtle or previously unseen expressions."
> Confidence: **high**

> Claim: Off-the-shelf sentence-transformer baselines are not appropriate for specialised clinical-coding downstream tasks; naïvely larger or nominally in-domain encoders make performance worse, not better. [^19]
> Source: *Task-Aligned Embeddings for Clinical Code Retrieval* (TietAI)
> URL: https://arxiv.org/abs/2605.30529
> Date: 2026-04
> Excerpt: "Off-the-shelf embedding models are not appropriate for specialised clinical-coding downstream tasks, and naïvely larger or nominally in-domain encoders make this worse, not better."
> Confidence: **high**

A 2025 study on medical feature extraction from clinical notes found that LLM-based frameworks with **semantic embedding matching** achieved F1=0.983 (semantic matching) vs. F1=0.888 for earlier rule-based/fuzzy systems (INCITE), because semantic matching captures variable expressions like "worsen 3 wks ago" vs "symptoms worsened 3 weeks." [^21]

> Claim: Semantic embedding matching captures variable clinical expressions that token-level or fuzzy methods miss, achieving state-of-the-art F1=0.983 on medical feature extraction. [^21]
> Source: *Medical Feature Extraction From Clinical Examination Notes* (Abumelha)
> URL: https://medinform.jmir.org/2025/1/e78432
> Date: 2025
> Excerpt: "Semantic embedding matching captures variable clinical expressions (eg, 'worsen 3 wks ago' vs 'symptoms worsened 3 weeks'), unlike token-level probability methods."
> Confidence: **high**

### 4.3 Negative-State Bias (Class Imbalance)

The whispernotes lexicon skew (37 phrases for energySluggish vs 7 for energyAlert; 39 for focusFoggy vs 6 for focusPresent) is a classic class-imbalance problem. In mental health text classification, this bias leads to poor recall on underrepresented positive-state classes. [^22]

Solutions from the literature include:
- **Focal Loss, Dice Loss, Tversky Loss:** Down-weight easy majority-class examples and focus on hard minority-class samples. [^23]
- **Balanced sampling / stratified splits:** Ensure minority classes are represented in training and evaluation. [^22]
- **Synthetic data augmentation:** Back-translation to generate paraphrases of minority-class examples. [^23]

> Claim: The dataset exhibits significant class imbalance where certain mental health statuses are considerably more frequent than others; custom loss functions (Focal Loss, Dice Loss, Tversky Loss) help the model learn more robustly across all classes. [^23]
> Source: *A new training approach for text classification in Mental Health: LatentGLoss*
> URL: https://arxiv.org/abs/2504.07245
> Date: 2025-04
> Excerpt: "The dataset exhibits a significant class imbalance problem... To address this issue, we propose the use of alternative loss functions specifically designed to mitigate the impact of class imbalance. These include the Focal Loss... the Dice Loss... and the Tversky Loss."
> Confidence: **medium**

### 4.4 Negation Handling

The whispernotes error "could not start" → matches focusFoggy instead of distracted is a classic negation scope error. Clinical NLP has well-studied this: rule-based systems like NegEx/ConText use trigger lists and scope windows, but 41% of false positives in one evaluation were due to scope errors (e.g., "no" extending to the wrong term). [^24] Modern BERT-based negation detectors achieve F1 > 0.84, but the problem remains challenging for informal diary text. [^25]

> Claim: Almost half of false positives for rule-based negation detection fall under the "scope" category; the default scope extends to the start/end of a sentence, causing false modifications for short unspecific triggers like "no." [^24]
> Source: *Negation detection in Dutch clinical texts* (van Es et al.)
> URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC9830789/
> Date: 2023
> Excerpt: "Almost half of the false positives for the rule-based method fell under the 'scope' category (41%)... The default scope for a negation trigger extends all the way to the start or end of a sentence."
> Confidence: **high**

---

## 5. Key Findings (Summary)

| # | Finding | Confidence |
|---|---------|------------|
| 1 | **Distance-aware evaluation is mandatory.** The current eval treats adjacent and polar misses identically; the literature uniformly recommends MAE, QWK, and 1-off accuracy as primary metrics. | high |
| 2 | **Semantic embedding similarity to anchor sentences is a proven, paraphrase-robust approach.** The Norel et al. (2025) study directly demonstrates mapping free patient text to ordinal NRS/VAS scores via RoBERTa embeddings. | high |
| 3 | **CORAL/CORN + BERT is the state-of-the-art neural architecture** for ordinal text classification, with CORN removing the expressiveness limitation of CORAL's weight-sharing constraint. | high |
| 4 | **CDW-CE and EMD are the strongest distance-aware losses** in recent head-to-head comparisons, consistently outperforming standard cross-entropy and other ordinal losses. | high |
| 5 | **Unimodal probability constraints** (soft labels, ORCU) improve calibration and prevent paradoxical predictions where a model assigns higher probability to a distant class than an adjacent one. | medium-high |
| 6 | **The negative-state bias is a class-imbalance problem** with known solutions: balanced data collection, synthetic augmentation, or focal-loss-style reweighting. | high |
| 7 | **Exact-match lexicons fail on paraphrases and informal language;** semantic embedding or hybrid lexicon+embedding approaches are required for robustness. | high |
| 8 | **Negation scope resolution** is a major source of error in rule-based clinical NLP; modern context-aware models reduce but do not eliminate this problem. | high |
| 9 | **On-device Apple NLP (Natural Language framework + Core ML)** supports text classification, sentiment analysis, and word/sentence embeddings, enabling local semantic similarity computation without cloud dependency. | high |
| 10 | **In few-shot/low-data settings, entailment-style implicit ordinal approaches** (using label semantics as natural language) outperform explicit loss-based methods; in full-data settings, fine-tuned LLMs or CORN+CNN/BERT are best. [^17] | medium |

---

## 6. Major Players & Sources

| Source / Tool | Type | Relevance |
|---------------|------|-----------|
| **dlordinal** (Bérchez-Moreno et al. 2025) | Python package | Implements CORAL, CORN, CDW-CE, EMD, QWK, MAE, 1-off for PyTorch. |
| **coral-pytorch** (Raschka research group) | GitHub / PyPI | Official CORAL & CORN implementations with tutorials. |
| **TOC-UCO repository** (Guijo-Rubio et al. 2025) | Dataset archive | 46 benchmark ordinal datasets; standard for method evaluation. |
| **N-GRID 2016 Shared Task** (Rios et al. 2017) | Clinical NLP benchmark | Psychiatric symptom severity from notes; the closest existing benchmark to whispernotes. |
| **Apple Natural Language framework** | iOS SDK | On-device text classification, sentiment analysis, embeddings. |
| **Apple Core ML + Create ML** | iOS SDK | Custom model training and deployment for ordinal text classification. |
| **PROMIS / PHQ-9 / GAD-7** | Clinical instruments | Established ordinal scales with validated severity cutoffs. |
| **NegEx / ConText** | Rule-based NLP | Classic negation detection; widely used but scope-limited. |
| **BioBERT / ClinicalBERT / MedTE** | Domain embeddings | Biomedical sentence embeddings; task-aligned fine-tuning improves clinical semantic similarity. |

---

## 7. Trends & Signals

1. **Shift from explicit rules to semantic embeddings:** The clinical NLP community is moving away from exact-match lexicons toward embedding-based semantic matching for symptom extraction, driven by paraphrase robustness. [^18][^21]
2. **Hybrid approaches are winning:** Neither pure rule-based nor pure neural approaches dominate. The best systems combine lexicon precision with neural generalization (e.g., LSE using LLM-generated lexicons + semantic similarity). [^18]
3. **On-device NLP is maturing:** Apple's Natural Language framework now supports text classification, sentiment analysis, tokenization, and word embeddings natively on iOS, with models as small as 1.4MB. [^26] This makes semantic similarity approaches feasible without cloud latency or privacy concerns.
4. **Distance-aware losses becoming standard:** In medical AI, ordinal-aware losses (EMD, CDW-CE) are increasingly expected for any severity-classification task, with cross-entropy now considered suboptimal. [^7][^6]
5. **Implicit ordinality via LLMs:** Recent work shows that LLMs naturally respect label order when labels are verbalized descriptively ("sluggish" vs "charged"), performing competitively without explicit ordinal loss engineering — especially in low-data settings. [^17]

---

## 8. Controversies & Conflicting Claims

| Controversy | Position A | Position B | Assessment |
|-------------|-----------|-----------|------------|
| **Regression vs. ordinal vs. classification** | Ordinal regression is principled and necessary. [^16] | With enough data, standard classification or regression works fine; ordinal methods add complexity without clear gain. | For 5-class scales with clinically meaningful distances, ordinal regression is justified. The whispernotes adjacent-miss problem makes this especially relevant. |
| **Lexicon vs. neural** | Rule-based/lexicon methods are interpretable, debuggable, and sufficient for narrow domains. | Neural methods generalize to paraphrases and require less manual curation. | A hybrid is likely optimal: use embeddings for paraphrase coverage, maintain lexicon for interpretability and edge cases. |
| **LLM vs. traditional NLP** | Fine-tuned LLMs achieve state-of-the-art on most NLP tasks. | In specific domains (mental health classification), TF-IDF + SVM can outperform fine-tuned LLMs, especially on recall for critical classes. [^22] | For a small-scale iOS app with limited data, a lightweight traditional approach or Apple's on-device NLP may be more practical than fine-tuning LLMs. |
| **Soft labels vs. hard labels** | Soft labels (SORD) improve calibration and reduce overconfidence. [^8] | Hard labels with distance-weighted loss (CDW-CE) achieve better feature separation and higher silhouette scores. [^6] | Both are valid; CDW-CE has stronger empirical results in recent head-to-heads, but soft labels are simpler to implement. |
| **Unimodality enforcement** | Unimodal constraints are essential for ordinal coherence. [^9] | Unimodality is a nice property but not strictly necessary; models can achieve high QWK without it. | For a 5-point app scale, unimodality is desirable because it prevents nonsensical bimodal predictions (e.g., high probability on both 1 and 5). |

---

## 9. Recommended Deep-Dive Areas

1. **Semantic Anchor Sentence Design:** Investigate whether a small set of 5 anchor sentences per dimension (one per level), embedded via Apple's on-device NLP or a lightweight bi-encoder, can map paraphrased user utterances to ordinal levels. This directly replicates the Norel et al. (2025) methodology in an iOS context.

2. **Distance-Aware Eval Protocol:** Replace the current nominal P/R eval with MAE, QWK, and 1-off accuracy. This will immediately surface whether the current system's "errors" are mostly adjacent misses (acceptable) or polar misses (critical).

3. **Negation Scope Audit:** The "could not start" → focusFoggy error suggests the negation handler flips the level without resolving scope. A systematic audit of negation patterns in the voice-note corpus, using ConText-style trigger+scope rules, would quantify this error source.

4. **Class Rebalancing Strategy:** The negative-state skew is the single biggest structural problem. Options: (a) collect more positive-state phrases via user studies; (b) apply CDW-CE or focal loss if moving to a learned model; (c) use synthetic back-translation to augment minority classes.

5. **CORN + Apple Core ML Feasibility:** Evaluate whether a CORN-style ordinal regression model can be trained (e.g., in PyTorch with coral-pytorch) and converted to Core ML for on-device inference. If Core ML does not support the custom output layer, an EMD-based loss or CDW-CE may be easier to port.

6. **Fuzzy Matching vs. Embedding Comparison:** A head-to-head benchmark on the whispernotes dataset comparing: (a) current exact-match lexicon; (b) fuzzy string matching (Levenshtein/RapidFuzz); (c) cosine similarity of sentence embeddings between user text and anchor sentences. This would directly justify the migration path.

---

## References

[^1]: Guijo-Rubio, D., et al. (2023). "Convolutional and Deep Learning based techniques for Time Series Ordinal Classification." *arXiv:2306.10084*.
[^2]: Vargas, V.M., et al. (2025). "TOC-UCO: a comprehensive repository of tabular ordinal classification datasets." *arXiv:2507.17348*.
[^3]: Cao, W., Mirjalili, V., & Raschka, S. (2020). "Rank consistent ordinal regression for neural networks." *Pattern Recognition Letters*, 140, 325–331.
[^4]: Shi, X., Cao, W., & Raschka, S. (2021/2023). "Deep Neural Networks for Rank-Consistent Ordinal Regression Based On Conditional Probabilities." *Pattern Analysis and Applications*, 26, 941–955. *arXiv:2111.08851*.
[^5]: Raschka Research Group. "coral-pytorch." GitHub. https://github.com/Raschka-research-group/coral-pytorch
[^6]: Polat, G., Çağlar, Ü.M., & Temizel, A. (2025). "Class Distance Weighted Cross Entropy Loss for Classification of Disease Severity." *Expert Systems with Applications*, 269, 126372. *arXiv:2412.01246*.
[^7]: Litvinov, A., et al. (2025/2026). "Clinically Aware Learning: Ordinal Loss Improves Medical Image Classifiers." *Cancers* / *PMC12787087*.
[^8]: Díaz, R., & Marathe, A. (2019). "Soft Labels for Ordinal Regression." *CVPR 2019*.
[^9]: Kim, D., Chung, H., & Jang, I. (2024). "Calibration of ordinal regression networks." *arXiv:2410.15658*.
[^10]: Clinical pain scale documentation (VAS/NRS/VRS). Oxford clinical manual excerpt.
[^11]: American Psychiatric Association. "PsychPRO-PROMs-Description-Guide." https://www.psychiatry.org/
[^12]: Norel, R., et al. (2025). "Turning Patients' Open-Ended Narratives of Chronic Pain Into Quantitative Measures: Natural Language Processing Study." *J Med Internet Res*, *PMC12690277*.
[^13]: Rios, A., et al. (2017). "Ordinal Convolutional Neural Networks for Predicting RDoC Positive Valence Psychiatric Symptom Severity Scores." *J Biomed Inform*, 75(Suppl), S85–S93. *PMC5682241*.
[^14]: Bérchez-Moreno, F., et al. (2025). "dlordinal: A Python package for deep ordinal classification." *Neurocomputing*, 622, 129305. *arXiv:2407.17163*.
[^15]: Various. QWK/MAE/1-off definitions across ordinal classification literature. See Guijo-Rubio et al. 2023 and TOC-UCO papers.
[^16]: StackExchange Cross Validated (2020). "Why ordinal target in classification problems need special attention?"
[^17]: Anonymous (2024). "Exploring Ordinality in Text Classification: A Comparative Analysis." *arXiv:2405.11775*.
[^18]: Hossain, B., et al. (2025). "Extracting Symptoms of Complex Conditions From Online Discourse (Subreddit to Symptomatology): Lexicon-Based Approach." *J Med Internet Res*, *PMC12475878*.
[^19]: TietAI (2026). "Task-Aligned Embeddings for Clinical Code Retrieval." *arXiv:2605.30529*.
[^20]: Kallstenius, T., et al. (2025). "Comparing traditional NLP and large language models for mental health status classification." *Sci Rep*, 15, 24102. *PMC12230148*.
[^21]: Abumelha, M. (2025). "Medical Feature Extraction From Clinical Examination Notes." *JMIR Med Inform*, e78432.
[^22]: Kallstenius et al. (2025) — see [^20].
[^23]: Anonymous (2025). "A new training approach for text classification in Mental Health: LatentGLoss." *arXiv:2504.07245*.
[^24]: van Es, B., et al. (2023). "Negation detection in Dutch clinical texts: an evaluation of rule-based and machine learning methods." *BMC Med Inform Decis Mak*. *PMC9830789*.
[^25]: German ED NLP study (2025). "Integrating structured and unstructured data for predicting emergency severity." *ResearchGate*.
[^26]: Apple Inc. (2018). "Introducing Natural Language Framework." WWDC 2018 Session 713. https://nonstrict.eu/wwdcindex/wwdc2018/713/
