# Cost-Efficient Strategies for LLM-Based Evaluation of NLP Extraction

> Deep research for an ADHD journaling app evaluating ~500 posts/run × 4 signals (mood, energy, focus, meds) via Claude API. Target budget: $5–20 per run.

---

## 1. Key Findings

### 1.1 Sampling: You Do Not Need to Judge All 500 Posts

Claim: A minimal sampling rate of **1%** can preserve model rankings on benchmarks like MMLU, while **quality-based sampling at 10%** achieves Pearson correlations of 0.85–0.95 with full-dataset scores.[^1]
Source: SubLIME (Xu et al., HP Labs)  
URL: https://arxiv.org/html/2406.15527v1  
Date: 21 Jun 2024  
Excerpt: "Notably, a minimal sampling rate of 1% proves effective for benchmarks like MMLU. Additionally, we demonstrate that employing difficulty-based sampling to target more challenging benchmark segments enhances model differentiation."  
Context: Evaluated across six NLP benchmarks and extended to 25 text-to-image models on 17 benchmarks.  
Confidence: high

Claim: **Stratified sampling** reduces metric deviation by up to 30% versus random sampling, or equivalently achieves the same precision on ~30% smaller datasets.[^2]
Source: Pylkkinen et al., Amazon (Interspeech 2016)  
URL: https://www.isca-archive.org/interspeech_2016/pylkkonen16_interspeech.pdf  
Date: 2016  
Excerpt: "We show that by altering the sampling, the deviations observed in the error metrics can be reduced by up to 30% compared to random sampling, or alternatively, the same precision can be obtained on about 30% smaller datasets."  
Context: Speech recognition evaluation, but stratification principles generalize to text classification/extraction.  
Confidence: high

Claim: For **imbalanced binary extraction** (e.g., rare positive signals), the optimal sampling strategy is to oversample the minority class; precision and sensitivity estimates improve with more positive examples, while specificity improves with more negatives.[^3]
Source: Valizadegan et al., PMC  
URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC4063531/  
Date: 2012  
Excerpt: "When the data is unbalanced, it is better to sample more from the minority class... there is a tradeoff between accurate estimate of precision and sensitivity on one side and specificity on the other side."  
Context: Medical diagnostic model evaluation, directly applicable to rare-signal extraction (e.g., "meds taken" may be a minority class).  
Confidence: high

Claim: For NLP evaluation, a **power analysis** with Cohen's d = 0.5 (medium effect) and power = 0.8 yields minimum sample sizes that are often far below full-corpus evaluation; within-subject designs further increase power.[^4]
Source: Schuff (Cambridge Natural Language Engineering)  
URL: https://www.cambridge.org/core/journals/natural-language-engineering/article/how-to-do-human-evaluation-a-brief-introduction-to-user-studies-in-nlp/85A5D9550233DFC3CF356DD7041E3306  
Date: 2023  
Excerpt: "A power level of 0.80 or higher is generally recommended... the smaller the effect size is, the more participants will be required to achieve the same statistical power."  
Context: Human evaluation tutorial, but the statistical power framework applies directly to LLM-judge sample sizing.  
Confidence: high

---

### 1.2 Tiered Judging: Cheap Filters + Expensive Escalation Works

Claim: A **hybrid tiered architecture** routing 97.5% of safe/straightforward cases through lightweight filters and only 2.5% to expensive LLMs can cut inference costs to **1.5% of a full-LLM deployment** while improving F1 by 66.5 points.[^5]
Source: Latitude (Rule-Based Filters vs LLMs)  
URL: https://latitude.so/blog/rule-based-filters-vs-llms-moderation-comparison  
Date: 2 May 2026  
Excerpt: "By routing 97.5% of safe content through lightweight filters and using LLMs only for the riskiest 2.5% of cases, costs can be reduced to about 1.5% of a full LLM deployment while improving the F1 score by 66.5 points."  
Context: Content moderation, but the cascade principle is transferable to extraction validation.  
Confidence: high

