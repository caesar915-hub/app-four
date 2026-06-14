# NLP Extraction — Implementation Plan

**Date:** 2026-06-11
**Companion:** `2026-06-11-nlp-extraction-analysis.md` (findings + bug numbers referenced below).
**Method:** TDD against the existing `app-twoTests` suite. Each phase ends green + committed before the next.
**Constraint:** Logic only. No View/UI changes except where a ViewModel bug forces it.

---

## Execution model — should we swarm Sonnet subagents?

**Short answer: sequential for P0/P1, swarm only P2 content.**

| Phase | Parallelizable? | Why |
|---|---|---|
| **P0 correctness** | ❌ No | All fixes touch the same 2–3 files (`NLNoteExtractor.swift`, `Lexicon.swift`, `ExtractionReviewViewModel.swift`) and are logically chained (negation depends on tokenization depends on the match engine). Parallel worktree agents would conflict; coordination cost > speedup. |
| **P1 engine refactor** | ❌ No | A single re-architecture of one engine. Inherently one author. |
| **P2 vocabulary content** | ✅ **Yes** | Generating lexicon entries by category (feelings, ADHD slang, med variants, sleep phrases) is genuinely disjoint — each agent owns a non-overlapping slice of a data file. **This is the one place a Sonnet swarm earns its cost.** |
| **P3 tiered LLM** | Partial | Design is sequential; eval-set generation could fan out later. |

**Recommended split:**

- **P0 + P1:** I implement sequentially, TDD, on a feature branch. Cheapest path to correct + reviewable.
- **P2:** one `Workflow` run, `parallel()` over ~5 vocabulary categories, each a `model: 'sonnet'` agent returning a structured JSON slice (canonical + variants + matchMode + weight). I merge, dedupe, and validate against the new schema. Worktree isolation **not** needed (they return data, I write the file once).

This is the honest call: swarms shine on independent fan-out, and P0/P1 are a dependency chain, not a fan-out.

---

## Branch & checkpoints

```
git checkout -b nlp-extraction-hardening
```

Commit after every phase. Run the test suite at each checkpoint. Do **not** merge until P0 + P1 are green and the 11 known-failing mood tests are resolved (fixed code or corrected assertions, documented).

---

## P0 — Correctness fixes (no architecture change)

**Goal:** stop storing/showing wrong data. Smallest diffs that fix the High bugs + the cheap Mediums.

### P0.1 — Word-boundary matching (Bugs 7, 10)

The systemic flaw. Replace `lower.contains(cue)` with boundary-aware matching.

- Add a private helper in `NLNoteExtractor`:
  ```swift
  // Tokenize the sentence ONCE into lowercased, punctuation-stripped tokens.
  // Single-word cues match by token-set membership; multi-word cues match by
  // contiguous token subsequence. No more substring-inside-word false hits.
  ```
- Tokenize via `NLTokenizer(unit: .word)` (handles "n't", hyphens correctly) → `[String]` of lowercased tokens, plus a normalized joined string for phrase checks.
- Single-word cue → `tokenSet.contains(cue)`. Multi-word cue → contiguous subsequence match over the token array.
- **Tests first:** add `NLNoteExtractorMatchingTests` — "I opened the window" ⇒ no win; "London was nice" ⇒ no energy=alert; "I finished the report" ⇒ no mood=okay from "fine"; "feeling restless" ⇒ no activity=Resting.

### P0.2 — Negation scoping (Bugs 2, 10)

- Strip punctuation before building the negation window (reuse P0.1 tokens).
- **Remove `forgot / missed / skipped` from the generic `negationTokens` list.** Keep `not / never / no / n't / without`.
- Re-introduce `forgot/missed/skipped` as a **medication-only "not taken" signal**, required within the med's own clause (same sentence AND within N tokens of the med mention, not just anywhere before it).
- **Tests:** "I skipped lunch and took my Concerta" ⇒ Concerta `taken == true`; "I forgot my Concerta" ⇒ `taken == false`; "I'm not happy" ⇒ mood low (unchanged).

### P0.3 — Medication de-duplication & attribute scoping (Bugs 1, 3, 11)

- In `extractMedications`: after collecting raw name hits, collapse overlapping matches — **longest canonical name wins per text span** ("Concerta XL" suppresses "Concerta"; "dextroamphetamine" suppresses "amphetamine").
- Scope `dose / time / quantity / change` to the **span around each med mention** (a window of tokens), not the whole sentence. Two meds in one sentence get their own nearest dose/time.
- Tighten `detectMedChange`: drop bare "finished"; require change verbs adjacent to the med clause. Drop the "half a"⊂"half an" quantity false-positive (require a word boundary / unit word).
- **Tests:** "took my Concerta XL 36mg" ⇒ exactly 1 event, "Concerta XL", 36mg; "Concerta 36mg and Strattera 40mg" ⇒ two events with correct distinct doses; "took Vyvanse and finished the report" ⇒ change == nil.

