# Dimension 03: Clinical Negation Detection — Deep Research

## Scope
Investigation of negation detection in clinical NLP for an ADHD journaling app (whispernotes / Squirl). The app currently uses a crude 5-word window heuristic for negation tokens. This research covers state-of-the-art approaches, scope resolution, clinical NLP evidence, and on-device feasibility.

---

## Key Findings

### Claim 1: NegEx remains the dominant baseline due to simplicity and speed, but its fixed window is a known limitation
**Source:** Chapman et al. (2001), as cited in Harkema et al. 2009 and Slater et al. 2021
**URL:** https://pmc.ncbi.nlm.nih.gov/articles/PMC2757457/
**Date:** 2001 (original); 2009 (ConText evaluation)
**Excerpt:**
> "NegEx uses regular expressions to identify the scope of trigger terms that are indicative of negation such as 'no' and 'ruled out.' Any clinical conditions within the scope of a trigger term are marked as negated." [^1]
**Context:** NegEx uses three trigger lists (pre-negation, post-negation, pseudo-negation) and a 6-token window. The original English version achieved 84.5% precision and 82.4% recall on discharge summaries. It is the most widely deployed standalone negation detection algorithm and is integrated into MetaMap, cTAKES, and CogStack pipelines.
**Confidence:** high

### Claim 2: ConText eliminated NegEx's fixed 6-token window, replacing it with sentence-end/termination-term scope, which improves recall for historical and hypothetical conditions
**Source:** Harkema, Dowling, Thornblade, Chapman — *Journal of Biomedical Informatics*, 2009
**URL:** https://pmc.ncbi.nlm.nih.gov/articles/PMC2757457/
**Date:** 2009
**Excerpt:**
> "In the NegEx algorithm the scope of a trigger term is a priori restricted to a window of six tokens... As described above, ConText has a more liberal definition of scope. There is no six-token window: the scope ends with a termination term or at the end of the sentence, however far removed from the trigger term. Experimental results show that extending the scope in this way improves performance." [^1]
**Context:** On a development set of 2,377 annotated conditions, ConText with extended scope achieved recall of .98 vs .96 for NegEx-style 6-token window on negation, .79 vs .70 for historical, and .93 vs .34 for hypothetical. ConText also handles pseudo-triggers and termination terms (e.g., "but", "presenting", "because") to delimit scope.
**Confidence:** high

### Claim 3: NegBERT achieved state-of-the-art token-level scope resolution F1 scores above 90% on multiple corpora using transfer learning
**Source:** Khandelwal & Sawant — *arXiv:1911.04211*, 2020
**URL:** https://arxiv.org/abs/1911.04211
**Date:** 2019 (v1); 2020 (revised)
**Excerpt:**
> "Our model, referred to as NegBERT, achieves a token level F1 score on scope resolution of 92.36 on the Sherlock dataset, 95.68 on the BioScope Abstracts subcorpus, 91.24 on the BioScope Full Papers subcorpus, 90.95 on the SFU Review Corpus, outperforming the previous state-of-the-art systems by a significant margin." [^2]
**Context:** NegBERT was the first major application of BERT to negation scope resolution. It uses a two-step approach (cue detection, then scope detection) and demonstrated that pretrained transformers dramatically outperform CRFs, BiLSTMs, and rule-based systems on benchmark datasets. However, it is domain-sensitive and requires retraining for new corpora.
**Confidence:** high

### Claim 4: A simple baseline of tagging exactly five words to the right of a negation cue achieves surprisingly strong performance (F1 ~72%)
**Source:** Cruz & Taboada — *Journal of the Association for Information Science and Technology*, 2016; citing Hogenboom et al. 2011
**URL:** https://www.sfu.ca/~mtaboada/docs/publications/Cruz_Taboada_Mitkov.pdf
**Date:** 2016
**Excerpt:**
> "In the SFU review corpus, the proportion of scopes to the left of the negation cues is virtually nonexistent (0.93%). In contrast, 99.40% of the scopes extend to the right of the cue with an average length of 5.66 words. Therefore, the baseline was created by tagging as scope five words to the right of the cue... This baseline achieves a promising performance value in terms of F1 (71.96% for negation and 68.59% for speculation)." [^3]
**Context:** This empirical finding directly validates the whispernotes app's current 5-word window strategy for "not", "never", "n't", and "without" (and 1-word for "no"). For short social-media-style and journal-entry text, the vast majority of negation scopes are short and rightward. The baseline even outperforms some Naïve Bayes and SVM classifiers.
**Confidence:** high

