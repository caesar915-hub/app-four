# LLM Judge Prompt Design for Structured Signal Extraction Evaluation

**Research Dimension:** Prompt engineering for LLM-as-a-judge evaluating structured extraction from short ADHD journaling text.  
**Date Compiled:** 2026-06-28  
**Searches Conducted:** 18 independent queries across academic papers, benchmarks, and practitioner guides.  

---

## Key Findings

### 1. Rubric-Based vs. Free-Form Evaluation

Claim: **Explicit rubrics significantly improve LLM judge consistency and reduce leniency bias compared to free-form evaluation.** Giving the judge a detailed scoring rubric with per-dimension criteria and fixed aggregation rules produces more reliable verdicts than asking for a holistic "gut feeling" score.[^1][^2][^3]

Source: MMRareBench (arXiv:2604.10755)  
URL: https://arxiv.org/html/2604.10755v1  
Date: 2026-04-12  
Excerpt: > "All rubrics enforce a strict-calibration principle to counter the leniency bias of LLM-as-judge pipelines: the judge defaults to NO and awards credit only when a criterion is completely satisfied."  
Context: Medical multimodal benchmark using Qwen3-VL-235B as judge with track-specific rubric prompts. Each prompt supplies the reference answer, a set of per-dimension evaluation criteria, and a strict-calibration instruction.  
Confidence: **high**

---

Claim: **Rubric-grounded evaluation with evidence-conditioned scoring reduces style leakage and improves robustness to prompt variation.** Decoupling the judge's evidence generation from the final score aggregation limits drift and makes judgments more traceable.[^4]

Source: "Rubric-Grounded Evaluation for Latent-Slate Tasks" (arXiv:2603.00552)  
URL: https://arxiv.org/pdf/2603.00552  
Date: 2026 (preprint)  
Excerpt: > "Rubric-grounded evaluation uses evidence conditioned scoring: the judge outputs traceable, criterion-level checks with supporting evidence, and a fixed rule aggregates them into a score or process increment. Decoupling evidence from aggregation reduces style leakage, improves robustness to prompt variation, and limits drift."  
Context: Social intelligence tasks; argument applies broadly to any structured evaluation.  
Confidence: **high**

---

Claim: **Detailed structured prompts lead to systematically harsher (but more accurate) judgments than minimal prompts.** An elaborated rubric-based prompt forces step-by-step evaluation, filtering out superficial cues like verbosity or authoritative tone that otherwise sway the judge.[^5]

Source: "Judging the Judges: A Systematic Evaluation of Bias Mitigation Strategies" (arXiv:2510.12462)  
URL: https://arxiv.org/pdf/2510.12462  
Date: 2025 (preprint)  
Excerpt: > "The trend is clear: using a detailed, structured prompt leads to systematically lower scores (harsher judgments), while the minimal prompt yields higher scores (more lenient evaluations) for the same answers."  
Context: Evaluating fine-tuned models on MMLU-Pro; the elaborated prompt reduced influence of superficial answer features.  
Confidence: **high**

---

### 2. Chain-of-Thought Reasoning

Claim: **Chain-of-thought (CoT) reasoning before the verdict improves judge accuracy by ~10 percentage points and increases robustness to systematic biases, at a 1.3–2.9× FLOP cost.** For LLM-as-a-judge, the accuracy-cost trade-off of explicit reasoning is superior to few-shot in-context learning.[^6][^7]

Source: "Thinking Small Models are Efficient LLM Judges" (arXiv:2509.13332)  
URL: https://arxiv.org/html/2509.13332v1  
Date: 2025 (preprint)  
Excerpt: > "Thinking mode offers a much more efficient performance-cost trade-off, delivering superior accuracy with only a modest 1.3-2.9x increase in FLOPs. In contrast, 7-shot ICL is 4.5 times more computationally expensive than the thinking mode, yet delivers less than half the accuracy improvement (+4.5 points vs. +10.5 points)."  
Context: Systematic comparison of Qwen 3 (0.6B, 1.7B, 4B) on RewardBench; Chat Hard category shows largest gap.  
Confidence: **high**

---

Claim: **G-Eval, which combines CoT with a form-filling paradigm and probability-weighted score aggregation, consistently reaches higher human agreement than naive direct scoring.** The framework auto-generates evaluation steps from a rubric, then uses token log-probabilities to smooth integer-snap bias.[^8][^9]

