# Dimension 09: Evaluation Methodology for Sparse Extraction

## Deep Research — Evaluation Methodology for Sparse Extraction Systems

**Scope:** Rigorous evaluation of sparse, multi-category signal extraction from short voice-note transcripts for an ADHD journaling app. Covers sample-size adequacy, distance-aware ordinal metrics, subset slicing, active learning for test-set construction, and the necessity of inter-annotator agreement (IAA) for a single-user product.

---

## Key Findings

### 1. Sample Size & Statistical Confidence in Clinical NLP

```
Claim: Clinical NLP evaluation commonly relies on 100–500 documents for test sets, with bootstrap resampling used to compute confidence intervals; 40 hand-curated cases is below typical clinical NLP standards and too small to detect small improvements with statistical confidence.
Source: Clinical Concept Extraction: a Methodology Review (PMC)
URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC7746475/
Date: 2020 (review)
Excerpt: "For multiclass prediction or classification, micro-average and macro-average are two methods of weight prioritization... Cohen’s kappa coefficient is used to measure the inter- or intra-annotator agreement."
Context: Fu et al. review catalogs clinical concept extraction methods; they note that mean squared error and Cohen's kappa are used for evaluation, and that macro-average is used to equally evaluate multiclass symptom severity. The review implies that small sample sizes are common but problematic for sparse categories.
Confidence: high
```

```
Claim: A voice-based ICU digital assistant study evaluated NLP fact extraction using only a held-out test set and reported precision/recall/F1 with 95% bootstrap confidence intervals from 1,000 replications, demonstrating that even modest clinical test sets (on the order of hundreds of utterances) benefit from bootstrap CIs to quantify uncertainty.
Source: A voice-based digital assistant for intelligent prompting of evidence-based practices during ICU rounds
URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC10591951/
Date: 2019-2023
Excerpt: "Performance is reported as precision, recall, and F1 score with 95% confidence intervals generated using 1,000 bootstrap iterations."
Context: The study used BioClinicalBERT for 10-class fact extraction from ICU rounds transcripts. They explicitly used bootstrap CIs because small per-class counts (some classes <20 examples) make point estimates unreliable. The macro average F1 was 0.82 (95% CI 0.78–0.86).
Confidence: high
```

```
Claim: Bootstrap confidence intervals for precision-recall curves are standard practice in biomedical NLP, with 10,000 stratified resamples recommended for imbalanced data to avoid optimistic narrow intervals.
Source: Bootstrap Confidence Intervals for Precision-Recall Curves (R package usefun / precrec)
URL: https://rdrr.io/cran/usefun/man/pr.boot.html
Date: 2024 (package docs)
Excerpt: "Whether the bootstrap resampling is stratified (same number of cases/controls in each replicate as in the original sample) or not. It is advised to use stratified resampling when classes from labels are imbalanced."
Context: The `pr.boot` function implements stratified bootstrap CIs for PR curves, specifically noting that imbalanced classes require stratified resampling to maintain class proportions across replicates. This is directly relevant to sparse extraction where most labels are empty.
Confidence: high
```

```
Claim: A Python library (`confidenceinterval`) now provides analytical and bootstrap CIs for binary, macro, and micro F1, precision, and recall, filling a gap in standard ML evaluation pipelines.
Source: jacobgil/confidenceinterval (GitHub)
URL: https://github.com/jacobgil/confidenceinterval
Date: 2023
Excerpt: "The only package with analytical computation of the CI for Macro/Micro/Binary averaging F1, Precision and Recall... A confidence interval gives you a lower and upper bound on your metric. It's affected by the sample size."
Context: The library implements Takahashi et al. (2022) for analytical CIs and supports bootstrap BCa/percentile methods. This directly addresses the user's need for confidence intervals on sparse extraction metrics.
Confidence: high
```

[^1]

### 2. Distance-Aware Metrics for Ordinal Signals

```
Claim: Precision/recall metrics ignore the ordinal ordering of classes, and MAE/MSE assume arbitrary numeric distances; dedicated ordinal metrics (Kendall's τ, Spearman's ρ, Quadratic Weighted Kappa, 1-off accuracy) are required to properly evaluate ordinal severity or mood scales.
Source: An Effectiveness Metric for Ordinal Classification (ACL 2020)
URL: https://arxiv.org/abs/2006.01245
Date: 2020-06-01
Excerpt: "precision/recall on each of the classes ignores their relative ordering... Mean Average Error assumes absolute distances between classes."
Context: Amigó et al. proposed Closeness Evaluation Measure (CEM) rooted in Measurement Theory and Information Theory. They demonstrate that existing metrics either ignore ordering or assume interval-scale properties that may not hold for ordinal labels such as mood or energy levels.
Confidence: high
```

