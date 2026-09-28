import SwiftUI

/// Settings › Medication bar: four toggle rows. Rows 2–4 only exist while the bar is shown
/// (the pen never draws them off). Keys are shared with `MedicationBarView` via `@AppStorage`.
struct MedicationBarSettingsSection: View {
    @AppStorage("medicationBarVisible") private var barVisible = true
    @AppStorage("medicationBarShowName") private var showName = true
    @AppStorage("medicationBarShowTakenTime") private var showTakenTime = true
    @AppStorage("medicationBarShowEndTime") private var showEndTime = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ToggleRow("Show medication bar", isOn: $barVisible)
                .accessibilityHint("Shows your active doses at the top of each screen.")
            if barVisible {
                HairlineDivider()
                ToggleRow("Show medication name", isOn: $showName)
                    .accessibilityHint("Shows the medication name and dose in the bar.")
                HairlineDivider()
                ToggleRow("Show taken time", isOn: $showTakenTime)
                    .accessibilityHint("Shows when each dose was taken.")
                HairlineDivider()
                ToggleRow("Show end time", isOn: $showEndTime)
                    .accessibilityHint("Shows when each dose is expected to wear off.")
            }
        }
        .animation(reduceMotion ? nil : Motion.expand, value: barVisible)
    }
}

#Preview {
    MedicationBarSettingsSection()
        .card(.large)
        .padding(Spacing.gutter)
        .background(Surface.screen)
}
