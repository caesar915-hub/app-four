import SwiftUI

/// §07 Recording detail — the **Summary** card (regenerate ↻ + green-dot bullets, plus
/// emotion/sleep/side-effect tags) and the standalone **Meds** card. The mood/energy/focus
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
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                SignalGlyph(.medication, size: 18, decorative: true)
                Text(medsLine)
                    .font(Typography.body)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    /// §07 single line: "Concerta 36mg · Ritalin 10mg" (quantity / missed appended inline).
    private var medsLine: String {
        transcriptMeds.map { event in
            var s = event.dose.map { "\(event.name) \($0)" } ?? event.name
            let qty = event.quantity ?? 1.0
            if qty == 0.5 { s += " ×½" }
            else if qty != 1.0 {
                let f = qty == qty.rounded() ? String(Int(qty)) : String(format: "%.1f", qty)
                s += " ×\(f)"
            }
            if !event.taken { s += " (missed)" }
            return s
        }.joined(separator: " · ")
    }

    // MARK: - Derived content

    private var hasSummaryContent: Bool {
        !recording.summaryBullets.isEmpty || hasTags
    }

    private var hasTags: Bool { !extraTags.isEmpty }

    private var extraTags: [DisplayTag] {
        var tags: [DisplayTag] = []
        for (i, emotion) in recording.decodedEmotions.enumerated() {
            tags.append(DisplayTag(id: "e-\(i)", label: emotion.capitalized, icon: "heart.fill", color: Theme.accent))
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