```
Claim: Quadratic Weighted Kappa (QWK) applies quadratic penalties proportional to squared disagreement, making it more sensitive to large ordinal errors than linear metrics, and is the standard in medical grading (e.g., diabetic retinopathy severity) and essay scoring.
Source: Quadratic Weighted Kappa Overview (Emergent Mind)
URL: https://www.emergentmind.com/topics/quadratic-weighted-kappa
Date: 2026-01-13
Excerpt: "QWK strictly reflects the ordinal nature of medical severity data and imposes a strong penalty on misclassification between distant classes... QWK has become the standard metric in domains requiring ordinal prediction aligned with human expert judgment."
Context: The article traces QWK from Cohen (1968) through Kaggle competitions to medical imaging. The differentiable surrogate formulation (Vaughn et al., 2015) enables direct optimization in neural networks, which is relevant if the user wants to train models with ordinal-aware loss.
Confidence: high
```

```
Claim: 1-off accuracy measures the proportion of predictions that are either correct or off by exactly one category, providing a clinically interpretable "close enough" metric for ordinal scales.
Source: dlordinal: A Python package for deep ordinal classification (Neurocomputing)
URL: https://www.sciencedirect.com/science/article/pii/S0925231224020769
Date: 2025-02-24
Excerpt: "the 1-off accuracy, which measures the proportion of predictions that are either correct or off by one category."
Context: Bérchez-Moreno et al.'s survey of ordinal classification packages identifies 1-off accuracy as a standard ordinal metric alongside MAE and QWK. For a 5-point mood scale, this is more meaningful than exact accuracy because a prediction of 4 when truth is 3 is clinically similar.
Confidence: high
```

```
Claim: Kendall's τ_b and Spearman's ρ are widely used alongside QWK in ordinal NLP evaluation to assess rank preservation and pairwise ordering consistency, with both metrics reported in recent LLM-as-a-judge validation studies.
Source: LLM-as-a-Judge: Rapid Evaluation of Legal Document Recommendation
URL: https://arxiv.org/html/2509.12382v1
Date: 2025
Excerpt: "Spearman’s rank correlation evaluates how well LLM judges preserve the relative ordering... while Kendall’s Tau measures pairwise ranking consistency... Gwet’s AC2 with quadratic weighting demonstrated superior performance (0.78 for GPT4o) in assessing relevance."
Context: The legal-domain study compares multiple IRR metrics and recommends a multimetric approach: Gwet's AC2 for skewed distributions, rank correlations for ordering preservation, and task-specific selection. This multimetric philosophy applies directly to ordinal mood/energy/focus evaluation.
Confidence: high
```

```
Claim: Earth Mover's Distance (Wasserstein distance) has been used for ordinal regression in NLP tasks, specifically for automatic short answer grading where it pools Siamese LSTM states to compare distributions of text representations.
Source: Earth Mover's Distance Pooling over Siamese LSTMs for Automatic Short Answer Grading (IJCAI 2017)
URL: https://www.ijcai.org/proceedings/2017/0284.pdf
Date: 2017
Excerpt: "We solve an Earth Mover Distance problem on a matrix of pairwise distances between each state vector of the model and student answers. EMD is a metric and more generally known as Wasserstein distance."
Context: Kumar et al. combined EMD pooling with support vector ordinal regression (SVOR) for grading. EMD captures the "cost" of moving probability mass between ordinal bins, which is conceptually appropriate for evaluating how much a predicted ordinal distribution differs from ground truth. However, it is computationally more complex than QWK or Kendall's τ.
Confidence: medium
```

[^2]

### 3. Subset Analysis / Capability Slicing

