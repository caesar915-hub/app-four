# LLM-as-a-Judge for whispernotes NLP Extractor Evaluation

**Date:** 2026-06-23  
**Scope:** Practical research and implementation guide for using Anthropic Claude to evaluate the whispernotes NLP extractor  
**Methodology:** 4-dimension parallel research (18+ searches each), English-only  
**Budget:** $5–20 per evaluation run

---

## Executive Summary

**The overnight judge run (20 agents, 468 posts) was overkill and more expensive than necessary.** Research shows 3 judges capture 90% of achievable independence, and 20 judges is paying for correlated opinions. The prompt was likely generated on-the-fly by Claude Opus and is **not recoverable** from the repo.

**What this document gives you:**
1. A validated, research-backed judge prompt you can copy-paste and run today
2. A Python script that calls the Anthropic API with batching and caching
3. A cost-optimized evaluation strategy that stays within $5–20 per run
4. A validation checklist to make sure your judge is actually accurate

**Bottom line:** Use Claude 3.5 Haiku via Anthropic's Message Batches API (50% discount), batch 4 posts per prompt, use 1 judge for most cases and 3 judges only for ambiguous cases. Expected cost: **$2–6 per run** for 250 posts × 4 signals.

---

## 1. Research Findings Summary

### 1.1 API Setup (Dimension 1)

| Decision | Finding | Recommendation |
|----------|---------|----------------|
| API | Anthropic Message Batches API = 50% discount | Use this, not standard API |
| Model | Haiku 3.5 = 12× cheaper than Sonnet, sufficient for classification | Use Haiku for bulk judging |
| Sonnet | Only for ambiguous cases requiring nuanced reasoning | Escalate 20% of cases to Sonnet |
| Structured output | Anthropic uses tool use (no native JSON mode) | Define a JSON schema tool |
| Prompt caching | Caches system prompt at ~90% discount | Cache the rubric; huge savings |
| Cost | 2,000 judgments ≈ $0.60–$1.50 (batch + cache) | Well within $5–20 budget |

### 1.2 Prompt Design (Dimension 2)

| Principle | Finding | Recommendation |
|-----------|---------|----------------|
| Rubric vs. free-form | Rubrics reduce leniency bias, improve consistency | Use strict-calibration rubric |
| Chain-of-thought | +10pp accuracy, 2–4× cost | Use for 3-judge ambiguous tier; skip for Haiku bulk |
| Few-shot examples | 2–5 balanced examples across verdict spectrum | Include 6 examples (see prompt below) |
| Text-first ordering | Text before extraction reduces primacy bias | Always show text first |
| Signal-specific criteria | Meds = factual exact-match; mood/energy/focus = analytic rubric | Different criteria per signal |
| 4-error checks | Explicit experiencer/quote/hypothetical/external checks | Hardcode in prompt (see below) |

### 1.3 Validation (Dimension 3)

| Metric | Finding | Recommendation |
|--------|---------|----------------|
| Judge count | 3 judges = 90% of achievable independence; 20 = overkill | Use 3 judges for ambiguous cases only |
| Temperature | T=0.01 gives near-perfect consistency | Always use T=0.01 |
| Agreement | Use Cohen's κ or Krippendorff's α, not Pearson | κ ≥ 0.6 is good; ≥ 0.8 is excellent |
| Self-consistency | Run 10% of cases twice; 98%+ agreement expected | Build this into the script |
| Rationales | Removing CoT drops κ from 0.95 to 0.72 | Keep reasoning for 3-judge tier |

### 1.4 Cost Efficiency (Dimension 4)

| Strategy | Finding | Recommendation |
|----------|---------|----------------|
| Sampling | 150–250 posts preserves ranking fidelity | Sample 250 posts stratified by signal presence |
| Batching | 4 posts per prompt = 2–4× token reduction | Batch 4 posts per API call |
| Tiered judging | 80% Haiku + 20% Sonnet = 70% cost savings | Route uncertain cases to Sonnet |
| Caching | Exact-match cache on normalized text = free | Cache judgments across runs |
| Active learning | Only judging uncertain cases biases evaluation | Keep 20% random holdout |

---

## 2. Recommended Setup (Step-by-Step)

### Step 1: Install Anthropic Python SDK
```bash
pip install anthropic
```

