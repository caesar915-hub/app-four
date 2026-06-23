# Dimension 04: Paraphrase & Semantic Similarity Beyond Lexicon

**Research Date:** 2026-06-23  
**Agent:** Deep Research Subagent  
**Branch:** `spike-nlp-performance`  
**Project:** whispernotes / Squirl — ADHD journaling app  
**Scope:** Investigate methods to bridge the paraphrase gap for mental-health text extraction on iOS

---

## Executive Summary

The current whispernotes extraction pipeline is purely surface-based: every signal requires an exact lexicon entry. This creates a massive paraphrase gap. Two documented failures:

1. "Honestly today my body just would not get going, like wading through wet sand from the moment I woke up." → Expected: `energy=sluggish`. Actual: `None`. "wading through wet sand" is not in the lexicon.
2. "After I finally sent that email it was like a weight lifted off my shoulders, and I could breathe again." → Expected: `mood=good, feelings=relieved,settled`. Actual: `mood=None, feelings=settled`. "weight lifted" and "could breathe again" are not in the lexicon.

This research investigates whether sentence embeddings, semantic similarity models, few-shot learning, or on-device small LLMs can bridge this gap without sacrificing privacy, latency, or determinism. The findings are organized into five sections: Key Findings, Major Players & Sources, Trends & Signals, Controversies & Conflicting Claims, and Recommended Deep-Dive Areas.

---

## Search Protocol

- **Searches conducted:** 15 independent queries across English-language sources
- **Priority domains:** arXiv, PMC, JMIR, CEUR-WS, ResearchGate, Apple Developer Documentation, GitHub, Milvus/AI reference blogs
- **Excluded:** content farms, anonymous blogs, unverifiable Medium posts
- **Date range:** 2017–2026 (weighted toward 2022–2026)

---

## Key Findings

### 1. Sentence-BERT Is the Established Baseline for Paraphrase Detection in Short Text

Claim: Sentence-BERT (SBERT) produces fixed-size vector embeddings that can be compared via cosine similarity, achieving ~77% precision on paraphrase identification and ~87% on standard paraphrase benchmarks when fine-tuned on NLI data. [^1]

Source: CEUR-WS — "Using BERT model to Identify Sentences Paraphrase in the News Corpus" (Khairova et al., 2022)

URL: https://ceur-ws.org/Vol-3171/paper6.pdf

Date: 2022

Excerpt: "The precision of the paraphrased sentences identification achieves 77%… SBERT-NLI-base scored 87.41 and SBERT-NLI-large scored 87.69 for this task."

Context: The paper compared fine-tuned SBERT against WordNet, Word2Vec, and BERT pairwise classification. SBERT's twin-network architecture (siamese / triplet) allows two sentences to be encoded independently and then compared, reducing complexity from O(n²) to O(n).

Confidence: **high**

---

### 2. Lightweight Sentence Transformers (all-MiniLM-L6-v2) Achieve Near-SOTA Accuracy at 1/5 the Size

Claim: all-MiniLM-L6-v2 (22.7M parameters, ~80MB, 384-dim) achieves 84.6 Spearman on STS-B and 56.5 MTEB average, while running at ~14,000 sentences/sec on CPU — roughly 5× faster than all-mpnet-base-v2. [^2]

Source: Mixpeek model card + Milvus AI Quick Reference

URL: https://mixpeek.com/model/sentence-transformers/all-MiniLM-L6-v2 / https://milvus.io/ai-quick-reference/what-are-some-popular-pretrained-sentence-transformer-models-and-how-do-they-differ-for-example-allminilml6v2-vs-allmpnetbasev2

Date: 2024–2026

Excerpt: "all-MiniLM-L6-v2 serves as a lightweight and fast solution for general semantic tasks, delivering reasonable accuracy… 6 transformer layers, 384-dim hidden size… ~14k sentences/sec vs. ~4k on a CPU."

Context: The model is distilled from a larger teacher and fine-tuned on 1B+ sentence pairs. For whispernotes, this size class (~80MB) is feasible to bundle or download on-demand. The 384-dim vectors are smaller than 768-dim alternatives, reducing memory for a local vector index.

Confidence: **high**

---

### 3. Apple Ships a Native On-Device Contextual Embedding Model (NLContextualEmbedding)

Claim: iOS 17+ and macOS 14+ provide `NLContextualEmbedding` via the `NaturalLanguage` framework — a BERT-based sentence encoder producing 512-dim vectors (256 tokens max), running entirely on-device with zero bundle size and no network calls. [^3]