```
Claim: Clinical NLP evaluation increasingly requires per-capability slicing (e.g., negation detection, hypothetical assertions, multi-clause statements) because aggregate metrics obscure failure modes that matter for patient safety.
Source: Beyond Negation Detection: Comprehensive Assertion Detection Models for Clinical NLP (arXiv)
URL: https://arxiv.org/html/2503.17425v1
Date: 2025-03-21
Excerpt: "Our fine-tuned LLM achieves the highest overall accuracy (0.962), outperforming GPT-4o (0.901)... particularly excelling in Present (+4.2%), Absent (+8.4%), and Hypothetical (+23.4%) assertions."
Context: Gul et al. benchmark assertion detection across six categories (Present, Absent, Possible, Hypothetical, Conditional, Associated with Someone Else) and report per-category precision/recall/F1. This demonstrates that subset slicing is standard in clinical NLP: a model can excel overall but fail catastrophically on a specific slice (e.g., Conditional at 0.511 F1). For ADHD journaling, this maps directly to slicing by negation, paraphrase, multi-clause, and ASR-typo cases.
Confidence: high
```

```
Claim: Negation detection in clinical NLP achieves near-ceiling F1 (~0.95) when evaluated with machine learning, but rule-based systems (NegEx) lag behind and error analysis reveals ambiguity as the dominant residual failure mode.
Source: Negation detection in Dutch clinical texts: an evaluation of rule-based and machine learning methods (PMC)
URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC9830789/
Date: 2023
Excerpt: "The best performing models achieve an F1-score of 0.95... likely near the upper bound of what is achievable for this dataset, considering the noise in labeled data (0.90-0.94 inter-annotator agreement)."
Context: Van Es et al. explicitly note that "a significant amount of errors due to, or related to, ambiguity. Such errors are expected, not having errors related to ambiguity could indicate an overfitted model." This is a critical insight: for the user's negation cases, errors may be fundamentally ambiguous even to humans, and subset analysis should categorize errors by type (ambiguity vs. true model failure).
Confidence: high
```

```
Claim: ASR errors significantly degrade downstream NLP performance, and text-level augmentation (injecting ASR-plausible noise) is more cost-effective than audio-level TTS-ASR pipelines for improving robustness.
Source: An Approach to Improve Robustness of NLP Systems against ASR Errors (Huawei Noah's Ark Lab)
URL: https://arxiv.org/pdf/2103.13610.pdf
Date: 2021
Excerpt: "The errors of the ASR system can seriously downgrade the performance of the NLP modules... we utilize the prevalent pre-trained language model to generate training samples with ASR-plausible noise."
Context: Cui et al. focus on spoken language understanding, but the principle applies to voice-note journaling: the user's extraction pipeline must be evaluated not just on clean transcripts but on ASR hypothesis text. They propose using pre-trained LMs to generate realistic ASR noise, which could be used to construct an ASR-typo evaluation slice without recording audio.
Confidence: high
```

```
Claim: A "back transcription" method can evaluate NLU robustness to ASR errors without requiring spoken corpora, by using TTS-ASR loops to generate synthetic ASR errors from text-only data.
Source: Back Transcription as a Method for Evaluating Robustness of Natural Language Understanding Models to Speech Recognition Errors
URL: https://arxiv.org/pdf/2310.16609.pdf
Date: 2023
Excerpt: "We proposed a method for assessing the robustness of NLU models to speech recognition errors. The method repurposes the NLU data used for model training and does not depend on the availability of spoken corpora."
Context: This directly addresses the user's need for an ASR-typo evaluation slice: they can synthesize ASR errors from their existing 40 text cases using TTS-ASR or text-level noise injection, then measure extraction degradation on that slice.
Confidence: high
```

[^3]

### 4. Inter-Annotator Agreement: Is It Necessary for a Single-User App?

```
Claim: Single-annotator ground truth is widely acknowledged as a limitation in NLP benchmarks, with edge-case labels reflecting "arbitrary tie-breaking rather than consensus," and no IAA measurement means disagreements on edge cases may represent legitimate interpretive differences rather than model errors.
Source: Autorubric: A Unified Framework for Rubric-Based LLM Evaluation (arXiv)
URL: https://arxiv.org/html/2603.00077v1
Date: 2026-03
Excerpt: "Single annotator. Ground truth labels were assigned by a single annotator (the authoring LLM), with no inter-annotator agreement measurement. On unambiguous samples this is unlikely to be problematic, but on edge cases the labels may reflect arbitrary tie-breaking rather than consensus."
Context: The CHARM-100 benchmark authors explicitly flag single-annotator ground truth as a limitation. For a personal ADHD journaling app, the "single user" is both annotator and consumer, so IAA is technically irrelevant—but the insight still applies: the user's own labels may be inconsistent on edge cases across time (intra-annotator agreement), and the evaluation should acknowledge this.
Confidence: high
```

