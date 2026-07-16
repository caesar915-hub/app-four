import SwiftUI

/// Insights tab (a07, spec 036): one continuous scroll — title, month chips, then every
/// section on its own white New Look card at natural height. The former 5-page snap-pager
/// (one section per flick, dimmed headings) was retired by owner ruling 2026-07-16.
struct InsightsView: View {
    @Binding var selectedTab: Tab
    @State private var viewModel: InsightsViewModel
    @State private var path = NavigationPath()
    @Environment(AppServices.self) private var services
    private let store: RecordingStore

    init(store: RecordingStore, selectedTab: Binding<Tab>) {
        self.store = store
        _viewModel = State(wrappedValue: InsightsViewModel(store: store))
        _selectedTab = selectedTab
    }

    var body: some View {
        ScreenContainer(title: "", scrollable: false, path: $path) {
            Group {
                if viewModel.hasAnyData {
                    sectionsScroll
                } else {
                    VStack(spacing: 0) {
                        monthSelector
                        emptyState
                        Spacer(minLength: 0)
                    }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let recording = viewModel.recording(for: id) {
                    RecordingDetailView(recording: recording, store: store, services: services)
                } else {
                    // Recording deleted out from under an open push → pop back to the list.
                    Color.clear.onAppear { if !path.isEmpty { path.removeLast() } }
                }
            }
        }
        .trackScreen("InsightsView")
    }

    private var monthSelector: some View {
        MonthSelectorScrollView(
            currentMonth: $viewModel.currentMonth,
            availableMonths: viewModel.availableMonths
        )
        .padding(.vertical, Spacing.s)
    }

    /// Screen identity — "Insights" + the "<month> · today vs your usual" framing.
    private var insightsIdentity: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Insights")
                .font(Typography.text(24, weight: .bold, relativeTo: .title2))
                .foregroundStyle(NewLook.inkPrimary)
            Text("\(viewModel.currentMonth.formatted(.dateTime.month(.wide))) · today vs your usual")
                .font(Typography.subheadline)
                .foregroundStyle(NewLook.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
    }

    /// Sleep is spec'd but its ramp is deferred — surface it as a dashed "not tracked yet" chip.
    private var sleepDeferredChip: some View {
        HStack(spacing: Spacing.xs) {
            SignalGlyph(.sleep, size: 15, decorative: true)
            Text("Sleep · not tracked yet")
                .font(Typography.caption)
                .foregroundStyle(NewLook.inkSecondary)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .overlay(Capsule().strokeBorder(NewLook.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sleep, not tracked yet")
    }

    // MARK: - Continuous scroll (a07)

    private var sectionsScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                insightsIdentity
                monthSelector
                breakdownCard
                signalsCard
                averagesCard
                rhythmCard
                connectionsBlock
            }
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.hero)
        }
        .edgeFadeMask(top: 0, bottom: 36)
    }

    /// In-card section header (a07): bold title with an optional trailing count and caption line.
    private func cardHeader(_ title: String, trailing: String? = nil, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(Typography.headline)
                    .foregroundStyle(NewLook.inkPrimary)
                    .accessibilityAddTraits(.isHeader)
                if let trailing {
                    Spacer(minLength: Spacing.s)
                    Text(trailing)
                        .font(Typography.caption)
                        .foregroundStyle(NewLook.inkSecondary)
                }
            }
            if let subtitle {
                Text(subtitle)
                    .font(Typography.caption)
                    .foregroundStyle(NewLook.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Cards

    @ViewBuilder
    private var breakdownCard: some View {
        let count = viewModel.monthRecordings.count
        VStack(alignment: .leading, spacing: Spacing.m) {
            cardHeader("Your overall check-in breakdown",
                       trailing: "\(count) check-in\(count == 1 ? "" : "s")")
            if !viewModel.moodShares.isEmpty {
                MoodBubbleChart(shares: viewModel.moodShares)
                MoodLegend(shares: viewModel.moodShares)
            }
        }
        .newLookCard()
    }

    private var signalsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            cardHeader("Your month in three signals",
                       subtitle: "Average by weekday — this month")
            SignalStripsView(strips: viewModel.weekdaySignalStrips)
            sleepDeferredChip
        }
        .newLookCard()
    }

    private var averagesCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            cardHeader("Where you averaged")
            SignalAverageGauges(averages: viewModel.signalAverages)
        }
        .newLookCard()
    }

    private var rhythmCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            cardHeader("Your daily rhythm",
                       subtitle: "Dominant level per signal by time of day")
            DailyRhythmMatrix(matrix: viewModel.rhythmMatrix)
        }
        .newLookCard()
    }

    /// CONNECTIONS block (a07): caps eyebrow + caption outside the cards; the card
    /// treatments live in `ConnectionCardsView`.
    private var connectionsBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("CONNECTIONS")
                    .font(Typography.label)
                    .tracking(1.3)
                    .foregroundStyle(NewLook.inkSecondary)
                    .accessibilityAddTraits(.isHeader)
                Text("Patterns across signals — 3 or more days to unlock")
                    .font(Typography.caption)
                    .foregroundStyle(NewLook.inkSecondary)
            }
            ConnectionCardsView(connections: viewModel.connections)
        }
        .padding(.top, Spacing.m)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(Typography.largeTitle)
                .imageScale(.large)
                .foregroundStyle(NewLook.inkSecondary)
            Text("Check in to see your month")
                .font(Typography.headline)
                .foregroundStyle(NewLook.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.bottom, Spacing.hero)
    }
}

#Preview {
    InsightsView(store: .preview, selectedTab: .constant(.insights))
        .withPreviewEnvironment()
}