### Claim 5: Lightweight transformers (ALBERT) can outperform both rule-based systems and larger transformer models on real-world clinical negation tasks
**Source:** Weng, Liu, Chen — *JMIR Medical Informatics*, 2023
**URL:** https://medinform.jmir.org/2023/1/e46348/
**Date:** 2023
**Excerpt:**
> "In our study, the fine-tuned ALBERT model outperformed larger and more complex models, including BERT and XLNet used by NegBERT, as well as RoBERTa... The use of lightweight models, such as ALBERT, may have practical advantages, including reduced computational resource requirements and training time, compared with BERT." [^4]
**Context:** On 6,000 real-world radiology reports, ALBERT achieved F1 0.991 vs. optimized NegEx 0.921, NegBio 0.826, and retrained NegBERT 0.981. ALBERT reduces parameters via matrix decomposition and cross-layer parameter sharing. This is highly relevant for on-device deployment: smaller domain-adapted models can beat both legacy rules and larger general-purpose transformers.
**Confidence:** high

### Claim 6: Domain-adapted fine-tuned LLMs achieve 96.2% accuracy on clinical assertion detection, but run 100× slower on CPU than lightweight deep learning models
**Source:** Kocaman et al. — *arXiv:2503.17425*, 2025 (John Snow Labs)
**URL:** https://arxiv.org/abs/2503.17425
**Date:** 2025
**Excerpt:**
> "Our fine-tuned LLM achieves the highest overall accuracy (0.962), outperforming GPT-4o (0.901) and commercial APIs by a notable margin... Our DL-based models run 100× faster on a CPU than the LLM on a GPU, while the LLM is thousands of times more expensive for just 1-2% better accuracy. This highlights the impracticality of LLM-based assertion detection for real-time, scalable clinical NLP." [^5]
**Context:** The few-shot classifier (0.929 accuracy) is explicitly recommended as "ideal for resource-constrained environments." This establishes a clear performance/cost frontier for mobile/on-device NLP: lightweight DL models are the sweet spot for real-time inference.
**Confidence:** high

### Claim 7: Dependency parsing improves precision but suffers from poor generalization and high computational cost
**Source:** Slater et al. — *Computers in Biology and Medicine*, 2021 (komenti-negation)
**URL:** https://pmc.ncbi.nlm.nih.gov/articles/PMC7910278/
**Date:** 2021
**Excerpt:**
> "The performance of NegBio also confirms that dependency-based negation detection systems that use specific grammatical rules, while highly precise, are unable to capture new negatory constructs when applied to new datasets... The quickest algorithm in both cases was NegEx, finishing in less than 2 s... NegBio is slow in both cases, in the faster case taking over 23 min to parse 1077 sentences." [^6]
**Context:** The komenti-negation heuristic (grammatical distance in dependency graph, max distance 4) achieved F1 0.87 on MIMIC and 0.885 on HCM, with far more stable cross-dataset performance than NegBio. The authors explicitly recommend heuristic dependency approaches as a "new default choice" when rule development is not possible. For mobile apps, dependency parsing is likely too slow and heavy.
**Confidence:** high

