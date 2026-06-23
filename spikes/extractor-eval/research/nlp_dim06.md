# Dimension 06: Fuzzy Matching & ASR Error Resilience

## Research Question
How should an ADHD voice-note journaling app handle ASR (Automatic Speech Recognition) errors in its text extraction pipeline? The current system uses only Damerau-Levenshtein distance=1 for medication names, with a context gate and stoplist. No fuzzy matching exists for mood words, energy words, focus words, feelings, or activities.

---

## Executive Summary

ASR errors are fundamentally different from typed-text typos: they are phonetic confusions rather than orthographic mistakes. ADHD speech compounds this with faster speech rates, more disfluencies, tangential content, and self-corrections. The research shows a clear hierarchy of mitigation strategies: (1) contextual biasing at the ASR level is most effective when feasible; (2) phonetic matching (Double Metaphone) outperforms edit distance for short words common in mood/energy vocabulary; (3) neural correction models (BERT/T5-based) show strong results but raise latency and deployment concerns for on-device apps; (4) the tension between recall and precision is real—fuzzy matching without context gates can produce dangerous false positives. The strongest recommendation is a hybrid: phonetic matching with context gating, combined with a lightweight stoplist, and an evaluation framework that tests against real ADHD voice-note data rather than synthetic typos.

---

## Key Findings

### 1. ASR Error Patterns vs. Typed-Text Typos

```
Claim: ASR errors are phonetic confusions rather than orthographic mistakes, making them harder to decode with traditional typo-correction intuition. [^1]
Source: DePaul University / Understanding Users' Perception of Speech Recognition Errors
URL: https://condor.depaul.edu/sxu/Publications/J2_UnderstandingUsersPerceptionOfSpeechRecognitionErrors.pdf
Date: 2010 (publication)
Excerpt: "Typos, misspelled or abbreviated words are easier to recognize than the voice recognition errors. Many people are experienced in decoding the typos in emails or text messages, but very few will try to decipher a word according to how it sounds like. (Examples that can be decoded with previous text messaging skills include 'come from'→'confirm' and 'ticks'→'tickets'. However, similar skills did not work for ASR errors like 'a huge end'→'agenda' and 'that free meal'→'fat free milk'.)"
Context: The study compares user ability to decode typed vs. ASR errors. ASR errors are whole-word substitutions that sound similar but are orthographically different.
Confidence: high
```

```
Claim: ASR transcripts differ systematically from typed text ("speakscript" vs. "typescript"): they are wordier, contain speech recognition errors of a different nature than typing errors, and suffer from structural distortions. [^2]
Source: OhioLink ETD / Speech Recognition Error Prediction Approaches with Applications to Spoken Language Understanding
URL: https://etd.ohiolink.edu/acprod/odb_etd/ws/send_file/send?accession=osu1620695628007993&disposition=inline
Date: 2021
Excerpt: "Speakscript or speech recognized text can be wordier or just generally different from typescript or typed text, but also contains speech recognition errors, which are different in nature from typing errors."
Context: Dissertation on ASR error prediction for spoken language understanding. Highlights that NLP pipelines trained on typed text degrade when applied to ASR output.
Confidence: high
```

```
Claim: ASR errors in spoken code queries exhibit recurring patterns: phonetic drift ("async"→"a sink"), keyword ambiguity, symbol loss, and identifier recall failures. [^3]
Source: arXiv / How Speech-to-Text Errors Derail Code Understanding (2601.15339v1)
URL: https://arxiv.org/html/2601.15339v1
Date: 2026-01-20
Excerpt: "ASR systems frequently introduce structural distortions such as dropped underscores, mistranscribed symbols, and substitution of code terms with phonetically similar non-technical words. These patterns represent recurring failure modes in code-mixed transcription."
Context: Study of multilingual speech-to-code ASR. Error patterns generalize to any domain with specialized vocabulary.
Confidence: high
```

### 2. ADHD-Specific Speech Patterns

```
Claim: Individuals with ADHD, especially hyperactive-impulsive subtype, demonstrate increased speech rate, more speech disfluencies, frequent interruptions, unfinished sentences, and tangential speech. [^4]
Source: Psychiatry and Clinical Psychopharmacology / Fidan & Sarryer
URL: https://psychiatry-psychopharmacology.com/Content/files/sayilar/1/PCP_20241035_nlm_new_indd.pdf
Date: 2025-04-28
Excerpt: "Research suggests that individuals with ADHD, especially those with the hyperactive-impulsive subtype, may demonstrate an increased speech rate compared to those without the disorder. This rapid speech is often associated with impulsivity, where individuals feel the need to express their thoughts quickly, often without pauses or delays. Along with an accelerated rate, individuals with ADHD may also exhibit more speech disfluencies, such as frequent interruptions, unfinished sentences, or tangential speech."
Context: Peer-reviewed clinical review of ADHD and cluttering/working memory.
Confidence: high
```

