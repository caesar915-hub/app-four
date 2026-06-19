# Summary pipeline architecture

```mermaid
flowchart LR
    A[Raw transcript] --> B{Tag extraction}
    A --> C{Summarization}

    subgraph Tags [Independent tag pipelines]
        B1[ML classifiers]
        B2[Lexicon / rules]
        B1 --> mood[mood / energy / focus]
        B2 --> meds[medications]
        B2 --> sleep[sleep]
        B2 --> fx[side-effects]
    end

    B --> Tags

    subgraph Summary [Summary pipeline]
        C --> D[FLAN-T5-base + faithful prompt<br>or FLAN-T5-large + fewshot-v2]
        D --> E{Output OK?}
        E -->|yes| F[summary bullets]
        E -->|meta / hallucination /<br>collapse / repetition /<br>medical hallucination| G[fallback to source]
        G --> F
    end

    mood --> R
    meds --> R
    sleep --> R
    fx --> R
    F --> R

    R[Compose SummaryResult]
```

## How it works

1. **Same input, parallel pipelines.** The raw transcript feeds three independent systems:
   - ML classifiers for mood / energy / focus
   - Lexicon/rules for sleep, medications, side-effects
   - FLAN-T5 for the bullet summary

2. **They do not depend on each other.** If the ML classifiers abstain (`mood: null`), the summary still runs.

3. **Faithful extractor.** The summary prompt asks FLAN-T5 to use the user's own words and not invent details.

4. **Fallback guard.** If the model outputs meta-language ("the journal entry is about...", "bullets:"), hallucinates words ("water"), collapses a long entry to a platitude, repeats a phrase in a loop, or makes a high-hallucination claim about medications, the fallback replaces it with the user's original text.

5. **Compose at the end.** Tags and bullets are merged into the final `SummaryResult` only after all three pipelines finish.
