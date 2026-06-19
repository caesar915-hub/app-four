"""
Named prompt templates. Each is a function of the raw transcript.

The template is the single biggest lever on output quality and voice — more
than model size. Edit these freely, add your own, then compare with:

    python run.py --all-prompts

Tradeoff axis (see DEVLOG / the FLAN-T5 plan):
  faithful  → uses the person's own words, no paraphrase, no hallucination.
              Right for a health journal. Can read choppy.
  balanced  → light condensing, mostly original phrasing.
  fluent    → free to rephrase for readability. Risks clinical/AI tone
              ("experienced low mood") that's emotionally wrong for journaling.
"""

PROMPTS = {
    "faithful": (
        "Summarize the following journal entry as 3 short bullet points.\n"
        "Use the person's own words and key phrases. Do not add anything that is "
        "not in the entry. If a detail is not mentioned, leave it out.\n"
        'Start each bullet with "- ".\n\n'
        "Journal entry:\n{transcript}\n\nBullet points:"
    ),

    "balanced": (
        "Summarize this journal entry as up to 3 concise bullet points. "
        "Keep the person's wording where it matters, but you may shorten. "
        "Do not invent details.\n"
        'Start each bullet with "- ".\n\n'
        "Entry:\n{transcript}\n\nBullets:"
    ),

    "fluent": (
        "Write a brief, readable 2-3 bullet summary of this journal entry. "
        "Rephrase for clarity and flow.\n"
        'Start each bullet with "- ".\n\n'
        "Entry:\n{transcript}\n\nSummary:"
    ),

    # v2 of faithful: "up to 3" prevents padding; explicit meta-language ban
    # prevents "the journal entry is about..." outputs on neutral inputs.
    "faithful-v2": (
        "Summarize the following journal entry as up to 3 short bullet points.\n"
        "Use the person's own words and key phrases. Do not add anything that is "
        "not in the entry. If a detail is not mentioned, leave it out. "
        "Do not use phrases like 'the journal entry is about' or 'the narrator'. "
        "If the entry is very short, one bullet is fine.\n"
        'Start each bullet with "- ".\n\n'
        "Journal entry:\n{transcript}\n\nBullet points:"
    ),

    # ── Large-model-specific prompts ──────────────────────────────────────────
    # Base copies; Large paraphrases and drops details. These prompts try to
    # force Large to behave more like Base: extractive, detail-preserving.


    "faithful-large-fewshot-v2": (
        "Extract the key facts from the journal entry as 3 to 8 short bullet points. "
        "Use the person's own words. Preserve every concrete detail: medications, doses, times, "
        "side-effects, sleep hours/quality, tasks, and both positive and negative emotional states. "
        "Do NOT change negations into affirmations (e.g., keep 'wasn't tired' as 'wasn't tired'). "
        "Do NOT collapse multiple events into one generic statement. "
        "Do NOT add anything not in the entry.\n\n"
        "Example 1 - medical:\n"
        "Entry: Took my Concerta 36mg at 8am. It kicked in after 45 minutes and I was firing on all cylinders until lunch. "
        "Crashed hard around 3pm, dry mouth all afternoon.\n"
        "Bullets:\n"
        "- Took my Concerta 36mg at 8am\n"
        "- It kicked in after 45 minutes and I was firing on all cylinders until lunch\n"
        "- Crashed hard around 3pm\n"
        "- Dry mouth all afternoon\n\n"
        "Example 2 - emotional arc:\n"
        "Entry: Started the day anxious and flat, almost called in sick. But after lunch something shifted. "
        "I got moving and by evening I actually felt good and capable.\n"
        "Bullets:\n"
        "- Started the day anxious and flat, almost called in sick\n"
        "- After lunch something shifted\n"
        "- Got moving and by evening I actually felt good and capable\n\n"
        "Example 3 - negation:\n"
        "Entry: Slept badly so I expected to be wiped out, but surprisingly I wasn't tired at all.\n"
        "Bullets:\n"
        "- Slept badly so I expected to be wiped out\n"
        "- Surprisingly I wasn't tired at all\n\n"
        "Journal entry:\n{transcript}\n\nBullet points:"
    ),

    # A single-sentence variant — useful to compare against bullets.
    "one_line": (
        "Summarize this journal entry in one short sentence using the person's "
        "own words:\n\n{transcript}"
    ),
}


def build(name: str, transcript: str) -> str:
    if name not in PROMPTS:
        raise KeyError(f"Unknown prompt '{name}'. Available: {', '.join(PROMPTS)}")
    return PROMPTS[name].format(transcript=transcript.strip())