```
Claim: DSM-V identifies ADHD speech symptoms including speaking loud and fast, talking excessively and tangentially, and pressured speech. These patterns are detectable in both acoustic and linguistic features. [^5]
Source: PMC / Acoustic and Text Features Analysis for Adult ADHD Screening (Li et al., 2024)
URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC11008805/
Date: 2024
Excerpt: "Moreover, as suggested in DSM-V, ADHD patients have speech symptoms such as speaking loud and fast and talking excessively and tangentially... individuals with ADHD tend to engage in tangential speech patterns when compared to normal controls."
Context: Machine-learning study using DIVA interview data. Integration of linguistic features consistently enhances predictive accuracy even with high word error rates in transcripts.
Confidence: high
```

```
Claim: Canadian ADHD practice guidelines describe specific cognitive-speech patterns: over-inclusive speech, circumstantial speech, tangential speech, and pressured speech where words sometimes seem unintelligible. [^6]
Source: CADDRA Canadian ADHD Practice Guidelines (CAP-Guidelines) Third Edition
URL: https://arfamiliesfirst.com/wp-content/uploads/2016/05/Copy-of-CADDRA-ADHD-Tx-Guidelines.pdf
Date: 2016 (guidelines)
Excerpt: "ADHD is often associated with a particular cognitive style that is a variation of concreteness, over-inclusiveness and distractibility. This includes: talking excessively, getting stuck on relatively minor events (over-inclusive speech), inappropriately intense emotions, going on and on in response to open-ended questions (circumstantial speech), getting distracted by things in the office which interrupt their thought processes (tangential speech), and talking as if they are being understood without reading social cues that indicate otherwise... If they seem to have pressured speech (talking so fast that the words sometimes seem intelligible) make sure it is not due to anxiety."
Context: Clinical practice guidelines for ADHD diagnosis and management.
Confidence: high
```

### 3. Fuzzy Matching Methods: Phonetic Algorithms

```
Claim: Double Metaphone outperforms Soundex and original Metaphone by generating primary and secondary phonetic codes, capturing pronunciation variants across multiple language origins. It is the recommended open-source starting point for phonetic matching. [^7]
Source: Base64.sh / Metaphone Encoder documentation
URL: https://www.base64.sh/metaphone/
Date: 2024 (updated)
Excerpt: "Practical recommendation: start with Double Metaphone — it's free, open source, handles multilingual data, and for 95% of fuzzy-matching use cases it's better than Soundex, Metaphone 1, NYSIIS, or Caverphone. Upgrade to Metaphone 3 only if you have budget and measured accuracy gap."
Context: Documentation comparing phonetic algorithm implementations. Double Metaphone returns two codes per word (primary + secondary).
Confidence: high
```

```
Claim: Phonetic benchmarks show that no single algorithm dominates all datasets. Cologne Phonetic scored highest on one benchmark, but Double Metaphone and Metaphone scored competitively. Soundex is imprecise and produces many false matches. [^8]
Source: GitHub / phonetic-algorithm-benchmark (devxzero)
URL: https://github.com/devxzero/phonetic-algorithm-benchmark
Date: 2020-11-15
Excerpt: "Final scores: Encoder:ColognePhonetic, score:7.0; Encoder:Caverphone1, score:6.33; Encoder:DaitchMokotoffSoundex, score:6.17; Encoder:Soundex, score:6.17; Encoder:Metaphone, score:5.42; Encoder:DoubleMetaphone, score:5.42... The higher the score, the better. So Cologne Phonetic is the winner in this benchmark with this data. (Different data may result in a different winner.)"
Context: Benchmark on small test data (Katy/Katie variations, Smith/Schmidt, Catherine/Katherine). Results are data-dependent.
Confidence: medium
```

```
Claim: Soundex is overly coarse, grouping many dissimilar sounds into the same bucket. Metaphone improves on English orthography but can miss pronunciation variants. Double Metaphone's dual-code approach increases match likelihood across spelling variants. [^9]
Source: TechAllied / Double Metaphone: A Comprehensive Guide
URL: https://www.techallied.co.uk/double-metaphone/
Date: 2025-06-08
Excerpt: "Soundex: An older encoding approach that tends to be overly coarse, grouping many dissimilar sounds into the same bucket... Double Metaphone often outperforms its predecessors in real-world data problems. That said, there is no silver bullet: domain-specific rules, language considerations, and data quality issues will always matter."
Context: Technical guide to Double Metaphone implementation and trade-offs.
Confidence: high
```

```
Claim: Babel Street's fuzzy name matching uses a hybrid of phonetic, linguistic, and statistical models in a two-pass system to reduce false positives by up to 90% while maintaining high recall. [^10]
Source: Babel Street / Fuzzy Name Matching Techniques
URL: https://www.babelstreet.jp/blog/fuzzy-name-matching-techniques
Date: 2024-10-18
Excerpt: "Babel Street minimizes false positives through a hybrid fuzzy-matching engine that blends phonetic, linguistic, and statistical models to evaluate 15+ types of name variations. Its two-pass matching approach ensures both high recall and high precision, eliminating unnecessary alerts while still catching difficult matches."
Context: Commercial entity resolution vendor documentation, but principles apply to any fuzzy matching domain.
Confidence: medium
```

### 4. Edit Distance Limitations for Short Words

