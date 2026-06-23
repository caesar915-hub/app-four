"""Canonical judge prompt (spec 013, FR-002/003/009).

Defines how the judge (Claude Code in-session, or a future API backend) decides
per-signal presence and per-field item correctness. Adversarial framing + the 7
span-level exclusion criteria; output is the verdict JSON in
contracts/judge-verdict.schema.md.
"""

EXCLUSIONS = [
    "Advice or 2nd-person directives ('you should try...').",
    "Quoted or reported affect (someone else's words about them).",
    "Past-tense / resolved states ('used to...', 'haven't been able to in years').",
    "Hypothetical / conditional ('if I skip a dose...').",
    "Venting about externals (pharmacy / insurance / shortage / generics).",
    "General claims about ADHD / medication in the abstract.",
    "Text quoting another Reddit commenter, then replying.",
]

SIGNAL_DEFS = {
    "mood": "emotional state / affect (good, low, anxious, content...)",
    "energy": "physical/mental energy or fatigue level",
    "focus": "attention / concentration / brain-fog",
    "sleep": "sleep quantity or quality",
}

_EXCL = "\n".join(f"  {i+1}. {e}" for i, e in enumerate(EXCLUSIONS))


def build_prompt(item: dict) -> str:
    ext = item["extraction"]
    ext_view = {
        "mood": ext.get("mood"), "energy": ext.get("energy"),
        "focus": ext.get("focus"), "sleepHours": ext.get("sleepHours"),
        "feelings": ext.get("feelings"), "activities": ext.get("activities"),
        "sideEffect": ext.get("sideEffect"),
    }
    return f"""You audit an NLP extractor for Reddit posts about ADHD medication.
The extractor OVER-EXTRACTS — be skeptical. A signal/item counts ONLY if it is the
author's OWN, FIRST-PERSON, PRESENT experience. Exclude when the text is:
{_EXCL}

POST (id={item['id']}):
\"\"\"{item['text']}\"\"\"

EXTRACTOR OUTPUT: {ext_view}

For each signal ({', '.join(SIGNAL_DEFS)}) decide `present` (is it genuinely the
author's own present experience in this post?) with a one-line reason FIRST.
For each richer field (feelings, activities, sleep, sideEffect) split the
extractor's items into correct_items / spurious_items, and add any missed_items
the author clearly stated. Return ONLY JSON per the verdict schema."""
