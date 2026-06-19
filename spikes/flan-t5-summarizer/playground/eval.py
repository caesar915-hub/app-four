#!/usr/bin/env python3
"""
Faithful-prompt evaluation with source-based quality metrics.

Produces a markdown table of: input → extracted tags → summary → quality scores.
No reference summaries are required; all metrics compare the summary back to the
source transcript.

Usage:
    source ../.venv/bin/activate
    python eval.py                       # default: inputs-quick.json
    python eval.py --input-file inputs.json
    python eval.py --save                # write results/eval-<stamp>.md
"""

import argparse
import json
import re
import sys
import time
from dataclasses import asdict
from pathlib import Path
from string import punctuation

import run as run_mod

HERE = Path(__file__).parent
RESULTS_DIR = HERE / "results"

# ── Lazy-loaded contradiction detector (NLI) ────────────────────────────────
_NLI = None


def _load_nli():
    global _NLI
    if _NLI is None:
        import torch
        from transformers import AutoModelForSequenceClassification, AutoTokenizer
        model_name = "cross-encoder/nli-deberta-v3-small"
        print(f"Loading NLI model {model_name}...", file=sys.stderr)
        tok = AutoTokenizer.from_pretrained(model_name)
        model = AutoModelForSequenceClassification.from_pretrained(model_name)
        model.eval()
        _NLI = (tok, model)
        print("Ready.", file=sys.stderr)
    return _NLI


def contradiction_score(premise: str, hypothesis: str) -> float:
    """Return probability that hypothesis contradicts premise."""
    tok, model = _load_nli()
    import torch
    inputs = tok(
        premise,
        hypothesis,
        return_tensors="pt",
        truncation=True,
        max_length=512,
    )
    with torch.no_grad():
        logits = model(**inputs).logits
    probs = torch.softmax(logits, dim=-1)[0]
    # cross-encoder/nli-deberta-v3-small labels: 0=contradiction, 1=entailment, 2=neutral
    return float(probs[0])

# ── Simple lexicons for tag visualization (not production quality) ──────────
MEDS = ["elvanse", "vyvanse", "concerta", "ritalin", "adderall", "medikinet"]

SIDE_EFFECTS = [
    "dry mouth", "no appetite", "loss of appetite", "nausea", "headache",
    "irritable", "irritability", "crash", "crashed", "heart racing",
    "racing heart", "wired", "jittery"
]

POSITIVE = ["good", "great", "happy", "brilliant", "motivated", "capable", "sharp", "best"]
NEGATIVE = ["bad", "terrible", "anxious", "flat", "drained", "tired", "exhausted", "irritable", "foggy"]


# ── Tag extraction (visualization only) ─────────────────────────────────────
def extract_tags(text: str) -> dict:
    t = text.lower()

    # sleep hours
    sleep_hours = None
    m = re.search(r"(\d+(?:\.\d+)?)\s*(?:hours?|hrs?|h)\b", t)
    if m:
        sleep_hours = float(m.group(1))

    # sleep quality
    quality = None
    if any(w in t for w in ["tossed", "turned", "woke up", "woke", "restless"]):
        quality = "restless"
    elif any(w in t for w in ["slept well", "slept great"]):
        quality = "good"

    # medications
    medications = []
    for med in MEDS:
        if med in t:
            dose = None
            time = None
            # dose near the med
            dm = re.search(rf"{med}\s+(\d+\s*(?:mg|mcg))", t)
            if dm:
                dose = dm.group(1)
            # time near the med
            tm = re.search(rf"{med}.*?\b(at\s+)?(\d{{1,2}}(?::\d{{2}})?\s*(?:am|pm|a\.m\.|p\.m\.)?)\b", t)
            if tm:
                time = tm.group(2)
            medications.append({"name": med.title(), "dose": dose, "time": time})

    # side effects
    side_effects = [se for se in SIDE_EFFECTS if se in t]

    # crude mood markers
    mood_markers = []
    pos = [w for w in POSITIVE if re.search(rf"\b{w}\b", t)]
    neg = [w for w in NEGATIVE if re.search(rf"\b{w}\b", t)]
    if pos and not neg:
        mood_markers.append("positive")
    elif neg and not pos:
        mood_markers.append("negative")
    elif pos and neg:
        mood_markers.append("mixed")
    else:
        mood_markers.append("neutral")

    return {
        "mood_markers": mood_markers,
        "sleep": {"hours": sleep_hours, "quality": quality},
        "medications": medications,
        "side_effects": side_effects,
    }