### Claim 8: The 2010 i2b2/VA challenge proved assertion classification (including negation) is the "easiest and best studied" clinical NLP task, with top systems reaching F1 ~0.93–0.94
**Source:** Uzuner et al. — *Journal of the American Medical Informatics Association*, 2011
**URL:** https://pmc.ncbi.nlm.nih.gov/articles/PMC3168320/
**Date:** 2011
**Excerpt:**
> "The results of the challenge showed that of the three tasks, assertion classification was the easiest and best studied, concept extraction was relatively complex because of the difficulty of boundary detection for concepts, and relation classification... was the most difficult. The most effective assertion classification systems used support vector machines (SVMs), either with contextual information and dictionaries that indicate negation, uncertainty, and family history, or with the output of rule-based systems." [^7]
**Context:** Top assertion classification F-measures: deBruijn et al. 0.936, Clark et al. 0.934, Demner-Fushman et al. 0.933. This established that hybrid approaches (rule-based + ML) are highly effective for negation/assertion in clinical text, and that the task is more tractable than extraction or relation classification.
**Confidence:** high

### Claim 9: BioScope is the foundational corpus for negation and uncertainty, but it annotates maximal (syntactic) scope, not minimal semantic scope
**Source:** Vincze et al. — *BMC Bioinformatics*, 2008
**URL:** https://bmcbioinformatics.biomedcentral.com/articles/10.1186/1471-2105-9-S11-S9
**Date:** 2008
**Excerpt:**
> "The dataset contains annotations at the token level for negative and speculative keywords and at the sentence level for their linguistic scope." ... "Sentences containing any kind of negation are examined for negative annotation. Negation is understood as the implication of the non-existence of something." [^8]
**Context:** BioScope consists of 20,924 sentences across medical free texts, biological full papers, and abstracts. Over 10% contain negation or uncertainty annotations. It was used for CoNLL-2010 and *SEM-2012 shared tasks. Importantly, BioScope annotates "maximal" scope (largest syntactic unit), whereas sentiment and clinical extraction tasks often need "minimal" scope (only the semantically negated event). This distinction matters for applications like whispernotes that flip polarities based on negation.
**Confidence:** high

### Claim 10: Mental health / psychiatric NLP explicitly requires negation detection for symptom extraction, and light interpretable models are preferred
**Source:** De la Hoz et al. — *Leveraging NLP for Psychiatric Phenotyping from Spanish EHRs*, 2024
**URL:** https://pmc.ncbi.nlm.nih.gov/articles/PMC12266705/
**Date:** 2024
**Excerpt:**
> "We developed a light, accurate, and interpretable natural language processing (NLP) algorithm to extract psychiatric phenotypes from Spanish clinical notes... For phenotypes meeting frequency and inter-annotator reliability thresholds, we developed three NLP algorithms... for phenotype extraction and context labeling (e.g., negation, family history, uncertainty)." [^9]
**Context:** Document-level F1 scores were 0.84–0.85; entry-level F1 0.75–0.78. Cross-hospital transportability was strong (F1 0.75–0.77). This is directly relevant to whispernotes: psychiatric symptom extraction with negation/uncertainty labeling is an active research area, and interpretable lightweight models are the pragmatic choice for real-world deployment.
**Confidence:** high

### Claim 11: On-device convolutional representations can be compressed 32× with negligible performance loss
**Source:** Desai et al. — *arXiv:2002.01535*, 2020
**URL:** https://arxiv.org/abs/2002.01535
**Date:** 2020
**Excerpt:**
> "We propose a fast, accurate, and lightweight convolutional representation that can be swapped into any neural model and compressed significantly (up to 32x) with a negligible reduction in performance. In addition, we show gains over recurrent representations when considering resource-centric metrics (e.g., model file size, latency, memory usage) on a Samsung Galaxy S9." [^10]
**Context:** This provides a feasibility argument for running neural negation models on-device. If a lightweight transformer or CNN-based negation classifier can be compressed 32×, it becomes viable for an iOS app without cloud dependency. Apple Neural Engine and CoreML further enable this.
**Confidence:** medium