Claim: Using a **mini-class model with criteria injection and ensembling (k=8)** reaches 85.8% accuracy (+13.5pp over baseline) at roughly **one-quarter the cost** of a full-class model ensemble, and **k=3 captures ~70% of the ensembling gain**.[^6]
Source: Composo AI (arXiv 2604.13717)  
URL: https://arxiv.org/html/2604.13717v3  
Date: 9 Jun 2026  
Excerpt: "The mini-class peak (85.8%) exceeds full-class ensembling at roughly one-quarter the cost... k=3 captures ~70% of the gain. Criteria injection (near-free) and ensembling (with k=3 capturing ~70% of the gain) are the simplest and most cost-effective."  
Context: RewardBench-2 evaluation; tested across OpenAI GPT and Anthropic Claude families.  
Confidence: high

Claim: **Per-response score variance** is a weak but measurable uncertainty signal (AUC ≈ 0.60 for predicting incorrectness), and mini-model variance tracks full-model variance only moderately (r = 0.421); therefore, naive variance-based escalation is **not reliably cost-effective**.[^6]
Source: Composo AI (Appendix D)  
URL: https://arxiv.org/html/2604.13717v3  
Date: 9 Jun 2026  
Excerpt: "Variance correlates weakly but systematically with correctness (r = −0.13; AUC = 0.60 as an incorrectness classifier), and mini-model variance tracks full-model variance (r = 0.421). We ultimately do not recommend any of the three variants."  
Context: The attempted adaptive escalation strategies were dominated by simple criteria + ensembling.  
Confidence: high

Claim: **Claude 3 Haiku is ~12× cheaper than Claude 3.5 Sonnet** and achieves competitive accuracy on classification and extraction tasks; Sonnet should be reserved for multi-step reasoning or ambiguous boundary cases.[^7]
Source: DocsBot / Anthropic pricing comparisons  
URL: https://docsbot.ai/models/compare/claude-3-5-sonnet-20241022/claude-3-haiku  
Date: 2025  
Excerpt: "Claude 3 Haiku is roughly 12.0x cheaper compared to Claude 3.5 Sonnet for input and output tokens."  
Context: Real-world API pricing as of 2025; newer Haiku 4.5 is ~3.75× cheaper than Sonnet 4.5, still a substantial gap.  
Confidence: high

---

### 1.3 Judge Count: Marginal Value Collapses After ~3–5 Judges

Claim: In LLM judge panels, the **effective sample size (n_eff) asymptotes at ~2.0–2.5** regardless of panel size; a 5-judge panel already captures **90% of achievable independence**, and adding judges 6–9 provides only +0.22 effective votes.[^8]
Source: "Correlated Errors Undermine LLM Evaluation Panels" (arXiv 2605.29800)  
URL: https://arxiv.org/html/2605.29800v1  
Date: 28 May 2026  
Excerpt: "The first 5 judges contribute 90% of the achievable independence (n_eff = 1.96 vs. 2.18). Adding judges 6–9 provides only +0.22 effective votes... paying for 9 opinions but receiving the informational equivalent of ~2 is a substantial inefficiency."  
Context: Tested across 350+ LLMs on ChaosNLI and RewardBench; structural correlation, not an artifact.  
Confidence: high

Claim: A **single LLM judge** can achieve strong Pearson correlation with human evaluators (r = 0.88), but correlation alone masks systematic bias; **3 human annotators** is the standard for reliable agreement, and LLM-human agreement with 3 annotators reaches Cohen's κ ≈ 0.80.[^9]
Source: "Judge's Verdict" (arXiv 2510.09738)  
URL: https://arxiv.org/html/2510.09738v1  
Date: 10 Oct 2025  
Excerpt: "High correlation (r ≥ 0.80) indicates the LLM understands the general pattern... We employ Cohen's Kappa... comparing against a baseline of κ = 0.801 from human-to-human agreement."  
Context: 54 LLM judges evaluated against 1,994 samples with 3 human annotators each.  
Confidence: high

