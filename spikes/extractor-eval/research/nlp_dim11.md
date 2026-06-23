# Dimension 11: Contextual Disambiguation & Word Sense Resolution

## Research Question
How should an ADHD journaling app handle polysemy and contextual disambiguation in short clinical/diary text? The app currently suffers from surface-based false positives (e.g., "gym bag felt heavy" → energySluggish, "clear my head" → focusSharp) and relies on a narrow "feel" carrier-phrase strategy that is not general.

---

## Executive Summary

General Word Sense Disambiguation (WSD) is a mature but heavyweight NLP discipline. For short diary/clinical text, three tensions dominate: (1) **context is sparse** — classic WSD methods assume rich surrounding text; (2) **the domain is narrow** — only a small subset of English polysemous words matter for mood/energy/focus tracking; (3) **on-device constraints** rule out large transformer models. The evidence suggests that a **hybrid, domain-targeted approach** — combining lightweight contextual embeddings, collocational blocking lists, and a small set of carrier/contra-indicator phrases — is more practical than deploying full WSD, while still needing more principled disambiguation than the current "feel" kludge.

---

### Key Findings

#### Finding 1: WSD for Short Text Is Fundamentally Harder

```
Claim: Microtext (sparse, informal short text) lacks exploitable context for WSD, creating a major challenge that supplemental context or expansion methods must address.
Source: Black et al., IEEE Tenth International Conference on Semantic Computing (2016)
URL: https://ieeexplore.ieee.org/abstract/document/7814724
Date: 2016-11-06
Excerpt: "WSD relies on the senses of words around an ambiguous word to disambiguate it. Because microtext is sparse and informal, it lacks exploitable context. This creates a major challenge for using this kind of data and consequently to the analyses of studies that rely on microtext sources."
Context: Paper proposes supplemental context for Twitter WSD; validates on ~10,000 tweets using a "blue standard" proxy based on one-sense-per-collocation.
Confidence: high
```

> Relevance: Diary entries are often microtext-length (5–15 words). The core WSD assumption — that surrounding words provide disambiguating signal — breaks down when there are barely any surrounding words.

#### Finding 2: State-of-the-Art WSD Uses BERT + Gloss Knowledge, But Is Heavy

```
Claim: Fine-tuning BERT on context-gloss pairs (GlossBERT) achieves state-of-the-art all-words WSD by treating disambiguation as a sentence-pair classification task.
Source: Huang et al., GlossBERT: BERT for Word Sense Disambiguation with Gloss Knowledge (EMNLP 2019)
URL: https://arxiv.org/pdf/1908.07245v4.pdf
Date: 2019-08 (revised 2020-01)
Excerpt: "We construct context-gloss pairs and propose three BERT-based models for WSD. We fine-tune the pre-trained BERT model on SemCor 3.0 training corpus and the experimental results on several English all-words WSD benchmark datasets show that our approach outperforms the state-of-the-art systems."
Context: GlossBERT outperformed traditional word-expert SVMs and earlier neural models. Key insight: converting WSD to an NLI-like sentence-pair task lets BERT exploit its pre-trained pair-wise reasoning.
Confidence: high
```

> Relevance: This is the current SOTA for general-domain WSD. However, BERT-base is ~110M parameters — far too large for on-device inference in a journaling app. Fine-tuning also requires sense-annotated corpora (SemCor) which do not cover emotion-specific polysemy.

#### Finding 3: Contextual Embeddings Capture Polysemy *Partially*, But Not Enough for Fine-Grained WSD

```
Claim: Even without explicit WSD fine-tuning, contextualized embeddings (ELMo, BERT) can distinguish word senses via 1-nearest-neighbor vector methods, but they do not match supervised WSD performance.
Source: Peters et al. 2018 (cited in Raganato et al. 2017; A Comparative Study of Transformers on WSD, 2021)
URL: https://arxiv.org/abs/2111.15417
Date: 2021-11-30
Excerpt: "Models that perform well on this task are able to separate the different semantic meaning of a word, depending on the context it is used in. ... Experiment 1 demonstrates that Binder features can be derived from various transformer embedding spaces and that some effects of context can be picked up."
Context: Comparative study of nine transformers on WSD found that k-NN on contextual embeddings achieves competitive but not SOTA results. BERT alone without gloss knowledge underperforms traditional supervised methods.
Confidence: high
```

