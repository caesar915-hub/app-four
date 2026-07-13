import SwiftUI

/// Day-card / calendar settings rows — designed to live inside a `List`. Shares the
/// `autoExpandOnSelection` / `alwaysExpandCards` keys with `CalendarLibraryView` via `@AppStorage` (the same pattern
/// as the medication-bar toggles), so toggling here is reflected in the calendar immediately.
struct DayCardSettingsSection: View {
    @AppStorage("autoExpandOnSelection") private var autoExpandOnSelection = true
    @AppStorage("alwaysExpandCards") private var alwaysExpandCards = false

    var body: some View {
        Section("Day cards") {
            Toggle(isOn: $alwaysExpandCards) {
                Label("Always expand cards", systemImage: "rectangle.stack")
            }
            .accessibilityHint("When on, every day's check-ins stay open in the calendar.")

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
