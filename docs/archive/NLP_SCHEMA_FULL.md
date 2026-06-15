> **⚠️ HISTORICAL SNAPSHOT — superseded.** Frozen 2026-06-15. Pre-app-four (WhisperNotes/app-two era); does not reflect current project state. Current architecture lives in the Notion `app-two` DB, [docs/BACKLOG.md](../BACKLOG.md), and [docs/DEVLOG.md](../DEVLOG.md). Any "Gemma" mention is historical — Gemma was removed before the app-four fork.

# NLP Data Schema — Complete Reference

> Every data structure, lexicon word, regex pattern, and mapping in the WhisperNotes NLP pipeline.

---

## 1. Data Flow

```
Transcript (String)
    ↓
NLNoteExtractor.extract(from:) → NoteExtraction
    ↓
NLSummarizationService.summarize() → SummaryResult
    ↓
Recording.applySummary(_:) → Recording (SwiftData)
```

---

## 2. Core Output Model — `NoteExtraction`

```swift
public struct NoteExtraction: Sendable, Codable, Equatable {
    // MARK: State
    var mood: String?               // mapped MoodLevel rawValue
    var moodValence: Double?        // -1.0 → +1.0 (NLTagger sentiment)
    var energy: EnergyLevel?        // .sluggish | .tired | .steady | .alert | .charged
    var focus: FocusLevel?          // .foggy | .distracted | .present | .sharp | .lockedIn
    var feelings: [String]          // 28 discrete emotions
    var activities: [String]        // 6 activity categories

    // MARK: Medication
    var medications: [MedEvent]     // full parsed med events
    var sideEffects: [String]       // full sentences containing side effects

    // MARK: Symptoms & behaviour
    var executiveDysfunction: [String]
    var physicalStim: [String]
    var physicalSideEffects: [String]
    var reboundTerms: [String]
    var appetiteLoss: [String]
    var appetiteReturn: [String]

    // MARK: Tasks & wins
    var tasksCompleted: [String]    // full sentences
    var tasksAvoided: [String]      // full sentences
    var wins: [String]              // full sentences
    var overwhelm: [String]         // full sentences

    // MARK: Sleep
    var sleep: SleepNote?           // mentioned, hours, quality

    // MARK: Structured regex extractions
    var extractedDose: String?      // e.g. "36mg XL"
    var sleepHours: Double?         // from regex (overrides SleepNote.hours)
    var onsetMinutes: Int?          // medication onset
    var durationHours: Double?      // medication duration
    var crashTime: String?          // e.g. "crash at 3pm"
    var intakeContext: String?      // e.g. "with breakfast", "empty stomach"

    // MARK: Display
    var highlights: [String]        // top scored sentences (max 5)
    var title: String               // first 6 words of top highlight
}
```

---

## 3. Enums

### `MoodLevel` — 5-point scale

| Case | Value | Subtitle |
|------|-------|----------|
| `.low` | 1 | heavy, muted |
| `.flat` | 2 | neutral, still |
| `.okay` | 3 | steady, fine |
| `.good` | 4 | warm, lifted |
| `.great` | 5 | bright, thriving |

### `EnergyLevel` — 5-point scale

| Case | Value | Subtitle |
|------|-------|----------|
| `.sluggish` | 1 | slow, heavy |
| `.tired` | 2 | low, dim |
| `.steady` | 3 | moderate, stable |
| `.alert` | 4 | awake, ready |
| `.charged` | 5 | electric, on |

### `FocusLevel` — 5-point scale

| Case | Value | Subtitle |
|------|-------|----------|
| `.foggy` | 1 | hazy, drifting |
| `.distracted` | 2 | pulled, unsteady |
| `.present` | 3 | grounded, there |
| `.sharp` | 4 | clear, on track |
| `.lockedIn` | 5 | deep, flowing |

### `SleepLevel` — 5-point scale

| Case | Value | Subtitle |
|------|-------|----------|
| `.restless` | 1 | broken, tossing |
| `.light` | 2 | thin, barely resting |
| `.okay` | 3 | decent, adequate |
| `.good` | 4 | solid, rested |
| `.deep` | 5 | restorative, refreshed |

### `MedEventChange`

| Case | Meaning |
|------|---------|
| `.regular` | ongoing / no change mentioned |
| `.started` | first time / began taking |
| `.stopped` | discontinued / came off |

---

## 4. Sub-Structures

### `MedEvent`