> Relevance: The app could use lightweight contextual embeddings (e.g., Apple NLP word embeddings) to get *some* sense separation, but this alone will not reliably distinguish "heavy" (physical) from "heavy" (emotional). The eval examples show exactly this failure mode.

#### Finding 4: WSD Improves Sentiment Analysis for Figurative Language

```
Claim: Applying WSD to sentiment analysis of figurative language improves accuracy over bag-of-words classifiers, and sense-level polarity assignment outperforms token-level approaches.
Source: Sumanth & Inkpen, Sentiment Analysis of Figurative Language using a Word Sense Disambiguation Approach (ResearchGate)
URL: https://www.researchgate.net/publication/215803149
Date: ~2015
Excerpt: "Our experiments show that the use of Word Sense Disambiguation alone has resulted in an improved sentiment analysis system that outperforms systems built without incorporating Word Sense Disambiguation."
Context: System targets micro-post data (tweets, SMS). Also cites Rentoumi et al. (2009) showing WSD is valuable in polarity classification of sentences containing figurative expressions.
Confidence: medium
```

> Relevance: This directly supports the claim that emotion/sentiment extraction from short text benefits from WSD. However, the improvement is modest (~3 percentage points in cited prior work), and the systems still rely on external sense inventories (WordNet) that do not map cleanly to emotion categories.

#### Finding 5: Metaphor and Emotion Words Are Deeply Polysemous

```
Claim: Metaphorical expressions are dominant sentiment-bearing parts of sentences, and their senses must be disambiguated before polarity can be assigned. Words like "cold" can be neutral ("cold winter") or negative ("cold answer") depending on activated sense.
Source: SentiFig dissertation (Sentiment Analysis of Metaphorical Language)
URL: https://www.icsd.aegean.gr/website_files/diplomatikes/phd/375138372.pdf
Date: ~2014
Excerpt: "In the first stage we exploit WSD since it is known that words can have different polarities depending on the sense they activate in a specific context. For instance, the phrase 'a cold winter' implies a neutral polarity orientation, while the phrase 'a cold answer' connotes a negative polarity orientation, as in this particular context the adjective 'cold' activates a metaphorical meaning."
Context: Three-stage approach: WSD → Sense-Level Polarity Assignment → Sentence-Level Polarity Detection. Evaluated on figurative language corpora.
Confidence: high
```

> Relevance: The app's "heavy", "clear", "light", "flat" problem is exactly this: physical senses are neutral/objective, while emotional/metaphorical senses carry signal. Without WSD, a surface lexicon conflates them.

#### Finding 6: Domain-Specific WSD Can Outperform General Supervised Systems

```
Claim: When applied to specific domains, knowledge-based WSD systems can outperform generic supervised WSD systems trained on balanced corpora, because domain sense distributions differ from general English.
Source: Agirre et al., Knowledge-Based WSD and Specific Domains (IJCAI 2009)
URL: https://www.ijcai.org/Proceedings/09/Papers/251.pdf
Date: 2009
Excerpt: "The results show that in all three corpora our knowledge-based WSD algorithm improves over previous results, and also over two state-of-the-art supervised WSD systems trained on SemCor... the results are higher for domain-specific corpus than for the general corpus, raising interesting prospects for improving current WSD systems when applied to specific domains."
Context: Evaluated on Sports and Finance domains. Personalized PageRank over related words obtained best results for domain-specific texts.
Confidence: high
```

> Relevance: The app operates in a very narrow domain (self-reported mental/physical state). A domain-targeted disambiguation approach — rather than general WordNet WSD — is theoretically sound and may be more accurate.

#### Finding 7: Clinical WSD Shows That Short Context Windows Are Viable with Topic Models

```
Claim: In clinical text, topic-modeling WSD with a restricted six-word context window outperforms graph-based methods using UMLS, and even approaches supervised SVM performance with modest annotated data.
Source: Chasin et al., Word sense disambiguation in the clinical domain (JAMIA / PMC)
URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC4147600/
Date: 2014
Excerpt: "The topic-modeling methods achieve 66.9% accuracy on a subset of the Mayo Clinic's data, while the graph-based methods only reach the 40–50% range... The fact that topic-modeling techniques perform well with a restricted context window (six closest words) suggests that this approach may prove more suitable for clinical applications where little context is available."
Context: Clinical text is abbreviated, template-heavy, and noisy. Topic models (LDA, HDP) induced sense clusters from unlabeled MIMIC-II nursing notes.
Confidence: high
```

