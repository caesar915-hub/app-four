import Foundation
import SquirlSignals
@testable import app_four

/// One labeled case for the MLX (LLM) extraction eval.
///
/// Mirrors `EvalCase` but carries two extras the tuned pipeline needs:
/// `medTaken` asserts per-med taken/skipped state, and the gate fields
/// (`hardGate` / `assertNil` / `energyAlternatives`) drive the hard assertions
/// in `MLXExtractionEvalTests`. Labels reflect the **tuned** pipeline
/// (Prompts.yaml temporal rules + ExtractionValidator deterministic overrides),
/// which intentionally differ from the NL-era `EvalSet` labels in a few
/// places — each such change is marked with a `// tuned:` comment.
struct MLXEvalCase {
    let id: String
    let language: String          // "en" | "pt" | "es"
    let transcript: String
    var mood: String? = nil
    var energy: EnergyLevel? = nil
    var focus: FocusLevel? = nil
    var emotions: Set<String> = []
    var activities: Set<String> = []
    var medNames: Set<String> = []
    var medTaken: [String: Bool] = [:]
    var sleepHours: Double? = nil
    var topics: Set<String> = []
    var anySideEffect: Bool = false

    /// When true, every labeled field above is hard-asserted with #expect
    /// (except fields named in `softFields`, which stay metrics-only).
    var hardGate: Bool = false
    /// Field names ("mood", "energy", "focus") whose labels count toward the
    /// metrics but are NOT hard-asserted even on hard-gate cases — for values
    /// the prompt deliberately leaves to model judgment.
    var softFields: Set<String> = []
    /// Field names ("mood", "energy", "focus", "emotions", "activities",
    /// "medications", "sleepHours", "topics", "sideEffects") that must come
    /// back nil/empty. Only consulted on hard-gate cases.
    var assertNil: Set<String> = []
    /// When set, the hard gate accepts any of these energy values (the prompt
    /// itself allows "sluggish" or "tired" for some wordings).
    var energyAlternatives: Set<EnergyLevel>? = nil
}