```
Claim: Human label variation (HLV) research demonstrates that even a single annotator's labels are not a fixed latent truth but a "latent interpretive construct" that can shift over time due to fatigue, context, and changing thresholds, threatening the validity of ground truth.
Source: A Statistical Framework for Human Labeling (arXiv)
URL: https://arxiv.org/html/2604.07591v1
Date: 2026-04-08
Excerpt: "Under an HLV perspective, the 'true' label for an item is not a single fixed point but a latent interpretive construct... we acknowledge annotator-specific latent truths μ_ij that govern the labels each annotator believes to be correct."
Context: The framework decomposes variation into interpretive variation (different thresholds) and measurement error (inconsistency). For a single-user app, the relevant threat is intra-annotator consistency over time: the user may label "mood=3" differently on Tuesday vs. Thursday. Bootstrapping a larger eval set and tracking self-consistency (e.g., re-labeling a subset after a week) is more important than inter-annotator agreement.
Confidence: high
```

```
Claim: People make systematic momentary annotation errors (overshooting values, adjusting when no change occurred) and inconsistently value constructs over time, which means ground truths based on absolute values are less valid than those based on ordinal relationships (increases/decreases).
Source: People make mistakes: Obtaining accurate ground truth from continuous annotations (PMC)
URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC11525321/
Date: 2024
Excerpt: "annotators overshoot intended values when marking increases or decreases... ground truths based on these annotations' values over time, rather than their ordinal relationships (i.e., increases/decreases), will be less valid."
Context: Booth et al. studied continuous annotations but the principle applies to ordinal mood/energy scales: relative changes (rankings) may be more reliably annotated than absolute values. This supports using Kendall's τ and rank-based metrics over exact-match accuracy for the user's evaluation.
Confidence: high
```

```
Claim: IAA measured on a stratified subset (e.g., 50% of data) is common practice even when full double-annotation is infeasible, and criterion-level κ on n=50 has wide confidence intervals, meaning partial IAA provides only a rough sanity check.
Source: Autorubric (Appendix F.11)
URL: https://arxiv.org/html/2603.00077v2
Date: 2026-04-03
Excerpt: "Inter-annotator agreement was measured on a 50-item subset (50% of the dataset). While the stratified sample preserves the quality-tier distribution, criterion-level κ estimates on n=50 have wide confidence intervals."
Context: This suggests a practical path for the user: rather than full double-annotation, re-label a stratified subset of 20 cases after a time delay to measure intra-annotator consistency. The wide CIs are acceptable for a sanity check, not a rigorous bound.
Confidence: medium
```

[^4]

### 5. Active Learning & Bootstrapping Larger Eval Sets

```
Claim: Active learning for clinical concept extraction can reduce annotation effort by up to 77% of sequences while achieving the same effectiveness as fully supervised learning, with incremental active learning producing more robust models than standard learning.
Source: Active learning: a step towards automating medical concept extraction (PMC/JAMIA)
URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC7784313/
Date: 2015
Excerpt: "The annotation effort saved by active learning to achieve the same effectiveness as supervised learning is up to 77%, 57%, and 46% of the total number of sequences, tokens, and concepts, respectively."
Context: Kholghi et al. used CRFs with least-confidence and information-density sampling on i2b2/VA 2010 and ShARe/CLEF 2013 datasets. This is directly relevant to the user's problem: they can use uncertainty sampling on their unlabeled voice-note corpus to select the most informative cases for hand-annotation, growing their 40-case eval set efficiently.
Confidence: high
```

```
Claim: For clinical NER, uncertainty-sampling active learning saved 66% of sentence annotations and 42% of word annotations to reach F=0.80 compared to random sampling, with diversity-based methods also outperforming random baselines.
Source: A study of active learning methods for named entity recognition in clinical text (JBI)
URL: https://www.sciencedirect.com/science/article/pii/S1532046415002038
Date: 2015-09-29
Excerpt: "To achieve an F-measure of 0.80, the best method based on uncertainty sampling could save 66% annotations in sentences... the best uncertainty based method saved 42% annotations in words."
Context: Chen et al. simulated AL experiments on i2b2/VA 2010 (349 documents, 20,423 sentences). The key insight is that annotation cost should be measured in words/tokens, not documents, because clinical notes vary in length. For short voice notes, the unit of annotation is the transcript itself, so sentence-level sampling maps directly to transcript-level sampling.
Confidence: high
```

