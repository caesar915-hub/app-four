import Foundation
import NaturalLanguage

/// On-device NaturalLanguage-based extractor for ADHD journal entries.
/// Instant; no model download required. iOS 26+ / macOS 15+.
///
/// `nonisolated` at the type level: the whole extraction pipeline is pure over
/// `Sendable` value types and is meant to run off the main actor. Without this,
/// the project default (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`) would make
/// every helper `@MainActor`, which the `nonisolated` `extract(from:)` cannot call.
public nonisolated struct NLNoteExtractor: NoteExtractor, Sendable {
    public let lexicon: Lexicon

    /// Activity cue lists built ONCE from the lexicon at init. Surface-only matching
    /// (lemmaEnabled: false) is required: gerunds like "reading"→"read" cause polysemy
    /// false positives, so activities never use the verb-lemma fallback (Task 9).
    private let activityCueLists: [(activity: String, list: CueMatcher.CueList)]

    /// Pre-tokenized cue lists, built ONCE from the lexicon at init. Every cue's
    /// token sequence is computed here instead of on every (sentence × cue) check.
    private struct CachedCues {
        let sideEffect, taskCompletion, taskAvoidance, win, overwhelm: CueMatcher.CueList
        let executiveDysfunction, physicalStim, physicalSideEffects, rebound: CueMatcher.CueList
        let appetiteLoss, appetiteReturn, appointment, emotions: CueMatcher.CueList
        let energyCharged, energyAlert, energySteady, energyTired, energySluggish: CueMatcher.CueList
        let focusLockedIn, focusSharp, focusPresent, focusDistracted, focusFoggy: CueMatcher.CueList
        let moodSurfaces, medications: CueMatcher.CueList
        let timeOfDay: CueMatcher.CueList
        /// Mood needs the (word → label) mapping; pre-tokenize each entry so
        /// `nearestMood` can scan for the longest contiguous-run match without
        /// re-tokenizing per call (preserves Task 5 longest-match-wins). Each entry
        /// carries a `Cue` so single-word mood cues get the verb-lemma fallback.
        let moodEntries: [(cue: CueMatcher.Cue, label: String)]
        /// Energy/focus carry their level + the pre-tokenized cue so the nearest-match
        /// scan can return the matched surface phrase for phraseLength selection (Task 3).
        let energyEntries: [(cue: CueMatcher.Cue, level: EnergyLevel)]
        let focusEntries: [(cue: CueMatcher.Cue, level: FocusLevel)]
    }
    private let cues: CachedCues

    public init(lexicon: Lexicon = Lexicon()) {
        self.lexicon = lexicon

        self.activityCueLists = lexicon.activityKeywords.map {
            ($0.category, CueMatcher.makeList($0.keywords, lemmaEnabled: false))
        }

        let energyByLevel: [(EnergyLevel, [String])] = [
            (.charged, lexicon.energyCharged), (.alert, lexicon.energyAlert),
            (.steady, lexicon.energySteady), (.tired, lexicon.energyTired),
            (.sluggish, lexicon.energySluggish)
        ]
        let focusByLevel: [(FocusLevel, [String])] = [
            (.lockedIn, lexicon.focusLockedIn), (.sharp, lexicon.focusSharp),
            (.present, lexicon.focusPresent), (.distracted, lexicon.focusDistracted),
            (.foggy, lexicon.focusFoggy)
        ]

        self.cues = CachedCues(
            sideEffect: CueMatcher.makeList(lexicon.sideEffectCues, lemmaEnabled: false),
            taskCompletion: CueMatcher.makeList(lexicon.taskCompletionCues),
            taskAvoidance: CueMatcher.makeList(lexicon.taskAvoidanceCues),
            win: CueMatcher.makeList(lexicon.winCues),
            overwhelm: CueMatcher.makeList(lexicon.overwhelmCues),
            executiveDysfunction: CueMatcher.makeList(lexicon.executiveDysfunction),
            physicalStim: CueMatcher.makeList(lexicon.physicalStim),
            physicalSideEffects: CueMatcher.makeList(lexicon.physicalSideEffects, lemmaEnabled: false),
            rebound: CueMatcher.makeList(lexicon.reboundTerms, lemmaEnabled: false),
            appetiteLoss: CueMatcher.makeList(lexicon.appetiteLoss, lemmaEnabled: false),
            appetiteReturn: CueMatcher.makeList(lexicon.appetiteReturn, lemmaEnabled: false),
            appointment: CueMatcher.makeList(lexicon.appointmentCues, lemmaEnabled: false),
            emotions: CueMatcher.makeList(lexicon.emotions),
            energyCharged: CueMatcher.makeList(lexicon.energyCharged),
            energyAlert: CueMatcher.makeList(lexicon.energyAlert),
            energySteady: CueMatcher.makeList(lexicon.energySteady),
            energyTired: CueMatcher.makeList(lexicon.energyTired),
            energySluggish: CueMatcher.makeList(lexicon.energySluggish),
            focusLockedIn: CueMatcher.makeList(lexicon.focusLockedIn),
            focusSharp: CueMatcher.makeList(lexicon.focusSharp),
            focusPresent: CueMatcher.makeList(lexicon.focusPresent),
            focusDistracted: CueMatcher.makeList(lexicon.focusDistracted),
            focusFoggy: CueMatcher.makeList(lexicon.focusFoggy),
            moodSurfaces: CueMatcher.makeList(lexicon.moodSpecific.map(\.word)),
            medications: CueMatcher.makeList(lexicon.medications.map { $0.lowercased() }),
            timeOfDay: CueMatcher.makeList(lexicon.timeOfDayKeywords.map(\.0)),
            moodEntries: lexicon.moodSpecific.map {
                (CueMatcher.makeList([$0.word]).cues[0], $0.label)
            },
            energyEntries: energyByLevel.flatMap { level, words in
                CueMatcher.makeList(words).cues.map { ($0, level) }
            },
            focusEntries: focusByLevel.flatMap { level, words in
                CueMatcher.makeList(words).cues.map { ($0, level) }
            }
        )
    }

    /// `nonisolated` so callers can run it off the main actor (the project default
    /// is `MainActor` isolation). It's pure over value types — `Lexicon` is
    /// `Sendable`, `NoteExtraction` is `Sendable` — so it's safe on any executor.
    public nonisolated func extract(from transcript: String) -> NoteExtraction {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return NoteExtraction(title: "Empty Note")
        }

        let sentences = splitSentences(text)
        var extraction = NoteExtraction()

        // 1. Mood (per-sentence, aggregated). Each signal has an explicit, documented
        //    policy (P1.2): mood = present-tense-wins, energy/focus = strongest-match-wins.
        var moodCandidates: [(label: String, temporalWeight: Double, sentenceIndex: Int)] = []
        var weakMoodCandidates: [(label: String, temporalWeight: Double, sentenceIndex: Int)] = []
        var energyCandidates: [(level: EnergyLevel, phraseLength: Int)] = []
        var weakEnergyCandidates: [(level: EnergyLevel, phraseLength: Int)] = []
        var focusCandidates: [(level: FocusLevel, phraseLength: Int)] = []

        // 2. Medications, tasks, wins, etc. collected per-sentence
        var medEvents: [MedEvent] = []
        var detectedEmotions: [String] = []
        var sideEffects: [String] = []
        var tasksCompleted: [String] = []
        var tasksAvoided: [String] = []
        var wins: [String] = []
        var overwhelm: [String] = []
        var activities: [String] = []
        var sleepMentioned = false
        var sleepHours: Double?
        var sleepQuality: String?

        // 3. Expanded triage fields
        var executiveDysfunction: [String] = []
        var physicalStim: [String] = []
        var physicalSideEffects: [String] = []
        var reboundTerms: [String] = []
        var appetiteLoss: [String] = []
        var appetiteReturn: [String] = []
        var appointments: [String] = []

        // 4. Structured regex extractions (take first match across whole text)
        let extractedDose: String? = ADHDRegexPatterns.extractDose(from: text)
        let extractedSleepHours: Double? = ADHDRegexPatterns.extractSleepHours(from: text)
        let extractedOnset: Int? = ADHDRegexPatterns.extractOnsetMinutes(from: text)
        let extractedDuration: Double? = ADHDRegexPatterns.extractDurationHours(from: text)
        let extractedCrashTime: String? = ADHDRegexPatterns.extractCrashTime(from: text)
        let extractedIntakeContext: String? = ADHDRegexPatterns.extractIntakeContext(from: text)

        let tenseClassifier = TenseClassifier()

        for (sentenceIndex, sentence) in sentences.enumerated() {
            // Cooperative cancellation: bail between sentences so cancelProcessing()
            // can interrupt a long transcript. Returns the partial extraction so far.
            if Task.isCancelled { break }
            let lower = sentence.lowercased()
            let tokens = CueMatcher.tokenizeWithLemmas(sentence)

            // Mood via exact lexicon seed (with targeted negation). Tag each
            // candidate with its sentence's tense so present-tense moods win the
            // headline (past moods are context).
            if let moodMatch = nearestMood(tokens: tokens) {
                let negated = isNegatedBefore(target: moodMatch.matchedPhrase, in: lower)
                let effectiveMood = negated ? flipMood(moodMatch.label) : moodMatch.label
                let weight = tenseClassifier.tense(of: sentence).temporalWeight
                moodCandidates.append((effectiveMood, weight, sentenceIndex))
            } else if let weak = weakMood(in: lower) {
                // Mood-gated fallback: sentence names "mood" but no strong cue matched.
                // Same gating/negation rationale as energy; used only if no strong mood
                // cue exists anywhere (resolved after the loop).
                let negated = isNegatedBefore(target: weak.matchedPhrase, in: lower)
                let effectiveMood = negated ? flipMood(weak.label) : weak.label
                let weight = tenseClassifier.tense(of: sentence).temporalWeight
                weakMoodCandidates.append((effectiveMood, weight, sentenceIndex))
            }

            // Energy (with targeted negation) — collect candidates; strongest match
            // (longest exact lexicon phrase) wins after the loop, not the last sentence (P1.2).
            if let energyMatch = nearestEnergy(tokens: tokens) {
                let negated = isNegatedBefore(target: energyMatch.phrase, in: lower)
                let effectiveEnergy = negated ? flipEnergy(energyMatch.level) : energyMatch.level
                energyCandidates.append((effectiveEnergy, energyMatch.phrase.count))
            } else if let weak = weakEnergy(in: lower) {
                // Energy-gated fallback: the sentence names "energy"/"energetic" but no
                // strong cue matched. Generic descriptors are safe here — they are only
                // consulted inside an energy sentence, never globally. Negation ("no
                // energy", "no dips") flips via the shared machinery. Used only if no
                // strong cue exists anywhere in the note (resolved after the loop).
                let negated = isNegatedBefore(target: weak.phrase, in: lower)
                let effectiveEnergy = negated ? flipEnergy(weak.level) : weak.level
                weakEnergyCandidates.append((effectiveEnergy, weak.phrase.count))
            }

            // Focus (with targeted negation) — same strongest-match-wins policy.
            if let focusMatch = nearestFocus(tokens: tokens) {
                let negated = isNegatedBefore(target: focusMatch.phrase, in: lower)
                let effectiveFocus = negated ? flipFocus(focusMatch.level) : focusMatch.level
                focusCandidates.append((effectiveFocus, focusMatch.phrase.count))
            }

            // Medications (can be multiple per sentence)
            let meds = extractMedications(from: sentence)
            medEvents.append(contentsOf: meds)

            // Single match primitive for every sentence-level cue category:
            // the LONGEST cue in the list that appears as a whole word/phrase, and
            // is not negated, marks the category present. Negation targets the most
            // specific matched cue (a behavior-preserving change vs the former
            // first-match). The category→cached-list table below is the single
            // source of cue collection (cues tokenized once at init).
            func nonNegatedCueMatch(_ list: CueMatcher.CueList) -> Bool {
                guard let cue = CueMatcher.longestMatch(in: tokens, list: list) else { return false }
                return !isNegatedBefore(target: cue, in: lower)
            }

            if nonNegatedCueMatch(cues.sideEffect)            { sideEffects.append(sentence) }
            if nonNegatedCueMatch(cues.taskCompletion)        { tasksCompleted.append(sentence) }
            if nonNegatedCueMatch(cues.taskAvoidance)         { tasksAvoided.append(sentence) }
            if nonNegatedCueMatch(cues.win)                   { wins.append(sentence) }
            if nonNegatedCueMatch(cues.overwhelm)             { overwhelm.append(sentence) }
            if nonNegatedCueMatch(cues.executiveDysfunction)  { executiveDysfunction.append(sentence) }
            if nonNegatedCueMatch(cues.physicalStim)          { physicalStim.append(sentence) }
            if nonNegatedCueMatch(cues.physicalSideEffects)   { physicalSideEffects.append(sentence) }
            if nonNegatedCueMatch(cues.rebound)               { reboundTerms.append(sentence) }
            if nonNegatedCueMatch(cues.appetiteLoss)          { appetiteLoss.append(sentence) }
            if nonNegatedCueMatch(cues.appetiteReturn)        { appetiteReturn.append(sentence) }
            if nonNegatedCueMatch(cues.appointment)           { appointments.append(sentence) }

            // Sleep — word-boundary match over a curated vocabulary (substring `contains`
            // catches "interest"/"snap"); covers kip/wink/rested/waking/lay-awake and a
            // bare "<n> hours … night" with no explicit sleep verb.
            if mentionsSleep(lower) {
                sleepMentioned = true
                if let hours = extractSleepHours(from: sentence) {
                    sleepHours = hours
                }
                if let quality = extractSleepQuality(from: sentence) {
                    sleepQuality = quality
                }
            }

            // Emotions: every non-negated emotion cue (deduped), not just the first.
            // Iterate the pre-tokenized pairs so each cue's tokens are reused.
            for cue in cues.emotions.cues {
                if CueMatcher.contains(tokens, cue) && !isNegatedBefore(target: cue.surface, in: lower) {
                    if !detectedEmotions.contains(cue.surface) {
                        detectedEmotions.append(cue.surface)
                    }
                }
            }

            // Activity detection
            for (activity, list) in activityCueLists {
                if CueMatcher.anyMatch(in: tokens, list: list) {
                    activities.append(activity)
                }
            }
        }

        // Headline mood = present-tense-wins: highest temporal weight, then most
        // recent sentence. Past-tense moods are context and only win when nothing
        // more present exists. No sentiment-valence fallback: NLTagger paragraph
        // sentiment is too negatively biased on short factual text (neutral
        // sentences score -0.6 to -0.8), so it fabricated "low" moods on
        // mood-free entries. Mood is exact lexicon match only.
        // Strong cues win; the mood-gated weak fallback only fills total misses.
        let moodPool = moodCandidates.isEmpty ? weakMoodCandidates : moodCandidates
        if let bestMood = moodPool.max(by: { a, b in
            if a.temporalWeight != b.temporalWeight { return a.temporalWeight < b.temporalWeight }
            return a.sentenceIndex < b.sentenceIndex
        }) {
            extraction.mood = bestMood.label
        }

        // Energy / focus = strongest match wins: longest exact lexicon phrase across
        // sentences, so a more specific multi-word hit beats a shorter one.
        // Strong cues win outright; the energy-gated weak fallback only fills in when
        // no strong energy cue matched anywhere in the note (recall for hedged phrasing).
        let energyPool = energyCandidates.isEmpty ? weakEnergyCandidates : energyCandidates
        if let bestEnergy = energyPool.max(by: { $0.phraseLength < $1.phraseLength }) {
            extraction.energy = bestEnergy.level
        }
        if let bestFocus = focusCandidates.max(by: { $0.phraseLength < $1.phraseLength }) {
            extraction.focus = bestFocus.level
        }

        extraction.emotions = detectedEmotions
        extraction.activities = Array(Set(activities)).sorted()
        extraction.medications = medEvents

        extraction.sideEffects = Array(Set(sideEffects)).sorted()
        // If the whole-text hours regex found a duration, sleep was mentioned even if
        // no keyword sentence triggered ("got a solid 8 hours last night").
        extraction.sleep = SleepNote(mentioned: sleepMentioned || extractedSleepHours != nil,
                                     hours: sleepHours, quality: sleepQuality)
        extraction.tasksCompleted = Array(Set(tasksCompleted)).sorted()
        extraction.tasksAvoided = Array(Set(tasksAvoided)).sorted()
        extraction.wins = Array(Set(wins)).sorted()
        extraction.overwhelm = Array(Set(overwhelm)).sorted()

        extraction.executiveDysfunction = Array(Set(executiveDysfunction)).sorted()
        extraction.physicalStim = Array(Set(physicalStim)).sorted()
        extraction.physicalSideEffects = Array(Set(physicalSideEffects)).sorted()
        extraction.reboundTerms = Array(Set(reboundTerms)).sorted()
        extraction.appetiteLoss = Array(Set(appetiteLoss)).sorted()
        extraction.appetiteReturn = Array(Set(appetiteReturn)).sorted()
        extraction.appointments = Array(Set(appointments)).sorted()

        extraction.extractedDose = extractedDose
        extraction.sleepHours = extractedSleepHours ?? sleepHours
        extraction.onsetMinutes = extractedOnset
        extraction.durationHours = extractedDuration
        extraction.crashTime = extractedCrashTime
        extraction.intakeContext = extractedIntakeContext

        // Extractive highlights
        extraction.highlights = extractHighlights(from: sentences)

        // Title from top highlight
        extraction.title = makeTitle(from: extraction.highlights, fallback: text)

        return extraction
    }

    // MARK: - Sentences

    private func splitSentences(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if sentence.count > 3 {
                sentences.append(sentence)
            }
            return true
        }
        return sentences.isEmpty ? [text] : sentences
    }

    // MARK: - Targeted Negation

    /// Returns true if a negation token appears before the target phrase in the text.
    /// "no" uses a window of 1 (must be the immediately preceding word) to avoid
    /// false negation when "no" belongs to a different clause ("no special energy focus…").
    /// All other tokens use a window of 5.
    private func isNegatedBefore(target: String, in text: String) -> Bool {
        guard let targetRange = text.range(of: target) else { return false }
        let prefix = String(text[..<targetRange.lowerBound])
        let prefixWords = prefix.split(separator: " ").map(String.init)
        let wideWindow = Array(prefixWords.suffix(5))
        let narrowWindow = Array(prefixWords.suffix(1))
        for token in lexicon.negationTokens {
            let window = token == "no" ? narrowWindow : wideWindow
            for word in window {
                if token == "n't" {
                    if word.hasSuffix("n't") { return true }
                } else {
                    if word == token { return true }
                }
            }
        }
        return false
    }

    private func flipMood(_ mood: String) -> String {
        switch mood {
        case "great", "good": return "low"
        case "low": return "okay"
        case "okay": return "low"
        case "flat": return "okay"
        default: return mood
        }
    }

    private func flipEnergy(_ energy: EnergyLevel) -> EnergyLevel {
        switch energy {
        case .charged:  return .sluggish
        case .alert:    return .tired
        case .steady:   return .tired
        case .tired:    return .steady
        case .sluggish: return .alert
        }
    }

    private func flipFocus(_ focus: FocusLevel) -> FocusLevel {
        switch focus {
        case .lockedIn:   return .foggy
        case .sharp:      return .distracted
        case .present:    return .distracted
        case .distracted: return .present
        case .foggy:      return .sharp
        }
    }

    // MARK: - Mood / Energy / Focus detection (exact-match, longest-phrase-wins)

    private struct MoodMatch {
        let label: String
        let matchedPhrase: String
    }

    private struct CategoryMatch<T> {
        let level: T
        let phrase: String
    }

    private func nearestMood(tokens: [CueMatcher.Token]) -> MoodMatch? {
        // Longest matching phrase wins: more words = more specific signal
        // ("feel nothing" beats "nothing"-class single words; "not bad" beats "bad").
        // Scans the pre-tokenized mood entries; cue tokens are computed once at init.
        var best: MoodMatch?
        for entry in cues.moodEntries where CueMatcher.contains(tokens, entry.cue) {
            if best == nil || entry.cue.surface.count > best!.matchedPhrase.count {
                best = MoodMatch(label: entry.label, matchedPhrase: entry.cue.surface)
            }
        }
        return best
    }

    private func nearestEnergy(tokens: [CueMatcher.Token]) -> CategoryMatch<EnergyLevel>? {
        var best: CategoryMatch<EnergyLevel>?
        for entry in cues.energyEntries where CueMatcher.contains(tokens, entry.cue) {
            if best == nil || entry.cue.surface.count > best!.phrase.count {
                best = CategoryMatch(level: entry.level, phrase: entry.cue.surface)
            }
        }
        return best
    }

    /// Energy-gated weak descriptors: consulted ONLY when the sentence names energy,
    /// so generic adjectives ("good"/"fine"/"rubbish") can never fire globally. Decline
    /// words map to `.tired`; "no dips"/"no energy" then flip to `.steady`/`.tired` via
    /// the shared negation machinery. Ordered so extreme levels beat the neutral default.
    private static let weakEnergyTable: [(word: String, level: EnergyLevel)] = [
        ("great", .charged), ("cracking", .charged), ("brilliant", .charged),
        ("fantastic", .charged), ("amazing", .charged), ("excellent", .charged),
        ("loads", .charged), ("tons", .charged), ("plenty", .charged), ("soaring", .charged),
        ("rubbish", .tired), ("poor", .tired), ("low", .tired), ("flat", .tired),
        ("sapped", .tired), ("drained", .tired), ("empty", .tired), ("fumes", .tired),
        ("faded", .tired), ("fading", .tired), ("tapered", .tired), ("tapering", .tired),
        ("dipped", .tired), ("dipping", .tired), ("dip", .tired), ("dips", .tired),
        ("dropped", .tired), ("dropping", .tired), ("declined", .tired), ("waned", .tired),
        ("slump", .tired), ("slumps", .tired), ("slumped", .tired), ("petered", .tired),
        ("fizzled", .tired), ("dwindled", .tired), ("nil", .tired), ("zero", .tired),
        ("meh", .tired), ("nap", .tired), ("lacking", .tired), ("sluggish", .tired),
        ("good", .steady), ("decent", .steady), ("fine", .steady), ("alright", .steady),
        ("okay", .steady), ("solid", .steady), ("consistent", .steady), ("reliable", .steady),
        ("stable", .steady), ("normal", .steady), ("manageable", .steady), ("held", .steady),
        ("hovered", .steady), ("even", .steady), ("moderate", .steady), ("reasonable", .steady),
        ("steady", .steady),
    ]

    /// Energy-presence fallback for sentences that name energy but match no strong cue.
    private func weakEnergy(in lower: String) -> CategoryMatch<EnergyLevel>? {
        guard lower.contains("energy") || lower.contains("energetic") else { return nil }
        for (word, level) in Self.weakEnergyTable
        where lower.range(of: "\\b\(word)\\b", options: .regularExpression) != nil {
            return CategoryMatch(level: level, phrase: word)
        }
        // Energy named but no descriptor -> neutral present; "no energy" flips to tired.
        return CategoryMatch(level: .steady, phrase: "energy")
    }

    /// Mood-gated weak descriptors: consulted ONLY when the sentence names "mood", so
    /// generic adjectives can't fire globally. Maps to the five mood labels; negation
    /// flips via flipMood. Ordered so extreme moods beat the neutral default.
    private static let weakMoodTable: [(word: String, label: String)] = [
        ("great", "great"), ("fantastic", "great"), ("amazing", "great"), ("brilliant", "great"),
        ("wonderful", "great"), ("excellent", "great"), ("elated", "great"), ("buzzing", "great"),
        ("rough", "low"), ("low", "low"), ("bad", "low"), ("down", "low"), ("sad", "low"),
        ("gloomy", "low"), ("miserable", "low"), ("terrible", "low"), ("awful", "low"),
        ("shot", "low"), ("tanked", "low"), ("withdrawn", "low"), ("irritable", "low"),
        ("foul", "low"), ("dark", "low"), ("dejected", "low"), ("snappy", "low"),
        ("flat", "flat"),
        ("good", "good"), ("positive", "good"), ("happy", "good"), ("content", "good"),
        ("calm", "good"), ("relaxed", "good"), ("stable", "good"), ("cheerful", "good"),
        ("upbeat", "good"), ("optimistic", "good"), ("pleased", "good"), ("lifted", "good"),
        ("okay", "okay"), ("ok", "okay"), ("meh", "okay"), ("middling", "okay"),
        ("neutral", "okay"), ("alright", "okay"), ("fine", "okay"), ("even", "okay"),
    ]

    /// Mood-presence fallback for sentences that name mood but match no strong cue.
    private func weakMood(in lower: String) -> MoodMatch? {
        guard lower.range(of: "\\bmood\\b", options: .regularExpression) != nil else { return nil }
        for (word, label) in Self.weakMoodTable
        where lower.range(of: "\\b\(word)\\b", options: .regularExpression) != nil {
            return MoodMatch(label: label, matchedPhrase: word)
        }
        return MoodMatch(label: "okay", matchedPhrase: "mood")
    }

    /// Curated sleep vocabulary, matched on word boundaries (not substring).
    private static let sleepWords = [
        "sleep", "slept", "asleep", "sleeping", "sleepless", "oversleep", "overslept",
        "woke", "woken", "awoke", "waking", "insomnia", "nightmare", "nightmares",
        "nap", "napped", "napping", "kip", "rested", "restless", "dozed", "dozing",
        "slumber", "bedtime",
    ]

    /// True if the sentence refers to sleep — curated words + a few multiword/duration
    /// patterns ("a wink", "lay awake", "<n> hours … night").
    private func mentionsSleep(_ lower: String) -> Bool {
        for w in Self.sleepWords
        where lower.range(of: "\\b\(w)\\b", options: .regularExpression) != nil {
            return true
        }
        let patterns = [
            "\\bdreams?\\b", "\\bwink\\b", "\\bl(?:a|i)e? awake\\b",
            "\\b(?:hours?|hrs?)\\b[^.!?]*\\bnight\\b",
            "\\bnight\\b[^.!?]*\\b(?:hours?|hrs?)\\b",
        ]
        return patterns.contains { lower.range(of: $0, options: .regularExpression) != nil }
    }

    private func nearestFocus(tokens: [CueMatcher.Token]) -> CategoryMatch<FocusLevel>? {
        var best: CategoryMatch<FocusLevel>?
        for entry in cues.focusEntries where CueMatcher.contains(tokens, entry.cue) {
            if best == nil || entry.cue.surface.count > best!.phrase.count {
                best = CategoryMatch(level: entry.level, phrase: entry.cue.surface)
            }
        }
        return best
    }

    // MARK: - Medication extraction (multiple per sentence)

    private func extractMedications(from sentence: String) -> [MedEvent] {
        let lower = sentence.lowercased()

        // 1. Collect every med name hit with its character range.
        // `surfaceKey` is the lowercased string to use for negation/not-taken checks:
        // for exact hits it equals the canonical name lowercased; for fuzzy hits it's
        // the typo token actually present in the sentence.
        var hits: [(med: String, range: Range<String.Index>, surfaceKey: String)] = []
        for med in lexicon.medications {
            var searchStart = lower.startIndex
            while let r = lower.range(of: med.lowercased(), range: searchStart..<lower.endIndex) {
                hits.append((med, r, med.lowercased()))
                searchStart = r.upperBound
            }
        }
        let tokens = CueMatcher.tokenize(sentence)
        if hits.isEmpty {
            let medContextTokens: Set<String> = ["took", "take", "taking", "taken", "dose", "skipped", "forgot", "missed", "mg", "milligram", "milligrams"]
            let stoplist: Set<String> = ["concert", "concerts", "concerto"]
            let hasContext = ADHDRegexPatterns.extractDose(from: sentence) != nil
                || tokens.contains { medContextTokens.contains($0) }
            if hasContext {
                let singleTokenMeds = lexicon.medications.filter { !$0.contains(" ") }
                for token in tokens where token.count >= 6 && !stoplist.contains(token) {
                    if let canonical = singleTokenMeds.first(where: {
                        CueMatcher.editDistanceIsOne(token, $0.lowercased())
                    }), let r = lower.range(of: token) {
                        hits.append((canonical, r, token))
                    }
                }
            }
        }
        guard !hits.isEmpty else { return [] }

        // 2. De-duplicate overlapping hits: longest canonical name wins per span
        //    ("Concerta XL" suppresses "Concerta"; "dextroamphetamine" suppresses
        //    "amphetamine"). A hit is dropped if its range is fully covered by a
        //    longer hit's range.
        let survivors = hits.filter { candidate in
            !hits.contains { other in
                other.med != candidate.med
                    && other.range.lowerBound <= candidate.range.lowerBound
                    && other.range.upperBound >= candidate.range.upperBound
                    && other.med.count > candidate.med.count
            }
        }

        // 3. Split the sentence into clauses so each med's attributes (dose, time,
        //    quantity, change) are scoped to its own clause, not the whole sentence.
        let clauses = clauseRanges(of: sentence)

        var events: [MedEvent] = []
        for hit in survivors.sorted(by: { $0.range.lowerBound < $1.range.lowerBound }) {
            let clause = clauses.first { $0.contains(hit.range.lowerBound) }
                ?? sentence.startIndex..<sentence.endIndex
            let clauseText = String(sentence[clause])

            let negated = isNegatedBefore(target: hit.surfaceKey, in: lower)
            let notTaken = medNotTaken(med: hit.surfaceKey, in: tokens)
            let dose = extractDose(from: clauseText)
            let (time, timeLabel) = extractPreciseTime(from: clauseText)
            let quantity = detectQuantity(from: clauseText)
            let change = detectMedChange(from: clauseText)
            events.append(MedEvent(name: hit.med, dose: dose, time: time, timeLabel: timeLabel, taken: !(negated || notTaken), quantity: quantity, change: change))
        }
        return events
    }

    /// Split a sentence into clause ranges at coordinating conjunctions, so each
    /// medication's attributes are scoped to the clause it appears in.
    private func clauseRanges(of sentence: String) -> [Range<String.Index>] {
        let lower = sentence.lowercased()
        let breakWords = [" and ", " but ", " then ", " so ", ", "]
        var boundaries: [String.Index] = [sentence.startIndex]
        for bw in breakWords {
            var searchStart = lower.startIndex
            while let r = lower.range(of: bw, range: searchStart..<lower.endIndex) {
                boundaries.append(r.upperBound)
                searchStart = r.upperBound
            }
        }
        boundaries.append(sentence.endIndex)
        boundaries.sort()
        var ranges: [Range<String.Index>] = []
        for i in 0..<(boundaries.count - 1) where boundaries[i] < boundaries[i + 1] {
            ranges.append(boundaries[i]..<boundaries[i + 1])
        }
        return ranges
    }

    /// True if a med-specific not-taken verb (forgot/missed/skipped) appears in
    /// the same clause as the med, before it. A clause boundary is a coordinating
    /// conjunction ("and", "but", "then", "so"), so "I skipped lunch and took my
    /// Concerta" does NOT mark Concerta not-taken, while "I forgot my Concerta"
    /// and "I skipped my Strattera but took my Concerta" resolve per-med.
    private func medNotTaken(med: String, in tokens: [String]) -> Bool {
        let medTokens = CueMatcher.tokenize(med)
        guard let firstMedToken = medTokens.first,
              let medIndex = tokens.firstIndex(of: firstMedToken) else { return false }
        let clauseBreaks: Set<String> = ["and", "but", "then", "so", "while", "after", "before"]
        var i = medIndex - 1
        while i >= 0 {
            let token = tokens[i]
            if clauseBreaks.contains(token) { return false }   // crossed into another clause
            if lexicon.medNotTakenVerbs.contains(token) { return true }
            i -= 1
        }
        return false
    }

    private func detectMedChange(from text: String) -> MedEventChange? {
        let lower = text.lowercased()
        // "finished" intentionally omitted: it ambiguously means finishing a task,
        // not a course of meds. detectMedChange now runs on the med's own clause.
        let stopTerms = ["stopped", "quit", "came off", "discontinued", "ended", "tapered off", "withdrawing from", "withdrew from", "off of", "off my"]
        let startTerms = ["started", "began", "started taking", "went on", "put on", "prescribed", "initiated", "first day", "first time", "commenced"]
        for term in stopTerms {
            if lower.contains(term) { return .stopped }
        }
        for term in startTerms {
            if lower.contains(term) { return .started }
        }
        return nil
    }

    private func detectQuantity(from text: String) -> Double? {
        let lower = text.lowercased()
        let halfTerms = ["half a", "half of", "half my", "half the", "halved", "split the", "split my", "split a", "splitting"]
        for term in halfTerms {
            if lower.contains(term) { return 0.5 }
        }
        if lower.contains("half") && lower.contains("pill") { return 0.5 }
        if lower.contains("half") && lower.contains("tablet") { return 0.5 }
        if lower.contains("half") && lower.contains("dose") { return 0.5 }
        return nil
    }

    private static let doseRegex = try? NSRegularExpression(
        pattern: #"\b\d+(?:\.\d+)?\s?(mg|mcg|milligrams?)\b"#, options: .caseInsensitive
    )

    private func extractDose(from text: String) -> String? {
        guard let regex = Self.doseRegex else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        if let match = regex.firstMatch(in: text, options: [], range: range) {
            let raw = String(text[Range(match.range, in: text)!])
            return raw.replacingOccurrences(of: "milligrams", with: "mg", options: .caseInsensitive)
                      .replacingOccurrences(of: "milligram", with: "mg", options: .caseInsensitive)
        }
        return nil
    }

    private func extractPreciseTime(from text: String) -> (time: String?, label: String?) {
        // 1. NSDataDetector for times like "8am", "3:30 PM"
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let nsRange = NSRange(text.startIndex..., in: text)
        if let match = detector?.firstMatch(in: text, options: [], range: nsRange),
           let date = match.date,
           let labelRange = Range(match.range, in: text) {
            let labelText = String(text[labelRange])
            // Only treat as a concrete time when the matched text contains a digit
            if labelText.contains(where: \.isNumber) {
                let cal = Calendar.current
                let hour = cal.component(.hour, from: date)
                let minute = cal.component(.minute, from: date)
                let label = labelText.trimmingCharacters(in: .whitespaces)
                return (String(format: "%02d:%02d", hour, minute), label)
            }
        }

        // 2. Keyword fallback
        let lower = text.lowercased()
        for (keyword, _) in lexicon.timeOfDayKeywords {
            if lower.contains(keyword) { return (nil, keyword) }
        }
        return (nil, nil)
    }

    // MARK: - Sleep

    /// Compiled once: require a sleep-duration phrase, not just any "N hours" in a
    /// sentence that mentions sleep ("couldn't sleep, worked 12 hours" must NOT
    /// yield 12h). A duration verb/phrase must precede the number.
    private static let numberWords: [String: Double] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6,
        "seven": 7, "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12
    ]
    // This runs ONLY on a sentence that already mentions sleep (caller-gated), so a
    // trigger verb is not required — a bare "<n> hours" / "sleep <n>" is safe here and
    // "three-hour lab session" never reaches this (it lives in a non-sleep sentence).
    // Accepts digits OR spelled-out numbers, optional "and a half", hrs/hr/h units.
    private static let sleepHoursRegex = try? NSRegularExpression(
        pattern: #"(?i)\b(\d{1,2}(?:\.\d)?|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)(\s+and\s+a\s+half)?\s*(?:hours?|hrs?|hr|h)\b"#
    )
    // Fallback for the terse "sleep 7" / "slept 7" phrasing (no unit).
    private static let sleepBareRegex = try? NSRegularExpression(
        pattern: #"(?i)\b(?:sleep|slept)\s+(\d{1,2}(?:\.\d)?)\b"#
    )
    // Activity verbs that govern an "N hours" duration that is NOT sleep. Without this,
    // the caller-gated bare-hours match logs work hours as sleep when both share one
    // sentence ("I couldn't sleep, so I worked 12 hours" -> must stay nil). Genuine sleep
    // phrasings ("got 8 hours last night", "slept 7") have no such verb before the number.
    private static let nonSleepHourVerbs: Set<String> = [
        "worked", "work", "working", "ran", "run", "running", "drove", "drive", "driving",
        "spent", "study", "studied", "studying", "played", "playing", "walked", "walking",
        "cycled", "commuted", "travelled", "traveled", "hiked"
    ]

    private func extractSleepHours(from text: String) -> Double? {
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        if let regex = Self.sleepHoursRegex {
            for m in regex.matches(in: text, options: [], range: full) {
                if Self.hoursGovernedByActivityVerb(in: ns, numberRange: m.range(at: 1)) { continue }
                let token = ns.substring(with: m.range(at: 1)).lowercased()
                if let base = Double(token) ?? Self.numberWords[token] {
                    let half = m.range(at: 2).location != NSNotFound
                    return half ? base + 0.5 : base
                }
            }
        }
        if let regex = Self.sleepBareRegex,
           let m = regex.firstMatch(in: text, options: [], range: full) {
            return Double(ns.substring(with: m.range(at: 1)))
        }
        return nil
    }

    /// True when the word immediately before the matched number is a non-sleep activity
    /// verb (so the duration is work/exercise time, not sleep).
    private static func hoursGovernedByActivityVerb(in ns: NSString, numberRange: NSRange) -> Bool {
        guard numberRange.location != NSNotFound, numberRange.location > 0 else { return false }
        let before = ns.substring(to: numberRange.location).lowercased()
        guard let last = before.split(whereSeparator: { !$0.isLetter }).last else { return false }
        return nonSleepHourVerbs.contains(String(last))
    }

    private func extractSleepQuality(from text: String) -> String? {
        let lower = text.lowercased()
        for good in lexicon.sleepQualityGood {
            if lower.contains(good) { return "good" }
        }
        for bad in lexicon.sleepQualityBad {
            if lower.contains(bad) { return "poor" }
        }
        for insomnia in lexicon.sleepInsomnia {
            if lower.contains(insomnia) { return "insomnia" }
        }
        return nil
    }

    // MARK: - Highlights

    private func extractHighlights(from sentences: [String]) -> [String] {
        guard !sentences.isEmpty else { return [] }

        var scored: [(sentence: String, score: Double)] = []
        for sentence in sentences {
            var score = 0.0
            let tokens = CueMatcher.tokenizeWithLemmas(sentence)

            // No sentiment term: NLTagger's paragraph sentiment is negatively biased
            // on neutral factual text (≈ -0.6), so abs() rewarded filler. Cue
            // presence is the salience signal; sentiment added noise, not signal.
            func hasAny(_ list: CueMatcher.CueList) -> Bool {
                CueMatcher.anyMatch(in: tokens, list: list)
            }

            if hasAny(cues.medications) { score += 3.0 }
            if hasAny(cues.timeOfDay) { score += 1.0 }
            if hasAny(cues.taskCompletion) || hasAny(cues.taskAvoidance) { score += 2.0 }
            if hasAny(cues.win) { score += 2.5 }
            if hasAny(cues.energyCharged) || hasAny(cues.energyAlert)
                || hasAny(cues.energyTired) || hasAny(cues.energySluggish) { score += 1.5 }
            if hasAny(cues.focusLockedIn) || hasAny(cues.focusSharp) || hasAny(cues.focusPresent)
                || hasAny(cues.focusDistracted) || hasAny(cues.focusFoggy) { score += 1.5 }
            if hasAny(cues.moodSurfaces) || hasAny(cues.emotions) { score += 1.5 }
            if hasAny(cues.sideEffect) || hasAny(cues.physicalSideEffects) { score += 2.0 }
            if hasAny(cues.rebound) { score += 2.5 }
            if hasAny(cues.appetiteLoss) || hasAny(cues.appetiteReturn) { score += 1.5 }
            if hasAny(cues.executiveDysfunction) { score += 2.0 }

            let len = sentence.count
            if len >= 40 && len <= 200 { score += 1.0 } else if len < 20 { score -= 1.0 }

            scored.append((sentence, score))
        }

        let threshold = 1.5
        let qualified = scored.enumerated().filter { $0.element.score >= threshold }

        let topIndices: [Int]
        if qualified.isEmpty {
            topIndices = scored.enumerated()
                .max(by: { $0.element.score < $1.element.score })
                .map { [$0.offset] } ?? []
        } else {
            let topN = min(5, max(1, sentences.count / 4 + 1))
            let sorted = qualified.sorted { $0.element.score > $1.element.score }
            topIndices = sorted.prefix(topN).map { $0.offset }.sorted()
        }

        var selected = topIndices

        // Dedup: drop a selected sentence whose token-set Jaccard overlap with an
        // earlier-selected (higher-scored first) sentence exceeds 0.6.
        let bySentenceTokens: [Int: Set<String>] = Dictionary(uniqueKeysWithValues:
            selected.map { ($0, Set(CueMatcher.tokenize(sentences[$0]))) })
        let scoreOrdered = selected.sorted { scored[$0].score > scored[$1].score }
        var kept: [Int] = []
        for idx in scoreOrdered {
            let tokens = bySentenceTokens[idx] ?? []
            let isDup = kept.contains { other in
                let otherTokens = bySentenceTokens[other] ?? []
                let union = tokens.union(otherTokens).count
                guard union > 0 else { return false }
                return Double(tokens.intersection(otherTokens).count) / Double(union) > 0.6
            }
            if !isDup { kept.append(idx) }
        }
        selected = kept.sorted()

        // Coverage: if any med sentence exists but none survived, swap it in for the
        // lowest-scored survivor (meds are the app's core signal).
        let medIndices = sentences.indices.filter {
            CueMatcher.anyMatch(in: CueMatcher.tokenizeWithLemmas(sentences[$0]), list: cues.medications)
        }
        if let bestMed = medIndices.max(by: { scored[$0].score < scored[$1].score }),
           !selected.contains(where: { medIndices.contains($0) }) {
            if selected.count >= 5, let worst = selected.min(by: { scored[$0].score < scored[$1].score }) {
                selected.removeAll { $0 == worst }
            }
            selected.append(bestMed)
            selected.sort()
        }

        return selected.map { sentences[$0] }
    }

    // MARK: - Title

    private static let titleFillers: Set<String> = [
        "so", "yeah", "um", "uh", "like", "okay", "ok", "well", "anyway", "right", "honestly", "basically"
    ]

    private func makeTitle(from highlights: [String], fallback: String) -> String {
        let source = highlights.first ?? fallback
        // Cut at the first clause boundary, then strip leading spoken fillers.
        let clause = source
            .components(separatedBy: CharacterSet(charactersIn: ",;"))[0]
            .components(separatedBy: " and then ")[0]
            .components(separatedBy: " but ")[0]
        var words = clause.split(separator: " ").map(String.init)
        while let first = words.first,
              Self.titleFillers.contains(first.lowercased().trimmingCharacters(in: .punctuationCharacters)) {
            words.removeFirst()
        }
        let title = words.prefix(8).joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        guard !title.isEmpty else { return String(fallback.split(separator: " ").prefix(6).joined(separator: " ")) }
        return title.prefix(1).uppercased() + title.dropFirst()
    }
}