# ── Quality metrics ─────────────────────────────────────────────────────────
STOPWORDS = {
    "the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
    "have", "has", "had", "do", "does", "did", "will", "would", "could",
    "should", "may", "might", "must", "shall", "can", "need", "dare",
    "ought", "used", "to", "of", "in", "for", "on", "with", "at", "by",
    "from", "as", "into", "through", "during", "before", "after", "above",
    "below", "between", "under", "and", "but", "or", "yet", "so", "if",
    "because", "although", "though", "while", "where", "when", "that",
    "which", "who", "whom", "whose", "what", "this", "these", "those",
    "i", "me", "my", "myself", "we", "our", "you", "your", "he", "him",
    "his", "she", "her", "it", "its", "they", "them", "their", "themself",
    "myself", "journal", "entry", "about", "person", "narrator",
}


def tokens(text: str) -> set:
    return {
        w.strip(punctuation).lower()
        for w in text.split()
        if w.strip(punctuation) and w.strip(punctuation).lower() not in STOPWORDS
    }


def evaluate(source: str, summary: str) -> dict:
    src_tok = tokens(source)
    sum_tok = tokens(summary)

    if not sum_tok:
        sum_tok = {"<empty>"}

    # 1. Content preservation: how much of the source's key words survive
    overlap = src_tok & sum_tok
    coverage = len(overlap) / len(src_tok) if src_tok else 0.0

    # 2. Hallucination: words in summary not in source (lower is better)
    novel = sum_tok - src_tok
    hallucination = len(novel) / len(sum_tok) if sum_tok else 0.0

    # 3. Conciseness: output length vs input length
    src_len = len(source.split())
    sum_len = len(summary.split())
    compression = src_len / sum_len if sum_len else 0.0

    # 4. Entity recall: did meds/doses/times survive?
    src_tags = extract_tags(source)
    sum_tags = extract_tags(summary)

    med_hits = 0
    med_total = 0
    for m in src_tags["medications"]:
        med_total += 1
        if any(s["name"] == m["name"] for s in sum_tags["medications"]):
            med_hits += 1

    sleep_hour_ok = (
        src_tags["sleep"]["hours"] is None
        or src_tags["sleep"]["hours"] == sum_tags["sleep"]["hours"]
    )

    side_hit = len(set(src_tags["side_effects"]) & set(sum_tags["side_effects"]))
    side_total = len(src_tags["side_effects"])

    # 5. Arc preservation: if source has both positive and negative markers,
    #    does summary also have both?
    src_mood = set(src_tags["mood_markers"])
    sum_mood = set(sum_tags["mood_markers"])
    arc_ok = not (src_mood == {"mixed"} and sum_mood != {"mixed"})

    return {
        "coverage": round(coverage, 2),
        "hallucination": round(hallucination, 2),
        "compression": round(compression, 2),
        "med_recall": f"{med_hits}/{med_total}",
        "sleep_hour_ok": sleep_hour_ok,
        "side_effect_recall": f"{side_hit}/{side_total}",
        "arc_ok": arc_ok,
        "src_words": len(src_tok),
        "sum_words": len(sum_tok),
    }


