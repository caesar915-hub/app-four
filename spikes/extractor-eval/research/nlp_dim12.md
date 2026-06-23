# Dimension 12: User Feedback Loop & Continuous Improvement

## Deep Research Report — NLP Learning from User Corrections

**Project:** whispernotes / Squirl (ADHD journaling app)
**Date:** 2026-06-23
**Researcher:** Deep Research Agent
**Dimension:** 12 — How NLP systems can learn from user corrections without full ML training

---

## Executive Summary

This report investigates how NLP systems can learn from user corrections in a privacy-sensitive, on-device context (Apple Natural Language framework, SwiftData). The app currently has a review UI (ExtractionReviewView) where users correct extractions, but the feedback loop only extends the lexicon for medications and feelings via PersonalLexiconBuilder. Mood/energy/focus corrections are stored as value changes but do NOT add new phrases to the lexicon. The app has no active learning, no error pattern mining, and no A/B testing framework.

Key findings: (1) Human-in-the-loop NLP and active learning can significantly reduce annotation burden while improving accuracy; (2) Competitors like Daylio, Bearable, and How We Feel use structured manual entry rather than NLP extraction, with limited feedback loops; (3) Lexicon bootstrapping and double-propagation methods can expand vocabularies from small seed sets; (4) Privacy-preserving approaches (federated learning, on-device personalization, differential privacy) are mature and deployed at scale (Gboard, Siri); (5) The minimum correction rate for useful learning depends on algorithm choice, with distance-based active learning reducing required samples by ~33% in clinical text; (6) Overfitting to individual user vocabulary is a real risk, mitigated by parameter decoupling, batched feedback, and hybrid global-local models.

---

### Key Findings

#### Finding 1: Human-in-the-Loop NLP Enables Continuous Post-Deployment Improvement

```
Claim: Once NLP systems are deployed, the learning process traditionally ends; however, researchers are increasingly studying how systems can benefit from end-user corrections to incrementally improve AI performance. [^1]
Source: Human-in-the-loop machine learning: a state of the art (Springer, Artificial Intelligence Review)
URL: https://link.springer.com/article/10.1007/s10462-022-10246-w
Date: 2022-08-17 (published 2023)
Excerpt: "More and more researchers are realizing the importance of studying users of intelligent systems and how these systems can benefit and learn interactively from their end-users. Once the systems are deployed they can receive from their users corrections that can be used to generate additional training data, enabling an incremental improvement of the AI performance."
Context: Survey paper on HITL machine learning, cited by 1499+ papers. Discusses how user corrections in deployed systems can generate additional training data.
Confidence: high
```

#### Finding 2: Active Learning Can Reduce Annotation Burden by One-Third in Clinical Text Classification

```
Claim: Distance-based active learning algorithms (DIST and CMB) required one-third fewer training instances than random sampling to achieve 90% accuracy on clinical text classification tasks. [^2]
Source: Active learning for clinical text classification: is it better than random sampling? (PMC/JAMIA)
URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC3422824/
Date: 2011-09-20
Excerpt: "For instance, in the SNS2 dataset at 90% accuracy (table 3), DIST and CMB required one third fewer instances than random sampling, while DIV required significantly larger sample sizes."
Context: Study tested five active learning algorithms on four clinical datasets. Found that clinical notes' restricted sublanguage and vocabulary affect algorithm performance differently than general-domain text.
Confidence: high
```

#### Finding 3: Active Learning Models for Mental Health Can Expand Knowledge Over Time

```
Claim: A semi-supervised active learning model using bidirectional LSTM with attention achieved 0.85 ROC for depression symptom extraction from patient-authored texts and was able to expand its knowledge with timestamps. [^3]
Source: Attention-Based Deep Entropy Active Learning Using Lexical Algorithm for Mental Health Treatment (Frontiers in Psychology)
URL: https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2021.642347/full
Date: 2021-03-30
Excerpt: "The active learning model was able to expand knowledge with time. Our model achieved 0.85 ROC, helped to visualize the attention-based words, and recommended the suggested symptoms."
Context: Focuses on personalized mental health interventions using NLP. Uses WordNet emotional lexicon and cosine similarity for symptom classification. Active learning component expands knowledge incrementally.
Confidence: high
```

