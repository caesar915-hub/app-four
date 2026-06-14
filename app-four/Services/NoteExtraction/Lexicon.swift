import Foundation
import NaturalLanguage

/// Injectable lexicon of seed words and canonical medication names.
/// Allows tests to control the vocabulary and extensions to add new terms.
public nonisolated struct Lexicon: Sendable {
    // MARK: - Medications
    public let medications: [String]

    // MARK: - Mood
    public let moodSpecific: [(word: String, label: String)]

    // MARK: - Energy (1 = sluggish … 5 = charged)
    public let energyCharged: [String]
    public let energyAlert: [String]
    public let energySteady: [String]
    public let energyTired: [String]
    public let energySluggish: [String]

    // MARK: - Focus (1 = foggy … 5 = lockedIn)
    public let focusLockedIn: [String]
    public let focusSharp: [String]
    public let focusPresent: [String]
    public let focusDistracted: [String]
    public let focusFoggy: [String]

    // MARK: - Feelings
    public let feelings: [String]

    // MARK: - Tasks / Wins / Overwhelm
    public let taskCompletionCues: [String]
    public let taskAvoidanceCues: [String]
    public let winCues: [String]
    public let overwhelmCues: [String]

    // MARK: - Executive Dysfunction
    public let executiveDysfunction: [String]

    // MARK: - Appointments
    public let appointmentCues: [String]

    // MARK: - Side effects
    public let sideEffectCues: [String]

    // MARK: - Physical / Stimming
    public let physicalStim: [String]
    public let physicalSideEffects: [String]

    // MARK: - Sleep
    public let sleepQualityGood: [String]
    public let sleepQualityBad: [String]
    public let sleepInsomnia: [String]

    // MARK: - Rebound / Crash
    public let reboundTerms: [String]

    // MARK: - Appetite
    public let appetiteLoss: [String]
    public let appetiteReturn: [String]

    // MARK: - Negation
    public let negationTokens: [String]
    public let medNotTakenVerbs: [String]

    // MARK: - Time of day
    public let timeOfDayKeywords: [(String, String)] // (keyword, normalized)

    // MARK: - Activities
    public let activityKeywords: [(category: String, keywords: [String])]

    public init(
        medications: [String]? = nil,
        moodSpecific: [(String, String)]? = nil,
        energyCharged: [String]? = nil,
        energyAlert: [String]? = nil,
        energySteady: [String]? = nil,
        energyTired: [String]? = nil,
        energySluggish: [String]? = nil,
        focusLockedIn: [String]? = nil,
        focusSharp: [String]? = nil,
        focusPresent: [String]? = nil,
        focusDistracted: [String]? = nil,
        focusFoggy: [String]? = nil,
        feelings: [String]? = nil,
        taskCompletionCues: [String]? = nil,
        taskAvoidanceCues: [String]? = nil,
        winCues: [String]? = nil,
        overwhelmCues: [String]? = nil,
        executiveDysfunction: [String]? = nil,
        appointmentCues: [String]? = nil,
        sideEffectCues: [String]? = nil,
        physicalStim: [String]? = nil,
        physicalSideEffects: [String]? = nil,
        sleepQualityGood: [String]? = nil,
        sleepQualityBad: [String]? = nil,
        sleepInsomnia: [String]? = nil,
        reboundTerms: [String]? = nil,
        appetiteLoss: [String]? = nil,
        appetiteReturn: [String]? = nil,
        negationTokens: [String]? = nil,
        medNotTakenVerbs: [String]? = nil,
        timeOfDayKeywords: [(String, String)]? = nil,
        activityKeywords: [(category: String, keywords: [String])]? = nil
    ) {
        self.medications = medications ?? Lexicon.defaultMedications
        self.moodSpecific = moodSpecific ?? Lexicon.defaultMoodSpecific
        self.energyCharged = energyCharged ?? Lexicon.defaultEnergyCharged
        self.energyAlert = energyAlert ?? Lexicon.defaultEnergyAlert
        self.energySteady = energySteady ?? Lexicon.defaultEnergySteady
        self.energyTired = energyTired ?? Lexicon.defaultEnergyTired
        self.energySluggish = energySluggish ?? Lexicon.defaultEnergySluggish
        self.focusLockedIn = focusLockedIn ?? Lexicon.defaultFocusLockedIn
        self.focusSharp = focusSharp ?? Lexicon.defaultFocusSharp
        self.focusPresent = focusPresent ?? Lexicon.defaultFocusPresent
        self.focusDistracted = focusDistracted ?? Lexicon.defaultFocusDistracted
        self.focusFoggy = focusFoggy ?? Lexicon.defaultFocusFoggy
        self.feelings = feelings ?? Lexicon.defaultFeelings
        self.taskCompletionCues = taskCompletionCues ?? Lexicon.defaultTaskCompletionCues
        self.taskAvoidanceCues = taskAvoidanceCues ?? Lexicon.defaultTaskAvoidanceCues
        self.winCues = winCues ?? Lexicon.defaultWinCues
        self.overwhelmCues = overwhelmCues ?? Lexicon.defaultOverwhelmCues
        self.executiveDysfunction = executiveDysfunction ?? Lexicon.defaultExecutiveDysfunction
        self.appointmentCues = appointmentCues ?? Lexicon.defaultAppointmentCues
        self.sideEffectCues = sideEffectCues ?? Lexicon.defaultSideEffectCues
        self.physicalStim = physicalStim ?? Lexicon.defaultPhysicalStim
        self.physicalSideEffects = physicalSideEffects ?? Lexicon.defaultPhysicalSideEffects
        self.sleepQualityGood = sleepQualityGood ?? Lexicon.defaultSleepQualityGood
        self.sleepQualityBad = sleepQualityBad ?? Lexicon.defaultSleepQualityBad
        self.sleepInsomnia = sleepInsomnia ?? Lexicon.defaultSleepInsomnia
        self.reboundTerms = reboundTerms ?? Lexicon.defaultReboundTerms
        self.appetiteLoss = appetiteLoss ?? Lexicon.defaultAppetiteLoss
        self.appetiteReturn = appetiteReturn ?? Lexicon.defaultAppetiteReturn
        self.negationTokens = negationTokens ?? Lexicon.defaultNegationTokens
        self.medNotTakenVerbs = medNotTakenVerbs ?? Lexicon.defaultMedNotTakenVerbs
        self.timeOfDayKeywords = timeOfDayKeywords ?? Lexicon.defaultTimeOfDayKeywords
        self.activityKeywords = activityKeywords ?? Lexicon.defaultActivityKeywords
    }
}

