> **⚠️ HISTORICAL SNAPSHOT — superseded.** Frozen 2026-06-15. Pre-app-four (WhisperNotes/app-two era); does not reflect current project state. Current architecture lives in the Notion `app-two` DB, [docs/BACKLOG.md](../BACKLOG.md), and [docs/DEVLOG.md](../DEVLOG.md). Any "Gemma" mention is historical — Gemma was removed before the app-four fork.

# How Natural Language Extraction Works

> A technical guide to the on-device ADHD journal extraction pipeline in app-two.

---

## Overview

When a user finishes recording a voice note, the app transcribes it with WhisperKit, then runs the transcript through `NLNoteExtractor` — an on-device, zero-download pipeline built on Apple's `NaturalLanguage` framework. No CoreML model, no cloud API, no network. It works entirely offline and completes in milliseconds.

The extractor turns a free-text transcript like:

> "Took my Concerta 36mg at 8am. Felt wired for a couple hours then crashed hard around 3. Couldn't focus at all in the afternoon, total brain fog. Skipped lunch because food seemed gross. Slept maybe 5 hours last night."

Into structured data:

| Field | Value |
|---|---|
| **Medications** | Concerta 36mg at morning — taken |
| **Energy** | `high` → `crashed` |
| **Focus** | `foggy` |
| **Side Effects** | appetite loss |
| **Sleep** | 5 hours, poor quality |
| **Highlights** | Top salient sentences |

---

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Voice Recording │────▶│  WhisperKit      │────▶│  Raw Transcript │
└─────────────────┘     │  (on-device STT) │     └─────────────────┘
                        └──────────────────┘              │
                                                          ▼
                        ┌──────────────────────────────────────────┐
                        │  NLNoteExtractor                         │
                        │  ├─ Lexicon (exact-match vocabulary)     │
                        │  ├─ NLEmbedding (semantic similarity)    │
                        │  ├─ NLTagger (sentiment)                 │
                        │  ├─ NLTokenizer (sentence splitting)     │
                        │  └─ Regex Patterns (structured data)     │
                        └──────────────────────────────────────────┘
                                          │
                                          ▼
                        ┌──────────────────────────────────────────┐
                        │  NoteExtraction (structured schema)      │
                        └──────────────────────────────────────────┘
                                          │
                                          ▼
                        ┌──────────────────────────────────────────┐
                        │  NLSummarizationService                  │
                        │  → SummaryResult → Recording.applySummary│
                        └──────────────────────────────────────────┘
```

---

## The Pipeline Step by Step

### 1. Sentence Splitting (`NLTokenizer`)

The transcript is split into sentences using `NLTokenizer(unit: .sentence)`. Every downstream analysis runs per-sentence. This is important because:

- Negation has a limited scope (words *before* a match in the same sentence)
- A single transcript can contain contradictory states: "Morning was great, afternoon was a disaster"
- Highlights are scored and selected at the sentence level

### 2. Exact-Match Detection (Lexicon)

The **Lexicon** is an injectable vocabulary of ADHD-domain terms. For every sentence, the extractor checks if any lexicon term appears as a substring.

**Example categories:**

| Category | Example terms |
|---|---|
| Medications | Concerta XL, Elvanse, Adderall XR, Guanfacine, Vyvanse |
| Energy High | wired, buzzing, pumped, on fire, vibing |
| Energy Low | drained, no spoons, burnt out, sluggish |
| Focus Hyper | hyperfocus, in the zone, locked in, tunnel vision |
| Focus Fog | brain fog, sluggish cognitive tempo, mental haze, fuzzy |
| Mood Irritable | snappy, short fuse, grouchy, touchy |
| Mood Flat | zombie, emotionless, lost my sparkle, hollow |
| Rebound | wearing off, afternoon crash, rebound irritability |
| Appetite Loss | food is gross, force eating, forgot lunch |
| Physical Stim | leg bouncing, skin picking, stimming, pacing |

The Lexicon is fully customizable at init time, so tests can inject small vocabularies and clinicians could theoretically extend it per-patient.

### 3. Embedding Fallback (`NLEmbedding`)

Apple ships a frozen English word embedding with iOS. `NLEmbedding.wordEmbedding(for: .english)` returns a vector space where semantically similar words are close together.

This catches **paraphrases and slang** that aren't in the Lexicon:

| User says | Lexicon seed | Embedding distance | Detected as |
|---|---|---|---|
| "lethargic" | "tired" | ~0.3 | `EnergyLevel.low` |
| "wired" | "energized" | ~0.2 | `EnergyLevel.high` |
| "all over the shop" | "scattered" | ~0.4 | `FocusLevel.scattered` |

**Threshold:** distance < 0.55. If nothing is below the threshold, no match is returned.

**Why both?** Apple's embedding knows general English but not ADHD community slang. "No spoons" (energy low) and "did the thing" (win) are community-specific phrases the embedding has never seen. The Lexicon covers those. The embedding covers synonyms the Lexicon missed.

### 4. Targeted Negation

A 5-word window is scanned **before** each matched phrase. If a negation token appears, the match is flipped or discarded.

**Negation tokens:** `not`, `never`, `no`, `n't`, `without`, `forgot`, `missed`, `skipped`