> Relevance: Diary entries share clinical-text characteristics: short, informal, sparse. A six-word window is often all the context available. Topic/induction approaches may work better than heavy knowledge-graph methods.

#### Finding 8: Tweet Expansion / Context Enrichment Improves Short-Text Sentiment

```
Claim: Enriching short tweets with semantically related terms from WordNet/ConceptNet/Wikipedia before sentiment classification improves F-score significantly over raw tweets.
Source: Tahayna et al., Context-Aware Sentiment Analysis using Tweet Expansion Method (J. ICT Res. Appl., 2022)
URL: https://pdfs.semanticscholar.org/76ad/eefbd0fa8c33ee637e312e8179221db59cc7.pdf
Date: 2022
Excerpt: "The obtained results showed that classification of consumer sentiment achieved a better F-score when using the expanded tweets over the raw baseline tweets... regardless which embedding technique was used, the accuracy of the proposed enrichment data representations outperformed the raw baseline data set."
Context: Hybrid CNN+LSTM model. Tested Word2Vec, GloVe, FastText, ELMo, BERT, Wiki2Vec. Enrichment adds synonyms, hypernyms, hyponyms from external knowledge.
Confidence: medium
```

> Relevance: If the app cannot do full WSD, it could at least expand the sparse context with related terms to reduce false positives. However, this risks introducing noise.

#### Finding 9: General WSD May Be Overkill for Narrow Domains

```
Claim: When restricting an NLP application to a domain, one is effectively using the "one sense per discourse" hypothesis to eliminate most semantic ambiguity of polysemous words. Current NLU applications are mostly domain-specific.
Source: Escudero, Machine Learning Techniques for Word Sense Disambiguation (PhD thesis, UPC, 2006)
URL: https://www.cs.upc.edu/~escudero/wsd/06-tesi.pdf
Date: 2006
Excerpt: "Obviously, when restricting the application to a domain we are, in fact, using the 'one sense per discourse' hypothesis to eliminate most of the semantic ambiguity of polysemous words... current NLU applications are mostly domain specific."
Context: Reviews applications of WSD and argues that domain restriction radically reduces the ambiguity problem.
Confidence: high
```

> Relevance: The app's domain is extremely narrow: mood, energy, focus, sleep, appetite. The number of polysemous words that actually matter is small (heavy, light, clear, sharp, flat, empty, spent, lost, etc.). Full WSD over all WordNet senses is massive overkill.

#### Finding 10: Data Augmentation on Glosses Improves WSD, But Requires Training

```
Claim: Augmenting context-gloss pairs via back-translation and hypernym glosses improves WSD F1, but the best gains come from augmenting glosses (not context) with a closely related language (German).
Source: Lin & Giambi, Context-gloss Augmentation for Improving Word Sense Disambiguation (arXiv 2021)
URL: https://arxiv.org/pdf/2110.07174.pdf
Date: 2021-10-14
Excerpt: "All augmentation methods applied to gloss increase the performance... back translation offers an even more significant improvement. The f1 score increases to 0.800 when using German... back translation performs better when used on gloss compared to when it's used on context."
Context: Builds on GlossBERT. Explores back-translation (De/Ru/Fr), hypernym/hyponym glosses, synonym replacement, and MLM augmentation.
Confidence: high
```

> Relevance: For a narrow emotion domain, one could manually define "glosses" (sense definitions) for each relevant polyseme and use a lightweight sentence-pair classifier. But this is still a supervised/fine-tuned approach, not a simple rule system.

#### Finding 11: Edge Deployment of Language Models Is Possible But Constrained