// MARK: - Default values

nonisolated extension Lexicon {
    static let defaultMedications: [String] = [
        // Methylphenidate family
        "Concerta", "Concerta XL", "Ritalin", "Ritalin LA", "Daytrana",
        "Metadate", "Methylin", "Aptensio XR", "Cotempla XR-ODT", "Jornay PM",
        "Quillivant XR", "QuilliChew ER", "Relexxii", "Medikinet XL", "Equasym XL",
        // Amphetamine family
        "Adderall", "Adderall XR", "Mydayis", "Vyvanse", "Elvanse", "Arynta",
        "Evekeo", "Evekeo ODT", "Dexedrine", "ProCentra", "Zenzedi", "Xelstrym",
        "Dyanavel XR", "Adzenys ER", "Adzenys XR-ODT", "Dexamfetamine",
        // Dexmethylphenidate
        "Focalin", "Focalin XR", "Azstarys",
        // Non-stimulants
        "Strattera", "Atomoxetine", "Atoncy", "Qelbree", "Viloxazine",
        "Intuniv", "Guanfacine", "Kapvay", "Clonidine", "Onyda XR",
        // Off-label / adjunct
        "Wellbutrin", "Bupropion", "Provigil", "Modafinil", "Nuvigil", "Armodafinil",
        // Generics users say
        "methylphenidate", "lisdexamfetamine", "amphetamine", "dextroamphetamine",
        "dexmethylphenidate", "serdexmethylphenidate"
    ]

    // MoodLevel (1=low … 5=high). Single source of mood vocabulary; the former
    // moodPositive/Negative/Irritable/Flat lists were folded in here and deleted.
    static let defaultMoodSpecific: [(String, String)] = [
        // Low (1) — absorbs former "dark" phrases
        ("bleak", "low"), ("numb", "low"), ("terrible", "low"), ("awful", "low"),
        ("destroyed", "low"), ("hopeless", "low"), ("can't go on", "low"),
        ("muted", "low"), ("depressed", "low"), ("really sad", "low"),
        ("feeling down", "low"), ("rock bottom", "low"),
        ("flat", "flat"), ("meh", "flat"), ("hollow", "flat"),
        ("emotionless", "flat"), ("zombie", "flat"), ("neutral", "flat"),
        ("detached", "flat"),
        ("okay", "okay"), ("fine", "okay"), ("alright", "okay"), ("not bad", "okay"),
        ("so-so", "okay"), ("steady mood", "okay"), ("getting by", "okay"),
        ("warm", "good"), ("lifted", "good"), ("better", "good"),
        ("pretty good", "good"), ("feeling good", "good"), ("feel good", "good"), ("positive", "good"),
        ("great", "great"), ("amazing", "great"), ("thriving", "great"), ("bright", "great"),
        ("fantastic", "great"), ("wonderful", "great"), ("on top of the world", "great"),
        ("brilliant", "great"),

        // Common single-word emotions. The iOS embedding fallback is too noisy to
        // match these reliably (synonym distances ~0.8–1.3 overlap unrelated words),
        // so they must be exact-match entries. Order is no longer load-bearing for
        // mood selection — nearestMood is longest-match-wins, not first-in-array —
        // but entries are kept grouped by label for readability.
        ("anxious", "low"), ("worried", "low"), ("angry", "low"), ("furious", "low"),
        ("grumpy", "low"), ("snappy", "low"), ("irritable", "low"), ("irritated", "low"),
        ("frustrated", "low"), ("stressed", "low"), ("overwhelmed", "low"),
        ("miserable", "low"), ("sad", "low"), ("zoned out", "low"),
        ("calm", "good"), ("relaxed", "good"), ("content", "good"), ("chill", "good"),
        ("at ease", "good"), ("peaceful", "good"),
        ("happy", "great"), ("cheerful", "great"), ("joyful", "great"), ("glad", "great"),
        ("ecstatic", "great"), ("nailed it", "great"), ("crushed it", "great"),
        ("accomplished", "great"), ("optimistic", "good"),

        // Folded in from the former moodPositive/Negative/Irritable/Flat lists
        // (now deleted — these are the single source of mood vocabulary).
        ("subdued", "low"), ("ruminating", "low"), ("looping", "low"),
        ("grouchy", "low"), ("touchy", "low"), ("short fuse", "low"),
        ("zombified", "flat"), ("lifeless", "flat"), ("not myself", "flat"),
        ("disconnected", "flat"), ("robotic", "flat"), ("dulled", "flat"),

        // Feel-context phrases for common words too ambiguous bare (the bare
        // "heavy"/"empty"/"nothing" fired on "gym bag felt heavy", "fridge was
        // empty", "nothing much happened"). Require a "feel"/"felt"/"feeling"
        // carrier so only the emotional sense matches; longest-match in
        // nearestMood picks these over any shorter overlap.
        ("feel empty", "flat"), ("feeling empty", "flat"), ("felt empty", "flat"),
        ("feel nothing", "flat"), ("feeling nothing", "flat"), ("felt nothing", "flat"),
        ("feel heavy", "low"), ("feeling heavy", "low")
    ]

    // Energy (1=sluggish … 5=charged)
    static let defaultEnergyCharged: [String] = [
        "charged", "electric", "energized", "wired", "buzzing", "pumped",
        "on fire", "vibing", "high energy", "unstoppable"
    ]
    static let defaultEnergyAlert: [String] = [
        "alert", "awake", "ready", "clear headed", "refreshed", "perked up",
        "switched on"
    ]
    static let defaultEnergySteady: [String] = [
        "steady", "stable", "moderate", "baseline", "okay energy",
        "normal energy", "holding up", "managing"
    ]
    static let defaultEnergyTired: [String] = [
        "tired", "fatigued", "low energy", "wiped out", "no spoons",
        "running on empty"
    ]
    static let defaultEnergySluggish: [String] = [
        "sluggish", "dragging", "lethargic", "moving slowly",
        "burnt out", "drained", "crashed", "crashing",
        "hit a wall", "sudden fatigue", "shutdown", "melted down", "wiped",
        "feel heavy", "feeling heavy", "felt heavy", "feel empty of energy",
        "totally spent", "feel spent", "felt spent", "feeling slow", "feel slow"
    ]

    // Focus (1=foggy … 5=lockedIn)
    static let defaultFocusLockedIn: [String] = [
        "locked in", "hyperfocus", "hyperfocused", "deep focus", "in the zone",
        "flow state", "tunnel vision", "locked on", "flowing"
    ]
    static let defaultFocusSharp: [String] = [
        "sharp", "focused", "focus", "on task", "concentrating", "concentration",
        "on track", "clear", "keeping up"
    ]
    static let defaultFocusPresent: [String] = [
        "present", "grounded", "with it", "tuned in", "showing up",
        "engaged"
    ]
    static let defaultFocusDistracted: [String] = [
        "distracted", "distractible", "can't focus", "unable to concentrate",
        "zoning out", "spacing out", "daydreaming", "mind wandering", "pulled",
        "unsteady", "sidetracked"
    ]
    static let defaultFocusFoggy: [String] = [
        "brain fog", "foggy", "hazy", "drifting", "cloudy", "mental haze",
        "fuzzy", "can't think straight", "jumbled thoughts", "groggy",
        "feel lost", "feeling lost", "went blank", "drawing a blank",
        "feel scattered", "feeling scattered", "felt scattered", "so scattered",
        "all over the place", "fragmented",
        "jumping around", "all over the shop", "mind blank"
    ]

    // Feelings — curated subset (lexicon.json is the superset). "feeling seen"/
    // "feel seen" are feel-context phrases that replaced the bare "seen", which
    // fired on "seen my therapist".
    static let defaultFeelings: [String] = [
        "grateful", "hopeful", "excited", "content", "inspired", "proud",
        "playful", "loved", "peaceful", "motivated",
        "curious", "reflective", "nostalgic", "restless", "indifferent",
        "bored", "uncertain", "tense",
        "anxious", "sad", "frustrated", "overwhelmed", "lonely", "angry",
        "scared", "guilty", "ashamed", "exhausted", "panicked",
        "feeling seen", "feel seen"
    ]

    static let defaultTaskCompletionCues: [String] = [
        "finished", "completed", "done", "checked off", "ticked off", "wrapped up",
        "got through", "got shit done", "did the thing", "nailed it", "smashed it"
    ]
    static let defaultTaskAvoidanceCues: [String] = [
        "avoided", "avoiding", "procrastinated", "procrastinating", "put off",
        "kept putting off", "couldn't start", "stuck on", "paralyzed by",
        "task paralysis", "initiation paralysis", "frozen", "stuck"
    ]
    static let defaultWinCues: [String] = [
        "proud", "accomplished", "win", "nailed it", "nailed", "smashed it",
        "victory", "achievement", "crushed it", "got shit done", "did the thing"
    ]
    static let defaultOverwhelmCues: [String] = [
        "overwhelmed", "too much", "drowning", "buried", "can't keep up",
        "paralyzed", "decision fatigue", "chaos"
    ]

    static let defaultExecutiveDysfunction: [String] = [
        "executive dysfunction", "can't start", "task paralysis", "initiation paralysis",
        "procrastinating", "avoidance", "avoiding", "stuck", "frozen",
        "decision fatigue", "can't prioritize", "disorganized",
        "time blind", "no sense of time", "running late", "missed deadline",
        "forgot to eat", "forgot to drink", "body doubling"
    ]

    static let defaultAppointmentCues: [String] = [
        "appointment", "psychiatrist", "therapist", "doctor", "dentist",
        "check-up", "checkup", "follow-up", "follow up"
    ]

    static let defaultSideEffectCues: [String] = [
        "dry mouth", "headache", "nausea", "loss of appetite", "insomnia", "jittery",
        "heart racing", "palpitations", "anxious", "irritable", "moody", "crash",
        "stomach ache", "dizzy", "racing pulse", "sweating", "clenched jaw",
        "tense", "tight shoulders", "appetite gone", "not hungry", "dehydrated",
        "grinding teeth", "rebound", "wearing off", "zombie", "emotionless",
        "flat affect", "no personality"
    ]

    static let defaultPhysicalStim: [String] = [
        "fidgeting", "bouncing", "leg bouncing", "tapping", "stimming",
        "hand flapping", "pacing", "can't sit still", "skin picking",
        "nail biting", "hair pulling"
    ]
    static let defaultPhysicalSideEffects: [String] = [
        "headache", "stomach ache", "nausea", "dry mouth", "dizzy",
        "heart racing", "racing pulse", "palpitations", "sweating",
        "clenched jaw", "tense", "tight shoulders", "appetite gone",
        "not hungry", "dehydrated", "grinding teeth"
    ]

    static let defaultSleepQualityGood: [String] = [
        "slept well", "slept like a rock", "good sleep", "rested", "refreshed",
        "deep sleep", "solid sleep"
    ]
    static let defaultSleepQualityBad: [String] = [
        "slept badly", "broken sleep", "woke up every hour", "nightmares",
        "vivid dreams", "overslept", "couldn't wake up",
        "tossed and turned", "woke up", "nightmare", "bad sleep", "light sleep"
    ]
    static let defaultSleepInsomnia: [String] = [
        "insomnia", "can't sleep", "wired at night", "racing thoughts at bedtime",
        "took hours to fall asleep", "couldn't switch off"
    ]

    static let defaultReboundTerms: [String] = [
        "rebound", "medication rebound", "wearing off", "drop off",
        "steep drop", "afternoon crash", "evening crash", "symptoms flared",
        "rebound irritability", "rebound hyperactivity", "rebound sadness",
        "worse than usual"
    ]

    static let defaultAppetiteLoss: [String] = [
        "no appetite", "food is gross", "force eating", "forgot lunch",
        "skipped dinner", "not hungry", "can't eat", "appetite gone"
    ]
    static let defaultAppetiteReturn: [String] = [
        "finally hungry", "ravenous", "binge ate", "crash eating",
        "starving", "ate everything"
    ]

    static let defaultNegationTokens: [String] = [
        "not", "never", "no", "n't", "without"
    ]

    /// Medication-specific "did not take" verbs. These are NOT generic negation
    /// (they used to wrongly suppress unrelated cues, e.g. "I skipped lunch but
    /// nailed the report" dropped the win). They mark a med as not-taken only when
    /// they appear within the med's own clause — see `medNotTakenVerbs` usage.
    static let defaultMedNotTakenVerbs: [String] = [
        "forgot", "missed", "skipped", "skip", "forget"
    ]

    static let defaultTimeOfDayKeywords: [(String, String)] = [
        ("morning", "morning"), ("afternoon", "afternoon"), ("evening", "evening"),
        ("night", "night"), ("bedtime", "bedtime"), ("lunch", "afternoon"),
        ("breakfast", "morning"), ("dinner", "evening")
    ]

    /// Activity vocabulary. All categories use surface-only matching (lemmaEnabled: false)
    /// to avoid gerund polysemy FPs (e.g. "reading"→"read" would fire on unrelated text).
    /// The 6 original categories are carried verbatim; 5 new ones added in Task 10.
    static let defaultActivityKeywords: [(category: String, keywords: [String])] = [
        ("Resting",      ["resting", "relaxing", "chilling", "laying down", "lying down", "rest", "taking it easy"]),
        ("Hobbies",      ["hobby", "reading", "gaming", "drawing", "playing", "painting", "crafting", "writing"]),
        ("Hanging Out",  ["hanging out", "with friends", "socializing", "party", "gathering", "meeting up"]),
        ("Fitness",      ["gym", "running", "workout", "exercise", "walking", "jogging", "cycling", "swimming", "yoga"]),
        ("Eating",       ["eating", "breakfast", "lunch", "dinner", "snack", "cooking", "meal", "food"]),
        ("Driving",      ["driving", "commuting", "in the car", "on the bus", "on the train", "traveling"]),
        ("Work",         ["work", "meeting", "meetings", "deadline", "email", "emails", "office", "standup", "presentation", "shift"]),
        ("Chores",       ["laundry", "dishes", "cleaning", "tidying", "tidied", "vacuum", "vacuuming", "groceries", "grocery run"]),
        ("Errands",      ["errand", "errands", "post office", "bank", "pharmacy", "dry cleaner", "returns"]),
        ("Outdoors",     ["outside", "park", "nature", "fresh air", "hike", "hiking", "garden", "gardening", "walk in the park", "long walk"]),
        ("Screen Time",  ["scrolling", "doomscrolling", "netflix", "youtube", "tiktok", "instagram", "binge watched", "binged", "screen time"])
    ]
}
