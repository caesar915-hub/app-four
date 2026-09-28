import SwiftUI

/// Settings › Check-in calendar › Calendar cards: two toggle rows. Shares the
/// `autoExpandOnSelection` / `alwaysExpandCards` keys with `CalendarLibraryView` via `@AppStorage`,
/// so a change here is reflected in the calendar immediately.
struct DayCardSettingsSection: View {
    @AppStorage("autoExpandOnSelection") private var autoExpandOnSelection = true
    @AppStorage("alwaysExpandCards") private var alwaysExpandCards = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Calendar cards")
                .font(Typography.rowTitle)
                .foregroundStyle(Ink.primary)
                .accessibilityAddTraits(.isHeader)
            ToggleRow("Auto-expand selected day", isOn: $autoExpandOnSelection)
                .accessibilityHint("When on, tapping a date opens that day's check-ins automatically.")
            HairlineDivider()
            ToggleRow("Always expand cards", isOn: $alwaysExpandCards)
                .accessibilityHint("When on, every day's check-ins stay open in the calendar.")
        }
    }
}

#Preview {
    DayCardSettingsSection()
        .card(.large)
        .padding(Spacing.gutter)
        .background(Surface.screen)
}
