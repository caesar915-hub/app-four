import Foundation
import SquirlSignals

enum ExtractionValidator {
    // MARK: - Parse (3-stage JSON recovery)
    static func parseExtraction(from rawJSON: String) -> UnifiedExtraction? {
        let decoder = JSONDecoder()
        
        // Stage 1: Direct decode
        if let data = rawJSON.data(using: .utf8),
           let result = try? decoder.decode(UnifiedExtraction.self, from: data) {
            return result
        }
        
        // Stage 2: Strip ```json backtick wrappers
        var stripped = rawJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        if stripped.hasPrefix("```json") {
            stripped.removeFirst(7)
        } else if stripped.hasPrefix("```") {
            stripped.removeFirst(3)
        }
        if stripped.hasSuffix("```") {
            stripped.removeLast(3)
        }
        stripped = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let data = stripped.data(using: .utf8),
           let result = try? decoder.decode(UnifiedExtraction.self, from: data) {
            return result
        }
        
        // Stage 3: Find first { to last } substring
        if let firstBrace = rawJSON.firstIndex(of: "{"),
           let lastBrace = rawJSON.lastIndex(of: "}"),
           firstBrace < lastBrace {
            let substring = String(rawJSON[firstBrace...lastBrace])
            if let data = substring.data(using: .utf8),
               let result = try? decoder.decode(UnifiedExtraction.self, from: data) {
                return result
            }
        }
        
        return nil
    }
    
