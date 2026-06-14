# NLP Extraction — Analysis & Findings

**Date:** 2026-06-11
**Scope:** Logic only (no View/UI). On-device NaturalLanguage extraction pipeline.
**Status:** Analysis complete. Nothing changed in code. Implementation plan in the companion file `2026-06-11-nlp-extraction-implementation-plan.md`.

---

## 1. How the pipeline works today

**Flow:**

```
Whisper transcript
  → ProcessingViewModel.run()                     (@MainActor)
  → NLSummarizationService.summarize()            (adapter)
  → NLNoteExtractor.extract()                     (the engine)
  → SummaryResult                                 (Sendable DTO)
  → Recording.applySummary()                      (scalars + JSON blobs)
  → Recording.setMedicationEvents()               (SwiftData rows)
  → store.save() → NotificationCenter ping        (med bar / calendar refresh)
```

`NLNoteExtractor.extract()` is a single synchronous pass:

1. **Sentence split** via `NLTokenizer`, dropping sentences ≤ 3 chars.
2. **Per sentence:**
   - Apple sentiment score (`NLTagger`, `.sentimentScore`).
   - Mood / energy / focus via a two-stage hybrid: lowercase `contains()` against `Lexicon` seed lists first, then an `NLEmbedding` word-distance fallback (threshold 0.55).
   - Cue scans for ~12 categories (side effects, tasks completed/avoided, wins, overwhelm, exec dysfunction, stimming, physical side effects, rebound, appetite loss/return), each appending the **whole sentence**.
   - Medication matching against ~60 brand/generic names.
3. **Negation** (`isNegatedBefore`): any of `not / never / no / n't / without / forgot / missed / skipped` within a 5-word window before the cue (1-word window for "no") flips mood/energy/focus or sets `MedEvent.taken = false`.
4. **Aggregation:** mood = candidate with min embedding distance; energy/focus = plain overwrite per matching sentence; valence = mean sentiment.
5. **Whole-text regexes** (`ADHDRegexPatterns`): dose, sleep hours, onset, duration, crash time, intake context — first match wins.
6. **Highlights:** sentences re-scored (sentiment magnitude + cue bonuses); title = first 6 words of top highlight.

**Persistence is dual:** scalar columns (`mood`, `energyLevel`, `sleepHours`, …) for queries/UI **plus** `noteExtractionJSON` and sibling JSON blobs for full fidelity. These can drift (see Bug 12).

---

## 2. Mood events vs. medication events — together & separate

Two different species that meet only in the calendar:

| Aspect | Mood | Medication |
|---|---|---|
| Storage | Attribute of `Recording` (string column + copy in `noteExtractionJSON` + a `RecordingTag` on review-confirm) | First-class `MedicationEvent` SwiftData row |
| Time | None of its own — lives at `recording.createdAt` | Resolved once at save via `resolvedTakenAt` (HH:mm → fuzzy label → `createdAt` fallback) |
| Cardinality | One per note (no intra-day history) | Many per day; `source` = `.manual` (bar tap, `recording == nil`) or `.transcript` (cascade-deleted with its recording) |
| On re-summarize | Overwritten in place | Transcript rows **deleted + recreated** (new UUIDs); manual rows untouched |

- **They join only by timestamp proximity** in `DayTimelineBuilder`: nodes grouped by *exact* `Date` equality. A transcript dose with no spoken time shares its recording's node; a "this morning" dose resolves to 08:00 → a *separate* node from its source recording.
- **Sync is NotificationCenter**, not SwiftData observation: `RecordingStore.save()` posts `medicationEventsDidChange` on *every* save; med bar + mood library re-fetch.
- **The analytical join does not exist yet.** Nothing correlates mood with active dose windows (e.g. mood 2h post-intake vs. rebound window). The model supports it (`createdAt` × `takenAt` + `durationHours`); it's a read-side feature waiting to be built — the natural payoff of the tiered NL+LLM idea.

---

## 3. Bugs (verified against code, none fixed)

### High — wrong data stored or shown

1. **Duplicate med events from overlapping names.** `Lexicon` has "Concerta" + "Concerta XL", "Adderall"/"Adderall XR", "amphetamine"⊂"dextroamphetamine". `extractMedications` appends one event per matching name → "took my Concerta XL" persists **two** doses → bar shows "dose 2 of 2", timeline draws double rings.
   `NLNoteExtractor.swift:497-511`, `Lexicon.swift:142-161`
2. **"skipped/forgot/missed" near a med marks it not-taken.** Negation tokens are shared across all categories. *"I skipped lunch and took my Concerta"* → `taken = false`.
   `NLNoteExtractor.swift:337-354`, `Lexicon.swift:337-339`
3. **`detectMedChange` stop-terms include "finished".** *"took my Vyvanse and finished the report"* → `change = .stopped`.
   `NLNoteExtractor.swift:515`
4. **Hard-coded `defaultDose = "36mg"`.** Every dose without an extracted mg shows Concerta's 36mg — wrong for Vyvanse/Strattera.
   `MedicationEvent.swift:14`
5. **Custom titles destroyed on review-confirm.** `applySummary` unconditionally overwrites `title`; `confirm()` only restores it if the name field changed *in that sheet*. Confirming without touching the name wipes a previously renamed note.
   `Recording.swift:189-196`, `ExtractionReviewViewModel.swift:171-181`
