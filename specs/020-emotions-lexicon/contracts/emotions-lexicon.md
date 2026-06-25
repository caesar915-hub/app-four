# Contract: Emotions Lexicon (the 20)

This is the **single source of truth** for the emotions word-list. It is mirrored into:
- `app-four/Resources/lexicon.json` → top-level `"emotions"` array (superset, all 20).
- `app-four/Services/NoteExtraction/Lexicon.swift` → `Lexicon.defaultEmotions` (curated default, same 20).

## The 20, by Mood-Meter quadrant (5 each)

| Quadrant | Valence × Energy | Emotions |
|---|---|---|
| 🟡 Yellow | pleasant · high | `excited`, `joyful`, `proud`, `thrilled`, `inspired` |
| 🔴 Red | unpleasant · high | `angry`, `anxious`, `frustrated`, `irritated`, `jealous` |
| 🟢 Green | pleasant · low | `content`, `grateful`, `peaceful`, `secure`, `serene` |
| 🔵 Blue | unpleasant · low | `sad`, `lonely`, `disappointed`, `hopeless`, `discouraged` |

**Flat array (lexicon order, lowercase):**

```json
["excited","joyful","proud","thrilled","inspired","angry","anxious","frustrated","irritated","jealous","content","grateful","peaceful","secure","serene","sad","lonely","disappointed","hopeless","discouraged"]
```

## Provenance

The Mood Meter (Yale Center for Emotional Intelligence / Dr. Marc Brackett, the model behind the How We Feel app — 144-word grid) is a 2×2 of **valence × energy**, a direct application of **Russell's circumplex model of affect**. The 20 are drawn from / consistent with that grid, balanced 5 per quadrant, verified per-quadrant against authoritative sources.

Three verifier replacements vs. an initial draft: `hopeful → thrilled` (hopeful's arousal is ambiguous on the high-energy axis), `relaxed → serene` (relaxed names the energy axis, not a discrete emotion), `gloomy → hopeless` (gloomy is a diffuse mood metaphor).

Sources:
- [The How We Feel App — Yale School of Medicine](https://medicine.yale.edu/news-article/the-how-we-feel-app-helping-emotions-work-for-us-not-against-us/)
- [How We Feel app (144-word Mood Meter) — Marc Brackett](https://marcbrackett.com/how-we-feel-app-3/)
- [What is the Mood Meter — The Mood Meter](https://www.themoodmeter.com/what-is-the-mood-meter/)
- [Green Quadrant (serene, relaxed, content) — The Mood Meter](https://www.themoodmeter.com/green-quadrant-of-the-mood-meter-meaning-examples-and-management-strategies/)
- [Mood Meter origins / circumplex basis — The Mood Meter](https://www.themoodmeter.com/how-the-mood-meter-improves-emotional-intelligence-history-and-benefits/)
- [Circumplex Model of Arousal and Valence — Psychology Fanatic](https://psychologyfanatic.com/circumplex-model-of-arousal-and-valence/)
- [Mood Meter blue-quadrant grid (sad, discouraged, hopeless, lonely) — Psychology Spot](https://psychology-spot.com/mood-meter-ruler-template/)
- [Russell's Circumplex Models — Psychology of Human Emotion (PSU, open access)](https://psu.pb.unizin.org/psych425/chapter/circumplex-models/)

## Exclusions (NOT in the list — owned by other axes or not discrete emotions)

- **Energy states** (app's energy axis): `exhausted`, `energised`, `wired`, `recharged`, `restless`, `tired`, `drained`, `sleepy`.
- **Mood / arousal descriptors that restate an axis**: `calm`, `relaxed`, `chill`, `mellow`, `down`, `restless`.
- **Cognitive / attentional / motivational** (focus/mood, not emotion): `indifferent`, `curious`, `reflective`, `motivated`, `apathetic`, `absorbed`, `uncertain`.
- **Clinical idioms** (may return later via the personal overlay only): `dysregulated`, `touched out`, `on edge`.

## Surface forms (matching)

Each of the 20 is matched as a **single lowercase whole token** — no synonyms, no inflection bridges, and no substring fragments (Constitution VII; `CueMatcher.canonicalInflections` is empty — none of the 20 needs a hand-bridged surface). No multi-word cue phrases are introduced, and surface-form expansion (e.g. mapping "anxiety"→"anxious") is deferred to the backlog. **The pre-existing mood cue-phrases containing "feeling" are untouched.**

## Eval re-pointing map (old expected word → action)

Old `EvalSet` emotion expectations that reference a dropped word must change:

| Old expected | In new 20? | Action |
|---|---|---|
| `proud`, `content`, `grateful`, `anxious`, `sad` | ✅ yes | keep |
| `overwhelmed` | ❌ | re-point to `anxious` (red, the transcript's high-energy unpleasant sense) or drop if better served by another axis |
| `indifferent` | ❌ | drop expectation (cognitive/mood state — not an emotion) |
| `curious` | ❌ | drop expectation (cognitive state) |
| `restless` | ❌ | drop expectation (energy axis) |
| `recharged`, `exhausted` | ❌ | drop expectation (energy axis; energy field still asserted) |
| `motivated` | ❌ | drop expectation (motivational state) |

Re-pointing keeps the emotions precision/recall floors meaningful (Constitution VII); the floors must not regress after the change.
