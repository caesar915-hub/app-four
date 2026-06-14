import SwiftUI

/// Medication Bar settings rows — designed to live inside a `List`.
struct MedicationBarSettingsSection: View {
    @AppStorage("medicationBarVisible") private var barVisible = true
    @AppStorage("medicationBarShowName") private var showName = true
    @AppStorage("medicationBarShowTime") private var showTime = true
    @AppStorage("medicationBarShowEndTime") private var showEndTime = true

    var body: some View {
        Section("Medication Bar") {
            Toggle(isOn: $barVisible) {
                Label("Show Medication Bar", systemImage: "pills.circle")
            }
            .accessibilityHint("Shows a medication progress bar at the top of each screen.")

            if barVisible {
                Toggle(isOn: $showName) {
                    Label("Show Medication Name", systemImage: "pill")
                }
                .accessibilityHint("Displays the medication name and dose in the bar.")

                Toggle(isOn: $showTime) {
                    Label("Show Taken Time", systemImage: "clock")
                }
                .accessibilityHint("Displays when the medication was taken.")

                Toggle(isOn: $showEndTime) {
                    Label("Show End Time", systemImage: "clock.arrow.circlepath")
                }
                .accessibilityHint("Displays when the medication effect is expected to end.")
            }
        }
    }
}

#Preview {
    List {
        MedicationBarSettingsSection()
    }
    .listStyle(.insetGrouped)
}