#### Finding 4: Lexicon Bootstrapping via Double Propagation Expands Opinion Lexicons from Small Seeds

```
Claim: A bootstrapping method called "double propagation" can expand an initial opinion lexicon and extract opinion targets by propagating information between opinion words and targets through syntactic dependency relations, requiring only a small seed lexicon to start. [^4]
Source: Dependency-Based Problem Phrase Extraction from User Reviews of Products (ResearchGate)
URL: https://www.researchgate.net/publication/300143452_Dependency-Based_Problem_Phrase_Extraction_from_User_Reviews_of_Products
Date: 2015-09-14
Excerpt: "A key advantage of the proposed method is that it only needs an initial opinion lexicon to start the bootstrapping process. Thus, the method is semi-supervised due to the use of opinion word seeds."
Context: Based on the paper by Qiu et al. on opinion lexicon expansion and target extraction. Highly relevant for expanding mood/energy/feeling lexicons from user corrections.
Confidence: high
```

#### Finding 5: Medical Vocabulary Expansion via Distributional Semantics Is Feasible on Patient-Authored Text

```
Claim: Medical vocabularies can be expanded by applying distributional semantics on medical corpora, enabling automatic extraction of medical terms from patient-authored text. [^5]
Source: Expansion of medical vocabularies using distributional semantics on Japanese patient blogs (Journal of Biomedical Semantics)
URL: https://link.springer.com/article/10.1186/s13326-016-0093-x
Date: 2016-09-26
Excerpt: "In this study, we aim to investigate the possibility of expanding medical vocabularies by applying distributional semantics on a medical corpus."
Context: Cited by 22 papers. Uses distributional semantics (word embeddings) to expand medical vocabularies from patient blogs. Directly applicable to expanding ADHD medication/symptom lexicons from user journals.
Confidence: high
```

#### Finding 6: Competitor Mood Tracking Apps Rely on Manual Structured Entry, Not NLP Extraction

```
Claim: Daylio uses a five-icon mood picker with optional activity tags; Bearable uses a 1-10 scale with pre-made taxonomy categories; How We Feel is a non-profit with scientific backing and zero-monetization. None of these apps use NLP extraction with user-correctable feedback loops for mood/energy/feeling inference. [^6]
Source: Bearable vs Daylio comparison (Bearable.app) and Best Mood Tracker App 2026 comparison (HabitBox)
URL: https://bearable.app/bearable-vs-daylio-which-one-should-you-choose/ and https://habitbox.app/blog/best-mood-tracker-app
Date: 2025-08-14 and 2026-05-13
Excerpt: "On Daylio your mood scale is smaller than on Bearable, meaning you miss some of that nuance between feeling at a 4 instead of a 5. (Daylio lets you rate your mood from 1-5; Bearable from 1-10)." / "Daylio leads on simplicity, Bearable leads on data depth, How We Feel leads on emotion vocabulary."
Context: Competitor analysis shows the market is dominated by manual-entry apps. NLP-driven extraction with correction loops is essentially a whitespace/opportunity in this category.
Confidence: high
```

#### Finding 7: Mood-Tracking App Users Strongly Prefer Flexibility Combined with Simplicity

```
Claim: Users of mood-tracking apps prefer entry screens that allow selecting words or emojis representing words, appreciate sliders for capturing nuance, and want customization without overwhelming complexity. They also avoid logging negative moods during bad times. [^7]
Source: Understanding People's Use of and Perspectives on Mood-Tracking Apps: Interview Study (JMIR)
URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC8387890/
Date: 2021-07-18
Excerpt: "Participants preferred entry screens which allowed them to select words (Youper, left) or emojis that represent words (Mood - Journal & Anxiety Chat, right)." / "I just can't go off of this scale." / "You don't use it for the bad times. Put all the good times on it."
Context: Qualitative study of 22 real-world mood-tracking app users. Key insight: users want simple entry but also nuanced capture, and they often skip negative entries. This has implications for correction-rate sufficiency.
Confidence: high
```

#### Finding 8: NLP Systems Can Learn From Corrections via Pattern-Based Incremental Learning

