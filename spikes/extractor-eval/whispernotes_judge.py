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
        sys.exit("Error: anthropic Python SDK not installed. Run: pip install anthropic")

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
            for rec in uncached:
                verdicts.append({
                    "id": rec.get("id"), "mood": {"verdict": "na", "reason": f"API error: {e}"},
                    "energy": {"verdict": "na", "reason": ""}, "focus": {"verdict": "na", "reason": ""},
                    "meds": {"verdict": "na", "reason": ""}, "overall": "poor", "note": "API failure"
                })
            continue

        # Parse JSON response
        try:
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

        # Rate limiting
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
                print(f"  {rec.get('id', 'unknown')[:8]}: compare v1 vs v2")
        print(f"Consistency check: {consistent}/{validate_n} matched (target: ≥95%)")


if __name__ == "__main__":
    main()