```swift
struct MedEvent: Sendable, Codable, Equatable {
    var name: String                // brand/generic from lexicon
    var dose: String?               // "36mg", "30mg XL"
    var time: String?               // HH:mm 24h (e.g. "10:00")
    var timeLabel: String?          // raw phrasing ("around 10 am", "morning")
    var taken: Bool                 // false when negation detected
    var quantity: Double?           // nil = 1.0; 0.5 = half dose
    var change: MedEventChange?     // .started / .stopped / .regular
}
```

### `SleepNote`

```swift
struct SleepNote: Sendable, Codable, Equatable {
    var mentioned: Bool
    var hours: Double?
    var quality: String?            // "good" | "poor" | "insomnia"
}
```

### `SleepEvent`

```swift
struct SleepEvent: Sendable, Codable, Equatable {
    var mentioned: Bool
    var hours: Double?
    var quality: String?            // "good" | "poor" | "insomnia"
    var bedtime: String?            // raw label ("11pm", "midnight")
    var wakeTime: String?           // raw label ("7am")
    var latencyMinutes: Int?        // time to fall asleep
}
```

---

## 5. Complete Lexicon — All 400+ Words

### 5.1 Medications — 34 brand + 6 generic = 40 names

**Methylphenidate family:**
Concerta, Concerta XL, Ritalin, Ritalin LA, Daytrana, Metadate, Methylin, Aptensio XR, Cotempla XR-ODT, Jornay PM, Quillivant XR, QuilliChew ER, Relexxii, Medikinet XL, Equasym XL

**Amphetamine family:**
Adderall, Adderall XR, Mydayis, Vyvanse, Elvanse, Arynta, Evekeo, Evekeo ODT, Dexedrine, ProCentra, Zenzedi, Xelstrym, Dyanavel XR, Adzenys ER, Adzenys XR-ODT, Dexamfetamine

**Dexmethylphenidate:**
Focalin, Focalin XR, Azstarys

**Non-stimulants:**
Strattera, Atomoxetine, Atoncy, Qelbree, Viloxazine, Intuniv, Guanfacine, Kapvay, Clonidine, Onyda XR

**Off-label / adjunct:**
Wellbutrin, Bupropion, Provigil, Modafinil, Nuvigil, Armodafinil

**Generics:**
methylphenidate, lisdexamfetamine, amphetamine, dextroamphetamine, dexmethylphenidate, serdexmethylphenidate

### 5.2 Mood — 82 mapped words

**Positive (18):**
proud, nailed it, smashed it, crushed it, win, victory, accomplished, productive, got shit done, did the thing, happy, calm, relaxed, content, good, great, optimistic, cheerful

**Negative (13):**
sad, low, down, subdued, empty, depressed, hopeless, overwhelmed, stressed, anxious, worried, ruminating, looping, frustrated, angry

**Irritable (9):**
irritable, irritability, grouchy, snappy, short fuse, angry, frustrated, grumpy, touchy

**Flat (16):**
zombie, zombified, zombie-like, zoned out, lifeless, no personality, flat, emotionless, detached, disconnected, not myself, lost my sparkle, grey, hollow, numb, muted, dulled, robotic

**Specific mapped → label (26 pairs):**

| Word | Maps to |
|------|---------|
| bleak, numb, terrible, awful, destroyed, hopeless, can't go on, heavy, muted, depressed, really sad, feeling down, rock bottom | low |
| flat, meh, hollow, empty, emotionless, zombie, neutral, detached, nothing | flat |
| okay, fine, alright, not bad, so-so, steady mood, getting by | okay |
| warm, lifted, better, pretty good, feeling good, positive | good |
| great, amazing, thriving, bright, fantastic, wonderful, on top of the world, brilliant | great |

### 5.3 Energy — 41 words across 5 levels

**Charged (11):**
charged, electric, energized, wired, buzzing, pumped, on fire, vibing, high energy, unstoppable

**Alert (8):**
alert, awake, ready, on, clear headed, refreshed, perked up, switched on

**Steady (7):**
steady, stable, moderate, baseline, okay energy, normal energy, holding up, managing

**Tired (7):**
tired, fatigued, low energy, dim, wiped out, no spoons, running on empty

**Sluggish (16):**
sluggish, slow, heavy, dragging, lethargic, moving slowly, burnt out, drained, empty, spent, crashed, crashing, hit a wall, sudden fatigue, shutdown, melted down, wiped