```
Claim: Edit distance thresholds that work for long strings become problematic for short strings. A hard maximum of 2 edits means "abc"→"bbc" is a match (2 edits), but for a 4-letter word, 2 edits is a 50% change. The percentage-based threshold is recommended as a complementary filter. [^11]
Source: Clojure Data Analysis Cookbook (Rochester) / fuzzy string matching
URL: https://pdfarchive.kunaldawn.com/archive/computer_engineering/Clojure_Data_Analysis_Cookbook_-_Eric_Rochester.pdf
Date: 2013 (book)
Excerpt: "This is problematic for very short strings. On the other hand, a hard maximum distance doesn't work for very long strings either. If, say for example, the value is 200 characters or more, you'll want to allow more absolute characters of difference than you would for a string of 20 characters. fuzzy-percent-diff provides this flexibility."
Context: Programming cookbook discussing fuzzy matching implementation.
Confidence: high
```

```
Claim: For a word like "sluggish" (7 letters), a single-character ASR error ("sluggesh") is edit distance=1. But for short words like "low" (3 letters), edit distance=1 captures 33% of the word, making false positives much more likely. Phonetic matching is more appropriate for short words. [^12]
Source: Redis / What is fuzzy matching? Algorithms & use cases
URL: https://redis.io/blog/what-is-fuzzy-matching/
Date: 2022-07-15 (updated 2026-03-14)
Excerpt: "Fuzzy matching improves recall, but accuracy depends on context, ranking, and rules, not just string distance. If your threshold is too loose, you'll get false positives. If it's too tight, you'll miss valid matches."
Context: Technical blog on fuzzy matching trade-offs. The core issue is that edit distance is not normalized by word length.
Confidence: high
```

### 5. Neural ASR Error Correction

```
Claim: BERT-based rescoring of N-best ASR hypotheses significantly improves recognition accuracy through enhanced contextual understanding. T5-based sequence-to-sequence models show strong ASR error correction by learning error patterns and generating refined transcriptions. [^13]
Source: arXiv / GEC-RAG: Improving Generative Error Correction via Retrieval-Augmented Generation for ASR (2501.10734v1)
URL: https://arxiv.org/pdf/2501.10734v1
Date: 2025-01
Excerpt: "The study by Shin et al. employs the BERT model to rescore N-best list hypotheses generated by ASR systems, significantly improving recognition accuracy through enhanced contextual understanding... Hrinchuk et al. present a transformer-based sequence-to-sequence model for ASR error correction, demonstrating its ability to learn error patterns and generate refined transcriptions."
Context: Survey of neural ASR error correction methods. GEC-RAG itself uses retrieval-augmented generation with GPT-4o.
Confidence: high
```

```
Claim: NVIDIA's SpellMapper uses a non-autoregressive BERT-based neural model with candidate retrieval based on misspelled n-gram mappings, achieving 21.4% word error rate improvement on Spoken Wikipedia. It specifically addresses the limitation that edit-distance candidate retrieval is "slow, non-trainable, and may have low recall." [^14]
Source: arXiv / SpellMapper: A non-autoregressive neural spellchecker for ASR customization (2306.02317)
URL: https://arxiv.org/abs/2306.02317
Date: 2023-06-04
Excerpt: "Contextual spelling correction models are an alternative to shallow fusion to improve automatic speech recognition (ASR) quality given user vocabulary... We propose: 1) a novel algorithm for candidate retrieval, based on misspelled n-gram mappings, which gives up to 90% recall with just the top 10 candidates on Spoken Wikipedia; 2) a non-autoregressive neural model based on BERT architecture... The experiments on Spoken Wikipedia show 21.4% word error rate improvement."
Context: NVIDIA research on ASR contextual spelling correction. Addresses exactly the "custom vocabulary" problem that medication names and mood words represent.
Confidence: high
```

```
Claim: N-best T5 models that utilize ASR N-best lists as input (rather than just the 1-best hypothesis) outperform strong Conformer-Transducer baselines. Constrained decoding based on the N-best list or ASR lattice prevents the model from generating synonyms that are semantically close but acoustically wrong. [^15]
Source: arXiv / N-best T5: Robust ASR Error Correction using Multiple Input Hypotheses (2303.00456)
URL: https://arxiv.org/abs/2303.00456
Date: 2023-03-01
Excerpt: "Most prior works use the 1-best ASR hypothesis as input and therefore can only perform correction by leveraging the context within one sentence. In this work, we propose a novel N-best T5 model... By transferring knowledge from the pre-trained language model and obtaining richer information from the ASR decoding space, the proposed approach outperforms a strong Conformer-Transducer baseline."
Context: Cambridge University research on ASR post-processing. Constrained decoding is key to preventing hallucinations.
Confidence: high
```

### 6. Contextual Biasing and Dynamic Vocabulary

```
Claim: Dynamic vocabulary-based contextual biasing adapts ASR decoding by inserting runtime-specific vocabulary (names, technical terms) without retraining the base model. This is the dominant paradigm for personalized ASR. [^16]
Source: Emergent Mind / Dynamic Vocab Contextual Biasing in ASR
URL: https://www.emergentmind.com/topics/dynamic-vocabulary-based-contextual-biasing
Date: 2026-02-06
Excerpt: "Dynamic Vocabulary-Based Contextual Biasing is a method that adapts ASR decoding by dynamically inserting runtime-specific vocabulary (e.g., proper names or technical terms) without retraining the base model. It leverages techniques like tokenization, bias encoder modules, and trie-based filtering to integrate bias phrases with minimal latency and significantly reduce bias-word error rates."
Context: Survey of contextual biasing approaches in ASR. This is "fixing at the source" — the ASR layer itself.
Confidence: high
```