Source: "G-Eval: NLG Evaluation using GPT-4 with Better Human Alignment" (Liu et al., 2023) — referenced in multiple secondary sources  
URL: https://futureagi.com/glossary/g-eval/  
Date: 2026-05-07 (guide)  
Excerpt: > "G-Eval does two things differently from naive judge prompting. First, it asks the judge to generate explicit chain-of-thought evaluation steps from a high-level rubric before scoring. Second, it computes the final score as a probability-weighted average across the score-token logprobs, smoothing the integer-snap problem that plagues raw judge outputs."  
Context: By 2026, G-Eval-style internals have become the de facto standard for reference-free evaluation on open-ended text.  
Confidence: **high**

---

Claim: **CoT improves evaluation accuracy by 10–15% across tasks, but increases token consumption 2–4×.** For high-stakes production evaluation the overhead is often worth it; for rapid development iteration it may be prohibitive.[^10]

Source: "Beyond the Vibe Check: A Systematic Approach to LLM Evaluation" (Vitor Sousa)  
URL: https://www.vitorsousa.com/blog/beyond-the-vibe-check-a-systematic-approach-to-llm-evaluation/  
Date: 2025-11-05  
Excerpt: > "Research shows CoT improves accuracy by 10-15% across various evaluation tasks. The tradeoff is clear: you're doubling latency and cost because the LLM must generate reasoning text before the final judgment."  
Context: Practical evaluation guide for production LLM systems.  
Confidence: **medium**

---

### 3. Few-Shot Examples

Claim: **2–5 diverse few-shot examples per prompt improve evaluation quality, but example selection strategy matters more than raw count.** Semantically dissimilar samples and length-diverse samples maximize coverage; random selection yields diminishing returns.[^11][^12]

Source: "Systematic exploration of prompt configurations and judge models" (arXiv:2603.26516)  
URL: https://arxiv.org/pdf/2603.26516  
Date: 2026 (preprint)  
Excerpt: > "We evaluate the effect of few-shot prompting on evaluation quality by varying both the number of examples (2–5 samples per prompt) and the example selection strategy... Each example comprises three candidate responses reflecting distinct quality levels: correct, moderate, and incorrect. For example selection, we consider: Random; Similarity (selecting semantically dissimilar samples); Length-Diverse (samples with maximally different response lengths)."  
Context: Judge selection methodology for a Portuguese benchmark; examined prompt language, few-shot, and judge model.  
Confidence: **high**

---

Claim: **Few-shot examples should be balanced and cover the full verdict spectrum.** Skewed examples (e.g., too many negatives at the end) can bias the judge through order effects or base-rate priors.[^13]

Source: Evidently AI — "LLM-as-a-judge: a complete guide to using LLMs for evaluations"  
URL: https://www.evidentlyai.com/llm-guide/llm-as-a-judge  
Date: 2023-03-30 (updated)  
Excerpt: > "If you include more negative examples than positive ones, or if all the negative examples are listed towards the end, their order or frequency may affect evaluation results."  
Context: Best-practice guide citing "Calibrate Before Use: Improving Few-Shot Performance of Language Models" (Zhao et al., 2021).  
Confidence: **high**

---

Claim: **Verdict balancing in few-shot calibration prevents the judge from inferring a base-rate prior.** When all examples share the same label, the judge learns to default to that label.[^14]

Source: Autorubric (arXiv:2603.00077)  
URL: https://arxiv.org/html/2603.00077v2  
Date: 2026-04-03  
Excerpt: > "Few-shot calibration includes example submissions with correct verdicts drawn from a training split, with verdict balancing to prevent the judge from inferring a base-rate prior."  
Context: Unified framework for rubric-based LLM evaluation; supports analytic rubrics, per-criterion grading, and ensemble panels.  
Confidence: **high**

---

### 4. Signal-Specific Evaluation Criteria

Claim: **Factual signals (meds) should use pointwise, reference-based evaluation with exact-match criteria; subjective signals (mood/energy/focus) should use analytic rubrics with per-dimension binary checks.** Pairwise evaluation achieves higher human agreement for subjective qualities, while pointwise is more appropriate for objective criteria and scales better.[^15]

Source: Autorubric (arXiv:2603.00077)  
URL: https://arxiv.org/html/2603.00077v2  
Date: 2026-04-03  
Excerpt: > "Pairwise evaluation achieves higher human agreement for subjective qualities like helpfulness, as relative comparison is often easier than absolute scoring. Pointwise evaluation is more appropriate for objective criteria (factuality, compliance) and scales better."  
Context: Framework design paper comparing holistic vs. analytic rubrics and evaluation modes.  
Confidence: **high**

---

Claim: **Binary criteria (MET/UNMET) yield the highest inter-rater reliability, while broad ordinal scales suffer from central-tendency bias.** Narrow scales (3–5 levels) with clear behavioral anchors are preferable.[^14]