| Sentence | Match | Negated? | Result |
|---|---|---|---|
| "Took Concerta at 8am" | Concerta | No | `taken: true` |
| "Forgot my Concerta today" | Concerta | Yes | `taken: false` |
| "Wasn't anxious, actually calm" | anxious | Yes | mood → "calm" |
| "Not hyperfocused, just distracted" | hyperfocused | Yes | focus → `distracted` |

**Scope is critical:** The window is only the words *before* the match in the same sentence. "I was tired but not anymore" → "tired" is NOT negated because "not" comes after.

### 5. Mood Detection (Hybrid)

Mood uses a slightly different path than energy/focus because it produces a free-text label, not an enum.

1. **Exact match** against `moodSpecific` pairs like `("anxious", "anxious")`, `("zombie", "flat")`
2. **Embedding fallback** against all mood seed words
3. The best match (lowest distance) wins across all sentences
4. **Sentiment valence** is also averaged across all sentences as a separate `moodValence` score (-1.0 to +1.0)

### 6. Medication Extraction

Multiple medications can be detected per sentence. For each match:

- **Name**: from Lexicon (preserves the brand name the user said)
- **Dose**: regex `\b\d+\s?(mg|mcg|milligrams?)\b`
- **Time of day**: `NSDataDetector` for clock times (8am → "morning"), or keyword fallback ("with breakfast" → "morning")
- **Taken**: negation scan sets `taken: false` for "forgot", "missed", "skipped"

### 7. Regex Patterns for Structured Data

Beyond substring matching, a set of regex patterns extract numeric/temporal data:

| Pattern | Example input | Extracted |
|---|---|---|
| **Dose** | "36mg XL twice daily" | `36mg XL twice daily` |
| **Sleep hours** | "slept about 6.5 hours" | `6.5` |
| **Onset** | "kicks in after 45 minutes" | `45` (mins) |
| **Duration** | "lasted 8 hours" | `8.0` |
| **Crash time** | "crashed around 3pm" | `crashed around 3pm` |
| **Sleep latency** | "took 2 hours to fall asleep" | `2.0` |
| **Intake context** | "took with orange juice" | `with orange juice` |
| **Severity** | "side effects 3/10" | domain: "side effects", severity: 3 |

These run over the **full transcript** (not per-sentence) and capture the first match.

### 8. Highlight Extraction

Highlights are the sentences shown as bullet points in the Journal card. They are selected by a scoring function:

**Score =**
- `abs(sentiment) * 2.0` — emotionally charged sentences
- `+3.0` if contains medication
- `+2.5` if contains win/rebound
- `+2.0` if contains task or executive dysfunction
- `+2.0` if contains side effect
- `+1.5` if contains energy/focus/mood/appetite cue
- `+1.0` if length is 40–200 chars (sweet spot)
- `-1.0` if under 20 chars (too short)

**Threshold:** Only sentences scoring ≥ 1.5 qualify. If nothing qualifies, at most **1** best sentence is returned. This prevents generic transcripts from echoing the full text as "highlights."

**Top N cap:** `min(5, max(1, sentences.count / 4 + 1))`

### 9. Title Generation

The title is the first 6 words of the top-scoring highlight. If no highlights exist, it falls back to the first 6 words of the full transcript.

---

## The Lexicon Design

The Lexicon is intentionally **two-layered**:

