# Phase 0 Research: Emotions Lexicon

## R1 — Rename strategy: identifier vs. user-language surface

**Decision**: Treat the ~335 `feeling` hits as two disjoint populations and only touch the first.

- **Category identifiers** (rename → `emotion(s)`): the `Recording` column, `TagCategory` case, `NoteExtraction` property + Codable key, `lexicon.json` top-level key, extractor/VM/view identifiers, UI header, nudge copy, tests. ~26 app sites.
- **User-language surfaces** (leave verbatim): mood/energy/focus cue phrases that literally contain "feeling" — `feeling down`, `feeling good`, `feeling empty`, `feeling nothing`, `feeling heavy`, `feeling slow`, `feeling lost`, `feeling scattered`, `feeling seen`, `feeling alive`, `feeling light`, `feeling raw`, `woke up feeling human` — plus tense markers (`i'm feeling`, `was feeling`) in `TenseClassifier.swift` and simulated transcripts in `EvalSet.swift`.

**Rationale**: Those phrases are *matched against user speech*; renaming `feeling down` → `emotion down` would silently break **mood** detection. The category named "feelings" and the English word "feeling" appearing inside a mood cue are unrelated.

**Alternatives considered**: a global `sed feelings→emotions` — rejected, it corrupts the mood lexicon and the eval transcripts.

## R2 — Migration: none (wipe-and-rebuild)

**Decision**: Rename the persisted `feelingsJSON` column to `emotionsJSON` with no `@Attribute(originalName:)` and no migration plan; let `AppModelContainer`'s existing schema-conflict path wipe and rebuild the store.

**Rationale**: Constitution IX declares the schema pre-release and recovers conflicts by wiping. The user explicitly accepted tester data loss. `emotionsJSON` stays `String?` (optional) → CloudKit-compatible, no unique/required attribute introduced. Three persisted touchpoints (`feelingsJSON` column, `TagCategory` rawValue `"feelings"`, `NoteExtraction` `"feelings"` Codable key) all reset cleanly on wipe; no legacy-key fallback needed.

**Alternatives considered**: `@Attribute(originalName:)` + legacy-key decode to preserve data — rejected by explicit user decision (accept the wipe), and it would add a compat shim that Constitution III/IV discourage once the wipe is acceptable.

## R3 — Vocabulary source: How We Feel / Mood Meter

**Decision**: Replace the ~60-word feelings list with **exactly 20 emotions**, **5 per quadrant** of the Mood Meter's valence×energy space:

| Quadrant | Valence | Energy | Count |
|---|---|---|---|
| Red | unpleasant | high | 5 |
| Blue | unpleasant | low | 5 |
| Yellow | pleasant | high | 5 |
| Green | pleasant | low | 5 |

The concrete 20 (produced by the citation-backed How We Feel research pass — 11 agents, 8 sources, per-quadrant adversarial verification) are recorded authoritatively in [contracts/emotions-lexicon.md](contracts/emotions-lexicon.md):

- 🟡 **Yellow** (pleasant·high): excited, joyful, proud, thrilled, inspired
- 🔴 **Red** (unpleasant·high): angry, anxious, frustrated, irritated, jealous
- 🟢 **Green** (pleasant·low): content, grateful, peaceful, secure, serene
- 🔵 **Blue** (unpleasant·low): sad, lonely, disappointed, hopeless, discouraged

Verifier replacements vs. the first draft: `hopeful → thrilled`, `relaxed → serene`, `gloomy → hopeless`.

**Rationale**: The How We Feel app (How We Feel Project, Ben Silbermann + Dr. Marc Brackett / Yale Center for Emotional Intelligence) organizes emotions on the Mood Meter, itself Russell's circumplex (valence × arousal). A quadrant-balanced 20 gives recognizable, scientifically-grounded coverage without the sprawl of 60.

**Alternatives considered**: Ekman's 6 basic emotions (too coarse — no gratitude/pride/contentment a journal user reaches for); Plutchik's 8 + dyads (richer but unbalanced for a flat picker); keeping 60 (the sprawl the user is removing).

## R4 — Exclusions: defer to the app's other axes

**Decision**: The 20 MUST NOT include states the app already captures elsewhere:

- **Energy axis** owns: `exhausted, energised, wired, recharged, restless, tired` → excluded.
- **Mood axis / cognitive states**: `indifferent, curious, reflective, motivated, uncertain, absorbed` → excluded (mood valence or focus/cognition, not discrete emotion).
- **Clinical idioms** from the old list (`dysregulated, touched out, on edge`) → excluded as non-emotion idioms; if desired later they return via the **personal overlay**, not the curated default.

**Rationale**: SC-003 — no emotion may duplicate a mood/energy/focus state. The Mood Meter's *energy* dimension is only a **selection** aid here; it is not a new stored field, because the app already has an energy axis.

## R5 — Eval re-pointing (Constitution VII gate)

**Decision**: For every `EvalSet` sample whose expected `feelings:` includes a now-dropped word, re-point it to a curated emotion that the transcript actually supports, or drop that expectation if the transcript better fits another axis. Rename the eval category `feelings` → `emotions` and its floor constant. Then run the eval; the emotions precision/recall floors must hold or improve.

**Rationale**: Constitution VII forbids regressing tracked floors and requires running the harness on any extraction change. Re-pointing keeps the floors *meaningful* (a sample asserting a deleted word would otherwise trivially fail or be removed, hiding regressions).

**Alternatives considered**: lowering the floors to pass — rejected (masks regression). Deleting affected samples — rejected where the transcript still legitimately expresses a curated emotion.

## R6 — Test-first ordering (Constitution X)

**Decision**: Sequence per the constitution: update/add the failing tests (RED) for the `NoteExtraction` rename + decode, `LexiconData`/`Lexicon` default vocabulary, `NLNoteExtractor` detection of the new words + non-detection of dropped words, and `ExtractionReviewViewModel`, before the implementation that turns them green. SwiftUI label/nudge changes are verified by build + simulator run (views exempt).
