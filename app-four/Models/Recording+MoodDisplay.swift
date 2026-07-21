import SwiftUI

// MARK: - Display helpers derived from NLP-extracted fields

extension Recording {

    /// Soft pastel fill for the mood bead and banner (calendar palette).
    /// See `MoodLevel` for the scale, the deeper header shade, and day-averaging.
    var moodColor: Color {
        MoodLevel(name: mood)?.fill ?? Color(.systemGray4)
    }

    /// Combined headline for a timeline check-in: mood + energy + focus
    /// (e.g. "Good Alert Focused"). Falls back to the note's title when none of
    /// the three were extracted.
    var headline: String {
        let parts = [mood, energyLevel, focusLevel]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? title : parts.joined(separator: " ")
    }

    /// Tags shown as chips under a timeline check-in: emotions, side effects,
    /// sleep, and topics. Excludes energy/focus (folded into the headline) and
    /// medications (rendered as their own "Taken …" / active-dose lines).
    @MainActor var chipTags: [DisplayTag] {
        displayTags.filter { tag in
            tag.id != "energy" && tag.id != "focus" && !tag.id.hasPrefix("med-")
        }
    }

    @MainActor var displayTags: [DisplayTag] {
        var tags: [DisplayTag] = []

        for category in topicCategories {
            tags.append(DisplayTag(id: "cat-\(category.rawValue)", label: category.displayName, icon: category.icon, color: category.color))
        }

        if let energy = energyLevel {
            let level = EnergyLevel(rawValue: energy.lowercased())
            tags.append(DisplayTag(id: "energy", label: "\(energy) energy", icon: "bolt.fill",
                                   color: level?.color ?? Palette.energyRamp[2],
                                   glyph: GlyphBadge(kind: .energy, level: level?.numericValue)))
        }

        if let focus = focusLevel {
            let level = FocusLevel(rawValue: focus.lowercased())
            tags.append(DisplayTag(id: "focus", label: focus, icon: "target",
                                   color: level?.color ?? Palette.focusRamp[2],
                                   glyph: GlyphBadge(kind: .focus, level: level?.numericValue)))
        }

        if let event = decodedSleepEvent {
            let label: String
            if let h = event.hours {
                label = h == h.rounded() ? "\(Int(h))h sleep" : "\(h)h sleep"
            } else if let q = event.quality {
                label = "\(q) sleep"
            } else {
                label = "sleep"
            }
            tags.append(DisplayTag(id: "sleep", label: label, icon: "bed.double.fill", color: .indigo, glyph: GlyphBadge(kind: .sleep)))
        } else if let hours = sleepHours {
            let label = hours == hours.rounded() ? "\(Int(hours))h sleep" : "\(hours)h sleep"
            tags.append(DisplayTag(id: "sleep", label: label, icon: "bed.double.fill", color: .indigo, glyph: GlyphBadge(kind: .sleep)))
        } else if let quality = sleepQuality {
            tags.append(DisplayTag(id: "sleep", label: "\(quality) sleep", icon: "bed.double.fill", color: .indigo, glyph: GlyphBadge(kind: .sleep)))
        }

        for (i, effect) in decodedSideEffects.enumerated() {
            tags.append(DisplayTag(id: "se-\(i)", label: effect.capitalized, icon: "bandage.fill", color: Palette.warning))
        }

        for (i, emotion) in decodedEmotions.enumerated() {
            tags.append(DisplayTag(id: "emotion-\(i)", label: emotion.capitalized, icon: "heart.fill", color: .pink))
        }

        var seenMedNames = Set<String>()
        for event in medicationEvents ?? [] {
            guard seenMedNames.insert(event.name).inserted else { continue }
            let qty = event.quantity ?? 1.0
            let changeSuffix = event.change == .started ? " ↑" : event.change == .stopped ? " ↓" : ""
            let qtySuffix = qty == 0.5 ? " ½" : ""
            let label = "\(event.name)\(qtySuffix)\(changeSuffix)"
            tags.append(DisplayTag(id: "med-\(event.name)", label: label, icon: "pills.fill", color: Palette.medication, glyph: GlyphBadge(kind: .medication)))
        }

        return tags
    }

    // MARK: - DayCard redesign (spec 023): line-3 sleep + line-4 caps

    /// Human sleep label ("5h sleep", "calm sleep") or nil when no sleep was logged.
    @MainActor var sleepLabel: String? {
        if let event = decodedSleepEvent {
            if let h = event.hours { return h == h.rounded() ? "\(Int(h))h sleep" : "\(h)h sleep" }
            if let q = event.quality { return "\(q) sleep" }
            return "sleep"
        }
        if let hours = sleepHours { return hours == hours.rounded() ? "\(Int(hours))h sleep" : "\(hours)h sleep" }
        if let quality = sleepQuality { return "\(quality) sleep" }
        return nil
    }

    /// Feelings (emotions) for line 4, capped to `max` capitalised values + an overflow count.
    func feelings(max: Int = 4) -> (shown: [String], overflow: Int) { Self.capped(decodedEmotions, max: max) }

    /// Side-effects for line 4, capped to `max` capitalised values + an overflow count.
    func sideEffects(max: Int = 4) -> (shown: [String], overflow: Int) { Self.capped(decodedSideEffects, max: max) }

    private static func capped(_ all: [String], max: Int) -> (shown: [String], overflow: Int) {
        (all.prefix(max).map(\.capitalized), Swift.max(0, all.count - max))
    }
}

struct DisplayTag: Identifiable {
    let id: String
    let label: String
    let icon: String
    let color: Color
    /// When set, render the Paper & Pollen glyph instead of `icon` (signal tags only).
    var glyph: GlyphBadge? = nil
}
