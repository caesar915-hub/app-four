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
    @State private var expandedCards = ExpandedDayCards()
    @AppStorage("autoExpandOnSelection") private var autoExpandOnSelection = true
    @AppStorage("didOfferHealthAccess") private var didOfferHealthAccess = false
    @AppStorage("healthSyncEnabled") private var healthSyncEnabled = true
    @Environment(AppServices.self) private var services
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let store: RecordingStore
    private let calendar = Calendar.current

    init(store: RecordingStore, selectedTab: Binding<Tab>) {
        self.store = store
        _viewModel = State(wrappedValue: MoodLibraryViewModel(store: store, signalsStore: AppDependencies.signalsStore))
        _selectedTab = selectedTab
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
                } else {
                    Color.clear.onAppear { detailRef = nil }   // recording deleted out from under the sheet → dismiss
                }
            }
        }
        .trackScreen("CalendarLibraryView")
        .task {
            // Silent nutrition/signal sync (spec 031 FR-010): only when access was already
            // offered elsewhere AND the user hasn't paused syncing. The calendar NEVER
            // presents the HealthKit primer — that stays in the Insights flow.
            guard didOfferHealthAccess, healthSyncEnabled else { return }
            _ = try? await AppDependencies.signalSyncCoordinator.syncRecentIfNeeded(lastDays: 30)
            viewModel.loadNutrition()
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if oldValue == .calendar && newValue != .calendar {
                path.removeLast(path.count)
            }
            if newValue == .calendar { jumpToToday() }
        }
    }

    // MARK: - Header

    private var pinnedHeader: some View {
        headerBlock
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
        VStack(spacing: 0) {
            pinnedHeader
            filterCaption
            ScrollView {
                LazyVStack(spacing: Spacing.m) {
                    ForEach(viewModel.timelineDaysFilteredToSelectedDate(selectedDay)) { day in
                        DayCard(
                            day: day,
                            isExpanded: expandedCards.contains(day.date),
                            onToggleExpand: {
                                withAnimation(reduceMotion ? nil : Motion.smooth) {
                                    expandedCards = expandedCards.toggling(day.date)
                                }
                            },
                            onTapRecording: { detailRef = RecordingDetailRef(id: $0) }
                        )
                        .id(day.date)
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.m)
                .padding(.bottom, Spacing.xxl)
            }
            .scrollPosition(id: $topDayID, anchor: .top)
            .edgeFadeMask(top: 0, bottom: Spacing.section)
        }
        .animation(reduceMotion ? nil : Motion.smooth, value: calendar.isDateInToday(selectedDay))
    }

    /// Names the filter boundary so a list trimmed to "≤ selected day" (FR-010) never reads as
    /// silently missing entries. Suppressed at today, when nothing is filtered out.
    @ViewBuilder private var filterCaption: some View {
        if !calendar.isDateInToday(selectedDay) {
            Text("Entries up to \(viewModel.dayLabel(for: selectedDay))")
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.s)
                .transition(.opacity)
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

    /// Selection (the filter boundary) is tap/jump-only — scrolling never re-filters, so
    /// browsing older days can't ratchet newer days out of the list.
    private func scrollList(to day: Date) {
        let target = calendar.startOfDay(for: day)
        selectedDay = target
        withAnimation(reduceMotion ? nil : Motion.smooth) {
            topDayID = target
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
