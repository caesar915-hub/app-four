import SwiftUI

/// One-time, plain-language primer shown before the system HealthKit sheet (FR-005):
/// explains what is read and that it stays on-device, then requests authorization.
/// "Not now" leaves the manual entry path fully usable.
struct HealthAccessPrimerView: View {
    let health: HealthDataReading
    var onFinished: (HealthAuthorizationState) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var requesting = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 56))
                .foregroundStyle(Palette.sleepIndigo)
            Text("Connect Apple Health")
                .font(.title2.bold())
            Text("Squirl can show your sleep, activity, heart, cycle, nutrition, and workout data next to your check-ins. It's read-only and stays on your device — nothing is uploaded.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Button {
                Task { await request() }
            } label: {
                Text(requesting ? "Requesting…" : "Connect")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(requesting)
            Button("Not now") {
                onFinished(.notDetermined)
                dismiss()
            }
            .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func request() async {
        requesting = true
        let state = (try? await health.requestAuthorization()) ?? .denied
        requesting = false
        onFinished(state)
        dismiss()
    }
}
