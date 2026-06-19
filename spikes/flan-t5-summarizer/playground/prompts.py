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

    # Medical-precision variant: explicitly protects meds, doses, times, side-effects.
    "faithful-med": (
        "Summarize the following journal entry as up to 3 short bullet points.\n"
        "Use the person's own words. Do not add anything that is not in the entry. "
        "IMPORTANT: preserve all medication names, doses, times, and side-effects exactly. "
        "Do not drop medical details. If a detail is not mentioned, leave it out.\n"
        'Start each bullet with "- ".\n\n'
        "Journal entry:\n{transcript}\n\nBullet points:"
    ),

    # ── Large-model-specific prompts ──────────────────────────────────────────
    # Base copies; Large paraphrases and drops details. These prompts try to
    # force Large to behave more like Base: extractive, detail-preserving.

    "faithful-large-3to8": (
        "Summarize the following journal entry as 3 to 8 short bullet points.\n"
        "Use the person's own words and key phrases. Do not add anything that is "
        "not in the entry. Do not drop medications, doses, times, side-effects, "
        "sleep details, or emotional states. If a detail is not mentioned, leave it out.\n"
        'Start each bullet with "- ".\n\n'
        "Journal entry:\n{transcript}\n\nBullet points:"
    ),

    "faithful-large-preserve": (
        "Extract the key facts from the following journal entry as 3 to 8 short bullet points.\n"
        "Preserve exactly: medication names, doses, times, side-effects, sleep hours/quality, "
        "negations (not, wasn't, didn't), and both positive and negative emotional states. "
        "Use the person's own wording where possible. Do not add anything not in the entry. "
        "Do not compress multiple events into one bullet.\n"
        'Start each bullet with "- ".\n\n'
        "Journal entry:\n{transcript}\n\nBullet points:"
    ),

    "faithful-large-extract": (
        "Extract the most important bullet points from the following journal entry.\n"
        "Do not summarize or paraphrase. Use the person's own words. "
        "List 3 to 8 bullets. Preserve medications, doses, times, side-effects, sleep, "
        "and emotional details exactly as written. Do not add anything not in the entry.\n"
        'Start each bullet with "- ".\n\n'
        "Journal entry:\n{transcript}\n\nBullet points:"
    ),

    "faithful-large-oneper": (
        "Summarize the following journal entry as 3 to 8 short bullet points. "
        "Use one bullet per distinct event, medication, side-effect, sleep detail, or emotional state. "
        "Use the person's own words. Do not combine multiple events into one bullet. "
        "Do not add anything not in the entry.\n"
        'Start each bullet with "- ".\n\n'
        "Journal entry:\n{transcript}\n\nBullet points:"
    ),

    "faithful-large-fewshot": (
        "Summarize the journal entry as 3 to 8 short bullet points using the person's own words. "
        "Preserve medications, doses, times, side-effects, sleep, and emotional states. "
        "Do not add anything not in the entry.\n\n"
        "Example 1:\n"
        "Entry: Took my Concerta 36mg at 8am. Crashed hard around 3pm, dry mouth all afternoon.\n"
        "Bullets:\n"
        "- Took my Concerta 36mg at 8am\n"
        "- Crashed hard around 3pm\n"
        "- Dry mouth all afternoon\n\n"
        "Example 2:\n"
        "Entry: Morning was brilliant, full of energy. Then the afternoon hit and I completely crashed.\n"
        "Bullets:\n"
        "- Morning was brilliant, full of energy\n"
        "- Afternoon hit and I completely crashed\n\n"
        "Journal entry:\n{transcript}\n\nBullet points:"
    ),

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

    # ── Topics + structured signals ───────────────────────────────────────────
    # New task: one bullet per distinct topic (count emerges from the entry, not
    # fixed), THEN extract the app's 5 signals. Extract-only — never guess a
    # signal that isn't stated (critical for meds/doses). Absent → "not mentioned".
    "topics-signals": (
        "Read this personal journal entry and do two things.\n\n"
        "1) TOPICS: Identify each distinct thing the person talks about. Write one "
        "bullet per topic, in the person's own words. Do not merge separate topics "
        "into one bullet. Do not add anything that is not in the entry.\n\n"
        "2) SIGNALS: Report these only if the person actually mentions them; if a "
        "signal is not mentioned, write \"not mentioned\". Never guess.\n"
        "   - mood: how they felt emotionally\n"
        "   - energy: energy or tiredness level\n"
        "   - focus: focus or concentration\n"
        "   - sleep: how they slept (hours or quality)\n"
        "   - medication: name, dose, and time exactly as written\n\n"
        "Use this exact format:\n"
        "Topics:\n"
        "- <topic>\n"
        "- <topic>\n"
        "Signals:\n"
        "mood: <...>\n"
        "energy: <...>\n"
        "focus: <...>\n"
        "sleep: <...>\n"
        "medication: <...>\n\n"
        "Journal entry:\n{transcript}\n\nOutput:"
    ),

    # ── TWO-PASS approach ─────────────────────────────────────────────────────
    # The combined topics+signals prompt failed zero-shot on 0.6B models (the
    # signal scaffold ate the topics). Split into two simpler passes instead.

    # Pass A — topics only. Open generation in the person's voice; no schema.
    "topics-only": (
        "Read this personal journal entry. Identify each distinct thing the person "
        "talks about and write ONE short bullet per topic, in the person's own words. "
        "Do not merge separate topics into one bullet. Do not add anything that is "
        "not in the entry. If the entry only covers one thing, one bullet is fine.\n"
        'Start each bullet with "- ".\n\n'
        "Journal entry:\n{transcript}\n\nTopics:"
    ),

    # Pass B — signal extraction, FEW-SHOT. Constrained slot-filling for the app's
    # five signals. Examples teach the schema + the "not mentioned / never guess"
    # rule (incl. a medication name/dose/time example and absent-signal cases).
    "signals-fewshot": (
        "Extract these five signals from a journal entry: mood, energy, focus, "
        "sleep, medication. Report a signal ONLY if the person actually mentions it; "
        "if it is not mentioned, write \"not mentioned\". Never guess or infer. Keep "
        "values short and in the person's own words. For medication, give the name, "
        "dose, and time exactly as written.\n\n"
        "Entry: Took my Concerta 36mg at 8am. Focus was razor sharp till lunch, then "
        "I crashed hard and felt wiped out by 3pm.\n"
        "mood: not mentioned\n"
        "energy: crashed hard, wiped out by 3pm\n"
        "focus: razor sharp till lunch\n"
        "sleep: not mentioned\n"
        "medication: Concerta 36mg at 8am\n\n"
        "Entry: Slept maybe 5 hours, woke up groggy. Felt low and flat all morning "
        "but calmer by the evening.\n"
        "mood: low and flat all morning, calmer by evening\n"
        "energy: groggy\n"
        "focus: not mentioned\n"
        "sleep: maybe 5 hours, woke up groggy\n"
        "medication: not mentioned\n\n"
        "Entry: Good productive day, got loads done and felt motivated.\n"
        "mood: good, motivated\n"
        "energy: not mentioned\n"
        "focus: got loads done\n"
        "sleep: not mentioned\n"
        "medication: not mentioned\n\n"
        "Entry: {transcript}\n"
    ),

    # Pass B, ZERO-SHOT. No worked examples → nothing for the model to copy.
    # Few-shot leaked example values on 0.6B encoder-decoders (naive concatenated
    # demos are the wrong ICL format for T5/T5Gemma). Run with no_repeat_ngram OFF.
    "signals-zeroshot": (
        "Extract five signals from the journal entry below. For each, use the "
        "person's own words kept short, or write \"not mentioned\" if the entry "
        "does not mention it. Do not invent details. If a medication name appears "
        "anywhere in the entry, you must include it exactly (name, dose, time).\n"
        "Write exactly these five lines:\n"
        "mood: <how they felt emotionally, or not mentioned>\n"
        "energy: <energy or tiredness level, or not mentioned>\n"
        "focus: <focus or concentration, or not mentioned>\n"
        "sleep: <sleep hours or quality, or not mentioned>\n"
        "medication: <name, dose, time, or not mentioned>\n\n"
        "Journal entry:\n{transcript}\n\nSignals:"
    ),

    # Pass B as CLASSIFICATION (closed buckets) instead of open extraction.
    # Forcing fixed labels removes the room to invent text — the failure mode of
    # the generative prompts. Meds/sleep handled separately by regex/NER.
    "signals-classify": (
        "Analyze the following text and extract psychological signals.\n"
        "Return the output strictly in this format:\n"
        "Mood: [Positive/Negative/Neutral]\n"
        "Energy: [High/Medium/Low]\n"
        "Focus: [High/Medium/Low]\n\n"
        "Text:\n{transcript}"
    ),

    # Summary (Pass A) as a concise PARAGRAPH. NOTE: "key technical findings"
    # framing is domain-mismatched for emotional journal entries — kept verbatim
    # per request; see summary-journal for a journal-tuned variant if needed.
    "summary-technical": (
        "Summarize the following document into a concise paragraph focusing on "
        "the key technical findings:\n\n{transcript}"
    ),
}


def build(name: str, transcript: str) -> str:
    if name not in PROMPTS:
        raise KeyError(f"Unknown prompt '{name}'. Available: {', '.join(PROMPTS)}")
    return PROMPTS[name].format(transcript=transcript.strip())