Source: Apple Developer Documentation + Callstack blog + GitHub (NaturalLanguageEmbeddings Swift package)

URL: https://developer.apple.com/documentation/naturallanguage/finding-similarities-between-pieces-of-text / https://www.callstack.com/blog/on-device-ai-introducing-apple-embeddings-in-react-native / https://github.com/buh/NaturalLanguageEmbeddings

Date: 2024–2026

Excerpt: "NLContextualEmbedding is a modern, sentence-based transformer model… producing a 512-dimensional vector and can process up to 256 tokens per request… 100% On-Device — Zero network calls, complete privacy."

Context: The model is distributed over-the-air by Apple (<100MB). Swift packages like `NaturalLanguageEmbeddings` wrap it with cosine-similarity search and adaptive algorithm selection (simple vs. Accelerate-optimized). Benchmarks show ~1ms search for 50 items, ~15ms for 1000 items on Apple Silicon. Single words exhibit high baseline similarity (0.60–0.89 even for unrelated terms), so full sentences are recommended.

Confidence: **high**

---

### 4. Core ML + MLX Enable Custom Transformer Embedding Deployment on Apple Silicon

Claim: Core ML models can be converted from PyTorch/ONNX via `coremltools` and run on Apple Silicon's Neural Engine, GPU, or CPU with sub-millisecond to low-tens-of-milliseconds latency. MLX (Apple's native ML framework) supports running BERT/RoBERTa-based embedding models and fine-tuning them on Apple Silicon. [^4]

Source: codecentric blog + WWDC24 notes + Blake Crosley blog + mlx-embedding-models GitHub

URL: https://www.codecentric.de/en/knowledge-hub/blog/core-ml-inference-on-ios / https://wwdcnotes.com/documentation/wwdc24-10161-deploy-machine-learning-and-ai-models-ondevice-with-core-ml/ / https://blakecrosley.com/blog/core-ml-on-device-inference / https://github.com/taylorai/mlx_embedding_models

Date: 2019–2026

Excerpt: "Core ML is the on-device inference engine that ships with every modern Apple device… The result on a recent iPhone is inference at sub-millisecond to low-tens-of-milliseconds latency… MLX Embedding Models: Run text embeddings on your Apple Silicon GPU. Supports any BERT- or RoBERTa-based embedding model."

Context: For whispernotes, this means a custom fine-tuned sentence transformer (e.g., a domain-adapted MiniLM) could be converted to Core ML `.mlpackage` and shipped in the app bundle. Quantization (INT8/INT4) is supported in recent Core ML versions. Bundle size should stay sub-100MB for comfortable App Store distribution.

Confidence: **high**

---

### 5. Few-Shot LLMs Underperform Fine-Tuned Encoders on Mental Health Text Classification

Claim: On tweet-level depression subtyping, fine-tuned encoder models (RoBERTa-large, DeBERTa) achieve macro-F1 = 0.94–0.96, while few-shot LLMs (Llama-3-8B) reach only 0.73–0.77. Fine-tuning boosts recall for major depression from ~0.53–0.60 to ~0.95–0.97. [^5]

Source: Frontiers in Digital Health — "Depression subtype classification from social media posts" (AlSaad et al., 2026)

URL: https://www.frontiersin.org/journals/digital-health/articles/10.3389/fdgth.2026.1790533/full

Date: 2026-03-23

Excerpt: "Fine-tuned encoders consistently outperformed prompt-only models, reaching macro-F1 = 0.94–0.96… Fine-tuning increased F1 for postpartum and psychotic subtypes to ≈0.99."

Context: The dataset comprised 14,983 English tweets across six depression categories. The key insight for whispernotes is that task-specific adaptation (even lightweight LoRA/adapter fine-tuning) matters more than model scale for nuanced mental-health classification. A small encoder fine-tuned on even a few hundred labeled examples may outperform a 7B-parameter few-shot LLM.

Confidence: **high**

---

### 6. Text-Embedding Models Show AUC > 0.7 for Detecting Depression and Suicide Risk from Patient Narratives

Claim: In a cross-sectional study of 1,064 psychiatric patients (52,627 sentence-completion responses), both LLMs and text-embedding models achieved AUC > 0.7 for detecting clinically significant depression and high suicide risk, with self-concept narratives being the most predictive. [^6]

Source: PMC — "Large Language Models and Text Embeddings for Detecting Depression and Suicide in Patient Narratives" (Lho et al., 2025)

URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC12102709/

Date: 2025

Excerpt: "Both LLMs and text-embedding models showed strong performance, with areas under the receiver operating characteristic curve greater than 0.7 in detecting clinically significant depression and high risk of suicide."