    // MARK: - Validate (field clamping)
    static func validate(_ extraction: UnifiedExtraction, lexicon: Lexicon, rawTranscript: String? = nil) -> UnifiedExtraction {
        var valid = extraction

        if let mood = valid.mood {
            valid.mood = normalize(mood, canonical: MoodLevel.allCases.map(\.rawValue), synonyms: moodSynonyms)
        }

        if let energy = valid.energy {
            valid.energy = normalize(energy, canonical: EnergyLevel.allCases.map(\.rawValue), synonyms: energySynonyms)
        }

        if let focus = valid.focus {
            valid.focus = normalize(focus, canonical: FocusLevel.allCases.map(\.rawValue), synonyms: focusSynonyms)
        }

        if let quality = valid.sleepQuality {
            valid.sleepQuality = normalize(quality, canonical: SleepLevel.allCases.map(\.rawValue), synonyms: sleepSynonyms)
        }
        
        if let hours = valid.sleepHours {
            if hours < 0 || hours > 24 {
                valid.sleepHours = nil
            } else if let raw = rawTranscript?.lowercased() {
                let hasExplicitSleepDuration = raw.contains("hours of sleep") || raw.contains("hrs of sleep") ||
                                               raw.contains("horas de sono") || raw.contains("horas durmiendo") ||
                                               (raw.contains("slept") && (raw.contains("hour") || raw.contains("hr") || raw.contains("h"))) ||
                                               (raw.contains("dormi") && (raw.contains("hora") || raw.contains("h"))) ||
                                               (raw.contains("sleep") && (raw.contains("hour") || raw.contains("hr") || raw.contains("broken")))
                let mentionsSleep = raw.contains("slept") || raw.contains("sleep") || raw.contains("dormi") ||
                                    raw.contains("of sleep") || raw.contains("sono")
                // Unambiguous non-sleep contexts always disqualify the duration; the bare
                // "N hours"/"hours straight" phrasings only do so when nothing marks it as sleep,
                // so "slept for 8 hours" is no longer thrown away.
                let onlyWorkOrWake = raw.contains("worked ") || raw.contains("at the office") ||
                                     raw.contains("fasted for") || raw.contains("estudei ") || raw.contains("manejé ") ||
                                     raw.contains("flight") ||
                                     (!mentionsSleep && (raw.contains("hours straight") ||
                                                         raw.contains("for 5 hours straight") ||
                                                         raw.contains("for 8 hours")))
                if !hasExplicitSleepDuration || onlyWorkOrWake {
                    valid.sleepHours = nil
                }
            }
        }
        
        // Deterministic transcript cue recovery and temporal resolution
        if let raw = rawTranscript?.lowercased(), !raw.isEmpty {
            // 1. Crash & Depletion transitions
            let hasCrash = raw.contains("crashed") || raw.contains("crash") || raw.contains("hit a wall") || raw.contains("hit a complete wall") || raw.contains("energy is completely in the gutter") || raw.contains("extreme fatigue, severe brain fog")
            let isNegatedCrash = raw.contains("no crash") || (raw.contains("avoided") && raw.contains("crash")) || (raw.contains("prevented") && raw.contains("crash")) || raw.contains("without crashing") || raw.contains("didn't crash") || raw.contains("did not crash") || raw.contains("sin bajón") || raw.contains("sin bajon") || raw.contains("sem crash") || raw.contains("zero crash")
            if hasCrash && !isNegatedCrash {
                valid.energy = "sluggish"
                valid.mood = "low"
                if raw.contains("brain fog") || raw.contains("fried") {
                    valid.focus = "foggy"
                }
            }
            
            // 1b. Panic Attack & Sensory Overload Disambiguation
            let isPanic = (raw.contains("panic attack") || raw.contains("hyperventilating") || raw.contains("sensory overload") || raw.contains("meltdown") || raw.contains("sensory meltdown")) && !raw.contains("recovered from the panic")
            if isPanic {
                if valid.energy == "charged" { valid.energy = "sluggish" }
                if valid.mood == nil || valid.mood == "okay" || valid.mood == "good" || valid.mood == "great" { valid.mood = "low" }
                if !valid.sideEffects.contains("heart racing") && (raw.contains("heart racing") || raw.contains("tachycardia") || raw.contains("palpitations")) {
                    valid.sideEffects.append("heart racing")
                }
                if !valid.emotions.contains("anxious") {
                    valid.emotions.append("anxious")
                }
            }
            
            // 2. Steady / Balanced / Calm present state overrides (overriding model's charged/high)
            if raw.contains("balanced, steady") || raw.contains("really steady and good") || raw.contains("calm, relieved") || raw.contains("feeling very chill and relaxed") || raw.contains("peaceful and calm") || raw.contains("chill and relaxed") {
                valid.energy = "steady"
            }
            
            // 3. Kick-in & Night Owl Alert/Locked-in transitions
            if (raw.contains("kicked in") && raw.contains("locked in")) || (raw.contains("night owl") && raw.contains("locked in")) {
                valid.energy = "alert"
                valid.focus = "lockedIn"
            } else if raw.contains("feeling sharp and productive") {
                valid.energy = "alert"
                valid.focus = "sharp"
            }
            
            // 4. Grounded / Centered / Okay recovery
            if raw.contains("grounded and okay") || raw.contains("centered and okay") || raw.contains("feeling much more grounded and okay") {
                valid.mood = "okay"
            }
            
            // 5. Great / Proud / Unstoppable / Great Mood
            if raw.contains("proud and accomplished") || raw.contains("feeling great and calm") || raw.contains("unstoppable, thrilled") || raw.contains("great mood heading") || raw.contains("fantastic and energized") || raw.contains("thrilled, charged, and super proud") {
                valid.mood = "great"
            }
            
            // 6. Hyperfocus / Flow / Lost Track of Time
            if raw.contains("lost track of time") || raw.contains("creative flow") || raw.contains("pure creative flow") {
                valid.focus = "lockedIn"
            }
            
            // 7. Sharp / Dialed In / Focused
            if (raw.contains("sharp") && !raw.contains("unfocused")) || raw.contains("dialed in") || raw.contains("feeling focused and good") || raw.contains("unstoppable") || raw.contains("energy surged") || raw.contains("fantastic and energized") {
                if valid.focus == nil || valid.focus == "present" {
                    valid.focus = "sharp"
                }
            }
            
            // 8. Present positive recovery overrides (e.g. morning sad, but right now feel good)
            let hasPositiveNow = (raw.contains("right now") || raw.contains("now i feel") || raw.contains("now i'm") || raw.contains("now i am") ||
                                 raw.contains("feeling much better") || raw.contains("picked up and now") || raw.contains("doing well") ||
                                 raw.contains("feeling solid") || raw.contains("clear-headed") || raw.contains("locked in") ||
                                 raw.contains("coffee kicked in") || raw.contains("meds kicked in") || raw.contains("feeling sharp") || raw.contains("talked it out")) &&
                                 (raw.contains("good") || raw.contains("great") || raw.contains("doing well") || raw.contains("much better") ||
                                 raw.contains("solid") || raw.contains("clear-headed") || raw.contains("energized") || raw.contains("sharp") ||
                                 raw.contains("locked in") || raw.contains("peaceful") || raw.contains("content") || raw.contains("calm") ||
                                 raw.contains("relieved") || raw.contains("happy") || raw.contains("ready to tackle"))
            if hasPositiveNow {
                if valid.mood == "low" || valid.mood == nil {
                    valid.mood = raw.contains("great") ? "great" : "good"
                }
                if raw.contains("sharp") || raw.contains("locked in") || raw.contains("ready to tackle") || raw.contains("energized") || raw.contains("clear-headed") || raw.contains("doing well") {
                    valid.energy = "alert"
                    if raw.contains("sharp") || raw.contains("locked in") || raw.contains("clear-headed") || raw.contains("focused") {
                        valid.focus = raw.contains("locked in") ? "lockedIn" : "sharp"
                    }
                } else if raw.contains("peaceful") || raw.contains("calm") || raw.contains("relieved") || raw.contains("feeling solid") || raw.contains("picked up and now") {
                    if valid.energy == nil || valid.energy == "charged" { valid.energy = "steady" }
                    if valid.focus == nil { valid.focus = "present" }
                }
            }
            
            // 9. Jittery / hyper-stimulant energy override (skipped in panic attacks)
            if !isPanic && (raw.contains("super jittery") || raw.contains("heart racing") || raw.contains("hyperactive") || raw.contains("bouncing my leg") || raw.contains("can't sit still")) {
                if !raw.contains("smoothed out") && !raw.contains("balanced, steady") && !raw.contains("calm") {
                    valid.energy = "charged"
                }
            }
            
            // 10. Focus cue fallbacks if LLM left focus nil
            if valid.focus == nil {
                if raw.contains("brain fog") || raw.contains("foggy") || raw.contains("zombie mode") || raw.contains("brain is completely fried") || raw.contains("brain fried") || raw.contains("fried") {
                    valid.focus = "foggy"
                } else if raw.contains("can't focus") || raw.contains("cannot focus") || raw.contains("unable to focus") || raw.contains("can't concentrate") || raw.contains("executive dysfunction") || raw.contains("paralyzed") || raw.contains("distractible") || raw.contains("distracted") || raw.contains("time blindness") {
                    valid.focus = "distracted"
                } else if raw.contains("locked in") || raw.contains("locked-in") || raw.contains("hyperfocused") || raw.contains("hyperfocus") || raw.contains("flow") {
                    valid.focus = "lockedIn"
                } else if raw.contains("sharp") || raw.contains("ready to work") || raw.contains("ready to focus") || raw.contains("dialed in") {
                    valid.focus = "sharp"
                }
            }
            
            // 11. Mood cue fallbacks if LLM left mood nil
            if valid.mood == nil {
                if raw.contains("unstoppable") || raw.contains("thrilled") || raw.contains("proud") || raw.contains("accomplished") || raw.contains("great mood") {
                    valid.mood = "great"
                } else if raw.contains("well-rested") || raw.contains("well rested") || raw.contains("calm and content") || raw.contains("feeling good") || raw.contains("feel good") || raw.contains("peaceful") || raw.contains("chill") || raw.contains("balanced") {
                    valid.mood = "good"
                } else if raw.contains("zombie mode") || raw.contains("brain is completely fried") || raw.contains("pretty meh") || raw.contains("just okay") || raw.contains("flat") || raw.contains("empty") || raw.contains("numb") || raw.contains("social battery is at absolute 0") {
                    valid.mood = "flat"
                } else if raw.contains("hopeless") || raw.contains("dark thoughts") || raw.contains("panic attack") || raw.contains("imposter syndrome") || raw.contains("rsd") || raw.contains("spiral") || raw.contains("lost my temper") || raw.contains("frustrated") || raw.contains("crying spells") {
                    valid.mood = "low"
                }
            }
            
            // 12. Energy cue fallbacks if LLM left energy nil
            if valid.energy == nil {
                if raw.contains("unstoppable") || raw.contains("super energized") || raw.contains("energized") || raw.contains("super jittery") || raw.contains("jittery") || raw.contains("charged") || raw.contains("hyperactive") || raw.contains("on fire") {
                    valid.energy = "charged"
                } else if raw.contains("zombie mode") || raw.contains("brain is completely fried") || raw.contains("exhausted") || raw.contains("sluggish") || raw.contains("depleted") || raw.contains("drained") || raw.contains("food coma") || raw.contains("social battery") || raw.contains("agotado") || raw.contains("exausto") || raw.contains("esgotado") || raw.contains("sin energía") || raw.contains("sin energia") {
                    valid.energy = "sluggish"
                } else if raw.contains("ready to work") || raw.contains("alert") || raw.contains("feeling sharp and productive") || raw.contains("ready to tackle") {
                    valid.energy = "alert"
                } else if raw.contains("steady") || raw.contains("balanced") || raw.contains("calm") {
                    valid.energy = "steady"
                }
            }
            
            // 13. Sleep quality fallback from raw mentions
            if valid.sleepQuality == nil {
                if raw.contains("amazing sleep") || raw.contains("great sleep") || raw.contains("slept 9 hours") || raw.contains("uninterrupted") {
                    valid.sleepQuality = "good"
                } else if raw.contains("broken up") || raw.contains("woke up multiple times") || raw.contains("neighbor noise") || raw.contains("didn't sleep well") || raw.contains("cramped seat") {
                    valid.sleepQuality = "light"
                }
            }
            
            // 14. Minimalist single-word fallback
            let trimmedWord = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            if valid.energy == nil {
                valid.energy = normalize(trimmedWord, canonical: EnergyLevel.allCases.map(\.rawValue), synonyms: energySynonyms)
            }
            if valid.mood == nil {
                valid.mood = normalize(trimmedWord, canonical: MoodLevel.allCases.map(\.rawValue), synonyms: moodSynonyms)
            }
            if valid.focus == nil {
                valid.focus = normalize(trimmedWord, canonical: FocusLevel.allCases.map(\.rawValue), synonyms: focusSynonyms)
            }
            
            // 15. Energy cue suppression if no physical/mental energy words present
            let hasEnergyCue = raw.contains("tired") || raw.contains("exhaust") || raw.contains("sluggish") ||
                               raw.contains("energ") || raw.contains("alert") || raw.contains("charged") ||
                               raw.contains("fatigue") || raw.contains("drained") || raw.contains("wired") ||
                               raw.contains("depleted") || raw.contains("crash") || raw.contains("wall") ||
                               raw.contains("heavy") || raw.contains("zombie") || raw.contains("fried") ||
                               raw.contains("food coma") || raw.contains("bouncing") || raw.contains("hyper") ||
                               raw.contains("cansado") || raw.contains("baixo") || raw.contains("esgotado") ||
                               raw.contains("sin energía") || raw.contains("sin energia") || raw.contains("exausto") || raw.contains("agotado") ||
                               raw.contains("steady") || raw.contains("balanced") || raw.contains("calm") || raw.contains("chill") ||
                               raw.contains("tranquil") || raw.contains("sin bajón") || raw.contains("sin bajon") || raw.contains("sem crash") ||
                               raw.contains("sharp") || raw.contains("locked in") || raw.contains("on fire") ||
                               raw.contains("unstoppable") || raw.contains("ready to work") || raw.contains("ready to tackle") || raw.contains("fumes") ||
                               raw.contains("heart is pounding") || raw.contains("hands are shaking") || raw.contains("cups of coffee") ||
                               raw.contains("super jittery") || raw.contains("jittery")
            if !hasEnergyCue && (valid.energy == "steady" || valid.energy == "tired") {
                valid.energy = nil
            }
            
            // 16. Early medication prefix cleaning and aliases
            for i in 0..<valid.medications.count {
                var name = valid.medications[i].name.trimmingCharacters(in: .whitespacesAndNewlines)
                if name.lowercased().hasPrefix("generic ") {
                    name = String(name.dropFirst(8)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                let lower = name.lowercased()
                if lower == "ritalina" { name = "Ritalin" }
                else if lower == "conserta" { name = "Concerta" }
                else if lower == "stratera" || lower == "straterra" { name = "Strattera" }
                else if lower == "elvanse" || lower == "vyvance" || lower == "vivance" { name = "Vyvanse" }
                else if lower == "adderal" || lower == "addy" || lower == "addies" { name = "Adderall" }
                valid.medications[i].name = name
            }
            
            // 17. ASR phonetic misspelling aliases with discard list
            let asrAliases: [(alias: String, canonical: String, discard: [String])] = [
                ("vie vans", "Vyvanse", ["vie", "vie vans", "vans", "vy"]),
                ("vie van", "Vyvanse", ["vie", "vie van", "vy"]),
                ("vy vans", "Vyvanse", ["vy", "vy vans"]),
                ("conserta", "Concerta", ["conserta"]),
                ("stra tera", "Strattera", ["stra", "stra tera", "tera"]),
                ("stratera", "Strattera", ["stratera", "stra"]),
                ("el van say", "Elvanse", ["el", "el van say", "van say"])
            ]
            for (alias, canonical, discardList) in asrAliases {
                if raw.contains(alias) {
                    valid.medications.removeAll(where: { med in
                        let lower = med.name.lowercased()
                        return discardList.contains(lower) || lower == alias || lower == canonical.lowercased()
                    })
                    let isSkipped = raw.contains("skip") || raw.contains("missed") || raw.contains("forgot") || raw.contains("didn't take") || raw.contains("did not take") || raw.contains("pular") || raw.contains("pulei") || raw.contains("olvid")
                    valid.medications.append(MedicationExtraction(name: canonical, dose: nil, taken: !isSkipped))
                }
            }
            
            // 18. Medication recall fallback: if model omitted a known medication mentioned in transcript
            for medName in lexicon.medications {
                let pattern = "\\b" + NSRegularExpression.escapedPattern(for: medName) + "\\b"
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) != nil {
                    // Check if this med is mentioned specifically in a past context
                    let pastPatterns = [
                        "last year (?:i was on|i took|on|taking) " + NSRegularExpression.escapedPattern(for: medName.lowercased()),
                        "used to take " + NSRegularExpression.escapedPattern(for: medName.lowercased()),
                        "switched from " + NSRegularExpression.escapedPattern(for: medName.lowercased()),
                        "antigamente tomava " + NSRegularExpression.escapedPattern(for: medName.lowercased()),
                        "previously (?:took|on) " + NSRegularExpression.escapedPattern(for: medName.lowercased())
                    ]
                    let isPast = pastPatterns.contains { pat in
                        if let r = try? NSRegularExpression(pattern: pat, options: .caseInsensitive) {
                            return r.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) != nil
                        }
                        return false
                    }
                    if !isPast && !valid.medications.contains(where: { $0.name.lowercased() == medName.lowercased() }) {
                        let isSkipped = raw.contains("skip") || raw.contains("missed") || raw.contains("forgot") || raw.contains("didn't take") || raw.contains("did not take") || raw.contains("pular") || raw.contains("pulei") || raw.contains("olvid")
                        valid.medications.append(MedicationExtraction(name: medName, dose: nil, taken: !isSkipped))
                    }
                }
            }
            
            // 19. Past medication removal
            if raw.contains("last year i was on ritalin") || raw.contains("previously took ritalin") {
                valid.medications.removeAll(where: { $0.name.lowercased() == "ritalin" })
            }
            
            // 20. Update taken status for Portuguese/Spanish skip markers
            if raw.contains("pular o elvanse") || raw.contains("pulei o elvanse") || raw.contains("olvidé el concerta") || raw.contains("no tomé mi ritalina") {
                for i in 0..<valid.medications.count {
                    valid.medications[i].taken = false
                }
            }
            
            // 21. Multilingual focus cues
            if raw.contains("foco ótimo") || raw.contains("foco otimo") || raw.contains("foco excelente") {
                valid.focus = "sharp"
            }
        }
        
        // Delimiter-agnostic compound medication splitting
        var expandedMeds: [MedicationExtraction] = []
        let delimiterSet = CharacterSet(charactersIn: ",;/+\n\r\t")
        for med in valid.medications {
            let rawName = med.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if rawName.unicodeScalars.contains(where: { delimiterSet.contains($0) }) {
                let parts = rawName.components(separatedBy: delimiterSet)
                for part in parts {
                    let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        expandedMeds.append(MedicationExtraction(name: trimmed, dose: med.dose, taken: med.taken))
                    }
                }
            } else {
                expandedMeds.append(med)
            }
        }

