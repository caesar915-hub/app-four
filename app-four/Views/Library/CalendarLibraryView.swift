import SwiftUI

/// The Calendar root as the pen draws it (spec 057, `iPhone 17 - 19`): the medication bar, the
/// month header + week strip (expandable to the month — D6.1), the selected day expanded into
/// its check-in rows, then "Previous days" as collapsed cards, month-scoped (D6.4). The strip
/// fades on scroll into the compact title band (spec 035, kept — D6.3).
struct CalendarLibraryView: View {
    @Binding var selectedTab: Tab
    @State private var viewModel: MoodLibraryViewModel
    @State private var path = NavigationPath()
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var isCalendarExpanded = false
    @State private var listPosition = ScrollPosition(edge: .top)
    @State private var expandedCards = ExpandedDayCards()
    @State private var collapseProgress: CGFloat = 0
    @State private var stripHeight: CGFloat = 0
    @State private var pendingDelete: UUID?
    @AppStorage("autoExpandOnSelection") private var autoExpandOnSelection = true
    @AppStorage("alwaysExpandCards") private var alwaysExpandCards = false
    @Environment(AppServices.self) private var services
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let store: RecordingStore
    private let calendar = Calendar.current

    init(store: RecordingStore, selectedTab: Binding<Tab>) {
        self.store = store
        _viewModel = State(wrappedValue: MoodLibraryViewModel(store: store))
        _selectedTab = selectedTab
    }

    var body: some View {
        ScreenContainer(title: "", showsMedicationBar: true, scrollable: false, path: $path) {
            // A non-scroll container is laid out BELOW the med-bar safe-area inset, so the bar
            // keeps its app-wide position (owner ruling 2026-07-16); the compact title band
            // overlays the top of this region.
            ZStack(alignment: .top) {
                if viewModel.hasAnyEntries {
                    timelineList
                    compactTitleBand
                } else {
                    VStack(spacing: 0) {
                        headerBlock
                        emptyState.frame(maxWidth: .infinity).padding(.top, Spacing.hero)
                        Spacer()
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
        .trackScreen("CalendarLibraryView")
        #if DEBUG
        // Screenshot pass: `-openLatest` pushes the newest check-in so Day Details can be captured.
        .onAppear {
            guard CommandLine.arguments.contains("-openLatest"), path.isEmpty,
                  let latest = store.recordings.first else { return }
            path.append(latest.id)
        }
        #endif
        .onChange(of: selectedTab) { oldValue, newValue in
            if oldValue == .calendar && newValue != .calendar {
                path.removeLast(path.count)
            }
            if newValue == .calendar { jumpToToday() }
        }
        .confirmationDialog("Delete this check-in?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Delete check-in", role: .destructive) {
                if let id = pendingDelete, let recording = viewModel.recording(for: id) {
                    viewModel.delete(recording)
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("The recording, its transcript and its signals are removed from this device.")
        }
    }

    // MARK: - Header

    private var showsTitle: Bool {
        CalendarStripFade.showsTitle(progress: collapseProgress)
    }

    /// Spec-035 cross-fade: the selected day's label snap-fades in once the strip is nearly gone.
    private var compactTitleBand: some View {
        VStack(spacing: 0) {
            Text(viewModel.dayLabel(for: selectedDay))
                .font(Typography.rowTitle)
                .foregroundStyle(Ink.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.s)
            HairlineDivider()
        }
        .background(Surface.screen)
        .opacity(showsTitle ? 1 : 0)
        .animation(reduceMotion ? nil : Motion.snappy, value: showsTitle)
        .accessibilityHidden(!showsTitle)
        .allowsHitTesting(showsTitle)
    }

    private var headerBlock: some View {
        CalendarHeaderView(
            model: viewModel.calendarMonth,
            selectedDay: $selectedDay,
            isExpanded: $isCalendarExpanded,
            monthLabel: viewModel.monthLabel,
            onSelect: { selectDay($0) },
            onPageMonth: { pageMonth($0) }
        )
        .padding(.horizontal, Spacing.gutter)
        .padding(.top, Spacing.m)
        .padding(.bottom, Spacing.s)
    }

    // MARK: - Timeline

    private var timelineList: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerBlock
                    .opacity(CalendarStripFade.stripOpacity(progress: collapseProgress))
                    .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { stripHeight = $0 }
                dayCards
                    .padding(.horizontal, Spacing.gutter)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.xxl)
            }
        }
        .scrollPosition($listPosition)
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            CalendarStripFade.progress(offset: geo.contentOffset.y + geo.contentInsets.top,
                                       stripHeight: stripHeight)
        } action: { _, new in
            collapseProgress = new
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
    }

    /// The selected day's card first, then a "Previous days" heading over the older, collapsed cards.
    private var dayCards: some View {
        let days = viewModel.timelineDaysFilteredToSelectedDate(selectedDay)
        let firstPrevious = days.firstIndex { !calendar.isDate($0.date, inSameDayAs: selectedDay) }
        return LazyVStack(spacing: Spacing.s) {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                if index == firstPrevious {
                    SectionHeading("Previous days")
                        .padding(.top, index == 0 ? 0 : Spacing.l)
                        .padding(.bottom, Spacing.xs)
                }
                DayCard(
                    day: day,
                    isExpanded: expandedCards.shouldExpand(day.date, alwaysExpand: alwaysExpandCards),
                    onToggleExpand: {
                        withAnimation(reduceMotion ? nil : Motion.expand) {
                            expandedCards = expandedCards.toggling(day.date)
                        }
                    },
                    onTapRecording: { path.append($0) },
                    onDeleteRecording: { pendingDelete = $0 }
                )
            }
        }
    }