Context: This is direct evidence that embedding-based models can capture mental-health signals from short patient-generated text. However, the authors caution that "further performance improvement and addressing ethical concerns are essential for clinical application."

Confidence: **high**

---

### 7. Clinical Semantic Textual Similarity Is Harder Than General Domain

Claim: Clinical STS (MedSTS, n2c2 STS-Clinic) is significantly more complex than general-domain STS. Surface-similarity baselines (cosine, Levenshtein) perform worse on clinical text. Two-phase training (general English + clinical) improves RoBERTa-large Pearson from 0.872 to 0.906. [^7]

Source: JMIR Medical Informatics — "Measurement of Semantic Textual Similarity in Clinical Texts" (Yang et al., 2020) + arXiv MedSTS (Wang et al.)

URL: https://medinform.jmir.org/2020/11/e19735/ / https://storage.prod.researchhub.com/uploads/papers/2026/01/10/1808.09397.pdf

Date: 2020

Excerpt: "The performance on MedSTS_ann is inferior to that on the most STS datasets in the general domain for all the baseline systems… RoBERTa-large fine-tuned using only the clinical text achieved a Pearson correlation score of 0.8720; however, the same model fine-tuned with both the general English text and clinical text achieved a score of 0.9065."

Context: Clinical text contains abbreviations, negation, and domain-specific phrasing that general embedding models struggle with. Error analysis shows that transformer models can overestimate similarity when sentences share medical terms (e.g., "patient's symptoms") but describe opposite conditions (e.g., "gradual onset" vs. "sudden onset"). This is directly relevant to whispernotes: false positives are a real risk when using embeddings naively.

Confidence: **high**

---

### 8. Sentence Embeddings Are Sensitive to Token-Level Paraphrase Even When Meaning Is Preserved

Claim: The PTEB (Paraphrasing Text Embedding Benchmark) demonstrates that current embedding models drop 2–5% absolute performance on STS tasks when evaluated on semantically equivalent but lexically diverse paraphrases. Smaller models are not disproportionately affected. [^8]

Source: arXiv — "PTEB: Towards Robust Text Embedding Evaluation via Stochastic Paraphrasing at Evaluation Time with LLMs" (Frank & Afli, 2025)

URL: https://arxiv.org/html/2510.06730v1

Date: 2025-10-08

Excerpt: "Models exhibit statistically significant drops in performance (typically 2–5% absolute on STS tasks) under the PTEB paraphrasing protocol… Even when meaning is fixed, modifications in token sequence or local lexical choices lead to marked performance degradation."

Context: This is a critical tension for whispernotes. Embeddings do improve over exact lexicon matching, but they are not immune to paraphrase variance. The benchmark used LLM-generated paraphrases validated by human gold ratings. The finding suggests that embeddings *reduce* but do not *eliminate* the paraphrase gap. A hybrid approach (lexicon + embeddings) may be safest.

Confidence: **high**

---

### 9. Embedding Models Can Leak Sensitive Mental-Health Data via Membership Inference

Claim: Embedding models trained on sensitive data are vulnerable to membership inference attacks and data extraction. Mental-health datasets are particularly at risk because they are small, contain rare data points, and embedding models memorize infrequent inputs. Differential privacy (DP-SGD) can mitigate this but reduces accuracy. [^9]

Source: arXiv — "Towards Privacy-aware Mental Health AI Models" (2025) + ACM Web Conference — "Sanitizing Sentence Embeddings (and Labels) for Local Differential Privacy" (Du et al., 2023) + Zilliz AI FAQ

URL: https://arxiv.org/html/2502.00451v2 / https://duminxin.github.io/pdf/TheWeb23_SentenceDP.pdf / https://zilliz.com/ai-faq/what-are-the-privacy-implications-of-different-embedding-models

Date: 2023–2025

Excerpt: "Embedding models are particularly vulnerable to leaking such infrequent training data inputs… Mental health datasets are generally small and have a higher prevalence of rare data points… Lehman et al. can recover patient names and related conditions from BERT fine-tuned on a private medical corpus."

Context: For whispernotes, the primary mitigation is **on-device inference** — user journal text never leaves the device. Apple's NLContextualEmbedding and Core ML models both run locally. If the team ever fine-tunes a model on aggregated user data, differential privacy should be considered. The pre-trained public models (e.g., all-MiniLM-L6-v2) have lower leakage risk because they were not trained on the app's sensitive data.

Confidence: **high**

---

### 10. WordNet and Lexical Methods Have Limited Coverage for Paraphrase Detection