Source: Autorubric (arXiv:2603.00077)  
URL: https://arxiv.org/html/2603.00077v2  
Date: 2026-04-03  
Excerpt: > "Binary criteria (MET/UNMET) are the simplest and yield the highest inter-rater reliability. Ordinal criteria use ordered levels (Likert scales) to capture gradations; we encourage narrow scales (3–5 levels) with clear behavioral anchors, since LLM judges exhibit central tendency bias on broad scales."  
Context: Rubric structure design recommendations based on LLM evaluation literature.  
Confidence: **high**

---

Claim: **Negative criteria (penalties for anti-patterns) counteract leniency bias documented in LLM judges.** Scoring should include weighted penalties for specific failure modes.[^14]

Source: Autorubric (arXiv:2603.00077)  
URL: https://arxiv.org/html/2603.00077v2  
Date: 2026-04-03  
Excerpt: > "Criteria carry configurable positive or negative weights. Negative criteria serve as penalties for anti-patterns, counteracting the leniency bias documented in LLM judges."  
Context: Weighted aggregation formula with clamping to prevent penalties pushing scores below zero.  
Confidence: **high**

---

### 5. The Four Error Types: Experiencer, Quotation, Hypothetical, External-Venting

Claim: **Clinical NLP has established that experiencer (patient vs. other), negation, temporality, and hypothetical status are critical contextual properties for accurate sentiment and condition extraction.** A simple trigger-term-based approach (ConText) achieves high precision on experiencer and negation, but historical/hypothetical detection requires more context.[^16][^17]

Source: "ConText: An Algorithm for Determining Negation, Experiencer, and Temporal Status from Clinical Reports" (Harkema et al., PMC2757457)  
URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC2757457/  
Date: 2009 (published)  
Excerpt: > "ConText is a simple algorithm that can be easily integrated in applications that index clinical conditions. It is derived from the NegEx algorithm for identifying negated findings and diseases in discharge summaries. ConText uses regular expressions to identify the scope of trigger terms that are indicative of negation such as 'no' and 'ruled out.'"  
Context: Evaluated on six clinical report types; experiencer precision was high (1.0 on available data) because non-patient experiencers are rare and lexically marked.  
Confidence: **high**

---

Claim: **An experiencer-aware model of emotion outperforms experiencer-agnostic baselines, confirming that disregarding event participants is an oversimplification for emotion detection.** Even state-of-the-art LLMs need explicit instruction to check experiencer attribution.[^18]

Source: "Experiencer-Specific Emotion and Appraisal Prediction" (Klinger & Cimiano, arXiv:2210.12078)  
URL: https://arxiv.org/abs/2210.12078  
Date: 2022-10-21  
Excerpt: > "With texts like 'I felt guilty when he cried', focusing on the sentence level disregards the standpoint of each participant in the situation: the writer ('I') and the other entity ('he') could in fact have different affective states. Our experiencer-aware models of emotions and appraisals outperform the experiencer-agnostic baselines, showing that disregarding event participants is an oversimplification for the emotion detection task."  
Context: Appraisal-based emotion representation on event description corpus.  
Confidence: **high**

---

Claim: **A clinical NLP pipeline using five context checks (current, not hypothetical, concerned the patient, not negated, change concerned the theme) successfully filtered experiencer errors from Dutch psychiatric notes.** The pipeline only scored sentences containing change indicators, and used dependency tagging + regex to enforce context.[^19]

Source: "Information extraction from free text for aiding transdiagnostic psychiatry" (Turner et al., BMC Psychiatry 2022)  
URL: https://link.springer.com/article/10.1186/s12888-022-04058-z  
Date: 2022-06-17  
Excerpt: > "Five checks were performed: whether the phrases were current, not hypothetical, concerned the patient, not negated, and whether the change concerned the theme... This filter uses part-of-speech and dependency tagging based on a previously developed spaCy model, regular expressions and literal phrases."  
Context: Extracting transdiagnostic outcomes from clinical notes; validated against HDRS scores.  
Confidence: **high**

---

Claim: **Quoted/hypothetical affect and external attribution are well-documented failure modes in sentiment analysis.** Aspect-level sentiment analysis explicitly tracks opinion holders (experiencers) and opinion targets, because the same text can express different sentiments from different sources.[^20]