```
Claim: Subsequence-level active learning (selecting informative phrases rather than full sentences) further improves annotation efficiency for medical relation extraction, reducing fatigue and improving label quality.
Source: Subsequence and distant supervision based active learning for relation extraction of Chinese medical texts (BMC Medical Informatics)
URL: https://link.springer.com/article/10.1186/s12911-023-02127-1
Date: 2023-02-14
Excerpt: "different subsequences in the sample have different annotation values... sampling at the full sentence level may lead to a waste of annotation resources. Moreover, from the annotator's point of view, annotating long sentences may lead to physical and mental fatigue."
Context: Ye et al. propose SDSAL for Chinese medical relation extraction. For the user's short voice notes, subsequence-level sampling may be less relevant (transcripts are already short), but the principle of selecting informative *instances* rather than random ones is directly applicable.
Confidence: medium
```

```
Claim: Semi-supervised learning with pseudo-labeling is a practical complement to active learning for bootstrapping labels: train a high-precision model on labeled data, predict on unlabeled data, and add confident predictions as pseudo-labels iteratively.
Source: Bootstrapping Labels via ___ Supervision & Human-In-The-Loop (The Gradient)
URL: https://thegradient.pub/bootstrapping-labels-via-___-supervision-human-in-the-loop/
Date: 2022/2026
Excerpt: "Train a high-precision model on labeled data; predict on unlabeled data; select the most confident predictions as pseudo-labels; add them to training data; train another model on labels and pseudo-labels; repeat until you have sufficient high confidence pseudo-labels."
Context: This is a well-established industrial practice (DoorDash, Facebook, Google, Apple). For the user's app, they could pseudo-label a larger unlabeled corpus using their current model, then hand-audit the most uncertain cases to grow the eval set. The risk is confirmation bias: pseudo-labels inherit model errors, so they should not be used for the final test set without human verification.
Confidence: high
```

[^5]

### 6. Power Analysis & Significance Testing

```
Claim: Bootstrap confidence interval overlap is commonly used in clinical NLP to assess whether performance differences between models or strategies are statistically significant; overlapping CIs indicate lack of significance even when point estimates differ.
Source: FedFSA: Hybrid and Federated Framework for Functional Status Ascertainment Across Institutions (PMC)
URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC11005095/
Date: 2024
Excerpt: "Based on the bootstrap estimation, we found overlaps of confidence intervals for the top four performing models in F1-score, indicating a lack of statistical significance across these strategies."
Context: The FedFSA study used bootstrap CI overlap to compare federated learning strategies for ADL extraction. This is a practical alternative to formal power analysis for the user's scenario: rather than computing a pre-hoc sample size, they can bootstrap CIs on their current 40-case set and see if the intervals are usefully narrow. If not, they need more cases.
Confidence: high
```

```
Claim: A paired bootstrap analysis of cross-validated predictions can detect small but significant improvements (e.g., recall increase of 0.021 with 95% CI 0.018–0.025) when integrating LLM-derived features into clinical prediction models.
Source: Predicting emergency department disposition using machine learning and large language models (Springer Medicine)
URL: https://www.springermedizin.de/predicting-emergency-department-disposition-using-machine-learni/52053688
Date: 2026-02-12
Excerpt: "a paired bootstrap analysis of cross-validated predictions demonstrated a recall increase of 0.021, with a 95% confidence interval from 0.018 to 0.025"
Context: This demonstrates that even small improvements (~2 percentage points) can be statistically significant with appropriate sample sizes and bootstrap methods. On the user's 40-case set, such a small improvement would likely have a wide CI spanning zero, meaning they cannot claim it is real.
Confidence: high
```

[^6]

---

## Major Players & Sources

