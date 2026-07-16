import SwiftUI

/// Calendar-grouped library tab: a collapsible week↔month calendar bound two-way to
/// a day-grouped mood/medication timeline (month-paged, newest-first).
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
            // `Group`, not `VStack`: the ScrollView must own the screen's top edge so the
            // med-bar safe-area inset lets the list scroll UNDER the floating bar (spec-035).
            Group {
                if viewModel.hasAnyEntries {
                    timelineList
                } else {
                    VStack(spacing: 0) {
                        pinnedHeader
                        emptyState.frame(maxWidth: .infinity).padding(.top, Spacing.hero)
                        Spacer()
                    }
                }
            }
            .toolbar { compactTitle }
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
        .onChange(of: selectedTab) { oldValue, newValue in
            if oldValue == .calendar && newValue != .calendar {
                path.removeLast(path.count)
            }
            if newValue == .calendar { jumpToToday() }
        }
    }

    // MARK: - Header

    /// Empty-state only: with no scroll there is nothing to collapse, so the strip stays
    /// fixed and fully opaque (FR-012).
    private var pinnedHeader: some View {
        headerBlock
    }

    /// Whether the compact nav title has taken over from the (almost fully faded) strip.
    private var showsTitle: Bool {
        CalendarStripFade.showsTitle(progress: collapseProgress)
    }

    /// Tiimo cross-fade (spec-035 US2): the selected day snap-fades into the otherwise-empty
    /// inline nav bar once the strip is nearly gone, so date context survives deep scrolls.
    private var compactTitle: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text(viewModel.dayLabel(for: selectedDay))
                .font(Typography.headline)
                .foregroundStyle(NewLook.inkPrimary)
                .opacity(showsTitle ? 1 : 0)
                .animation(reduceMotion ? nil : Motion.snappy, value: showsTitle)
                .accessibilityHidden(!showsTitle)
        }
    }

    private var headerBlock: some View {
        VStack(spacing: 0) {
            CalendarHeaderView(
                model: viewModel.calendarMonth,
                selectedDay: $selectedDay,
                isExpanded: $isCalendarExpanded,
                monthLabel: viewModel.monthLabel,
                onSelect: { selectDay($0) },
                onPageMonth: { pageMonth($0) }
            )
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.s)

            Divider().padding(.top, Spacing.s)
        }
    }

    // MARK: - Timeline

    private var timelineList: some View {
        ScrollView {
            // Plain VStack: the strip must always be materialized (it drives the fade
            // geometry); the cards keep their laziness in the nested LazyVStack. In-content
            // placement reclaims the strip's space by layout and fades by compositor —
            // never a scroll-driven height animation (spec-035 D1, FR-011).
            VStack(spacing: 0) {
                headerBlock
                    .opacity(CalendarStripFade.stripOpacity(progress: collapseProgress))
                    .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { stripHeight = $0 }
                LazyVStack(spacing: Spacing.m) {
                    ForEach(viewModel.timelineDaysFilteredToSelectedDate(selectedDay)) { day in
                        DayCard(
                            day: day,
                            isExpanded: expandedCards.shouldExpand(day.date, alwaysExpand: alwaysExpandCards),
                            onToggleExpand: {
                                withAnimation(reduceMotion ? nil : Motion.expand) {
                                    expandedCards = expandedCards.toggling(day.date)
                                }
                            },
                            onTapRecording: { path.append($0) }
                        )
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.m)
                .padding(.bottom, Spacing.xxl)
            }
        }
        .scrollPosition($listPosition)
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            // contentOffset.y + contentInsets.top == 0 at rest by documented contract —
            // the clean origin the dead zone needs (spec-035 D2).
            CalendarStripFade.progress(offset: geo.contentOffset.y + geo.contentInsets.top,
                                       stripHeight: stripHeight)
        } action: { _, new in
            collapseProgress = new
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)   // short filtered lists can't flicker-fade (FR-013)
        .edgeFadeMask(top: 0, bottom: Spacing.section)
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

    /// Selection (the filter boundary) is tap/jump-only — scrolling never re-filters, so
    /// browsing older days can't ratchet newer days out of the list. Edge-based, not
    /// id-based: the strip is now the first scroll item, and anchoring the selected day's
    /// card to `.top` would scroll the calendar itself off-screen on every tap (spec-035 D3).
    private func scrollList(to day: Date) {
        let target = calendar.startOfDay(for: day)
        selectedDay = target
        withAnimation(reduceMotion ? nil : Motion.smooth) {
            listPosition.scrollTo(edge: .top)
            expandedCards = expandedCards.selecting(target, autoExpand: autoExpandOnSelection)   // collapse all, open selected (FR-009/FR-019)
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
        if let newest = viewModel.timelineDays.first?.date {   // newest in-range day of the now-current month
            scrollList(to: newest)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No entries yet",
            systemImage: "calendar.badge.exclamationmark",
            description: Text("Record a voice note to see it here.")
        )
    }
}

#Preview {
    CalendarLibraryView(store: .preview, selectedTab: .constant(.calendar))
        .withPreviewEnvironment()
}