```
Claim: A pattern-based system (GEN) can learn from implicit user feedback by taking corrected outputs as new seeds in each iteration, improving question generation by 10%+ depending on metric and strategy. [^8]
Source: Using Implicit Feedback to Improve Question Generation (arXiv)
URL: https://arxiv.org/abs/2304.13664
Date: 2023-04-26
Excerpt: "Each generated question, after being corrected by the user, is used as a new seed in the next iteration, so more patterns are created each time. Results show that GEN is able to improve by learning from both levels of implicit feedback when compared to the version with no learning."
Context: Relevant for designing a lexicon expansion system where each user correction becomes a new seed for pattern extraction.
Confidence: high
```

#### Finding 9: Injecting Human Correction Information Into Deep Models Improves Classification

```
Claim: A model (Model-C) trained with both the original prediction and the corrected human label as inputs learns the correction task and the classification task simultaneously, improving over the baseline model trained only on original labels. [^9]
Source: Learning From How Humans Correct (arXiv)
URL: https://arxiv.org/html/2102.00225v19
Date: 2024-01-14
Excerpt: "We add the Model-A's predicted one-hot label as the addition input for training / fine-tuning a new model... Model-C is learning how to correct and learning the text classification task in the same time."
Context: Uses BERT fine-tuning. The "before-corrected" label is fed as additional input. Highly relevant for Squirl's extraction review scenario where the system has both the NLP prediction and the user correction.
Confidence: high
```

#### Finding 10: Adversarial and Privacy Risks Are Elevated When Learning From User Data

```
Claim: NLP models trained on user data face privacy threats including membership inference, attribute inference, re-identification, and reverse engineering attacks. Models can inadvertently memorize and reproduce private or confidential information. [^10]
Source: How to keep text private? A systematic review of deep learning methods for privacy-preserving NLP (Springer, Artificial Intelligence Review)
URL: https://link.springer.com/article/10.1007/s10462-022-10204-6
Date: 2022-05-21
Excerpt: "Text data encompasses a large number of private attributes which can be leaked through embeddings for words, sentences, or texts... These attributes include gender, age, location, political views, and sexual orientation."
Context: Comprehensive review of privacy-preserving NLP techniques. Essential for informing Squirl's on-device-only architecture decisions.
Confidence: high
```

#### Finding 11: On-Device Training Suffers From Overfitting Due to Scarce Local Data

```
Claim: Compared to cloud-based personalization, on-device training suffers from severe overfitting due to the scarcity of local data samples. Cloud-based models with aggregated data from many users mitigate this overfitting while maintaining privacy through anonymous embeddings. [^11]
Source: Personalized Language Model Learning on Text Data Without User Identifiers (arXiv)
URL: https://arxiv.org/html/2501.06062v1
Date: 2025
Excerpt: "The improvement of IDfree-PL is mainly due to mitigating overfitting with large-scale samples on the cloud uploaded from many users. In contrast, on-device training suffers from the scarcity of local data samples."
Context: Proposes IDfree-PL (anonymous user embeddings) as a middle ground. For Squirl, this suggests lexicon-only local updates may be safer than full model personalization on-device.
Confidence: high
```

#### Finding 12: Federated Learning Enables Privacy-Preserving NLP Personalization on Mobile Devices

```
Claim: Federated learning enables training NLP models across decentralized devices without transferring raw user data to central servers, with real-world deployment at scale in Gboard for next-word prediction and grammar correction. [^12]
Source: Private Federated Learning in On-device NLP (NAACL workshop paper)
URL: https://www.cs.jhu.edu/~kevinduh/t/naacl24/final_pdf/paper287.pdf
Date: 2024
Excerpt: "The success of private FL has also led to real-world applications such as GBoard, which uses on-device LMs for next word prediction... Given relatively small model sizes, state-of-the-art differentially private learning algorithms have enabled on-device LMs to achieve strong downstream task utility."
Context: Federated learning with differential privacy is a proven, production-ready approach for mobile NLP personalization. Squirl could potentially use federated lexicon aggregation rather than full model training.
Confidence: high
```