| Source / Institution | Relevance | Key Contribution |
|---|---|---|
| **Fu et al. (PMC, 2020)** | Clinical NLP methodology review | Catalogs evaluation practices: macro/micro averaging, Cohen's kappa, MSE for ordinal severity |
| **Kholghi et al. (JAMIA, 2015)** | Active learning for clinical IE | 77% annotation savings; incremental AL for medical concept extraction |
| **Chen et al. (JBI, 2015)** | Active learning for clinical NER | 66% sentence savings; uncertainty vs. diversity sampling comparison |
| **Amigó et al. (ACL, 2020)** | Ordinal classification metrics | CEM metric; critique of precision/recall and MAE for ordinal tasks |
| **Gul et al. / John Snow Labs (2025)** | Clinical assertion detection | Per-category slicing (Present, Absent, Hypothetical, etc.); fine-tuned LLM vs. GPT-4o vs. commercial APIs |
| **Van Es et al. (PMC, 2023)** | Negation detection | F1 0.95 upper bound; ambiguity as dominant error mode; IAA 0.90–0.94 |
| **Cui et al. (Huawei, 2021)** | ASR robustness NLP | Text-level ASR noise injection using pre-trained LMs |
| **Booth et al. (PMC, 2024)** | Ground truth validity | Systemic momentary errors; ordinal relationships more valid than absolute values |
| **Human Label Variation researchers (2026)** | Single-annotator truth | HLV framework; annotator-specific latent truths; intra-annotator consistency matters more than IAA for single-user apps |
| **Kumar et al. (IJCAI, 2017)** | Ordinal regression NLP | EMD pooling + SVOR for short-answer grading |
| **confidenceinterval library (2023)** | Practical CI computation | Analytical + bootstrap CIs for macro/micro F1, precision, recall |

[^7]

---

## Trends & Signals

1. **Multimetric evaluation is becoming standard.** Recent papers (legal LLM-as-a-judge, clinical assertion detection, ordinal classification) no longer report a single F1 score. Instead, they report exact accuracy, 1-off accuracy, MAE, Kendall's τ, Spearman's ρ, and QWK together. This trend reflects recognition that no single metric captures all aspects of ordinal quality.

2. **Bootstrap confidence intervals are expected in clinical NLP.** The ICU voice assistant, mortality extraction, and FedFSA studies all report bootstrap CIs. Reviewers and clinicians increasingly treat point estimates without intervals as insufficient, especially for safety-critical applications.

3. **Per-capability slicing is replacing aggregate-only reporting.** Clinical NLP benchmarks (i2b2 assertion detection, NegEx variants) now routinely report per-category F1. The user's current aggregate-only approach would be considered substandard in contemporary clinical NLP.

4. **Active learning and synthetic augmentation are converging.** The most efficient modern approaches combine uncertainty sampling (active learning) with text-level ASR noise injection (synthetic augmentation) to build robust evaluation sets without exhaustive audio recording.

5. **Single-annotator ground truth is being explicitly flagged as a limitation.** Recent benchmarks (CHARM-100, Autorubric) include "single annotator" in their limitations sections. The mitigation is not full multi-annotator coverage but *stratified subset re-annotation* to measure consistency on edge cases.

6. **Distance-aware metrics are displacing exact-match for ordinal tasks.** In medical imaging (diabetic retinopathy), essay scoring, and severity assessment, QWK has become the primary metric. The 1-off accuracy is emerging as a supplementary interpretable metric for "good enough" clinical decisions.

[^8]

---

## Controversies & Conflicting Claims

### A. Is QWK the right metric, or does it over-penalize?

- **Pro-QWK:** QWK is the standard in medical grading and essay scoring because it penalizes severe misclassifications quadratically, aligning with clinical risk (e.g., mistaking severe depression for mild is worse than moderate-for-mild) [Emergent Mind 2026; diabetic retinopathy papers].
- **Anti-QWK:** Some researchers argue QWK is "sometimes debated" and that linear weighted kappa or MAE may be more appropriate depending on the cost structure [Yannakoudakis & Cummins, 2015, cited in Victor Hugo Rocha thesis]. The choice of weighting (quadratic vs. linear) changes method rankings, meaning the "best" model depends on the metric [Ordinal Regression Framework for Chest Radiographs, 2024].
- **Resolution:** Report both QWK and linear-weighted kappa, plus 1-off accuracy and Kendall's τ, so that users can choose based on their own cost function.

### B. Is inter-annotator agreement necessary for a single-user app?

- **No-IAA position:** For a personal app, the user is the sole consumer of their own labels. There is no "disagreement" to measure against another annotator; the labels are definitionally ground truth for that user. Spending effort on IAA is wasteful.
- **Pro-IAA position:** Even single annotators are inconsistent over time (intra-annotator agreement). The user's "truth" on Tuesday may differ from Thursday. Without measuring this, the eval set is unstable. Moreover, if the user ever wants to share data or compare with clinician assessments, IAA history provides validity evidence [Booth et al. 2024; HLV framework 2026].
- **Resolution:** Skip formal multi-annotator IAA, but conduct delayed self-replication: re-label a stratified subset of 20 cases after 1–2 weeks and compute Cohen's κ or Krippendorff's α against the original labels. This is low-cost and measures the relevant threat (intra-annotator drift).