enum MLXEvalSet {
    /// 40 cases ported from `EvalSet` (labels reviewed under tuned semantics)
    /// + 8 targeted cases (`tuned-*`) covering the deterministic safeguards.
    static let cases: [MLXEvalCase] = [

        // ════════════════════════════════════════════════════════════
        // Targeted tuning cases (hard gate) — deterministic, validator-backed
        // ════════════════════════════════════════════════════════════

        // Temporal recovery: morning low must not win over the stated NOW.
        MLXEvalCase(
            id: "tuned-temporal-recovery", language: "en",
            transcript: "This morning was honestly awful, I was sad and could not get off the couch. But the meds kicked in around noon and right now I feel good and pretty sharp.",
            mood: "good", energy: .alert, focus: .sharp,
            hardGate: true, softFields: ["energy", "focus"],   // degree is model judgment; only mood is rule-backed
            assertNil: ["medications"]   // "meds" is a stop word
        ),
        // Crash override: late crash overrides the earlier high (rule 3 + validator).
        MLXEvalCase(
            id: "tuned-crash-override", language: "en",
            transcript: "I felt amazing all morning, got through my whole to-do list. Then around 4pm I hit a wall and now I can barely keep my eyes open.",
            mood: "low", energy: .sluggish,
            hardGate: true
        ),
        // Skipped med: taken:false via prompt few-shot AND validator regex fallback.
        MLXEvalCase(
            id: "tuned-med-skipped", language: "en",
            transcript: "The pharmacy was closed so I didn't take my Ritalin today.",
            medNames: ["Ritalin"], medTaken: ["Ritalin": false], topics: ["Medications"],
            hardGate: true
        ),
        // Jitter override: overstimulated beats "don't feel tired".
        MLXEvalCase(
            id: "tuned-jitter-charged", language: "en",
            transcript: "Had two espressos and my afternoon Concerta and now I'm super jittery, my heart is racing, but I definitely don't feel tired.",
            energy: .charged, medNames: ["Concerta"],
            hardGate: true
        ),
        // Minimalist single-word note: energy recovered, focus/meds stay empty.
        // (The current tuned synonym tables also map "exhausted" → mood "low".)
        MLXEvalCase(
            id: "tuned-minimalist", language: "en",
            transcript: "Exhausted.",
            mood: "low", energy: .tired,                  // few-shot twin "Tired." → tired
            hardGate: true, assertNil: ["focus", "medications"],
            energyAlternatives: [.tired, .sluggish]   // prompt allows either
        ),
        // Generic stop-word trap: "meds" must not become a medication entity.
        MLXEvalCase(
            id: "tuned-generic-med-stopword", language: "en",
            transcript: "I took my meds this morning and felt fine, nothing special.",
            mood: "okay",
            hardGate: true, assertNil: ["medications"]
        ),
        // Rule ordering (2026-08-17-c): crash forces energy sluggish + mood low,
        // then positive-now lifts mood→good AND (new) energy→alert when the
        // recovery cue is "locked in"/"sharp"/"energized"/"ready to tackle".
        MLXEvalCase(
            id: "tuned-crash-then-recovery", language: "en",
            transcript: "I crashed hard after lunch, could barely function for a while. But honestly right now I feel good and locked in again.",
            mood: "good", energy: .alert, focus: .lockedIn,
            hardGate: true
        ),
        // Temporal rule 5: past emotions must not leak into the signals.
        // Metrics-only: no deterministic validator guard exists for this —
        // tracked as a characterization finding, not a gate.
        MLXEvalCase(
            id: "tuned-past-emotion-excluded", language: "en",
            transcript: "Yesterday I was furious about the parking ticket and anxious all evening. Today I'm calm and collected.",
            mood: "good", assertNil: ["emotions"]
        ),

        // ════════════════════════════════════════════════════════════
        // Ported from EvalSet (EN) — labels reviewed under tuned semantics
        // ════════════════════════════════════════════════════════════

        // tuned: was mood "good" / energy .charged — the 3pm crash makes the
        // post-crash state current (mood "low", energy .sluggish).
        MLXEvalCase(
            id: "en-med-day", language: "en",
            transcript: "Took my Concerta 36mg at 8am with breakfast. It kicked in after about 45 minutes and I was firing on all cylinders until lunch. Crashed hard around 3pm, dry mouth all afternoon. Still managed to finish the report, proud of that.",
            mood: "low", energy: .sluggish,
            emotions: ["proud"], medNames: ["Concerta"],
            topics: ["Medications", "Symptoms"], anySideEffect: true
        ),
        MLXEvalCase(
            id: "en-paraphrase-energy", language: "en",
            transcript: "Honestly today my body just would not get going, like wading through wet sand from the moment I woke up. Could not get off the couch until noon.",
            energy: .sluggish
        ),
        MLXEvalCase(
            id: "en-neutral", language: "en",
            transcript: "I went to the store and bought milk. The meeting is at three tomorrow. Nothing much happened today."
        ),
        MLXEvalCase(
            id: "en-traps", language: "en",
            transcript: "The fridge was empty so I ordered groceries. My gym bag felt heavy. I've seen my therapist this morning and we talked about raw vegetables.",
            activities: ["Eating"], topics: ["Appointments"]
        ),
        // tuned: emotions ["anxious"] → [] — the anxiety was Monday (past).
        MLXEvalCase(
            id: "en-past-progressive", language: "en",
            transcript: "I was feeling really anxious on Monday. Today I'm actually calm and got my inbox to zero.",
            mood: "good"
        ),
        MLXEvalCase(
            id: "en-sleep", language: "en",
            transcript: "Slept maybe 5 hours, tossed and turned all night. Skipped my Vyvanse because my heart was racing yesterday. Felt foggy and irritable the whole morning.",
            mood: "low", focus: .foggy, medNames: ["Vyvanse"], medTaken: ["Vyvanse": false], sleepHours: 5,
            topics: ["Medications", "Symptoms"], anySideEffect: true
        ),
        MLXEvalCase(
            id: "en-inflection", language: "en",
            transcript: "I'm panicking about the deadline and I keep avoiding the email thread. Spent the evening doomscrolling instead.",
            activities: ["Screen Time"]
        ),
        MLXEvalCase(
            id: "en-activities", language: "en",
            transcript: "Folded the laundry, did the dishes, then went for a long walk in the park to clear my head. Read a few chapters before bed.",
            activities: ["Chores", "Outdoors", "Hobbies"]
        ),

        // ── EN mood/emotion-centric ──
        MLXEvalCase(
            id: "en-mood-great", language: "en",
            transcript: "Today was great, honestly one of the best days in ages. I felt happy and light, like everything was clicking into place.",
            mood: "great"
        ),
        MLXEvalCase(
            id: "en-mood-overwhelmed", language: "en",
            transcript: "I'm so overwhelmed right now, completely buried under deadlines and the to-do list just keeps growing. Feeling really stressed and on edge all day.",
            mood: "low"
        ),
        MLXEvalCase(
            id: "en-mood-paraphrase-lifted", language: "en",
            transcript: "After I finally sent that email it was like a weight lifted off my shoulders, and I could breathe again. Spent the rest of the afternoon feeling settled.",
            mood: "good"
        ),
        MLXEvalCase(
            id: "en-mood-paraphrase-grey", language: "en",
            transcript: "Everything just felt grey and pointless today, like there was no colour in anything. I was sad for most of the morning and couldn't shake it.",
            mood: "low", emotions: ["sad"]
        ),
        MLXEvalCase(
            id: "en-mood-flat", language: "en",
            transcript: "Pretty meh day, just kind of numb and going through the motions. Didn't feel much of anything either way, totally indifferent.",
            mood: "flat"
        ),
        MLXEvalCase(
            id: "en-mood-okay", language: "en",
            transcript: "I'm alright, not bad at all really. Got curious about a new podcast and ended up taking notes, which was kind of nice.",
            mood: "okay"
        ),
        MLXEvalCase(
            id: "en-mood-nil-logistics", language: "en",
            transcript: "Renewed the car insurance, called the dentist to reschedule, and dropped a parcel at the post office. Nothing else on the calendar this week.",
            topics: ["Appointments"]
        ),
        MLXEvalCase(
            id: "en-mood-nil-factual", language: "en",
            transcript: "I lost my keys again so I spent ten minutes retracing my steps before they turned up in my coat. Then I caught the later bus into town."
        ),

        // ── EN medication-centric ──
        MLXEvalCase(
            id: "en-med-two", language: "en",
            transcript: "Started the morning with Ritalin 10mg and I take my Wellbutrin with it now. The combo seems smoother, less of a hard comedown in the afternoon.",
            medNames: ["Ritalin", "Wellbutrin"], topics: ["Medications"]
        ),
        MLXEvalCase(
            id: "en-med-skip", language: "en",
            transcript: "Completely forgot to take my Adderall this morning and only realised at lunch. The whole day was a write-off, couldn't focus on a single thing.",
            focus: .distracted, medNames: ["Adderall"], medTaken: ["Adderall": false], topics: ["Medications"]
        ),
        MLXEvalCase(
            id: "en-med-change", language: "en",
            transcript: "The psychiatrist switched me off Strattera and onto Elvanse starting today. First dose of the Elvanse went down fine, no obvious side effects yet.",
            medNames: ["Strattera", "Elvanse"], topics: ["Medications", "Appointments"]
        ),
        // ASR typo "Conserta" — not in the lexicon; relies on the LLM
        // normalizing to the allowed-value "Concerta".
        MLXEvalCase(
            id: "en-med-asr-typo", language: "en",
            transcript: "I bumped my Conserta up to 54 milligrams this week on the doctor's advice. Appetite has tanked though, barely touched lunch.",
            medNames: ["Concerta"], topics: ["Medications", "Symptoms"], anySideEffect: true
        ),
        MLXEvalCase(
            id: "en-med-sidefx", language: "en",
            transcript: "The Vyvanse has me wired and jittery, hands literally shaking by mid-afternoon, and I could not fall asleep until 2am with my heart pounding.",
            energy: .charged, medNames: ["Vyvanse"], topics: ["Medications", "Symptoms"], anySideEffect: true
        ),

        // ── EN sleep-centric ──
        MLXEvalCase(
            id: "en-sleep-seven", language: "en",
            transcript: "Got about 7 hours last night and woke up before the alarm feeling rested. Made a proper breakfast instead of skipping it for once.",
            activities: ["Eating"], sleepHours: 7
        ),
        // tuned: was energy .tired — "completely exhausted" maps to .sluggish
        // under the tuned synonym table.
        MLXEvalCase(
            id: "en-sleep-three", language: "en",
            transcript: "Barely slept, maybe three hours total because the baby was up all night. I'm completely exhausted and running on fumes.",
            energy: .sluggish, sleepHours: 3
        ),
        MLXEvalCase(
            id: "en-sleep-nine", language: "en",
            transcript: "Slept a solid nine hours and yet I still feel worn out, which makes no sense. Dragged myself through the morning.",
            energy: .tired, sleepHours: 9
        ),
        MLXEvalCase(
            id: "en-sleep-trap-worked", language: "en",
            transcript: "Worked a brutal 12 hours straight at the office, back to back meetings with no break. Light dinner and straight to bed, didn't even check my phone.",
            activities: ["Work", "Eating"]
        ),

        // ── EN executive-dysfunction / overwhelm / win register ──
        MLXEvalCase(
            id: "en-exec-stuck", language: "en",
            transcript: "I knew exactly what I needed to do but I just could not start any of it, sat staring at the screen for an hour. My head was all over the place and I felt restless and useless.",
            focus: .distracted
        ),
        MLXEvalCase(
            id: "en-win-presentation", language: "en",
            transcript: "Absolutely nailed the presentation today, the client signed off on the spot. Felt accomplished and proud walking out of that room.",
            mood: "great", emotions: ["proud"]
        ),
        MLXEvalCase(
            id: "en-overwhelm-then-focus", language: "en",
            transcript: "The inbox was a mountain and I felt completely overwhelmed at first, but once I got into the zone I powered through it. Ended up feeling really motivated.",
            focus: .lockedIn
        ),
        MLXEvalCase(
            id: "en-quiet-win", language: "en",
            transcript: "Nothing dramatic, but I cleared the small admin tasks I'd been putting off for weeks and felt quietly content about it. Grateful for a calm evening.",
            mood: "good", emotions: ["content", "grateful"]
        ),

        // ── EN neutral / no-signal ──
        MLXEvalCase(
            id: "en-neutral-weather", language: "en",
            transcript: "Light rain most of the morning then it cleared up by lunchtime. The bins go out tonight and the recycling is on Thursday this week."
        ),
        MLXEvalCase(
            id: "en-neutral-errand", language: "en",
            transcript: "Spent forty quid on a new phone charger and a pack of batteries at the shop. The bus was a couple of minutes late but otherwise an uneventful trip."
        ),
        MLXEvalCase(
            id: "en-neutral-schedule", language: "en",
            transcript: "Forecast says scattered showers tomorrow afternoon. The plumber is booked for nine, and the parcel is meant to arrive sometime between noon and four."
        ),

        // ════════════════════════════════════════════════════════════
        // Ported from EvalSet (PT / ES) — reported as a separate breakdown;
        // the tuning was EN-focused so these are signal, not gate.
        // ════════════════════════════════════════════════════════════

        MLXEvalCase(
            id: "pt-med-day", language: "pt",
            transcript: "Tomei o Concerta de 36mg às 8 da manhã. Dormi só 5 horas e passei o dia todo ansioso, sem conseguir começar nada. Boca seca a tarde inteira.",
            mood: "low", medNames: ["Concerta"], sleepHours: 5,
            topics: ["Medications", "Symptoms"], anySideEffect: true
        ),
        MLXEvalCase(
            id: "pt-good-day", language: "pt",
            transcript: "Que dia maravilhoso, me senti ótimo do começo ao fim. Tomei meu Ritalina de manhã e consegui terminar tudo no trabalho, muito orgulhoso.",
            mood: "great",
            activities: ["Work"], medNames: ["Ritalin"], topics: ["Medications"]
        ),
        MLXEvalCase(
            id: "pt-sleep-chores", language: "pt",
            transcript: "Dormi apenas 4 horas e acordei exausto. Mesmo assim lavei a louça e fiz a faxina da casa toda antes do almoço.",
            energy: .tired,
            activities: ["Chores"], sleepHours: 4
        ),
        MLXEvalCase(
            id: "pt-med-skip", language: "pt",
            transcript: "Esqueci de tomar o Adderall hoje e fiquei com uma dor de cabeça horrível a tarde inteira, sem conseguir me concentrar.",
            focus: .distracted, medNames: ["Adderall"],
            topics: ["Medications", "Symptoms"], anySideEffect: true
        ),

        MLXEvalCase(
            id: "es-med-day", language: "es",
            transcript: "Hoy no tomé el Vyvanse y estuve agotado toda la tarde, sin poder concentrarme. Cené temprano y caminé un rato por el parque.",
            energy: .sluggish, focus: .distracted,
            activities: ["Outdoors", "Eating"], medNames: ["Vyvanse"], topics: ["Medications"]
        ),
        MLXEvalCase(
            id: "es-anxious-day", language: "es",
            transcript: "Hoy me sentí muy triste y ansioso todo el día, no podía dejar de preocuparme. Tomé mi Concerta de 36 miligramos pero no ayudó mucho.",
            mood: "low", medNames: ["Concerta"],
            topics: ["Medications"]
        ),
        MLXEvalCase(
            id: "es-run-park", language: "es",
            transcript: "Dormí ocho horas y me desperté con mucha energía. Salí a correr por el parque y me sentí genial, muy contento el resto del día.",
            mood: "great", energy: .charged,
            activities: ["Fitness", "Outdoors"], sleepHours: 8
        ),
        MLXEvalCase(
            id: "es-med-sidefx", language: "es",
            transcript: "El Elvanse me deja la boca muy seca y sin apetito, casi no almorcé. Por la noche me costó muchísimo dormir.",
            medNames: ["Elvanse"], topics: ["Medications", "Symptoms"], anySideEffect: true
        ),
    ]
}