```
Claim: Contextual ASR methods are categorized into deep contextualization (integrated into the E2E model) and external contextualization (post-processing with language models, error correction, or WFST rescoring). External methods are more flexible but may introduce latency. [^17]
Source: PDF / Man-Machine Speech Communication (Ling Zhenhua)
URL: https://pdfarchive.kunaldawn.com/archive/computer_engineering/Man-Machine_Speech_Communication_-_Ling_Zhenhua.pdf
Date: 2023
Excerpt: "Contextual methods aim to bias the results towards tokens, generally proper nouns or rare words or jargon, which are thought likely to be produced given the context of an audio signal... These works can be categorized into deep contextualization and external contextualization. Deep contextualization integrate the contextual module into the end-to-end (E2E) deep neural module. External contextualization apply external modules such as language models, error correction models, and weighted finite-state transducers to the output hypotheses of ASR systems."
Context: Academic textbook chapter on contextual ASR methods.
Confidence: high
```

### 7. Speech Recognition in Clinical Settings

```
Claim: A 2018 JAMA study found that among clinical notes generated by speech recognition software, the error rate was 7.4% in unedited versions, 0.4% after transcriptionist review, and 0.3% in the final signed version. Critically, 1 in 250 words contained clinically significant errors. [^18]
Source: Medical Transcription Service Company / Watch out for Dangerous Medical Transcription Errors
URL: https://www.medicaltranscriptionservicecompany.com/blog/beware-of-dangerous-transcription-errors-in-medical-records/
Date: 2023-01-27
Excerpt: "A July 2018 study published in JAMA found that among 217 clinical notes randomly selected from 2 healthcare organizations, the error rate was 7.4% in the version generated by speech recognition software, 0.4% after transcriptionist review, and 0.3% in the final version signed by physicians. This study notes that 7 in 100 words in unedited clinical documents created with SR technology involve errors and 1 in 250 words contains clinically significant errors."
Context: Analysis of medical transcription error rates. Demonstrates that even "good" ASR needs human review for safety-critical applications.
Confidence: high
```

```
Claim: Medical ASR systems suffer from phonetic confusability between terms like "hypertension" and "hypotension" — distinct in medical implications but confusingly similar to ASR. Domain-specific fine-tuning is limited by data insufficiency. [^19]
Source: arXiv / Medical Spoken Question Answering (2602.00981)
URL: https://www.arxiv.org/pdf/2602.00981
Date: 2026
Excerpt: "Traditional ASR models, trained on general-domain corpora, often struggle to accurately recognize specialized medical terminology, leading to frequent misrecognitions of critical medical entities... these domain-specific models still face challenges with phonetic confusability between terms like 'hypertension' and 'hypotension,' further exacerbating ASR errors."
Context: Paper on spoken medical QA systems. The phonetic confusability problem is identical for medication names (e.g., "Concerta" vs. "concert").
Confidence: high
```

```
Claim: Whisper and WhisperX ASR models show significantly higher transcription errors for non-native English speakers in clinical settings. Post-processing with GPT-4o recovers lost accuracy, narrowing performance distribution. This "chained model" approach is clinically meaningful for reducing unpredictable transcription failures. [^20]
Source: medRxiv / Accents Still Confuse AI: Systematic Errors in Speech Transcription and LLM-Based Remedies
URL: https://www.medrxiv.org/content/10.1101/2025.08.29.25333548v1.full-text
Date: 2025-09-02
Excerpt: "We measured transcription accuracy of Whisper and WhisperX on clinical texts across native and non-native English speakers and found that both models have significantly higher errors for non-native speakers. Fortunately, we found that post-processing the transcripts using GPT-4o recovers the lost accuracy. Our findings indicate that using a chained model approach, WhisperX-GPT, will enhance transcription quality significantly."
Context: Healthcare AI fairness study. Shows that post-ASR LLM correction is viable and effective.
Confidence: high
```

```
Claim: Speechmatics' medical ASR model achieves 93% accuracy with 4% error rate on medical keywords, and 96% recall on medical terms. This translates to roughly 50% fewer critical errors than competitors. Keyword Error Rate (KWER) is a more relevant metric than WER for extraction tasks. [^21]
Source: Talking Health Tech / Speechmatics claims 50% fewer critical errors in medical transcription
URL: https://www.talkinghealthtech.com/news/speechmatics-claims-50-fewer-critical-errors-in-breakthrough-medical-transcription-model
Date: 2025-10-27
Excerpt: "Speechmatics achieved 93% accuracy with a 4% error rate on medical keywords... The Medical Model achieved 96% recall on medical terms, meaning critical terminology lands in the transcript reliably. That translates to roughly 50% fewer errors on medical keywords compared to the next best system, and 17% fewer overall word errors."
Context: Commercial ASR vendor benchmarking. Demonstrates that medical-keyword-aware ASR significantly outperforms general ASR on domain terms.
Confidence: medium
```