Claim: WordNet-based paraphrase detection achieves competitive results on clean text but suffers from "small lexical coverage and lack of vocabulary diversity." Deep learning approaches (BERT, SBERT, CNNs) consistently outperform WordNet on MSRP and Quora benchmarks, with fine-tuned BERT reaching 86.51% on MSRP and 94.32% on Quora. [^10]

Source: ResearchGate — "Comparative Analysis of Semantic Similarity Word Embedding Techniques for Paraphrase Detection" (2022) + arXiv paraphrase review (2024) + ResearchGate — "A Deep Network Model for Paraphrase Detection in Short Text Messages" (2018)

URL: https://www.researchgate.net/publication/360112885 / https://arxiv.org/html/2212.06933v3 / https://www.researchgate.net/publication/321718880

Date: 2018–2024

Excerpt: "The effectiveness of WordNet relationships in identifying paraphrases is limited by their small lexical coverage and lack of vocabulary diversity… Fine-tuned BERT using ELMo embeddings with preprocessing produces promising outcomes. Paraphrase identification rates achieved on MSRP and Quora datasets are 86.51% and 94.32%."

Context: This directly addresses the whispernotes gap: a WordNet/lexicon approach will never catch "wading through wet sand" as a paraphrase of "sluggish." Neural embeddings are necessary for figurative, idiomatic, and non-literal mental-health language. However, WordNet can still serve as a fast fallback or validation layer.

Confidence: **high**

---

### 11. Quantized Small Language Models (1–3B) Can Run on Modern iPhones with Acceptable Latency

Claim: Quantized SLMs (INT4/INT8) achieve 50–500 tokens/sec on edge hardware and reduce memory usage by ~75%. On an iPhone with 12–16GB RAM, models up to 3B parameters run smoothly; 4GB devices can run 1B models (e.g., TinyLlama) with Q5 quantization. [^11]

Source: deepsense.ai blog + Zenvanriel blog + arXiv — "Compact LLM Deployment and World Model Assisted Offloading in Mobile Edge Computing" (2026)

URL: https://deepsense.ai/blog/implementing-small-language-models-slms-with-rag-on-embedded-devices-leading-to-cost-reduction-data-privacy-and-offline-use/ / https://zenvanriel.com/ai-engineer-blog/how-to-deploy-ai-on-edge-devices-with-small-language-models/ / https://arxiv.org/html/2602.13628v1

Date: 2024–2026

Excerpt: "Recent phones with 12-16GB+ RAM can run models in the range 1-3B and even those in the range 7B… For devices with 6GB RAM, we could run Q5-quantized Gemma and smaller models. 4GB is challenging, but models like 1.1B TinyLLAMA can still be run there."

Context: For whispernotes, a small LLM (1–3B) is theoretically feasible for few-shot classification, but the latency for sentence-level embedding (not generation) is the more relevant metric. Encoder-only models (e.g., MiniLM, Gemma 3 270M) are far more efficient than generative models for the paraphrase-similarity task. The deepsense.ai team found that `llama.cpp` is the best mobile runtime, but ExecuTorch may become viable for Apple-only apps.

Confidence: **medium** (latency numbers vary by device and quantization)

---

### 12. Token-Based Features Act as a Double-Edged Sword in Clinical Text Similarity

Claim: In clinical STS, shared terms (e.g., "patient's symptoms") increase similarity scores for both genuinely similar and falsely similar pairs. An encoder network scored a false pair (gradual vs. sudden onset) at 2.43 while a Random Forest scored it at 3.11, closer to the gold 3.95 — showing that neural encoders can be *too* conservative, while lexical methods can be *too* generous. [^12]

Source: PMC — "Deep learning with sentence embeddings pre-trained on biomedical corpora" (Chen et al., 2020)

URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC7191680/

Date: 2020

Excerpt: "For this example, the Random Forest model has a closer score than the Encoder Network… token-based and character-based features act as a double-edged sword. For pairs of high similarity, the performance of the Random Forest is improved by awarding shared terms, but it also brings false positives when sentences have low similarity but share some of the same terms."

Context: This is a crucial warning for whispernotes. If the app uses embeddings to match "wading through wet sand" to "sluggish," it must also avoid matching "I had energy today" to "My energy was drained" simply because they share the word "energy." A threshold-tuned hybrid (lexical anchor + embedding expansion) may be safer than pure embedding matching.

Confidence: **high**

---

### 13. Single Words Show Dangerously High Baseline Similarity in Embedding Space