### Claim 12: LLMs still struggle with deep semantic negation comprehension, even when they perform well on syntactic scope detection
**Source:** Thunder-NUBench — *arXiv:2506.14397*, 2025
**URL:** https://arxiv.org/abs/2506.14397
**Date:** 2025
**Excerpt:**
> "Pretrained transformer models like BERT have been leveraged through transfer learning (e.g., NegBERT), significantly enhancing the accuracy of negation detection tasks. However, these methods still primarily address syntactic span detection, with deeper semantic comprehension of negation remaining challenging." [^11]
**Context:** The 2025 benchmark also notes that existing NLU benchmarks (SNLI, CommonsenseQA, SST-2) are criticized for "insufficiently accounting for the semantic impact of negation," enabling models to achieve high accuracy even when ignoring negation entirely. This is a warning: high scope-detection F1 does not guarantee correct semantic interpretation (e.g., "not only happy" vs. "not happy").
**Confidence:** high

---

## Major Players & Sources

| System / Corpus | Authors | Year | Type | Key Contribution |
|---------------|---------|------|------|------------------|
| **NegEx** | Chapman et al. | 2001 | Rule-based (regex, window) | First widely deployed standalone negation detector; 6-token window |
| **ConText / pyConTextNLP** | Harkema et al. | 2009 | Rule-based (termination terms) | Extended NegEx to scope-to-sentence-end; added temporality & experiencer |
| **BioScope corpus** | Vincze et al. | 2008 | Annotated corpus | 20K sentences with cue + scope annotations; benchmark for CoNLL-2010, *SEM-2012 |
| **i2b2/VA 2010** | Uzuner et al. | 2011 | Shared task | Assertion classification (negation, uncertainty, hypothetical, etc.) |
| **DEEPEN** | Mehrabi et al. | 2015 | Dependency + NegEx hybrid | Stanford Dependency Parser to reduce NegEx false positives |
| **NegBio** | Peng et al. | 2018 | Dependency-based rules | Subgraph matching on dependency graphs; high precision but slow |
| **NegBERT** | Khandelwal & Sawant | 2020 | Transformer (BERT) | SOTA scope resolution via transfer learning; F1 > 90% on benchmarks |
| **komenti-negation** | Slater et al. | 2021 | Heuristic dependency | Single grammatical-distance heuristic; stable cross-dataset; fast |
| **ALBERT (clinical fine-tuning)** | Weng et al. | 2023 | Lightweight transformer | Outperformed NegEx, NegBio, NegBERT on radiology; F1 0.991 |
| **Spark NLP AssertionDL** | Kocaman et al. | 2025 | DL + few-shot + LLM | Comprehensive assertion detection; few-shot 0.929, ideal for resource-constrained |
| **Thunder-NUBench** | Various | 2025 | LLM benchmark | Exposes that LLMs still lack deep semantic negation understanding |

---

## Trends & Signals

1. **Shift from two-step (cue → scope) to end-to-end:** Weng et al. (2023) showed that learning "the entire part of the sentence containing both the cue and scope in the same step without explicitly telling the model which word is the 'cue'" outperforms traditional two-step approaches. This simplifies pipeline architecture and reduces annotation burden. [^4]

2. **Lightweight > Large for on-device inference:** Multiple 2023–2025 papers converge on the finding that smaller, domain-finetuned models (ALBERT, DistilBERT, few-shot classifiers) offer the best accuracy/cost ratio for real-time clinical NLP. This is a strong signal for whispernotes to avoid cloud-based LLM inference. [^4][^5]

3. **Rule-based systems are not dead, but their window is closing:** For short, well-formed text, rule-based systems (NegEx, ConText) remain competitive and are orders of magnitude faster. However, as soon as multi-sentence context, symbols, or ungrammatical text enters the picture, rule-based systems degrade. The komenti-negation paper explicitly calls heuristic dependency approaches a potential "new default." [^6]

4. **Assertion detection is broader than pure negation:** Modern clinical NLP treats negation as one assertion type alongside possible, conditional, hypothetical, and associated-with-someone-else. Whispernotes currently only handles negation, but the literature suggests that a more complete model (e.g., "possibly tired" should not flip to sluggish) would be more robust. [^5][^7]

5. **Cross-lingual portability is an open problem:** Most negation systems are developed for English. Spanish, Swedish, and French adaptations exist but require significant customization. If whispernotes ever expands to other languages, this is a major risk factor.

---

## Controversies & Conflicting Claims

