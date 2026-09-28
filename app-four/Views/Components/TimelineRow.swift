import SwiftUI

/// One check-in row of the expanded day card (DESIGN.md §8.23): the 44-pt mood avatar, the mood
/// word in its colour + the time, the energy · focus words with 18-pt glyphs, and a `•••` menu.
/// Tapping the row opens the recording; emotions and side effects live on Day Details (D6.6).
/// A dose-only node (a logged dose with no check-in) shows the medication badge and dose.
struct TimelineRow: View {
    let node: DayTimeline.Node
    let onTapRecording: (UUID) -> Void
    var onDeleteRecording: ((UUID) -> Void)? = nil

    private var level: MoodLevel? { MoodLevel(name: node.recording?.mood) }

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.m) {
            if let recording = node.recording {
                Button { onTapRecording(recording.id) } label: { content(recording) }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens recording detail")
                menu(recording)
            } else {
                content(nil)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Content

    private func content(_ recording: Recording?) -> some View {
        HStack(alignment: .center, spacing: Spacing.m) {
            if recording != nil {
                MoodAvatar(level: level)
            } else {
                MedicationBadge(size: Metrics.avatar)
            }
            VStack(alignment: .leading, spacing: Spacing.xs) {
                headline(recording)
                    .fixedSize(horizontal: false, vertical: true)
                if !signalItems.isEmpty {
                    SignalWordsLine(items: signalItems, glyphSize: Metrics.glyphRow, ink: Ink.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(.rect)
    }

    /// "Great 18:30" — the mood word (or the recording's status title when no mood was
    /// extracted — FR-017) and the time, as one wrapping `Text`.
    private func headline(_ recording: Recording?) -> Text {
        let time = Text(node.time, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
            .font(Typography.rowLabel)
            .foregroundStyle(Ink.primary)
        if let level {
            let word = Text(level.displayLabel).font(Typography.entryTitle).foregroundStyle(level.wordColor)
            return Text("\(word) \(time)")
        }
        if let recording {
            let title = Text(recording.displayTitle).font(Typography.entryTitle).foregroundStyle(Ink.primary)
            return Text("\(title) \(time)")
        }
        let dose = Text(doseTitle).font(Typography.entryTitle).foregroundStyle(Ink.primary)
        return Text("\(dose) \(time)")
    }

    private var signalItems: [SignalWordsLine.Item] {
        var items: [SignalWordsLine.Item] = []
        if let raw = node.recording?.energyLevel, let level = EnergyLevel(rawValue: raw.lowercased()) {
            items.append(.init(kind: .energy, level: level.numericValue, text: level.displayLabel))
        }
        if let raw = node.recording?.focusLevel, let level = FocusLevel(rawValue: raw.lowercased()) {
            items.append(.init(kind: .focus, level: level.numericValue, text: level.displayLabel))
        }
        return items
    }

    private var doseTitle: String {
        let names = node.intakeDoses.map { dose in
            dose.dose.map { "\(dose.name) \($0)" } ?? dose.name
        }
        return names.joined(separator: ", ")
    }

    private func menu(_ recording: Recording) -> some View {
        Menu {
            Button("Open", systemImage: Icons.chevronRight) { onTapRecording(recording.id) }
            if let onDeleteRecording {
                Button("Delete", systemImage: Icons.trash, role: .destructive) { onDeleteRecording(recording.id) }
            }
        } label: {
            Image(systemName: Icons.more)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Accent.deepText)
                .frame(width: Metrics.navPillSmall, height: Metrics.navPillSmall)
                .background(Surface.card, in: .circle)
                .overlay { Circle().strokeBorder(Stroke.chip, lineWidth: Stroke.hairlineWidth) }
                .frame(minWidth: Metrics.minTapTarget, minHeight: Metrics.minTapTarget)
                .contentShape(.rect)
        }
        .accessibilityLabel("More")
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var parts: [String] = []
        if let level { parts.append(level.displayLabel) }
        parts.append(node.time.formatted(.dateTime.hour().minute(.twoDigits)))
        parts.append(contentsOf: signalItems.map(\.text))
        if node.recording == nil { parts.append(doseTitle) }
        return parts.joined(separator: ", ")
    }
}
