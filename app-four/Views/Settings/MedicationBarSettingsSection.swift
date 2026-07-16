import SwiftUI

/// Medication Bar settings rows — designed to live inside a `List`.
struct MedicationBarSettingsSection: View {
    @AppStorage("medicationBarVisible") private var barVisible = true
    @AppStorage("medicationBarShowName") private var showName = true

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
