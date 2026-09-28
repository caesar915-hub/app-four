import SwiftUI

/// The medical-scope disclaimer for the medication cluster in Settings — App Review guideline
/// 1.4.1 expects health apps to state their limits and cite where drug information comes from.
/// Calm and factual, never alarming.
struct MedicalInfoSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            InfoRow(symbol: Icons.info,
                    text: "Squirl is a personal journal, not medical advice. Dose lists and effect times are typical values from the manufacturer's product information — your prescription and response may differ.")
            Text("Talk with your clinician or pharmacist before changing how you take medication.")
                .font(Typography.captionMedium)
                .foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    MedicalInfoSection()
        .card(.medium)
        .padding(Spacing.gutter)
        .background(Surface.screen)
}
