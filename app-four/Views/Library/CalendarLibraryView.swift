import SwiftUI

/// Calendar-grouped library tab: a collapsible week↔month calendar bound two-way to
/// a day-grouped mood/medication timeline (month-paged, newest-first).
struct CalendarLibraryView: View {
    @Binding var selectedTab: Tab
    @State private var viewModel: MoodLibraryViewModel
    @State private var path = NavigationPath()
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var isCalendarExpanded = false
    @State private var topDayID: Date?
    @State private var expandedCards = ExpandedDayCards()
    @AppStorage("autoExpandOnSelection") private var autoExpandOnSelection = true
    @AppStorage("alwaysExpandCards") private var alwaysExpandCards = false
    @Environment(AppServices.self) private var services
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var calendarAccess: CalendarAccessState = .notDetermined
    @AppStorage(CalendarPreferences.Keys.calendarInvitationDismissed) private var invitationDismissed = false
    @AppStorage(CalendarPreferences.Keys.calendarExplainerDeclined) private var explainerDeclined = false
    @State private var showCalendarExplainer = false
    private let store: RecordingStore
    private let calendar = Calendar.current

    init(store: RecordingStore, selectedTab: Binding<Tab>) {
        self.store = store
        _viewModel = State(wrappedValue: MoodLibraryViewModel(store: store))
        _selectedTab = selectedTab
    }

    var body: some View {
        ScreenContainer(title: "", showsMedicationBar: true, scrollable: false, path: $path) {
            VStack(spacing: 0) {
                if viewModel.hasAnyEntries {
                    timelineList
                } else {
                    pinnedHeader
                    if CalendarAccessPresentation.shouldShowInvitationCard(
                        accessState: calendarAccess,
                        invitationDismissed: invitationDismissed,
                        explainerDeclined: explainerDeclined
                    ) {
                        invitationCard
                            .padding(.horizontal, Spacing.l)
                            .padding(.top, Spacing.m)
                    }
                    emptyState.frame(maxWidth: .infinity).padding(.top, Spacing.hero)
                    Spacer()
                }
            }
            .task {
                viewModel.attach(dayContextStore: services.dayContextStore, coordinator: services.calendarCoordinator)
                calendarAccess = await services.calendarContextService.accessState()
            }
            .task(id: scenePhase) {
                if scenePhase == .active {
                    calendarAccess = await services.calendarContextService.accessState()
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
            .sheet(isPresented: $showCalendarExplainer) {
                CalendarExplainerSheet {
                    Task { calendarAccess = await services.calendarContextService.accessState() }
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
        VStack(spacing: 0) {
            pinnedHeader
            ScrollView {
                LazyVStack(spacing: Spacing.m) {
                    if CalendarAccessPresentation.shouldShowInvitationCard(
                        accessState: calendarAccess,
                        invitationDismissed: invitationDismissed,
                        explainerDeclined: explainerDeclined
                    ) {
                        invitationCard
                    }
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
    }

    private var invitationCard: some View {
        CalendarInvitationCard(
            onConnect: { showCalendarExplainer = true },
            onDismiss: { invitationDismissed = true }
        )
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

// MARK: - Calendar invitation card

private struct CalendarInvitationCard: View {
    let onConnect: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Calendar")
                    .font(Typography.label)
                    .textCase(.uppercase)
                    .tracking(0.7)
                    .foregroundStyle(Theme.accent)

                Text("See what your day held")
                    .font(Typography.headline)
                    .foregroundStyle(Theme.textPrimary)

                Text("A one-line reminder of what was on your calendar, beside each check-in. So past days make sense again.")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.trailing, Spacing.xxl)

                Button(action: onConnect) {
                    Label("Connect calendar", systemImage: "calendar")
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.vertical, Spacing.xs + 3)
                        .padding(.horizontal, Spacing.m + 2)
                        .background(Theme.surface2, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground, in: .rect(cornerRadius: Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card)
                    .strokeBorder(Theme.separator, lineWidth: 1)
            )
            .shadow(color: Theme.textPrimary.opacity(0.06), radius: 10, y: 3)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(Theme.surface2, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(Spacing.m)
        }
    }
}

#Preview {
    CalendarLibraryView(store: .preview, selectedTab: .constant(.calendar))
        .withPreviewEnvironment()
}