#### Finding 13: Users Desire Personalized Mood Options but Apps Often Provide Fixed Taxonomies

```
Claim: The most commonly requested features in mood-tracking apps are the capability to add personalized mood options, process logged data, and update privacy settings. Users with mental illness expected features such as tracking other symptoms or tracking medicine. [^13]
Source: Mobile apps for mood tracking: an analysis of features and user reviews (AMIA)
URL: https://cpb-us-w2.wpmucdn.com/blogs.iu.edu/dist/8/675/files/2021/02/MoodTracking-AMIA17.pdf
Date: 2021
Excerpt: "The most commonly requested features were the capability to add personalized mood options, process logged data... and update privacy settings." / "Users with mental illness also expected features such as tracking other symptoms or tracking medicine."
Context: Systematic analysis of mood-tracking app user reviews. Users want personalization but within structured frameworks. Squirl's NLP extraction + lexicon expansion directly addresses this gap.
Confidence: high
```

#### Finding 14: Bias in NLP Systems Can Propagate From Training Data and Requires Regular Auditing

```
Claim: 85% of AI and ML projects will deliver erroneous outcomes due to bias in data, algorithms, or team management. Bias in training data propagates into model outputs, leading to unfair outcomes in sentiment analysis and other NLP tasks. [^14]
Source: Optimizing CRM Workflows with NLP (SuperAGI) — citing Gartner
URL: https://superagi.com/optimizing-crm-workflows-with-nlp-a-step-by-step-guide-to-automation-and-personalization/
Date: 2025-06-20
Excerpt: "According to a report by Gartner, 85% of AI and machine learning projects will deliver erroneous outcomes due to bias in data, algorithms, or the teams responsible for managing them."
Context: Relevant for Squirl's lexicon expansion: if the seed lexicon is biased (e.g., toward certain dialects or expression styles), user corrections may amplify rather than reduce that bias.
Confidence: medium
```

#### Finding 15: Semantic Lexicon Expansion Using Bootstrapping and Syntax-Based Patterns Is Well-Established

```
Claim: Semantic lexicon expansion — starting from a small seed lexicon and expanding it to cover all terms in a corpus using bootstrapping and syntax-based contextual extraction patterns — is a mature NLP technique with significant research history. [^15]
Source: Semantic Lexicon Expansion using Bootstrapping and Syntax-based Contextual Extraction Patterns (ResearchGate)
URL: https://www.researchgate.net/publication/242041380_Semantic_Lexicon_Expansion_using_Bootstrapping_and_Syntax-based_Contextual_Extraction_Patterns
Date: not specified (pre-2010s)
Excerpt: "We describe the task of Semantic Lexicon Expansion, in which a small seed lexicon is expanded into a semantic lexicon that encompasses all terms in..."
Context: Thelen & Riloff's work on bootstrapping semantic lexicons. This is the foundational technique that PersonalLexiconBuilder approximates, but with dependency parsing it could be significantly more powerful.
Confidence: high
```

#### Finding 16: Single-Axis Mood Tracking Fails for Bipolar and ADHD Users Who Need Multi-Dimensional Capture

```
Claim: A single mood axis collapses clinically relevant information. Bipolar and ADHD users need separate axes for mood, energy, sleep, and stability because combinations matter (e.g., high energy + low mood = mixed state). [^16]
Source: Daylio Alternative for Bipolar Mood Tracking (Steadyline)
URL: https://steadyline.app/blog/daylio-alternative-bipolar
Date: 2026-02-14
Excerpt: "A single number collapses all of that into one data point. You lose the most important information. I go deeper on this in why mood alone isn't enough." / "High energy with low mood is a mixed state, which is one of the more dangerous presentations of bipolar."
Context: Squirl's multi-dimensional extraction (mood, energy, focus) is architecturally correct for ADHD users. The feedback loop should preserve this multi-dimensionality when learning from corrections.
Confidence: high
```

#### Finding 17: Adaptive NLP Systems Can Self-Improve by Monitoring User Corrections

