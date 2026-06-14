import Foundation
import SwiftUI

// MARK: - Supporting types

enum SignalKind: CaseIterable, Equatable, Hashable {
    case mood, energy, focus

    var label: String {
        switch self { case .mood: "Mood"; case .energy: "Energy"; case .focus: "Focus" }
    }
}

struct MoodShare {
    let level: MoodLevel
    let count: Int
    let fraction: Double
}

struct SignalBead {
    let date: Date
    let level: (any SignalLevel)?
    let recordingID: UUID?
}

struct SignalStrip {
    let kind: SignalKind
    let beads: [SignalBead]
    let summary: String
}

struct SignalAverage {
    let kind: SignalKind
    let fillLabel: String
    let caption: String
    let fraction: Double
    var isEmpty: Bool { fillLabel == "—" }
}

enum TimeBucket: CaseIterable, Hashable {
    case morning   // 06–11
    case afternoon // 12–17
    case evening   // 18–21
    case late      // 22–23 + 00–05

    var label: String {
        switch self {
        case .morning:   "Morning"
        case .afternoon: "Afternoon"
        case .evening:   "Evening"
        case .late:      "Late"
        }
    }

    func contains(hour: Int) -> Bool {
        switch self {
        case .morning:   return (6..<12).contains(hour)
        case .afternoon: return (12..<18).contains(hour)
        case .evening:   return (18..<22).contains(hour)
        case .late:      return hour >= 22 || hour < 6
        }
    }
}

struct RhythmCell {
    let bucket: TimeBucket
    let dominant: (any SignalLevel)?
    let count: Int
}

struct RhythmRow {
    let kind: SignalKind
    let cells: [RhythmCell]
}

enum ConnectionState {
    case gated(unlockCopy: String)
    case unlocked(sentence: String, fraction: Double, barLabel: String, leadingText: String, trailingText: String)
}

struct Connection {
    let title: String
    let state: ConnectionState
}

// MARK: - InsightsViewModel computed properties

extension InsightsViewModel {

    // MARK: moodShares

    var moodShares: [MoodShare] {
        let levels = monthRecordings.compactMap { r in r.mood.flatMap { MoodLevel(name: $0) } }
        guard !levels.isEmpty else { return [] }
        var counts: [MoodLevel: Int] = [:]
        for l in levels { counts[l, default: 0] += 1 }
        let total = levels.count
        return MoodLevel.allCases.compactMap { level in
            guard let c = counts[level] else { return nil }
            return MoodShare(level: level, count: c, fraction: Double(c) / Double(total))
        }
    }

    // MARK: signalStrips

    var signalStrips: [SignalStrip] {
        let days = Array(Set(monthRecordings.map { calendar.startOfDay(for: $0.createdAt) })).sorted()
        return SignalKind.allCases.map { kind in
            let beads: [SignalBead] = days.map { day in
                let dayRecs = monthRecordings
                    .filter { calendar.startOfDay(for: $0.createdAt) == day }
                    .sorted { $0.createdAt > $1.createdAt }
                let latest = dayRecs.first
                let level: (any SignalLevel)? = signalLevel(for: kind, from: latest)
                return SignalBead(date: day, level: level, recordingID: latest?.id)
            }
            return SignalStrip(kind: kind, beads: beads, summary: stripSummary(kind: kind))
        }
    }

    // MARK: signalAverages

    var signalAverages: [SignalAverage] {
        SignalKind.allCases.map { kind in
            let values = monthRecordings.compactMap { r -> Double? in
                signalLevel(for: kind, from: r).map { Double($0.numericValue) }
            }
            guard !values.isEmpty else {
                return SignalAverage(kind: kind, fillLabel: "—", caption: "", fraction: 0)
            }
            let avg = values.reduce(0, +) / Double(values.count)
            let fraction = avg / 5.0
            let lower = Int(avg)
            let isWhole = Double(lower) == avg
            let fillLabel: String
            let caption: String
            if isWhole {
                let label = levelLabel(kind: kind, numericValue: lower)
                fillLabel = label
                caption = "\(label) on average"
            } else {
                let lowerLabel = levelLabel(kind: kind, numericValue: lower)
                let upperLabel = levelLabel(kind: kind, numericValue: lower + 1)
                fillLabel = "\(lowerLabel)+"
                caption = "between \(lowerLabel) & \(upperLabel)"
            }
            return SignalAverage(kind: kind, fillLabel: fillLabel, caption: caption, fraction: fraction)
        }
    }

