import SwiftUI

/// Renders the ADHD-specific fields produced by ProcessingViewModel:
/// medication info, mood/energy/focus state, and the structured bullet summary.
/// Hidden entirely when the recording has no ADHD data (e.g., legacy notes).
struct ADHDSummarySection: View {
    let recording: Recording
    var onRegenerate: (() -> Void)?

    var body: some View {
        if hasContent {
            VStack(alignment: .leading, spacing: Spacing.l) {
                HStack {
                    Text("Log Entries")
                        .font(Typography.headline)
                    Spacer()
                    if let onRegenerate {
                        Button(action: onRegenerate) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(Theme.accent)
                        }
                        .accessibilityLabel("Regenerate summary")
                    }
                }

                if hasStateBadges {
                    HStack(spacing: Spacing.s) {
                        if let mood = recording.mood {
                            StateBadge(glyph: GlyphBadge(kind: .mood, level: MoodLevel(name: mood)?.numericValue),
                                       label: "Mood", value: mood, color: recording.moodColor)
                        }
                        if let energy = recording.energyLevel {
                            StateBadge(glyph: GlyphBadge(kind: .energy, level: EnergyLevel(rawValue: energy.lowercased())?.numericValue),
                                       label: "Energy", value: energy, color: .orange)
                        }
                        if let focus = recording.focusLevel {
                            StateBadge(glyph: GlyphBadge(kind: .focus, level: FocusLevel(rawValue: focus.lowercased())?.numericValue),
                                       label: "Focus", value: focus, color: .indigo)
                        }
                    }
                }

                if recording.hasMedication {
                    medicationSection()
                }

                if hasTags {
                    TagFlowView(tags: extraTags)
                }
            }
            .card(padding: Spacing.xxl)
        }
    }

    private var hasContent: Bool {
        recording.hasMedication
            || recording.mood != nil
            || recording.energyLevel != nil
            || recording.focusLevel != nil
            || !recording.decodedFeelings.isEmpty
            || !recording.decodedSideEffects.isEmpty
            || recording.decodedSleepLevel != nil
            || recording.sleepHours != nil
    }

    private var hasStateBadges: Bool {
        recording.mood != nil
            || recording.energyLevel != nil
            || recording.focusLevel != nil
    }

    private var hasTags: Bool { !extraTags.isEmpty }

    private var extraTags: [DisplayTag] {
        var tags: [DisplayTag] = []
        for (i, feeling) in recording.decodedFeelings.enumerated() {
            tags.append(DisplayTag(id: "f-\(i)", label: feeling.capitalized, icon: "heart.fill", color: .pink))
        }
        if let level = recording.decodedSleepLevel {
            tags.append(DisplayTag(id: "sleep", label: level.rawValue.capitalized, icon: "moon.fill", color: .indigo, glyph: GlyphBadge(kind: .sleep)))
        } else if let hours = recording.sleepHours {
            let label = hours == hours.rounded() ? "\(Int(hours))h sleep" : "\(hours)h sleep"
            tags.append(DisplayTag(id: "sleep", label: label, icon: "moon.fill", color: .indigo, glyph: GlyphBadge(kind: .sleep)))
        }
        for (i, effect) in recording.decodedSideEffects.enumerated() {
            tags.append(DisplayTag(id: "se-\(i)", label: effect.capitalized, icon: "bandage.fill", color: .orange))
        }
        return tags
    }

    private func medicationSection() -> some View {
        let sorted = recording.medicationEvents
            .filter { $0.source == .transcript }
            .sorted { $0.takenAt < $1.takenAt }
        return VStack(alignment: .leading, spacing: Spacing.s) { // was 6
            Text("Medication")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, Spacing.xs) // was 2
            VStack(spacing: Spacing.xs) {
                ForEach(sorted) { event in
                    medicationRow(event)
                }
            }
        }
        .padding(Spacing.m)
        .background(Color.purple.opacity(0.12))
        .clipShape(.rect(cornerRadius: 12))
    }

    private func medicationRow(_ event: MedicationEvent) -> some View {
        let timeStr = event.takenAt.formatted(date: .omitted, time: .shortened)
        return HStack(spacing: Spacing.s) {
            SignalGlyph(.medication, size: 18, decorative: true)
            Text(timeStr)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)
            Text(doseText(for: event))
                .font(Typography.subheadline)
                .fontWeight(.medium)
            Spacer(minLength: 0)
            if let change = event.change {
                changeBadge(change)
            }
            if !event.taken {
                Image(systemName: "xmark.circle")
                    .font(.caption)
                    .foregroundStyle(.orange.opacity(0.8))
                    .accessibilityLabel("missed")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(medicationRowLabel(event))
    }

    private func changeBadge(_ change: MedEventChange) -> some View {
        Group {
            if change == .started {
                Text("Started")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, Spacing.s) // was 6
                    .padding(.vertical, Spacing.xs) // was 2
                    .background(Color.green.opacity(0.15))
                    .foregroundStyle(.green)
                    .clipShape(.rect(cornerRadius: 8))
            } else if change == .stopped {
                Text("Stopped")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, Spacing.s) // was 6
                    .padding(.vertical, Spacing.xs) // was 2
                    .background(Color.red.opacity(0.15))
                    .foregroundStyle(.red)
                    .clipShape(.rect(cornerRadius: 8))
            }
        }
    }


    private func doseText(for event: MedicationEvent) -> String {
        let qty = event.quantity ?? 1.0
        let base = event.dose.map { "\(event.name) \($0)" } ?? event.name
        if qty == 0.5 {
            return "\(base) × ½"
        } else if qty != 1.0 {
            let formatted = qty == qty.rounded() ? String(Int(qty)) : String(format: "%.1f", qty)
            return "\(base) × \(formatted)"
        }
        return base
    }

    private func medicationRowLabel(_ event: MedicationEvent) -> String {
        var parts = [event.name]
        if let dose = event.dose { parts.append(dose) }
        let qty = event.quantity ?? 1.0
        if qty == 0.5 { parts.append("half dose") }
        else if qty != 1.0 { parts.append("\(qty) doses") }
        if let change = event.change, change != .regular {
            parts.append(change.rawValue)
        }
        parts.append("at \(event.takenAt.formatted(date: .omitted, time: .shortened))")
        if let label = event.timeLabel { parts.append(label) }
        if !event.taken { parts.append("missed") }
        return parts.joined(separator: " ")
    }
}

