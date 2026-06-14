# app-two — Feature Reference

> On-device ADHD voice journal. Everything runs locally — no data leaves your device.

---

## Capture

### Voice Recording
Tap the microphone button to start a recording. While you speak, a live transcript appears in real time so you can see what's being captured. Tap the button again (now red, showing a stop square) to finish. A cancel button appears to the left during recording to discard without saving.

The app enforces a maximum recording duration and requires at least 50 MB of free disk space before starting. If microphone permission hasn't been granted, a prompt links directly to Settings.

**Status states:** Ready → Recording → Processing → Done

### Text Note
Switch to the Text tab on the Record screen to type a note instead of speaking. Tap **Analyze Note** and the same on-device NLP pipeline runs over your text — no audio file is created. The result flows into the same Review screen as a voice note.

---

## On-Device NLP Extraction

After every capture, Apple's NaturalLanguage framework analyzes the transcript. Nothing is sent to a server. The extraction runs in milliseconds and produces the following structured fields:

### Medications
Detects 50+ ADHD medications by name, including brand and generic forms:
- **Stimulants:** Concerta, Ritalin, Methylin, Metadate, Jornay PM, Quillivant XR, Adderall, Vyvanse, Elvanse, Dexedrine, Focalin, Azstarys, and more
- **Non-stimulants:** Strattera, Atomoxetine, Intuniv, Guanfacine, Kapvay, Clonidine, Qelbree
- **Off-label / adjunct:** Wellbutrin, Bupropion, Provigil, Modafinil, Nuvigil
- **Generics:** methylphenidate, lisdexamfetamine, dextroamphetamine, dexmethylphenidate

For each medication event the extractor captures:
- **Name** — canonical brand or generic name
- **Dose** — e.g. "36mg", "18 mg"
- **Time** — exact HH:mm if a clock time is mentioned, or a label like "morning" / "around 10am"
- **Taken or missed** — negation detection ("forgot my meds", "skipped the booster") marks the event as missed
- **Quantity** — fractional dosing, e.g. "half a pill" → 0.5
- **Change** — detects "started" or "stopped" to flag medication changes

### Energy Level
Classified into four levels:

| Level | Example phrases |
|---|---|
| High | energized, wired, buzzing, pumped, on fire |
| Steady | baseline, normal energy, stable, managing |
| Low | tired, exhausted, drained, sluggish, fatigued |
| Crashed | crashed, hit a wall, sudden fatigue, melted down |

### Focus State
Classified into five levels:

| Level | Example phrases |
|---|---|
| Hyperfocused | deep focus, locked in, tunnel vision, flow state |
| Focused | on task, concentrating, on track, keeping up |
| Scattered | all over the place, fragmented, jumping around |
| Distracted | zoning out, spacing out, mind wandering, sidetracked |
| Foggy | brain fog, cloudy, hazy, can't think straight |

### Mood
Maps natural speech to 18 canonical mood labels: happy, motivated, accomplished, excited, proud, calm, content, relieved, focused, anxious, stressed, frustrated, irritable, overwhelmed, sad, empty, flat, neutral.

Handles negation ("not bad" → neutral) and flip logic ("not anxious" → calm). Backed by Apple NLEmbedding for semantic matching when exact keywords aren't used.