    // MARK: rhythmMatrix

    var rhythmMatrix: [RhythmRow] {
        SignalKind.allCases.map { kind in
            let cells = TimeBucket.allCases.map { bucket -> RhythmCell in
                let inBucket: [Recording] = monthRecordings.filter { r -> Bool in
                    let h = self.calendar.component(Calendar.Component.hour, from: r.createdAt)
                    return bucket.contains(hour: h)
                }
                let levels: [any SignalLevel] = inBucket.compactMap { signalLevel(for: kind, from: $0) }
                let dominant: (any SignalLevel)?
                if levels.isEmpty {
                    dominant = nil
                } else {
                    var freq: [Int: Int] = [:]
                    for l in levels { freq[l.numericValue, default: 0] += 1 }
                    let maxCount = freq.values.max()!
                    let topValue = freq.filter { $0.value == maxCount }.keys.max()!
                    dominant = resolvedLevel(kind: kind, numericValue: topValue)
                }
                return RhythmCell(bucket: bucket, dominant: dominant, count: levels.count)
            }
            return RhythmRow(kind: kind, cells: cells)
        }
    }

    // MARK: connections

    var connections: [Connection] {
        [medFocusConnection, energyMoodConnection, sleepMoodConnection]
    }

    private var medFocusConnection: Connection {
        let medRecs = monthRecordings.filter { !$0.medicationEvents.isEmpty }
        let medDayDates = Set(medRecs.map { calendar.startOfDay(for: $0.createdAt) })
        guard medDayDates.count >= 4 else {
            let need = 4 - medDayDates.count
            let copy = "Log medication on \(need) more \(Self.dayNoun(need)) to unlock this connection."
            return Connection(title: "Medication × focus", state: .gated(unlockCopy: copy))
        }
        let goodFocusDays = medDayDates.filter { day -> Bool in
            let dayRecs = monthRecordings.filter { self.calendar.startOfDay(for: $0.createdAt) == day }
            return dayRecs.contains { r -> Bool in
                let level = r.focusLevel.flatMap { FocusLevel(rawValue: $0.lowercased()) }
                return (level?.numericValue ?? 0) >= 4
            }
        }
        let frac = Double(goodFocusDays.count) / Double(medDayDates.count)
        let pct = Int((frac * 100).rounded())
        return Connection(
            title: "Medication × focus",
            state: .unlocked(
                sentence: "On medication days, sharp focus appeared \(pct)% of the time.",
                fraction: frac,
                barLabel: "\(pct)%",
                leadingText: "Med days",
                trailingText: "Sharp+ focus"
            )
        )
    }

    private var energyMoodConnection: Connection {
        let highEnergyRecs = monthRecordings.filter { r -> Bool in
            let level = r.energyLevel.flatMap { EnergyLevel(rawValue: $0.lowercased()) }
            return (level?.numericValue ?? 0) >= 4
        }
        let highEnergyDayDates = Set(highEnergyRecs.map { calendar.startOfDay(for: $0.createdAt) })
        guard highEnergyDayDates.count >= 5 else {
            let need = 5 - highEnergyDayDates.count
            let copy = "Log high energy on \(need) more \(Self.dayNoun(need)) to unlock this connection."
            return Connection(title: "Energy × mood", state: .gated(unlockCopy: copy))
        }
        let goodMoodDays = highEnergyDayDates.filter { day -> Bool in
            let dayRecs = monthRecordings.filter { self.calendar.startOfDay(for: $0.createdAt) == day }
            return dayRecs.contains { r -> Bool in
                let level = r.mood.flatMap { MoodLevel(name: $0) }
                return (level?.numericValue ?? 0) >= 4
            }
        }
        let frac = Double(goodMoodDays.count) / Double(highEnergyDayDates.count)
        let pct = Int((frac * 100).rounded())
        return Connection(
            title: "Energy × mood",
            state: .unlocked(
                sentence: "On high-energy days, good-or-better mood appeared \(pct)% of the time.",
                fraction: frac,
                barLabel: "\(pct)%",
                leadingText: "High energy",
                trailingText: "Good+ mood"
            )
        )
    }

