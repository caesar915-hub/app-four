import Foundation
@testable import app_four

struct EvalCase {
    let id: String
    let language: String          // "en" | "pt" | "es"
    let transcript: String
    var mood: String? = nil
    var energy: EnergyLevel? = nil
    var focus: FocusLevel? = nil
    var feelings: Set<String> = []
    var activities: Set<String> = []
    var medNames: Set<String> = []
    var sleepHours: Double? = nil
    var topics: Set<String> = []          // TopicCategory rawValues
    var anySideEffect: Bool = false
}

enum EvalSet {
    static let cases: [EvalCase] = [
        // ── EN: multi-signal med day ──
        EvalCase(
            id: "en-med-day", language: "en",
            transcript: "Took my Concerta 36mg at 8am with breakfast. It kicked in after about 45 minutes and I was firing on all cylinders until lunch. Crashed hard around 3pm, dry mouth all afternoon. Still managed to finish the report, proud of that.",
            mood: "good",
            energy: .charged, feelings: ["proud"], medNames: ["Concerta"],
            topics: ["Medications", "Symptoms"], anySideEffect: true
        ),
        // ── EN: paraphrase energy (current pipeline SHOULD miss — recall gap doc) ──
        EvalCase(
            id: "en-paraphrase-energy", language: "en",
            transcript: "Honestly today my body just would not get going, like wading through wet sand from the moment I woke up. Could not get off the couch until noon.",
            energy: .sluggish
        ),
        // ── EN: neutral filler — NOTHING should fire ──
        EvalCase(
            id: "en-neutral", language: "en",
            transcript: "I went to the store and bought milk. The meeting is at three tomorrow. Nothing much happened today."
        ),
        // ── EN: common-word traps (Task 5 targets) ──
        EvalCase(
            id: "en-traps", language: "en",
            transcript: "The fridge was empty so I ordered groceries. My gym bag felt heavy. I've seen my therapist this morning and we talked about raw vegetables.",
            activities: ["Eating"], topics: ["Appointments"]
        ),
        // ── EN: past-progressive mood (Task 4 target) ──
        EvalCase(
            id: "en-past-progressive", language: "en",
            transcript: "I was feeling really anxious on Monday. Today I'm actually calm and got my inbox to zero.",
            mood: "good", feelings: ["anxious"]
        ),
        // ── EN: sleep + side effects ──
        EvalCase(
            id: "en-sleep", language: "en",
            transcript: "Slept maybe 5 hours, tossed and turned all night. Skipped my Vyvanse because my heart was racing yesterday. Felt foggy and irritable the whole morning.",
            mood: "low", focus: .foggy, medNames: ["Vyvanse"], sleepHours: 5,
            topics: ["Medications", "Symptoms"], anySideEffect: true
        ),
        // ── EN: inflection recall (Task 9 target) ──
        EvalCase(
            id: "en-inflection", language: "en",
            transcript: "I'm panicking about the deadline and I keep avoiding the email thread. Spent the evening doomscrolling instead.",
            feelings: ["panicked"], activities: ["Screen Time"]
        ),
        // ── EN: activities beyond the original six (Task 10 target) ──
        EvalCase(
            id: "en-activities", language: "en",
            transcript: "Folded the laundry, did the dishes, then went for a long walk in the park to clear my head. Read a few chapters before bed.",
            activities: ["Chores", "Outdoors", "Hobbies"]
        ),
        // ── PT: truth labels, zero expected recall today except med/dose ──
        EvalCase(
            id: "pt-med-day", language: "pt",
            transcript: "Tomei o Concerta de 36mg às 8 da manhã. Dormi só 5 horas e passei o dia todo ansioso, sem conseguir começar nada. Boca seca a tarde inteira.",
            mood: "low", feelings: ["anxious"], medNames: ["Concerta"], sleepHours: 5,
            topics: ["Medications", "Symptoms"], anySideEffect: true
        ),
        // ── ES: truth labels, zero expected recall today except med/dose ──
        EvalCase(
            id: "es-med-day", language: "es",
            transcript: "Hoy no tomé el Vyvanse y estuve agotado toda la tarde, sin poder concentrarme. Cené temprano y caminé un rato por el parque.",
            energy: .sluggish, focus: .distracted,
            activities: ["Outdoors", "Eating"], medNames: ["Vyvanse"], topics: ["Medications"]
        ),

        // ════════════════════════════════════════════════════════════
        // 8 EN mood/feelings-centric
        // ════════════════════════════════════════════════════════════

        // exact lexicon mood word "great", happy
        EvalCase(
            id: "en-mood-great", language: "en",
            transcript: "Today was great, honestly one of the best days in ages. I felt happy and light, like everything was clicking into place.",
            mood: "great", feelings: ["delighted"]
        ),
        // exact lexicon mood word "overwhelmed"/"stressed" → low; overwhelmed feeling
        EvalCase(
            id: "en-mood-overwhelmed", language: "en",
            transcript: "I'm so overwhelmed right now, completely buried under deadlines and the to-do list just keeps growing. Feeling really stressed and on edge all day.",
            mood: "low", feelings: ["overwhelmed", "on edge"]
        ),
        // paraphrase mood the pipeline likely misses: "weight lifted" → good, relieved
        EvalCase(
            id: "en-mood-paraphrase-lifted", language: "en",
            transcript: "After I finally sent that email it was like a weight lifted off my shoulders, and I could breathe again. Spent the rest of the afternoon feeling settled.",
            mood: "good", feelings: ["relieved", "settled"]
        ),
        // paraphrase mood the pipeline likely misses: "world is grey" → low, sad
        EvalCase(
            id: "en-mood-paraphrase-grey", language: "en",
            transcript: "Everything just felt grey and pointless today, like there was no colour in anything. I was sad for most of the morning and couldn't shake it.",
            mood: "low", feelings: ["sad"]
        ),
        // flat mood + indifferent feeling
        EvalCase(
            id: "en-mood-flat", language: "en",
            transcript: "Pretty meh day, just kind of numb and going through the motions. Didn't feel much of anything either way, totally indifferent.",
            mood: "flat", feelings: ["indifferent"]
        ),
        // okay mood + curious feeling
        EvalCase(
            id: "en-mood-okay", language: "en",
            transcript: "I'm alright, not bad at all really. Got curious about a new podcast and ended up taking notes, which was kind of nice.",
            mood: "okay", feelings: ["curious"]
        ),
        // NO mood at all #1 — logistics with trap word "nothing" non-emotional
        EvalCase(
            id: "en-mood-nil-logistics", language: "en",
            transcript: "Renewed the car insurance, called the dentist to reschedule, and dropped a parcel at the post office. Nothing else on the calendar this week.",
            topics: ["Appointments"]
        ),
        // NO mood at all #2 — factual recap, trap words "lost" (lost keys) + "spent" (time), non-emotional
        EvalCase(
            id: "en-mood-nil-factual", language: "en",
            transcript: "I lost my keys again so I spent ten minutes retracing my steps before they turned up in my coat. Then I caught the later bus into town."
        ),

        // ════════════════════════════════════════════════════════════
        // 5 EN medication-centric
        // ════════════════════════════════════════════════════════════

        // dose stated, two meds
        EvalCase(
            id: "en-med-two", language: "en",
            transcript: "Started the morning with Ritalin 10mg and I take my Wellbutrin with it now. The combo seems smoother, less of a hard comedown in the afternoon.",
            medNames: ["Ritalin", "Wellbutrin"], topics: ["Medications"]
        ),
        // skip / forgot a med
        EvalCase(
            id: "en-med-skip", language: "en",
            transcript: "Completely forgot to take my Adderall this morning and only realised at lunch. The whole day was a write-off, couldn't focus on a single thing.",
            focus: .distracted, medNames: ["Adderall"], topics: ["Medications"]
        ),
        // med change (switching)
        EvalCase(
            id: "en-med-change", language: "en",
            transcript: "The psychiatrist switched me off Strattera and onto Elvanse starting today. First dose of the Elvanse went down fine, no obvious side effects yet.",
            medNames: ["Strattera", "Elvanse"], topics: ["Medications", "Appointments"]
        ),
        // ASR-typo case: "Conserta" → Concerta (Task 11 target)
        EvalCase(
            id: "en-med-asr-typo", language: "en",
            transcript: "I bumped my Conserta up to 54 milligrams this week on the doctor's advice. Appetite has tanked though, barely touched lunch.",
            medNames: ["Concerta"], topics: ["Medications", "Symptoms"], anySideEffect: true
        ),
        // med + clear side effects (insomnia, jitters)
        EvalCase(
            id: "en-med-sidefx", language: "en",
            transcript: "The Vyvanse has me wired and jittery, hands literally shaking by mid-afternoon, and I could not fall asleep until 2am with my heart pounding.",
            energy: .charged, medNames: ["Vyvanse"], topics: ["Medications", "Symptoms"], anySideEffect: true
        ),

        // ════════════════════════════════════════════════════════════
        // 4 EN sleep-centric
        // ════════════════════════════════════════════════════════════

        // "got about 7 hours" → 7, slept well
        EvalCase(
            id: "en-sleep-seven", language: "en",
            transcript: "Got about 7 hours last night and woke up before the alarm feeling rested. Made a proper breakfast instead of skipping it for once.",
            feelings: ["recharged"], activities: ["Eating"], sleepHours: 7
        ),
        // "barely slept, three hours" → 3, exhausted
        EvalCase(
            id: "en-sleep-three", language: "en",
            transcript: "Barely slept, maybe three hours total because the baby was up all night. I'm completely exhausted and running on fumes.",
            energy: .tired, feelings: ["exhausted"], sleepHours: 3
        ),
        // "nine hours and still tired" → 9, tired energy
        EvalCase(
            id: "en-sleep-nine", language: "en",
            transcript: "Slept a solid nine hours and yet I still feel worn out, which makes no sense. Dragged myself through the morning.",
            energy: .tired, sleepHours: 9
        ),
        // "worked 12 hours" trap — NO sleepHours (sleepHours: nil)
        EvalCase(
            id: "en-sleep-trap-worked", language: "en",
            transcript: "Worked a brutal 12 hours straight at the office, back to back meetings with no break. Light dinner and straight to bed, didn't even check my phone.",
            activities: ["Work", "Eating"]
        ),

        // ════════════════════════════════════════════════════════════
        // 4 EN executive-dysfunction / overwhelm / win register
        // ════════════════════════════════════════════════════════════

        // executive dysfunction / can't start, scattered focus, restless
        EvalCase(
            id: "en-exec-stuck", language: "en",
            transcript: "I knew exactly what I needed to do but I just could not start any of it, sat staring at the screen for an hour. My head was all over the place and I felt restless and useless.",
            focus: .distracted, feelings: ["restless"]
        ),
        // win register — crushed it, accomplished, proud → great mood
        EvalCase(
            id: "en-win-presentation", language: "en",
            transcript: "Absolutely nailed the presentation today, the client signed off on the spot. Felt accomplished and proud walking out of that room.",
            mood: "great", feelings: ["proud"]
        ),
        // overwhelm + locked-in focus once started, motivated
        EvalCase(
            id: "en-overwhelm-then-focus", language: "en",
            transcript: "The inbox was a mountain and I felt completely overwhelmed at first, but once I got into the zone I powered through it. Ended up feeling really motivated.",
            focus: .lockedIn, feelings: ["overwhelmed", "motivated"]
        ),
        // quiet win, content/good register, grateful
        EvalCase(
            id: "en-quiet-win", language: "en",
            transcript: "Nothing dramatic, but I cleared the small admin tasks I'd been putting off for weeks and felt quietly content about it. Grateful for a calm evening.",
            mood: "good", feelings: ["content", "grateful"]
        ),

        // ════════════════════════════════════════════════════════════
        // 3 EN neutral / no-signal (ALL fields empty/nil)
        // ════════════════════════════════════════════════════════════

        // weather + logistics, trap word "light" (light rain), non-emotional
        EvalCase(
            id: "en-neutral-weather", language: "en",
            transcript: "Light rain most of the morning then it cleared up by lunchtime. The bins go out tonight and the recycling is on Thursday this week."
        ),
        // errand recap, trap word "spent" (spent money), non-emotional
        EvalCase(
            id: "en-neutral-errand", language: "en",
            transcript: "Spent forty quid on a new phone charger and a pack of batteries at the shop. The bus was a couple of minutes late but otherwise an uneventful trip."
        ),
        // factual scheduling, trap word "scattered" (scattered showers), non-emotional
        EvalCase(
            id: "en-neutral-schedule", language: "en",
            transcript: "Forecast says scattered showers tomorrow afternoon. The plumber is booked for nine, and the parcel is meant to arrive sometime between noon and four."
        ),

        // ════════════════════════════════════════════════════════════
        // 3 PT
        // ════════════════════════════════════════════════════════════

        // PT mood great + meds, no side effects
        EvalCase(
            id: "pt-good-day", language: "pt",
            transcript: "Que dia maravilhoso, me senti ótimo do começo ao fim. Tomei meu Ritalina de manhã e consegui terminar tudo no trabalho, muito orgulhoso.",
            mood: "great", feelings: ["proud"],
            activities: ["Work"], medNames: ["Ritalin"], topics: ["Medications"]
        ),
        // PT sleep + tired + chores
        EvalCase(
            id: "pt-sleep-chores", language: "pt",
            transcript: "Dormi apenas 4 horas e acordei exausto. Mesmo assim lavei a louça e fiz a faxina da casa toda antes do almoço.",
            energy: .tired, feelings: ["exhausted"],
            activities: ["Chores"], sleepHours: 4
        ),
        // PT med skip + symptom (headache)
        EvalCase(
            id: "pt-med-skip", language: "pt",
            transcript: "Esqueci de tomar o Adderall hoje e fiquei com uma dor de cabeça horrível a tarde inteira, sem conseguir me concentrar.",
            focus: .distracted, medNames: ["Adderall"],
            topics: ["Medications", "Symptoms"], anySideEffect: true
        ),

        // ════════════════════════════════════════════════════════════
        // 3 ES
        // ════════════════════════════════════════════════════════════

        // ES mood low + anxious + meds
        EvalCase(
            id: "es-anxious-day", language: "es",
            transcript: "Hoy me sentí muy triste y ansioso todo el día, no podía dejar de preocuparme. Tomé mi Concerta de 36 miligramos pero no ayudó mucho.",
            mood: "low", feelings: ["anxious", "sad"], medNames: ["Concerta"],
            topics: ["Medications"]
        ),
        // ES sleep + good mood + outdoors fitness
        EvalCase(
            id: "es-run-park", language: "es",
            transcript: "Dormí ocho horas y me desperté con mucha energía. Salí a correr por el parque y me sentí genial, muy contento el resto del día.",
            mood: "great", energy: .charged,
            activities: ["Fitness", "Outdoors"], sleepHours: 8
        ),
        // ES med side effect (dry mouth, appetite loss)
        EvalCase(
            id: "es-med-sidefx", language: "es",
            transcript: "El Elvanse me deja la boca muy seca y sin apetito, casi no almorcé. Por la noche me costó muchísimo dormir.",
            medNames: ["Elvanse"], topics: ["Medications", "Symptoms"], anySideEffect: true
        ),
    ]
}
