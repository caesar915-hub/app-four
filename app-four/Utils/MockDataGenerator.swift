import Foundation
import SwiftData

@MainActor
class MockDataGenerator {
    static func generate(context: ModelContext) {
        let calendar = Calendar.current
        let now = Date()
        
        // Med names for variety
        let medNames = ["Concerta", "Elvanse", "Ritalin", "Vyvanse"]
        let doses = ["18mg", "36mg", "54mg", "30mg", "50mg", "70mg"]
        
        // Generate for last 10 days
        for dayOffset in (0..<10).reversed() {
            guard let baseDate = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            
            // Randomly 2 to 4 recordings per day
            let count = Int.random(in: 2...4)
            
            for i in 0..<count {
                // Spread recordings throughout the day (8 AM to 10 PM)
                let hour = 8 + (14 / count) * i + Int.random(in: 0...1)
                let minute = Int.random(in: 0...59)
                guard let recordingDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: baseDate) else { continue }
                
                let mood = MoodLevel.allCases.randomElement()!
                let energy = EnergyLevel.allCases.randomElement()!
                let focus = FocusLevel.allCases.randomElement()!
                
                // Morning entry always has medication; others ~70% of the time.
                let hasMed = i == 0 || Int.random(in: 0...9) < 7
                let medName = hasMed ? medNames.randomElement()! : nil
                let medDose = hasMed ? doses.randomElement()! : nil
                
                let recording = Recording(
                    createdAt: recordingDate,
                    updatedAt: recordingDate,
                    audioFileName: "mock_\(dayOffset)_\(i)_\(UUID().uuidString).m4a",
                    duration: TimeInterval.random(in: 30...300),
                    status: .completed,
                    fullTranscriptText: "This is a mock transcript for day \(dayOffset + 1), entry \(i + 1). Discussing my \(mood.rawValue) mood and \(focus.displayLabel) focus today.",
                    title: "\(mood.rawValue.capitalized) · \(energy.rawValue.capitalized) · \(focus.displayLabel)",
                    isFavorite: Bool.random(),
                    hasMedication: hasMed,
                    energyLevel: energy.rawValue,
                    focusLevel: focus.rawValue,
                    mood: mood.rawValue
                )
                
                let bullets = [
                    "Discussed feeling \(mood.subtitle)",
                    "Energy level was \(energy.subtitle)",
                    "Focus was \(focus.subtitle)"
                ]
                if let data = try? JSONEncoder().encode(bullets), let json = String(data: data, encoding: .utf8) {
                    recording.summaryBulletsJSON = json
                    recording.summary = bullets.map { "- \($0)" }.joined(separator: "\n")
                }
                
                let categories = [TopicCategory.general.rawValue, hasMed ? TopicCategory.medications.rawValue : TopicCategory.symptoms.rawValue]
                if let data = try? JSONEncoder().encode(categories), let json = String(data: data, encoding: .utf8) {
                    recording.topicTagsJSON = json
                }
                
                recording.summaryStatus = SummaryStatus.completed.rawValue
                recording.summaryGeneratedAt = recordingDate
                recording.isMockData = true

                // Emotions (0–3) drawn from the curated Mood-Meter set, shown as chips.
                let emotionPool = ["excited", "joyful", "proud", "inspired", "content",
                                   "grateful", "serene", "anxious", "frustrated", "sad",
                                   "lonely", "discouraged"]
                let emotions = Array(emotionPool.shuffled().prefix(Int.random(in: 0...3)))
                if let data = try? JSONEncoder().encode(emotions), let json = String(data: data, encoding: .utf8) {
                    recording.emotionsJSON = json
                }

                // Side effects on roughly a third of entries.
                if Int.random(in: 0...2) == 0 {
                    let sideEffectPool = ["Headache", "Nausea", "Dry mouth", "Jitters", "Appetite loss"]
                    let effects = Array(sideEffectPool.shuffled().prefix(Int.random(in: 1...2)))
                    if let data = try? JSONEncoder().encode(effects), let json = String(data: data, encoding: .utf8) {
                        recording.sideEffectsJSON = json
                    }
                }

                // Sleep on the first (morning) entry of the day.
                if i == 0 {
                    recording.sleepHours = Double(Int.random(in: 5...9))
                }

                context.insert(recording)

                // Create a MedicationEvent linked to this recording when applicable
                if hasMed, let name = medName, let dose = medDose {
                    let event = MedicationEvent(
                        name: name,
                        dose: dose,
                        takenAt: recordingDate,
                        taken: true,
                        durationHours: 10.0,
                        timeLabel: "morning",
                        source: .transcript
                    )
                    event.isMockData = true
                    context.insert(event)
                    event.recording = recording
                }

                // Add some segments for realism
                let segment = TranscriptionSegment(
                    text: recording.fullTranscriptText,
                    startTime: 0,
                    endTime: recording.duration,
                    isFinal: true
                )
                segment.recording = recording
                context.insert(segment)
            }
        }
        