```
Claim: Small Language Models (SLMs) with ≤3B parameters can run on edge devices, offering privacy and offline use, but they trade capability for size. Quantization and pruning are required.
Source: DeepSense AI / various industry sources (2024–2025)
URL: https://deepsense.ai/blog/implementing-small-language-models-slms-with-rag-on-embedded-devices/
Date: 2024-04-25
Excerpt: "We can consider models with more than 7 billion parameters as LLMs... we consider models lightweight enough to run on edge devices, typically with 3 billion parameters or less."
Context: Focuses on SLMs + RAG on embedded devices. Notes trade-offs between model size and retrieval chunk count.
Confidence: medium
```

> Relevance: Even "small" 3B-parameter models are far beyond what a journaling app can run per-entry for real-time tagging. Apple NLP embeddings or tiny BERT variants are the realistic ceiling.

#### Finding 12: WSD Explicitly Listed As a Semantics-Layer Problem for Sentiment Analysis

```
Claim: In holistic sentiment analysis frameworks, WSD sits in the semantics layer alongside concept extraction and NER, indicating it is a recognized prerequisite for accurate sentiment understanding.
Source: Systematic reviews in sentiment analysis: a tertiary study (Artificial Intelligence Review, 2021)
URL: https://link.springer.com/article/10.1007/s10462-021-09973-3
Date: 2021-03-03
Excerpt: "Cambria et al. (2017) stated that a holistic approach to sentiment analysis is required... They presented the problem as a three-layer structure that includes 15 Natural Language Processing (NLP) problems as follows: Syntactics layer... Semantics layer: Word sense disambiguation, concept extraction..."
Context: Tertiary study of sentiment analysis reviews. Classifies WSD as a core semantics-layer component.
Confidence: high
```

> Relevance: The research community treats WSD as a legitimate concern for sentiment/emotion analysis, not a theoretical luxury.

---

### Major Players & Sources

| Source / System | Type | Key Contribution | Relevance to App |
|-----------------|------|------------------|-----------------|
| **GlossBERT** (Huang et al., Fudan) | Neural WSD | BERT + gloss pairs → SOTA all-words WSD | Proof that gloss-aware contextual models work; too heavy for edge |
| **Context-gloss Augmentation** (Lin & Giambi, NTHU) | Data augmentation | Back-translation + hypernym glosses improve WSD | Method for expanding limited training data if app pursues supervised WSD |
| **Agirre et al. (Basque Country)** | Knowledge-based WSD | Personalized PageRank over WordNet for domain-specific WSD | Domain-targeted KB-WSD can beat generic supervised systems |
| **Chasin et al. (Mayo Clinic / JAMIA)** | Clinical WSD | Topic modeling (LDA/HDP) with 6-word windows outperforms UMLS graphs | Short-context WSD is viable with induction methods; clinical parallels to diary text |
| **Black et al. (IEEE)** | Short-text WSD | Supplemental context for microtext WSD | Core evidence that sparse diary text breaks standard WSD assumptions |
| **Sumanth & Inkpen** | WSD for sentiment | WSD improves figurative-language sentiment on tweets/SMS | Direct evidence that emotion extraction from short text needs WSD |
| **SentiFig** (PhD thesis, Aegean) | Metaphor + sentiment | Three-stage: WSD → sense polarity → sentence polarity | Framework for how metaphorical emotion words ("cold answer") require sense disambiguation |
| **Tahayna et al.** | Tweet expansion | WordNet/ConceptNet enrichment improves sentiment F-score | Alternative to WSD: expand context rather than disambiguate |
| **WiC Benchmark** (Pilehvar & Camacho-Collados, 2019) | Evaluation | Binary same/different sense task for minimal pairs | Relevant benchmark: even minimal context can be tested, but models struggle without enough signal |
| **Apple NLP / Natural Language framework** | On-device NLP | Lemmatization, PoS tagging, named entity recognition, word embeddings | Realistic platform for the app; no built-in WSD, but contextual embeddings available |

---

### Trends & Signals

1. **Short-context WSD is an active frontier.** The WiC dataset (2019), Elexis-WSD (2021), and clinical topic-modeling work (2014) all demonstrate that WSD with minimal context is possible but requires different techniques than traditional long-context methods. The "blue standard" proxy (one-sense-per-collocation) is increasingly used when gold sense annotations are unavailable.

2. **Contextual embeddings are necessary but insufficient.** BERT/ELMo implicitly capture some sense distinctions, but for WSD benchmarks they underperform dedicated supervised systems unless augmented with gloss knowledge (GlossBERT). For the app, this means Apple NLP embeddings alone will not solve the "heavy"/"clear" problem.