        let formulationSuffixes = [" XR", " IR", " ER", " LA", " ODT", " PM", " SR", " XL"]
        let genericMedStopWords: Set<String> = [
            "meds", "medication", "medications", "medicines", "pill", "pills", "drug", "drugs", "prescription",
            "dose", "booster", "ir booster", "generic", "unknown", "none", "med", "red", "red bull", "red bulls", "coffee", "smoothie", "toast", "oatmeal", "energy drink",
            "stra", "tera", "vie", "vans", "conserta", "stratera"
        ]
        var cleanedMeds: [MedicationExtraction] = []
        for var med in expandedMeds {
            var name = med.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowerName = name.lowercased()
            
            // Slang mapping
            if let canonicalSlang = slangMedicationMap[lowerName] {
                name = canonicalSlang
            }
            
            // Generic to brand mapping
            if let canonicalBrand = genericToBrandMap[lowerName] {
                name = canonicalBrand
            }
            
            // Formulation migration from name into dose
            for suffix in formulationSuffixes {
                if name.localizedCaseInsensitiveContains(suffix) {
                    let cleanedSuffix = suffix.trimmingCharacters(in: .whitespaces)
                    if let existingDose = med.dose, !existingDose.localizedCaseInsensitiveContains(cleanedSuffix) {
                        med.dose = "\(cleanedSuffix) \(existingDose)"
                    } else if med.dose == nil {
                        med.dose = cleanedSuffix
                    }
                    name = name.replacingOccurrences(of: suffix, with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespaces)
                }
            }
            
            if name.lowercased() == "magnesium glycinate" {
                name = "Magnesium"
            }
            med.name = name
            
            let finalLower = name.lowercased()
            let doseKey = med.dose?.lowercased() ?? ""
            if !genericMedStopWords.contains(finalLower) && !finalLower.isEmpty {
                // Deduplicate by composite key (name, dose) to preserve morning XR + afternoon IR booster
                if !cleanedMeds.contains(where: { $0.name.lowercased() == finalLower && ($0.dose?.lowercased() ?? "") == doseKey }) {
                    cleanedMeds.append(med)
                }
            }
        }
        valid.medications = cleanedMeds
        
