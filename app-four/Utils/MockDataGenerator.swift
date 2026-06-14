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

                // Feelings (0–3), shown as neutral chips.
                let feelingPool = ["Happy", "Calm", "Relaxed", "Content", "Anxious", "Tired", "Bored", "Indifferent", "Restless", "Grateful"]
                let feelings = Array(feelingPool.shuffled().prefix(Int.random(in: 0...3)))
                if let data = try? JSONEncoder().encode(feelings), let json = String(data: data, encoding: .utf8) {
                    recording.feelingsJSON = json
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
    }
}