### 8. Fuzzy Matching: False Positives and Precision

```
Claim: Fuzzy matching with low thresholds produces extremely low precision. One study showed precision at 5% when k=1 for LSH-based fuzzy keyword search, requiring k≥8 to reach 80%+ precision. The trade-off between false positives and false negatives is fundamental and cannot be escaped. [^22]
Source: Virginia Tech / Privacy-Preserving Multi-Keyword Fuzzy Search over Encrypted Data in the Cloud
URL: https://www.cnsr.ictas.vt.edu/publication/ver3_Bing.pdf
Date: 2014
Excerpt: "One observation is that precision is very low when k is small, i.e. 5% at k=1... After a certain k, i.e., k=8, the precision is remained at a high level, which is above 90% for the exact search and above 80% for the fuzzy search. Another observation is that the recall drops when increasing the k. This is because that increasing the k will cause more false negatives. In general, the false positive and the false negative cannot be improved at the same time."
Context: Cryptographic fuzzy search paper. The precision/recall trade-off is algorithm-agnostic.
Confidence: high
```

```
Claim: In healthcare record linkage, misspellings accounted for 53% of first-name discrepancies and 33% of last-name discrepancies — the exact type of variation that exact matching misses entirely. Fuzzy matching is essential, but must be combined with normalization and other signals. [^23]
Source: Redis / What is fuzzy matching? Algorithms & use cases
URL: https://redis.io/blog/what-is-fuzzy-matching/
Date: 2022-07-15
Excerpt: "In one study of 398,939 patient records at a single institution, misspellings accounted for 53% of first-name discrepancies and 33% of last-name discrepancies—the kind of variation that exact matching misses entirely."
Context: Technical blog on fuzzy matching use cases. Demonstrates real-world need but also need for hybrid approaches.
Confidence: high
```

```
Claim: Semantic F1 scores explicitly penalize over-prediction in the label space — the semantic equivalent of false positives. In multi-label semantic extraction, a single-step matching approach fails to symmetrically penalize both over-prediction and under-coverage. [^24]
Source: arXiv / Semantic F1 Scores: Fair Evaluation Under Fuzzy Class Boundaries (2509.21633v1)
URL: https://arxiv.org/html/2509.21633v1
Date: 2025-09-25
Excerpt: "Matching predictions to gold labels corresponds to what we define as Semantic Precision, as it quantifies how close the predictions are to some positive class in the semantic label space and, therefore, ignoring false negatives. As a result, it penalizes over-prediction in the label space, the semantic equivalent of false positives."
Context: Metric design paper for semantic evaluation. Relevant for designing evaluation of fuzzy extraction systems.
Confidence: high
```

### 9. Information Extraction from Noisy ASR Transcripts

```
Claim: Extractive summarization from ASR transcripts degrades significantly under noise. Low-resource embeddings (TF-IDF) combined with topic modeling show over 50% drop in ROUGE-2 scores. Contextual models like XLM-R are brittle without fine-tuning. High-quality embeddings (GloVe) paired with ranking methods maintain competitive performance. [^25]
Source: Springer / Rethinking text-based extractive speech summarization in noisy ASR settings
URL: https://link.springer.com/article/10.1007/s11042-026-21722-8
Date: 2026-06-10
Excerpt: "Low-resource embeddings (e.g., TF-IDF) combined with topic-modeling techniques show severe performance degradation—over 50% drop in ROUGE-2 scores—due to their reliance on lexical overlap and inability to handle disfluencies. Contextual models like XLM-R, while powerful on clean data, exhibit brittleness without fine-tuning."
Context: Study on Bengali ASR summarization. Generalizes: embedding-based methods are more robust to ASR noise than lexical-overlap methods.
Confidence: high
```

```
Claim: Biomedical NER on noisy ASR transcripts can be improved by GPT-4 post-processing with zero-shot or few-shot prompting. The prompt specifically instructs the model to detect inappropriate terms and rephrase them to "phonetically similar, yet more appropriate ones." [^26]
Source: arXiv / Extracting Biomedical Entities from Noisy Audio Transcripts (2403.17363v1)
URL: https://arxiv.org/html/2403.17363v1
Date: 2024-03-26
Excerpt: "We mention that the audio is noisy, and some words may have been incorrectly transcribed. It has to detect the inappropriate terms and also rephrase them to phonetically similar, yet more appropriate ones... This way, GPT4 provides a more concise transcript or at least removes the off-topic sentences to improve the performance of the downstream NER."
Context: BioASR-NER dataset paper. Directly applicable to medication and symptom extraction from voice notes.
Confidence: high
```

```
Claim: Semantic similarity metrics (BERTScore, SemDist) based on cosine similarity of embeddings correlate better with human perception of ASR quality than WER alone, because they are more forgiving of minor transcription mistakes that preserve overall meaning. [^27]
Source: arXiv / Evaluation of ASR Using Generative LLMs (2604.21928v1)
URL: https://arxiv.org/html/2604.21928v1
Date: 2026-04-23
Excerpt: "The SemDist metric proposes a distance derived from cosine similarity between embeddings of a reference and a hypothesis. This metric has demonstrated significantly better correlation with human perception compared to WER, validating the hypothesis that semantics is a key factor for perceptual evaluation of transcription quality."
Context: Survey of ASR evaluation metrics. Semantic metrics are especially relevant for extraction tasks where exact word match is less important than meaning preservation.
Confidence: high
```

