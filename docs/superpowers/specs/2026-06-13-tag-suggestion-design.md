# NLP Extraction Quality: Current Tags, Measured Improvement, Multilingual (EN/PT/ES)

**Date:** 2026-06-13 (amended same day: scope corrected to **existing tag vocabulary** — Daylio/HWF were UX references, not a request for a new ontology)
**Status:** Approved design, pre-implementation

## 1. Goal

Improve the precision, recall, and summary quality of the **existing** extraction pipeline — current tags, current lexicon — measured by a real eval harness, then extend it with a paraphrase/multilingual tier. Auto-suggested tag chips stay confirmable (suggested → confirmed/rejected), and confirmations accumulate as labeled data for later trained heads.

Explicitly **not**: a new HWF emotion ontology, emotion families/quadrants, TopicCategory absorption, abstractive summarization, or open-vocabulary tags.

## 2. Locked decisions

| Decision | Choice |
|---|---|
| Tag vocabulary | **Existing tags only**: mood/energy/focus (5-level enums), feelings (58), activities (expanded, moved to lexicon), 11 cue categories, meds, sleep, side effects, topics |
| Model | **Apple `NLContextualEmbedding`** (built-in BERT, Latin-script model covers EN/PT/ES, OS-downloaded, A14-capable). MiniLM/GLiNER = Gate-0 fallback only. Generative SLM rejected |
| Languages | English first; PT/ES via translated lexicon + seeds + per-language corpus means |
| Summary | Extractive only; quality fixes (bias removal, dedup, title) — no new model |
| Order | **Measure → fix → extend.** No ML work before the eval harness and P0 precision fixes land |
| Device floor | iPhone 12 Pro (A14). Apple Foundation Models hard-excluded (A17 Pro+) |

## 3. Motivating findings (review of 2026-06-13)

**P0:** topics are mock-only (`topicTagsJSON` written only by MockDataGenerator; `SummaryResult` has no topics field) · sentiment negativity bias inflates cue-free sentences past the highlight threshold via `abs(sentiment)×2` (filler bullets, bad titles) · highlight scorer still uses raw substring matching · energy/focus `NLEmbedding` fallback is dead code (gate `d<0.55` vs measured synonym distances 0.82–1.33) burning `words × ~186` distance calls per sentence.

**P1 precision:** common-word lexicon entries fire on non-affective text ("nothing"→flat, "heavy"→low, "empty"→flat, feelings "seen"/"light"/"raw") · mood = first-match in an 85-entry ordered list · past-progressive tense bug ("I was feeling really anxious" → present) · negation checks first substring occurrence, not the matched token position.

**P1 recall:** no lemmatization ("panicking" misses "panicked") · activities hardcoded in extractor source (6 categories, violates lexicon-as-data) · structural paraphrase blindness · PT/ES recall ≈ 0 except meds/doses.

**P2:** no summary redundancy control or coverage slots; title = 6-word mid-clause truncation · compute waste (cue re-tokenization ≈ 550 NLTokenizer allocs/sentence, per-sentence NLTagger).

**P0-meta:** no measurement — 111 unit tests assert crafted-sentence behavior, not precision/recall on realistic speech.

## 4. Phases

| Phase | Work | Exit criterion |
|---|---|---|
| **A — Measure** | Eval harness: 30–50 realistic ADHD-register transcripts (synthetic, reviewed; incl. PT/ES handful) + expected-tag labels; per-category precision/recall runner, CI-runnable; `.userCorrected` rows feed it as they accumulate | Baseline numbers per category committed |
| **B — Fix (P0)** | Delete dead embedding fallback · remove/dampen sentiment term in highlight scoring · tokenized matching in scorer · fix past-progressive tense · guard common-word lexicon entries (require feel-context) · wire topics into `SummaryResult` → `topicTagsJSON` | Eval precision improves, no recall regression; tests green |
| **C — Cheap recall** | Lemma-augmented tokens (NLTagger) before cue matching · activities → `lexicon.json`, expanded · pre-tokenized cue cache · fuzzy med matching (edit distance ≤ 1) | Eval recall improves at held precision |
| **D — Paraphrase + multilingual tier** | **Gate 0:** anisotropy spike (assets, ~500-sentence mean-cosine raw vs centered, cross-lingual sanity; ~1 day, go/no-go). Then: `ContextualEmbeddingClassifier` — per-sentence mean-pooled 512-d vectors, per-language mean-centering, L2-norm, cosine vs prototypes (seeds = existing lexicon entries expanded into natural sentences; PT/ES translated), per-class null-distribution thresholds, top-k ≤ 3 + margin + absolute floor, negation layer in front, `fillOnly` merge (lexicon authoritative). Prototypes computed on-device, cached keyed by (model revision, language, lexicon version) | Gate-0 pass; eval: paraphrase recall up, precision ≥ 0.8 per enabled category; PT/ES ≥ usable baseline |
| **E — Summary quality** | Token-overlap dedup (MMR via embeddings once D lands) · coverage slots (med/mood/sleep) · clause-bounded title + spoken-filler stripping | Side-by-side bullet quality review on eval set |
| **F — Heads (later)** | Per-label logistic/CreateML heads on frozen embeddings, trained on confirmations/rejections (trigger ~25 labels/class); per-label switchover, prototypes stay cold-start | Head beats prototype on held-out corrections |