private struct StateBadge: View {
    var icon: String? = nil
    var glyph: GlyphBadge? = nil
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                if let glyph {
                    SignalGlyph(glyph.kind, level: glyph.level, size: 16, decorative: true)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                        .accessibilityHidden(true)
                }
                Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundStyle(color)
            Text(value.capitalized)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.15))
        .clipShape(.rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

#Preview("Full") {
    let recording = Recording(
        audioFileName: "preview.m4a",
        duration: 60,
        fullTranscriptText: "I took Concerta 36mg this morning, feeling focused but anxious, energy is high.",
        title: "Morning check-in",
        hasMedication: true,
        energyLevel: "high",
        focusLevel: "focused",
        mood: "anxious",
        summaryBulletsJSON: "[\"Medication: Concerta 36mg at 8am\",\"Feeling focused after morning dose\",\"Energy: high\",\"Some lingering anxiety\"]"
    )
    return ADHDSummarySection(recording: recording, onRegenerate: {})
        .padding()
}

#Preview("No medication") {
    let recording = Recording(
        audioFileName: "preview2.m4a",
        duration: 30,
        fullTranscriptText: "Slept well, calm morning.",
        title: "Quiet morning",
        hasMedication: false,
        energyLevel: "low",
        focusLevel: "scattered",
        mood: "calm",
        summaryBulletsJSON: "[\"Medication: Not mentioned\",\"Slept well\",\"Calm mood\"]"
    )
    return ADHDSummarySection(recording: recording, onRegenerate: {})
        .padding()
}

#Preview("Empty (legacy note)") {
    let recording = Recording(
        audioFileName: "legacy.m4a",
        title: "Legacy note"
    )
    return ADHDSummarySection(recording: recording)
        .padding()
        .border(.gray)
}