6. **Whole extraction runs on the main thread.** Target sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` → extractor/service are MainActor-inferred. Sentence loops, double sentiment passes, embedding-distance loops, per-call regex compiles all block the UI. No cancellation point inside `extract()`, so `cancelProcessing()` can't interrupt it.
   `project.pbxproj:491`, `NLNoteExtractor.swift:22-303`, `ProcessingViewModel.swift`

### Medium — silent misclassification

7. **Substring matching fires inside words** (systemic). Energy cue `"on"` matches almost every sentence; `"fine"`⊂"finished", `"meh"`⊂"somehow", `"win"`⊂"window", `"done"`⊂"abandoned", `"rest"`⊂"restless", `"tense"`⊂"intense", `"content"`⊂"discontent".
   `Lexicon.swift:208` and throughout
8. **Mood = first match, not strongest.** All substring matches carry distance 0.0; `min(by:)` keeps the first. *"I'm okay I guess. Honestly, rock bottom."* → "okay". Energy/focus use the opposite (last-sentence-wins). Neither is deliberate.
   `NLNoteExtractor.swift:260-261`
9. **Four mood lists are dead.** `moodPositive/moodNegative/moodIrritable/moodFlat` are never read by the extractor (only `moodSpecific` drives mood). Root cause of most of the 11 failing mood tests (`detectsHappy`, `detectsAnxious`, `detectsIrritable`…). Two assertions are *also* wrong: `detectsAccomplished` expects "low" for "I nailed it"; `detectsZonedOut` expects "low" where "flat" is designed.
   `Lexicon.swift:163-200`, `NLNoteExtractorMoodTests.swift:30-33,72-75`
10. **Punctuation defeats negation and embeddings.** Words split on spaces only → "not," ≠ "not"; `distance("tired,", …)` misses. Multi-word seeds ("hit a wall", "no spoons") can never match in the word-embedding fallback — silent dead vocabulary.
    `NLNoteExtractor.swift:68,337-354,466-477`
11. **Sentence-scoped med attributes.** *"Concerta 36mg and Strattera 40mg"* → both get 36mg (first dose regex in sentence). "half an hour" → `quantity = 0.5` ("half a"⊂"half an"). `NSDataDetector` grabs first time in sentence even if unrelated to the med.
    `NLNoteExtractor.swift:497-536,550-574`
12. **Review-confirm drift.** `confirm()` (a) passes `durationHours: nil` → all med windows reset to 10h; (b) keeps the *original* `noteExtraction` JSON while scalars change → `decodedNoteExtraction` disagrees with columns; (c) sets `recording.createdAt = date` *after* `setMedicationEvents` resolved times against the old date → editing date strands meds on previous day.
    `ExtractionReviewViewModel.swift:153-210`
13. **Cross-listed vocabulary double-counts.** "anxious"/"irritable"/"tense" are simultaneously feelings, mood words, *and* side-effect cues → "I'm anxious about the meeting" yields a medication-side-effect tag. "crash" is in energy + side effects + rebound.
    `Lexicon.swift` (multiple)
14. **Loose sleep/onset fallback.** In a sleep-keyword sentence, any "N hours" matches → "couldn't sleep, worked 12 hours" → 12h sleep. Onset regex verb "took" → "took 2 hours to fall asleep" → `onsetMinutes = 120`.
    `NLNoteExtractor.swift:578-587`, `ADHDRegexPatterns.extractOnsetMinutes`

### Low — dead code & hygiene

15. **`MedicalTermCorrector` has zero call sites** (grep-verified). Two entries are dangerous if ever wired: "executive function"→"executive dysfunction" corrupts legitimate speech; "CBD"→"CBT" rewrites a real substance.
    `MedicalTermCorrector.swift`
16. **Dead regexes & never-filled fields.** `extractTimeEvent`, `extractSeverity` (also has the `(\d|10)` alternation bug — captures "1" from "10"), `extractSleepLatency` are uncalled. `SleepEvent.bedtime/wakeTime/latencyMinutes` are never populated.
17. **Misc hygiene.** Stale doc comment "dark/low/flat/okay/good/high" (`NoteExtraction.swift:5`); orphan `"alert"` mood case in `moodColor`; comment says "prefer shorter" while code keeps *longer* match (code right, comment wrong) `NLNoteExtractor.swift:456-457`; sentiment computed twice per sentence; `NLEmbedding` reloaded per `extract()`; med-bar 24h fetch cutoff hides >24h windows; `save()` broadcasts on every save.

---

## 4. Open questions (drive the plan)

1. **Mood aggregation policy** when a note swings ("okay… then rock bottom"): worst / last / dominant?
2. **Vocabulary home:** bundled JSON (PR-reviewable) vs. SwiftData (in-app editable) as primary, with the other layered?
3. **Med matching scope:** full ~60-name catalog vs. prefer the user's own configured meds (catalog as fallback)?
4. **Portuguese** on the roadmap (dead `pt` table in the corrector) or drop it?

---

## 5. Cross-references

- `[[idea-user-correction-learning]]` — the `RecordingTag .userCorrected` provenance already written by `ExtractionReviewViewModel.confirm()` is the seed for a personal lexicon (P2).
- `[[idea-tag-provenance]]` — tag source/confidence model aligns with the match-provenance refactor (P1).
- `[[idea-nl-llm-tiered-pipeline]]` — P3; the mood × dose-window join is its first concrete feature.
- `[[project-topic-tags-fix]]` — related persistence/display-tag work.
- `[[test-debt-followups]]` — the 11 failing mood tests are resolved by Bug 9 fixes.