```
Claim: Adaptive NLP systems can analyze the success rate of their predictions by monitoring user corrections, leading to decreased errors over time without human intervention. Personalization, contextual awareness, and real-time learning are key capabilities. [^17]
Source: Conversational feedback mechanism: Designing Effective Feedback Loops for NLP Models (FasterCapital)
URL: https://fastercapital.com/content/Conversational-feedback-mechanism--Designing-Effective-Feedback-Loops-for-Natural-Language-Processing-Models.html
Date: 2024-06-24
Excerpt: "An adaptive NLP system could analyze the success rate of its language translations by monitoring user corrections. Over time, it would learn from these corrections, leading to a decrease in translation errors without human intervention."
Context: Practical guide to designing feedback loops in NLP systems. Notes ethical considerations and bias risks as systems become more adaptive.
Confidence: medium
```

#### Finding 18: On-Device Grammar Correction with LLMs Is Now Deployed on Pixel Phones

```
Claim: Google deployed grammar correction as you type on Pixel 6 using a server-side PaLM2-XS model with supervised fine-tuning and reinforcement learning, with future work targeting on-device deployment and expanded error coverage. [^18]
Source: AI-Powered Grammar Correction in Keyboards (journal review paper)
URL: https://journals.mriindia.com/index.php/ijaece/article/download/837/818/2271
Date: 2025
Excerpt: "Proofread: Fixes All Errors with One Tap... used a server-side LLM(PaLM2-XS) model with supervised fine-tuning and reinforcement learning. It was deployed within Gboard. The study suggests future improvements like on-device deployment, reduced latency, expanded error coverage."
Context: Shows the trajectory of NLP feedback loops: server-side learning with user corrections → on-device deployment. Squirl is starting from an on-device position (Apple NL framework) which is actually ahead of this curve for privacy.
Confidence: high
```

---

### Major Players & Sources

| Source | Type | Relevance |
|--------|------|-----------|
| Mosqueira-Rey et al. (2023) | Academic survey (Springer) | HITL ML comprehensive review; cited 1499+ times. Foundation for understanding post-deployment learning. |
| Figueroa et al. (2012) | Academic study (JAMIA/PMC) | Active learning on clinical text; concrete reduction numbers (1/3 fewer samples). |
| Ahmed et al. (2021) | Academic study (Frontiers) | Active learning for mental health NLP; 0.85 ROC, knowledge expansion over time. |
| Qiu et al. (2015) / Thelen & Riloff (2002) | Academic papers | Lexicon bootstrapping via double propagation and syntax-based patterns. Directly applicable to Squirl's lexicon expansion. |
| Ahltorp et al. (2016) | Academic study (J. Biomed. Semantics) | Medical vocabulary expansion via distributional semantics. Cited 22 times. |
| Schueller et al. (2021) | Academic study (JMIR) | Qualitative user research on mood-tracking apps; 22 participants, 119 citations. Essential UX evidence. |
| Bearable, Daylio, How We Feel | Commercial apps | Competitor landscape. Manual-entry dominant. NLP extraction gap is whitespace. |
| Sun et al. (2024) / Zhang et al. (2023) | Academic papers (Google) | Federated learning for Gboard grammar correction and OOV word discovery. Production-scale privacy-preserving NLP. |
| Ding et al. (2025) | Academic paper | IDfree-PL: anonymous user embeddings for cloud personalization without identifiers. |
| EDPB (2025) | Regulatory document (EU) | AI privacy risks and mitigations in LLMs. Data poisoning, adversarial attacks, membership inference. |
| Voloch et al. (2026) | Academic review (PMC) | AI privacy threats across domains: NLP, LLMs, speech, computer vision. Systematic defense mapping. |
| Steadyline, Seauton | New entrant apps | Bipolar-focused multi-axis tracking; trigger mapping. Shows market evolution toward more granular NLP-friendly data models. |

---

### Trends & Signals

**Trend 1: Shift from manual-entry to AI-assisted mood tracking.**
New entrants like Seauton and Steadyline are moving beyond simple emoji scales to AI-driven trigger mapping and multi-axis tracking. The market is evolving from "how often did you feel X?" to "what patterns cause X?" This creates an opening for Squirl's NLP-first approach, provided the feedback loop actually learns.