## 5. Provenance & UX

Tag lifecycle: `suggested (.nlp + confidence) → confirmed (.user/.userCorrected) | rejected (persisted — negative labels for F)`. Lexicon hits stay authoritative; classifier fills gaps. `RecordingTag` is the SSOT for chip display; extraction JSON stays the raw payload. UI: suggested vs confirmed chip states + reject affordance — **HTML mockup before SwiftUI** (house rule). No quadrant grid, no drill-in picker.

## 6. Risks & escalations

| Risk | Mitigation |
|---|---|
| Gate-0 fails (embedding can't separate tags after centering) | Swap encoder to bundled MiniLM-class CoreML (~100MB); architecture unchanged |
| Cross-lingual under-firing PT/ES | Per-language seeds + means + eval slices; ship EN-only if PT/ES misses bar |
| Lexicon guard-rules cut real recall | Eval harness catches it (A before B is non-negotiable) |
| OS embedding revision changes vectors | Caches keyed by revision; background re-embed on bump |
| No assets on first run | Lexicon-only degradation (current behavior) |

## 7. Out of scope

New emotion ontology / families / valence×energy grid · TopicCategory replacement · GLiNER/span extraction · abstractive summaries · open vocabularies · languages beyond EN/PT/ES · Apple Foundation Models.

## Baseline 2026-06-13 (Phases A–C start)

Current extraction pipeline measured against the 40-case labeled eval set (`app-twoTests/Eval/EvalSet.swift`). Micro-averaged P/R per category. Floors set to `max(0, observed − 0.02)` in `EvalFloors`. Topics not scored yet (`deriveTopics` not built).

| Category        | Precision | Recall | tp | fp | fn |
|-----------------|-----------|--------|----|----|----|
| mood            | 0.600     | 0.600  | 9  | 6  | 6  |
| energy          | 0.133     | 0.250  | 2  | 13 | 6  |
| focus           | 0.286     | 0.333  | 2  | 5  | 4  |
| feelings        | 0.714     | 0.625  | 15 | 6  | 9  |
| activities      | 0.222     | 0.143  | 2  | 7  | 12 |
| meds            | 1.000     | 0.933  | 14 | 0  | 1  |
| sleepHours      | 1.000     | 0.286  | 2  | 0  | 5  |
| sideEffectFlag  | 0.750     | 0.429  | 3  | 1  | 4  |

Notes: meds extraction is strong across EN/PT/ES (lexicon-driven). Low activities recall is expected — truth uses final Title-Case category names (incl. new categories like Outdoors/Screen Time) the current pipeline does not yet emit. Energy over-fires (13 fp). PT/ES recall is ~0 outside meds/dose by design.

## Results after Phases A–C + E (2026-06-13)

Same 40-case eval. Branch `feat/nlp-eval-and-precision`. Floors in `EvalFloors` ratcheted to observed − 0.02 throughout.

| Category        | Precision (base→now) | Recall (base→now) | Δ |
|-----------------|----------------------|-------------------|---|
| mood            | 0.600 → **0.750**    | 0.600 → 0.600     | precision +0.15 |
| energy          | 0.133 → **0.667**    | 0.250 → 0.250     | precision +0.53 (dropped function-word "on") |
| focus           | 0.286 → **0.400**    | 0.333 → 0.333     | precision +0.11 |
| feelings        | 0.714 → **0.941**    | 0.625 → **0.667** | P +0.23 (dropped seen/light/raw/alive), R +0.04 (lemma) |
| activities      | 0.222 → **0.300**    | 0.143 → **0.429** | recall ×3 (lexicon-as-data + 5 categories) |
| meds            | 1.000 → 1.000        | 0.933 → **1.000** | fuzzy ASR-typo matching |
| topics          | *(unscored/broken)* → **0.900** | 0 → **0.783** | wired end-to-end (was mock-only) |
| sleepHours      | 1.000 → 1.000        | 0.286 → 0.286     | unchanged |
| sideEffectFlag  | 0.750 → 0.750        | 0.429 → 0.429     | unchanged |

**What moved:** big precision wins on mood/energy/focus/feelings (common-word + function-word guards, longest-match mood, dead-fallback removal), activities recall tripled, meds recall to 1.0, topics fixed from mock-only to a real 0.90/0.78 pipeline. Highlight summaries no longer pad cue-free filler; titles are clause-bounded and filler-stripped (not eval-scored).

**Known residual gaps (Phase D / future):**
- energy/focus/sleepHours **recall** and PT/ES recall remain low — these are the paraphrase + multilingual gaps that exact-match lexicon structurally cannot close. This is precisely Phase D's target (NLContextualEmbedding), pending the Gate-0 spike.
- activities **precision** 0.30 — broad terms ("work"/"email"/"food") co-fire; soft FPs, acceptable for v1, refined by Phase D.
- `"anxious"` is in both `feelings` and `sideEffectCues`, so anxious-mood sentences get a spurious `Symptoms` topic (part of topics fp). Minor; revisit when side-effect vocabulary is split from affect.
- Highlight **dedup does not backfill**: dropping a near-duplicate leaves the slot empty rather than promoting the next distinct sentence. Rare in real speech; Phase-E polish.