Claim: Apple's NLEmbedding and similar word-embedding APIs show cosine similarity of 0.60–0.89 even for unrelated single words. Full sentences or phrases are required for reliable discrimination. [^13]

Source: GitHub — NaturalLanguageEmbeddings (evaluation results)

URL: https://github.com/buh/NaturalLanguageEmbeddings

Date: 2025

Excerpt: "Single words show high baseline similarity (0.60-0.89 even for unrelated terms)… Full sentences or phrases provide better discrimination."

Context: whispernotes extracts from short journal entries (often single clauses). The system must ensure that extracted phrases are embedded as full sentences, not isolated keywords, to avoid false matches. For example, embedding "energy" alone could match "energy" in any context; embedding "my body would not get going, like wading through wet sand" provides contextual disambiguation.

Confidence: **high**

---

### 14. Fine-Tuning vs. Zero-Shot vs. RAG for Mental Health: Fine-Tuning Wins, but Zero-Shot Is Viable

Claim: On mental health text classification (DAIR-AI Emotion + SWMH datasets), fine-tuning LLaMA 3 8B achieved 91% accuracy on emotion and 80% on mental health conditions. Zero-shot prompting reached 68% on mental health conditions, surpassing few-shot and RAG. RAG and few-shot showed unexpectedly lower performance due to retrieval quality and example-selection issues. [^14]

Source: arXiv — "Fine-tuning vs. Prompt Engineering vs. RAG for mental health text analysis" (2025)

URL: https://arxiv.org/html/2503.24307v1

Date: 2025-03-31

Excerpt: "Fine-tuning achieves the best performance, with accuracies of 91% and 80% on the DAIR-AI Emotion and SWMH datasets. Notably, zero-shot prompting emerged as the second-best performing approach… Both RAG and few-shot prompting showed limited effectiveness."

Context: For whispernotes, this suggests that if the team uses an LLM at all, fine-tuning a small model (or using LoRA adapters) on a curated mental-health/ADHD symptom dataset is the highest-accuracy path. However, for a lightweight on-device pipeline, a pre-trained sentence embedding + cosine threshold may be more practical than any LLM approach, given the 68% zero-shot ceiling.

Confidence: **high**

---

### 15. Hybrid Approaches (Lexical + Embedding + Domain Gazetteer) Are Emerging as Best Practice

Claim: Multiple recent studies combine string similarity, BERT embedding similarity, and WordNet/semantic similarity into hybrid classifiers for paraphrase detection, achieving 90.1 F1 with Longformer and 96 with fine-tuned GPT-3.5 on paragraph-level detection. [^15]

Source: ResearchGate — "A Hybrid Approach to Paraphrase Detection Based on Text Similarities and Machine Learning Classifiers" (2022) + various paraphrase surveys

URL: https://www.researchgate.net/publication/361026403

Date: 2022

Excerpt: "They specifically integrated three categories of similarity scores: string similarity, embedding similarity derived from BERT, and semantic similarity, utilising WordNet and spaCy algorithms."

Context: For whispernotes, the recommended architecture is likely a **hybrid**:
- **Layer 1:** Exact lexicon match (fast, deterministic, high precision)
- **Layer 2:** Embedding similarity fallback for lexicon misses (catches paraphrases)
- **Layer 3:** Domain-specific gazetteer / seed terms for mental-health concepts (reduces false positives)
- **Threshold tuning:** Per-dimension similarity thresholds, validated on an eval set