        try? context.save()

        seedNutritionEvents(context: context)
    }

    // MARK: - Nutrition events (spec 031)

    /// Deterministic 30-day food/exercise seed. Values are pure functions of `dayOffset`
    /// (no RNG) so re-seeding produces identical data — a stable demo. Caffeine runs low
    /// on the med-seeded days (offsets 0..<10, where `generate` always logs a morning
    /// dose) and high on the rest: the ADHD self-medication storyline. Two skip days
    /// (offsets 5 and 18) keep partial-data realism.
    static func seedNutritionEvents(context: ModelContext, calendar: Calendar = .current, now: Date = Date()) {
        let today = calendar.startOfDay(for: now)
        for dayOffset in 0..<30 {
            if dayOffset == 5 || dayOffset == 18 { continue }
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let d = dayOffset
            let medDay = d < 10
            let caffeineTotal = medDay
                ? Double(40 + (d * 7) % 55)          // 40–94 mg — medicated, easing off coffee
                : Double(180 + (d * 13) % 160)       // 180–339 mg — self-medicating

            func insertFood(_ name: String, hour: Int, minute: Int,
                            kcal: Double?, protein: Double?, caffeine: Double?) {
                guard let at = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) else { return }
                let event = NutritionEvent(startDate: at, kind: .food)
                event.name = name
                event.kcal = kcal
                event.proteinGrams = protein
                event.caffeineMg = caffeine
                event.isMockData = true
                context.insert(event)
            }

            let jitter = (d * 3) % 20
            // Med days: 3 meals, breakfast carries the (small) caffeine. Off days: a 4th
            // event — the big coffee — carries most of it.
            insertFood("Breakfast", hour: 7, minute: 30 + jitter,
                       kcal: Double(420 + (d * 31) % 180),
                       protein: Double(18 + d % 8),
                       caffeine: medDay ? caffeineTotal : (caffeineTotal * 0.4).rounded())
            if !medDay {
                insertFood("Coffee", hour: 10, minute: 15 + jitter,
                           kcal: 5, protein: nil,
                           caffeine: (caffeineTotal * 0.6).rounded())
            }
            insertFood("Lunch", hour: 13, minute: jitter,
                       kcal: Double(650 + (d * 37) % 230),
                       protein: Double(28 + (d * 3) % 14),
                       caffeine: nil)
            insertFood("Dinner", hour: 20, minute: jitter,
                       kcal: Double(700 + (d * 29) % 260),
                       protein: Double(24 + (d * 5) % 16),
                       caffeine: nil)

            if d % 2 == 0 {
                guard let at = calendar.date(bySettingHour: 18, minute: jitter, second: 0, of: day) else { continue }
                let minutes = Double(25 + (d * 7) % 20)
                let workout = NutritionEvent(startDate: at, kind: .exercise)
                workout.name = ["Run", "Walk", "Strength"][d % 3]
                workout.durationMinutes = minutes
                workout.endDate = at.addingTimeInterval(minutes * 60)
                workout.kcal = Double(180 + (d * 23) % 240)
                workout.isMockData = true
                context.insert(workout)
            }
        }
        try? context.save()
    }
}