Source: "Review of sentiment analysis: An emotional product development view" (Yan et al., Frontiers Eng Manag 2022)  
URL: https://journal.hep.com.cn/fem/EN/10.1007/s42524-022-0227-z  
Date: 2022-12-15  
Excerpt: > "An opinion can be expressed by a quadruple (g, s, h, t), where g is the target of the sentiment, s is the opinion sentiment with respect to the target g, h is the opinion holder, and t is the time when the opinion is expressed by the opinion holder."  
Context: Aspect-level sentiment analysis survey; emphasis on opinion holder and target.  
Confidence: **medium** (general sentiment analysis, not clinical)

---

### 6. Position and Format

Claim: **Position bias in LLM judges is real and measurable: swapping answer order can shift GPT-4's preference by more than 10% even when responses are identical.** Mitigation requires running both orderings and averaging, or using a "commit-then-justify" paradigm that forces a structured verdict before explanation.[^21][^22][^23]

Source: "Judging LLM-as-a-Judge with MT-Bench and Chatbot Arena" (Zheng et al., 2023) — cited in multiple guides  
URL: https://lmsys.org/blog/2023-06-22-leaderboard/  
Date: 2023-06-22  
Excerpt: > "To mitigate positional bias, evaluation is repeated with reversed answer order. We validate the alignment with human evaluators by asking domain experts to re-judge a subset of 144 pairs. The LLM-based judgments are aligned with human assessments in 92.4% of cases."  
Context: MT-Bench pairwise evaluation; the Arena also uses randomization.  
Confidence: **high**

---

Claim: **The "commit-then-justify" paradigm forces the judge to produce a structured verdict before reasoning, reducing post-hoc rationalization.** This pattern, combined with strict bias controls (conservatism, locality, position independence, verbosity independence), is used in production extraction evaluation.[^24]

Source: EvalBench (arXiv:2510.05710)  
URL: https://arxiv.org/html/2510.05710v2  
Date: 2026-03-19  
Excerpt: > "Following the commit-then-justify paradigm, the judge first produces a structured verdict and then a concise justification (up to 15 words). To ensure reliable and reproducible judgments, we enforce strict bias controls. First, we adopt a principle of conservatism: whenever the evidence is ambiguous, the judge defaults to a negative decision (0), thereby mitigating leniency bias. Second, we enforce locality, strictly prohibiting the use of world knowledge or inferences beyond the provided text. Third, we guarantee position independence by instructing the judge not to let the order or placement of sentences influence its verdicts."  
Context: Financial knowledge-graph extraction evaluation using heterogeneous LLM judge ensemble.  
Confidence: **high**

---

Claim: **Reasoning order matters: requiring the model to output reasoning before the answer yields different (and generally more accurate) results than answer-first.** Answer-first prompts can lead to hallucination where the model fabricates an answer and then defends it.[^25]

Source: "Order Matters in Hallucination: Reasoning Order as Benchmark and Reflexive Prompting for Large-Language-Models" (arXiv:2408.05093)  
URL: https://arxiv.org/html/2408.05093v4  
Date: 2024 (preprint)  
Excerpt: > "We discovered that the order in which LLMs generate answers and reasoning impacts their consistency. Specifically, results vary significantly when an LLM generates an answer first and then provides the reasoning versus generating the reasoning process first and then the conclusion."  
Context: Proposed Reflexive Prompting strategy to mitigate reasoning-order inconsistency.  
Confidence: **high**

---

Claim: **For extraction evaluation, presenting the source text before the extraction (text-first) is generally preferred because it lets the judge build context before evaluating claims.** However, in prompt design, placing the evaluation instruction at the end (after all inputs) is standard practice.[^26]

Source: "When processing a text: prompt before it or after it?" (OpenAI Community)  
URL: https://community.openai.com/t/when-processing-a-text-prompt-before-it-or-after-it/247801  
Date: 2023-06-02  
Excerpt: > "Placing the prompt before the text allows the model to immediately understand the task and frame its response accordingly." / "The instructions that I provided for the generation seem to permeate better when the text is provided after the the set of instructions."  
Context: Practitioner discussion on instruction ordering; consensus is instruction → context → task.  
Confidence: **medium** (practitioner consensus, not controlled experiment)

---

### 7. General LLM-as-a-Judge Accuracy

Claim: **Well-calibrated LLM judges reach 80–90% agreement with human evaluators on clear rubrics, which is comparable to or better than inter-annotator agreement between humans.** Accuracy depends heavily on rubric quality, judge model strength, and bias mitigation.[^27][^28]

Source: Arize — "LLM as a Judge - Primer and Pre-Built Evaluators"  
URL: https://arize.com/llm-as-a-judge/  
Date: 2026-04-23  
Excerpt: > "Compare accuracy: if the judge and human labels match on 75-90% of examples, you've got alignment and you're ready to scale. If not, iterate on your template or adjust the model to refine the results."  
Context: Production evaluation guide for Arize platform; recommends reading disagreements to identify rubric gaps.  
Confidence: **high**