// MARK: - Regex Utility

/// All patterns are compiled ONCE as `static let` regexes (NSRegularExpression is
/// immutable + thread-safe), shared across every nonisolated extraction instead of
/// recompiling per call (P1.3 perf).
nonisolated struct ADHDRegexPatterns {

    private static func compile(_ pattern: String) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern, options: [])
    }

    // MARK: - Dose

    private static let doseRegex = compile(#"(?i)\b(\d{1,3})\s?(mg|mcg|milligram)\s?(XL|XR|IR|SR|ER|ODT|LA|PM|modified release|extended release|immediate release)?\s?(once|twice|three times|daily|every morning|with breakfast|q\.?d|b\.?i\.?d|t\.?i\.?d)?\b"#)

    /// "18mg", "30 mg", "20mg XL", "10 mg IR"
    static func extractDose(from text: String) -> String? {
        guard let regex = doseRegex else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        if let match = regex.firstMatch(in: text, options: [], range: range),
           let doseRange = Range(match.range(at: 0), in: text) {
            let raw = String(text[doseRange])
            return raw.replacingOccurrences(of: "milligrams", with: "mg", options: .caseInsensitive)
                      .replacingOccurrences(of: "milligram", with: "mg", options: .caseInsensitive)
        }
        return nil
    }

    // MARK: - Sleep Hours

    private static let sleepHoursRegex = compile(#"(?i)(?:slept|got|in bed for|was asleep for|only|about|roughly|maybe)\s?(\d{1,2}(?:\.\d)?)\s?(hours?|hrs?|h)"#)

    /// "slept 7 hours", "got about 6 hrs"
    static func extractSleepHours(from text: String) -> Double? {
        guard let regex = sleepHoursRegex else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        if let match = regex.firstMatch(in: text, options: [], range: range),
           let hoursRange = Range(match.range(at: 1), in: text) {
            return Double(text[hoursRange])
        }
        return nil
    }

    // MARK: - Onset

    private static let onsetRegex = compile(#"(?i)(?:kicks? in|kicked in|kicks?|kicked|onset)\s*(?:in|after|about|around)*\s*(\d{1,3})\s?(minutes?|mins?|m|hours?|hrs?)\b"#)

    /// "kicks in after 45 minutes", "kicked in after 45 min", "onset 30 minutes".
    /// Requires a kick-in / onset phrase. Bare "took" is intentionally excluded —
    /// it collides with sleep latency ("took 2 hours to fall asleep").
    static func extractOnsetMinutes(from text: String) -> Int? {
        guard let regex = onsetRegex else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        if let match = regex.firstMatch(in: text, options: [], range: range),
           let numRange = Range(match.range(at: 1), in: text),
           let unitRange = Range(match.range(at: 2), in: text),
           let num = Int(text[numRange]) {
            let unit = text[unitRange].lowercased()
            if unit.contains("hour") || unit == "h" || unit == "hr" || unit == "hrs" {
                return num * 60
            }
            return num
        }
        return nil
    }

    // MARK: - Duration

    private static let durationRegex = compile(#"(?i)(?:lasted|duration|worked for|good for|wore off after|wearing off after|coverage)\s?(\d{1,2}(?:\.\d)?)\s?(hours?|hrs?|h)"#)

    /// "lasted 8 hours", "wore off after 6 hours"
    static func extractDurationHours(from text: String) -> Double? {
        guard let regex = durationRegex else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        if let match = regex.firstMatch(in: text, options: [], range: range),
           let hoursRange = Range(match.range(at: 1), in: text) {
            return Double(text[hoursRange])
        }
        return nil
    }

    // MARK: - Crash Time

    private static let crashTimeRegex = compile(#"(?i)(?:crash|rebound|wore off|dropped off|hit a wall|symptoms came back)\s?(?:at|around|about)?\s?(\d{1,2}(?::\d{2})?\s?(?:am|pm|a\.?m\.?|p\.?m\.?)?)"#)

    /// "crash at 3pm", "rebound around 4"
    static func extractCrashTime(from text: String) -> String? {
        guard let regex = crashTimeRegex else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        if let match = regex.firstMatch(in: text, options: [], range: range),
           let timeRange = Range(match.range(at: 0), in: text) {
            return String(text[timeRange])
        }
        return nil
    }

    // MARK: - Intake Context

    private static let intakeContextRegex = compile(#"(?i)(?:took|had|with|on)\s?(empty stomach|full stomach|with food|with breakfast|with lunch|with dinner|after eating|before eating|orange juice|coffee|vitamin C|OJ|protein)"#)

    /// "empty stomach", "with breakfast", "orange juice"
    static func extractIntakeContext(from text: String) -> String? {
        guard let regex = intakeContextRegex else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        if let match = regex.firstMatch(in: text, options: [], range: range),
           let ctxRange = Range(match.range(at: 1), in: text) {
            return String(text[ctxRange])
        }
        return nil
    }
}