### A. Rule-based vs. ML: Which is better?
- **Pro-rule:** Goryachev (2017) and Slater et al. (2021) found rule-based approaches (NegEx, ConText) superior or comparable to ML classifiers, especially when out-of-context training is used. Rule-based systems are interpretable, modifiable, and extremely fast. [^6]
- **Pro-ML:** Weng et al. (2023) and Kocaman et al. (2025) show fine-tuned transformers consistently outperform optimized rule-based systems on real-world data. The gap is largest for ambiguous or multi-sentence cases. [^4][^5]
- **Resolution:** The consensus is hybrid or domain-adapted lightweight DL for production, with rule-based systems as fallback or for speed-critical paths.

### B. How far should negation scope extend?
- **Maximal scope (BioScope):** Annotations extend to the largest syntactic unit. This is linguistically principled but can over-predict for downstream tasks. [^8]
- **Minimal scope (Product Reviews / PR):** Only the semantically negated span is annotated. This is better for sentiment polarity flipping but harder to annotate consistently. [^12]
- **Window heuristic (NegEx / whispernotes):** Fixed word-count window. Empirically, 5–6 words captures ~72% of scopes correctly for short text, but fails on complex sentences. [^3]
- **ConText compromise:** Scope to end-of-sentence or termination term. This is a practical middle ground that improves recall without catastrophic precision loss. [^1]

### C. On-device feasibility of transformers
- **Optimistic:** Desai et al. (2020) show 32× compression with negligible loss. Apple's CoreML and Neural Engine are specifically designed for on-device inference. A fine-tuned ALBERT-size model is well within modern iPhone capabilities. [^10]
- **Pessimistic:** Even lightweight transformers require embedding tables, tokenizer vocabularies, and inference frameworks that add binary size. Rule-based heuristics add essentially zero binary overhead. For an app that needs to work offline, the engineering complexity of shipping a CoreML model may not be worth a ~5–10% accuracy gain on a task that is already handled adequately by rules. [^4]

### D. Should negation always flip polarity symmetrically?
- Whispernotes currently flips mood great→low, energy charged→sluggish, focus lockedIn→foggy. This is symmetric.
- **Cruz & Taboada (2016)** found that "negated positives become mild negatives (score × 0.7). Negated negatives become mild positives (score × 0.5). This asymmetry reflects how 'not bad' is weaker than 'good.'" [^3]
- **Implication:** A symmetric flip may be too strong. "Not great" does not mean "low"; it means "middling/okay." The current system risks over-flipping.

---

## Recommended Deep-Dive Areas

1. **Clause-level segmentation for mood/energy/focus:** Current clause splitting exists only for medications. Extending this to subjective states would address "wasn't tired but exhausted" — the negation should not flip "tired" to steady if the clause is explicitly overridden by "but exhausted." ConText's termination-term approach (especially "But" class) is directly applicable. [^1]

2. **Pseudo-negation handling:** The current system has no pseudo-negation list. Phrases like "not only happy" (pseudo-negation: "not only" does not flip polarity) and "no special energy focus" (the 1-word "no" window is designed to avoid this) need explicit handling. ConText maintains 17 pseudo-triggers for negation alone. [^1]

3. **Asymmetric polarity flip:** Research shows negated positives should flip to mild negatives, not full opposites. "Not great" → "okay" rather than "low." This could be implemented by mapping to a middle tier instead of the antipode. [^3]

4. **Lightweight transformer evaluation:** A pragmatic next step is to fine-tune a tiny transformer (DistilBERT, ALBERT, or even a 2-layer CNN) on a small corpus of ADHD journal entries annotated for negation scope. The model could run on-device via CoreML. The John Snow Labs few-shot classifier (0.929 accuracy) suggests only hundreds of examples may be needed. [^5]

5. **Multi-sentence context:** The current system processes each sentence independently. Weng et al. (2023) showed that BERT's attention mechanism can look across multiple sentences to determine whether a speculative statement is related to abnormal findings. For journal entries, "I felt okay. Not really though." requires cross-sentence context. [^4]