---

Claim: **The automated judge retains a higher proportion of samples than human evaluation, indicating a systematic leniency bias in LLM judges.** This is consistent across languages and domains.[^29][^30]

Source: Luxembourgish Instruction Tuning Dataset (arXiv:2510.24434)  
URL: https://arxiv.org/html/2510.24434v2  
Date: 2026-03-30  
Excerpt: > "The automated judge retains a higher proportion of samples (92.6%) than the human evaluation (69.0%), indicating a leniency bias in the LLM judge."  
Context: LLM-as-a-judge scoring for low-resource language generation; same pattern observed in mental health evaluation.  
Confidence: **high**

---

## Prompt Design Principles

Based on the evidence above, the following principles are recommended for designing an LLM judge prompt that evaluates structured signal extraction from ADHD journal text:

### P1. Use an Analytic Rubric with Binary Criteria
Decompose evaluation into per-signal, per-error-type checks rather than a single holistic score. Each signal (mood, energy, focus, meds) should have its own set of binary MET/UNMET criteria. Binary criteria yield the highest inter-rater reliability.[^14]

### P2. Enforce Strict Calibration: Default to "No"
Counter leniency bias by instructing the judge to default to a negative verdict (e.g., `false_positive` or `na`) unless the evidence is unambiguous. Award credit only when a criterion is fully satisfied.[^1][^24]

### P3. Require Reasoning Before the Verdict (CoT)
Instruct the judge to produce a step-by-step reasoning trace before emitting the final verdict. This improves accuracy by 10–15% and reduces post-hoc rationalization. For production, use a "commit-then-justify" structure: structured verdict first, then concise reasoning.[^6][^8][^24]

### P4. Include 2–5 Balanced Few-Shot Examples
Show examples spanning the full verdict spectrum (correct, partial, missed, false_positive, na). Include at least one example of each major error type the extractor is prone to. Balance positive and negative examples and avoid clustering all negatives at the end.[^11][^12][^13]

### P5. Separate Factual from Subjective Signals
- **Meds:** Use exact-match or reference-based criteria. A med is either present in the text or fabricated. Pointwise evaluation is appropriate.[^15]
- **Mood/Energy/Focus:** Use experiencer-aware criteria. The judge must explicitly verify the author is the experiencer, the statement is not quoted/hypothetical, and the sentiment is directed at the self, not an external entity.[^16][^18][^19]

### P6. Explicitly Enumerate the Four Error Checks
The judge should be instructed to check each error type explicitly, not infer them implicitly:
1. **Experiencer confusion:** Is the subject of the affect the author? ("the kids were tired" → author is not tired)
2. **Quoted/hypothetical affect:** Is the affect reported speech, a hypothetical, or a description of someone else's observation? ("she said I seem happy" → not author-reported)
3. **External venting:** Is the sentiment directed at an external entity rather than the author's internal state? ("Retail fucking blows" → external anger, not personal mood)
4. **Context inversion / resolved past state:** Is the described state a resolved past condition or an active medication effect? ("brain fog that Sandoz cleared" → fog is resolved, not current)

### P7. Mitigate Position Bias
- In the prompt, present the **source text first**, then the **extracted signals**, then the **evaluation instructions**.
- Use neutral labels (e.g., "Response A / Response B") rather than ordinal labels ("first / second").
- If doing pairwise comparison, run both orderings and only accept consistent verdicts.[^21][^22]

### P8. Use Structured Output (JSON)
Require the judge to output a machine-parseable format with fixed fields: `verdict`, `reasoning`, `warning` (error-type tag). This enables automated aggregation and error analysis.[^24]

### P9. Set Temperature to 0.0
Use deterministic decoding to maximize reproducibility. Judge evaluation should not require creativity.[^24]

### P10. Validate Against a Human-Labeled Gold Set
Before trusting the judge at scale, calibrate it against 30–50 human-annotated examples. Track leniency drift across runs and recalibrate when it exceeds ±0.25.[^27][^30]

---

## Recommended Prompt Structure (Template)

