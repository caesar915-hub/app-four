import SwiftUI

/// One day of the journal (DESIGN.md §8.23). **Collapsed** — the pen's previous-day card: a
/// mood-tinted r-12 card with the 44-pt avatar, the mood word + date, the signals line
/// (energy · focus · sleep) and the medication line. **Expanded** — the selected day: a white
/// r-24 card whose mint header band names the day's average mood, with one `TimelineRow` per
/// check-in. Tapping the collapsed body or the pill toggles expansion.
struct DayCard: View {
    let day: MoodLibraryViewModel.TimelineDay
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onTapRecording: (UUID) -> Void
    var onDeleteRecording: ((UUID) -> Void)? = nil

    private var summary: DayCardSummary { DayCardSummary(day: day) }
    private var level: MoodLevel? { MoodLevel(name: summary.mood) }

    var body: some View {
        if isExpanded && !day.nodes.isEmpty {
            expandedCard
        } else {
            collapsedCard
        }
    }

    // MARK: - Collapsed (previous day)

    private var collapsedCard: some View {
        Button(action: onToggleExpand) {
            HStack(alignment: .top, spacing: Spacing.m) {
                MoodAvatar(level: level)
                VStack(alignment: .leading, spacing: Spacing.s) {
                    HStack(alignment: .top, spacing: Spacing.s) {
                        titleRow
                        Spacer(minLength: Spacing.s)
                        NavPill(.chevronDown, size: Metrics.navPillSmall, action: onToggleExpand)
                            .accessibilityHidden(true)
                    }
                    if summary.isEmpty {
                        Text(DayCardSummary.emptyCopy)
                            .font(Typography.captionMedium)
                            .foregroundStyle(Ink.tertiary)
                            .lineLimit(2)
                    } else {
                        signalsLine
                        medicationLine
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .card(.day(level))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to expand")
    }

    /// "Great  Aug 30" — the mood word in its word colour, the date in primary ink; one `Text`
    /// so it wraps rather than truncates at large sizes.
    private var titleRow: Text {
        let date = Text(day.date, format: .dateTime.month(.abbreviated).day())
            .font(Typography.cardTitle)
            .foregroundStyle(Ink.primary)
        guard let level else { return date }
        let word = Text(level.displayLabel)
            .font(Typography.cardTitle)
            .foregroundStyle(level.wordColor)
        return Text("\(word)  \(date)")
    }

    private var signalsLine: some View {
        SignalWordsLine(items: signalItems, glyphSize: Metrics.glyphInline, ink: Ink.secondary)
    }

    private var signalItems: [SignalWordsLine.Item] {
        var items: [SignalWordsLine.Item] = []
        if let energy = summary.energy {
            items.append(.init(kind: .energy, level: EnergyLevel(rawValue: energy.lowercased())?.numericValue, text: energy))
        }
        if let focus = summary.focus {
            items.append(.init(kind: .focus, level: FocusLevel(rawValue: focus.lowercased())?.numericValue, text: focus))
        }
        if let sleep = summary.sleep {
            items.append(.init(kind: .sleep, level: summary.sleepLevel?.numericValue, text: sleep))
        }
        return items
    }

    @ViewBuilder private var medicationLine: some View {
        if let name = summary.mostRecentMedicationName {
            HStack(spacing: Spacing.xs) {
                MedicationPill()
                Text([name, summary.mostRecentMedicationDose].compactMap { $0 }.joined(separator: " "))
                    .font(Typography.captionMedium)
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Expanded (selected day)

    private var expandedCard: some View {
        VStack(spacing: 0) {
            band
            VStack(spacing: Spacing.m) {
                ForEach(Array(day.nodes.enumerated()), id: \.element.id) { index, node in
                    if index > 0 { HairlineDivider() }
                    TimelineRow(node: node, onTapRecording: onTapRecording, onDeleteRecording: onDeleteRecording)
                }
            }
            .padding(Spacing.cardInset)
        }
        .clipShape(.rect(cornerRadius: Radius.cardL))
        .raisedCard(.expandedDay, padding: 0)
    }

    /// The fixed mint band: "Okay • Fri 08" in green-800 with the collapse pill.
    private var band: some View {
        Button(action: onToggleExpand) {
            HStack(spacing: Spacing.s) {
                bandTitle
                Spacer(minLength: Spacing.s)
                NavPill(.chevronUp, size: Metrics.navPillSmall, action: onToggleExpand)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.cardInset)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(Surface.bandMint)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Expanded, double tap to collapse")
    }

    private var bandTitle: Text {
        let date = Text(day.date, format: .dateTime.weekday(.abbreviated).day(.twoDigits))
            .font(Typography.rowTitle)
            .foregroundStyle(Ink.title)
        guard let level else { return date }
        let word = Text(level.displayLabel).font(Typography.rowTitle).foregroundStyle(Ink.title)
        let dot = Text(" • ").font(Typography.rowTitle).foregroundStyle(Ink.secondary)
        return Text("\(word)\(dot)\(date)")
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        if summary.isEmpty { return "\(day.label). \(DayCardSummary.emptyCopy)" }
        let signals = [summary.mood, summary.energy, summary.focus, summary.mostRecentMedicationName, summary.sleep].compactMap { $0 }
        return ([day.label] + signals).joined(separator: ", ")
    }
}

// MARK: - Shared atoms

/// The 44-pt mood avatar: a tinted disc with the day's sprout (or the empty placeholder).
struct MoodAvatar: View {
    let level: MoodLevel?
    var size: CGFloat = Metrics.avatar

    var body: some View {
        Circle()
            .fill(level?.avatarTint ?? Surface.track)
            .overlay { Circle().strokeBorder(level?.avatarTint ?? Stroke.empty, lineWidth: Stroke.hairlineWidth) }
            .overlay {
                SignalGlyph(.mood, level: level?.numericValue, size: size * 0.76, decorative: true)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// "⚡ Alert • ◎ Distracted • ☾ 8h sleep" — glyph + word pairs separated by dots, wrapping.
struct SignalWordsLine: View {
    struct Item {
        let kind: GlyphSignal
        let level: Int?
        let text: String
    }

    let items: [Item]
    var glyphSize: CGFloat = Metrics.glyphRow
    var ink: Color = Ink.primary

    var body: some View {
        FlowLayout(spacing: Spacing.xs, rowSpacing: Spacing.xs) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(spacing: Spacing.xs) {
                    if index > 0 {
                        Text("•").font(Typography.captionMedium).foregroundStyle(Ink.secondary)
                    }
                    SignalGlyph(item.kind, level: item.level, size: glyphSize, decorative: true)
                    Text(item.text)
                        .font(Typography.captionMedium)
                        .foregroundStyle(ink)
                        .lineLimit(1)
                }
                .fixedSize()
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Collapsed / expanded") {
    VStack(spacing: Spacing.s) {
        DayCard(
            day: .init(date: .now, label: "Tuesday, 10 Jun", nodes: []),
            isExpanded: false,
            onToggleExpand: {},
            onTapRecording: { _ in }
        )
    }
    .padding(Spacing.gutter)
    .background(Surface.screen)
}