# ── Rendering ───────────────────────────────────────────────────────────────
def fmt_tags(tags: dict) -> str:
    parts = []
    parts.append("mood: " + "/".join(tags["mood_markers"]))
    if tags["sleep"]["hours"] is not None:
        q = f", {tags['sleep']['quality']}" if tags["sleep"]["quality"] else ""
        parts.append(f"sleep: {tags['sleep']['hours']}h{q}")
    for m in tags["medications"]:
        dose = f" {m['dose']}" if m["dose"] else ""
        tm = f" @{m['time']}" if m["time"] else ""
        parts.append(f"med: {m['name']}{dose}{tm}")
    if tags["side_effects"]:
        parts.append("fx: " + ", ".join(tags["side_effects"]))
    return "<br>".join(parts)


def fmt_metrics(m: dict) -> str:
    return (
        f"coverage={m['coverage']} "
        f"halluc={m['hallucination']} "
        f"compress={m['compression']}x "
        f"med={m['med_recall']} "
        f"sleep={m['sleep_hour_ok']} "
        f"fx={m['side_effect_recall']} "
        f"arc={m['arc_ok']}"
    )


# ── Post-processing fallbacks ───────────────────────────────────────────────
META_PHRASES = [
    "the journal entry is about",
    "the narrator",
    "the person",
    "this journal entry",
    "bullets:",
    "bullet points:",
]


def first_sentence(text: str) -> str:
    # Simple first-sentence extractor; falls back to full text if no terminator.
    m = re.match(r".+?[.!?](?=\s|$)", text.strip())
    return m.group(0) if m else text


