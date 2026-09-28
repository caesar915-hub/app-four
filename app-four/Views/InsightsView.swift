import SwiftUI

/// Insights as the pen draws it (spec 057, `iPhone 17 - 7`): page title, the three-segment month
/// picker, then four `.large` cards — mood breakdown bubbles, weekday glyph rows, "Where you
/// averaged" range bars, the daily rhythm matrix — and the Connections section. One scroll; the
/// floating chrome stays (root tab).
struct InsightsView: View {
    @State private var viewModel: InsightsViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(store: RecordingStore) {
        _viewModel = State(wrappedValue: InsightsViewModel(store: store))
    }

    var body: some View {
        ScreenContainer(title: "", scrollable: false) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.cardGap) {
                    PageTitleBlock("Insights", subtitle: "Your month at a glance")
                    monthPicker
                    if viewModel.hasAnyData {
                        breakdownCard
                        signalsCard
                        averagesCard
                        rhythmCard
                        connectionsBlock
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.top, Spacing.m)
                .padding(.bottom, Spacing.section)
            }
        }
        .trackScreen("InsightsView")
    }

    // MARK: - Month picker (prev · selected · next)

    private var selectedMonth: Date { viewModel.calendar.startOfMonth(for: viewModel.currentMonth) }

    private var monthOptions: [Date] {
        let calendar = viewModel.calendar
        return [-1, 0, 1].compactMap { calendar.date(byAdding: .month, value: $0, to: selectedMonth) }
    }

    private var monthSelection: Binding<Date> {
        Binding(get: { selectedMonth }, set: { viewModel.currentMonth = $0 })
    }

    /// Next is disabled at the current month; previous once there is no data further back.
    private func isMonthEnabled(_ month: Date) -> Bool {
        let calendar = viewModel.calendar
        let thisMonth = calendar.startOfMonth(for: Date())
        let earliest = viewModel.availableMonths.first ?? thisMonth
        return month <= thisMonth && month >= min(earliest, selectedMonth)
    }

    /// Three segments fit "Sep 2026" at the default size; accessibility sizes drop the year.
    private func monthLabel(_ month: Date) -> String {
        dynamicTypeSize.isAccessibilitySize
            ? month.formatted(.dateTime.month(.abbreviated))
            : month.formatted(.dateTime.month(.abbreviated).year())
    }

    private var monthPicker: some View {
        SegmentedPicker(monthOptions, selection: monthSelection, label: monthLabel, isEnabled: isMonthEnabled)
            .accessibilityLabel("Month")
            .accessibilityValue(selectedMonth.formatted(.dateTime.month(.wide).year()))
    }

    // MARK: - Card scaffold

    /// Title + trailing count share a line; at accessibility sizes the count drops under the title
    /// so the title never breaks mid-word.
    private func cardHeader(_ title: String, trailing: String? = nil, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if dynamicTypeSize.isAccessibilitySize {
                Text(title)
                    .font(Typography.cardTitle)
                    .foregroundStyle(Ink.primary)
                    .accessibilityAddTraits(.isHeader)
                if let trailing {
                    Text(trailing)
                        .font(Typography.captionMedium)
                        .foregroundStyle(Ink.secondary)
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(Typography.cardTitle)
                        .foregroundStyle(Ink.primary)
                        .accessibilityAddTraits(.isHeader)
                    if let trailing {
                        Spacer(minLength: Spacing.s)
                        Text(trailing)
                            .font(Typography.captionMedium)
                            .foregroundStyle(Ink.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            if let subtitle {
                Text(subtitle)
                    .font(Typography.captionMedium)
                    .foregroundStyle(Ink.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Cards

    /// The header answers the "24 check-ins vs the chips' counts" question: when some check-ins
    /// carry no mood, say how many do.
    private var breakdownCount: String {
        let total = viewModel.monthRecordings.count
        let withMood = viewModel.moodShares.reduce(0) { $0 + $1.count }
        let noun = "check-in\(total == 1 ? "" : "s")"
        return withMood == total ? "\(total) \(noun)" : "\(withMood) of \(total) \(noun) with a mood"
    }

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            cardHeader("Mood check-in breakdown", trailing: breakdownCount)
            if viewModel.moodShares.isEmpty {
                Text("No moods logged this month yet.")
                    .font(Typography.cardSubtitle)
                    .foregroundStyle(Ink.tertiary)
            } else {
                MoodBubbleChart(shares: viewModel.moodShares)
                HairlineDivider()
                ChipRow {
                    ForEach(viewModel.moodShares, id: \.level) { share in
                        BillChip("\(share.level.displayLabel) (\(share.count))", style: .withDot(share.level.color))
                            .accessibilityLabel("\(share.level.displayLabel): \(share.count)")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(.large)
    }

    private var signalsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.cardInset) {
            cardHeader("Your month in three signals", subtitle: "Average by weekday")
            WeekdayGlyphRows(strips: viewModel.weekdaySignalStrips)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(.large)
    }

    private var averagesCard: some View {
        VStack(alignment: .leading, spacing: Spacing.cardInset) {
            cardHeader("Where you averaged")
            ForEach(Array(viewModel.signalAverages.enumerated()), id: \.element.kind) { index, average in
                if index > 0 { HairlineDivider() }
                RangeBar(average: average)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(.large)
    }

    private var rhythmCard: some View {
        VStack(alignment: .leading, spacing: Spacing.cardInset) {
            cardHeader("Your daily rhythm", subtitle: "Dominant level per signal by time of day")
            DailyRhythmMatrix(matrix: viewModel.rhythmMatrix)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(.large)
    }

    /// The caption states the real gates (4 / 5 / 3 + 3 days) — the pen's "3 or more days" was wrong.
    private var connectionsBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionHeading("Connections",
                           subtitle: "Patterns across signals — 4 medication days, 5 high-energy days, or 3 good + 3 poor sleep days to unlock")
            ConnectionCardsView(connections: viewModel.connections)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: Icons.insightsOutline)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Ink.tertiary)
                .accessibilityHidden(true)
            Text("Check in to see your month")
                .font(Typography.sectionTitle)
                .foregroundStyle(Ink.secondary)
            Text("Your mood, energy and focus patterns appear here once this month has a check-in.")
                .font(Typography.cardSubtitle)
                .foregroundStyle(Ink.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.hero)
    }
}

#Preview {
    InsightsView(store: .preview)
        .withPreviewEnvironment()
}