```
You are an expert evaluator assessing structured signal extraction from ADHD
journal entries. Your job is to determine whether the extracted signals are
grounded in the source text.

=== STRICT CALIBRATION ===
- Default to the most conservative verdict when evidence is ambiguous.
- Award a "correct" verdict ONLY when the extraction is fully and unambiguously
  supported by the text.
- Do NOT use world knowledge or inference beyond what is explicitly stated.
- Do NOT let sentence order or position in the text affect your verdict.

=== SOURCE TEXT ===
{source_text}

=== EXTRACTED SIGNALS ===
Mood:   {extracted_mood}
Energy: {extracted_energy}
Focus:  {extracted_focus}
Meds:   {extracted_meds}

=== EVALUATION CRITERIA ===
For each signal, check the following in order:

1. EXPERIENCER: Is the subject of the state the author themselves?
   - Reject if the text describes someone else ("the kids were tired").
   - Reject if the text is about an external entity ("Retail fucking blows").

2. QUOTATION/HYPOTHETICAL: Is the affect the author's own direct report?
   - Reject if it is reported speech ("she said I seem happy").
   - Reject if it is hypothetical or conditional ("if I took more, I might feel better").

3. TEMPORALITY / CONTEXT INVERSION: Is the state current and unresolved?
   - Reject if the text describes a resolved past state ("brain fog that Sandoz cleared").
   - Reject if the text describes a future or hypothetical state.

4. SUBJECTIVE SIGNAL ALIGNMENT (Mood / Energy / Focus):
   - The extracted label must match the author's explicit or strongly implied
     self-reported state.
   - Do NOT infer a positive state from a complaint about externals.
   - Do NOT infer a negative state from advice-giving or informational text.

5. FACTUAL SIGNAL ALIGNMENT (Meds):
   - The medication name must appear verbatim or as an unambiguous synonym
     in the source text.
   - If the text mentions a medication class ("stimulants") without a specific
     drug name, a specific extraction is a FALSE POSITIVE unless the extractor
     has a known mapping rule.

=== VERDICT CATEGORIES ===
- correct:       The extraction is fully supported by the text.
- partial:       The extraction is partially correct but incomplete or imprecise.
- missed:        The text contains a signal that the extractor failed to capture.
- false_positive: The extractor invented a signal not supported by the text.
- na:            The text does not contain enough information to evaluate this signal.

=== FEW-SHOT EXAMPLES ===
[Example 1: Correct extraction]
Text: "Feeling pretty good today, took my Adderall at 8am."
Extraction: mood=good, energy=alert, focus=sharp, meds=[Adderall]
Verdict: correct
Reasoning: All signals are directly stated by the author. Med name is exact.

[Example 2: Experiencer confusion → false_positive]
Text: "the kids were tired and I had to carry them"
Extraction: mood=low, energy=tired
Verdict: false_positive
Reasoning: The tiredness is attributed to "the kids," not the author. The
  extractor incorrectly assigned the experiencer.
Warning: experiencer_error

[Example 3: Quoted affect → false_positive]
Text: "she said I seem happy lately"
Extraction: mood=good
Verdict: false_positive
Reasoning: The happiness is reported speech from a third party, not the
  author's own self-reported mood.
Warning: quotation_error

[Example 4: External venting → false_positive]
Text: "Retail fucking blows, I hate this job"
Extraction: mood=low
Verdict: false_positive
Reasoning: The anger is directed at an external entity (retail/job). There is
  no explicit self-reported mood state. The author may feel many things;
  "low" is not directly supported.
Warning: external_venting

[Example 5: Resolved past state → false_positive]
Text: "brain fog that Sandoz cleared in about an hour"
Extraction: focus=foggy
Verdict: false_positive
Reasoning: The fog is described as resolved ("cleared"). The current state is
  "cleared," not "foggy." Extracting "foggy" reads a resolved past state as current.
Warning: context_inversion

[Example 6: Advice post → false_positive]
Text: "If you're starting Elvanse, drink a lot of water and take magnesium"
Extraction: meds=[Elvanse, magnesium], mood=good, focus=sharp
Verdict: false_positive (mood, focus), correct (meds)
Reasoning: The text is pure medication advice. No mood or focus state is
  reported by the author. The med "Elvanse" is mentioned correctly; the med
  "magnesium" is advice, not a reported medication taken by the author.
Warning: fabricated_state

=== YOUR TASK ===
Apply the criteria above to the current text and extraction. Produce your
reasoning step-by-step, then output ONLY the following JSON:

{
  "mood": {
    "verdict": "correct|partial|missed|false_positive|na",
    "reasoning": "<15-word concise explanation>",
    "warning": "<error_type tag or empty string>"
  },
  "energy": {
    "verdict": "correct|partial|missed|false_positive|na",
    "reasoning": "<15-word concise explanation>",
    "warning": "<error_type tag or empty string>"
  },
  "focus": {
    "verdict": "correct|partial|missed|false_positive|na",
    "reasoning": "<15-word concise explanation>",
    "warning": "<error_type tag or empty string>"
  },
  "meds": {
    "verdict": "correct|partial|missed|false_positive|na",
    "reasoning": "<15-word concise explanation>",
    "warning": "<error_type tag or empty string>"
  }
}
```