Claim: **Unanimous panel agreement is far less diagnostic than it appears**: a 9-judge unanimous panel still has a 9.1% error rate, versus ~0.02% expected under independence.[^8]
Source: "Correlated Errors Undermine LLM Evaluation Panels"  
URL: https://arxiv.org/html/2605.29800v1  
Date: 28 May 2026  
Excerpt: "Unanimous panel agreement carries far less weight than it appears — our data show a 9.1% error rate on unanimous items, vs. ~0.02% under independence."  
Context: Because LLM judges share correlated errors, majority voting does not compound reliability the way independent human votes would.  
Confidence: high

---

### 1.4 Batching: Multiple Posts and Signals Per Prompt Saves 2–4× Tokens

Claim: **Batched prompting** aggregating multiple examples into a single prompt reduces token usage by **2–4×** (depending on batch size) versus single-example prompting, and GPT-4o retains over **90% of baseline metric quality at batch size 4** when compression is applied.[^10]
Source: BatchGEMBA-MQM (arXiv 2503.02756)  
URL: https://arxiv.org/html/2503.02756v1  
Date: 4 Mar 2025  
Excerpt: "Our approach aggregates multiple translation examples into a single prompt, reducing token usage by 2–4 times... GPT-4o retains over 90% of its baseline performance at a batch size of 4 when compression is applied."  
Context: Machine translation evaluation, but the batching mechanics apply to any rubric-based scoring.  
Confidence: high

Claim: In production, **up to 20 articles can be batched per API call** for multi-signal scoring with structured output, achieving high throughput without sacrificing parse success (97.9% success reported).[^11]
Source: FinRL-MultiSignal (arXiv 2605.06730)  
URL: https://arxiv.org/html/2605.06730v1  
Date: 2024  
Excerpt: "Up to 20 articles are batched per API call to amortise latency... output one line per item. Never add explanation --- only scores."  
Context: Financial news scoring with 4 integer signals per article; directly analogous to the 4-signal extraction task.  
Confidence: high

Claim: **Batch prompting** for multi-problem evaluation retains downstream performance with small batch sizes (<6), but quality can degrade for larger batches unless output formatting is carefully structured (e.g., JSON-per-example).[^12]
Source: "Evaluating LLMs with Multiple Problems at once" (arXiv 2406.10786)  
URL: https://arxiv.org/html/2406.10786v3  
Date: 2023  
Excerpt: "Few-shot MPP greatly increases LLM inference efficiency while retaining downstream performance with a small batch size (e.g., <6)."  
Context: Multiple homogeneous classification problems; the advice to keep batches small and structured is directly applicable.  
Confidence: high

---

### 1.5 Caching and Deduplication: Reuse Judgments When Text Repeats

Claim: **Multi-layer caching** (exact-match → semantic → prompt-level) can reduce redundant LLM calls dramatically; exact-match caching handles repeated identical requests at near-zero latency, while semantic caching catches paraphrases with 5–20 ms overhead.[^13]
Source: Michael Brenndoerfer (caching blog)  
URL: https://mbrenndoerfer.com/writing/caching-prompt-semantic-invalidation-hit-rates-llm  
Date: 11 Feb 2026  
Excerpt: "The combination means that the most common requests (exact repeats) are handled instantly, semantically equivalent requests are handled quickly, and all requests benefit from reduced time-to-first-token through prompt caching."  
Context: Production LLM architecture advice; for repeated evaluation runs, judgments on identical posts should be cached.  
Confidence: high

Claim: **Query normalization and deduplication** prevent silent cache bloat; normalizing whitespace and lowercasing before hashing ensures identical queries map to a single entry.[^14]
Source: PyImageSearch (Semantic Caching for LLMs)  
URL: https://pyimagesearch.com/2026/05/04/semantic-caching-for-llms-ttls-confidence-and-cache-safety/  
Date: 4 May 2026  
Excerpt: "From a naïve cache’s perspective, they are completely different strings... Using a hash instead of raw strings provides fixed-length comparisons, efficient storage, and no dependency on query length."  
Context: If the same journaling post appears in multiple evaluation runs, hashing the normalized text avoids re-judging.  
Confidence: high