### 5.4 Focus — 37 words across 5 levels

**Locked In (9):**
locked in, hyperfocus, hyperfocused, deep focus, in the zone, flow state, tunnel vision, locked on, flowing

**Sharp (8):**
sharp, focused, focus, on task, concentrating, concentration, on track, clear, keeping up

**Present (7):**
present, grounded, here, with it, tuned in, showing up, engaged

**Distracted (9):**
distracted, distractible, can't focus, unable to concentrate, zoning out, spacing out, daydreaming, mind wandering, pulled, unsteady, sidetracked

**Foggy (15):**
brain fog, foggy, hazy, drifting, cloudy, mental haze, fuzzy, can't think straight, jumbled thoughts, groggy, scattered, lost, blank, all over the place, fragmented, jumping around, all over the shop, chaos, mind blank

### 5.5 Feelings — 28 discrete emotions

**Positive (10):**
grateful, hopeful, excited, content, inspired, proud, playful, loved, peaceful, motivated

**Neutral (8):**
curious, reflective, nostalgic, restless, indifferent, bored, uncertain, tense

**Negative (10):**
anxious, sad, frustrated, overwhelmed, lonely, angry, scared, guilty, ashamed, exhausted

### 5.6 Tasks / Wins / Overwhelm — 32 words

**Task completion (12):**
finished, completed, done, checked off, ticked off, wrapped up, got through, got shit done, did the thing, nailed it, smashed it

**Task avoidance (13):**
avoided, avoiding, procrastinated, procrastinating, put off, kept putting off, couldn't start, stuck on, paralyzed by, task paralysis, initiation paralysis, frozen, stuck

**Win cues (12):**
proud, accomplished, win, nailed it, nailed, smashed it, victory, achievement, crushed it, got shit done, did the thing

**Overwhelm (8):**
overwhelmed, too much, drowning, buried, can't keep up, paralyzed, decision fatigue, chaos

### 5.7 Executive Dysfunction — 16 words

executive dysfunction, can't start, task paralysis, initiation paralysis, procrastinating, avoidance, avoiding, stuck, frozen, decision fatigue, can't prioritize, disorganized, time blind, no sense of time, running late, missed deadline, forgot to eat, forgot to drink, body doubling

### 5.8 Side Effects — 25 words

dry mouth, headache, nausea, loss of appetite, insomnia, jittery, heart racing, palpitations, anxious, irritable, moody, crash, stomach ache, dizzy, racing pulse, sweating, clenched jaw, tense, tight shoulders, appetite gone, not hungry, dehydrated, grinding teeth, rebound, wearing off, zombie, emotionless, flat affect, no personality

### 5.9 Physical / Stimming — 21 words

**Physical stim (11):**
fidgeting, bouncing, leg bouncing, tapping, stimming, hand flapping, pacing, can't sit still, skin picking, nail biting, hair pulling

**Physical side effects (14):**
headache, stomach ache, nausea, dry mouth, dizzy, heart racing, racing pulse, palpitations, sweating, clenched jaw, tense, tight shoulders, appetite gone, not hungry, dehydrated, grinding teeth

### 5.10 Sleep — 26 words

**Quality good (7):**
slept well, slept like a rock, good sleep, rested, refreshed, deep sleep, solid sleep

**Quality bad (12):**
slept badly, broken sleep, woke up every hour, nightmares, vivid dreams, overslept, couldn't wake up, tossed and turned, woke up, nightmare, bad sleep, light sleep

**Insomnia (6):**
insomnia, can't sleep, wired at night, racing thoughts at bedtime, took hours to fall asleep, couldn't switch off

### 5.11 Rebound / Crash — 12 words

rebound, medication rebound, wearing off, drop off, steep drop, afternoon crash, evening crash, symptoms flared, rebound irritability, rebound hyperactivity, rebound sadness, worse than usual

### 5.12 Appetite — 14 words

**Loss (8):**
no appetite, food is gross, force eating, forgot lunch, skipped dinner, not hungry, can't eat, appetite gone

**Return (6):**
finally hungry, ravenous, binge ate, crash eating, starving, ate everything

### 5.13 Negation — 8 tokens

not, never, no, n't, without, forgot, missed, skipped

### 5.14 Time of Day — 8 keywords

| Keyword | Normalized |
|---------|-----------|
| morning | morning |
| afternoon | afternoon |
| evening | evening |
| night | night |
| bedtime | bedtime |
| lunch | afternoon |
| breakfast | morning |
| dinner | evening |

