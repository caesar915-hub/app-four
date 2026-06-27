import SwiftUI

struct ADHDSummarySection: View {
    let recording: Recording

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            if !transcriptMeds.isEmpty { medsCard }
            sleepCard
            emotionsCard
            sideEffectsCard
        }
    }

    private var transcriptMeds: [MedicationEvent] {
        recording.medicationEvents
            .filter { $0.source == .transcript }
            .sorted { $0.takenAt < $1.takenAt }
    }

    // MARK: - Medications card

    private var medsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Medications").cardEyebrow()
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

    // MARK: - Sleep card

    @ViewBuilder private var sleepCard: some View {
        let tag: DisplayTag? = {
            if let level = recording.decodedSleepLevel {
                return DisplayTag(id: "sleep", label: level.rawValue.capitalized,
                                  icon: "moon.fill", color: Palette.sleepIndigo,
                                  glyph: GlyphBadge(kind: .sleep))
            } else if let hours = recording.sleepHours {
                let label = hours == hours.rounded() ? "\(Int(hours))h sleep" : "\(hours)h sleep"
                return DisplayTag(id: "sleep", label: label,
                                  icon: "moon.fill", color: Palette.sleepIndigo)
            }
            return nil
        }()
        if let tag {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Sleep").cardEyebrow()
                TagFlowView(tags: [tag])
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    // MARK: - Emotions card

    @ViewBuilder private var emotionsCard: some View {
        let tags = recording.decodedEmotions.enumerated().map { (i, e) in
            DisplayTag(id: "e-\(i)", label: e.capitalized, icon: "heart.fill", color: Theme.accent)
        }
        if !tags.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Emotions").cardEyebrow()
                TagFlowView(tags: tags)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    // MARK: - Side Effects card

    @ViewBuilder private var sideEffectsCard: some View {
        let tags = recording.decodedSideEffects.enumerated().map { (i, e) in
            DisplayTag(id: "se-\(i)", label: e.capitalized, icon: "bandage.fill", color: Palette.warning)
        }
        if !tags.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Side Effects").cardEyebrow()
                TagFlowView(tags: tags)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
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
    return ADHDSummarySection(recording: recording)
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
    return ADHDSummarySection(recording: recording)
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