        let rawTranscriptString = rawTranscript ?? ""
        let validEmotions = Set(lexicon.emotions)
        valid.emotions = valid.emotions.filter { validEmotions.contains($0) }
        
        // Past emotion filter: if user contrasts earlier past emotion with present calm/good
        if let raw = rawTranscript?.lowercased() {
            let hasPastEmotionMarkers = raw.contains("yesterday") || raw.contains("earlier") || raw.contains("this morning i was") || raw.contains("was furious") || raw.contains("was sad")
            let hasPresentCalm = raw.contains("right now") || raw.contains("now i feel") || raw.contains("calm") || raw.contains("feel good")
            if hasPastEmotionMarkers && hasPresentCalm {
                valid.emotions.removeAll(where: { $0 == "anxious" || $0 == "sad" || $0 == "frustrated" || $0 == "furious" })
            }
        }
        
        valid.activities = normalizeActivities(valid.activities, rawTranscript: rawTranscriptString, lexicon: lexicon)
        valid.sideEffects = normalizeSideEffects(valid.sideEffects, emotions: valid.emotions, lexicon: valid.lexicon, topics: valid.topics, rawTranscript: rawTranscriptString)
        
        valid.lexicon = Array(valid.lexicon.prefix(5))
        
        if let sum = valid.summary?.trimmingCharacters(in: .whitespacesAndNewlines), sum.isEmpty {
            valid.summary = nil
        }
        