### 5.15 Activity Keywords — 6 categories, 35 words

| Category | Keywords |
|----------|----------|
| Resting | resting, relaxing, chilling, laying down, lying down, rest, taking it easy |
| Hobbies | hobby, reading, gaming, drawing, playing, painting, crafting, writing |
| Hanging Out | hanging out, with friends, socializing, party, gathering, meeting up |
| Fitness | gym, running, workout, exercise, walking, jogging, cycling, swimming, yoga |
| Eating | eating, breakfast, lunch, dinner, snack, cooking, meal, food |
| Driving | driving, commuting, in the car, on the bus, on the train, traveling |

---

## 6. Extraction Pipeline — Step by Step

### 6.1 Sentence Splitting
Uses `NLTokenizer(unit: .sentence)`. Sentences < 4 chars are dropped. Falls back to whole text if no sentences found.

### 6.2 Per-Sentence Processing Loop

For each sentence:

| Step | Method | What it does |
|------|--------|-------------|
| 1 | `sentimentScore()` | `NLTagger(.sentimentScore)` → adds to valence average |
| 2 | `nearestMood()` | Exact substring → embedding fallback (distance < 0.55) |
| 3 | `nearestEnergy()` | Exact substring → embedding fallback |
| 4 | `nearestFocus()` | Exact substring → embedding fallback |
| 5 | `extractMedications()` | Substring match on all 40 med names + dose/time/quantity/change |
| 6 | Side effects | Substring match on 25 cues, negation-checked |
| 7 | Sleep detection | Keyword triggers: "sleep", "slept", "woke", "insomnia", "nightmare", "dream", "nap" |
| 8 | Tasks completed | Substring match on 12 cues, negation-checked |
| 9 | Tasks avoided | Substring match on 13 cues, negation-checked |
| 10 | Wins | Substring match on 12 cues, negation-checked |
| 11 | Overwhelm | Substring match on 8 cues, negation-checked |
| 12 | Executive dysfunction | Substring match on 16 cues, negation-checked |
| 13 | Physical stim | Substring match on 11 cues, negation-checked |
| 14 | Physical side effects | Substring match on 14 cues, negation-checked |
| 15 | Rebound terms | Substring match on 12 cues, negation-checked |
| 16 | Appetite loss | Substring match on 8 cues, negation-checked |
| 17 | Appetite return | Substring match on 6 cues, negation-checked |
| 18 | Feelings | Substring match on 28 emotions, negation-checked |
| 19 | Activities | Substring match on 6 categories × 35 keywords |

### 6.3 Negation Logic

```swift
isNegatedBefore(target: String, in text: String) -> Bool
```

- Looks at 5 words before the target
- "no" uses only 1-word window (avoids false negation in "no special energy focus")
- "n't" checks word suffix
- Tokens: `not`, `never`, `no`, `n't`, `without`, `forgot`, `missed`, `skipped`

### 6.4 Flip Tables (when negated)

**Mood flips:**
| Original | Flipped |
|----------|---------|
| anxious | calm |
| calm | anxious |
| happy | sad |
| sad | happy |
| motivated | frustrated |
| frustrated | motivated |
| stressed | calm |
| overwhelmed | calm |
| proud | disappointed |
| accomplished | stuck |
| irritable | calm |
| flat | engaged |
| empty | fulfilled |

**Energy flips:** charged→sluggish, alert→tired, steady→tired, tired→steady, sluggish→alert

**Focus flips:** lockedIn→foggy, sharp→distracted, present→distracted, distracted→present, foggy→sharp

### 6.5 Medication Detail Extraction

Per matched medication name:

| Field | Source |
|-------|--------|
| `name` | Matched lexicon entry |
| `dose` | Regex: `\b\d+(?:\.\d+)?\s?(mg\|mcg\|milligrams?)\b` |
| `time` | NSDataDetector date → `HH:mm` (only if match contains digits) |
| `timeLabel` | Raw detector match text, or keyword fallback |
| `taken` | `!isNegatedBefore(medName)` |
| `quantity` | "half a", "halved", "split" → 0.5 |
| `change` | "started", "began", "went on" → `.started`; "stopped", "quit", "came off" → `.stopped` |

**Stop terms (12):** stopped, quit, came off, discontinued, ended, tapered off, finished, withdrawing from, withdrew from, off of, off my