### P0.4 — Dose defaults (Bug 4)

- Remove the hard-coded `defaultDose = "36mg"` from `MedicationEvent` (both the stored default and the init default). Default to `nil`.
- UI shows dose only when known (a ViewModel/display tweak may be needed where `effectiveDose` is read — minimal, flagged as the one allowed UI touch).
- **Test/where read:** grep `effectiveDose`; assert a Vyvanse manual log with no dose shows no "36mg".

### P0.5 — Review-confirm correctness (Bugs 5, 12)

In `ExtractionReviewViewModel.confirm()` and `Recording.applySummary()`:
- **Title precedence:** user edits always win. `applySummary` should not overwrite a user-set title; gate the "Mood · Energy · Focus" auto-title behind "title is still the generated one". Track an explicit `userDidSetTitle` rather than comparing to `originalTitle` of the current sheet.
- **Resolve med times against the NEW date:** set `recording.createdAt = date` **before** `setMedicationEvents`, or pass `date` into the resolver.
- **Rebuild `noteExtractionJSON` from corrected scalars** so `decodedNoteExtraction` can't disagree with the columns (or stop persisting the redundant copy — see P1.4).
- Pass a real `durationHours` (carry the original extraction's, or per-med default) instead of `nil`.
- **Tests:** rename a note, regenerate without touching name ⇒ title preserved; edit date in review ⇒ med `takenAt` lands on the new day; edit mood in review ⇒ `decodedNoteExtraction.mood` matches the column.

### P0.6 — Loose regex fallbacks (Bug 14)

- Sleep-hours fallback: require a sleep-duration phrase ("slept N", "got N hours of sleep"), not any "N hours" in a sleep-keyword sentence.
- Onset regex: drop the bare "took" verb (it collides with sleep latency) or require "kick(s) in / kicked in / onset".
- **Tests:** "couldn't sleep, worked 12 hours" ⇒ sleepHours == nil; "took 2 hours to fall asleep" ⇒ onsetMinutes == nil (and, once P2 wires it, latency == 120).

### P0.7 — Dead mood lists + failing tests (Bugs 8, 9)

- **Decide aggregation policy** (open question 1) — default recommendation: **worst-mood-wins** for the note's headline mood, since this is a clinical/ADHD journal where the low point matters. Replace `min(by: distance)` with a policy function.
- Wire the dead `moodPositive/moodNegative/moodIrritable/moodFlat` vocabulary into mood detection (fold into `moodSpecific` or consume directly) so `detectsHappy/Anxious/Irritable` pass.
- Fix the two genuinely wrong assertions: `detectsAccomplished` ("nailed it" is a **win/positive**, not "low"); `detectsZonedOut` ("zoned out" → **flat**, not "low"). Document the correction inline.
- **Outcome:** the 11 known failures (`[[test-debt-followups]]`) go green.

**P0 exit criteria:** full suite green; the new matching/negation/med tests pass; manual smoke of a multi-med, mood-swing, edited-title transcript looks right.

---

## P1 — Engine hardening (one-author refactor)

**Goal:** make the engine correct *by construction* and move it off the main thread.

### P1.1 — One match engine with provenance

Replace the ~12 copy-pasted `for cue in … { if contains … break }` loops with a single matcher returning `[CueMatch]` where:
```swift
struct CueMatch { let category: Category; let cue: String; let tokenRange: Range<Int>; let sentenceIndex: Int; let negated: Bool }
```
Every category derives from this one list. Eliminates order-dependency, the duplicated negation calls, and the cross-list double-count surface (Bug 13 is then a *vocabulary* decision — see P2 — not a code accident). Aligns with `[[idea-tag-provenance]]`.

### P1.2 — Explicit aggregation policies

Per signal, a named policy: mood = worst-wins (P0.7), energy/focus = strongest-match-wins (not last-sentence-wins), valence = mean. Documented and unit-tested with multi-sentence inputs.

### P1.3 — Concurrency & performance (Bug 6)

- Make `NLNoteExtractor` / `NLSummarizationService` `nonisolated` and run `extract()` off the main actor (it's pure over value types — `Lexicon` is `Sendable`). Under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, mark the extraction entry point `nonisolated` so it hops to the global executor; `ProcessingViewModel` awaits it without freezing the UI.
- Add cooperative cancellation: `try Task.checkCancellation()` between sentences so `cancelProcessing()` works.
- Cache `NLEmbedding.wordEmbedding(for: .english)` once (static, lazy). One `NLTagger` reused. Pre-compile all regexes as `static let`. Compute sentiment **once** per sentence (Bug 17) and reuse in highlights.
- **Tests:** a `swift-concurrency-pro` pass; a timing sanity check (large transcript) is optional/manual.

### P1.4 — Persistence single-source-of-truth (Bug 12 root)

Decide: keep scalars as the source of truth and **derive** display from them, OR keep the JSON and derive scalars. Recommendation: **scalars are canonical**; `noteExtractionJSON` stores only fields without a column (activities, valence, triage arrays). Removes the drift class entirely.

**P1 exit criteria:** suite green; concurrency review clean; no UI jank on a 3-minute transcript; no scalar/JSON drift possible.

---

## P2 — Vocabulary as data (**Sonnet swarm here**)

**Goal:** lexicon becomes a bundled, reviewable, growable data file; matching is generic.

### P2.1 — Schema

```jsonc
{
  "category": "mood",
  "canonical": "anxious",
  "label": "low",          // or level for energy/focus
  "variants": ["anxious", "on edge", "wound up", "panicky"],
  "matchMode": "phrase",   // word | phrase | substring
  "weight": 1.0,
  "excludeFromCategories": ["sideEffect"]  // resolves Bug 13 cross-listing explicitly
}
```
Loader builds the typed `Lexicon` from the bundle (keep the `Lexicon(...)` init for tests — only the *defaults* move to data).

### P2.2 — Swarm to generate content

One `Workflow`, `parallel()` over disjoint slices, each `model: 'sonnet'`:
- feelings granularity (expand the 28),
- energy/focus paraphrases,
- ADHD-community slang (doom-scrolling, doom piles, waiting mode, time blindness, RSD, masking, spoons, hyperfixation vs hyperfocus),
- medication variants + Whisper-isms (fold the salvageable `MedicalTermCorrector` entries in as `variants`; **drop** the dangerous "executive function"→"dysfunction" and "CBD"→"CBT" rewrites),
- sleep bedtime/wake/latency phrases (to finally populate `SleepEvent.bedtime/wakeTime/latencyMinutes`, wiring the dead regexes — Bug 16).

Each returns validated JSON against the P2.1 schema; I merge + dedupe + commit the single data file. No worktree isolation (agents return data, not edits).

### P2.3 — Personal lexicon overlay

SwiftData-backed personal terms, seeded from the `RecordingTag(source: .userCorrected)` rows already written in `confirm()`. Layered over the bundled base at load. Delivers `[[idea-user-correction-learning]]` for free.

### P2.4 — Cleanups folded in

Delete `MedicalTermCorrector` (or repurpose into variants); remove dead `extractTimeEvent`/`extractSeverity`/`extractSleepLatency` or wire them; fix the `(\d|10)` alternation if `extractSeverity` is kept; remove the orphan `"alert"` mood case and stale doc comments (Bug 17).

**P2 exit:** lexicon loads from data; swarm-generated content reviewed in the PR diff; personal overlay tested; dead code gone.

---

## P3 — Tiered NL + LLM (future, separate plan)

Per `[[idea-nl-llm-tiered-pipeline]]`: keep NL for instant per-note extraction; Apple Foundation Models via `BGProcessingTask` for daily/weekly aggregation. **First concrete feature: the mood × active-dose-window join** (Section 2 of the analysis) — the model already supports it via `createdAt` × `takenAt` + `durationHours`. P1 provenance + P2 lexicon make its prompts and eval set far stronger. Defer until P0–P2 land.

---

## Decisions — RESOLVED 2026-06-11

1. **Mood aggregation: PRESENT-TENSE WINS** (supersedes worst/last/dominant). Detect past vs. present
   per sentence and pick the *present* mood as the headline; past-tense moods are context, not the headline.
   - Signal: `NLTagger` lexical class + cue lists. Present markers: "I feel / I am / I'm / right now /
     today / currently / now" + present-tense verbs. Past markers: "I was / felt / earlier / this morning /
     by evening / yesterday" + past-tense verbs.
   - Examples: "started okay... by evening I'm at rock bottom" → **low** (present). "This morning I was a
     mess but now I feel okay" → **okay** (present). Tie / all-past → fall back to most-recent sentence.
   - Implementation: each `CueMatch` (P1.1) gains a `temporalWeight` (present=1.0, neutral=0.5, past=0.2);
     the mood policy is `argmax(temporalWeight, then recency)`, replacing `min(by: distance)`.
   - **This raises P0.7 from "wire dead lists" to "wire dead lists + add tense detection."** Adds a
     `TenseClassifier` helper + tests for swing sentences.
2. **Vocabulary home: JSON base + SwiftData personal overlay.** (P2.1/P2.3 as written.)
3. Med matching: *still open* — default **prefer user's configured meds, catalog fallback**. Not blocking P0.
4. Portuguese: *still open* — default **drop** the dead `pt` path. Not blocking P0.

**Starting now:** P0.1 → P0.2 → P0.3 (matching, negation, med dedup) on branch `nlp-extraction-hardening`.
These don't depend on the still-open items. Tense detection lands with P0.7 / P1.