```
┌─────────────────────────────────────────────┐
│  Layer 1: Exact Substring Match             │
│  - Fast, O(n) per sentence                  │
│  - Catches multi-word phrases               │
│  - Domain-specific slang                    │
│  - Examples: "no spoons", "task paralysis"  │
├─────────────────────────────────────────────┤
│  Layer 2: NLEmbedding Semantic Similarity   │
│  - Catches synonyms / paraphrases           │
│  - General English vocabulary               │
│  - Examples: "lethargic" ≈ "tired"          │
└─────────────────────────────────────────────┘
```

**Exact match wins.** If a term is in the Lexicon, it returns immediately with distance 0.0. Embedding is only consulted when no exact match is found.

This design means:
- **Precision** for ADHD-specific language (exact match)
- **Recall** for general English variants (embedding fallback)
- **Testability** — inject a small lexicon in unit tests
- **Extensibility** — add new terms without retraining anything

---

## Data Flow to the UI

```
NoteExtraction
    │
    ├── medications  ──────────▶  medicationInfo string
    │                              → Recording.medicationInfo
    │
    ├── energy (enum)  ────────▶  rawValue string
    │                              → Recording.energyLevel
    │
    ├── focus (enum)  ─────────▶  rawValue string
    │                              → Recording.focusLevel
    │
    ├── mood (string)  ────────▶  Recording.mood
    │
    ├── highlights  ───────────▶  JSON array
    │                              → Recording.summaryBulletsJSON
    │                              → Journal card bullet list
    │
    └── title  ────────────────▶  Recording.title
```

New fields (`executiveDysfunction`, `reboundTerms`, `appetiteLoss`, etc.) are captured in `NoteExtraction` but not yet persisted to `Recording`. They can be surfaced in future UI iterations without changing the extraction engine.

---

## Performance

| Step | Cost | Notes |
|---|---|---|
| Sentence splitting | ~0.1ms | `NLTokenizer` is C-backed |
| Lexicon scan | ~0.5ms | Simple substring checks |
| Embedding lookup | ~1ms | Only for unmatched sentences |
| Regex patterns | ~0.2ms | Compiled once, first-match |
| **Total** | **~2ms** | For a 200-word transcript |

The entire extraction is synchronous and single-threaded. `NLSummarizationService` wraps it in an `async` function for protocol compliance, but there's no actual suspension point.

---

## Why This Architecture

| Approach | Pros | Cons | Why we didn't choose it |
|---|---|---|---|
| **On-device LLM (Gemma)** | Handles any paraphrase | 2GB+ download, 5–10s inference, battery drain | Kept dormant for future "weekly insights" feature |
| **Cloud API (OpenAI/Claude)** | Best accuracy | Requires network, privacy risk, latency, cost | Medical voice notes should stay on device |
| **CoreML classifier** | Fast, offline | Needs training data, retraining for new meds | Lexicon is easier to extend than a model |
| **Apple NL (this approach)** | Instant, offline, tiny, extensible | Less nuanced than LLM | Right trade-off for per-note triage |

The NLP pipeline is specifically designed for **triage**, not therapy. It answers: *"Did they take their meds? How was their energy? Any side effects?"* — not *"Why do they feel this way?"* For that, the LLM path (Gemma) is preserved for future weekly-summary use.

---

## Extending the System

### Add a new medication
```swift
let lexicon = Lexicon(
    medications: Lexicon.defaultMedications + ["MyNewDrug"]
)
let extractor = NLNoteExtractor(lexicon: lexicon)
```

### Add a new side effect term
```swift
let lexicon = Lexicon(
    sideEffectCues: Lexicon.defaultSideEffectCues + ["new symptom"]
)
```

### Test a specific transcript
```swift
let extractor = NLNoteExtractor()
let note = extractor.extract(from: "Took Vyvanse 30mg at 7am. Crashed at 2pm.")

assert(note.medications.first?.name == "Vyvanse")
assert(note.medications.first?.dose == "30mg")
assert(note.energy == .crashed)
```

---

## Files

| File | Role |
|---|---|
| `Services/NoteExtraction/Lexicon.swift` | Injectable vocabulary |
| `Services/NoteExtraction/NLNoteExtractor.swift` | Extraction engine |
| `Services/NoteExtraction/NoteExtraction.swift` | Data models & schema |
| `Services/NLSummarizationService.swift` | Adapter to app domain |
| `NL_ARCHITECTURE.md` | This document |

---

## Related

- Standalone package: `https://github.com/caesar915-hub/nl-calssifier`
- Apple NLP docs: https://developer.apple.com/documentation/naturallanguage
- WhisperKit: https://github.com/argmaxinc/WhisperKit
