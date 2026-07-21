# NL Extractor Evaluation Guide

Testing methodology for `NLNoteExtractor` — the keyword/lexicon-based extractor that derives structured signals (mood, energy, sleep hours, emotions, medications, focus, activities) from short free-text ADHD check-ins.

Sources are cited inline. All URLs were live-fetched or confirmed via search in session 2026-06-26. `[VERIFIED]` = page was fetched; `[CITED]` = confirmed via search metadata.

---

## 1. What We're Measuring

The extractor is a **rule-based information extraction (IE) system**: it uses a fixed lexicon plus regex patterns to produce structured fields from unstructured text. It has no stochastic component and no training data.

The evaluation framework comes from two lineages that converged into the field standard:

- **MUC conferences (1987–1997)** — instituted precision and recall as the canonical IE metrics at the entity/slot level, not the token level. Source: [MUC-5 Evaluation Metrics, Chinchor & Sundheim, ACL 1993](https://aclanthology.org/M93-1007/) `[VERIFIED]`
- **CoNLL-2003 shared task** — established entity-level exact-match micro-averaged F1 as the modern NER standard. A prediction is correct only if the label AND both span boundaries match gold exactly. Source: [Tjong Kim Sang & De Meulder, 2003](https://aclanthology.org/W03-0419/) `[CITED]`

**Definitions:**

```
Precision = TP / (TP + FP)   "of everything the extractor fired on, how much was real?"
Recall    = TP / (TP + FN)   "of everything real in the corpus, how much did it catch?"
F1        = 2 · P · R / (P + R)
```

Where TP = extracted signal matches gold, FP = extracted signal not in gold, FN = gold signal not extracted.

### Micro vs Macro averaging

| | Micro-F1 | Macro-F1 |
|---|---|---|
| **How** | Pool all TP/FP/FN across all notes, compute once | F1 per signal type, then average |
| **Weights** | More weight to frequent signals | Equal weight to each signal type |
| **Use for** | Overall system performance | Catching per-category weakness |

**Recommendation:** report micro-F1 as primary (field standard per CoNLL/i2b2), macro-F1 as secondary. The low macro recall for `sleepHours` (0.27) and `energy` (0.23) is most visible in per-category breakdown — macro reveals this; micro buries it.

### Strict vs Lenient matching

For this extractor:
- `mood`, `energy`, `emotions`, `focus`, `activities` — strict label match (field must match gold label exactly)
- `sleepHours` — strict value match within ±0.1h tolerance (Float comparison, not span)
- `medications` — strict name match (normalized, case-insensitive)

Lenient/overlap matching is only appropriate when boundaries are genuinely ambiguous. A lexicon extractor produces deterministic boundaries, so lenient matching would artificially inflate precision. Use strict throughout.

---

## 2. Current Test Architecture

The codebase already implements the field-standard pattern:

```
app-fourTests/
  Eval/
    EvalSet.swift              ← curated corpus of (input, expected) pairs  [unit tests / MFT]
    ExtractionEvalTests.swift  ← precision/recall/F1 per signal category, with ratchet floors
```

This is directly analogous to the **CheckList framework** (Ribeiro et al., [ACL 2020 Best Paper](https://aclanthology.org/2020.acl-main.442/) `[VERIFIED]`), which defines:

| CheckList type | This codebase analog | What it catches |
|---|---|---|
| **MFT (Minimum Functionality Test)** | `EvalSet.cases` — fixed `(note_text, expected_signals)` | Specific pattern regressions; a lexicon edit that breaks one case |
| **INV (Invariance Test)** | Not yet implemented | "felt anxious today" vs "felt anxious yesterday" — output should be identical |
| **DIR (Directional Expectation Test)** | Not yet implemented | Adding "not" before emotion word should negate the extracted signal |

CheckList found bugs **3× more frequently** than aggregate metrics alone. The MFT suite (`EvalSet.cases`) is the most valuable single investment.

### Current ratchet floors

From `ExtractionEvalTests.swift` (verified 2026-06-26, 314/0/2 green):

| Signal | Precision floor | Recall floor | Notes |
|---|---|---|---|
| medications | 0.980 | 0.980 | High confidence; structured input |
| emotions | 0.920 | 0.647 | Mood-Meter lexicon (spec-020) |
| mood | 0.730 | 0.580 | Weak fallback gated on "mood" trigger |
| energy | 0.647 | **0.230** | Weak fallback gated on "energy" trigger |
| sleepHours | 0.980 | **0.266** | Two-tier parser (see §5) |
| focus | 0.380 | 0.310 | Lowest combined; broad category |
| activities | 0.280 | 0.410 | FP-heavy; broad category |

Floors are ratchets — they can only increase, never decrease. When a lexicon change genuinely raises F1, raise the floor in the same commit. The test fails the build if any floor is violated.

---

## 3. Building the Gold Corpus

The current `EvalSet.cases` is the gold corpus. Expanding it requires a structured annotation process.

### Industry standard: double-annotation + adjudication

Source: [Savova et al., JAMIA 2012 — Building Gold Standard Corpora for Medical NLP](https://pmc.ncbi.nlm.nih.gov/articles/PMC3540456/) `[VERIFIED]`

Protocol:
1. Write an annotation guide (see §3.1)
2. Each document gets **two independent annotations** with no cross-reference
3. **Consensus session** adjudicates disagreements — the result is the gold standard
4. Measure IAA **before** consensus; target **inter-annotator F1 ≥ 0.80**
5. If IAA < 0.70 on a label, the label definition is ambiguous — coarsen or remove it (source: [Sun et al., i2b2 2012, JAMIA 2013](https://pmc.ncbi.nlm.nih.gov/articles/PMC3756273/) `[VERIFIED]`)

**IAA metric to use:** F1 between annotators (treat annotator A as "gold", annotator B as "system"), not Cohen's kappa. Kappa requires counting true negatives, which are undefined for span extraction — there are infinitely many non-annotated spans. (Source: [Savova et al. 2012](https://pmc.ncbi.nlm.nih.gov/articles/PMC3540456/) and [IAA review, arXiv 2603.06865, 2026](https://arxiv.org/html/2603.06865) `[VERIFIED]`)

If two annotators aren't available (solo project): annotate a set, wait 2 weeks, re-annotate from memory. Self-IAA is weaker but still informative. Target self-IAA F1 ≥ 0.85.

### 3.1 Annotation guide for this extractor

When annotating a check-in note, label each of the following:

| Field | What counts | Examples | What does NOT count |
|---|---|---|---|
| `mood` | Any explicit or strong-implicit mood statement | "felt rubbish", "mood was good", "low today" | Nested under emotion label already captured |
| `energy` | Explicit energy/fatigue statement | "no energy", "felt wired", "crashed at 3pm" | "tired of waiting for the bus" (not fatigue) |
| `sleepHours` | A numeric duration of sleep | "7 hours", "eight and a half", "barely 5hrs" | Clock times ("woke at 7"), activity durations ("worked 12 hours") |
| `emotions` | Named emotions from the Mood-Meter lexicon | "anxious", "frustrated", "excited" | Mood adjectives not in the lexicon |
| `medications` | Medication taken + dose if present | "took 20mg ritalin", "forgot my concerta" | Brand names not in the catalog |
| `focus` | Explicit focus/concentration statement | "couldn't focus", "hyperfocused on code" | General productivity statements |
| `activities` | Named activities | "went for a run", "cooked dinner" | Vague activity verbs ("did stuff") |

Annotation produces a Swift-compatible expected dict per note. Notes with no signal in a field get `nil`/empty for that field — **include these explicitly**; they are needed to measure precision (false positive detection).

### 3.2 Corpus composition

Source: structural guidance from [2010 i2b2/VA Challenge (Uzuner et al., JAMIA 2011)](https://pmc.ncbi.nlm.nih.gov/articles/PMC3168320/) `[VERIFIED]`

A representative corpus for this extractor should include:

| Note type | Why |
|---|---|
| Single-signal notes ("slept 8 hours, nothing else") | Isolates each extractor path |
| Multi-signal notes ("tired, anxious, took 20mg, slept 6h") | Tests interaction between extractors |
| No-signal notes ("went to the shops, called mum") | Tests false positive rate — critical for precision |
| Negation notes ("didn't sleep well", "no energy today") | Tests negation handling |
| Implicit notes ("kip was rough", "could barely keep eyes open") | Tests recall depth |
| Clock-time notes ("woke at 7h, bed at 23:00") | Tests false positive exclusion in sleepHours |
| Activity-duration notes ("worked for 12 hours") | Tests `hoursGovernedByActivityVerb` guard |
| Dialect/informal notes ("slept a solid 7", "proper tired") | Tests real user phrasing |

Minimum useful corpus: **100 annotated notes** (enough for stable P/R estimates with ±5% confidence). Source: general corpus size guidance from i2b2 papers.

---

## 4. Evaluation Protocols by Source Type

### 4.1 Existing EvalSet corpus (automated)

Run on every build via `ExtractionEvalTests.metricsMeetFloors()`. This is the ground truth. If it's green, no regression. If it fails, a lexicon or pattern change broke a known case — examine the failing case before changing anything.

### 4.2 New check-in notes (manual → corpus)

Workflow:
1. Collect 10–20 real notes (your own, with consent from others)
2. Annotate expected signals by hand (don't run the extractor first — that biases annotation)
3. Run the extractor, compare to annotation
4. For every discrepancy: classify as FP or FN, add the note as an `EvalSet.case`
5. Rerun test suite — new case may fail the floor, which is correct signal that the floor was set too high for the new data distribution

### 4.3 Targeted edge-case generation (manual → corpus)

Use LLM-generated text for coverage of edge cases the extractor is known to handle badly. Ground rule: **generate the text, label it yourself** — do not let an LLM auto-label, as the eval handoff document notes the LLM judge was found unreliable on this corpus. (Source: `docs/extractor-eval-handoff.md`, session 2026-06-26)

Priority edge cases to generate:
- Spelled-out numbers: "eight and a half hours sleep"
- Compound sleep phrases: "lay awake for hours", "couldn't get to sleep until 3am"
- Energy product nouns: "drank two energy drinks and felt fine" (should NOT extract energy signal)
- Sleep activity-verb collision: "worked through the night for 14 hours" (should NOT extract sleepHours)
- Negated sleep: "didn't sleep much", "not tired at all"
- Medication miss: "forgot to take my meds again"

### 4.4 CheckList INV and DIR tests (not yet implemented)

These are the highest-leverage tests missing from the current suite.

**INV (Invariance) examples:**
```swift
// Tense should not change extraction
("I felt anxious today", "I felt anxious yesterday")  // same extraction
("slept 8 hours last night", "slept 8 hours on Monday")  // same extraction
```

**DIR (Directional) examples:**
```swift
// Negation should suppress or invert signal
("felt anxious") → emotions contains "anxious"
("did not feel anxious") → emotions does NOT contain "anxious"

("slept 8 hours") → sleepHours ≈ 8.0
("barely slept") → sleepHours = nil
```

Implementation: add a separate `XCTestCase` class (`ExtractionInvarianceTests`, `ExtractionDirectionalTests`) that does not contribute to the floor metrics — these are behavioral correctness tests, not regression floors.

---

## 5. The Two-Tier Sleep-Hours Design

This is a non-obvious architectural constraint that any future evaluator needs to understand to interpret test failures correctly.

```
Tier 1 (whole-text): ADHDRegexPatterns.extractSleepHours
  - Trigger-gated: only fires if sleep trigger word found in the full check-in
  - Higher recall: searches across the whole note
  - Takes priority: extraction.sleepHours

Tier 2 (per-sentence): NLNoteExtractor.extractSleepHours
  - Trigger-less: fires on any sentence classified as a sleep sentence
  - Safer false-positive profile: restricted to sleep-labelled sentences only
  - Fills gaps when Tier 1 finds no duration: SleepNote.hours fallback
```

If Tier 1 fires and Tier 2 also fires with a different value, Tier 1 wins. This is intentional — Tier 1 has broader context (whole note). An eval failure in sleepHours should first ask: which tier fired, and was the test note designed to exercise both?

---

## 6. Ablation Protocol

Source: structural approach from [Rao et al., PLOS ONE 2017](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0171649) `[VERIFIED]` and [Replicable NER comparison, Chuniversiteit](https://chuniversiteit.nl/papers/replicable-comparison-study-of-ner-software) `[VERIFIED]`

Ablation = disable one signal category at a time, run the full corpus, measure the F1 delta. This identifies:
- Which categories are responsible for most errors
- Whether removing a category causes unexpected cross-category changes (signal leakage)
- Whether a category has net-negative precision impact (removing it raises overall F1)

Ablation is especially useful before adding new lexicon entries — run an ablation baseline first so the effect of the new entries is measurable in isolation.

---

## 7. When to Update the Floors

Rules (derived from ratchet pattern, validated by industry quality-gate practice from [Codecentric AG](https://www.codecentric.de/en/knowledge-hub/blog/evaluating-machine-learning-models-quality-gates) `[VERIFIED]`):

| Situation | Action |
|---|---|
| Lexicon change improves a floor metric | Raise the floor in the same commit; floor = new value |
| Lexicon change maintains the floor | No floor change; commit proceeds |
| Lexicon change drops a floor metric | Floor test fails; investigate before proceeding |
| New notes added to `EvalSet.cases` that fail current floors | Floor is NOT lowered; extractor must be fixed |
| New signal category added | Add a new floor at the measured baseline for that category |

The floor file is a hard lower bound on deployed quality. It is the production SLA for the extractor.

---

## 8. Clinical NLP Reference Benchmarks

For context — these are the field's best systems on directly analogous tasks, representing the upper bound of what's achievable with state-of-the-art ML (not lexicon-based):

| Challenge | Task | Best F1 | Source |
|---|---|---|---|
| i2b2 2009 | Medication extraction from clinical notes | ~0.90 | [Uzuner et al., JAMIA 2010](https://pmc.ncbi.nlm.nih.gov/articles/PMC2995676/) `[VERIFIED]` |
| i2b2 2010 | Concept + assertion + relation extraction | ~0.85 concept | [Uzuner et al., JAMIA 2011](https://pmc.ncbi.nlm.nih.gov/articles/PMC3168320/) `[VERIFIED]` |
| n2c2 2018 | ADE + medication extraction (MIMIC-III) | F1=0.94 concept | [Henry et al., JAMIA 2020](https://pmc.ncbi.nlm.nih.gov/articles/PMC7489085/) `[VERIFIED]` |

Personal health notes are shorter, less structured, and more colloquial than clinical notes — expect lower ceilings than the above. A lexicon extractor in the 0.65–0.85 F1 range on a well-annotated corpus of real user notes is within the range of published rule-based clinical IE systems.

---

## 9. Source Index

| # | Source | URL |
|---|---|---|
| 1 | MUC-5 Evaluation Metrics (Chinchor & Sundheim, ACL 1993) | https://aclanthology.org/M93-1007/ |
| 2 | CoNLL-2003 NER Shared Task (Tjong Kim Sang & De Meulder, 2003) | https://aclanthology.org/W03-0419/ |
| 3 | Jurafsky & Martin, SLP3 (Stanford, free online) | https://web.stanford.edu/~jurafsky/slp3/ |
| 4 | Building Gold Standard Medical NLP Corpora (Savova et al., JAMIA 2012) | https://pmc.ncbi.nlm.nih.gov/articles/PMC3540456/ |
| 5 | Counting on Consensus — IAA Metric Selection (arXiv 2026) | https://arxiv.org/html/2603.06865 |
| 6 | Replicable Comparison of NER Software (Chuniversiteit) | https://chuniversiteit.nl/papers/replicable-comparison-study-of-ner-software |
| 7 | spaCy Scorer API | https://spacy.io/api/scorer |
| 8 | Lexicon-Enhanced Sentiment Analysis (Rao et al., PLOS ONE 2017) | https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0171649 |
| 9 | 2010 i2b2/VA Challenge (Uzuner et al., JAMIA 2011) | https://pmc.ncbi.nlm.nih.gov/articles/PMC3168320/ |
| 10 | 2009 i2b2 Medication Extraction (Uzuner et al., JAMIA 2010) | https://pmc.ncbi.nlm.nih.gov/articles/PMC2995676/ |
| 11 | 2018 n2c2 ADE/Medication (Henry et al., JAMIA 2020) | https://pmc.ncbi.nlm.nih.gov/articles/PMC7489085/ |
| 12 | 2012 i2b2 Temporal Relations (Sun et al., JAMIA 2013) | https://pmc.ncbi.nlm.nih.gov/articles/PMC3756273/ |
| 13 | CheckList Behavioral Testing (Ribeiro et al., ACL 2020 Best Paper) | https://aclanthology.org/2020.acl-main.442/ |
| 14 | ML Quality Gates (Codecentric AG) | https://www.codecentric.de/en/knowledge-hub/blog/evaluating-machine-learning-models-quality-gates |
| 15 | Carletta 1996 — Kappa thresholds | *Computational Linguistics* 22(2):249–254 (1996) |
