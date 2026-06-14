import SwiftUI

// MARK: - Display helpers derived from NLP-extracted fields

extension Recording {

    /// Soft pastel fill for the mood bead and banner (calendar palette).
    /// See `MoodLevel` for the scale, the deeper header shade, and day-averaging.
    var moodColor: Color {
        MoodLevel(name: mood)?.fill ?? Color(.systemGray4)
    }

    var moodIcon: String {
        switch mood?.lowercased() {
        case "low":  return "cloud.fill"
        case "flat": return "minus.circle"
        case "okay": return "circle"
        case "good": return "sun.min.fill"
        case "great": return "sun.max.fill"
        default:     return "circle"
        }
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

    /// Tags shown as chips under a timeline check-in: feelings, side effects,
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
                                   color: level?.color ?? Palette.energyRamp[2]))
        }

        if let focus = focusLevel {
            let level = FocusLevel(rawValue: focus.lowercased())
            tags.append(DisplayTag(id: "focus", label: focus, icon: "target",
                                   color: level?.color ?? Palette.focusRamp[2]))
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
            tags.append(DisplayTag(id: "sleep", label: label, icon: "moon.fill", color: .indigo))
        } else if let hours = sleepHours {
            let label = hours == hours.rounded() ? "\(Int(hours))h sleep" : "\(hours)h sleep"
            tags.append(DisplayTag(id: "sleep", label: label, icon: "moon.fill", color: .indigo))
        } else if let quality = sleepQuality {
            tags.append(DisplayTag(id: "sleep", label: "\(quality) sleep", icon: "moon.fill", color: .indigo))
        }

        for (i, effect) in decodedSideEffects.enumerated() {
            tags.append(DisplayTag(id: "se-\(i)", label: effect.capitalized, icon: "bandage.fill", color: Palette.warning))
        }

        for (i, feeling) in decodedFeelings.enumerated() {
            tags.append(DisplayTag(id: "feeling-\(i)", label: feeling.capitalized, icon: "heart.fill", color: .pink))
        }

        var seenMedNames = Set<String>()
        for event in medicationEvents {
            guard seenMedNames.insert(event.name).inserted else { continue }
            let qty = event.quantity ?? 1.0
            let changeSuffix = event.change == .started ? " ↑" : event.change == .stopped ? " ↓" : ""
            let qtySuffix = qty == 0.5 ? " ½" : ""
            let label = "\(event.name)\(qtySuffix)\(changeSuffix)"
            tags.append(DisplayTag(id: "med-\(event.name)", label: label, icon: "pills.fill", color: Palette.medication))
        }

        return tags
    }
}

struct DisplayTag: Identifiable {
    let id: String
    let label: String
    let icon: String
    let color: Color
}