    private var sleepMoodConnection: Connection {
        let goodSleep: Set<String> = ["good", "great", "excellent", "well"]
        let poorSleep: Set<String> = ["poor", "bad", "terrible", "awful", "rough"]
        let withSleep = monthRecordings.filter { $0.sleepQuality != nil }
        let goodDays = Set(withSleep
            .filter { goodSleep.contains($0.sleepQuality?.lowercased() ?? "") }
            .map { calendar.startOfDay(for: $0.createdAt) })
        let poorDays = Set(withSleep
            .filter { poorSleep.contains($0.sleepQuality?.lowercased() ?? "") }
            .map { calendar.startOfDay(for: $0.createdAt) })
        guard goodDays.count >= 3, poorDays.count >= 3 else {
            let needGood = max(0, 3 - goodDays.count)
            let needPoor = max(0, 3 - poorDays.count)
            var parts: [String] = []
            if needGood > 0 { parts.append("\(needGood) more good-sleep \(Self.dayNoun(needGood))") }
            if needPoor > 0 { parts.append("\(needPoor) more poor-sleep \(Self.dayNoun(needPoor))") }
            let copy = "Note \(parts.joined(separator: " and ")) to unlock this connection."
            return Connection(title: "Sleep × mood", state: .gated(unlockCopy: copy))
        }
        let alignedGood = goodDays.filter { day -> Bool in
            let dayRecs = monthRecordings.filter { calendar.startOfDay(for: $0.createdAt) == day }
            return dayRecs.contains { r -> Bool in
                let n = r.mood.flatMap { MoodLevel(name: $0) }?.numericValue ?? 0
                return n >= 3
            }
        }
        let alignedPoor = poorDays.filter { day -> Bool in
            let dayRecs = monthRecordings.filter { calendar.startOfDay(for: $0.createdAt) == day }
            return dayRecs.contains { r -> Bool in
                let n = r.mood.flatMap { MoodLevel(name: $0) }?.numericValue ?? 0
                return n <= 2
            }
        }
        let totalDays = goodDays.count + poorDays.count
        let frac = Double(alignedGood.count + alignedPoor.count) / Double(totalDays)
        let pct = Int((frac * 100).rounded())
        return Connection(
            title: "Sleep × mood",
            state: .unlocked(
                sentence: "Sleep quality and mood moved together \(pct)% of the time.",
                fraction: frac,
                barLabel: "\(pct)%",
                leadingText: "Sleep quality",
                trailingText: "Aligned mood"
            )
        )
    }

    // MARK: - Private helpers

    /// "day" / "days" for unlock copy.
    fileprivate static func dayNoun(_ n: Int) -> String { n == 1 ? "day" : "days" }

    private func signalLevel(for kind: SignalKind, from recording: Recording?) -> (any SignalLevel)? {
        guard let r = recording else { return nil }
        switch kind {
        case .mood:   return r.mood.flatMap { MoodLevel(name: $0) }
        case .energy: return r.energyLevel.flatMap { EnergyLevel(rawValue: $0.lowercased()) }
        case .focus:  return r.focusLevel.flatMap { FocusLevel(rawValue: $0.lowercased()) }
        }
    }

    private func stripSummary(kind: SignalKind) -> String {
        let levels: [any SignalLevel] = monthRecordings.compactMap { signalLevel(for: kind, from: $0) }
        guard !levels.isEmpty else { return "no data" }
        var freq: [Int: (count: Int, label: String)] = [:]
        for l in levels {
            if freq[l.numericValue] == nil { freq[l.numericValue] = (0, l.displayLabel) }
            freq[l.numericValue]!.count += 1
        }
        let modal = freq.max { $0.value.count < $1.value.count }!.value
        return "mostly \(modal.label)"
    }

    private func levelLabel(kind: SignalKind, numericValue: Int) -> String {
        switch kind {
        case .mood:   return MoodLevel.allCases.first { $0.numericValue == numericValue }?.displayLabel ?? ""
        case .energy: return EnergyLevel.allCases.first { $0.numericValue == numericValue }?.displayLabel ?? ""
        case .focus:  return FocusLevel.allCases.first { $0.numericValue == numericValue }?.displayLabel ?? ""
        }
    }

    private func resolvedLevel(kind: SignalKind, numericValue: Int) -> (any SignalLevel)? {
        switch kind {
        case .mood:   return MoodLevel.allCases.first { $0.numericValue == numericValue }
        case .energy: return EnergyLevel.allCases.first { $0.numericValue == numericValue }
        case .focus:  return FocusLevel.allCases.first { $0.numericValue == numericValue }
        }
    }
}