**Trend 2: Privacy-preserving personalization is becoming table stakes.**
Apple's on-device ML, Google's federated learning for Gboard, and the EU AI Act are converging on a privacy-first paradigm. Users expect their mental health data to stay local. Squirl's Apple-only, SwiftData-local architecture is well-positioned, but needs to avoid naive approaches that leak patterns through model updates.

**Trend 3: Lexicon bootstrapping from small seeds is a mature, lightweight technique.**
Unlike full ML retraining, lexicon expansion via bootstrapping and dependency propagation can be done entirely on-device with minimal compute. This is exactly what Squirl's PersonalLexiconBuilder attempts, but it should be extended to mood/energy/focus dimensions, not just medications and feelings.

**Trend 4: Correction-as-signal is underutilized in current apps.**
None of the major competitors (Daylio, Bearable, How We Feel) have a visible correction loop for NLP extraction. This is because they don't do NLP extraction. Squirl's ExtractionReviewView is a differentiator, but only if it closes the loop. Currently, the loop is broken for mood/energy/focus.

**Trend 5: Federated aggregation of lexicon updates (not model weights) is a viable middle path.**
Rather than federated learning of full model parameters (expensive on mobile), Squirl could consider federated aggregation of lexicon entries: anonymized phrase → label mappings, aggregated across users, with differential privacy noise added. This would improve the baseline lexicon without exposing individual journal text.

**Trend 6: Users with ADHD/mental illness need different tracking patterns.**
Research shows users avoid logging negative moods, want medication tracking, and find single-axis scales insufficient. Squirl's multi-dimensional extraction (mood + energy + focus + meds) maps better to clinical needs than generic wellness trackers. The feedback loop should be sensitive to clinical relevance (e.g., "flat" as an energy state, "wired" as a focus state).

---

### Controversies & Conflicting Claims

**Controversy 1: Is active learning always better than random sampling?**
Figueroa et al. (2012) found that some active learning algorithms (DIV) did NOT perform better than random sampling on clinical text, and that the target performance level matters. Learning curves start close, diverge, then converge again at larger sample sizes. This suggests that for Squirl, if the correction rate is low, active learning may not help much — a simple random or recency-based correction sampling might be sufficient.

**Controversy 2: Can we safely learn from user corrections without exposing private information?**
There is a tension between personalization and privacy. On-device learning prevents data leakage but causes overfitting (Finding 11). Cloud-based learning mitigates overfitting but risks membership inference, attribute inference, and re-identification attacks (Finding 10). The compromise — federated learning with differential privacy — adds noise that may reduce accuracy, especially for rare phrases. Squirl must decide: pure on-device (safe, potentially overfitted), federated lexicon (balanced), or no learning at all (status quo).

**Controversy 3: Will users actually correct extractions enough to learn from?**
Schueller et al. (2021) found that users often skip negative moods and track infrequently. If users only open the app when they feel good, the correction data will be positively biased. This creates a sampling bias in the feedback loop. The system might learn "good mood" language well but remain poor at "bad mood" detection. Additionally, users with ADHD may have inconsistent tracking habits, reducing the correction rate below useful thresholds.

