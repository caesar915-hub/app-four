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
        
        seedCalendarContexts(context: context, calendar: calendar, now: now)
        try? context.save()
    }

    private static func seedCalendarContexts(context: ModelContext, calendar: Calendar, now: Date) {
        // Five representative days out of the 10 seeded; offsets match the Recording loop above.
        let fixtures: [(offset: Int, events: CapturedDayEvents)] = [
            // Day −1: standup + design review meeting, plus a dentist appointment
            (offset: 1, events: {
                guard
                    let base = calendar.date(byAdding: .day, value: -1, to: now),
                    let s1 = calendar.date(bySettingHour: 9, minute: 30, second: 0, of: base),
                    let e1 = calendar.date(bySettingHour: 9, minute: 45, second: 0, of: base),
                    let s2 = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: base),
                    let e2 = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: base),
                    let s3 = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: base),
                    let e3 = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: base)
                else { return CapturedDayEvents(events: []) }
                return CapturedDayEvents(events: [
                    CapturedEvent(title: "Standup", start: s1, end: e1, isAllDay: false, attendeeCount: 5, availability: "busy"),
                    CapturedEvent(title: "Design Review", start: s2, end: e2, isAllDay: false, attendeeCount: 3, availability: "busy"),
                    CapturedEvent(title: "Dentist", start: s3, end: e3, isAllDay: false, attendeeCount: 0, availability: "busy"),
                ])
            }()),

            // Day −3: all-day birthday + one meeting
            (offset: 3, events: {
                guard
                    let base = calendar.date(byAdding: .day, value: -3, to: now),
                    let dayStart = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: base),
                    let dayEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: base),
                    let s1 = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: base),
                    let e1 = calendar.date(bySettingHour: 10, minute: 30, second: 0, of: base)
                else { return CapturedDayEvents(events: []) }
                return CapturedDayEvents(events: [
                    CapturedEvent(title: "Mom's Birthday", start: dayStart, end: dayEnd, isAllDay: true, attendeeCount: 0, availability: "free"),
                    CapturedEvent(title: "1:1 with Manager", start: s1, end: e1, isAllDay: false, attendeeCount: 2, availability: "busy"),
                ])
            }()),

            // Day −5: meetings-only day (three back-to-back)
            (offset: 5, events: {
                guard
                    let base = calendar.date(byAdding: .day, value: -5, to: now),
                    let s1 = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: base),
                    let e1 = calendar.date(bySettingHour: 9, minute: 30, second: 0, of: base),
                    let s2 = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: base),
                    let e2 = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: base),
                    let s3 = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: base),
                    let e3 = calendar.date(bySettingHour: 15, minute: 30, second: 0, of: base)
                else { return CapturedDayEvents(events: []) }
                return CapturedDayEvents(events: [
                    CapturedEvent(title: "Standup", start: s1, end: e1, isAllDay: false, attendeeCount: 6, availability: "busy"),
                    CapturedEvent(title: "Sprint Planning", start: s2, end: e2, isAllDay: false, attendeeCount: 8, availability: "busy"),
                    CapturedEvent(title: "Retrospective", start: s3, end: e3, isAllDay: false, attendeeCount: 7, availability: "busy"),
                ])
            }()),

            // Day −7: single personal errand, no meetings
            (offset: 7, events: {
                guard
                    let base = calendar.date(byAdding: .day, value: -7, to: now),
                    let s1 = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: base),
                    let e1 = calendar.date(bySettingHour: 11, minute: 45, second: 0, of: base)
                else { return CapturedDayEvents(events: []) }
                return CapturedDayEvents(events: [
                    CapturedEvent(title: "Pharmacy", start: s1, end: e1, isAllDay: false, attendeeCount: 0, availability: "busy"),
                ])
            }()),

            // Day −9: mixed — standup + focus block + gym
            (offset: 9, events: {
                guard
                    let base = calendar.date(byAdding: .day, value: -9, to: now),
                    let s1 = calendar.date(bySettingHour: 9, minute: 15, second: 0, of: base),
                    let e1 = calendar.date(bySettingHour: 9, minute: 30, second: 0, of: base),
                    let s2 = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: base),
                    let e2 = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: base),
                    let s3 = calendar.date(bySettingHour: 17, minute: 30, second: 0, of: base),
                    let e3 = calendar.date(bySettingHour: 18, minute: 30, second: 0, of: base)
                else { return CapturedDayEvents(events: []) }
                return CapturedDayEvents(events: [
                    CapturedEvent(title: "Standup", start: s1, end: e1, isAllDay: false, attendeeCount: 4, availability: "busy"),
                    CapturedEvent(title: "Focus Block", start: s2, end: e2, isAllDay: false, attendeeCount: 0, availability: "busy"),
                    CapturedEvent(title: "Gym", start: s3, end: e3, isAllDay: false, attendeeCount: 0, availability: "free"),
                ])
            }()),
        ]

        for fixture in fixtures {
            guard let baseDate = calendar.date(byAdding: .day, value: -fixture.offset, to: now) else { continue }
            let key = DayKey.make(for: baseDate)
            let ctx = DayCalendarContext(
                dayKey: key,
                capturedAt: baseDate,
                titlesIncluded: true,
                isMockData: true
            )
            ctx.encodeEvents(fixture.events)
            context.insert(ctx)
        }
    }
}