Claim: **Re-judging functionality** decouples expensive response generation from evaluation, allowing researchers to iterate on evaluation criteria without re-running the underlying system.[^15]
Source: Unnamed evaluation framework (arXiv 2511.10523)  
URL: https://arxiv.org/pdf/2511.10523  
Date: 2025  
Excerpt: "The framework preserves these responses in structured logs that can be re-evaluated with different judging criteria, models, or prompts without re-running the memory system."  
Context: For iterative extractor development, log the post + extractor output once, then re-judge with new rubrics for free.  
Confidence: medium

---

### 1.6 Distillation: Train a Small Model to Mimic the Expensive Judge

Claim: A **distilled specialist judge** can achieve over **95% agreement** with its teacher on a specific task while being orders of magnitude cheaper and faster to run.[^16]
Source: Oboe (Enterprise Agent Evaluation Frameworks)  
URL: https://oboe.com/learn/architecting-enterprise-agent-evaluation-frameworks-66v856/latency-and-cost-analysis-1wlq6kr  
Date: 11 Mar 2026  
Excerpt: "A successfully distilled judge model can achieve over 95% agreement with its teacher on a specific task, while being orders of magnitude cheaper and faster to run."  
Context: General industry best-practice; requires an initial investment in labeled data (2,000–5,000 examples) and fine-tuning.  
Confidence: medium

Claim: **JudgeLM** and related approaches fine-tune smaller models using supervision signals from stronger models (e.g., GPT-4o), enabling them to evaluate open-ended generation with high agreement to both teacher and human judgments.[^17]
Source: Survey on LLM Evaluation (arXiv 2602.07773)  
URL: https://www.arxiv.org/pdf/2602.07773  
Date: 2025  
Excerpt: "Zhu et al. (2025) introduce JudgeLM, which fine-tunes smaller language models using supervision signals from stronger models such as GPT4o, allowing them to evaluate open-ended generation with high agreement to both teacher and human judgments."  
Context: Academic distillation specifically for evaluation tasks; viable for a domain like ADHD journaling if 2,000+ examples are collected.  
Confidence: medium

Claim: For teams processing **fewer than 10,000 evaluations monthly**, general-purpose LLM judges typically have better ROI; distilled SLMs pay back within 3–6 months for high-volume or specialized domains.[^18]
Source: Galileo AI  
URL: https://galileo.ai/blog/llm-as-a-judge-vs-human-evaluation  
Date: 25 Feb 2026  
Excerpt: "Teams processing fewer than 10,000 evaluations monthly typically see better ROI from general-purpose LLM judges. But high-volume teams... often find that the initial investment... pays back within 3-6 months."  
Context: The user's 500 posts × 4 signals = 2,000 judgments/run; if running weekly, that's ~8,000/month—close to the threshold.  
Confidence: high

---

### 1.7 Active Learning: Only Judge Uncertain Cases — With Caveats

Claim: Active learning strategies can achieve **comparable performance to full-data training using only 20% of the labeled data** for information extraction tasks, but learning curves are often non-monotonic and can decline after mid-rounds.[^19]
Source: "An Empirical Study on Chemical Reaction Extraction" (arXiv 2604.19335)  
URL: https://arxiv.org/html/2604.19335v1  
Date: 21 Apr 2026  
Excerpt: "The Core-set method reaches near-baseline performance using only 70% of the full labeled dataset... entropy sampling showing a performance difference of less than 1.5% from the baseline as early as round 6."  
Context: Deep active learning for NLP extraction; uncertainty + diversity hybrid strategies work best.  
Confidence: medium