    // MARK: - Selection / navigation

    private func selectDay(_ cell: CalendarMonthModel.DayCell) {
        if !cell.isInMonth {                       // out-of-month tap → page to that month, then select
            let delta = cell.date < viewModel.currentMonth ? -1 : 1
            guard canPage(delta) else { return }
            delta < 0 ? viewModel.prevMonth() : viewModel.nextMonth()
        }
        scrollList(to: cell.date)
    }

    /// Selection (the filter boundary) is tap/jump-only — scrolling never re-filters (spec-035 D3).
    private func scrollList(to day: Date) {
        let target = calendar.startOfDay(for: day)
        selectedDay = target
        withAnimation(reduceMotion ? nil : Motion.smooth) {
            listPosition.scrollTo(edge: .top)
            expandedCards = expandedCards.selecting(target, autoExpand: autoExpandOnSelection)
        }
    }

    private func jumpToToday() {
        viewModel.currentMonth = Date()
        if reduceMotion { isCalendarExpanded = false }
        else { withAnimation(Motion.smooth) { isCalendarExpanded = false } }
        scrollList(to: calendar.startOfDay(for: Date()))
    }

    /// Month paging is bounded: back to the earliest month with data, forward to the current month.
    private func canPage(_ delta: Int) -> Bool {
        if delta < 0 {
            guard let earliest = viewModel.availableMonths.first else { return false }
            return calendar.compare(viewModel.currentMonth, to: earliest, toGranularity: .month) == .orderedDescending
        } else {
            return !viewModel.isCurrentMonth
        }
    }

    private func pageMonth(_ delta: Int) {
        guard canPage(delta) else { return }
        delta < 0 ? viewModel.prevMonth() : viewModel.nextMonth()
        if let newest = viewModel.timelineDays.first?.date {
            scrollList(to: newest)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.s) {
            IdentityIcon(.mood, size: Metrics.glyphTile)
            Text("No entries yet")
                .font(Typography.sectionTitle)
                .foregroundStyle(Ink.primary)
            Text("Record a voice note to see it here.")
                .font(Typography.cardSubtitle)
                .foregroundStyle(Ink.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Spacing.gutter)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    CalendarLibraryView(store: .preview, selectedTab: .constant(.calendar))
        .withPreviewEnvironment()
}