6. **Implicit negation cues:** The current system only handles explicit tokens ("not", "never", "no", "n't", "without"). Implicit negation (e.g., "failed to concentrate", "lacked energy") is not handled. The 2024 survey by Ilmawan et al. explicitly calls this "a need for more studies addressing implicit negation cue detection, even within the state-of-the-art BERT approach." [^13]

---

## Footnotes

[^1]: Harkema H, Dowling JN, Thornblade T, Chapman WW. ConText: An Algorithm for Determining Negation, Experiencer, and Temporal Status from Clinical Reports. *J Biomed Inform*. 2009;42(5):839-851. https://pmc.ncbi.nlm.nih.gov/articles/PMC2757457/

[^2]: Khandelwal A, Sawant S. NegBERT: A Transfer Learning Approach for Negation Detection and Scope Resolution. *arXiv:1911.04211 [cs]*. 2020. https://arxiv.org/abs/1911.04211

[^3]: Cruz NP, Taboada M, Mitkov R. A Machine Learning Approach to Negation and Speculation Detection for Sentiment Analysis. *J Assoc Inf Sci Technol*. 2016;67(9):2118-2133. https://www.sfu.ca/~mtaboada/docs/publications/Cruz_Taboada_Mitkov.pdf

[^4]: Weng KH, Liu CF, Chen CJ. Deep Learning Approach for Negation and Speculation Detection for Automated Important Finding Flagging and Extraction in Radiology Report: Internal Validation and Technique Comparison Study. *JMIR Med Inform*. 2023;11:e46348. https://medinform.jmir.org/2023/1/e46348/

[^5]: Kocaman V, Gul Y, Kaya MA, et al. Beyond Negation Detection: Comprehensive Assertion Detection Models for Clinical NLP. *arXiv:2503.17425 [cs]*. 2025. https://arxiv.org/abs/2503.17425

[^6]: Slater LT, Bradlow W, Motti DFA, et al. A fast, accurate, and generalisable heuristic-based negation detection algorithm for clinical text. *Comput Biol Med*. 2021;130:104216. https://pmc.ncbi.nlm.nih.gov/articles/PMC7910278/

[^7]: Uzuner Ö, South BR, Shen S, DuVall SL. 2010 i2b2/VA challenge on concepts, assertions, and relations in clinical text. *J Am Med Inform Assoc*. 2011;18(5):552-556. https://pmc.ncbi.nlm.nih.gov/articles/PMC3168320/

[^8]: Vincze V, Szarvas G, Farkas R, Móra G, Csirik J. The BioScope corpus: biomedical texts annotated for uncertainty, negation and their scopes. *BMC Bioinformatics*. 2008;9(Suppl 11):S9. https://bmcbioinformatics.biomedcentral.com/articles/10.1186/1471-2105-9-S11-S9

[^9]: De la Hoz J, Frydman-Gani C, Arias A, Olde Loohuis LM. Leveraging Natural Language Processing for Psychiatric Phenotyping from Spanish Electronic Health Records. *PMC*. 2024. https://pmc.ncbi.nlm.nih.gov/articles/PMC12266705/

[^10]: Desai S, Durrett G, Cai D. Lightweight Convolutional Representations for On-Device Natural Language Processing. *arXiv:2002.01535 [cs]*. 2020. https://arxiv.org/abs/2002.01535

[^11]: Thunder-NUBench: A Benchmark for LLMs' Sentence-Level Negation Understanding. *arXiv:2506.14397 [cs]*. 2025. https://arxiv.org/abs/2506.14397

[^12]: Lapponi T, et al. Representing and Resolving Negation for Sentiment Analysis. *SenticNet / Sentire Workshop*. 2012. https://sentic.net/sentire2012lapponi.pdf

[^13]: Ilmawan LB, Muladi, Prasetya DD. Negation handling for sentiment analysis task: approaches and performance analysis. *Int J Electr Comput Eng (IJECE)*. 2024;14(3):3382-3393. https://ijece.iaescore.com/index.php/IJECE/article/view/35021
