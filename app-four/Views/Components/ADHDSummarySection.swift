import SwiftUI

/// §07 Recording detail — the **Summary** card (regenerate ↻ + green-dot bullets, plus
/// feeling/sleep/side-effect tags) and the standalone **Meds** card. The mood/energy/focus
/// signal readback lives in the detail's top glyph row (RecordingDetailView), not here.
/// Hidden entirely when the recording carries no ADHD data (e.g. legacy notes).
struct ADHDSummarySection: View {
    let recording: Recording
    var onRegenerate: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            if hasSummaryContent { summaryCard }
            // Gate on the rows that actually render (transcript-sourced), not hasMedication —
            // a manual-only dose would otherwise show an empty "Meds" eyebrow card.
            if !transcriptMeds.isEmpty { medsCard }
        }
    }

    private var transcriptMeds: [MedicationEvent] {
        recording.medicationEvents
            .filter { $0.source == .transcript }
            .sorted { $0.takenAt < $1.takenAt }
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Text("Summary").cardEyebrow()
                Spacer()
                if let onRegenerate {
                    Button(action: onRegenerate) {
                        Image(systemName: "arrow.clockwise")
                            .font(Typography.subheadline)
                            .foregroundStyle(Theme.accent)
                    }
                    .accessibilityLabel("Regenerate summary")
                }
            }

            if !recording.summaryBullets.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    ForEach(Array(recording.summaryBullets.enumerated()), id: \.offset) { _, bullet in
                        HStack(alignment: .top, spacing: Spacing.s) {
                            Circle()
                                .fill(Theme.meadowGreen)
                                .frame(width: 5, height: 5)
                                .padding(.top, 7)
                            Text(bullet)
                                .font(Typography.body)
                                .foregroundStyle(Theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if hasTags { TagFlowView(tags: extraTags) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: - Meds card

    private var medsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Meds").cardEyebrow()
            VStack(spacing: Spacing.xs) {
                ForEach(transcriptMeds) { event in
                    medicationRow(event)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func medicationRow(_ event: MedicationEvent) -> some View {
        HStack(spacing: Spacing.s) {
            SignalGlyph(.medication, size: 18, decorative: true)
            Text(doseText(for: event))
                .font(Typography.body)
                .foregroundStyle(Theme.textPrimary)
            if let change = event.change, change != .regular {
                changeBadge(change)
            }
            Spacer(minLength: 0)
            if !event.taken {
                Image(systemName: "xmark.circle")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityLabel("missed")
            }
            Text(event.takenAt.formatted(date: .omitted, time: .shortened))
                .font(Typography.mono12)
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(medicationRowLabel(event))
    }

    private func changeBadge(_ change: MedEventChange) -> some View {
        Group {
            if change == .started {
                badge("Started", Theme.meadowGreen)
            } else if change == .stopped {
                badge("Stopped", Theme.danger)
            }
        }
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(Typography.label)
            .foregroundStyle(color)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs)
            .background(color.opacity(0.15))
            .clipShape(.rect(cornerRadius: 8))
    }

    // MARK: - Derived content

    private var hasSummaryContent: Bool {
        !recording.summaryBullets.isEmpty || hasTags
    }

    private var hasTags: Bool { !extraTags.isEmpty }

    private var extraTags: [DisplayTag] {
        var tags: [DisplayTag] = []
        for (i, feeling) in recording.decodedFeelings.enumerated() {
            tags.append(DisplayTag(id: "f-\(i)", label: feeling.capitalized, icon: "heart.fill", color: Theme.accent))
        }
        if let level = recording.decodedSleepLevel {
            tags.append(DisplayTag(id: "sleep", label: level.rawValue.capitalized, icon: "moon.fill", color: Palette.sleepIndigo, glyph: GlyphBadge(kind: .sleep)))
        } else if let hours = recording.sleepHours {
            let label = hours == hours.rounded() ? "\(Int(hours))h sleep" : "\(hours)h sleep"
            tags.append(DisplayTag(id: "sleep", label: label, icon: "moon.fill", color: Palette.sleepIndigo, glyph: GlyphBadge(kind: .sleep)))
        }
        for (i, effect) in recording.decodedSideEffects.enumerated() {
            tags.append(DisplayTag(id: "se-\(i)", label: effect.capitalized, icon: "bandage.fill", color: Palette.warning))
        }
        return tags
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
