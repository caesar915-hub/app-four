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
    static func validate(_ extraction: UnifiedExtraction, lexicon: Lexicon) -> UnifiedExtraction {
        var valid = extraction
        
        let validMoods = Set(MoodLevel.allCases.map(\.rawValue))
        if let mood = valid.mood, !validMoods.contains(mood) {
            valid.mood = nil
        }
        
        let validEnergies = Set(EnergyLevel.allCases.map(\.rawValue))
        if let energy = valid.energy, !validEnergies.contains(energy) {
            valid.energy = nil
        }
        
        let validFocus = Set(FocusLevel.allCases.map(\.rawValue))
        if let focus = valid.focus, !validFocus.contains(focus) {
            valid.focus = nil
        }
        
        let validSleep = Set(SleepLevel.allCases.map(\.rawValue))
        if let quality = valid.sleepQuality, !validSleep.contains(quality) {
            valid.sleepQuality = nil
        }
        
        if let hours = valid.sleepHours {
            if hours < 0 || hours > 24 {
                valid.sleepHours = nil
            }
        }
        
        let validEmotions = Set(lexicon.emotions)
        valid.emotions = valid.emotions.filter { validEmotions.contains($0) }
        
        let categoryNames = Set(lexicon.activityKeywords.map { $0.category })
        valid.activities = valid.activities.filter { categoryNames.contains($0) }
        
        let validSideEffects = Set(lexicon.sideEffectCues + lexicon.physicalSideEffects)
        valid.sideEffects = valid.sideEffects.filter { validSideEffects.contains($0) }
        
        valid.topics = Array(valid.topics.prefix(4))
        valid.lexicon = Array(valid.lexicon.prefix(5))
        
        if let sum = valid.summary?.trimmingCharacters(in: .whitespacesAndNewlines), sum.isEmpty {
            valid.summary = nil
        }
        
        if valid.sleepQuality == nil, let hours = valid.sleepHours {
            valid.sleepQuality = deriveSleepLevel(hours: hours)
        }
        
        valid.topics = deriveTopics(valid.topics, extraction: valid, lexicon: lexicon)
        
        return valid
    }
    
    // MARK: - Sleep Level Derivation
    static func deriveSleepLevel(hours: Double?) -> String? {
        guard let hours = hours else { return nil }
        if hours < 5 { return SleepLevel.restless.rawValue }
        if hours < 6 { return SleepLevel.light.rawValue }
        if hours < 7 { return SleepLevel.okay.rawValue }
        if hours < 9 { return SleepLevel.good.rawValue }
        return SleepLevel.deep.rawValue
    }
    
    // MARK: - Topic Derivation
    static func deriveTopics(_ topics: [String], extraction: UnifiedExtraction, lexicon: Lexicon) -> [String] {
        var newTopics = topics
        
        if !extraction.medications.isEmpty {
            newTopics.append("Medications")
        }
        
        if !extraction.sideEffects.isEmpty {
            newTopics.append("Symptoms")
        }
        
        let summaryText = extraction.summary?.lowercased() ?? ""
        let hasAppointments = lexicon.appointmentCues.contains { cue in
            let lowerCue = cue.lowercased()
            return summaryText.contains(lowerCue) ||
                   extraction.topics.contains(where: { $0.lowercased() == lowerCue }) ||
                   extraction.lexicon.contains(where: { $0.lowercased() == lowerCue }) ||
                   extraction.activities.contains(where: { $0.lowercased() == lowerCue })
        }
        
        if hasAppointments {
            newTopics.append("Appointments")
        }
        
        var unique: [String] = []
        for topic in newTopics {
            if !unique.contains(topic) {
                unique.append(topic)
            }
        }
        
        return Array(unique.prefix(4))
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
