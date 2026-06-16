import SwiftUI

/// Calendar-grouped library tab: a collapsible week↔month calendar bound two-way to
/// a day-grouped mood/medication timeline (month-paged, newest-first).
struct CalendarLibraryView: View {
    @Binding var selectedTab: Tab
    @State private var viewModel: MoodLibraryViewModel
    @State private var path = NavigationPath()
    @State private var detailRef: RecordingDetailRef?
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var isCalendarExpanded = false
    @State private var topDayID: Date?
    @State private var isProgrammaticScroll = false
    @State private var scrollGuardTask: Task<Void, Never>?
    @State private var scrollOffset: CGFloat = 0
    @State private var headerHeight: CGFloat = 0
    @Environment(AppServices.self) private var services
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let store: RecordingStore
    private let calendar = Calendar.current

    init(store: RecordingStore, selectedTab: Binding<Tab>) {
        self.store = store
        _viewModel = State(wrappedValue: MoodLibraryViewModel(store: store))
        _selectedTab = selectedTab
    }

    private var currentHeaderOpacity: Double {
        Self.headerOpacity(scrollOffset: scrollOffset, headerHeight: headerHeight)
    }

    var body: some View {
        ScreenContainer(title: "", showsMedicationBar: true, scrollable: false, path: $path) {
            VStack(spacing: 0) {
                if viewModel.hasAnyEntries {
                    timelineList
                } else {
                    pinnedHeader
                    emptyState.frame(maxWidth: .infinity).padding(.top, Spacing.hero)
                    Spacer()
                }
            }
            .sheet(item: $detailRef) { ref in
                if let recording = viewModel.recording(for: ref.id) {
                    RecordingDetailView(recording: recording, store: store, services: services)
                        .presentationDragIndicator(.visible)
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

    /// The header+divider block as a non-scrolling element (used only in the empty-state path).
    private var pinnedHeader: some View {
        headerBlock
    }

    /// The header+divider block that lives inside the ScrollView as first content.
    private var scrollingHeader: some View {
        headerBlock
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
            .opacity(currentHeaderOpacity)
            .allowsHitTesting(currentHeaderOpacity > 0.05)
    }

    private var headerBlock: some View {
        VStack(spacing: 0) {
            CalendarHeaderView(
                model: viewModel.calendarMonth,
                selectedDay: $selectedDay,
                isExpanded: $isCalendarExpanded,
                monthLabel: viewModel.monthLabel,
                canJumpToToday: !calendar.isDateInToday(selectedDay) || !viewModel.isCurrentMonth,
                onSelect: { selectDay($0) },
                onJumpToToday: { jumpToToday() },
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
            LazyVStack(spacing: Spacing.m) {
                scrollingHeader
                ForEach(viewModel.timelineDays) { day in
                    DayCard(day: day, onTapRecording: { detailRef = RecordingDetailRef(id: $0) })
                        .id(day.date)
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.xxl)
        }
        .scrollPosition(id: $topDayID, anchor: .top)
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top   // 0 at rest, grows as scrolled up — inset-independent
        } action: { _, new in
            scrollOffset = new
        }
        .edgeFadeMask(top: 0, bottom: Spacing.section)
        .onChange(of: topDayID) { _, newValue in
            guard !isProgrammaticScroll, let day = newValue else { return }
            selectedDay = day
        }
    }

    // MARK: - Pure opacity mapping (testable)

    static func headerOpacity(scrollOffset: CGFloat, headerHeight: CGFloat) -> Double {
        guard headerHeight > 0 else { return 1.0 }
        return Double(min(max(1 - scrollOffset / headerHeight, 0), 1))
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

    private func scrollList(to day: Date) {
        let target = calendar.startOfDay(for: day)
        selectedDay = target
        isProgrammaticScroll = true
        withAnimation(reduceMotion ? nil : Motion.smooth) { topDayID = target }
        scrollGuardTask?.cancel()                       // a newer tap supersedes the previous guard
        scrollGuardTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.45))  // ~ the scroll animation; clears the loop guard
            if !Task.isCancelled { isProgrammaticScroll = false }
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