Claim: **Confidence-based selective automation** can automatically process 55–90% of cases at high accuracy while routing only low-confidence cases for expert review, reducing expert effort by 50–60%.[^20]
Source: RadAnnotate (arXiv 2603.16002)  
URL: https://arxiv.org/html/2603.16002v1  
Date: 16 Mar 2026  
Excerpt: "By learning entity-specific confidence thresholds, RadAnnotate can automatically annotate 55–90% of reports at 0.86–0.92 entity match score while routing low-confidence cases for expert review."  
Context: Radiology entity extraction; directly analogous to extractor confidence gating for journaling signals.  
Confidence: medium

Claim: Active learning adoption in NLP is **motivated primarily by cost reduction (87%)**, but practitioners report **sampling bias (15%)** and performance mismatch as key risks.[^21]
Source: "Reassessing Active Learning Adoption in Contemporary NLP" (arXiv 2503.09701)  
URL: https://arxiv.org/html/2503.09701v3  
Date: 2025  
Excerpt: "The primary motivation was obtaining annotated data at minimal cost (87%)... respondents noted sampling bias (15%) and dataset-model dependency (15%)."  
Context: Community survey of 138 NLP practitioners; confirms that AL is effective but requires careful validation.  
Confidence: high

---

## 2. Cost-Saving Strategies (Ranked by Impact)

| Rank | Strategy | Expected Savings | Risk/Notes |
|------|----------|------------------|------------|
| 1 | **Stratified sampling** (judge 100–150 posts, not 500) | **60–80%** cost reduction | Requires stratifying by signal presence, text length, or error history; use power analysis to pick N |
| 2 | **Model tiering** (Haiku for clear cases, Sonnet for uncertain) | **70–90%** cost reduction | Haiku is ~12× cheaper; only escalate posts with ambiguous signals or low extractor confidence |
| 3 | **Batching** (4–8 posts per prompt, 4 signals per post) | **50–75%** token reduction | Keep batch sizes small (<6) to preserve quality; use structured JSON output per example |
| 4 | **Judge count optimization** (use 1 judge, or 3 with criteria injection) | **60–95%** vs 20-judge panels | Research shows n_eff ≈ 2–2.5 even with 9 judges; a single good judge with criteria injection is often sufficient |
| 5 | **Caching / deduplication** (hash normalized post text) | **10–40%** across repeated runs | Exact-match cache near-zero cost; semantic cache for near-duplicate posts |
| 6 | **Active learning** (only judge uncertain cases) | **50–70%** of cases can be skipped | Biases evaluation toward hard cases; must weight back to population estimates |
| 7 | **Distillation** (fine-tune 7B–13B model on Sonnet verdicts) | **>95%** inference cost reduction | High upfront cost (2,000–5,000 labeled examples + training); pays off at >10K evals/month |

---

## 3. Recommended Evaluation Budget

### 3.1 Baseline Cost Calculation (500 posts × 4 signals = 2,000 judgments)

Assuming ~500 input tokens and ~30 output tokens per judgment (structured JSON verdict):

| Model | Input $/1M | Output $/1M | Cost per 2,000 judgments | Cost per run |
|-------|-----------|-------------|--------------------------|--------------|
| Claude 3.5 Sonnet (full) | $3.00 | $15.00 | ~$3.90 | **$3.90** |
| Claude 3 Haiku (cheap) | $0.25 | $1.25 | ~$0.33 | **$0.33** |
| **Hybrid: 80% Haiku + 20% Sonnet** | blended | blended | ~$1.05 | **$1.05** |
| **Hybrid + 30% sample (batched)** | blended | blended | ~$0.22 | **$0.22** |

> Note: The overnight run with 20 judges on Sonnet would cost ~$78/run. The below recommendations target $5–20/run.

### 3.2 Recommended Configurations by Budget Tier

**Tier A: "$5 Friday" (frugal, ~$3–6/run)**
- Sample **150 posts** (stratified by signal presence + text length).
- Use **Claude 3 Haiku** for all judgments.
- **Batch 4 posts per prompt**, scoring all 4 signals per post in one JSON object.
- Use **1 judge** with explicit criteria injection in the prompt.
- Implement **exact-match caching** on normalized post text.
- *Estimated cost: ~$1.50–3.00 per run.*

