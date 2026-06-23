import SwiftUI

/// Day-card / calendar settings rows — designed to live inside a `List`. Shares the
/// `autoExpandOnSelection` key with `CalendarLibraryView` via `@AppStorage` (the same pattern
/// as the medication-bar toggles), so toggling here is reflected in the calendar immediately.
struct DayCardSettingsSection: View {
    @AppStorage("autoExpandOnSelection") private var autoExpandOnSelection = true

    var body: some View {
        Section("Calendar") {
            Toggle(isOn: $autoExpandOnSelection) {
                Label("Auto-expand selected day", systemImage: "rectangle.expand.vertical")
            }
            .accessibilityHint("When on, tapping a date opens that day's check-ins automatically.")
        }
    }
}

#Preview {
    List {
        DayCardSettingsSection()
    }
    .listStyle(.insetGrouped)
}