3. **Domain restriction reduces the WSD burden.** Multiple sources (Escudero 2006; Agirre et al. 2009; Palacios 2024) note that narrow domains have far fewer active senses per word. A journaling app does not need to disambiguate "bank" (river/financial); it only needs to handle ~20–30 emotion-relevant polysemes.

4. **Clinical NLP parallels are strong.** Clinical notes and diary entries share: abbreviations, shorthand, templates, sparse context, and the need to distinguish physical vs. mental/state descriptions. The clinical WSD literature (Chasin, Savova, MetaMap) treats context windows as small as 6 words as standard.

5. **LLM-based approaches are emerging for low-resource WSD.** The 2025 Slovene WSD paper shows that LLMs (GPT-3.5) can extend short dictionary examples into complete training sentences. This opens a path to synthetic data for rare emotion senses, but requires verification.

---

### Controversies & Conflicting Claims

**Claim A: WSD is essential for sentiment/emotion analysis.**
- *Supported by:* Sumanth & Inkpen, SentiFig, Cambria et al. (systematic review), Rentoumi et al. (2009).
- *Counter:* Many production sentiment systems (VADER, TextBlob, AFINN) ignore WSD entirely and perform adequately on literal language. The gain from WSD is largest for figurative/metaphorical text, which is common in diaries but rare in product reviews.

**Claim B: The "feel" carrier strategy is sufficient.**
- *Supported by:* The app currently uses it; it works for "feel heavy", "feel empty", "feel spent".
- *Counter:* It fails for "light rain" (no "feel"), "clear my head" (different verb), "sharp pain" (physical), "flat tire" (physical). It is not compositional or general. The eval set explicitly shows false positives that "feel" cannot catch.

**Claim C: Embeddings implicitly solve polysemy.**
- *Supported by:* WiC benchmark results show BERT embeddings can distinguish senses without explicit WSD training; "some effects of context can be picked up."
- *Counter:* Without gloss-aware fine-tuning, BERT alone underperforms traditional supervised WSD (GlossBERT paper, Table 3). And for very short text (2–6 words), there may not be enough context tokens for the transformer to resolve ambiguity.

**Claim D: General WSD is overkill for this app.**
- *Supported by:* Escudero 2006 (domain restriction eliminates most ambiguity); the app only cares about ~20 polysemes; full WordNet has 100K+ senses.
- *Counter:* Even a narrow domain needs *some* principled mechanism. Hand-coding carriers for every polyseme does not scale. The risk of a narrow solution is that new polysemes (e.g., "sharp", "dull", "raw", "broken") emerge continuously in user data.

**Claim E: Short text makes WSD impossible / unnecessary.**
- *Supported by:* Black et al. (microtext lacks exploitable context); Moon et al. (coarse-grained ambiguities need 80-word windows for supervised resolution).
- *Counter:* Chasin et al. show 6-word windows work with topic models; WiC dataset proves minimal pairs can be classified; supplemental context (tweet expansion) can artificially increase context.

---

### Recommended Deep-Dive Areas

1. **Domain-Specific Sense Inventory for Mood/Energy/Focus.** Instead of WordNet, create a lightweight custom inventory with only two senses per relevant polyseme: {physical, emotional/mental}. For "heavy": physical_weight vs. emotional_burden. For "clear": physical_visibility vs. mental_clarity. This collapses the WSD problem to binary classification per word, which is tractable with tiny models.

2. **Collocational Blocklists (Anti-Carriers).** Complement the "feel" carrier with *negative* indicators: if "heavy" co-occurs with {rain, bag, box, weight, gym, lift}, block energySluggish. If "clear" co-occurs with {sky, day, weather, rain, glass, picture}, block focusSharp. This is essentially a Lesk-like overlap approach but with a domain-specific micro-lexicon.

3. **Evaluate Apple NLP Embeddings on WiC-Style Pairs.** Construct a minimal in-house dataset of emotion polyseme pairs (e.g., "gym bag felt heavy" vs. "mind felt heavy today") and test whether Apple NLP's contextual word embeddings can distinguish them via cosine similarity. This directly tests Claim C for the app's platform.