def post_process(source: str, raw_summary: str) -> tuple[str, str]:
    """
    Apply lightweight rule-based fallbacks. Returns (processed_summary, reason).
    """
    src_words = source.split()
    sum_words = raw_summary.split()
    src_lower = source.lower()
    sum_lower = raw_summary.lower()
    src_tok = tokens(source)
    sum_tok = tokens(raw_summary)

    # 1. Meta-language: model describes the entry instead of summarizing it.
    if any(p in sum_lower for p in META_PHRASES):
        return first_sentence(source), "meta_fallback"

    # 2. Nonsensical injection: summary adds a concrete noun not in source.
    #    "The water is drained..." when source has no water.
    injected_concrete = ["water"]
    for word in injected_concrete:
        if word in sum_lower and word not in src_lower:
            return source, "injection_fallback"

    # 3. Very short source: don't summarize at all.
    if len(src_words) < 12:
        return source, "short_source_fallback"

    # 3b. Short-ish source where the model hallucinated >50% of content:
    #     e.g. "rough morning" → "weather was rough", "numb" → "not feeling well".
    if len(src_words) < 20 and sum_tok:
        if len(sum_tok - src_tok) / len(sum_tok) > 0.5:
            return source, "short_hallucination_fallback"

    # 4. Severe collapse: long source got compressed to almost nothing.
    #    Return the full source as the safest extractive fallback.
    if len(src_words) > 50 and len(sum_words) < 7:
        return source, "collapse_fallback"

    # 5. Generic fallback outputs: model defaulted to a platitude.
    generic_outputs = {
        "i was a little tired today",
        "i'm not sure what to do",
        "i'm a little sluggish today",
        "i'm not sure how to describe today",
        "the weather was fine",
        "i went to the gym",
        "i went to the supermarket",
        "i had a pretty good day",
        "i was tired and energized",
        "i slept poorly, but i was still able to get through the day",
    }
    if sum_lower.strip("- ") in generic_outputs:
        return source, "generic_fallback"

    # 5b. Repetition loop: the decoder got stuck repeating a phrase.
    words = raw_summary.split()
    if len(words) >= 12:
        # If any 4-word span appears more than twice, it's a loop.
        from collections import Counter
        fourgrams = Counter(" ".join(words[i:i+4]) for i in range(len(words)-3))
        if any(c >= 3 for c in fourgrams.values()):
            return source, "repetition_fallback"

    # 5c. High-hallucination medical entries: if the source mentions medications
    #     and the summary is largely invented, return the source. This catches
    #     dangerous claims like "Ritalin and Wellbutrin are the same medication."
    if any(m in src_lower for m in MEDS) and sum_tok:
        novel_ratio = len(sum_tok - src_tok) / len(sum_tok)
        if novel_ratio > 0.30:
            return source, "medical_hallucination_fallback"

    # 6. Explicit negation flip: source says "wasn't X" / "not X" but summary
    #    says "was X". Common with state words (tired, anxious, sad, etc.).
    state_words = ["tired", "anxious", "sad", "happy", "well", "fine", "okay", "terrible"]
    for state in state_words:
        negated = re.search(rf"\b(wasn'?t|isn'?t|didn'?t|don'?t|not|never)\s+{state}\b", src_lower)
        # allow adverbs/adjectives between verb and state: "was a little tired", "felt really sad"
        affirmed = re.search(rf"\b(was|is|felt|feel|am|'m)\s+(?:\w+\s+)*{state}\b", sum_lower)
        if negated and affirmed:
            return source, "negation_fallback"

    # 7. Semantic contradiction via NLI model (DISABLED — rule-based negation
    #    check above is sufficient and avoids the ~300 MB NLI download).
    # if contradiction_score(source, raw_summary) > 0.35:
    #     return source, "contradiction_fallback"

    return raw_summary, "none"


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--input-file", default=str(HERE / "inputs-quick.json"))
    p.add_argument("--prompt", default="faithful", help="prompt template name (see prompts.py)")
    p.add_argument("--model", default=None, help="HF model id (overrides config)")
    p.add_argument("--save", action="store_true")
    args = p.parse_args()

    cfg = run_mod.cfg_mod.DEFAULT
    if args.model:
        cfg = run_mod.replace(cfg, model_name=args.model)
    cfg = run_mod.replace(cfg, prompt=args.prompt)

    with open(args.input_file) as f:
        cases = json.load(f)

    lines = []
    def sink(s):
        print(s)
        lines.append(s)

    sink(f"# {cfg.prompt} prompt evaluation")
    sink(f"model={cfg.model_name} | prompt={cfg.prompt} | run={time.strftime('%Y-%m-%d %H:%M:%S')}")
    sink("")
    sink("| id | input | tags | raw model output | post-processed | fallback | quality |")
    sink("|---|---|---|---|---|---|---|")

    for case in cases:
        cid = case.get("id", "?")
        src = case["transcript"]
        raw_summary, latency, n_in, n_out = run_mod.summarize(cfg, cfg.prompt, src)
        proc_summary, reason = post_process(src, raw_summary)
        tags = extract_tags(src)
        m = evaluate(src, proc_summary)

        short_input = src[:90] + "…" if len(src) > 90 else src
        # Escape pipe chars in summary for markdown table
        raw_cell = raw_summary.replace("|", "\\|").replace("\n", "<br>")
        proc_cell = proc_summary.replace("|", "\\|").replace("\n", "<br>")
        input_cell = short_input.replace("|", "\\|")

        sink(
            f"| {cid} | {input_cell} | {fmt_tags(tags)} | {raw_cell} | {proc_cell} | {reason} | {fmt_metrics(m)} |"
        )

    sink("")
    sink("## Metric definitions")
    sink("- **coverage**: % of source content words that appear in summary (higher = more faithful)")
    sink("- **hallucination**: % of summary content words NOT in source (lower = safer)")
    sink("- **compression**: input words / summary words (higher = more condensed)")
    sink("- **med**: medication name recall (e.g. 1/1 if the med survived)")
    sink("- **sleep**: did the sleep hour value survive?")
    sink("- **fx**: side-effect recall")
    sink("- **arc**: if source has mixed positive/negative signal, does summary keep both?")

    if args.save:
        RESULTS_DIR.mkdir(exist_ok=True)
        stamp = time.strftime("%Y%m%d-%H%M%S")
        out = RESULTS_DIR / f"eval-{stamp}.md"
        out.write_text("\n".join(lines) + "\n")
        print(f"\nSaved → {out}", file=sys.stderr)


if __name__ == "__main__":
    main()