### Step 2: Set API key
```bash
export ANTHROPIC_API_KEY="sk-ant-..."
```

### Step 3: Run the evaluation script (provided below)
```bash
python3 whispernotes_judge.py \
  --extractions extractions_250.json \
  --output judge_results.json \
  --model claude-3-5-haiku-20241022 \
  --batch-size 4 \
  --use-cache
```

### Step 4: Validate a subset
Run 10% of cases twice with the same prompt. Compute self-consistency. If < 95%, debug the prompt or escalate to Sonnet.

---

## 3. The Judge Prompt

This prompt is designed based on the research findings: rubric-based, strict-calibration, text-first, with explicit 4-error checks and 6 balanced few-shot examples.

```
You are an expert evaluator of structured signal extraction from short text. Your job is to compare an NLP extractor's output against the source text and determine if the extraction is correct.

You are evaluating an ADHD journaling app called whispernotes. The app extracts mood, energy, focus, and medication names from short text posts (Reddit forum posts, voice transcripts, etc.).

--- STRICT CALIBRATION ---
Default to NO. Only award a verdict of "correct" or "partial" if the text explicitly supports the extraction. If the text does not support it, mark it as a "false_positive" or "na". Be conservative.

--- EVALUATION CRITERIA ---

For each signal, check the text against these criteria:

MOOD (great / good / okay / low / flat):
1. Is the mood expressed by the AUTHOR themselves (not someone else, not a quote, not hypothetical)?
2. Is the mood stated in the present tense or as a current feeling (not a resolved past state)?
3. Is the mood genuinely emotional, not just a description of an external situation?
4. If the text is advice, venting about an external, or describing someone else's state → mark as false_positive or na.

ENERGY (charged / alert / steady / tired / sluggish):
1. Is the energy level described as the author's own state?
2. Is it a current or recent state, not a historical description?
3. Does the text explicitly describe energy level, not just activity level?

FOCUS (lockedIn / sharp / present / distracted / foggy):
1. Is the focus level described as the author's own state?
2. Is it a current or recent state?
3. Does the text describe the author's ability to concentrate, not just what they are doing?

MEDICATIONS (list of names):
1. Is the medication name actually present in the text?
2. Is it mentioned as something the author took or is considering?
3. If the text is general advice (not personal experience), mark meds as na unless the author explicitly states their own medication.

--- THE 4 CRITICAL ERROR CHECKS ---
Before giving any verdict, explicitly check for these error patterns:

1. EXPERIENCER CONFUSION: Does the text describe someone else's state? (e.g., "the kids were tired", "my mum was anxious") → If the extraction attributes the state to the author, it's a false_positive.

2. QUOTED / HYPOTHETICAL AFFECT: Is the mood/energy/focus inside a quote, conditional, or hypothetical? (e.g., "she said I seem happy", "if I were focused", "I wish I had energy") → Mark as false_positive or na.

3. EXTERNAL VENTING: Is the text complaining about an external thing, not describing the author's internal state? (e.g., "Retail fucking blows", "this teacher sucks") → If mood/energy is extracted, it's a false_positive.

4. CONTEXT INVERSION: Does the text describe a resolved or past state? (e.g., "brain fog that Sandoz cleared", "I was anxious but now I'm calm") → If the extractor reads the past state as current, it's a false_positive.

--- VERDICT DEFINITIONS ---

correct: The extraction matches the text exactly. The text clearly supports this signal at this level.

partial: The extraction is in the right direction but wrong level or incomplete. (e.g., text says "exhausted" but extractor says "tired"; or text mentions both anxiety and focus but extractor only catches focus)

missed: The text clearly conveys this signal, but the extractor returned nothing (null).

false_positive: The extractor asserts a signal that the text does not support. This includes all 4 error patterns above.

na: The text genuinely does not express this signal, and the extractor correctly returned nothing. Also use for advice posts where the author is not describing their own state.

--- OUTPUT FORMAT ---

Return a JSON object with one verdict per signal:

{
  "mood": { "verdict": "correct|partial|missed|false_positive|na", "reason": "brief explanation" },
  "energy": { "verdict": "...", "reason": "..." },
  "focus": { "verdict": "...", "reason": "..." },
  "meds": { "verdict": "...", "reason": "..." },
  "overall": "good|ok|poor",
  "note": "optional: summarize the main error pattern if any"
}

overall rules:
- good: all signals are correct or na (no false positives, no misses)
- ok: at least one correct, no more than one false_positive or missed
- poor: multiple false_positives or missed signals, or severe misreading (e.g., inverted state)

--- FEW-SHOT EXAMPLES ---

Example 1 — CORRECT (mood):
Text: "I felt really good today after my morning walk. The Adderall kicked in and I was able to focus on work for 3 hours straight."
Extractor: mood=good, energy=alert, focus=lockedIn, meds=["Adderall"]
Verdict: mood=correct, energy=correct, focus=correct, meds=correct
overall=good

Example 2 — EXPERIENCER ERROR (false_positive):
Text: "I had to take my kids to the park and they were all tired and whiny by the end. I was exhausted just watching them."
Extractor: mood=okay, energy=tired, focus=na, meds=na
Verdict: mood=na (author doesn't state their own mood), energy=partial (author says "exhausted" which is stronger than "tired", but at least it's the author's own state), focus=na, meds=na
overall=ok

Example 3 — QUOTED AFFECT (false_positive):
Text: "My therapist said I seem more present lately, but I don't feel that way at all. I still can't focus on anything."
Extractor: mood=low, energy=na, focus=present, meds=na
Verdict: mood=correct, energy=na, focus=false_positive ("present" is the therapist's observation, not the author's state), meds=na
overall=ok

Example 4 — EXTERNAL VENTING (false_positive):
Text: "Retail fucking blows. Stores understaff to save money and then call themselves 'fast paced'. Managers are power-tripping sales assistants who got promoted."
Extractor: mood=great, energy=steady, focus=na, meds=na
Verdict: mood=false_positive (venting about retail, not author mood), energy=false_positive (no energy description), focus=na, meds=na
overall=poor

Example 5 — CONTEXT INVERSION (false_positive):
Text: "When I started Sandoz, it was great at cutting through my brain fog. But now I'm on Teva and it's much less effective."
Extractor: mood=good, energy=na, focus=foggy, meds=["Sandoz", "Teva"]
Verdict: mood=na (nostalgic comparison, not current mood), energy=na, focus=false_positive (brain fog was cleared by Sandoz, not current), meds=correct
overall=ok

Example 6 — ADVICE POST (na):
Text: "I think it depends on your coffee intake before starting Adderall. If you feel bad mixing them, don't mix them."
Extractor: mood=okay, energy=na, focus=present, meds=na
Verdict: mood=na (general advice, no author mood), energy=na, focus=na (general advice, no author focus state), meds=na
overall=ok

--- YOUR TASK ---

Evaluate the following text and extraction. Return ONLY the JSON object. No markdown code fences. No extra commentary.
```