**Tier B: "$12 Standard" (balanced, ~$8–15/run)**
- Sample **250 posts** (stratified, ensuring rare signals are represented).
- Use **Haiku for 80%** of cases (clear lexicon matches, high extractor confidence); **escalate 20% to Sonnet** (ambiguous, short posts, no lexicon match).
- **Batch 4 posts per prompt** for Haiku; **single-post prompts** for Sonnet edge cases.
- Use **3 judges with criteria injection** on the Sonnet subset only; **1 judge on Haiku**.
- Cache all judgments.
- *Estimated cost: ~$8–12 per run.*

**Tier C: "$20 Thorough" (max quality, ~$15–20/run)**
- Judge **all 500 posts** but tier aggressively: **Haiku 70%, Sonnet 30%**.
- For the Sonnet tier, use **3-judge ensembling** with criteria injection; for Haiku, use **1 judge**.
- **Batch 4 posts per prompt** for Haiku; **batch 2 posts per prompt** for Sonnet.
- Cache judgments; maintain a **rolling "hard case" log** for future distillation.
- *Estimated cost: ~$15–18 per run.*

---

## 4. Controversies & Trade-offs

### 4.1 Sampling Bias vs. Cost
- **Oversampling rare signals** (e.g., meds, low-energy mentions) improves precision/recall estimates for minority classes but can overestimate overall error rates if not weighted back.
- **Undersampling easy cases** (e.g., long posts with explicit "I feel great") saves money but may miss subtle extractor regressions on "obvious" examples.

### 4.2 Tiered Judging: When Does Escalation Fail?
- Research shows per-response variance is a **weak routing signal** (AUC ≈ 0.60).[^6] If you route based on extractor confidence alone, you may miss cases where the extractor is confidently wrong.
- **Mitigation:** Combine multiple routing signals: extractor confidence + lexicon match absence + text length + sentiment polarity ambiguity.

### 4.3 Judge Count: The Paradox of Correlated Errors
- Adding more judges does **not** proportionally increase reliability because LLMs share systematic biases (position bias, verbosity bias, self-enhancement).[^8]
- A 20-judge panel is almost certainly **massive overkill**; the information equivalent is ~2.5 independent judges.
- **Mitigation:** Invest in **prompt criteria injection** (virtually free) rather than more judges.

### 4.4 Active Learning: Evaluating Only Hard Cases Skews Metrics
- If you only judge posts where the extractor is uncertain, you will **overestimate error rates** because the judged subset is not representative of the full distribution.
- **Mitigation:** Use active learning to select the *marginal* cases, but always retain a **random holdout sample** (~20%) to estimate population-level precision/recall. Weight stratum results by their population prevalence.

### 4.5 Distillation: High Fixed Cost, Uncertain Generalization
- A distilled 7B judge may achieve 95% agreement with Sonnet on the training distribution, but **extractor迭代ation changes the error distribution**, so the distilled model may need periodic retraining.
- **Mitigation:** Only pursue distillation once the extractor architecture and rubric have stabilized; use the distilled model as a fast filter, not the final arbiter.

### 4.6 Batching: Quality at Scale
- Batching multiple posts per prompt can introduce **inter-example interference**; some models (e.g., Mistral Small) suffer steep correlation drops, while GPT-4o/Claude are more robust.[^10]
- **Mitigation:** Start with batch size 2–4, measure agreement against single-post baselines on a 50-example validation set, and increase batch size only if correlation is preserved.

---

## 5. Actionable Next Steps

1. **Implement exact-match caching** immediately (free; prevents re-judging identical posts across runs).
2. **Reduce from 20 judges to 1–3 judges** with criteria injection (saves ~90% of judge cost with minimal accuracy loss).
3. **Switch to Claude 3 Haiku** for the majority of cases; reserve Sonnet for a ~20% escalation queue defined by ambiguity rules.
4. **Introduce stratified sampling** (target 150–250 posts/run) weighted by signal rarity and post length.
5. **Batch 4 posts per prompt** with structured JSON output, validating against single-post correlation on a holdout set.
6. **Log all (post, extractor_output, judge_verdict) triples** to enable future distillation and re-judging without new API calls.
7. **Run a power analysis** on the first 3 runs to empirically determine the minimum sample size needed to detect extractor changes of a given magnitude.

