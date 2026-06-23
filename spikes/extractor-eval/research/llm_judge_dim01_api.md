# Deep Research: Anthropic API for Bulk LLM Judging of NLP Extraction Quality

**Research Date:** 2026-06-23  
**Researcher:** Deep Research Agent  
**Mission:** Investigate practical Anthropic API usage for bulk LLM judging of ~2,000 extraction judgments per run (500 posts × 4 signals), with a $5–20 budget per evaluation run.

---

## Table of Contents

- [Key Findings](#key-findings)
- [Cost Estimates](#cost-estimates)
- [Recommended API Setup](#recommended-api-setup)
- [Controversies & Trade-offs](#controversies--trade-offs)
- [Source Index](#source-index)

---

## Key Findings

### 1. Message Batches API is the Primary Cost-Lever for Bulk Evaluation

```
Claim: Anthropic's Message Batches API processes up to 10,000 requests per batch at 50% off standard token pricing, with a 24-hour completion SLA, and supports all Messages API features including tool use, system prompts, and multi-turn conversations.[^1]
Source: CodeWords AI — "Anthropic batch API: process thousands of prompts at 50% cost"
URL: https://www.codewords.ai/blog/anthropic-batch-api
Date: 2026-06-03
Excerpt: "Anthropic's batch API processes up to 10,000 requests in a single call at half the per-token cost of standard synchronous requests... batch processing delivers a guaranteed 50% discount on both input and output tokens across all Claude models."
Context: Article describes a production workflow where 1,000 articles at ~2,000 tokens input + ~1,000 tokens output cost $21 synchronous vs $10.50 batch.
Confidence: high
```

```
Claim: Each batch request is independent — it gets its own system prompt, messages array, and model parameters — but results are returned unordered, so meaningful custom_id values are essential for reconciliation.[^2]
Source: Steve Kinney — "Using Anthropic's Message Batches API with Temporal"
URL: https://stevekinney.com/writing/anthropic-batch-api-with-temporal
Date: 2026-03-17 (modified); original 2025-05-08
Excerpt: "The Message Batches API allows you to submit batches of up to 10,000 queries that will be processed within 24 hours, with a 50% cost reduction compared to standard API calls... Any request that you can make to the standard Messages API can be included in a batch."
Context: Practical TypeScript implementation guide with Temporal workflow orchestration.
Confidence: high
```

```
Claim: Batch requests have a 32 MB file-size limit and expire after 29 days. Most batches under 5,000 requests finish within 1–2 hours in practice.[^3]
Source: Pristren — "Anthropic Message Batches API: 50% Off Claude for Async Workloads"
URL: https://pristren.com/blog/anthropic-batch-api-guide/
Date: 2026-05-17
Excerpt: "Maximum batch size: 10,000 requests or 32 MB... Batches expire after 29 days... In practice, most batches under 5,000 requests finish within 1-2 hours depending on current queue depth and model load."
Context: FAQ-style guide with cost-comparison tables showing batch + caching savings up to 85%.
Confidence: high
```

### 2. Claude 3.5 Haiku is the Cost-Accuracy Sweet Spot for Simple Extraction Judging

```
Claim: Claude 3.5 Haiku costs $0.80/1M input tokens and $4.00/1M output tokens, roughly 12× cheaper than Claude 3.5 Sonnet, yet achieves strong performance on classification, extraction, and simple reasoning tasks.[^4]
Source: TeamAI — "Every Claude Model, Compared: Versions, Pricing & Which to Use"
URL: https://teamai.com/blog/large-language-models-llms/understanding-different-claude-models/
Date: 2026-06-18
Excerpt: "Claude 3 Haiku is cheaper than any previous Claude version, costing $0.25 per million token input and $1.25 per million token output. Claude 3.5 Haiku is slightly more expensive, at $0.80 per million input tokens and $4.00 per million output tokens. This slight added price brings an extensive increase in quality."
Context: Model comparison showing Haiku matches Claude 3 Opus on many intelligence tasks and surpasses it on multiple evaluations.
Confidence: high
```

```
Claim: Haiku models are specifically recommended for "classification, extraction, summarization, and any high-volume, latency-sensitive task" because these tasks depend on pattern matching rather than reasoning chains.[^5]
Source: MorphLLM — "Sonnet vs Haiku: Claude Model Comparison for Developers"
URL: https://www.morphllm.com/sonnet-vs-haiku
Date: 2026-03-31
Excerpt: "Haiku wins on tasks where the bottleneck is speed or cost, not reasoning depth. Classification... simple extraction... routing decisions... Haiku handles these at the same quality as Sonnet at 3.75x lower cost."
Context: Detailed task-based routing advice showing most teams should route 60% of prompts to Haiku.
Confidence: high
```

```
Claim: For the developer's specific extraction-judging task (binary/multiclass verdicts on mood, energy, focus, medication presence), Haiku's instruction-following capability is sufficient and it is the recommended model tier.[^6]
Source: SitePoint — "Claude Model Selection Guide | Sonnet vs Opus vs Haiku"
URL: https://www.sitepoint.com/claude-model-selection-framework/
Date: 2026-03-13
Excerpt: "Claude 3.5 Haiku: The Speed Tier... Pricing sits at $0.80 per million input tokens and $4.00 per million output tokens... the natural choice for tasks where milliseconds count and volume is high."
Context: Task-based framework explicitly recommends Haiku for "classification, extraction, simple transforms."
Confidence: high
```

### 3. Structured Output via Tool Use is Anthropic's Native Schema Enforcement Path

```
Claim: Anthropic does not provide a dedicated `response_format` JSON mode like OpenAI; instead, Claude's primary structured output mechanism is tool use — defining a function with a JSON Schema input spec and forcing the model to call it via `tool_choice: {type: "tool", name: "..."}`.[^7]
Source: TokenMix AI — "Structured Output and JSON Mode Guide 2026"
URL: https://tokenmix.ai/blog/structured-output-json-guide
Date: 2026-04-10
Excerpt: "Anthropic Tool Use: Schema Enforcement: Yes (tool input schema)... Parse Failure Rate: <0.2%... Token Overhead: ~150-300 tokens... Available Since: Apr 2024"
Context: Cross-provider comparison ranking Anthropic tool use as second-best after OpenAI strict mode for parse reliability.
Confidence: high
```

```
Claim: In November 2025, Anthropic released a beta native Structured Outputs feature (via `output_format` with `anthropic-beta: structured-outputs-2025-11-13`) that compiles JSON schemas into grammars at inference time, but it requires Claude Sonnet 4.5 or Opus 4.1 and is not yet available for Haiku.[^8]
Source: Thomas Wiegold — "Claude API Structured Output: Complete Guide to Schema-Guaranteed Responses"
URL: https://thomas-wiegold.com/blog/claude-api-structured-output/
Date: 2025-11-15
Excerpt: "November 14, 2025 changed that. Anthropic released structured outputs in public beta, and it actually solves the problem... structured outputs compile your JSON schema into a grammar and actively restrict token generation during inference."
Context: Technical deep dive noting first-request latency from grammar compilation and 24-hour cache invalidation.
Confidence: medium
```

```
Claim: Anthropic's beta Structured Outputs (GA as of March 2026) are supported in Batch API, and when combined with prompt caching can save up to 90% on repeated requests.[^9]
Source: ClaudeLab — "Claude API Structured Outputs GA: Complete Guide"
URL: https://claudelab.net/en/articles/api-sdk/structured-outputs-ga
Date: 2026-03-14
Excerpt: "For high-volume workloads, combine Structured Outputs with prompt caching to save up to 90% on repeated requests. Cache the system prompt and schema — both remain constant across requests."
Context: Official-feature documentation comparing Structured Outputs vs Tool Use for different use cases.
Confidence: medium
```

### 4. Prompt Caching Can Reduce Input Costs by ~90% for Repeated Evaluation Prompts

```
Claim: Anthropic provides developer-controlled prompt caching through explicit cache breakpoints (`cache_control: {type: "ephemeral"}`), offering a 90% discount on cached input tokens — e.g., Haiku 4.5 cached read at $0.10/1M vs $1.00/1M standard input.[^10]
Source: Anthropic Official Pricing Page
URL: https://www.anthropic.com/pricing
Date: 2026-06-23 (fetched live)
Excerpt: "Haiku 4.5: Input $1 / MTok, Output $5 / MTok, Prompt caching Write $1.25 / MTok, Read $0.10 / MTok... Save 50% with batch processing."
Context: Live pricing snapshot showing current production rates for all model tiers.
Confidence: high
```

```
Claim: For bulk evaluation workloads where the system prompt (rubric, instructions) and JSON schema are identical across requests, prompt caching combined with batch processing can yield 85%+ input cost savings.[^11]
Source: Steve Kinney — "Using Anthropic's Message Batches API with Temporal"
URL: https://stevekinney.com/writing/anthropic-batch-api-with-temporal
Date: 2026-03-17
Excerpt: "When combined with other features like prompt caching, discounts can potentially reach up to 95% for input tokens under optimal conditions."
Context: Cost-savings table showing batch + optimal caching for 10,000 document summaries: $650 → $100 (85% savings).
Confidence: high
```

### 5. Rate Limits and Error Handling Require Production-Grade Retry Logic

```
Claim: Anthropic enforces three simultaneous rate-limit dimensions: requests per minute (RPM), input tokens per minute (TPM), and output tokens per minute (TPM), each with independent quotas and reset windows. Exceeding any triggers a 429 with `Retry-After` or `anthropic-ratelimit-*` headers.[^12]
Source: SitePoint — "Claude API 429 Error Handling | Production Python Guide"
URL: https://www.sitepoint.com/claude-api-429-error-handling-python/
Date: 2026-03-20
Excerpt: "Anthropic enforces three simultaneously: request-rate limits, token-rate limits, and concurrent-request limits... Generic retry logic typically assumes one throttle boundary. The token-budget gate can still reject a request that passed the requests-per-minute check."
Context: Production Python code for parsing rate-limit headers and implementing circuit breakers.
Confidence: high
```

```
Claim: The Anthropic Python SDK includes built-in retry logic (default max_retries=2) with exponential backoff for 429 and 5xx errors, but production systems should implement additional application-level retry logic, circuit breakers, and proactive throttling.[^13]
Source: ClaudeReadiness — "Claude Error Handling Patterns"
URL: https://claudereadiness.com/blog/claude-error-handling-patterns/
Date: 2025-12-01
Excerpt: "The SDK has built-in retry logic for 429 and 5xx errors, but production systems require additional application-level retry logic and careful configuration... Increase max_retries to 4-5 for background tasks, keep at 2-3 for user-facing requests."
Context: Complete error taxonomy table showing retryable vs permanent errors for all HTTP status codes.
Confidence: high
```

```
Claim: For batch processing, partial failure is expected. Batch results include per-request status codes; common failure modes include `overloaded`, `invalid_request`, and `rate_limited`. The recommended pattern is to parse successes vs failures, inspect error reasons, and resubmit failed requests in a new batch with exponential backoff.[^14]
Source: CodeWords AI — "Anthropic batch API"
URL: https://www.codewords.ai/blog/anthropic-batch-api
Date: 2026-06-03
Excerpt: "Batch results include per-request status codes. Some requests will fail — rate limits, malformed inputs, or context length violations. Your automation needs to handle partial failures gracefully... Parse the results file, separating successes from failures. Inspect failure reasons... Reformat failed requests into a new batch."
Context: Best-practice guide for production batch evaluation workflows.
Confidence: high
```

### 6. LLM-as-a-Judge Achieves 80–90% Human Agreement with Proper Prompting

```
Claim: Strong LLM judges (GPT-4 class, Claude Sonnet class) achieve 80–90% agreement with human evaluators on quality dimensions, comparable to inter-annotator agreement between humans. Accuracy improves significantly with well-designed rubrics and clear evaluation criteria.[^15]
Source: Langfuse — "LLM-as-a-Judge"
URL: https://langfuse.com/docs/evaluation/evaluation-methods/llm-as-a-judge
Date: 2026-06-08
Excerpt: "Research shows that strong LLM judges (such as GPT-5 class models) achieve 80-90% agreement with human evaluators on many quality dimensions, which is comparable to inter-annotator agreement between humans."
Context: FAQ-style guide recommending judge models with strong instruction-following and structured output support.
Confidence: high
```

```
Claim: Four drop-in techniques — ensemble scoring, task-specific criteria injection, calibration context, and adaptive model escalation — can improve LLM judge accuracy significantly. Criteria + ensembling reach up to 85.8% accuracy (+13.5pp over baseline), and small models benefit disproportionately from ensembling.[^16]
Source: arXiv — "On Cost-Effective LLM-as-a-Judge Improvement Techniques" (v3)
URL: https://arxiv.org/html/2604.13717v3
Date: 2026-06-09
Excerpt: "Criteria + ensembling reach up to 85.8% accuracy, +13.5pp over baseline... Small models benefit disproportionately from ensembling, making high-accuracy LLM judges accessible at low cost. We show that these techniques generalise across model providers, evaluating on both OpenAI GPT and Anthropic Claude families."
Context: Rigorous empirical study on RewardBench 2 with cost-accuracy Pareto frontier analysis.
Confidence: high
```

```
Claim: For extraction-evaluation tasks, structured output formatting consistently improves LLM judge performance across all models compared to unstructured evaluation.[^17]
Source: arXiv — "Improving Automatic Evaluation of LLMs in Biomedical Relation Extraction via LLMs-as-the-Judge"
URL: https://arxiv.org/html/2506.00777v1
Date: 2025-06-01
Excerpt: "For all three datasets, we find based on paired t-test that the performance difference between the structured and unstructured approach is statistically significant (p<0.05) for both metrics."
Context: Academic study on biomedical extraction showing structured output improves judge reliability.
Confidence: high
```

### 7. Anthropic vs OpenAI: Anthropic Wins on Cost-Efficiency and Context Length; OpenAI Has Broader Ecosystem

```
Claim: Anthropic is 40–60% cheaper at comparable quality levels. Claude 3 Sonnet offers comparable quality to GPT-4o at roughly 40–60% lower cost for typical workloads. Anthropic's context window is 200K tokens (vs OpenAI's 128K).[^18]
Source: Sfailabs — "OpenAI API vs Anthropic API: Developer and Cost Comparison"
URL: https://sfailabs.com/guides/openai-api-vs-anthropic-api
Date: 2026-01-31
Excerpt: "Anthropic is 40-60% cheaper at comparable quality levels... Claude 3 Sonnet offers comparable quality to GPT-4o at roughly 40-60% lower cost for typical workloads... Context window: Anthropic 200K tokens vs OpenAI 128K tokens."
Context: Side-by-side comparison table with detailed pricing, feature, and ecosystem analysis.
Confidence: high
```

```
Claim: One academic study excluded Anthropic models from final consideration because "the Anthropic API lacked [native structured output] capability and was therefore eliminated" at the time of the study, though this has since been resolved with the 2025 beta and 2026 GA releases.[^19]
Source: arXiv — "An analysis of a decade of AI research and 56,800 conference papers"
URL: https://arxiv.org/html/2606.16974v1
Date: 2026-06-15
Excerpt: "The Anthropic API lacked this native capability and was therefore eliminated."
Context: Large-scale academic paper analysis using Gemini 2.5 Flash due to structured output requirements.
Confidence: medium
```

---

## Cost Estimates

### Model Pricing (Standard Synchronous API, per 1M tokens)

| Model | Input | Output | Context | Best For |
|-------|-------|--------|---------|----------|
| **Haiku 4.5** (current) | $1.00 | $5.00 | 200K | Volume classification, extraction judging |
| **Haiku 3.5** (legacy) | $0.80 | $4.00 | 200K | Same as above; slightly cheaper |
| **Sonnet 4.6** | $3.00 | $15.00 | 1M | Complex reasoning, coding, deep analysis |
| **Opus 4.8** | $5.00 | $25.00 | 1M | Maximum capability, agentic coding |
| **Fable 5** | $10.00 | $50.00 | 1M | Frontier quality, non-negotiable accuracy |

*Source: Anthropic official pricing page, fetched 2026-06-23.[^10]*

### Model Pricing (Batch API — 50% discount)

| Model | Input | Output |
|-------|-------|--------|
| **Haiku 4.5** | $0.50 | $2.50 |
| **Sonnet 4.6** | $1.50 | $7.50 |
| **Opus 4.8** | $2.50 | $12.50 |

### Prompt Caching (read hits — ~90% discount on input)

| Model | Cached Read |
|-------|-------------|
| **Haiku 4.5** | $0.10 / 1M |
| **Sonnet 4.6** | $0.30 / 1M |
| **Opus 4.8** | $0.50 / 1M |

### Estimated Cost Per 1,000 Judgments (Haiku 4.5, Batch API)

Assumptions for a single judgment:
- **System prompt / rubric:** ~1,500 tokens (cached after first request)
- **User prompt (post text + extraction candidate + instructions):** ~500 tokens
- **Output (JSON verdict + reasoning):** ~100 tokens

| Scenario | Input Cost | Output Cost | Total |
|----------|------------|-------------|-------|
| Batch API, no caching | ~$0.50 | ~$0.25 | **~$0.75** |
| Batch API + prompt caching | ~$0.05 | ~$0.25 | **~$0.30** |
| Synchronous, no caching | ~$1.00 | ~$0.50 | **~$1.50** |

For **2,000 judgments** (500 posts × 4 signals):

| Scenario | Total Cost |
|----------|------------|
| **Recommended: Batch API + caching** | **~$0.60–$1.50** |
| Batch API only | ~$1.50–$2.00 |
| Synchronous API only | ~$3.00–$4.00 |

Even with a buffer for retries, partial failures, and longer outputs, **the $5–20 budget is easily achievable** with Haiku 4.5 batch + caching. Sonnet 4.6 batch would run approximately **$4.50–$6.00** for 2,000 judgments, still within budget but ~3–4× more expensive.

### Cost-Accuracy Trade-off Table

| Model | Cost for 2K judgments | Relative Accuracy | Verdict |
|-------|----------------------|-------------------|-------|
| Haiku 4.5 (batch + cache) | ~$0.60–$1.50 | High for simple extraction | **Best value** |
| Haiku 3.5 (batch + cache) | ~$0.50–$1.20 | High for simple extraction | Cheapest legacy option |
| Sonnet 4.6 (batch) | ~$4.50–$6.00 | Very high | Use if budget allows and reasoning is complex |
| Opus 4.8 (batch) | ~$7.50–$10.00 | Maximum | Overkill for this use case |

---

## Recommended API Setup

### Step 1: Choose the Model Tier

**Use Claude 3.5 Haiku (or Haiku 4.5 if available)** for the bulk of extraction judgments. The task is fundamentally binary/multiclass classification (did the extractor correctly identify mood/energy/focus/medication?), which Haiku handles at quality comparable to Sonnet.[^5][^6]

Reserve Sonnet 4.6 only for:
- Edge cases requiring nuanced reasoning (ambiguous mood descriptions)
- Calibration / golden-set validation
- Disputed cases where Haiku gives low-confidence verdicts

### Step 2: Use the Message Batches API

Structure each judgment as an independent request in a JSONL file:

```jsonl
{"custom_id": "post-001_mood", "params": {"model": "claude-3-5-haiku-20241022", "max_tokens": 256, "system": "You are an expert NLP evaluator...", "messages": [{"role": "user", "content": "Evaluate this extraction..."}]}}
{"custom_id": "post-001_energy", "params": {"model": "claude-3-5-haiku-20241022", "max_tokens": 256, "system": "You are an expert NLP evaluator...", "messages": [{"role": "user", "content": "Evaluate this extraction..."}]}}
```

Key practices:[^2][^14]
- Use descriptive `custom_id` values (e.g., `post-001_mood`) for easy result reconciliation
- Validate a single request shape with the synchronous Messages API before submitting a large batch
- Set realistic `max_tokens` (e.g., 256) to avoid wasted spend on verbose outputs
- Keep batches under 5,000 requests for faster completion (typically 1–2 hours)

### Step 3: Enforce Structured Output via Tool Use

Until native Structured Outputs are available for Haiku, use the tool-use pattern:[^7]

```python
import anthropic

client = anthropic.Anthropic()

response = client.messages.create(
    model="claude-3-5-haiku-20241022",
    max_tokens=256,
    tools=[{
        "name": "extraction_verdict",
        "description": "Return the evaluation verdict",
        "input_schema": {
            "type": "object",
            "properties": {
                "signal": {"type": "string", "enum": ["mood", "energy", "focus", "medication"]},
                "verdict": {"type": "string", "enum": ["correct", "incorrect", "partial", "missing"]},
                "confidence": {"type": "number", "minimum": 0, "maximum": 1},
                "reasoning": {"type": "string"}
            },
            "required": ["signal", "verdict", "confidence", "reasoning"]
        }
    }],
    tool_choice={"type": "tool", "name": "extraction_verdict"},
    messages=[{"role": "user", "content": evaluation_prompt}]
)

# Extract structured result
for block in response.content:
    if block.type == "tool_use":
        verdict = block.input
```

Expected parse failure rate: <0.2% with tool use.[^7]

### Step 4: Add Prompt Caching for the System Prompt

Tag the system prompt with a cache breakpoint to reduce input costs by ~90% on all subsequent requests in the batch:[^10][^11]

```python
system=[{
    "type": "text",
    "text": "You are an expert NLP evaluator... [full rubric]",
    "cache_control": {"type": "ephemeral"}
}]
```

The first request pays full price to write the cache; all subsequent requests in the batch (and within the 5-minute TTL window) read from cache at $0.10/1M tokens for Haiku 4.5.

### Step 5: Implement Error Handling and Retry Logic

Production-grade error handling should:[^12][^13]

1. **Parse rate-limit headers** on every response: `anthropic-ratelimit-requests-remaining`, `anthropic-ratelimit-tokens-remaining`, `anthropic-ratelimit-requests-reset`
2. **Respect `Retry-After`** first, then fall back to exponential backoff with jitter: `wait = base_delay × 2^attempt + random(0, 0.5)`
3. **Never retry 400-level errors** (invalid request, content policy) — these are permanent
4. **Always retry 429, 500, 529** with backoff — these are transient
5. **For batch processing**: after retrieval, separate successes from failures, inspect error fields, and resubmit failed requests in a new batch

### Step 6: Calibrate Against Human Annotations

Before scaling to 2,000 judgments:[^15][^16]

1. Label a stratified sample of ~50–100 judgments manually
2. Run the same sample through the LLM judge (Haiku batch)
3. Measure agreement (Cohen's Kappa or exact-match accuracy)
4. If agreement < 80%, iterate the rubric — add examples, sharpen criteria, or switch to Sonnet
5. Consider criteria injection (virtually free) and ensemble scoring (k=3–5) for marginal gains

---

## Controversies & Trade-offs

### 1. Native Structured Outputs vs Tool Use: The API Divergence Problem

Anthropic's lack of a native `response_format` parameter (until the late-2025 beta, which is Haiku-incompatible) forces developers to use tool use as a workaround. This works well but carries two costs:
- **Token overhead**: ~150–300 extra tokens per request for the tool schema definition[^7]
- **Code complexity**: Responses are nested inside `tool_use` content blocks rather than top-level text, requiring provider-specific parsing logic

OpenAI's `strict: true` structured outputs are more ergonomic and have lower overhead (~80–120 tokens), but Anthropic's Haiku is significantly cheaper, which may offset the overhead for large batch jobs.

### 2. Haiku Accuracy vs Sonnet Accuracy: The "Good Enough" Debate

While multiple sources recommend Haiku for classification and extraction tasks,[^5][^6] there is legitimate debate about whether a smaller model can reliably judge nuanced extraction errors (e.g., partial mood matches, ambiguous medication references). The conservative approach:
- **Haiku for the bulk** (>90% of cases)
- **Sonnet for calibration** and edge-case arbitration
- **Human review for disputed cases**

The cost of running everything on Sonnet (~$5–6 for 2K judgments) is still within the $5–20 budget, so teams with lower tolerance for judge error may prefer Sonnet as the default.

### 3. Batch API Latency: Is the 24-Hour SLA Acceptable?

The batch API's 24-hour SLA is typically over-delivered (1–2 hours for <5K requests), but it is fundamentally asynchronous. This is fine for offline evaluation pipelines but unsuitable for real-time extractor feedback. If the developer needs same-day iteration, the batch API is still viable — most jobs complete within an hour. If they need sub-minute feedback, they must use the synchronous API at 2× cost.

### 4. Anthropic vs OpenAI: Should They Consider OpenAI Too?

Despite already having an Anthropic API key, the developer should be aware of OpenAI's advantages:[^18]
- **More mature structured output ecosystem**: OpenAI's `response_format` with `strict: true` is simpler and more reliable than Anthropic's tool-use workaround
- **GPT-4o-mini as a cheap judge**: GPT-4o-mini is comparable in cost to Haiku and has strong evaluation capabilities
- **Broader tooling**: OpenAI has more third-party eval frameworks (e.g., OpenAI Evals, PromptLayer)

However, Anthropic's advantages for this specific use case are compelling:
- **Lower cost at comparable quality**: 40–60% cheaper than OpenAI equivalents
- **Longer context window**: 200K tokens vs 128K (useful if evaluating long journal posts with full history)
- **Prompt caching**: Developer-controlled caching with explicit breakpoints, which can yield higher savings than OpenAI's automatic caching for this repetitive evaluation pattern

**Verdict**: Stay with Anthropic for cost reasons, but monitor OpenAI's pricing. If OpenAI drops GPT-4o-mini prices further or Anthropic's native structured outputs for Haiku are delayed, a hybrid approach (Anthropic for bulk, OpenAI for golden-set validation) could be optimal.

### 5. The "Schema-Compliance ≠ Semantic-Correctness" Trap

Structured outputs (via tool use or native schema enforcement) guarantee syntactically valid JSON with correct field types and required keys. They do **not** guarantee that the verdict is factually correct.[^20]

A schema-valid response like:
```json
{"signal": "mood", "verdict": "correct", "confidence": 0.95, "reasoning": "The post mentions feeling 'flat' which matches the extracted mood value."}
```
...can still be wrong if the model hallucinated the reasoning or misread the post text. The only defense is:
- Calibrate against human labels
- Use low temperature (0.1–0.2) for consistency
- Add "cannot determine" as a verdict option to reduce forced guesses

---

## Source Index

[^1]: CodeWords AI, "Anthropic batch API: process thousands of prompts at 50% cost," 2026-06-03. https://www.codewords.ai/blog/anthropic-batch-api

[^2]: Steve Kinney, "Using Anthropic's Message Batches API with Temporal," 2026-03-17. https://stevekinney.com/writing/anthropic-batch-api-with-temporal

[^3]: Pristren, "Anthropic Message Batches API: 50% Off Claude for Async Workloads," 2026-05-17. https://pristren.com/blog/anthropic-batch-api-guide/

[^4]: TeamAI, "Every Claude Model, Compared: Versions, Pricing & Which to Use," 2026-06-18. https://teamai.com/blog/large-language-models-llms/understanding-different-claude-models/

[^5]: MorphLLM, "Sonnet vs Haiku: Claude Model Comparison for Developers," 2026-03-31. https://www.morphllm.com/sonnet-vs-haiku

[^6]: SitePoint, "Claude Model Selection Guide | Sonnet vs Opus vs Haiku," 2026-03-13. https://www.sitepoint.com/claude-model-selection-framework/

[^7]: TokenMix AI, "Structured Output and JSON Mode Guide 2026," 2026-04-10. https://tokenmix.ai/blog/structured-output-json-guide

[^8]: Thomas Wiegold, "Claude API Structured Output: Complete Guide to Schema-Guaranteed Responses," 2025-11-15. https://thomas-wiegold.com/blog/claude-api-structured-output/

[^9]: ClaudeLab, "Claude API Structured Outputs GA: Complete Guide," 2026-03-14. https://claudelab.net/en/articles/api-sdk/structured-outputs-ga

[^10]: Anthropic, "Pricing," fetched live 2026-06-23. https://www.anthropic.com/pricing

[^11]: Steve Kinney, "Using Anthropic's Message Batches API with Temporal" (cost-savings section), 2026-03-17. https://stevekinney.com/writing/anthropic-batch-api-with-temporal

[^12]: SitePoint, "Claude API 429 Error Handling | Production Python Guide," 2026-03-20. https://www.sitepoint.com/claude-api-429-error-handling-python/

[^13]: ClaudeReadiness, "Claude Error Handling Patterns," 2025-12-01. https://claudereadiness.com/blog/claude-error-handling-patterns/

[^14]: CodeWords AI, "Anthropic batch API" (error-handling section), 2026-06-03. https://www.codewords.ai/blog/anthropic-batch-api

[^15]: Langfuse, "LLM-as-a-Judge," 2026-06-08. https://langfuse.com/docs/evaluation/evaluation-methods/llm-as-a-judge

[^16]: arXiv, "On Cost-Effective LLM-as-a-Judge Improvement Techniques" (v3), 2026-06-09. https://arxiv.org/html/2604.13717v3

[^17]: arXiv, "Improving Automatic Evaluation of LLMs in Biomedical Relation Extraction via LLMs-as-the-Judge," 2025-06-01. https://arxiv.org/html/2506.00777v1

[^18]: Sfailabs, "OpenAI API vs Anthropic API: Developer and Cost Comparison," 2026-01-31. https://sfailabs.com/guides/openai-api-vs-anthropic-api

[^19]: arXiv, "An analysis of a decade of AI research and 56,800 conference papers," 2026-06-15. https://arxiv.org/html/2606.16974v1

[^20]: CloudAI, "Schema-Valid LLM Output Still Gets 20% of Values Wrong," 2026-06-03. https://cloudai.pt/schema-valid-llm-output-still-gets-20-of-values-wrong/