---

## Controversies & Trade-offs

### C1. CoT Cost vs. Accuracy
- **Pro:** CoT improves accuracy ~10–15%, reduces bias, and produces debuggable reasoning traces.[^6][^10]
- **Con:** Increases token consumption 2–4× and latency. For a high-volume journaling app, evaluating thousands of daily entries could become expensive. The trade-off is most acute if using a frontier model (GPT-4o/Claude) as the judge.
- **Resolution:** Use a "thinking" small model (e.g., Qwen 3 4B with reasoning enabled) for routine batch evaluation, and reserve frontier models for disputed cases or calibration.[^6]

### C2. Rubric Brittleness
- **Pro:** Detailed rubrics reduce leniency and increase consistency.[^1][^5]
- **Con:** Rubrics can be brittle. Minor wording changes can shift scores dramatically. If the judge model is updated, scores may drift even for identical content.[^22]
- **Resolution:** Version the rubric and judge model together. Recalibrate on a human gold set after any model change. Track leniency as a first-class metric.[^30]

### C3. Few-Shot Example Curation Burden
- **Pro:** Few-shot examples teach the judge domain-specific edge cases far better than abstract definitions.[^11][^12]
- **Con:** Curating balanced, diverse examples is labor-intensive. Poor examples (e.g., all negatives clustered together) can themselves bias the judge.[^13]
- **Resolution:** Start with 3 examples covering the three most common error types. Add examples iteratively based on judge-human disagreement analysis.[^27]

### C4. Subjective vs. Objective Signal Tension
- **Pro:** Treating mood/energy/focus as subjective (requiring explicit self-report) and meds as objective (exact match) aligns with the different epistemic nature of these signals.[^15]
- **Con:** Some useful signals are genuinely ambiguous. For example, "Retail fucking blows, I hate this job" might legitimately indicate low mood if the author consistently vents about work. A strict "no external venting" rule may undercount valid signals.
- **Resolution:** Use the `na` category generously for ambiguous cases rather than forcing a false positive or false negative. Human review of `na` cases can refine the rubric over time.

### C5. Position Bias vs. Readability
- **Pro:** Text-first, extraction-second ordering reduces primacy bias and lets the judge build context before evaluating claims.[^26]
- **Con:** Very long source texts followed by extractions can cause "lost in the middle" attention problems, where the middle of the prompt receives less attention.[^22]
- **Resolution:** Keep source texts short (1–3 sentences as given). Use explicit delimiters (`=== SOURCE TEXT ===`) to structure the prompt. If texts are longer, consider chunking or placing key extraction claims in the instruction before the text.[^22]

### C6. Commit-Then-Justify vs. CoT-First
- **Pro:** Commit-then-justify (verdict before reasoning) prevents the model from generating a verdict to fit its reasoning.[^24]
- **Con:** Some research shows that reasoning-first produces more accurate results because the model explores the evidence before committing.[^25]
- **Resolution:** The evidence is mixed. For extraction evaluation where the answer space is discrete and small, commit-then-justify is likely safer because it reduces post-hoc rationalization. For open-ended quality scoring, reasoning-first may be better.[^24][^25]

### C7. Binary vs. Graded Verdicts
- **Pro:** Binary MET/UNMET criteria yield the highest reliability.[^14]
- **Con:** A 5-category verdict (`correct`, `partial`, `missed`, `false_positive`, `na`) adds nuance that is valuable for downstream analytics (e.g., precision/recall curves).
- **Resolution:** Use binary internal checks per criterion, but allow the final aggregated verdict to be categorical. The internal checks should be binary; the final output can be the 5-way label. This preserves reliability while capturing useful granularity.

---

## Footnotes

[^1]: MMRareBench. "Model-graded rubric scoring." arXiv:2604.10755, 2026. https://arxiv.org/html/2604.10755v1

[^2]: Langfuse. "LLM-as-a-Judge." 2026-06-08. https://langfuse.com/docs/evaluation/evaluation-methods/llm-as-a-judge

[^3]: Confident AI. "LLM-as-a-Judge Simply Explained." 2026-05-16. https://www.confident-ai.com/blog/why-llm-as-a-judge-is-the-best-llm-evaluation-method

[^4]: "Rubric-Grounded Evaluation for Latent-Slate Tasks." arXiv:2603.00552, 2026. https://arxiv.org/pdf/2603.00552