**Start terms (10):** started, began, started taking, went on, put on, prescribed, initiated, first day, first time, commenced

**Half terms (9):** half a, half of, half my, half the, halved, split the, split my, split a, splitting

### 6.6 Regex Patterns — `ADHDRegexPatterns`

| Pattern | Regex | Example matches |
|---------|-------|-----------------|
| Dose | `(?i)\b(\d{1,3})\s?(mg\|mcg\|milligram)\s?(XL\|XR\|IR\|SR\|ER\|ODT\|LA\|PM\|modified release\|extended release\|immediate release)?\s?(once\|twice\|three times\|daily\|every morning\|with breakfast\|q\.?d\|b\.?i\.?d\|t\.?i\.?d)?\b` | "36mg XL", "20mg daily" |
| Sleep hours | `(?i)(?:slept\|got\|in bed for\|was asleep for\|only\|about\|roughly\|maybe)\s?(\d{1,2}(?:\.\d)?)\s?(hours?\|hrs?\|h)` | "slept 7 hours", "got about 6 hrs" |
| Time event | `(?i)(woke up\|got up\|took it\|took my meds?\|took\|dose\|alarm\|bedtime\|sleep\|crashed)\s?(?:at\|around\|about\|~)?\s?(\d{1,2}(?::\d{2})?\s?(?:am\|pm\|a\.?m\.?\|p\.?m\.?)?)` | "woke up at 7", "took it at 8:30am" |
| Onset minutes | `(?i)(?:kicks?\|started?\|kicked\|onset\|took)\s?(?:in\|after\|about\|around)?\s?(\d{1,3})\s?(minutes?\|mins?\|m\|hours?\|hrs?)` | "kicks in after 45 minutes", "took 2 hours" |
| Duration hours | `(?i)(?:lasted\|duration\|worked for\|good for\|wore off after\|wearing off after\|coverage)\s?(\d{1,2}(?:\.\d)?)\s?(hours?\|hrs?\|h)` | "lasted 8 hours", "wore off after 6 hours" |
| Crash time | `(?i)(?:crash\|rebound\|wore off\|dropped off\|hit a wall\|symptoms came back)\s?(?:at\|around\|about)?\s?(\d{1,2}(?::\d{2})?\s?(?:am\|pm\|a\.?m\.?\|p\.?m\.?)?)` | "crash at 3pm", "rebound around 4" |
| Severity | `(?i)(side effects?\|mood\|focus\|energy\|anxiety\|headache\|nausea\|sleep\|appetite\|crash\|rebound\|irritability).*?(\d\|10)\s?(?:\/\|out of\|\/10\|\s?10)?` | "side effects 3/10", "mood is about a 7" |
| Sleep latency | `(?i)(\d{1,2})\s?(?:hours?\|hrs?\|h)\s?(?:to fall asleep\|to get to sleep\|before sleep)` | "took 2 hours to fall asleep" |
| Intake context | `(?i)(?:took\|had\|with\|on)\s?(empty stomach\|full stomach\|with food\|with breakfast\|with lunch\|with dinner\|after eating\|before eating\|orange juice\|coffee\|vitamin C\|OJ\|protein)` | "with breakfast", "empty stomach" |

### 6.7 Highlight Scoring

Each sentence scored, threshold = 1.5 to qualify:

| Cue present | Points |
|-------------|--------|
| Medication | +3.0 |
| Time keyword | +1.0 |
| Task (completed/avoided) | +2.0 |
| Win | +2.5 |
| Energy | +1.5 |
| Focus | +1.5 |
| Mood | +1.5 |
| Side effect | +2.0 |
| Rebound | +2.5 |
| Appetite | +1.5 |
| Executive dysfunction | +2.0 |
| Sentiment magnitude | +abs(sentiment) × 2.0 |
| Length 40–200 chars | +1.0 |
| Length < 20 chars | −1.0 |

Top N = min(5, max(1, sentenceCount / 4 + 1)). If nothing qualifies, takes single best sentence.

### 6.8 Title Generation
First 6 words of top highlight. Fallback: first 6 words of transcript.

### 6.9 Mood Aggregation

1. If mood candidates exist → pick lowest embedding distance
2. Else if sentiment valence exists → coarse map:
   - > 0.5 → "great"
   - > 0.2 → "good"
   - > -0.1 → "okay"
   - > -0.3 → "flat"
   - else → "low"

---

## 7. SummaryResult → Recording Mapping

### `SummaryResult` (intermediate)