---

## Footnotes

[^1]: Xu, C., Saranathan, G., Alam, M.P., et al. (2024). *Data Efficient Evaluation of Large Language Models and Text-to-Image Models via Adaptive Sampling*. arXiv:2406.15527.
[^2]: Pylkkinen, J., Drugman, T., & Bisani, M. (2016). *Optimizing Speech Recognition Evaluation Using Stratified Sampling*. Interspeech 2016.
[^3]: Valizadegan, H. (2012). *Sampling Strategies to Evaluate the Performance of Unknown Predictors*. PMC4063531.
[^4]: Schuff, H. (2023). *How to do human evaluation: A brief introduction to user studies in NLP*. Natural Language Engineering, Cambridge Core.
[^5]: Latitude. (2026). *Rule-Based Filters vs LLMs: Moderation Comparison*. https://latitude.so/blog/rule-based-filters-vs-llms-moderation-comparison
[^6]: Composo AI. (2026). *On Cost-Effective LLM-as-a-Judge Improvement Techniques*. arXiv:2604.13717.
[^7]: DocsBot AI. (2025). *Claude 3.5 Sonnet vs Claude 3 Haiku*. https://docsbot.ai/models/compare/claude-3-5-sonnet-20241022/claude-3-haiku
[^8]: arXiv. (2026). *Correlated Errors Undermine LLM Evaluation Panels*. arXiv:2605.29800.
[^9]: arXiv. (2025). *Judge's Verdict: A Comprehensive Analysis of LLM Judge Capability Through Human Agreement*. arXiv:2510.09738.
[^10]: Larionov, D., & Eger, S. (2025). *Token-Efficient Machine Translation Evaluation with Batched Prompting and Prompt Compression*. arXiv:2503.02756.
[^11]: arXiv. (2024). *Semantic State Abstraction Interfaces for LLM-Augmented Portfolio Decisions*. arXiv:2605.06730.
[^12]: arXiv. (2023). *Evaluating LLMs with Multiple Problems at once*. arXiv:2406.10786.
[^13]: Brenndoerfer, M. (2026). *Caching for LLMs: Prompt, Semantic, and Invalidation*. https://mbrenndoerfer.com/writing/caching-prompt-semantic-invalidation-hit-rates-llm
[^14]: PyImageSearch. (2026). *Semantic Caching for LLMs: TTLs, Confidence, and Cache Safety*. https://pyimagesearch.com/2026/05/04/semantic-caching-for-llms-ttls-confidence-and-cache-safety/
[^15]: arXiv. (2025). *Multi-Level Caching Infrastructure*. arXiv:2511.10523.
[^16]: Oboe. (2026). *Distilling a Specialist Judge*. https://oboe.com/learn/architecting-enterprise-agent-evaluation-frameworks-66v856/latency-and-cost-analysis-1wlq6kr
[^17]: arXiv. (2025). *Survey on LLM Evaluation — Distilling Evaluation Abilities*. arXiv:2602.07773.
[^18]: Galileo AI. (2026). *LLM-as-a-Judge vs Human Evaluation*. https://galileo.ai/blog/llm-as-a-judge-vs-human-evaluation
[^19]: arXiv. (2026). *An Empirical Study on Chemical Reaction Extraction*. arXiv:2604.19335.
[^20]: Shetty, S.P., Goldman, R.E., & Filkov, V. (2026). *RadAnnotate: Large Language Models for Efficient and Reliable Radiology Report Annotation*. arXiv:2603.16002.
[^21]: Schröder, C., Gonsior, J., & Tomanek, K. (2025). *Reassessing Active Learning Adoption in Contemporary NLP: A Community Survey*. arXiv:2503.09701.