[^5]: "Judging the Judges: A Systematic Evaluation of Bias Mitigation Strategies." arXiv:2510.12462, 2025. https://arxiv.org/pdf/2510.12462

[^6]: "Thinking Small Models are Efficient LLM Judges." arXiv:2509.13332, 2025. https://arxiv.org/html/2509.13332v1

[^7]: Comet. "Chain-of-Thought Prompting: A Guide for LLM Apps and Agents." 2026-01-22. https://www.comet.com/site/blog/chain-of-thought-prompting/

[^8]: FutureAGI. "What Is G-Eval?" 2026-05-07. https://futureagi.com/glossary/g-eval/

[^9]: Comet. "G-Eval for LLM Evaluation." 2026-02-02. https://www.comet.com/site/blog/g-eval-for-llm-evaluation/

[^10]: Vitor Sousa. "Beyond the Vibe Check: A Systematic Approach to LLM Evaluation." 2025-11-05. https://www.vitorsousa.com/blog/beyond-the-vibe-check-a-systematic-approach-to-llm-evaluation/

[^11]: "Systematic exploration of prompt configurations and judge models." arXiv:2603.26516, 2026. https://arxiv.org/pdf/2603.26516

[^12]: MT-Bench / FastChat. "LLM Judge README." 2023. https://github.com/lm-sys/FastChat/blob/main/fastchat/llm_judge/README.md

[^13]: Evidently AI. "LLM-as-a-judge: a complete guide." 2023-03-30. https://www.evidentlyai.com/llm-guide/llm-as-a-judge

[^14]: Autorubric. "A Unified Framework for Rubric-Based LLM Evaluation." arXiv:2603.00077, 2026. https://arxiv.org/html/2603.00077v2

[^15]: Autorubric. "Pointwise vs. pairwise evaluation modes." arXiv:2603.00077, 2026. https://arxiv.org/html/2603.00077v2

[^16]: Harkema et al. "ConText: An Algorithm for Determining Negation, Experiencer, and Temporal Status." PMC2757457, 2009. https://pmc.ncbi.nlm.nih.gov/articles/PMC2757457/

[^17]: MedCAT / CogStack. "Experiencer, negation, and temporality meta-annotations." 2020–2023. https://www.medrxiv.org/content/10.1101/2020.04.24.20078006v1.full-text

[^18]: Klinger & Cimiano. "Experiencer-Specific Emotion and Appraisal Prediction." arXiv:2210.12078, 2022. https://arxiv.org/abs/2210.12078

[^19]: Turner et al. "Information extraction from free text for aiding transdiagnostic psychiatry." BMC Psychiatry, 2022. https://link.springer.com/article/10.1186/s12888-022-04058-z

[^20]: Yan et al. "Review of sentiment analysis: An emotional product development view." Frontiers Eng Manag, 2022. https://journal.hep.com.cn/fem/EN/10.1007/s42524-022-0227-z

[^21]: Zheng et al. "Judging LLM-as-a-Judge with MT-Bench and Chatbot Arena." 2023. https://lmsys.org/blog/2023-06-22-leaderboard/

[^22]: Shi et al. "A Systematic Study of Position Bias in LLM-as-a-Judge." arXiv:2406.07791, 2024. https://arxiv.org/html/2406.07791v9

[^23]: Brenndoerfer. "Position Bias in LLM Judges: Measurement and Mitigation." 2026-03-11. https://mbrenndoerfer.com/writing/position-bias-in-llm-judges

[^24]: EvalBench. "LLM-as-Judge evaluation protocol." arXiv:2510.05710, 2026. https://arxiv.org/html/2510.05710v2

[^25]: Xie et al. "Order Matters in Hallucination: Reasoning Order as Benchmark." arXiv:2408.05093, 2024. https://arxiv.org/html/2408.05093v4

[^26]: OpenAI Community. "When processing a text: prompt before it or after it?" 2023-06-02. https://community.openai.com/t/when-processing-a-text-prompt-before-it-or-after-it/247801

[^27]: Arize. "LLM as a Judge - Primer and Pre-Built Evaluators." 2026-04-23. https://arize.com/llm-as-a-judge/

[^28]: DeepEval / Confident AI. "G-Eval | DeepEval." 2026. https://deepeval.com/docs/metrics-llm-evals

[^29]: Luxembourgish IT Dataset. "LLM-as-a-judge scoring." arXiv:2510.24434, 2026. https://arxiv.org/html/2510.24434v2

[^30]: eval-layer / Erez Weinstein. "Leniency Tracking." 2026-04-23. https://github.com/erezweinstein5/eval-layer/blob/main/references/rubric-design.md
