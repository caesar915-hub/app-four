import SwiftUI

struct InsightsView: View {
    @Binding var selectedTab: Tab
    @State private var viewModel: InsightsViewModel
    @State private var path = NavigationPath()
    @State private var activeSectionID: SectionID? = .breakdown
    @Environment(AppServices.self) private var services
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let store: RecordingStore

    private enum SectionID: Hashable {
        case breakdown, signals, averages, rhythm, connections
    }

    init(store: RecordingStore, selectedTab: Binding<Tab>) {
        self.store = store
        _viewModel = State(wrappedValue: InsightsViewModel(store: store))
        _selectedTab = selectedTab
    }

    var body: some View {
        ScreenContainer(title: "", scrollable: false, path: $path) {
            Group {
                if viewModel.hasAnyData {
                    // Month selector rides at the top of the first page so it scrolls
                    // (and pages) away with the content rather than staying pinned.
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
                }
            }
        }
        .trackScreen("InsightsView")
        .sheet(item: $viewModel.selectedDay) { day in
            DayDetailSheet(day: day) { id in path.append(id) }
        }
        .onChange(of: selectedTab) { _, newValue in
            guard newValue == .insights else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                activeSectionID = .breakdown
            }
        }
    }

    private var monthSelector: some View {
        MonthSelectorScrollView(
            currentMonth: $viewModel.currentMonth,
            availableMonths: viewModel.availableMonths
        )
        .padding(.vertical, Spacing.s)
    }

    // MARK: - Snapping scroll

    private var sectionsScroll: some View {
        GeometryReader { proxy in
            let pageHeight = proxy.size.height
            ScrollView {
                VStack(spacing: 0) {
                    page(breakdownSection, height: pageHeight)
                    page(signalsSection, height: pageHeight)
                    page(averagesSection, height: pageHeight)
                    page(rhythmSection, height: pageHeight)
                    page(connectionsSection, height: pageHeight)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $activeSectionID, anchor: .top)
            .edgeFadeMask(top: 0, bottom: 36)
        }
    }

    /// Sizes a section to exactly one viewport so paging snaps one section per
    /// flick with no peek of the next. Content top-aligns for a consistent title Y.
    private func page(_ section: some View, height: CGFloat) -> some View {
        section
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .frame(height: height)
    }

    /// Active heading at full emphasis; every other heading (incl. the peeking
    /// next one) dimmed. 0.4 ≈ the dimmed peek in the reference video.
    private func headerOpacity(_ id: SectionID) -> Double {
        activeSectionID == id ? 1.0 : 0.4
    }

    private var headerAnimation: Animation? {
        reduceMotion ? nil : Motion.snappy
    }

    // MARK: - Sections

    @ViewBuilder
    private var breakdownSection: some View {
        let count = viewModel.monthRecordings.count
        let subtitle = "\(count) check-in\(count == 1 ? "" : "s")"
        VStack(spacing: 0) {
            monthSelector
            InsightsSectionHeader(title: "Your overall check-in breakdown", subtitle: subtitle)
                .opacity(headerOpacity(.breakdown))
            if !viewModel.moodShares.isEmpty {
                MoodBubbleChart(shares: viewModel.moodShares)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.s)
                MoodLegend(shares: viewModel.moodShares)
                    .padding(.top, Spacing.xs)
            }
        }
        .id(SectionID.breakdown)
        .animation(headerAnimation, value: activeSectionID)
    }

    private var signalsSection: some View {
        VStack(spacing: 0) {
            InsightsSectionHeader(
                title: "Your month in three signals",
                subtitle: "Each bead is one check-in day, in order"
            )
            .opacity(headerOpacity(.signals))
            SignalStripsView(strips: viewModel.signalStrips) { date in
                viewModel.selectedDay = viewModel.calendarDay(for: date)
            }
            .padding(.top, Spacing.s)
        }
        .id(SectionID.signals)
        .animation(headerAnimation, value: activeSectionID)
    }

    private var averagesSection: some View {
        VStack(spacing: 0) {
            InsightsSectionHeader(title: "Where you averaged")
                .opacity(headerOpacity(.averages))
            SignalAverageGauges(averages: viewModel.signalAverages)
                .padding(.top, Spacing.s)
        }
        .id(SectionID.averages)
        .animation(headerAnimation, value: activeSectionID)
    }

    private var rhythmSection: some View {
        VStack(spacing: 0) {
            InsightsSectionHeader(
                title: "Your daily rhythm",
                subtitle: "Dominant level per signal by time of day"
            )
            .opacity(headerOpacity(.rhythm))
            DailyRhythmMatrix(matrix: viewModel.rhythmMatrix)
                .padding(.top, Spacing.s)
        }
        .id(SectionID.rhythm)
        .animation(headerAnimation, value: activeSectionID)
    }

    private var connectionsSection: some View {
        VStack(spacing: 0) {
            InsightsSectionHeader(
                title: "Connections",
                subtitle: "Patterns across signals — 3 or more days to unlock"
            )
            .opacity(headerOpacity(.connections))
            ConnectionCardsView(connections: viewModel.connections)
                .padding(.top, Spacing.s)
                .padding(.bottom, Spacing.hero)
        }
        .id(SectionID.connections)
        .animation(headerAnimation, value: activeSectionID)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundStyle(Theme.textSecondary)
            Text("Check in to see your month")
                .font(Typography.headline)
                .foregroundStyle(Theme.textSecondary)
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