```swift
struct SummaryResult {
    var bullets: [String]
    var medications: [MedEvent]
    var generatedTitle: String
    var energyLevel: String?
    var focusLevel: String?
    var mood: String?
    var sleepHours: Double?
    var sleepQuality: String?
    var sleepEvent: SleepEvent?
    var sleepLevel: String?
    var sideEffects: [String]
    var feelings: [String]
    var noteExtraction: NoteExtraction    // FULL blob
}
```

### `Recording` persisted fields (SwiftData)

| Recording field | Source | Type |
|-----------------|--------|------|
| `title` | `SummaryResult.generatedTitle` | String |
| `summary` | `bullets.joined(separator: "\n")` | String? |
| `summaryBulletsJSON` | `JSONEncoder.encode(bullets)` | String? |
| `medicationsJSON` | `JSONEncoder.encode(medications)` | String? |
| `medicationInfo` | Formatted string from meds | String? |
| `hasMedication` | `!medications.isEmpty` | Bool |
| `energyLevel` | `SummaryResult.energyLevel` | String? |
| `focusLevel` | `SummaryResult.focusLevel` | String? |
| `mood` | `SummaryResult.mood` | String? |
| `sleepHours` | `SummaryResult.sleepHours` | Double? |
| `sleepQuality` | `SummaryResult.sleepQuality` | String? |
| `sleepEventJSON` | `JSONEncoder.encode(sleepEvent)` | String? |
| `sleepLevelValue` | `SummaryResult.sleepLevel` | String? |
| `sideEffectsJSON` | `JSONEncoder.encode(sideEffects)` | String? |
| `feelingsJSON` | `JSONEncoder.encode(feelings)` | String? |
| `topicTagsJSON` | Derived from transcript | String? |
| `noteExtractionJSON` | `JSONEncoder.encode(noteExtraction)` | String? |
| `summaryStatus` | `"completed"` | String? |
| `summaryGeneratedAt` | `Date()` | Date? |

### `SleepLevel` derivation

```
quality = "insomnia" or "poor" → .restless
quality = "good" → .good
hours < 5 → .restless
hours 5–6 → .light
hours 6–7 → .okay
hours 7–9 → .good
hours ≥ 9 → .deep
```

### `DisplayTag` — computed at render time

```swift
struct DisplayTag: Identifiable {
    let id: String      // "cat-medication", "energy-alert", "med-Concerta"
    let label: String   // "Concerta", "Alert", "Focused"
    let icon: String    // SF Symbol name
}
```

Derived from persisted fields in `Recording+MoodDisplay.swift`. Not stored.

---

## 8. What's Extracted but NOT Persisted

These fields exist in `NoteExtraction` but are dropped after `applySummary`:

| Field | Why it matters |
|-------|---------------|
| `moodValence` | Quantified sentiment for trend charts |
| `activities` | Activity breakdown for daily/weekly view |
| `tasksCompleted` | Productivity tracking |
| `tasksAvoided` | Procrastination patterns |
| `wins` | Positive reinforcement data |
| `overwhelm` | Stress pattern tracking |
| `executiveDysfunction` | ADHD symptom severity |
| `physicalStim` | Stimming frequency |
| `physicalSideEffects` | Physical symptom tracking |
| `reboundTerms` | Medication wear-off patterns |
| `appetiteLoss` / `appetiteReturn` | Side effect timeline |
| `onsetMinutes` | Medication effectiveness |
| `durationHours` | Coverage duration tracking |
| `crashTime` | Rebound timing patterns |
| `intakeContext` | Food/environment correlation |
| `extractedDose` | Dose parsing validation |

They ARE stored in `noteExtractionJSON` as a full blob, but individual columns don't exist for querying.

---

## 9. File Map

| File | Role |
|------|------|
| `NoteExtraction.swift` | `NoteExtraction`, `MedEvent`, `SleepNote`, `SleepEvent`, enums |
| `Lexicon.swift` | Injectable vocabulary with all default words |
| `NLNoteExtractor.swift` | Extraction engine — per-sentence processing |
| `ADHDRegexPatterns` | Static regex utilities (bottom of NLNoteExtractor.swift) |
| `NLSummarizationService.swift` | Maps `NoteExtraction` → `SummaryResult` |
| `Recording.swift` | SwiftData model, `applySummary(_:)` |
| `Recording+MoodDisplay.swift` | `DisplayTag`, `moodColor`, `moodIcon` |