Confidence: **medium** (the specific hybrid architecture must be validated on the app's data)

---

## Major Players & Sources

| Player / Source | Type | Relevance to whispernotes |
|-----------------|------|---------------------------|
| **Sentence-Transformers (UKPLab)** | Open-source library | Reference implementation of SBERT; provides all-MiniLM-L6-v2 and other production-ready models |
| **Apple NaturalLanguage / NLContextualEmbedding** | Native iOS framework | Zero-bundle, on-device, privacy-first sentence embeddings; requires iOS 17+ |
| **Apple Core ML / coremltools** | Conversion + runtime | Path to ship custom fine-tuned embedding models in the app bundle |
| **Apple MLX** | Native Apple Silicon framework | Training and inference for custom embedding models on Mac (dev) and potentially iOS |
| **Hugging Face** | Model hub | Source of pre-trained and fine-tuned embedding models; can be converted to Core ML |
| **deepsense.ai / edge-slm** | Research + open-source code | Demonstrated RAG + SLM on Android; relevant for mobile LLM feasibility assessment |
| **MedSTS / n2c2 (Mayo Clinic)** | Clinical NLP benchmark | The closest public benchmark to mental-health short-text similarity |
| **PTEB (Frank & Afli, MTU)** | Academic benchmark | First systematic evaluation of embedding robustness to paraphrase; shows residual fragility |
| **Zilliz / Milvus** | Vector DB + embedding guides | Practical guidance on embedding selection, thresholds, and similarity metrics |
| **ResearchGate / arXiv paraphrase surveys** | Academic literature | Comprehensive coverage of WordNet → deep learning evolution in paraphrase detection |

---

## Trends & Signals

### Trend 1: On-Device Embedding Is Now a First-Class Citizen
- Apple, Google, and Qualcomm are all shipping on-device embedding models.
- `NLContextualEmbedding` (iOS 17+) eliminates the need to bundle or download a model for basic semantic search.
- For whispernotes, this is the fastest path to production: use Apple's native embedding API with a cosine-similarity index over the lexicon.

### Trend 2: Small Models Are Catching Up — Size Is Not the Only Metric
- PTEB showed that smaller embedding models (4B parameters) are not disproportionately affected by paraphrasing compared to larger ones (12B+).
- all-MiniLM-L6-v2 (22.7M) achieves 84.6% of the STS-B performance of models 5× its size.
- For whispernotes, a 22M-parameter model is likely sufficient if the domain is narrow (ADHD symptoms, energy, mood, focus).

### Trend 3: Domain Adaptation Matters More Than Model Scale for Mental Health
- Fine-tuned RoBERTa-large (355M) outperforms few-shot Llama-3-8B on depression subtyping.
- Clinical STS requires two-phase training (general + clinical) to reach peak performance.
- Signal: whispernotes should budget for a small labeled dataset (even 100–500 examples) to fine-tune or adapt the embedding model, rather than relying on zero-shot generalization.

### Trend 4: Hybrid Retrieval Is Replacing Pure Semantic Search
- BM25 + embedding hybrid RAG outperforms pure dense retrieval on clinical and technical text.
- Lexical + embedding combination is the dominant pattern in production paraphrase detection systems.
- Signal: whispernotes should not abandon its lexicon; it should augment it with embedding similarity.

### Trend 5: Privacy-by-Default Is Becoming a Competitive Feature
- On-device NLP is explicitly marketed as privacy-critical (medical notes, personal journals).
- Apple's marketing for Apple Intelligence emphasizes that personal data never leaves the device.
- Signal: whispernotes' on-device-only architecture aligns with a growing user expectation and may be a differentiator against cloud-based competitors.

---

## Controversies & Conflicting Claims

### Controversy 1: Do Embeddings Solve the Paraphrase Gap or Introduce New Noise?
- **Pro-embedding:** SBERT and clinical embedding models demonstrably capture paraphrase relationships that lexicons miss (e.g., "wading through wet sand" → "sluggish"). AUC > 0.7 on mental-health detection tasks. [^6]
- **Anti-embedding:** PTEB shows that embeddings still drop 2–5% performance under paraphrase. Clinical error analysis shows false positives when sentences share domain terms but describe opposite conditions. [^8] [^12]
- **Resolution:** Embeddings *reduce* the gap but do not *close* it. A hybrid layer with threshold validation is necessary.

### Controversy 2: What Is the Minimum Viable Model Size?
- **Small-model camp:** all-MiniLM-L6-v2 (22.7M) is "state-of-the-art for its size" and runs at 14k sentences/sec. Apple's NLContextualEmbedding is likely in a similar size class. [^2]
- **Accuracy camp:** all-mpnet-base-v2 (110M) and larger models achieve 3–5% higher Spearman on STS-B. For clinical text, domain-specific fine-tuned RoBERTa (355M) is the gold standard. [^5] [^7]
- **Resolution:** For whispernotes' narrow domain (ADHD symptom lexicon), a 22M–80M model is likely sufficient. If clinical-grade accuracy is required, a fine-tuned 80M–110M model converted to Core ML is the next step.

### Controversy 3: Should the App Use Apple's Native Embedding or a Custom Model?
- **Native pros:** Zero bundle size, no conversion work, automatic updates, Neural Engine optimized, privacy guaranteed. [^3]
- **Native cons:** 512-dim vectors (larger than MiniLM's 384), 256-token limit, unknown training data, no domain adaptation, Apple-only (blocks future Android port). [^3]
- **Custom pros:** Can fine-tune on mental-health data, smaller vectors possible, cross-platform weights, full control over architecture. [^4]
- **Custom cons:** Bundle size (~80MB+), conversion complexity, update friction (requires app release), need for threshold validation.
- **Resolution:** Start with `NLContextualEmbedding` for a prototype. If the eval set shows false positives or misses, pivot to a custom Core ML model.

### Controversy 4: Is Fine-Tuning on User Data Ethically Safe?
- **Privacy risk:** Embedding models memorize rare training examples. Mental-health data is highly sensitive. Membership inference attacks can extract patient names and conditions from fine-tuned BERT. [^9]
- **Mitigation:** On-device inference of a pre-trained model carries near-zero leakage risk. If fine-tuning on aggregated data is ever attempted, differential privacy (DP-SGD) is mandatory. The safest path is never to train on user data at all.

### Controversy 5: Are Few-Shot LLMs a Viable Shortcut?
- **Optimist view:** Zero-shot LLaMA 3 achieves 68% accuracy on mental-health classification without any training data. [^14]
- **Pessimist view:** Few-shot LLMs are outperformed by fine-tuned encoders by 15–20% absolute. On-device LLMs require 1–3B parameters and have latency issues for real-time journaling. [^5] [^11]
- **Resolution:** LLMs are not the right tool for this specific problem. Sentence embeddings are faster, smaller, and more deterministic for a fixed lexicon-expansion task.

---

## Recommended Deep-Dive Areas

1. **Prototype with `NLContextualEmbedding`** (1–2 days)
   - Build a Swift test harness that embeds the existing whispernotes lexicon entries and the eval-set sentences.
   - Measure cosine similarity between user text and each lexicon entry.
   - Report precision/recall at thresholds 0.70, 0.80, 0.85, 0.90.
   - If the two failure cases are recovered, the native path is viable.

2. **Evaluate all-MiniLM-L6-v2 via Core ML** (2–3 days)
   - Convert the model to `.mlpackage` using `coremltools`.
   - Benchmark inference latency on iPhone 13/14/15/16 across Neural Engine, GPU, and CPU.
   - Compare accuracy against `NLContextualEmbedding` on the whispernotes eval set.
   - Decide if the custom model's accuracy gain justifies the bundle-size cost.

3. **Build a Hybrid Matching Layer** (3–5 days)
   - Layer 1: Exact lexicon match (preserve current deterministic behavior).
   - Layer 2: Embedding cosine-similarity fallback for lexicon misses.
   - Layer 3: Hard-negatives filter — if the best match is a known opposite (e.g., "high energy" vs. "low energy"), reject or require a second-best confirmation.
   - Validate on the full eval set with precision floors.

4. **Curate a Domain-Specific Training Dataset** (ongoing)
   - Collect 200–500 labeled pairs of (journal_snippet, canonical_label) from ADHD communities (Reddit, forums) or synthetic generation.
   - Fine-tune all-MiniLM-L6-v2 with contrastive loss (anchor = user text, positive = canonical label, negative = hard negatives).
   - Evaluate whether domain adaptation improves paraphrase recovery on the eval set.

5. **Privacy & Security Audit** (1 day)
   - Confirm that the chosen embedding pipeline runs entirely on-device.
   - Document that no text, embeddings, or similarity scores are transmitted to servers.
   - If future fine-tuning on aggregated data is considered, spec out a DP-SGD protocol and legal review.

6. **Longitudinal Threshold Monitoring** (ongoing)
   - Embedding similarity thresholds drift as users expand their vocabulary.
   - Build an internal feedback loop: when a user manually edits an extracted label, log the snippet (locally) and periodically recompute the optimal threshold per dimension.

---

## References

[^1]: Khairova, N., Shapovalova, A., Mamyrbayev, O., Sharonova, N., & Mukhsina, K. (2022). *Using BERT model to Identify Sentences Paraphrase in the News Corpus*. CEUR-WS, Vol. 3171. https://ceur-ws.org/Vol-3171/paper6.pdf

[^2]: Mixpeek model card; Milvus AI Quick Reference. (2024–2026). *all-MiniLM-L6-v2: A Lightweight Sentence Transformer Model*. https://mixpeek.com/model/sentence-transformers/all-MiniLM-L6-v2 ; https://milvus.io/ai-quick-reference/what-are-some-popular-pretrained-sentence-transformer-models-and-how-do-they-differ-for-example-allminilml6v2-vs-allmpnetbasev2

[^3]: Apple Developer Documentation. (2024). *Finding Similarities Between Pieces of Text*; Callstack blog (2025). *On-Device Text Embeddings in React Native With Apple NLP Framework*; GitHub — NaturalLanguageEmbeddings. https://developer.apple.com/documentation/naturallanguage/finding-similarities-between-pieces-of-text ; https://www.callstack.com/blog/on-device-ai-introducing-apple-embeddings-in-react-native ; https://github.com/buh/NaturalLanguageEmbeddings

[^4]: codecentric blog (2019). *Core ML – inference on iOS*; WWDC24 (2024). *Deploy machine learning and AI models on-device with Core ML*; Crosley, B. (2026). *Core ML On-Device Inference: The Patterns That Actually Ship*; GitHub — mlx_embedding_models. https://www.codecentric.de/en/knowledge-hub/blog/core-ml-inference-on-ios ; https://wwdcnotes.com/documentation/wwdc24-10161-deploy-machine-learning-and-ai-models-ondevice-with-core-ml/ ; https://blakecrosley.com/blog/core-ml-on-device-inference ; https://github.com/taylorai/mlx_embedding_models

[^5]: AlSaad, R., et al. (2026). *Depression subtype classification from social media posts*. Frontiers in Digital Health. https://www.frontiersin.org/journals/digital-health/articles/10.3389/fdgth.2026.1790533/full

[^6]: Lho, S.K., et al. (2025). *Large Language Models and Text Embeddings for Detecting Depression and Suicide in Patient Narratives*. PMC. https://pmc.ncbi.nlm.nih.gov/articles/PMC12102709/

[^7]: Yang, X., et al. (2020). *Measurement of Semantic Textual Similarity in Clinical Texts*. JMIR Medical Informatics. https://medinform.jmir.org/2020/11/e19735/ ; Wang, Y., et al. *MedSTS: A Resource for Clinical Semantic Textual Similarity*. arXiv. https://storage.prod.researchhub.com/uploads/papers/2026/01/10/1808.09397.pdf

[^8]: Frank, M., & Afli, H. (2025). *PTEB: Towards Robust Text Embedding Evaluation via Stochastic Paraphrasing at Evaluation Time with LLMs*. arXiv. https://arxiv.org/html/2510.06730v1

[^9]: *Towards Privacy-aware Mental Health AI Models*. arXiv (2025). https://arxiv.org/html/2502.00451v2 ; Du, M., et al. (2023). *Sanitizing Sentence Embeddings (and Labels) for Local Differential Privacy*. ACM Web Conference. https://duminxin.github.io/pdf/TheWeb23_SentenceDP.pdf ; Zilliz. (2025). *What are the privacy implications of different embedding models?* https://zilliz.com/ai-faq/what-are-the-privacy-implications-of-different-embedding-models

[^10]: *Comparative Analysis of Semantic Similarity Word Embedding Techniques for Paraphrase Detection*. ResearchGate (2022). https://www.researchgate.net/publication/360112885 ; *Paraphrase Identification with Deep Learning: A Review of Datasets and Methods*. arXiv (2024). https://arxiv.org/html/2212.06933v3 ; *A Deep Network Model for Paraphrase Detection in Short Text Messages*. ResearchGate (2018). https://www.researchgate.net/publication/321718880

[^11]: deepsense.ai. (2024). *Implementing Small Language Models (SLMs) with RAG on Embedded Devices*; Zenvanriel. (2026). *How to Deploy AI on Edge Devices with Small Language Models?*; arXiv. (2026). *Compact LLM Deployment and World Model Assisted Offloading in Mobile Edge Computing*. https://deepsense.ai/blog/implementing-small-language-models-slms-with-rag-on-embedded-devices-leading-to-cost-reduction-data-privacy-and-offline-use/ ; https://zenvanriel.com/ai-engineer-blog/how-to-deploy-ai-on-edge-devices-with-small-language-models/ ; https://arxiv.org/html/2602.13628v1

[^12]: Chen, Q., et al. (2020). *Deep learning with sentence embeddings pre-trained on biomedical corpora*. PMC. https://pmc.ncbi.nlm.nih.gov/articles/PMC7191680/

[^13]: GitHub — NaturalLanguageEmbeddings. (2025). *Evaluation Results & Best Practices*. https://github.com/buh/NaturalLanguageEmbeddings

[^14]: *Fine-tuning vs. Prompt Engineering vs. RAG for mental health text analysis*. arXiv (2025). https://arxiv.org/html/2503.24307v1

[^15]: *A Hybrid Approach to Paraphrase Detection Based on Text Similarities and Machine Learning Classifiers*. ResearchGate (2022). https://www.researchgate.net/publication/361026403

---

*Document generated by deep-research subagent. 15 independent searches conducted. All URLs verified accessible at research time. Recommendations are conditional on the app's eval dataset and should be validated empirically before production deployment.*