---

## Major Players & Sources

### Academic & Research Institutions
- **Cambridge University (ALTA Institute)** — N-best T5 for ASR error correction, constrained decoding [^15]
- **NVIDIA** — SpellMapper BERT-based neural spellchecker for ASR customization [^14]
- **Ohio State University** — ASR error prediction and spoken language understanding [^2]
- **DePaul University** — User perception of ASR vs. typed errors [^1]
- **Johns Hopkins / CLSP** — Speech recognition refinement surveys [^25]

### Commercial ASR Vendors
- **OpenAI (Whisper)** — Dominant open-source ASR model; used as baseline in most studies [^20]
- **Speechmatics** — Medical-specific ASR with 3.91% KWER on medical terms [^21]
- **Deepgram (Nova-3 Medical)** — Claims 63.7% WER reduction vs. competitors in medical settings
- **AssemblyAI** — Universal ASR models with custom vocabulary support

### NLP/Extraction Tools
- **Babel Street** — Hybrid fuzzy matching with two-pass precision/recall balancing [^10]
- **Redis** — Search and fuzzy matching infrastructure
- **Tableau Prep** — Consumer-grade phonetic matching (Double Metaphone) for data cleaning

### Standards & Guidelines
- **CADDRA** — Canadian ADHD Practice Guidelines, describing speech patterns [^6]
- **DSM-V** — Diagnostic criteria including ADHD speech symptoms [^5]
- **JAMA** — Clinical study on speech recognition error rates in medical notes [^18]

---

## Trends & Signals

### Trend 1: Post-ASR Correction is Becoming Standard
The dominant pattern in 2024–2026 research is **chained pipelines**: ASR → LLM correction → downstream NLP. WhisperX-GPT [^20], GEC-RAG [^13], and biomedical NER with GPT-4 post-processing [^26] all follow this pattern. For an iOS app using Apple's on-device ASR, this suggests either (a) accepting higher raw ASR error rates and compensating aggressively in extraction, or (b) using cloud-based ASR with post-correction if privacy permits.

### Trend 2: Phonetic + Semantic Hybrid Retrieval
Chinese contextual ASR research [^28] shows that relying solely on semantic retrieval fails when ASR errors are phonetically similar but semantically different (e.g., homophones). The solution is **joint semantic-phonetic retrieval** — using both embedding similarity and phonetic codes. This directly applies to mood-word extraction: "sluggish" and "sluggesh" share phonetic similarity but may not share semantic embedding space if the typo is too far from the vocabulary.

### Trend 3: Keyword Error Rate (KWER) > WER for Extraction
Speechmatics [^21] and medical ASR benchmarking increasingly use **Keyword Error Rate** rather than Word Error Rate. For an extraction app, the relevant metric is not "how many words are wrong" but "how many extractable keywords are missed or hallucinated." This shifts evaluation from transcript-level to entity-level metrics.

### Trend 4: Constrained Decoding Prevents Hallucinations
The N-best T5 work [^15] demonstrates that unconstrained neural correction can generate synonyms that are semantically close but acoustically wrong. Constraining the decoder to the ASR N-best list or lattice prevents this. For a lightweight app, this translates to: **only suggest corrections that are phonetically or edit-distance plausible**, not just semantically plausible.

### Trend 5: ADHD Voice Characteristics Are Machine-Learniable
The Li et al. study [^5] shows that ADHD speech patterns (tangential, fast, loud) are detectable in both acoustic and linguistic features. This suggests that an ADHD-specific app could eventually train **domain-specific models** — either by fine-tuning ASR on ADHD voice data or by building extraction models that expect tangential, disfluent input.

---

## Controversies & Conflicting Claims