4. **Context Expansion vs. Explicit WSD Trade-off Study.** Compare two approaches on the eval set: (a) expand sparse diary entries with WordNet synonyms/hypernyms before lexicon matching; (b) add a tiny binary sense classifier for each polyseme. Measure precision/recall, latency, and model size.

5. **User-Specific Adaptation.** The app is personal. A user's "heavy" may almost always mean emotional burden. Topic-modeling / induction approaches (LDA/HDP) can learn per-user sense distributions from their own history, reducing the need for universal rules. This mirrors the personalized seed-term approach in the clinical depression monitoring paper.

6. **SentiWordNet / Sense-Level Polarity Lexicon.** Investigate whether a sense-aware polarity resource (e.g., SentiWordNet) can replace the current flat lexicon. Each word-sense synset has positive/negative/objective scores. If "heavy" (physical) is objective and "heavy" (emotional) is negative, sense-aware matching would eliminate the false positive without needing a full WSD pipeline.

7. **Hybrid: Lexicon + Tiny WSD for Top-K Polysemes.** A pragmatic middle ground: keep the flat lexicon for monosemous words, but apply a lightweight disambiguation step (carrier phrases + collocational blocklists + embedding similarity) only for the ~20 known polysemes that cause false positives. This keeps the system fast and small while addressing the demonstrated failure modes.

---

## Footnotes

[^1]: Black et al., "Introducing Supplemental Context for Word Sense Disambiguation," IEEE ICSC 2016. https://ieeexplore.ieee.org/abstract/document/7814724

[^2]: Huang et al., "GlossBERT: BERT for Word Sense Disambiguation with Gloss Knowledge," EMNLP 2019. https://arxiv.org/pdf/1908.07245v4.pdf

[^3]: Chawla, "A Comparative Study of Transformers on Word Sense Disambiguation," arXiv 2021. https://arxiv.org/abs/2111.15417

[^4]: Sumanth & Inkpen, "Sentiment Analysis of Figurative Language using a Word Sense Disambiguation Approach." https://www.researchgate.net/publication/215803149

[^5]: SentiFig PhD thesis, "Sentiment Analysis of Metaphorical Language." https://www.icsd.aegean.gr/website_files/diplomatikes/phd/375138372.pdf

[^6]: Agirre et al., "Knowledge-Based WSD and Specific Domains," IJCAI 2009. https://www.ijcai.org/Proceedings/09/Papers/251.pdf

[^7]: Chasin et al., "Word sense disambiguation in the clinical domain," JAMIA / PMC 2014. https://pmc.ncbi.nlm.nih.gov/articles/PMC4147600/

[^8]: Tahayna et al., "Context-Aware Sentiment Analysis using Tweet Expansion Method," J. ICT Res. Appl. 2022. https://pdfs.semanticscholar.org/76ad/eefbd0fa8c33ee637e312e8179221db59cc7.pdf

[^9]: Escudero, "Machine Learning Techniques for Word Sense Disambiguation," PhD thesis, UPC 2006. https://www.cs.upc.edu/~escudero/wsd/06-tesi.pdf

[^10]: Lin & Giambi, "Context-gloss Augmentation for Improving Word Sense Disambiguation," arXiv 2021. https://arxiv.org/pdf/2110.07174.pdf

[^11]: DeepSense AI, "Implementing Small Language Models (SLMs) with RAG on Embedded Devices," 2024. https://deepsense.ai/blog/implementing-small-language-models-slms-with-rag-on-embedded-devices/

[^12]: Systematic review in sentiment analysis, "Sentiment analysis: a tertiary study," Artificial Intelligence Review 2021. https://link.springer.com/article/10.1007/s10462-021-09973-3

[^13]: Palacios et al., "Word Sense Disambiguation for Linking Domain-Specific...," CEUR-WS 2024. https://ceur-ws.org/Vol-3797/paper20.pdf

[^14]: Pilehvar & Camacho-Collados, "WiC: the Word-in-Context Dataset," NAACL 2019. https://pilehvar.github.io/wic/

[^15]: Zuheros et al., "Deep recurrent neural network for geographical entities disambiguation on social media data," Knowledge-Based Systems 2021. https://www.sciencedirect.com/science/article/abs/pii/S0950705119300917