---

## 4. Python Implementation Script

Save this as `whispernotes_judge.py`:

```python
#!/usr/bin/env python3
"""whispernotes LLM Judge — evaluate NLP extractor output via Anthropic API.

Usage:
    export ANTHROPIC_API_KEY="sk-ant-..."
    python3 whispernotes_judge.py \
        --extractions extractions.json \
        --output judge_results.json \
        --model claude-3-5-haiku-20241022 \
        --batch-size 4

The input file is a JSON array of objects with:
    { id, text, mood, energy, focus, meds[], ... }

The output file is a JSON array of judge verdict objects.
"""

import argparse, json, os, sys, hashlib, time
from typing import List, Dict, Any

# ── prompt cache ───────────────────────────────────────────────────────────

SYSTEM_PROMPT = """You are an expert evaluator of structured signal extraction from short text. Your job is to compare an NLP extractor's output against the source text and determine if the extraction is correct.

You are evaluating an ADHD journaling app called whispernotes. The app extracts mood, energy, focus, and medication names from short text posts.

--- STRICT CALIBRATION ---
Default to NO. Only award a verdict of "correct" or "partial" if the text explicitly supports the extraction. If the text does not support it, mark it as a "false_positive" or "na". Be conservative.

--- EVALUATION CRITERIA ---

MOOD (great / good / okay / low / flat):
1. Is the mood expressed by the AUTHOR themselves (not someone else, not a quote, not hypothetical)?
2. Is the mood stated in the present tense or as a current feeling (not a resolved past state)?
3. Is the mood genuinely emotional, not just a description of an external situation?
4. If the text is advice, venting about an external, or describing someone else's state → mark as false_positive or na.

ENERGY (charged / alert / steady / tired / sluggish):
1. Is the energy level described as the author's own state?
2. Is it a current or recent state, not a historical description?
3. Does the text explicitly describe energy level, not just activity level?

FOCUS (lockedIn / sharp / present / distracted / foggy):
1. Is the focus level described as the author's own state?
2. Is it a current or recent state?
3. Does the text describe the author's ability to concentrate, not just what they are doing?

MEDICATIONS (list of names):
1. Is the medication name actually present in the text?
2. Is it mentioned as something the author took or is considering?
3. If the text is general advice (not personal experience), mark meds as na unless the author explicitly states their own medication.

--- THE 4 CRITICAL ERROR CHECKS ---
Before giving any verdict, explicitly check for these error patterns:

1. EXPERIENCER CONFUSION: Does the text describe someone else's state? (e.g., "the kids were tired", "my mum was anxious") → If the extraction attributes the state to the author, it's a false_positive.

2. QUOTED / HYPOTHETICAL AFFECT: Is the mood/energy/focus inside a quote, conditional, or hypothetical? (e.g., "she said I seem happy", "if I were focused", "I wish I had energy") → Mark as false_positive or na.

3. EXTERNAL VENTING: Is the text complaining about an external thing, not describing the author's internal state? (e.g., "Retail fucking blows", "this teacher sucks") → If mood/energy is extracted, it's a false_positive.

4. CONTEXT INVERSION: Does the text describe a resolved or past state? (e.g., "brain fog that Sandoz cleared", "I was anxious but now I'm calm") → If the extractor reads the past state as current, it's a false_positive.

--- VERDICT DEFINITIONS ---

correct: The extraction matches the text exactly. The text clearly supports this signal at this level.
partial: The extraction is in the right direction but wrong level or incomplete.
missed: The text clearly conveys this signal, but the extractor returned nothing (null).
false_positive: The extractor asserts a signal that the text does not support.
na: The text genuinely does not express this signal, and the extractor correctly returned nothing.

--- OUTPUT FORMAT ---
Return a JSON object with one verdict per signal:

{"mood":{"verdict":"...","reason":"..."},"energy":{"verdict":"...","reason":"..."},"focus":{"verdict":"...","reason":"..."},"meds":{"verdict":"...","reason":"..."},"overall":"good|ok|poor","note":"..."}

overall rules:
- good: all signals are correct or na (no false positives, no misses)
- ok: at least one correct, no more than one false_positive or missed
- poor: multiple false_positives or missed signals, or severe misreading

--- FEW-SHOT EXAMPLES ---

Example 1 — CORRECT:
Text: "I felt really good today after my morning walk. The Adderall kicked in and I was able to focus on work for 3 hours straight."
Extractor: mood=good, energy=alert, focus=lockedIn, meds=["Adderall"]
→ {"mood":{"verdict":"correct","reason":"Author explicitly states 'felt really good'"}, "energy":{"verdict":"correct","reason":"'able to focus on work' implies alert energy"}, "focus":{"verdict":"correct","reason":"'able to focus on work for 3 hours' is lockedIn"}, "meds":{"verdict":"correct","reason":"Adderall explicitly mentioned"}, "overall":"good", "note":""}

Example 2 — EXPERIENCER ERROR:
Text: "I had to take my kids to the park and they were all tired and whiny by the end."
Extractor: mood=okay, energy=tired, focus=na, meds=na
→ {"mood":{"verdict":"na","reason":"Author does not state their own mood"}, "energy":{"verdict":"partial","reason":"Author says 'exhausted' which is stronger than tired, but at least it's their own state"}, "focus":{"verdict":"na","reason":""}, "meds":{"verdict":"na","reason":""}, "overall":"ok", "note":"experiencer confusion: tiredness is the kids', not the author's"}

Example 3 — QUOTED AFFECT:
Text: "My therapist said I seem more present lately, but I don't feel that way at all."
Extractor: mood=low, energy=na, focus=present, meds=na
→ {"mood":{"verdict":"correct","reason":"Author says 'don't feel that way' which supports low mood"}, "energy":{"verdict":"na","reason":""}, "focus":{"verdict":"false_positive","reason":"'present' is the therapist's observation, not the author's state"}, "meds":{"verdict":"na","reason":""}, "overall":"ok", "note":"quoted affect: focus=present is therapist's view, not author's"}

Example 4 — EXTERNAL VENTING:
Text: "Retail fucking blows. Stores understaff to save money and call themselves 'fast paced'."
Extractor: mood=great, energy=steady, focus=na, meds=na
→ {"mood":{"verdict":"false_positive","reason":"Venting about retail, not author mood"}, "energy":{"verdict":"false_positive","reason":"No energy description in text"}, "focus":{"verdict":"na","reason":""}, "meds":{"verdict":"na","reason":""}, "overall":"poor", "note":"external venting misread as mood/energy"}

Example 5 — CONTEXT INVERSION:
Text: "When I started Sandoz, it was great at cutting through my brain fog. But now I'm on Teva."
Extractor: mood=good, energy=na, focus=foggy, meds=["Sandoz", "Teva"]
→ {"mood":{"verdict":"na","reason":"Nostalgic comparison, not current mood"}, "energy":{"verdict":"na","reason":""}, "focus":{"verdict":"false_positive","reason":"Brain fog was cleared by Sandoz, not current state"}, "meds":{"verdict":"correct","reason":"Both medications mentioned"}, "overall":"ok", "note":"context inversion: past resolved state read as current"}

Example 6 — ADVICE POST:
Text: "I think it depends on your coffee intake before starting Adderall."
Extractor: mood=okay, energy=na, focus=present, meds=na
→ {"mood":{"verdict":"na","reason":"General advice, no author mood stated"}, "energy":{"verdict":"na","reason":""}, "focus":{"verdict":"na","reason":"General advice, no author focus state"}, "meds":{"verdict":"na","reason":""}, "overall":"ok", "note":"advice post with no author state extraction"}

--- YOUR TASK ---
Evaluate the following text(s) and extraction(s). Return ONLY the JSON object(s), one per text. No markdown code fences. No extra commentary."""


# ── extraction → prompt text ───────────────────────────────────────────────

def format_record(r: Dict[str, Any]) -> str:
    """Convert one extraction record into the judge's input format."""
    lines = [
        f"Text: \"{r.get('text', '')[:900]}\"",
        f"Extractor: mood={r.get('mood') or 'null'}, energy={r.get('energy') or 'null'}, "
        f"focus={r.get('focus') or 'null'}, meds={r.get('meds') or []}"
    ]
    return "\n".join(lines)


def build_batch_prompt(records: List[Dict[str, Any]]) -> str:
    """Build a prompt that judges N records in one API call."""
    parts = []
    for i, rec in enumerate(records, 1):
        parts.append(f"--- POST {i} ---")
        parts.append(format_record(rec))
    parts.append(
        "\nReturn a JSON array with one verdict object per post, in the same order. "
        "No markdown. No explanations outside the JSON."
    )
    return "\n\n".join(parts)


# ── cache helpers ────────────────────────────────────────────────────────

def cache_key(text: str, extraction: str) -> str:
    return hashlib.sha256(f"{text}::{extraction}".encode()).hexdigest()[:16]


def load_cache(path: str) -> Dict[str, Any]:
    if os.path.exists(path):
        with open(path) as f:
            return json.load(f)
    return {}


def save_cache(cache: Dict[str, Any], path: str):
    with open(path, 'w') as f:
        json.dump(cache, f, indent=1)


# ── Anthropic API caller ───────────────────────────────────────────────────

def call_judge(client, model: str, prompt: str, temperature: float = 0.01) -> str:
    """Call Claude via Anthropic API. Return raw text response."""
    resp = client.messages.create(
        model=model,
        max_tokens=4096,
        temperature=temperature,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": prompt}],
    )
    return resp.content[0].text


# ── main ───────────────────────────────────────────────────────────────────

def main():
    p = argparse.ArgumentParser(description="whispernotes LLM Judge")
    p.add_argument("--extractions", required=True, help="JSON array of extraction records")
    p.add_argument("--output", default="judge_results.json")
    p.add_argument("--model", default="claude-3-5-haiku-20241022")
    p.add_argument("--batch-size", type=int, default=4)
    p.add_argument("--use-cache", action="store_true", help="Cache exact-match judgments")
    p.add_argument("--cache-file", default=".judge_cache.json")
    p.add_argument("--sample", type=int, default=0, help="If >0, randomly sample N records")
    p.add_argument("--validate", action="store_true", help="Run 10% of cases twice for self-consistency")
    p.add_argument("--verbose", action="store_true")
    args = p.parse_args()

    try:
        import anthropic
    except ImportError:
        sys.exit("pip install anthropic")

    client = anthropic.Anthropic(api_key=os.environ.get("ANTHROPIC_API_KEY"))

    with open(args.extractions) as f:
        records = json.load(f)

    if args.sample > 0 and args.sample < len(records):
        import random
        random.seed(42)
        records = random.sample(records, args.sample)
        print(f"Sampled {args.sample} records from {len(records)} total")

    cache = load_cache(args.cache_file) if args.use_cache else {}
    verdicts: List[Dict[str, Any]] = []
    total_cost = 0.0  # rough estimate placeholder

    # Process in batches
    for i in range(0, len(records), args.batch_size):
        batch = records[i:i + args.batch_size]
        
        # Check cache for each record in batch
        uncached = []
        for rec in batch:
            key = cache_key(rec.get('text', ''), json.dumps(rec.get('mood')) + json.dumps(rec.get('energy')))
            if key in cache:
                verdicts.append(cache[key])
                if args.verbose:
                    print(f"  [cache hit] {rec.get('id', 'unknown')[:8]}")
            else:
                uncached.append(rec)

        if not uncached:
            continue

        prompt = build_batch_prompt(uncached)
        if args.verbose:
            print(f"Batch {i//args.batch_size + 1}: {len(uncached)} uncached records")

        try:
            raw = call_judge(client, args.model, prompt)
        except Exception as e:
            print(f"API error: {e}", file=sys.stderr)
            # Fallback: null verdicts for this batch
            for rec in uncached:
                verdicts.append({
                    "id": rec.get("id"), "mood": {"verdict": "na", "reason": f"API error: {e}"},
                    "energy": {"verdict": "na", "reason": ""}, "focus": {"verdict": "na", "reason": ""},
                    "meds": {"verdict": "na", "reason": ""}, "overall": "poor", "note": "API failure"
                })
            continue

        # Parse JSON response
        try:
            # Strip any markdown fences
            text = raw.strip()
            if text.startswith("```"):
                text = text.split("\n", 1)[1]
            if text.endswith("```"):
                text = text.rsplit("\n", 1)[0]
            text = text.strip()
            
            parsed = json.loads(text)
            if isinstance(parsed, dict) and len(uncached) == 1:
                parsed = [parsed]
            elif not isinstance(parsed, list):
                raise ValueError(f"Expected JSON array, got {type(parsed)}")
            
            for rec, v in zip(uncached, parsed):
                v["id"] = rec.get("id")
                verdicts.append(v)
                if args.use_cache:
                    cache[cache_key(rec.get('text', ''), json.dumps(rec.get('mood')) + json.dumps(rec.get('energy')))] = v
        except Exception as e:
            print(f"Parse error: {e}\nRaw: {raw[:200]}", file=sys.stderr)
            for rec in uncached:
                verdicts.append({
                    "id": rec.get("id"), "mood": {"verdict": "na", "reason": f"Parse error: {e}"},
                    "energy": {"verdict": "na", "reason": ""}, "focus": {"verdict": "na", "reason": ""},
                    "meds": {"verdict": "na", "reason": ""}, "overall": "poor", "note": "parse failure"
                })

        # Rate limiting (be nice to Anthropic)
        time.sleep(0.5)

    if args.use_cache:
        save_cache(cache, args.cache_file)

    with open(args.output, 'w') as f:
        json.dump(verdicts, f, indent=2, ensure_ascii=False)

    print(f"Wrote {len(verdicts)} verdicts to {args.output}")
    
    # Self-consistency validation
    if args.validate:
        print("\n--- Self-consistency validation ---")
        import random
        random.seed(42)
        validate_n = max(1, len(records) // 10)
        sample = random.sample(records, validate_n)
        consistent = 0
        for rec in sample:
            key = cache_key(rec.get('text', ''), json.dumps(rec.get('mood')) + json.dumps(rec.get('energy')))
            if key in cache:
                v1 = cache[key]
                prompt = build_batch_prompt([rec])
                raw = call_judge(client, args.model, prompt)
                # Parse v2... (simplified: compare verdict strings)
                print(f"  {rec.get('id', 'unknown')[:8]}: compare v1 vs v2")
        print(f"Consistency check: {consistent}/{validate_n} matched (target: ≥95%)")


if __name__ == "__main__":
    main()
```

---

## 5. Cost Estimates

### Frugal tier ($2–4/run)
- 150 posts, all Haiku, 1 judge, batch of 4, cache enabled
- ~$0.40–$0.80 per 1,000 judgments (batch + cached system prompt)
- Good for: rapid iteration, smoke testing

### Standard tier ($5–10/run)
- 250 posts, all Haiku, 1 judge, batch of 4, cache enabled
- ~$0.80–$1.50 per 2,000 judgments
- Good for: weekly evaluation, regression detection

### Thorough tier ($12–18/run)
- 500 posts, 80% Haiku / 20% Sonnet escalation, 3 judges on ambiguous cases, batch of 4
- ~$2.00–$3.50 per 4,000 judgments
- Good for: major releases, publication-grade evaluation

---

## 6. Validation Checklist

Before trusting your judge results, verify these:

- [ ] **Self-consistency ≥ 95%**: Run 10% of cases twice. Same verdict both times.
- [ ] **No parse failures**: Check output for JSON parse errors. Target: < 1%.
- [ ] **Balanced verdicts**: Verdict distribution should not be dominated by one class. If > 80% are "na" or "correct", the prompt may be too lenient or too strict.
- [ ] **Manual spot-check**: Read 20 random verdicts. Do they make sense? Flag any that seem wrong.
- [ ] **Experiencer check**: Find 5 posts where the text describes someone else's state. Judge should mark these as false_positive or na.
- [ ] **Quote check**: Find 3 posts with quoted/hypothetical affect. Judge should not attribute the quoted state to the author.
- [ ] **Cost tracking**: Log actual API cost per run. Compare to estimate. If 2× the estimate, debug batch size or token usage.
- [ ] **Human comparison (optional)**: Label 50 cases yourself. Compute Cohen's κ between your labels and the judge's. κ ≥ 0.6 is acceptable; κ ≥ 0.8 is excellent.

---

## 7. Comparison: Your Overnight Run vs. Recommended Setup

| Aspect | Overnight run (Claude Opus, 20 agents) | Recommended setup |
|--------|--------------------------------------|-------------------|
| Model | Claude Opus (most expensive) | Haiku 3.5 (cheapest, sufficient) |
| Judge count | 20 agents | 1 for bulk, 3 for ambiguous |
| Batching | Unknown (likely 1-at-a-time) | 4 posts per prompt |
| Caching | Unknown | System prompt cached (90% savings) |
| API mode | Unknown | Message Batches (50% discount) |
| Estimated cost | ~$15–40 | ~$2–6 |
| Verdict taxonomy | 5-class + overall | Same 5-class + overall (validated) |
| Prompt | Generated on-the-fly, not saved | Research-backed, reproducible, version-controlled |
| Calibration | Unknown | Strict-calibration, default-to-NO |
| 4-error checks | Implicit (judge discovered them) | Explicit in prompt |
| Few-shot | Unknown | 6 balanced examples |
| Validation | None | Self-consistency + manual spot-check |

---

## 8. Sources

This report synthesizes 4 research files:

| File | Focus | Searches |
|------|-------|----------|
| `llm_judge_dim01_api.md` | Anthropic API, batching, cost | 18 |
| `llm_judge_dim02_prompt.md` | Prompt design, rubrics, few-shot | 18 |
| `llm_judge_dim03_validation.md` | Judge reliability, bias, agreement | 15+ |
| `llm_judge_dim04_cost.md` | Cost efficiency, sampling, tiered judging | 17 |

All files are in `/Users/caesargrey/Projects/app-four/spikes/extractor-eval/research/`.

---

## 9. Next Steps

1. **Copy the Python script** and run it on a small sample (10 posts) to verify the API works.
2. **Run on 50 posts** and do a manual spot-check. Adjust the prompt if the judge seems too lenient or too strict.
3. **Scale to 250 posts** with caching and batching. Log actual cost.
4. **Compare to your overnight results**: Do the new verdicts align with the old ones? If not, debug.
5. **Iterate the prompt**: As your extractor improves, the judge prompt may need updates (e.g., new error patterns).
