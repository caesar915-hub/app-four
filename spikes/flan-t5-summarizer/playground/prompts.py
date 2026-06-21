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
    # Fine-tuning + inference prompt for the LoRA'd flan-t5-large. Short (no few-shot)
    # so the transcript fits flan-t5's 512-token encoder. Use the SAME string in
    # build_lora_data.py (to form training `input`) and at eval (--prompt lora-short),
    # or train/inference drift silently degrades the model.
    "lora-short": (
        "Write a faithful summary of this ADHD post as 3-6 bullet points.\n"
        "- Only include dimensions actually described: mood, energy, focus (plus triggers, coping).\n"
        '- Each bullet starts with its label: "- Mood:", "- Energy:", "- Focus:", "- Trigger:", or "- Coping:".\n'
        "- State only what is described; do not infer, embellish, or add anything not in the text.\n"
        "- Omit any dimension not present.\n\n"
        "Post:\n{transcript}\n\nSummary:"
    ),

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

    # ── T5Gemma-specific prompts ──────────────────────────────────────────────
    # T5Gemma -it variants are Gemma-2 chat-tuned; run.py wraps these as a user
    # turn via apply_chat_template. So phrase as a NATURAL instruction, not the
    # T5 task-prefix style ("Summarize the following...") that FLAN was tuned on.
    # The prior T5Gemma eval used the FLAN task-prefix prompt — an unfair test.
    "gemma-faithful": (
        "Here is a personal journal entry:\n\n{transcript}\n\n"
        "Summarise it as a few short bullet points (around 3 to 6) in the "
        "person's own words. Don't add anything they didn't say. Keep every "
        "medication name, dose, time, sleep detail, side-effect, and how they "
        'felt exactly as written. Start each bullet with "- ".'
    ),

    "gemma-faithful-fewshot": (
        "You turn personal journal entries into short, faithful bullet points "
        "in the person's own words. Never add anything they didn't say. Keep "
        "medications, doses, times, sleep, side-effects, and feelings exact.\n\n"
        "Entry: Took my Concerta 36mg at 8am. Razor sharp till lunch, then "
        "crashed hard and felt wiped out by 3pm.\n"
        "Bullets:\n"
        "- Took my Concerta 36mg at 8am\n"
        "- Razor sharp till lunch\n"
        "- Crashed hard, wiped out by 3pm\n\n"
        "Entry: {transcript}\n"
        "Bullets:"
    ),

    # ── Rematch prompts (per-model, from the Phase-A failure taxonomy) ────────
    # flan-base: ~94% meta-language ("The journal entry is about…") + invents a
    # profession/diagnosis. Ban both; force first-person content; few-shot anchor
    # (base follows demonstrations far more reliably than instructions).
    "base-strict": (
        "Rewrite this journal entry as up to 4 short bullet points of its actual content.\n"
        "- Never write 'The journal entry is about', 'The narrator', or 'The person'. Write the content itself.\n"
        "- Do not state any profession, diagnosis, or condition unless those exact words appear in the entry.\n"
        "- Keep every medication name, dose, time, sleep duration, mood, and side-effect exactly as written.\n"
        "- Use the writer's own first-person words. Do not repeat any line.\n"
        'Start each bullet with "- ".\n\n'
        "Journal entry:\n{transcript}\n\nBullet points:"
    ),

    "base-fewshot": (
        "Turn each journal entry into up to 4 short first-person bullets of its real content. "
        "Keep medications, doses, times, sleep, mood, and side-effects exactly. Never describe the "
        "entry and never invent a profession or diagnosis.\n\n"
        "Entry: Took my Concerta 36mg at 8am after six hours of broken sleep. Foggy until it kicked in. "
        "Crashed by 3 with a dry mouth. Mood low all evening.\n"
        "Bullets:\n"
        "- Took Concerta 36mg at 8am\n"
        "- Six hours of broken sleep, foggy until it kicked in\n"
        "- Crashed by 3 with a dry mouth\n"
        "- Mood low all evening\n\n"
        "Entry: {transcript}\n"
        "Bullets:"
    ),

    # flan-large: extractive & safe but truncates to the first 1-4 sentences,
    # dropping late signals (sleep/mood/food/coping) and one negation flip
    # (drug-holiday → "took Concerta"). Force whole-entry coverage by signal slot
    # + the closing line, and lock negation literally.
    "large-coverage": (
        "Summarize the ENTIRE journal entry as 3 to 8 short bullet points — cover the whole entry, "
        "not just the first few sentences. Include every one of these that appears: medication "
        "(name, dose, time), sleep (hours/quality), mood, energy, focus, food/water, social, and what "
        "the person did about it (coping or resolution — often the last sentence).\n"
        "Use the person's own words. Copy medications, doses, times, and sleep numbers exactly. "
        "If a medication was NOT taken or was skipped, say so explicitly — never turn 'didn't take' into 'took'. "
        "Do not add anything not in the entry. Do not repeat a bullet.\n"
        'Start each bullet with "- ".\n\n'
        "Journal entry:\n{transcript}\n\nBullet points:"
    ),

    "large-coverage-fewshot": (
        "Summarize the ENTIRE journal entry as 3 to 8 short bullets covering the whole entry — never stop "
        "after the first few sentences. Keep medications/doses/times and sleep numbers exact, keep negations "
        "('didn't', 'skipped', 'no'), and always include the final outcome or what the person did.\n\n"
        "Entry: Took my Concerta at 8 after six hours of broken sleep. Focus held until 1, then I crashed "
        "around 2:30. Mood went flat after. Forgot lunch again. Overall the morning was good and I want to keep that.\n"
        "Bullets:\n"
        "- Took Concerta at 8\n"
        "- Six hours of broken sleep\n"
        "- Focus held until 1, crashed around 2:30\n"
        "- Mood went flat after the crash\n"
        "- Forgot lunch\n"
        "- Overall the morning was good and wants to keep that\n\n"
        "Entry: Weekend drug holiday, no Concerta today. Woke naturally at 9:30. Calmer but scattered.\n"
        "Bullets:\n"
        "- Drug holiday, did not take Concerta today\n"
        "- Woke naturally at 9:30\n"
        "- Calmer but scattered\n\n"
        "Entry: {transcript}\n"
        "Bullets:"
    ),

    # T5Gemma: fabricates clock specifics (appends am/pm, invents durations),
    # flips negations, and barely compresses. Lock times/numbers/negation, force
    # genuine compression. Run with --no-repeat-ngram 3 --repetition-penalty 1.3.
    "gemma-strict": (
        "Here is a personal journal entry:\n\n{transcript}\n\n"
        "Summarise it as at most 4 short bullets in the person's own words — aim for about one-third the length.\n"
        "- Copy every clock time exactly. If the entry gives a bare time like '2:30' or 'at 8', never add 'am' or 'pm'.\n"
        "- Never invent a number, dose, or duration that is not in the entry.\n"
        "- 'Slept N hours' means time asleep — never rewrite it as 'tired for N hours'.\n"
        "- Keep every 'not'/'didn't'/'no' exactly; never flip a negative into a positive. Keep emotional words as written.\n"
        "- Do not add symptoms or events not in the entry. Do not repeat a bullet.\n"
        'Start each bullet with "- ".'
    ),

    "gemma-strict-fewshot": (
        "You summarise personal journal entries into at most 4 short, faithful bullets in the person's own "
        "words. Copy times and numbers exactly (never add am/pm to a bare time), keep negations, never "
        "invent symptoms, never repeat a bullet.\n\n"
        "Entry: Took my Concerta at 8. Crash came early, maybe 2:30. Meeting at 3 was rough. Slept maybe 5 "
        "hours. Didn't eat lunch.\n"
        "Bullets:\n"
        "- Took Concerta at 8\n"
        "- Crash came early, maybe 2:30\n"
        "- Meeting at 3 was rough\n"
        "- Slept maybe 5 hours; didn't eat lunch\n\n"
        "Entry: {transcript}\n"
        "Bullets:"
    ),

    # T5Gemma-prefixlm: loops eat the medication before the decoder reaches it
    # (32% med-drop). Emit the medication slot FIRST so it can't be lost to a loop.
    "gemma-medslot": (
        "Here is a personal journal entry:\n\n{transcript}\n\n"
        "First, if any medication is mentioned, write one line copying its name, dose, and time exactly "
        "(e.g. 'Meds: Elvanse 50mg at 7:30'); if none, write 'Meds: none mentioned'. "
        "Then write at most 4 more short bullets for the other facts, in the person's own words. "
        "Copy all times and numbers exactly (never add am/pm to a bare time, never invent a ':30'). "
        "Keep every negation. Do not invent symptoms. Never repeat a line.\n"
        'Start each bullet with "- ".'
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

    # ── addrec teacher prompt (mirrors generate_summaries.py exactly) ─────────
    # This is the SAME prompt Claude used to generate addrec_500_summaries.jsonl.
    # {signals} must be passed as a comma-joined string from the input metadata;
    # use build_addrec() below instead of build() for this prompt.
    "addrec-structured": (
        "Generate a structured summary of the following r/ADHD Reddit post for LoRA fine-tuning data.\n\n"
        "Output ONLY bullet points. No preamble, no explanation, no insight blocks, no prose. Just bullets.\n\n"
        "Rules:\n"
        "- Each bullet must start with exactly one of: \"- Mood:\", \"- Energy:\", \"- Focus:\", \"- Trigger:\", \"- Coping:\"\n"
        "- Only include a dimension if it is explicitly described in the post. Omit it entirely if absent.\n"
        "- Do not infer, embellish, or add anything not stated in the text.\n"
        "- 3-6 bullets total.\n"
        "- If the post contains no symptom content at all, output only: \"- No extractable symptom content.\"\n\n"
        "Signals detected in this post: {signals}\n\n"
        "Post:\n{transcript}\n\nBullets:"
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


def build_addrec(transcript: str, signals: list) -> str:
    """addrec-structured requires a signals list in addition to the transcript."""
    return PROMPTS["addrec-structured"].format(
        transcript=transcript.strip(),
        signals=", ".join(signals) if signals else "none detected",
    )