### Sleep
Detects sleep mentions and extracts:
- **Hours** — "slept 7 hours", "got about 6 hrs"
- **Quality** — good (slept well, rested, refreshed) / poor (broken sleep, nightmares, woke up every hour) / insomnia (can't sleep, wired at night, racing thoughts)

### Side Effects & Physical Symptoms
Captures sentences mentioning:
- Common medication side effects: dry mouth, headache, nausea, appetite loss, heart racing, jittery, dizzy, clenched jaw, grinding teeth
- Rebound / wearing off: "afternoon crash", "symptoms came back", "wearing off", "steep drop"
- Physical stimming: fidgeting, leg bouncing, pacing, skin picking, nail biting

### Executive Dysfunction & Tasks
- **Tasks completed:** finished, done, nailed it, smashed it, crushed it
- **Tasks avoided:** procrastinated, stuck, frozen, task paralysis, initiation paralysis, kept putting off
- **Wins:** proud, victory, achievement, got shit done
- **Overwhelm:** drowning, buried, decision fatigue, can't keep up
- **Executive dysfunction markers:** time blind, running late, forgot to eat, body doubling, can't prioritize

### Appetite
- **Loss:** no appetite, force eating, skipped lunch, not hungry, food is gross
- **Return:** ravenous, starving, binge ate, crash eating

### Whisper Prompt Biasing
The Whisper transcription model is primed with an ADHD-specific vocabulary prompt at inference time. This biases it toward correct spelling of medication names and compound ADHD terms (hyperfocused, brain fog, executive dysfunction, stimming, body doubling, rebound) rather than phonetically similar common words.

---

## Extraction Review

After every note is processed, a **Review** sheet appears before anything is saved. This is the confirmation step — it shows what the NLP understood and lets you correct it.

### What you see
- A preview of the first extracted highlight from the transcript
- The detected **mood** with all 18 presets available as tappable chips
- The detected **energy level** (4 chips)
- The detected **focus state** (5 chips)
- Extracted **medications** with dose and time

### Editing
Tap any chip to change the value. The app tracks which fields you changed. When you tap **Save**, each field is written with a source tag:
- `.nlp` — the NLP result, accepted without change
- `.userCorrected` — you changed it before saving

Tap **Cancel** to discard the extraction. The recording is kept in the library as a retryable failed state — you can regenerate from the detail view.

---

## Library (Journal View)

The default tab. Shows all recordings grouped by day, newest first, with full month navigation using `<` and `>` arrows.

Each entry card shows:
- A **mood-colored circle** (teal for positive, green for calm, orange for anxious/stressed, red for overwhelmed, blue for neutral/unknown)
- **Mood label** or "No mood" if not detected
- **Timestamp** (hour:minute)
- **Tag chips** — up to 3 visible tags drawn from: topic categories, energy level, focus state, sleep, medications

---

## Calendar View

Monthly grid view showing every day that has at least one recording. Days are colored by the dominant mood of their entries.

- **Mood Count chart** — a visual breakdown of how moods distributed across the month (Great / Good / Neutral / Low / Rough buckets)
- **Day tap** — opens a bottom sheet showing all recordings for that day, each as a tappable card
- **Jump to Today** toolbar button

---

## Recording Detail View

Full view for a single recording. Accessible by tapping any entry in the Library or Calendar.

### Header card
- Mood circle + mood text
- Recording title
- Date, time, and duration
- **`…` menu** with:
  - Edit Date & Time — wheel picker, past dates only
  - Edit Mood — preset grid + free-text field

### Favorite
Heart button in the top toolbar. Favorited recordings are marked for quick reference (filtering by favorites coming in a future release).

### Share
Exports the recording's title, summary bullets, and full transcript as plain text via the system share sheet.

### Journal section
Conditionally shown when ADHD data exists:
- **Medication rows** — sorted by time, each showing the time, name + dose, change badge (Started / Stopped), and a missed indicator
- **State badges** — Mood (pink), Energy (orange), Focus (indigo)
- **Summary bullets** — extractive highlights from the transcript
- **Regenerate button** — re-runs the full NLP pipeline on the existing transcript

### Transcript section
Full text of the Whisper transcription with a status badge (Recorded / Transcribing / Completed / Failed).

### Audio player
Waveform-style pill player. Shows current position, play/pause, and supports seeking by tapping the waveform. Displays duration in MM:SS.

### Delete
Removes the recording and its audio file from the device permanently.

---

## Settings

| Setting | Description |
|---|---|
| **Whisper model** | Download (~150 MB) or delete the on-device transcription model. Shows download progress. |
| **Storage** | Displays total recording count and disk space used. |
| **Download over cellular** | When off, model downloads are Wi-Fi only. |
| **Medical context prompt** | Enables the ADHD vocabulary prompt injected into Whisper at inference time. On by default. |
| **Reduce Motion** | Disables waveform and status pill animations app-wide. |
| **Clear All Data** | Deletes all recordings and resets the app. Destructive, no undo. |

App version is shown at the bottom of Settings.

---

## Data & Privacy

All processing — transcription, NLP extraction, storage — happens entirely on-device using:
- **WhisperKit** (openai/whisper-small CoreML) for speech-to-text
- **Apple NaturalLanguage** framework for extraction
- **SwiftData** for local persistence

The recordings database is excluded from iCloud backup by default. No analytics, no telemetry, no network requests for core functionality.

### What's stored per recording

| Field | Description |
|---|---|
| Full transcript | Complete Whisper output |
| Title | First 6 words of the top-scored highlight |
| Mood | Canonical mood label |
| Energy level | high / steady / low / crashed |
| Focus level | hyperfocused / focused / scattered / distracted / foggy |
| Medications JSON | Array of MedEvent objects with name, dose, time, taken flag |
| Sleep hours | Numeric hours if mentioned |
| Sleep quality | good / poor / insomnia |
| Summary bullets | Top-scored transcript sentences |
| noteExtractionJSON | Full NoteExtraction blob — all extracted fields including side effects, rebound, appetite, tasks, wins, onset/duration, crash time, intake context |
| Correction tags | RecordingTag entries recording source (nlp / user / userCorrected) and confidence per field |

---

## Supported Formats

Audio is recorded as `.m4a` (AAC, device microphone default). Transcripts can be exported as plain text, JSON, or SRT subtitle format via the Share button in the detail view.