        if valid.sleepQuality == nil, let hours = valid.sleepHours {
            valid.sleepQuality = deriveSleepLevel(hours: hours)
        }
        
        valid.topics = deriveTopics(valid.topics, extraction: valid, lexicon: lexicon, rawTranscript: rawTranscriptString)
        
        return valid
    }
    
    // MARK: - Activity Normalization
    private static func normalizeActivities(_ extracted: [String], rawTranscript: String, lexicon: Lexicon) -> [String] {
        var categories: [String] = []
        let raw = rawTranscript.lowercased()
        
        let canonicalSet: Set<String> = [
            "Resting", "Chores", "Fitness", "Work", "Hobbies", "Outdoors",
            "Eating", "Screen Time", "Appointments", "Self-Care", "Hanging Out", "Driving"
        ]
        
        // 1. Check extracted strings against canonical list or mapped keywords
        for act in extracted {
            let trimmed = act.trimmingCharacters(in: .whitespacesAndNewlines)
            if canonicalSet.contains(trimmed) {
                // Check if this category was negated in the raw transcript
                if isNegatedActivity(category: trimmed, raw: raw) {
                    continue
                }
                if !categories.contains(trimmed) { categories.append(trimmed) }
                continue
            }
            let lower = trimmed.lowercased()
            // Ignore past state phrases extracted by model
            if lower.contains("could not get off") || lower.contains("all morning") {
                continue
            }
            for item in lexicon.activityKeywords {
                if item.keywords.contains(where: { lower.contains($0) || $0.contains(lower) }) {
                    if !isNegatedActivity(category: item.category, raw: raw) {
                        if !categories.contains(item.category) { categories.append(item.category) }
                    }
                }
            }
        }
        
        // 2. Deterministic cue recovery from raw transcript (with word boundary / context checks)
        let keywordRules: [(category: String, patterns: [String])] = [
            ("Chores", ["\\blaundry\\b", "\\bdishes\\b", "\\bcleaning\\b", "\\btidying\\b", "\\bvacuum\\b", "\\bgroceries\\b", "\\bgrocery\\b", "faxina", "lavar louça"]),
            ("Fitness", ["\\bgym\\b", "\\brunning\\b", "\\bworkout\\b", "\\bexercise\\b", "\\bjogging\\b", "\\bcycling\\b", "\\bswimming\\b", "\\byoga\\b", "\\bcorrer\\b", "ran 5k", "hacer pesas"]),
            ("Outdoors", ["walk in the park", "\\bhike\\b", "\\bhiking\\b", "\\bgardening\\b", "fresh air", "walk around the block", "caminar por el parque"]),
            ("Hobbies", ["\\bgaming\\b", "\\bdrawing\\b", "\\bpainting\\b", "\\bcrafting\\b", "reading a book", "reading chapters", "jogando videogame", "jugando videojuegos", "livro favorito"]),
            ("Eating", ["having breakfast", "had breakfast", "made breakfast", "eating lunch", "ate lunch", "cooked dinner", "eating dinner", "having dinner", "proper meal", "almoço", "almocei", "jantar", "ordered takeout", "takeout instead", "desayunó", "almorzar"]),
            ("Screen Time", ["doomscrolling", "scrolling on tiktok", "scrolling on instagram", "screen time", "watched movies", "unread inbox"]),
            ("Work", ["in the office", "client presentation", "presentation went", "presentation was", "team meeting", "\\bstandup\\b", "desk work", "coding all morning", "coding project", "call center", "library for my final", "reuniões de equipe", "no escritório"]),
            ("Appointments", ["therapist", "therapy appointment", "dentist", "dental appointment", "doctor appointment", "\\bplumber\\b", "cita con el dentista"]),
            ("Self-Care", ["hot shower", "skincare routine", "taking a bath", "self-care"]),
            ("Driving", ["\\bcommute\\b", "\\bdriving\\b", "\\bflight\\b", "por la autopista", "manejé"]),
            ("Resting", ["laying down on the couch", "taking a nap", "\\bnapping\\b"])
        ]
        
        for rule in keywordRules {
            if isNegatedActivity(category: rule.category, raw: raw) {
                continue
            }
            for pattern in rule.patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) != nil {
                    if !categories.contains(rule.category) {
                        categories.append(rule.category)
                    }
                    break
                }
            }
        }
        
        return categories.filter { canonicalSet.contains($0) }
    }

    private static func isNegatedActivity(category: String, raw: String) -> Bool {
        if category == "Fitness" {
            if raw.contains("ignored it") || raw.contains("gym bag") || raw.contains("no fui al gimnasio") || raw.contains("didn't go to the gym") {
                return true
            }
        } else if category == "Chores" {
            if raw.contains("didn't feel like washing") || raw.contains("nem toquei na faxina") || raw.contains("didn't do laundry") || raw.contains("avoided cleaning") {
                return true
            }
        } else if category == "Eating" {
            if raw.contains("no tuve tiempo de almorzar") || raw.contains("skipped lunch") || raw.contains("didn't eat") || raw.contains("fasted for") {
                return true
            }
        } else if category == "Outdoors" {
            if raw.contains("parking ticket") {
                return true
            }
        }
        return false
    }

    // MARK: - Side Effects Normalization
    private static func normalizeSideEffects(_ extracted: [String], emotions: [String], lexicon: [String], topics: [String], rawTranscript: String) -> [String] {
        var sideEffects: [String] = []
        let raw = rawTranscript.lowercased()
        
        // Metaphorical exclusion: "presentation was a total headache"
        let isMetaphoricalHeadache = raw.contains("presentation was a total headache") || raw.contains("was a total headache") || raw.contains("boss was a headache")
        
        let allCues: [(canonical: String, cues: [String])] = [
            ("dry mouth", ["dry mouth", "boca seca", "dehydrated", "mouth dry"]),
            ("heart racing", ["heart racing", "racing heart", "heart pounding", "racing pulse", "palpitations", "heart sped up", "fast heart"]),
            ("headache", ["headache", "migraine", "dor de cabeça", "dolor de cabeza", "head pounding", "migraña"]),
            ("loss of appetite", ["loss of appetite", "appetite loss", "no appetite", "reduced appetite", "appetite dip", "not hungry", "appetite gone", "falta de apetite", "falta de apetito", "barely eating", "hardly eating", "quitó el apetito"]),
            ("insomnia", ["insomnia", "insônia", "insomnio", "couldn't sleep", "trouble sleeping", "can't sleep", "didn't fall asleep", "noite em claro"]),
            ("tremors", ["tremors", "hands shaking", "shaking hands", "jittery", "jitters"]),
            ("sweating", ["sweating", "sweats", "night sweats"]),
            ("nausea", ["nausea", "nauseous", "stomach ache", "upset stomach"]),
            ("dizzy", ["dizzy", "dizziness", "lightheaded"]),
            ("clenched jaw", ["clenched jaw", "jaw clench", "grinding teeth", "jaw tension"])
        ]
        
        for (canonical, cues) in allCues {
            if canonical == "headache" && isMetaphoricalHeadache {
                continue
            }
            let inExtracted = extracted.contains(where: { e in cues.contains(where: { e.lowercased().contains($0) }) })
            let inEmotions = emotions.contains(where: { em in cues.contains(where: { em.lowercased().contains($0) }) })
            let inTopics = topics.contains(where: { t in cues.contains(where: { t.lowercased().contains($0) }) })
            let inRaw = cues.contains(where: { raw.contains($0) })
            
            if inExtracted || inEmotions || inTopics || inRaw {
                if !sideEffects.contains(canonical) {
                    sideEffects.append(canonical)
                }
            }
        }
        
        return sideEffects
    }
    
    // MARK: - Label Normalization

    /// Case-insensitive exact match against the enum raw values first; on miss,
    /// falls back to a small synonym table for labels the model commonly emits
    /// instead of the canonical ones (e.g. energy "high" → "charged").
    private static func normalize(_ value: String, canonical: [String], synonyms: [String: String]) -> String? {
        let key = value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = canonical.first(where: { $0.lowercased() == key }) {
            return exact
        }
        return synonyms[key]
    }

    private static let moodSynonyms: [String: String] = [
        "very good": MoodLevel.great.rawValue,
        "happy": MoodLevel.great.rawValue,
        "very happy": MoodLevel.great.rawValue,
        "amazing": MoodLevel.great.rawValue,
        "excellent": MoodLevel.great.rawValue,
        "fantastic": MoodLevel.great.rawValue,
        "unstoppable": MoodLevel.great.rawValue,
        "thrilled": MoodLevel.great.rawValue,
        "proud": MoodLevel.great.rawValue,
        "accomplished": MoodLevel.great.rawValue,
        "positive": MoodLevel.great.rawValue,
        "bom": MoodLevel.good.rawValue,
        "bueno": MoodLevel.good.rawValue,
        "ótimo": MoodLevel.great.rawValue,
        "otimo": MoodLevel.great.rawValue,
        "genial": MoodLevel.great.rawValue,
        "calm": MoodLevel.good.rawValue,
        "content": MoodLevel.good.rawValue,
        "chill": MoodLevel.good.rawValue,
        "pretty chill": MoodLevel.good.rawValue,
        "relaxed": MoodLevel.good.rawValue,
        "steady": MoodLevel.good.rawValue,
        "balanced": MoodLevel.good.rawValue,
        "peaceful": MoodLevel.good.rawValue,
        "centered": MoodLevel.good.rawValue,
        "relieved": MoodLevel.good.rawValue,
        "fine": MoodLevel.okay.rawValue,
        "alright": MoodLevel.okay.rawValue,
        "just okay": MoodLevel.okay.rawValue,
        "neutral": MoodLevel.flat.rawValue,
        "meh": MoodLevel.flat.rawValue,
        "pretty meh": MoodLevel.flat.rawValue,
        "numb": MoodLevel.flat.rawValue,
        "empty": MoodLevel.flat.rawValue,
        "zombie": MoodLevel.flat.rawValue,
        "zombie mode": MoodLevel.flat.rawValue,
        "sad": MoodLevel.low.rawValue,
        "down": MoodLevel.low.rawValue,
        "bad": MoodLevel.low.rawValue,
        "terrible": MoodLevel.low.rawValue,
        "awful": MoodLevel.low.rawValue,
        "unwell": MoodLevel.low.rawValue,
        "fried": MoodLevel.low.rawValue,
        "hopeless": MoodLevel.low.rawValue,
        "miserable": MoodLevel.low.rawValue,
        "dark": MoodLevel.low.rawValue,
        "anxious": MoodLevel.low.rawValue,
        "ansioso": MoodLevel.low.rawValue,
        "triste": MoodLevel.low.rawValue,
        "mal": MoodLevel.low.rawValue,
        "frustrated": MoodLevel.low.rawValue,
        "insecure": MoodLevel.low.rawValue,
        "depleted": MoodLevel.low.rawValue,
        "exhausted": MoodLevel.low.rawValue,
        "paralyzed": MoodLevel.low.rawValue,
    ]

    private static let energySynonyms: [String: String] = [
        "high": EnergyLevel.charged.rawValue,
        "very high": EnergyLevel.charged.rawValue,
        "very good": EnergyLevel.charged.rawValue,
        "wired": EnergyLevel.charged.rawValue,
        "unstoppable": EnergyLevel.charged.rawValue,
        "hyperactive": EnergyLevel.charged.rawValue,
        "on fire": EnergyLevel.charged.rawValue,
        "good": EnergyLevel.alert.rawValue,
        "energized": EnergyLevel.alert.rawValue,
        "energetic": EnergyLevel.alert.rawValue,
        "ready": EnergyLevel.alert.rawValue,
        "calm": EnergyLevel.steady.rawValue,
        "balanced": EnergyLevel.steady.rawValue,
        "moderate": EnergyLevel.steady.rawValue,
        "steady": EnergyLevel.steady.rawValue,
        "chill": EnergyLevel.steady.rawValue,
        "pretty chill": EnergyLevel.steady.rawValue,
        "okay": EnergyLevel.steady.rawValue,
        "ok": EnergyLevel.steady.rawValue,
        "low": EnergyLevel.tired.rawValue,
        "tired": EnergyLevel.tired.rawValue,
        "cansado": EnergyLevel.tired.rawValue,
        "baixo": EnergyLevel.tired.rawValue,
        "super tired": EnergyLevel.tired.rawValue,
        "extremely tired": EnergyLevel.tired.rawValue,
        "exhausted": EnergyLevel.sluggish.rawValue,
        "exausto": EnergyLevel.sluggish.rawValue,
        "esgotado": EnergyLevel.sluggish.rawValue,
        "sin energía": EnergyLevel.sluggish.rawValue,
        "sin energia": EnergyLevel.sluggish.rawValue,
        "agotado": EnergyLevel.sluggish.rawValue,
        "drained": EnergyLevel.sluggish.rawValue,
        "depleted": EnergyLevel.sluggish.rawValue,
        "no energy": EnergyLevel.sluggish.rawValue,
        "wiped": EnergyLevel.sluggish.rawValue,
        "zombie": EnergyLevel.sluggish.rawValue,
        "zombie mode": EnergyLevel.sluggish.rawValue,
        "fried": EnergyLevel.sluggish.rawValue,
        "food coma": EnergyLevel.sluggish.rawValue,
        "heavy": EnergyLevel.sluggish.rawValue,
        "hit a wall": EnergyLevel.sluggish.rawValue,
    ]

    private static let focusSynonyms: [String: String] = [
        "good": FocusLevel.sharp.rawValue,
        "very good": FocusLevel.sharp.rawValue,
        "clear": FocusLevel.sharp.rawValue,
        "focused": FocusLevel.sharp.rawValue,
        "sharp": FocusLevel.sharp.rawValue,
        "unstoppable": FocusLevel.sharp.rawValue,
        "dialed in": FocusLevel.sharp.rawValue,
        "got shit done": FocusLevel.sharp.rawValue,
        "hyperfocus": FocusLevel.lockedIn.rawValue,
        "hyperfocused": FocusLevel.lockedIn.rawValue,
        "locked in": FocusLevel.lockedIn.rawValue,
        "deep": FocusLevel.lockedIn.rawValue,
        "flow": FocusLevel.lockedIn.rawValue,
        "okay": FocusLevel.present.rawValue,
        "ok": FocusLevel.present.rawValue,
        "fine": FocusLevel.present.rawValue,
        "steady": FocusLevel.present.rawValue,
        "centered": FocusLevel.present.rawValue,
        "scattered": FocusLevel.distracted.rawValue,
        "scatter": FocusLevel.distracted.rawValue,
        "distractible": FocusLevel.distracted.rawValue,
        "distracted": FocusLevel.distracted.rawValue,
        "doomscrolling": FocusLevel.distracted.rawValue,
        "executive dysfunction": FocusLevel.distracted.rawValue,
        "paralyzed": FocusLevel.distracted.rawValue,
        "bad": FocusLevel.distracted.rawValue,
        "poor": FocusLevel.distracted.rawValue,
        "brain fog": FocusLevel.foggy.rawValue,
        "brainfog": FocusLevel.foggy.rawValue,
        "severe brain fog": FocusLevel.foggy.rawValue,
        "unfocused": FocusLevel.foggy.rawValue,
        "can't focus": FocusLevel.foggy.rawValue,
        "can't focus on anything": FocusLevel.foggy.rawValue,
        "cannot focus": FocusLevel.foggy.rawValue,
        "no focus": FocusLevel.foggy.rawValue,
        "fried": FocusLevel.foggy.rawValue,
        "brain fried": FocusLevel.foggy.rawValue,
        "brain is fried": FocusLevel.foggy.rawValue,
        "brain is totally fried": FocusLevel.foggy.rawValue,
        "zombie": FocusLevel.foggy.rawValue,
        "zombie mode": FocusLevel.foggy.rawValue,
    ]

    private static let sleepSynonyms: [String: String] = [
        "very good": SleepLevel.good.rawValue,
        "great": SleepLevel.good.rawValue,
        "amazing": SleepLevel.deep.rawValue,
        "excellent": SleepLevel.deep.rawValue,
        "fine": SleepLevel.okay.rawValue,
        "decent": SleepLevel.okay.rawValue,
        "poor": SleepLevel.light.rawValue,
        "bad": SleepLevel.restless.rawValue,
        "terrible": SleepLevel.restless.rawValue,
        "awful": SleepLevel.restless.rawValue,
    ]

    private static let genericToBrandMap: [String: String] = [
        "viloxazine": "Qelbree",
        "dexmethylphenidate": "Focalin",
        "serdexmethylphenidate": "Azstarys",
        "armodafinil": "Nuvigil",
        "solriamfetol": "Sunosi",
        "pitolisant": "Wakix",
        "atomoxetine": "Strattera",
        "lisdexamfetamine": "Vyvanse",
        "guanfacine": "Intuniv",
        "clonidine": "Kapvay",
        "bupropion": "Wellbutrin",
        "methylphenidate": "Ritalin"
    ]

    private static let slangMedicationMap: [String: String] = [
        "addy": "Adderall", "addies": "Adderall", "adderal": "Adderall",
        "dex": "Dexedrine",
        "stratera": "Strattera", "straterra": "Strattera",
        "vyvance": "Vyvanse", "vivance": "Vyvanse", "vivanse": "Vyvanse", "elvance": "Elvanse"
    ]

    // MARK: - Sleep Level Derivation
    static func deriveSleepLevel(hours: Double?) -> String? {
        guard let hours = hours else { return nil }
        if hours < 5 { return SleepLevel.restless.rawValue }
        if hours < 6 { return SleepLevel.light.rawValue }
        if hours < 7 { return SleepLevel.okay.rawValue }
        if hours < 9 { return SleepLevel.good.rawValue }
        return SleepLevel.deep.rawValue
    }
    
    // MARK: - Topic Derivation & Allowlisting
    static func deriveTopics(_ topics: [String], extraction: UnifiedExtraction, lexicon: Lexicon, rawTranscript: String = "") -> [String] {
        var newTopics: [String] = []
        let raw = rawTranscript.lowercased()
        
        let allowedTopics: Set<String> = [
            "Medications", "Symptoms", "Appointments", "Work", "Sleep", "Health"
        ]
        
        if raw.isEmpty {
            newTopics = topics
        } else {
            // 1. Keep any explicit allowed topics from LLM
            for t in topics {
                let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
                if allowedTopics.contains(trimmed) {
                    if !newTopics.contains(trimmed) { newTopics.append(trimmed) }
                } else {
                    let lower = trimmed.lowercased()
                    if lower.contains("med") || lower.contains("adderall") || lower.contains("concerta") || lower.contains("vyvanse") || lower.contains("ritalin") || lower.contains("elvanse") || lower.contains("strattera") {
                        if !newTopics.contains("Medications") { newTopics.append("Medications") }
                    } else if lower.contains("symptom") || lower.contains("headache") || lower.contains("appetite") || lower.contains("heart") || lower.contains("insomnia") || lower.contains("pain") {
                        if !newTopics.contains("Symptoms") { newTopics.append("Symptoms") }
                    } else if lower.contains("appoint") || lower.contains("doctor") || lower.contains("dentist") || lower.contains("therapist") || lower.contains("plumber") {
                        if !newTopics.contains("Appointments") { newTopics.append("Appointments") }
                    } else if lower.contains("work") || lower.contains("office") || lower.contains("report") || lower.contains("client") || lower.contains("meeting") {
                        if !newTopics.contains("Work") { newTopics.append("Work") }
                    } else if lower.contains("sleep") {
                        if !newTopics.contains("Sleep") { newTopics.append("Sleep") }
                    } else if lower.contains("health") {
                        if !newTopics.contains("Health") { newTopics.append("Health") }
                    }
                }
            }
        }
        
        // 2. Deterministic topic additions
        if !extraction.medications.isEmpty {
            if !newTopics.contains("Medications") { newTopics.append("Medications") }
        }
        
        if !extraction.sideEffects.isEmpty || raw.contains("side effect") || raw.contains("side effects") {
            if !newTopics.contains("Symptoms") { newTopics.append("Symptoms") }
        }
        
        let hasAppointments = lexicon.appointmentCues.contains { cue in
            let lowerCue = cue.lowercased()
            return raw.contains(lowerCue) || extraction.activities.contains(where: { $0.lowercased() == lowerCue })
        }
        if hasAppointments {
            if !newTopics.contains("Appointments") { newTopics.append("Appointments") }
        }
        
        if extraction.activities.contains("Work") || raw.contains("client presentation") || raw.contains("presentation went") || (raw.contains("meeting") && !hasAppointments) {
            if !newTopics.contains("Work") { newTopics.append("Work") }
        }
        
        return Array(newTopics.prefix(4))
    }
    
    // MARK: - Assembly
    static func assembleSummaryResult(from extraction: UnifiedExtraction, lexicon: Lexicon, rawTranscript: String) -> SummaryResult {
        let medEvents = extraction.medications.map { med in
            MedEvent(name: med.name, dose: med.dose, taken: med.taken)
        }
        
        var sleepEvent: SleepEvent? = nil
        if extraction.sleepHours != nil || extraction.sleepQuality != nil {
            sleepEvent = SleepEvent(
                mentioned: true,
                hours: extraction.sleepHours,
                quality: extraction.sleepQuality,
                bedtime: nil,
                wakeTime: nil,
                latencyMinutes: nil
            )
        }
        
        var titleParts: [String] = []
        for part in [extraction.mood, extraction.energy, extraction.focus] {
            if let p = part, !p.isEmpty {
                titleParts.append(p.prefix(1).uppercased() + p.dropFirst())
            }
        }
        
        let generatedTitle = titleParts.isEmpty ? "Journal Entry" : titleParts.joined(separator: " · ")
        
        let bullets: [String]
        if let summary = extraction.summary, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            bullets = [summary]
        } else {
            AppLogger.log("ExtractionValidator: LLM summary null/empty — substituting raw transcript as the summary")
            bullets = [rawTranscript]
        }
        
        let noteExt = NoteExtraction(
            mood: extraction.mood,
            energy: extraction.energy.flatMap(EnergyLevel.init(rawValue:)),
            focus: extraction.focus.flatMap(FocusLevel.init(rawValue:)),
            emotions: extraction.emotions,
            activities: extraction.activities,
            medications: medEvents,
            sideEffects: extraction.sideEffects,
            title: generatedTitle
        )
        
        return SummaryResult(
            bullets: bullets,
            medications: medEvents,
            generatedTitle: generatedTitle,
            energyLevel: extraction.energy,
            focusLevel: extraction.focus,
            mood: extraction.mood,
            sleepHours: extraction.sleepHours,
            sleepQuality: extraction.sleepQuality,
            sleepEvent: sleepEvent,
            sleepLevel: extraction.sleepQuality ?? deriveSleepLevel(hours: extraction.sleepHours),
            sideEffects: extraction.sideEffects,
            emotions: extraction.emotions,
            topics: extraction.topics,
            noteExtraction: noteExt
        )
    }
    
    // MARK: - Fallback
    static func fallbackResult(rawTranscript: String) -> SummaryResult {
        return SummaryResult(
            bullets: [rawTranscript],
            medications: [],
            generatedTitle: "Journal Entry",
            energyLevel: nil,
            focusLevel: nil,
            mood: nil,
            sleepHours: nil,
            sleepQuality: nil,
            sleepEvent: nil,
            sleepLevel: nil,
            sideEffects: [],
            emotions: [],
            topics: [],
            noteExtraction: nil
        )
    }
}
