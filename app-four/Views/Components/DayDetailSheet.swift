import SwiftUI

struct DayDetailSheet: View {
    let day: InsightsViewModel.CalendarDay
    let onNavigate: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss

    private var dayLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(day.date) { return "Today" }
        if cal.isDateInYesterday(day.date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMM"
        return f.string(from: day.date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.s) { // was 10
                    DaySignalsSummaryView(
                        dayStart: SignalDayKey.dayStart(for: day.date),
                        store: AppDependencies.signalsStore,
                        coordinator: AppDependencies.signalSyncCoordinator,
                        health: AppDependencies.healthService
                    )
                    ForEach(day.recordings) { recording in
                        Button {
                            dismiss()
                            onNavigate(recording.id)
                        } label: {
                            RecordingRow(recording: recording)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Spacing.xl)
            }
            .navigationTitle(dayLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