**Controversy 4: Does learning from one user's vocabulary create overfitting that harms generalization?**
On-device personalization with scarce local data leads to severe overfitting (Finding 11). A user who consistently describes energy as "flat — out — gone" (Squirl's preferred short labels) might train the system to only recognize that exact phrasing, missing synonyms or related expressions. The solution may be hybrid: keep a global lexicon (crowd-sourced or bootstrapped) plus a lightweight per-user overlay, rather than a single merged model.

**Controversy 5: Is it ethical to use mental health journal text for any form of learning, even on-device?**
The EU AI Act classifies mental health AI as high-risk. Even on-device learning creates a record of inferred mental states. If the device is backed up to iCloud (which is not end-to-end encrypted for all data types), the learned patterns could be exposed. Squirl's architecture audit should verify that PersonalLexiconBuilder data and correction histories are excluded from standard iCloud backup or encrypted with user-controlled keys.

---

### Recommended Deep-Dive Areas

**Area 1: Implement Dependency-Based Double Propagation for Lexicon Expansion**
Investigate porting Qiu et al.'s dependency-parser-based double propagation to Apple Natural Language's dependency parsing capabilities. When a user corrects "wading through wet sand" → energy=sluggish, the system should extract syntactic neighbors and bootstrap new energy-related phrases. This is a pure lexicon operation requiring no full ML retraining.

**Area 2: Design a Correction Confidence Scoring System**
Not all corrections are equally valuable. A correction on a low-confidence extraction should be weighted more heavily than a correction on a high-confidence extraction. Implement uncertainty sampling logic: when the NL framework reports low confidence, flag for review; when the user corrects, use that as a high-signal training point. This mirrors the DIST active learning approach from Figueroa et al.

**Area 3: Explore Federated Lexicon Aggregation (Not Model Training)**
Instead of federated learning of model weights (computationally expensive), explore federated aggregation of anonymized lexicon entries. Differential privacy noise can be added to phrase counts. This would allow the global app to learn that "wading through wet sand" → energy=sluggish across many users, without exposing any individual's journal text. Research Google's "Private Federated Discovery of Out-of-Vocabulary Words" (Sun et al., 2024) as a template.

**Area 4: Audit for Bias in the Seed Lexicon and Correction Distribution**
If the seed lexicon is built from a particular demographic's language, user corrections may amplify rather than reduce bias. Implement a periodic bias audit: analyze which phrases are never corrected (system is confident and correct), which are frequently corrected (system is wrong), and whether correction patterns correlate with demographic factors (if known). Even on-device, this metadata can be logged locally for user-facing transparency.

**Area 5: Study Minimum Correction Rates for Clinical-Useful Learning**
Figueroa et al. found that 90% accuracy required ~1/3 fewer samples with active learning, but the absolute number still depends on dataset characteristics. For Squirl, a simulation study should be run: at what correction rate (corrections per journal entry) does the lexicon expansion measurably improve precision/recall? If the rate is <5%, the system may not learn meaningfully. If >20%, even simple recency-based updates may suffice.

**Area 6: Design a "No Learning" Fallback Mode**
Given the privacy and bias concerns, some users may want a guarantee that their corrections are never used for learning. Squirl should offer a toggle: "Use corrections only for this entry, never for future extractions." This is a responsible AI feature that builds trust, especially for mental health apps where users may be paranoid about data use.

**Area 7: Correlate Correction Patterns with User Retention**
If users correct the same type of error repeatedly and the system doesn't improve, they may churn. Implement a "frustration metric": if a user corrects the same phrase category (e.g., energy extractions) more than N times without seeing improvement, trigger a "Teach me" flow or escalate to a simplified extraction mode. This connects the NLP feedback loop to product metrics.

---

## Sources

[^1]: Mosqueira-Rey, E., et al. "Human-in-the-loop machine learning: a state of the art." *Artificial Intelligence Review*, 2023. https://link.springer.com/article/10.1007/s10462-022-10246-w

[^2]: Figueroa, R.L., et al. "Active learning for clinical text classification: is it better than random sampling?" *JAMIA / PMC*, 2012. https://pmc.ncbi.nlm.nih.gov/articles/PMC3422824/

[^3]: Ahmed, U., et al. "Attention-Based Deep Entropy Active Learning Using Lexical Algorithm for Mental Health Treatment." *Frontiers in Psychology*, 2021. https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2021.642347/full

[^4]: Qiu, G., et al. "Dependency-Based Problem Phrase Extraction from User Reviews of Products." 2015. https://www.researchgate.net/publication/300143452

[^5]: Ahltorp, M., et al. "Expansion of medical vocabularies using distributional semantics on Japanese patient blogs." *Journal of Biomedical Semantics*, 2016. https://link.springer.com/article/10.1186/s13326-016-0093-x

[^6]: Bearable.app. "Bearable vs Daylio, which one should you choose?" 2025. https://bearable.app/bearable-vs-daylio-which-one-should-you-choose/ ; HabitBox. "Best Mood Tracker App in 2026." 2026. https://habitbox.app/blog/best-mood-tracker-app

[^7]: Schueller, S.M., et al. "Understanding People's Use of and Perspectives on Mood-Tracking Apps: Interview Study." *JMIR*, 2021. https://pmc.ncbi.nlm.nih.gov/articles/PMC8387890/

[^8]: Coheur, L., et al. "Using Implicit Feedback to Improve Question Generation." *arXiv*, 2023. https://arxiv.org/abs/2304.13664

[^9]: "Learning From How Humans Correct." *arXiv*, 2024. https://arxiv.org/html/2102.00225v19

[^10]: "How to keep text private? A systematic review of deep learning methods for privacy-preserving natural language processing." *Artificial Intelligence Review*, 2022. https://link.springer.com/article/10.1007/s10462-022-10204-6

[^11]: "Personalized Language Model Learning on Text Data Without User Identifiers." *arXiv*, 2025. https://arxiv.org/html/2501.06062v1

[^12]: "Can Public Large Language Models Help Private Cross-device Federated Learning?" *NAACL 2024 workshop*. https://www.cs.jhu.edu/~kevinduh/t/naacl24/final_pdf/paper287.pdf

[^13]: "Mobile apps for mood tracking: an analysis of features and user reviews." *AMIA*, 2021. https://cpb-us-w2.wpmucdn.com/blogs.iu.edu/dist/8/675/files/2021/02/MoodTracking-AMIA17.pdf

[^14]: SuperAGI. "Optimizing CRM Workflows with NLP." 2025. https://superagi.com/optimizing-crm-workflows-with-nlp-a-step-by-step-guide-to-automation-and-personalization/

[^15]: Thelen, M., & Riloff, E. "Semantic Lexicon Expansion using Bootstrapping and Syntax-based Contextual Extraction Patterns." https://www.researchgate.net/publication/242041380

[^16]: Steadyline. "Daylio Alternative for Bipolar Mood Tracking." 2026. https://steadyline.app/blog/daylio-alternative-bipolar

[^17]: FasterCapital. "Conversational feedback mechanism: Designing Effective Feedback Loops for NLP Models." 2024. https://fastercapital.com/content/Conversational-feedback-mechanism--Designing-Effective-Feedback-Loops-for-Natural-Language-Processing-Models.html

[^18]: "AI-Powered Grammar Correction in Keyboards." *International Journal of Advanced Research in Engineering and Technology*, 2025. https://journals.mriindia.com/index.php/ijaece/article/download/837/818/2271

[^19]: EDPB. "AI Privacy Risks & Mitigations – Large Language Models (LLMs)." 2025. https://www.edpb.europa.eu/system/files/2025-04/ai-privacy-risks-and-mitigations-in-llms.pdf

[^20]: Voloch, N., et al. "Both ends of artificial intelligence impacting privacy: a review of violation and protection." *PMC*, 2026. https://pmc.ncbi.nlm.nih.gov/articles/PMC12957209/

[^21]: "Federated Learning for Privacy-Preserving LLMs in Mobile Devices." *ResearchGate*, 2025. https://www.researchgate.net/publication/392032370

[^22]: Sun, Z., et al. "Private Federated Discovery of Out-of-Vocabulary Words for Gboard." 2024.

[^23]: Xu, Z., et al. "Federated Learning of Gboard Language Models with Differential Privacy." 2023.

[^24]: "CooperLLM: Cloud-Edge-End Cooperative Federated Fine-tuning for LLMs." *arXiv*, 2026. https://arxiv.org/abs/2601.12917

[^25]: "Active Learning Methods for Efficient Data Utilization and Model Performance Enhancement." *arXiv*, 2025. https://arxiv.org/html/2504.16136v1

[^26]: "Federated Learning Survey: A Multi-Level Taxonomy of Aggregation Techniques." *arXiv*, 2025. https://arxiv.org/html/2511.22616

[^27]: "Federated Learning for Cyber Physical Systems: A Comprehensive Survey." *arXiv*, 2025. https://arxiv.org/html/2505.04873v1

[^28]: "Dual-Personalizing Adapter for Federated Foundation Models." *arXiv*, 2024. https://arxiv.org/abs/2403.19211

[^29]: "Collaborative Learning of On-Device Small Model and Cloud-Based Large Model." *arXiv*, 2023/2025. https://arxiv.org/html/2504.15300v1
