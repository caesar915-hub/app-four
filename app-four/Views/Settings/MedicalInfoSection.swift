import SwiftUI

/// The medical-scope disclaimer for the medication cluster in Settings —
/// App Review guideline 1.4.1 expects health apps to state their limits and
/// cite where drug information comes from. Calm and factual, never alarming.
struct MedicalInfoSection: View {
    var body: some View {
        Section {
            Text("Squirl is a personal journal, not medical advice. Dose lists and effect times are typical values from the manufacturer's product information — your prescription and response may differ.")
                .font(Typography.body)
                .foregroundStyle(NewLook.inkPrimary)
        } header: {
            Text("Medication info")
        } footer: {
            Text("Talk with your clinician or pharmacist before changing how you take medication.")
        }
    }
}

#Preview {
    NavigationStack {
        List {
            MedicalInfoSection()
        }
        .listStyle(.insetGrouped)
    }
    .withPreviewEnvironment()
}