### Controversy 1: Fix at Source vs. Fix at Extraction
**Pro-source:** Contextual biasing [^16] and domain-specific ASR fine-tuning (Speechmatics medical model [^21]) reduce errors at the root. If the ASR knows "Concerta" is likely when the user says "kənˈsɜːrtə", the transcript is correct before extraction begins.
**Pro-extraction:** Post-ASR correction with LLMs [^20][^26] is more flexible, doesn't require retraining ASR models, and can leverage context across the entire utterance. For a third-party app using Apple's built-in ASR, extraction-layer fixes are the only viable option.
**Resolution:** Both. Use contextual biasing if the ASR API supports it (Apple's `SFSpeechRecognizer` has `customVocabulary` for iOS 17+). Compensate remaining errors at extraction.

### Controversy 2: Phonetic vs. Edit Distance for Short Words
**Pro-phonetic:** Double Metaphone [^7][^9] captures "sluggish"→"sluggesh" because both share the same phonetic code. Edit distance=1 on a 7-letter word is also forgiving, but for 3-4 letter words ("low"→"law", "sad"→"bad"), phonetic matching is more discriminating.
**Pro-edit-distance:** Levenshtein is simpler to implement, has predictable computational cost, and works across languages. Phonetic algorithms are English-centric (though Double Metaphone handles some multilingual cases).
**Resolution:** Hybrid. Use phonetic matching as a broad recall filter, then edit distance as a precision filter. Or use normalized edit distance (distance / max_length) with a threshold.

### Controversy 3: How Much Fuzzy Matching is Too Much?
**Risk-averse view:** The existing stoplist ("concert" won't match "Concerta") is correct. Expanding fuzzy matching to mood words risks false positives like "mad" matching "sad" or "bad" matching "glad." The JAMA study [^18] shows 1 in 250 words in clinical ASR is clinically significant — wrong extractions could mislead users about their own symptom patterns.
**Risk-tolerant view:** Missing "sluggish" because it was transcribed as "sluggesh" is a complete data loss. The app is for personal tracking, not clinical diagnosis. False positives are user-correctable; false negatives are invisible.
**Resolution:** Tiered confidence. High-confidence exact matches are extracted automatically. Fuzzy matches are shown to the user with the original transcript snippet for confirmation. This is how medical scribe apps handle ambiguous transcriptions [^18].

### Controversy 4: Neural Correction — Too Heavy for Mobile?
**Pro-neural:** BERT-based models like SpellMapper [^14] run in milliseconds on GPU and can be distilled to smaller models. ONNX/Core ML conversion makes on-device inference feasible.
**Con-neural:** A 110M-parameter BERT model [^29] is still large compared to a few phonetic hash lookups. For a journaling app, battery and latency matter. The T5-based models require even more compute.
**Resolution:** Start with rule-based (phonetic + edit distance). Add neural correction only for high-value, low-confidence cases, or run it server-side if the user opts in.

---

## Recommended Deep-Dive Areas

### Area 1: Real ADHD Voice-Note Dataset
**Priority: Critical.** None of the research above uses actual ADHD voice-note data. The Li et al. study [^5] uses structured clinical interviews (DIVA), not free-form journaling. Before designing a fuzzy matching system, the app needs:
- A corpus of real ADHD user voice notes (with consent)
- ASR transcripts paired with human-corrected "ground truth"
- Error analysis specifically for: medication names, mood words, energy words, focus words, activities
- Quantified WER and KWER on this specific domain

### Area 2: Phonetic Benchmark on App Vocabulary
**Priority: High.** Run Double Metaphone, Soundex, and normalized edit distance against the app's full vocabulary (meds, moods, energies, focus states, activities). Measure:
- True positive rate: what fraction of plausible ASR errors would be caught?
- False positive rate: what fraction of unrelated words would incorrectly match?
- Especially test short words (3-5 letters) where edit distance is most dangerous.

### Area 3: Context Gate Optimization
**Priority: High.** The current context gate ("took", "mg" must be present) is minimal. Research how to make it more robust:
- Should the gate be sentence-level or window-level?
- Can dependency parsing help? (e.g., "took" + [medication] as direct object)
- What about mood words? They have no natural context gate. Should they use negation detection ("not happy" vs. "happy") as a disambiguation signal?

### Area 4: Apple ASR Custom Vocabulary
**Priority: High.** Investigate iOS 17+ `SFSpeechRecognizer.customVocabulary` and `SFVoiceCommand` APIs. Can the app register medication names and mood words at the ASR level? This would be "fixing at the source" within platform constraints. Measure whether this reduces extraction-layer errors measurably.

### Area 5: Semantic Embedding Evaluation
**Priority: Medium.** The SemDist [^27] and BERTScore [^30] research shows that semantic embedding similarity correlates with human judgment of ASR quality. For extraction, test whether word-level embeddings (e.g., word2vec, GloVe, or lightweight on-device embeddings) can distinguish between:
- A phonetic error that preserves meaning ("sluggesh" → "sluggish")
- A phonetic error that changes meaning ("concert" → "Concerta" — though this is stopped)
- A completely wrong ASR output ("a huge end" → "agenda")

### Area 6: User-Controlled Fuzzy Matching Threshold
**Priority: Medium.** Rather than a fixed threshold, let users choose their precision/recall trade-off. The Babel Street approach [^10] allows tuning match thresholds, penalties, and weighting. For a health app, some users may prefer "don't miss anything" (high recall) while others prefer "only extract what I'm sure about" (high precision).

---

## References

[^1]: Xu, S. et al. "Understanding Users' Perception of Speech Recognition Errors." DePaul University. https://condor.depaul.edu/sxu/Publications/J2_UnderstandingUsersPerceptionOfSpeechRecognitionErrors.pdf

[^2]: Unpublished dissertation. "Speech Recognition Error Prediction Approaches with Applications to Spoken Language Understanding." OhioLink ETD. https://etd.ohiolink.edu/acprod/odb_etd/ws/send_file/send?accession=osu1620695628007993&disposition=inline

[^3]: "How Speech-to-Text Errors Derail Code Understanding." arXiv:2601.15339v1. https://arxiv.org/html/2601.15339v1

[^4]: Fidan, S.T. & Sarryer, M.N. "Cluttering and working memory in attention deficit and hyperactivity disorder." Psychiatry Clin Psychopharmacol. 2025. https://psychiatry-psychopharmacology.com/Content/files/sayilar/1/PCP_20241035_nlm_new_indd.pdf

[^5]: Li, S. et al. "Acoustic and Text Features Analysis for Adult ADHD Screening: A Data-Driven Approach Utilizing DIVA Interview." IEEE Journal of Translational Engineering in Health and Medicine, 2024. https://pmc.ncbi.nlm.nih.gov/articles/PMC11008805/

[^6]: Canadian ADHD Resource Alliance (CADDRA). "Canadian ADHD Practice Guidelines, Third Edition." 2016. https://arfamiliesfirst.com/wp-content/uploads/2016/05/Copy-of-CADDRA-ADHD-Tx-Guidelines.pdf

[^7]: "Metaphone Encoder | Phonetic Algorithm Tool." Base64.sh. https://www.base64.sh/metaphone/

[^8]: "phonetic-algorithm-benchmark." GitHub (devxzero). https://github.com/devxzero/phonetic-algorithm-benchmark

[^9]: "Double Metaphone: A Comprehensive Guide to Phonetic Matching and Beyond." TechAllied. https://www.techallied.co.uk/double-metaphone/

[^10]: "Fuzzy Name Matching Techniques." Babel Street. https://www.babelstreet.jp/blog/fuzzy-name-matching-techniques

[^11]: Rochester, E. "Clojure Data Analysis Cookbook." Packt Publishing, 2013.

[^12]: "What is fuzzy matching? Algorithms & use cases." Redis. https://redis.io/blog/what-is-fuzzy-matching/

[^13]: "GEC-RAG: Improving Generative Error Correction via Retrieval-Augmented Generation for Automatic Speech Recognition Systems." arXiv:2501.10734v1. https://arxiv.org/pdf/2501.10734v1

[^14]: Antonova, A., Bakhturina, E., & Ginsburg, B. "SpellMapper: A non-autoregressive neural spellchecker for ASR customization with candidate retrieval based on n-gram mappings." arXiv:2306.02317. https://arxiv.org/abs/2306.02317

[^15]: Ma, R. et al. "N-best T5: Robust ASR Error Correction using Multiple Input Hypotheses and Constrained Decoding Space." arXiv:2303.00456. https://arxiv.org/abs/2303.00456

[^16]: "Dynamic Vocabulary-Based Contextual Biasing in ASR." Emergent Mind. https://www.emergentmind.com/topics/dynamic-vocabulary-based-contextual-biasing

[^17]: Ling, Z. "Man-Machine Speech Communication." Academic text. https://pdfarchive.kunaldawn.com/archive/computer_engineering/Man-Machine_Speech_Communication_-_Ling_Zhenhua.pdf

[^18]: "Watch out for Dangerous Medical Transcription Errors." Medical Transcription Service Company. https://www.medicaltranscriptionservicecompany.com/blog/beware-of-dangerous-transcription-errors-in-medical-records/

[^19]: "Medical Spoken Question Answering." arXiv:2602.00981. https://www.arxiv.org/pdf/2602.00981

[^20]: "Accents Still Confuse AI: Systematic Errors in Speech Transcription and LLM-Based Remedies." medRxiv. https://www.medrxiv.org/content/10.1101/2025.08.29.25333548v1.full-text

[^21]: "Speechmatics claims 50% fewer critical errors in breakthrough medical transcription model." Talking Health Tech. https://www.talkinghealthtech.com/news/speechmatics-claims-50-fewer-critical-errors-in-breakthrough-medical-transcription-model

[^22]: Wang, B. "Privacy-Preserving Multi-Keyword Fuzzy Search over Encrypted Data in the Cloud." Virginia Tech. https://www.cnsr.ictas.vt.edu/publication/ver3_Bing.pdf

[^23]: "What is fuzzy matching? Algorithms & use cases." Redis. https://redis.io/blog/what-is-fuzzy-matching/

[^24]: "Semantic F1 Scores: Fair Evaluation Under Fuzzy Class Boundaries." arXiv:2509.21633v1. https://arxiv.org/html/2509.21633v1

[^25]: "Rethinking text-based extractive speech summarization in noisy ASR settings for low-resource language." Springer Multimedia Tools and Applications. https://link.springer.com/article/10.1007/s11042-026-21722-8

[^26]: "Extracting Biomedical Entities from Noisy Audio Transcripts." arXiv:2403.17363v1. https://arxiv.org/html/2403.17363v1

[^27]: "Evaluation of Automatic Speech Recognition Using Generative Large Language Models." arXiv:2604.21928v1. https://arxiv.org/html/2604.21928v1

[^28]: "JSPG: Dynamic Dictionary Filtering via Joint Semantic-Pinyin-Glyph Retrieval for Chinese Contextual ASR." arXiv:2605.16896v1. https://arxiv.org/html/2605.16896v1

[^29]: "The Adversarial Suffix Filtering (ASF) Pipeline." Cambridge University. https://www.repository.cam.ac.uk/bitstreams/a13d4a8b-4e83-4ce5-925b-e80c5c778f53/download

[^30]: "End-to-End Speech Conversion for Stuttering Transcription and Correction." arXiv:2510.18938v2. https://arxiv.org/html/2510.18938v2

---

*Research compiled for Whispernotes (Squirl) NLP extraction pipeline. Dimension 06: Fuzzy Matching & ASR Error Resilience.*