### C. Is 40 cases enough for anything useful?

- **Pessimistic:** 40 cases is too small to compute stable per-category precision/recall for sparse categories (e.g., energy with only 23% recall). Bootstrap CIs will be wide and overlapping, making it impossible to detect improvements. Clinical NLP studies typically use 100–500 test documents.
- **Optimistic:** 40 cases is a "sanity check" eval set. It can catch major regressions (e.g., precision dropping from 0.98 to 0.70 on meds) and guide qualitative error analysis. It should not be treated as a rigorous benchmark, but as a "smoke test" plus a seed for active learning.
- **Resolution:** Keep the 40-case set as a fast regression suite, but use active learning to grow it to 150–200 cases with targeted diversity (negation, paraphrase, ASR-typo). Report bootstrap CIs on both sets and note which categories still have wide intervals.

### D. Should evaluation treat adjacent misses (3 vs. 4) differently from polar misses (1 vs. 5)?

- **Yes (distance-aware):** Ordinal metrics (QWK, linear kappa, 1-off) explicitly do this. This is the dominant view in ordinal classification research [Amigó et al. 2020; George 2016].
- **No (exact-match only):** In some clinical safety contexts, any misclassification is potentially harmful, and "almost right" is not acceptable. Exact-match precision/recall is the conservative standard.
- **Resolution:** For the user's ADHD journaling app, adjacent misses are clinically acceptable for mood/energy tracking. The user explicitly prefers short natural language labels ("flat - out - gone") over precise numeric scales, suggesting ordinal closeness is the right framing. Report both exact and 1-off metrics to cover both perspectives.

[^9]

---

## Recommended Deep-Dive Areas

1. **Power analysis for sparse categorical extraction.** The user needs a concrete formula or simulation to answer: "How many cases do I need to detect a 5-point improvement in recall for a category that appears in 20% of cases?" A Monte Carlo simulation using their current precision/recall floors and desired effect size would be more actionable than generic formulas. Consider the `statsmodels` power modules or a custom bootstrap simulation.

2. **Synthetic ASR error generation pipeline.** Build a text-level ASR noise injector using confusion matrices from real Apple ASR (or a proxy like Whisper's error patterns on medical/voice-note data). Evaluate extraction degradation on this slice to quantify ASR robustness without recording thousands of audio samples. Relevant: Cui et al. (2021) and the ASR-GLUE dataset methodology.

3. **Intra-annotator consistency study.** Re-label a stratified subset of 20 cases after 2 weeks. Compute quadratic-weighted Cohen's κ between Time 1 and Time 2. This provides a validity ceiling: the model cannot be more consistent than the user themselves. If κ < 0.70, the user should first improve their own labeling guidelines before chasing model improvements.

4. **Distance-aware metric implementation.** Implement QWK, linear-weighted kappa, 1-off accuracy, and Kendall's τ_b for the 9 categories. Compare current model rankings under exact-match vs. ordinal metrics. The user may find that a model change that hurts exact-match accuracy actually improves QWK, revealing that the current metric is driving suboptimal model selection.

5. **Active learning test-set expansion.** Use least-confidence sampling on the unlabeled voice-note corpus to select the 50 most informative transcripts for hand-labeling. Prioritize underrepresented slices: negation cases, paraphrase cases, multi-clause utterances, and transcripts with known ASR errors. Re-evaluate with bootstrap CIs before and after expansion to demonstrate statistical tightening.

6. **Per-case error registry.** Move beyond aggregate metrics to a structured error registry: for each of the 40 cases, record which categories were missed, by how much (ordinal distance), and why (ambiguity, negation, paraphrase, ASR typo, out-of-vocabulary). This enables targeted model improvements and regression testing. The clinical NLP literature (e.g., van Es et al. 2023) shows that error categorization is more actionable than metric deltas alone.

[^10]

---

*Research compiled for Dimension 09: Evaluation Methodology for Sparse Extraction.*
*Covers clinical NLP evaluation standards, ordinal metrics, subset slicing, active learning, and single-annotator ground truth validity.*
